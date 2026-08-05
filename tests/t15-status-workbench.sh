#!/usr/bin/env bash
# t15: status workbench — strict template sections, soft-alert negatives
# (malformed row / version drift / uncommitted), escape-aware 推进总览 with a
# raw-pipe title, and close-iteration leaving the escaped-pipe index row intact.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

SB="$(build_sandbox t15)"
WS="$SB/AGENTSPACE"
ST="$WS/scripts/status.sh"
WSV="$(grep -o '"version": "[^"]*"' "$WS/.agentspace-version.json" | head -1 | cut -d'"' -f4)"
[ -n "$WSV" ] || fail "workspace version unreadable"

mc() { git -C "$WS" add -A >/dev/null 2>&1; git -C "$WS" commit -qm "test: t15 milestone" >/dev/null 2>&1 || true; }

# --- 1) 严格模板: 节头逐字 + 项目占位 + 全绿基线 ---
OUT="$(bash "$ST" "$WSV")"
assert_output_contains "$OUT" "# AGENTSPACE Status "
assert_output_contains "$OUT" "## 项目总览"
assert_output_contains "$OUT" "- 项目: —"
assert_output_contains "$OUT" "## 版本与环境"
assert_output_contains "$OUT" "## 推进总览"
assert_output_contains "$OUT" "## 进行中"
assert_output_contains "$OUT" "## 近期动态 (最近 10 条)"
assert_output_contains "$OUT" "## 软告警 (0)"
assert_output_contains "$OUT" "✓ 无软告警"
assert_output_contains "$OUT" "## 会话入口"
assert_output_contains "$OUT" "✓ 一致"
assert_output_contains "$OUT" "✓ 无进行中"
assert_output_contains "$OUT" "- $(date +%F)"     # 近期动态带日期

# --- 1b) 节序: 7 个固定节必须按序出现 (近期动态/软告警 带后缀 → 匹配前缀) ---
ORDER_ERR="$(printf '%s\n' "$OUT" | awk '
  BEGIN { split("项目总览 版本与环境 推进总览 进行中 近期动态 软告警 会话入口", want, " ") }
  /^## / {
    h=$0; sub(/^## +/, "", h); sub(/[(].*/, "", h); gsub(/ +$/, "", h)
    i++
    if (h != want[i]) { print "got \"" h "\" at #" i ", want \"" want[i] "\""; exit 1 }
  }
  END { if (i != 7) { print "found " i " sections, want 7"; exit 1 } }
')" || fail "status section order mismatch: $ORDER_ERR"

# --- 1c) 近期动态 UTF-8 回归: 60 字节截断落在 4 字节 emoji 内 (47 x + 日期
# 前缀 11 字节 → 第 60 字节 = emoji 第 2 字节 F0 9F), 输出仍须为合法 UTF-8 ---
git -C "$WS" commit -q --allow-empty -m "$(printf 'x%.0s' {1..47})😀"
OUT_UTF8="$(bash "$ST" "$WSV")"
if ! printf '%s' "$OUT_UTF8" | python3 -c "import sys; sys.stdin.buffer.read().decode('utf-8')" >/dev/null 2>&1; then
  fail "status output is not valid UTF-8 (60-byte trunc cut inside a 4-byte char)"
fi

# --- 2) 软告警负向: 版本漂移 ---
OUT2="$(bash "$ST" 9.9.9)"
assert_output_contains "$OUT2" "⚠ 漂移 (插件 v9.9.9)"
assert_output_contains "$OUT2" "⚠ 版本: 工作区 v$WSV != 插件 v9.9.9"

# --- 3) 软告警负向: 形状(坏行) + 未提交 ---
printf '| 主题 | 只有三格 |\n' >> "$WS/notes.md"
OUT3="$(bash "$ST" "$WSV")"
assert_output_contains "$OUT3" "⚠ 形状:"
grep -vF '| 主题 | 只有三格 |' "$WS/notes.md" > "$WS/notes.md.tmp" && mv "$WS/notes.md.tmp" "$WS/notes.md"
printf 'scratch\n' > "$WS/scratch.txt"
OUT4="$(bash "$ST" "$WSV")"
assert_output_contains "$OUT4" "⚠ git: "
rm -f "$WS/scratch.txt"
OUT5="$(bash "$ST" "$WSV")"
assert_output_contains "$OUT5" "✓ 无软告警"       # 全部恢复 → 回到全绿

# --- 4) \| 回归: 原始管道标题全链路 ---
bash "$WS/scripts/new-plan.sh" "Esc Pipe Plan" >/dev/null 2>&1
PLAN="$(ls "$WS"/plan/todo/ | head -1 | cut -d- -f1)"
mc
bash "$WS/scripts/new-iteration.sh" "$PLAN" "list | 修复 + close diff" >/dev/null 2>&1
ITER="$(ls -d "$WS"/iterations/iteration_[0-9]* | sort | tail -1 | xargs basename | sed 's/iteration_//')"
mc
# 进行中视图: 转义管标题完整显示
OUT_MID="$(bash "$ST" "$WSV")"
assert_output_contains "$OUT_MID" "list \\| 修复 + close diff"
# 关闭: 结果节填满 → close (结果含原始管道) → index 行必须完整 (8 列 + 2 转义管)
grep -vF "指标 / 结论" "$WS/iterations/iteration_$ITER/readme.md" > "$WS/iterations/iteration_$ITER/readme.md.tmp" && mv "$WS/iterations/iteration_$ITER/readme.md.tmp" "$WS/iterations/iteration_$ITER/readme.md"
assert_ok bash "$WS/scripts/close-iteration.sh" "$ITER" "esc | result"
LINE="$(grep -F "| $ITER |" "$WS/iterations/index.md")"
[ -n "$LINE" ] || fail "index row for iteration_$ITER missing"
NF="$(printf '%s\n' "$LINE" | awk -F'|' '{print NF}')"
[ "$NF" = "12" ] || fail "index row $ITER has $NF fields (expect 12 = 8 cols + 2 escaped pipes): $LINE"
assert_contains "$WS/iterations/index.md" "list \\| 修复 + close diff"
assert_contains "$WS/iterations/index.md" "esc \\| result"
assert_contains "$WS/iterations.md" "list \\| 修复 + close diff"
mc
# 推进总览: 转义感知计数; 已关 iteration 不在进行中
OUT_AFTER="$(bash "$ST" "$WSV")"
assert_output_contains "$OUT_AFTER" "1 迭代 (1 已关)"
assert_output_not_contains "$OUT_AFTER" "(iteration_$ITER)"
# 状态输出不得泄漏原始 \037 屏蔽字节 (转义管在显示路径必须被还原为 \|)
ESC_BYTE="$(printf '\037')"
if printf '%s' "$OUT_MID" | grep -Fq "$ESC_BYTE" || printf '%s' "$OUT_AFTER" | grep -Fq "$ESC_BYTE"; then
  fail "status output leaks raw ESC byte"
fi
assert_ok bash "$WS/scripts/doctor.sh"

rm -rf "$SB"
echo "PASS t15"
