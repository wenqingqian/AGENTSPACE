#!/usr/bin/env bash
# t27: asset AGENTS.md v1.1.0 structure (用户规则 split).
# The `## 用户规则` section exists, comes after `## 纪律`, and is the LAST
# section; the 纪律 section gained the two new MUSTs at the changelog-pinned
# position (after 脚本报错恢复, before the unprefixed 内容文档 line); the
# milestone-trigger line carries the `用户规则写入` trigger; the user-rules
# section carries its placeholder comment (no realized entries in the asset).
set -euo pipefail
. "$(dirname "$0")/lib.sh"

AG="$REPO/skills/agentspace-init/assets/agentspace/AGENTS.md"
[ -f "$AG" ] || fail "asset AGENTS.md missing"

# section presence + ordering: 纪律 < 用户规则, and 用户规则 is the last section
grep -Fq "## 纪律" "$AG" || fail "纪律 section missing"
grep -Fq "## 用户规则" "$AG" || fail "用户规则 section missing"
n_disc="$(grep -nF "## 纪律" "$AG" | cut -d: -f1)"
n_user="$(grep -nF "## 用户规则" "$AG" | cut -d: -f1)"
[ -n "$n_disc" ] && [ -n "$n_user" ] || fail "section headings unresolvable"
[ "$n_disc" -lt "$n_user" ] || fail "用户规则 must come after 纪律"
LAST="$(grep -n '^## ' "$AG" | tail -1)"
assert_output_contains "$LAST" "用户规则"

# the two new MUSTs live INSIDE 纪律 at the changelog-pinned position:
# 脚本报错恢复 < 用户规则守护 < 注释卫生 < 内容文档 < 用户规则 section
for s in "[MUST] 用户规则守护" "[MUST] 注释卫生" "[MUST] 脚本报错恢复" "内容文档("; do
  grep -Fq "$s" "$AG" || fail "expected '$s' in asset AGENTS.md"
done
n_anchor="$(grep -nF "[MUST] 脚本报错恢复" "$AG" | cut -d: -f1)"
n_must1="$(grep -nF "[MUST] 用户规则守护" "$AG" | cut -d: -f1)"
n_must2="$(grep -nF "[MUST] 注释卫生" "$AG" | cut -d: -f1)"
n_content="$(grep -nF "内容文档(" "$AG" | cut -d: -f1)"
[ "$n_anchor" -lt "$n_must1" ] || fail "用户规则守护 must follow 脚本报错恢复"
[ "$n_must1" -lt "$n_must2" ] || fail "注释卫生 must follow 用户规则守护"
[ "$n_must2" -lt "$n_content" ] || fail "注释卫生 must precede the 内容文档 line"
[ "$n_content" -lt "$n_user" ] || fail "纪律 MUSTs must precede the 用户规则 section"

# milestone trigger line gains 用户规则写入 before update 应用
ML="$(grep -F -- '- **里程碑 git 提交**' "$AG")"
[ -n "$ML" ] || fail "milestone trigger line missing"
assert_output_contains "$ML" "用户规则写入 · update 应用"

# user-rules section is the user-owned placeholder form (asset ships no entries)
grep -Fq "<!-- 用户规则条目从此处追加 -->" "$AG" || fail "user-rules placeholder missing"
n_ph="$(grep -nF "<!-- 用户规则条目从此处追加 -->" "$AG" | cut -d: -f1)"
[ "$n_ph" -gt "$n_user" ] || fail "placeholder must live inside the 用户规则 section"

echo "t27 PASS: asset AGENTS.md 用户规则 structure"
