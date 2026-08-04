#!/usr/bin/env bash
# t06: doctor cross-reference checks — green on a consistent content-rich
# workspace; red on: iteration→plan mismatch [6], note 来源 malformed [7],
# note 来源 target missing [7], missing note back-link [8]. Each case uses a
# fresh sandbox and locks the failure reason with output assertions.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

# helper: create a note file from the template with a given 来源 and optional
# 详情 back-link text
make_note() {
  local ws="$1" slug="$2" title="$3" src="$4" backlink="$5"
  sed -e "s/{{TITLE}}/$title/g" -e "s/{{DATE}}/2026-08-04/" "$ws/templates/note.md" > "$ws/notes/$slug.md"
  python3 - "$ws/notes/$slug.md" "$src" "$backlink" <<'EOF'
import sys
p, src, backlink = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(p).read()
s = s.replace("<!-- 必填: plan:NNNN / iteration_NNNN 等证据引用 -->", src)
if backlink:
    s = s.replace("<!-- 上下文 / 数据 / 复现方式 -->", backlink)
open(p, "w").write(s)
EOF
}

# helper: append a notes.md entry row after the table separator
add_note_row() {
  local ws="$1" slug="$2" title="$3" src="$4"
  python3 - "$ws/notes.md" "$slug" "$title" "$src" <<'EOF'
import sys
p, slug, title, src = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
s = open(p).read()
row = f"| {title} | test |  | {src} | 2026-08-04 | [notes/{slug}.md](notes/{slug}.md) |"
s = s.replace("| --- | --- | --- | --- | --- | --- |",
              "| --- | --- | --- | --- | --- | --- |\n" + row, 1)
open(p, "w").write(s)
EOF
}

# helper: create plan + iteration, fill the resume block
make_plan_iteration() {
  local ws="$1" plan_title="$2" iter_title="$3"
  local out pid out2 iid
  out="$(bash "$ws/scripts/new-plan.sh" "$plan_title")"
  pid="$(printf '%s' "$out" | grep -o 'plan:[0-9]*' | cut -d: -f2)"
  out2="$(bash "$ws/scripts/new-iteration.sh" "$pid" "$iter_title")"
  iid="$(printf '%s' "$out2" | grep -o 'iteration_[0-9]*' | head -1 | cut -d_ -f2)"
  python3 - "$ws/iterations/iteration_$iid/readme.md" <<'EOF'
import re, sys
p = sys.argv[1]
s = open(p).read()
s = re.sub(r"<!-- 会话续接块:.*?-->", "当前状态: 测试中; 下一步: 无", s, flags=re.S)
open(p, "w").write(s)
EOF
  printf '%s %s' "$pid" "$iid"
}

# --- [6][7][8] green on a consistent content-rich workspace ---
SB="$(build_sandbox t06a)"
WS="$SB/AGENTSPACE"
read -r PID IID <<EOF
$(make_plan_iteration "$WS" "Crossref Green Plan" "crossref green")
EOF
make_note "$WS" "green-note" "Green note" "iteration_$IID" "回链: [iteration_$IID readme](../iterations/iteration_$IID/readme.md)"
add_note_row "$WS" "green-note" "Green note" "iteration_$IID"
git -C "$WS" add -A >/dev/null 2>&1
git -C "$WS" commit -qm "test: t06a milestone" >/dev/null 2>&1
assert_ok bash "$WS/scripts/doctor.sh"
rm -rf "$SB"

# --- [6] iteration→plan mismatch: entry table row says a different plan ---
SB="$(build_sandbox t06b)"
WS="$SB/AGENTSPACE"
OUT="$(bash "$WS/scripts/new-plan.sh" "First Plan")"
PID1="$(printf '%s' "$OUT" | grep -o 'plan:[0-9]*' | cut -d: -f2)"
OUT="$(bash "$WS/scripts/new-plan.sh" "Second Plan")"
PID2="$(printf '%s' "$OUT" | grep -o 'plan:[0-9]*' | cut -d: -f2)"
OUT2="$(bash "$WS/scripts/new-iteration.sh" "$PID1" "mismatch test")"
IID="$(printf '%s' "$OUT2" | grep -o 'iteration_[0-9]*' | head -1 | cut -d_ -f2)"
python3 - "$WS/iterations/iteration_$IID/readme.md" <<'EOF'
import re, sys
p = sys.argv[1]
s = open(p).read()
s = re.sub(r"<!-- 会话续接块:.*?-->", "当前状态: 测试中; 下一步: 无", s, flags=re.S)
open(p, "w").write(s)
EOF
# table row now claims plan:PID2 while readme says plan:PID1
python3 - "$WS/iterations.md" "$IID" "$PID1" "$PID2" <<'EOF'
import sys
p, iid, pid1, pid2 = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
s = open(p).read()
s = s.replace(f"| {iid} | plan:{pid1} |", f"| {iid} | plan:{pid2} |", 1)
open(p, "w").write(s)
EOF
git -C "$WS" add -A >/dev/null 2>&1
git -C "$WS" commit -qm "test: t06b milestone" >/dev/null 2>&1
OUT="$(bash "$WS/scripts/doctor.sh" 2>&1 || true)"
assert_output_contains "$OUT" "mismatch"
rm -rf "$SB"

