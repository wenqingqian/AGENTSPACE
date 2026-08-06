#!/usr/bin/env bash
# Read-only status workbench. Strict template — section headers, order and
# empty-state placeholders below are fixed (skills/agentspace-status/SKILL.md);
# the `- 项目: —` line is a placeholder the command replaces with a
# subagent-synthesized project paragraph. Every other line is a mechanical
# aggregation — no file contents are printed.
# Usage: status.sh [plugin-version]
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

PLUGIN_VERSION="${1#v}"

# Escape-aware cell splitting: \| cells must not shift fixed column positions.
# Content printed later restores the placeholder back to \|.
ESC="$(printf '\037')"

# UTF-8 byte classes for trunc (BSD sed has no \xHH — build them with printf).
L2="$(printf '\302-\337')"; L3="$(printf '\340-\357')"; L4="$(printf '\360-\364')"; CT="$(printf '\200-\277')"

# UTF-8-safe byte truncation (LC_ALL=C): exact byte cut via head -c (bash
# substring is character-based even under LC_ALL=C), then strip an incomplete
# trailing multibyte char (longest rules first).
trunc() {
  local s
  s="$(printf '%s' "$1" | head -c "$2")"
  s="$(printf '%s' "$s" | sed -e "s/\\([$L4][$CT][$CT]\\)\$//" \
                              -e "s/\\([$L4][$CT]\\)\$//" \
                              -e "s/\\([$L3][$CT]\\)\$//" \
                              -e "s/[$L2]\$//" -e "s/[$L3]\$//" -e "s/[$L4]\$//")"
  s="${s%"${s##*[^ ]}"}"   # trim trailing spaces
  printf '%s' "$s"
}

WS_VERSION="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$AS_ROOT/.agentspace-version.json" 2>/dev/null | head -1 || true)"
WS_VERSION="${WS_VERSION:-?}"

git_ok=0
git -C "$AS_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 && git_ok=1

echo "# AGENTSPACE Status $(as_today)"
echo

# --- 项目总览: `- 项目:` 段落由命令侧子代理填充; 其余为机械事实 ---
AP="$(sed "s/\\\\|/$ESC/g" "$AS_ROOT/plan.md" 2>/dev/null | awk -F'|' -v sec="$SEC_TODO" '
  $0 == ("## " sec) { f=1; next }
  /^## / { f=0 }
  f && /^\| [0-9]/ { n++ }
  END { print n+0 }
' || true)"
AI="$(sed "s/\\\\|/$ESC/g" "$AS_ROOT/iterations.md" 2>/dev/null | awk -F'|' -v sec="$SEC_PROGRESS" '
  $0 == ("## " sec) { f=1; next }
  /^## / { f=0 }
  f && /^\| [0-9]/ { n++ }
  END { print n+0 }
' || true)"
NOTES="$(sed "s/\\\\|/$ESC/g" "$AS_ROOT/notes.md" 2>/dev/null | awk -F'|' '
  # 计数与表无关: 首个分隔行之后所有 `| ` 行都算 (软告警场景下可接受)
  /^\|[ :|-]*-[ :|-]*\|$/ { seen=1; next }
  seen && /^\| / { n++ }
  END { print n+0 }
' || true)"
# doctor.sh 总是打印 `== Done: N issues ==` 形式 (正则匹配该形式, 非裸 Done: 形式)
DOC="$( { bash "$AS_ROOT/scripts/doctor.sh" 2>/dev/null || true; } | sed -n 's/^==* *Done: *\([0-9]*\) issues.*/\1/p' | head -1 || true)"
DOC="${DOC:-?}"
case "$DOC" in
  0) DOC_MSG="0 issues ✓" ;;
  "?") DOC_MSG="不可用" ;;
  *) DOC_MSG="$DOC issues ⚠" ;;
esac

