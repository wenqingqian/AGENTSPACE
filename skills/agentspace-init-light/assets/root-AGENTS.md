# {{PROJECT_NAME}}

## 项目背景

<!-- 一句话: 这个项目主要干什么(实现/维护什么功能, 优化什么, 达到什么效果) -->

## 关键代码仓库

<!-- 与项目强相关的代码仓库(路径 + 职责 + 关键入口文件/目录);
     工作区常有多个仓库, 这些是开工前必读的核心入口 -->

## AGENTSPACE

本项目的任务计划由 `AGENTSPACE/` 管理(独立 git 仓库, light 版): 仅 plan(任务计划) 模块 — 含 base plan(基准计划)。

### 何时读取 AGENTSPACE/AGENTS.md

对话涉及本项目的**任务计划、项目迭代安排或状态查询/变更**时 → 先读 `AGENTSPACE/AGENTS.md` 并按其规则工作。

### 何时不必读取

与本项目无关的问答、闲聊、无状态变化的纯查询, 且用户未明确要求使用 AGENTSPACE 时。

### 硬规则

- AGENTSPACE 初始化只通过显式命令(/agentspace-init 或 /agentspace-init-light), 绝不自动创建
- AGENTSPACE 的索引/条目状态(plan.md、plan/index.md)只能由 `AGENTSPACE/scripts/` 下的脚本改写; 当前为 light 工作区(仅 plan 模块), iterations/exp 等流程不可用, 需要时运行 /agentspace-update 扩展为完整工作区
- 基准计划(base plan, plan/base/)文件一经激活不可修改; 发现基准不可实现或有正确性错误必须显式告知用户, 方向变更由用户决定; 基准计划的创建与修改呈交用户审核 — 草稿写好后直接结束会话, 用户在文件上评论反馈
- commit 门: 在已登记关键代码仓库(AGENTSPACE/.agentspace-repos)执行 `git commit` 前, 必须先运行 `AGENTSPACE/scripts/commit-check.sh <仓库> "<message>"` 并通过; 未登记仓库先登记(用户确认)后提交
- 代码/注释/commit 文本卫生遵循 agentspace-code-clean 规则(默认被动层); 对既有代码/历史的清理与重建仅在用户显式要求时执行
- 禁止读取插件开发数据: `skills/agentspace-update/versions/`、`DEVELOPMENT.md`、`marketplace.json` 等与项目无关, 不在 AGENTSPACE 管理范围内
