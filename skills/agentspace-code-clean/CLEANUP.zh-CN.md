# Code-Clean 后处理流程(主动层)

agentspace-code-clean 的流程半边。SKILL.md 承担常驻规则(commit 门、commit 文本规则、注释分级、文件规则); 本文档承担对**既有**代码的清理流程。只有经 SKILL.md 的指针规则才会读到本文档 — 用户显式要求清理过去代码/注释、跑风格检查、改写 commit message 或重建历史。绝不自动触发本层; 绝不自行扩大范围。默认姿态: 先报告, 用户确认后才动手(用户明确说"直接修"可跳过报告步)。

## 范围(动手前先定)

- **git 区间模式** — 用户点名 commit 区间。先验证: `git log --oneline <start>..<head>` 必须线性(区间内出现 merge → 请用户重新表述区间); `git diff --stat <start>..<head>` 给出文件清单。
- **文件模式** — 用户点名文件或目录。
- **批量审查模式** — 本次会话 commit 触及的文件, 或用户显式给出的精确区间(`git diff --name-only <base>..<head>`)。
- **范围修正(关键)** — git 区间只显示 start commit **之后**被修改的行; 由 start commit 本身创建的注释在 diff 里不可见。区间内新建的文件, 要问用户审全文(推荐)还是只审 diff 行。
- **铁律** — 范围就是用户给你的那个。绝不自行扩大到仓库其余部分。

## 提取候选

- Python 精确解析(tokenize/ast): 完整注释、行内注释、docstring。
- 其他语言按扩展名的注释标记启发式扫描 — 结果只当候选清单, 逐条对照真实文件核实。
- 无论用什么方法, 报告引用的 `文件:行号` 与文本必须来自真实文件(区间模式下: `git show <end>:<file>`), 绝不转述提取器的一面之词。

## 分级(SKILL.md 四类, 应用于存量注释)

- **① 删除 — 反馈式 "why not alternative X"。** 可识别措辞: 否定式("not a load-balancing choice"); 防御性对冲("kept as a safeguard"、"normally unreachable"); 替代方案对比("without using retain_graph=True"、"deliberately does not implement `__getattr__`"); 解释两个函数为何不共享代码的注记; 会话指令残留("do not duplicate these checks elsewhere"); 测试实例引用("we tested with the 4b config")。
- **② 删除 — 冗余注释**: 逐字复述代码或兄弟 docstring。
- **③ 精简 — 过长 prose** 到核心 what/why(去掉对冲与重复从句)。
- **④ 保留/微调 — 非显然 what/why、接口契约、节分隔线、一行用途 docstring、版权头(永远保留; 只修事实错误与非局部假设)。** 长 docstring 不天然有罪: 文件格式契约、WARNING/caveat 块、带真实不变量的设计注记都留下。引用本代码具体失败模式的 "why not" 是设计注记 → 归 ④ 不归 ①。
- **Assert-vs-example** — 删除配置引用注释前先查约束是否真实: 真实但未被 assert 的, 修复是**补 assert**, 不是留注释。教学示例保留数字, 但相对化书写("TP member 0/1")。
- **坑** — 不为显得忙而"改进"④ 类注释; ~90% 保持原样是健康结果。拿不准精简还是删除时, 精简到事实内核。检查器与 agent 只报告不裁决 — 想象得出辩解理由也不许丢掉一条发现。

## 报告(动手前)

- **改动项(①–③)**: `文件:行号` + 原文(节选)+ 分级 + 替换文本(③ 类精简逐字给出)。
- **保留项(④)**: 每文件一行紧凑列出 — 行号 + 3–6 词理由("non-obvious why"、"接口契约")。
- 结尾给汇总计数(删除 N / 精简 N / 保留 N)。用户确认前不动手。

## 应用与验证