echo "## 项目总览"
echo "- 项目: —"
echo "- 现状: 工作区 v$WS_VERSION | $AP plan / $AI iteration 进行中 | $NOTES 条 notes | next: plan $(as_next_plan_id) / iteration $(as_next_iteration_id) | doctor $DOC_MSG"
echo

# --- 版本与环境 ---
if [ "$git_ok" -eq 1 ]; then
  dirty="$(git -C "$AS_ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ' || true)"
  ab="$(git -C "$AS_ROOT" rev-list --left-right --count @{u}...HEAD 2>/dev/null || true)"
  if [ -n "$ab" ]; then
    behind="$(printf '%s' "$ab" | cut -f1)"; ahead="$(printf '%s' "$ab" | cut -f2)"
    ab_str="ahead $ahead / behind $behind"
  else
    ab_str="(无上游)"
  fi
  last="$(git -C "$AS_ROOT" log -1 --format='%h %ad %s' --date=short 2>/dev/null || true)"
else
  dirty="?"; ab_str="(无 git)"; last=""
fi
# 版本对比仅在传入插件版本参数时进行 — 无参调用(bare)不产生永久性误报漂移
if [ -n "$PLUGIN_VERSION" ]; then
  [ "$WS_VERSION" = "$PLUGIN_VERSION" ] && drift="✓ 一致" || drift="⚠ 漂移 (插件 v$PLUGIN_VERSION)"
else
  drift="(未传插件版本)"
fi

echo "## 版本与环境"
echo "- 工作区 v$WS_VERSION | 插件 v$PLUGIN_VERSION | $drift"
echo "- git: dirty $dirty | $ab_str | 最近提交 $(trunc "${last:-—}" 60)"
echo

# --- 推进总览: per-plan iteration counts + plan titles (escape-aware) ---
echo "## 推进总览"
overview="$(sed "s/\\\\|/$ESC/g" "$AS_ROOT/iterations/index.md" 2>/dev/null | awk -F'|' '
  /^\| [0-9]/ {
    p=$3; gsub(/^ +| +$/, "", p)
    s=$5; gsub(/^ +| +$/, "", s)
    cnt[p]++
    if (s == "已完成") done[p]++
  }
  END { for (p in cnt) printf "%s %d %d\n", p, cnt[p], done[p]+0 }
