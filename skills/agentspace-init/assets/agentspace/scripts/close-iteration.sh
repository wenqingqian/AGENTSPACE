#!/usr/bin/env bash
# Close an iteration: move row from 进行中 to 最近完成 (truncate to 10),
# update iterations/index.md status/result, freeze readme and append close log.
# Usage: close-iteration.sh <id> "result"
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

ID="$(as_norm_id "${1:-}")"
RESULT="${2:-}"
[ -n "$RESULT" ] || as_die "Usage: close-iteration.sh <id> \"result\""

DIR="iterations/iteration_$ID"
README="$AS_ROOT/$DIR/readme.md"
[ -f "$README" ] || as_die "iteration_$ID does not exist"
# Gate: exact match on status line
grep -qx "$STATUS_PROGRESS" "$README" || as_die "iteration_$ID is not in progress (already closed or status anomaly)"
# Gate: results section must be filled (template placeholder gone)
if grep -Fq "$RESULT_PH_ITER" "$README"; then
  as_die "Results section not filled (template placeholder still present): $README"
fi

PLANREF="$(as_row_cell "$AS_ROOT/iterations.md" "$ID" 3)"
TITLE="$(as_row_cell "$AS_ROOT/iterations.md" "$ID" 4)"
[ -n "$TITLE" ] || as_die "iteration_$ID not found in iterations.md 进行中 table"
DATE="$(as_today)"
RESULT_CELL="$(as_cell "$RESULT")"

as_lock

# iterations.md: remove 进行中 row, insert into 最近完成, truncate to 10
as_remove_row "$AS_ROOT/iterations.md" "$ID"
as_insert_row "$AS_ROOT/iterations.md" "$SEC_RECENT" \
  "| $ID | $PLANREF | $TITLE | $RESULT_CELL | $DATE | [$DIR/readme.md]($DIR/readme.md) |"
as_truncate_section "$AS_ROOT/iterations.md" "$SEC_RECENT" 10

# iterations/index.md: update status/completed-date/result
tmp="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
awk -F'|' -v id="$ID" -v d="$DATE" -v r="$RESULT_CELL" '
  BEGIN { pat="^\\| *" id " *\\|"; found=0 }
  $0 ~ pat {
    $5=" 已完成 "; $7=" " d " "; $8=" " r " "
    out=$1; for (i=2; i<=NF; i++) out=out "|" $i
    print out; found=1; next
  }
  { print }
  END { if (!found) exit 3 }
' "$AS_ROOT/iterations/index.md" > "$tmp" || { rm -f "$tmp"; as_die "iterations/index.md missing iteration_$ID"; }
cat "$tmp" > "$AS_ROOT/iterations/index.md" && rm -f "$tmp"

# Atomic: replace status line + append close log in single awk pass
tmp2="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
awk -v status_old="$STATUS_PROGRESS" -v status_new="> 状态: 已完成 ($DATE)" -v log_line="- $DATE 关闭: $RESULT_CELL" '
  $0 == status_old && !done { print status_new; done=1; next }
  { print }
  END {
    if (!done) exit 3
    print log_line
  }
' "$README" > "$tmp2" || { rm -f "$tmp2"; as_die "readme status line $STATUS_PROGRESS not found"; }
cat "$tmp2" > "$README" && rm -f "$tmp2"

echo "iteration_$ID closed → $DIR/readme.md (frozen)"