- 逐条按工作树精确匹配编辑。
- 语法门按语言: Python `python3 -m py_compile`; Shell `bash -n`; YAML 用 python3 yaml.safe_load 解析; C/C++ 等 — 无工具链就跳过并明说。
- `git diff` 自检: 只有注释/已分级发现变化 — 零行为漂移。
- 仅在用户要求时 commit; 清理 commit 的 message 本身遵守 SKILL.md commit 文本规则并过 commit 门(如 `Trim feedback-driven and redundant comments in <area>`)。

## 风格检查(按需)

用户要求风格检查时(如 import 不在模块顶层), 发现与分级项同格式报告 — 工具产出的 JSON 形 `{checker, file, line, column, text, message}`, 人工核查的给等价事实。报告**全部**发现; 用户裁决。检查器只发现不裁决; 修复走同一"先报告后确认"流程。

## Commit message 改写

- **从暂存/未提交改动起草**: `git status --porcelain` + `git diff --cached`(回退用 `git diff`); 从 `git log --oneline -10` 学仓库的 type 词汇; 按 SKILL.md commit 文本规则起草; heredoc message 提交。用户明确要快速提交的一次性 WIP 快照、以及工具生成的 merge commit / rebase 产物可跳过。
- **改写最后一条 message**: 仅当分支无上游或该 commit 未推送(`git log @{u}..HEAD`)。已推送 → 打印改进版 message 并警示, 不 amend。
- **改进既有 commit `<rev>`**: 只打印改进版 message; 绝不自行改写历史。
- 登记仓库里的每次改写, 提交前都用新 message 重新过 commit 门。

## 历史重建(用户决定, 仅显式要求)

已提交的违规(message 或内容里的记账 id、落地的实验数据)默认只报告(doctor [15])。重建历史 — rebase / filter-repo — 会改写 commit SHA, 决定权在用户; 仅在其显式要求时执行, 且:

1. **先备份**: 动手前 `git branch backup/pre-clean-<scope>`; 重建涉及多引用或已推送分支时优先用全新 clone。
2. **按形状选工具**: 近期短线性窗口用交互式 rebase(`git rebase -i <base>`, reword/edit); 深历史的批量文本替换用 `git filter-repo --replace-text <map-file>`(每行一个字面量, `旧==>新`, 留空替换即删除); 需要移动文件时才用 `--tree-filter`/`--index-filter`。
3. **护栏**: 未获用户对 force-push 后果的明确认知(队友 clone 会分叉)绝不改写已推送/共享历史。重建在代码仓库内执行, 绝不在 AGENTSPACE/ 内 — 但重建后宿主 SHA 变了, 同一会话内把新 HEAD SHA 记进 iteration readme(台账必须指向现实)。
4. **事后验证**: 对重建窗口重扫被清除的形状(`git log -p -- <paths>`), 注释变过的文件过语法门, 确认工作树干净, 有测试就跑。

## 批量注释审查(完整流程)

对本次会话 commit 触及文件(或用户显式区间)的深度审查模式 — 只报告, 与逐次 commit 的门相互独立。

- **范围(铁律)**: 仅这些文件 — 对本会话 commit 或给定区间跑 `git diff --name-only`。绝不自行扩大到仓库其余部分; 永不自动全仓扫查。
- **全文件注释**: 范围内每个文件全量审查 — 文件里的每一条注释, 不只本轮新增行 — 连新增行门看不到的存量叙述(旧日期戳、旧来源注记)也一并抓出。
- **多 subagent**: 把范围内文件切分给并行 subagent。每个 subagent 只读分配到的文件、只返回发现(文件:行 · 摘录 · 命中维度 · 建议方向)— 绝不编辑。发现聚合到你, 由你向用户呈现一份合并报告。
- **维度**: 语义层对新增行执法的一切(任何拼写的记账引用、实验/run 标识、diff 形状粘贴)加上过程叙述维度(日期叙述、工具/skill 来源)— 按全文件评估, 存量注释也在内, 外加 SKILL.md 四类分级。
- **只报告**: 报告即本模式终点。修复是独立的、用户驱动的另一次 commit — 提出修复批次并等用户点头; 绝不未经要求把修复混进进行中的 commit。
