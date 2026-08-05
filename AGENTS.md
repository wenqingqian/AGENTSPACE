# AGENTSPACE

## 项目背景

<!-- 一句话: 这个项目做什么; 关键目录 / 入口 -->

## 实验环境

<!-- 容器 / conda / GPU 等一句话; 详情见 AGENTSPACE/tests.md -->

## AGENTSPACE

本项目的实验与迭代状态由 `AGENTSPACE/` 管理(独立 git 仓库): plan(任务计划)、iterations(实验轮次)、utils(复用工具)、tests(环境与测试)、notes(知识)。

### 何时读取 AGENTSPACE/AGENTS.md

对话涉及本项目的**实验、代码改动、项目迭代或状态查询/变更**时 → 先读 `AGENTSPACE/AGENTS.md` 并按其规则工作(它会引导你读取 tests.md、iterations.md 等入口文件)。

### 何时不必读取

与本项目无关的问答、闲聊、无状态变化的纯查询, 且用户未明确要求使用 AGENTSPACE 时。

### 硬规则

- AGENTSPACE 初始化只通过显式 `/agentspace-init` 命令, 绝不自动创建
- AGENTSPACE 的索引/条目状态(plan.md、iterations.md、两个 index.md)只能由 `AGENTSPACE/scripts/` 下的脚本改写
