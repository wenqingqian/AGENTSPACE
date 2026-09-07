# AGENTSPACE v1.1.0

Upgrade from v1.0.1. Date: 2026-09-07

## Summary

- **AGENTS.md: 用户所有的 用户规则 节 + 纪律 新增两条 MUST(用户规则守护 / 注释卫生)**: 内置固定规则与用户蒸馏的工作规则拆为两个同级节 — 内置 纪律 节保持插件所有、可与 asset 逐字节机械比对升级; 新增 用户规则 节归用户所有, 更新永不改写。存量工作区需一次性拆分迁移(step 8b, 精确文本操作见下), 把用户蒸馏的纪律行带入新节。
- **commit 门: 只报告(report-only)的扩网候选层** — lib.sh 新增 `COMMIT_CANDIDATE_PLAN_RE` / `COMMIT_CANDIDATE_ITER_RE`; commit-check.sh 在禁令扫描之外额外打印不阻断的 CANDIDATES(plan/iteration 词与数字相邻、任意分隔符)。候选绝不改变退出码, 由 agent 语义层逐条裁决。
- **doctor skill 块 6/7(notes 内容质量审核、跨 plan 冲突审核)与 code-clean 批量注释审查是插件侧 skill 能力** — 无工作区迁移, 也没有任何工作区文件与之对应。
- 本版本无模块清单、结构树、template、表 schema 变更。

## Changes

### [Addition] AGENTS.md: 用户规则节 + 纪律新增两条 MUST(拆分迁移)

- **What**: `AGENTSPACE/AGENTS.md` 恰好改三处(逐字文本全部在下): ① 纪律 节新增两条 MUST 行; ② 里程碑触发行新增 `用户规则写入` 触发词; ③ 文件末尾追加用户所有的 `## 用户规则` 节。机械插入之外, 本版本的核心迁移任务是**拆分迁移**: 工作区 纪律 节中不属于 v1.0.1 内置集合的行是用户蒸馏规则, 原样移入新节。
- **Why**: 内置纪律集合必须与 asset 逐字节一致, 未来更新才能对它做机械 diff/升级; 用户蒸馏规则必须在每次更新中原样存活 — 混在同一节里这两个目标不可能同时达成。注释卫生 把注释卫生规则(由 commit 门语义层的过程叙述检查与 code-clean 审查执法)钉为 MUST; 用户规则守护 定义用户规则的唯一产生方式(用户驱动, agent 仅可在有现象证据时启发式提议)。
- **Migration** (**AGENTS.md (step 8b — agent 动作, 逐字插入)**; 保守模式下, 把全部五步作为 step 7 更新方案中的 AGENTS.md 条目呈现, 含 Step 3 发现的任何歧义行):

  **Step 0 — 幂等守卫**: 若 `AGENTSPACE/AGENTS.md` 已含 `## 用户规则` 标题(v1.0.1 工作区不应存在), 跳过 Step 4 的建节, 把 Step 3 的迁移行并入既有节。

  **Step 1 — 插入两条 MUST 行。** 精确位置: `## 纪律` 节内, 紧跟以 `- **[MUST] 脚本报错恢复**:` 开头的行之后、以 `- 内容文档(` 开头的无前缀行之前。逐字插入以下两行:

  ```markdown
  - **[MUST] 用户规则守护**: 用户规则节的写入/修改/删除只能经用户显式确认; agent 永不自动创建或改写用户规则; agent 提议仅限当前会话内工作或用户指示显现强规则性质时启发式提出(附现象证据), 用户拒绝后同一提议不再重复
  - **[MUST] 注释卫生**: 注释只描述代码意图与约束, 禁止过程叙述(写作日期、所用工具/skill、记账与会话上下文); 违规由 commit 门语义层与 code-clean 审查报出, 修复由用户驱动
  ```

  **Step 2 — 里程碑触发行。** 找到以 `- **里程碑 git 提交**` 开头的唯一一行。在 `update 应用` 之前紧挨插入 `用户规则写入 · `, 即把子串 `examples/data 登记 · update 应用` 改为 `examples/data 登记 · 用户规则写入 · update 应用`。该行其余部分一个字不动。

  **Step 3 — 拆分迁移(本版本的核心)。** 构造 v1.0.1 内置基线: 取规范 asset `skills/agentspace-init/assets/agentspace/AGENTS.md` 的 `## 纪律` 节, 删去 Step 1 的两条 MUST 行 — 剩余部分即 v1.0.1 内置集合。把工作区 `## 纪律` 节与该基线逐行比对:
  - 工作区中不在基线里的每一行(非逐字节相同)= 用户蒸馏规则。原样迁入新 `## 用户规则` 节(Step 4), `[MUST]`/`[SHOULD]`/`[MAY]` 标记保持原状; 迁入的行替换占位注释。
  - 例外: 里程碑触发行是内置行, 不是用户内容 — 它在 v1.0.1→v1.1.0 的唯一差异就是 `用户规则写入 · ` 插入, Step 2 已处理。若工作区该行与基线里程碑行的差异仅为该 token, 视为内置, 不迁移。
  - 歧义行(疑似内置行的改写/换述)绝不自动迁移: 逐条列入 step 7 更新方案的 AGENTS.md 条目, 由用户逐项决定 — 迁入 用户规则 / 留在 纪律 / 丢弃。
  - Step 1–3 完成后, 工作区 纪律 节必须与 asset 的 纪律 节逐字节相同(任何残余差异要么是等待用户 Step 3 决定的用户内容, 要么是错误 — 重新核对)。

  **Step 4 — 追加新节** 到 `AGENTSPACE/AGENTS.md` 最末尾(纪律 节之后, 节前空一行), 逐字:

  ```markdown
  ## 用户规则

  > 本节由用户维护: 只记录经用户确认的固定工作规则; 与 纪律(内置规则) 同级, 同样使用 [MUST]/[SHOULD]/[MAY] 分级, 一条一规则。
  > 创建/修改/删除只能由用户驱动; agent 仅可在当前工作显现强规则性质时启发式提议, 经用户确认后写入(见 纪律 节)。

  <!-- 用户规则条目从此处追加 -->
  ```

  Step 3 发现用户蒸馏行时, 由它们替换 `<!-- 用户规则条目从此处追加 -->` 占位行(一条一规则, 标记不变); 没有用户蒸馏行则占位行保留。

  **BAD migration(绝不允许的做法)**: "加上新的 用户规则 节, 并把 纪律 同步到最新 asset" — 无锚点、无逐字文本、无拆分分析。具体败法两种: 用内置集合覆盖工作区 纪律 节(悄悄销毁用户蒸馏规则 — 数据丢失), 或者建了一个空 用户规则 节而用户蒸馏规则仍滞留在 纪律 里(下次更新的内置 diff 会把它们误读为漂移)。

