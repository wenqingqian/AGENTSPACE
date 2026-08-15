#!/usr/bin/env bash
# t19: doctor [14] registry consistency (stale row / nested shield / gitlink
# leak / hot unregistered repo), doctor [15] ex-post commit audit (message +
# path rules over history, report-only), doctor [13] registered-repo whitelist
# exemption, and status.sh multi-repo rendering + empty-registry fallback.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

SB="$(build_sandbox t19)"
WS="$SB/AGENTSPACE"
cd "$SB"   # "--add ." / "--remove ." below must resolve against the sandbox, not the caller's cwd
mc() { git -C "$WS" add -A >/dev/null 2>&1; git -C "$WS" commit -qm "test: t19 milestone" >/dev/null 2>&1 || true; }
hc() { git -C "$SB" add -A >/dev/null 2>&1; git -C "$SB" -c user.name=test -c user.email=test@test commit -qm "$1" >/dev/null 2>&1 || true; }

# --- 0) baseline: register host, commit, doctor green ---
bash "$WS/scripts/repos.sh" --add . >/dev/null
mc
OUT="$(bash "$WS/scripts/doctor.sh")" || fail "baseline doctor must be green: $OUT"

# --- 1) [14] shield missing: drop the /AGENTSPACE/ ignore entry ---
# Commit ONLY the .gitignore change here: an add -A commit would sweep the
# AGENTSPACE gitlink into history itself, where [15] would flag it forever.
sed -i '' 's|^/AGENTSPACE/$|# shield off|' "$SB/.gitignore"
git -C "$SB" add .gitignore
git -C "$SB" -c user.name=test -c user.email=test@test commit -qm "shield off" >/dev/null
OUT="$(bash "$WS/scripts/doctor.sh" || true)"
assert_output_contains "$OUT" "盾牌缺失"
# restore
sed -i '' 's|^# shield off$|/AGENTSPACE/|' "$SB/.gitignore"
git -C "$SB" add .gitignore
git -C "$SB" -c user.name=test -c user.email=test@test commit -qm "shield back" >/dev/null
OUT="$(bash "$WS/scripts/doctor.sh")" || fail "shield restored must be green: $OUT"

# --- 2) [14] leak: force-track a workspace path (gitlink) ---
# From here on doctor can never be green again in this sandbox: [15] is
# report-only forever, so the violating commit stays flagged inside the
# COMMIT_AUDIT_N window. All later assertions target specific issue lines.
sed -i '' 's|^/AGENTSPACE/$|# shield off|' "$SB/.gitignore"
git -C "$SB" add AGENTSPACE .gitignore 2>/dev/null || true
git -C "$SB" -c user.name=test -c user.email=test@test commit -qm "gitlink in" >/dev/null
OUT="$(bash "$WS/scripts/doctor.sh" || true)"
assert_output_contains "$OUT" "已被登记仓库跟踪"
assert_output_contains "$OUT" "触碰工作区路径 AGENTSPACE"
# cleanup: untrack the gitlink, restore shield
git -C "$SB" rm -q --cached AGENTSPACE >/dev/null 2>&1 || true
sed -i '' 's|^# shield off$|/AGENTSPACE/|' "$SB/.gitignore"
hc "gitlink out"
OUT="$(bash "$WS/scripts/doctor.sh" || true)"
assert_output_not_contains "$OUT" "盾牌缺失"
assert_output_not_contains "$OUT" "已被登记仓库跟踪"
# report-only forever: the committed gitlink stays flagged by [15]
assert_output_contains "$OUT" "触碰工作区路径 AGENTSPACE"

# --- 3) [14] stale row: registered repo moved away ---
mkdir -p "$SB/inner" && git -C "$SB/inner" init -q -b main \
  && git -C "$SB/inner" -c user.name=test -c user.email=test@test commit -q --allow-empty -m init >/dev/null
bash "$WS/scripts/repos.sh" --add inner >/dev/null
mv "$SB/inner" "$SB/inner-moved"
OUT="$(bash "$WS/scripts/doctor.sh" || true)"
assert_output_contains "$OUT" "登记仓库路径不存在"
bash "$WS/scripts/repos.sh" --remove inner >/dev/null   # stale-row removal must work
rm -rf "$SB/inner-moved"   # scenario over — a moved-away repo left in the tree is itself hot+unregistered
mc

# --- 4) [14] hot unregistered repo (fresh commit, inside project tree) ---
mkdir -p "$SB/hotrepo" && git -C "$SB/hotrepo" init -q -b main \
  && git -C "$SB/hotrepo" -c user.name=test -c user.email=test@test commit -q --allow-empty -m init >/dev/null
