#!/usr/bin/env bash
# t31: parallel-workspace.sh full API (v1.2.0 collaboration table) — init/remove
# cascade, show filters, update rules, send/recv/withdraw, merge-slot
# exclusivity, stale-MERGELOCK takeover. The 60s occupied-slot wait is mocked
# (fake `sleep` first on PATH — zero duration) so the wait path is exercised
# without real waiting; every other path is non-waiting by design.
# Constructed ids only at runtime (selfhost literal discipline).
set -euo pipefail
. "$(dirname "$0")/lib.sh"

SB="$(build_sandbox t31)"
WS="$SB/AGENTSPACE"
PWS="$WS/scripts/parallel-workspace.sh"
DATA="$WS/.agentspace-parallel-workspace.txt"

# fake sleep: the --merge occupied path sleeps 60s once before re-checking —
# a zero-duration sleep keeps the branch under test while the run stays fast
FAKEBIN="$(mktemp -d)"
printf '#!/bin/sh\nexit 0\n' > "$FAKEBIN/sleep"
chmod +x "$FAKEBIN/sleep"

# --- release contract: the data file must ship gitignored ---
assert_contains "$WS/.gitignore" ".agentspace-parallel-workspace.txt"

# --- usage errors: exit 3, no data file touched ---
assert_fails bash "$PWS" --bogus
assert_fails bash "$PWS" --update 1
assert_fails bash "$PWS" --init 1
assert_fails bash "$PWS" --send --src 1 --dst 2
[ ! -f "$DATA" ] || fail "data file created by a pure usage error"

# --- id discipline: numeric only, normalized to 0001 form ---
assert_fails bash "$PWS" --init abc "not numeric"

# --- --init / --show ---
OUT="$(bash "$PWS" --init 1 "lane one" "info-a")"
assert_output_contains "$OUT" "registered: PLAN|0001|doing|lane one|info-a"
[ -f "$DATA" ] || fail "data file not created by --init"
assert_fails bash "$PWS" --init 1 "duplicate id must be refused"
bash "$PWS" --init 2 "lane two" >/dev/null
bash "$PWS" --init 3 "desc | with pipe" "info|x" >/dev/null   # cell-escaping surface

OUT="$(bash "$PWS" --show)"
assert_output_contains "$OUT" "== plans =="
assert_output_contains "$OUT" "PLAN|0001|doing|lane one|info-a"
assert_output_contains "$OUT" "PLAN|0002|doing|lane two|"
assert_output_contains "$OUT" "PLAN|0003|doing|desc \\| with pipe|info\\|x"
OUT="$(bash "$PWS" --show --state test)"
assert_output_contains "$OUT" "== plans (state=test plan=*): 0 row(s) =="   # nothing in test yet
OUT="$(bash "$PWS" --show --plan 2)"
assert_output_contains "$OUT" "PLAN|0002|"
assert_output_not_contains "$OUT" "PLAN|0001|"
# stored escapes: the raw pipe must sit in the file shielded, 5 logical fields
assert_contains "$DATA" 'PLAN|0003|doing|desc \| with pipe|info\|x'

# --- --update: field rewrite, forbidden merge state, unregistered id ---
OUT="$(bash "$PWS" --update 2 --state test --any_info "wip|note")"
assert_output_contains "$OUT" "updated: PLAN|0002|test|lane two|wip\|note"
assert_output_contains "$OUT" "== inbox of 0002 (auto-return after --update): 0 message(s) =="
OUT="$(bash "$PWS" --show --state test)"
assert_output_contains "$OUT" "PLAN|0002|"
assert_output_not_contains "$OUT" "PLAN|0001|"
# escaped desc survives a state rewrite (shield + restore round-trip)
bash "$PWS" --update 3 --state test >/dev/null
assert_contains "$DATA" 'PLAN|0003|test|desc \| with pipe|info\|x'
OUT="$(bash "$PWS" --update 2 --state merge 2>&1 || true)"
assert_output_contains "$OUT" "state=merge"
assert_fails bash "$PWS" --update 99 --state doing

