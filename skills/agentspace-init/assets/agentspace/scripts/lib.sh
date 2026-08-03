#!/usr/bin/env bash
# AGENTSPACE shared function library. Sourced by sibling scripts, not run directly.
# Convention: AS_ROOT = AGENTSPACE workspace root (parent of this scripts/ directory).

AS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Resolve symlinks to physical path (cd -P + pwd -P)
AS_ROOT="$(cd -P "$AS_LIB_DIR/.." && pwd -P)"

# ---- Table section headings / status marker constants ----
# These MUST match the actual markdown headings in deployed workspace files.
readonly SEC_TODO="Todo"
readonly SEC_DONE="Done (最近 10 条)"
readonly SEC_PROGRESS="进行中"
readonly SEC_RECENT="最近完成 (10 条)"
readonly SEC_RELATED="相关迭代"
readonly SEC_REGISTERED="已注册模块"
readonly STATUS_TODO="> 状态: todo"
readonly STATUS_PROGRESS="> 状态: 进行中"
# ---- Placeholder constants (must match template comments exactly; doctor [5] checks drift) ----
# Gate: close-iteration refuses while present. Template: iteration-readme.md "结果"
readonly RESULT_PH_ITER="<!-- 指标 / 结论; 关闭 iteration 前必填 -->"
# Gate: complete-plan refuses while present. Template: plan.md "结果" (first line of 2-line comment)
readonly RESULT_PH_PLAN="<!-- 完成时填写: 一句话结论"
# Warning: doctor flags in-progress readmes while present. Template: iteration-readme.md "当前状态 · 下一步"
readonly RESUME_PH_ITER="<!-- 会话续接块:"

as_die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# Host repo HEAD short sha (project root = AS_ROOT/..). Empty if host is not a git repo.
as_host_head() {
  if git -C "$AS_ROOT/.." rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$AS_ROOT/.." rev-parse --short HEAD 2>/dev/null || true
  fi
}

as_today() { date +%F; }

# Table cell sanitization: | and newlines break markdown tables.
as_cell() { printf '%s' "$1" | sed 's/|/\\|/g' | tr '\n\t' '  ' | tr -d '\r'; }

