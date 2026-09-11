#!/usr/bin/env bash
# t37: v1.5.1 gate-criteria batch — (1) results gates judge section CONTENT,
# not template-comment presence: a filled section keeps its guidance comments
# and passes, a comments-only section refuses with an actionable error
# (close-iteration / complete-plan / complete-exp). (2) transition scripts pin
# the milestone commit boundary with an exact ledger-commit command
# (as_commit_hint); new-iteration announces its plan-doc append so agents
# re-read, and the append keeps a blank line before the next heading.
# (3) commit-check refuses empty staging (vacuous PASS) and gains a --commit
# mode that commits byte-identical to the gated message. (4) handoff consume
# dumps the content before destroying it. (5) close-iteration's status-anomaly
# error names the readme status line it reads.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

SB="$(build_sandbox t37)"
WS="$SB/AGENTSPACE"

fill_results() {  # <file> <content> — replace the guidance comment, KEEP the other comments
  python3 - "$1" "$2" <<'EOF'
import sys
p, txt = sys.argv[1], sys.argv[2]
s = open(p).read()
s = s.replace("<!-- 完成时填写: 一句话结论 + 关键证据(iteration 引用 / 文件链接)。\n     有可迁移教训时, 同步记录 notes/ -->", txt)
s = s.replace("<!-- 指标 / 结论; 关闭 iteration 前必填 -->", txt)
s = s.replace("<!-- 一句话结论; 关闭 exp 前必填 -->", txt)
open(p, "w").write(s)
EOF
}

# ============ 1. results gates: content-based ============
OUT="$(bash "$WS/scripts/new-plan.sh" "gate keeps comments")"
ID="$(printf '%s' "$OUT" | grep -o 'plan:[0-9]*' | cut -d: -f2)"
DOC="$(ls "$WS"/plan/todo/"$ID"*.md)"

# comments-only section still refuses, with the new error naming the section
OUT2="$(bash "$WS/scripts/complete-plan.sh" "$ID" done "x" 2>&1 || true)"
assert_output_contains "$OUT2" "Results section is empty"
assert_output_contains "$OUT2" "guidance comments don't count"

# P1-1: a content line carrying an INLINE comment still counts as content
OUT="$(bash "$WS/scripts/new-iteration.sh" "$ID" "inline comment probe")"
IIDX="$(printf '%s' "$OUT" | grep -o 'iteration_[0-9]*' | head -1 | cut -d_ -f2)"
RX="$WS/iterations/iteration_$IIDX/readme.md"
python3 - "$RX" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read().replace("<!-- 指标 / 结论; 关闭 iteration 前必填 -->", "指标: latency -30% <!-- evidence inline -->")
open(p, "w").write(s)
EOF
bash "$WS/scripts/close-iteration.sh" "$IIDX" "inline comment close" || fail "as_section_filled discarded a line with an inline comment"

# close-iteration: comments-only 结果 refuses; filled-with-comments passes
OUT="$(bash "$WS/scripts/new-iteration.sh" "$ID" "close gate probe")"
IID="$(printf '%s' "$OUT" | grep -o 'iteration_[0-9]*' | head -1 | cut -d_ -f2)"
README="$WS/iterations/iteration_$IID/readme.md"
OUT2="$(bash "$WS/scripts/close-iteration.sh" "$IID" "x" 2>&1 || true)"
assert_output_contains "$OUT2" "Results section is empty"
fill_results "$README" "指标: all green"
bash "$WS/scripts/close-iteration.sh" "$IID" "comment-kept close" || fail "close-iteration rejected a comment-kept fill"

# complete-exp: register (config contract), fill keeping comments, close passes
OUT="$(bash "$WS/scripts/new-exp.sh" "gate exp probe" --plan "$ID")"
EID="$(printf '%s' "$OUT" | grep -o 'exp_[0-9]*' | head -1 | cut -d_ -f2)"
printf 'model: probe\n' > "$WS/examples/exp_spec/exp_$EID/probe.yaml"
EMANUAL="$(ls "$WS"/exp/todo/exp_$EID*.md)"
OUT2="$(bash "$WS/scripts/complete-exp.sh" "$EID" done "x" 2>&1 || true)"
assert_output_contains "$OUT2" "Results section is empty"
fill_results "$EMANUAL" "结论: probe closed"
CEXPOUT="$(bash "$WS/scripts/complete-exp.sh" "$EID" done "comment-kept exp close")" || fail "complete-exp rejected a comment-kept fill"
assert_output_contains "$CEXPOUT" "exp: complete $EID"
assert_output_contains "$CEXPOUT" "add exp.md exp/index.md exp/todo exp/doing"

# the plan itself: filled section that KEEPS the remaining template comments passes
fill_results "$DOC" "结论: gate now reads content"
bash "$WS/scripts/complete-plan.sh" "$ID" done "comment-kept fill" || fail "complete-plan rejected a comment-kept fill"

# ============ 2. milestone commit hints + append notice ============
OUT="$(bash "$WS/scripts/new-plan.sh" "commit hint probe")"
ID2="$(printf '%s' "$OUT" | grep -o 'plan:[0-9]*' | cut -d: -f2)"
assert_output_contains "$OUT" "Next [MUST]: ledger-commit now"
assert_output_contains "$OUT" "commit -m \"plan: open $ID2\""

OUT="$(bash "$WS/scripts/new-iteration.sh" "$ID2" "hint and notice probe")"
IID2="$(printf '%s' "$OUT" | grep -o 'iteration_[0-9]*' | head -1 | cut -d_ -f2)"
assert_output_contains "$OUT" "appended 相关迭代 → "
assert_output_contains "$OUT" "re-read that file before further edits"
assert_output_contains "$OUT" "Next [MUST]: ledger-commit now"
# the append keeps exactly one blank line between content and the next heading
PDOC="$(ls "$WS"/plan/todo/"$ID2"*.md)"
awk '
  $0 == "## 结果" { seen=1; if (prev !~ /^$/) exit 1; exit 0 }
  { prev=$0 }
  END { if (!seen) exit 1 }
