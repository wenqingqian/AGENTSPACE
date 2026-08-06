---
name: agentspace-status
description: 查看 AGENTSPACE 工作区状态工作台 — 项目总览 + 现状 + 软告警。仅由显式 /agentspace-status 命令触发, 绝不自动运行。
---

# AGENTSPACE 状态工作台

仅在用户显式执行 `/agentspace-status` 时运行。绝不自动触发。

工作台是**现状快照**(项目是什么、现在处于什么状态)。它不推进度, 也不带"下一步"叙述。

## 执行流程 (MUST)

1. MUST 运行硬脚本: `bash AGENTSPACE/scripts/status.sh <插件版本>` — 插件版本 = 从插件仓库 `.zcode-plugin/plugin.json` 读取的裸版本号(不带 v)。脚本输出全部机械节, 含 `- 项目: —` 占位行。
2. MUST 派**恰好一个** Explore 子代理执行下方"项目段落提示词", 只消费其 `PROJECT_SUMMARY=<段落>` 一行。子代理失败或为空 → 保留 `- 项目: —`。
3. MUST 将脚本输出的 `- 项目: —` 行替换为 `- 项目: <段落>`。
4. MUST 原样呈现组装后的完整输出 — 不得增删节、不得改写格式、不得附加解读。
5. MUST 全程不得在主上下文读取任何 AGENTSPACE/*.md 文件(脚本输出 + 子代理段落是唯一数据源)。
6. 用户追问需要工作区内容时: MUST 派 Explore 子代理执行下方"追问提取提示词"; MUST NOT 在主上下文读工作区文件。

## 输出模板 (逐字)

```
# AGENTSPACE Status <YYYY-MM-DD>

## 项目总览
- 项目: <段落> / —
- 现状: <脚本输出一行>

## 版本与环境
- <脚本输出两行>

## 推进总览
- <每 plan 一行>

## 进行中
- <每项一行> / ✓ 无进行中

## 近期动态 (最多 10 条)
- <每行一条动态: 工作区事件或提交摘要> / (无动态)

## 软告警 (N)
- <每告警一行> / ✓ 无软告警

## 会话入口
- <handoff 行>
```

节名、顺序、空态占位由 status.sh 硬编码 — 命令侧不得修改。

## 项目段落子代理提示词 (逐字)

> Read-only synthesis. Read ONLY these files: AGENTSPACE/AGENTS.md (项目背景 section), AGENTSPACE/plan.md, AGENTSPACE/plan/index.md, AGENTSPACE/iterations.md, AGENTSPACE/iterations/index.md, AGENTSPACE/notes.md. Synthesize ONE paragraph (≤120 Chinese characters) stating what the project is and its current state. Return EXACTLY one line in the form `PROJECT_SUMMARY=<paragraph>`. No file excerpts, no lists, no commentary.

## 追问提取子代理提示词 (逐字)

> Read-only extraction. Read the workspace files needed to answer: <用户问题>. Return ONLY the requested facts, one per line, as `FIELD=value`. No prose, no file excerpts, no markdown.

## 备注

- 即使没有段落, 脚本输出本身也是完整模板(该行保持 `—`)。
- 状态 ≠ 进度: 绝不虚构"下一步"; 工作区没有进行中内容时, 各节如实显示。
- 近期动态 = 机械活动时间线(最多 10 条, 显示日期, 不过滤日期窗口): 索引日期列的工作区事件(计划创建/完成、迭代开启/关闭、笔记新增、交接生成) + 提交摘要(类型前缀映射中文, 如 plan:→计划 / fix:→修复)。
