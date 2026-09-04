# AGENTSPACE

面向实验/迭代型项目的 **git 管理 agent 工作区** 跨平台插件。

全部功能以 agent skill 交付 — 三个受支持平台(ZCode / Codex / Kimi)都从 `skills/` 加载; 支持斜杠命令的平台(ZCode)额外获得委托给 skill 的轻量 `/agentspace-*` 命令包装。通过显式初始化(ZCode: `/agentspace-init`; 其他平台: 让 agent 运行 `agentspace-init` skill)在项目根目录创建 `AGENTSPACE/`(独立 git 仓库) + 项目根 `AGENTS.md` 引导文件; 之后 agent 在涉及实验/代码改动/项目迭代的会话中自动按规范维护工作区状态, 并在里程碑时自动提交。

## 核心概念

- **plan → iteration 严格一对多**: 一个任务写成一个或多个 plan(全局递增索引, 永不复用); 每个 iteration 是 plan 内的一次代码/状态变更, 必属且仅属一个 plan
- **入口是视图, 文件系统是真源**: `plan.md`/`iterations.md` 只维护 Todo + 最近 10 条 Done; 完整历史在 `plan/index.md`/`iterations/index.md`; 所有索引由 `AGENTSPACE/scripts/` 下的脚本改写, agent 不手编表格
- **内容文档由 agent 撰写**: plan 文档、iteration readme、notes 等使用 `templates/` 模板直接生成
- **实验产物全量本地保存**: `iteration_NNNN/data/` 已 gitignore, 不入 git
- **关键代码仓库 commit 规范**: 关键仓库登记在 `.agentspace-repos`(登记须用户确认); 每次 commit 前必须先通过 `commit-check.sh` 门 — 记账 id 与实验产物永不泄漏进代码仓库(见下文"关键代码仓库与 commit 规范")

## 工作区结构

```
<项目>/
├── AGENTS.md                  # 根引导: 项目背景 + 实验环境 + 关键代码仓库 + 何时读取规则
└── AGENTSPACE/                # 独立 git 仓库
    ├── AGENTS.md              # 核心入口: 结构/模块 what-when-how/纪律
    ├── plan.md                # 入口: Todo + Done(最近10条, 完成/失败/放弃)
    ├── plan/{index.md, todo/, done/}
    ├── iterations.md          # 入口: 进行中 + 最近完成(10条)
    ├── iterations/{index.md, latest→, iteration_NNNN/{readme.md, data/}}
    ├── data.md + data/        # 公用数据(训练集/模型权重/软连接; 大文件 gitignore)
    ├── examples.md + examples/ # 可复用实验配置(YAML/JSON); 与 tests/ 配合
    ├── utils.md + utils/      # 复用工具(做图/机器状态/日志分析...)
    ├── tests.md + tests/      # 实验环境(容器/conda/GPU) + 测试脚本
    ├── notes.md + notes/      # 持久知识(带来源证据)
    ├── register.md            # 按需扩展模块(项目特定扩展)
    ├── handoff/               # 一次性会话交接(index.md 入 git; handoff_*.md 一次性, gitignore)
    ├── .agentspace-version.json       # 工作区版本追踪
    ├── .agentspace-architecture.json  # 当前架构快照
    ├── .agentspace-repos              # 关键代码仓库登记处(只能由 scripts/repos.sh 改写)
    ├── .agentspace-whitelist          # 外部依赖白名单(standalone 模式)
    ├── templates/  scripts/  .gitignore
```

## 安装

通过所在平台支持的插件机制安装并启用本仓库。本仓库同时包含三个受支持平台(ZCode / Codex / Kimi)的原生清单；安装始终由用户执行。

## 使用

### Skill(全平台)

Skill 是功能交付单元 — 在所有受支持平台上行为一致。标注"仅显式"的功能只在用户点名时触发(在 ZCode 上也可用下方命令), 绝不自动触发。

