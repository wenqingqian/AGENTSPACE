---
name: agentspace-code-clean
description: AGENTSPACE 关键代码仓库的两级代码/注释/commit 卫生。第一级为被动默认 — 登记于 AGENTSPACE/.agentspace-repos 的仓库(或含 AGENTSPACE/ 工作区的项目内任何 git 仓库)中写入的代码、注释与 commit 文本都遵守本 skill 规则, commit 前由 AGENTSPACE/scripts/commit-check.sh 把门; 动手写入或审查前必须通读本文件, 全部规则与分级以本文件为准。第二级为主动显式 — 用户显式要求清理既有代码/注释、跑风格检查或改写 commit message 时, 阅读本 skill 目录内的 CLEANUP.md 并照做; 绝不自动触发。
---

# AGENTSPACE Code-Clean

**两级, 一个入口。** 第一级(被动, 默认)— 下列分级规则约束你在 AGENTSPACE 托管仓库里写入或审查的每一轮代码、注释与 commit 文本; 它随默认加载, 因此边写边判。第二级(主动, 仅显式)— 对**既有**代码的任意范围后处理放在独立流程文档里: **若用户显式要求清理既有代码或注释、跑风格检查或改写既有 commit message — 阅读本 skill 目录内的 CLEANUP.md 并照做。** 主动级绝不自动触发, 你也绝不自行扩大其范围。

适用范围: 登记于 `AGENTSPACE/.agentspace-repos` 的每个 git 仓库, 以及含 AGENTSPACE/ 工作区的项目内任何 git 仓库。AGENTSPACE 台账仓库自身**豁免** — 记账 id 是台账的母语; 永远不要对台账仓库运行此门。(v0.6.4 前名为 agentspace-commit — 门从 message 扩大到提交内容; 脚本名 `commit-check.sh` 不变。)

## 门(MUST)

在登记仓库 commit 前, 按序: 暂存目标文件, 起草 message, 带齐两个参数送检 — `AGENTSPACE/scripts/commit-check.sh <仓库路径> "<message 草稿>"` — 用**刚才送检的原 message** 提交(禁止检查 A 提交 B)。

- **0 PASS** — 提交。**CANDIDATES** 清单可能随行(只报告的扩网候选 — 脚本在标准 id 之外撒网捞到的形状): 候选绝不阻断、绝不推迟; 逐条显式裁决, 出声给出带理由的结论。结论由你宣布; 脚本只负责撒网。
- **1 BLOCKED** — 禁止提交。违规清单原样摆给用户, 修复后重新过门。
- **2 未登记** — 禁止提交。提议登记; 用户显式确认后 `AGENTSPACE/scripts/repos.sh --add <path>`, 再重新过门。**项目根下未登记仓库一律不 commit** — 先登记, 后提交。
- **3 用法错误** — 门被错误调用(缺 message, 或路径不在 git 工作树内)。带齐两个参数重新调用; 漏传 message 绝不静默放行 — 门失败即关闭。

门没有 `--force` 阀门, 你也不许变相制造(禁用检查、删规则都不行)。被挡的 commit 只能改写, 不能强推。

## Commit 文本规则

脚本确定性拦截标准记账 id 与空标题; 其余由你判断(标题 = 第一行; 正文可选)。

