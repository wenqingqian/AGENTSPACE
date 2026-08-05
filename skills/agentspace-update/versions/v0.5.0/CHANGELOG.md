# AGENTSPACE v0.5.0

Upgrade from v0.4.1. Date: 2026-08-06

## Summary

- **status 工作台**: 新命令 `/agentspace-status` + 新 skill — 硬脚本机械聚合(不污染主上下文)+ 严格输出模板(逐字固定)+ 项目总览段落由子代理合成; 现状快照定位, 无"下一步"叙述。
- **status.sh 重写**: 项目总览(现状行)/ 版本与环境 / 推进总览(转义感知)/ 进行中 / 近期动态(最近 10 条, 显示日期不按日期筛选)/ 软告警(入口文件行形状校验 + 版本漂移 + 未提交 + doctor)/ 会话入口。
- **`\|` 教训收口**: close-iteration index 改写与 as_row_cell 读取改为转义感知(占位符法)——标题/结果含转义管不再错位截断(第 4/5/6 次复现: index 改写、status 推进总览、as_row_cell 读取)。
- **文档契约修复**: SKILL.zh-CN 示例数字 8/4 → 9/5、step 9 两段式验证闸门镜像 EN; architecture.json AGENTS.md 模块 subsections 补 data/examples/handoff。
- **dev 工具**: verify-release [1] 检查 marketplace 双版本字段、[8] 双语清单扩 agentspace-status; new-version.sh marketplace 双字段同步修复。

## Changes

