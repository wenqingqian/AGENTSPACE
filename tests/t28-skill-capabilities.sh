#!/usr/bin/env bash
# t28: plugin-side skill capabilities shipped with v1.1.0 (EN SKILL.md text).
# doctor: Phase C gains Block 6 (notes content-quality audit) and Block 7
# (cross-plan conflict audit), both report-only forever; plan documents are
# user-owned in all modes/tiers. code-clean: the gate prints report-only
# wide-net CANDIDATES the agent must adjudicate, plus the Batch Comment
# Review mode (whole-file, multi-subagent, report-only, explicit trigger).
set -euo pipefail
. "$(dirname "$0")/lib.sh"

DOC="$REPO/skills/agentspace-doctor/SKILL.md"
[ -f "$DOC" ] || fail "doctor SKILL.md missing"
for s in "Block 6" "Block 7" \
         "notes 内容质量审核" "跨 plan 冲突审核" \
         "Report-only forever" "report-only forever" \
         "Plan documents are user-owned"; do
  assert_contains "$DOC" "$s"
done

CC="$REPO/skills/agentspace-code-clean/SKILL.md"
[ -f "$CC" ] || fail "code-clean SKILL.md missing"
for s in "## Batch Comment Review" \
         "CANDIDATES" \
         "wide-net candidates" \
         "never block" \
         "adjudicate every candidate" \
         "explicit trigger only"; do
  assert_contains "$CC" "$s"
done

echo "t28 PASS: doctor Blocks 6/7 + code-clean candidates/batch review"
