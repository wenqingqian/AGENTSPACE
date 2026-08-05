#!/usr/bin/env bash
# Read-only status summary: next indexes / 推进总览 / todo plans / in-progress iterations / recent closes / latest / next step / recent commits.
# Usage: status.sh
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

echo "# AGENTSPACE Status Summary"
echo
echo "Next index: plan $(as_next_plan_id) / iteration $(as_next_iteration_id)"
echo

echo "## 推进总览"
# per-plan iteration counts from the full index (closed vs total)
overview="$(awk -F'|' '
  /^\| [0-9]/ {
    plan=$3; gsub(/ /, "", plan)
    cnt[plan]++; gsub(/^ +| +$/, "", $5)
    if ($5 == "已完成") done[plan]++
  }
  END { for (p in cnt) printf "  %s: %d 迭代 (%d 已关)\n", p, cnt[p], done[p]+0 }
' "$AS_ROOT/iterations/index.md" | sort)"
[ -n "$overview" ] && echo "$overview" || echo "  (无迭代)"
echo

echo "## Handoffs (待消费)"
# 会话续接入口; 过时判龄与 doctor [11] 一致(STALE_DAYS 来自 lib.sh, find -mtime +$((STALE_DAYS-1)) = 7 天以上, 无日期算术)
if [ -d "$AS_ROOT/handoff" ] && [ -f "$AS_ROOT/handoff/index.md" ]; then
  rows="$(awk -v sec="## $SEC_HANDOFF" '
    $0 ~ ("^" sec "[[:space:]]*$") { in_sec=1; next }
    /^## / { in_sec=0 }
    in_sec && /^\| / && !/^\| *name *\|/ && !/^\|[ :|-]+\|$/ { print }
  ' "$AS_ROOT/handoff/index.md" 2>/dev/null || true)"
  found=0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    # 字段按形状定位(首列 name / 末尾日期), 容忍 description 中的 \| (同 doctor [10])
    tmp="${line#| }"; name="${tmp%% | *}"; rest="${tmp#* | }"
    date="${rest##* | }"; date="${date% |}"
    nodate="${rest% | *}"; loc="${nodate##* | }"; desc="${nodate%% | *}"
    if [ -z "$name" ] || [ -z "$loc" ] || [[ "$name" == *'|'* ]] || [[ "$loc" != handoff_*.md ]] || [[ "$loc" == */* ]] || [[ "$date" != [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] ]]; then
      echo "  (行格式异常: $line)"
      found=1
      continue
    fi
    [ -n "$desc" ] || desc="—"
    if [ ! -e "$AS_ROOT/handoff/$loc" ]; then
      echo "  - $name | $desc | $date (文件缺失 — 见 doctor [10])"
    elif grep -Fq '> 状态: kept(--keep,' "$AS_ROOT/handoff/$loc" 2>/dev/null; then
      echo "  - $name | $desc | $date (--keep 保留)"
    elif [ -n "$(find "$AS_ROOT/handoff/$loc" -mtime "+$((STALE_DAYS - 1))" 2>/dev/null)" ]; then
      echo "  - $name | $desc | $date ⚠ 过时(>$STALE_DAYS 天未消费 — 见 doctor [11])"
    else
      echo "  - $name | $desc | $date"
    fi
    found=1
  done <<< "$rows"
  [ "$found" -eq 1 ] || echo "  (空)"
else
  echo "  (无 handoff 模块)"
fi
echo

echo "## Todo plans"
shopt -s nullglob
todo_files=( "$AS_ROOT"/plan/todo/[0-9]*.md )
if ((${#todo_files[@]})); then
  for f in "${todo_files[@]}"; do echo "- $(basename "$f" .md)"; done
else
  echo "(empty)"
fi
echo

echo "## In-progress iterations"
rows="$(awk -F'|' -v sec="$SEC_PROGRESS" '
  $0 == ("## " sec) { f=1; next }
  /^## / { f=0 }
  f && /^\| [0-9]/ {
    gsub(/^ +| +$/, "", $2); gsub(/^ +| +$/, "", $3); gsub(/^ +| +$/, "", $4)
    print "- " $2 " (" $3 ") " $4
  }
' "$AS_ROOT/iterations.md")"
[ -n "$rows" ] && echo "$rows" || echo "(empty)"
echo

echo "## 最近关闭"
recent="$(awk -F'|' -v sec="$SEC_RECENT" '
  $0 == ("## " sec) { f=1; next }
  /^## / { f=0 }
  f && /^\| [0-9]/ {
    gsub(/^ +| +$/, "", $2); gsub(/^ +| +$/, "", $4); gsub(/^ +| +$/, "", $5)
    print "- " $2 " " $4 " (" $5 ")"
  }
' "$AS_ROOT/iterations.md" | head -3)"
[ -n "$recent" ] && echo "$recent" || echo "  (无)"
echo

echo "## Latest"
if [ -L "$AS_ROOT/iterations/latest" ]; then
  echo "latest -> $(readlink "$AS_ROOT/iterations/latest")"
else
  echo "(not set)"
fi
echo

echo "## 下一步"
if [ -L "$AS_ROOT/iterations/latest" ]; then
  latest_dir="$(readlink "$AS_ROOT/iterations/latest")"
  # First non-empty, non-comment, non-heading line after the heading — covers
  # the template's blank line and the multi-line `<!-- 会话续接块 -->` placeholder
  # (skipped as a whole, so an unfilled block keeps the fallback clean), and
  # tolerates a missing readme/heading (2>/dev/null + || true → fallback).
  next="$(awk '
    /^## 当前状态 · 下一步/ { f=1; next }
    f && /^## / { exit }
    f && /^<!--/ { if ($0 !~ /-->/) c=1; next }
    f && c { if ($0 ~ /-->/) c=0; next }
    f && NF { print; exit }
  ' "$AS_ROOT/iterations/$latest_dir/readme.md" 2>/dev/null || true)"
  [ -n "$next" ] && echo "  $latest_dir: $next" || echo "  (见 iterations/latest/readme.md)"
else
  echo "  (无进行中迭代)"
fi
echo

# Use git rev-parse (works with git worktree where .git may be a file)
if git -C "$AS_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "## Recent commits"
  git -C "$AS_ROOT" log --oneline -3 2>/dev/null || echo "(no commits)"
fi