| Skill | 触发方式 | 功能 |
| --- | --- | --- |
| `agentspace` | 自动(带守卫) | 涉及实验/代码改动/迭代的会话中的日常管理; 项目无关会话不介入 |
| `agentspace-init` | 仅显式 | 初始化工作区 — 唯一入口, 幂等; 分析工作区后询问 goal/运行环境/关键代码仓库 |
| `agentspace-update` | 仅显式 | 把工作区迁移到当前插件版本; 默认保守, `--force` 激进 |
| `agentspace-doctor` | 仅显式 | 深度健康检查: 确定性一致性 + `--minor` 逐文件审查 + `--major` 跨历史审计 + `--fix` 分级修复; 绝不自动触发 |
| `agentspace-status` | 仅显式 | 状态工作台: 项目总览 + 现状 + 软告警(现状快照, 无"下一步"叙述) |
| `agentspace-mode` | 仅显式 | 工作区模式切换(默认 hybrid / standalone); 管理外部依赖白名单 |
| `agentspace-handoff` | 仅显式 | 一次性会话交接: 收尾时 produce 上下文快照, 下次会话 consume(读后即删) |
| `agentspace-code-clean` | 场景触发 — 登记仓库每次 commit 前 | commit 门与卫生规范: 暂存文件、新增代码/注释行与 message 草稿都必须先过 `AGENTSPACE/scripts/commit-check.sh`; 记账 id 与实验产物永不进入代码仓库 |
| `agentspace-parallel` | 场景触发 — 多 plan 并行推进时 | 本地 PR-like 并行工作区: 固定泳道(`worktrees/<plan-id>/<仓库名>/`, 分支 `plan-<id>`)从记录在案的主线基点切出; 实施 + 单测 + e2e 全部在泳道内按预先写定的验收层级完成; 用户确认后 CAS squash 合回 — 主线恰好落一个 PR 名 commit(泳道内部 commit 不进主线; 主线已推进则先 absorb 进泳道重测再合); 纯本地, push 仍是用户显式动作 |

### 命令(ZCode 便捷入口)

ZCode 上每个显式 skill 另有斜杠命令, 经命令前置 `skills:` 字段委托给对应 skill; 无斜杠命令的平台直接让 agent 运行对应 skill — 如"用 --minor 跑 agentspace-doctor"。

```text
/agentspace-init                                # 初始化            (skill agentspace-init)
/agentspace-update [--force]                    # 迁移工作区        (skill agentspace-update)
/agentspace-doctor [--minor | --major] [--fix]  # 深度健康检查      (skill agentspace-doctor)
/agentspace-status                              # 状态工作台        (skill agentspace-status)
/agentspace-mode                                # 模式控制          (skill agentspace-mode)
/agentspace-handoff-produce [--name <名>] [--description <说明>]  # 会话收尾(skill agentspace-handoff)
/agentspace-handoff-consume [--name <名>] [--keep]                # 会话开始(skill agentspace-handoff)
```

之后日常对话中(agent 自动判断, 项目无关会话不介入):

```bash
AGENTSPACE/scripts/new-plan.sh "baseline 复现"
AGENTSPACE/scripts/new-iteration.sh 1 "跑通训练 pipeline"
AGENTSPACE/scripts/close-iteration.sh 1 "acc=0.91, 达标"
AGENTSPACE/scripts/complete-plan.sh 1 done "复现成功"
AGENTSPACE/scripts/status.sh      # 状态摘要
AGENTSPACE/scripts/doctor.sh      # 一致性检查/修复
```

需要更深的审计(逐文件内容审查 `--minor` / 跨历史对照宿主仓库 `--major` / 分级修复 `--fix`)时, 显式运行 `/agentspace-doctor` 命令; 该命令绝不自动触发。

一次性会话交接(`/agentspace-handoff-produce` / `/agentspace-handoff-consume`): 会话收尾时 produce 把上下文快照写入 `AGENTSPACE/handoff/`(语义命名必需——冲突会拒绝, 绝不自动改名); 下个会话 consume 读取后删除。任何会话都可产生, 不要求有进行中 plan。doctor 已覆盖该模块 — [10] 残留一致性(死行/孤儿文件/重复行)与 [11] 过时审核(>7 天未消费; 报告该 handoff 要干什么 — 绝不自动删除或 consume); `AGENTSPACE/scripts/status.sh` 列出待消费 handoff 并带过时标记。

