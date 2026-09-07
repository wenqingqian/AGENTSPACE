#!/usr/bin/env bash
# t25: parallel × other-components integration — the agentspace-parallel lane
# form composed with the rest of the workspace, all in one live scenario:
#   · crossing repo sets: plan one lanes repoA+repoB, plan two lanes repoB+repoC
#     (repoB hosts two lanes of the same repo — legal per §2)
#   · ledger lifecycle mid-parallelism: plans/iterations created while lanes active
#   · handoff produce/list/consume with lanes active, incl. a CONCURRENT produce
#     pair (handoff.sh self-lock must keep the index intact)
#   · ledger lock dir + owner file (constructed literal id) — embedded-form
#     gitignore iron rule: the host repo must stay blind to locks and lanes
#   · multi-repo CAS sequencing: repoB mainline moves between the two plans, so
#     plan two's recheck fails → absorb (disjoint files, no conflict) → squash
#   · status: lanes collapse into main rows while pending handoffs stay listed
#   · doctor green mid-flow (resume sections filled) and fully green after cleanup
# All ids/names CONSTRUCTED at runtime (selfhost literal discipline).
set -euo pipefail
. "$(dirname "$0")/lib.sh"

SB="$(build_sandbox t25)"; SB="$(cd -P "$SB" && pwd -P)"   # canonicalize (macOS /tmp symlink, t22 lesson)
WS="$SB/AGENTSPACE"
cd "$SB"
mc() { git -C "$WS" add -A >/dev/null 2>&1; git -C "$WS" commit -qm "test: t25 milestone" >/dev/null 2>&1 || true; }
SEQ=0
# monotonic commit dates: identical tree+message+parent inside one second would
# collide into the same sha, making a squashed lane tip "merged" for branch -d
gc() { SEQ=$((SEQ+1)); GIT_AUTHOR_DATE="@$SEQ +0000" GIT_COMMITTER_DATE="@$SEQ +0000" \
  git -c user.name=test -c user.email=test@test -C "$1" "${@:2}"; }
P1="$(printf '%04d' 1)"; P2="$(printf '%04d' 2)"
BR1="$(printf 'plan-%04d' 1)"; BR2="$(printf 'plan-%04d' 2)"
IT1="iteration_$(printf '%04d' 1)"; IT2="iteration_$(printf '%04d' 2)"
HN1="$(printf 'lane-%04d-wrap' 1)"; HN2="$(printf 'lane-%04d-wrap' 2)"; HN3="$(printf 'lane-%04d-mid' 2)"

# --- three external repos; crossing plan sets will share repoB ---
for r in repoA repoB repoC; do
  git init -q -b main "$SB/$r"
  printf 'base %s\n' "$r" > "$SB/$r/base.txt"
  gc "$SB/$r" add -A >/dev/null; gc "$SB/$r" commit -qm "chore: init $r" >/dev/null
  bash "$WS/scripts/repos.sh" --add "$r" >/dev/null
done
bash "$WS/scripts/repos.sh" --add . >/dev/null
BASEA="$(git -C "$SB/repoA" rev-parse main)"; BASEB="$(git -C "$SB/repoB" rev-parse main)"; BASEC="$(git -C "$SB/repoC" rev-parse main)"
# embedded-form iron rule: lanes/locks/external repos invisible to the host repo
printf '/AGENTSPACE/\n/worktrees/\n/.locks/\n/repoA/\n/repoB/\n/repoC/\n' > "$SB/.gitignore"
gc "$SB" add .gitignore >/dev/null; gc "$SB" commit -qm "ignore lanes, locks and external repos"

