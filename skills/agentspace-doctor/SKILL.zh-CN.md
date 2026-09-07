---
name: agentspace-doctor
description: 对已有 AGENTSPACE 工作区的深度健康检查 — 确定性一致性、逐文件内容审查、跨历史审计、分级修复。仅在显式 /agentspace-doctor 命令(--minor | --major [--fix])时触发。绝不自动触发, 也绝不替代收尾协议中的低成本闸门 AGENTSPACE/scripts/doctor.sh。
---

# AGENTSPACE Doctor 命令

审计已有 AGENTSPACE 工作区: 确定性一致性(doctor.sh)、逐文件内容审查, major 模式再加跨目录的、结合宿主仓库的全量历史审计。默认只读; `--fix` 开启分级修复。

## 0. 触发守卫

仅当用户显式执行 `/agentspace-doctor` 时继续。绝不自动触发, 绝不作为收尾协议的一部分运行(低成本闸门 `AGENTSPACE/scripts/doctor.sh` 仍留在收尾协议), 也绝不对没有 AGENTSPACE 工作区的项目运行(直说并停止)。

## 1. 参数与模式

- `--minor`(无参数时的默认): 结构 + 逐文件内容审查(阶段 A + B)
- `--major`: minor 的全部 + 跨目录深度审计(阶段 C); minor ⊂ major。必须(MUST)作为本会话唯一主任务运行 — 绝不在同时承载代码改动、实验或其他台账工作的会话中进行; 当前会话已有工作进行时, 先建议在全新会话中运行 `--major`, 仅当用户显式坚持后才继续。`--minor` 不受影响(仍可在会话收尾时运行)
- `--fix`: 开启修复 — 一级脚本自动修复 + 二级经确认的语义修复(§5); 可与任一模式组合
- 未知参数: 说明并询问用户, 绝不猜测
- 不存在 `--force` 阀门, 也不提供 — 本 skill 的 MUST 约束(审计发现只报告、plan 文档不可改、`--major` 独立会话运行)没有覆盖开关

## 2. 阶段 A — 确定性核心

先运行 `AGENTSPACE/scripts/doctor.sh [--fix]`, 其输出是基线:
- exit 0 → 确定性层全绿; exit 1 → 列出红色项
- 逐字报告每条确定性发现, 标注 [script] 来源 — 不重新争辩、不改写脚本输出。doctor.sh 的问题一律为红(硬错误)— 不得降级为黄
- major 模式不跳过本阶段; major 的各层叠加在它之上

## 3. 阶段 B — Minor: 逐文件内容审查

**审查范围 — 全量阅读**:
- 管理表: `plan.md`、`iterations.md`、`notes.md`、`data.md`、`register.md`
- 条目: `plan/todo/*.md`、`plan/done/*.md`、`iterations/iteration_NNNN/readme.md`、`notes/*.md`、`examples/*.md`、`templates/*.md`
- 范围内的文件缺失时(如早于 data/examples 模块的工作区没有 `data.md`/`examples.md`): 记为蓝级观察 — 不升级为红/黄
- 宿主根 `AGENTS.md` — 其中的 AGENTSPACE 区块: 只做内部一致性(规则与硬规则存在且不互相矛盾、结构块与实际布局一致)。**不要**与插件侧模板比对 — 用户项目中插件开发数据禁读
- `utils/`、`tests/` — 只做与入口表的存在性/结构对应(如 `utils.md` ↔ `utils/`); `scripts/` — 与架构契约(`AGENTS.md` 结构块 + `.agentspace-architecture.json`)对应, 因为 `scripts/` 没有入口表; 不对脚本做文字审查
- `.agentspace-repos` / `.agentspace-whitelist` — 脚本管理态文件(只能 repos.sh / mode.sh 改写); 不做文字审查, 绝不手工编辑。它们的一致性由 doctor.sh [13]/[14] 负责
- `data/` 载荷: 绝不读
- 插件开发数据(`skills/agentspace-update/versions/`、`DEVELOPMENT.md`、`marketplace.json` 等): 绝不读(用户项目)

