#!/usr/bin/env bash
# t34: doctor [16] exp consistency — orphan Todo row (--fix removes), section↔dir
# mismatch (--fix reconciles the row into Doing), orphan exp_spec dir, missing
# exp_spec dir, missing exp_data gitignore line; commit gate exp_NNNN message ban;
# status.sh exp slots (counts / next id / Doing rows / events). Runtime ids only.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

SB="$(build_sandbox t34)"
WS="$SB/AGENTSPACE"
PROJ="$(dirname "$WS")"

bash "$WS/scripts/repos.sh" --add "$PROJ" >/dev/null 2>&1 || fail "repo registration failed"

bash "$WS/scripts/new-plan.sh" "exp doctor plan" >/dev/null
OUT="$(bash "$WS/scripts/new-exp.sh" "doctor checks exp")"
XID="$(printf '%s' "$OUT" | grep -o 'exp_[0-9]*' | head -1 | cut -d_ -f2)"
XD="exp_$XID"
bash "$WS/scripts/start-exp.sh" "$XID" >/dev/null

# --- commit gate: exp bookkeeping id in the message is blocked (exit 1) ---
OUTG="$(bash "$WS/scripts/commit-check.sh" "$PROJ" "test change on $XD")" && fail "gate passed an exp id" || [ $? -eq 1 ] || fail "gate wrong exit code"
printf '%s' "$OUTG" | grep -q "exp_NNNN" || fail "gate message missing exp ban wording"

# --- doctor [16]: section↔dir mismatch (row still in Todo, manual in doing/) ---
python3 - "$WS/exp.md" "$XID" <<'EOF'
import sys
p, xid = sys.argv[1], sys.argv[2]
s = open(p).read()
# move the row back into Todo (simulating a crash between mv and table writes)
j = s.index("\n| ", s.index("| ---", s.index("## Doing")))
row = s[j+1:s.index("\n", j+1)]
s = s[:j+1] + s[s.index("\n", j+1)+1:]          # drop from Doing
k = s.index("\n", s.index("| --- |", s.index("## Todo")))
s = s[:k+1] + row + "\n" + s[k+1:]              # insert into Todo
open(p, "w").write(s)
EOF
DOUT="$(bash "$WS/scripts/doctor.sh" 2>&1)" && fail "doctor green on mismatch" || [ $? -eq 1 ] || fail "doctor wrong exit code"
printf '%s' "$DOUT" | grep -q "section ≠ dir position" || fail "mismatch not reported"
DOUT2="$(bash "$WS/scripts/doctor.sh" --fix 2>&1 || true)"
printf '%s' "$DOUT2" | grep -q "moved Todo → Doing" || fail "row not reconciled"
sed -n '/^## Doing/,/^## 最近完成/p' "$WS/exp.md" | grep -q "^| $XID |" || fail "row not in Doing after --fix"

# --- orphan Todo row (no manual anywhere) → --fix removes ---
python3 - "$WS/exp.md" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read()
k = s.index("\n", s.index("| --- |", s.index("## Todo")))
s = s[:k+1] + "| 9001 | ghost exp | 2026-01-01 | [exp/todo/nowhere.md](exp/todo/nowhere.md) |\n" + s[k+1:]
open(p, "w").write(s)
EOF
DOUT3="$(bash "$WS/scripts/doctor.sh" --fix 2>&1 || true)"
printf '%s' "$DOUT3" | grep -q "removed orphan Todo row exp_9001" || fail "orphan row not removed"

# --- orphan exp_spec dir (no index row) + missing exp_spec dir for a row ---
mkdir -p "$WS/examples/exp_spec/exp_9002"
DOUT4="$(bash "$WS/scripts/doctor.sh" 2>&1)" && fail "doctor green on orphan exp_spec" || [ $? -eq 1 ] || fail "doctor wrong exit code (exp_spec)"
printf '%s' "$DOUT4" | grep -q "exp_9002 has no exp/index.md row" || fail "orphan exp_spec not reported"
rmdir "$WS/examples/exp_spec/exp_9002"
rmdir "$WS/examples/exp_spec/$XD" 2>/dev/null || rm -rf "$WS/examples/exp_spec/$XD"
DOUT5="$(bash "$WS/scripts/doctor.sh" 2>&1)" && fail "doctor green on missing exp_spec" || [ $? -eq 1 ] || fail "doctor wrong exit code (missing exp_spec)"
printf '%s' "$DOUT5" | grep -q "missing examples/exp_spec/$XD" || fail "missing exp_spec not reported"
mkdir -p "$WS/examples/exp_spec/$XD" && touch "$WS/examples/exp_spec/$XD/.gitkeep"

# --- exp_data gitignore contract: missing line is reported ---
python3 - "$WS/.gitignore" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read().replace("exp/exp_data/\n", "")
open(p, "w").write(s)
EOF
DOUT6="$(bash "$WS/scripts/doctor.sh" 2>&1)" && fail "doctor green on missing gitignore line" || [ $? -eq 1 ] || fail "doctor wrong exit code (gitignore)"
printf '%s' "$DOUT6" | grep -q "missing the exp/exp_data/ line" || fail "gitignore line not reported"
printf 'exp/exp_data/\n' >> "$WS/.gitignore"

# --- exp_data dir→row direction: an orphan data dir (no index row) is reported ---
mkdir -p "$WS/exp/exp_data/exp_9003"
DOUT7="$(bash "$WS/scripts/doctor.sh" 2>&1)" && fail "doctor green on orphan exp_data dir" || [ $? -eq 1 ] || fail "doctor wrong exit code (exp_data)"
printf '%s' "$DOUT7" | grep -q "exp/exp_data/exp_9003 has no exp/index.md row" || fail "orphan exp_data not reported"
rm -rf "$WS/exp/exp_data/exp_9003"

# --- status.sh exp slots ---
STOUT="$(bash "$WS/scripts/status.sh" 2>/dev/null || true)"
printf '%s' "$STOUT" | grep -q "exp 0 待跑 / 1 在跑" || fail "status exp counts missing"
printf '%s' "$STOUT" | grep -q "exp $(printf '%04d' $((10#$XID + 1)))" || fail "status next exp id missing"
printf '%s' "$STOUT" | grep -q "\- $XD — doctor checks exp" || fail "status Doing row missing"
printf '%s' "$STOUT" | grep -q "实验登记: doctor checks exp" || fail "status exp event missing"

# cleanup + green
git -C "$WS" add -A >/dev/null 2>&1
git -C "$WS" commit -qm "test: exp doctor milestone" >/dev/null 2>&1
assert_ok bash "$WS/scripts/doctor.sh"

rm -rf "$SB"
echo "PASS t34"
