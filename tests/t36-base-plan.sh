#!/usr/bin/env bash
# t36: base plan lifecycle — new-base-plan (draft + dual-table registration,
# slug contract shared with new-plan, counter independence from the plan
# counter), activate gates (direction-placeholder refusal, unknown id,
# state machine) and sha256 checksum pinning, tamper → doctor [17] red
# (report-only even under --fix), retire (replaced requires --by; successor
# must already be 生效; voided allowed from 待审核; the FILE is never touched;
# retired row leaves the plan.md view but stays in the index), derived-plan
# links (--base registration in both tables, unknown-base refusal, open plan
# deriving from a non-生效 anchor is report-only), consistency repair (orphan
# index row removed by --fix, entry-view row re-added by --fix).
# Ids are computed at runtime — never hardcode realized ids.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

SB="$(build_sandbox t36)"
WS="$SB/AGENTSPACE"

# a regular plan exists first — the base counter must ignore it entirely
OUTP="$(bash "$WS/scripts/new-plan.sh" "host plan one")"
PID="$(printf '%s' "$OUTP" | grep -o 'plan:[0-9]*' | head -1 | cut -d: -f2)"

# slug contract (shared as_slug_of): punctuation refused BEFORE any write
BEFORE="$(grep -c '^| ' "$WS/plan/index.md" || true)"
assert_fails bash "$WS/scripts/new-base-plan.sh" "方向 实验!"
AFTER="$(grep -c '^| ' "$WS/plan/index.md" || true)"
[ "$BEFORE" = "$AFTER" ] || fail "refused title burned an index row"

# draft: file in plan/base/, row in plan.md Base view + index Base section
OUT="$(bash "$WS/scripts/new-base-plan.sh" "immutable direction anchor")"
BID="$(printf '%s' "$OUT" | grep -o 'base:[0-9]*' | head -1 | cut -d: -f2)"
[ -n "$BID" ] || fail "no base id: $OUT"
# counter independence: base namespace starts at 0001 regardless of plan ids
[ "$BID" = "0001" ] || fail "base counter must be independent (expected 0001, got $BID)"
BFILE="$(ls "$WS"/plan/base/"$BID"-*.md)"
[ -f "$BFILE" ] || fail "draft file not created"
assert_contains "$WS/plan.md" "| base:$BID | immutable direction anchor | 待审核 |"
assert_contains "$WS/plan/index.md" "| base:$BID | immutable direction anchor | 待审核 |"
# review-flow contract is part of the script output (the session MUST end)
assert_output_contains "$OUT" "直接结束本会话"

# activate gates: unknown id, direction placeholder still present
assert_fails bash "$WS/scripts/activate-base-plan.sh" 9999
assert_fails bash "$WS/scripts/activate-base-plan.sh" "$BID"
python3 - "$BFILE" <<'EOF'
import re, sys
p = sys.argv[1]
s = open(p).read()
s = re.sub(r"<!-- 方向: 这个基准锚定什么方向.*?-->",
           "All release tooling ships from one immutable direction anchor.", s, flags=re.S)
open(p, "w").write(s)
EOF
ACT="$(bash "$WS/scripts/activate-base-plan.sh" "$BID")" || fail "activate failed"
assert_output_contains "$ACT" "生效"
# checksum pinned into the index Base row — and it equals an independent recompute
HASH="$(printf '%s' "$ACT" | grep -oE 'checksum pinned: [0-9a-f]+' | grep -oE '[0-9a-f]+$')"
[ -n "$HASH" ] || fail "no checksum in activate output: $ACT"
assert_contains "$WS/plan/index.md" "$HASH"
NOW="$(PYTHONIOENCODING=utf-8 python3 -c "import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest()[:12])" "$BFILE")"
[ "$NOW" = "$HASH" ] || fail "pinned checksum ($HASH) != recomputed ($NOW)"
assert_contains "$WS/plan.md" "| base:$BID | immutable direction anchor | 生效 |"
# state machine: a second activation is refused
assert_fails bash "$WS/scripts/activate-base-plan.sh" "$BID"

# derived-plan links: --base lands in both tables' 基准 cell
OUTD="$(bash "$WS/scripts/new-plan.sh" "derived work" --base "$BID")"
DID="$(printf '%s' "$OUTD" | grep -o 'plan:[0-9]*' | head -1 | cut -d: -f2)"
assert_contains "$WS/plan.md" "| $DID | derived work | base:$BID |"
assert_contains "$WS/plan/index.md" "| $DID | derived work | todo | base:$BID |"
# unknown base refused before any write
assert_fails bash "$WS/scripts/new-plan.sh" "bad link" --base 9999
# default cell when no --base: dash
assert_contains "$WS/plan/index.md" "| $PID | host plan one | todo | - |"

