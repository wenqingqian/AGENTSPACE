# AGENTSPACE v1.3.1

Upgrade from v1.3.0. Date: 2026-09-09

## Summary

- **新增 `/agentspace-exp` 触发器(命令 + 同名 skill, 第 12 个 skill)**: exp 模块的工作流入口 — 持有登记门(仅限主动登记、同一会话最多提议一次、开发收尾的正确性验证绝不登记)并驱动手册生命周期(设计对齐 → new-exp / start-exp / complete-exp → 报告); 设计对齐与报告分别委托两个正式 skill agentspace-better-exp / agentspace-better-exp-report。触发器与正式 skill 的分工就此厘清: plan 创建情形简单, 由主 skill §2 直接管; exp 登记情形复杂(不是所有实验都登记 — 正确性验证等默认不登记), 因此需要专门入口。主 agentspace skill §2 的实验小节同步改为指针。
- **AGENTS.md exp 节措辞修正(8b)**: v1.3.0 把 agentspace-exp 写成"本模块工作流的称谓, 非斜杠命令" — 与命令+skill 触发器的事实冲突, exp 模块 what/when 两行与纪律"创建前确认"行改写(逐字迁移见 Changes)。
- **better-exp-report 文字规范去白名单化**: §2 首条"(throughput, gate, expert, top-1 accuracy)"的枚举写法会被读成固定英文白名单, 无法正确覆盖 — 改为单判据"该领域社区是否默认使用该术语"(§1.3 与 description 双语同步)。插件侧。
- **双 README 重写**: skill 表每行一句(新增 agentspace-exp 行)、命令表补 `/agentspace-exp`、插件结构树补两个新文件、Release History 全部一行摘要化(约 150 词行 → 约 30 词, 事实保留) — 文档过自家 better-exp-report 的表格短事实/一行摘要约束; 根 AGENTS.md 硬规则行与 init 模板 root-AGENTS.md(仅新 init 生效, 并补 exp 模块枚举)同步。插件侧文档。
- **发布门收紧**: verify-release [14] description 长度上限 1024→1000 字符; [8] 双语名单改为从 skills/ 目录自推导并新增触发器一次性提议规则的机制配对断言; t13 回放表补 v1.3.1 三处 8b op; t14 新增超长 description 反向用例; t20 命令清单补 exp 并加反向完备断言。仅仓库侧工具。
- 无工作区结构/脚本/模板/schema 变更(架构档案自 v1.3.0 拷贝, 仅版本号)。

## Changes

### [Addition] /agentspace-exp 命令 + agentspace-exp 触发器 skill(第 12 个 skill)
- **What**: 新增 `commands/agentspace-exp.md`(ZCode 命令, 经 `skills:` 前置字段委托)与 `skills/agentspace-exp/SKILL.md` + `SKILL.zh-CN.md`(双语)。触发器保持极简: 启动守卫(AGENTSPACE/ 存在 + 用户显式调用或正在考虑登记) + 登记门 MUST(仅限主动登记、同一会话最多提议一次、正确性验证绝不登记、不是所有实验都登记) + 生命周期(先经 agentspace-better-exp 对齐设计, 其产出契约填充手册后登记; 三脚本 mechanics 归工作区 AGENTS.md exp 模块节; 关闭出报告走 agentspace-better-exp-report) + 分工(plan=为什么/做什么, iteration=改代码, exp=测代码)。
- **Why**: v1.3.0 只交付了两个正式 skill(better-exp / better-exp-report), 没有入口 — 登记规则寄生在主 skill 的 9 行小节里, "触发器"与"正式 skill"的分工未被表达。plan 创建情形简单所以主 skill 直接管; exp 登记需要先判断"这个实验算不算", 必须有专门入口持有这道门。
- **Migration**: 插件侧 skill/命令, 随插件更新交付; **工作区无需任何操作**。

### [Fix] 主 agentspace skill §2 实验小节改为指针
- **What**: `skills/agentspace/SKILL.md` + `SKILL.zh-CN.md` 的"跑实验"小节从 9 行(登记规则全文 + 三脚本 bash 块)缩为 3 行指针 — exp 记录一律经 agentspace-exp skill(由显式 `/agentspace-exp` 命令、或它在用户提到要做实验时的一次性提议触发; 开发收尾的正确性验证绝不登记), 设计对齐与报告分别委托 agentspace-better-exp / agentspace-better-exp-report skill。MUST 计数双语平衡, 主 skill 行数预算放松。
- **Why**: 登记门与脚本细节的单一事实源移入触发器 skill; 主 skill 不再复述(复述文本必然漂移)。
- **Migration**: 插件侧 skill, 随插件更新交付; **工作区无需任何操作**。