# --- ledger lifecycle while lanes exist: plans + iterations ---
bash "$WS/scripts/new-plan.sh" "cross a" >/dev/null
bash "$WS/scripts/new-plan.sh" "cross b" >/dev/null
bash "$WS/scripts/new-iteration.sh" "$P1" "lane work a" >/dev/null
bash "$WS/scripts/new-iteration.sh" "$P2" "lane work b" >/dev/null
# fill resume sections so mid-flow doctor is truly green (not placeholder-tolerant)
python3 - "$WS" "$IT1" "$IT2" <<'EOF'
import re, sys
ws, it1, it2 = sys.argv[1], sys.argv[2], sys.argv[3]
for it in (it1, it2):
    p = f"{ws}/iterations/{it}/readme.md"
    t = open(p).read()
    t = re.sub(r"<!-- 会话续接块:.*?-->", "干到哪: 泳道实施中; 下一步: 验收后 CAS 合回。", t, flags=re.S)
    open(p, "w").write(t)
EOF
mc

# --- lanes: plan one → repoA+repoB, plan two → repoB+repoC ---
gc "$SB/repoA" worktree add "$SB/worktrees/$P1/repoA" -b "$BR1" main >/dev/null
gc "$SB/repoB" worktree add "$SB/worktrees/$P1/repoB" -b "$BR1" main >/dev/null
gc "$SB/repoB" worktree add "$SB/worktrees/$P2/repoB" -b "$BR2" main >/dev/null
gc "$SB/repoC" worktree add "$SB/worktrees/$P2/repoC" -b "$BR2" main >/dev/null
for w in "$P1/repoA" "$P1/repoB" "$P2/repoB" "$P2/repoC"; do
  bash "$WS/scripts/repos.sh" --add "worktrees/$w" >/dev/null
done
# dev commits per lane, each through the gate (registration recognized per lane)
echo "a1 = 1" > "$SB/worktrees/$P1/repoA/a1.txt"
gc "$SB/worktrees/$P1/repoA" add -A >/dev/null
bash "$WS/scripts/commit-check.sh" "$SB/worktrees/$P1/repoA" "feat: plan-one repoA module" >/dev/null || fail "gate must pass in lane repoA"
gc "$SB/worktrees/$P1/repoA" commit -qm "feat: plan-one repoA module"
echo "b1 = 1" > "$SB/worktrees/$P1/repoB/b1.txt"
gc "$SB/worktrees/$P1/repoB" add -A >/dev/null
bash "$WS/scripts/commit-check.sh" "$SB/worktrees/$P1/repoB" "feat: plan-one repoB module" >/dev/null || fail "gate must pass in lane repoB"
gc "$SB/worktrees/$P1/repoB" commit -qm "feat: plan-one repoB module"
echo "b2 = 2" > "$SB/worktrees/$P2/repoB/b2.txt"
gc "$SB/worktrees/$P2/repoB" add -A >/dev/null
gc "$SB/worktrees/$P2/repoB" commit -qm "feat: plan-two repoB module"
echo "c2 = 2" > "$SB/worktrees/$P2/repoC/c2.txt"
gc "$SB/worktrees/$P2/repoC" add -A >/dev/null
gc "$SB/worktrees/$P2/repoC" commit -qm "feat: plan-two repoC module"

# --- handoffs while lanes are active: produce ×3 (one concurrent pair), list, consume ---
bash "$WS/scripts/handoff.sh" --produce --name "$HN1" --description "lane one session wrap" >/dev/null
bash "$WS/scripts/handoff.sh" --produce --name "$HN2" >/dev/null &
bash "$WS/scripts/handoff.sh" --produce --name "$HN3" >/dev/null &
wait
OUT="$(bash "$WS/scripts/handoff.sh" --list)"
assert_output_contains "$OUT" "$HN1"; assert_output_contains "$OUT" "$HN2"; assert_output_contains "$OUT" "$HN3"
[ "$(grep -c '| handoff_' "$WS/handoff/index.md")" -eq 3 ] || fail "concurrent produce corrupted the index"
bash "$WS/scripts/handoff.sh" --consume --name "$HN2" >/dev/null
[ ! -f "$WS/handoff/handoff_$HN2.md" ] || fail "consumed handoff file must be gone"
assert_not_contains "$WS/handoff/index.md" "$HN2"

