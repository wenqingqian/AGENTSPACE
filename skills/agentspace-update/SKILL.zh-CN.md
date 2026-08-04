---
name: agentspace-update
description: 将现有 AGENTSPACE 工作区更新至当前插件版本。仅由显式 /update-agentspace 命令触发，使用变更日志驱动的智能分析迁移，支持保守/激进模式。绝不自动触发。
---

# AGENTSPACE 更新流程

仅在用户显式执行 `/update-agentspace` 时进行。绝不自动运行。

## 步骤

### 1. 守卫

检查项目根是否存在 `AGENTSPACE/`。不存在 → 报错并建议 `/init-agentspace`。不执行初始化（那是独立命令）。

同时检查工作区 git 状态：`git -C AGENTSPACE status --porcelain` 有未提交改动时，先告知用户——建议先提交挂起里程碑，并警告回滚（`git -C AGENTSPACE reset --hard pre-update-v<旧版本>`）会丢弃未提交改动。

### 2. 读取当前状态

读取 `AGENTSPACE/.agentspace-version.json`：
- 文件存在 → 提取 `version`
- 不存在 → 视为 `"0.1.0"`（旧版工作区），通知用户这是首次更新

读取 `AGENTSPACE/.agentspace-architecture.json`：
- 存在 → 用作当前架构参考
- 不存在 → 从工作区实际文件推断架构（读取节标题、表格列头）

读取插件版本：`.zcode-plugin/plugin.json` → `targetVersion`

### 3. 版本检查

比较 `currentVersion` 与 `targetVersion`。相同：
- 运行 `AGENTSPACE/scripts/status.sh`
- 报告"已是最新 (vX.Y.Z)"后结束

### 4. 确定更新模式

默认：**保守模式**（破坏性变更前询问）。

切换**激进模式**：
- 用户传入 `--force` 参数
- 用户在对话中明确说"激进更新"

### 5. 加载目标版本档案

从 `currentVersion + 1` 到 `targetVersion`（时间顺序），逐版本读取：
- `skills/agentspace-update/versions/vX.Y.Z/CHANGELOG.md` — 变更详情
- `skills/agentspace-update/versions/vX.Y.Z/architecture.json` — 目标架构快照

跨多个版本升级时，按顺序读取所有中间版本的 CHANGELOG。

### 6. Agent 分析（核心步骤，非脚本）

这是智能分析步骤。Agent（你）必须：

**a. 理解每项变更**：仔细阅读每个 CHANGELOG 条目——什么变了、为什么变、迁移指导

**b. 对比架构**：比较当前 `.agentspace-architecture.json` 与目标版本：
- 新增 / 删除 / 重命名的文件
- 文件内新增 / 删除 / 重命名的节
- 表格列变更（新增 / 删除 / 重排序）
- `type` 变更（view→content 等）
- `managedBy` 变更
- `constants` 漂移（SEC_*/STATUS_* 字符串变化 → lib.sh 契约变更）

**c. 扫描工作区实际内容**：
- 读取关键文件了解当前状态
- 检查用户是否有自定义内容会受影响
- 统计 schema 变更影响的数据行数

