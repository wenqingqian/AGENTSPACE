# AGENTSPACE v1.4.0

Upgrade from v1.3.1. Date: 2026-09-09

## Summary

- **agentspace-code-clean 双层化**: 融合 x-code-clean 与 x-better-commit 的规则(取并集), 拆为被动层(SKILL.md 重写, 默认加载的 MUST/SHOULD 常驻规则)与主动层(新增 CLEANUP.md + CLEANUP.zh-CN.md, 仅显式触发才读的后处理流程), SKILL.md 内以 "if 用户显式要求清理 → read CLEANUP.md" 指针规则衔接。插件侧 skill。
- **AGENTS.md 内置代码卫生规则(8b)**: 部署 AGENTS.md 的 commit 门行尾与纪律"注释卫生"行改写 — code-clean 被动层成为登记仓库的默认要求, 主动清理/历史重建仅限用户显式要求(逐字迁移见 Changes); root-AGENTS.md 模板与 init 追加块同步(仅新 init 生效)。
- **文档聚焦**: CHANGELOG 条目遵守 code-clean commit 文本规则(一行点题、只陈述 diff 可证事实、Why 一句话、不复述 What), 原则写入 DEVELOPMENT.md; README 双语 code-clean 行与结构树按两层能力重写。
- **发布门与测试**: verify-release [8] 新增 CLEANUP 指针规则双语机制配对; t13 回放表补 v1.4.0 两处 8b op; 新增 t35 两层结构测试。仅仓库侧工具。
- 无工作区结构/脚本/模板/schema 变更(架构档案自 v1.3.1 拷贝, 仅版本号)。

## Changes

### [Addition] agentspace-code-clean 两层拆分 + x-code-clean / x-better-commit 规则融合
- **What**: `skills/agentspace-code-clean/SKILL.md` + `SKILL.zh-CN.md` 重写为**被动层** — commit 门(机制不变)+ commit 文本规则(原两问 rubric 吸收 x-better-commit: `<type>:` 前缀/祈使句/≤50 软 72 硬/单一目的/正文 why-over-how 与 72 折行)+ 注释规则(原新增行禁令吸收 x-code-clean: why-not-alternative 反馈残留禁令及其设计注记边界、测试实例引用禁令与 assert-vs-example、四类分级①删②删③精简④保留、公开 API 一行 docstring 例外)+ 文件规则; 批量注释审查节缩为指针。新增 `CLEANUP.md` + `CLEANUP.zh-CN.md` **主动层** — 范围界定(区间/文件/批量审查三模式 + 区间起点盲区修正 + 范围铁律)、候选提取(Python tokenize/ast 精确、他语言启发式须对照真实文件)、分级应用(可识别措辞清单 + 坑点)、先报告后确认、语法门与零行为漂移自检、风格检查(只报告不裁决)、commit message 改写三模式(起草 / amend 仅未推送 / `<rev>` 只打印)、历史重建安全流程(先备份、按形状选 rebase/filter-repo、force-push 护栏、事后验证; 边界从"用户自己的操作"放宽为"用户决定, 显式要求下按流程执行")。description 双语重写(EN 994 / zh 518 字符, ≤1000 上限内); skills/agentspace-doctor 双语的 [15] 历史违规措辞同步新边界(重建 = 用户决定, 显式要求时按 CLEANUP 流程执行, 不再是"用户自己的操作")。
- **Why**: 三个 skill 把指导性规则与处理流程混装, 默认加载体积大且规则分散 — 指导性置为默认、流程性按需读取, 是用户定下的结构; 规则取并集, 无一方删减。
- **Migration**: 插件侧 skill, 随插件更新交付; **工作区无需任何操作**。

