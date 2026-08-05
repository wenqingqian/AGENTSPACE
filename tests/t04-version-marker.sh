#!/usr/bin/env bash
# t04: version marker mechanics — update-version.sh preserves installedAt and
# refreshes lastUpdatedAt on update; creates the file with installedAt=today
# when it is missing (v0.1.0-era workspace, first update).
set -euo pipefail
. "$(dirname "$0")/lib.sh"

SB="$(build_sandbox t04)"
VERSION_FILE="$SB/AGENTSPACE/.agentspace-version.json"
UPDATE_SH="$REPO/skills/agentspace-update/scripts/update-version.sh"

# pin a past installedAt to prove preservation
python3 - "$VERSION_FILE" <<'EOF'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d["installedAt"] = "2026-01-01"
open(p, "w").write(json.dumps(d, ensure_ascii=False, indent=2) + "\n")
EOF

# update-version.sh resolves PROJECT_ROOT from pwd
(cd "$SB" && assert_ok bash "$UPDATE_SH" 0.9.9)
V="$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d['version'], d['installedAt'], d['lastUpdatedAt'])" "$VERSION_FILE")"
[ "$V" = "0.9.9 2026-01-01 $(date +%F)" ] || fail "unexpected version file after update: $V"

# missing file (v0.1.0 era) → created with installedAt = today
rm "$VERSION_FILE"
(cd "$SB" && assert_ok bash "$UPDATE_SH" 0.9.10)
python3 -c "import json,sys; d=json.load(open(sys.argv[1])); assert d['version']=='0.9.10' and d['installedAt']=='$(date +%F)', d" "$VERSION_FILE" \
  || fail "missing-file creation path failed"

# update-version.sh locates the project root by walking up from subdirs (v0.3.1)
(cd "$SB/AGENTSPACE/plan" && assert_ok bash "$UPDATE_SH" 0.9.11)
V="$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d['version'])" "$VERSION_FILE")"
[ "$V" = "0.9.11" ] || fail "walk-up project-root resolution failed: $V"

# update-version.sh locates the project root by walking up from subdirs (v0.3.1)
(cd "$SB/AGENTSPACE/plan" && assert_ok bash "$UPDATE_SH" 0.9.11)
V="$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d['version'])" "$VERSION_FILE")"
[ "$V" = "0.9.11" ] || fail "walk-up project-root resolution failed: $V"

# v0.3.3: legacy workspace (no version marker) from a subdir — create path still
# resolves via the scripts/ anchor instead of walking past the workspace
rm "$VERSION_FILE"
(cd "$SB/AGENTSPACE/plan" && assert_ok bash "$UPDATE_SH" 0.9.12)
python3 -c "import json,sys; d=json.load(open(sys.argv[1])); assert d['version']=='0.9.12' and d['installedAt']=='$(date +%F)', d" "$VERSION_FILE" \
  || fail "legacy create path via subdir failed"

rm -rf "$SB"
echo "PASS t04"
