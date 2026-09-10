#!/usr/bin/env bash
# Create a new plan: allocate global index, instantiate plan/todo/NNNN-slug.md,
# insert row in plan.md Todo table, append to plan/index.md.
# Usage: new-plan.sh "Plan title" [--base NNNN[,NNNN...]]
#   The title must yield a compliant slug — lowercase english words, digits
#   and single hyphens only; CJK / uppercase / punctuation titles are refused
#   before anything is written (new plans only — existing plan files are
#   never touched).
#   --base links the plan to one or more base plans (direction anchors): each
#   id must exist in the plan/index.md Base section; the link lands in the
#   基准 column of plan.md Todo and plan/index.md.
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

TITLE="${1:-}"
[ -n "$TITLE" ] || as_die "Usage: new-plan.sh \"Plan title\" [--base NNNN[,NNNN...]]"
shift || true

BASE_ARG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --base) [ $# -ge 2 ] || as_die "--base needs a value"; BASE_ARG="$2"; shift 2 ;;
    *) as_die "unknown argument: $1 (Usage: new-plan.sh \"Plan title\" [--base NNNN[,NNNN...]])" ;;
  esac
done

# Slug derivation + contract — as_slug_of dies before any write on a
# non-compliant title (see lib.sh).
SLUG="$(as_slug_of "$TITLE" plan)"

# Lock BEFORE id allocation (t21): as_next_plan_id reads the index — computing
# it pre-lock let every concurrent creator read the same "next id" and collide
# on the same plan/todo/NNNN file. The lock covers the whole read-compute-write.
as_lock

# --base: comma-separated ids, each normalized; the base plan must exist in the
# plan/index.md Base section (any state — doctor [17] reports links to a
# non-active base for the user to adjudicate; a base may be replaced while
# derived plans stay open). Cell form "base:NNNN, base:NNNN", or "-" unlinked.
BASE_CELL="-"
if [ -n "$BASE_ARG" ]; then
  BASE_CELL=""
  IFS=',' read -r -a _bids <<< "$BASE_ARG"
  for b in "${_bids[@]}"; do
    [ -n "$b" ] || continue
    bid="$(as_norm_id "$b")"
    grep -q "^| *base:$bid *|" "$AS_ROOT/plan/index.md" 2>/dev/null \
      || as_die "base:$bid not found in plan/index.md Base section (linked base plans must exist)"
    BASE_CELL="${BASE_CELL:+$BASE_CELL, }base:$bid"
  done
  [ -n "$BASE_CELL" ] || BASE_CELL="-"
fi

ID="$(as_next_plan_id)"
DATE="$(as_today)"
CELL="$(as_cell "$TITLE")"
FILE="plan/todo/${ID}-${SLUG}.md"

PH_ID="$ID" PH_TITLE="$TITLE" PH_DATE="$DATE" \
  as_fill_template "$AS_ROOT/templates/plan.md" "$AS_ROOT/$FILE"

as_insert_row "$AS_ROOT/plan.md" "$SEC_TODO" \
  "| $ID | $CELL | $BASE_CELL | $DATE | [$FILE]($FILE) |"

# Index append via tmp+mv: atomic (audit R8) — a `>>` crash window leaves a
# half-written index row that doctor [2] cannot repair
tmp="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
{ cat "$AS_ROOT/plan/index.md" 2>/dev/null || true; echo "| $ID | $CELL | todo | $BASE_CELL | $DATE |  |  | [$FILE]($FILE) |"; } > "$tmp" \
  && as_atomic_write "$AS_ROOT/plan/index.md" "$tmp"

echo "plan:$ID created → $FILE (base: $BASE_CELL)"
echo "Next: write the goal/background/plan-steps in that file"
