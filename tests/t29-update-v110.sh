#!/usr/bin/env bash
# t29: update-skill v1.1.0 deliverables.
# versions/v1.1.0/ carries the full trio (CHANGELOG.md / architecture.json /
# rehearsal.md); the changelog carries the two migration markers (step 8b
# AGENTS.md block, step 8a coverage note); the architecture snapshot lists the
# new 用户规则 section and records both COMMIT_CANDIDATE_* constants byte-
# identical to the assets lib.sh (single source); the update flow's step 8b
# preserves the user-owned 用户规则 section verbatim; the rehearsal record is
# a PASS.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

V="$REPO/skills/agentspace-update/versions/v1.1.0"
for f in CHANGELOG.md architecture.json rehearsal.md; do
  [ -f "$V/$f" ] || fail "v1.1.0 archive missing $f"
done

# changelog migration markers
assert_contains "$V/CHANGELOG.md" "**AGENTS.md (step 8b"
assert_contains "$V/CHANGELOG.md" "handled by step 8a"

# rehearsal record must be a PASS (verify-release [11] depends on this line)
grep -Fq "Result: PASS" "$V/rehearsal.md" || fail "v1.1.0 rehearsal is not a PASS"

# update flow: step 8b must preserve the user-owned section verbatim
US="$REPO/skills/agentspace-update/SKILL.md"
[ -f "$US" ] || fail "update SKILL.md missing"
assert_contains "$US" "Preserve the 用户规则 section verbatim"

# architecture snapshot: 用户规则 section + the two candidate constants,
# byte-identical to the assets lib.sh declarations (extracted at runtime so
# this file never realizes them — single-source cross-check)
LIB="$REPO/skills/agentspace-init/assets/agentspace/scripts/lib.sh"
PLAN_RE="$(sed -n 's/^readonly COMMIT_CANDIDATE_PLAN_RE="\(.*\)"$/\1/p' "$LIB")"
ITER_RE="$(sed -n 's/^readonly COMMIT_CANDIDATE_ITER_RE="\(.*\)"$/\1/p' "$LIB")"
[ -n "$PLAN_RE" ] && [ -n "$ITER_RE" ] || fail "candidate constants unreadable from assets lib.sh"
python3 - "$V/architecture.json" "$PLAN_RE" "$ITER_RE" <<'EOF' || fail "architecture.json v1.1.0 contract violated"
import json, sys
d = json.load(open(sys.argv[1]))
secs = d["files"]["AGENTS.md"]["sections"]
assert "用户规则" in secs, f"用户规则 section missing: {sorted(secs)}"
assert d["constants"]["COMMIT_CANDIDATE_PLAN_RE"] == sys.argv[2], "PLAN candidate constant drift"
assert d["constants"]["COMMIT_CANDIDATE_ITER_RE"] == sys.argv[3], "ITER candidate constant drift"
EOF

echo "t29 PASS: versions/v1.1.0 trio + update SKILL.md 8b preservation"