- **MUST 无记账。** 在脚本的标准 `plan:NNNN` / `iteration_NNNN` / `exp_NNNN` 禁令之上, 拦截脚本看不到的每个变体 — `plan_0013`、`plan 13`、`plan-0013`、"迭代 3"、"对应计划"、超过 0999 失去前导 0 的 id — 以及记账叙述("完成本轮迭代"、"update the workspace state")。message 只描述**代码改动本身**, 一个字都不多。上下文特例: 业务对象就是 agentspace 的仓库可以合法出现 "agentspace" 字样("feat: /agentspace-mode"); 记账 id 在所有仓库一律禁止。归属信息不会丢 — 它由 iteration readme 的宿主 SHA 承担; 工作区按 SHA 找 commit, commit 永不回指。
- **MUST 无 run 标识且与 diff 相关。** 不出现实验/run 标识 — `(6-run driver launch on .42)` 是 run 名(run 编号 + 机器地址 + 配置标签), 读起来像日志行; 这些属于 iteration readme / `data/`。判断前先读 `git show --stat`(暂存态: `git diff --cached --stat`): 标题点名的主题必须在改动文件里有落点 — 标题说 "driver launch" 而 diff 只动数据清洗, 是实验名穿 commit 外套; 拒绝并提议改写为对真实改动的描述。
- **MUST 注释规则同样约束 commit 文本。** 标题与正文的每一行都按下文「注释规则」审判 — 反馈残留、缺失上下文的引用、冗余复述、测试实例引用、过程叙述、机器标识与秘密, 在 commit 文本里与在代码注释里同罪; 正文不是绕开注释规则的侧门。豁免: commit 本身就是在描述改动 — delta 陈述("X renamed to Y, update callers")、前后对比数字与迁移事实合法, 因为它们随附的 diff 就是在场上下文; 仍禁的是向审阅者叙述评审过程("per review discussion"、"as requested")。
- **SHOULD 标题格式。** `<type>: <summary>`, 或仓库 log 用 scope 时 `<type>(<scope>): <summary>`; type 跟随仓库自身词汇表(feat fix refactor docs test chore perf build ci style)。祈使语气("add" 而非 "added"), 小写摘要, 无句尾句号; 摘要 ≤ 50 字符软目标、72 硬上限; 标题不带 issue 号 — 引用进正文 footer。拒绝无信息标题(`driver`、`stuff`、`update`)。
- **SHOULD 单一目的。** 紧耦合的改动集(功能 + 配套测试与文档)是一个 commit; 只拆不相关的改动。标题里的 "and" 在各部分服务同一目的时没问题; 不服务同一目的时就是该拆的信号。
- **SHOULD 正文要配得上。** 多数 commit 只发标题。仅当 why 无法从标题加 diff 推出、或携带评审人需要的事实时才写正文(取舍、兼容/迁移说明、性能数字、已知限制)。标题后空一行, 72 折行; why 先于 what(diff 已说明 what); 写行为不做文件清单导览; 具体胜过含糊("cuts cold start from 340ms to 120ms" 而非 "improves performance"); 无废话(不写 "this commit", 不复述标题)。

任一违规: 重写文本(代码不动), 用新文本重新过门。用户坚持原文 → 尊重决定但明说: doctor [15] 会在审计窗口内持续报告这条 commit — 只报告, 但可见。

## 注释规则

记账/run 禁令同样适用于 commit **新增**的内容 — 代码注释、字符串字面量、任何文本行(脚本扫描新增 diff 行; 改名只计被编辑 hunk; 删除行永不阻断; 每文件至多列 5 条)。在此之上, 你写入或触及的每条注释遵守:

- **MUST 注释自洽于当前代码 — 禁反馈驱动, 禁缺失上下文。** 每条注释都要像专门为"改动之后"的代码写下; 改动之前的代码属于缺失的上下文, 依赖它的注释是残留。最典型的残留是解释为什么没用另一种写法("why the code is not written some other way"): "why not alternative X" 回答的是过往评审的问题, 未来读者没有那份上下文。同族残留: "no longer does X"、"changed from Y to Z"、向审阅者叙述本轮 diff 的注释。边界: 引用本代码具体失败模式的"why not"("a wider group would elementwise all-reduce different vocab shards — silent embedding-gradient corruption")是设计注记, 保留; 裸的替代方案对比("not a load-balancing choice")是反馈残留, 删除。
- **MUST 删除冗余复述。** 逐字复述代码或兄弟 docstring 的注释删除 — 代码已说清的事不说第二遍。
- **MUST 精简过度解释。** 过度解释压到核心 what/why — 去掉防御性对冲与重复从句; 多段 docstring 通常收敛到 1–2 句。docstring 同级适用, 唯一例外: 公开函数/类保留一行用途说明, API 保持可读。
- **MUST 保留该保留的。** 非显然 what/why、接口契约、节分隔线、版权头(永远保留)不因清洁化被误删; 只修事实错误与非局部假设, 不借清洁化做风格重写。
- **MUST 不引用测试实例。** 引用具体测试实例(模型名、超参、并行布局、数据集)的注释不含代码语义且会过期 — 删除。代码确实只在特定配置下可用的, 用 `assert` 表达约束(可执行、响亮失败、不会烂)外加至多一条指向它的短注释; 只"声称"约束的注释既不受强制又会过期。教学示例不同: 保留, 但相对化书写("TP member 0/1"), 绝不写成 "under config X"。
- **MUST 描述代码, 不描述会话。** 注释里无记账叙述("本轮迭代新增…"、"updated per workspace state"); 无 diff 形状粘贴(以 `++ `/`-- ` 开头的行); 无实验/run 标识(`# 6-run on .42`)。合法却仍会命中脚本的形态(YAML `plan: 0NNN` 键、`iteration_0NNN.pt` 文件名): 把键名/常量改名为描述其角色。CJK/全角变体(`：`、`０００１`)是你的语义层 — 脚本只认 ASCII。确实必须引用标准 id 的内容(工具、夹具快照)归 `AGENTSPACE/utils/` 或所属 iteration 的 `data/`。
- **MUST 无过程叙述。** 叙述编辑会话而非代码的注释禁止写入: 日期叙述("# 2026-09-07 修改"、"// added on 2026-09-07")、工具/skill 来源("# based on X skill")一律不写, 触及存量时在改写中清除。陈述代码事实的非过程性日期合法("# since 2026-01: API v2")。脚本不捕这些形状 — 你就是执法层。
- **MUST 无机器指纹与秘密。** 注释禁止 IP 地址、主机名、内网拓扑、绑定具体机器的 host:port、用户名/家目录路径等机器相关标识 — 绑定具体机器的信息换个环境就是噪声; 禁止 token、密钥、密码等秘密。需要指代槽位时用可读占位名(`<endpoint>`, 不是 `10.1.2.3:8000`)。