' | sort || true)"
if [ -n "$overview" ]; then
  while read -r p total d; do
    [ -n "$p" ] || continue
    title="$(sed "s/\\\\|/$ESC/g" "$AS_ROOT/plan/index.md" 2>/dev/null | awk -F'|' -v pid="${p#plan:}" -v esc="$ESC" '
      /^\| [0-9]/ {
        gsub(/^ +| +$/, "", $2)
        if ($2 == pid) { gsub(/^ +| +$/, "", $3); gsub(esc, "\\|", $3); print $3; exit }
      }
    ' || true)"
    [ -n "$title" ] || title="—"
    echo "- $p — $(trunc "$title" 40) — $total 迭代 ($d 已关)"
  done <<< "$overview"
else
  echo "  (无迭代)"
fi
echo

# --- 进行中 ---
echo "## 进行中"
active="$( { sed "s/\\\\|/$ESC/g" "$AS_ROOT/plan.md" 2>/dev/null | awk -F'|' -v sec="$SEC_TODO" -v esc="$ESC" '
  $0 == ("## " sec) { f=1; next }
  /^## / { f=0 }
  f && /^\| [0-9]/ {
    gsub(/^ +| +$/, "", $2); gsub(/^ +| +$/, "", $3); gsub(esc, "\\|", $3)
    print "- plan:" $2 " — " $3
  }
' || true
sed "s/\\\\|/$ESC/g" "$AS_ROOT/iterations.md" 2>/dev/null | awk -F'|' -v sec="$SEC_PROGRESS" -v esc="$ESC" '
  $0 == ("## " sec) { f=1; next }
  /^## / { f=0 }
  f && /^\| [0-9]/ {
    gsub(/^ +| +$/, "", $2); gsub(/^ +| +$/, "", $3); gsub(/^ +| +$/, "", $4)
    gsub(esc, "\\|", $3); gsub(esc, "\\|", $4)
    print "- " $3 " — " $4 " (iteration_" $2 ")"
  }
' || true; } )"
if [ -n "$active" ]; then
  echo "$active"
else
  echo "  ✓ 无进行中"
fi
echo

# --- 近期动态: 工作区事件 + 提交摘要 — 最多 10 条, 显示日期但不按日期筛选 ---
# 事件流取自索引表自带的日期列(创建/完成/开始/关闭/日期/time), 不依赖
# commit — 有些活动不是 commit 也是近期动态; 提交流把类型前缀映射为中文
# 摘要(plan:→计划, fix:→修复…), 不再裸列 commit 名字。两流按日期倒序合并
# 取前 10: sort -s -k1,1r 按日期字段稳定排序 — 同日之内保持各流"新→旧"
# 发射顺序(脚本管理的 plan/iterations 索引为末尾追加 → 反转流; notes/handoff
# 为表头插入 → 保持文件序; git log 本就新→旧), 不会因字节序丢掉最新活动。
# 跨流同日顺序 = 流发射顺序(plan/iteration/notes/handoff/commit) — 日期是
# 日粒度无时间戳, 这是该设计的天花板。所有读取均守卫, 缺失文件自然为空流。
commit_summary() {
  local line="$1" d="${1%% *}" s="${1#* }" t label matched=0
  t="${s%%:*}"
  case "$t" in
    plan) label="计划"; matched=1 ;;
    iteration|iterations) label="迭代"; matched=1 ;;
    notes|note) label="笔记"; matched=1 ;;
    handoff) label="交接"; matched=1 ;;
    update|upgrade) label="升级"; matched=1 ;;
    fix) label="修复"; matched=1 ;;
    feat|feature) label="功能"; matched=1 ;;
    docs) label="文档"; matched=1 ;;
    test|tests) label="测试"; matched=1 ;;
    chore) label="杂项"; matched=1 ;;
    refactor) label="重构"; matched=1 ;;
    merge) label="合并"; matched=1 ;;
    release) label="发布"; matched=1 ;;
    revert) label="回退"; matched=1 ;;
    *) label="提交" ;;
  esac
  # 仅当已知类型前缀命中才剥离前缀 — 未命中的标题(含 ": " 或 fixup! 标记)
  # 必须原样保留, 否则摘要头部会被吞掉。
  if [ "$matched" -eq 1 ]; then
    s="${s#*:}"; s="${s# }"
  fi
  printf '%s %s: %s\n' "$d" "$label" "$s"
}

