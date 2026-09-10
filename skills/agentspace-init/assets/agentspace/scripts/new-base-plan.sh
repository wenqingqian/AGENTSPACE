#!/usr/bin/env bash
# Create a new base plan (direction anchor): allocate the base counter,
# instantiate plan/base/NNNN-slug.md as a 待审核 draft, insert a row in the
# plan.md Base table, append to the plan/index.md Base section.
# Usage: new-base-plan.sh "Direction title"
#   Creation is user-driven and review-gated: after this script the agent
#   fills the draft (方向/约束/边界), then ENDS THE SESSION so the user can
#   review the file with inline comments — never the agent-plan-mode review.
#   The file is mutable while 待审核; activation (activate-base-plan.sh, next
#   session, explicit user approval only) pins its checksum and freezes it.
#   The title slug contract is the same as new-plan.sh.
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

TITLE="${1:-}"
[ -n "$TITLE" ] || as_die "Usage: new-base-plan.sh \"Direction title\""

SLUG="$(as_slug_of "$TITLE" base)"

# Lock BEFORE id allocation (t21 contract — same critical-section shape as
# new-plan/new-exp).
as_lock

ID="$(as_next_base_id)"
DATE="$(as_today)"
CELL="$(as_cell "$TITLE")"
FILE="plan/base/${ID}-${SLUG}.md"
[ -e "$AS_ROOT/$FILE" ] && as_die "$FILE already exists (id allocation collision — run doctor.sh)"

PH_ID="$ID" PH_TITLE="$TITLE" PH_DATE="$DATE" \
  as_fill_template "$AS_ROOT/templates/base-plan.md" "$AS_ROOT/$FILE"

# Entry view: newest first inside the Base section (same shape as Todo).
as_insert_row "$AS_ROOT/plan.md" "$SEC_BASE" \
  "| base:$ID | $CELL | 待审核 | $DATE | [$FILE]($FILE) |"

# Full index: Base section, chronological append. 8 columns; 审核日期/校验/备注
# stay empty until activation / retirement.
as_append_to_section "$AS_ROOT/plan/index.md" "$SEC_BASE" \
  "| base:$ID | $CELL | 待审核 | $DATE |  |  |  | [$FILE]($FILE) |"

echo "base:$ID 待审核 → $FILE"
echo "Next: fill the 方向/约束/边界 sections in that file (the draft is mutable until activation)"
echo "Next [MUST]: base plan 创建与修改必须呈交用户审核 — 写好后直接结束本会话, 请用户在该文件上以评论形式反馈; 不走 agent plan 模式审核。用户批准后(下一会话)运行 activate-base-plan.sh $ID"
