#!/usr/bin/env bash
# t18: key code-repo registry (repos.sh) + commit gate (commit-check.sh).
# repos.sh: list/add idempotent/toplevel normalization/refuse AS_ROOT/refuse
# non-git/remove spellings. commit-check.sh: exit 2 unregistered, PASS clean,
# message idiom bans (case-insensitive, body lines, leading-zero anchor), hard
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

# message bans: canonical idioms, case-insensitive, anywhere in the message
for m in "plan:0013 完成" "PLAN: 0014 done" "iteration_0009 修复" "ITERATION_0001 x"; do
  set +e; OUT="$(bash "$GATE" . "$m")"; rc=$?; set -e
  [ "$rc" -eq 1 ] || fail "message '$m' must be blocked"
  assert_output_contains "$OUT" "BLOCK"
done
# multi-line body hit
set +e; OUT="$(bash "$GATE" . "subject line

body refers to plan:0007 here")"; rc=$?; set -e
[ "$rc" -eq 1 ] || fail "body-line id must be blocked"
# natural text must pass (4-digit floor + tight idioms)
for m in "test plan: 3 phases" "refactor iteration logic" "agentspace: bump version" "roadmap plan: 2026"; do
  set +e; OUT="$(bash "$GATE" . "$m")"; rc=$?; set -e
  [ "$rc" -eq 0 ] || fail "natural message '$m' must pass, got: $OUT"
done
# variants without the canonical separator fall to the agent layer — script passes them
OUT="$(bash "$GATE" . "plan_0013 variant")"
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
