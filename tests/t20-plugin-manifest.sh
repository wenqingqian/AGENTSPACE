#!/usr/bin/env bash
# t20: plugin-manifest contract — the additional manifest is valid and stays
# version-aligned without changing shared skill semantics or existing commands.
# This test is portable and does not install the plugin.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

python3 - "$REPO" <<'PYEOF' || fail "plugin manifest contract failed"
import json, os, sys

root = sys.argv[1]

def load(rel):
    with open(os.path.join(root, rel), encoding="utf-8") as fh:
        return json.load(fh)

existing = load(".zcode-plugin/plugin.json")
codex = load(".codex-plugin/plugin.json")
kimi = load("kimi.plugin.json")
market = load("marketplace.json")
asset_version = load("skills/agentspace-init/assets/agentspace/.agentspace-version.json")
archive_dirs = [name for name in os.listdir(os.path.join(root, "skills/agentspace-update/versions"))
                if name.startswith("v")]
latest = max(archive_dirs, key=lambda name: tuple(map(int, name[1:].split("."))))[1:]
versions = {
    existing["version"], codex["version"], kimi["version"], market["version"],
    market["plugins"][0]["version"], asset_version["version"], latest,
}
if len(versions) != 1:
    raise SystemExit("version drift: " + repr(sorted(versions)))
for manifest in (codex, kimi):
    if manifest.get("name") != "agentspace" or manifest.get("skills", "").rstrip("/") not in ("skills", "./skills"):
        raise SystemExit("manifest name/skills contract invalid")
for field in ("displayName", "shortDescription", "longDescription", "developerName", "category"):
    if not codex.get("interface", {}).get(field):
        raise SystemExit("missing interface." + field + " (codex)")
for field in ("displayName", "shortDescription", "longDescription", "developerName", "websiteURL"):
    if not kimi.get("interface", {}).get(field):
        raise SystemExit("missing interface." + field + " (kimi)")
import re as _re
if not _re.fullmatch(r"[a-z0-9][a-z0-9_-]{0,63}", kimi.get("name", "")):
    raise SystemExit("kimi name violates [a-z0-9][a-z0-9_-]{0,63}")
for field in ("composerIcon", "logo"):
    rel = codex["interface"].get(field, "")
    if not rel.startswith("./") or not os.path.isfile(os.path.join(root, rel[2:])):
        raise SystemExit("invalid interface asset " + field)
PYEOF

for command in init update doctor handoff-produce handoff-consume status mode exp; do
  [ -f "$REPO/commands/agentspace-$command.md" ] || fail "existing command missing: agentspace-$command"
done
# reverse completeness: every command file on disk must be in the list above —
# a new command added without extending the list would silently lose its guard
for f in "$REPO"/commands/agentspace-*.md; do
  base="$(basename "$f" .md)"; base="${base#agentspace-}"
  case " init update doctor handoff-produce handoff-consume status mode exp " in
    *" $base "*) ;;
    *) fail "command file not covered by the t20 list: $base" ;;
  esac
done

for doc in "$REPO"/skills/*/SKILL.md "$REPO"/skills/*/SKILL.zh-CN.md; do
  if grep -Eq 'ZCode|Codex|Kimi' "$doc"; then
    fail "shared skill contains platform-specific branching: ${doc#$REPO/}"
  fi
done

assert_contains "$REPO/new-version.sh" '.codex-plugin/plugin.json'
assert_contains "$REPO/new-version.sh" 'kimi.plugin.json'

echo "PASS t20"
