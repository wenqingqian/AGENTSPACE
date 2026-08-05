#!/usr/bin/env bash
# handoff.sh — produce / list / consume one-shot session handoffs.
#
#   handoff.sh --produce --name <name> [--description <desc>]
#       Validate the name/location are free, create handoff_<name>.md from the
#       template, register a row in handoff/index.md. Conflicts REFUSE with an
#       error (no -2/-3 auto-renaming — names must stay meaningful; the
#       skill/agent supplies a semantic name, this script only enforces).
#   handoff.sh --list
#       Print the index rows (name | description | location | time).
#   handoff.sh --consume [--keep] --name <name>
#       Remove the handoff file and its index row (both kept with --keep).
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

ACTION=""
NAME=""
DESC=""
KEEP=0

while [ $# -gt 0 ]; do
  case "$1" in
    --produce) ACTION="produce" ;;
    --consume) ACTION="consume" ;;
    --list) ACTION="list" ;;
    --name) [ $# -ge 2 ] || as_die "--name requires a value"; NAME="$2"; shift ;;
    --description) [ $# -ge 2 ] || as_die "--description requires a value"; DESC="$2"; shift ;;
    --keep) KEEP=1 ;;
    *) as_die "unknown option: $1 (usage: --produce --name X [--description Y] | --list | --consume [--keep] --name X)" ;;
  esac
  shift
done

[ -n "$ACTION" ] || as_die "usage: handoff.sh --produce|--list|--consume [--keep] [--name X] [--description Y]"

HANDOFF_DIR="$AS_ROOT/handoff"
INDEX="$HANDOFF_DIR/index.md"

# Location slug: spaces -> _, drop chars unsafe for filenames/globs (keeps CJK).
# The index keeps the original name (may contain spaces/CJK); only the
# location is normalized. Near-collisions ("a b" vs "a_b") are refused at
# produce time with a clear error.
as_handoff_slug() { printf '%s' "$1" | tr ' ' '_' | tr -d '/\\:*?"<>|[]'; }

# Names live in a | delimited table — | and control chars are rejected up
# front so stored rows, conflict checks and consume all agree on one form.
# "name" is reserved: a handoff named "name" collides with the index table
# header filter used by --list, doctor [10]/[11] and status.sh (invisible row).
as_handoff_check_name() {
  case "$1" in
    *'|'*) as_die "handoff name must not contain '|': $1" ;;
    *$'\n'*|*$'\r'*|*$'\t'*) as_die "handoff name must not contain control characters: $1" ;;
    name) as_die "handoff name 'name' is reserved (index header collision): $1" ;;
  esac
}

case "$ACTION" in
  list)
    # data rows only (skip header + separator); print name|description|location|time
    awk -F'|' '
      /^\| *---/ || /^\| *name *\|/ { next }
      /^\| [^|]+ \|/ {
        gsub(/^ +| +$/, "", $2); gsub(/^ +| +$/, "", $3)
        gsub(/^ +| +$/, "", $4); gsub(/^ +| +$/, "", $5)
        print "- " $2 " | " $3 " | " $4 " | " $5
      }
    ' "$INDEX" 2>/dev/null || true
    ;;

  produce)
    [ -n "$NAME" ] || NAME="session-$(date +%Y%m%d-%H%M%S)"
    as_handoff_check_name "$NAME"
    LOC="handoff_$(as_handoff_slug "$NAME").md"
    as_lock
    # index.md may be absent in workspaces upgraded before v0.4.0 — init it
    if [ ! -f "$INDEX" ]; then
      cat > "$INDEX" <<EOF
# Handoff 索引

> 一次性会话交接文件索引, 由 scripts/handoff.sh 维护, 请勿手工编辑。
> 生成: /agentspace-handoff-produce; 消费: /agentspace-handoff-consume。

## $SEC_HANDOFF

| name | description | location | time |
| --- | --- | --- | --- |
EOF
    fi
    # Conflict check INSIDE the lock — refuse, never auto-rename (-2/-3
    # destroys meaning); a near-collision slug is refused the same way
    if grep -qF "| $NAME |" "$INDEX"; then
      as_die "handoff name already indexed: $NAME (see $INDEX) — pick a distinct name"
    fi
    if [ -e "$HANDOFF_DIR/$LOC" ]; then
      as_die "handoff location already exists: $LOC — pick a distinct name"
    fi
    if ! PH_NAME="$NAME" PH_DATE="$(as_today)" \
      as_fill_template "$AS_ROOT/templates/handoff.md" "$HANDOFF_DIR/$LOC"; then
      as_die "failed to create handoff file: $LOC"
    fi
    if ! as_insert_row "$INDEX" "$SEC_HANDOFF" \
      "| $NAME | $(as_cell "$DESC") | $LOC | $(as_today) |"; then
      rm -f "$HANDOFF_DIR/$LOC"   # no orphan on registration failure
      as_die "failed to register handoff in $INDEX"
    fi
    echo "handoff produced → $HANDOFF_DIR/$LOC (indexed)"
    echo "Next: fill the content sections (项目上下文/当前状态/本次会话/下一步/开放问题/引用)"
    ;;

  consume)
    [ -n "$NAME" ] || as_die "consume requires --name (run --list first to see available handoffs)"
    as_handoff_check_name "$NAME"
    LOC="handoff_$(as_handoff_slug "$NAME").md"
    FILE="$HANDOFF_DIR/$LOC"
    [ -f "$INDEX" ] || as_die "handoff index missing: $INDEX"
    # row present? (first column == name, string compare — no regex metachars)
    if ! awk -F'|' -v name="$NAME" '
        /^\| [^|]+ \|/ { c=$2; gsub(/^ +| +$/, "", c); if (c == name) found=1 }
        END { exit found ? 0 : 1 }
      ' "$INDEX"; then
      as_die "handoff not indexed: $NAME (run --list)"
    fi
    [ -f "$FILE" ] || as_die "handoff file missing: $FILE"
    if [ "$KEEP" -eq 1 ]; then
      echo "handoff kept (--keep): $FILE (index row kept)"
      exit 0
    fi
    as_lock
    rm -f "$FILE"
    # remove the index row by first-column string equality, section-scoped
    tmp="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
    awk -F'|' -v sec="## $SEC_HANDOFF" -v name="$NAME" '
      $0 ~ ("^" sec "[[:space:]]*$") { in_sec=1; print; next }
      /^## / { in_sec=0 }
      in_sec && /^\|/ && !done { c=$2; gsub(/^ +| +$/, "", c); if (c == name) { done=1; next } }
      { print }
    ' "$INDEX" > "$tmp" && as_atomic_write "$INDEX" "$tmp"
    echo "handoff consumed → deleted $FILE + index row"
    ;;
esac
