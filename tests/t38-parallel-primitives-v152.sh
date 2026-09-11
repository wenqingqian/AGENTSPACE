#!/usr/bin/env bash
# t38: v1.5.2 parallel-primitives batch — (1) new-plan --claim NNNN reserves a
# SPECIFIC id atomically (free id claims and creates; a taken id — todo file,
# done file, or bare index row — refuses; the plain counter skips claimed ids).
# (2) parallel-workspace --recv no longer echoes a plan's own broadcasts back
# into its inbox (rows and header count stay consistent; --remove cascade
# still clears own rows). (3) --worktree <plan_id> <repo> builds the skill's
# canonical lane checkout (worktrees/<plan-id>/<repo-name> on branch
# plan-<id>), idempotent, reusing a kept branch, warning on embedded-form
# worktrees/ not being gitignored. (4) commit-check gates a lane worktree of a
# REGISTERED repo through its main checkout (no per-worktree registration
# row), while an unregistered repo's worktree still refuses with exit 2.
# (5) doctor [0] names the active parallel lanes when the ledger is dirty so
# the dirt gets attributed before a milestone commit.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

SB="$(build_sandbox t38)"
WS="$SB/AGENTSPACE"
HOST="$SB"
PWS="$WS/scripts/parallel-workspace.sh"
DOC="$WS/scripts/doctor.sh"

CID="$(printf '%04d' 7)"          # claimed id under test (runtime-built)
L1="$(printf '%04d' 1)"
L2="$(printf '%04d' 2)"
BR1="plan-$L1"

# ============ 1. new-plan --claim: atomic id reservation ============
OUT="$(bash "$WS/scripts/new-plan.sh" "claim target" --claim 7)"
assert_output_contains "$OUT" "plan:$CID"
assert_output_contains "$OUT" "(claimed)"
compgen -G "$WS/plan/todo/$CID-*.md" >/dev/null || fail "claimed plan file missing"
grep -q "^| $CID |" "$WS/plan/index.md" || fail "claimed id missing from plan/index.md"

# claiming the same id again refuses (todo file present)
OUT2="$(bash "$WS/scripts/new-plan.sh" "claim clash" --claim 7 2>&1 || true)"
assert_output_contains "$OUT2" "plan:$CID already exists"

# the plain counter skips claimed ids
NEXT="$(printf '%04d' 8)"
OUT="$(bash "$WS/scripts/new-plan.sh" "plain next")"
assert_output_contains "$OUT" "plan:$NEXT"

# a DONE id refuses too (done file present)
python3 - "$WS"/plan/todo/"$CID"-*.md <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read().replace("<!-- 完成时填写: 一句话结论", "一句话结论: done probe")
open(p, "w").write(s)
EOF
bash "$WS/scripts/complete-plan.sh" "$CID" done "done probe" >/dev/null
OUT2="$(bash "$WS/scripts/new-plan.sh" "claim done clash" --claim 7 2>&1 || true)"
assert_output_contains "$OUT2" "plan:$CID already exists"

# a bare index row (file removed from both dirs) refuses via the index check
rm "$WS"/plan/done/"$CID"-*.md
OUT2="$(bash "$WS/scripts/new-plan.sh" "claim index clash" --claim 7 2>&1 || true)"
assert_output_contains "$OUT2" "plan:$CID already exists"

# non-numeric claim is a usage-level refusal
OUT2="$(bash "$WS/scripts/new-plan.sh" "claim bad" --claim abc 2>&1 || true)"
assert_output_contains "$OUT2" "Id must be numeric"

# ============ 2. --recv: no self-echo ============
bash "$PWS" --init "$L1" "lane one" >/dev/null
bash "$PWS" --init "$L2" "lane two" >/dev/null
bash "$PWS" --send --src "$L1" --dst all --msg "broadcast hello" >/dev/null

OUT="$(bash "$PWS" --recv "$L1")"
assert_output_contains "$OUT" "inbox of $L1: 0 message(s)"
OUT="$(bash "$PWS" --recv "$L2")"
assert_output_contains "$OUT" "1 message(s)"
assert_output_contains "$OUT" "broadcast hello"

# a direct note still lands; the earlier broadcast no longer re-appears for its sender
bash "$PWS" --send --src "$L2" --dst "$L1" --msg "direct note" >/dev/null
OUT="$(bash "$PWS" --recv "$L1")"
assert_output_contains "$OUT" "1 message(s)"
assert_output_contains "$OUT" "direct note"
assert_output_not_contains "$OUT" "broadcast hello"

# ============ 3. --worktree: canonical lane checkout ============
# register the host repo (as repos.sh does after user confirmation)
bash "$WS/scripts/repos.sh" --add "$HOST" >/dev/null

OUT="$(bash "$PWS" --worktree "$L1" "$HOST" 2>&1)"
WTP="$HOST/worktrees/$L1/$(basename "$HOST")"
assert_output_contains "$OUT" "$WTP"
[ -d "$WTP" ] || fail "worktree dir missing"
[ "$(git -C "$WTP" branch --show-current)" = "$BR1" ] || fail "worktree branch is not $BR1"

