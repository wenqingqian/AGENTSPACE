#!/usr/bin/env bash
# t05: register-module — happy path creates <name>/ + .gitkeep + <name>.md
# entry (template filled) + register.md row; duplicate and invalid names
# (regex ^[a-z0-9][a-z0-9-]*$) must be rejected.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

SB="$(build_sandbox t05)"
WS="$SB/AGENTSPACE"

# (a) happy path
assert_ok bash "$WS/scripts/register-module.sh" viz "charting lib"
[ -d "$WS/viz" ] || fail "viz/ dir not created"
[ -f "$WS/viz/.gitkeep" ] || fail "viz/.gitkeep not created"
[ -f "$WS/viz.md" ] || fail "viz.md entry not created"
assert_contains "$WS/viz.md" "# viz"
assert_contains "$WS/viz.md" "> 用途: charting lib"
assert_contains "$WS/viz.md" "> 注册: $(date +%F)"
assert_contains "$WS/register.md" "| viz | charting lib |"

# (b) duplicate registration of the same name must fail
assert_fails bash "$WS/scripts/register-module.sh" viz "again"

# (c) invalid names must fail (uppercase / special chars vs the name regex)
assert_fails bash "$WS/scripts/register-module.sh" "Viz" "uppercase"
assert_fails bash "$WS/scripts/register-module.sh" "viz_extra" "underscore"
assert_fails bash "$WS/scripts/register-module.sh" "viz extra" "space"

# workspace still consistent (milestone commit first — wrap-up protocol)
git -C "$WS" add -A >/dev/null 2>&1
git -C "$WS" commit -qm "test: register-module milestone" >/dev/null 2>&1
assert_ok bash "$WS/scripts/doctor.sh"

rm -rf "$SB"
echo "PASS t05"
