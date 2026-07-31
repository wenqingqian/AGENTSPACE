#!/usr/bin/env bash
# 创建新 plan: 分配全局索引, 从模板实例化 plan/todo/NNNN-slug.md,
# 在 plan.md Todo 表插行, 在 plan/index.md 追加全量记录。
# 用法: new-plan.sh "计划标题"
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

TITLE="${1:-}"
[ -n "$TITLE" ] || as_die "用法: new-plan.sh \"计划标题\""

ID="$(as_next_plan_id)"
DATE="$(as_today)"
CELL="$(as_cell "$TITLE")"
# Required 4+5: 先规范化空白(含 \n\r\t)再过滤破坏 markdown 与文件名的字符
SLUG="$(printf '%s' "$TITLE" | tr '\n\r\t' '   ' | tr -s ' ' | tr ' ' '-' | tr -d '/\\?*":<>|()[]#!' | cut -c1-40)"
[ -n "$SLUG" ] || SLUG="plan"
FILE="plan/todo/${ID}-${SLUG}.md"

as_lock

PH_ID="$ID" PH_TITLE="$TITLE" PH_DATE="$DATE" \
  as_fill_template "$AS_ROOT/templates/plan.md" "$AS_ROOT/$FILE"

as_insert_row "$AS_ROOT/plan.md" "$SEC_TODO" \
  "| $ID | $CELL | $DATE | [$FILE]($FILE) |"

echo "| $ID | $CELL | todo | $DATE |  |  | [$FILE]($FILE) |" >> "$AS_ROOT/plan/index.md"

echo "plan:$ID 已创建 → $FILE"
echo "下一步: 撰写该文件的目标/背景/方案步骤"
