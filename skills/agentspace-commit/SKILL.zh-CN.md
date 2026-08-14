---
name: agentspace-commit
description: AGENTSPACE 关键代码仓库的 commit 门。在任何登记于 AGENTSPACE/.agentspace-repos 的仓库(或含 AGENTSPACE/ 工作区的项目内任何 git 仓库)执行 git commit 前必触发 — 暂存文件与 message 草稿必须先过 AGENTSPACE/scripts/commit-check.sh。未登记仓库禁止 commit; 记账 id(plan:NNNN / iteration_NNNN)与实验数据永不进入代码仓库 commit。
---

# AGENTSPACE Commit 门

适用于**已登记关键代码仓库**(`AGENTSPACE/.agentspace-repos`)里的一切 `git commit`。AGENTSPACE 台账仓库自身**豁免** — 记账 id 是台账的母语, 永远不要对台账仓库运行此门。

## 门(MUST)

在登记仓库 commit 前, 按序:

1. 暂存目标文件。
2. 起草 commit message。
3. 两者一起送检:
   ```bash
   AGENTSPACE/scripts/commit-check.sh <仓库路径> "<message 草稿>"
   ```
4. 退出码:
   - **0 PASS** — 用**刚才送检的原 message** 提交(禁止检查 A 提交 B)。
   - **1 BLOCKED** — 禁止提交。违规清单原样摆给用户, 修复后重新过门。
   - **2 未登记** — 禁止提交。向用户提议登记; 用户显式确认后 `AGENTSPACE/scripts/repos.sh --add <path>`, 再重新过门。**项目根下未登记仓库一律不 commit** — 先登记, 后提交。
   - **3 用法错误** — 门被错误调用(缺 message 草稿, 或路径不在 git 工作树内)。带齐两个参数重新调用: `AGENTSPACE/scripts/commit-check.sh <仓库路径> "<message 草稿>"`。漏传 message 绝不静默放行 — 门失败即关闭。

门没有 `--force` 阀门, 你也不许变相制造(禁用检查、删规则都不行)。被挡的 commit 只能改写, 不能强推。

## Message 规则

脚本确定性拦截标准记账 idiom — `plan:NNNN` / `iteration_NNNN`(as_norm_id `%04d` 零填充标准形: 前导 0 锚定匹配, 因此 "test plan: 3 phases"、"roadmap plan: 2026" 这类自然文本不误伤; 整条 message 含正文、大小写不敏感)。在此之上, **你**必须语义拦截脚本看不到的形态:

- 变体拼写: `plan_0013`、`plan 13`、`plan-0013`、"迭代 3"、"对应计划" — 任何形态的工作区记账引用。超过 0999 的 id 失去前导 0(如 `plan:1234`), 同样归这一层管。
- 记账叙述: "完成本轮迭代"、"更新工作区状态" — message 只描述**代码改动本身**, 一个字都不多。
- 上下文特例: 业务对象就是 agentspace 的仓库(如插件开发仓库)可以合法出现 "agentspace" 字样(如 "feat: /agentspace-mode"); 记账 id 在所有仓库一律禁止。

归属信息不会丢 — 它只是回家: iteration readme 记录宿主起始/结束 commit SHA(`> 宿主起始/结束 commit:`, close-iteration.sh 自动写)。工作区按 SHA 找 commit; commit 永不回指。

## 文件规则

硬阻断(绝不落地): `AGENTSPACE/` 路径(内嵌工作区内容或 gitlink)· 实验输出特征(`events.out.tfevents.*`、顶层 `wandb/` `mlruns/` `lightning_logs/`)· 单 blob ≥ 50MB。

WARN(不阻断 — 由你结合仓库上下文判断): 数据/模型扩展名 ≥ 100KB(.npy/.pt/.ckpt/.h5/.parquet/.safetensors/.onnx/.log 等)· 顶层输出目录(`runs/ outputs/ checkpoints/ logs/ results/ exps/ experiments/`)。合法情形存在(测试小夹具、日志库的 `logs/` 源码目录), 但每条 WARN 都必须连同你的判断摆给用户。

## 阻断后的导流(MUST, 数据类违规)

实验输出不属于代码仓库 — 搬回家, 不是删掉:

1. `git reset -- <path>` 取消暂存。
2. 搬进当前 iteration: `mv <path> AGENTSPACE/iterations/iteration_NNNN/data/`(已 gitignore — 即 AGENTS.md 数据收集三策略的第 3 条)。
3. 程序写死输出目录的, 建议把该目录加进仓库 `.gitignore` — 写宿主文件必须经用户同意, 无一例外。
4. 重新过门。

## 边界

- 永不给托管仓库装 git hook; 永不主动写入托管仓库(工作区对代码仓库无感)。
- 历史违规(已提交的)由 `doctor.sh` [15] 与 `/agentspace-doctor` 报告 — 永远只报告。改写历史(rebase / filter-repo)是用户的决定与用户自己的操作。
- 登记变更(`repos.sh --add/--remove`)每次都必须用户显式确认。