# --- [7] note 来源 malformed: header left as template placeholder ---
SB="$(build_sandbox t06c)"
WS="$SB/AGENTSPACE"
make_note "$WS" "malformed-note" "Malformed note" "<!-- 必填: plan:NNNN / iteration_NNNN 等证据引用 -->" ""
add_note_row "$WS" "malformed-note" "Malformed note" "plan:0001"
git -C "$WS" add -A >/dev/null 2>&1
git -C "$WS" commit -qm "test: t06c milestone" >/dev/null 2>&1
OUT="$(bash "$WS/scripts/doctor.sh" 2>&1 || true)"
assert_output_contains "$OUT" "来源 missing or malformed"
assert_output_not_contains "$OUT" "missing row"
rm -rf "$SB"

# --- [7] note 来源 target missing: iteration_9999 does not exist ---
SB="$(build_sandbox t06d)"
WS="$SB/AGENTSPACE"
make_note "$WS" "ghost-src-note" "Ghost source note" "iteration_9999" "回链: [iteration_9999 readme](../iterations/iteration_9999/readme.md)"
add_note_row "$WS" "ghost-src-note" "Ghost source note" "iteration_9999"
git -C "$WS" add -A >/dev/null 2>&1
git -C "$WS" commit -qm "test: t06d milestone" >/dev/null 2>&1
OUT="$(bash "$WS/scripts/doctor.sh" 2>&1 || true)"
assert_output_contains "$OUT" "来源 iteration_9999 target dir not found"
assert_output_not_contains "$OUT" "no back-link"
rm -rf "$SB"

# --- [8] iteration-sourced note without a back-link to its readme ---
SB="$(build_sandbox t06e)"
WS="$SB/AGENTSPACE"
read -r PID IID <<EOF
$(make_plan_iteration "$WS" "Backlink Plan" "backlink test")
EOF
make_note "$WS" "no-backlink-note" "No backlink note" "iteration_$IID" ""
add_note_row "$WS" "no-backlink-note" "No backlink note" "iteration_$IID"
git -C "$WS" add -A >/dev/null 2>&1
git -C "$WS" commit -qm "test: t06e milestone" >/dev/null 2>&1
OUT="$(bash "$WS/scripts/doctor.sh" 2>&1 || true)"
assert_output_contains "$OUT" "no back-link to iteration_$IID/readme.md"
rm -rf "$SB"

# --- [7] hand-written non-padded 来源 ref (plan:1): normalized before lookup ---
SB="$(build_sandbox t06f)"
WS="$SB/AGENTSPACE"
OUT="$(bash "$WS/scripts/new-plan.sh" "Norm Note Plan")"
PID="$(printf '%s' "$OUT" | grep -o 'plan:[0-9]*' | cut -d: -f2)"
# hand-write the ref WITHOUT zero padding: plan:1 instead of plan:0001
make_note "$WS" "padded-note" "Padded note" "plan:${PID#0}" ""
add_note_row "$WS" "padded-note" "Padded note" "plan:${PID#0}"
git -C "$WS" add -A >/dev/null 2>&1
git -C "$WS" commit -qm "test: t06f milestone" >/dev/null 2>&1
set +e
OUT="$(bash "$WS/scripts/doctor.sh" 2>&1)"
rc=$?
set -e
[ "$rc" -eq 0 ] || fail "expected doctor to pass, got $rc"
assert_output_not_contains "$OUT" "not found"
rm -rf "$SB"

# --- [6] hand-written non-padded readme plan ref (plan: 001): normalized ---
SB="$(build_sandbox t06g)"
WS="$SB/AGENTSPACE"
read -r PID IID <<EOF
$(make_plan_iteration "$WS" "Norm Iter Plan" "norm iter")
EOF
python3 - "$WS/iterations/iteration_$IID/readme.md" "$PID" <<'EOF'
import sys
p, pid = sys.argv[1], sys.argv[2]
s = open(p).read()
s = s.replace(f"> plan: {pid}", f"> plan: {pid[1:]}", 1)  # drop one leading zero
open(p, "w").write(s)
EOF
git -C "$WS" add -A >/dev/null 2>&1
git -C "$WS" commit -qm "test: t06g milestone" >/dev/null 2>&1
set +e
OUT="$(bash "$WS/scripts/doctor.sh" 2>&1)"
rc=$?
set -e
[ "$rc" -eq 0 ] || fail "expected doctor to pass, got $rc"
assert_output_not_contains "$OUT" "mismatch"
assert_output_not_contains "$OUT" "not found"
rm -rf "$SB"

# --- [8] pre-discipline notes are exempt (v0.2.12: existing notes NOT retrofitted) ---
SB="$(build_sandbox t06h)"
WS="$SB/AGENTSPACE"
read -r PID IID <<EOF
$(make_plan_iteration "$WS" "Exemption Plan" "exemption test")
EOF
make_note "$WS" "old-note" "Old note" "iteration_$IID" ""
# created before the back-link discipline was adopted (2026-08-04)
sed -i '' 's/> 创建: 2026-08-04/> 创建: 2026-07-01/' "$WS/notes/old-note.md"
add_note_row "$WS" "old-note" "Old note" "iteration_$IID"
git -C "$WS" add -A >/dev/null 2>&1
git -C "$WS" commit -qm "test: t06h milestone" >/dev/null 2>&1
assert_ok bash "$WS/scripts/doctor.sh"
rm -rf "$SB"

echo "PASS t06"
