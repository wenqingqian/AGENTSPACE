---
name: agentspace
description: 在已有 AGENTSPACE 工作区的项目中工作(plan、iterations、utils、tests、notes)。仅在两个条件同时满足时激活: (1) 项目根存在 AGENTSPACE/ 目录, 且 (2) 当前会话涉及本项目的实验、代码改动、项目迭代或状态追踪。项目无关的闲聊或无状态变化的问答不激活。绝不创建或初始化 AGENTSPACE —— 初始化仅通过显式 /agentspace-init 命令。
---

# AGENTSPACE 日常管理

## 0. 启动守卫

按顺序判断, 任一不满足则静默退出(不提及本 skill, 按普通请求处理):
1. 项目根存在 `AGENTSPACE/` 目录
2. 当前会话涉及**本项目**的实验 / 代码改动 / 项目迭代 / 状态变更 —— 项目无关的会话(问答、闲聊、无状态变化的纯查询)不启动

绝不允许: 自动初始化 AGENTSPACE(只有显式 `/agentspace-init` 可以)。

## 1. 上下文自保(模型判断, 无 hook)

工作时确保以下三个文件的内容在当前上下文中; 不确定(如 compact 之后)或**做任何状态变更前**, 先重新读取:
1. `AGENTSPACE/AGENTS.md` — 结构、模块规则与纪律
2. `AGENTSPACE/tests.md` — 实验环境
3. `AGENTSPACE/iterations.md` — 迭代状态

恢复序列(会话开始/状态不确定时): `AGENTS.md` → `tests.md` → `iterations.md` → `plan.md`(任务相关时) → `iterations/latest/readme.md` 的"当前状态 · 下一步"。

## 2. 工作流

**规则分级**: `[MUST]` = 违反会造成损坏或不可逆, 必须执行; `[SHOULD]` = 最佳实践; `[MAY]` = 可选。

### 新任务 → 建 plan(一个任务可拆成多个 plan)

**Plan 创建规则 (MUST)**:
- **文件名必须英文** — plan 标题会成为文件名, CJK 字符会导致编码问题。plan 文档内容不限语言。
- **必须向用户确认** — 未经用户明确同意不得创建 plan。先描述 plan 涵盖的内容, 确认后再创建。
- **plan 是特定、有界的事件** — 简单的确认、验证、搜索、读文件、回答问题等不要建 plan。plan 用于: 实现功能、修复 bug、重构代码、运行实验、做结构性变更。

```bash
AGENTSPACE/scripts/new-plan.sh "English plan title"   # 输出 plan:NNNN
```
然后撰写生成的 `plan/todo/NNNN-*.md`: 目标 / 背景 / 方案步骤。里程碑提交(见 §4)。

### 开始一轮迭代 → 建 iteration(plan-id 必填: 一个 iteration 必属且仅属一个 plan)

**iteration = 实现 plan 过程中的一次代码/仓库状态变更**(递进关系, 一轮接一轮)。常伴随实验验证, 所以有 readme + data/。

**Iteration 创建规则 (MUST)**:
- **只为 plan 创建** — iteration 服务于实现某个 plan, 没有 plan-id 绝不创建
- **必须向用户确认** — 未经用户同意不得创建 iteration
- **只对有意义的代码变更创建** — 简单改动、快速修复、文件移动等不建 iteration。iteration 用于: 实现功能的步骤、重构、伴随实验验证的显著变更
- **与 commit 无一一对应** — 一个 plan 常含 1+ 个 commit, 一个 commit 可能含多个 iteration, 部分 commit 是用户自行处理的。plan / iteration / commit 之间**没有必然对应关系**

```bash
AGENTSPACE/scripts/new-iteration.sh <plan-id> "本轮内容"   # 输出 iteration_NNNN
```
- 更新 readme: 目标 / 代码变更摘要 / 环境(宿主起始/结束 commit sha 由脚本自动记录)
- **涉及文件**: 在"代码变更 (diff)"节列出本轮涉及的文件路径(`- 文件: path/to/file.py`, 每行一个)——日后可用 grep 定位"哪个 plan 动过哪个文件" 
- **代码 diff**: 变更涉及代码时, 保存宿主仓库 diff 到 data/: `git -C <宿主> diff <起始>..<结束> > data/diff-<起始>..<结束>.patch`; 在 readme"代码变更 (diff)"节登记
- **产物放置**: 全部实验产物进 `iteration_NNNN/data/`(已 gitignore) — 三种收集策略见 AGENTS.md(iterations 模块)
- 工作过程中及时更新 readme 的"当前状态 · 下一步"和"日志"(append-only)

### 关闭迭代
结果写入 readme 的"结果"节后:
```bash
AGENTSPACE/scripts/close-iteration.sh <id> "结果一句话"
```
里程碑提交。
结果含可迁移教训时 (SHOULD — 知识提炼), 写一条笔记(templates/note.md, 来源 `iteration_NNNN`), 在"详情"中回链本迭代的 readme。

