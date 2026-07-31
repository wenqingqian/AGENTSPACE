#!/usr/bin/env bash
# AGENTSPACE 脚本公共函数库。被同目录脚本 source, 不直接执行。
# 约定: AS_ROOT = AGENTSPACE 工作区根目录(本文件所在 scripts/ 的上一层)。

AS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Optional 4: 用 cd -P + pwd -P 解析符号链接, 确保 AS_ROOT 是物理路径
AS_ROOT="$(cd -P "$AS_LIB_DIR/.." && pwd -P)"

# ---- 表格小节标题 / 状态标记常量 (Required 9) ----
readonly SEC_TODO="Todo"
readonly SEC_DONE="Done (最近 10 条)"
readonly SEC_PROGRESS="进行中"
readonly SEC_RECENT="最近完成 (10 条)"
readonly SEC_RELATED="相关迭代"
readonly SEC_REGISTERED="已注册模块"
readonly STATUS_TODO="> 状态: todo"
readonly STATUS_PROGRESS="> 状态: 进行中"

as_die() { printf 'error: %s\n' "$*" >&2; exit 1; }

as_today() { date +%F; }

# 表格单元格安全化: | 与换行会破坏 markdown 表格
# (Required 7) | → \| (保留原意), 同时剥离 \r; (Optional 1) \t → 空格(防 awk -v 转义序列)
as_cell() { printf '%s' "$1" | sed 's/|/\\|/g' | tr '\n\t' '  ' | tr -d '\r'; }

