# AGENTSPACE

## 项目背景

AGENTSPACE — 跨平台插件, 为实验/迭代型项目提供 git 管理的 agent 工作区; 源码在 `skills/` 与 `commands/`, 入口文档 `README.md` / `README.zh-CN.md`, 开发台账在 `AGENTSPACE/`。

## 实验环境

无容器/conda/GPU — 纯 bash + python3 脚本项目; 发布验证走 `self-test.sh` 与 `verify-release.sh`(详见 AGENTSPACE/tests.md)。

## AGENTSPACE

本项目的实验与迭代状态由 `AGENTSPACE/` 管理(独立 git 仓库): plan(任务计划)、iterations(实验轮次)、exp(实验记录)、utils(复用工具)、tests(环境与测试)、notes(知识)。

### 何时读取 AGENTSPACE/AGENTS.md

对话涉及本项目的**实验、代码改动、项目迭代或状态查询/变更**时 → 先读 `AGENTSPACE/AGENTS.md` 并按其规则工作(它会引导你读取 tests.md、iterations.md 等入口文件)。

### 何时不必读取

与本项目无关的问答、闲聊、无状态变化的纯查询, 且用户未明确要求使用 AGENTSPACE 时。

### 硬规则

- AGENTSPACE 初始化只通过显式 `/agentspace-init` 命令, 绝不自动创建
- AGENTSPACE 的索引/条目状态(plan.md、iterations.md、exp.md、各 index.md)只能由 `AGENTSPACE/scripts/` 下的脚本改写; 实验(exp)只在用户显式要求走 agentspace-exp 或经确认提议后登记
- commit 门: 在已登记关键代码仓库(AGENTSPACE/.agentspace-repos)执行 `git commit` 前, 必须先运行 `AGENTSPACE/scripts/commit-check.sh <仓库> "<message>"` 并通过; 未登记仓库先登记(用户确认)后提交
