#!/usr/bin/env bash
# t09: init self-check — /agentspace-init runs doctor.sh at the end and reports
# "初始化一致性" on a fresh, green workspace (v0.3.1).
set -euo pipefail
. "$(dirname "$0")/lib.sh"

SB="$(mktemp -d "/tmp/as-test-t09-XXXXXX")" || exit 1
mkdir -p "$SB/project"
set +e
OUT="$(cd "$SB/project" && bash "$REPO/skills/agentspace-init/scripts/init-agentspace.sh" 2>&1)"
rc=$?
set -e
[ "$rc" -eq 0 ] || fail "init exited $rc"
assert_output_contains "$OUT" "== Self-check (doctor) =="
assert_output_contains "$OUT" "初始化一致性 ✓"
rm -rf "$SB"

echo "PASS t09"
