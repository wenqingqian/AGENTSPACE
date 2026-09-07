---
name: agentspace-code-clean
description: AGENTSPACE 关键代码仓库的 commit 门与代码/注释卫生。在任何登记于 AGENTSPACE/.agentspace-repos 的仓库(或含 AGENTSPACE/ 工作区的项目内任何 git 仓库)执行 git commit 前必触发 — 暂存文件、新增代码/注释行与 message 草稿必须先过 AGENTSPACE/scripts/commit-check.sh。未登记仓库禁止 commit; 记账 id(plan:NNNN / iteration_NNNN)与实验数据永不进入代码仓库 commit — message 里不出现, 代码与注释里也不出现; commit 文本必须描述真实代码改动(一句话标题、无实验/run 标识、与 diff 相关)。门还会打印只报告(report-only)的扩网候选(plan/iteration 词与数字相邻、任意分隔符 — `plan-12`、`plan_12`、`plan 13`) — 候选永不阻断; agent 必须逐条显式裁决并给出带理由的结论。另有针对本会话 commit 触及文件的批量注释审查(全文件、多 subagent、只报告)— 仅在用户显式要求时运行, 绝不自动。
---

# AGENTSPACE Code-Clean 提交门

适用于**已登记关键代码仓库**(`AGENTSPACE/.agentspace-repos`)里的一切 `git commit`。AGENTSPACE 台账仓库自身**豁免** — 记账 id 是台账的母语, 永远不要对台账仓库运行此门。(v0.6.4 由 agentspace-commit 更名而来 — 门的范围从 commit message 扩大到提交内容; 脚本名 `commit-check.sh` 不变。)

## 门(MUST)

在登记仓库 commit 前, 按序:

1. 暂存目标文件。
2. 起草 commit message。
3. 两者一起送检:
   ```bash
   AGENTSPACE/scripts/commit-check.sh <仓库路径> "<message 草稿>"
   ```
4. 退出码:
   - **0 PASS** — 用**刚才送检的原 message** 提交(禁止检查 A 提交 B)。**CANDIDATES** 清单可能随行(只报告): 它绝不构成阻断或推迟的理由 — 逐条显式裁决并给出结论(放行需陈述理由)。结论由你宣布; 脚本只负责撒网。
   - **1 BLOCKED** — 禁止提交。违规清单原样摆给用户, 修复后重新过门。CANDIDATES 清单可能与阻断项一并打印(便于完整归因)— 候选本身绝不阻断。
   - **2 未登记** — 禁止提交。向用户提议登记; 用户显式确认后 `AGENTSPACE/scripts/repos.sh --add <path>`, 再重新过门。**项目根下未登记仓库一律不 commit** — 先登记, 后提交。
   - **3 用法错误** — 门被错误调用(缺 message 草稿, 或路径不在 git 工作树内)。带齐两个参数重新调用: `AGENTSPACE/scripts/commit-check.sh <仓库路径> "<message 草稿>"`。漏传 message 绝不静默放行 — 门失败即关闭。

门没有 `--force` 阀门, 你也不许变相制造(禁用检查、删规则都不行)。被挡的 commit 只能改写, 不能强推。

## Message 规则

脚本确定性拦截标准记账 idiom — `plan:NNNN` / `iteration_NNNN`(as_norm_id `%04d` 零填充标准形: 前导 0 锚定匹配, 因此 "test plan: 3 phases"、"roadmap plan: 2026" 这类自然文本不误伤; 整条 message 含正文、大小写不敏感)。在此之上, **你**必须语义拦截脚本看不到的形态:

- 变体拼写: `plan_0013`、`plan 13`、`plan-0013`、"迭代 3"、"对应计划" — 任何形态的工作区记账引用。超过 0999 的 id 失去前导 0(如 `plan:1234`), 同样归这一层管。
- 记账叙述: "完成本轮迭代"、"更新工作区状态" — message 只描述**代码改动本身**, 一个字都不多。
- 上下文特例: 业务对象就是 agentspace 的仓库(如插件开发仓库)可以合法出现 "agentspace" 字样(如 "feat: /agentspace-mode"); 记账 id 在所有仓库一律禁止。