echo "## 近期动态 (最多 10 条)"
recent="$(
  {
    # 计划: 创建(创建日期, 仅未完成时) / 完成·失败·放弃(完成日期) — 同日
    # 闭环的计划由"完成"事件代表, 不再重复"创建", 给提交流留出位置。
    # 末尾追加的索引 → END 反转使流内新→旧。
    # -F'|' 下首列以 | 开头 → $1 恒为空, 实际列从 $2 起(ID) — 全脚本同约定。
    sed "s/\\\\|/$ESC/g" "$AS_ROOT/plan/index.md" 2>/dev/null | awk -F'|' -v esc="$ESC" '
      /^\| [0-9]/ {
        gsub(/^ +| +$/, "", $2); gsub(/^ +| +$/, "", $3); gsub(/^ +| +$/, "", $4)
        gsub(/^ +| +$/, "", $5); gsub(/^ +| +$/, "", $6)
        if ($5 != "" && $6 == "") { gsub(esc, "\\|", $3); buf[++n] = $5 " 计划创建: " $3 " (plan:" $2 ")" }
        if ($6 != "") {
          k = ($4 == "失败" ? "失败" : ($4 == "放弃" ? "放弃" : "完成"))
          gsub(esc, "\\|", $3); buf[++n] = $6 " 计划" k ": " $3 " (plan:" $2 ")"
        }
      }
      END { for (i = n; i >= 1; i--) print buf[i] }
    '
    # 迭代: 开启(开始日期, 仅未关闭时) / 关闭(完成日期); 同上反转
    sed "s/\\\\|/$ESC/g" "$AS_ROOT/iterations/index.md" 2>/dev/null | awk -F'|' -v esc="$ESC" '
      /^\| [0-9]/ {
        gsub(/^ +| +$/, "", $2); gsub(/^ +| +$/, "", $4)
        gsub(/^ +| +$/, "", $6); gsub(/^ +| +$/, "", $7)
        if ($6 != "" && $7 == "") { gsub(esc, "\\|", $4); buf[++n] = $6 " 迭代开启: " $4 " (iteration_" $2 ")" }
        if ($7 != "") { gsub(esc, "\\|", $4); buf[++n] = $7 " 迭代关闭: " $4 " (iteration_" $2 ")" }
      }
      END { for (i = n; i >= 1; i--) print buf[i] }
    '
    # 笔记: 新增(日期列; 与 NOTES 计数同表同形状)。notes.md 为表头插入
    # (doctor --fix 的 notes_insert_row), 文件序即新→旧, 不反转。
    sed "s/\\\\|/$ESC/g" "$AS_ROOT/notes.md" 2>/dev/null | awk -F'|' -v esc="$ESC" '
      /^\|[ :|-]*-[ :|-]*\|$/ { seen=1; next }
      seen && /^\| / {
        gsub(/^ +| +$/, "", $2); gsub(/^ +| +$/, "", $6)
        if ($6 != "") { gsub(esc, "\\|", $2); print $6 " 笔记新增: " $2 }
      }
    '
    # 交接: 生成(待消费项, time 列)。与 会话入口 同构, 限定 ## Handoffs 节;
    # 行由 as_insert_row 表头插入, 文件序即新→旧, 不反转。
    sed "s/\\\\|/$ESC/g" "$AS_ROOT/handoff/index.md" 2>/dev/null | awk -F'|' -v sec="$SEC_HANDOFF" -v esc="$ESC" '
      $0 == ("## " sec) { in_sec=1; next }
      /^## / { in_sec=0 }
      in_sec && /^\| / && !/^\| *name *\|/ && !/^\|[ :|-]*-[ :|-]*\|$/ {
        gsub(/^ +| +$/, "", $2); gsub(/^ +| +$/, "", $5)
        if ($5 != "") { gsub(esc, "\\|", $2); print $5 " 交接生成: " $2 }
      }
    '
    # 提交: 类型前缀 → 中文摘要; git log 本就新→旧, 不反转
    if [ "$git_ok" -eq 1 ]; then
      git -C "$AS_ROOT" log -20 --format='%ad %s' --date=short 2>/dev/null | while IFS= read -r line; do
        [ -n "$line" ] || continue
        commit_summary "$line"
      done
    fi
  } | sort -s -k1,1r | head -10 || true
)"
if [ -n "$recent" ]; then
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    echo "- $(trunc "$line" 60)"
  done <<< "$recent"
else
  echo "  (无动态)"
fi
echo

# --- 软告警: 入口文件行形状校验 + 版本漂移 + 未提交 + doctor ---
alerts=""
for f in plan.md plan/index.md iterations.md iterations/index.md notes.md register.md utils.md tests.md data.md examples.md handoff/index.md; do
  [ -f "$AS_ROOT/$f" ] || continue
  alerts+="$(sed "s/\\\\|/$ESC/g" "$AS_ROOT/$f" 2>/dev/null | awk -F'|' -v f="$f" '
    /^## / { sec=$0; sub(/^## +/, "", sec); expect=0; next }
    /^\|[ :|-]*-[ :|-]*\|$/ { expect=NF; next }
    /^\| / && expect > 0 && NF != expect {
      printf "  ⚠ 形状: %s %s 节第 %d 行 %d 列 != 表头 %d 列\n", f, sec, NR, NF, expect
    }
  ' || true)"$'\n'
