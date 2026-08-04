#!/usr/bin/env bash
# t08: lock/atomic-write hardening — stale locks (dead PID, old pid-less) are
# recovered instead of deadlocking writers; a live lock is never stolen;
# atomic writes preserve file permissions. Each case uses a fresh sandbox.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

# --- stale lock with a dead owner PID: recovered, write proceeds ---
SB="$(build_sandbox t08a)"
WS="$SB/AGENTSPACE"
mkdir -p "$WS/.scripts.lock"
printf '%s' "999999" > "$WS/.scripts.lock/pid"   # a PID that cannot be alive
OUT="$(bash "$WS/scripts/new-plan.sh" "Stale Lock Plan")"
printf '%s' "$OUT" | grep -q 'plan:[0-9]*' || fail "write blocked by stale lock"
[ ! -e "$WS/.scripts.lock" ] || fail "stale lock not cleaned up"
[ ! -e "$WS/.scripts-tmp."* ] || fail "tmp dir left behind"
rm -rf "$SB"

# --- stale pid-less lock older than the grace window: recovered ---
SB="$(build_sandbox t08b)"
WS="$SB/AGENTSPACE"
mkdir -p "$WS/.scripts.lock"
touch -t 200001010000 "$WS/.scripts.lock"        # 20 years old → stale
OUT="$(bash "$WS/scripts/new-plan.sh" "Old Lock Plan")"
printf '%s' "$OUT" | grep -q 'plan:[0-9]*' || fail "write blocked by old pid-less lock"
rm -rf "$SB"

# --- live lock (alive PID) is never stolen: writer waits ---
SB="$(build_sandbox t08c)"
WS="$SB/AGENTSPACE"
mkdir -p "$WS/.scripts.lock"
printf '%s' "$$" > "$WS/.scripts.lock/pid"        # the test shell itself: alive
bash "$WS/scripts/new-plan.sh" "Live Lock Plan" >/dev/null 2>&1 &
WRITER=$!
sleep 1
[ -z "$(ls "$WS/plan/todo/"*.md 2>/dev/null || true)" ] \
  || fail "write proceeded while the lock is held by a live process"
rm -rf "$WS/.scripts.lock"                          # simulate the holder finishing
wait "$WRITER" || fail "writer failed after lock release"
[ -n "$(ls "$WS/plan/todo/"*.md 2>/dev/null || true)" ] \
  || fail "writer did not complete after lock release"
rm -rf "$SB"

# --- atomic write preserves the target's permissions ---
SB="$(build_sandbox t08d)"
WS="$SB/AGENTSPACE"
chmod 600 "$WS/plan.md"
before="$(stat -f '%Lp' "$WS/plan.md")"
bash "$WS/scripts/new-plan.sh" "Perm Plan" >/dev/null 2>&1
after="$(stat -f '%Lp' "$WS/plan.md")"
[ "$before" = "$after" ] || fail "plan.md permissions changed: $before -> $after"
rm -rf "$SB"

echo "PASS t08"
