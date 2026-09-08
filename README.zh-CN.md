# AGENTSPACE

跨平台插件, 为实验/迭代型项目提供 **git 管理的 agent 工作区**。

全部功能以 agent skill 交付 — 三个受支持平台(ZCode / Codex / Kimi)都从 `skills/` 加载; 支持斜杠命令的平台(ZCode)额外获得委托给 skill 的轻量 `/agentspace-*` 命令包装。通过显式初始化(ZCode: `/agentspace-init`; 其他平台: 让 agent 运行 `agentspace-init` skill)在项目根目录创建 `AGENTSPACE/`(独立 git 仓库) + 项目根 `AGENTS.md` 引导文件; 之后 agent 在涉及实验/代码改动/项目迭代的会话中自动按规范维护工作区状态, 并在里程碑时自动提交。

## 核心概念

- **plan → iteration 严格一对多**: 一个任务写成一个或多个 plan(全局递增索引, 永不复用); 每个 iteration 是 plan 内的一次代码/状态变更, 必属且仅属一个 plan
- **入口是视图, 文件系统是真源**: `plan.md` 只维护 Todo + 最近 10 条 Done, `iterations.md` 只维护进行中 + 最近 10 条完成; 完整历史在 `plan/index.md`/`iterations/index.md`; 所有索引由 `AGENTSPACE/scripts/` 下的脚本改写, agent 不手编表格
- **内容文档由 agent 撰写**: plan 文档、iteration readme、notes 等使用 `templates/` 模板直接生成
- **实验产物全量本地保存**: `iteration_NNNN/data/` 已 gitignore, 不入 git
- **关键代码仓库 commit 规范**: 关键仓库登记在 `.agentspace-repos`(登记须用户确认); 每次 commit 前必须先通过 `commit-check.sh` 门 — 记账 id 与实验产物永不泄漏进代码仓库(见下文"关键代码仓库与 commit 规范")

## 工作区结构

```
<项目>/
├── AGENTS.md                  # 根引导: 项目背景 + 实验环境 + 关键代码仓库 + 何时读取规则
├── worktrees/  .locks/        # agentspace-parallel 泳道与协同锁(按需创建; gitignore)
└── AGENTSPACE/                # 独立 git 仓库
    ├── AGENTS.md              # 核心入口: 结构/模块 what-when-how/纪律
    ├── plan.md                # 入口: Todo + Done(最近10条)
    ├── plan/{index.md, todo/, done/}
    ├── iterations.md          # 入口: 进行中 + 最近完成(10条)
    ├── iterations/{index.md, latest→, iteration_NNNN/{readme.md, data/}}
    ├── exp.md                 # 入口: Todo + Doing + 最近完成(10条) — 实验仅限主动登记(用户确认后才入册)
    ├── exp/{index.md, todo/, doing/, done/}   # 实验手册生命周期; 索引关联 plan/iteration/commit 点/配置
    ├── exp/exp_data/exp_NNNN/ # 完整实验记录(全量日志; 本机保存, gitignore; 关联 iteration 的 data/ 复制至此)
    ├── data.md + data/        # 公用数据(训练集/模型权重/软连接; 全部 gitignore)
    ├── examples.md + examples/ # 可复用实验配置(YAML/JSON); 与 tests/ 配合; exp_spec/exp_NNNN/ 为登记实验的专属配置位(每个登记 exp 必须有)
    ├── utils.md + utils/      # 复用工具(做图/机器状态/日志分析...)
    ├── tests.md + tests/      # 实验环境(容器/conda/GPU) + 测试脚本
    ├── notes.md + notes/      # 持久知识(带来源证据)
    ├── register.md            # 按需扩展模块(项目特定扩展)
    ├── handoff/               # 一次性会话交接(index.md 入 git; handoff_*.md 一次性, gitignore)
    ├── .agentspace-version.json       # 工作区版本追踪
    ├── .agentspace-architecture.json  # 当前架构快照
    ├── .agentspace-repos              # 关键代码仓库登记处(只能由 scripts/repos.sh 改写)
    ├── .agentspace-whitelist          # 外部依赖白名单(standalone 模式)
    ├── .agentspace-parallel-workspace.txt  # 并行工作区协同表(doing/test/merge + 异步便签; 按需创建, gitignore)
    ├── templates/  scripts/  .gitignore
```

## 安装

通过所在平台支持的插件机制安装并启用本仓库 — 仓库自带三个受支持平台(ZCode / Codex / Kimi)的原生清单, 安装始终由用户执行。

