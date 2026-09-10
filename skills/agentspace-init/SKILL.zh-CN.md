---
name: agentspace-init
description: /agentspace-init 命令的内部初始化流程——在当前项目中创建 git 管理的 AGENTSPACE 工作区(plan、iterations、utils、tests、notes)。仅通过 /agentspace-init 命令使用。绝不为项目工作自动触发, 也绝不自行初始化工作区。
---

# AGENTSPACE 初始化流程

只在用户显式执行 `/agentspace-init` 时进行。任何其他情况(包括"这个项目看起来需要管理")都不得初始化。

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
   本项目的实验与迭代状态由 AGENTSPACE/ 管理(独立 git 仓库): plan(任务计划)、iterations(代码变更迭代)、exp(实验记录)、utils(复用工具)、tests(环境与测试)、notes(知识)。
   - 何时读取 AGENTSPACE/AGENTS.md: 对话涉及本项目的实验、代码改动、项目迭代或状态查询/变更时 → 先读 AGENTSPACE/AGENTS.md 并按其规则工作
   - 何时不必读取: 与本项目无关的问答、无状态变化的纯查询, 且用户未明确要求使用 AGENTSPACE 时
   - 硬规则: 初始化只通过显式 /agentspace-init; AGENTSPACE 的索引/条目状态只能由 AGENTSPACE/scripts/ 下的脚本改写; 实验(exp)只在用户显式要求走 /agentspace-exp(命令或同名触发器 skill)或经确认提议后登记, 设计对齐走 agentspace-better-exp、报告走 agentspace-better-exp-report
   - 硬规则(commit 门): 在已登记关键代码仓库(.agentspace-repos)执行 git commit 前, 必须先运行 AGENTSPACE/scripts/commit-check.sh <仓库> "<message>" 并通过; 未登记仓库先登记后提交
   - 硬规则(代码卫生): 代码/注释/commit 文本卫生遵循 agentspace-code-clean 规则(默认被动层); 对既有代码/历史的清理与重建仅在用户显式要求时执行
   - 硬规则(基准计划): plan/base/ 下的基准计划(base plan)文件一经激活不可修改; 发现基准不可实现或有正确性错误必须显式告知用户, 方向变更由用户决定; 基准计划的创建与修改呈交用户审核 — 草稿写好后直接结束会话, 用户在文件上评论反馈
   <!-- /AGENTSPACE -->
   ```

4. **工作区分析(简单)**: 先熟悉整个工作区, 不深入:
   - 顶层目录一览(区分代码仓库 / 文档 / 数据 / 配置)
   - 找出全部 git 仓库: `find . -maxdepth 2 -name .git`(排除 AGENTSPACE/), 记录路径与最近提交
   - 各仓库的 README / 依赖文件(package.json、requirements.txt、pyproject.toml、go.mod、Cargo.toml 等), 大致判断每个仓库干什么
   - 向用户呈现简短清单(仓库 + 一句话说明), 供下一步确认

5. **主动询问三个信息**(可用 AskUserQuestion 一次收集; 用户暂无答复的项保留占位注释, 绝不编造):
   1. **goal**: 项目主要干什么 —— 实现/维护什么功能、优化什么、达到什么效果
   2. **代码运行环境**: 用什么跑代码 —— 容器 / conda / GPU / 关键依赖与启动命令
   3. **关键代码仓库**: 工作区常有多个代码仓库, 请用户指明与项目强相关的关键仓库, 以及其中已有的相关代码文件(这些是下一步深入分析的对象) — **包括位于项目根目录之外的仓库**(上面的 find 只能看到项目树内, 树外仓库必须显式问路径)

6. **深入分析关键代码仓库**(只针对上一步确认的仓库与文件): 读 README、目录结构、入口文件、核心模块与依赖, 弄清各关键仓库的职责、关键路径与入口; 目标是能准确写清项目背景与关键文件清单, 不需要逐行读代码。

7. **落盘(内容先与用户确认)**:
   - 根 AGENTS.md **新建**(来自模板): 填入 项目背景(goal)、实验环境(环境一句话, 详见 tests.md)、关键代码仓库(路径 + 职责 + 关键入口文件/目录)
   - 根 AGENTS.md **已存在**(只写经确认的追加区块, 区块之外不动): goal 与关键仓库写入 `AGENTSPACE/AGENTS.md` 的"项目简介""根仓库简介"
   - 一律更新: `AGENTSPACE/tests.md` 实验环境表(容器 / conda / GPU / 关键依赖)与 `AGENTSPACE/AGENTS.md` 项目简介 / 根仓库简介
   - **登记关键仓库**(每次登记都必须用户显式同意 — 绝不自行登记): `bash AGENTSPACE/scripts/repos.sh --add <path>`。工作区内嵌宿主仓库时默认提议登记宿主(用户可拒绝); 树外仓库用绝对路径登记。登记状态存于 `AGENTSPACE/.agentspace-repos` — 只能 repos.sh 改写, 禁止手工编辑。汇报时注明探测到的形态: 内嵌(宿主需 .gitignore 豁免 AGENTSPACE/, 见第 8 步)或分开存放(无需豁免)

8. **宿主 .gitignore**: 询问用户是否将 `AGENTSPACE/` 加入宿主仓库 .gitignore(推荐, 避免宿主 git 跟踪嵌套仓库); 同意才修改。

9. **汇报**: 创建了哪些文件、首个 commit、工作区分析结论(仓库清单)、三问落盘位置; 下一步建议(新建首个 plan 时从关键代码仓库的入口文件出发)。

## 边界

- 只初始化; 不替用户做任何 plan/iteration 操作
- 除"追加 AGENTSPACE 引导区块"(经确认)外, 不修改项目根已有文件; 新建的根 AGENTS.md 直接按三问结果填写
- 三问中用户未答复的项留占位注释, 不编造
- git 操作仅限 AGENTSPACE/ 内部
