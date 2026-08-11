#!/usr/bin/env bash
# t15: status workbench — strict template sections (4-part 近期动态: 主线软槽 /
# 宿主代码提交 / 工作区事件 / 台账), soft-alert negatives (malformed row /
# version drift / uncommitted), escape-aware 推进总览 with a raw-pipe title,
# host-commit stream with iteration linkage + 最近关闭 anchor, empty states,
# and per-part caps (events 10 / ledger 5).
set -euo pipefail
. "$(dirname "$0")/lib.sh"

SB="$(build_sandbox t15)"
WS="$SB/AGENTSPACE"
ST="$WS/scripts/status.sh"
WSV="$(grep -o '"version": "[^"]*"' "$WS/.agentspace-version.json" | head -1 | cut -d'"' -f4)"
[ -n "$WSV" ] || fail "workspace version unreadable"

# --- 0) 空态: 无 git 且无事件 → 三个分区各自空态占位 ---
SB_NG="$(mktemp -d /tmp/as-t15-nogit-XXXXXX)"
cp -R "$WS" "$SB_NG/ws"
rm -rf "$SB_NG/ws/.git"
OUT_NG="$(bash "$SB_NG/ws/scripts/status.sh" "$WSV")"
assert_output_contains "$OUT_NG" "(无宿主仓库)"
assert_output_contains "$OUT_NG" "(无动态)"
assert_output_contains "$OUT_NG" "(无台账)"
rm -rf "$SB_NG"

mc() { git -C "$WS" add -A >/dev/null 2>&1; git -C "$WS" commit -qm "test: t15 milestone" >/dev/null 2>&1 || true; }
hc() { git -C "$SB" add -A >/dev/null 2>&1; git -C "$SB" -c user.name=test -c user.email=test@test commit -qm "$1" >/dev/null 2>&1 || true; }

# --- 1) 严格模板: 节头逐字 + 软槽占位 + 分区 + 全绿基线 ---
OUT="$(bash "$ST" "$WSV")"
assert_output_contains "$OUT" "# AGENTSPACE Status "
assert_output_contains "$OUT" "## 项目总览"
assert_output_contains "$OUT" "- 项目: —"
assert_output_contains "$OUT" "## 版本与环境"
assert_output_contains "$OUT" "## 推进总览"
assert_output_contains "$OUT" "## 进行中"
assert_output_contains "$OUT" "## 近期动态"
assert_output_contains "$OUT" "### 主线"
assert_output_contains "$OUT" "- 近期主线: —"
assert_output_contains "$OUT" "### 代码提交 (宿主仓库 · 最近 5 条)"
assert_output_contains "$OUT" "### 工作区事件 (最近 10 条)"
assert_output_contains "$OUT" "### 台账 (agentspace 记账 · 最近 5 条)"
assert_output_contains "$OUT" "## 软告警 (0)"
assert_output_contains "$OUT" "✓ 无软告警"
assert_output_contains "$OUT" "## 会话入口"
assert_output_contains "$OUT" "✓ 无已关闭迭代"
assert_output_contains "$OUT" "✓ 一致"
assert_output_contains "$OUT" "✓ 无进行中"
assert_output_contains "$OUT" "- $(date +%F)"     # 台账行带日期
# 宿主流: 宿主 init commit 在列; 概括占位符必须是完整形状(sha 为 hex)
assert_output_contains "$OUT" "· init"
printf '%s\n' "$OUT" | grep -Eq '^  概括\[[0-9a-f]+\]: —$' || fail "概括 placeholder missing or malformed"

# --- 1b) 节序: 7 个固定 ## 节按序出现 (### 子节不干扰) ---
ORDER_ERR="$(printf '%s\n' "$OUT" | awk '
  BEGIN { split("项目总览 版本与环境 推进总览 进行中 近期动态 软告警 会话入口", want, " ") }
  /^## / {
    h=$0; sub(/^## +/, "", h); sub(/[(].*/, "", h); gsub(/ +$/, "", h)
    i++
    if (h != want[i]) { print "got \"" h "\" at #" i ", want \"" want[i] "\""; exit 1 }
  }
  END { if (i != 7) { print "found " i " sections, want 7"; exit 1 } }
')" || fail "status section order mismatch: $ORDER_ERR"

# --- 1c) 近期动态 UTF-8 回归: 台账行 "- " 2 字节 + 日期前缀 11 + "提交: " 8
# → 38 x 占至第 59 字节, 4 字节 emoji 从第 60 字节起, head -c 60 切在 emoji
# 首字节 → strip 后输出仍须为合法 UTF-8 ---
git -C "$WS" commit -q --allow-empty -m "$(printf 'x%.0s' {1..38})😀"
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
# 有告警时软告警节不得出现每文件一个的空行(真实三方验证发现的显示 bug)
ALERT_SEC3="$(printf '%s\n' "$OUT3" | awk '/^## 软告警/{f=1;next} /^## /{f=0} f')"
[ "$(printf '%s\n' "$ALERT_SEC3" | grep -c '^$' || true)" -le 1 ] || fail "soft-alert section has stray blank lines"
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
# 宿主侧代码提交 — close 会记录宿主结束 commit → 关联反查 + 最近关闭锚点
printf 'host = 1\n' > "$SB/host.py"
hc "feat: host side change"
# 进行中视图: 转义管标题完整显示
OUT_MID="$(bash "$ST" "$WSV")"
assert_output_contains "$OUT_MID" "list \\| 修复 + close diff"
# 近期动态: 工作区事件(索引日期列, 不依赖 commit) + 台账摘要(类型前缀映射)
assert_output_contains "$OUT_MID" "$(date +%F) 计划创建: Esc Pipe Plan"
assert_output_contains "$OUT_MID" "$(date +%F) 迭代开启: list \\| 修复 + close diff"
assert_output_contains "$OUT_MID" "$(date +%F) 测试: t15 milestone"  # 台账(test:→测试)
# 宿主代码提交块: feat commit 在列
assert_output_contains "$OUT_MID" "feat: host side change"
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
# 推进总览: 转义感知计数; 已关 iteration 不在进行中 (限定 进行中 节内断言 —
# 近期动态的 迭代关闭 行合法含该后缀, 全输出断言会依赖截断位置而失真)
OUT_AFTER="$(bash "$ST" "$WSV")"
assert_output_contains "$OUT_AFTER" "1 迭代 (1 已关)"
PROGRESS_SEC="$(printf '%s\n' "$OUT_AFTER" | awk '/^## 进行中/{f=1;next} /^## /{f=0} f')"
assert_output_not_contains "$PROGRESS_SEC" "(iteration_$ITER)"
# 近期动态: 关闭事件(完成日期)入列
assert_output_contains "$OUT_AFTER" "$(date +%F) 迭代关闭: list \\| 修复 + close diff"
# 宿主代码提交: close 记录的宿主 commit 关联到本 iteration
assert_output_contains "$OUT_AFTER" "feat: host side change"
assert_output_contains "$OUT_AFTER" "关联: iteration_$ITER · plan:"
# 会话入口: 最近关闭锚点(标题 + 关闭日期 + 宿主 SHA)
assert_output_contains "$OUT_AFTER" "- 最近关闭: iteration_$ITER — list \\| 修复 + close diff ("
assert_output_contains "$OUT_AFTER" "关闭 · 宿主 "
# 状态输出不得泄漏原始 \037 屏蔽字节 (转义管在显示路径必须被还原为 \|)
ESC_BYTE="$(printf '\037')"
if printf '%s' "$OUT_MID" | grep -Fq "$ESC_BYTE" || printf '%s' "$OUT_AFTER" | grep -Fq "$ESC_BYTE"; then
  fail "status output leaks raw ESC byte"
fi
# 近期动态: 完成状态分支 — 失败标签 (先移除结果占位以满足 complete-plan 闸门)
PLANFILE="$(ls "$WS"/plan/todo/"$PLAN"-*.md)"
grep -vF "完成时填写" "$PLANFILE" > "$PLANFILE.tmp" && mv "$PLANFILE.tmp" "$PLANFILE"
bash "$WS/scripts/complete-plan.sh" "$PLAN" failed "cap result" >/dev/null 2>&1
mc
OUT_FAIL="$(bash "$ST" "$WSV")"
assert_output_contains "$OUT_FAIL" "$(date +%F) 计划失败: Esc Pipe Plan"

# --- 5) 近期动态: 笔记新增 + 交接生成 事件流 ---
printf '| cap probe note | 标签 | 结论 | plan:%s | %s | [notes/cap-probe-note.md](notes/cap-probe-note.md) |\n' "$PLAN" "$(date +%F)" >> "$WS/notes.md"
printf '# cap probe note\n\n> 创建: %s\n> 来源: plan:%s\n\n## 结论\n\ncap probe note body.\n' "$(date +%F)" "$PLAN" > "$WS/notes/cap-probe-note.md"
bash "$WS/scripts/handoff.sh" --produce --name cap-probe --description "cap probe" >/dev/null 2>&1
mc
OUT5="$(bash "$ST" "$WSV")"
assert_output_contains "$OUT5" "$(date +%F) 笔记新增: cap probe note"
assert_output_contains "$OUT5" "$(date +%F) 交接生成: cap-probe"

# --- 6) 分区 cap: 事件 10 条 / 台账 5 条 (同日 >cap 时保留真正最新) ---
for n in {1..13}; do
  git -C "$WS" commit -q --allow-empty -m "feat: cap probe $n"
done
OUT_CAP="$(bash "$ST" "$WSV")"
EVENT_SEC="$(printf '%s\n' "$OUT_CAP" | awk '/^### 工作区事件/{f=1;next} /^### /{f=0} /^## /{f=0} f')"
CNT_E="$(printf '%s\n' "$EVENT_SEC" | grep -c '^- ' || true)"
# 同日闭环抑制创建/开启(计划失败/迭代关闭代表) → 4 条: 失败/关闭/笔记/交接
[ "$CNT_E" = "4" ] || fail "工作区事件 shows $CNT_E lines (expect 4: 计划失败/迭代关闭/笔记/交接)"
LEDGER_SEC="$(printf '%s\n' "$OUT_CAP" | awk '/^### 台账/{f=1;next} /^### /{f=0} /^## /{f=0} f')"
CNT_L="$(printf '%s\n' "$LEDGER_SEC" | grep -c '^- ' || true)"
[ "$CNT_L" = "5" ] || fail "台账 shows $CNT_L lines (expect 5 cap)"
assert_output_contains "$OUT_CAP" "$(date +%F) 功能: cap probe 13"

# --- 6b) 事件 10-cap 边界: >10 同日事件 → 恰好 10 条, 且最新事件在列 ---
# notes 流语义 = 表头插入(新在前) → 反向追加等效(12 为最新, 文件行序在前)
for n in {12..1}; do
  fn="cap-event-$(printf '%02d' "$n").md"
  printf '| cap event %02d | 标签 | 结论 | plan:%s | %s | [notes/%s](notes/%s) |\n' "$n" "$PLAN" "$(date +%F)" "$fn" "$fn" >> "$WS/notes.md"
  printf '# cap event %02d\n\n> 创建: %s\n> 来源: plan:%s\n\n## 结论\n\ncap event body.\n' "$n" "$(date +%F)" "$PLAN" > "$WS/notes/$fn"
done
mc
OUT_EV="$(bash "$ST" "$WSV")"
EVENT_SEC2="$(printf '%s\n' "$OUT_EV" | awk '/^### 工作区事件/{f=1;next} /^### /{f=0} /^## /{f=0} f')"
CNT_E2="$(printf '%s\n' "$EVENT_SEC2" | grep -c '^- ' || true)"
[ "$CNT_E2" = "10" ] || fail "工作区事件 shows $CNT_E2 lines (expect 10 cap)"
assert_output_contains "$OUT_EV" "$(date +%F) 笔记新增: cap event 12"
assert_ok bash "$WS/scripts/doctor.sh"

rm -rf "$SB"
echo "PASS t15"
