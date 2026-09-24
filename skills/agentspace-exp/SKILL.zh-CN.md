---
name: agentspace-exp
description: 实验记录(exp 模块)触发器(AGENTSPACE 工作区)— 把实验目标登记进 exp 的工作流入口; 设计与报告纪律由它委托的两个独立 skill 承担(agentspace-better-exp、agentspace-better-exp-report)。当用户调用 /agentspace-exp、要求把实验登记进 exp、或提到要做实验(此时本 skill 发起一次性登记提议)时激活。一个 exp = 一个大目标下的一组实验轮次 — 登记新 exp 即新的大目标, 仅限主动登记(用户显式确认); 同一目标的后续轮次归并进已有 exp(不新开 exp、无需再次确认), 已关闭的先经 reopen-exp.sh 重开。开发收尾的正确性验证绝不登记。用户选择登记后, 设计对齐交给 agentspace-better-exp, 随后驱动手册生命周期(new-exp.sh、start-exp.sh、complete-exp.sh; 配置必须落入 examples/exp_spec/, 全量记录落入 exp_data/)。
---

# 实验记录触发器 (agentspace-exp)

> exp 模块的工作流入口 — 登记门 + 手册生命周期。本 skill 是触发器, 不是纪律本身: 设计对齐归 agentspace-better-exp, 报告与作图归 agentspace-better-exp-report。

## 0. 启动守卫

按顺序判断; 任一不满足则静默退出(按普通请求处理):
1. 用户调用了 `/agentspace-exp`、要求把实验登记进 exp、或提到了要做实验(最后一种情形由本 skill 发起一次性登记提议)
2. 项目根存在 `AGENTSPACE/` 目录 — 若用户显式调用了命令而工作区不存在, 明确说明并停止(工作区只能经 /agentspace-init 创建)

## 1. 登记门 (MUST)

- **一个 exp = 一个大目标** — exp 登记的是大目标(其下容纳一组实验轮次), 绝不是一轮一个 exp。按目标粒度登记, 与用户确认的是**目标**: 只有用户显式要求走 agentspace-exp、或接受了你在其提到要做实验时的一次性提议, 才登记。同一会话内最多提议一次; 被婉拒则实验照常进行但不记录, 且不再重复提议。
- **后续轮次归并进行中 exp, 绝不一轮一个新 exp** — 同一目标下的新参数轮、补测、增量结果属于进行中(todo/doing)的 exp: 在手册"轮次"节追加本轮记录, 配置以轮前缀放入 examples/exp_spec/exp_NNNN/, 数据落 exp/exp_data/exp_NNNN/(建议按轮建子目录)。向用户报备你在追加什么 — 无需再次确认(目标级登记已覆盖), 不新开 exp。目标已关闭: 先重开(`reopen-exp.sh <id>`)再追加。归属不清(算后续轮次还是新目标)— 问用户; 新目标走上方完整登记门。
- **不是所有实验都登记** — 开发收尾的常规正确性验证默认不登记(除非用户确认)。exp 只记录用户选择登记的度量/验证/调研; plan/iteration 流程不受影响。
- 上下文与纪律规则(AGENTS.md 读取顺序、scripts-only 索引)遵循 agentspace skill 与工作区 AGENTS.md 的 exp 模块节。

## 2. 生命周期(登记确认后)

1. **先对齐设计** — agentspace-better-exp skill(五轴)**只在目标登记时运行一次**; 其产出契约填充 exp 手册。后续轮次只需增量核对(相对上一轮改了什么、是否仍单变量), 记入本轮条目:
```bash
AGENTSPACE/scripts/new-exp.sh "English experiment title" [--plan NNNN] [--iteration NNNN]   # 配置必须落入 examples/exp_spec/exp_NNNN/
AGENTSPACE/scripts/start-exp.sh <id>                     # 开跑 todo→doing(小实验可省略); 全量记录 → exp/exp_data/exp_NNNN/
AGENTSPACE/scripts/reopen-exp.sh <id> ["原因"]           # done→doing: 已关闭的目标经重开接纳后续轮次, 绝不为此新开 exp
AGENTSPACE/scripts/complete-exp.sh <id> <done|failed|abandoned> "结果一句话" [--commit "仓库名@sha,..."]   # 目标有结论时才关闭
```
2. 机制(exp_spec 契约、exp_data 权威全量记录、commit 点语义)由工作区 AGENTS.md 的 exp 模块节承担 — 遵循它, 绝不手编索引。
3. **关闭时出报告** — 用户要从已记录数据出报告或图时, 运行 agentspace-better-exp-report skill。

## 3. 分工

- plan = 为什么/做什么, iteration = 改代码, exp = 测代码; exp 可不关联 plan/iteration; 关联的 exp 把 iteration data/ 复制进 exp_data。
- 对齐中途用户放弃登记 — 停止; 实验照常进行但不记录, 同一会话内不再重复提议。
