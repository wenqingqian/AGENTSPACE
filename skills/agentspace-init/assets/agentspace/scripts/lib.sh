#!/usr/bin/env bash
# AGENTSPACE shared function library. Sourced by sibling scripts, not run directly.
# Convention: AS_ROOT = AGENTSPACE workspace root (parent of this scripts/ directory).

AS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Resolve symlinks to physical path (cd -P + pwd -P)
AS_ROOT="$(cd -P "$AS_LIB_DIR/.." && pwd -P)"

# ---- Runtime environment gate (fail fast, one clear message) ----
# The scripts need bash >= 3.1 (scalar +=) and the core POSIX toolchain; the
# macOS system bash is 3.2, Linux ships 4.x+. A cryptic mid-script error on an
# old bash / missing tool is worse than this upfront gate.
if [ "${BASH_VERSINFO[0]:-0}" -lt 3 ] || { [ "${BASH_VERSINFO[0]:-0}" -eq 3 ] && [ "${BASH_VERSINFO[1]:-0}" -lt 1 ]; }; then
  printf 'error: AGENTSPACE scripts need bash >= 3.1 (found %s) — upgrade bash and re-run.\n' "${BASH_VERSION:-unknown}" >&2
  exit 1
fi
for _as_cmd in grep awk sed find date tr mkdir mktemp git; do
  if ! command -v "$_as_cmd" >/dev/null 2>&1; then
    printf 'error: required command not found: %s (AGENTSPACE scripts need the core POSIX toolchain)\n' "$_as_cmd" >&2
    exit 1
  fi
done
unset _as_cmd

# Deterministic byte behavior for mixed CJK/ASCII content: under the ambient
# locale, regex character classes ([a-z]) and sort collation vary by system.
# LC_ALL=C fixes byte-exact semantics; CJK bytes pass through untouched, so
# display and content are unaffected.
export LC_ALL=C

# ---- Table section headings / status marker constants ----
# These MUST match the actual markdown headings in deployed workspace files.
readonly SEC_TODO="Todo"
readonly SEC_DONE="Done (最近 10 条)"
readonly SEC_PROGRESS="进行中"
readonly SEC_RECENT="最近完成 (10 条)"
readonly SEC_RELATED="相关迭代"
readonly SEC_REGISTERED="已注册模块"
readonly SEC_HANDOFF="Handoffs"
readonly STATUS_TODO="> 状态: todo"
readonly STATUS_PROGRESS="> 状态: 进行中"
# Staleness threshold for handoff [11] / status summary (days unconsumed
# before a handoff is flagged 过时). Single source — doctor.sh and status.sh
# both use it (find -mtime +$((STALE_DAYS-1)) = strictly more than STALE_DAYS-1
# whole days = 7 天以上).
readonly STALE_DAYS="7"
# ---- Placeholder constants (must match template comments exactly; doctor [5] checks drift) ----
# Gate: close-iteration refuses while present. Template: iteration-readme.md "结果"
readonly RESULT_PH_ITER="<!-- 指标 / 结论; 关闭 iteration 前必填 -->"
# Gate: complete-plan refuses while present. Template: plan.md "结果" (first line of 2-line comment)
readonly RESULT_PH_PLAN="<!-- 完成时填写: 一句话结论"
# Warning: doctor flags in-progress readmes while present. Template: iteration-readme.md "当前状态 · 下一步"
readonly RESUME_PH_ITER="<!-- 会话续接块:"

as_die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# Atomic replace: mv is same-filesystem ($AS_TMPDIR lives in $AS_ROOT) and
# atomic, so a crash cannot truncate the target mid-write. mktemp creates
# 0600 — copy the target's mode onto the tmp first so permissions are kept.
as_atomic_write() {
  local file="$1" tmp="$2"
  if [ -e "$file" ]; then
    chmod "$(stat -f '%Lp' "$file" 2>/dev/null || stat -c '%a' "$file" 2>/dev/null || printf '644')" "$tmp" 2>/dev/null || true
  fi
  mv -f "$tmp" "$file"
}

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

