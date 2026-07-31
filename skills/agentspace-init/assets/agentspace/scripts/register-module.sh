#!/usr/bin/env bash
# Register an on-demand extension module: generate <name>.md entry + <name>/ directory,
# insert row in register.md. Agent must confirm with user before calling.
# Usage: register-module.sh <name> "purpose"
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

NAME="${1:-}"
PURPOSE="${2:-}"
[ -n "$NAME" ] && [ -n "$PURPOSE" ] || as_die "Usage: register-module.sh <name> \"purpose\""
[[ "$NAME" =~ ^[a-z0-9][a-z0-9-]*$ ]] || as_die "Module name must be lowercase alphanumeric/hyphen: $NAME"
[ ! -e "$AS_ROOT/$NAME.md" ] && [ ! -e "$AS_ROOT/$NAME" ] || as_die "Module already exists: $NAME"

DATE="$(as_today)"

as_lock

mkdir -p "$AS_ROOT/$NAME"
touch "$AS_ROOT/$NAME/.gitkeep"

PH_NAME="$NAME" PH_PURPOSE="$PURPOSE" PH_DATE="$DATE" \
  as_fill_template "$AS_ROOT/templates/module-entry.md" "$AS_ROOT/$NAME.md"

as_insert_row "$AS_ROOT/register.md" "$SEC_REGISTERED" \
  "| $NAME | $(as_cell "$PURPOSE") | [$NAME.md]($NAME.md) | $DATE |"

echo "Module registered: $NAME.md + $NAME/ (entry template needs what/when/how)"
