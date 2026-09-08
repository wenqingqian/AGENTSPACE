#!/usr/bin/env bash
# Launch a registered experiment: move manual todo→doing, move row Todo→Doing
# in exp.md (开始日期 = today), update exp/index.md state + link, rewrite the
# manual status line.
# Usage: start-exp.sh <id>
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

ID="$(as_norm_id "${1:-}")"

SRC=( "$AS_ROOT"/exp/todo/exp_"$ID"-*.md )
[ -e "${SRC[0]}" ] || as_die "exp_$ID not in exp/todo/ (does not exist, already running, or already completed)"

TITLE="$(as_row_cell "$AS_ROOT/exp.md" "$ID" 3)"
[ -n "$TITLE" ] || as_die "exp_$ID not found in exp.md Todo table"
DATE="$(as_today)"
DEST="exp/doing/$(basename "${SRC[0]}")"

# Validate all preconditions before first mutation
grep -qx "$STATUS_TODO" "${SRC[0]}" || as_die "exp_$ID status line is not $STATUS_TODO"

as_lock

# exp.md: Todo row → Doing row (link path rewritten to exp/doing/)
as_remove_row_section "$AS_ROOT/exp.md" "$SEC_TODO" "$ID"
as_insert_row "$AS_ROOT/exp.md" "$SEC_EXP_DOING" \
  "| $ID | $TITLE | $DATE | [$DEST]($DEST) |"

# exp/index.md: state cell todo→doing + link cell rewrite. Escape-aware (\| shield),
# ENVIRON for the title-free row edit — same shape as complete-plan's index pass.
tmp="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
ESC="$(printf '\037')"
sed "s/\\\\|/$ESC/g" "$AS_ROOT/exp/index.md" \
  | awk -F'|' -v id="$ID" -v st="doing" -v link="[$DEST]($DEST)" -v esc="$ESC" '
    BEGIN { pat="^\\| *" id " *\\|"; found=0 }
    $0 ~ pat {
      $4=" " st " "; $12=" " link " "
      out=$1; for (i=2; i<=NF; i++) out=out "|" $i
      print out; found=1; next
    }
    { print }
    END { if (!found) exit 3 }
  ' | sed "s/$ESC/\\\\|/g" > "$tmp" || { rm -f "$tmp"; as_die "index missing exp_$ID"; }
as_atomic_write "$AS_ROOT/exp/index.md" "$tmp"

# Move file + update status line (only after the table operations succeed)
mv "${SRC[0]}" "$AS_ROOT/$DEST"
as_replace_line "$AS_ROOT/$DEST" "$STATUS_TODO" "$STATUS_EXP_DOING"

echo "exp_$ID → doing ($DEST)"
echo "Next: full logs/results into exp/exp_data/exp_$ID/ (copy iteration data/ there too when the exp is linked); close with complete-exp.sh $ID <done|failed|abandoned> \"result\""