# second base stays 待审核: an open plan deriving from it is REPORT-ONLY
OUT2="$(bash "$WS/scripts/new-base-plan.sh" "second direction")"
BID2="$(printf '%s' "$OUT2" | grep -o 'base:[0-9]*' | head -1 | cut -d: -f2)"
BFILE2="$(ls "$WS"/plan/base/"$BID2"-*.md)"
[ "$BID2" = "0002" ] || fail "second base id expected 0002, got $BID2"
OUTE="$(bash "$WS/scripts/new-plan.sh" "early derived" --base "$BID2")"
EID="$(printf '%s' "$OUTE" | grep -o 'plan:[0-9]*' | head -1 | cut -d: -f2)"
# both namespaces hold the same number — the base: prefix keeps the rows
# distinct (as_row_key resolves each to its own row)
grep -q "^| base:$BID2 |" "$WS/plan/index.md" || fail "base row drifted away"
grep -q "^| $DID |" "$WS/plan/index.md" || fail "plan row drifted away"
DOC="$(bash "$WS/scripts/doctor.sh" 2>&1 || true)"
assert_output_contains "$DOC" "plan:$EID derives from base:$BID2 which is \"待审核\""

# retire gates: bad status; replaced without --by; --by pointing at a
# non-生效 successor
assert_fails bash "$WS/scripts/retire-base-plan.sh" "$BID" sideways "x"
assert_fails bash "$WS/scripts/retire-base-plan.sh" "$BID" replaced "superseded"
assert_fails bash "$WS/scripts/retire-base-plan.sh" "$BID" replaced "superseded" --by "$BID2"
# voided from 待审核 is legal (no successor involved)
RET0="$(bash "$WS/scripts/retire-base-plan.sh" "$BID2" voided "draft dropped")" || fail "void retire failed"
assert_output_contains "$RET0" "废弃"
# so is replaced from 生效 with an activated successor: reactivate path —
# BID2 is now 废弃, create + activate a third base as the real successor
OUT3="$(bash "$WS/scripts/new-base-plan.sh" "successor direction")"
BID3="$(printf '%s' "$OUT3" | grep -o 'base:[0-9]*' | head -1 | cut -d: -f2)"
BFILE3="$(ls "$WS"/plan/base/"$BID3"-*.md)"
python3 - "$BFILE3" <<'EOF'
import re, sys
p = sys.argv[1]
s = open(p).read()
s = re.sub(r"<!-- 方向: 这个基准锚定什么方向.*?-->", "Successor anchor: narrower scope.", s, flags=re.S)
open(p, "w").write(s)
EOF
bash "$WS/scripts/activate-base-plan.sh" "$BID3" >/dev/null || fail "activate successor failed"
cp "$BFILE" "$SB/b1.snapshot"
RET="$(bash "$WS/scripts/retire-base-plan.sh" "$BID" replaced "direction changed" --by "$BID3")" || fail "retire failed"
assert_output_contains "$RET" "被取代"
assert_contains "$WS/plan/index.md" "direction changed → base:$BID3"
# retired row leaves the plan.md Base view (section-scoped), stays in the index
awk '/^## Base/{f=1; next} /^## /{f=0} f' "$WS/plan.md" | grep -q "^| base:$BID |" \
  && fail "retired base row still in plan.md Base view"
grep -q "^| base:$BID |" "$WS/plan/index.md" || fail "retired row must stay in the index"
# the FILE is never touched by retirement
cmp -s "$BFILE" "$SB/b1.snapshot" || fail "retire rewrote the base plan file"
# open derived plan + retired anchor: report-only warning
DOC2="$(bash "$WS/scripts/doctor.sh" 2>&1 || true)"
assert_output_contains "$DOC2" "plan:$DID derives from base:$BID which is \"被取代\""

# tamper: checksum mismatch is corruption — reported, never auto-repaired
printf '\ntamper\n' >> "$BFILE"
DOC3="$(bash "$WS/scripts/doctor.sh" 2>&1 || true)"
assert_output_contains "$DOC3" "no longer matches its activation checksum"
cp "$BFILE" "$SB/b1.tampered"
FIXOUT="$(bash "$WS/scripts/doctor.sh" --fix 2>&1 || true)"
assert_output_contains "$FIXOUT" "no longer matches its activation checksum"
cmp -s "$BFILE" "$SB/b1.tampered" || fail "--fix must not rewrite a frozen base plan"
cp "$SB/b1.snapshot" "$BFILE"

