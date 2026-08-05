---
name: agentspace-handoff
description: 生成或消费一次性会话交接(AGENTSPACE/handoff/)——produce 流程在会话关闭时写入可丢弃的上下文快照, 使新会话无需重建上下文; consume 流程读取后删除。仅在显式 /agentspace-handoff-produce 与 /agentspace-handoff-consume 命令时触发。绝不自动触发。
---

# AGENTSPACE Handoff(一次性会话交接)

会话关闭时生成一次性上下文快照(`AGENTSPACE/handoff/handoff_<名>.md` + `handoff/index.md` 一行);新会话开始时消费(读取后删除)。多个 handoff 可并存;索引(脚本维护、入 git)登记 `name | description | location | time`。

## 0. 触发守卫

仅当用户显式执行 `/agentspace-handoff-produce` 或 `/agentspace-handoff-consume` 时进行。绝不自动触发(收尾时不、会话开始时也不)。项目无 AGENTSPACE 工作区时直说并停止。

## 1. Produce 流程(会话关闭)

1. **先更新常驻文档**(收尾协议①):刷新进行中 iteration readme 的"当前状态 · 下一步"与相关 plan 文档——handoff 快照必须是**更新后**的状态, 不是陈旧状态。
2. **快照**: 运行 `AGENTSPACE/scripts/status.sh`, 读最新 iteration readme。
3. **命名**: 取短而有语义的名字——名字是下个会话"看名字就能想起来"的依据。绝不用 `xxx-2`/`xxx-3` 后缀。用户未提供名字时, 从会话主题提炼(最新 iteration 标题 / plan 标题 / 当日工作);脚本兜底的 `session-<时间戳>` 只是最后手段。
4. **生成**: 运行 `AGENTSPACE/scripts/handoff.sh --produce --name <名> [--description <说明>]`。若脚本拒绝(名字/location 已登记), 换一个有语义的新名字重试——绝不用数字后缀改名。
5. **填充内容**: 脚本已从 `templates/handoff.md` 生成文件; 填满各节——项目上下文(从 AGENTS.md/tests.md 提炼)、当前状态(status 快照 + 续接块)、本次会话(做了什么/关键决定/data/ 产物)、下一步(下个会话的任务清单)、开放问题、引用(plan:NNNN / iteration_NNNN / notes / 文件路径)。
6. **里程碑提交**(index 行是入 git 的契约;handoff 文件本身 gitignore): `git -C AGENTSPACE add -A -- . && git -C AGENTSPACE commit -m "handoff: <名>"`。告知用户下个会话可用 `/agentspace-handoff-consume --name <名>` 开始。

## 2. Consume 流程(会话开始)

1. 用户未给 `--name`: 运行 `AGENTSPACE/scripts/handoff.sh --list`, 展示候选(name | description | location | time), 问用户消费哪个。
2. **完整读取文件**(`AGENTSPACE/handoff/handoff_<名>.md`)——它是上下文入口: 项目上下文、当前状态、上个会话做了什么、任务清单、开放问题。
3. 读取完成后(绝不在读取前——读取中途崩溃不能丢文件): 运行 `AGENTSPACE/scripts/handoff.sh --consume --name <名>` 删除文件与 index 行。`--keep` 两者都保留(调试/转交第二个会话)。
4. handoff 引用的 plan/iteration/notes 按 AGENTS.md 读取规则按需加载。

## 3. 边界

- 用户调用 consume 前只读;consume 只删除指定的 handoff 文件 + 其 index 行
- 绝不自动触发;不先读取绝不消费;冲突绝不自动改名
- handoff 文件 gitignore(一次性);`handoff/index.md` 入 git(仅 scripts 改写)
- handoff 是快照而非事实源——工作区文件始终是权威
