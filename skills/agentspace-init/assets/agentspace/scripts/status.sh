#!/usr/bin/env bash
# 只读状态摘要: 下一索引 / todo plans / 进行中 iterations / latest / 最近提交。
# 用法: status.sh
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

echo "# AGENTSPACE 状态摘要"
echo
echo "下一索引: plan $(as_next_plan_id) / iteration $(as_next_iteration_id)"
echo

echo "## Todo plans"
shopt -s nullglob
todo_files=( "$AS_ROOT"/plan/todo/[0-9]*.md )
if ((${#todo_files[@]})); then
  for f in "${todo_files[@]}"; do echo "- $(basename "$f" .md)"; done
else
  echo "(空)"
fi
echo

echo "## 进行中 iterations"
rows="$(awk -F'|' -v sec="$SEC_PROGRESS" '
  $0 == ("## " sec) { f=1; next }
  /^## / { f=0 }
  f && /^\| [0-9]/ {
    gsub(/^ +| +$/, "", $2); gsub(/^ +| +$/, "", $3); gsub(/^ +| +$/, "", $4)
    print "- " $2 " (" $3 ") " $4
  }
' "$AS_ROOT/iterations.md")"
[ -n "$rows" ] && echo "$rows" || echo "(空)"
echo

echo "## latest"
if [ -L "$AS_ROOT/iterations/latest" ]; then
  echo "latest -> $(readlink "$AS_ROOT/iterations/latest")"
else
  echo "(未设置)"
fi
echo

	# Optional 3: 用 git rev-parse 检测(兼容 git worktree 场景, .git 可能是文件而非目录)
	if git -C "$AS_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	  echo "## 最近提交"
	  git -C "$AS_ROOT" log --oneline -3 2>/dev/null || echo "(无提交)"
	fi
