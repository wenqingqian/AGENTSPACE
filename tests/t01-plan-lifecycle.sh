#!/usr/bin/env bash
# t01: plan lifecycle — new-plan creates row+doc+index entry; complete-plan
# refuses while the 结果 placeholder is present, then moves todo→done.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

SB="$(build_sandbox t01)"
WS="$SB/AGENTSPACE"

OUT="$(bash "$WS/scripts/new-plan.sh" "Test Plan Alpha")"
ID="$(printf '%s' "$OUT" | grep -o 'plan:[0-9]*' | cut -d: -f2)"
[ -n "$ID" ] || fail "no plan id in new-plan output: $OUT"

# row in plan.md Todo + index, doc created
assert_contains "$WS/plan.md" "$ID"
assert_contains "$WS/plan/index.md" "| $ID |"
DOC="$(ls "$WS"/plan/todo/"$ID"*.md)"
[ -f "$DOC" ] || fail "plan doc not created: $DOC"

# gate: complete refused while the result placeholder is still in the doc
assert_fails bash "$WS/scripts/complete-plan.sh" "$ID" done "done"

# agent fills the 结果 section (content docs are agent-written)
python3 - "$DOC" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read()
s = s.replace("<!-- 完成时填写: 一句话结论", "一句话结论: test done")
open(p, "w").write(s)
EOF

assert_ok bash "$WS/scripts/complete-plan.sh" "$ID" done "test done"
assert_contains "$WS/plan.md" "| $ID |"       # now in Done table
[ -f "$WS/plan/done/$(basename "$DOC")" ] || fail "plan doc not moved to plan/done/"
[ ! -f "$DOC" ] || fail "plan doc still in plan/todo/"
assert_contains "$WS/plan/done/$(basename "$DOC")" "> 状态: 完成"

# truncation boundary: 12 more plans completed → Done table keeps the NEWEST 10
i=1
while [ "$i" -le 12 ]; do
  OUT="$(bash "$WS/scripts/new-plan.sh" "Trunc Plan $i")"
  TID="$(printf '%s' "$OUT" | grep -o 'plan:[0-9]*' | cut -d: -f2)"
  TDOC="$(ls "$WS"/plan/todo/"$TID"*.md)"
  python3 - "$TDOC" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read()
s = s.replace("<!-- 完成时填写: 一句话结论", "一句话结论: trunc")
open(p, "w").write(s)
EOF
  assert_ok bash "$WS/scripts/complete-plan.sh" "$TID" done "trunc"
  i=$((i+1))
done
# Done table: at most 10 rows; newest (12th) still listed; the first completed
# plan's doc survives on disk (truncation trims the table, not plan/done/)
DONE_ROWS="$(awk -v sec="## Done (最近 10 条)" '
  $0 == sec { f=1; next }
  /^## / { f=0 }
  f && /^\| [0-9]/ { n++ }
  END { print n+0 }
' "$WS/plan.md")"
[ "$DONE_ROWS" -le 10 ] || fail "Done table has $DONE_ROWS rows (> 10)"
assert_contains "$WS/plan.md" "| $TID |"
[ -f "$WS/plan/done/$(basename "$DOC")" ] || fail "first completed plan doc gone"

# workspace still consistent after the lifecycle (milestone commit first —
# wrap-up protocol: doctor-green implies just-committed)
git -C "$WS" add -A >/dev/null 2>&1
git -C "$WS" commit -qm "test: plan lifecycle milestone" >/dev/null 2>&1
assert_ok bash "$WS/scripts/doctor.sh"

rm -rf "$SB"
echo "PASS t01"