归属信息不会丢 — 它只是回家: iteration readme 记录宿主起始/结束 commit SHA(`> 宿主起始/结束 commit:`, close-iteration.sh 自动写)。工作区按 SHA 找 commit; commit 永不回指。

## 代码与注释规则(新增行 — 确定性 + 语义层)

同样的 idiom 禁止出现在 commit **新增**的内容里 — 代码注释、字符串字面量、任何文本行(v0.6.4)。脚本扫描新增 diff 行(改名只计其被编辑的 hunk; 大小写不敏感; 报告为 `文件:行号` + 摘录; 每文件至多列 5 条命中, 之后一条形如 `+N more …` 的英文尾注)。删除行永不阻断 — 清除旧泄漏永远放行; 二进制文件与纯改名没有新增行。在此之上, **你**必须语义拦截新增行里脚本看不到的形态:

- 代码/注释里的变体拼写: `plan_0013`、`plan 13`、"迭代 3" — 任何形态的工作区记账引用。
- 注释里的记账叙述("本轮迭代新增…"、"按工作区状态更新") — 注释只描述**代码本身**, 一个字都不多。
- 注释里的实验/run 标识(`# 6-run on .42`) — 这些属于 iteration readme / `data/`。
- Diff 形状内容 — 以 `++ `/`-- ` 开头的行(粘贴的 diff、xtrace 日志)— 描述改动本身, 永不粘贴工作区 diff。
- 合法却仍会命中的形态(YAML `plan: 0NNN` 键、`iteration_0NNN.pt` 文件名): 把键名/常量改名为描述其角色 — 归属由 iteration readme 承担; CJK/全角变体(`：`、`０００１`)是你的语义层, 脚本只认 ASCII。
- 过程叙述注释(WARN 候选 — 由你裁决, 绝不硬阻断): 叙述编辑会话而非代码的注释 — (a) 日期叙述, "何时写的"(`# 2026-09-07 修改`、`// added on 2026-09-07`); (b) 工具/skill 来源, "基于什么改的"(`# based on X skill`)。陈述代码事实的非过程性日期用法合法放行(`# since 2026-01: API v2`)— 这个判断由你做: 对每条候选向用户出声给出带理由的结论。

确实必须引用标准 id 的内容(生成工作区引用的工具、夹具快照)归 `AGENTSPACE/utils/` 或所属 iteration 的 `data/` — 永不进代码仓库。

## Commit 文本质量(语义层 — 你的判断, 两问)

记账之外, 每条 commit 文本草稿都要过两问(标题 = 第一行; 正文可选)。两问都是**你的判断** — 脚本只抓空标题。

1. **标题是不是对这次代码改动的一句话描述?** 必须能独立回答"这个 commit 改了什么":
   - 合格: `add retry to driver launch` / `fix: parse NaN in metrics` — 动词短语点名改动。
   - 拒绝: 无信息标题(`driver`、`stuff`、`update`); **实验/run 标识** — `(6-run driver launch on .42)` 是实验 run 名(run 编号 + 机器地址 + 配置标签), 读起来像日志行, 不像 commit。这些细节属于 iteration readme / `data/`, 永不进 commit。
   - 正文(如有)解释"为什么"(动机、取舍) — 不复述"改了什么"(diff 已经说了)。与标题同一禁单: 无记账、无 run 元数据。
   - 标题 ≤ 72 字符可读性软线, 不是门。

2. **标题/正文与实际的 diff 相关吗?** 先读 `git show --stat`(暂存态: `git diff --cached --stat`)再判断。标题点名的主题必须在改动文件/内容里有落点: 标题说 "driver launch" 而 diff 只动了数据清洗 → 这是实验名穿 commit 外套 — 拒绝, 提议改写为对真实改动的描述(`fix: retry driver launcher against .42` 保留技术要点、去掉 run 记账)。

