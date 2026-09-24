#!/usr/bin/env bash
# t39: init-light contract (v1.6.0) — /agentspace-init-light creates a plan-only
# workspace: exact tree (no module entry files/dirs), edition marker, light
# architecture snapshot (modules == ["plan"]), doctor green, status renders,
# plan + base-plan lifecycles work end to end, the eight module-bound scripts
# refuse with the expansion hint before mutating anything, repos/commit-gate
# work, re-init is refused, and the mechanical light→full expansion copy
# converges to a doctor-green full workspace.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

LIGHT_INIT="$REPO/skills/agentspace-init-light/scripts/init-agentspace-light.sh"
FULL_ASSETS="$REPO/skills/agentspace-init/assets/agentspace"

SB="$(mktemp -d "/tmp/as-test-t39-XXXXXX")" || exit 1
mkdir -p "$SB/project"
WS="$SB/project/AGENTSPACE"

# --- 1) light init: exit 0, doctor self-check green, root AGENTS.md created ---
set +e
OUT="$(cd "$SB/project" && bash "$LIGHT_INIT" 2>&1)"
rc=$?
set -e
[ "$rc" -eq 0 ] || fail "init-light exited $rc: $OUT"
assert_output_contains "$OUT" "== AGENTSPACE initialized (light — plan module only) =="
assert_output_contains "$OUT" "初始化一致性 ✓"
[ -f "$SB/project/AGENTS.md" ] || fail "root AGENTS.md not created"
assert_contains "$SB/project/AGENTS.md" "light 版"

# --- 2) exact tree: plan module + shared trees, no other module entry files ---
for f in AGENTS.md plan.md plan/index.md .gitignore .agentspace-version.json \
         .agentspace-architecture.json .agentspace-repos .agentspace-whitelist; do
  [ -f "$WS/$f" ] || fail "light workspace missing $f"
done
for d in plan/todo plan/done plan/base scripts templates; do
  [ -d "$WS/$d" ] || fail "light workspace missing $d/"
done
for f in plan/todo/.gitkeep plan/done/.gitkeep plan/base/.gitkeep; do
  [ -f "$WS/$f" ] || fail "light workspace missing $f"
done
for f in iterations.md iterations/index.md exp.md exp/index.md data.md examples.md \
         utils.md tests.md notes.md register.md handoff/index.md; do
  [ ! -e "$WS/$f" ] || fail "light workspace must NOT contain $f"
done
for d in iterations exp data examples utils tests notes handoff; do
  [ ! -e "$WS/$d" ] || fail "light workspace must NOT contain $d/"
done
# shared trees are the full set (single source with /agentspace-init)
[ "$(ls "$WS/scripts"/*.sh | wc -l | tr -d ' ')" = "$(ls "$FULL_ASSETS/scripts"/*.sh | wc -l | tr -d ' ')" ] \
  || fail "scripts/ tree is not the full set"
[ "$(ls "$WS/templates"/*.md | wc -l | tr -d ' ')" = "$(ls "$FULL_ASSETS/templates"/*.md | wc -l | tr -d ' ')" ] \
  || fail "templates/ tree is not the full set"

# --- 3) self-description: edition marker + light architecture snapshot -------
assert_contains "$WS/AGENTS.md" "## agentspace edition"
grep -A1 '^## agentspace edition$' "$WS/AGENTS.md" | grep -qx 'light' || fail "edition block value is not 'light'"
assert_contains "$WS/AGENTS.md" "## agentspace mode"
assert_contains "$WS/AGENTS.md" "未初始化模块"
python3 - "$WS/.agentspace-architecture.json" <<'EOF' || fail "light architecture contract"
import json, sys
d = json.load(open(sys.argv[1]))
assert d["modules"] == ["plan"], d["modules"]
assert "iterations.md" not in d["files"] and "exp.md" not in d["files"]
assert "scripts/lib.sh" in d["files"] and "plan/index.md" in d["files"]
assert d["files"]["plan.md"]["sections"]["Todo"]["columns"] == ["ID", "计划", "基准", "创建日期", "链接"]
EOF

