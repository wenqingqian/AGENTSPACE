#!/usr/bin/env bash
# Initialization script for /agentspace-init: creates a git-managed AGENTSPACE
# workspace in the current project root.
# Idempotent: if AGENTSPACE/ already exists, reports status and exits.
# Usage: run from the project root directory.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ASSETS_DIR="$(cd "$SCRIPT_DIR/../assets" && pwd)"
PROJECT_ROOT="$(pwd)"
TARGET="$PROJECT_ROOT/AGENTSPACE"

# ---- Idempotency guard ----
if [ -d "$TARGET" ]; then
  echo "AGENTSPACE already exists: $TARGET (not re-initializing)"
  if [ -x "$TARGET/scripts/status.sh" ]; then
    echo
    "$TARGET/scripts/status.sh"
  fi
  exit 0
fi

# ---- Create directory tree and copy workspace contents ----
mkdir -p "$TARGET"
cp -R "$ASSETS_DIR/agentspace/." "$TARGET/"
mkdir -p "$TARGET/plan/todo" "$TARGET/plan/done" "$TARGET/plan/base" "$TARGET/iterations" "$TARGET/handoff" \
         "$TARGET/exp/todo" "$TARGET/exp/doing" "$TARGET/exp/done" \
         "$TARGET/data" "$TARGET/examples" "$TARGET/utils" "$TARGET/tests" "$TARGET/notes"
# Git needs files to track empty directories (data/ is gitignored, no .gitkeep needed)
touch "$TARGET/plan/todo/.gitkeep" "$TARGET/plan/done/.gitkeep" "$TARGET/plan/base/.gitkeep" \
      "$TARGET/exp/todo/.gitkeep" "$TARGET/exp/doing/.gitkeep" "$TARGET/exp/done/.gitkeep" \
      "$TARGET/examples/.gitkeep" \
      "$TARGET/utils/.gitkeep" "$TARGET/tests/.gitkeep" "$TARGET/notes/.gitkeep"
# Replace {{DATE}} placeholder in version file (BSD/GNU compatible)
if [ -f "$TARGET/.agentspace-version.json" ]; then
  _tmp="$TARGET/.agentspace-version.json.tmp"
  sed "s/{{DATE}}/$(date +%F)/g" "$TARGET/.agentspace-version.json" > "$_tmp" \
    && mv "$_tmp" "$TARGET/.agentspace-version.json"
fi
chmod +x "$TARGET"/scripts/*.sh

# ---- Project root AGENTS.md (do not overwrite if exists) ----
if [ -f "$PROJECT_ROOT/AGENTS.md" ]; then
  echo "NOTICE: project root AGENTS.md already exists, not overwritten."
  echo "        Consider appending the AGENTSPACE guidance block (agent will confirm with you)."
else
  escaped_name="$(printf '%s' "$(basename "$PROJECT_ROOT")" | sed 's/[&\\/]/\\&/g')"
  sed "s/{{PROJECT_NAME}}/$escaped_name/g" \
    "$ASSETS_DIR/root-AGENTS.md" > "$PROJECT_ROOT/AGENTS.md"
  echo "created: ./AGENTS.md (project root guide)"
fi

# ---- AGENTSPACE independent git repo + first commit ----
# Check .git directly (not rev-parse, which walks up parent dirs and false-positives in nested repos)
if [ ! -e "$TARGET/.git" ]; then
  git -C "$TARGET" init -b main >/dev/null 2>&1 || git -C "$TARGET" init >/dev/null
fi
# -- . limits staging to workspace only, preventing host uncommitted changes from leaking in
git -C "$TARGET" add -A -- .
if ! git -C "$TARGET" commit -m "chore: initialize AGENTSPACE workspace" >/dev/null 2>&1; then
  # Set a local identity when git user is not configured
  git -C "$TARGET" config user.name "AGENTSPACE Bot"
  git -C "$TARGET" config user.email "agentspace@localhost"
  git -C "$TARGET" commit -m "chore: initialize AGENTSPACE workspace" >/dev/null
fi

echo
echo "== AGENTSPACE initialized =="
echo "Location: $TARGET"
echo "First commit: $(git -C "$TARGET" log --oneline -1)"
echo
echo "== Self-check (doctor) =="
if "$TARGET/scripts/doctor.sh"; then
  echo "初始化一致性 ✓"
else
  echo "NOTICE: doctor 发现问题(见上方输出), 请修复后再开始使用"
fi
echo
echo "Next steps:"
echo "  1. Fill AGENTSPACE/AGENTS.md '项目简介' and '根仓库简介'"
echo "  2. Fill AGENTSPACE/tests.md experiment environment table (container/conda/GPU)"
echo "  3. Consider adding AGENTSPACE/ to host repo .gitignore (agent will confirm with you)"
