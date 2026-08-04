#!/usr/bin/env bash
# t08: lock/atomic-write hardening — stale locks (dead PID, old pid-less,
# empty pid file) are recovered instead of deadlocking writers; a live lock
# and a pid-less lock inside the 5-min grace are never stolen; concurrent
# claimants never overlap their critical sections; atomic writes preserve
# file permissions. Each case uses a fresh sandbox.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

# --- stale lock with a dead owner PID: recovered, write proceeds ---
SB="$(build_sandbox t08a)"
WS="$SB/AGENTSPACE"
mkdir -p "$WS/.scripts.lock"
# construct a PID that just died and was reaped — practically unreusable
sleep 30 & SPID=$!
kill -9 "$SPID"
wait "$SPID" 2>/dev/null || true
printf '%s' "$SPID" > "$WS/.scripts.lock/pid"
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

# --- stale lock with an EMPTY pid file + old mtime: recovered (R1 fail-open) ---
SB="$(build_sandbox t08e)"
WS="$SB/AGENTSPACE"
mkdir -p "$WS/.scripts.lock"
: > "$WS/.scripts.lock/pid"           # empty pid (crash between truncate and write)
touch -t 200001010000 "$WS/.scripts.lock"        # old → outside the 5-min grace
OUT="$(bash "$WS/scripts/new-plan.sh" "Empty Pid Plan")"
printf '%s' "$OUT" | grep -q 'plan:[0-9]*' || fail "write blocked by empty-pid stale lock"
[ ! -e "$WS/.scripts.lock" ] || fail "empty-pid stale lock not cleaned up"
rm -rf "$SB"

# --- fresh pid-less lock (inside the 5-min grace): NOT recovered, writer waits ---
SB="$(build_sandbox t08f)"
WS="$SB/AGENTSPACE"
mkdir -p "$WS/.scripts.lock"          # pid-less, mtime = now → within grace
bash "$WS/scripts/new-plan.sh" "Fresh Lock Plan" >/dev/null 2>&1 &
WRITER=$!
sleep 1
[ -z "$(ls "$WS/plan/todo/"*.md 2>/dev/null || true)" ] \
  || fail "pid-less lock within the grace window was stolen (writer should wait)"
rm -rf "$WS/.scripts.lock"            # simulate the crashed holder's lock going away
wait "$WRITER" || fail "writer failed after lock removal"
[ -n "$(ls "$WS/plan/todo/"*.md 2>/dev/null || true)" ] \
  || fail "writer did not complete after lock removal"
rm -rf "$SB"

# --- two concurrent waiters race for one stale lock: critical sections never overlap ---
SB="$(build_sandbox t08g)"
WS="$SB/AGENTSPACE"
mkdir -p "$WS/.scripts.lock"
sleep 30 & SPID=$!
kill -9 "$SPID"
wait "$SPID" 2>/dev/null || true
printf '%s' "$SPID" > "$WS/.scripts.lock/pid"    # dead owner → both see stale
LOG="$SB/lock-trace.log"
WAITER="$SB/waiter.sh"
cat > "$WAITER" <<'EOF'
#!/usr/bin/env bash
# Waiter: acquire the AGENTSPACE lock, log ENTER/EXIT markers, hold briefly.
# Each waiter is its own bash process so $$ is a distinct owner PID.
set -euo pipefail
. "$1/scripts/lib.sh"
as_lock
python3 -c 'import sys, time
pid, log = sys.argv[1], sys.argv[2]
with open(log, "a") as f:
    f.write("ENTER %s %f\n" % (pid, time.time()))' "$$" "$2"
sleep 0.5
python3 -c 'import sys, time
pid, log = sys.argv[1], sys.argv[2]
with open(log, "a") as f:
    f.write("EXIT %s %f\n" % (pid, time.time()))' "$$" "$2"
EOF
bash "$WAITER" "$WS" "$LOG" &
W1=$!
bash "$WAITER" "$WS" "$LOG" &
W2=$!
wait "$W1" || fail "waiter 1 failed"
wait "$W2" || fail "waiter 2 failed"
python3 - "$LOG" <<'EOF' || fail "waiter critical sections overlapped"
import sys
iv = {}
for line in open(sys.argv[1]):
    kind, pid, t = line.split()
    if kind == "ENTER":
        iv[pid] = [float(t), None]
    else:
        iv[pid][1] = float(t)
pids = list(iv)
assert len(pids) == 2, "expected 2 waiters, got %d" % len(pids)
for pid in pids:
    assert iv[pid][1] is not None, "missing EXIT marker for %s" % pid
for i in range(len(pids)):
    for j in range(i + 1, len(pids)):
        a, b = iv[pids[i]], iv[pids[j]]
        assert not (a[0] < b[1] and b[0] < a[1]), \
            "overlap between waiter %s and %s" % (pids[i], pids[j])
EOF
[ ! -e "$WS/.scripts.lock" ] || fail "lock not cleaned up after both waiters exited"
rm -rf "$SB"

echo "PASS t08"