**判断判据 — 状态断言 vs 历史记录**:
- 矛盾: 同一体系内两处对当前状态的声称冲突 → **红**
- 当前状态断言与现实不符(版本标记、索引、脚本行为)→ **红/黄**(可明确证伪为红, 需判断的为黄)。minor 中"现实" = 工作区内部状态(表、索引、版本标记、脚本输出)+ 可直接观测的宿主事实(文件存在性、git 状态); 宿主代码/git 的深度核对属于阶段 C(major)
- 历史记录(已关闭迭代、已完成功能、已回滚尝试、旧版本行为): **一律不算问题**; 仅在缺乏上下文会误导时标记, 并建议补充上下文(**黄**)
- 废话 / 无信息量占位 → **黄**
- 优化机会(去重、蒸馏缺口、缺上下文)→ **蓝**(仅建议)

每条发现带来源标签 — `[script]`(来自 doctor.sh)或 `[agent]`(你的判断)— 以及文件路径与证据。

## 4. 阶段 C — Major: 跨目录深度审计

阶段 A + B 的全部, 再加**并行分发 subagent**(每块一个 — 主 agent 不做分块工作), 然后汇总各块报告。若本会话没有 subagent 工具, 串行执行各块并在报告中注明偏离。子代理指令必须包含: 只读(绝不修改工作区)、用户项目中绝不读插件开发数据、以 file:line 证据报告发现、返回结构化清单。

- **块 1 — 宿主代码+git 成果核对**: 核对 iterations/notes 中的成果断言("已实现 / 已修复 / 已上线")在宿主代码与 git log 中是否有迹可循
- **块 2 — 工作区 git 审计**: 工作区仓库提交卫生(里程碑化, 非碎片提交)、close-iteration 记录的宿主起始/结束 commit 存在且分支正确、pre-update tag 合理、`.agentspace-version.json` 的 lastUpdatedAt 未久未刷新; **另加**: 对已登记关键代码仓库(`.agentspace-repos`)最近 20 条 commit message(与 doctor [15] 同窗口)按 agentspace-code-clean rubric 做三维语义审计: (a) 记账引用变体 — `plan_0013`、"迭代 3"、任何语言形态的记账叙述; (b) 文本质量 — 标题必须是对真实改动的一句话描述(无实验/run 标识如 `(6-run driver launch on .42)`、无机器地址、无无信息标题); (c) 相关性 — 标题/正文主题必须落在实际 diff 里(核对 `git show --stat`)。每条违规报告: sha + 维度 + 具体建议(如拟改写的标题)。只报告。
- **块 3 — 全历史纪律审计**: 跨全部已关闭 plan/iteration/notes 的全量纪律追溯 — 回链完整性、`plan:NNNN` / `iteration_NNNN` 引用有效性、notes 来源、索引一致性
- **块 4 — 版本元数据断言核对**: notes/AGENTS.md/readme 中的版本与元数据声称 ↔ `.agentspace-version.json` 及实际脚本行为
- **块 5 — 环境/脚本调用链 dry-run**: 对 `scripts/`、`utils/`、`tests/` — 顺着调用链(source 关系、依赖、模板引用)分析每个脚本能否运行、写法是否正确、意图是否与 tests.md / plan / iterations 文档一致; **不执行任何东西**
- **块 6 — notes 内容质量审核**: 范围 = `notes.md` 索引加每个 `notes/*.md` 文件。两类判定: **outdated(过时)**(已被工作区此后更新的事实取代)与 **wrong(错误)**(被证据证伪)。方法: note 之间互审 + notes × plan × commit × iteration 四源交叉验证(证据链核对)。每条发现报告: note 标识、判定类别、证据链(`plan:NNNN` / `iteration_NNNN` / 宿主 commit)与建议动作(删除 / 重写 / 知情保留)。永久只报告(§5)
- **块 7 — 跨 plan 冲突审核**(pre-code review: 在 plan 源头拦截冲突; 不是代码质量审查): **只报冲突 — 重复/交叠明确不算发现**。两个维度: (a) plan×plan 矛盾(目标、范围或结论互斥); (b) plan×知识冲突(某 plan 的做法与 notes 结论或 iteration 已验证事实矛盾)

