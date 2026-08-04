#!/usr/bin/env bash
# Complete a plan: move file todo→done, update doc header status,
# remove Todo row from plan.md + insert into Done table (truncate to 10),
# update plan/index.md status/result.
# Usage: complete-plan.sh <id> <done|failed|abandoned> "result"
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

ID="$(as_norm_id "${1:-}")"
STATUS_ARG="${2:-}"
RESULT="${3:-}"

case "$STATUS_ARG" in
  done)       STATUS_CN="完成" ;;
  failed)     STATUS_CN="失败" ;;
  abandoned)  STATUS_CN="放弃" ;;
  *) as_die "Status must be done|failed|abandoned" ;;
esac
[ -n "$RESULT" ] || as_die "Usage: complete-plan.sh <id> <done|failed|abandoned> \"result\""

SRC=( "$AS_ROOT"/plan/todo/"$ID"-*.md )
[ -e "${SRC[0]}" ] || as_die "plan:$ID not in plan/todo/ (does not exist or already completed)"

TITLE="$(as_row_cell "$AS_ROOT/plan.md" "$ID" 3)"
[ -n "$TITLE" ] || as_die "plan:$ID not found in plan.md Todo table"
DATE="$(as_today)"
RESULT_CELL="$(as_cell "$RESULT")"

DEST="plan/done/$(basename "${SRC[0]}")"

# Validate all preconditions before first mutation
grep -qx "$STATUS_TODO" "${SRC[0]}" || as_die "plan:$ID status line is not $STATUS_TODO"
# Gate: results section must be filled (template placeholder gone)
if grep -Fq "$RESULT_PH_PLAN" "${SRC[0]}"; then
  as_die "Results section not filled (template placeholder still present): ${SRC[0]}"
fi

as_lock

# plan.md: update tables (remove Todo → insert Done → truncate)
as_remove_row "$AS_ROOT/plan.md" "$ID"
as_insert_row "$AS_ROOT/plan.md" "$SEC_DONE" \
  "| $ID | $TITLE | $STATUS_CN | $RESULT_CELL | $DATE | [$DEST]($DEST) |"
as_truncate_section "$AS_ROOT/plan.md" "$SEC_DONE" 10

# plan/index.md: update status/completed-date/result/link
tmp="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
awk -F'|' -v id="$ID" -v st="$STATUS_CN" -v d="$DATE" -v r="$RESULT_CELL" -v link="[$DEST]($DEST)" '
  BEGIN { pat="^\\| *" id " *\\|"; found=0 }
  $0 ~ pat {
    $4=" " st " "; $6=" " d " "; $7=" " r " "; $8=" " link " "
    out=$1; for (i=2; i<=NF; i++) out=out "|" $i
    print out; found=1; next
  }
  { print }
  END { if (!found) exit 3 }
' "$AS_ROOT/plan/index.md" > "$tmp" || { rm -f "$tmp"; as_die "index missing plan:$ID"; }
cat "$tmp" > "$AS_ROOT/plan/index.md" && rm -f "$tmp"

# Move file + update status line (only after above operations succeed)
mv "${SRC[0]}" "$AS_ROOT/$DEST"
as_replace_line "$AS_ROOT/$DEST" "$STATUS_TODO" "> 状态: $STATUS_CN ($DATE)"

echo "plan:$ID → $STATUS_CN ($DEST)"
# v0.3.2: lesson distillation upgraded from SHOULD to MUST — every completed
# plan's transferable lessons must land in notes/ before the milestone commit
echo "Next [MUST]: review this plan's iterations (结果/code-diff) and distill transferable lessons into notes with source plan:$ID"
