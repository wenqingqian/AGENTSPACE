# AGENTSPACE v1.0.0

Upgrade from v0.6.4. Date: 2026-09-05

## Summary

- **新 skill: agentspace-parallel(第 8 个 skill, 双语 SKILL.md / SKILL.zh-CN.md)**: 本地 PR-like 并行工作区。固定形态 — 每个 plan 一组泳道: `<项目根>/worktrees/<plan-id>/<仓库名>/`, 分支 `plan-<plan-id>`, 从主线最新 commit 切出并记录基点; 实施 + 单测 + e2e 全部在泳道内完成(验收层级 T0-T3 先写定后执行); 用户确认后 CAS squash 合回 — 检查主线仍在记录基点, 是则 `git merge --squash` + 过 commit 门 + 恰好一个 PR 名 commit 落主线(泳道内部 commit 不进主线历史), 否则先把主线 absorb 进泳道、按重测分层规则重测、再合; 合回后 `diff plan-<id> main` 必须为空(已测态==已合态证明)。纯本地: 无远端 PR, push 仍是用户显式动作。触发破例: 允许情境触发(出现并行意图时), 不再仅限显式命令。
- **并发安全修复(Fix)**: `new-plan.sh` / `new-iteration.sh` 的 id 分配移到 `as_lock` 之后 — 此前锁外读索引计算"下一个 id", 并发创建全部撞号(由新增并发回归测试当场抓获, 8 并发全撞同号)。
- **doctor [14] 常规位泳道扫描**: 项目根 `worktrees/*/*/.git` 定点扫描(通用热扫描 maxdepth 2 看不见深度 3 的 worktree .git 文件), 在册泳道未登记即告警, `_anchor-*` 锚点目录豁免。
- **doctor [15] 并行事后审计(武装式)**: 仅当仓库呈现并行证据(存在 `plan-*` 分支或检出本身是 linked worktree)才启用 — ① 主线审计窗口内 merge commit 报告(仅主检出; 泳道内 absorb 合并合法, 不报); ② commit message 连字符形泳道标识 `plan-0\d{3,}` 报告(新常量 `COMMIT_BAN_PLAN_DASH_RE`, 与门同源, 前导零锚定零误报)。无并行证据的传统 merge 工作流仓库零新增告警。
- **status 泳道去重**: 登记检出若是 linked worktree, 并入其主检出的行/块(注记 `泳道: plan-NNNN@相对路径`), 不再单独成行; 主检出未登记的泳道保留自身行并加"(泳道检出 — 其主检出未登记)"后缀。
- **模板**: plan 模板新增"改动面声明"节(并行适用性判定输入: 仓库清单 + 文件/语义面); iteration-readme 模板注释新增 PR 簿记指引(永久锚点 = 每仓库 base SHA 记环境节、squash SHA 记结果节; 临时锚点记日志节, 用完即弃)。
- **AGENTS.md 纪律新增"并行工作区约定"铁律行**(8b 精确文本, 见下)。
- 无模块清单变化; 无破坏性变更。

## Changes

### [Addition] agentspace-parallel skill(第 8 个 skill)
- **What**: `skills/agentspace-parallel/SKILL.md` + `SKILL.zh-CN.md`。内容: 七条铁律 / 项目发现(含 e2e 多实例隔离与内嵌形态 .gitignore 前置检查) / 适用性检查(逐仓库改动面交集, 冲突须点名对方 plan) / 固定 worktree 形态 / 角色与冻结(仅合并窗口冻结主线) / 泳道内纪律 / 台账协议(脚本自带锁 + `.locks/ledger/` + 并行期禁 `git add -A` 一把梭 + 会话重入只走 handoff) / refactor-aware absorb(单向: 主线→泳道; 冲突=移植意图; 重测分层) / CAS squash 合回(空净差不建 commit; 多轮 absorb-back) / 资源仲裁 / 不满意分层(合前改当前分支, 合后清理前 fix-forward, 清理后开新迭代; 无重开机制) / 边界(纯本地)。
- **Why**: 多 plan 并行开发此前无章可循 — worktree 位置随意、台账写竞争、合回污染主线历史(默认模板 merge commit + 内部 commit 全量进主线)。PR-like 本地泳道把"确认后才合、只落一个 PR 名 commit、已测==已合"变成可执行流程。
- **Migration**: 插件侧 skill, 随插件更新交付; **工作区无需任何操作**。触发方式注意: 本 skill 是家族内首个允许情境触发的 skill(并行意图出现即可能激活), 其余 skill 触发规则不变。

### [Fix] new-plan.sh / new-iteration.sh 锁先于 id 分配
- **What**: `as_lock` 调用前移到一切工作区状态读取之前(`as_next_plan_id` / `as_next_iteration_id` 读索引计算下一 id, 此前在锁外)。两脚本各删去一处重复加锁(自身活 pid 会自旋死锁)。
- **Why**: 并发创建时所有进程读到同一个"下一个 id"而撞号 — 新增并发回归测试(8 并发 new-plan + 6 并发 new-iteration)当场抓获; 该竞态自 as_lock 引入起潜伏。
- **Migration**: handled by step 8a(scripts 整体替换)。

