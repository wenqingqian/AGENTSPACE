# AGENTSPACE v1.2.5

Upgrade from v1.2.4. Date: 2026-09-08

## Summary

- **[Fix] agentspace-code-clean 英文 description 超长(1094 字符 > 宿主 1024 上限)**: 裁剪为 890 字符, 只删 body 已详述的细节, 触发关键信息(何时激活/commit-check.sh 门/未登记禁 commit/候选仅报告/批量注释审查仅显式)全保留。中文 description(528 字符)不超标, 未动。
- **dev 门扩展(仅开发侧, 不随插件发布)**: `verify-release.sh` 的 `[14]` 检查在同一次 PyYAML 解析后追加 description 1024 字符上限校验, 超长 skill 不再可能发布。
- 本版本无结构变更: 无模块/结构树/template/schema 变更, 无 AGENTS.md 文本操作(无 step 8b), 无脚本变更(step 8a 无差异)。

## Changes

### [Fix] SKILL.md description 裁剪(仅删冗余细节, 语义零变化)

- **What**: `skills/agentspace-code-clean/SKILL.md` 的 `description` 行三处删减, 逐字:
  1. `never enter code-repo commits — not in the message, not in code or comments; the commit text must describe the actual code change (one-line title, no experiment/run identifiers, related to the diff).` 改为 `never enter code-repo commits; the commit text must describe the actual code change.`
  2. `wide-net candidates (plan/iteration word adjacent to digits, any separator — \`plan-12\`, \`plan_12\`, \`plan 13\`) — they never block` 改为 `wide-net candidates (plan/iteration word adjacent to digits) — they never block`
  3. `A batch comment review (whole-file, multi-subagent, report-only) over the files this session's commits touched exists — it runs ONLY on the user's explicit request` 改为 `A batch comment review (report-only) over the files this session's commits touched runs ONLY on the user's explicit request`
  长度 1094 → 890 字符(上限 1024)。
- **Why**: 宿主对 skill description 强制 1024 字符上限, 超长即拒绝加载该 skill; 被删片段(逐字展开、分隔符示例、批量审查的实现细节)在 skill 正文均有完整表述, 不影响触发与执行。
- **Migration**: **仅插件侧 skill 文本 — 本块工作区无需任何迁移动作。** skill 文件不经过 /agentspace-update 分发(随插件本体更新), 不要为此创建、编辑或查找任何工作区文件; 无 step 8a/8b/8c 手工动作。

### [Fix] 结构树、templates、模块清单、表 schema、AGENTS.md、scripts、constants: 无变更

- **What**: 本版本仅上述一处 description 删减; `versions/v1.2.5/architecture.json` 与 v1.2.4 的差异仅限 version 字段。
- **Why**: 明说以免更新 agent 为本版本虚构结构性工作, 或对 AGENTS.md 发明 8b 文本操作。
- **Migration**: 无 — 无事可做。本版本**没有 step 8b**: 不要改 `AGENTSPACE/AGENTS.md` 的任何一行。若工作区扫描提示需要结构树/模块/schema/AGENTS.md 变更, 均不在 v1.2.5 范围内; 保持工作区原样并报告。
