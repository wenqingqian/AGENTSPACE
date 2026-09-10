#!/usr/bin/env bash
# t16: v0.5.1 audit-fix regressions — complete-plan pipe result keeps the
# index row intact (ENVIRON + \037 shield), doctor --fix id normalization +
# latest FIX-gate, handoff --consume dual-match, notes_insert_row pipe topic,
# atomic index appends.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

SB="$(build_sandbox t16)"
WS="$SB/AGENTSPACE"
NEWP="$WS/scripts/new-plan.sh"
COMP="$WS/scripts/complete-plan.sh"
DOC="$WS/scripts/doctor.sh"
HO="$WS/scripts/handoff.sh"

mc() { git -C "$WS" add -A >/dev/null 2>&1; git -C "$WS" commit -qm "test: t16 milestone" >/dev/null 2>&1 || true; }

# --- 1) complete-plan: result containing a raw pipe must keep the index row
# intact (v1.5.0 schema: 8 columns + 1 escaped pipe → awk NF=11) and doctor stays green
bash "$NEWP" "pipe result plan" >/dev/null 2>&1
PLAN="$(ls "$WS"/plan/todo/ | head -1 | cut -d- -f1)"
PLANFILE="$(ls "$WS"/plan/todo/*.md | head -1)"
grep -vF "完成时填写" "$PLANFILE" > "$PLANFILE.tmp" && mv "$PLANFILE.tmp" "$PLANFILE"
mc
bash "$COMP" "$PLAN" done "结果 | 含管道"
assert_contains "$WS/plan/index.md" "结果 \\| 含管道"
LINE="$(grep -F "| $PLAN |" "$WS/plan/index.md")"
[ -n "$LINE" ] || fail "plan/index.md row $PLAN missing"
NF="$(printf '%s\n' "$LINE" | awk -F'|' '{print NF}')"
[ "$NF" = "11" ] || fail "plan/index.md row $PLAN NF=$NF (expect 11 = 8 cols + 1 escaped pipe): $LINE"
mc
assert_ok bash "$DOC"

# --- 2) doctor --fix id normalization: `| 1 |` row with 0001 file must NOT be
# deleted; a genuine orphan (0999) is still repaired
bash "$NEWP" "pad plan" >/dev/null 2>&1
PID2="$(ls "$WS"/plan/todo/ | head -1 | cut -d- -f1)"
mc
python3 - "$WS/plan.md" "$PID2" <<'EOF'
import sys
p, pid = sys.argv[1], sys.argv[2]
s = open(p).read()
s = s.replace(f"| {pid} |", f"| {int(pid)} |", 1)   # unpadded: `| 1 |`
open(p, "w").write(s)
EOF
OUT="$(bash "$DOC" --fix 2>&1 || true)"
assert_output_not_contains "$OUT" "removed orphan Todo row"
ROWS="$(awk -v sec="Todo" '$0 == ("## " sec) {f=1; next} /^## / {f=0} f && /^\| [0-9]/ {n++} END {print n+0}' "$WS/plan.md")"
[ "$ROWS" = "1" ] || fail "Todo rows = $ROWS (expect 1 — live unpadded row must survive)"
python3 - "$WS/plan.md" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read()
s = s.replace("| --- | --- | --- | --- |", "| --- | --- | --- | --- |\n| 0999 | Orphan Plan | 2026-08-06 | [x](x) |", 1)
open(p, "w").write(s)
EOF
OUT="$(bash "$DOC" --fix 2>&1 || true)"
assert_output_contains "$OUT" "removed orphan Todo row 0999"
python3 - "$WS/plan.md" "$PID2" <<'EOF'
import sys
p, pid = sys.argv[1], sys.argv[2]
s = open(p).read()
s = s.replace(f"| {int(pid)} |", f"| {pid} |", 1)   # restore padding
open(p, "w").write(s)
EOF
mc

# --- 3) doctor [1] latest FIX-gate: broken symlink reported, repaired only
# under --fix (an iteration must exist for the recreate path to have a target)
bash "$WS/scripts/new-iteration.sh" "$PID2" "fix gate iter" >/dev/null 2>&1
IID3="$(ls -d "$WS"/iterations/iteration_[0-9]* | sort | tail -1 | xargs basename | sed 's/iteration_//')"
python3 - "$WS/iterations/iteration_$IID3/readme.md" <<'EOF'
import re, sys
p = sys.argv[1]
s = open(p).read()
s = re.sub(r"<!-- 会话续接块:.*?-->", "当前状态: 测试中", s, flags=re.S)   # fill resume block (doctor [3])
open(p, "w").write(s)
EOF
mc
ln -sfn iteration_9999 "$WS/iterations/latest"       # broken symlink
OUT="$(bash "$DOC" 2>&1 || true)"
assert_output_contains "$OUT" "latest symlink broken (run --fix"
assert_output_not_contains "$OUT" "[fixed]"
[ -L "$WS/iterations/latest" ] && [ ! -e "$WS/iterations/latest" ] || fail "latest changed without --fix"
OUT="$(bash "$DOC" --fix 2>&1 || true)"
assert_output_contains "$OUT" "latest -> iteration_"
[ -L "$WS/iterations/latest" ] && [ -e "$WS/iterations/latest" ] || fail "latest not repaired by --fix"
mc
assert_ok bash "$DOC"

# --- 4) handoff --consume dual-match: duplicate names with different locs —
# only the row pointing at the derived file is consumed
printf 'x' > "$WS/handoff/handoff_dup.md"
printf 'x' > "$WS/handoff/handoff_dup_b.md"
python3 - "$WS/handoff/index.md" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read()
s = s.replace("| --- | --- | --- | --- |",
  "| --- | --- | --- | --- |\n| dup | B 行 | handoff_dup_b.md | 2026-08-06 |\n| dup | A 行 | handoff_dup.md | 2026-08-06 |", 1)
open(p, "w").write(s)
EOF
OUT="$(bash "$HO" --consume --name dup 2>&1)"
assert_output_contains "$OUT" "handoff consumed"
assert_contains "$WS/handoff/index.md" "handoff_dup_b.md"   # wrong row kept
assert_not_contains "$WS/handoff/index.md" "handoff_dup.md"  # target row removed
[ -f "$WS/handoff/handoff_dup_b.md" ] || fail "wrong file deleted"
[ ! -f "$WS/handoff/handoff_dup.md" ] || fail "target file not deleted"
mc

# --- 5) notes_insert_row pipe topic (doctor [7] --fix path): the inserted
# notes row keeps the escaped pipe (ENVIRON, not -v)
mkdir -p "$WS/notes"
# runtime-constructed 来源 id (self-hosting: no realized literal here)
printf '# 主题 | 带管道\n> 创建: 2026-08-06\n> 来源: plan:%04d\n' 1 > "$WS/notes/pipe-topic.md"
OUT="$(bash "$DOC" --fix 2>&1 || true)"
assert_contains "$WS/notes.md" "主题 \\| 带管道"
mc
assert_ok bash "$DOC"

rm -rf "$SB"
echo "PASS t16"