# Normalize to 4-digit zero-padded id; input must be numeric.
as_norm_id() {
  [ $# -ge 1 ] || as_die "Missing id argument"
  [[ "$1" =~ ^[0-9]+$ ]] || as_die "Id must be numeric: $1"
  printf "%04d" "$((10#$1))"
}

# Next plan index (scan plan/todo + plan/done, max+1, monotonically increasing, never reused).
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

# Next iteration index (scan iterations/iteration_NNNN).
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

# Insert a row after the separator line of a "## SECTION" table (becomes first data row).
# Usage: as_insert_row <file> <section> <row>
as_insert_row() {
  local file="$1" tmp
  tmp="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
  awk -v sec="## $2" -v row="$3" '
    $0 == sec { in_sec=1; print; next }
    /^## / { in_sec=0 }
    in_sec && /^\|[ :|-]+\|$/ && !inserted { print; print row; inserted=1; next }
    { print }
    END { if (!inserted) exit 3 }
  ' "$file" > "$tmp" || { rm -f "$tmp"; as_die "Table section not found: ## $2 ($file)"; }
  cat "$tmp" > "$file" && rm -f "$tmp"
}

# Delete table rows whose first column equals id.
# Usage: as_remove_row <file> <id>
as_remove_row() {
  local file="$1" tmp
  [[ "$2" =~ ^[0-9]+$ ]] || as_die "as_remove_row: id must be numeric: $2"
  tmp="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
  awk -v id="$2" '
    BEGIN { pat="^ *\\| *" id " *\\|" }
    $0 ~ pat { next }
    { print }
  ' "$file" > "$tmp" && cat "$tmp" > "$file" && rm -f "$tmp"
}

# Delete table rows whose first column equals id, bounded to one "## SECTION".
# Rows outside the section are never touched — the same id may legitimately
# appear in several sections (e.g. a plan id in Todo and in Done).
# Usage: as_remove_row_section <file> <section> <id>
as_remove_row_section() {
  local file="$1" tmp
  [[ "$3" =~ ^[0-9]+$ ]] || as_die "as_remove_row_section: id must be numeric: $3"
  tmp="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
  awk -v sec="## $2" -v id="$3" '
    BEGIN { pat="^ *\\| *" id " *\\|" }
    $0 == sec { in_sec=1; print; next }
    /^## / { in_sec=0 }
    in_sec && $0 ~ pat { next }
    { print }
  ' "$file" > "$tmp" && cat "$tmp" > "$file" && rm -f "$tmp"
}

# Keep only the first <keep> data rows in a section table.
# Note: data rows matched by "| digit" prefix — designed for numeric-ID tables.
# Usage: as_truncate_section <file> <section> <keep>
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

# Read the Nth |-delimited field of the row whose first column equals id.
# Usage: as_row_cell <file> <id> <colnum>
as_row_cell() {
  [[ "$2" =~ ^[0-9]+$ ]] || as_die "as_row_cell: id must be numeric: $2"
  awk -F'|' -v id="$2" -v c="$3" '
    BEGIN { pat="^\\| *" id " *\\|" }
    $0 ~ pat { gsub(/^ +| +$/, "", $c); print $c; exit }
  ' "$1"
}

# Fill template placeholders {{ID}} {{TITLE}} {{DATE}} {{PLAN_ID}} {{NAME}} {{PURPOSE}}.
# Usage: PH_ID=.. PH_TITLE=.. as_fill_template <src> <dst>
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

# Replace a single line in-place (exact match old → new). Errors if not found.
# Usage: as_replace_line <file> <old> <new>
as_replace_line() {
  local file="$1" tmp
  tmp="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
  awk -v old="$2" -v new="$3" '
    $0 == old && !done { print new; done=1; next }
    { print }
    END { if (!done) exit 3 }
  ' "$file" > "$tmp" || { rm -f "$tmp"; as_die "Line not found: $2 ($file)"; }
  cat "$tmp" > "$file" && rm -f "$tmp"
}

# Insert a line after the first occurrence of a heading.
# Usage: as_insert_after <file> <heading> <line>
as_insert_after() {
  local file="$1" tmp
  tmp="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
  awk -v heading="$2" -v line="$3" '
    $0 == heading && !done { print; print line; done=1; next }
    { print }
    END { if (!done) exit 3 }
  ' "$file" > "$tmp" || { rm -f "$tmp"; as_die "Line not found: $2 ($file)"; }
  cat "$tmp" > "$file" && rm -f "$tmp"
}

# Insert a line after the first line that STARTS WITH prefix (dynamic content safe).
# Usage: as_insert_after_prefix <file> <prefix> <line>
as_insert_after_prefix() {
  local file="$1" tmp
  tmp="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
  awk -v pre="$2" -v line="$3" '
    index($0, pre) == 1 && !done { print; print line; done=1; next }
    { print }
    END { if (!done) exit 3 }
  ' "$file" > "$tmp" || { rm -f "$tmp"; as_die "Prefix line not found: $2 ($file)"; }
  cat "$tmp" > "$file" && rm -f "$tmp"
}

# Append a line at the end of a section (before next ## or EOF).
# Usage: as_append_to_section <file> <section> <line>
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
  ' "$file" > "$tmp" || { rm -f "$tmp"; as_die "Section not found: ## $2 ($file)"; }
  cat "$tmp" > "$file" && rm -f "$tmp"
}

# ---- Concurrency lock + temp cleanup ----
# mkdir-based spinlock called by the four write scripts.
# Also creates $AS_TMPDIR and installs an EXIT trap to clean both.
as_lock() {
  while ! mkdir "$AS_ROOT/.scripts.lock" 2>/dev/null; do sleep 0.2; done
  AS_TMPDIR="$(mktemp -d "$AS_ROOT/.scripts-tmp.XXXXXXXX")"
  trap '
    rm -rf "$AS_TMPDIR" 2>/dev/null || true
    rmdir "$AS_ROOT/.scripts.lock" 2>/dev/null || true
  ' EXIT
}