## 代码与文件规则

- **SHOULD import 置于模块顶层。** 合法例外存在(条件 `if TYPE_CHECKING:` import、脚本中的强制延迟 import)— 属实时说明。
- **MUST 硬阻断文件**(绝不落地): `AGENTSPACE/` 路径(内嵌工作区内容或 gitlink)· 实验输出特征(`events.out.tfevents.*`、顶层 `wandb/` `mlruns/` `lightning_logs/`)· 单 blob ≥ 50MB。改名可被识别(`-M`): 改名进入阻断路径的文件按新路径阻断。
- **WARN — 由你结合仓库上下文判断, 连同判断摆给用户**: 数据/模型扩展名 ≥ 100KB(.npy/.pt/.ckpt/.h5/.parquet/.safetensors/.onnx/.log 等)· 顶层输出目录(`runs/ outputs/ checkpoints/ logs/ results/ exps/ experiments/`)。合法情形存在(测试小夹具、日志库的 `logs/` 源码目录); 每条 WARN 都连同你的判断出示。

## 阻断后

- **内容违规**(新增行): 改写该注释/代码行, 使其描述改动本身 — 归属由 iteration readme 的宿主 SHA 承担, 永不写进代码。重新暂存、重新过门。禁止把 id 变形混过正则 — 那是戴面具的泄漏。
- **数据违规**: 实验输出搬回家, 不是删掉 — `git reset -- <path>` 取消暂存 → `mv <path> AGENTSPACE/iterations/iteration_NNNN/data/`(已 gitignore)→ 程序写死输出目录的, 建议补 `.gitignore` 行(写宿主文件必须经用户同意, 无一例外)→ 重新过门。

## 批量注释审查(仅显式触发)

一种深度全文件审查模式, 与逐次 commit 的门相互独立: 范围 = 本次会话 commit 触及的文件, 或用户显式给出的精确区间; 只报告。仅在用户显式要求时运行 — 绝不自动、绝不作为门的副作用、绝不自行扩大成全仓扫查。完整流程(范围铁律、多 subagent 切分、维度、合并报告)在 CLEANUP.md 里 — 运行本模式前先读它。

## 边界

- 永不给托管仓库装 git hook; 永不主动写入托管仓库(工作区对代码仓库无感)。
- 历史违规(已提交的), 无论 message 还是内容, 由 `doctor.sh` [15] 与 `/agentspace-doctor` 报告 — 永远只报告。改写已发布历史是用户的决定; 用户显式要求时, 按 CLEANUP.md 的历史重建安全流程执行(先备份、未推送或经确认的强推规则、事后验证)。
- 登记变更(`repos.sh --add/--remove`)每次都必须用户显式确认。