done
if [ -n "$PLUGIN_VERSION" ] && [ "$WS_VERSION" != "$PLUGIN_VERSION" ]; then
  alerts+="  ⚠ 版本: 工作区 v$WS_VERSION != 插件 v$PLUGIN_VERSION"$'\n'
fi
if [ "$git_ok" -eq 1 ] && [ "${dirty:-0}" != "0" ]; then
  alerts+="  ⚠ git: $dirty 个未提交改动"$'\n'
fi
case "$DOC" in
  0) ;;
  "?") alerts+="  ⚠ doctor: 无法运行"$'\n' ;;
  *) alerts+="  ⚠ doctor: $DOC issues (建议运行 /agentspace-doctor)"$'\n' ;;
esac
n_alerts="$(printf '%s' "$alerts" | grep -c '^  ⚠' || true)"

echo "## 软告警 (${n_alerts:-0})"
if [ "${n_alerts:-0}" -gt 0 ]; then
  printf '%s' "$alerts"
else
  echo "  ✓ 无软告警"
fi
echo

# --- 会话入口 ---
echo "## 会话入口"
# handoff 行由 handoff.sh 机器生成, 字段受约束 (name/desc 无原始 |, 行形状
# 由下方校验把关), 因此不需要 \037 屏蔽 — 原始解析 + 行格式异常兜底即可
if [ -d "$AS_ROOT/handoff" ] && [ -f "$AS_ROOT/handoff/index.md" ]; then
  rows="$(awk -v sec="## $SEC_HANDOFF" '
    $0 ~ ("^" sec "[[:space:]]*$") { in_sec=1; next }
    /^## / { in_sec=0 }
    in_sec && /^\| / && !/^\| *name *\|/ && !/^\|[ :|-]*-[ :|-]*\|$/ { print }
  ' "$AS_ROOT/handoff/index.md" 2>/dev/null || true)"
  entries=""; count=0; found=0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    tmp="${line#| }"; name="${tmp%% | *}"; rest="${tmp#* | }"
    date="${rest##* | }"; date="${date% |}"
    nodate="${rest% | *}"; loc="${nodate##* | }"; desc="${nodate%% | *}"
    if [ -z "$name" ] || [ -z "$loc" ] || [[ "$name" == *'|'* ]] || [[ "$loc" != handoff_*.md ]] || [[ "$loc" == */* ]] || [[ "$date" != [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] ]]; then
      entries+="  (行格式异常: $line)"$'\n'
      found=1; count=$((count+1))
      continue
    fi
    [ -n "$desc" ] || desc="—"
    marker=""
    if [ ! -e "$AS_ROOT/handoff/$loc" ]; then
      marker=" (文件缺失 — 见 doctor [10])"
    elif grep -Fq '> 状态: kept(--keep,' "$AS_ROOT/handoff/$loc" 2>/dev/null; then
      marker=" (--keep 保留)"
    elif [ -n "$(find "$AS_ROOT/handoff/$loc" -mtime "+$((STALE_DAYS - 1))" 2>/dev/null)" ]; then
      marker=" ⚠ 过时(>$STALE_DAYS 天未消费 — 见 doctor [11])"
    fi
    entries+="  - $name | $desc | $date$marker"$'\n'
    found=1; count=$((count+1))
  done <<< "$rows"
  if [ "$found" -eq 1 ]; then
    echo "- Handoffs: $count 待消费"
    printf '%s' "$entries"
  else
    echo "  ✓ 空"
  fi
else
  echo "  (无 handoff 模块)"
fi
