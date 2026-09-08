#!/usr/bin/env bash
# t33: exp lifecycle — new-exp (manual + exp_data + exp_spec pre-creation, plan/
# iteration co-links with backlink into the readme, slug contract), start-exp
# (todo→doing row move + link rewrite), complete-exp gates (results placeholder,
# empty exp_spec refusal) and the closing snapshot (commits cell, configs cell,
# status rewrite). Ids are computed at runtime — never hardcode realized ids.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

SB="$(build_sandbox t33)"
WS="$SB/AGENTSPACE"

OUT="$(bash "$WS/scripts/new-plan.sh" "exp host plan")"
PID="$(printf '%s' "$OUT" | grep -o 'plan:[0-9]*' | cut -d: -f2)"
OUT2="$(bash "$WS/scripts/new-iteration.sh" "$PID" "feature step")"
IID="$(printf '%s' "$OUT2" | grep -o 'iteration_[0-9]*' | head -1 | cut -d_ -f2)"
# fill the resume block (doctor [3] flags the placeholder while in progress)
python3 - "$WS/iterations/iteration_$IID/readme.md" <<'EOF'
import re, sys
p = sys.argv[1]
s = open(p).read()
s = re.sub(r"<!-- 会话续接块:.*?-->", "当前状态: exp 登记与关闭演练; 下一步: 无", s, flags=re.S)
open(p, "w").write(s)
EOF

# slug contract: CJK/punctuation titles refused before any write (no id burn)
BEFORE="$(grep -c '^| ' "$WS/exp/index.md" || true)"
assert_fails bash "$WS/scripts/new-exp.sh" "延迟 实验!"
AFTER="$(grep -c '^| ' "$WS/exp/index.md" || true)"
[ "$BEFORE" = "$AFTER" ] || fail "refused title burned an index row"

# --plan validation: unknown plan refused
assert_fails bash "$WS/scripts/new-exp.sh" "bad link exp" --plan 9999

OUT3="$(bash "$WS/scripts/new-exp.sh" "latency measurement" --plan "$PID" --iteration "$IID")"
XID="$(printf '%s' "$OUT3" | grep -o 'exp_[0-9]*' | head -1 | cut -d_ -f2)"
[ -n "$XID" ] || fail "no exp id: $OUT3"
XD="exp_$XID"

# created: manual in todo/, exp_data + exp_spec dirs, tables
MANUAL="$(ls "$WS"/exp/todo/"$XD"-*.md)"
[ -f "$MANUAL" ] || fail "manual not created"
[ -d "$WS/exp/exp_data/$XD" ] || fail "exp_data dir not pre-created"
[ -d "$WS/examples/exp_spec/$XD" ] || fail "exp_spec dir not pre-created"
[ -f "$WS/examples/exp_spec/$XD/.gitkeep" ] || fail "exp_spec .gitkeep missing"
assert_contains "$WS/exp.md" "| $XID |"
assert_contains "$WS/exp/index.md" "| $XID | latency measurement | todo | plan:$PID | iteration_$IID |"
# backlink: id reference (not a path link — the manual moves later) in the readme
assert_contains "$WS/iterations/iteration_$IID/readme.md" "## 相关实验"
assert_contains "$WS/iterations/iteration_$IID/readme.md" "- $XD — latency measurement"

# start: todo→doing (row section + link path + status line)
START_OUT="$(bash "$WS/scripts/start-exp.sh" "$XID")" || fail "start failed"
DOING_MANUAL="$(ls "$WS"/exp/doing/"$XD"-*.md)"
[ -f "$DOING_MANUAL" ] || fail "manual not moved to doing/"
grep -q "^## Doing" "$WS/exp.md" || fail "Doing section missing"
assert_contains "$WS/exp.md" "exp/doing/$XD-"
assert_contains "$WS/exp/index.md" "| $XID | latency measurement | doing |"
assert_contains "$DOING_MANUAL" "> 状态: doing"
# Todo section must no longer hold the row (section-bounded, not file-wide)
sed -n '/^## Todo/,/^## Doing/p' "$WS/exp.md" | grep -q "^| $XID |" \
  && fail "Todo section still holds the row after start-exp"
# starting twice fails (manual no longer in todo/)
assert_fails bash "$WS/scripts/start-exp.sh" "$XID"

# gate: complete refused while the 结果 placeholder is present
assert_fails bash "$WS/scripts/complete-exp.sh" "$XID" done "result"
# gate: empty exp_spec (only .gitkeep) refused — the config contract has teeth
sed -i_tmp "s|<!-- 一句话结论; 关闭 exp 前必填 -->|baseline 42ms vs optimized 31ms|" "$DOING_MANUAL" && rm -f "${DOING_MANUAL}_tmp"
assert_fails bash "$WS/scripts/complete-exp.sh" "$XID" done "result"

# satisfy the config contract, record data, close with commit points
printf 'iters: 200\nwarmup: 10\n' > "$WS/examples/exp_spec/$XD/config-a.yaml"
printf 'seed run\n' > "$WS/exp/exp_data/$XD/run.log"
CLOSE_OUT="$(bash "$WS/scripts/complete-exp.sh" "$XID" done "baseline 42ms vs optimized 31ms" --commit "demo-repo@a1b2c3d")" || fail "complete failed"
assert_output_contains "$CLOSE_OUT" "not a registered key repo"
DONE_MANUAL="$(ls "$WS"/exp/done/"$XD"-*.md)"
[ -f "$DONE_MANUAL" ] || fail "manual not moved to done/"
assert_contains "$DONE_MANUAL" "> 状态: 完成"
assert_contains "$WS/exp.md" "| $XID | latency measurement | 完成 | baseline 42ms vs optimized 31ms |"
# index snapshot: status / commits point / config names
assert_contains "$WS/exp/index.md" "| $XID | latency measurement | 完成 | plan:$PID | iteration_$IID | demo-repo@a1b2c3d | config-a.yaml |"
# closing twice fails
assert_fails bash "$WS/scripts/complete-exp.sh" "$XID" done "again"

# complete from todo (start ceremony skipped) — a second exp closed directly
OUT4="$(bash "$WS/scripts/new-exp.sh" "quick survey exp")"
XID2="$(printf '%s' "$OUT4" | grep -o 'exp_[0-9]*' | head -1 | cut -d_ -f2)"
MANUAL2="$(ls "$WS"/exp/todo/exp_"$XID2"-*.md)"
sed -i_tmp2 "s|<!-- 一句话结论; 关闭 exp 前必填 -->|survey done|" "$MANUAL2" && rm -f "${MANUAL2}_tmp2"
printf 'notes\n' > "$WS/examples/exp_spec/exp_$XID2/README.md"
bash "$WS/scripts/complete-exp.sh" "$XID2" abandoned "out of scope" >/dev/null || fail "direct close failed"
[ -f "$(ls "$WS"/exp/done/exp_"$XID2"-*.md)" ] || fail "second manual not in done/"

# milestone commit + doctor green (exp consistency included)
git -C "$WS" add -A >/dev/null 2>&1
git -C "$WS" commit -qm "test: exp lifecycle milestone" >/dev/null 2>&1
assert_ok bash "$WS/scripts/doctor.sh"

rm -rf "$SB"
echo "PASS t33"
