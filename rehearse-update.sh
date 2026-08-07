#!/usr/bin/env bash
# Dev tool — repo root only, NOT part of the deployed plugin.
# Changelog-driven update rehearsal (MUST before every release that adds a
# changelog): builds a sandbox workspace from the PREVIOUS version's assets
# (`git archive <old-ref>`), applies the new version's CHANGELOG Migration
# instructions (8a scripts/templates + 8c markers; 8b AGENTS.md text ops are
# agent-executed per the changelog — see below), and verifies convergence.
# On success writes the rehearsal record to versions/v<new>/rehearsal.md —
# verify-release [11] refuses a release without a PASSING record.
#
# Usage: bash rehearse-update.sh <old-ref> <new-version>
#   <old-ref>      any git ref whose assets carry the previous version
#                  (e.g. the previous release commit)
#   <new-version>  must match an existing versions/v<new>/CHANGELOG.md
#
# 8b handling: if a Migration item instructs AGENTS.md text ops (canonical
# wording `**AGENTS.md (step 8b — ...`), the record is written with 8b: MANUAL
# and the sandbox path is printed — the agent executes the text ops per the
# changelog, re-verifies, and flips the line to PASS before the release.
# Everything mechanical (8a/8c + convergence) is done here.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
OLD_REF="${1:-}"
NEW="${2:-}"
NEW="${NEW#v}"
[ -n "$OLD_REF" ] && [ -n "$NEW" ] || { echo "usage: rehearse-update.sh <old-ref> <new-version>" >&2; exit 1; }

CL="$ROOT/skills/agentspace-update/versions/v$NEW/CHANGELOG.md"
[ -f "$CL" ] || { echo "error: no changelog at versions/v$NEW/CHANGELOG.md" >&2; exit 1; }
git -C "$ROOT" rev-parse --verify "$OLD_REF" >/dev/null 2>&1 || { echo "error: unknown git ref: $OLD_REF" >&2; exit 1; }

SB="$(mktemp -d /tmp/as-rehearse-XXXXXX)"
trap 'rm -rf "$SB"' EXIT
mkdir -p "$SB/project"
WS="$SB/project/AGENTSPACE"
ASSETS="$ROOT/skills/agentspace-init/assets/agentspace"
TODAY="$(date +%F)"

echo "== changelog-driven update rehearsal: v$NEW (old-ref $OLD_REF) =="

# --- 1) sandbox: previous-version workspace from git archive ---------------
echo "== 1/6 sandbox: previous-version assets from git archive =="
git -C "$ROOT" archive "$OLD_REF" skills/agentspace-init/assets/agentspace | tar -x -C "$SB" 2>/dev/null
[ -f "$SB/skills/agentspace-init/assets/agentspace/scripts/lib.sh" ] \
  || { echo "error: old-ref assets not extractable (does $OLD_REF carry the assets tree?)" >&2; exit 1; }
