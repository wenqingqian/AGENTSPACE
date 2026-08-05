#!/usr/bin/env bash
# t14: verify-release negative smoke — the release gate must ACTUALLY fail on a
# broken archive (gate-false-negative discipline, cf. notes/gate-false-negative).
# Sandbox = git archive HEAD snapshot; a baseline run must pass, then dropping
# the latest CHANGELOG's ## Summary line must make the gate fail with a [3]
# finding. Guards the gate itself, which t01-t13 never exercise.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

SB="$(mktemp -d /tmp/as-test-t14-XXXXXX)" || fail "mktemp"
git -C "$REPO" archive HEAD | tar -x -C "$SB" 2>/dev/null
[ -f "$SB/verify-release.sh" ] || fail "repo snapshot not extractable"

# baseline: a clean HEAD snapshot must pass the gate
OUT="$(bash "$SB/verify-release.sh" 2>&1 || true)"
assert_output_contains "$OUT" "[pass] release-ready"

# break the latest CHANGELOG: drop its ## Summary line (verify [3] requires it)
LATEST="$(ls -d "$SB"/skills/agentspace-update/versions/v* | sed 's|.*/v||' | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)"
CL="$SB/skills/agentspace-update/versions/v$LATEST/CHANGELOG.md"
grep -vF "## Summary" "$CL" > "$CL.tmp" && mv "$CL.tmp" "$CL"

OUT="$(bash "$SB/verify-release.sh" 2>&1 || true)"
assert_output_contains "$OUT" "[fail]"
assert_output_contains "$OUT" "[3]"

rm -rf "$SB"
echo "PASS t14"
