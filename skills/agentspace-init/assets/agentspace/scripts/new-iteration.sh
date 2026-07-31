#!/usr/bin/env bash
# 创建新 iteration: 分配全局索引, 建 iteration_NNNN/{readme.md, data/},
# 翻转 latest 软连接, iterations.md 进行中插行, iterations/index.md 追加,
# 并向所属 plan 文档"相关迭代"节追加引用。
# 一个 iteration 必属且仅属一个 plan, 因此 plan-id 必填。
# 用法: new-iteration.sh <plan-id> "本轮内容"
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

PLAN_ARG="${1:-}"
TITLE="${2:-}"
[ -n "$PLAN_ARG" ] && [ -n "$TITLE" ] || as_die "用法: new-iteration.sh <plan-id> \"本轮内容\""

PLAN_ID="$(as_norm_id "$PLAN_ARG")"
PLAN_FILE=""
# Required 8: 仅允许对 todo 中的 plan 创建 iteration
for m in "$AS_ROOT"/plan/todo/"$PLAN_ID"-*.md; do
  [ -e "$m" ] && { PLAN_FILE="$m"; break; }
done
[ -n "$PLAN_FILE" ] || as_die "plan:$PLAN_ID 不存在或已完成(一个 iteration 必须属于一个进行中的 plan)"

ID="$(as_next_iteration_id)"
DATE="$(as_today)"
CELL="$(as_cell "$TITLE")"
DIR="iterations/iteration_$ID"

as_lock

mkdir -p "$AS_ROOT/$DIR/data"
PH_ID="$ID" PH_PLAN_ID="$PLAN_ID" PH_TITLE="$TITLE" PH_DATE="$DATE" \
  as_fill_template "$AS_ROOT/templates/iteration-readme.md" "$AS_ROOT/$DIR/readme.md"

# latest 软连接指向最新一轮
ln -sfn "iteration_$ID" "$AS_ROOT/iterations/latest"

as_insert_row "$AS_ROOT/iterations.md" "$SEC_PROGRESS" \
  "| $ID | plan:$PLAN_ID | $CELL | $DATE | [$DIR/readme.md]($DIR/readme.md) |"

echo "| $ID | plan:$PLAN_ID | $CELL | 进行中 | $DATE |  |  | [$DIR/readme.md]($DIR/readme.md) |" \
  >> "$AS_ROOT/iterations/index.md"

  # plan 文档"相关迭代"节末尾追加(不再用 as_insert_after 压在注释上方, Nit 2)
  ENTRY="- [iteration_$ID](../../iterations/iteration_$ID/readme.md) — $CELL ($DATE)"
  as_append_to_section "$PLAN_FILE" "$SEC_RELATED" "$ENTRY"

echo "iteration_$ID 已创建 (plan:$PLAN_ID) → $DIR/"
echo "下一步: 更新 readme 的目标/改动摘要; 实验产物按 data 三策略放入 $DIR/data/"