**d. 构建更新方案**：
- **安全替换**：scripts/*.sh、templates/*.md、.gitignore（无用户内容）
- **Schema 转换**：列变更的 view 文件（列出列差异 + 影响行数）
- **内容合并**：AGENTS.md、tests.md、utils.md、notes.md（新节 vs 保留的用户内容）
- **删除项**：被移除的模块/文件（列出将删除的每个文件）

### 7. 保守模式确认

向用户展示更新方案：

```
## 更新方案: v0.1.0 → v0.2.0

### 安全操作（自动执行）
- scripts/*.sh — 8 个文件替换为最新版本
- templates/*.md — 4 个文件替换
- .gitignore — 替换

### Schema 变更
- plan.md: 新增「优先级」列（影响 N 条现有 plan 记录）
- plan/index.md: 新增「优先级」列
- iterations.md: 无变更

### 内容合并
- AGENTS.md: 在「纪律」后插入「版本历史」节；你的 项目简介/根仓库简介 原样保留
- tests.md: 无变更

### 删除
- register.md + register/ — 模块移除（X 条注册条目将丢失）
```

用户响应：
- **"继续"/"确认"** → 执行所有变更
- **逐项拒绝** → 跳过该项，执行其余
- **"取消"/"不更新"** → 终止，不改动任何文件
- **"切换激进模式"** → 无需确认直接执行

**关键**：保守模式下，用户拒绝的破坏性变更被**跳过**而非强制执行。版本文件记录**最高完整应用版本 V**（从 `currentVersion + 1` 到 V 的每个 changelog 都被完整应用）：即最早被跳过的变更若来自 vN，记录 N-1（或保持当前版本），绝不记录目标版本——否则下次更新从被跳过的版本之后开始，被拒绝的项永远不会被重试。

### 8. 执行更新

确认后（或激进模式下直接），先在工作区仓库创建回滚 tag（init 契约保证工作区是 git 仓库）。`<旧版本>` = step 2 读到的 currentVersion（本次更新从哪个版本出发）。用 `-f` 覆盖：同一基线版本重试时，tag 重新指向当前更新前的状态，此时回滚只撤销本次更新。tag 命令失败则中止并报告错误：

```bash
git -C AGENTSPACE tag -f pre-update-v<旧版本>
```

然后：

**维护迁移台账**：逐项应用 changelog 时，为每个变更块记录 `已应用 / 跳过 / 不适用`（跳过注明原因）。台账是 Step 11 汇报的审计依据，不要只依赖会话记忆。

**a. 替换插件管理文件**：scripts/*.sh、templates/*.md、.gitignore

**b. 逐项应用 changelog 变更**（agent 执行，非刚性脚本）：
- 新增节/文件 → 在指定位置创建
- 删除模块 → 删除该模块下所有文件和目录
- Schema 变更 → 用当前数据重建 view 文件（新表头 + 旧数据行，新列默认空值）
- AGENTS.md 变更 → 智能合并（新节插入、用户内容保留、结构树更新、常量漂移时更新纪律节；重试此前被拒绝的插入时，锚点处可能残留上次跳过留下的连续空行——插入后把连续空行折叠为一个，与规范资产 `skills/agentspace-init/assets/agentspace/AGENTS.md` 比对确认）

**c. 更新版本标记**——传入 step 7 确定的版本（全部应用则为 targetVersion，否则为最高完整应用版本）：
```bash
bash skills/agentspace-update/scripts/update-version.sh <已记录版本>
```
拷贝**已记录版本**的 architecture.json（快照必须描述工作区实际状态，而非目标版本）：
```bash
cp skills/agentspace-update/versions/v<已记录>/architecture.json AGENTSPACE/.agentspace-architecture.json
```

### 9. 验证

运行 `AGENTSPACE/scripts/doctor.sh`。问题分类：
- 可自动修复（断链）→ doctor 处理
- 数据不一致 → 报告给用户，建议手动修复

### 10. Git 提交

```bash
git -C AGENTSPACE add -A && git -C AGENTSPACE commit -m "update: AGENTSPACE v旧 → v新"
```

提交类型：`update`。若已记录版本等于旧版本（部分拒绝），提交为 `update: AGENTSPACE partial (v<旧版本>, 被拒项待重试)`。告知用户 commit hash。

### 11. 汇报

总结：版本跨度、替换文件数、schema 变更、内容合并、跳过项（保守模式）、逐项迁移台账（每个 changelog 变更块一行，标注 已应用/跳过/不适用）、doctor 结果、回滚命令（`git -C AGENTSPACE reset --hard pre-update-v<旧版本>`）、下一步建议。

## 备注

- **部分更新**：用户在保守模式下拒绝部分变更时，工作区处于混合状态。`.agentspace-version.json` 记录**最高完整应用版本**并拷贝该版本的 architecture.json（见 step 7 关键说明与 step 8c），低于 targetVersion。下次更新重读被跳过版本的 changelog，重试被跳过的变更。
- **回滚**：每次更新在变更前创建/覆盖 `pre-update-v<旧版本>` tag（`<旧版本>` = step 2 的 currentVersion，见 step 8）。回滚：`git -C AGENTSPACE reset --hard pre-update-v<旧版本>`；删除 tag：`git -C AGENTSPACE tag -d pre-update-v<旧版本>`。tag 很便宜，保留即可。`reset --hard` 前先查 `git status`——未提交的改动会被丢弃（先 stash 或提交）。
- **工作区模板语言**：assets/ 中的模板保持中文（工作区语言约定）。更新 skill 和开发文档使用英文（插件基础设施层面）。