OUT="$(bash "$WS/scripts/doctor.sh" || true)"
assert_output_contains "$OUT" "近期活跃但未登记"
# registering silences it (targeted: [15] keeps the step-2 commit flagged)
bash "$WS/scripts/repos.sh" --add hotrepo >/dev/null
mc
OUT="$(bash "$WS/scripts/doctor.sh" || true)"
assert_output_not_contains "$OUT" "近期活跃但未登记"

# --- 5) [15] ex-post audit: a violating commit already in history ---
mkdir -p "$SB/wandb" && echo x > "$SB/wandb/run.db"
git -C "$SB" add wandb/run.db
git -C "$SB" -c user.name=test -c user.email=test@test commit -qm "plan:0013 的训练结果" >/dev/null
OUT="$(bash "$WS/scripts/doctor.sh" || true)"
assert_output_contains "$OUT" "commit message 含工作区记账引用"
assert_output_contains "$OUT" "commit 含实验输出目录 wandb/"
# report-only: the file stays tracked, doctor --fix must NOT touch history
bash "$WS/scripts/doctor.sh" --fix >/dev/null 2>&1 || true
git -C "$SB" ls-files | grep -q "^wandb/run.db$" || fail "[15]/--fix must never rewrite history (wandb/run.db must stay)"
# 15 only scans registered repos — hotrepo's clean history stays silent
OUT2="$(bash "$WS/scripts/doctor.sh" || true)"
assert_output_not_contains "$OUT2" "hotrepo @"
# cleanup the violation (user-side action, as designed)
git -C "$SB" rm -q --cached wandb/run.db >/dev/null
git -C "$SB" -c user.name=test -c user.email=test@test commit -qm "untrack wandb" >/dev/null
rm -rf "$SB/wandb"
OUT="$(bash "$WS/scripts/doctor.sh" || true)"
# the violating commit remains in history forever — [15] keeps reporting it
assert_output_contains "$OUT" "记账引用"
# [15] deterministic quality rule: a blank-title commit is flagged (report-only)
git -C "$SB" -c user.name=test -c user.email=test@test commit -q --allow-empty --allow-empty-message -m "" >/dev/null
OUT="$(bash "$WS/scripts/doctor.sh" || true)"
assert_output_contains "$OUT" "标题为空"

# --- 6) [13] exemption: standalone + symlink into a registered repo ---
# The link must resolve OUT of the workspace into the registered host tree:
# from AGENTSPACE/data that is ../../shared-data (../shared-data would land
# inside AGENTSPACE and never surface as an external ref at all).
mkdir -p "$SB/shared-data" && echo payload > "$SB/shared-data/blob.bin"
ln -sfn ../../shared-data "$WS/data/via-host"
bash "$WS/scripts/mode.sh" --standalone >/dev/null 2>&1 || true
OUT="$(bash "$WS/scripts/doctor.sh" || true)"
assert_output_contains "$OUT" "登记仓库"
assert_output_not_contains "$OUT" "引用失效"
assert_output_not_contains "$OUT" "外部引用未白名单"
bash "$WS/scripts/mode.sh" --hybrid >/dev/null 2>&1
rm -f "$WS/data/via-host"
mc; hc "t19 cleanup"

# --- 7) status: multi-repo rendering ---
OUT="$(bash "$WS/scripts/status.sh" 0.6.0)"
assert_output_contains "$OUT" "### 关键代码仓库"
assert_output_contains "$OUT" "hotrepo ("
assert_output_contains "$OUT" "### 代码提交 (关键代码仓库 · 每仓库最近 3 条)"
assert_output_contains "$OUT" "#### hotrepo ("
# per-commit soft slots keep their shape
printf '%s\n' "$OUT" | grep -Eq '^  概括\[[0-9a-f]+\]: —$' || fail "概括 placeholder missing"
# section order intact (### does not disturb the ## sequence)
printf '%s\n' "$OUT" | grep -E '^## ' | awk '{sub(/^## /,""); sub(/[(].*/,""); gsub(/ +$/,""); print}' \
  | paste -sd, - | grep -Fq "项目总览,版本与环境,推进总览,进行中,近期动态,软告警,会话入口" \
  || fail "## section order drifted"

# --- 8) status: empty-registry fallback ---
bash "$WS/scripts/repos.sh" --remove . >/dev/null
bash "$WS/scripts/repos.sh" --remove hotrepo >/dev/null
mc
OUT="$(bash "$WS/scripts/status.sh" 0.6.0)"
assert_output_contains "$OUT" "(无登记仓库)"
assert_output_contains "$OUT" "### 代码提交 (宿主仓库 · 最近 5 条)"
assert_output_contains "$OUT" "(未登记 — 回退宿主仓库探测"

echo "t19 PASS: doctor [13]/[14]/[15] + status multi-repo"
