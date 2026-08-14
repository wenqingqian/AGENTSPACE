# AGENTSPACE

面向实验/迭代型项目的 **git 管理 agent 工作区** ZCode 插件。

通过显式 `/agentspace-init` 在项目根目录初始化 `AGENTSPACE/`(独立 git 仓库) + 项目根 `AGENTS.md` 引导文件; 之后 agent 在涉及实验/代码改动/项目迭代的会话中自动按规范维护工作区状态, 并在里程碑时自动提交。

## 核心概念

- **plan → iteration 严格一对多**: 一个任务写成一个或多个 plan(全局递增索引, 永不复用); 每个 iteration 是 plan 内的一次代码/状态变更, 必属且仅属一个 plan
- **入口是视图, 文件系统是真源**: `plan.md`/`iterations.md` 只维护 Todo + 最近 10 条 Done; 完整历史在 `plan/index.md`/`iterations/index.md`; 所有索引由 `AGENTSPACE/scripts/` 下的脚本改写, agent 不手编表格
- **内容文档由 agent 撰写**: plan 文档、iteration readme、notes 等使用 `templates/` 模板直接生成
- **实验产物全量本地保存**: `iteration_NNNN/data/` 已 gitignore, 不入 git

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
    ├── templates/  scripts/  .gitignore
```

## 安装

将本仓库作为 ZCode 插件安装(插件市场或本地插件目录), 启用后即可使用。

## 使用

```text
/agentspace-init              # 显式初始化(唯一入口, 幂等; 分析工作区后询问 goal/运行环境/关键代码仓库)
/agentspace-update [--force]  # 更新工作区至插件版本(默认保守, --force 激进)
/agentspace-doctor [--minor | --major] [--fix]  # 深度健康检查(仅显式命令触发, 绝不自动触发)
/agentspace-handoff-produce [--name <名>] [--description <说明>]  # 会话收尾: 写入一次性上下文快照
/agentspace-handoff-consume [--name <名>] [--keep]  # 会话开始: 读取 handoff, 读后删除
/agentspace-status          # 状态工作台: 项目总览 + 现状 + 软告警(现状快照, 无"下一步"叙述)
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

## 插件结构

```
.zcode-plugin/plugin.json        # 清单
commands/agentspace-init.md      # /agentspace-init 命令
commands/agentspace-update.md    # /agentspace-update 命令
commands/agentspace-doctor.md    # /agentspace-doctor 命令(深度健康检查)
commands/agentspace-handoff-produce.md  # /agentspace-handoff-produce 命令(会话收尾)
commands/agentspace-handoff-consume.md  # /agentspace-handoff-consume 命令(会话开始)
skills/agentspace-init/          # 初始化 skill(仅命令显式触发) + init 脚本 + 全部模板 assets
skills/agentspace-update/        # 更新 skill + 版本档案 + 更新脚本
skills/agentspace/               # 日常管理 skill(自动触发, 带守卫)
skills/agentspace-doctor/        # 深度审计 skill(仅显式命令触发, 绝不自动触发)
skills/agentspace-handoff/       # handoff skill(仅显式命令触发, 绝不自动触发)
```

## 版本管理

每个插件版本在 `skills/agentspace-update/versions/` 下维护版本档案(`CHANGELOG.md` + `architecture.json`)。`/agentspace-update` 命令使用这些档案智能迁移工作区, 由 agent 分析变更, 支持保守模式(破坏性变更需确认)和激进模式。

详见 `skills/agentspace-update/DEVELOPMENT.md`(英文)获取添加新版本的贡献指南。

## 版本历史

| 版本 | 日期 | 更新内容 |
| --- | --- | --- |
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