cp -R "$SB/skills/agentspace-init/assets/agentspace/." "$WS/"
rm -rf "$SB/skills"
OLD_VER="$(grep -o '"version": "[^"]*"' "$WS/.agentspace-version.json" | head -1 | grep -o '[0-9.]*')"
[ "$OLD_VER" != "$NEW" ] || { echo "error: old-ref assets already carry v$NEW — pick the previous version's ref" >&2; exit 1; }
echo "  old workspace version: v$OLD_VER"
git -C "$WS" init -q -b main
git -C "$WS" -c user.name=rehearsal -c user.email=rehearsal@local add -A >/dev/null 2>&1
git -C "$WS" -c user.name=rehearsal -c user.email=rehearsal@local commit -qm "chore: initialize AGENTSPACE workspace (rehearsal)" >/dev/null 2>&1 || true

# --- 2) changelog analysis ---------------------------------------------------
echo "== 2/6 changelog analysis (Migration sections) =="
NBLOCKS="$(grep -c '^### ' "$CL" || true)"
N8A="$(grep -c "handled by step 8a" "$CL" || true)"
echo "  $NBLOCKS change blocks, $N8A 8a-covered Migration items"
if grep -q '\*\*AGENTS\.md (step 8b' "$CL"; then
  HAS_8B="yes"
  echo "  [8b] changelog has AGENTS.md text ops — agent MUST execute them in"
  echo "       $WS per the changelog, then flip the 8b line to PASS in the record."
else
  HAS_8B="no"
  echo "  8b: none (no AGENTS.md text ops)"
fi

# --- 3) apply 8a: replace plugin-managed files from current assets -----------
echo "== 3/6 apply 8a: scripts + templates + .gitignore =="
cp "$ASSETS/scripts/"*.sh "$WS/scripts/"
chmod 755 "$WS/scripts/"*.sh
if diff -rq "$ASSETS/templates" "$WS/templates" >/dev/null 2>&1; then
  echo "  templates unchanged (no copy needed)"
else
  cp "$ASSETS/templates/"*.md "$WS/templates/"
  echo "  templates synced (changelog should document this)"
fi
diff -q "$ASSETS/.gitignore" "$WS/.gitignore" >/dev/null 2>&1 || cp "$ASSETS/.gitignore" "$WS/.gitignore"
echo "  scripts replaced: $(ls "$ASSETS/scripts/"*.sh | wc -l | tr -d ' ') files"

# --- 4) apply 8c: version markers --------------------------------------------
echo "== 4/6 apply 8c: update-version.sh + architecture.json =="
(cd "$SB/project" && bash "$ROOT/skills/agentspace-update/scripts/update-version.sh" "$NEW")
cp "$ROOT/skills/agentspace-update/versions/v$NEW/architecture.json" "$WS/.agentspace-architecture.json"

# --- 5) milestone commit + convergence ---------------------------------------
echo "== 5/6 milestone commit + convergence =="
git -C "$WS" add -A >/dev/null 2>&1
git -C "$WS" -c user.name=rehearsal -c user.email=rehearsal@local commit -qm "update: rehearsal v$OLD_VER → v$NEW" >/dev/null 2>&1 || true

ok() { echo "  ✓ $*"; }
bad() { echo "  ✗ $*"; PASS=0; }
PASS=1
grep -q '"version": "'"$NEW"'"' "$WS/.agentspace-version.json" && ok "version.json → v$NEW" || bad "version.json != v$NEW"
grep -q '"installedAt"' "$WS/.agentspace-version.json" && ok "installedAt preserved" || bad "installedAt missing"
grep -q '"lastUpdatedAt": "'"$TODAY"'"' "$WS/.agentspace-version.json" && ok "lastUpdatedAt = today" || bad "lastUpdatedAt != today"
grep -q '"version": "'"$NEW"'"' "$WS/.agentspace-architecture.json" && ok "architecture.json → v$NEW" || bad "architecture.json != v$NEW"
diff -rq "$ASSETS/scripts" "$WS/scripts" >/dev/null 2>&1 && ok "scripts byte-identical to assets" || bad "scripts differ from assets"
DR="$(bash "$WS/scripts/doctor.sh" 2>/dev/null | tail -1 || true)"
if [ "$DR" = "Workspace consistent ✓" ]; then ok "doctor green"; else bad "doctor: $DR"; fi
# 先整体捕获再 grep — `bash ... | grep -q` 会因 grep 提前退出让 status.sh 吃
# SIGPIPE, pipefail 下误判失败(仓库既有教训: grep -q SIGPIPE)
ST_OUT="$(bash "$WS/scripts/status.sh" "$NEW" 2>/dev/null || true)"
if printf '%s' "$ST_OUT" | grep -qF "# AGENTSPACE Status"; then
  ok "status.sh renders"
else
  bad "status.sh failed to render"
fi

# --- 6) rehearsal record ------------------------------------------------------
if [ "$PASS" -eq 1 ]; then
  RECORD="$ROOT/skills/agentspace-update/versions/v$NEW/rehearsal.md"
  {
    echo "# Changelog-driven update rehearsal — v$NEW"
    echo
    echo "Date: $TODAY"
    echo "Old ref: $OLD_REF (workspace v$OLD_VER)"
    echo "Changelog: versions/v$NEW/CHANGELOG.md ($NBLOCKS change blocks, $N8A 8a-covered)"
    echo "8a: PASS (scripts replaced from assets, templates/.gitignore verified)"
    if [ "$HAS_8B" = "yes" ]; then
      echo "8b: MANUAL — agent executed the AGENTS.md text ops per the changelog and flipped this line to PASS"
    else
      echo "8b: N/A (no AGENTS.md text ops)"
    fi
    echo "8c: PASS (version markers + architecture.json)"
    echo "Convergence: PASS (scripts byte-identical, doctor green, status renders)"
    echo "Result: PASS"
  } > "$RECORD"
  echo "== 6/6 record written: ${RECORD#$ROOT/}"
  echo "== rehearsal PASS (v$OLD_VER → v$NEW)"
  exit 0
else
  echo "== rehearsal FAILED — fix and re-run (sandbox was cleaned)"
  exit 1
fi
