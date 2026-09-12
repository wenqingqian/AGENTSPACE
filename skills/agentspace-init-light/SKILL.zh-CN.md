---
name: agentspace-init-light
description: /agentspace-init-light 命令的内部初始化流程 — 创建仅含 plan 模块的 git 管理 AGENTSPACE 轻量工作区(plan.md + plan/ 含基准计划生命周期; 不含 iterations/exp/utils/tests/notes/data/examples/register/handoff)。仅经显式 /agentspace-init-light 命令使用, 绝不自动触发, 也绝不自行初始化工作区。
---

# AGENTSPACE 初始化流程(Light)

仅当用户显式执行 `/agentspace-init-light` 时才继续。任何其他情形(包括"这个项目看起来需要管理")都不得初始化。

light 工作区只管理任务计划: plan.md + plan/(todo/done/base 含完整 base plan 生命周期)。scripts/ 与 templates/ 整套部署, plan 侧脚本全部可用; 模块流转脚本(iterations/exp/register/handoff)会拒绝并给出可操作提示。之后扩展为完整工作区走 `/agentspace-update` — 绝不手工复制模块文件。

## 步骤

1. **守卫**: `./AGENTSPACE/` 已存在 → 不初始化(light 或 full 均不)。运行 `AGENTSPACE/scripts/status.sh` 报告当前状态, 然后停止。

2. **运行初始化脚本**(相对本 SKILL.md 所在目录):
   ```bash
   bash skills/agentspace-init-light/scripts/init-agentspace-light.sh
   ```
   脚本: 创建仅含 plan 模块的 `AGENTSPACE/`(plan.md、plan/{index.md,todo,done,base})加共享的 scripts/、templates/ 与配置文件 → light 版 AGENTS.md(带 `## agentspace edition: light` 标记) → AGENTSPACE/ 内 `git init` 并首次提交 → 根 AGENTS.md 不存在时从 light 模板创建(已存在则不覆盖并提示) → 运行 doctor 自检。

3. **根 AGENTS.md 已存在时**: 不覆盖。询问用户是否追加以下指引块(带标识便于日后识别); 仅经用户同意后追加:
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

4. **工作区分析(轻量)**: 先熟悉工作区, 不深读:
   - 顶层目录总览(区分代码仓库 / 文档 / 数据 / 配置)
   - 找出全部 git 仓库: `find . -maxdepth 2 -name .git`(排除 AGENTSPACE/), 记录路径与近期提交
   - 各仓库的 README / 依赖文件(package.json、requirements.txt、pyproject.toml、go.mod、Cargo.toml 等), 大致判断各自职责
   - 给出简要清单(仓库 + 一句话职责), 供下一步使用

5. **主动问两个问题**(可用 AskUserQuestion 一次收集; 未答的留占位注释 — 绝不编造):
   1. **goal**: 项目主要做什么 — 实现/维护什么功能, 优化什么, 达到什么效果
   2. **key code repositories**: 工作区常有多个仓库; 请用户指出项目关键仓库与其中的相关代码文件 — **包括位于项目根之外的仓库**(上面的 find 只看项目树内; 树外路径要显式询问)
   (不问运行环境: light 工作区没有 tests.md — 用户主动提及环境信息时, 记入 项目简介/项目背景 的一句话里。)

6. **深读关键代码仓库**(仅限上一步确认的仓库/文件): 读 README、目录结构、入口文件、核心模块与依赖; 理解每个关键仓库的职责、关键路径与入口。目标: 准确描述项目背景与关键文件清单 — 无需逐行读代码。

7. **落盘到文件(先与用户确认内容)**:
   - 根 AGENTS.md **新建**(light 模板): 填写 项目背景(goal) 与 关键代码仓库(路径 + 职责 + 关键入口文件/目录)
   - 根 AGENTS.md **已存在**(只写经确认的追加块内; 块外不动): goal 与关键仓库写入 `AGENTSPACE/AGENTS.md` 的 "项目简介" 与 "根仓库简介"
   - 总是更新: `AGENTSPACE/AGENTS.md` 的项目/仓库概览
   - **登记关键仓库**(每次登记需用户显式同意 — 绝不自行登记): `bash AGENTSPACE/scripts/repos.sh --add <path>`。工作区内嵌于宿主仓库时默认提议宿主(用户可拒绝); 树外仓库按绝对路径登记。状态存于 `AGENTSPACE/.agentspace-repos` — 只能经 repos.sh, 绝不手工编辑。报告里注明探测到的形态: 内嵌(宿主经 .gitignore 豁免 AGENTSPACE/, 步骤 8)或分开(无需盾牌)

8. **宿主 .gitignore**: 询问用户是否把 `AGENTSPACE/` 加进宿主仓库的 .gitignore(推荐, 防止宿主 git 跟踪内嵌仓库); 仅经同意后修改。

9. **报告**: 创建了哪些文件、首次提交、工作区分析结果(仓库清单)、答案落在了哪里; 下一步 — 从关键仓库的入口文件出发创建第一个 plan(`AGENTSPACE/scripts/new-plan.sh "<标题>"`), 并明确说明: iterations/exp/utils/tests/notes 未初始化; 项目需要时运行 `/agentspace-update`(扩展保留全部 plan 数据与用户内容)。

## 边界

- 只初始化; 不替用户执行任何 plan 操作
- 除"追加 AGENTSPACE (light) 指引块"(经确认)外, 不修改项目根的既有文件; 新建的根 AGENTS.md 依据两个问题直接填写
- 未答的问题留占位注释 — 绝不编造
- 绝不手工创建模块文件(iterations.md、exp.md 等)来"临时"使用某模块 — 扩展只走 /agentspace-update
- git 操作仅限 AGENTSPACE/ 内
