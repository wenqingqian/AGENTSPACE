#!/usr/bin/env bash
# t40: exp goal grouping + reopen (v1.6.1) — template 轮次 section and the
# RESULT_PH anchor kept verbatim; script hints carry the fold-in rule; SKILL /
# command / asset text contracts (EN + zh); reopen lifecycle end to end (done→
# doing with a 日志 trail line, index clears 完成日期/结果 while keeping the
# commits/configs snapshot, Doing row reappears with today's date); refusals
# (open exp / unknown id); a follow-up round appended then re-closed re-snapshots
# configs; doctor green at the milestone commit. Ids are computed at runtime.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

SB="$(build_sandbox t40)"
WS="$SB/AGENTSPACE"

# --- repo-side text contracts -------------------------------------------------
assert_contains "$REPO/skills/agentspace-init/assets/agentspace/templates/exp-manual.md" "## 轮次"
grep -q '^<!-- 一句话结论; 关闭 exp 前必填 -->$' "$REPO/skills/agentspace-init/assets/agentspace/templates/exp-manual.md" \
  || fail "exp-manual 结果 anchor (RESULT_PH_EXP) drifted"
assert_contains "$REPO/skills/agentspace-init/assets/agentspace/AGENTS.md" "一个 exp = 一个大目标下的一组实验轮次"
assert_contains "$REPO/skills/agentspace-init/assets/agentspace/AGENTS.md" 'reopen-exp.sh <id> ["原因"]'
assert_contains "$REPO/skills/agentspace-init/assets/agentspace/AGENTS.md" "exp 创建/完成/重开"
assert_contains "$REPO/skills/agentspace-init/assets/agentspace/AGENTS.md" "后续轮次归并"
assert_contains "$REPO/skills/agentspace-init/assets/root-AGENTS.md" "已关闭的先经 reopen-exp.sh 重开"
assert_contains "$REPO/skills/agentspace-exp/SKILL.md" "One exp = one goal"
assert_contains "$REPO/skills/agentspace-exp/SKILL.md" "never a new exp per round"
assert_contains "$REPO/skills/agentspace-exp/SKILL.zh-CN.md" "一个 exp = 一个大目标"
assert_contains "$REPO/skills/agentspace-exp/SKILL.zh-CN.md" "绝不一轮一个新 exp"
assert_contains "$REPO/commands/agentspace-exp.md" "reopen-exp.sh"
assert_contains "$REPO/skills/agentspace/SKILL.md" "never a new exp per round"
assert_contains "$REPO/skills/agentspace/SKILL.zh-CN.md" "归并进行中 exp"

# --- lifecycle: register (goal granularity), hint, template instantiation -----
OUT="$(bash "$WS/scripts/new-exp.sh" "latency goal")"
assert_output_contains "$OUT" "One exp = one goal"
XID="$(printf '%s' "$OUT" | grep -o 'exp_[0-9]*' | head -1 | cut -d_ -f2)"
[ -n "$XID" ] || fail "no exp id: $OUT"
MANUAL="$(ls "$WS"/exp/todo/exp_"$XID"-*.md)"
assert_contains "$MANUAL" "## 轮次"

# refusals: unknown id; open (todo) exp — follow-ups append, no reopen
assert_fails bash "$WS/scripts/reopen-exp.sh" 9999
if R_OUT="$(bash "$WS/scripts/reopen-exp.sh" "$XID" 2>&1)"; then fail "reopen on a todo exp must fail"; fi
assert_output_contains "$R_OUT" "still open"

