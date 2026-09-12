# AGENTSPACE v1.5.3

Upgrade from v1.5.2. Date: 2026-09-12

## Summary

- **code-clean 注释规则硬化**: 用户文件评审的 5 条意见落成规则 — ① 注释必须自洽于"改动之后"的代码: 禁反馈驱动、禁缺失上下文(改动前的代码、被否掉的写法、产生本轮改动的讨论都是缺失上下文, 依赖它们的注释是残留); ② 原"四类分级"单条拆成 删冗余复述 / 精简过度解释 / 保留该保留的 三条 MUST; ③ 过程叙述(日期叙述、工具/skill 来源)从 WARN 升为 MUST; ④ 新增 MUST: 禁 IP 地址、主机名等机器相关标识与秘密(token、密钥)。
- **commit 文本与注释规则并轨**: Commit 文本规则新增一条 MUST — 下方注释规则同样约束 commit 标题与正文每一行, 正文不是绕开注释规则的侧门。
- **description 去举例**: code-clean 双语 SKILL 的 description 删去规则细节枚举, 改为直接要求"动手前必读本文件, 规则以本文件为准"(触发语义与两级结构保留)。
- **CLEANUP 双语同步**: ① 类可识别措辞补"改动前引用"; 批量审查维度行补机器指纹与秘密, "SKILL.md 四类"措辞对齐新规则形态。
- **部署资产 AGENTS.md**: 纪律"代码卫生"行追加机器标识/秘密禁令(8b 逐字替换一处)。
- **测试**: t13 回放链加 v1.5.3 操作; t35 加新规则断言(含"WARN 过程叙述"消失的反向断言); verify-release [8] 加一条新机制短语对。
- 插件侧文件(SKILL/CLEANUP/测试)随插件更新交付, 工作区无操作; 唯一手工迁移是 AGENTS.md 代码卫生行的 **8b** 逐字替换; 无 schema/结构变化。

## Changes

### [Fix] code-clean SKILL 双语 — 注释规则硬化与 description 精简
- **What**: `skills/agentspace-code-clean/SKILL.md` + `SKILL.zh-CN.md`: 注释规则节重组为八条 MUST — 「注释自洽于当前代码(禁反馈驱动/禁缺失上下文, 原因即"注释像为改动后代码专写; 改动前代码属缺失上下文")」「删除冗余复述」「精简过度解释」「保留该保留的」(后三条由原"四类分级"拆出; 反馈式解释归入第一条)、「不引用测试实例」「描述代码不描述会话」(原文保留)、「无过程叙述」(原 WARN 升 MUST, 日期叙述/工具来源一律禁写、触及即清)、「无机器指纹与秘密」(禁 IP/主机名/内网拓扑/端口/用户路径, 禁 token/密钥/密码; 槽位用可读占位名)。Commit 文本规则节在两条既有 MUST 后加「注释规则同样约束 commit 文本」(带改动描述豁免: 正文以所附 diff 为在场上下文, delta 陈述与迁移事实合法)。「无机器指纹与秘密」的机器标识枚举收窄为绑定具体机器的 host:port。description 双语删去规则枚举, 改为"动手写入或审查前必须通读本文件, 全部规则与分级以本文件为准"。
- **Why**: 用户评审指出的四类问题 — 描述举例代替必读约束、注释规则未覆盖 commit 文本、分级单条不可执法、反馈驱动/缺失上下文与机器信息泄漏缺一条明确的禁令; 过程叙述在部署 AGENTS.md 摘要里早已是禁令, skill 本体升 MUST 消除两层落差。
- **Migration**: 插件侧 skill, 随插件更新交付; **工作区无需任何操作**。

