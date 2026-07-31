#!/usr/bin/env bash
# 关闭 iteration: iterations.md 行从进行中移入最近完成(截断 10 条),
# iterations/index.md 更新状态/结果, readme 标记冻结并追加关闭日志。
# 用法: close-iteration.sh <id> "结果一句话"
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

ID="$(as_norm_id "${1:-}")"
RESULT="${2:-}"
[ -n "$RESULT" ] || as_die "用法: close-iteration.sh <id> \"结果一句话\""

DIR="iterations/iteration_$ID"
README="$AS_ROOT/$DIR/readme.md"
[ -f "$README" ] || as_die "iteration_$ID 不存在"
# Required 1: 守门与替换须同语义(精确整行匹配)
grep -qx "$STATUS_PROGRESS" "$README" || as_die "iteration_$ID 不在进行中(已关闭或状态异常)"

PLANREF="$(as_row_cell "$AS_ROOT/iterations.md" "$ID" 3)"
TITLE="$(as_row_cell "$AS_ROOT/iterations.md" "$ID" 4)"
[ -n "$TITLE" ] || as_die "iterations.md 进行中表中未找到 iteration_$ID"
DATE="$(as_today)"
RESULT_CELL="$(as_cell "$RESULT")"

as_lock

# iterations.md: 移除进行中行, 完成表头插行, 截断 10 条
as_remove_row "$AS_ROOT/iterations.md" "$ID"
as_insert_row "$AS_ROOT/iterations.md" "$SEC_RECENT" \
  "| $ID | $PLANREF | $TITLE | $RESULT_CELL | $DATE | [$DIR/readme.md]($DIR/readme.md) |"
as_truncate_section "$AS_ROOT/iterations.md" "$SEC_RECENT" 10

  # iterations/index.md 全量记录: 更新状态/完成日期/结果
  # 列: | ID | Plan | 内容 | 状态 | 开始日期 | 完成日期 | 结果 | 链接 |
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
  ' "$AS_ROOT/iterations/index.md" > "$tmp" || { rm -f "$tmp"; as_die "iterations/index.md 缺少 iteration_$ID"; }
  cat "$tmp" > "$AS_ROOT/iterations/index.md" && rm -f "$tmp"

  # Nit 4: 单次 awk 同时完成 readme 状态行替换与关闭日志追加(原子化写回)
  tmp2="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
  awk -v status_old="$STATUS_PROGRESS" -v status_new="> 状态: 已完成 ($DATE)" -v log_line="- $DATE 关闭: $RESULT_CELL" '
    $0 == status_old && !done { print status_new; done=1; next }
    { print }
    END {
      if (!done) exit 3
      print log_line
    }
  ' "$README" > "$tmp2" || { rm -f "$tmp2"; as_die "readme 状态行 $STATUS_PROGRESS 未找到"; }
  cat "$tmp2" > "$README" && rm -f "$tmp2"

echo "iteration_$ID 已关闭 → $DIR/readme.md (冻结)"