### [Addition] /agentspace-status 工作台命令 + skill
**What**: 新命令 `commands/agentspace-status.md` + 新 skill `skills/agentspace-status/`(SKILL.md EN + SKILL.zh-CN.md)。命令 = 薄封装: ① 跑硬脚本 `AGENTSPACE/scripts/status.sh <插件版本>`(插件版本 = plugin.json 裸版本号); ② 派**恰好一个** Explore 子代理按 skill 内嵌固定提示词合成项目段落(`PROJECT_SUMMARY=<段落>`, ≤120 字, 失败 → —); ③ 把脚本输出的 `- 项目: —` 占位行替换为段落; ④ 原样呈现。skill 以 MUST 措辞强制: 主 agent 全程不得读取任何 AGENTSPACE/*.md(脚本输出 + 子代理段落是唯一数据源); 输出模板逐字固定(节名/顺序/空态占位由 status.sh 硬编码); 追问解读必须派子代理按固定提取模板。
**Why**: 用户三约束 — ① 不污染上下文(MUST: 硬脚本聚合, 主 agent 零读取); ② 严格模板(MUST: 每次执行输出格式一致); ③ 全面但简洁(MUST: 脚本遍历全部入口文件, 每文件 ≤2 行聚合)。工作台定位 = 现状快照, 不推进度、无"下一步"叙述(用户明确)。
**Migration**:
1. **Plugin-side (no workspace action)**: ships with the plugin — command + skill.
2. **Script (handled by step 8a — no manual work)**: `AGENTSPACE/scripts/status.sh` is replaced from assets.
3. **No data migration**: read-only.

### [Addition] status.sh 重写为工作台
**What**: `AGENTSPACE/scripts/status.sh` 输出改为严格模板(节名/顺序/空态占位固定): `# AGENTSPACE Status <日期>` → `## 项目总览`(`- 项目: —` 占位 + `- 现状:` 一行: 工作区版本/进行中 plan·iteration 计数/notes 数/next 索引/doctor 结果)→ `## 版本与环境`(工作区 vs 插件版本一致/漂移、git dirty/ahead-behind/最近提交)→ `## 推进总览`(每 plan 一行: 标题截断 ≤40 字节 + 迭代数/已关数, 标题取自 plan/index.md)→ `## 进行中`(plan.md Todo 行 + iterations.md 进行中行, 空 → `✓ 无进行中`)→ `## 近期动态 (最近 10 条)`(`git log -10`, 显示日期但不按日期筛选, 主题截断 ≤60 字节 UTF-8 安全)→ `## 软告警 (N)`(① 入口文件行形状校验: plan.md/plan/index.md/iterations.md/iterations/index.md/notes.md/register.md/utils.md/tests.md/data.md/examples.md/handoff/index.md 每数据行格数与表头比对, 转义感知 ② 版本漂移 ③ git 未提交 ④ doctor issues 只读运行, 空 → `✓ 无软告警`)→ `## 会话入口`(handoff 待消费列表, 形状解析沿用)。接受可选参数 = 插件版本号(裸版本, 带 v 自动剥离)。
**Why**: 工作台需在"全面"与"简洁"间平衡 — 脚本遍历所有入口文件但每文件只产 1-2 行聚合; 行形状校验使审计发现的 index.md:16 类损坏(裸 `-F'|'` 改写产生)从此可被工作台直接抓住, 不必等审计。UTF-8 截断: bash 子串在 LC_ALL=C 下仍是字符语义, 用 `head -c` 字节切 + sed 字节类(printf 构建, BSD sed 无 \xHH)剔除不完整尾字符。
**Migration**:
1. **Script (handled by step 8a — no manual work)**: `AGENTSPACE/scripts/status.sh` is replaced from assets.
2. **No data migration**: read-only; the section headers/order are the contract (t15 asserts them verbatim).

### [Fix] close-iteration index 改写 + as_row_cell 读取转义感知(`\|` 教训收口)
**What**: 两处裸 `awk -F'|'` 改为转义感知(占位符法: `\|` 先替换为 \037, 切分/改写后还原):
- `AGENTSPACE/scripts/close-iteration.sh` iterations/index.md 状态/完成日期/结果改写: 标题或结果含转义管时不再错位切分(曾致 index 行 9 格 vs 8 列、"进行中"滞留日期列、链接列空 — 嵌套工作区 iteration_0009 实损)。
- `AGENTSPACE/scripts/lib.sh` as_row_cell: 含转义管的单元格读取不再截断(close-iteration 读 TITLE 曾致 `\\` 残留在最近完成行); 返回单元格存储原样(不重复转义)。
**Why**: `\|` 教训第 4/5/6 次复现的收口 — insert(v0.4.0)/doctor·status 解析(v0.4.1)/--list(v0.4.2)之后, index 改写、推进总览解析、行单元格读取三条路径全部转义感知。输入卫生(标题勿预转义 `\|`, 直接写原始 `|`)在 tests/t15 固化。
**Migration**:
1. **Scripts (handled by step 8a — no manual work)**: `AGENTSPACE/scripts/close-iteration.sh`, `AGENTSPACE/scripts/lib.sh`, `AGENTSPACE/scripts/status.sh` are replaced from assets.
2. **No data migration**: existing rows untouched; workspaces with already-corrupted rows need a one-time user-confirmed repair.

### [Fix] SKILL.zh-CN 文档同步: 示例数字 + step 9 两段式闸门
**What**: `skills/agentspace-update/SKILL.zh-CN.md` 两处机制级不同步修复: ① 第 7 步更新方案示例数字 `8 个文件/4 个模板` → `9 个/5 个`(v0.4.0 handoff 新增后资产实为 9 个 .sh + 5 个 .md, 与 EN 版 "(9 at v0.4.x)" 一致); ② 第 9 步从旧版单次 doctor 描述改为两段式验证闸门(先 `doctor.sh --fix` 再 `doctor.sh`, [0] 以外红项提交前解决, post-commit 必须全绿 — 镜像 EN step 9, v0.4.1 变更此前只进了 EN 版)。
**Why**: 中文模式 update agent 按 zh-CN 执行, 机制级指令缺失会走旧流程; 示例数字失真会误导 agent 核对替换清单。
**Migration**:
1. **Plugin-side (no workspace action)**: ships with the plugin.

### [Fix] architecture.json AGENTS.md 模块 subsections 补全
**What**: `versions/v0.5.0/architecture.json` 与部署 marker `.agentspace-architecture.json` 的 `模块: what / when / how` subsections 从 6 项补为 9 项 — 新增 `data —— 公用数据 (data.md + data/)`、`examples —— 实验配置 (examples.md + examples/)`、`handoff —— 一次性会话交接 (handoff/)`(与资产 AGENTS.md 实际 `### ` 小节一致, 按文件顺序排列)。
**Why**: 审计发现 C2 — 档案只列 6 项而资产有 9 个小节, verify-release [6] 单向检查(列出的必须存在)放行该缺口; 补齐后契约与实现双向一致。
**Migration**:
1. **Plugin-side (no workspace action)**: ships with the plugin; the workspace `.agentspace-architecture.json` snapshot refreshes at the next update (8c).

### [Addition] tests: t15-status-workbench.sh
**What**: `tests/t15-status-workbench.sh` 回归: ① 严格模板断言(7 节头逐字 + `- 项目: —` 占位 + 日期头 + 全绿基线 `✓ 无软告警`); ② 软告警负向(版本漂移 / 种坏行触发 `⚠ 形状:` / 未提交触发 `⚠ git:`, 恢复后回到全绿); ③ `\|` 全链路回归(原始管道标题: new-iteration → as_cell 转义存储 → status 进行中完整显示 → close-iteration 关闭后 index 行 8 列 + 转义管 NF=11 完整、最近完成行标题完整 → 推进总览转义感知计数 `1 迭代 (1 已关)`); ④ 结尾 doctor 全绿。
**Why**: 工作台模板与 `\|` 修复需要永久护栏; 模板节头逐字断言防"每次执行格式漂移"(用户 MUST-2)。
**Migration**:
1. **Dev-only (no workspace action)**: ships with the repo.

### [Addition] dev 工具: verify-release 与 new-version 加固
**What**: `verify-release.sh` [1] 版本一致性检查新增 `marketplace.json` 顶层字段(此前只查 plugins[0] — 顶层漂移逃过门禁); [8] 双语检查清单新增 `skills/agentspace-status`。`new-version.sh` 脚手架修复: marketplace 双字段(顶层 + plugins[0])在同一 lambda 内同步更新(此前两条独立 lambda 因"后写覆盖"丢失顶层)。
**Why**: v0.5.0 脚手架实测抓到 marketplace 顶层漏改(plugins[0] 已更新、顶层停留 0.4.1); 门禁双向覆盖防复发。
**Migration**:
1. **Dev-only (no workspace action)**: ships with the repo.

### No structural changes
- plan/iterations/notes/utils/tests/data/examples/register/handoff schemas unchanged; no new constants in lib.sh (STALE_DAYS 等 13 常量不变); AGENTS.md 无内容操作(t13 重放表无需扩展); 无新文件进入工作区结构。
