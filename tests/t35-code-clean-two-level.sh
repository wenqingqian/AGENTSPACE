#!/usr/bin/env bash
# t35: code-clean two-level contract shipped with v1.4.0. Level 1 (passive,
# default) — SKILL.md carries the merged rule union (gate + x-better-commit
# commit-text rules + x-code-clean comment tiers). Level 2 (active,
# explicit-only) — CLEANUP.md carries the post-processing procedures (scope,
# classification, report-then-confirm, commit rewrite, history-rebuild safety,
# batch review) and is reached only via the SKILL.md pointer rule. Guards the
# seam against regressions: a rewrite that drops the pointer, moves procedure
# back into the default load, or lets EN/zh drift fails here.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

CC="$REPO/skills/agentspace-code-clean"
[ -f "$CC/CLEANUP.md" ] || fail "CLEANUP.md missing (active level)"
[ -f "$CC/CLEANUP.zh-CN.md" ] || fail "CLEANUP.zh-CN.md missing (active level)"

# --- Level 1: passive rule union lives in SKILL.md, pointer rule included ---
EN="$CC/SKILL.md"; ZH="$CC/SKILL.zh-CN.md"
for s in "## The Commit Gate (MUST)" \
         "## Commit-Text Rules" \
         "## Comment Rules" \
         "why the code is not written some other way" \
         "<type>: <summary>" \
         "read CLEANUP.md in this skill directory"; do
  assert_contains "$EN" "$s"
done
for s in "## 注释规则" \
         "为什么没用另一种写法" \
         "阅读本 skill 目录内的 CLEANUP.md"; do
  assert_contains "$ZH" "$s"
done

# --- Level 2: procedure doc carries the workflows, never the default load ---
CU="$CC/CLEANUP.md"; CUZ="$CC/CLEANUP.zh-CN.md"
for s in "## Report (before any edit)" \
         "## History rebuild (user decision, explicit request only)" \
         "Back up first" \
         "Iron rule" \
         "Assert-vs-example" \
         "Never auto-trigger this level" \
         "## Batch comment review (full procedure)"; do
  assert_contains "$CU" "$s"
done
for s in "## 报告(动手前)" \
         "## 历史重建(用户决定, 仅显式要求)" \
         "先备份" \
         "铁律" \
         "绝不自动触发" \
         "## 批量注释审查(完整流程)"; do
  assert_contains "$CUZ" "$s"
done

# --- CLEANUP heading parity EN vs zh (same discipline as verify-release [8]) ---
awk '/^```/{f=!f} !f' "$CU" | grep -o '^#\+' > /tmp/as-t35-en.$$
awk '/^```/{f=!f} !f' "$CUZ" | grep -o '^#\+' > /tmp/as-t35-zh.$$
if ! diff -q /tmp/as-t35-en.$$ /tmp/as-t35-zh.$$ >/dev/null; then
  rm -f /tmp/as-t35-en.$$ /tmp/as-t35-zh.$$
  fail "CLEANUP heading-level sequence mismatch (EN vs zh-CN)"
fi
rm -f /tmp/as-t35-en.$$ /tmp/as-t35-zh.$$

# --- platform-word ban extends to the procedure doc (t20 only scans SKILL*) ---
for doc in "$CU" "$CUZ"; do
  if grep -Eq 'ZCode|Codex|Kimi' "$doc"; then
    fail "CLEANUP contains platform-specific words: ${doc#$REPO/}"
  fi
done

echo "t35 PASS: code-clean two-level contract (SKILL union + CLEANUP procedures + bilingual parity)"
