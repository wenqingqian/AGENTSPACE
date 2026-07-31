#!/usr/bin/env bash
# /init-agentspace 的初始化脚本: 在当前项目根目录创建 git 管理的 AGENTSPACE 工作区。
# 幂等: AGENTSPACE/ 已存在时只输出状态并退出。
# 用法: 在项目根目录执行 init-agentspace.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ASSETS_DIR="$(cd "$SCRIPT_DIR/../assets" && pwd)"
PROJECT_ROOT="$(pwd)"
TARGET="$PROJECT_ROOT/AGENTSPACE"

# ---- 幂等守卫 ----
if [ -d "$TARGET" ]; then
  echo "AGENTSPACE 已存在: $TARGET (不重复初始化)"
  if [ -x "$TARGET/scripts/status.sh" ]; then
    echo
    "$TARGET/scripts/status.sh"
  fi
  exit 0
fi

# ---- 创建目录并拷入工作区内容 ----
mkdir -p "$TARGET"
cp -R "$ASSETS_DIR/agentspace/." "$TARGET/"
mkdir -p "$TARGET/plan/todo" "$TARGET/plan/done" "$TARGET/iterations" \
         "$TARGET/utils" "$TARGET/tests" "$TARGET/notes"
# git 需要文件才能跟踪空目录
touch "$TARGET/plan/todo/.gitkeep" "$TARGET/plan/done/.gitkeep" \
      "$TARGET/utils/.gitkeep" "$TARGET/tests/.gitkeep" "$TARGET/notes/.gitkeep"
chmod +x "$TARGET"/scripts/*.sh

# ---- 项目根 AGENTS.md (已存在则不覆盖) ----
if [ -f "$PROJECT_ROOT/AGENTS.md" ]; then
  echo "NOTICE: 项目根 AGENTS.md 已存在, 未覆盖。"
  echo "        建议追加 AGENTSPACE 引导区块(由 agent 与你确认后处理)。"
else
  escaped_name="$(printf '%s' "$(basename "$PROJECT_ROOT")" | sed 's/[&\\/]/\\&/g')"
  sed "s/{{PROJECT_NAME}}/$escaped_name/g" \
    "$ASSETS_DIR/root-AGENTS.md" > "$PROJECT_ROOT/AGENTS.md"
  echo "created: ./AGENTS.md (项目根引导文件)"
fi

# ---- AGENTSPACE 独立 git 仓库 + 首个 commit ----
# Critical 1: 直接检查 .git 目录而非 rev-parse (后者会沿父目录上溯,宿主是 git 仓库时误判)
if [ ! -e "$TARGET/.git" ]; then
  git -C "$TARGET" init -b main >/dev/null 2>&1 || git -C "$TARGET" init >/dev/null
fi
# 用 -- . 将暂存范围限制在工作区内,防止宿主未提交改动被意外卷入
git -C "$TARGET" add -A -- .
if ! git -C "$TARGET" commit -m "chore: initialize AGENTSPACE workspace" >/dev/null 2>&1; then
  # 未配置 git 身份时给工作区仓库一个局部身份
  git -C "$TARGET" config user.name "AGENTSPACE Bot"
  git -C "$TARGET" config user.email "agentspace@localhost"
  git -C "$TARGET" commit -m "chore: initialize AGENTSPACE workspace" >/dev/null
fi

echo
echo "== AGENTSPACE 初始化完成 =="
echo "位置: $TARGET"
echo "首个 commit: $(git -C "$TARGET" log --oneline -1)"
echo
echo "下一步建议:"
echo "  1. 填写 AGENTSPACE/AGENTS.md 的\"项目简介\"\"根仓库简介\""
echo "  2. 填写 AGENTSPACE/tests.md 的实验环境表(容器/conda/GPU)"
echo "  3. 建议将 AGENTSPACE/ 加入宿主仓库 .gitignore(由 agent 与你确认)"
