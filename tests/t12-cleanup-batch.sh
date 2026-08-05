#!/usr/bin/env bash
# t12: v0.4.2 batch — doctor [12] register module consistency (report-only,
# no --fix) and close-iteration auto host-diff collection (data/diff-*.patch).
set -euo pipefail
. "$(dirname "$0")/lib.sh"

SB="$(build_sandbox t12)"
WS="$SB/AGENTSPACE"
DOC="$WS/scripts/doctor.sh"
REG="$WS/scripts/register-module.sh"
NEWP="$WS/scripts/new-plan.sh"
NEWI="$WS/scripts/new-iteration.sh"
CLOSE="$WS/scripts/close-iteration.sh"

mc() { git -C "$WS" add -A >/dev/null 2>&1; git -C "$WS" commit -qm "test: t12 milestone" >/dev/null 2>&1 || true; }

# --- [12] register consistency: registered module = NAME.md + NAME/ ---
bash "$REG" "visual" "可视化工具" >/dev/null 2>&1
mc
assert_ok bash "$DOC"                       # pair intact → green
rm -rf "$WS/visual"
OUT="$(bash "$DOC" 2>&1 || true)"
assert_output_contains "$OUT" "missing visual/ directory"
rm "$WS/visual.md"
OUT="$(bash "$DOC" 2>&1 || true)"
assert_output_contains "$OUT" "missing visual.md"
OUT="$(bash "$DOC" --fix 2>&1 || true)"
assert_output_contains "$OUT" "missing visual.md"   # report-only: --fix must not repair
mkdir "$WS/visual" && : > "$WS/visual.md"           # manual restore
mc
assert_ok bash "$DOC"
# malformed name (hand-edit artifact)
awk '{ print; if (index($0, "| visual |")) print "| Bad Name | x | [Bad Name.md](Bad Name.md) | 2026-08-05 |" }' "$WS/register.md" > "$WS/register.md.tmp" && mv "$WS/register.md.tmp" "$WS/register.md"
OUT="$(bash "$DOC" 2>&1 || true)"
assert_output_contains "$OUT" "malformed module name"
grep -vF "| Bad Name |" "$WS/register.md" > "$WS/register.md.tmp" && mv "$WS/register.md.tmp" "$WS/register.md"
mc
assert_ok bash "$DOC"

# --- close-iteration: auto host-diff collection ---
bash "$NEWP" "Diff collection test plan" >/dev/null 2>&1
PLAN="$(ls "$WS"/plan/todo/ | head -1 | cut -d- -f1)"
mc
bash "$NEWI" "$PLAN" "auto diff collection test" >/dev/null 2>&1
ITER="$(ls -d "$WS"/iterations/iteration_[0-9]* | sort | tail -1 | xargs basename | sed 's/iteration_//')"
mc
# host change + commit (start..end window)
printf 'host change for diff\n' >> "$SB/AGENTS.md"
git -C "$SB" add -A >/dev/null 2>&1
git -C "$SB" -c user.name=test -c user.email=test@test commit -qm "test: host change" >/dev/null 2>&1
# fill the 结果 section (close gate) and close
grep -vF "指标 / 结论" "$WS/iterations/iteration_$ITER/readme.md" > "$WS/iterations/iteration_$ITER/readme.md.tmp" && mv "$WS/iterations/iteration_$ITER/readme.md.tmp" "$WS/iterations/iteration_$ITER/readme.md"
OUT="$(bash "$CLOSE" "$ITER" "diff collected automatically" 2>&1)"
assert_output_contains "$OUT" "code diff saved"
PATCH="$(ls "$WS/iterations/iteration_$ITER"/data/diff-*.patch 2>/dev/null | head -1)"
[ -n "$PATCH" ] || fail "auto-diff patch not created"
assert_contains "$PATCH" "host change for diff"
mc
assert_ok bash "$DOC"

rm -rf "$SB"
echo "PASS t12"
