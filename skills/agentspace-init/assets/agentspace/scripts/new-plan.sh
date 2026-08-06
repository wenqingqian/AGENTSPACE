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
# PYTHONIOENCODING=utf-8 (3.6+) + PYTHONUTF8=1 (3.7+): under LC_ALL=C python 3.6
# reads stdin as ASCII — forcing UTF-8 keeps CJK titles intact on every supported
# python (PYTHONUTF8 alone is ignored by 3.6 — audit R2).
command -v python3 >/dev/null 2>&1 || as_die "new-plan.sh needs python3 (CJK-aware title truncation) — install it or run the plan creation manually"
SLUG="$(printf '%s' "$TITLE" | tr '\n\r\t' '   ' | tr -s ' ' | tr ' ' '-' | tr -d '/\\?*":<>|()[]#!' | PYTHONIOENCODING=utf-8 PYTHONUTF8=1 python3 -c "import sys; s=sys.stdin.read().strip(); print(s[:40])")"
[ -n "$SLUG" ] || SLUG="plan"
FILE="plan/todo/${ID}-${SLUG}.md"

as_lock

PH_ID="$ID" PH_TITLE="$TITLE" PH_DATE="$DATE" \
  as_fill_template "$AS_ROOT/templates/plan.md" "$AS_ROOT/$FILE"

as_insert_row "$AS_ROOT/plan.md" "$SEC_TODO" \
  "| $ID | $CELL | $DATE | [$FILE]($FILE) |"

# Index append via tmp+mv: atomic (audit R8) — a `>>` crash window leaves a
# half-written index row that doctor [2] cannot repair
tmp="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
{ cat "$AS_ROOT/plan/index.md" 2>/dev/null || true; echo "| $ID | $CELL | todo | $DATE |  |  | [$FILE]($FILE) |"; } > "$tmp" \
  && as_atomic_write "$AS_ROOT/plan/index.md" "$tmp"

echo "plan:$ID created → $FILE"
echo "Next: write the goal/background/plan-steps in that file"
