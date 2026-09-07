#!/usr/bin/env bash
# t03: doctor checks — green on a consistent workspace; red on: broken table
# link [4], placeholder-constant drift [5], duplicated 结果 section [3] (F1
# backstop). Each case uses a fresh sandbox.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

# --- baseline: consistent workspace is green ---
SB="$(build_sandbox t03a)"
WS="$SB/AGENTSPACE"
assert_ok bash "$WS/scripts/doctor.sh"
rm -rf "$SB"

# --- [4]+[2] broken link in a script-managed table (test-only tamper) —
# the injected row also trips [2] (orphan Todo row); both issues are intended ---
SB="$(build_sandbox t03b)"
WS="$SB/AGENTSPACE"
python3 - "$WS/plan.md" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read()
s = s.replace("| --- | --- | --- | --- |",
              "| --- | --- | --- | --- |\n| 9999 | Broken | 2026-08-03 | [missing-file.md](missing-file.md) |", 1)
open(p, "w").write(s)
EOF
assert_fails bash "$WS/scripts/doctor.sh"
rm -rf "$SB"

# --- [5] placeholder-constant drift: template comment rewritten ---
SB="$(build_sandbox t03c)"
WS="$SB/AGENTSPACE"
python3 - "$WS/templates/iteration-readme.md" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read()
s = s.replace("<!-- 指标 / 结论; 关闭 iteration 前必填 -->", "<!-- 已填写 -->")
open(p, "w").write(s)
EOF
assert_fails bash "$WS/scripts/doctor.sh"
rm -rf "$SB"

# --- [3] F1 backstop: in-progress readme with duplicated 结果 section ---
SB="$(build_sandbox t03d)"
WS="$SB/AGENTSPACE"
OUT="$(bash "$WS/scripts/new-plan.sh" "dup section plan")"
PID="$(printf '%s' "$OUT" | grep -o 'plan:[0-9]*' | cut -d: -f2)"
OUT2="$(bash "$WS/scripts/new-iteration.sh" "$PID" "dup test")"
IID="$(printf '%s' "$OUT2" | grep -o 'iteration_[0-9]*' | head -1 | cut -d_ -f2)"
README="$WS/iterations/iteration_$IID/readme.md"
# fill the resume block first — the duplicate-结果 warning (F1) must be the
# only reason this fails, not the resume-freshness check
python3 - "$README" <<'EOF'
import re, sys
p = sys.argv[1]
s = open(p).read()
s = re.sub(r"<!-- 会话续接块:.*?-->", "当前状态: 测试中; 下一步: 无", s, flags=re.S)
open(p, "w").write(s)
EOF
# duplicate the 结果 heading (v0.2.3-era template regression shape)
sed -i '' '/^## 结果$/p' "$README"
OUT="$(bash "$WS/scripts/doctor.sh" 2>&1 || true)"
assert_output_contains "$OUT" "duplicated '## 结果'"
assert_output_not_contains "$OUT" "resume placeholder still present"
rm -rf "$SB"

# --- [1] auto-repair: broken latest symlink is removed and recreated ---
SB="$(build_sandbox t03e)"
WS="$SB/AGENTSPACE"
OUT="$(bash "$WS/scripts/new-plan.sh" "repair symlink plan")"
PID="$(printf '%s' "$OUT" | grep -o 'plan:[0-9]*' | cut -d: -f2)"
OUT2="$(bash "$WS/scripts/new-iteration.sh" "$PID" "repair test")"
IID="$(printf '%s' "$OUT2" | grep -o 'iteration_[0-9]*' | head -1 | cut -d_ -f2)"
README="$WS/iterations/iteration_$IID/readme.md"
# fill the resume block first — the broken-symlink issue must be the reason
# this fails, not the resume-freshness check
python3 - "$README" <<'EOF'
import re, sys
p = sys.argv[1]
s = open(p).read()
s = re.sub(r"<!-- 会话续接块:.*?-->", "当前状态: 测试中; 下一步: 无", s, flags=re.S)
open(p, "w").write(s)
EOF
git -C "$WS" add -A >/dev/null 2>&1
git -C "$WS" commit -qm "test: t03e milestone" >/dev/null 2>&1
ln -sf nonexistent "$WS/iterations/latest"
# doctor counts the broken-symlink issue (exit 1) AND auto-repairs the link
assert_fails bash "$WS/scripts/doctor.sh"
[ "$(readlink "$WS/iterations/latest")" = "iteration_$IID" ] || fail "latest symlink not repaired"
rm -rf "$SB"

echo "PASS t03"
