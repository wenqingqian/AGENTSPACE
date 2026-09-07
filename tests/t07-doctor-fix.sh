#!/usr/bin/env bash
# t07: doctor --fix — safe deterministic items are auto-repaired only with the
# flag; without --fix doctor stays read-only. Orphan plan rows [2], orphan
# in-progress iteration rows [3], missing notes.md rows [7]. Each case uses a
# fresh sandbox and verifies the fix side effects directly.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

# --- [2] orphan Todo row: removed by --fix, untouched without it ---
SB="$(build_sandbox t07a)"
WS="$SB/AGENTSPACE"
python3 - "$WS/plan.md" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read()
s = s.replace("| --- | --- | --- | --- |",
              "| --- | --- | --- | --- |\n| 9999 | Broken | 2026-08-03 | [plan.md](plan.md) |", 1)
open(p, "w").write(s)
EOF
git -C "$WS" add -A >/dev/null 2>&1
git -C "$WS" commit -qm "test: t07a milestone (fault)" >/dev/null 2>&1
OUT="$(bash "$WS/scripts/doctor.sh" 2>&1 || true)"
assert_output_contains "$OUT" "orphan row"
assert_contains "$WS/plan.md" "| 9999 |"
# without --fix the tampered row is still there
OUT="$(bash "$WS/scripts/doctor.sh" --fix 2>&1 || true)"
assert_output_contains "$OUT" "removed orphan Todo row 9999"
assert_not_contains "$WS/plan.md" "| 9999 |"
[ ! -e "$WS/.scripts.lock" ] || fail "lock left behind after --fix"
git -C "$WS" add -A >/dev/null 2>&1
git -C "$WS" commit -qm "test: t07a milestone (fixed)" >/dev/null 2>&1
assert_ok bash "$WS/scripts/doctor.sh"
rm -rf "$SB"

# --- [3] orphan in-progress iteration row: removed by --fix ---
SB="$(build_sandbox t07b)"
WS="$SB/AGENTSPACE"
python3 - "$WS/iterations.md" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read()
s = s.replace("| --- | --- | --- | --- | --- |",
              "| --- | --- | --- | --- | --- |\n| 8888 | plan:%04d | orphan | 2026-08-03 | [iterations/latest](iterations/latest) |" % 1, 1)
open(p, "w").write(s)
EOF
git -C "$WS" add -A >/dev/null 2>&1
git -C "$WS" commit -qm "test: t07b milestone (fault)" >/dev/null 2>&1
OUT="$(bash "$WS/scripts/doctor.sh" 2>&1 || true)"
assert_output_contains "$OUT" "orphan row"
OUT="$(bash "$WS/scripts/doctor.sh" --fix 2>&1 || true)"
assert_output_contains "$OUT" "removed orphan in-progress row 8888"
assert_not_contains "$WS/iterations.md" "| 8888 |"
git -C "$WS" add -A >/dev/null 2>&1
git -C "$WS" commit -qm "test: t07b milestone (fixed)" >/dev/null 2>&1
assert_ok bash "$WS/scripts/doctor.sh"
rm -rf "$SB"

