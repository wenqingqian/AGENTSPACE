#!/usr/bin/env bash
# 完成 plan: 文件 todo→done, 更新文档头部状态,
# plan.md 移除 Todo 行 + Done 表头插行(截断 10 条), plan/index.md 更新状态/结果。
# 用法: complete-plan.sh <id> <done|failed|abandoned> "结果一句话"
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

ID="$(as_norm_id "${1:-}")"
STATUS_ARG="${2:-}"
RESULT="${3:-}"

case "$STATUS_ARG" in
  done)       STATUS_CN="完成" ;;
  failed)     STATUS_CN="失败" ;;
  abandoned)  STATUS_CN="放弃" ;;
  *) as_die "状态必须是 done|failed|abandoned" ;;
esac
[ -n "$RESULT" ] || as_die "用法: complete-plan.sh <id> <done|failed|abandoned> \"结果一句话\""

SRC=( "$AS_ROOT"/plan/todo/"$ID"-*.md )
[ -e "${SRC[0]}" ] || as_die "plan:$ID 不在 plan/todo/ 中(不存在或已完成)"

TITLE="$(as_row_cell "$AS_ROOT/plan.md" "$ID" 3)"
[ -n "$TITLE" ] || as_die "plan.md Todo 表中未找到 plan:$ID"
DATE="$(as_today)"
RESULT_CELL="$(as_cell "$RESULT")"

DEST="plan/done/$(basename "${SRC[0]}")"

# Critical 3: 先校验全部前置条件,通过后再开始第一个 mutation
grep -qx "$STATUS_TODO" "${SRC[0]}" || as_die "plan:$ID 文档状态行非 $STATUS_TODO"

as_lock

# plan.md: 先更新表(移 Todo → 插 Done → 截断)
as_remove_row "$AS_ROOT/plan.md" "$ID"
as_insert_row "$AS_ROOT/plan.md" "$SEC_DONE" \
  "| $ID | $TITLE | $STATUS_CN | $RESULT_CELL | $DATE | [$DEST]($DEST) |"
as_truncate_section "$AS_ROOT/plan.md" "$SEC_DONE" 10

  # plan/index.md 全量记录: 更新状态/完成日期/结果/链接
  # 列: | ID | 计划 | 状态 | 创建日期 | 完成日期 | 结果 | 链接 |
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
  ' "$AS_ROOT/plan/index.md" > "$tmp" || { rm -f "$tmp"; as_die "index 缺少 plan:$ID"; }
  cat "$tmp" > "$AS_ROOT/plan/index.md" && rm -f "$tmp"

  # 最后移动文件 + 更新状态行(上述操作成功后执行)
mv "${SRC[0]}" "$AS_ROOT/$DEST"
as_replace_line "$AS_ROOT/$DEST" "$STATUS_TODO" "> 状态: $STATUS_CN ($DATE)"

echo "plan:$ID → $STATUS_CN ($DEST)"
echo "提醒: 请在 plan 文档\"结果\"节补充结论; 有可迁移教训时记录 notes"