块 6 与块 7 各自独占一个 subagent, 与块 1-5 按同一模式并行分发; 数据量大时单个块可在块内分批。主 agent 只做切分、汇总与呈现 — 绝不在主上下文里审读大体量 notes 或 plan 全文。

**Auto-memory(仅主 agent)**: 子代理不共享你的上下文 — 把你上下文中加载的 auto-memory 条目与工作区 notes 做只读交叉核对。矛盾/过时的记忆条目以黄级报告给用户; 绝不修改 auto-memory。

汇总: 去重发现、合并进三级报告、注明各块覆盖情况。

## 5. 修复 (--fix)

- **一级 — 脚本层(自动)**: 运行 `doctor.sh --fix` — 修复断链 latest 软链、清除 orphan 表行(仅 orphan 行, 绝不碰已完成行 — 全量历史保留在 `plan/index.md`)、回填缺失的 notes.md 行。结果为 [script] 修复, 如实报告
- **二级 — 语义层(agent, 需用户确认)**: 对每条红/黄 agent 发现, 提出具体修复方案(精确文件 + 精确改动), 获得用户确认(逐项或一次批量), 然后执行:
  - 内容文档(readme、notes、examples、templates): 直接编辑 — plan 文档永不编辑(任何模式、任何 tier; 见下)
  - 表格(`plan.md` / `iterations.md` / `plan/index.md` / `iterations/index.md` / `register.md`): 只能走脚本, 或用户明确确认的一次性手工例外
- **优化(蓝)**: 只列建议; 未经用户明确要求绝不执行
- **[14]/[15] 发现**: [14] 的修复(repos.sh 摘除陈旧登记行、往宿主 .gitignore / .git/info/exclude 补盾牌)一律二级 — 必须用户确认, 绝不自动; [15] 的发现(已落入代码仓库**历史**的记账 id / 实验数据)永远只报告 — 任何 tier 都不改写 git 历史, rebase/filter-repo 是用户的决定与用户自己的操作
- **块 6 / 块 7 发现**(notes 内容质量判定、跨 plan 冲突): 永远只报告, 与 [15] 同级 — 任何 tier 都不自动修复, doctor 在本轮运行中即使顺带确认了正确处置也不得就地修复; 处置由用户驱动, 是报告之后的独立工作
- **plan 文档用户所有 — 所有模式、所有 tier**: doctor 绝不修改 plan 文档内容(`plan/todo/*.md` 与其他 plan 正文), 有无 `--fix` 皆然; 涉及 plan 的发现只报告, 任何 plan 修订都是用户自己的独立工作。视图行的脚本层结构卫生不变(tier-1 经 `doctor.sh --fix` 清理 `plan.md` 的 orphan 行)— 那是脚本独占视图上的索引卫生, 不是 plan 文档编辑
- **绝不**: 修改进行中 plan/iteration 的状态字段、`data/` 载荷、宿主项目文件(宿主根 AGENTS.md 仅在用户明确批准时)、auto-memory

## 6. 报告

仅 stdout — 绝不向工作区写报告文件(工作区仓库必须保持干净):

```
## /agentspace-doctor <模式> 报告
### 红 (必须修复) — N
- [script|agent] <路径>: <发现>
### 黄 (告警) — M
### 蓝 (优化建议) — K
### 结论: 全绿 / 红 N · 黄 M · 蓝 K (有红 = 不绿)
```

## 7. 边界

- 除非显式 `--fix`, 一律只读
- 不写工作区文件、不写报告文件、不写 auto-memory
- `data/` 载荷绝不读; 插件开发数据绝不读(用户项目)
- 环境声称用静态 dry-run 分析验证 — 绝不执行测试套件
- doctor.sh 仍是收尾协议闸门; 本命令仅按需显式运行