' "$PDOC" || fail "appended entry butts against the next heading (no blank line)"

R2="$WS/iterations/iteration_$IID2/readme.md"
fill_results "$R2" "指标: hint probe green"
OUT="$(bash "$WS/scripts/close-iteration.sh" "$IID2" "hint close")"
assert_output_contains "$OUT" "Next [MUST]: ledger-commit now"
assert_output_contains "$OUT" "iterations/index.md"

# status-anomaly error names the line it reads (probe on the still-open plan)
OUT="$(bash "$WS/scripts/new-iteration.sh" "$ID2" "anomaly message probe")"
IID3="$(printf '%s' "$OUT" | grep -o 'iteration_[0-9]*' | head -1 | cut -d_ -f2)"
R3="$WS/iterations/iteration_$IID3/readme.md"
fill_results "$R3" "指标: ok"
python3 - "$R3" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read().replace("> 状态: 进行中", "> 状态: 已完成")
open(p, "w").write(s)
EOF
OUT="$(bash "$WS/scripts/close-iteration.sh" "$IID3" "x" 2>&1 || true)"
assert_output_contains "$OUT" "状态: 进行中"

DOC2="$(ls "$WS"/plan/todo/"$ID2"*.md)"
fill_results "$DOC2" "结论: hint probe done"
OUT="$(bash "$WS/scripts/complete-plan.sh" "$ID2" done "hint complete")"
assert_output_contains "$OUT" "Next [MUST]: ledger-commit now"
assert_output_contains "$OUT" "notes.md notes/"

# ============ 3. commit-check: empty staging + --commit mode ============
HOST="$SB"
bash "$WS/scripts/repos.sh" --add "$HOST" >/dev/null
CC="bash $WS/scripts/commit-check.sh $HOST"

# gate before stage is a precondition error (exit 3), never a PASS
printf 'x=1\n' > "$HOST/probe_module.py"
OUT="$($CC "feat: probe for empty staging refusal" 2>&1 || true)"
assert_output_contains "$OUT" "nothing staged"
$CC "feat: probe for empty staging refusal" >/dev/null 2>&1 && fail "empty staging passed the gate" || EC=$?
[ "${EC:-0}" = "3" ] || fail "empty staging must exit 3, got: ${EC:-unset}"

# P1-2: pure-deletion staging is real staging (no false "nothing staged")
printf 'z=3\n' > "$HOST/probe_third.py"
git -C "$HOST" add probe_third.py
git -C "$HOST" -c user.name=test -c user.email=test@test commit -qm "chore: seed for deletion" >/dev/null
git -C "$HOST" rm -q probe_third.py
$CC "chore: remove the deletion seed" >/dev/null 2>&1 && true || EC2=$?
[ "${EC2:-0}" = "0" ] || fail "pure-deletion staging hit the empty-staging precondition (exit ${EC2:-unset})"
git -C "$HOST" -c user.name=test -c user.email=test@test commit -qm "chore: remove the deletion seed" >/dev/null

# --commit mode: gated message and committed message are byte-identical
git -C "$HOST" add probe_module.py
MSG="feat(probe): exercise the commit mode of the gate"
OUT="$($CC --commit "$MSG")" || fail "--commit mode failed a clean gate"
assert_output_contains "$OUT" "committed: "
LAST="$(git -C "$HOST" log -1 --format=%B)"
[ "$LAST" = "$MSG" ] || fail "committed message drifted from the gated one"

# --commit mode with a banned message: blocked, nothing committed
printf 'y=2\n' > "$HOST/probe_second.py"
git -C "$HOST" add probe_second.py
BEFORE="$(git -C "$HOST" rev-list --count HEAD)"
BANNED_ID="$(printf 'plan:%04d' 1)"   # constructed at runtime — realized ids are gate-blocked
OUT="$($CC --commit "feat: references $BANNED_ID in the subject" 2>&1 || true)"
assert_output_contains "$OUT" "BLOCKED"
[ "$(git -C "$HOST" rev-list --count HEAD)" = "$BEFORE" ] || fail "a blocked --commit still committed"

# wrong arity: --commit without a message fails on usage (exit 3)
$CC --commit >/dev/null 2>&1 && fail "--commit without a message must fail" || UEC=$?
[ "${UEC:-0}" = "3" ] || fail "--commit arity error must exit 3, got: ${UEC:-unset}"

# ============ 4. handoff consume dumps content before destroying ============
bash "$WS/scripts/handoff.sh" --produce --name "t37 probe" --description "dump probe" >/dev/null
HF="$WS/handoff/handoff_t37_probe.md"
printf 'SECRET-MARKER-777\n' >> "$HF"
OUT="$(bash "$WS/scripts/handoff.sh" --consume --name "t37 probe")"
assert_output_contains "$OUT" "SECRET-MARKER-777"
[ ! -f "$HF" ] || fail "consumed handoff file survived"
assert_not_contains "$WS/handoff/index.md" "t37 probe"

# --keep also dumps content before marking
bash "$WS/scripts/handoff.sh" --produce --name "t37 keep" --description "keep probe" >/dev/null
HK="$WS/handoff/handoff_t37_keep.md"
printf 'KEEP-MARKER-888\n' >> "$HK"
OUT="$(bash "$WS/scripts/handoff.sh" --consume --keep --name "t37 keep")"
assert_output_contains "$OUT" "KEEP-MARKER-888"
grep -q "状态: kept" "$HK" || fail "--keep marker missing"

echo "t37: all assertions passed"
