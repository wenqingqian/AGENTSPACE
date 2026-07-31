---
name: agentspace-init
description: Internal initialization flow for the explicit /init-agentspace command — creates the git-managed AGENTSPACE workspace (plans, iterations, utils, tests, notes) in the current project. Use ONLY via the /init-agentspace command. Never trigger automatically for project work, and never initialize a workspace on your own.
---

# AGENTSPACE 初始化流程

只在用户显式执行 `/init-agentspace` 时进行。任何其他情况(包括"这个项目看起来需要管理")都不得初始化。

## 步骤

1. **守卫**: `./AGENTSPACE/` 已存在 → 不重复初始化。运行 `AGENTSPACE/scripts/status.sh` 向用户汇报现状后结束。

2. **运行初始化脚本**(相对本 SKILL.md 所在目录):
   ```bash
   bash skills/agentspace-init/scripts/init-agentspace.sh
   ```
   脚本会: 创建 `AGENTSPACE/` 并拷入全部模板与脚本 → 在 AGENTSPACE/ 内 `git init` 并创建首个 commit → 项目根无 AGENTS.md 时从模板创建(已存在则不覆盖并提示)。

3. **根 AGENTS.md 已存在时**: 不覆盖。询问用户是否追加以下引导区块(带标记, 便于将来识别); 用户同意才追加:
   ```markdown
   <!-- AGENTSPACE -->
   ## AGENTSPACE
   本项目的实验与迭代状态由 AGENTSPACE/ 管理(独立 git 仓库): plan(任务计划)、iterations(实验轮次)、utils(复用工具)、tests(环境与测试)、notes(知识)。
   - 何时读取 AGENTSPACE/AGENTS.md: 对话涉及本项目的实验、代码改动、项目迭代或状态查询/变更时 → 先读 AGENTSPACE/AGENTS.md 并按其规则工作
   - 何时不必读取: 与本项目无关的问答、无状态变化的纯查询, 且用户未明确要求使用 AGENTSPACE 时
   - 硬规则: 初始化只通过显式 /init-agentspace; AGENTSPACE 的索引/条目状态只能由 AGENTSPACE/scripts/ 下的脚本改写
   <!-- /AGENTSPACE -->
   ```

4. **起草项目信息**: 快速扫描项目(README / 依赖文件 / 目录结构), 为根 AGENTS.md 的"项目背景""实验环境"两节起草内容, 请用户确认后填入; 用户暂无答复则保留占位注释, 不编造。

5. **宿主 .gitignore**: 询问用户是否将 `AGENTSPACE/` 加入宿主仓库 .gitignore(推荐, 避免宿主 git 跟踪嵌套仓库); 同意才修改。

6. **汇报**: 创建了哪些文件、首个 commit、下一步建议(填写 AGENTSPACE/AGENTS.md 的项目简介与根仓库简介、tests.md 的环境表)。

## 边界

- 只初始化; 不替用户做任何 plan/iteration 操作
- 除"追加 AGENTSPACE 引导区块"(经确认)外, 不修改项目根已有文件
- git 操作仅限 AGENTSPACE/ 内部