## 关键代码仓库与 commit 规范

实验型项目通常在台账之外还有若干关键代码仓库。AGENTSPACE 让代码仓库保持干净, 记账全部留在工作区:

- **登记处**: 关键仓库登记在 `AGENTSPACE/.agentspace-repos`(一行一路径; 登记/出册始终须用户显式确认, 只能由 `scripts/repos.sh` 改写)
- **commit 门(MUST)**: 在登记仓库执行任何 `git commit` 前, agent 先运行 `AGENTSPACE/scripts/commit-check.sh <仓库> "<message>"`, 仅 PASS 才提交。阻断项: message **与新增代码/注释行**中的记账 id(`plan:NNNN` / `iteration_NNNN` 及变体拼写)、实验输出特征(`events.out.tfevents.*`、顶层 `wandb/` `mlruns/` `lightning_logs/`)、≥50MB blob、任何 `AGENTSPACE/` 内容泄漏进代码仓库。被阻断的实验产物移入本轮 iteration 的 `data/` 而非删除
- **commit 文本质量**: 标题=对实际改动的一句话描述 — 无实验/run 标识、无记账叙述; 归属由 iteration readme 的宿主起始/结束 commit SHA 承担, 永不进入代码仓库
- **事后审计**: `scripts/doctor.sh` [14](登记一致性)与 [15](近期 commit 内容审计), 加上 `/agentspace-doctor`, 报告违规 — 只报告, 绝不自动改写历史

## 插件结构

```
.zcode-plugin/plugin.json         # ZCode 清单
.codex-plugin/plugin.json         # Codex 清单
kimi.plugin.json                  # Kimi 清单
marketplace.json                  # 市场清单
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
└── agentspace-parallel/          # 本地 PR-like 并行工作区(场景触发, 无命令包装)
```

## 版本管理

每个插件版本在 `skills/agentspace-update/versions/` 下维护版本档案(`CHANGELOG.md` + `architecture.json`)。`/agentspace-update` 命令使用这些档案智能迁移工作区, 由 agent 分析变更, 支持保守模式(破坏性变更需确认)和激进模式。

详见 `skills/agentspace-update/DEVELOPMENT.md`(英文)获取添加新版本的贡献指南。

## 版本历史