# --- [7] note file missing from notes.md: row backfilled by --fix ---
SB="$(build_sandbox t07c)"
WS="$SB/AGENTSPACE"
OUT="$(bash "$WS/scripts/new-plan.sh" "backfill plan")"
PID="$(printf '%s' "$OUT" | grep -o 'plan:[0-9]*' | cut -d: -f2)"
sed -e "s/{{TITLE}}/Backfill note/" -e "s/{{DATE}}/2026-08-04/" "$WS/templates/note.md" > "$WS/notes/backfill-note.md"
python3 - "$WS/notes/backfill-note.md" "$PID" <<'EOF'
import sys
p, pid = sys.argv[1], sys.argv[2]
s = open(p).read()
s = s.replace("<!-- 必填: plan:NNNN / iteration_NNNN 等证据引用 -->", f"plan:{pid}")
open(p, "w").write(s)
EOF
git -C "$WS" add -A >/dev/null 2>&1
git -C "$WS" commit -qm "test: t07c milestone (fault)" >/dev/null 2>&1
OUT="$(bash "$WS/scripts/doctor.sh" 2>&1 || true)"
assert_output_contains "$OUT" "notes.md missing row for backfill-note.md"
OUT="$(bash "$WS/scripts/doctor.sh" --fix 2>&1 || true)"
assert_output_contains "$OUT" "inserted row for backfill-note.md"
assert_contains "$WS/notes.md" "[notes/backfill-note.md](notes/backfill-note.md)"
assert_contains "$WS/notes.md" "plan:$PID"
git -C "$WS" add -A >/dev/null 2>&1
git -C "$WS" commit -qm "test: t07c milestone (fixed)" >/dev/null 2>&1
assert_ok bash "$WS/scripts/doctor.sh"
rm -rf "$SB"

# --- read-only guarantee: without --fix, doctor never modifies files ---
SB="$(build_sandbox t07d)"
WS="$SB/AGENTSPACE"
python3 - "$WS/plan.md" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read()
s = s.replace("| --- | --- | --- | --- |",
              "| --- | --- | --- | --- |\n| 7777 | Broken | 2026-08-03 | [plan.md](plan.md) |", 1)
open(p, "w").write(s)
EOF
sed -e "s/{{TITLE}}/Ro note/" -e "s/{{DATE}}/2026-08-04/" "$WS/templates/note.md" > "$WS/notes/ro-note.md"
python3 - "$WS/notes/ro-note.md" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read()
s = s.replace("<!-- 必填: plan:NNNN / iteration_NNNN 等证据引用 -->", "plan:%04d" % 1)
open(p, "w").write(s)
EOF
git -C "$WS" add -A >/dev/null 2>&1
git -C "$WS" commit -qm "test: t07d milestone (fault)" >/dev/null 2>&1
bash "$WS/scripts/doctor.sh" >/dev/null 2>&1 || true
assert_contains "$WS/plan.md" "| 7777 |"
assert_not_contains "$WS/notes.md" "ro-note"
[ ! -e "$WS/.scripts.lock" ] || fail "read-only doctor created a lock"
rm -rf "$SB"

# --- [7] row insert failure: --fix must not claim a fix that did not happen ---
SB="$(build_sandbox t07e)"
WS="$SB/AGENTSPACE"
OUT="$(bash "$WS/scripts/new-plan.sh" "sep fail plan")"
PID="$(printf '%s' "$OUT" | grep -o 'plan:[0-9]*' | cut -d: -f2)"
sed -e "s/{{TITLE}}/Sep fail note/" -e "s/{{DATE}}/2026-08-04/" "$WS/templates/note.md" > "$WS/notes/sep-fail-note.md"
python3 - "$WS/notes/sep-fail-note.md" "$PID" <<'EOF'
import sys
p, pid = sys.argv[1], sys.argv[2]
s = open(p).read()
s = s.replace("<!-- 必填: plan:NNNN / iteration_NNNN 等证据引用 -->", f"plan:{pid}")
open(p, "w").write(s)
EOF
# corrupt the notes.md table separator so the awk insert cannot find it
python3 - "$WS/notes.md" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read()
s = s.replace("| --- | --- | --- | --- | --- | --- |", "| corrupted separator |")
open(p, "w").write(s)
EOF
git -C "$WS" add -A >/dev/null 2>&1
git -C "$WS" commit -qm "test: t07e milestone (fault)" >/dev/null 2>&1
set +e
OUT="$(bash "$WS/scripts/doctor.sh" --fix 2>&1)"
rc=$?
set -e
[ "$rc" -eq 1 ] || fail "expected --fix to exit 1 (row insert failed), got $rc"
assert_output_contains "$OUT" "[issue]"
assert_output_contains "$OUT" "table separator not found, row not inserted"
assert_output_not_contains "$OUT" "inserted row for"
assert_output_contains "$OUT" "== Done: 1 issues, 0 auto-repaired =="
assert_not_contains "$WS/notes.md" "sep-fail-note"
rm -rf "$SB"