### [Addition] doctor.sh [14] 常规位泳道扫描 + [15] 并行审计(武装式)
- **What**: [14] 在既有热仓库扫描后新增: 若 `<项目根>/worktrees/` 存在, 对其下 `*/*/.git`(mindepth=maxdepth=3)定点扫描, 目录名 `_anchor-*` 豁免, 未登记且非台账自身的检出告警"固定位置的 worktree 未登记"。[15] 仓库循环开头计算武装条件(lib.sh 新函数 `as_parallel_evidence`: 存在 `plan-[0-9]*` 分支或检出本身是 linked worktree, 后者经新函数 `as_repo_main_worktree` 判定); 武装后新增两审计 — ① 窗口内多父 commit(merge commit)报告, 仅主检出执行(泳道内 absorb 合法); ② message 命中新常量 `COMMIT_BAN_PLAN_DASH_RE="plan-0[0-9]{3,}"`(连字符形泳道标识)报告, 所有登记仓库执行。均只报告, 不改历史。
- **Why**: 并行泳道是登记处的盲区(深度 3 的 .git 文件热扫描看不见); 主线出现 merge commit / 泳道标识进 message 是 CAS squash 流程被绕过的信号。武装式设计保证传统 merge 工作流仓库零新增告警。
- **Migration**: handled by step 8a(lib.sh / doctor.sh 整体替换)。注意: 若工作区已存在并行痕迹(`plan-*` 分支或 linked worktree), 更新后 [15] 可能对**已存在的历史**报红 — 这是事后审计的正常产出, 只报告, 处置由用户决定。

### [Addition] status.sh 泳道去重
- **What**: 登记检出按 git-common-dir 归并: linked worktree 不再单独成行/成块, 并入主检出行并注记 `· 泳道: plan-NNNN@<相对路径>`(每个泳道一条); 主检出未在册的泳道保留自身行, 标题加后缀 `(泳道检出 — 其主检出未登记)`。
- **Why**: 并行期同一仓库的泳道检出会让 status 的仓库清单与代码提交区重复膨胀, 甚至淹没主检出动向。
- **Migration**: handled by step 8a(status.sh 整体替换)。

### [Schema] 模板: plan "改动面声明"节 + iteration-readme PR 簿记指引
- **What**: `templates/plan.md` 在 `## 背景` 之后新增 `## 改动面声明` 节(注释引导: 逐仓库一行 `<仓库路径>: 预计改动的文件/目录/接口面`; 不并行也写一句话; 留空时并行检查要求先补写)。`templates/iteration-readme.md` 三处注释扩展(节结构不变): 环境节 + 并行轮次永久锚点登记指引(每仓库一行 `<repo> plan-<id>:<base-sha>`); 结果节 + 验收层级先写定 / squash SHA 登记指引(保留 `<!-- 指标 / 结论; 关闭 iteration 前必填 -->` 占位行逐字不动); 日志节 + 临时锚点指引。
- **Why**: 改动面声明是 agentspace-parallel §2 适用性判定的输入; PR 簿记让"基点记录 / 已测==已合证明 / 清理依据"在台账有据可查(永久锚点主线永远可达, 临时锚点清理后即失效)。
- **Migration**: 模板文件 handled by step 8a(templates 整体替换)。**存量文档不强制回填**: 进行中 plan 缺改动面声明时, 由并行适用性检查在触发时要求属主会话补写(agentspace-parallel §2 既有规则); 存量 iteration readme 无需改动(注释级指引仅对新建生效)。

### [Addition] AGENTS.md 纪律"并行工作区约定"铁律行(8b 精确文本)
- **What**: `AGENTSPACE/AGENTS.md` `## 纪律` 节新增一条 MUST — 固定位置与锁目录在项目根、内嵌形态 .gitignore 前置豁免、并行期台账写锁与 add 纪律。
- **Why**: 锁 owner 文件含记账 id 字面量, 内嵌形态下被宿主 `git add -A` 扫入会触发 commit 门甚至把泳道整体卷进宿主; 并行期台账 `add -A` 会把别家泳道的未暂存内容卷入自家里程碑提交。
- **Migration** (step 8b — agent action, 逐字执行): 在 `AGENTSPACE/AGENTS.md` 的 `## 纪律` 节中, 找到 `- **[MUST] commit 门**:` 开头的那一行, 在其后插入一行(完整文本, 逐字):

  ```markdown
  - **[MUST] 并行工作区约定**: 多 plan 并行开发走 agentspace-parallel skill(PR-like 本地泳道)。固定位置 `worktrees/<plan-id>/<仓库名>/` 与锁目录 `.locks/` 在**项目根**(非 AGENTSPACE/ 内); 内嵌形态下宿主仓库必须先经 .gitignore 豁免这两个路径(锁 owner 文件含记账 id 字面量, 被 `git add -A` 扫入会触发 commit 门)。并行期台账写操作: 脚本自带锁, 内容文档写前取 `.locks/ledger/`; 永不 `git -C AGENTSPACE add -A` 一把梭(逐路径 add)
  ```