## 使用

### Skill(全平台)

Skill 是功能交付单元 — 在所有受支持平台上行为一致。标注"仅显式"的 skill 只在用户点名时触发(在 ZCode 上也可用下方命令)。

| Skill | 触发方式 | 功能 |
| --- | --- | --- |
| `agentspace` | 自动(带守卫) | 涉及实验/代码改动/迭代的会话中的日常管理; 项目无关会话不介入 |
| `agentspace-init` | 仅显式 | 初始化工作区 — 唯一入口, 幂等; 分析项目后询问 goal/运行环境/关键代码仓库 |
| `agentspace-update` | 仅显式 | 把工作区迁移到当前插件版本; 默认保守, `--force` 激进 |
| `agentspace-doctor` | 仅显式 | 深度健康检查: 确定性一致性 + `--minor` 逐文件审查 + `--major` 跨历史审计 + `--fix` 分级修复; 绝不自动触发 |
| `agentspace-status` | 仅显式 | 状态工作台: 项目总览 + 现状 + 软告警(现状快照, 无"下一步"叙述) |
| `agentspace-mode` | 仅显式 | 工作区模式切换(默认 hybrid / standalone); 管理外部依赖白名单 |
| `agentspace-handoff` | 仅显式 | 一次性会话交接: 收尾时 produce 上下文快照, 下次会话 consume(读后即删) |
| `agentspace-code-clean` | 场景触发 — 登记仓库每次 commit 前 | commit 门与卫生规范: 暂存文件、新增代码/注释行与 message 草稿都必须先过 `AGENTSPACE/scripts/commit-check.sh`; 记账 id 与实验产物永不进入代码仓库 |
| `agentspace-parallel` | 场景触发 — 多 plan 并行推进时 | 本地 PR-like 并行工作区: 每个 plan 一条泳道(`worktrees/<plan-id>/<仓库名>/`, 分支 `plan-<id>`)从记录在案的主线基点切出; 实施与验证全部在泳道内完成; 用户确认后 CAS squash 合回 — 主线恰好落一个 commit; 纯本地, push 仍是用户显式动作; 多 agent 协同经 `AGENTSPACE/scripts/parallel-workspace.sh`(共享 plan 状态表 doing/test/merge + 异步便签) |
| `agentspace-better-exp` | 场景触发 — 用户选择登记实验之后(显式要求走 agentspace-exp 或接受提议) | 实验设计讯问(x-grilling 实验特化版): 每次一问, 沿五轴推进 — 范围、基线与对照公平、测量准确(指标定义/迭代数与 warmup/计时口径/种子与方差)、数据完整、可复现与终止判据 — 每问附推荐答案; 事实查环境不问用户; 共识确认后才行动。绝不自动登记实验; 开发收尾的正确性验证不经用户确认不入册 |
| `agentspace-better-exp-report` | 场景触发 — 基于已记录实验数据写报告/总结/图时 | 报告写作规范: 先复用项目 `utils/` 的做图工具; 色盲友好配色且全套图一套系列-颜色映射、坐标轴带单位、误差棒注明 n; 文字规则 — 中文为主保留公认英文术语、不用"门/臂"等歧义单字缩称、完整优先于精简、自完备为核心规则(阅读者看不到 agent 的记忆: 每个符号首次出现即定义, 每个结论标注图与数据路径) |

### 命令(ZCode 便捷入口)

ZCode 上每个显式 skill 另有斜杠命令, 经命令的 `skills:` 前置字段委托给对应 skill; 无斜杠命令的平台直接让 agent 运行对应 skill — 如"用 --minor 跑 agentspace-doctor"。

```text
/agentspace-init                                # 初始化            (skill agentspace-init)
/agentspace-update [--force]                    # 迁移工作区        (skill agentspace-update)
/agentspace-doctor [--minor | --major] [--fix]  # 深度健康检查      (skill agentspace-doctor)
/agentspace-status                              # 状态工作台        (skill agentspace-status)
/agentspace-mode                                # 模式控制          (skill agentspace-mode)
/agentspace-handoff-produce [--name <名>] [--description <说明>]  # 会话收尾(skill agentspace-handoff)
/agentspace-handoff-consume [--name <名>] [--keep]                # 会话开始(skill agentspace-handoff)
```

之后, agent 在涉及实验/代码改动/迭代的会话中自动管理工作区:

