#!/usr/bin/env bash
# Initialization script for /agentspace-init-light: creates a git-managed
# AGENTSPACE workspace containing ONLY the plan module (plan.md + plan/ with
# the base-plan lifecycle). The scripts/ + templates/ trees and the plan/config
# files are shared with /agentspace-init (single source of truth); module-bound
# transition scripts refuse with an actionable message (lib.sh
# as_require_module). Expansion to the full workspace goes through
# /agentspace-update — never by hand-copying module files.
# Idempotent: if AGENTSPACE/ already exists, reports status and exits.
# Usage: run from the project root directory.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ASSETS_DIR="$(cd "$SCRIPT_DIR/../assets" && pwd)"
FULL_ASSETS="$(cd "$SCRIPT_DIR/../../agentspace-init/assets/agentspace" && pwd)"
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
mkdir -p "$TARGET/plan"
# Light-specific files: workspace AGENTS.md + light architecture snapshot
cp "$ASSETS_DIR/agentspace/AGENTS.md" "$TARGET/AGENTS.md"
cp "$ASSETS_DIR/agentspace/.agentspace-architecture.json" "$TARGET/.agentspace-architecture.json"
# Shared plan/config files (identical to the full init)
cp "$FULL_ASSETS/plan.md" "$TARGET/plan.md"
cp "$FULL_ASSETS/plan/index.md" "$TARGET/plan/index.md"
cp "$FULL_ASSETS/.gitignore" "$TARGET/.gitignore"
cp "$FULL_ASSETS/.agentspace-version.json" "$TARGET/.agentspace-version.json"
cp "$FULL_ASSETS/.agentspace-repos" "$TARGET/.agentspace-repos"
cp "$FULL_ASSETS/.agentspace-whitelist" "$TARGET/.agentspace-whitelist"
# Shared plugin-managed trees (full set — doctor [5] template contract etc.)
cp -R "$FULL_ASSETS/scripts" "$TARGET/scripts"
cp -R "$FULL_ASSETS/templates" "$TARGET/templates"
mkdir -p "$TARGET/plan/todo" "$TARGET/plan/done" "$TARGET/plan/base"
# Git needs files to track empty directories
touch "$TARGET/plan/todo/.gitkeep" "$TARGET/plan/done/.gitkeep" "$TARGET/plan/base/.gitkeep"
# Replace {{DATE}} placeholder in version file (BSD/GNU compatible)
if [ -f "$TARGET/.agentspace-version.json" ]; then
  _tmp="$TARGET/.agentspace-version.json.tmp"
  sed "s/{{DATE}}/$(date +%F)/g" "$TARGET/.agentspace-version.json" > "$_tmp" \
    && mv "$_tmp" "$TARGET/.agentspace-version.json"
fi
chmod +x "$TARGET"/scripts/*.sh

# ---- Project root AGENTS.md (light template; do not overwrite if exists) ----
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
if ! git -C "$TARGET" commit -m "chore: initialize AGENTSPACE workspace (light)" >/dev/null 2>&1; then
  # Set a local identity when git user is not configured
  git -C "$TARGET" config user.name "AGENTSPACE Bot"
  git -C "$TARGET" config user.email "agentspace@localhost"
  git -C "$TARGET" commit -m "chore: initialize AGENTSPACE workspace (light)" >/dev/null
fi

echo
echo "== AGENTSPACE initialized (light — plan module only) =="
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
echo "  2. Create the first plan: AGENTSPACE/scripts/new-plan.sh \"<title>\""
echo "  3. iterations/exp/utils/... are NOT initialized — run /agentspace-update when the project needs them"
echo "  4. Consider adding AGENTSPACE/ to host repo .gitignore (agent will confirm with you)"