# --- 4) plan lifecycle works end to end ---------------------------------------
ID="0001"
OUT="$(bash "$WS/scripts/new-plan.sh" "first light plan" 2>&1)" || fail "new-plan failed: $OUT"
assert_output_contains "$OUT" "plan:$ID created"
assert_contains "$WS/plan.md" "| $ID | first light plan |"
PLANF="$(printf '%s' "$WS"/plan/todo/"$ID"-*.md)"
[ -f "$PLANF" ] || fail "plan doc missing"
python3 - "$PLANF" <<'EOF'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
s = s.replace("<!-- 这个计划要达成什么(一句话、可验证的终点) -->", "land a light plan")
s = s.replace("<!-- 完成时填写: 一句话结论 + 关键证据(iteration 引用 / 文件链接)。\n     有可迁移教训时, 同步记录 notes/ -->", "landed")
open(p, "w", encoding="utf-8").write(s)
EOF
OUT="$(bash "$WS/scripts/complete-plan.sh" "$ID" done "light done" 2>&1)" || fail "complete-plan failed: $OUT"
assert_output_contains "$OUT" "→ 完成"
assert_output_contains "$OUT" "light workspace (no iterations/notes module)"
assert_output_contains "$OUT" 'git -C "'
assert_output_not_contains "$OUT" "notes.md notes/"
[ -f "$WS/plan/done/$(basename "$PLANF")" ] || fail "plan doc not moved to done/"
[ ! -e "$WS/notes.md" ] || fail "notes.md must stay absent"

# --- 5) base plan lifecycle works in light ------------------------------------
python3 - "$WS" <<'EOF'
import sys, subprocess, glob, os
ws = sys.argv[1]
r = subprocess.run([f"{ws}/scripts/new-base-plan.sh", "keep the light direction"],
                   capture_output=True, text=True)
assert r.returncode == 0, r.stderr
f = glob.glob(f"{ws}/plan/base/0001-*.md")[0]
s = open(f, encoding="utf-8").read()
assert "<!-- 方向: 这个基准锚定什么方向" in s
s = s.replace("<!-- 方向: 这个基准锚定什么方向", "anchor: plans stay plan-only")
open(f, "w", encoding="utf-8").write(s)
r = subprocess.run([f"{ws}/scripts/activate-base-plan.sh", "0001"], capture_output=True, text=True)
assert r.returncode == 0, r.stderr
EOF
assert_contains "$WS/plan/index.md" "| $(printf 'base:%04d' 1) |"

# --- 6) module-bound scripts refuse with the expansion hint -------------------
REFUSE_MSG="module is not initialized in this workspace (light init — plan module only); run /agentspace-update to expand to the full workspace first"
for cmd in "new-iteration.sh 0001 iteration body" \
           "close-iteration.sh 0001 result" \
           "new-exp.sh experiment" \
           "start-exp.sh 0001" \
           "complete-exp.sh 0001 done ok" \
           "reopen-exp.sh 0001 reason" \
           "register-module.sh viz visuals" \
           "handoff.sh --list"; do
  set +e
  # unquoted $cmd: the string carries the script name plus its arguments
  OUT="$(bash "$WS/scripts/"$cmd 2>&1)"
  rc=$?
  set -e
  [ "$rc" -ne 0 ] || fail "module script must refuse in light workspace: $cmd"
  assert_output_contains "$OUT" "$REFUSE_MSG"
done
# refusals happen before ANY mutation: no module files appeared
[ ! -e "$WS/iterations.md" ] && [ ! -e "$WS/exp.md" ] && [ ! -e "$WS/register.md" ] \
  || fail "refused script created module files"

