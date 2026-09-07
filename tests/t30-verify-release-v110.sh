#!/usr/bin/env bash
# t30: verify-release v1.1.0 extension checks + gate-false-negative smoke
# (same discipline as t14). Two new checks: [3] Summary-CJK policy (CHANGELOG
# is Chinese per DEVELOPMENT.md; historical English archives not retro-fitted)
# and [6b] reverse AGENTS.md section alignment ([6] only walks archive→asset,
# so an asset-side section without an architecture record passed silently).
# Baseline assertions only cover THESE markers — the working tree may carry
# other agents' pending red items (version markers / README rows), which this
# test must not gate on.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

SB="$(mktemp -d /tmp/as-test-t30-XXXXXX)" || fail "mktemp"
tar -C "$REPO" --exclude ./.git --exclude ./AGENTSPACE -cf - . | tar -xf - -C "$SB"
[ -f "$SB/verify-release.sh" ] || fail "working-tree snapshot not extractable"
LATEST="$(ls -d "$SB"/skills/agentspace-update/versions/v* | sed 's|.*/v||' | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)"
CL="$SB/skills/agentspace-update/versions/v$LATEST/CHANGELOG.md"
AG_ASSET="$SB/skills/agentspace-init/assets/agentspace/AGENTS.md"
run() { bash "$SB/verify-release.sh" 2>&1 || true; }

# baseline: neither new check fires on the unmutated tree
OUT="$(run)"
assert_output_not_contains "$OUT" "no CJK characters"
assert_output_not_contains "$OUT" "[6b]"

# [3] negative: Summary rewritten to English-only must fail the CJK policy
# (structural [3] strings — Summary/Changes/Migration/blocks — stay intact, so
# the ONLY new finding is the language one)
python3 - "$CL" <<'EOF'
import re, sys
p = sys.argv[1]
t = open(p).read()
t2 = re.sub(r"(## Summary\n).*?(\n## )", r"\1- English-only negative probe summary line.\n\2", t, flags=re.S)
assert t2 != t, "Summary rewrite did not apply"
open(p, "w").write(t2)
EOF
OUT="$(run)"
assert_output_contains "$OUT" "no CJK characters"
cp "$REPO/skills/agentspace-update/versions/v$LATEST/CHANGELOG.md" "$CL"

# [6b] negative: an asset-side section absent from the architecture snapshot
# must fail the reverse alignment (archive→asset [6] cannot see it)
printf '\n## 负向探针节\n\nprobe section for negative smoke\n' >> "$AG_ASSET"
OUT="$(run)"
assert_output_contains "$OUT" "[6b]"
assert_output_contains "$OUT" "负向探针节"
cp "$REPO/skills/agentspace-init/assets/agentspace/AGENTS.md" "$AG_ASSET"

# both mutations restored → neither marker fires again
OUT="$(run)"
assert_output_not_contains "$OUT" "no CJK characters"
assert_output_not_contains "$OUT" "[6b]"

rm -rf "$SB"
echo "t30 PASS: verify-release Summary-CJK + [6b] reverse sections (positive + negatives)"
