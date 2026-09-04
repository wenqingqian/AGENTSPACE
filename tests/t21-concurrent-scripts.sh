#!/usr/bin/env bash
# t21: concurrent script safety (agentspace-parallel F1) — N concurrent
# new-plan / new-iteration calls must allocate unique ids and lose no index
# rows (as_lock contract pinned by regression). Race outcome is scheduler-
# dependent, so the assertions are on the POSTCONDITIONS (uniqueness,
# completeness, doctor green), not on a particular serialization.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

SB="$(build_sandbox t21)"
WS="$SB/AGENTSPACE"

# --- 8 concurrent plan creations ---
for i in $(seq 1 8); do
  bash "$WS/scripts/new-plan.sh" "concurrent probe $i" >/dev/null 2>&1 &
done
wait

n_docs="$(ls "$WS/plan/todo/" | grep -c '^00[0-9][0-9]-.*\.md$')"
[ "$n_docs" -eq 8 ] || fail "expected 8 plan docs, got $n_docs"
n_todo="$(grep -cE '^\| 00[0-9]+ ' "$WS/plan.md")"
[ "$n_todo" -eq 8 ] || fail "expected 8 todo rows in plan.md, got $n_todo"
n_index="$(grep -cE '^\| 00[0-9]+ ' "$WS/plan/index.md")"
[ "$n_index" -eq 8 ] || fail "expected 8 index rows, got $n_index"
# ids unique and exactly 0001..0008
ls "$WS/plan/todo/" | sed 's/^\(00[0-9][0-9]\)-.*/\1/' | sort -u | paste -sd' ' - \
  | grep -Fxq "0001 0002 0003 0004 0005 0006 0007 0008" || fail "plan ids not unique/complete: $(ls "$WS/plan/todo/")"

# --- 6 concurrent iterations on plan 0001 ---
for i in $(seq 1 6); do
  bash "$WS/scripts/new-iteration.sh" 1 "lane probe $i" >/dev/null 2>&1 &
done
wait

n_iters="$(ls -d "$WS/iterations/iteration_"00?? 2>/dev/null | wc -l | tr -d ' ')"
[ "$n_iters" -eq 6 ] || fail "expected 6 iteration dirs, got $n_iters"
n_prog="$(grep -cE '^\| 00[0-9]+ ' "$WS/iterations.md")"
[ "$n_prog" -eq 6 ] || fail "expected 6 in-progress rows, got $n_prog"
n_iindex="$(grep -cE '^\| 00[0-9]+ ' "$WS/iterations/index.md")"
[ "$n_iindex" -eq 6 ] || fail "expected 6 iteration index rows, got $n_iindex"
# latest symlink must resolve into a real iteration dir
[ -d "$WS/iterations/latest" ] || fail "latest symlink broken after concurrent creation"

# --- structural integrity after the storm: the ONLY allowed doctor issues are
# the untouched-readme placeholder notes ([3] resume block) — one per storm-
# created iteration. Anything else (lost rows, dupes, broken links) fails. ---
git -C "$WS" add -A >/dev/null 2>&1
git -C "$WS" commit -qm "test: t21 concurrency storm" >/dev/null 2>&1
OUT="$(bash "$WS/scripts/doctor.sh" || true)"
printf '%s\n' "$OUT" | grep -q "== Done:" || fail "doctor did not run to completion: $OUT"
n_issues="$(printf '%s\n' "$OUT" | grep -c '\[issue\]')"
[ "$n_issues" -eq 6 ] || fail "expected only the 6 untouched-readme placeholder notes, got $n_issues: $OUT"
printf '%s\n' "$OUT" | grep '\[issue\]' | grep -vF "not updated (resume placeholder" \
  && fail "unexpected structural issue after the storm" || true

echo "t21 PASS: concurrent new-plan/new-iteration — unique ids, zero lost rows"