# run + first close (goal-level result)
bash "$WS/scripts/start-exp.sh" "$XID" >/dev/null || fail "start failed"
DOING="$(ls "$WS"/exp/doing/exp_"$XID"-*.md)"
sed -i_tmp "s|<!-- 一句话结论; 关闭 exp 前必填 -->|goal concluded after round 1|" "$DOING" && rm -f "${DOING}_tmp"
printf 'iters: 200\n' > "$WS/examples/exp_spec/exp_$XID/run1-baseline.yaml"
printf 'round 1 log\n' > "$WS/exp/exp_data/exp_$XID/run.log"
CLOSE_OUT="$(bash "$WS/scripts/complete-exp.sh" "$XID" done "goal concluded after round 1" --commit "demo-repo@a1b2c3d")" || fail "complete failed"
assert_output_contains "$CLOSE_OUT" "reopen-exp.sh $XID"
DONE_MANUAL="$(ls "$WS"/exp/done/exp_"$XID"-*.md)"
[ -f "$DONE_MANUAL" ] || fail "manual not in done/"
assert_contains "$WS/exp/index.md" "| $XID | latency goal | 完成 |"

# --- reopen: done→doing with the previous conclusion preserved in 日志 --------
REOPEN_OUT="$(bash "$WS/scripts/reopen-exp.sh" "$XID" "late follow-up round")" || fail "reopen failed"
DOING2="$(ls "$WS"/exp/doing/exp_"$XID"-*.md)"
[ -f "$DOING2" ] || fail "manual not back in doing/"
[ ! -f "$WS/exp/done/exp_$XID-latency-goal.md" ] || fail "done/ manual still present"
assert_contains "$DOING2" "> 状态: doing"
assert_contains "$DOING2" "重开"
assert_contains "$DOING2" "goal concluded after round 1"
assert_output_contains "$REOPEN_OUT" "exp_$XID → doing"
# entry view: Doing row with today's date; the completed row left 最近完成
assert_contains "$WS/exp.md" "exp/doing/exp_$XID-"
TODAY="$(date +%F)"
assert_contains "$WS/exp.md" "| $XID | latency goal | $TODAY |"
sed -n '/^## 最近完成/,$p' "$WS/exp.md" | grep -q "^| $XID |" \
  && fail "最近完成 still holds the reopened row"
# index: state doing, completion snapshot cleared (完成日期/结果), link→doing
assert_contains "$WS/exp/index.md" "| $XID | latency goal | doing |"
assert_contains "$WS/exp/index.md" "exp/doing/exp_$XID-"
awk -F'|' -v id="$XID" '
  $0 ~ ("^\\| *" id " *\\|") { c10=$10; c11=$11; gsub(/^ +| +$/, "", c10); gsub(/^ +| +$/, "", c11); print (c10=="" && c11=="") ? "cleared" : "left<" c10 "|" c11 ">"; exit }
' "$WS/exp/index.md" | grep -q cleared || fail "完成日期/结果 not cleared on reopen"
# second reopen refusal (already doing again)
assert_fails bash "$WS/scripts/reopen-exp.sh" "$XID"

# --- follow-up round folds in, goal re-closes with a fresh snapshot -----------
printf 'lr sweep\n' > "$WS/examples/exp_spec/exp_$XID/run2-lr-sweep.yaml"
sed -i_tmp2 "s|goal concluded after round 1|goal concluded: round 2 confirmed the sweep|" "$DOING2" && rm -f "${DOING2}_tmp2"
CLOSE2="$(bash "$WS/scripts/complete-exp.sh" "$XID" done "goal concluded: round 2 confirmed the sweep" --commit "demo-repo@b2c3d4e")" || fail "re-close failed"
assert_contains "$WS/exp/index.md" "| $XID | latency goal | 完成 |"
assert_contains "$WS/exp/index.md" "run1-baseline.yaml"
assert_contains "$WS/exp/index.md" "run2-lr-sweep.yaml"
assert_contains "$WS/exp/index.md" "demo-repo@b2c3d4e"
[ -f "$(ls "$WS"/exp/done/exp_"$XID"-*.md)" ] || fail "manual not back in done/"

# milestone commit + doctor green (reopen shape included)
git -C "$WS" add -A >/dev/null 2>&1
git -C "$WS" commit -qm "test: exp goal grouping milestone" >/dev/null 2>&1
assert_ok bash "$WS/scripts/doctor.sh"

rm -rf "$SB"
echo "PASS t40"
