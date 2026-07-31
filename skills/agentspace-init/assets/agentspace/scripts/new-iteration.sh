#!/usr/bin/env bash
# Create a new iteration: allocate global index, create iteration_NNNN/{readme.md, data/},
# flip latest symlink, insert row in iterations.md 进行中 table, append to iterations/index.md,
# and append a reference to the parent plan's "相关迭代" section.
# Each iteration belongs to exactly one plan (plan-id required).
# Usage: new-iteration.sh <plan-id> "iteration content"
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

PLAN_ARG="${1:-}"
TITLE="${2:-}"
[ -n "$PLAN_ARG" ] && [ -n "$TITLE" ] || as_die "Usage: new-iteration.sh <plan-id> \"iteration content\""

PLAN_ID="$(as_norm_id "$PLAN_ARG")"
PLAN_FILE=""
# Only allow creating iterations for plans in todo (not completed)
for m in "$AS_ROOT"/plan/todo/"$PLAN_ID"-*.md; do
  [ -e "$m" ] && { PLAN_FILE="$m"; break; }
done
[ -n "$PLAN_FILE" ] || as_die "plan:$PLAN_ID does not exist or is completed (iteration must belong to an active plan)"

ID="$(as_next_iteration_id)"
DATE="$(as_today)"
CELL="$(as_cell "$TITLE")"
DIR="iterations/iteration_$ID"

as_lock

mkdir -p "$AS_ROOT/$DIR/data"
PH_ID="$ID" PH_PLAN_ID="$PLAN_ID" PH_TITLE="$TITLE" PH_DATE="$DATE" \
  as_fill_template "$AS_ROOT/templates/iteration-readme.md" "$AS_ROOT/$DIR/readme.md"

# latest symlink points to the newest iteration
ln -sfn "iteration_$ID" "$AS_ROOT/iterations/latest"

as_insert_row "$AS_ROOT/iterations.md" "$SEC_PROGRESS" \
  "| $ID | plan:$PLAN_ID | $CELL | $DATE | [$DIR/readme.md]($DIR/readme.md) |"

echo "| $ID | plan:$PLAN_ID | $CELL | 进行中 | $DATE |  |  | [$DIR/readme.md]($DIR/readme.md) |" \
  >> "$AS_ROOT/iterations/index.md"

# Append to plan document's "相关迭代" section
ENTRY="- [iteration_$ID](../../iterations/iteration_$ID/readme.md) — $CELL ($DATE)"
as_append_to_section "$PLAN_FILE" "$SEC_RELATED" "$ENTRY"

echo "iteration_$ID created (plan:$PLAN_ID) → $DIR/"
echo "Next: update readme goal/change-summary; place experiment output in $DIR/data/"
