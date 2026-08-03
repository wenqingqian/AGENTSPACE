#!/usr/bin/env bash
# t02: iteration lifecycle — new-iteration (plan-required, readme+data+latest
# symlink, host start commit, plan 相关迭代 entry); close-iteration refuses
# while the 结果 placeholder is present, then records the host end commit BELOW
# the start commit and freezes the readme.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

SB="$(build_sandbox t02)"
WS="$SB/AGENTSPACE"

OUT="$(bash "$WS/scripts/new-plan.sh" "Iteration Host Plan")"
PID="$(printf '%s' "$OUT" | grep -o 'plan:[0-9]*' | cut -d: -f2)"
[ -n "$PID" ] || fail "no plan id: $OUT"

# iteration requires an existing plan
assert_fails bash "$WS/scripts/new-iteration.sh" 9999 "orphan iteration"

OUT2="$(bash "$WS/scripts/new-iteration.sh" "$PID" "feature step 1")"
IID="$(printf '%s' "$OUT2" | grep -o 'iteration_[0-9]*' | head -1 | cut -d_ -f2)"
[ -n "$IID" ] || fail "no iteration id: $OUT2"

README="$WS/iterations/iteration_$IID/readme.md"
[ -f "$README" ] || fail "readme not created"
[ -d "$WS/iterations/iteration_$IID/data" ] || fail "data/ dir not created"
[ -L "$WS/iterations/latest" ] || fail "latest symlink not created"
assert_contains "$WS/iterations.md" "$IID"
assert_contains "$WS/iterations/index.md" "| $IID |"
assert_contains "$README" "> 宿主起始 commit: "   # host is a git repo
PLAN_DOC="$(ls "$WS"/plan/todo/"$PID"*.md)"
assert_contains "$PLAN_DOC" "iteration_$IID"        # 相关迭代 entry appended

# gate: close refused while the 结果 placeholder is present
assert_fails bash "$WS/scripts/close-iteration.sh" "$IID" "result"

# agent fills 结果 + resume block, then closes
python3 - "$README" <<'EOF'
import re, sys
p = sys.argv[1]
s = open(p).read()
s = s.replace("<!-- 指标 / 结论; 关闭 iteration 前必填 -->", "结论: step 1 works")
s = re.sub(r"<!-- 会话续接块:.*?-->", "当前状态: 已关闭; 下一步: 无", s, flags=re.S)
open(p, "w").write(s)
EOF

assert_ok bash "$WS/scripts/close-iteration.sh" "$IID" "step 1 works"
assert_contains "$WS/iterations.md" "$IID"          # now in 最近完成
assert_contains "$README" "> 状态: 已完成"
assert_contains "$README" "> 宿主结束 commit: "

# F4 ordering: end commit must sit BELOW the start commit
START_LN="$(grep -n '宿主起始 commit' "$README" | cut -d: -f1)"
END_LN="$(grep -n '宿主结束 commit' "$README" | cut -d: -f1)"
[ -n "$START_LN" ] && [ -n "$END_LN" ] || fail "host commit lines missing"
[ "$START_LN" -lt "$END_LN" ] || fail "end commit above start commit (F4 regression)"

# closing twice must fail (status no longer 进行中)
assert_fails bash "$WS/scripts/close-iteration.sh" "$IID" "again"

git -C "$WS" add -A >/dev/null 2>&1
git -C "$WS" commit -qm "test: iteration lifecycle milestone" >/dev/null 2>&1
assert_ok bash "$WS/scripts/doctor.sh"

rm -rf "$SB"
echo "PASS t02"