### [Addition] commit 门扩网候选层(lib.sh + commit-check.sh)

- **What**: `scripts/lib.sh` 新增两个 readonly 常量, 逐字记录于 `versions/v1.1.0/architecture.json`:

  ```
  COMMIT_CANDIDATE_PLAN_RE="(^|[^[:alnum:]_])plan[[:space:]_:-]*[0-9]"
  COMMIT_CANDIDATE_ITER_RE="(^|[^[:alnum:]_])iteration[[:space:]_:-]*[0-9]"
  ```

  `scripts/commit-check.sh` 现在还会在与禁令扫描相同的两个面(整条 message 草稿 + 暂存 diff 的新增行)上打印只报告的 CANDIDATES 清单, 撒网比标准禁令对更宽: plan/iteration 词 + 任意分隔符(`- _ :` 空格, 或无)+ 数字, 如 `plan-12`、`plan_12`、"plan 13"、`iteration:34`。已被标准禁令对命中的行绝不会再列为候选。
- **Why**: 标准禁令对刻意收窄(前导零锚定、单一分隔符形态)以做到零误报, 因此变体拼写完全逃逸。候选层把这些形态捞出来交给 agent 显式裁决 — 候选绝不阻断、绝不改变退出码(硬命中仍 exit 1); agent 必须对每条候选给出带理由的裁决(带理由放行, 或改写)。
- **Migration**: handled by step 8a — 全部 `scripts/*.sh` 由规范 asset 整体替换(本版本实际变化的是 lib.sh 与 commit-check.sh, 其余十个脚本逐字节相同), `templates/*.md` 与 `.gitignore` 由同一步替换且本版本无变化。**本块无需任何手工工作区操作。**

### [Behavior] doctor 块 6/7 + code-clean 批量注释审查(插件侧能力)

- **What**: doctor skill 的 `--major` 模式新增块 6(notes 内容质量审核: outdated/wrong 两判定 + 证据链, 永远只报告)与块 7(跨 plan 冲突审核: 只审 plan×plan 与 plan×知识两类矛盾 — 重复/交叠明确不算发现), 以及 `--major` 必须作为本会话唯一主任务运行的规则。code-clean skill 新增过程叙述注释维度作为 WARN 候选(日期叙述、工具/skill 来源 — agent 裁决, 绝不硬阻断)与批量注释审查模式(全文件、多 subagent、只报告、仅用户显式触发, 范围 = 本会话 commit 触及的文件)。
- **Why**: 需要对大体量内容做判断的审计属于 agent 语义层而非脚本; 把它们定位为插件侧 skill 能力, 工作区脚本保持确定性。
- **Migration**: **仅插件侧 skill 文本 — 本块工作区无需任何迁移动作。** 块 6/7 与批量审查没有任何对应的工作区文件: 不要为此创建、编辑或查找任何工作区文件。(工作区 `scripts/doctor.sh` 本版本未变; 但它与其他脚本一样照常由 step 8a 刷新。)

### [Fix] 结构树、templates、模块清单、表 schema: 无变更

- **What**: 本版本不新增模块、不删除模块、不改任何表格列。`AGENTSPACE/AGENTS.md` 的 `结构` 代码块不增一行不减一行; 五个 `templates/*.md` 与 `.gitignore` 和 v1.0.1 内容相同; `versions/v1.1.0/architecture.json` 与 v1.0.1 的差异仅限 version 字段、AGENTS.md 节清单(新增 `用户规则`)与两个新常量。
- **Why**: 明说以免更新 agent 为本版本虚构结构性工作。
- **Migration**: 无 — 无事可做。若工作区扫描提示需要结构树/模块/schema 变更, 均不在 v1.1.0 范围内; 保持工作区原样并报告。
