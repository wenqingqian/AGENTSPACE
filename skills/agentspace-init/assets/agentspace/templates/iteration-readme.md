# iteration_{{ID}} {{TITLE}}

> plan: {{PLAN_ID}}
> 状态: 进行中
> 创建: {{DATE}}

## 当前状态 · 下一步

<!-- 会话续接块: 每次结束工作前更新"干到哪 / 卡在哪 / 下一步做什么"。
     这是新会话恢复上下文的入口; iteration 关闭后本节冻结。 -->

## 目标

<!-- 这一轮代码/状态变更要完成什么(实现某功能的中间步骤, 可能伴随实验验证) -->

## 代码变更 (diff)

<!-- 本轮相对上一轮改了什么(代码 / 配置 / 数据 / 环境)。
     有关键代码变更时, 保存宿主仓库 diff 到 data/:
     git -C <宿主> diff <起始commit>..<结束commit> > data/diff-<起始>..<结束>.patch
     并在下方登记 diff 文件。
     同时列出本轮涉及的文件路径(每行一个), 便于日后检索:
     - 文件: path/to/file.py
     - 文件: path/to/other.cfg -->

## 环境

<!-- 引用 tests.md 的环境条目。
     宿主起始/结束 commit 由脚本自动记录(创建时/关闭时各一行)。
     宿主有未提交改动时, 把 diff 存到 data/: git -C <宿主> diff > data/code.diff
     并行轮次(agentspace-parallel)在本节登记 PR 簿记永久锚点:
     每仓库一行 <repo> plan-<id>:<base-sha>(创建泳道时的主线基点, 主线永远可达)。 -->

## 结果

<!-- 指标 / 结论; 关闭 iteration 前必填 -->
<!-- 并行轮次追加: 验收层级(T0-T3)与理由在执行前写定于本节;
     合并后登记每仓库 squash SHA(永久锚点), 空净差合并记 no-op。 -->

## data 产物清单

<!-- data/ 下各文件是什么、怎么产生的(实验产物 + 代码 diff)。
     data/ 全量本地保存, 已被 gitignore 屏蔽, 不入 git -->

## 日志

<!-- append-only: 每次工作追加一行, 不修改历史行。
     并行轮次的临时锚点(泳道分支 HEAD / absorb 基点)记本节, 合并清理后即失效。 -->
- {{DATE}} 创建