```bash
AGENTSPACE/scripts/new-plan.sh "baseline reproduction"
AGENTSPACE/scripts/new-iteration.sh 1 "跑通训练 pipeline"
AGENTSPACE/scripts/close-iteration.sh 1 "acc=0.91, 达标"
AGENTSPACE/scripts/complete-plan.sh 1 done "复现成功"
AGENTSPACE/scripts/new-exp.sh "latency benchmark" --plan 1 --iteration 1     # 主动登记的实验记录(配置 → examples/exp_spec/)
AGENTSPACE/scripts/complete-exp.sh 1 done "baseline 42ms vs 优化后 31ms" --commit "myrepo@a1b2c3d"
AGENTSPACE/scripts/status.sh      # 状态摘要
AGENTSPACE/scripts/doctor.sh      # 一致性检查/修复
```

plan 标题必须能产出合规文件名 slug — 只接受小写英文词、数字与单连字符(空格转为连字符; 含中文/大写/标点的标题在任何写入前被硬拒, 且不消耗 id); iteration 标题自由。

一次性交接在任何会话都可用, 不要求有进行中 plan: `/agentspace-handoff-produce` 采用语义命名 — 冲突会拒绝, 绝不自动改名。doctor 审计该模块(残留一致性、过时 — 超 7 天未消费只报告, 绝不自动删除); `AGENTSPACE/scripts/status.sh` 列出待消费 handoff。

## 关键代码仓库与 commit 规范

实验型项目通常在台账之外还有若干关键代码仓库。AGENTSPACE 让代码仓库保持干净, 记账全部留在工作区:

- **登记处**: 关键仓库登记在 `AGENTSPACE/.agentspace-repos`(一行一路径; 登记/出册始终须用户显式确认, 只能由 `scripts/repos.sh` 改写)
- **commit 门(MUST)**: 在登记仓库执行任何 `git commit` 前, agent 先运行 `AGENTSPACE/scripts/commit-check.sh <仓库> "<message>"`, 仅 PASS 才提交。阻断项: message **与新增代码/注释行**中的记账 id(`plan:NNNN` / `iteration_NNNN` / `exp_NNNN` 及变体拼写)、实验输出特征(`events.out.tfevents.*`、顶层 `wandb/` `mlruns/` `lightning_logs/`)、≥50MB blob、任何 `AGENTSPACE/` 内容泄漏进代码仓库。被阻断的实验产物移入本轮 iteration 的 `data/` 而非删除
- **commit 文本质量**: 标题=对实际改动的一句话描述 — 无实验/run 标识、无记账叙述; 归属由 iteration readme 的宿主起始/结束 commit SHA 承担, 永不进入代码仓库
- **事后审计**: `scripts/doctor.sh`(关键仓库登记一致性、近期 commit 纪律审计)加上 `/agentspace-doctor`, 报告违规 — 只报告, 绝不自动改写历史

## 插件结构

```
.zcode-plugin/plugin.json         # ZCode 清单
.codex-plugin/plugin.json         # Codex 清单
kimi.plugin.json                  # Kimi 清单
marketplace.json                  # 市场清单
.agents/plugins/marketplace.json    # Agents 插件市场清单
icons/icon.png                    # 市场图标
commands/                         # ZCode 斜杠命令(轻量包装, 经 skills: 前置字段委托给 skill)
├── agentspace-init.md
├── agentspace-update.md
├── agentspace-doctor.md
├── agentspace-status.md
├── agentspace-mode.md
├── agentspace-handoff-produce.md
└── agentspace-handoff-consume.md
skills/                           # 功能交付单元 — 跨平台可移植
├── agentspace/                   # 日常管理(自动触发, 带守卫)
├── agentspace-init/              # 初始化(仅显式)+ init 脚本 + 全部模板 assets
├── agentspace-update/            # 更新/迁移(仅显式)+ 版本档案 + DEVELOPMENT.md
├── agentspace-doctor/            # 深度审计(仅显式)
├── agentspace-status/            # 状态工作台(仅显式)
├── agentspace-mode/              # 模式控制(仅显式)
├── agentspace-handoff/           # 会话交接(仅显式)
├── agentspace-code-clean/        # 登记关键仓库的 commit 门与卫生规范(场景触发, 无命令包装)
├── agentspace-parallel/          # 本地 PR-like 并行工作区(场景触发, 无命令包装)
├── agentspace-better-exp/        # 实验设计讯问(场景触发, 无命令包装)
└── agentspace-better-exp-report/ # 实验报告/作图写作规范(场景触发, 无命令包装)
tests/  self-test.sh  verify-release.sh  rehearse-update.sh  new-version.sh  push-retry.sh   # 发布工具(仓库侧, 不随插件分发)
```

