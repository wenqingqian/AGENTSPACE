#!/usr/bin/env bash
# Consistency check: entry tables / full indexes ↔ filesystem.
# Broken latest symlink auto-repaired; other issues reported.
# Usage: doctor.sh
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

issues=0
fixed=0
# Use printf to avoid echo interpreting leading `-`
# warn/ok only valid in main shell (pipe subshell changes don't propagate)
warn() { printf '  [issue] %s\n' "$*"; issues=$((issues + 1)); }
ok()   { printf '  [fixed] %s\n' "$*"; fixed=$((fixed + 1)); }

echo "== AGENTSPACE doctor: $AS_ROOT =="
echo

# ---- 0. git worktree: uncommitted changes (milestone commit may have been skipped) ----
echo "[0] git worktree"
if git -C "$AS_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  dirty="$(git -C "$AS_ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  [ "$dirty" -eq 0 ] || warn "uncommitted changes ($dirty file(s)); run a milestone commit"
fi

# ---- 1. latest symlink ----
echo "[1] iterations/latest"
L="$AS_ROOT/iterations/latest"
if [ -L "$L" ] && [ ! -e "$L" ]; then
  rm -f "$L"
  warn "latest symlink broken, removed"
fi
if [ ! -L "$L" ]; then
  last="$(ls -d "$AS_ROOT"/iterations/iteration_[0-9]* 2>/dev/null | sort | tail -1 || true)"
  if [ -n "$last" ]; then
    ln -sfn "$(basename "$last")" "$L"
    ok "latest -> $(basename "$last")"
  fi
fi

# ---- 2. plan: files ↔ entry table ↔ full index ----
echo "[2] plan consistency"
shopt -s nullglob

for f in "$AS_ROOT"/plan/todo/[0-9]*.md; do
  id="$(basename "$f" | cut -d- -f1)"
  [ -n "$(as_row_cell "$AS_ROOT/plan.md" "$id" 3)" ] \
    || warn "plan.md Todo missing $id ($(basename "$f"))"
  grep -q "^| *$id *|" "$AS_ROOT/plan/index.md" \
    || warn "plan/index.md missing $id ($(basename "$f"))"
done

for f in "$AS_ROOT"/plan/done/[0-9]*.md; do
  id="$(basename "$f" | cut -d- -f1)"
  grep -q "^| *$id *|" "$AS_ROOT/plan/index.md" \
    || warn "plan/index.md missing completed $id ($(basename "$f"))"
done

# Todo rows must have corresponding files
todo_ids="$(awk -F'|' -v sec="$SEC_TODO" '
  $0 == ("## " sec) { f=1; next }
  /^## / { f=0 }
  f && /^\| [0-9]/ { gsub(/ /, "", $2); print $2 }
' "$AS_ROOT/plan.md")"
for id in $todo_ids; do
  ls "$AS_ROOT"/plan/todo/"$id"-*.md >/dev/null 2>&1 \
    || warn "plan.md Todo row $id has no corresponding file (orphan row)"
done

# ---- 3. iterations: dirs ↔ entry table ↔ full index ----
echo "[3] iterations consistency"
for d in "$AS_ROOT"/iterations/iteration_[0-9]*; do
  [ -d "$d" ] || continue
  id="$(basename "$d" | sed 's/iteration_//')"
  [ -f "$d/readme.md" ] || warn "iteration_$id missing readme.md"
  grep -q "^| *$id *|" "$AS_ROOT/iterations/index.md" \
    || warn "iterations/index.md missing $id"
  # Only in-progress iterations must appear in entry table (completed may be truncated)
  if grep -q "^$STATUS_PROGRESS$" "$d/readme.md" 2>/dev/null; then
    grep -q "^| *$id *|" "$AS_ROOT/iterations.md" \
      || warn "iterations.md missing in-progress $id"
  fi
done

# In-progress rows must have corresponding dirs
prog_ids="$(awk -F'|' -v sec="$SEC_PROGRESS" '
  $0 == ("## " sec) { f=1; next }
  /^## / { f=0 }
  f && /^\| [0-9]/ { gsub(/ /, "", $2); print $2 }
' "$AS_ROOT/iterations.md")"
for id in $prog_ids; do
  [ -d "$AS_ROOT/iterations/iteration_$id" ] \
    || warn "iterations.md in-progress row $id has no corresponding dir (orphan row)"
done

# ---- 4. link validity: script-managed tables only (links are script contract output) ----
echo "[4] link validity"
# shellcheck disable=SC2016
for t in plan.md plan/index.md iterations.md iterations/index.md register.md; do
  tfile="$AS_ROOT/$t"
  [ -f "$tfile" ] || continue
  # Only table data rows (| ...) — header pointers like the latest symlink are out of scope
  while IFS= read -r target; do
    [ -n "$target" ] || continue
    case "$target" in
      http://*|https://*|mailto:*|\#*) continue ;;
    esac
    [ -e "$AS_ROOT/$target" ] || warn "$t: broken link → $target"
  done < <(grep '^| ' "$tfile" | grep -o ']([^)]*)' | sed 's/^](//; s/)$//')
done

echo
echo "== Done: $issues issues, $fixed auto-repaired =="
if [ "$issues" -eq 0 ]; then
  echo "Workspace consistent ✓"
else
  echo "Tip: do NOT hand-edit tables on your own. Discuss a repair plan with the user first;"
  echo "     a one-time manual fix explicitly confirmed by the user is the only allowed exception."
  exit 1
fi
