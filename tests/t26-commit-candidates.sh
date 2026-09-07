#!/usr/bin/env bash
# t26: commit gate wide-net candidate layer (v1.1.0, report-only).
# Message face: `plan-12` / `iteration:34` are candidates that never block
# (exit 0 with a CANDIDATES section); the canonical ban pair still blocks
# (exit 1); a line already matching the canonical pair is never re-listed as
# a candidate (positional dedup, same-line); left word boundary holds
# ("unplanned 4 steps" nets nothing). Diff face: an ADDED comment line with a
# candidate shape is listed under content; a canonical hit on a diff line is
# owned by the ban scan and not re-listed. Gate under test is the sandbox's
# deployed copy (built from the current assets, same reference style as t18).
set -euo pipefail
. "$(dirname "$0")/lib.sh"

SB="$(build_sandbox t26)"
WS="$SB/AGENTSPACE"
REPOS="$WS/scripts/repos.sh"
GATE="$WS/scripts/commit-check.sh"
cd "$SB"   # relative repo arg "." — cwd must be the sandbox project
assert_output_contains "$(bash "$REPOS" --add .)" "registered:"

# one clean staged file so every message case has a realistic staged set
echo hello > "$SB/a.txt"
git -C "$SB" add a.txt

# (a) message `plan-12` → exit 0, candidate listed, never blocks
set +e; OUT="$(bash "$GATE" . "plan-12 lane naming")"; rc=$?; set -e
[ "$rc" -eq 0 ] || fail "candidate-only message must pass, got rc=$rc: $OUT"
assert_output_contains "$OUT" "CANDIDATES (1)"
assert_output_contains "$OUT" "plan-12"
assert_output_contains "$OUT" "== PASS"

# (b) canonical ban in message → exit 1 regardless of the candidate layer
# (id CONSTRUCTED at runtime — self-hosting discipline, cf. t18)
MSG="$(printf 'plan:%04d schema' 13)"
set +e; OUT="$(bash "$GATE" . "$MSG")"; rc=$?; set -e
[ "$rc" -eq 1 ] || fail "canonical message ban must still block, got rc=$rc"
assert_output_contains "$OUT" "BLOCK"
# the banned line is owned by the ban scan — no candidate section rides along
assert_output_not_contains "$OUT" "CANDIDATES"

# (c) same line carries BOTH a canonical id and a candidate shape → exit 1,
# and the candidate shape is NOT re-listed (positional dedup: the whole line
# belongs to the ban scan) — no CANDIDATES section at all
MSG2="$(printf 'apply plan:%04d and plan-12 both' 13)"
set +e; OUT="$(bash "$GATE" . "$MSG2")"; rc=$?; set -e
[ "$rc" -eq 1 ] || fail "combined line must block on the canonical id, got rc=$rc"
assert_output_contains "$OUT" "plan-12"   # visible in the BLOCK listing
assert_output_not_contains "$OUT" "CANDIDATES"

# (d) left word boundary: "unplanned 4 steps" is natural text — no candidate
set +e; OUT="$(bash "$GATE" . "unplanned 4 steps")"; rc=$?; set -e
[ "$rc" -eq 0 ] || fail "natural message must pass, got rc=$rc: $OUT"
assert_output_not_contains "$OUT" "CANDIDATES"

# (e) non-canonical separator `iteration:34` → exit 0 with a candidate
set +e; OUT="$(bash "$GATE" . "iteration:34 report")"; rc=$?; set -e
[ "$rc" -eq 0 ] || fail "iteration:34 is a candidate, not a block, got rc=$rc"
assert_output_contains "$OUT" "CANDIDATES (1)"
assert_output_contains "$OUT" "iteration:34"

# --- diff face: ADDED lines carry the candidate layer too ---
printf '# header\nx = 1\n' > "$SB/c.py"
git -C "$SB" add c.py
git -C "$SB" -c user.name=test -c user.email=test@test commit -qm "add c" >/dev/null 2>&1 || true

# (f) added comment line `# plan-12` → listed as a content candidate, exit 0
printf '# header\nx = 2\n# plan-12 note\n' > "$SB/c.py"
git -C "$SB" add c.py
set +e; OUT="$(bash "$GATE" . "extend c")"; rc=$?; set -e
[ "$rc" -eq 0 ] || fail "diff-face candidate must not block, got rc=$rc: $OUT"
assert_output_contains "$OUT" "CANDIDATES (1)"
assert_output_contains "$OUT" "c.py:3"
assert_output_contains "$OUT" "# plan-12 note"

# diff-face dedup: a canonical hit owns its line (ban listing), while the
# candidate shape on the NEXT line is still listed — full attribution
LEAK="$(printf '# plan:%04d here' 15)"
printf '# header\nx = 3\n%s\n# plan-12 note\n' "$LEAK" > "$SB/c.py"
git -C "$SB" add c.py
set +e; OUT="$(bash "$GATE" . "extend c again")"; rc=$?; set -e
[ "$rc" -eq 1 ] || fail "canonical diff hit must block, got rc=$rc"
assert_output_contains "$OUT" "content:"
assert_output_contains "$OUT" "c.py:3"
assert_output_contains "$OUT" "  - content c.py:4"   # candidate listed
assert_output_not_contains "$OUT" "  - content c.py:3"  # never re-listed
git -C "$SB" reset -q

rm -rf "$SB"
echo "t26 PASS: commit gate candidate layer (message + diff faces, dedup, boundary)"
