---
name: agentspace-init-light
description: Internal initialization flow for the explicit /agentspace-init-light command — creates a git-managed AGENTSPACE workspace containing ONLY the plan module (plan.md + plan/ with the base-plan lifecycle; no iterations/exp/utils/tests/notes/data/examples/register/handoff). Use ONLY via the /agentspace-init-light command. Never trigger automatically, and never initialize a workspace on your own.
---

# AGENTSPACE Initialization Flow (Light)

Only proceed when the user explicitly executes `/agentspace-init-light`. Under no other circumstances (including "this project looks like it needs management") should you initialize.

A light workspace manages task plans only: plan.md + plan/ (todo/done/base with the full base-plan lifecycle). The full scripts/ + templates/ set is deployed, so every plan-side script works; module-bound transition scripts (iterations/exp/register/handoff) refuse with an actionable message. Expansion to a full workspace later goes through `/agentspace-update` — never by hand-copying module files.

## Steps

1. **Guard**: `./AGENTSPACE/` already exists → do not initialize (light or full). Run `AGENTSPACE/scripts/status.sh` to report current status, then stop.

2. **Run initialization script** (relative to this SKILL.md's directory):
   ```bash
   bash skills/agentspace-init-light/scripts/init-agentspace-light.sh
   ```
   The script: creates `AGENTSPACE/` with ONLY the plan module (plan.md, plan/{index.md,todo,done,base}) plus the shared scripts/, templates/ and config files → light AGENTS.md with the `## agentspace edition: light` marker → `git init` inside AGENTSPACE/ with first commit → creates root AGENTS.md from the light template if absent (if present, does not overwrite and notifies) → runs doctor self-check.

3. **When root AGENTS.md already exists**: do not overwrite. Ask the user whether to append the following guidance block (marked for future identification); only append with user consent:
   ```markdown
   <!-- AGENTSPACE (light) -->
   ## AGENTSPACE
   本项目的任务计划由 AGENTSPACE/ 管理(独立 git 仓库, light 版): 仅 plan(任务计划) 模块 — 含 base plan(基准计划)。
   - 何时读取 AGENTSPACE/AGENTS.md: 对话涉及本项目的任务计划、项目迭代安排或状态查询/变更时 → 先读 AGENTSPACE/AGENTS.md 并按其规则工作
   - 何时不必读取: 与本项目无关的问答、无状态变化的纯查询, 且用户未明确要求使用 AGENTSPACE 时
   - 硬规则: 初始化只通过显式命令(/agentspace-init 或 /agentspace-init-light); plan.md 与 plan/index.md 只能由 AGENTSPACE/scripts/ 下的脚本改写; 当前为 light 工作区(仅 plan 模块), iterations/exp 等流程不可用, 需要时运行 /agentspace-update 扩展为完整工作区
   - 硬规则(commit 门): 在已登记关键代码仓库(AGENTSPACE/.agentspace-repos)执行 git commit 前, 必须先运行 AGENTSPACE/scripts/commit-check.sh <仓库> "<message>" 并通过; 未登记仓库先登记后提交
   - 硬规则(代码卫生): 代码/注释/commit 文本卫生遵循 agentspace-code-clean 规则(默认被动层)
   - 硬规则(基准计划): plan/base/ 下的基准计划(base plan)文件一经激活不可修改; 基准计划的创建与修改呈交用户审核 — 草稿写好后直接结束会话, 用户在文件上评论反馈
   <!-- /AGENTSPACE -->
   ```

4. **Workspace analysis (lightweight)**: familiarize with the workspace first, without deep reading:
   - Top-level directory overview (distinguish code repos / docs / data / config)
   - Find all git repos: `find . -maxdepth 2 -name .git` (exclude AGENTSPACE/), record paths and recent commits
   - Each repo's README / dependency files (package.json, requirements.txt, pyproject.toml, go.mod, Cargo.toml, etc.), roughly determine what each repo does
   - Present a brief inventory (repo + one-line description) for the next step

5. **Proactively ask two questions** (may use AskUserQuestion to collect both at once; for any unanswered, leave placeholder comments — never fabricate):
   1. **goal**: what the project mainly does — implement/maintain what feature, optimize what, achieve what effect
   2. **key code repositories**: workspaces often contain multiple repos; ask the user to identify project-critical repos and existing relevant code files within them — **including repos located OUTSIDE the project root** (the find above only sees the project tree; ask for external paths explicitly)
   (No runtime-environment question: a light workspace has no tests.md — if the user volunteers environment info, record it in the 项目简介/项目背景 one-liner.)

6. **Deep analysis of key code repositories** (only for repos/files confirmed in the previous step): read README, directory structure, entry files, core modules and dependencies; understand each key repo's responsibility, key paths, and entry points. Goal: accurately describe project background and key file inventory — no need to read code line by line.

7. **Persist to files (confirm content with user first)**:
   - Root AGENTS.md **new** (from the light template): fill in 项目背景 (goal) and 关键代码仓库 (path + responsibility + key entry files/directories)
   - Root AGENTS.md **already exists** (only write within the confirmed append block; nothing outside the block): goal and key repos go into `AGENTSPACE/AGENTS.md` "项目简介" and "根仓库简介"
   - Always update: `AGENTSPACE/AGENTS.md` project/repo overview
   - **Register key repos** (each registration needs explicit user consent — never self-register): `bash AGENTSPACE/scripts/repos.sh --add <path>`. When the workspace nests inside a host repo, propose the host by default (user may decline); external repos register by absolute path. State lives in `AGENTSPACE/.agentspace-repos` — repos.sh only, never hand-edited. Note the detected form in the report: nested (host shields AGENTSPACE/ via .gitignore, step 8) vs separate (no shield needed)

8. **Host .gitignore**: ask the user whether to add `AGENTSPACE/` to the host repo's .gitignore (recommended, to prevent host git from tracking the nested repo); only modify with consent.

9. **Report**: what files were created, first commit, workspace analysis results (repo inventory), where the answers were persisted; next steps — start the first plan from the key repos' entry files (`AGENTSPACE/scripts/new-plan.sh "<title>"`), and note explicitly: iterations/exp/utils/tests/notes are NOT initialized; when the project needs them, run `/agentspace-update` (expansion preserves all plan data and user content).

## Boundaries

- Only initialize; do not perform any plan operations for the user
- Except for "appending the AGENTSPACE (light) guidance block" (with confirmation), do not modify existing files in the project root; newly created root AGENTS.md is filled directly based on the two questions
- Unanswered questions leave placeholder comments — never fabricate
- Never hand-create module files (iterations.md, exp.md, ...) to "temporarily" use a module — expansion goes through /agentspace-update only
- Git operations limited to inside AGENTSPACE/