# orphan index row (file gone) --fix removes it from BOTH tables
OUT4="$(bash "$WS/scripts/new-base-plan.sh" "doomed draft")"
BID4="$(printf '%s' "$OUT4" | grep -o 'base:[0-9]*' | head -1 | cut -d: -f2)"
rm -f "$WS"/plan/base/"$BID4"-*.md
DOC4="$(bash "$WS/scripts/doctor.sh" 2>&1 || true)"
assert_output_contains "$DOC4" "has no file in plan/base/ (orphan row)"
FIXOUT2="$(bash "$WS/scripts/doctor.sh" --fix 2>&1 || true)"
assert_output_contains "$FIXOUT2" "removed orphan Base row base:$BID4"
grep -q "^| base:$BID4 |" "$WS/plan/index.md" && fail "orphan row survived --fix"
awk '/^## Base/{f=1; next} /^## /{f=0} f' "$WS/plan.md" | grep -q "^| base:$BID4 |" \
  && fail "orphan view row survived --fix"

# entry-view reconcile: a dropped plan.md Base row is re-added from the index
awk -v k="base:$BID3" '$0 !~ ("^\\| *" k " \\|")' "$WS/plan.md" > "$SB/pm.tmp"
mv "$SB/pm.tmp" "$WS/plan.md"
DOC5="$(bash "$WS/scripts/doctor.sh" 2>&1 || true)"
assert_output_contains "$DOC5" "run --fix to re-add from the index"
FIXOUT3="$(bash "$WS/scripts/doctor.sh" --fix 2>&1 || true)"
assert_output_contains "$FIXOUT3" "plan.md Base view re-added base:$BID3"
awk '/^## Base/{f=1; next} /^## /{f=0} f' "$WS/plan.md" | grep -q "^| base:$BID3 |" \
  || fail "re-added view row missing"

# escape-pipe regression (review P1): a title carrying a raw pipe keeps its
# escaped 方向 cell intact AND the state flips in BOTH tables on activation
OUTP2="$(bash "$WS/scripts/new-base-plan.sh" "piped direction a|b")"
BIDP="$(printf '%s' "$OUTP2" | grep -o 'base:[0-9]*' | head -1 | cut -d: -f2)"
PFILE="$(ls "$WS"/plan/base/"$BIDP"-*.md)"
python3 - "$PFILE" <<'EOF'
import re, sys
p = sys.argv[1]
s = open(p).read()
s = re.sub(r"<!-- 方向: 这个基准锚定什么方向.*?-->", "Pipe title anchor.", s, flags=re.S)
open(p, "w").write(s)
EOF
ACTP="$(bash "$WS/scripts/activate-base-plan.sh" "$BIDP")" || fail "activate pipe-title base failed"
assert_contains "$WS/plan.md" "| base:$BIDP | piped direction a\|b | 生效 |"
assert_contains "$WS/plan/index.md" "| base:$BIDP | piped direction a\|b | 生效 |"

# retire guard: a successor cannot be the retired row itself
assert_fails bash "$WS/scripts/retire-base-plan.sh" "$BID3" replaced "loop" --by "$BID3"

# milestone commit + doctor green (base consistency included). The two derived
# plans linking retired/voided anchors are closed first — the link warning is
# report-only while the plan is OPEN (todo), by design.
for spec in "$DID:derived-work:anchor retired, work landed" "$EID:early-derived:anchor voided"; do
  id="${spec%%:*}"; rest="${spec#*:}"; slug="${rest%%:*}"
  python3 - "$WS/plan/todo/$id-$slug.md" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read()
s = s.replace("<!-- 完成时填写: 一句话结论", "一句话结论: closed")
open(p, "w").write(s)
EOF
done
bash "$WS/scripts/complete-plan.sh" "$DID" done "anchor retired, work landed" >/dev/null || fail "close derived plan failed"
bash "$WS/scripts/complete-plan.sh" "$EID" abandoned "anchor voided" >/dev/null || fail "close early plan failed"
git -C "$WS" add -A >/dev/null 2>&1
git -C "$WS" commit -qm "test: base plan lifecycle milestone" >/dev/null 2>&1
assert_ok bash "$WS/scripts/doctor.sh"

rm -rf "$SB"
echo "PASS t36"