# --- [2] duplicated id across sections: --fix removes only the orphan row ---
SB="$(build_sandbox t07f)"
WS="$SB/AGENTSPACE"
OUT="$(bash "$WS/scripts/new-plan.sh" "dup fix plan")"
PID="$(printf '%s' "$OUT" | grep -o 'plan:[0-9]*' | cut -d: -f2)"
# complete the plan first so id $PID has a legitimate Done row + plan/done file
python3 - "$WS/plan/todo/$PID-"*.md <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read()
s = s.replace("<!-- 完成时填写: 一句话结论", "一句话结论: test result", 1)
open(p, "w").write(s)
EOF
bash "$WS/scripts/complete-plan.sh" "$PID" done "test result" >/dev/null
# inject an orphan Todo row reusing the same id (no file in plan/todo/)
python3 - "$WS/plan.md" "$PID" <<'EOF'
import sys
p, pid = sys.argv[1], sys.argv[2]
s = open(p).read()
s = s.replace("| --- | --- | --- | --- |",
              "| --- | --- | --- | --- |\n| " + pid + " | Duplicate orphan | 2026-08-03 | [plan.md](plan.md) |", 1)
open(p, "w").write(s)
EOF
git -C "$WS" add -A >/dev/null 2>&1
git -C "$WS" commit -qm "test: t07f milestone (fault)" >/dev/null 2>&1
OUT="$(bash "$WS/scripts/doctor.sh" 2>&1 || true)"
assert_output_contains "$OUT" "orphan row"
OUT="$(bash "$WS/scripts/doctor.sh" --fix 2>&1 || true)"
assert_output_contains "$OUT" "removed orphan Todo row $PID (no file)"
assert_output_not_contains "$OUT" "[issue]"
assert_output_contains "$OUT" "== Done: 0 issues, 1 auto-repaired =="
# the orphan row is gone from the Todo section...
assert_not_contains "$WS/plan.md" "Duplicate orphan"
# ...while the legitimate Done row (plan/done file present) survives
assert_contains "$WS/plan.md" "| $PID | dup fix plan |"
# blast radius: --fix modified only plan.md
[ "$(git -C "$WS" diff --name-only)" = "plan.md" ] \
  || fail "unexpected blast radius after --fix: $(git -C "$WS" diff --name-only)"
git -C "$WS" add -A >/dev/null 2>&1
git -C "$WS" commit -qm "test: t07f milestone (fixed)" >/dev/null 2>&1
assert_ok bash "$WS/scripts/doctor.sh"
rm -rf "$SB"

# --- v0.3.3: section heading with trailing whitespace — --fix still repairs ---
# (both the orphan-row detection and as_remove_row_section tolerate heading drift)
SB="$(build_sandbox t07g)"
WS="$SB/AGENTSPACE"
# inject an orphan Todo row, then drift the heading with a trailing space
python3 - "$WS/plan.md" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read()
s = s.replace("## Todo", "## Todo ", 1)
s = s.replace("| --- | --- | --- | --- |",
              "| --- | --- | --- | --- |\n| 9998 | Drifted Ghost | 2026-08-03 | [plan/todo/9998-x.md](plan/todo/9998-x.md) |", 1)
open(p, "w").write(s)
EOF
git -C "$WS" add -A >/dev/null 2>&1
git -C "$WS" commit -qm "test: t07g milestone (fault)" >/dev/null 2>&1
OUT="$(bash "$WS/scripts/doctor.sh" 2>&1 || true)"
assert_output_contains "$OUT" "orphan row"
OUT="$(bash "$WS/scripts/doctor.sh" --fix 2>&1 || true)"
assert_output_contains "$OUT" "removed orphan Todo row 9998 (no file)"
assert_output_not_contains "$OUT" "NOT removed"
rm -rf "$SB"

echo "PASS t07"