### 完成计划
**运行前(脚本闸门要求)**: 先填写 plan 文档"结果"节(一句话结论 + 关键证据) — 占位符未替换时脚本会拒绝。

```bash
AGENTSPACE/scripts/complete-plan.sh <id> <done|failed|abandoned> "结果一句话"
```
**完成后 (SHOULD — 知识提炼)**:
1. 回顾本 plan 的 iterations — 读它们的"结果"节和"代码变更 (diff)"产物
2. 把可迁移教训沉淀进 notes(模板 `templates/note.md`, 来源 `plan:NNNN`); 打主题标签为建议(可选)
3. 里程碑提交

### 历史检索(结果定位 / 哪个 plan 动过文件 Y)
- 小范围: `grep -rn <关键词> plan iterations notes`(排除 `data/`)
- 关键词可能对不上(同义词/描述差异)或范围大: 派 subagent(Explore)读 readme 的"代码变更 (diff)"/"结果"节归纳
- 检索结论若可复用 → 记入 notes(带来源)

### 工具 / 环境 / 知识 / 扩展模块
- 需要辅助工具(做图 / 机器状态 / 运行状态 / 日志分析)先查 `utils.md`, 复用而非重写; 新工具写入 `utils/` 并在 `utils.md` 登记
- 公用数据(训练集/模型权重/软连接)放 `data/` 并在 `data.md` 登记; data/ 全部 gitignore
- 可复用实验配置(YAML/JSON)放 `examples/` 并在 `examples.md` 登记; tests/ 放脚本, examples/ 放配置
- 环境变化(容器 / conda / 机器 / 依赖)当天更新 `tests.md`; 测试脚本放 `tests/` 并登记
- 踩坑 / 可迁移结论 → `notes/`(模板 `templates/note.md`), **必须带来源**(plan:NNNN / iteration_NNNN)
- 新模块(非内置模块): **先与用户确认** → `AGENTSPACE/scripts/register-module.sh <name> "用途"`

## 3. 纪律

- **[MUST] 登记仓库 commit 门** — 在登记于 `AGENTSPACE/.agentspace-repos` 的仓库执行 `git commit` 前, 必须先运行 `AGENTSPACE/scripts/commit-check.sh <仓库> "<message>"` 且通过才可提交; 未登记仓库一律不 commit(先提议登记, 用户确认后再提交)。完整规则见 agentspace-code-clean skill 与 AGENTS.md "关键代码仓库"节
- `plan.md` / `iterations.md` / `plan/index.md` / `iterations/index.md` **只能由 scripts/ 改写** — 一律调脚本, 不手工编辑表格
- 内容文档(plan 文档 / iteration readme / notes / utils / tests)由你直接撰写, 使用 `templates/` 模板
- 相互引用一律用 id: `plan:NNNN` / `iteration_NNNN`; 不用路径, 不用 latest
- `data/` 不入 git(已 gitignore), 产物全量本地保存
- **[MUST] 收尾协议** — 结束任何项目工作前, 依次: ① 更新进行中 iteration readme 的"当前状态 · 下一步"(下次会话续接入口 — 用实际内容替换模板引导注释) ② 运行 `AGENTSPACE/scripts/doctor.sh`(硬错误必须解决; 告警必须向用户报告) ③ 里程碑提交(§4)
- **[MUST] 脚本报错时**(如"Section not found"): 禁止自行手工编辑表格。先跑 `doctor.sh` 定位, 再与用户确认修复方案。**经用户明确确认的一次性手工修复是唯一合法例外**(scripts-only 规则的出口)。适用于 plan.md / iterations.md / plan/index.md / iterations/index.md / register.md 及内容文档
- **[MUST] scripts-only** — `plan.md` / `iterations.md` / `plan/index.md` / `iterations/index.md` 只能由 scripts 改写, 禁止手工编辑(用户确认例外除外)
- 状态自检 `AGENTSPACE/scripts/status.sh`; 收尾后及怀疑损坏时运行 `AGENTSPACE/scripts/doctor.sh`; 需要深度审计(逐文件内容、跨历史交叉、修复)时显式运行 `/agentspace-doctor` 命令(--minor | --major [--fix])— 该命令绝不自动触发
- **禁止读取**: 插件开发数据(`skills/agentspace-update/versions/`、`DEVELOPMENT.md`、`marketplace.json` 等)与项目无关, 禁止在项目工作中读取或引用

## 4. 里程碑 git 提交

触发点(具体清单): plan 创建/完成 · iteration 创建/关闭 · 模块注册 · notes 写入 · tests.md 环境变更 · examples/data 登记 · 用户规则写入 · update 应用 · 脚本/模板更新。
```bash
git -C AGENTSPACE add -A && git -C AGENTSPACE commit -m "<type>: <摘要>"
```
type 示例: `plan` / `iteration` / `notes` / `data` / `examples` / `utils` / `tests` / `register` / `docs`。
提交后告知用户(commit 摘要)。**只操作 AGENTSPACE 仓库**, 绝不 add/commit 宿主仓库; 宿主代码状态用 commit sha 记录, 需要时存 diff(对宿主 HEAD)到 data/。
