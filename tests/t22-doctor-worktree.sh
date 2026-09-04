#!/usr/bin/env bash
# t22: worktree awareness (agentspace-parallel F2) — doctor [14]'s
# conventional-lane scan (worktrees/<plan>/<repo> MUST be registered,
# _anchor-* carve-out) and status.sh lane dedupe (a linked-worktree checkout
# collapses into its main checkout's row/block).
# Lane branch names are CONSTRUCTED at runtime (selfhost literal discipline).
set -euo pipefail
. "$(dirname "$0")/lib.sh"

SB="$(build_sandbox t22)"
SB="$(cd -P "$SB" && pwd -P)"   # physical path: /tmp symlinks to /private/tmp on macOS — path assertions compare canonical
WS="$SB/AGENTSPACE"
cd "$SB"
mc() { git -C "$WS" add -A >/dev/null 2>&1; git -C "$WS" commit -qm "test: t22 milestone" >/dev/null 2>&1 || true; }

BR1="$(printf 'plan-%04d' 1)"
BR2="$(printf 'plan-%04d' 2)"

# --- 0) baseline: register host, doctor green ---
bash "$WS/scripts/repos.sh" --add . >/dev/null
mc
OUT="$(bash "$WS/scripts/doctor.sh")" || fail "baseline doctor must be green: $OUT"

# --- 1) unregistered lane at the conventional location → [14] warns ---
# Embedded form per the skill's iron rule: worktrees/ gitignored in the host.
printf '/AGENTSPACE/\n/worktrees/\n' > "$SB/.gitignore"
git -C "$SB" add .gitignore >/dev/null 2>&1
git -C "$SB" -c user.name=test -c user.email=test@test commit -qm "ignore worktrees" >/dev/null 2>&1
git -C "$SB" worktree add "$SB/worktrees/0001/host" -b "$BR1" main >/dev/null 2>&1 \
  || fail "worktree add failed"
OUT="$(bash "$WS/scripts/doctor.sh" || true)"
assert_output_contains "$OUT" "worktree 未登记"
assert_output_contains "$OUT" "worktrees/0001/host"

# --- 2) registered lane → warning gone; status collapses the lane ---
bash "$WS/scripts/repos.sh" --add worktrees/0001/host >/dev/null
mc
OUT="$(bash "$WS/scripts/doctor.sh" || true)"
assert_output_not_contains "$OUT" "worktree 未登记"
OUT="$(bash "$WS/scripts/status.sh" 9.9.9)"
assert_output_contains "$OUT" "泳道: $BR1@worktrees/0001/host"
# the lane must NOT get its own row (table) or block (recent commits)
printf '%s\n' "$OUT" | grep -F -- "- host ($SB/worktrees/0001/host)" \
  && fail "lane got its own 关键代码仓库 row" || true
printf '%s\n' "$OUT" | grep -F -- "#### host ($SB/worktrees/0001/host)" \
  && fail "lane got its own 代码提交 block" || true

# --- 3) anchor worktree carve-out: _anchor-* is NOT a registration target ---
git -C "$SB" worktree add --detach "$SB/worktrees/_anchor-x/host" HEAD >/dev/null 2>&1 \
  || fail "anchor worktree add failed"
OUT="$(bash "$WS/scripts/doctor.sh" || true)"
assert_output_not_contains "$OUT" "_anchor-x"

# --- 4) lane whose MAIN checkout is unregistered keeps its own status row ---
bash "$WS/scripts/repos.sh" --remove . >/dev/null   # registry: {lane} only
mc
OUT="$(bash "$WS/scripts/status.sh" 9.9.9)"
assert_output_contains "$OUT" "泳道检出 — 其主检出未登记"
printf '%s\n' "$OUT" | grep -F -- "- host ($SB/worktrees/0001/host)" >/dev/null \
  || fail "unregistered-main lane lost its own row"
# restore: host re-registered, lane collapses again
bash "$WS/scripts/repos.sh" --add . >/dev/null
mc
OUT="$(bash "$WS/scripts/status.sh" 9.9.9)"
assert_output_contains "$OUT" "泳道: $BR1@worktrees/0001/host"

# --- 5) cleanup: remove worktrees, deregister lane, doctor green ---
git -C "$SB" worktree remove "$SB/worktrees/_anchor-x/host" >/dev/null 2>&1
git -C "$SB" worktree remove "$SB/worktrees/0001/host" >/dev/null 2>&1
git -C "$SB" branch -D "$BR1" >/dev/null 2>&1 || true
bash "$WS/scripts/repos.sh" --remove worktrees/0001/host >/dev/null
mc
OUT="$(bash "$WS/scripts/doctor.sh")" || fail "post-cleanup doctor must be green: $OUT"
OUT="$(bash "$WS/scripts/status.sh" 9.9.9)"
assert_output_not_contains "$OUT" "泳道"

echo "t22 PASS: doctor [14] lane scan + status worktree dedupe + anchor carve-out"