# --- 7) workspace-level scripts still work: repos + commit gate ---------------
mkdir "$SB/keyrepo" && git -C "$SB/keyrepo" init -q -b main
git -C "$SB/keyrepo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
assert_ok bash "$WS/scripts/repos.sh" --add "$SB/keyrepo"
assert_contains "$WS/.agentspace-repos" "keyrepo"
echo "hello" > "$SB/keyrepo/a.txt"
git -C "$SB/keyrepo" add a.txt
LEAK_MSG="$(printf 'plan: %04d leak' 1)"
assert_fails bash "$WS/scripts/commit-check.sh" "$SB/keyrepo" "$LEAK_MSG"
assert_ok bash "$WS/scripts/commit-check.sh" "$SB/keyrepo" "add a file"

# --- 8) doctor green + status renders on the populated light workspace --------
git -C "$WS" add -A -- . && git -C "$WS" -c user.name=t -c user.email=t@t commit -qm "milestone: light plan cycle"
assert_ok bash "$WS/scripts/doctor.sh"
OUT="$(bash "$WS/scripts/status.sh" 2>&1)"
assert_output_contains "$OUT" "next: plan 0002"
assert_output_contains "$OUT" "base 1 生效"

# --- 9) re-init guard ----------------------------------------------------------
set +e
OUT="$(cd "$SB/project" && bash "$LIGHT_INIT" 2>&1)"
rc=$?
set -e
[ "$rc" -eq 0 ] || fail "re-init must exit 0 (idempotent report)"
assert_output_contains "$OUT" "already exists"

# --- 10) mechanical light→full expansion copy converges (doctor green) --------
mkdir -p "$WS/iterations" "$WS/handoff" "$WS/exp/todo" "$WS/exp/doing" "$WS/exp/done" \
         "$WS/data" "$WS/examples" "$WS/utils" "$WS/tests" "$WS/notes"
for f in iterations.md exp.md data.md examples.md utils.md tests.md notes.md register.md; do
  cp "$FULL_ASSETS/$f" "$WS/$f"
done
cp "$FULL_ASSETS/iterations/index.md" "$WS/iterations/index.md"
cp "$FULL_ASSETS/exp/index.md" "$WS/exp/index.md"
cp "$FULL_ASSETS/handoff/index.md" "$WS/handoff/index.md"
touch "$WS/exp/todo/.gitkeep" "$WS/exp/doing/.gitkeep" "$WS/exp/done/.gitkeep" \
      "$WS/examples/.gitkeep" "$WS/utils/.gitkeep" "$WS/tests/.gitkeep" "$WS/notes/.gitkeep"
git -C "$WS" add -A -- . && git -C "$WS" -c user.name=t -c user.email=t@t commit -qm "milestone: light-to-full expansion"
# module scripts now pass their guard (entry files exist) — iterations flow works
PLAN2="0002"
OUT="$(bash "$WS/scripts/new-plan.sh" "post expansion plan" 2>&1)" || fail "new-plan after expansion failed"
assert_output_contains "$OUT" "plan:$PLAN2 created"
PLANF2="$(printf '%s' "$WS"/plan/todo/"$PLAN2"-*.md)"
OUT="$(bash "$WS/scripts/new-iteration.sh" "$PLAN2" "first iteration" 2>&1)" || fail "new-iteration after expansion failed"
assert_output_contains "$OUT" "iteration_$(printf '%04d' 1) created"
ITERF="$WS/iterations/iteration_$(printf '%04d' 1)/readme.md"
python3 - "$ITERF" <<'EOF'
import sys
s = open(sys.argv[1], encoding="utf-8").read()
s = s.replace("<!-- 会话续接块:", "续接块已更新:")
open(sys.argv[1], "w", encoding="utf-8").write(s)
EOF
# the expanded workspace is a valid full workspace: doctor green
git -C "$WS" add -A -- . && git -C "$WS" -c user.name=t -c user.email=t@t commit -qm "milestone: first iteration"
assert_ok bash "$WS/scripts/doctor.sh"

rm -rf "$SB"
echo "PASS t39"
