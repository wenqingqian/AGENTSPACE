---
name: agentspace-doctor
description: 对已有 AGENTSPACE 工作区的深度健康检查 — 确定性一致性、逐文件内容审查、跨历史审计、分级修复。仅在显式 /doctor-agentspace 命令(--minor | --major [--fix])时触发。绝不自动触发, 也绝不替代收尾协议中的低成本闸门 AGENTSPACE/scripts/doctor.sh。
---

# AGENTSPACE Doctor 命令

审计已有 AGENTSPACE 工作区: 确定性一致性(doctor.sh)、逐文件内容审查, major 模式再加跨目录的、结合宿主仓库的全量历史审计。默认只读; `--fix` 开启分级修复。

## 0. 触发守卫

仅当用户显式执行 `/doctor-agentspace` 时继续。绝不自动触发, 绝不作为收尾协议的一部分运行(低成本闸门 `AGENTSPACE/scripts/doctor.sh` 仍留在收尾协议), 也绝不对没有 AGENTSPACE 工作区的项目运行(直说并停止)。

## 1. 参数与模式

- `--minor`(无参数时的默认): 结构 + 逐文件内容审查(阶段 A + B)
- `--major`: minor 的全部 + 跨目录深度审计(阶段 C); minor ⊂ major
- `--fix`: 开启修复 — 一级脚本自动修复 + 二级经确认的语义修复(§5); 可与任一模式组合
- 未知参数: 说明并询问用户, 绝不猜测

## 2. 阶段 A — 确定性核心

先运行 `AGENTSPACE/scripts/doctor.sh [--fix]`, 其输出是基线:
- exit 0 → 确定性层全绿; exit 1 → 列出红色项
- 逐字报告每条确定性发现, 标注 [script] 来源 — 不重新争辩、不改写脚本输出
- major 模式不跳过本阶段; major 的各层叠加在它之上

## 3. 阶段 B — Minor: 逐文件内容审查

**审查范围 — 全量阅读**:
- 管理表: `plan.md`、`iterations.md`、`notes.md`、`data.md`、`register.md`
- 条目: `plan/todo/*.md`、`plan/done/*.md`、`iterations/iteration_NNNN/readme.md`、`notes/*.md`、`examples/*.md`、`templates/*.md`
- 宿主根 `AGENTS.md` — 其中的 AGENTSPACE 区块(与 init 模板的漂移: 规则、硬规则、结构块)
- `utils/`、`tests/`、`scripts/` — 只做与入口表的存在性/结构对应(如 `utils.md` ↔ `utils/`); 不对脚本做文字审查
- `data/` 载荷: 绝不读
- 插件开发数据(`skills/agentspace-update/versions/`、`DEVELOPMENT.md`、`marketplace.json` 等): 绝不读(用户项目)

**判断判据 — 状态断言 vs 历史记录**:
- 矛盾: 同一体系内两处对当前状态的声称冲突 → **红**
- 当前状态断言与现实不符(版本标记、索引、脚本行为、宿主代码/git)→ **红/黄**(可明确证伪为红, 需判断的为黄)
- 历史记录(已关闭迭代、已完成功能、已回滚尝试、旧版本行为): **一律不算问题**; 仅在缺乏上下文会误导时标记, 并建议补充上下文(**黄**)
- 废话 / 无信息量占位 → **黄**
- 优化机会(去重、蒸馏缺口、缺上下文)→ **蓝**(仅建议)

每条发现带来源标签 — `[script]`(来自 doctor.sh)或 `[agent]`(你的判断)— 以及文件路径与证据。

## 4. 阶段 C — Major: 跨目录深度审计

阶段 A + B 的全部, 再加**并行分发 subagent**(每块一个 — 主 agent 不做分块工作), 然后汇总各块报告。子代理指令必须包含: 只读(绝不修改工作区)、用户项目中绝不读插件开发数据、以 file:line 证据报告发现、返回结构化清单。

- **块 1 — 宿主代码+git 成果核对**: 核对 iterations/notes 中的成果断言("已实现 / 已修复 / 已上线")在宿主代码与 git log 中是否有迹可循
- **块 2 — 工作区 git 审计**: 工作区仓库提交卫生(里程碑化, 非碎片提交)、close-iteration 记录的宿主起始/结束 commit 存在且分支正确、pre-update tag 合理、`.agentspace-version.json` 的 lastUpdatedAt 未久未刷新
- **块 3 — 全历史纪律审计**: 跨全部已关闭 plan/iteration/notes 的全量纪律追溯 — 回链完整性、`plan:NNNN` / `iteration_NNNN` 引用有效性、notes 来源、索引一致性
- **块 4 — 版本元数据断言核对**: notes/AGENTS.md/readme 中的版本与元数据声称 ↔ `.agentspace-version.json` 及实际脚本行为
- **块 5 — 环境/脚本调用链 dry-run**: 对 `scripts/`、`utils/`、`tests/` — 顺着调用链(source 关系、依赖、模板引用)分析每个脚本能否运行、写法是否正确、意图是否与 tests.md / plan / iterations 文档一致; **不执行任何东西**

**Auto-memory(仅主 agent)**: 子代理不共享你的上下文 — 把你上下文中加载的 auto-memory 条目与工作区 notes 做只读交叉核对。矛盾/过时的记忆条目以黄级报告给用户; 绝不修改 auto-memory。

汇总: 去重发现、合并进三级报告、注明各块覆盖情况。

## 5. 修复 (--fix)

- **一级 — 脚本层(自动)**: 运行 `doctor.sh --fix` — 修复断链 latest 软链、清除 orphan 表行(仅 orphan 行, 绝不碰已完成行 — 全量历史保留在 `plan/index.md`)、回填缺失的 notes.md 行。结果为 [script] 修复, 如实报告
- **二级 — 语义层(agent, 需用户确认)**: 对每条红/黄 agent 发现, 提出具体修复方案(精确文件 + 精确改动), 获得用户确认(逐项或一次批量), 然后执行:
  - 内容文档(plan 文档、readme、notes、examples、templates): 直接编辑
  - 表格(`plan.md` / `iterations.md` / `plan/index.md` / `iterations/index.md` / `register.md`): 只能走脚本, 或用户明确确认的一次性手工例外
- **优化(蓝)**: 只列建议; 未经用户明确要求绝不执行
- **绝不**: 修改进行中 plan/iteration 的状态字段、`data/` 载荷、宿主项目文件(宿主根 AGENTS.md 仅在用户明确批准时)、auto-memory

## 6. 报告

仅 stdout — 绝不向工作区写报告文件(工作区仓库必须保持干净):

```
## /doctor-agentspace <模式> 报告
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