处置: 任一违规 → 提交前要求重写标题/正文(代码不动), 用新文本重新过门。用户坚持原文本 → 尊重决定但明说: doctor [15] 与 `/agentspace-doctor` 会在审计窗口内持续报告这条 commit — 只报告, 但可见。

## 文件规则

硬阻断(绝不落地): `AGENTSPACE/` 路径(内嵌工作区内容或 gitlink)· 实验输出特征(`events.out.tfevents.*`、顶层 `wandb/` `mlruns/` `lightning_logs/`)· 单 blob ≥ 50MB。改名可被识别(`-M`): 改名进入阻断路径的文件(如顶层 `wandb/`)按新路径阻断。

WARN(不阻断 — 由你结合仓库上下文判断): 数据/模型扩展名 ≥ 100KB(.npy/.pt/.ckpt/.h5/.parquet/.safetensors/.onnx/.log 等)· 顶层输出目录(`runs/ outputs/ checkpoints/ logs/ results/ exps/ experiments/`)。合法情形存在(测试小夹具、日志库的 `logs/` 源码目录), 但每条 WARN 都必须连同你的判断摆给用户。

## 阻断后的导流(MUST)

- **内容违规**(新增行): 改写该注释/代码行, 使其描述改动本身 — 归属信息由 iteration readme 的宿主 SHA 承担, 永不写进代码。重新暂存、重新过门。禁止把 id 变形混过正则 — 那是戴面具的泄漏。
- **数据违规**: 实验输出不属于代码仓库 — 搬回家, 不是删掉:
  1. `git reset -- <path>` 取消暂存。
  2. 搬进当前 iteration: `mv <path> AGENTSPACE/iterations/iteration_NNNN/data/`(已 gitignore — 即 AGENTS.md 数据收集三策略的第 3 条)。
  3. 程序写死输出目录的, 建议把该目录加进仓库 `.gitignore` — 写宿主文件必须经用户同意, 无一例外。
  4. 重新过门。

## 批量注释审查(仅显式触发 — 只报告)

一种深度审查模式, 与逐次 commit 的门相互独立。仅在用户显式要求时运行(如"对本轮改动做一次批量注释审查")— 绝不自动运行, 绝不作为门的副作用, 也绝不演变为全仓扫查。

- **范围(铁律):** 仅限本次会话 commit 触及的文件, 或用户显式给出的精确 commit 区间(对该区间跑 `git diff --name-only <base>..<head>`)。绝不自行扩大到仓库其余部分 — 永不自动全仓扫查, 无一例外。
- **全文件注释:** 范围内每个文件全量审查 — 文件里的每一条注释, 不只本轮新增行 — 连新增行门看不到的存量叙述(旧日期戳、旧来源注记)也一并抓出。
- **多 subagent:** 把范围内文件切分给并行 subagent。每个 subagent 只读分配到的文件、只返回发现(文件:行 · 摘录 · 命中维度 · 建议方向)— 绝不编辑。发现聚合到你, 由你向用户呈现一份合并报告。
- **维度:** 语义层对新增行执法的一切(任何拼写的记账引用、实验/run 标识、diff 形状粘贴)加上过程叙述维度(日期叙述、工具/skill 来源)— 按全文件评估, 存量注释也在内。
- **只报告:** 报告即本模式终点。修复是独立的、用户驱动的另一次 commit — 提出修复批次并等用户点头; 绝不未经要求把修复混进进行中的 commit。

## 边界

- 永不给托管仓库装 git hook; 永不主动写入托管仓库(工作区对代码仓库无感)。
- 历史违规(已提交的), 无论 message 还是内容: 由 `doctor.sh` [15](内容: 近期 commit 的新增行, 每类首命中 — message / 内容 / 空标题 三类不互相遮蔽)与 `/agentspace-doctor` 报告 — 永远只报告。改写历史(rebase / filter-repo)是用户的决定与用户自己的操作。
- 登记变更(`repos.sh --add/--remove`)每次都必须用户显式确认。
