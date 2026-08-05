#!/usr/bin/env bash
# t11: handoff × doctor — [10] residue consistency (dangling row / orphan
# file / duplicate rows, shape-based row parsing tolerating \| descriptions)
# and [11] staleness (report-only, find -mtime +7 threshold). Also: status.sh
# lists handoffs with the staleness marker.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

SB="$(build_sandbox t11)"
WS="$SB/AGENTSPACE"
HS="$WS/scripts/handoff.sh"
DOC="$WS/scripts/doctor.sh"
ST="$WS/scripts/status.sh"
INDEX="$WS/handoff/index.md"
D="$(date +%F)"

# milestone commit so doctor [0] stays clean between assertions
mc() { git -C "$WS" add -A >/dev/null 2>&1; git -C "$WS" commit -qm "test: t11 milestone" >/dev/null 2>&1 || true; }

# --- fresh consistent handoff: doctor green, status lists it ---
OUT="$(bash "$HS" --produce --name "alpha" --description "配对一致" 2>&1)"
assert_output_contains "$OUT" "handoff produced"
mc
assert_ok bash "$DOC"
OUT="$(bash "$ST" 2>&1)"
assert_output_contains "$OUT" "alpha"

# --- crashed consume: dangling row (file gone) → red; --fix removes the row ---
rm "$WS/handoff/handoff_alpha.md"
OUT="$(bash "$DOC" 2>&1 || true)"
assert_output_contains "$OUT" "missing file"
assert_output_contains "$OUT" "dangling row"
OUT="$(bash "$DOC" --fix 2>&1 || true)"
assert_output_contains "$OUT" "removed dangling handoff row"
mc
assert_ok bash "$DOC"

# --- crashed produce: orphan file (row gone) → red; --fix never deletes it ---
bash "$HS" --produce --name "beta" >/dev/null 2>&1
grep -vF "| beta |" "$INDEX" > "$INDEX.tmp" && mv "$INDEX.tmp" "$INDEX"
mc
OUT="$(bash "$DOC" --fix 2>&1 || true)"
assert_output_contains "$OUT" "not indexed"
[ -f "$WS/handoff/handoff_beta.md" ] || fail "--fix must never delete an orphan handoff file"
rm "$WS/handoff/handoff_beta.md"   # user reads the snapshot, then removes manually
mc
assert_ok bash "$DOC"

# --- duplicate rows (hand-edit artifact) → red ---
bash "$HS" --produce --name "gamma" >/dev/null 2>&1
awk -v dup="| gamma | dup | handoff_gamma.md | $D |" '{ print; if (index($0, "| gamma |")) print dup }' "$INDEX" > "$INDEX.tmp" && mv "$INDEX.tmp" "$INDEX"
mc
OUT="$(bash "$DOC" 2>&1 || true)"
assert_output_contains "$OUT" "duplicate handoff index rows"
assert_output_contains "$OUT" "duplicate handoff index locations"
grep -vF "| gamma | dup |" "$INDEX" > "$INDEX.tmp" && mv "$INDEX.tmp" "$INDEX"
mc
assert_ok bash "$DOC"

# --- staleness: fresh → silent; old mtime → red with 下一步 preview, no --fix ---
bash "$HS" --produce --name "delta" --description "过时审核" >/dev/null 2>&1
awk '{ print; if ($0 == "## 下一步") print "- 重试推送并确认同步" }' "$WS/handoff/handoff_delta.md" > "$WS/handoff/handoff_delta.md.tmp" && mv "$WS/handoff/handoff_delta.md.tmp" "$WS/handoff/handoff_delta.md"
mc
assert_ok bash "$DOC"   # fresh handoff: no staleness finding
touch -t 202001010000 "$WS/handoff/handoff_delta.md"
OUT="$(bash "$DOC" 2>&1 || true)"
assert_output_contains "$OUT" "stale handoff"
assert_output_contains "$OUT" "delta"
assert_output_contains "$OUT" "重试推送并确认同步"
OUT="$(bash "$DOC" --fix 2>&1 || true)"
assert_output_contains "$OUT" "stale handoff"    # report-only: --fix must not clear it
[ -f "$WS/handoff/handoff_delta.md" ] || fail "--fix must never delete a stale handoff file"
assert_contains "$INDEX" "| delta |"
# status.sh marks it stale
OUT="$(bash "$ST" 2>&1)"
assert_output_contains "$OUT" "delta"
assert_output_contains "$OUT" "过时"
# user resolves by consuming (reads the snapshot, then consumes)
bash "$HS" --consume --name "delta" >/dev/null 2>&1
mc
assert_ok bash "$DOC"