# --- --send / --recv / --revc / --withdraw ---
bash "$PWS" --send --src 1 --dst 2 --msg "hello lane two" >/dev/null
OUT="$(bash "$PWS" --recv 2)"
assert_output_contains "$OUT" "== inbox of 0002: 1 message(s) =="
assert_output_contains "$OUT" "MSG|0001|0002|"
assert_output_contains "$OUT" "hello lane two"
OUT="$(bash "$PWS" --recv 1)"
assert_output_contains "$OUT" "== inbox of 0001: 0 message(s) =="
OUT="$(bash "$PWS" --recv 99)"  # recv on an unregistered id is a plain empty inbox
assert_output_contains "$OUT" "== inbox of 0099: 0 message(s) =="
assert_fails bash "$PWS" --send --src 1 --dst 99 --msg "no such dst"
assert_fails bash "$PWS" --send --src 99 --dst 1 --msg "no such src"
bash "$PWS" --send --src 2 --dst all --msg "standup at noon" >/dev/null
OUT="$(bash "$PWS" --recv 1)"
assert_output_contains "$OUT" "== inbox of 0001: 1 message(s) =="
assert_output_contains "$OUT" "MSG|0002|all|"
OUT="$(bash "$PWS" --revc 2)"   # compatibility alias
assert_output_contains "$OUT" "== inbox of 0002: 2 message(s) =="

OUT="$(bash "$PWS" --withdraw 1)"
assert_output_contains "$OUT" "withdraw: removed 1 sent message row(s)"
OUT="$(bash "$PWS" --recv 2)"
assert_output_contains "$OUT" "== inbox of 0002: 1 message(s) =="
assert_output_not_contains "$OUT" "hello lane two"
OUT="$(bash "$PWS" --withdraw 1)"
assert_output_contains "$OUT" "has no sent message row(s)"

# --- merge-slot exclusivity (short-window iron law), with mocked 60s wait ---
OUT="$(bash "$PWS" --merge 1)"
assert_output_contains "$OUT" "merge state set: PLAN|0001|merge|"
assert_contains "$DATA" "PLAN|0001|merge|"
assert_contains "$DATA" "MERGELOCK|0001|"
OUT="$(bash "$PWS" --merge 1)"   # idempotent re-entry
assert_output_contains "$OUT" "already merge"
# occupied slot: sleep 60 mocked to zero — still occupied after the re-check
OUT="$(PATH="$FAKEBIN:$PATH" bash "$PWS" --merge 2 2>&1 || true)"
assert_output_contains "$OUT" "still occupied by plan 0001"
# stale takeover: occupier's stamp older than the threshold -> revert + proceed
awk 'index($0, "MERGELOCK|0001|") == 1 { print "MERGELOCK|0001|2020-01-01T00:00:00Z"; next } { print }' \
  "$DATA" > "$DATA.tmp" && mv "$DATA.tmp" "$DATA"
OUT="$(PATH="$FAKEBIN:$PATH" bash "$PWS" --merge 2 2>&1)"
assert_output_contains "$OUT" "is stale"
assert_output_contains "$OUT" "merge state set: PLAN|0002|merge|"
OUT="$(bash "$PWS" --show --plan 1)"
assert_output_contains "$OUT" "PLAN|0001|doing|"
assert_contains "$DATA" "MERGELOCK|0002|"
# rollback releases the slot and drops the stamp; free slot -> instant merge
bash "$PWS" --update 2 --state doing >/dev/null
assert_not_contains "$DATA" "MERGELOCK|"
OUT="$(bash "$PWS" --merge 1)"
assert_output_contains "$OUT" "merge state set: PLAN|0001|merge|"

# --- --remove: row + cascade of ALL the plan's MSG rows ---
bash "$PWS" --init 4 "remove four" >/dev/null
bash "$PWS" --init 5 "remove five" >/dev/null
bash "$PWS" --update 1 --state doing >/dev/null   # free the merge slot first
bash "$PWS" --send --src 4 --dst 5 --msg "direct" >/dev/null
bash "$PWS" --send --src 5 --dst 4 --msg "reply" >/dev/null
bash "$PWS" --send --src 4 --dst all --msg "broadcast" >/dev/null
OUT="$(bash "$PWS" --remove 4)"
assert_output_contains "$OUT" "removed: plan 0004 (+3 message row(s) cascaded"
assert_not_contains "$DATA" "PLAN|0004|"
assert_not_contains "$DATA" "MSG|0004|"
assert_not_contains "$DATA" "|0004|"
OUT="$(bash "$PWS" --recv 5)"
assert_output_contains "$OUT" "== inbox of 0005: 1 message(s) =="   # only the earlier standup broadcast survives
assert_output_not_contains "$OUT" "direct"
assert_output_not_contains "$OUT" "reply"
OUT="$(bash "$PWS" --remove 5)"
assert_output_contains "$OUT" "removed: plan 0005"
assert_fails bash "$PWS" --remove 99
bash "$PWS" --help >/dev/null   # exit 0

rm -rf "$SB" "$FAKEBIN"
echo "t31 PASS: parallel-workspace API — init/show/update/send/recv/withdraw, merge exclusivity, stale takeover, remove cascade"