### [Fix] CLEANUP 双语对齐新规则形态
- **What**: `skills/agentspace-code-clean/CLEANUP.md` + `CLEANUP.zh-CN.md`: 开头括号"comment tiers/注释分级"改"comment rules/注释规则"; 分级节标题指向改为"SKILL.md 注释 MUST"; ① 类可识别措辞补「改动前引用("no longer does X"、"changed from Y to Z")」; 批量注释审查维度行改为「整条注释级 MUST(过程叙述、机器指纹、秘密)」并去掉对 SKILL.md"四类分级"的旧称引用。
- **Why**: CLEANUP 是流程半边, 其分类与维度清单逐字镜像 SKILL 规则面 — SKILL 拆分与升 MUST 后必须同轮收敛, 否则批量审查仍按旧 WARN 姿态执法。
- **Migration**: 插件侧文件, 随插件更新交付; **工作区无需任何操作**。

### [Fix] 部署资产 AGENTS.md 代码卫生行补机器标识/秘密禁令
- **What**: `skills/agentspace-init/assets/agentspace/AGENTS.md` 纪律节"代码卫生"行在"禁止 why-not-alternative 反馈残留与测试实例引用"后追加「, 禁止 IP/主机名等机器标识与秘密(token、密钥)」, 其余逐字不变。root-AGENTS.md 模板与 init 双语追加块为指针句(无规则枚举), 无需改动。
- **Why**: 部署摘要必须与 skill 规则面同轮对齐 — 新 MUST 是真实新增的禁令面, 摘要不加则老工作区看不到这条边界。
- **Migration**: 资产行的 **8b** 逐字替换见下方 AGENTS.md 块。

- **AGENTS.md (step 8b — agent action, exact insertion)**(逐字执行, 共 1 处编辑; 文本与规范资产 `skills/agentspace-init/assets/agentspace/AGENTS.md` 一致, 以资产为校对源):

  1. 纪律节代码卫生行(整行替换): 将 `- **[MUST] 代码卫生**: 登记仓库内写入的代码、注释与 commit 文本默认遵循 agentspace-code-clean 被动层规则 — 注释只描述代码意图与约束, 禁止过程叙述(写作日期、所用工具/skill、记账与会话上下文), 禁止 why-not-alternative 反馈残留与测试实例引用; 违规由 commit 门语义层与 code-clean 审查报出, 修复由用户驱动; 既有代码/历史的清理与重建仅在用户显式要求时按该 skill 的 CLEANUP 流程执行` 整行替换为:
     ```markdown
     - **[MUST] 代码卫生**: 登记仓库内写入的代码、注释与 commit 文本默认遵循 agentspace-code-clean 被动层规则 — 注释只描述代码意图与约束, 禁止过程叙述(写作日期、所用工具/skill、记账与会话上下文), 禁止 why-not-alternative 反馈残留与测试实例引用, 禁止 IP/主机名等机器标识与秘密(token、密钥); 违规由 commit 门语义层与 code-clean 审查报出, 修复由用户驱动; 既有代码/历史的清理与重建仅在用户显式要求时按该 skill 的 CLEANUP 流程执行
     ```

### [Test] t13 回放链 + t35 契约 + verify [8] 机制短语对
- **What**: `tests/t13-upgrade-chain.sh` 回放表追加 v1.5.3 操作(上述 8b 代码卫生行整行替换, 旧串内联钉死); `tests/t35-code-clean-two-level.sh` 增加新规则断言 — 双语 SKILL 各含「注释规则同样约束 commit 文本 / apply the Comment Rules below to commit text too」「无机器指纹与秘密 / carry no machine fingerprints or secrets」, 且"WARN 过程叙述 / WARN process-narrative"不再出现(反向断言钉住升级); `verify-release.sh` [8] 机制短语对追加 `MUST carry no machine fingerprints or secrets|MUST 无机器指纹与秘密`。
- **Why**: 新 8b 操作必须进回放链(老工作区逐版升级的通道回归); 新 MUST 与 WARN 降级是可断言的契约面, 需要正反两向钉住。
- **Migration**: 测试为插件开发侧资产, **工作区无需任何操作**。