# --- \| tolerance: escaped-pipe description parses as one intact row ---
bash "$HS" --produce --name "esc" --description "a | b" >/dev/null 2>&1
mc
assert_ok bash "$DOC"   # [10] must not flag the escaped row as malformed
OUT="$(bash "$ST" 2>&1)"
assert_output_contains "$OUT" "esc"

# --- R2 regression: duplicate names, FIRST row live, SECOND dangling — --fix
#     must remove the dangling row and keep the live one ---
bash "$HS" --produce --name "dupname" >/dev/null 2>&1
awk -v dup="| dupname | x | handoff_dupname2.md | $D |" '{ print; if (index($0, "| dupname |")) print dup }' "$INDEX" > "$INDEX.tmp" && mv "$INDEX.tmp" "$INDEX"
mc
OUT="$(bash "$DOC" --fix 2>&1 || true)"
assert_output_contains "$OUT" "removed dangling handoff row"
[ -f "$WS/handoff/handoff_dupname.md" ] || fail "--fix removed the LIVE row under duplicate names"
assert_contains "$INDEX" "| dupname |  | handoff_dupname.md |"
assert_not_contains "$INDEX" "handoff_dupname2.md"
mc
assert_ok bash "$DOC"

# --- R3 regression: stale handoff with EMPTY description — the report must
#     keep the date in the date slot (IFS-tab empty-field collapse) ---
bash "$HS" --produce --name "nod" >/dev/null 2>&1   # no --description
touch -t 202001010000 "$WS/handoff/handoff_nod.md"
OUT="$(bash "$DOC" 2>&1 || true)"
assert_output_contains "$OUT" "stale handoff nod ($D,"
bash "$HS" --consume --name "nod" >/dev/null 2>&1
mc

# --- R1 regression: workspace path containing a space — find output must not
#     be word-split into fragmented stale reports ---
SB2="$(mktemp -d "/tmp/as-test t11-space-XXXXXX")" || fail "mktemp spaced"
mkdir -p "$SB2/project"
(cd "$SB2/project" && bash "$REPO/skills/agentspace-init/scripts/init-agentspace.sh" >/dev/null 2>&1) || fail "init in spaced path"
bash "$SB2/project/AGENTSPACE/scripts/handoff.sh" --produce --name "spaced" >/dev/null 2>&1
touch -t 202001010000 "$SB2/project/AGENTSPACE/handoff/handoff_spaced.md"
OUT="$(bash "$SB2/project/AGENTSPACE/scripts/doctor.sh" 2>&1 || true)"
assert_output_contains "$OUT" "stale handoff spaced"
rm -rf "$SB2"

# --- --keep marker: a kept snapshot is intentionally preserved — [11] skips it ---
bash "$HS" --produce --name "kept" >/dev/null 2>&1
touch -t 202001010000 "$WS/handoff/handoff_kept.md"
OUT="$(bash "$DOC" 2>&1 || true)"
assert_output_contains "$OUT" "stale handoff kept"     # unmarked: red
bash "$HS" --consume --keep --name "kept" >/dev/null 2>&1
assert_contains "$WS/handoff/handoff_kept.md" "> 状态: kept(--keep"
touch -t 202001010000 "$WS/handoff/handoff_kept.md"   # make it old again despite the append
mc
assert_ok bash "$DOC"                                  # marked: skipped → green
bash "$HS" --consume --name "kept" >/dev/null 2>&1
mc

# --- CJK handoff name: full read-path compatibility (doctor/list/status) ---
bash "$HS" --produce --name "中文交接" --description "CJK 名称" >/dev/null 2>&1
touch -t 202001010000 "$WS/handoff/handoff_中文交接.md"
OUT="$(bash "$DOC" 2>&1 || true)"
assert_output_contains "$OUT" "stale handoff 中文交接"
OUT="$(bash "$HS" --list 2>&1)"
assert_output_contains "$OUT" "中文交接"
assert_output_not_contains "$OUT" "行格式异常"   # parsed path, not the raw-row fallback
OUT="$(bash "$ST" 2>&1)"
assert_output_contains "$OUT" "中文交接"
assert_output_not_contains "$OUT" "行格式异常"
bash "$HS" --consume --name "中文交接" >/dev/null 2>&1
mc

# --- cleanup: consume the remaining handoffs ---
bash "$HS" --consume --name "gamma" >/dev/null 2>&1
bash "$HS" --consume --name "esc" >/dev/null 2>&1
bash "$HS" --consume --name "dupname" >/dev/null 2>&1
mc
assert_ok bash "$DOC"

rm -rf "$SB"
echo "PASS t11"
