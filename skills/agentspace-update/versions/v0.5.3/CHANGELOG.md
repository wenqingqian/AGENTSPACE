# AGENTSPACE v0.5.3

Upgrade from v0.5.2. Date: 2026-08-11

## Summary

- **status 近期动态分区重构(软硬结合再分层)**: `## 近期动态` 下分四个 `###` 分区 — 主线(软槽, 子代理 2-3 句合成)/ 代码提交(宿主仓库 commit 流 + 每 commit 机械事实 stat/关联反查 + 概括软槽)/ 工作区事件(原事件流, cap 10)/ 台账(agentspace 记账 commit, cap 5)。宿主仓库 commit(iteration 对应的真正代码改动)首次入列, 且按 close-iteration 记录的宿主 commit SHA 反查关联到 iteration/plan。
- **会话入口"最近关闭"锚点**: 最近一次关闭的 iteration 一行给全 — 标题 / 关闭日期 / 宿主结束 commit SHA; 无进行中任务时它是重开会话的上下文锚点。
- **/agentspace-status 版本闸门**: 工作区脚本版本落后于插件时, 输出固定警示行 + 原样呈现旧格式(不再静默拼接) — 旧工作区在新型插件下产出旧格式的盲点只有 skill 侧能捕。
- **三方验证 3 修复入库**(eacbeda): 白名单条目输入规范化(cd -P)、软告警空行、doctor [13] 小文件豁免 note 不计数。
- No structural changes(无 AGENTS.md / 模块结构变化)。

## Changes

### [Feature] status.sh 近期动态四分区: 主线 / 代码提交 / 工作区事件 / 台账
- **What**: `## 近期动态` 由单一交错时间线改为四个 `###` 分区:
  - `### 主线` — 软槽, 占位 `- 近期主线: —`, 命令侧子代理合成 2-3 句(近期活动整体意味着什么);
  - `### 代码提交 (宿主仓库 · 最近 5 条)` — 宿主仓库 `git log -5`(排除 AGENTSPACE 路径), 每 commit 块三行: `- <sha> · <日期> · <主题>` / `  改动: <N> files, +A/-D · 关联: <iteration_N · plan:XXXX 标题>|—`(SHA 反查 iterations/iteration_*/readme.md 的 `> 宿主起始/结束 commit:` 记录) / `  概括[<sha>]: —`(软槽, 子代理按 SHA 分析 2-3 句, 失败保持 —);
  - `### 工作区事件 (最近 10 条)` — 原事件流(plan/iteration/notes/handoff 索引日期列), 分区内日期倒序, cap 10;
  - `### 台账 (agentspace 记账 · 最近 5 条)` — 原提交摘要流(类型前缀映射中文), cap 5。
  - 宿主判定与 close-iteration 的 as_host_head 同款(AS_ROOT 父目录在 git 工作树内, toplevel 取根), 非 git 宿主 → `(无宿主仓库)` 空态。
- **Why**: 近期动态是工作台的"当前焦点"段落 — 台账 commit 只有记账意义, 真正的代码改动(iteration 对应的宿主仓库 commit)此前完全不可见; 且单行时间线无法承载"这段 commit 在干什么"的概括。软硬结合: 槽/stat/关联是硬(可测试), 概括/主线是软(agent 分析)。
- **Migration**: handled by step 8a(scripts/status.sh 整体替换)。

### [Feature] /agentspace-status 版本闸门(skill 侧)
- **What**: SKILL.md/zh-CN step 0: 先读 `AGENTSPACE/.agentspace-version.json` 的 version 与插件版本对比; 不一致或文件缺失时, 以固定行 `⚠ 工作区脚本 v<ws> 落后于插件 v<plugin> — 以下为旧版格式输出, 建议先运行 /agentspace-update` 为前缀原样呈现 status.sh 输出, 跳过子代理合成与占位符替换。
- **Why**: 工作区脚本是工作区侧资产, 只有 /agentspace-update 更新; 旧工作区在新型插件下产出旧格式输出, 且旧脚本自身无法告警漂移(v0.5.0+ 的漂移软告警只在已更新脚本里) — 曾导致用户误把旧格式当成新版输出。
- **Migration**: handled by step 8a(skills/agentspace-status/SKILL.md + SKILL.zh-CN.md 整体替换)。

### [Addition] 会话入口"最近关闭"锚点
- **What**: `## 会话入口` 首行固定输出最近一次关闭的 iteration: `- 最近关闭: iteration_0007 — <标题> (<完成日期> 关闭 · 宿主 <SHA>|—)`(完成日期最大者, 宿主 SHA 取 readme 的 `> 宿主结束 commit:`); 无已关闭迭代 → `  ✓ 无已关闭迭代`。
- **Why**: 无进行中任务时, 重开会话最需要的是"上次干到哪、代码在哪" — 标题/日期/宿主 SHA 一次给全, 替代旧版 `latest -> iteration_0007` 式裸链接。
- **Migration**: handled by step 8a。

### [Fix] 三方验证 3 修复入库(eacbeda 内容)
- **What**: (1) add/remove_whitelist_entry 输入规范化 — `cd -P` 后再剥离项目根前缀, /tmp 拼写条目不再与 /private/tmp 规范化匹配错位; (2) status.sh 软告警节空行 — 仅当实际产出告警才追加; (3) doctor [13] 白名单小文件豁免项从 issue 改为 `[note]`(合法用户显式豁免不再让 doctor 永远红色)。
- **Why**: 真实三方验证(agentspace-thirdparty mode 转换)发现的使用路径缺陷 — 均有对应回归测试(t15 空行断言 / t17 /tmp 拼写 --allow)。
- **Migration**: handled by step 8a。

### No structural changes
- 无 AGENTS.md 标记块、模块目录、index 表结构变化; 无 8b 步骤。