# embedded-form guard: worktrees/ not gitignored in the host repo -> warning
OUT2="$(bash "$PWS" --worktree "$L2" "$HOST" 2>&1 || true)"
WTP2="$HOST/worktrees/$L2/$(basename "$HOST")"
assert_output_contains "$OUT2" "worktrees/$L2 is not ignored there"

# idempotent re-entry rebuilds nothing
OUT="$(bash "$PWS" --worktree "$L1" "$HOST")"
assert_output_contains "$OUT" "already exists"

# a plan absent from the collaboration table refuses
OUT2="$(bash "$PWS" --worktree 0003 "$HOST" 2>&1 || true)"
assert_output_contains "$OUT2" "plan not registered"

# kept-branch reuse: commit on the lane branch, remove the worktree, keep the
# branch, re-create on it — branch AND tip must survive (dissatisfaction tiers
# iterate on the SAME branch, never rebuilt)
printf 'lane work\n' > "$WTP/lane.txt"
git -C "$WTP" add lane.txt
git -C "$WTP" -c user.name=test -c user.email=test@test commit -qm "lane work" >/dev/null
TIP="$(git -C "$WTP" rev-parse HEAD)"
git -C "$HOST" worktree remove "$WTP"
OUT="$(bash "$PWS" --worktree "$L1" "$HOST")"
assert_output_contains "$OUT" "$WTP"
[ "$(git -C "$WTP" branch --show-current)" = "$BR1" ] || fail "kept branch not reused"
[ "$(git -C "$WTP" rev-parse HEAD)" = "$TIP" ] || fail "kept branch tip not preserved"

# a dangling repo path refuses up front (as_repo_canon would otherwise resolve
# it to the CONTAINING repo and lane the wrong repo with rc 0)
CODE=0; OUT2="$(bash "$PWS" --worktree "$L1" "$SB/no-such-repo" 2>&1)" || CODE=$?
[ "$CODE" -eq 3 ] || fail "dangling repo path must exit 3 (got $CODE): $OUT2"

# the AGENTSPACE ledger repo itself never gets a lane worktree
CODE=0; OUT2="$(bash "$PWS" --worktree "$L1" "$WS" 2>&1)" || CODE=$?
[ "$CODE" -eq 1 ] || fail "ledger repo must be refused (got $CODE): $OUT2"
assert_output_contains "$OUT2" "never gets lane worktrees"

# ============ 4. commit-check: lane worktree gated via its main registration ============
CC="$WS/scripts/commit-check.sh"
printf 'token line for the gate\n' > "$WTP/token.txt"
git -C "$WTP" add token.txt
CODE=0; OUT="$(bash "$CC" "$WTP" "self check token" 2>&1)" || CODE=$?
[ "$CODE" -eq 0 ] || fail "commit-check refused a registered repo's lane worktree (exit $CODE): $OUT"
assert_output_contains "$OUT" "gated as the same repo"

# an UNREGISTERED repo's worktree still refuses with exit 2
mkdir -p "$SB/other" && git -C "$SB/other" init -q -b main
printf 'x\n' > "$SB/other/a.txt" && git -C "$SB/other" add a.txt
git -C "$SB/other" -c user.name=test -c user.email=test@test commit -qm init >/dev/null
git -C "$SB/other" worktree add "$SB/other-wt" -b side >/dev/null 2>&1
printf 'token\n' > "$SB/other-wt/token.txt" && git -C "$SB/other-wt" add token.txt
CODE=0; OUT="$(bash "$CC" "$SB/other-wt" "self check token" 2>&1)" || CODE=$?
[ "$CODE" -eq 2 ] || fail "unregistered repo's worktree must exit 2 (got $CODE): $OUT"

# ============ 5. doctor [0]: dirty ledger names the active lanes ============
printf 'dirty probe\n' > "$WS/notes/dirty-probe.md"
OUT="$(bash "$DOC" 2>&1 || true)"
assert_output_contains "$OUT" "并行泳道活跃"
assert_output_contains "$OUT" "$L1:doing"
assert_output_contains "$OUT" "$L2:doing"

# removing one lane drops it from the attribution list (the other still shows)
bash "$PWS" --remove "$L2" >/dev/null
OUT="$(bash "$DOC" 2>&1 || true)"
assert_output_contains "$OUT" "并行泳道活跃"
assert_output_contains "$OUT" "$L1:doing"
assert_output_not_contains "$OUT" "$L2:doing"

# without active lanes the warning stays the plain milestone-commit reminder
bash "$PWS" --remove "$L1" >/dev/null
OUT="$(bash "$DOC" 2>&1 || true)"
assert_output_not_contains "$OUT" "并行泳道活跃"

# --remove cascades the removed plan's own rows too (self-echo fix keeps the
# cascade surface intact): broadcast (src L1) and direct note (dst L1) must go
[ "$(grep -c '^MSG|' "$WS/.agentspace-parallel-workspace.txt" 2>/dev/null || true)" = "0" ] \
  || fail "--remove cascade left MSG rows behind"

echo "PASS: t38"
