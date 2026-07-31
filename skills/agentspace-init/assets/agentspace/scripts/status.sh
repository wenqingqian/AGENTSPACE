#!/usr/bin/env bash
# Read-only status summary: next indexes / todo plans / in-progress iterations / latest / recent commits.
# Usage: status.sh
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

echo "# AGENTSPACE Status Summary"
echo
echo "Next index: plan $(as_next_plan_id) / iteration $(as_next_iteration_id)"
echo

echo "## Todo plans"
shopt -s nullglob
todo_files=( "$AS_ROOT"/plan/todo/[0-9]*.md )
if ((${#todo_files[@]})); then
  for f in "${todo_files[@]}"; do echo "- $(basename "$f" .md)"; done
else
  echo "(empty)"
fi
echo

echo "## In-progress iterations"
rows="$(awk -F'|' -v sec="$SEC_PROGRESS" '
  $0 == ("## " sec) { f=1; next }
  /^## / { f=0 }
  f && /^\| [0-9]/ {
    gsub(/^ +| +$/, "", $2); gsub(/^ +| +$/, "", $3); gsub(/^ +| +$/, "", $4)
    print "- " $2 " (" $3 ") " $4
  }
' "$AS_ROOT/iterations.md")"
[ -n "$rows" ] && echo "$rows" || echo "(empty)"
echo

echo "## Latest"
if [ -L "$AS_ROOT/iterations/latest" ]; then
  echo "latest -> $(readlink "$AS_ROOT/iterations/latest")"
else
  echo "(not set)"
fi
echo

# Use git rev-parse (works with git worktree where .git may be a file)
if git -C "$AS_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "## Recent commits"
  git -C "$AS_ROOT" log --oneline -3 2>/dev/null || echo "(no commits)"
fi
