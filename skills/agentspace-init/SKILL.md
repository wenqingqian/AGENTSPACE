---
name: agentspace-init
description: Internal initialization flow for the explicit /agentspace-init command — creates the git-managed AGENTSPACE workspace (plans, iterations, utils, tests, notes) in the current project. Use ONLY via the /agentspace-init command. Never trigger automatically for project work, and never initialize a workspace on your own.
---

# AGENTSPACE Initialization Flow

Only proceed when the user explicitly executes `/agentspace-init`. Under no other circumstances (including "this project looks like it needs management") should you initialize.

## Steps

1. **Guard**: `./AGENTSPACE/` already exists → do not re-initialize. Run `AGENTSPACE/scripts/status.sh` to report current status, then stop.

2. **Run initialization script** (relative to this SKILL.md's directory):
   ```bash
   bash skills/agentspace-init/scripts/init-agentspace.sh
   ```
   The script: creates `AGENTSPACE/` and copies all templates and scripts → `git init` inside AGENTSPACE/ with first commit → creates root AGENTS.md from template if absent (if present, does not overwrite and notifies).

3. **When root AGENTS.md already exists**: do not overwrite. Ask the user whether to append the following guidance block (marked for future identification); only append with user consent:
   ```markdown
   <!-- AGENTSPACE -->
   ## AGENTSPACE
   本项目的实验与迭代状态由 AGENTSPACE/ 管理(独立 git 仓库): plan(任务计划)、iterations(代码变更迭代)、exp(实验记录)、utils(复用工具)、tests(环境与测试)、notes(知识)。
   - 何时读取 AGENTSPACE/AGENTS.md: 对话涉及本项目的实验、代码改动、项目迭代或状态查询/变更时 → 先读 AGENTSPACE/AGENTS.md 并按其规则工作
   - 何时不必读取: 与本项目无关的问答、无状态变化的纯查询, 且用户未明确要求使用 AGENTSPACE 时
   - 硬规则: 初始化只通过显式 /agentspace-init; AGENTSPACE 的索引/条目状态只能由 AGENTSPACE/scripts/ 下的脚本改写; 实验(exp)只在用户显式要求走 /agentspace-exp(命令或同名触发器 skill)或经确认提议后登记, 设计对齐走 agentspace-better-exp、报告走 agentspace-better-exp-report
   - 硬规则(commit 门): 在已登记关键代码仓库(.agentspace-repos)执行 git commit 前, 必须先运行 AGENTSPACE/scripts/commit-check.sh <仓库> "<message>" 并通过; 未登记仓库先登记后提交
   - 硬规则(代码卫生): 代码/注释/commit 文本卫生遵循 agentspace-code-clean 规则(默认被动层); 对既有代码/历史的清理与重建仅在用户显式要求时执行
   - 硬规则(基准计划): plan/base/ 下的基准计划(base plan)文件一经激活不可修改; 发现基准不可实现或有正确性错误必须显式告知用户, 方向变更由用户决定; 基准计划的创建与修改呈交用户审核 — 草稿写好后直接结束会话, 用户在文件上评论反馈
   <!-- /AGENTSPACE -->
   ```

4. **Workspace analysis (lightweight)**: familiarize with the workspace first, without deep reading:
   - Top-level directory overview (distinguish code repos / docs / data / config)
   - Find all git repos: `find . -maxdepth 2 -name .git` (exclude AGENTSPACE/), record paths and recent commits
   - Each repo's README / dependency files (package.json, requirements.txt, pyproject.toml, go.mod, Cargo.toml, etc.), roughly determine what each repo does
   - Present a brief inventory (repo + one-line description) for the next step

5. **Proactively ask three questions** (may use AskUserQuestion to collect all at once; for any unanswered, leave placeholder comments — never fabricate):
   1. **goal**: what the project mainly does — implement/maintain what feature, optimize what, achieve what effect
   2. **code runtime environment**: how to run code — container / conda / GPU / key dependencies and startup commands
   3. **key code repositories**: workspaces often contain multiple repos; ask the user to identify project-critical repos and existing relevant code files within them (these are the objects for deep analysis in the next step) — **including repos located OUTSIDE the project root** (the find above only sees the project tree; ask for external paths explicitly)

6. **Deep analysis of key code repositories** (only for repos/files confirmed in the previous step): read README, directory structure, entry files, core modules and dependencies; understand each key repo's responsibility, key paths, and entry points. Goal: accurately describe project background and key file inventory — no need to read code line by line.

7. **Persist to files (confirm content with user first)**:
   - Root AGENTS.md **new** (from template): fill in project background (goal), experiment environment (one-liner, see tests.md), key code repositories (path + responsibility + key entry files/directories)
   - Root AGENTS.md **already exists** (only write within confirmed append block; nothing outside the block): goal and key repos go into `AGENTSPACE/AGENTS.md` "项目简介" and "根仓库简介"
   - Always update: `AGENTSPACE/tests.md` experiment environment table (container / conda / GPU / key deps) and `AGENTSPACE/AGENTS.md` project/repo overview
   - **Register key repos** (each registration needs explicit user consent — never self-register): `bash AGENTSPACE/scripts/repos.sh --add <path>`. When the workspace nests inside a host repo, propose the host by default (user may decline); external repos register by absolute path. State lives in `AGENTSPACE/.agentspace-repos` — repos.sh only, never hand-edited. Note the detected form in the report: nested (host shields AGENTSPACE/ via .gitignore, step 8) vs separate (no shield needed)

8. **Host .gitignore**: ask the user whether to add `AGENTSPACE/` to the host repo's .gitignore (recommended, to prevent host git from tracking the nested repo); only modify with consent.

9. **Report**: what files were created, first commit, workspace analysis results (repo inventory), where the three questions were persisted; next step suggestion (start the first plan from the key code repositories' entry files).

## Boundaries

- Only initialize; do not perform any plan/iteration operations for the user
- Except for "appending AGENTSPACE guidance block" (with confirmation), do not modify existing files in the project root; newly created root AGENTS.md is filled directly based on the three questions
- Unanswered questions leave placeholder comments — never fabricate
- Git operations limited to inside AGENTSPACE/