# --- ledger lock + owner file (constructed literal id): host must stay blind ---
mkdir -p "$SB/.locks"
mkdir "$SB/.locks/ledger" || fail "ledger lock should be free"
printf 'plan:%04d iteration:%04d testhost pid:%s %s lane ledger write\n' 1 1 "$$" "$(date -u +%FT%TZ)" > "$SB/.locks/ledger/owner"
[ -z "$(git -C "$SB" status --porcelain)" ] || fail "host repo sees locks/lanes/repos — embedded-form gitignore iron rule broken"

# --- plan one CAS squash across repoA+repoB (one lock window, per repo) ---
mkdir "$SB/.locks/mainline" || fail "mainline lock should be free"
[ "$(git -C "$SB/repoA" rev-parse main)" = "$BASEA" ] || fail "CAS recheck repoA: main moved"
gc "$SB/repoA" merge --squash "$BR1" >/dev/null
bash "$WS/scripts/commit-check.sh" "$SB/repoA" "feat: plan-one repoA module" >/dev/null || fail "gate must pass repoA squash"
gc "$SB/repoA" commit -qm "feat: plan-one repoA module"
[ -z "$(git -C "$SB/repoA" diff "$BR1" main)" ] || fail "diff-empty proof failed: repoA"
[ "$(git -C "$SB/repoB" rev-parse main)" = "$BASEB" ] || fail "CAS recheck repoB: main moved"
gc "$SB/repoB" merge --squash "$BR1" >/dev/null
bash "$WS/scripts/commit-check.sh" "$SB/repoB" "feat: plan-one repoB module" >/dev/null || fail "gate must pass repoB squash"
gc "$SB/repoB" commit -qm "feat: plan-one repoB module"
[ -z "$(git -C "$SB/repoB" diff "$BR1" main)" ] || fail "diff-empty proof failed: repoB (plan one)"
rmdir "$SB/.locks/mainline"

# --- plan two: repoB mainline moved (plan one's squash) → recheck fails → absorb → squash ---
mkdir "$SB/.locks/mainline" || fail "mainline lock should be free (plan two)"
[ "$(git -C "$SB/repoC" rev-parse main)" = "$BASEC" ] || fail "CAS recheck repoC: main moved"
gc "$SB/repoC" merge --squash "$BR2" >/dev/null
gc "$SB/repoC" commit -qm "feat: plan-two repoC module"
[ -z "$(git -C "$SB/repoC" diff "$BR2" main)" ] || fail "diff-empty proof failed: repoC"
rmdir "$SB/.locks/mainline"
[ "$(git -C "$SB/repoB" rev-parse main)" != "$BASEB" ] || fail "repoB CAS recheck should have detected plan one's squash"
gc "$SB/worktrees/$P2/repoB" merge main -m "merge: absorb mainline $(git -C "$SB/repoB" rev-parse --short main) after plan-one squash" >/dev/null \
  || fail "absorb in repoB lane failed (disjoint files, should be clean)"
mkdir "$SB/.locks/mainline" || fail "mainline lock should be free (plan two retry)"
ABSORBED_B="$(git -C "$SB/repoB" rev-parse main)"
gc "$SB/repoB" merge --squash "$BR2" >/dev/null
bash "$WS/scripts/commit-check.sh" "$SB/repoB" "feat: plan-two repoB module" >/dev/null || fail "gate must pass repoB plan-two squash"
gc "$SB/repoB" commit -qm "feat: plan-two repoB module"
[ -z "$(git -C "$SB/repoB" diff "$BR2" main)" ] || fail "diff-empty proof failed: repoB (plan two)"
rmdir "$SB/.locks/mainline"

# --- mainline shapes: squashes only, PR-name titles, zero merge commits ---
[ "$(git -C "$SB/repoB" rev-list --count "$BASEB..main")" -eq 2 ] || fail "repoB main must carry exactly 2 squash commits"
[ "$(git -C "$SB/repoB" rev-list --count --merges "$BASEB..main")" -eq 0 ] || fail "repoB main must have zero merge commits (absorb stays on the lane)"
git -C "$SB/repoB" log --first-parent --format=%s "$BASEB..main" | grep -Fxq "feat: plan-one repoB module" || fail "repoB missing plan-one PR title"
git -C "$SB/repoB" log --first-parent --format=%s "$BASEB..main" | grep -Fxq "feat: plan-two repoB module" || fail "repoB missing plan-two PR title"
[ -f "$SB/repoB/b1.txt" ] && [ -f "$SB/repoB/b2.txt" ] || fail "repoB main must carry both plans' content"

