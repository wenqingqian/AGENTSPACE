#!/usr/bin/env bash
# t18: key code-repo registry (repos.sh) + commit gate (commit-check.sh).
# repos.sh: list/add idempotent/toplevel normalization/refuse AS_ROOT/refuse
# non-git/remove spellings. commit-check.sh: exit 2 unregistered, PASS clean,
# message idiom bans (case-insensitive, body lines, leading-zero anchor),
# content bans on ADDED lines (comment/literal hit, natural-text pass,
# deletion pass, pure rename pass, rename+edit block, spoofed ++ header
# attribution, uppercase id, per-file cap "+N more" tail, ext-diff driver
# blinding negative, matcher budget sentinel unit pin, binary pass), hard
# blocks (tfevents / wandb dir / ≥50MB / AGENTSPACE gitlink), WARN non-blocking.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

SB="$(build_sandbox t18)"
WS="$SB/AGENTSPACE"
REPOS="$WS/scripts/repos.sh"
GATE="$WS/scripts/commit-check.sh"
cd "$SB"   # several cases pass "." / relative paths — cwd must be the sandbox project
hc() { git -C "$SB" add -A >/dev/null 2>&1; git -C "$SB" -c user.name=test -c user.email=test@test commit -qm "$1" >/dev/null 2>&1 || true; }

