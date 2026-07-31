---
name: agentspace-update
description: 将现有 AGENTSPACE 工作区更新至当前插件版本。仅由显式 /update-agentspace 命令触发，使用变更日志驱动的智能分析迁移，支持保守/激进模式。绝不自动触发。
---

# AGENTSPACE 更新流程

仅在用户显式执行 `/update-agentspace` 时进行。绝不自动运行。

## 步骤

### 1. 守卫

检查项目根是否存在 `AGENTSPACE/`。不存在 → 报错并建议 `/init-agentspace`。不执行初始化（那是独立命令）。

### 2. 读取当前状态

读取 `AGENTSPACE/.agentspace-version.json`：
- 文件存在 → 提取 `workspaceVersion`
- 不存在 → 视为 `"0.1.0"`（旧版工作区），通知用户这是首次更新

读取 `AGENTSPACE/.agentspace-architecture.json`：
- 存在 → 用作当前架构参考
- 不存在 → 从工作区实际文件推断架构（读取节标题、表格列头）

读取插件版本：`.zcode-plugin/plugin.json` → `pluginVersion`

### 3. 版本检查

比较 `workspaceVersion` 与 `pluginVersion`。相同：
- 运行 `AGENTSPACE/scripts/status.sh`
- 报告"已是最新 (vX.Y.Z)"后结束

### 4. 确定更新模式

默认：**保守模式**（破坏性变更前询问）。

切换**激进模式**：
- 用户传入 `--force` 参数
- 用户在对话中明确说"激进更新"

### 5. 加载目标版本档案

从 `workspaceVersion + 1` 到 `pluginVersion`，逐版本读取：
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

**关键**：保守模式下，用户拒绝的破坏性变更被**跳过**而非强制执行。版本文件记录实际应用的版本（可能低于 pluginVersion）。

### 8. 执行更新

确认后（或激进模式下直接）执行：

**a. 替换插件管理文件**：scripts/*.sh、templates/*.md、.gitignore

**b. 逐项应用 changelog 变更**（agent 执行，非刚性脚本）：
- 新增节/文件 → 在指定位置创建
- 删除模块 → 删除该模块下所有文件和目录
- Schema 变更 → 用当前数据重建 view 文件（新表头 + 旧数据行，新列默认空值）
- AGENTS.md 变更 → 智能合并（新节插入、用户内容保留、结构树更新、常量漂移时更新纪律节）

**c. 更新版本标记**：
```bash
bash skills/agentspace-update/scripts/update-version.sh <目标版本> <插件版本>
cp skills/agentspace-update/versions/v<目标>/architecture.json AGENTSPACE/.agentspace-architecture.json
```

### 9. 验证

运行 `AGENTSPACE/scripts/doctor.sh`。问题分类：
- 可自动修复（断链）→ doctor 处理
- 数据不一致 → 报告给用户，建议手动修复

### 10. Git 提交

```bash
git -C AGENTSPACE add -A && git -C AGENTSPACE commit -m "update: AGENTSPACE v旧 → v新"
```

提交类型：`update`。告知用户 commit hash。

### 11. 汇报

总结：版本跨度、替换文件数、schema 变更、内容合并、跳过项（保守模式）、doctor 结果、下一步建议。

## 备注

- **部分更新**：用户在保守模式下拒绝部分变更时，工作区处于混合状态。`.agentspace-version.json` 记录实际应用的版本（可能低于 pluginVersion）。下次更新会重新尝试被跳过的变更。
- **无回滚**：无内置回滚机制。AGENTSPACE git 历史即回滚点——用户可 `git -C AGENTSPACE reset --hard <更新前commit>`。
- **工作区模板语言**：assets/ 中的模板保持中文（工作区语言约定）。更新 skill 和开发文档使用英文（插件基础设施层面）。
