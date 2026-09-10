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

# plan/index.md: update status/completed-date/result/link. Columns (awk
# -F'|'): $4=状态 $7=完成日期 $8=结果 $9=链接 ($5=基准 stays untouched).
# Escape-aware: \| cells (result) are shielded before the -F'|' split and
# restored after; RESULT_CELL travels via ENVIRON, not -v (awk -v unescapes
# the \| cells produced by as_cell — same hazard as lib.sh::as_insert_row).
tmp="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
ESC="$(printf '\037')"
sed "s/\\\\|/$ESC/g" "$AS_ROOT/plan/index.md" \
  | RESULT_CELL="$RESULT_CELL" awk -F'|' -v id="$ID" -v st="$STATUS_CN" -v d="$DATE" -v link="[$DEST]($DEST)" -v esc="$ESC" '
    BEGIN { pat="^\\| *" id " *\\|"; found=0; r=ENVIRON["RESULT_CELL"] }
    $0 ~ pat {
      $4=" " st " "; $7=" " d " "; $8=" " r " "; $9=" " link " "
      out=$1; for (i=2; i<=NF; i++) out=out "|" $i
      print out; found=1; next
    }
    { print }
    END { if (!found) exit 3 }
  ' | sed "s/$ESC/\\\\|/g" > "$tmp" || { rm -f "$tmp"; as_die "index missing plan:$ID"; }
as_atomic_write "$AS_ROOT/plan/index.md" "$tmp"

# Move file + update status line (only after above operations succeed)
mv "${SRC[0]}" "$AS_ROOT/$DEST"
as_replace_line "$AS_ROOT/$DEST" "$STATUS_TODO" "> 状态: $STATUS_CN ($DATE)"

echo "plan:$ID → $STATUS_CN ($DEST)"
# Soft reminder: linked open experiments survive a plan's closure (an exp may
# outlive its plan); reverse lookup on exp/index.md 关联 plan column. Escape-
# aware read (\| shielded before the -F'|' split), same as status.sh.
_RE="$(printf '\037')"
OPEN_EXPS="$(sed "s/\\\\|/$_RE/g" "$AS_ROOT/exp/index.md" 2>/dev/null | awk -F'|' -v pid="plan:$ID" '
  /^\| [0-9]/ {
    pl=$5; gsub(/^ +| +$/, "", pl); state=$4; gsub(/^ +| +$/, "", state)
    if (index(pl, pid) && (state == "todo" || state == "doing")) n++
  }
  END { print n+0 }
' || true)"
if [ "${OPEN_EXPS:-0}" -gt 0 ]; then
  echo "note: $OPEN_EXPS linked open experiment(s) reference plan:$ID — they stay open (an exp may outlive its plan); remember to close them separately"
fi
# v0.3.2: lesson distillation upgraded from SHOULD to MUST — every completed
# plan's transferable lessons must land in notes/ before the milestone commit
echo "Next [MUST]: review this plan's iterations (结果/code-diff) and distill transferable lessons into notes with source plan:$ID"