| 版本 | 日期 | 更新内容 |
| --- | --- | --- |
| v1.0.0 | 2026-09-05 | 新 skill `agentspace-parallel`: 本地 PR-like 并行工作区(固定泳道形态、泳道内 T0-T3 验收分层、CAS squash 合回 — 主线恰好落一个 PR 名 commit, 主线已推进则 absorb 重测后再合, 纯本地)+ 并发竞态修复(plan/iteration 创建脚本锁先于 id 分配, 由新增并发回归测试当场抓获)+ doctor [14] 常规位泳道扫描与 [15] 武装式并行审计(主线 merge commit + 连字符形泳道标识报告, 传统工作流仓库零新增告警)+ status 泳道去重 + plan 模板改动面声明节与 iteration 模板 PR 簿记指引 |
| v0.6.4 | 2026-09-01 | commit 门记账 id 禁令扩展到新增 diff 行(代码注释/字符串字面量; 同一 lib.sh 单源正则与前导零锚定, 删除行永不阻断, rename+edit hunk 经 -M ACMRT 照扫)+ doctor [15] 内容事后审计(按类首命中: message/内容/空标题 三类互不遮蔽, 新增行预算封顶)+ rubric skill 更名 agentspace-commit → agentspace-code-clean(脚本名 commit-check.sh 不变)+ 发布工具自食防护(verify-release [4] 反向 + [12] 已实现字面量守卫) |
| v0.6.3 | 2026-08-19 | 新增 Kimi 兼容清单(`kimi.plugin.json`)并纳入三清单版本同步与发布校验；共享 skill description、正文、工作区 assets 与命令行为保持不变 |
| v0.6.2 | 2026-08-16 | 新增 Codex 强制插件清单与发布校验；共享 skill description、正文、工作区 assets 与命令行为保持不变 |
| v0.6.1 | 2026-08-15 | commit 文本质量: 门 + doctor [15] 空标题规则(lib.sh 单源)+ agentspace-commit skill Commit-text Quality rubric(性质标准: 标题=一句话代码改动描述, 无实验/run 标识, 无无信息标题; 正文解释 why; 标题/正文须与 diff 相关(git show --stat); 类型前缀推荐不强制)+ agentspace-doctor Phase C Block 2 三维审计(记账变体/质量/相关性, sha+维度+建议, 只报告) |
| v0.6.0 | 2026-08-15 | commit 规范: 关键代码仓库登记处(.agentspace-repos + repos.sh, 登记须用户确认)+ agentspace-commit skill + commit-check.sh 门(message 记账 id 禁令 / 实验输出特征 / ≥50MB blob / AGENTSPACE 路径; exit 0/1/2)+ doctor [14] 登记一致性(陈旧行 / 内嵌盾牌 git check-ignore 行为检测 / ls-files+gitlink 泄漏 / 7 天热仓库告警)+ [15] commit 事后审计(最近 20 条, 只报告)+ status 关键代码仓库分区 + 多仓库代码提交(每仓库 3 条, 空登记回退宿主)+ init 登记步骤 + 引导块铁律行 + standalone 白名单对登记仓库豁免 |
| v0.5.3 | 2026-08-11 | status 近期动态四分区分层: 主线软槽 / 宿主仓库代码提交(每 commit stat + 按记录宿主 SHA 关联 iteration + 每 commit 概括软槽)/ 工作区事件 / 台账(分区独立 cap)+ 会话入口"最近关闭"锚点(标题/日期/宿主 SHA)+ `/agentspace-status` 版本闸门(工作区脚本漂移固定警示, 不再静默吐旧格式)+ 三方验证修复(白名单输入规范化、软告警空行、doctor [13] 小文件 note 不计数) |
| v0.5.2 | 2026-08-07 | `/agentspace-mode` 命令: 工作区模式控制(默认 hybrid / standalone)+ 外部依赖白名单(.agentspace-whitelist, 大文件 ≥1G 自动豁免、小文件须用户显式确认)+ doctor [13] standalone 外部引用检查(minor 面, --fix 只自动白名单大文件)+ AGENTS.md 模式标记块 |
| v0.5.1 | 2026-08-06 | 风险审计修复: complete-plan ENVIRON+shield、doctor 守卫/id 归一化/latest FIX 门控、handoff consume 双匹配、update-version 原子写、python 3.6 兼容、索引追加原子化 + t16 回归 + 脚本模式纪律 + status 近期动态事件流+提交摘要 |
| v0.5.0 | 2026-08-06 | status 工作台: `/agentspace-status` 命令 + skill(硬脚本聚合、严格模板、子代理项目段落)+ status.sh 重写(总览/版本环境/推进总览转义感知/近期动态 10 条/软告警形状校验/handoff)+ `\|` 转义感知修复(close-iteration index 改写、as_row_cell)+ zh-CN 文档同步(示例数字、两段式验证闸门)+ 架构 subsections 补全 + t15 回归 |
| v0.4.1 | 2026-08-05 | handoff doctor 审计 [10]/[11] + status 摘要 + cleanup 批量(--list \| 修复、close 自动 diff、doctor [12]、--keep 标记)+ 风险审计修复 + bash 生态硬化(环境闸门、LC_ALL=C)+ 升级链 GAP 修复 + t13 重放测试 |
| v0.4.0 | 2026-08-05 | handoff 模块(一次性会话交接: produce/consume)+ 命令统一为 `/agentspace-*` 前缀(破坏性) |
| v0.3.3 | 2026-08-05 | 24h review 加固: 原子写补全、update-version 锚点 legacy 化、`--fix` 标题容错 + 失败可见 |
| v0.3.2 | 2026-08-05 | 教训提炼升级为 MUST; 更新迁移台账(逐项 已应用/跳过) |
| v0.3.1 | 2026-08-05 | doctor [8] 链接级回链 + [9] 版本元数据; ID 并集扫描; update-version cwd 修复; status 推进总览; init 自检 |
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
