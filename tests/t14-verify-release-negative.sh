#!/usr/bin/env bash
# t14: verify-release negative smoke — the release gate must ACTUALLY fail on
# broken inputs (gate-false-negative discipline, cf. notes/gate-false-negative).
# Sandbox = working-tree snapshot (.git + nested ledger excluded): the release
# gate runs BEFORE the release commit, so the negative smoke must exercise the
# tree that is about to be committed — the gate version under test is the
# working tree's. Baseline must pass; then each planted defect must fail with
# its check id: [11] rehearsal record dropped, [3] CHANGELOG ## Summary
# dropped, [12] realized bookkeeping id planted, [4] reverse constants pass.
# Guards the gate itself, which t01-t13 never exercise.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

SB="$(mktemp -d /tmp/as-test-t14-XXXXXX)" || fail "mktemp"
tar -C "$REPO" --exclude ./.git --exclude ./AGENTSPACE -cf - . | tar -xf - -C "$SB"
[ -f "$SB/verify-release.sh" ] || fail "working-tree snapshot not extractable"

# baseline: a clean snapshot must pass the gate
OUT="$(bash "$SB/verify-release.sh" 2>&1 || true)"
assert_output_contains "$OUT" "[pass] release-ready"

LATEST="$(ls -d "$SB"/skills/agentspace-update/versions/v* | sed 's|.*/v||' | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)"

# [11] negative: drop the rehearsal record of the latest version → gate must
# fail with a [11] finding (a new changelog without a PASSING rehearsal record
# is not release-ready)
REH="$SB/skills/agentspace-update/versions/v$LATEST/rehearsal.md"
[ -f "$REH" ] || fail "rehearsal record missing in snapshot — the gate's own baseline is broken"
mv "$REH" "$REH.bak"
OUT="$(bash "$SB/verify-release.sh" 2>&1 || true)"
assert_output_contains "$OUT" "[fail]"
assert_output_contains "$OUT" "[11]"
mv "$REH.bak" "$REH"

# [3] negative: drop the latest CHANGELOG's ## Summary line (verify [3]
# requires it)
CL="$SB/skills/agentspace-update/versions/v$LATEST/CHANGELOG.md"
grep -vF "## Summary" "$CL" > "$CL.tmp" && mv "$CL.tmp" "$CL"
OUT="$(bash "$SB/verify-release.sh" 2>&1 || true)"
assert_output_contains "$OUT" "[fail]"
assert_output_contains "$OUT" "[3]"
cp "$REPO/skills/agentspace-update/versions/v$LATEST/CHANGELOG.md" "$CL"

# [12] negative: a REALIZED canonical bookkeeping id planted in a tracked file
# must fail the realized-literal guard (self-hosting: the plugin repo runs
# under its own valveless gate — such a literal would block future edits).
# The id is constructed at runtime so THIS file stays clean.
T18="$SB/tests/t18-commit-gate.sh"
printf '# planted realized id for negative smoke: plan:%04d\n' 123 >> "$T18"
OUT="$(bash "$SB/verify-release.sh" 2>&1 || true)"
assert_output_contains "$OUT" "[fail]"
assert_output_contains "$OUT" "[12]"
assert_output_contains "$OUT" "[issue] realized bookkeeping id:"
assert_output_contains "$OUT" "planted realized id"
cp "$REPO/tests/t18-commit-gate.sh" "$T18"

# [12] negative, uppercase variant: the guard is case-insensitive (as the
# gate's message scan is) — an UPPERCASE realized id must fail it too
printf '# planted realized id for negative smoke: PLAN:%04d\n' 7 >> "$T18"
OUT="$(bash "$SB/verify-release.sh" 2>&1 || true)"
assert_output_contains "$OUT" "[fail]"
assert_output_contains "$OUT" "[12]"
assert_output_contains "$OUT" "realized bookkeeping id"
cp "$REPO/tests/t18-commit-gate.sh" "$T18"

# [4] reverse negative: a COMMIT_* constant declared in assets lib.sh but
# missing from the architecture snapshot must fail (forward pass alone cannot
# catch lib→arch drift)
LIB="$SB/skills/agentspace-init/assets/agentspace/scripts/lib.sh"
printf '\nreadonly COMMIT_NEGATIVE_PROBE="1" # planted\n' >> "$LIB"
OUT="$(bash "$SB/verify-release.sh" 2>&1 || true)"
assert_output_contains "$OUT" "[fail]"
assert_output_contains "$OUT" "COMMIT_NEGATIVE_PROBE"
cp "$REPO/skills/agentspace-init/assets/agentspace/scripts/lib.sh" "$LIB"

# planted defects all restored → the gate must pass again
OUT="$(bash "$SB/verify-release.sh" 2>&1 || true)"
assert_output_contains "$OUT" "[pass] release-ready"

rm -rf "$SB"
echo "PASS t14"