### [Fix] AGENTS.md — exp 节触发器措辞(8b 精确文本)
- **What**: 工作区 `AGENTSPACE/AGENTS.md` 三处文本编辑, 把 v1.3.0 的"称谓, 非斜杠命令"表述改为命令+skill 触发器表述。资产 `skills/agentspace-init/assets/agentspace/AGENTS.md` 与 `exp.md` 已同措辞(仅新 init 生效); 存量工作区的 exp.md 头注属静态模板文本, 不迁移不强求(脚本只改其表格, 旧头注文字不影响任何门禁)。
- **Why**: AGENTS.md 是登记/触发规则的第一入口, v1.3.0 的"非斜杠命令"与 v1.3.1 事实直接矛盾, 必须修正。
- **AGENTS.md (step 8b — agent action, exact insertion)**(逐字执行, 共 3 处编辑):

  1. exp 模块 what 行(局部替换): 在 `### exp —— 实验记录 (exp.md + exp/)` 小节的 what 行内, 把 `(agentspace-exp 即本模块工作流的称谓, 非斜杠命令)` 整段替换为:
     ```markdown
     (agentspace-exp 是本模块的触发器 — `/agentspace-exp` 命令 + 同名 skill, 持有登记门与生命周期; 设计对齐/报告由 better-exp 系列两个正式 skill 承担)
     ```
  2. exp 模块 when 行(整行替换): 将 `- **when**: **用户显式要求走 agentspace-exp, 或 agent 在用户提到要做实验时提议并经用户确认**; 开发收尾的正确性验证等常规实验默认不登记(除非用户确认); 登记前的设计对齐走 agentspace-better-exp skill` 整行替换为:
     ```markdown
     - **when**: **用户显式要求走 /agentspace-exp, 或 agent 在用户提到要做实验时提议一次并经用户确认**; 开发收尾的正确性验证等常规实验默认不登记(除非用户确认); 登记前的设计对齐走 agentspace-better-exp skill
     ```
  3. 纪律 创建前确认 行(局部替换): 在该行内把 `exp 只在用户显式要求走 agentspace-exp、或 agent 提议并经用户确认后创建` 替换为 `exp 只在用户显式要求走 /agentspace-exp、或 agent 提议并经用户确认后创建`。

### [Fix] better-exp-report 文字规范 — 英文白名单改为社区默认判据
- **What**: `skills/agentspace-better-exp-report/SKILL.md` + `SKILL.zh-CN.md` 三处双语同步: §2 首条从"公认技术术语保留英文(throughput、gate、expert、top-1 accuracy)"改为单判据式 — 是否保留英文只看"该领域社区是否默认使用这个术语", 明确写"不设固定英文白名单(任何词表都无法正确覆盖)"; 社区默认英文的术语保留英文, 社区惯用中文的术语写中文, 既不硬造中文合成词也不生造英文。§1.3 图内语言行与 description 同步为"英文仅限社区默认术语"。
- **Why**: 枚举清单天然会被读成封闭白名单 — 固定词表无法正确覆盖各领域术语, 判据才是可执行的规则。
- **Migration**: 插件侧 skill, 随插件更新交付; **工作区无需任何操作**。

### [Fix] 双 README + 根 AGENTS.md 重写(插件侧文档)
- **What**: README.md / README.zh-CN.md: skill 表 12 行(新增 agentspace-exp 行; parallel / better-exp / better-exp-report 等行从 60–100 词缩到一句, 触发关键信息保留)、命令表补 `/agentspace-exp [标题]` 行、插件结构树补 `commands/agentspace-exp.md` 与 `skills/agentspace-exp/` 两行、Release History v1.0.0–v1.3.1 全部一行摘要化; 根 AGENTS.md 硬规则的 exp 行改为"/agentspace-exp(命令或同名触发器 skill)"并指向两个正式 skill; init 模板 `skills/agentspace-init/assets/root-AGENTS.md` 同步同一硬规则措辞并在模块枚举行补 `exp(实验记录)`(该模板仅新 init 部署到项目根, 既有项目根 AGENTS.md 属用户内容不迁移)。
- **Why**: README 介绍 skill 与 changelog 时把长段落塞进表格单元格、无重点, 违反自家 better-exp-report 的约束(表格承载短事实、解释入正文、历史行一行摘要); 文档应当过自己立的规范。root-AGENTS.md 模板不同步则新 init 项目看到的登记规则措辞与所有其他面不一致(评审发现)。
- **Migration**: 插件侧文档, 随插件更新交付; **工作区无需任何操作**(README/根 AGENTS.md 不部署到既有工作区)。

### [Fix] 发布门与测试 — description 上限 1000 + [8] 纳入新 skill + t20 命令清单
- **What**: verify-release.sh [14] 的 skill/command description 长度上限 1024→1000 字符(注释与报错消息同步改); [8] 双语同步名单改为从 `skills/` 目录自推导(新 skill 自动纳管, 漏加名单即不可能), 机制配对断言新增 agentspace-exp 的"at most once per session / 同一会话内最多提议一次"双语短语对; tests/t13-upgrade-chain.sh 回放表补 v1.3.1 三处 8b op(回放表是升级链的第二事实源); tests/t14-verify-release-negative.sh 新增超 1000 字符 description 反向用例(守卫上限值本身); tests/t20-plugin-manifest.sh 的既有命令守卫清单加入 exp 并加反向完备断言(命令文件必须在清单内)。
- **Why**: description 上限按用户设定收紧到 1000(在宿主 1024 硬拒绝线下留余量); 新 skill 面必须纳入双语校验([8] 名单硬编码, 漏加即无校验)与机制守卫; t20 守卫既有命令不被误删, 新命令入列。
- **Migration**: 仅仓库侧开发工具(verify-release / tests 不随插件分发); **工作区无需任何操作**。

### 无变更块
- **[Fix] 结构树/模块清单/schema 兼容性**: 工作区 scripts / templates / .gitignore / 各表结构与既有脚本行为**无变更**(架构档案自 v1.3.0 原样拷贝, 仅版本号); 三平台 manifest 结构无变更(仅版本号); plan/iteration 既有流程零改动; doctor / status / commit 门行为零改动。Migration: 无 — 无事可做。
