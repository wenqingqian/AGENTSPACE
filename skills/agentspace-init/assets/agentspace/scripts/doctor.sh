#!/usr/bin/env bash
# 一致性检查: 入口表 / 全量索引 ↔ 文件系统。latest 断链自动修复, 其余报告。
# 用法: doctor.sh
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

issues=0
fixed=0
# Optional 5: 用 printf 避免 echo 对 `-` 开头的消息误解释
# Optional 7: warn/ok 只应在主 shell 调用(管道子 shell 中修改不回传 issues/fixed)
warn() { printf '  [问题] %s\n' "$*"; issues=$((issues + 1)); }
ok()   { printf '  [修复] %s\n' "$*"; fixed=$((fixed + 1)); }

echo "== AGENTSPACE doctor: $AS_ROOT =="
echo

# ---- 1. latest 软连接 ----
echo "[1] iterations/latest"
L="$AS_ROOT/iterations/latest"
if [ -L "$L" ] && [ ! -e "$L" ]; then
  rm -f "$L"
  warn "latest 断链, 已移除"
fi
if [ ! -L "$L" ]; then
  last="$(ls -d "$AS_ROOT"/iterations/iteration_[0-9]* 2>/dev/null | sort | tail -1 || true)"
  if [ -n "$last" ]; then
    ln -sfn "$(basename "$last")" "$L"
    ok "latest -> $(basename "$last")"
  fi
fi

# ---- 2. plan: 文件 ↔ 入口表 ↔ 全量索引 ----
echo "[2] plan 一致性"
shopt -s nullglob

for f in "$AS_ROOT"/plan/todo/[0-9]*.md; do
  id="$(basename "$f" | cut -d- -f1)"
  [ -n "$(as_row_cell "$AS_ROOT/plan.md" "$id" 3)" ] \
    || warn "plan.md Todo 缺少 $id ($(basename "$f"))"
  grep -q "^| *$id *|" "$AS_ROOT/plan/index.md" \
    || warn "plan/index.md 缺少 $id ($(basename "$f"))"
done

for f in "$AS_ROOT"/plan/done/[0-9]*.md; do
  id="$(basename "$f" | cut -d- -f1)"
  grep -q "^| *$id *|" "$AS_ROOT/plan/index.md" \
    || warn "plan/index.md 缺少已完成 $id ($(basename "$f"))"
done

# 入口 Todo 行必须有对应文件
todo_ids="$(awk -F'|' -v sec="$SEC_TODO" '
  $0 == ("## " sec) { f=1; next }
  /^## / { f=0 }
  f && /^\| [0-9]/ { gsub(/ /, "", $2); print $2 }
' "$AS_ROOT/plan.md")"
for id in $todo_ids; do
  ls "$AS_ROOT"/plan/todo/"$id"-*.md >/dev/null 2>&1 \
    || warn "plan.md Todo 行 $id 没有对应文件(孤立行)"
done

# ---- 3. iterations: 目录 ↔ 入口表 ↔ 全量索引 ----
echo "[3] iterations 一致性"
for d in "$AS_ROOT"/iterations/iteration_[0-9]*; do
  [ -d "$d" ] || continue
  id="$(basename "$d" | sed 's/iteration_//')"
  [ -f "$d/readme.md" ] || warn "iteration_$id 缺少 readme.md"
  grep -q "^| *$id *|" "$AS_ROOT/iterations/index.md" \
    || warn "iterations/index.md 缺少 $id"
  # Critical 2: 只对"进行中"的 iteration 要求出现在入口表(已完成的可被截断)
  if grep -q "^$STATUS_PROGRESS$" "$d/readme.md" 2>/dev/null; then
    grep -q "^| *$id *|" "$AS_ROOT/iterations.md" \
      || warn "iterations.md 缺少进行中 $id"
  fi
done

# 进行中行必须有对应目录
prog_ids="$(awk -F'|' -v sec="$SEC_PROGRESS" '
  $0 == ("## " sec) { f=1; next }
  /^## / { f=0 }
  f && /^\| [0-9]/ { gsub(/ /, "", $2); print $2 }
' "$AS_ROOT/iterations.md")"
for id in $prog_ids; do
  [ -d "$AS_ROOT/iterations/iteration_$id" ] \
    || warn "iterations.md 进行中行 $id 没有对应目录(孤立行)"
done

echo
echo "== 完成: $issues 个问题, $fixed 处已自动修复 =="
if [ "$issues" -eq 0 ]; then
  echo "工作区状态一致 ✓"
else
  echo "提示: 索引/表问题由 scripts/ 操作产生异常时, 可对照文件系统手工修复对应行"
  exit 1
fi
