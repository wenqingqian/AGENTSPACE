#!/usr/bin/env bash
# Create a new plan: allocate global index, instantiate plan/todo/NNNN-slug.md,
# insert row in plan.md Todo table, append to plan/index.md.
# Usage: new-plan.sh "Plan title"
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

TITLE="${1:-}"
[ -n "$TITLE" ] || as_die "Usage: new-plan.sh \"Plan title\""

ID="$(as_next_plan_id)"
DATE="$(as_today)"
CELL="$(as_cell "$TITLE")"
# Normalize whitespace (incl. \n\r\t) then strip chars unsafe for markdown/filenames.
# Use python3 for character-aware truncation (awk/cut are byte-aware on macOS, split CJK).
# PYTHONUTF8=1: python3 3.6- reads stdin with the locale encoding (ASCII under
# LC_ALL=C); forcing UTF-8 keeps CJK titles intact on every supported python.
command -v python3 >/dev/null 2>&1 || as_die "new-plan.sh needs python3 (CJK-aware title truncation) — install it or run the plan creation manually"
SLUG="$(printf '%s' "$TITLE" | tr '\n\r\t' '   ' | tr -s ' ' | tr ' ' '-' | tr -d '/\\?*":<>|()[]#!' | PYTHONUTF8=1 python3 -c "import sys; s=sys.stdin.read().strip(); print(s[:40])")"
[ -n "$SLUG" ] || SLUG="plan"
FILE="plan/todo/${ID}-${SLUG}.md"

as_lock

PH_ID="$ID" PH_TITLE="$TITLE" PH_DATE="$DATE" \
  as_fill_template "$AS_ROOT/templates/plan.md" "$AS_ROOT/$FILE"

as_insert_row "$AS_ROOT/plan.md" "$SEC_TODO" \
  "| $ID | $CELL | $DATE | [$FILE]($FILE) |"

echo "| $ID | $CELL | todo | $DATE |  |  | [$FILE]($FILE) |" >> "$AS_ROOT/plan/index.md"

echo "plan:$ID created → $FILE"
echo "Next: write the goal/background/plan-steps in that file"
