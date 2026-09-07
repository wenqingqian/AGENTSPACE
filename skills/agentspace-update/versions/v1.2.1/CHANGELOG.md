# AGENTSPACE v1.2.1

Upgrade from v1.2.0. Date: 2026-09-07

## Summary

- **new-plan.sh slug 硬校验**: plan 标题必须产出合规 slug — 小写英文词、数字、单连字符(正则 `^[a-z0-9]+(-[a-z0-9]+)*$`); 中文/大写/下划线/标点/空标题在写入任何文件或表行**之前**被硬拒(exit 非 0), 报错提示改用小写英文标题。只对未来新建 plan 生效 — 存量 plan 文件、文件名与索引行一律不动。
- 本版本无其他变更: 无模块/结构树/template/schema 变更, 无 AGENTS.md 文本操作(无 step 8b)。

## Changes

### [Behavior] new-plan.sh: slug 硬校验(创建入口拒绝, 存量不动)

- **What**: `scripts/new-plan.sh` 在分配 id 之后、创建任何文件或写任何表行之前, 对标题派生的 slug 施加正则 `^[a-z0-9]+(-[a-z0-9]+)*$`(小写英文词 + 数字 + 单连字符; 无前导/尾随/连续连字符)。不合规 — 含 CJK 字节、大写字母、下划线、残留标点, 或标题全由可剥离字符组成导致 slug 为空 — 一律 `as_die` 硬拒, exit 非 0, 报错形如:

  ```
  plan slug not allowed: "<slug>" (generated from title "<标题>") — plan filenames
  accept lowercase english words, digits and single hyphens only; retry with a
  lowercase english title (words joined by hyphens)
  ```

  拒绝发生在 id 展示之后, 但**不消耗 plan id**(索引/条目均未写入, 下次创建沿用同一 id)。
- **Why**: plan 文档文件名携带 slug(`plan/todo/NNNN-<slug>.md`)。v0.2.2 修过 CJK 截断, 但大写/下划线/标点标题依旧产出不可读、难引用、跨平台脆弱的文件名; 与其事后清洗, 不如把命名契约钉死在唯一创建入口, 并在报错里直接给出合规形态, agent 无需猜测即可重试。
- **Migration**: **handled by step 8a — 全部 `scripts/*.sh` 由规范 asset 整体替换**(本版本实际变化的仅 `new-plan.sh` 一个脚本)。无需任何手工工作区动作; 行为只影响更新**之后**的新建 plan — 存量 plan 的文件名、文档与索引行不做任何转换, 也不会被回扫校验。更新后首次 `new-plan.sh` 若用中文/大写/含标点标题会被硬拒: 换小写英文词(连字符连接)重试即可, 例如 `new-plan.sh "baseline reproduction"`。

### [Fix] 结构树、templates、模块清单、表 schema、AGENTS.md: 无变更

- **What**: 本版本除 `new-plan.sh` 的 slug 校验外无任何变化。不新增模块、不删除模块、不改任何表格列; `AGENTSPACE/AGENTS.md` 的 `结构` 代码块不增一行不减一行; 五个 `templates/*.md` 与 `.gitignore` 和 v1.2.0 内容相同; `versions/v1.2.1/architecture.json` 与 v1.2.0 的差异仅限 version 字段。
- **Why**: 明说以免更新 agent 为本版本虚构结构性工作, 或对 AGENTS.md 发明 8b 文本操作。
- **Migration**: 无 — 无事可做。本版本**没有 step 8b**: 不要改 `AGENTSPACE/AGENTS.md` 的任何一行。若工作区扫描提示需要结构树/模块/schema/AGENTS.md 变更, 均不在 v1.2.1 范围内; 保持工作区原样并报告。
