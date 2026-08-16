#!/usr/bin/env bash
# Dev tool — repo root only, NOT part of the deployed plugin.
# Scaffold a new plugin version: create the versions/vX.Y.Z/ archive (CHANGELOG
# skeleton + architecture snapshot copied from the latest version) and bump the
# version fields in both platform manifests / marketplace.json / init assets.
#
# Usage: bash new-version.sh X.Y.Z
# After running: fill the CHANGELOG migration details (DEVELOPMENT.md quality
# requirements), sync assets if the structure changed, then run
# `bash verify-release.sh` as the release gate.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
VERSIONS="$ROOT/skills/agentspace-update/versions"
NEW="${1:-}"

[[ "$NEW" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  echo "usage: bash new-version.sh X.Y.Z" >&2
  exit 2
}
[ -d "$VERSIONS/v$NEW" ] && {
  echo "error: versions/v$NEW already exists" >&2
  exit 1
}

# Latest existing version (python for version-aware sort; macOS sort lacks -V)
LATEST="$(python3 - "$VERSIONS" <<'EOF'
import os, re, sys
dirs = [d[1:] for d in os.listdir(sys.argv[1]) if re.match(r'^v\d+\.\d+\.\d+$', d)]
def key(s): return tuple(int(x) for x in s.split('.'))
if not dirs:
    print("error: no version archives found", file=sys.stderr)
    sys.exit(1)
print(sorted(dirs, key=key)[-1])
EOF
)"

if ! python3 - "$LATEST" "$NEW" <<'EOF' | grep -qx newer
import sys
def v(s): return tuple(int(x) for x in s.split('.'))
print("newer" if v(sys.argv[2]) > v(sys.argv[1]) else "")
EOF
then
  echo "error: $NEW is not newer than latest v$LATEST" >&2
  exit 1
fi

# --- 1. version archive -----------------------------------------------------
mkdir -p "$VERSIONS/v$NEW"

cat > "$VERSIONS/v$NEW/CHANGELOG.md" <<EOF
# AGENTSPACE v$NEW

Upgrade from v$LATEST. Date: $(date +%F)

## Summary

- TODO: one bullet per high-level change

## Changes

### [Addition] TODO change title
- **What**: precise description of the change
- **Why**: design rationale
- **Migration**: exact steps for the update agent — full paths, exact insertion
  text and positions; state "handled by step 8a" when scripts/templates/.gitignore
  are replaced from assets

<!-- Add one [Addition]/[Fix]/[Schema]/[Breaking] block per change.
     Quality requirements: skills/agentspace-update/DEVELOPMENT.md -->
EOF

python3 - "$VERSIONS/v$LATEST/architecture.json" "$VERSIONS/v$NEW/architecture.json" "$NEW" <<'EOF'
import json, sys
src, dst, ver = sys.argv[1], sys.argv[2], sys.argv[3]
d = json.load(open(src))
d["version"] = ver
open(dst, "w").write(json.dumps(d, ensure_ascii=False, indent=2) + "\n")
print(f"  {dst}: copied from {src}, version -> {ver}")
EOF

# --- 2. version field bumps -------------------------------------------------
# Load + apply to all targets in memory first; only write once every target
# validated, so a missing/corrupt file cannot leave a partially-applied state.
python3 - "$NEW" "$ROOT" <<'EOF'
import json, sys
ver, root = sys.argv[1], sys.argv[2]
targets = [
    (f"{root}/.zcode-plugin/plugin.json", lambda d: d.__setitem__("version", ver)),
    (f"{root}/.codex-plugin/plugin.json", lambda d: d.__setitem__("version", ver)),
    # marketplace carries BOTH a top-level version and plugins[0].version —
    # one lambda per field would reload the unmodified file and the last write
    # wins, dropping the other field (drift caught by verify-release [1])
    (f"{root}/marketplace.json", lambda d: [d.__setitem__("version", ver), d["plugins"][0].__setitem__("version", ver)]),
    (f"{root}/skills/agentspace-init/assets/agentspace/.agentspace-version.json", lambda d: d.__setitem__("version", ver)),
    (f"{root}/skills/agentspace-init/assets/agentspace/.agentspace-architecture.json", lambda d: d.__setitem__("version", ver)),
]
docs = []
errors = []
for path, fn in targets:
    try:
        d = json.load(open(path))
        fn(d)
    except Exception as e:
        errors.append(f"{path}: {e}")
        continue
    docs.append((path, d))
if errors:
    for e in errors:
        print(f"error: cannot load {e}", file=sys.stderr)
    sys.exit(1)
for path, d in docs:
    open(path, "w").write(json.dumps(d, ensure_ascii=False, indent=2) + "\n")
    print(f"  {path}: version -> {ver}")
EOF

echo ""
echo "Scaffolded v$NEW (from v$LATEST):"
echo "  - versions/v$NEW/CHANGELOG.md      (fill in migration details)"
echo "  - versions/v$NEW/architecture.json (adjust sections/columns/constants to the actual changes)"
echo "  - version fields bumped in both plugin manifests / marketplace.json / init assets"
echo ""
echo "Next:"
echo "  1. Write CHANGELOG migration steps (DEVELOPMENT.md quality requirements)"
echo "  2. Sync assets if files/schemas changed (assets/agentspace/, lib.sh constants) —"
echo "     verify-release [1b] catches marker drift, but sync manually first"
echo "  3. bash verify-release.sh   <- release gate"
echo "  4. Code review -> commit -> push"
