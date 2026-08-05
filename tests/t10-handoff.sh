#!/usr/bin/env bash
# t10: handoff lifecycle — produce (named/auto/conflict-refusal/CJK/|refusal),
# list (fields, no header/separator leak), consume (delete / --keep /
# unknown-name / regex-metachar safety / file-missing). All writes through
# handoff.sh; the index self-initializes when absent.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

SB="$(build_sandbox t10)"
WS="$SB/AGENTSPACE"
HS="$WS/scripts/handoff.sh"
INDEX="$WS/handoff/index.md"

# --- produce with an explicit semantic name ---
OUT="$(bash "$HS" --produce --name "summarization-baseline" --description "基线实验收尾, 下一步微调" 2>&1)"
assert_output_contains "$OUT" "handoff produced"
[ -f "$WS/handoff/handoff_summarization-baseline.md" ] || fail "handoff file not created"
assert_contains "$INDEX" "| summarization-baseline | 基线实验收尾, 下一步微调 | handoff_summarization-baseline.md |"

# --- name conflict: refused, never auto-renamed ---
OUT="$(bash "$HS" --produce --name "summarization-baseline" 2>&1 || true)"
assert_output_contains "$OUT" "already indexed"
[ -f "$WS/handoff/handoff_summarization-baseline-2.md" ] && fail "-2 auto-rename must never happen"

# --- produce without a name: script fallback session-<ts> ---
OUT="$(bash "$HS" --produce 2>&1)"
assert_output_contains "$OUT" "handoff produced"
[ "$(ls "$WS"/handoff/handoff_session-*.md | wc -l | tr -d ' ')" -eq 1 ] || fail "session fallback file missing"

# --- produce with CJK name: slug keeps CJK, consume round-trip works ---
OUT="$(bash "$HS" --produce --name "基线实验收尾" 2>&1)"
assert_output_contains "$OUT" "handoff produced"
[ -f "$WS/handoff/handoff_基线实验收尾.md" ] || fail "CJK handoff file missing"

# --- name with | is refused up front (stored/checked/consumed forms stay in sync) ---
OUT="$(bash "$HS" --produce --name "bad|name" 2>&1 || true)"
assert_output_contains "$OUT" "must not contain"
[ ! -f "$WS/handoff/handoff_bad_name.md" ] || fail "| name must not produce a file"

# --- description with | is sanitized into one intact row ---
OUT="$(bash "$HS" --produce --name "piped-desc" --description "a | b" 2>&1)"
assert_output_contains "$OUT" "handoff produced"
assert_contains "$INDEX" "| piped-desc | a \\| b | handoff_piped-desc.md |"

# --- list: correct fields (description+time visible), no header/separator leak ---
OUT="$(bash "$HS" --list)"
assert_output_contains "$OUT" "summarization-baseline | 基线实验收尾, 下一步微调 | handoff_summarization-baseline.md |"
assert_output_contains "$OUT" "基线实验收尾"
assert_output_not_contains "$OUT" "name |"
assert_output_not_contains "$OUT" "---"

# --- consume without --name: refuses and points at --list ---
OUT="$(bash "$HS" --consume 2>&1 || true)"
assert_output_contains "$OUT" "consume requires --name"

# --- consume unknown name: refused ---
OUT="$(bash "$HS" --consume --name "no-such-handoff" 2>&1 || true)"
assert_output_contains "$OUT" "not indexed"

# --- consume regex-metachar safety: "a.b" must not take "axb" with it ---
OUT="$(bash "$HS" --produce --name "a.b" 2>&1)"
assert_output_contains "$OUT" "handoff produced"
OUT="$(bash "$HS" --produce --name "axb" 2>&1)"
assert_output_contains "$OUT" "handoff produced"
OUT="$(bash "$HS" --consume --name "a.b" 2>&1)"
assert_output_contains "$OUT" "consumed"
[ ! -f "$WS/handoff/handoff_a.b.md" ] || fail "a.b file not deleted"
[ -f "$WS/handoff/handoff_axb.md" ] || fail "axb file wrongly deleted"
assert_contains "$INDEX" "| axb |"
assert_not_contains "$INDEX" "| a.b |"

# --- consume --keep: file and index row both survive ---
OUT="$(bash "$HS" --consume --keep --name "summarization-baseline" 2>&1)"
assert_output_contains "$OUT" "kept"
[ -f "$WS/handoff/handoff_summarization-baseline.md" ] || fail "--keep deleted the file"
assert_contains "$INDEX" "| summarization-baseline |"

# --- consume: file + index row removed ---
OUT="$(bash "$HS" --consume --name "summarization-baseline" 2>&1)"
assert_output_contains "$OUT" "consumed"
[ ! -f "$WS/handoff/handoff_summarization-baseline.md" ] || fail "file not deleted on consume"
assert_not_contains "$INDEX" "summarization-baseline"

# --- index self-init: shipped index deleted -> produce recreates it ---
rm "$INDEX"
OUT="$(bash "$HS" --produce --name "self-init" 2>&1)"
assert_output_contains "$OUT" "handoff produced"
assert_contains "$INDEX" "| self-init |"

# --- consume file-missing path: row present, file gone -> clear refusal ---
rm "$WS/handoff/handoff_self-init.md"
OUT="$(bash "$HS" --consume --name "self-init" 2>&1 || true)"
assert_output_contains "$OUT" "handoff file missing"

# --- handoff is in doctor scope: the dangling row left by the file-missing
#     case is exactly doctor [10]; --fix removes the row. The four orphan files
#     (rows destroyed when index.md was recreated in the self-init test) are
#     reported but never deleted by doctor — the user removes them manually ---
OUT="$(bash "$WS/scripts/doctor.sh" --fix 2>&1 || true)"
assert_output_contains "$OUT" "removed dangling handoff row"
assert_output_contains "$OUT" "not indexed"
[ -f "$WS/handoff/handoff_axb.md" ] || fail "--fix must never delete an orphan handoff file"
rm "$WS"/handoff/handoff_*.md   # user cleanup per doctor's guidance
git -C "$WS" add -A >/dev/null 2>&1
git -C "$WS" commit -qm "test: t10 milestone" >/dev/null 2>&1 || true
assert_ok bash "$WS/scripts/doctor.sh"

rm -rf "$SB"
echo "PASS t10"