# Numeric ids from script-managed table rows (entry view + full index).
# Union scan prevents reusing an id that only exists as an orphan table row.
as_row_ids() {
  grep -hoE '^\| *[0-9]+' "$@" 2>/dev/null | grep -oE '[0-9]+' || true
}

# Next plan index (scan plan/todo + plan/done + tables, max+1, monotonically increasing, never reused).
as_next_plan_id() {
  local max=0 f base n
  while IFS= read -r -d '' f; do
    base="$(basename "$f")"
    n="${base%%-*}"
    [[ "$n" =~ ^[0-9]+$ ]] || continue
    (( 10#$n > max )) && max=$((10#$n))
  done < <(find "$AS_ROOT/plan/todo" "$AS_ROOT/plan/done" -maxdepth 1 \
    -name '[0-9][0-9][0-9][0-9]-*.md' -print0 2>/dev/null)
  while IFS= read -r n; do
    [[ "$n" =~ ^[0-9]+$ ]] || continue
    (( 10#$n > max )) && max=$((10#$n))
  done < <(as_row_ids "$AS_ROOT/plan.md" "$AS_ROOT/plan/index.md")
  printf "%04d" $((max + 1))
}

# Next iteration index (scan iterations/iteration_NNNN + tables).
as_next_iteration_id() {
  local max=0 d base n
  while IFS= read -r -d '' d; do
    base="$(basename "$d")"
    n="${base#iteration_}"
    [[ "$n" =~ ^[0-9]+$ ]] || continue
    (( 10#$n > max )) && max=$((10#$n))
  done < <(find "$AS_ROOT/iterations" -maxdepth 1 -type d \
    -name 'iteration_[0-9][0-9][0-9][0-9]*' -print0 2>/dev/null)
  while IFS= read -r n; do
    [[ "$n" =~ ^[0-9]+$ ]] || continue
    (( 10#$n > max )) && max=$((10#$n))
  done < <(as_row_ids "$AS_ROOT/iterations.md" "$AS_ROOT/iterations/index.md")
  printf "%04d" $((max + 1))
}

# Insert a row after the separator line of a "## SECTION" table (becomes first data row).
# Usage: as_insert_row <file> <section> <row>
# NOTE: the row travels via ENVIRON, not -v — awk -v would unescape the `\|`
# cells produced by as_cell, silently corrupting escaped pipes.
as_insert_row() {
  local file="$1" tmp
  tmp="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
  ROW="$3" awk -v sec="## $2" '
    $0 == sec { in_sec=1; print; next }
    /^## / { in_sec=0 }
    in_sec && /^\|[ :|-]+\|$/ && !inserted { print; print ENVIRON["ROW"]; inserted=1; next }
    { print }
    END { if (!inserted) exit 3 }
  ' "$file" > "$tmp" || { rm -f "$tmp"; as_die "Table section not found: ## $2 ($file)"; }
  as_atomic_write "$file" "$tmp"
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
  ' "$file" > "$tmp" && as_atomic_write "$file" "$tmp"
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
    $0 ~ ("^" sec "[[:space:]]*$") { in_sec=1; print; next }
    /^## / { in_sec=0 }
    in_sec && $0 ~ pat { next }
    { print }
  ' "$file" > "$tmp" && as_atomic_write "$file" "$tmp"
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
  ' "$file" > "$tmp" && as_atomic_write "$file" "$tmp"
}

# Read the Nth |-delimited field of the row whose first column equals id.
# Escape-aware: \| cells are shielded before splitting and restored verbatim,
# so a title/desc containing an escaped pipe cannot shift the column positions.
# Usage: as_row_cell <file> <id> <colnum>
as_row_cell() {
  [[ "$2" =~ ^[0-9]+$ ]] || as_die "as_row_cell: id must be numeric: $2"
  local esc
  esc="$(printf '\037')"
  sed "s/\\\\|/$esc/g" "$1" | awk -F'|' -v id="$2" -v c="$3" -v esc="$esc" '
    BEGIN { pat="^\\| *" id " *\\|" }
    $0 ~ pat {
      gsub(/^ +| +$/, "", $c)
      gsub(esc, "\\|", $c)
      print $c
      exit
    }
  '
}

# Fill template placeholders {{ID}} {{TITLE}} {{DATE}} {{PLAN_ID}} {{NAME}} {{PURPOSE}}.
# Usage: PH_ID=.. PH_TITLE=.. as_fill_template <src> <dst>
# Intentionally direct (no tmp+mv): dst is always a NEW file — there is no
# existing content that a crash could truncate.
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
  as_atomic_write "$file" "$tmp"
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
  as_atomic_write "$file" "$tmp"
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
  as_atomic_write "$file" "$tmp"
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
  as_atomic_write "$file" "$tmp"
}

# ---- Concurrency lock + temp cleanup ----
# mkdir-based spinlock called by the write scripts.
# Also creates $AS_TMPDIR and installs an EXIT trap to clean both.
# Stale-lock recovery: a SIGKILLed writer leaves the lock behind and every
# subsequent writer would spin forever. A lock whose owner PID is dead is
# stale; a pid-less lock (crash mid-acquire) older than the grace window is
# treated as stale too. A pid file that is empty / unreadable / non-numeric
# (crash between mkdir and pid write, or a partial write) also falls back to
# the mtime grace path — never spin forever on it (fail-open). Liveness is
# checked with `ps -p PID -o pid=` (empty output = no such process), which
# answers across users where `kill -0` would fail with EPERM.
as_lock() {
  local owner stale pidtmp
  while ! mkdir "$AS_ROOT/.scripts.lock" 2>/dev/null; do
    owner="$(cat "$AS_ROOT/.scripts.lock/pid" 2>/dev/null || true)"
    stale=""
    if [ -n "$owner" ] && [[ "$owner" =~ ^[0-9]+$ ]]; then
      # parseable owner PID: stale iff the process no longer exists
      [ -n "$(ps -p "$owner" -o pid= 2>/dev/null)" ] || stale=1
    elif [ -n "$(find "$AS_ROOT/.scripts.lock" -mmin +5 2>/dev/null | head -1)" ]; then
      # pid file missing / empty / unreadable / non-numeric → mtime grace path
      stale=1
    fi
    if [ -n "$stale" ]; then
      # Atomic claim: mv IS the claim — exactly one waiter wins it; losers
      # find the source gone, re-loop, and see the new holder's live lock.
      # Never `rm -rf` the lock in place: a concurrent claimant could then
      # delete a freshly re-acquired live lock.
      if mv "$AS_ROOT/.scripts.lock" "$AS_ROOT/.scripts.lock.stale.$$" 2>/dev/null; then
        rm -rf "$AS_ROOT/.scripts.lock.stale.$$"
      fi
      continue
    fi
    sleep 0.2
  done
  # Write the owner PID atomically (tmp + mv): a crash mid-write can never
  # leave an empty or half-written pid file behind.
  pidtmp="$(mktemp "$AS_ROOT/.scripts.lock/pid.XXXXXXXX")"
  printf '%s' "$$" > "$pidtmp"
  mv -f "$pidtmp" "$AS_ROOT/.scripts.lock/pid"
  AS_TMPDIR="$(mktemp -d "$AS_ROOT/.scripts-tmp.XXXXXXXX")"
  trap '
    rm -rf "$AS_TMPDIR" 2>/dev/null || true
    # Ownership guard: only the recorded owner PID may tear the lock down,
    # so a process whose lock was legitimately taken over (stale-claim race)
    # can never delete the new holder live lock on EXIT.
    if [ "$(cat "$AS_ROOT/.scripts.lock/pid" 2>/dev/null || true)" = "$$" ]; then
      rm -rf "$AS_ROOT/.scripts.lock" 2>/dev/null || true
    fi
  ' EXIT
}
