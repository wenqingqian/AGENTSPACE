#!/usr/bin/env bash
set -euo pipefail

# update-version.sh — Update .agentspace-version.json after a successful update.
# Usage: update-version.sh <new-version>
#
# Locates the project root automatically (walks up from cwd until an AGENTSPACE/
# workspace is found), so it can be invoked from the project root or any subdir.
# Anchor = the scripts/ dir (present in every workspace version incl. v0.1.0-era
# workspaces without a version marker — those go through the create path below).

PROJECT_ROOT="$(pwd)"
while [ ! -d "$PROJECT_ROOT/AGENTSPACE/scripts" ]; do
  parent="$(dirname "$PROJECT_ROOT")"
  if [ "$parent" = "$PROJECT_ROOT" ]; then
    echo "error: no AGENTSPACE/ workspace found from $(pwd) upward (looked for AGENTSPACE/scripts/)" >&2
    exit 1
  fi
  PROJECT_ROOT="$parent"
done
VERSION_FILE="$PROJECT_ROOT/AGENTSPACE/.agentspace-version.json"

if [ $# -lt 1 ]; then
  echo "Usage: update-version.sh <version>" >&2
  exit 1
fi

NEW_VER="$1"
TODAY="$(date +%F)"

if [ ! -f "$VERSION_FILE" ]; then
  cat > "$VERSION_FILE" <<EOF
{
  "version": "$NEW_VER",
  "installedAt": "$TODAY",
  "lastUpdatedAt": "$TODAY"
}
EOF
  echo "Created $VERSION_FILE (v$NEW_VER)"
else
  # Preserve original installedAt
  installed_at="$(grep '"installedAt"' "$VERSION_FILE" | sed 's/.*: *"//;s/".*//')" || installed_at="$TODAY"
  if [ -z "$installed_at" ] || [ "$installed_at" = "null" ]; then installed_at="$TODAY"; fi
  cat > "$VERSION_FILE" <<EOF
{
  "version": "$NEW_VER",
  "installedAt": "$installed_at",
  "lastUpdatedAt": "$TODAY"
}
EOF
  echo "Updated $VERSION_FILE → v$NEW_VER"
fi
