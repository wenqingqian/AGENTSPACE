# {{PROJECT_NAME}}

## 项目背景

<!-- 一句话: 这个项目主要干什么(实现/维护什么功能, 优化什么, 达到什么效果) -->

## 实验环境

<!-- 容器 / conda / GPU 等一句话; 详情见 AGENTSPACE/tests.md -->

## 关键代码仓库

<!-- 与项目强相关的代码仓库(路径 + 职责 + 关键入口文件/目录);
     工作区常有多个仓库, 这些是开工前必读的核心入口 -->

## AGENTSPACE

本项目的实验与迭代状态由 `AGENTSPACE/` 管理(独立 git 仓库): plan(任务计划)、iterations(代码变更迭代)、exp(实验记录)、utils(复用工具)、tests(环境与测试)、notes(知识)。

### 何时读取 AGENTSPACE/AGENTS.md

对话涉及本项目的**实验、代码改动、项目迭代或状态查询/变更**时 → 先读 `AGENTSPACE/AGENTS.md` 并按其规则工作(它会引导你读取 tests.md、iterations.md 等入口文件)。

### 何时不必读取

与本项目无关的问答、闲聊、无状态变化的纯查询, 且用户未明确要求使用 AGENTSPACE 时。

### 硬规则

- AGENTSPACE 初始化只通过显式 `/agentspace-init` 命令, 绝不自动创建
- AGENTSPACE 的索引/条目状态(plan.md、iterations.md、exp.md、各 index.md)只能由 `AGENTSPACE/scripts/` 下的脚本改写; 实验(exp)只在用户显式要求走 /agentspace-exp(命令或同名触发器 skill)或经确认提议后登记, 设计对齐走 agentspace-better-exp、报告走 agentspace-better-exp-report
- commit 门: 在已登记关键代码仓库(AGENTSPACE/.agentspace-repos)执行 `git commit` 前, 必须先运行 `AGENTSPACE/scripts/commit-check.sh <仓库> "<message>"` 并通过; 未登记仓库先登记(用户确认)后提交
- 禁止读取插件开发数据: `skills/agentspace-update/versions/`、`DEVELOPMENT.md`、`marketplace.json` 等与项目无关, 不在 AGENTSPACE 管理范围内
