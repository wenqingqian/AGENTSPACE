#!/usr/bin/env bash
# Create a new plan: allocate global index, instantiate plan/todo/NNNN-slug.md,
# insert row in plan.md Todo table, append to plan/index.md.
# Usage: new-plan.sh "Plan title"
#   The title must yield a compliant slug — lowercase english words, digits
#   and single hyphens only; CJK / uppercase / punctuation titles are refused
#   before anything is written (new plans only — existing plan files are
#   never touched).
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

TITLE="${1:-}"
[ -n "$TITLE" ] || as_die "Usage: new-plan.sh \"Plan title\""

# Lock BEFORE id allocation (t21): as_next_plan_id reads the index — computing
# it pre-lock let every concurrent creator read the same "next id" and collide
# on the same plan/todo/NNNN file. The lock covers the whole read-compute-write.
as_lock

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
# Slug contract: lowercase english words + digits + single hyphens. The strip
# set above leaves CJK bytes, uppercase, underscores and most punctuation in
# place, and a title made only of stripped chars yields an empty slug — every
# such result is refused here, before any file or table row is written.
slug_re='^[a-z0-9]+(-[a-z0-9]+)*$'
[[ "$SLUG" =~ $slug_re ]] || as_die "plan slug not allowed: \"${SLUG:-<empty>}\" (generated from title \"$TITLE\") — plan filenames accept lowercase english words, digits and single hyphens only; retry with a lowercase english title (words joined by hyphens)"
FILE="plan/todo/${ID}-${SLUG}.md"

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
