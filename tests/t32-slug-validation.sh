#!/usr/bin/env bash
# t32: new-plan.sh slug hard-check (v1.2.1) — compliant titles pass; CJK /
# uppercase / underscore / punctuation-only (empty slug) titles are refused
# BEFORE any file or table row is written, and refused attempts never consume
# a plan id. Existing plan files are never touched.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

SB="$(build_sandbox t32)"
WS="$SB/AGENTSPACE"
NP="$WS/scripts/new-plan.sh"
n_docs() { ls "$WS"/plan/todo/*.md 2>/dev/null | wc -l | tr -d ' '; }
n_index() { awk '/^\| [0-9]/ { n++ } END { print n+0 }' "$WS/plan/index.md"; }

# --- compliant title: plan created, file carries the slug ---
OUT="$(bash "$NP" "baseline reproduction")"
assert_output_contains "$OUT" "$(printf 'plan:%04d' 1) created"
[ -f "$WS/plan/todo/0001-baseline-reproduction.md" ] || fail "compliant plan doc missing"
[ "$(n_docs)" = "1" ] || fail "expected exactly 1 plan doc"
[ "$(n_index)" = "1" ] || fail "expected exactly 1 index row"

# --- refusals: CJK / uppercase / underscore / trailing hyphen / empty slug ---
refused() {  # <title>: must exit non-zero, write nothing, name the contract
  local title="$1" out
  out="$(bash "$NP" "$title" 2>&1 || true)"
  assert_output_contains "$out" "plan slug not allowed"
  assert_output_contains "$out" "lowercase english title"
}
refused "训练基线复现"
refused "Baseline Reproduction"
refused "snake_case title"
refused "trailing-hyphen-"
refused "???"              # every char strippable -> empty slug -> <empty> in the error
out="$(bash "$NP" "???" 2>&1 || true)"
assert_output_contains "$out" "<empty>"

# --- nothing was written by any refused attempt ---
[ "$(n_docs)" = "1" ] || fail "a refused title leaked a plan doc"
[ "$(n_index)" = "1" ] || fail "a refused title leaked an index row"
assert_not_contains "$WS/plan.md" "$(printf '| %04d ' 2)"

# --- refused attempts never consume ids: next compliant plan is 0002 ---
OUT="$(bash "$NP" "second compliant title")"
assert_output_contains "$OUT" "$(printf 'plan:%04d' 2) created"
[ -f "$WS/plan/todo/0002-second-compliant-title.md" ] || fail "second plan doc missing"
[ "$(n_docs)" = "2" ] || fail "expected exactly 2 plan docs"

# --- existing plans untouched: first doc intact, still completable ---
[ -f "$WS/plan/todo/0001-baseline-reproduction.md" ] || fail "first plan doc disturbed"
DOC="$WS/plan/todo/0001-baseline-reproduction.md"
python3 - "$DOC" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read()
s = s.replace("<!-- 完成时填写: 一句话结论", "一句话结论: done")
open(p, "w").write(s)
EOF
assert_ok bash "$WS/scripts/complete-plan.sh" "$(printf '%04d' 1)" done "slug ok"

rm -rf "$SB"
echo "t32 PASS: slug hard-check — compliant passes, CJK/uppercase/underscore/empty refused, ids not consumed, existing plans untouched"
