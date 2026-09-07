# AGENTSPACE v1.2.4

Upgrade from v1.2.3. Date: 2026-09-08

## Summary

- **[Fix] 三份 SKILL.md 前置 YAML 解析失败(用户实证)**: description 为无引号 YAML 纯量, 其中出现 `): ` 冒号+空格序列 — 冒号+空格是 YAML 的 mapping 指示符, PyYAML 报 "mapping values are not allowed in this context", skill 在严格解析的宿主上无法加载。修复: `agentspace-code-clean` 双语 description 各一处 `): ` 改 `) —`(词语零变化, 仅标点), `agentspace` 中文 description 一处 `激活: (1)` 改 `激活 — (1)`(与英文版既有 em-dash 风格对齐)。
- **dev 门扩展(仅开发侧, 不随插件发布)**: `verify-release.sh` 新增 `[14] skill/command frontmatter YAML` — 全部 skill/命令前置块必须通过 PyYAML 解析, 防止此类缺陷再次发布(t14 补对应反向用例)。
- 本版本无结构变更: 无模块/结构树/template/schema 变更, 无 AGENTS.md 文本操作(无 step 8b), 无脚本变更(step 8a 无差异)。

## Changes

### [Fix] SKILL.md 前置 YAML: 三处 description 裸冒号改写(仅标点, 词语零变化)

- **What**: 三份插件侧 skill 文件的 `description` 行各改一处标点, 逐字:
  1. `skills/agentspace-code-clean/SKILL.md`: ``any separator — `plan-12`, `plan_12`, `plan 13`): they never block;`` 改为 ``any separator — `plan-12`, `plan_12`, `plan 13`) — they never block;``
  2. `skills/agentspace-code-clean/SKILL.zh-CN.md`: ``任意分隔符 — `plan-12`、`plan_12`、`plan 13`): 候选永不阻断;`` 改为 ``任意分隔符 — `plan-12`、`plan_12`、`plan 13`) — 候选永不阻断;``
  3. `skills/agentspace/SKILL.zh-CN.md`: `仅在两个条件同时满足时激活: (1)` 改为 `仅在两个条件同时满足时激活 — (1)`(英文版原文即为 `Activate ONLY when BOTH hold — (1)` em-dash 风格, 本次使中文版与之对齐)。
- **Why**: frontmatter 的 description 是无引号 YAML 纯量, 纯量内任何 `冒号+空格` 序列都会被解析器当作 mapping 指示符, 触发 `mapping values are not allowed in this context`(用户实证于 agentspace-code-clean 英文版, line 2 column 812), skill 无法加载。改写为 em-dash 既消除解析歧义又保持可读; 不采用加引号方案(全量 18 份 description 引号化改动面大, 且门禁 [14] 已能在发布前拦住未来任何裸冒号)。
- **Migration**: **仅插件侧 skill 文本 — 本块工作区无需任何迁移动作。** skill 文件不经过 /agentspace-update 分发(随插件本体更新), 不要为此创建、编辑或查找任何工作区文件; 无 step 8a/8b/8c 手工动作。

### [Fix] 结构树、templates、模块清单、表 schema、AGENTS.md、scripts、constants: 无变更

- **What**: 本版本除上述三处 skill description 标点与两份开发侧工具(`verify-release.sh` 新增 [14] 检查、`tests/t14-verify-release-negative.sh` 新增 [14] 反向用例)外无任何变化; 开发侧工具不随插件分发, 不入版本档案契约面。`versions/v1.2.4/architecture.json` 与 v1.2.3 的差异仅限 version 字段。
- **Why**: 明说以免更新 agent 为本版本虚构结构性工作, 或对 AGENTS.md 发明 8b 文本操作。
- **Migration**: 无 — 无事可做。本版本**没有 step 8b**: 不要改 `AGENTSPACE/AGENTS.md` 的任何一行。若工作区扫描提示需要结构树/模块/schema/AGENTS.md 变更, 均不在 v1.2.4 范围内; 保持工作区原样并报告。
