#!/usr/bin/env bash
# t24: agentspace-parallel CAS squash flow — end-to-end git mechanics exactly
# as the skill's §3/§7/§8 prescribe: fixed worktree location, registration,
# CAS recheck, squash merge through the commit gate, diff-empty proof, absorb
# with a FORCED conflict (deliberate surface intersection to exercise the
# machinery — iron rule 7 forbids this in real use), cleanup with branch -D.
# Lane branch names are CONSTRUCTED at runtime (selfhost literal discipline).
set -euo pipefail
. "$(dirname "$0")/lib.sh"

SB="$(build_sandbox t24)"
WS="$SB/AGENTSPACE"
cd "$SB"
mc() { git -C "$WS" add -A >/dev/null 2>&1; git -C "$WS" commit -qm "test: t24 milestone" >/dev/null 2>&1 || true; }
SEQ=0
# monotonic commit dates: identical tree+message+parent inside one second would
# collide into the same sha, making a squashed lane tip "merged" for branch -d
gc() { SEQ=$((SEQ+1)); GIT_AUTHOR_DATE="@$SEQ +0000" GIT_COMMITTER_DATE="@$SEQ +0000" \
  git -c user.name=test -c user.email=test@test -C "$1" "${@:2}"; }

BRA="$(printf 'plan-%04d' 1)"
BRB="$(printf 'plan-%04d' 2)"
BADMSG="$(printf 'plan:%04d results' 2)"   # colon-form violation for the gate negative

bash "$WS/scripts/repos.sh" --add . >/dev/null
printf '/AGENTSPACE/\n/worktrees/\n' > "$SB/.gitignore"
git -C "$SB" add .gitignore >/dev/null && gc "$SB" commit -qm "ignore worktrees"
printf 'line1\nline2\nline3\n' > "$SB/shared.py"
git -C "$SB" add shared.py && gc "$SB" commit -qm "feat: shared module"
BASE="$(git -C "$SB" rev-parse HEAD)"
mc

# --- lane A: worktree + dev commit ---
gc "$SB" worktree add "$SB/worktrees/0001/host" -b "$BRA" main >/dev/null
bash "$WS/scripts/repos.sh" --add worktrees/0001/host >/dev/null
echo "alpha = 1" > "$SB/worktrees/0001/host/a.py"
printf 'line1\nline2\nline3\nalpha_shared = True\n' > "$SB/worktrees/0001/host/shared.py"
gc "$SB/worktrees/0001/host" add -A >/dev/null
gc "$SB/worktrees/0001/host" commit -qm "feat: lane a module"

# --- lane B: created BEFORE A merges (forces absorb later); touches the SAME
# --- lines of shared.py on purpose (conflict path) ---
gc "$SB" worktree add "$SB/worktrees/0002/host" -b "$BRB" main >/dev/null
bash "$WS/scripts/repos.sh" --add worktrees/0002/host >/dev/null
echo "beta = 2" > "$SB/worktrees/0002/host/b.py"
printf 'line1\nline2\nline3\nbeta_shared = True\n' > "$SB/worktrees/0002/host/shared.py"
gc "$SB/worktrees/0002/host" add -A >/dev/null
gc "$SB/worktrees/0002/host" commit -qm "feat: lane b module"
mc

# --- lane A CAS: recheck → squash → gate → commit → proof ---
mkdir -p "$SB/.locks"
mkdir "$SB/.locks/mainline" || fail "mainline lock should be free"
[ "$(git -C "$SB" rev-parse main)" = "$BASE" ] || fail "CAS recheck: main moved unexpectedly"
# gate negative first: a bookkeeping-id squash message must be blocked
assert_fails bash "$WS/scripts/commit-check.sh" "$SB" "$BADMSG"
gc "$SB" merge --squash "$BRA" >/dev/null
bash "$WS/scripts/commit-check.sh" "$SB" "feat: lane a module" >/dev/null \
  || fail "gate must pass a clean squash message"
gc "$SB" commit -qm "feat: lane a module"
[ -z "$(git -C "$SB" diff "$BRA" main)" ] || fail "diff-empty proof failed after lane A squash"
np="$(git -C "$SB" rev-list --parents -n 1 HEAD | awk '{print NF-1}')"
[ "$np" -eq 1 ] || fail "squash commit must be single-parent, got $np"
rmdir "$SB/.locks/mainline"