# 规范化为 4 位数字 id; 输入须为纯数字
as_norm_id() {
  [ $# -ge 1 ] || as_die "缺少 id 参数"
  [[ "$1" =~ ^[0-9]+$ ]] || as_die "id 必须是数字: $1"
  printf "%04d" "$((10#$1))"
}

# 下一个 plan 索引(扫描 plan/todo + plan/done, max+1, 自项目创建递增, 不复用)
# Optional 6: 用 find 显式枚举避免 glob 字面量回退; Optional 8: 正则不限制 4 位, 支持 5+ 位 id
as_next_plan_id() {
  local max=0 f base n
  while IFS= read -r -d '' f; do
    base="$(basename "$f")"
    n="${base%%-*}"
    [[ "$n" =~ ^[0-9]+$ ]] || continue
    (( 10#$n > max )) && max=$((10#$n))
  done < <(find "$AS_ROOT/plan/todo" "$AS_ROOT/plan/done" -maxdepth 1 \
    -name '[0-9][0-9][0-9][0-9]-*.md' -print0 2>/dev/null)
  printf "%04d" $((max + 1))
}

# 下一个 iteration 索引(扫描 iterations/iteration_NNNN)
# Optional 6: 用 find 显式枚举避免 glob 字面量回退; Optional 8: 正则不限制 4 位
as_next_iteration_id() {
  local max=0 d base n
  while IFS= read -r -d '' d; do
    base="$(basename "$d")"
    n="${base#iteration_}"
    [[ "$n" =~ ^[0-9]+$ ]] || continue
    (( 10#$n > max )) && max=$((10#$n))
  done < <(find "$AS_ROOT/iterations" -maxdepth 1 -type d \
    -name 'iteration_[0-9][0-9][0-9][0-9]*' -print0 2>/dev/null)
  printf "%04d" $((max + 1))
}

# 在 "## SECTION" 下表格的分隔行之后插入一行(即成为该表第一行数据)
# 用法: as_insert_row <file> <section> <row>
as_insert_row() {
  local file="$1" tmp
  tmp="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
  awk -v sec="## $2" -v row="$3" '
    $0 == sec { in_sec=1; print; next }
    /^## / { in_sec=0 }
    in_sec && /^\|[ :|-]+\|$/ && !inserted { print; print row; inserted=1; next }
    { print }
    END { if (!inserted) exit 3 }
  ' "$file" > "$tmp" || { rm -f "$tmp"; as_die "未找到表格小节: ## $2 ($file)"; }
  cat "$tmp" > "$file" && rm -f "$tmp"
}

# 删除首列等于 id 的表格行
# 用法: as_remove_row <file> <id>
as_remove_row() {
  local file="$1" tmp
  [[ "$2" =~ ^[0-9]+$ ]] || as_die "as_remove_row: id 必须是数字: $2"
  tmp="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
  awk -v id="$2" '
    BEGIN { pat="^ *\\| *" id " *\\|" }
    $0 ~ pat { next }
    { print }
  ' "$file" > "$tmp" && cat "$tmp" > "$file" && rm -f "$tmp"
}

# 保留某小节表格的前 keep 行数据行。
# 注意: 当前数据行匹配以 "| 数字" 开头(Nit 5), 仅用于数字 ID 首列表格。
# 用法: as_truncate_section <file> <section> <keep>
as_truncate_section() {
  local file="$1" tmp
  tmp="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
  awk -v sec="## $2" -v keep="$3" '
    $0 == sec { in_sec=1; n=0; print; next }
    /^## / { in_sec=0 }
    in_sec && /^\| [0-9]/ { n++; if (n > keep) next }
    { print }
  ' "$file" > "$tmp" && cat "$tmp" > "$file" && rm -f "$tmp"
}

# 取表格中首列为 id 的行的第 N 个 |-分隔字段(去首尾空格; N=2 为第一列)
# 用法: as_row_cell <file> <id> <colnum>
as_row_cell() {
  [[ "$2" =~ ^[0-9]+$ ]] || as_die "as_row_cell: id 必须是数字: $2"
  awk -F'|' -v id="$2" -v c="$3" '
    BEGIN { pat="^\\| *" id " *\\|" }
    $0 ~ pat { gsub(/^ +| +$/, "", $c); print $c; exit }
  ' "$1"
}

# 用环境变量填充模板占位符 {{ID}} {{TITLE}} {{DATE}} {{PLAN_ID}} {{NAME}} {{PURPOSE}}
# 用法: PH_ID=.. PH_TITLE=.. as_fill_template <src> <dst>
as_fill_template() {
  PH_ID="${PH_ID:-}" PH_TITLE="${PH_TITLE:-}" PH_DATE="${PH_DATE:-}" \
  PH_PLAN_ID="${PH_PLAN_ID:-}" PH_NAME="${PH_NAME:-}" PH_PURPOSE="${PH_PURPOSE:-}" \
  awk '
    function esc(s) { gsub(/\\/, "\\\\", s); gsub(/&/, "\\\\&", s); return s }
    {
      line=$0
      gsub(/{{ID}}/, esc(ENVIRON["PH_ID"]), line)
      gsub(/{{TITLE}}/, esc(ENVIRON["PH_TITLE"]), line)
      gsub(/{{DATE}}/, esc(ENVIRON["PH_DATE"]), line)
      gsub(/{{PLAN_ID}}/, esc(ENVIRON["PH_PLAN_ID"]), line)
      gsub(/{{NAME}}/, esc(ENVIRON["PH_NAME"]), line)
      gsub(/{{PURPOSE}}/, esc(ENVIRON["PH_PURPOSE"]), line)
      print line
    }
  ' "$1" > "$2"
}

# 就地替换单行(精确匹配 old_line → new_line), 找不到则报错
# 用法: as_replace_line <file> <old> <new>
as_replace_line() {
  local file="$1" tmp
  tmp="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
  awk -v old="$2" -v new="$3" '
    $0 == old && !done { print new; done=1; next }
    { print }
    END { if (!done) exit 3 }
  ' "$file" > "$tmp" || { rm -f "$tmp"; as_die "未找到行: $2 ($file)"; }
  cat "$tmp" > "$file" && rm -f "$tmp"
}

# 在匹配 heading 的行之后插入一行(仅第一次匹配)
# 用法: as_insert_after <file> <heading> <line>
as_insert_after() {
  local file="$1" tmp
  tmp="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
  awk -v heading="$2" -v line="$3" '
    $0 == heading && !done { print; print line; done=1; next }
    { print }
    END { if (!done) exit 3 }
  ' "$file" > "$tmp" || { rm -f "$tmp"; as_die "未找到行: $2 ($file)"; }
  cat "$tmp" > "$file" && rm -f "$tmp"
}

# 在指定 section 的末尾(下一个 ## 或 EOF 之前)追加一行
# 用法: as_append_to_section <file> <section> <line>
as_append_to_section() {
  local file="$1" tmp
  tmp="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
  awk -v sec="## $2" -v line="$3" '
    function flush_buf() {
      for (i=1; i<=b; i++) print buf[i]
      if (!inserted) { print line; inserted=1 }
      b=0
    }
    $0 == sec { in_sec=1; print; next }
    in_sec && /^## / { flush_buf(); in_sec=0; print; next }
    in_sec { buf[++b] = $0; next }
    { print }
    END {
      if (in_sec) flush_buf()
      if (!inserted) exit 3
    }
  ' "$file" > "$tmp" || { rm -f "$tmp"; as_die "未找到小节: ## $2 ($file)"; }
  cat "$tmp" > "$file" && rm -f "$tmp"
}

# ---- 并发保护 (Required 3) + 临时文件清理 (Nit 6) ----
# 基于 mkdir 原子性的自旋锁; 在四个写脚本进入时调用.
# 同时创建临时目录 $AS_TMPDIR 并在 EXIT trap 中一并清理.
as_lock() {
  while ! mkdir "$AS_ROOT/.scripts.lock" 2>/dev/null; do sleep 0.2; done
  AS_TMPDIR="$(mktemp -d "$AS_ROOT/.scripts-tmp.XXXXXXXX")"
  trap '
    rm -rf "$AS_TMPDIR" 2>/dev/null || true
    rmdir "$AS_ROOT/.scripts.lock" 2>/dev/null || true
  ' EXIT
}
