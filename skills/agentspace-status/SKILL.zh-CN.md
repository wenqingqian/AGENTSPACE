---
name: agentspace-status
description: 查看 AGENTSPACE 工作区状态工作台 — 项目总览 + 现状 + 软告警。仅由显式 /agentspace-status 命令触发, 绝不自动运行。
---

# AGENTSPACE 状态工作台

仅在用户显式执行 `/agentspace-status` 时运行。绝不自动触发。

工作台是**现状快照**(项目是什么、现在处于什么状态)。它不推进度, 也不带"下一步"叙述。

## 执行流程 (MUST)

0. MUST 先做**工作区脚本版本闸门**: 读 `AGENTSPACE/.agentspace-version.json` 的 `version` 字段, 与插件版本(裸版本号, 不带 v, 取自插件仓库 `.zcode-plugin/plugin.json`)对比。不一致或版本文件缺失时, 以**恰好这一行**为前缀、原样呈现 status.sh 输出 — 不做子代理合成、不做替换:
   `⚠ 工作区脚本 v<工作区版本> 落后于插件 v<插件版本> — 以下为旧版格式输出, 建议先运行 /agentspace-update`
   (版本文件缺失 → `v?`。) 版本一致才继续 1–5。
1. MUST 运行硬脚本: `bash AGENTSPACE/scripts/status.sh <插件版本>`。脚本输出全部机械节, 软槽以固定占位符呈现: `- 项目: —`、`- 近期主线: —`, 以及每个列出的 commit 一行 `  概括[<sha>]: —`。
2. MUST 从脚本输出收集 commit SHA → 仓库 配对: 匹配 `^  概括\[([0-9a-f]+)\]: —` 的每一行, 仓库路径取自其上方最近的 `#### <name> (<path>)` 块头(单宿主回退输出: 经 `git -C AGENTSPACE/.. rev-parse --show-toplevel` 定位宿主)。
3. MUST 派**恰好一个** Explore 子代理执行下方"项目段落提示词"(提示词必须带上 SHA 列表), 只消费其 `PROJECT_SUMMARY=`、`RECENT_SUMMARY=`、`COMMIT_SUMMARY_<sha>=` 行。子代理失败或为空 → 所有软槽保持原样。
4. MUST 替换脚本输出中的占位符: `- 项目: —` → `- 项目: <PROJECT_SUMMARY>`; `- 近期主线: —` → `- 近期主线: <RECENT_SUMMARY>`; 每个 `  概括[<sha>]: —` → `  概括: <COMMIT_SUMMARY_<sha>>`(某 SHA 无结果 → 该行保持 `—`)。
5. MUST 原样呈现组装后的完整输出 — 不得增删节、不得改写格式、不得附加解读。
6. MUST 全程不得在主上下文读取任何 AGENTSPACE/*.md 文件(脚本输出 + 子代理行是唯一数据源)。
7. 用户追问需要工作区内容时: MUST 派 Explore 子代理执行下方"追问提取提示词"; MUST NOT 在主上下文读工作区文件。

## 输出模板 (逐字)

```
# AGENTSPACE Status <YYYY-MM-DD>

## 项目总览
- 项目: <段落> / —
- 现状: <脚本输出一行>

### 关键代码仓库
- <每登记仓库一行: name (path) · 分支 · 脏 N · 最新: sha 日期 主题 ↑a/↓b> / (无登记仓库)

## 版本与环境
- <脚本输出两行>

## 推进总览
- <每 plan 一行>

## 进行中
- <每项一行> / ✓ 无进行中

## 近期动态
### 主线
- 近期主线: <2-3 句合成> / —
### 代码提交 (关键代码仓库 · 每仓库最近 3 条) — 空登记时回退 (宿主仓库 · 最近 5 条) 并标注 (未登记 …)
#### <仓库 name> (<path>) — 回退模式无此行, 为旧式单宿主列表
- <sha> · <日期> · <主题>
  改动: <N> files, +A/-D · 关联: <iteration_N · plan:XXXX 标题> / —
  概括: <2-3 句, 按 sha 分析> / —
### 工作区事件 (最近 10 条)
- <每事件一行> / (无动态)
### 台账 (agentspace 记账 · 最近 5 条)
- <每记账 commit 一行> / (无台账)

## 软告警 (N)
- <每告警一行> / ✓ 无软告警

## 会话入口
- 最近关闭: <最近关闭的 iteration, 如有> / ✓ 无已关闭迭代
- <handoff 行>
```

节名、顺序、空态占位由 status.sh 硬编码 — 命令侧不得修改。

## 项目段落子代理提示词 (逐字; 把 <SHA1> <SHA2> … 替换为收集到的列表)

> Read-only synthesis. Read ONLY these files: AGENTSPACE/AGENTS.md (项目背景 section), AGENTSPACE/plan.md, AGENTSPACE/plan/index.md, AGENTSPACE/iterations.md, AGENTSPACE/iterations/index.md, AGENTSPACE/exp.md, AGENTSPACE/exp/index.md, AGENTSPACE/notes.md. Produce THREE deliverables:
> 1. `PROJECT_SUMMARY=<paragraph>` — ONE paragraph (≤120 Chinese characters) stating what the project is and its current state.
> 2. `RECENT_SUMMARY=<2-3 句>` — what the recent activity (events + commits) means as a whole: what converged, what was reverted, what is pending. Do not enumerate — synthesize.
> 3. For EACH `SHA@REPO` pair in this list: <SHA1>@<REPO1> <SHA2>@<REPO2> — inspect it via `git -C <REPO> show --stat <sha>` and `git -C <REPO> log -1 --format='%s' <sha>`; write `COMMIT_SUMMARY_<sha>=<2-3 句中文>` — what the change does and why, linking to its iteration/plan when the workspace records it. If a SHA cannot be inspected, omit its line.
> Return EXACTLY one line per deliverable as `FIELD=value` (values must not contain newlines). No file excerpts, no lists of facts, no commentary.

## 追问提取子代理提示词 (逐字)

> Read-only extraction. Read the workspace files needed to answer: <用户问题>. Return ONLY the requested facts, one per line, as `FIELD=value`. No prose, no file excerpts, no markdown.

## 备注

- 即使没有软内容, 脚本输出本身也是完整模板(每个软槽保持 `—`)。
- 状态 ≠ 进度: 绝不虚构"下一步"; 工作区没有进行中内容时, 各节如实显示。
- 软槽(项目段落 / 近期主线 / 每 commit 概括)是模板硬编码的**槽**, 其内容由 agent 分析(软) — 槽固定、内容软。其余(事件、台账、stat、关联、锚点)全部机械。
- 近期动态 = 机械活动时间线: 索引日期列的工作区事件(计划创建/完成、迭代开启/关闭、实验登记/完成、笔记新增、交接生成) + **已登记关键代码仓库**的 commit(`.agentspace-repos`, 每仓库 3 条, 带 stat 与 iteration 关联; 空登记回退单宿主探测并标注"未登记") + 工作区自身台账 commit(类型前缀映射中文, 如 plan:→计划 / fix:→修复)。
- 版本闸门: 工作区脚本是工作区侧资产, 只有 /agentspace-update 会更新; 旧工作区在新型插件下也会产出旧格式输出, 而旧脚本本身无法告警漂移 — 闸门是唯一能捕获此场景的位置。
