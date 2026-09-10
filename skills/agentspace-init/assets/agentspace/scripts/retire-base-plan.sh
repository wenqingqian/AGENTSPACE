#!/usr/bin/env bash
# Retire a base plan: mark it 被取代 (superseded, optionally naming the
# successor) or 废弃 (voided) in the plan/index.md Base row and drop it from
# the plan.md Base view. The FILE is never touched — retired base plans stay
# in plan/base/ as immutable history.
# Usage: retire-base-plan.sh <id> <replaced|voided> "reason" [--by NNNN]
#   Retiring is user-driven only: the agent reports an unimplementable or
#   incorrect base plan and the USER decides the direction change. --by (the
#   successor) must already be 生效 — activate the successor first.
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

ID="$(as_norm_id "${1:-}")"
KEY="base:$ID"
STATUS_ARG="${2:-}"
REASON="${3:-}"
BY_ARG=""
shift 3 || as_die "Usage: retire-base-plan.sh <id> <replaced|voided> \"reason\" [--by NNNN]"
while [ $# -gt 0 ]; do
  case "$1" in
    --by) [ $# -ge 2 ] || as_die "--by needs a value"; BY_ARG="$2"; shift 2 ;;
    *) as_die "unknown argument: $1 (Usage: retire-base-plan.sh <id> <replaced|voided> \"reason\" [--by NNNN])" ;;
  esac
done

case "$STATUS_ARG" in
  replaced) STATUS_CN="被取代" ;;
  voided)   STATUS_CN="废弃" ;;
  *) as_die "Status must be replaced|voided" ;;
esac
[ -n "$REASON" ] || as_die "Usage: retire-base-plan.sh <id> <replaced|voided> \"reason\" [--by NNNN]"

STATE="$(as_row_cell "$AS_ROOT/plan/index.md" "$KEY" 4)"
[ -n "$STATE" ] || as_die "$KEY not found in plan/index.md Base section"
case "$STATUS_CN:$STATE" in
  被取代:生效) ;;
  废弃:生效|废弃:待审核) ;;
  *) as_die "$KEY state is \"$STATE\" — only a 生效 (or, for 废弃, 待审核) base plan can be retired" ;;
esac
if [ "$STATUS_CN" = "被取代" ] && [ -z "$BY_ARG" ]; then
  as_die "被取代 requires --by <successor id> (the new base plan that supersedes this one)"
fi

NOTE_CELL="$(as_cell "$REASON")"
if [ -n "$BY_ARG" ]; then
  BY_ID="$(as_norm_id "$BY_ARG")"
  [ "$BY_ID" != "$ID" ] || as_die "--by must name a DIFFERENT base plan (a successor cannot be itself)"
  BY_STATE="$(as_row_cell "$AS_ROOT/plan/index.md" "base:$BY_ID" 4)"
  [ "$BY_STATE" = "生效" ] \
    || as_die "base:$BY_ID is \"$BY_STATE\" — the successor must already be 生效 (activate it first)"
  NOTE_CELL="$NOTE_CELL → base:$BY_ID"
fi

as_lock

# plan/index.md Base row: $4=状态 $8=备注 (escape-aware: the reason cell may
# carry escaped pipes — same shield discipline as complete-plan.sh).
tmp="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
ESC="$(printf '\037')"
sed "s/\\\\|/$ESC/g" "$AS_ROOT/plan/index.md" \
  | NOTE_CELL="$NOTE_CELL" awk -F'|' -v id="$KEY" -v st="$STATUS_CN" -v esc="$ESC" '
    BEGIN { pat="^\\| *" id " *\\|"; found=0; n=ENVIRON["NOTE_CELL"] }
    $0 ~ pat {
      $4=" " st " "; $8=" " n " "
      out=$1; for (i=2; i<=NF; i++) out=out "|" $i
      print out; found=1; next
    }
    { print }
    END { if (!found) exit 3 }
  ' | sed "s/$ESC/\\\\|/g" > "$tmp" || { rm -f "$tmp"; as_die "index missing $KEY"; }
as_atomic_write "$AS_ROOT/plan/index.md" "$tmp"

# Entry view: retired anchors leave the Base view (full history stays in the
# index; the file itself is never modified).
as_remove_row "$AS_ROOT/plan.md" "$KEY"

echo "$KEY → $STATUS_CN ($NOTE_CELL)"
echo "note: the base plan file stays in plan/base/ unchanged — retired base plans are immutable history"