# --- lane B: CAS recheck fails (main moved) → absorb with conflict → resolve ---
B_BASE="$BASE"
[ "$(git -C "$SB" rev-parse main)" = "$B_BASE" ] && fail "CAS recheck should have detected A's squash"
gc "$SB/worktrees/0002/host" merge main -m "merge: absorb mainline $(git -C "$SB" rev-parse --short main) — lane a squash" >/dev/null 2>&1 \
  && fail "absorb should have conflicted on shared.py"
# port, not pick sides: keep BOTH lanes' lines
printf 'line1\nline2\nline3\nalpha_shared = True\nbeta_shared = True\n' > "$SB/worktrees/0002/host/shared.py"
gc "$SB/worktrees/0002/host" add shared.py >/dev/null
gc "$SB/worktrees/0002/host" commit -qm "merge: absorb mainline — port lane b onto lane a state" >/dev/null \
  || fail "absorb resolution commit failed"
grep -q "alpha_shared" "$SB/worktrees/0002/host/shared.py" || fail "resolution lost lane A content"

# --- lane B CAS retry: green path ---
mkdir "$SB/.locks/mainline" || fail "mainline lock should be free (retry)"
ABSORBED="$(git -C "$SB" rev-parse main)"
[ "$(git -C "$SB" rev-parse main)" = "$ABSORBED" ] || fail "main moved after absorb"
gc "$SB" merge --squash "$BRB" >/dev/null
bash "$WS/scripts/commit-check.sh" "$SB" "feat: lane b module" >/dev/null \
  || fail "gate must pass lane B squash"
gc "$SB" commit -qm "feat: lane b module"
[ -z "$(git -C "$SB" diff "$BRB" main)" ] || fail "diff-empty proof failed after lane B squash"
rmdir "$SB/.locks/mainline"

# --- mainline shape: exactly 2 new single-parent commits, PR-name titles ---
n_new="$(git -C "$SB" rev-list --count "$BASE..main")"
[ "$n_new" -eq 2 ] || fail "expected exactly 2 squash commits on main, got $n_new"
n_merges="$(git -C "$SB" rev-list --count --merges "$BASE..main")"
[ "$n_merges" -eq 0 ] || fail "mainline must have zero merge commits, got $n_merges"
git -C "$SB" log --first-parent --format=%s "$BASE..main" | grep -Fxq "feat: lane a module" || fail "lane A PR-name missing on mainline"
git -C "$SB" log --first-parent --format=%s "$BASE..main" | grep -Fxq "feat: lane b module" || fail "lane B PR-name missing on mainline"
grep -q "alpha_shared" "$SB/shared.py" && grep -q "beta_shared" "$SB/shared.py" \
  || fail "mainline shared.py must carry both lanes' content"

# --- doctor mid-flow: armed (branches + lanes exist), mainline clean ---
mc
OUT="$(bash "$WS/scripts/doctor.sh")" || fail "doctor must be green mid-flow: $OUT"
assert_output_not_contains "$OUT" "主线窗口含 merge commit"
assert_output_not_contains "$OUT" "连字符形"
assert_output_not_contains "$OUT" "worktree 未登记"

# --- cleanup: branch -d must REFUSE (squash is not an ancestor), -D works ---
gc "$SB" worktree remove "$SB/worktrees/0001/host" >/dev/null
gc "$SB" worktree remove "$SB/worktrees/0002/host" >/dev/null
bash "$WS/scripts/repos.sh" --remove worktrees/0001/host >/dev/null
bash "$WS/scripts/repos.sh" --remove worktrees/0002/host >/dev/null
assert_fails git -C "$SB" branch -d "$BRA"
gc "$SB" branch -D "$BRA" >/dev/null || fail "branch -D lane A failed"
gc "$SB" branch -D "$BRB" >/dev/null || fail "branch -D lane B failed"
mc
OUT="$(bash "$WS/scripts/doctor.sh")" || fail "post-cleanup doctor must be green: $OUT"

echo "t24 PASS: CAS squash flow — gate-ordered merge, diff-empty proofs, conflict absorb, -D cleanup"
