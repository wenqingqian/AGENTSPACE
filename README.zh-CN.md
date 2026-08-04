# AGENTSPACE

面向实验/迭代型项目的 **git 管理 agent 工作区** ZCode 插件。

通过显式 `/init-agentspace` 在项目根目录初始化 `AGENTSPACE/`(独立 git 仓库) + 项目根 `AGENTS.md` 引导文件; 之后 agent 在涉及实验/代码改动/项目迭代的会话中自动按规范维护工作区状态, 并在里程碑时自动提交。

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
    ├── .agentspace-version.json       # 工作区版本追踪
    ├── .agentspace-architecture.json  # 当前架构快照
    ├── templates/  scripts/  .gitignore
```

## 安装

将本仓库作为 ZCode 插件安装(插件市场或本地插件目录), 启用后即可使用。

## 使用

```text
/init-agentspace              # 显式初始化(唯一入口, 幂等; 分析工作区后询问 goal/运行环境/关键代码仓库)
/update-agentspace [--force]  # 更新工作区至插件版本(默认保守, --force 激进)
/doctor-agentspace [--minor | --major] [--fix]  # 深度健康检查(仅显式命令触发, 绝不自动触发)
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

需要更深的审计(逐文件内容审查 `--minor` / 跨历史对照宿主仓库 `--major` / 分级修复 `--fix`)时, 显式运行 `/doctor-agentspace` 命令; 该命令绝不自动触发。

## 插件结构

```
.zcode-plugin/plugin.json        # 清单
commands/init-agentspace.md      # /init-agentspace 命令
commands/update-agentspace.md    # /update-agentspace 命令
commands/doctor-agentspace.md    # /doctor-agentspace 命令(深度健康检查)
skills/agentspace-init/          # 初始化 skill(仅命令显式触发) + init 脚本 + 全部模板 assets
skills/agentspace-update/        # 更新 skill + 版本档案 + 更新脚本
skills/agentspace/               # 日常管理 skill(自动触发, 带守卫)
skills/agentspace-doctor/        # 深度审计 skill(仅显式命令触发, 绝不自动触发)
```

## 版本管理

每个插件版本在 `skills/agentspace-update/versions/` 下维护版本档案(`CHANGELOG.md` + `architecture.json`)。`/update-agentspace` 命令使用这些档案智能迁移工作区, 由 agent 分析变更, 支持保守模式(破坏性变更需确认)和激进模式。

详见 `skills/agentspace-update/DEVELOPMENT.md`(英文)获取添加新版本的贡献指南。

## License

MIT
