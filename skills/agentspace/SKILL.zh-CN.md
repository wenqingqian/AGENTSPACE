---
name: agentspace
description: 在已有 AGENTSPACE 工作区的项目中工作(plan、iterations、utils、tests、notes)。仅在两个条件同时满足时激活: (1) 项目根存在 AGENTSPACE/ 目录, 且 (2) 当前会话涉及本项目的实验、代码改动、项目迭代或状态追踪。项目无关的闲聊或无状态变化的问答不激活。绝不创建或初始化 AGENTSPACE —— 初始化仅通过显式 /init-agentspace 命令。
---

# AGENTSPACE 日常管理

## 0. 启动守卫

按顺序判断, 任一不满足则静默退出(不提及本 skill, 按普通请求处理):
1. 项目根存在 `AGENTSPACE/` 目录
2. 当前会话涉及**本项目**的实验 / 代码改动 / 项目迭代 / 状态变更 —— 项目无关的会话(问答、闲聊、无状态变化的纯查询)不启动

绝不允许: 自动初始化 AGENTSPACE(只有显式 `/init-agentspace` 可以)。

## 1. 上下文自保(模型判断, 无 hook)

工作时确保以下三个文件的内容在当前上下文中; 不确定(如 compact 之后)或**做任何状态变更前**, 先重新读取:
1. `AGENTSPACE/AGENTS.md` — 结构、模块规则与纪律
2. `AGENTSPACE/tests.md` — 实验环境
3. `AGENTSPACE/iterations.md` — 迭代状态

恢复序列(会话开始/状态不确定时): `AGENTS.md` → `tests.md` → `iterations.md` → `plan.md`(任务相关时) → `iterations/latest/readme.md` 的"当前状态 · 下一步"。

## 2. 工作流

### 新任务 → 建 plan(一个任务可拆成多个 plan)
```bash
AGENTSPACE/scripts/new-plan.sh "计划标题"        # 输出 plan:NNNN
```
然后撰写生成的 `plan/todo/NNNN-*.md`: 目标 / 背景 / 方案步骤。里程碑提交(见 §4)。

### 开始一轮迭代 → 建 iteration(plan-id 必填: 一个 iteration 必属且仅属一个 plan)
```bash
AGENTSPACE/scripts/new-iteration.sh <plan-id> "本轮内容"   # 输出 iteration_NNNN
```
- 更新 readme: 目标 / 改动摘要 / 环境(宿主 commit sha)
- **data 收集三策略**(产物全量进 `iteration_NNNN/data/`, 该目录已 gitignore):
  1. 程序支持设置 output 位置 → 直接指向 `iteration_NNNN/data/`
  2. 支持重定向 → `cmd > iteration_NNNN/data/xxx.log`
  3. fallback → 在工作区找到本轮产出文件, `mv` 进 `iteration_NNNN/data/`
- 工作过程中及时更新 readme 的"当前状态 · 下一步"和"日志"(append-only)

### 关闭迭代
结果写入 readme 的"结果"节后:
```bash
AGENTSPACE/scripts/close-iteration.sh <id> "结果一句话"
```
里程碑提交。

### 完成计划
```bash
AGENTSPACE/scripts/complete-plan.sh <id> <done|failed|abandoned> "结果一句话"
```
补充 plan 文档"结果"节; 有可迁移教训 → 记录 notes; 里程碑提交。

### 工具 / 环境 / 知识 / 扩展模块
- 需要辅助工具(做图 / 机器状态 / 运行状态 / 日志分析)先查 `utils.md`, 复用而非重写; 新工具写入 `utils/` 并在 `utils.md` 登记
- 公用数据(训练集/模型权重/软连接)放 `data/` 并在 `data.md` 登记; data/ 全部 gitignore
- 可复用实验配置(YAML/JSON)放 `examples/` 并在 `examples.md` 登记; tests/ 放脚本, examples/ 放配置
- 环境变化(容器 / conda / 机器 / 依赖)当天更新 `tests.md`; 测试脚本放 `tests/` 并登记
- 踩坑 / 可迁移结论 → `notes/`(模板 `templates/note.md`), **必须带来源**(plan:NNNN / iteration_NNNN)
- 新模块(非内置模块): **先与用户确认** → `AGENTSPACE/scripts/register-module.sh <name> "用途"`

## 3. 纪律

- `plan.md` / `iterations.md` / `plan/index.md` / `iterations/index.md` **只能由 scripts/ 改写** — 一律调脚本, 不手工编辑表格
- 内容文档(plan 文档 / iteration readme / notes / utils / tests)由你直接撰写, 使用 `templates/` 模板
- 相互引用一律用 id: `plan:NNNN` / `iteration_NNNN`; 不用路径, 不用 latest
- `data/` 不入 git(已 gitignore), 产物全量本地保存
- 结束一轮工作前: 更新进行中 iteration readme 的"当前状态 · 下一步" — 这是下次会话的续接入口
- 状态自检 `AGENTSPACE/scripts/status.sh`; 怀疑状态损坏 `AGENTSPACE/scripts/doctor.sh`
- **禁止读取**: 插件开发数据(`skills/agentspace-update/versions/`、`DEVELOPMENT.md`、`marketplace.json` 等)与项目无关, 禁止在项目工作中读取或引用

## 4. 里程碑 git 提交

触发点: plan 创建/完成、iteration 创建/关闭、模块注册、重要文档更新。
```bash
git -C AGENTSPACE add -A && git -C AGENTSPACE commit -m "<type>: <摘要>"
```
type 示例: `plan` / `iteration` / `notes` / `data` / `examples` / `utils` / `tests` / `register` / `docs`。
提交后告知用户(commit 摘要)。**只操作 AGENTSPACE 仓库**, 绝不 add/commit 宿主仓库; 宿主代码状态用 commit sha 记录, 需要时存 diff(对宿主 HEAD)到 data/。
