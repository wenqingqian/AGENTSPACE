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

# Lock BEFORE any workspace-state read (t21): the plan-todo glob and the id
# allocation must sit in the same critical section as the writes — computing
# the id pre-lock let every concurrent creator read the same "next id" and
# collide on the same iteration_NNNN.
as_lock

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

mkdir -p "$AS_ROOT/$DIR/data"
PH_ID="$ID" PH_PLAN_ID="$PLAN_ID" PH_TITLE="$TITLE" PH_DATE="$DATE" \
  as_fill_template "$AS_ROOT/templates/iteration-readme.md" "$AS_ROOT/$DIR/readme.md"

# latest symlink points to the newest iteration
ln -sfn "iteration_$ID" "$AS_ROOT/iterations/latest"

# Record host start commit in the readme 环境 section.
# Guarded: host must be a git repo, section must exist, line must not already be present.
HOST_HEAD="$(as_host_head)"
if [ -n "$HOST_HEAD" ] && grep -q '^## 环境$' "$AS_ROOT/$DIR/readme.md" \
   && ! grep -q '^> 宿主起始 commit: ' "$AS_ROOT/$DIR/readme.md"; then
  as_insert_after "$AS_ROOT/$DIR/readme.md" "## 环境" "> 宿主起始 commit: $HOST_HEAD"
fi

as_insert_row "$AS_ROOT/iterations.md" "$SEC_PROGRESS" \
  "| $ID | plan:$PLAN_ID | $CELL | $DATE | [$DIR/readme.md]($DIR/readme.md) |"

# Index append via tmp+mv: atomic (audit R8) — same rationale as new-plan.sh
tmp="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
{ cat "$AS_ROOT/iterations/index.md" 2>/dev/null || true; echo "| $ID | plan:$PLAN_ID | $CELL | 进行中 | $DATE |  |  | [$DIR/readme.md]($DIR/readme.md) |"; } > "$tmp" \
  && as_atomic_write "$AS_ROOT/iterations/index.md" "$tmp"

# Append to plan document's "相关迭代" section
ENTRY="- [iteration_$ID](../../iterations/iteration_$ID/readme.md) — $CELL ($DATE)"
as_append_to_section "$PLAN_FILE" "$SEC_RELATED" "$ENTRY"

echo "iteration_$ID created (plan:$PLAN_ID) → $DIR/"
echo "Next: update readme goal/change-summary; place experiment output in $DIR/data/"
