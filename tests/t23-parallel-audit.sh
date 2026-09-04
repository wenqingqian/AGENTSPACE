#!/usr/bin/env bash
# t23: doctor [15] parallel audit (agentspace-parallel F7) — mainline
# merge-commit detection + dash-form lane-id message detection, armed ONLY by
# parallel-flow evidence (plan-* branches / linked worktree); absorb merges on
# lane branches are legal and must stay silent. All ids CONSTRUCTED at runtime
# (selfhost literal discipline).
set -euo pipefail
. "$(dirname "$0")/lib.sh"

SB="$(build_sandbox t23)"
WS="$SB/AGENTSPACE"
cd "$SB"
mc() { git -C "$WS" add -A >/dev/null 2>&1; git -C "$WS" commit -qm "test: t23 milestone" >/dev/null 2>&1 || true; }
hc() { git -C "$SB" -c user.name=test -c user.email=test@test commit -q "$@" >/dev/null 2>&1; }

BR7="$(printf 'plan-%04d' 7)"
DASHID="$(printf 'plan-%04d' 25)"

bash "$WS/scripts/repos.sh" --add . >/dev/null
printf '/AGENTSPACE/\n/worktrees/\n' > "$SB/.gitignore"
git -C "$SB" add .gitignore >/dev/null 2>&1 && hc -m "ignore worktrees"
mc

# --- 1) NO parallel evidence: merge commit + dash-form message stay silent ---
git -C "$SB" checkout -q -b feature-x
echo fx > "$SB/fx.txt" && git -C "$SB" add fx.txt && hc -m "feat: feature x"
git -C "$SB" checkout -q main
git -C "$SB" -c user.name=test -c user.email=test@test merge --no-ff feature-x -m "Merge branch 'feature-x'" >/dev/null 2>&1
MERGESHA="$(git -C "$SB" rev-parse --short HEAD)"
hc --allow-empty -m "merge main into $DASHID after absorb"   # dash-form lane id in text
DASHSHA="$(git -C "$SB" rev-parse --short HEAD)"
OUT="$(bash "$WS/scripts/doctor.sh")" || fail "no-evidence doctor must be green (conventional merge workflow stays silent): $OUT"
assert_output_not_contains "$OUT" "主线窗口含 merge commit"
assert_output_not_contains "$OUT" "连字符形"

# --- 2) arm with a plan branch → both audits fire on the mainline window ---
git -C "$SB" branch "$BR7"
OUT="$(bash "$WS/scripts/doctor.sh" || true)"
assert_output_contains "$OUT" "@$MERGESHA: 主线窗口含 merge commit"
assert_output_contains "$OUT" "@$DASHSHA: commit message 含连字符形泳道标识"

# --- 3) lane absorb merge is LEGAL: merge check fires only on main worktree ---
git -C "$SB" worktree add "$SB/worktrees/0007/host" "$BR7" >/dev/null 2>&1 || fail "lane worktree add failed"
bash "$WS/scripts/repos.sh" --add worktrees/0007/host >/dev/null
echo adv > "$SB/adv.txt" && git -C "$SB" add adv.txt && hc -m "feat: mainline advanced"
ADVSHA="$(git -C "$SB" rev-parse --short HEAD)"
git -C "$SB/worktrees/0007/host" -c user.name=test -c user.email=test@test \
  merge main -m "merge: absorb mainline $ADVSHA — one clean line" >/dev/null 2>&1 \
  || fail "lane absorb merge failed"
ABSHA="$(git -C "$SB/worktrees/0007/host" rev-parse --short HEAD)"
mc
OUT="$(bash "$WS/scripts/doctor.sh" || true)"
# the lane's absorb merge must NOT be flagged as a mainline merge commit
printf '%s\n' "$OUT" | grep -F -- "@$ABSHA: 主线窗口含 merge commit" \
  && fail "lane absorb merge wrongly flagged as mainline merge commit" || true
# the old pollution is reported exactly once (main worktree row), not per lane
n_merge="$(printf '%s\n' "$OUT" | grep -c "主线窗口含 merge commit")"
[ "$n_merge" -eq 1 ] || fail "expected exactly 1 mainline-merge report, got $n_merge"
# dash-form message check DOES apply on lane scans too (main's dash commit is
# in lane ancestry) — at least one report, keyed by sha
assert_output_contains "$OUT" "@$DASHSHA: commit message 含连字符形泳道标识"

# --- 4) disarm: branches deleted + lane removed → parallel audits silent again ---
git -C "$SB" worktree remove "$SB/worktrees/0007/host" >/dev/null 2>&1
git -C "$SB" branch -D "$BR7" >/dev/null 2>&1
bash "$WS/scripts/repos.sh" --remove worktrees/0007/host >/dev/null
mc
OUT="$(bash "$WS/scripts/doctor.sh")" || fail "disarmed doctor must be green again: $OUT"
assert_output_not_contains "$OUT" "主线窗口含 merge commit"
assert_output_not_contains "$OUT" "连字符形"

echo "t23 PASS: doctor [15] parallel audit — merge-commit + dash-id, evidence-armed, lane-legal"