### [Fix] AGENTS.md 内置代码卫生规则(8b 精确文本)
- **What**: 资产 `skills/agentspace-init/assets/agentspace/AGENTS.md` 两处编辑: 关键代码仓库 commit 门行尾从"完整规则见 agentspace-code-clean skill。"扩为两层表述; 纪律节 `[MUST] 注释卫生` 升级为 `[MUST] 代码卫生`(保留原禁令, 增补 why-not-alternative / 测试实例禁令与主动层门槛)。`skills/agentspace-init/assets/root-AGENTS.md` 硬规则新增代码卫生一行; init 双语 SKILL.md 的追加块同步该行, 并补齐 v1.3.1 漏同步的 exp 枚举与登记门措辞(root-AGENTS.md 与追加块均仅新 init 生效; 既有项目根 AGENTS.md 属用户内容, 不迁移)。
- **Why**: code-clean 规则此前只经 skill 触达; 用户要求将其作为 AGENTS.md 内置要求, 默认行为有章可循。
- **AGENTS.md (step 8b — agent action, exact insertion)**(逐字执行, 共 2 处编辑):

  1. 关键代码仓库 commit 门行(局部替换): 在该行内把 `未登记仓库(exit 2)先登记后提交。完整规则见 agentspace-code-clean skill。` 替换为:
     ```markdown
     未登记仓库(exit 2)先登记后提交。commit 门与全部代码/注释/commit 文本卫生规则见 agentspace-code-clean skill(被动层默认生效; 主动清理既有代码/历史仅经用户显式要求)。
     ```
  2. 纪律 注释卫生 行(整行替换): 将 `- **[MUST] 注释卫生**: 注释只描述代码意图与约束, 禁止过程叙述(写作日期、所用工具/skill、记账与会话上下文); 违规由 commit 门语义层与 code-clean 审查报出, 修复由用户驱动` 整行替换为:
     ```markdown
     - **[MUST] 代码卫生**: 登记仓库内写入的代码、注释与 commit 文本默认遵循 agentspace-code-clean 被动层规则 — 注释只描述代码意图与约束, 禁止过程叙述(写作日期、所用工具/skill、记账与会话上下文), 禁止 why-not-alternative 反馈残留与测试实例引用; 违规由 commit 门语义层与 code-clean 审查报出, 修复由用户驱动; 既有代码/历史的清理与重建仅在用户显式要求时按该 skill 的 CLEANUP 流程执行
     ```

### [Fix] 文档聚焦 — CHANGELOG 规范化 + README 重写
- **What**: `skills/agentspace-update/DEVELOPMENT.md` 的 CHANGELOG 质量要求新增一条 — 条目本身遵守 agentspace-code-clean commit 文本规则: Summary 每条一行点明"变更加效果"且只陈述 diff 可证事实, Why 一句话说动机, 不复述 What、不写过程叙述; 唯一例外是 Migration 的 8b 文本操作必须逐字完整(执行契约, 不是叙述)。README.md / README.zh-CN.md: code-clean skill 行按两层能力重写为一句, 插件结构树 code-clean 行注释同步两级表述, Release History 增 v1.4.0 一行摘要。
- **Why**: changelog 本质是面向 update agent 的 commit message — 无重点的长条目迫使迁移 agent 在叙述里捞操作; 规则并入 code-clean 后文档照做, 本条目即示范。
- **Migration**: 插件侧文档(DEVELOPMENT.md 随插件分发但仅面向贡献者); **工作区无需任何操作**。

### [Fix] 发布门与测试 — [8] 新机制配对 + t13 回放补 op + t35 新测试
- **What**: `verify-release.sh` [8] 机制配对清单新增 skills/agentspace-code-clean 的 `read CLEANUP.md in this skill directory` / `阅读本 skill 目录内的 CLEANUP.md` 双语对; `tests/t13-upgrade-chain.sh` 回放表补 v1.4.0 两处 8b op(与上方逐字一致), 并把 v1.1.0 块的 注释卫生 行源从实时资产改为内联固定(该行已被 v1.4.0 改名为 代码卫生, 实时取行必然落空); `tests/t27-agentsmd-user-rules.sh` 的 MUST 字面量与排序断言随改名同步; 新增 `tests/t35-code-clean-two-level.sh`(断言两层结构契约: CLEANUP.md / CLEANUP.zh-CN.md 存在且含先报告后确认与历史重建护栏、SKILL 双语含指针规则与批量注释审查节、CLEANUP 双语标题配对与平台词禁令), 并在 AGENTSPACE/tests.md 登记。
- **Why**: 指针规则是两层结构的接缝 — 配对断言防双语漂移, t35 防结构回退, t13 回放表是升级链的第二事实源。
- **Migration**: 仅仓库侧开发工具(verify-release / tests 不随插件分发); **工作区无需任何操作**。

### 无变更块
- **[Fix] 结构树/模块清单/schema 兼容性**: 工作区 scripts / templates / .gitignore / 各表结构与既有脚本行为**无变更**(架构档案自 v1.3.1 原样拷贝, 仅版本号); 三平台 manifest 结构无变更(仅版本号); plan/iteration/exp 既有流程零改动; doctor / status / commit 门脚本行为零改动。本版本**有 step 8b**(上方 2 处 AGENTS.md 编辑), 除该两处外无事可做。
