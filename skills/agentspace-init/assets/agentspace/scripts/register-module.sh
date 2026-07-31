#!/usr/bin/env bash
# 注册按需扩展模块: 从模板生成 <name>.md 入口 + <name>/ 目录, register.md 加行。
# 调用前必须先与用户确认(agent 职责)。
# 用法: register-module.sh <name> "用途"
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

NAME="${1:-}"
PURPOSE="${2:-}"
[ -n "$NAME" ] && [ -n "$PURPOSE" ] || as_die "用法: register-module.sh <name> \"用途\""
[[ "$NAME" =~ ^[a-z0-9][a-z0-9-]*$ ]] || as_die "模块名必须是小写字母/数字/连字符: $NAME"
[ ! -e "$AS_ROOT/$NAME.md" ] && [ ! -e "$AS_ROOT/$NAME" ] || as_die "模块已存在: $NAME"

DATE="$(as_today)"

as_lock

mkdir -p "$AS_ROOT/$NAME"
touch "$AS_ROOT/$NAME/.gitkeep"

PH_NAME="$NAME" PH_PURPOSE="$PURPOSE" PH_DATE="$DATE" \
  as_fill_template "$AS_ROOT/templates/module-entry.md" "$AS_ROOT/$NAME.md"

as_insert_row "$AS_ROOT/register.md" "$SEC_REGISTERED" \
  "| $NAME | $(as_cell "$PURPOSE") | [$NAME.md]($NAME.md) | $DATE |"

echo "模块已注册: $NAME.md + $NAME/ (入口模板待补充 what/when/how)"
