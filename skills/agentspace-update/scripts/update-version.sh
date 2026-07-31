#!/usr/bin/env bash
set -euo pipefail

# update-version.sh — Update .agentspace-version.json after a successful update.
# Usage: update-version.sh <new-workspace-version> <new-plugin-version>

# Called from project root: bash skills/agentspace-update/scripts/update-version.sh <args>
PROJECT_ROOT="$(pwd)"
VERSION_FILE="$PROJECT_ROOT/AGENTSPACE/.agentspace-version.json"

if [ $# -lt 2 ]; then
  echo "Usage: update-version.sh <workspace-version> <plugin-version>" >&2
  exit 1
fi

NEW_WV="$1"
NEW_PV="$2"
TODAY="$(date +%F)"

if [ ! -f "$VERSION_FILE" ]; then
  # Create from scratch if missing
  cat > "$VERSION_FILE" <<EOF
{
  "workspaceVersion": "$NEW_WV",
  "pluginVersion": "$NEW_PV",
  "installedAt": "$TODAY",
  "lastUpdatedAt": "$TODAY"
}
EOF
  echo "Created $VERSION_FILE (v$NEW_WV)"
else
  # Read existing installedAt (preserve original install date)
  installed_at="$(grep '"installedAt"' "$VERSION_FILE" | sed 's/.*: *"//;s/".*//')" || installed_at="$TODAY"
  if [ -z "$installed_at" ] || [ "$installed_at" = "null" ]; then installed_at="$TODAY"; fi
  cat > "$VERSION_FILE" <<EOF
{
  "workspaceVersion": "$NEW_WV",
  "pluginVersion": "$NEW_PV",
  "installedAt": "$installed_at",
  "lastUpdatedAt": "$TODAY"
}
EOF
  echo "Updated $VERSION_FILE → workspace v$NEW_WV, plugin v$NEW_PV"
fi