# --- repos.sh ---
assert_output_contains "$(bash "$REPOS" --list)" "(无登记仓库)"
PHYS_TMP="$(cd -P /tmp && pwd -P)"
assert_output_contains "$(bash "$REPOS" --add .)" "registered: $PHYS_TMP/"
# stored spelling must be the physical path (sandbox lives under /tmp → $PHYS_TMP)
ROW="$(bash "$REPOS" --list)"
case "$ROW" in "$PHYS_TMP"/*) : ;; *) fail "expected physical absolute row, got: $ROW" ;; esac
assert_output_contains "$(bash "$REPOS" --add .)" "already registered"
# subdir input normalizes to the same toplevel → still idempotent
mkdir -p "$SB/src/deep"
assert_output_contains "$(bash "$REPOS" --add src/deep)" "already registered"
# refuse: the workspace itself
assert_fails bash "$REPOS" --add AGENTSPACE
# refuse: path not inside ANY git worktree (bare dir outside any repo)
NOGIT="$(mktemp -d /tmp/as-t18-nogit-XXXXXX)"
assert_fails bash "$REPOS" --add "$NOGIT"
rm -rf "$NOGIT"
# external repo (outside project root) registers absolute
EXT="$(mktemp -d /tmp/as-t18-ext-XXXXXX)"
EXT="$(cd -P "$EXT" && pwd -P)"   # repos.sh stores/echoes the physical spelling
git -C "$EXT" init -q -b main
assert_output_contains "$(bash "$REPOS" --add "$EXT")" "registered: $EXT"
# remove: relative-spelling attempt misses (stored absolute), exact spelling hits
assert_output_contains "$(bash "$REPOS" --remove "$EXT")" "removed: $EXT"
assert_output_contains "$(bash "$REPOS" --remove "$EXT")" "not registered"
# remove stale row after the repo vanished
bash "$REPOS" --add "$EXT" >/dev/null
rm -rf "$EXT"
assert_output_contains "$(bash "$REPOS" --remove "$EXT")" "removed: $EXT"
# registry is scripts-owned — hand-edits are out of scope; rows survive verbatim
assert_output_contains "$(bash "$REPOS" --list)" "/project"
rm -rf "$EXT"

# --- commit-check.sh: registration gate first ---
UNREG="$(mktemp -d /tmp/as-t18-unreg-XXXXXX)"
git -C "$UNREG" init -q -b main
set +e; bash "$GATE" "$UNREG" "x" >/dev/null 2>&1; rc=$?; set -e
[ "$rc" -eq 2 ] || fail "unregistered repo must exit 2, got $rc"
rm -rf "$UNREG"

# clean staged file + clean message → PASS
echo hello > "$SB/a.txt"
git -C "$SB" add a.txt
OUT="$(bash "$GATE" . "add a.txt")"
assert_output_contains "$OUT" "== PASS"

# message bans: canonical idioms, case-insensitive, anywhere in the message.
# Fixtures are CONSTRUCTED at runtime (printf %04d), never spelled out as
# literals — this file is tracked content in the plugin repo and must stay
# clean under its own gate + verify-release [12] (self-hosting discipline).
MSG1="$(printf 'plan:%04d 完成' 13)"
MSG2="$(printf 'PLAN: %04d done' 14)"
MSG3="$(printf 'iteration_%04d 修复' 9)"
MSG4="$(printf 'ITERATION_%04d x' 1)"
for m in "$MSG1" "$MSG2" "$MSG3" "$MSG4"; do
  set +e; OUT="$(bash "$GATE" . "$m")"; rc=$?; set -e
  [ "$rc" -eq 1 ] || fail "message '$m' must be blocked"
  assert_output_contains "$OUT" "BLOCK"
done
# multi-line body hit (constructed the same way — no realized literal here)
BODYID="$(printf 'plan:%04d' 7)"
set +e; OUT="$(bash "$GATE" . "subject line

body refers to $BODYID here")"; rc=$?; set -e
[ "$rc" -eq 1 ] || fail "body-line id must be blocked"
# natural text must pass (4-digit floor + tight idioms)
for m in "test plan: 3 phases" "refactor iteration logic" "agentspace: bump version" "roadmap plan: 2026"; do
  set +e; OUT="$(bash "$GATE" . "$m")"; rc=$?; set -e
  [ "$rc" -eq 0 ] || fail "natural message '$m' must pass, got: $OUT"
done
# variants without the canonical separator fall to the agent layer — script passes them
OUT="$(bash "$GATE" . "plan_0013 variant")"
assert_output_contains "$OUT" "== PASS"
# blank title (the one deterministic quality rule): empty / whitespace-only /
# newline-only messages always block
for m in "" "   " $'\n\n'; do
  set +e; OUT="$(bash "$GATE" . "$m")"; rc=$?; set -e
  [ "$rc" -eq 1 ] || fail "blank title must block: '${m}'"
  assert_output_contains "$OUT" "标题为空"
done
# a title on line 1 with body after is fine (title is what matters)
OUT="$(bash "$GATE" . "add retry to launcher

why: the .42 host drops connections")"
assert_output_contains "$OUT" "== PASS"

# --- file rules ---
git -C "$SB" reset -q
# tfevents signature (nested path, distinctive basename)
mkdir -p "$SB/runs/sept"
echo x > "$SB/runs/sept/events.out.tfevents.1700000000.host"
git -C "$SB" add runs/sept/events.out.tfevents.1700000000.host
set +e; OUT="$(bash "$GATE" . "train")"; rc=$?; set -e
[ "$rc" -eq 1 ] || fail "tfevents must block"
assert_output_contains "$OUT" "tensorboard"
git -C "$SB" reset -q

# wandb top-level dir
mkdir -p "$SB/wandb"; echo x > "$SB/wandb/latest.db"
git -C "$SB" add wandb/latest.db
set +e; OUT="$(bash "$GATE" . "train")"; rc=$?; set -e
[ "$rc" -eq 1 ] || fail "wandb/ must block"
git -C "$SB" reset -q

# ≥50MB blob
dd if=/dev/zero of="$SB/big.bin" bs=1048576 count=51 2>/dev/null
git -C "$SB" add big.bin
set +e; OUT="$(bash "$GATE" . "big")"; rc=$?; set -e
[ "$rc" -eq 1 ] || fail "51MB blob must block"
assert_output_contains "$OUT" "51MB"
git -C "$SB" reset -q; rm -f "$SB/big.bin"

# WARN: 200KB .npy under runs/ — passes with warnings, never blocks
dd if=/dev/zero of="$SB/runs/metric.npy" bs=1024 count=200 2>/dev/null
git -C "$SB" add runs/metric.npy
OUT="$(bash "$GATE" . "metrics")"
assert_output_contains "$OUT" "== PASS"
assert_output_contains "$OUT" "WARN (1)"
assert_output_contains "$OUT" "顶层输出目录 runs/"
git -C "$SB" reset -q

# --- content rules (v0.6.4): ADDED lines carry the same idiom ban ---
LEAK="$(printf '# plan:%04d implements this' 1)"
ITAG="$(printf 'iteration_%04d' 3)"
printf '# header\nx = 1\n' > "$SB/c.py"
git -C "$SB" add c.py
git -C "$SB" -c user.name=test -c user.email=test@test commit -qm "add c" >/dev/null 2>&1 || true
# staged comment + string literal with canonical ids → BLOCK with file:line
printf '# header\nx = 2\n%s\ntag = "%s"\n' "$LEAK" "$ITAG" > "$SB/c.py"
git -C "$SB" add c.py
set +e; OUT="$(bash "$GATE" . "tune lr")"; rc=$?; set -e
[ "$rc" -eq 1 ] || fail "added-line id in comment must block"
assert_output_contains "$OUT" "content:"
assert_output_contains "$OUT" "c.py:3"
assert_output_contains "$OUT" "c.py:4"
# natural comment text passes — the leading-zero anchor holds on content too
printf '# header\nx = 3\n# test plan: 3 phases\n' > "$SB/c.py"
git -C "$SB" add c.py
OUT="$(bash "$GATE" . "bump x")"
assert_output_contains "$OUT" "== PASS"
# deleting an old leak never blocks (fix-forward always passes)
printf '# header\nx = 4\n' > "$SB/c.py"
git -C "$SB" add c.py
OUT="$(bash "$GATE" . "drop comment")"
assert_output_contains "$OUT" "== PASS"
git -C "$SB" -c user.name=test -c user.email=test@test commit -qm "drop comment" >/dev/null 2>&1 || true
# pure rename: no added lines, nothing blocked (pathspec-scoped staging —
# earlier negative cases left untracked leftovers the gate must not see)
mv "$SB/c.py" "$SB/d.py"; git -C "$SB" add -A -- c.py d.py
OUT="$(bash "$GATE" . "rename file")"
assert_output_contains "$OUT" "== PASS"
# rename + edited hunk carrying a leak → BLOCK (R is not a content bypass)
printf '# header\nx = 5\n%s\n' "$LEAK" >> "$SB/d.py"
git -C "$SB" add -- d.py
set +e; OUT="$(bash "$GATE" . "extend file")"; rc=$?; set -e
[ "$rc" -eq 1 ] || fail "rename+edit added-line id must block"
assert_output_contains "$OUT" "content:"
git -C "$SB" reset -q
# spoofed `+++ ` header: an ADDED line whose text starts `++ ` must be scanned
# as content (hunk counting), never eaten as a file header — attribution stays
# on the real file:line for BOTH the spoof line and the line after it.
# Ids CONSTRUCTED at runtime (self-hosting discipline).
ID5="$(printf 'plan:%04d' 5)"
ID5B="$(printf 'plan:%04d' 8)"
printf 's = 0\n' > "$SB/s.py"
git -C "$SB" add s.py
git -C "$SB" -c user.name=test -c user.email=test@test commit -qm "add s" >/dev/null 2>&1 || true
printf 's = 0\n++ echo %s\n# note %s\n' "$ID5" "$ID5B" > "$SB/s.py"
git -C "$SB" add s.py
set +e; OUT="$(bash "$GATE" . "spoof scan")"; rc=$?; set -e
[ "$rc" -eq 1 ] || fail "spoofed +++ content line must block"
assert_output_contains "$OUT" "content:"
assert_output_contains "$OUT" "s.py:2"
assert_output_contains "$OUT" "s.py:3"
git -C "$SB" reset -q
# uppercase canonical id in an added line → BLOCK (content scan is case-insensitive)
printf '# PLAN: %04d upper\n' 13 > "$SB/u.py"
git -C "$SB" add u.py
set +e; OUT="$(bash "$GATE" . "upper case")"; rc=$?; set -e
[ "$rc" -eq 1 ] || fail "uppercase content id must block"
assert_output_contains "$OUT" "content:"
git -C "$SB" reset -q
# per-file hits cap: 7 leaky lines in ONE staged file → exactly the first
# COMMIT_FILE_HITS_CAP(=5) listed + one "+N more hit(s) suppressed" tail
: > "$SB/cap.py"
for i in 1 2 3 4 5 6 7; do
  printf '# leak %s here\n' "$(printf 'plan:%04d' "$i")" >> "$SB/cap.py"
done
git -C "$SB" add cap.py
set +e; OUT="$(bash "$GATE" . "cap file")"; rc=$?; set -e
[ "$rc" -eq 1 ] || fail "multi-hit leak file must block"
assert_output_contains "$OUT" "+2 more hit(s) suppressed"
assert_output_contains "$OUT" "cap.py:1"
assert_output_contains "$OUT" "cap.py:5"
assert_output_not_contains "$OUT" "cap.py:6"
git -C "$SB" reset -q
# repo-local diff driver blinding: diff.<driver>.command + worktree
# .gitattributes must NOT blind the scan (--no-ext-diff pins it)
git -C "$SB" config diff.blind.command /usr/bin/true
printf '*.py diff=blind\n' > "$SB/.gitattributes"
printf 'x = 1\n# see %s\n' "$(printf 'plan:%04d' 4)" > "$SB/blind.py"
git -C "$SB" add blind.py
set +e; OUT="$(bash "$GATE" . "blind driver")"; rc=$?; set -e
[ "$rc" -eq 1 ] || fail "ext-diff driver must not blind the content scan"
assert_output_contains "$OUT" "content:"
git -C "$SB" config --unset diff.blind.command
rm -f "$SB/.gitattributes"
git -C "$SB" reset -q
# matcher unit pin: the -budget sentinel fires at AS_LINE_MAX and output past
# the budget is suppressed (ids only inside printf format strings, never realized)
UNIT_OUT="$(bash -c 'source "'"$REPO"'/skills/agentspace-init/assets/agentspace/scripts/lib.sh"; { printf "diff --git a/u.py b/u.py\n--- a/u.py\n+++ b/u.py\n@@ -0,0 +1,9 @@\n"; for i in 1 2 3 4 5 6 7 8 9; do printf "+line %d\n" "$i"; done; printf "+leak plan:%04d end\n" 9; } | AS_LINE_MAX=5 as_diff_added_hits')"
assert_output_contains "$UNIT_OUT" "-budget"
assert_output_not_contains "$UNIT_OUT" "leak"
# binary staged: no text hunks, no crash
head -c 2048 /dev/urandom > "$SB/b.bin"; git -C "$SB" add b.bin
OUT="$(bash "$GATE" . "add binary asset")"
assert_output_contains "$OUT" "== PASS"
git -C "$SB" reset -q

# AGENTSPACE gitlink staged (shield removed first — sandbox host gitignores /AGENTSPACE/).
# Commit ONLY the .gitignore change here: an add -A commit would sweep the
# gitlink into history itself, leaving nothing staged for the gate to see.
sed -i '' 's|^/AGENTSPACE/$|# shield off|' "$SB/.gitignore"
git -C "$SB" add .gitignore
git -C "$SB" -c user.name=test -c user.email=test@test commit -qm "shield off" >/dev/null
git -C "$SB" add AGENTSPACE 2>/dev/null || true
set +e; OUT="$(bash "$GATE" . "workspace in")"; rc=$?; set -e
[ "$rc" -eq 1 ] || fail "staged AGENTSPACE gitlink must block"
assert_output_contains "$OUT" "工作区路径混入"
git -C "$SB" reset -q

echo "t18 PASS: registry + commit gate"