# --- status: lanes collapse into main rows; pending handoffs listed ---
mc
OUT="$(bash "$WS/scripts/status.sh")"
ROWB="$(printf '%s\n' "$OUT" | grep '^- repoB ' || true)"
[ -n "$ROWB" ] || fail "repoB main row missing from status"
printf '%s' "$ROWB" | grep -q "泳道: $BR1@" || fail "repoB row missing plan-one lane annotation"
printf '%s' "$ROWB" | grep -q "$BR2@" || fail "repoB row missing plan-two lane annotation"
[ "$(printf '%s\n' "$OUT" | grep -cE '^- [^(]*\([^)]*worktrees/')" -eq 0 ] || fail "collapsed lanes must not keep own table rows"
assert_output_contains "$OUT" "$HN1"
assert_output_contains "$OUT" "$HN3"

# --- doctor mid-flow: truly green (lanes registered, handoffs consistent, [15] armed but clean) ---
OUT="$(bash "$WS/scripts/doctor.sh")" || fail "doctor must be green mid-flow: $OUT"
assert_output_not_contains "$OUT" "worktree 未登记"
assert_output_not_contains "$OUT" "连字符形"
assert_output_not_contains "$OUT" "主线窗口含 merge commit"

# --- cleanup: worktrees, registry rows, branches (-D; squash never ancestors), handoffs, lock, iterations ---
for w in "$P1/repoA" "$P1/repoB" "$P2/repoB" "$P2/repoC"; do
  gc "$SB/${w##*/}" worktree remove "$SB/worktrees/$w" >/dev/null
  bash "$WS/scripts/repos.sh" --remove "worktrees/$w" >/dev/null
done
gc "$SB/repoA" branch -D "$BR1" >/dev/null || fail "branch -D repoA"
gc "$SB/repoB" branch -D "$BR1" >/dev/null || fail "branch -D repoB plan-one"
gc "$SB/repoB" branch -D "$BR2" >/dev/null || fail "branch -D repoB plan-two"
gc "$SB/repoC" branch -D "$BR2" >/dev/null || fail "branch -D repoC"
bash "$WS/scripts/handoff.sh" --consume --name "$HN1" >/dev/null
bash "$WS/scripts/handoff.sh" --consume --name "$HN3" >/dev/null
rm "$SB/.locks/ledger/owner"; rmdir "$SB/.locks/ledger"
# close-iteration refuses while the 结果 placeholder is still present — fill first
python3 - "$WS" "$IT1" "$IT2" <<'EOF'
import sys
ws, it1, it2 = sys.argv[1], sys.argv[2], sys.argv[3]
for it, res in ((it1, "两仓库 CAS 合回; 泳道期 handoff 并发/锁目录/状态渲染全绿"),
                (it2, "交叉组吸收后 CAS 合回; repoB 双泳道注解与去重正确")):
    p = f"{ws}/iterations/{it}/readme.md"
    t = open(p).read()
    t = t.replace("<!-- 指标 / 结论; 关闭 iteration 前必填 -->", res)
    open(p, "w").write(t)
EOF
bash "$WS/scripts/close-iteration.sh" "$P1" "cross a done: two-repo CAS, handoffs clean" >/dev/null
bash "$WS/scripts/close-iteration.sh" "$P2" "cross b done: absorb after crossing squash, then CAS" >/dev/null
mc
OUT="$(bash "$WS/scripts/doctor.sh")" || fail "post-cleanup doctor must be fully green: $OUT"
[ -z "$(git -C "$SB" status --porcelain)" ] || fail "host repo dirty at the end"

echo "t25 PASS: crossing repo sets + handoffs mid-lanes + lock-dir iron rule + multi-repo CAS sequencing + status/doctor composition"