## 版本管理

每个插件版本在 `skills/agentspace-update/versions/` 下维护版本档案(`CHANGELOG.md` + `architecture.json`)。`/agentspace-update` 命令使用这些档案迁移工作区, 由 agent 分析变更, 支持保守模式(破坏性变更需确认)和激进模式。

详见 `skills/agentspace-update/DEVELOPMENT.md`(英文)获取添加新版本的贡献指南。

## 版本历史

| 版本 | 日期 | 更新内容 |
| --- | --- | --- |
| v1.3.0 | 2026-09-08 | 实验记录(agentspace-exp): 新增内置 `exp` 模块 — `exp.md` 入口视图 + `exp/{index.md, todo/, doing/, done/, exp_data/exp_NNNN/}` 与三个脚本(`new-exp.sh` / `start-exp.sh` / `complete-exp.sh`); 登记仅限主动(用户显式要求走 agentspace-exp 或接受一次性提议 — 开发收尾的正确性验证绝不自动登记); 每个登记 exp 的配置必须写入 `examples/exp_spec/exp_NNNN/`(complete-exp 对空目录拒绝关闭), 完整实验记录本机全量保存在 exp_data(关联 iteration 的 data/ 复制一份); 索引关联 plan/iteration、测试用 commit 点(repo@sha)与配置文件名; commit 门禁令扩展 `exp_0NNN`(message + 新增行); doctor [16] exp 一致性(--fix 下节↔目录对账) + notes 接受 `exp_NNNN` 来源; status 工作台展示 exp 计数/Doing/事件; 两个新 skill — agentspace-better-exp(开跑前五轴实验设计讯问)与 agentspace-better-exp-report(作图规范 + 自完备文字规则); verify [8] 覆盖两新 skill(并补 handoff), [12] 守卫 exp 实字面量, [13] 强制 exp_data gitignore 合同 |
| v1.2.5 | 2026-09-08 | agentspace-code-clean 英文 description 从 1094 字符裁剪到 890 — 宿主对 skill description 强制 1024 字符上限, 超长即拒绝加载; 仅删正文已详述的冗余细节(禁令逐字展开、扩网分隔符示例、批量审查实现形容词), 触发关键信息全保留(何时激活/commit-check.sh 门/未登记禁 commit/候选仅报告/批量审查仅显式); 中文 description(528 字符)不超标未动; 仅插件侧 skill 文本, 无工作区/结构变更 |
| v1.2.4 | 2026-09-08 | SKILL.md 前置 YAML 修复(用户实证): 三份 description 含 `): ` 冒号+空格序列 — 无引号 YAML 纯量内的 mapping 指示符 — 导致 PyYAML 宿主报 "mapping values are not allowed in this context"、skill 无法加载; 改写为 `) —`(agentspace-code-clean 双语)与 `激活 — (1)`(agentspace 中文版, 与英文版 em-dash 风格对齐), 词语零变化仅标点; 发布门新增 [14] 检查(真实 PyYAML 解析全部 skill/命令前置块, t14 补反向用例), 此类缺陷不再可能发布; 仅插件侧 skill 文本, 无工作区/结构变更 |
| v1.2.3 | 2026-09-08 | parallel-workspace.sh 三处修复(audit + expert 咨询): MERGELOCK 戳解析补 GNU `date -d` 回退(修复 stale-merge 接管在 Linux 上静默失效 — BSD 专有的 `date -j -f` 报错被吞、卡死的 merge 槽每次都退化为 60s 等待 + 手动恢复); 自由文本字段以反斜杠结尾在解析期硬拒(exit 3 — 尾随 `\` 会与行内 `\|` 分隔符融合, 下一次读改写把 desc/info 两列静默合并); 幂等 `--merge` 现在重写 MERGELOCK 戳 — 语义变更: 15 分钟 stale 窗改为按持有者最后一次 merge 活动起算(重入即 proof-of-life, 阈值只检测死亡、不再误杀超长 merge); 仅脚本面(由 step 8a 自动替换), 无结构/AGENTS.md 变更 |
| v1.2.2 | 2026-09-08 | as_lock 三处加固(expert 审查驱动的安全修复): 获取等待上限(`AS_LOCK_TIMEOUT_SECONDS`, 默认 120s — 存活超过上限的持有者必是卡死的 writer, 等待者报出 pid 后 exit 非 0, stale 接管不受此限)、mkdir 后先写占位 pid 收窄无 trap 崩溃窗口(该窗口留下的锁可被立即 stale 接管, 不必幽灵等满 mtime 宽限)、pid 复用 mtime 二级宽限(`AS_LOCK_STALE_HOURS`, 默认 6h — 锁 mtime 即获取时刻且持有期不刷新, 老锁上的活 pid 必是复用 pid); 两条常量 env 可预置、数值消毒、readonly, 已录入 architecture.json; 仅脚本面(由 step 8a 自动替换), 无结构/AGENTS.md 变更 |
| v1.2.1 | 2026-09-07 | new-plan slug 硬校验: plan 标题必须产出合规 slug(小写英文词、数字、单连字符); 中文/大写/下划线/尾连字符/空 slug 标题在任何写入前被硬拒且不消耗 id — 只对未来新建生效, 存量 plan 文件与索引行不动 |
| v1.2.0 | 2026-09-07 | 协同 agent workspace: 新增 `AGENTSPACE/scripts/parallel-workspace.sh` — 共享 plan 状态表(doing/test/merge)+ 异步便签, 单把文件锁 + 原子写, merge 槽全表独占(短窗铁律)+ 15 分钟 MERGELOCK stale 接管; 数据文件 `.agentspace-parallel-workspace.txt`(台账内, gitignore)+ agentspace-parallel skill 四项增强: 固定 worktree 路径 MUST、主线历史改写探测(其本身绝不构成冻结)、合回前后双报告层挂点、§6.5 协同表登记 |
| v1.1.0 | 2026-09-07 | AGENTS.md 新增用户所有的 用户规则 节 + 纪律 新增两条 MUST(用户规则守护 / 注释卫生; 经 /agentspace-update step 8b 一次性拆分迁移)+ commit 门新增只报告的扩网候选(plan/iteration 词与数字相邻、任意分隔符 — 永不阻断, 由 agent 逐条裁决并给出理由)+ doctor --major 新增块 6/7(notes 内容质量审核带证据链; 跨 plan 冲突审核 — 重复/交叠明确不算发现)+ code-clean 新增批量注释审查(全文件、多 subagent、只报告、仅显式触发) |
| v1.0.1 | 2026-09-05 | agentspace-parallel 行为修正: 改动面交集(文件级或语义级)不再阻塞准入 — §2 交集扫描降级为纯信息动作; 唯一阻塞点钉死在合回(§7h: 冲突 hunk / 退役面命中 / 结构性 absorb / 重测失败任一 → 冻结 merge, 与用户讨论处理计划后泳道内更新重测) |
| v1.0.0 | 2026-09-05 | 新 skill `agentspace-parallel` — 本地 PR-like 并行工作区(按 plan 一条泳道、泳道内验证、CAS squash 合回主线恰好一个 commit, 纯本地)+ plan/iteration 创建脚本锁先于 id 分配的竞态修复 + doctor 并行工作区审计覆盖 + status 泳道去重 + plan 模板改动面声明节与 iteration 模板 PR 簿记指引 |
| v0.6.4 | 2026-09-01 | commit 门记账 id 禁令扩展到新增 diff 行(代码注释/字符串字面量; 删除行永不阻断)+ doctor 新增行内容事后审计 + rubric skill 更名 agentspace-commit → agentspace-code-clean(脚本名 commit-check.sh 不变)+ 发布工具自食防护(verify-release 常量反向校验与已实现字面量守卫) |
| v0.6.3 | 2026-08-19 | 新增 Kimi 兼容清单(`kimi.plugin.json`)并纳入三清单版本同步与发布校验; 共享 skill description、正文、工作区 assets 与命令行为保持不变 |
| v0.6.2 | 2026-08-16 | 新增 Codex 强制插件清单与发布校验; 共享 skill description、正文、工作区 assets 与命令行为保持不变 |
| v0.6.1 | 2026-08-15 | commit 文本质量: 门 + doctor 空标题规则(lib.sh 单源)+ agentspace-commit 质量 rubric(标题=一句话改动描述, 无实验/run 标识, 标题/正文须与 diff 相关)+ doctor 三维 commit 审计 |
| v0.6.0 | 2026-08-15 | commit 规范: 关键代码仓库登记处(.agentspace-repos + repos.sh, 登记须用户确认)+ agentspace-commit skill + commit-check.sh 门 + doctor 登记一致性与 commit 事后审计 + status 关键代码仓库分区 + init 登记步骤 + standalone 白名单豁免 |
| v0.5.3 | 2026-08-11 | status 近期动态四分区分层(主线软槽 / 宿主代码提交 / 工作区事件 / 台账)+ 会话入口"最近关闭"锚点 + `/agentspace-status` 版本闸门 + 三方验证修复 |
| v0.5.2 | 2026-08-07 | `/agentspace-mode` 命令: 工作区模式控制(默认 hybrid / standalone)+ 外部依赖白名单(.agentspace-whitelist, 大文件 ≥1G 自动豁免、小文件须用户显式确认)+ doctor standalone 外部引用检查(minor 面, --fix 只自动白名单大文件)+ AGENTS.md 模式标记块 |
| v0.5.1 | 2026-08-06 | 风险审计修复: complete-plan ENVIRON+shield、doctor 守卫/id 归一化/latest FIX 门控、handoff consume 双匹配、update-version 原子写、python 3.6 兼容、索引追加原子化 + 回归测试 + 脚本模式纪律 + status 近期动态事件流+提交摘要 |
| v0.5.0 | 2026-08-06 | status 工作台: `/agentspace-status` 命令 + skill(硬脚本聚合、严格模板、子代理项目段落)+ status.sh 重写(总览/版本环境/推进总览转义感知/近期动态 10 条/软告警形状校验/handoff)+ `\|` 转义感知修复(close-iteration index 改写、as_row_cell)+ zh-CN 文档同步(示例数字、两段式验证闸门)+ 架构 subsections 补全 + 回归测试 |
| v0.4.1 | 2026-08-05 | handoff doctor 审计(残留一致性、过时)+ status 摘要 + cleanup 批量(--list \| 修复、close 自动 diff、doctor 登记一致性检查、--keep 标记)+ 风险审计修复 + bash 生态硬化(环境闸门、LC_ALL=C)+ 升级链 GAP 修复 + 全链重放回归测试 |
| v0.4.0 | 2026-08-05 | handoff 模块(一次性会话交接: produce/consume)+ 命令统一为 `/agentspace-*` 前缀(破坏性) |
| v0.3.3 | 2026-08-05 | 24h review 加固: 原子写补全、update-version 锚点 legacy 化、`--fix` 标题容错 + 失败可见 |
| v0.3.2 | 2026-08-05 | 教训提炼升级为 MUST; 更新迁移台账(逐项 已应用/跳过) |
| v0.3.1 | 2026-08-05 | doctor 链接级回链 + 版本元数据检查; ID 并集扫描; update-version cwd 修复; status 推进总览; init 自检 |
| v0.3.0 | 2026-08-04 | `/agentspace-doctor` 深度健康检查(确定性核心 + 逐文件审查 + 跨历史审计, 分级 `--fix`) |
| v0.2.12 | 2026-08-04 | notes↔iteration 回链纪律 |
| v0.2.11 | 2026-08-04 | 更新流程加固(skill 文本) |
| v0.2.10 | 2026-08-02 | 外部审计修复版(5 项发现) |
| v0.2.9 | 2026-08-02 | 日常 skill 精简; 中文 skill 修复 |
| v0.2.8 | 2026-08-02 | iteration readme 自动记录宿主起始/结束 commit |
| v0.2.7 | 2026-08-02 | 知识提炼流程(SHOULD); notes 增加标签列 |
| v0.2.6 | 2026-08-02 | doctor 续接块新鲜度 + 占位符漂移检查 |
| v0.2.5 | 2026-08-02 | 收尾协议 + 结果节质量闸门 + MUST 规则分级 |
| v0.2.4 | 2026-08-02 | 修复 v0.2.3 模板回归(重复节) |
| v0.2.3 | 2026-08-02 | iteration 重新定义为代码/状态变更步骤; 模板改 代码变更 |
| v0.2.2 | 2026-08-02 | 脚本改英文; 修复 CJK slug 截断 |
| v0.2.1 | 2026-08-02 | data + examples 模块 |
| v0.2.0 | 2026-07-31 | skill 以英文为主; `/agentspace-update` 变更日志驱动迁移 |
| v0.1.0 | 2026-07-31 | 初始版本: plan + iteration 双主线、入口视图、scripts 独占索引 |

各版本详细变更与迁移指引见 `skills/agentspace-update/versions/`。

## License

MIT
