# AGENTSPACE 工作区

> 本文件是 AGENTSPACE 的入口: 结构总览 + 各模块 what/when/how + 操作纪律。
> 进行实验 / 代码改动 / 项目迭代相关工作前必读;
> 并确保本文件、tests.md、iterations.md 三者内容在上下文中(丢失则重读)。

## agentspace mode
hybrid

## 项目简介

<!-- 一句话: 这个项目做什么 -->

## 根仓库简介

<!-- 宿主项目(上一层目录)的结构与关键路径。
     关系: AGENTSPACE 是独立 git 管理的工作区; 代码在宿主仓库, 这里只管理状态与产物索引。
     工作区常有多个代码仓库: 写明与项目强相关的关键代码仓库、职责与关键入口文件(init 时经分析+用户确认填写)。 -->

## 关键代码仓库

> 登记处 = `.agentspace-repos`(一行一个仓库路径: 项目根内相对路径, 树外绝对路径; 物理路径 + git toplevel 规范化)。
> **只能由 `scripts/repos.sh` 改写**(`--add` / `--remove` / `--list`); 每次登记/出册必须用户显式确认, agent 不得自行登记。
> AGENTSPACE 自身(台账仓库)永远豁免、永不在册。

- **形态**: 内嵌(工作区在代码仓库内 — 宿主须经 .gitignore 或 .git/info/exclude 豁免 AGENTSPACE/, 宿主历史不出现其内容与 gitlink)或分开存放(仓库在树外, 按路径登记)。形态是派生事实, 不存储。
- **commit 门(MUST)**: 在登记仓库执行 `git commit` 前, 必须先运行 `scripts/commit-check.sh <仓库> "<message>"` 并通过(exit 0); 未登记仓库(exit 2)先登记后提交。commit 门与全部代码/注释/commit 文本卫生规则见 agentspace-code-clean skill(被动层默认生效; 主动清理既有代码/历史仅经用户显式要求)。
- **message**: 记账 id(plan:NNNN / iteration_NNNN)与记账叙述永不进入代码仓库 commit; 归属由 iteration readme 的宿主 SHA 记录承担。
- **文件**: 实验产物(`events.out.tfevents.*`、顶层 wandb/mlruns/lightning_logs、≥50MB blob)阻断; 数据扩展名 ≥100KB 与顶层输出目录为 WARN(agent 结合仓库上下文判断); 阻断后导流: unstage → `mv` 进 iteration_NNNN/data/ → 建议补 .gitignore(须用户同意)。
- **standalone 模式**: 登记仓库是工作对象, 豁免白名单语义(doctor [13] 不报违规)。
- **审计**: doctor [14](登记一致性/内嵌盾牌/热仓库未登记)与 [15](近期 commit 事后扫描, 只报告不改历史)。

## 结构

```
AGENTSPACE/
├── AGENTS.md          ← 本文件
├── plan.md            ← plan 入口视图 (Todo + 最近 Done 10 条)
├── plan/              ← index.md(全量索引) + todo/ + done/(含 完成/失败/放弃)
├── iterations.md      ← iteration 入口视图 (进行中 + 最近完成 10 条)
├── iterations/        ← index.md(全量索引) + latest 软连接 + iteration_NNNN/{readme.md, data/(实验产物+代码diff)}
├── exp.md             ← exp 入口视图 (Todo + Doing + 最近完成 10 条)
├── exp/               ← index.md(全量索引) + todo/ + doing/ + done/ + exp_data/exp_NNNN/(完整实验记录, 不入 git)
├── data.md + data/    ← 公用数据(训练集/模型权重/软连接; 全部 gitignore)
├── examples.md + examples/ ← 可复用实验配置(YAML/JSON); exp_spec/exp_NNNN/ 为登记实验的专属配置位
├── utils.md + utils/  ← 复用工具(做图/机器状态/运行状态/日志分析等)
├── tests.md + tests/  ← 实验环境(容器/conda/GPU) + 测试脚本
├── notes.md + notes/  ← 持久知识(可迁移结论/踩坑)
├── register.md        ← 按需扩展模块注册表
├── .agentspace-repos  ← 关键代码仓库登记处(一行一路径; 只能由 scripts/repos.sh 改写)
├── handoff/           ← 一次性会话交接文件 + index.md(由 scripts/handoff.sh 维护, 文件不入 git)
├── templates/         ← 文档模板(plan / iteration-readme / exp-manual / module-entry / note / handoff)
└── scripts/           ← 状态流转与登记脚本(索引/条目/登记处的唯一写入口) + commit 检查门(commit-check.sh)
```

## 模块: what / when / how

### plan —— 任务计划 (plan.md + plan/)
- **what**: 一个任务写成一个或多个 plan; 索引自项目创建起全局递增、永不复用
- **when**: 有新任务/目标时创建; 到达明确终点(完成/失败/放弃)时关闭
- **how**: `scripts/new-plan.sh "标题"` → 撰写 plan/todo/NNNN-*.md(目标/背景/方案步骤) → `scripts/complete-plan.sh <id> <done|failed|abandoned> "结果"`

### iterations —— 代码变更迭代 (iterations.md + iterations/)
- **what**: 实现 plan 过程中的一次**代码/仓库状态变更**(递进关系, 一轮接一轮); 常伴随实验验证, 所以有 readme + data/; **每个 iteration 必属且仅属一个 plan**, 一个 plan 可含多个 iteration
- **when**: 在 plan 内推进一个有意义的代码变更时创建; 简单改动不建 iteration; 创建前须与用户确认; 结果落盘且 readme 完成时关闭
- **how**: `scripts/new-iteration.sh <plan-id> "本轮内容"` → 工作并及时更新 readme → `scripts/close-iteration.sh <id> "结果"`
- **代码 diff**: readme"环境"节记录宿主仓库起始/结束 commit sha; 有关键代码变更时把 `git diff <起始>..<结束>` 存到 `iteration_NNNN/data/`
- **data 收集三策略** (实验产物全量放入 iteration_NNNN/data/, 该目录已被 gitignore):
  1. 程序支持设置 output 位置 → 直接指向 `iteration_NNNN/data/`
  2. 支持重定向 → `cmd > iteration_NNNN/data/xxx.log`
  3. fallback → 在工作区找到本轮产出的结果文件, `mv` 进 `iteration_NNNN/data/`

### exp —— 实验记录 (exp.md + exp/)
- **what**: 独立登记的实验(度量/验证/调研)。分工: plan 管"为什么/做什么", iteration 管"改代码", exp 管"测代码"; exp 可不关联 plan/iteration(纯度量/调研实验), 关联时经索引的 关联 plan / 关联 iteration 列记录(agentspace-exp 是本模块的触发器 — `/agentspace-exp` 命令 + 同名 skill, 持有登记门与生命周期; 设计对齐/报告由 better-exp 系列两个正式 skill 承担)
- **when**: **用户显式要求走 /agentspace-exp, 或 agent 在用户提到要做实验时提议一次并经用户确认**; 开发收尾的正确性验证等常规实验默认不登记(除非用户确认); 登记前的设计对齐走 agentspace-better-exp skill
- **how**: `scripts/new-exp.sh "标题" [--plan NNNN] [--iteration NNNN]` → 实验配置**必须**写入 `examples/exp_spec/exp_NNNN/`(脚本预创建) → 运行与结果**全量**落 `exp/exp_data/exp_NNNN/`(关联 iteration 的 data/ 产物复制一份至此; 该目录不入 git, 为本机权威记录) → `scripts/start-exp.sh <id>`(开跑, todo→doing; 小实验可省略) → `scripts/complete-exp.sh <id> <done|failed|abandoned> "结果" [--commit "仓库名@sha,..."]`
- **commits 语义**: exp 记录测试用关键仓库的 commit **点**(repo@sha, 关闭时落定), 与 iteration 的 commit 窗口(起始/结束)互补; 报告与作图走 agentspace-better-exp-report skill

### data —— 公用数据 (data.md + data/)
- **what**: 项目公用数据(训练集、模型权重、预处理数据等); 也可以是对其他位置的软连接
- **when/how**: 多个实验需要同一份数据时放入 data/ 并在 data.md 登记; data/ 全部 gitignore(与 .gitignore 行为一致, 无 opt-out)

### examples —— 实验配置 (examples.md + examples/)
- **what**: 可复用的实验配置文件(YAML/JSON 等); 与 tests/ 配合: tests/ 放入口脚本(如何跑), examples/ 放配置(用什么参数跑)
- **when/how**: 有可复用的实验参数/配置时放入 examples/ 并在 examples.md 登记; 测试脚本通过路径引用 examples/ 下的配置
- **exp_spec 契约**: 所有经 agentspace-exp 登记的实验, 其配置必须写入 `examples/exp_spec/exp_NNNN/`(由 new-exp.sh 预创建, 关闭时空目录会被 complete-exp.sh 拒绝); 该子树由 exp/index.md 的配置列索引, 不在 examples.md 登记

### utils —— 复用工具 (utils.md + utils/)
- **what**: 频繁使用的辅助工具(做图 / 机器状态查询 / 运行状态查询 / 日志分析等)
- **when/how**: 需要工具先查 utils.md, 复用而非重写; 新工具写入 utils/ 并在 utils.md 登记一行

### tests —— 实验环境与测试 (tests.md + tests/)
- **what**: tests.md 是实验环境(容器/conda/GPU/依赖)的唯一事实来源 + 测试脚本索引
- **when/how**: 环境变化当天更新 tests.md; 测试脚本放 tests/ 并登记

### notes —— 持久知识 (notes.md + notes/)
- **what**: 跨 plan/iteration 可迁移的结论与踩坑记录
- **when/how**: plan 完成时回顾 iterations 提炼教训、或发现坑时立即记录; 每条笔记必须带"来源"(plan:NNNN / iteration_NNNN / exp_NNNN); 由 iteration 提炼的笔记在"详情"中回链该 iteration 的 readme; 建议打主题"标签"便于检索聚合; 模板 templates/note.md

### register —— 按需扩展模块 (register.md)
- **what**: 按需注册的模块登记处(按项目需要扩展, 如 visualization.md + visualization/)
- **how**: 先与用户确认 → `scripts/register-module.sh <name> "用途"`

### handoff —— 一次性会话交接 (handoff/)
- **what**: 会话结束时生成的一次性上下文快照, 新会话读取后即销毁(consume); 支持多个 handoff 并存, index.md 登记 name/description/location/time
- **when**: 关闭会话前收尾时(任何情况都可用, 不要求有进行中 plan); 新会话开始时消费
- **how**: `/agentspace-handoff-produce [--name <名>] [--description <说明>]` → 填充内容 → 新会话 `/agentspace-handoff-consume --name <名> [--keep]`; 所有写操作经 `scripts/handoff.sh`(名字冲突会拒绝, 不会自动加后缀)

## 读取规则

1. **上下文常驻**: 本文件 + tests.md + iterations.md。丢失(如 compact 后)或不确定 → 重新读取
2. 任务相关时读 plan.md(有登记实验时读 exp.md); 会话续接时: 有 handoff 先读 `handoff/index.md` 选最新并 consume, 否则读 `iterations/latest/readme.md` 的"当前状态 · 下一步"
3. 文件夹内部(plan/ iterations/ utils/ 等)**按需读取**, 不预加载

## 纪律

规则分级: `[MUST]` 违反会造成损坏/不可逆; `[SHOULD]` 最佳实践; `[MAY]` 可选。

- **[MUST] scripts-only**: plan.md / iterations.md / exp.md / plan/index.md / iterations/index.md / exp/index.md 与 .agentspace-repos **只能由 scripts/ 改写**, 禁止手工编辑
- **[MUST] 创建前确认**: plan / iteration 创建前必须经用户明确确认; 简单改动不建 plan/iteration。exp 只在用户显式要求走 /agentspace-exp、或 agent 提议并经用户确认后创建; 开发收尾的正确性验证等常规实验默认不建 exp(agent 最多提议一次, 用户未确认不登记)
- **[MUST] commit 门**: 登记仓库 commit 前必过 `scripts/commit-check.sh <仓库> "<message>"`(见 关键代码仓库 节); 未登记仓库先登记后提交; 登记/出册必须用户显式确认
- **[MUST] 并行工作区约定**: 多 plan 并行开发走 agentspace-parallel skill(PR-like 本地泳道)。固定位置 `worktrees/<plan-id>/<仓库名>/` 与锁目录 `.locks/` 在**项目根**(非 AGENTSPACE/ 内); 内嵌形态下宿主仓库必须先经 .gitignore 豁免这两个路径(锁 owner 文件含记账 id 字面量, 被 `git add -A` 扫入会触发 commit 门)。并行期台账写操作: 脚本自带锁, 内容文档写前取 `.locks/ledger/`; 永不 `git -C AGENTSPACE add -A` 一把梭(逐路径 add)
- **[MUST] 收尾协议**: 结束项目工作前依次执行 — ① 更新进行中 readme 的"当前状态 · 下一步" ② 运行 `scripts/doctor.sh`(硬错误必须解决, 告警报告用户) ③ 里程碑提交
- **[MUST] 脚本报错恢复**: 报错时禁止自行手工编辑表格; 先跑 `scripts/doctor.sh` 定位, 修复方案与用户确认; **经用户明确确认的一次性手工修复是唯一合法例外**
- **[MUST] 用户规则守护**: 用户规则节的写入/修改/删除只能经用户显式确认; agent 永不自动创建或改写用户规则; agent 提议仅限当前会话内工作或用户指示显现强规则性质时启发式提出(附现象证据), 用户拒绝后同一提议不再重复
- **[MUST] 代码卫生**: 登记仓库内写入的代码、注释与 commit 文本默认遵循 agentspace-code-clean 被动层规则 — 注释只描述代码意图与约束, 禁止过程叙述(写作日期、所用工具/skill、记账与会话上下文), 禁止 why-not-alternative 反馈残留与测试实例引用; 违规由 commit 门语义层与 code-clean 审查报出, 修复由用户驱动; 既有代码/历史的清理与重建仅在用户显式要求时按该 skill 的 CLEANUP 流程执行
- 内容文档(plan 文档 / iteration readme / exp 手册 / notes / utils / tests)由 agent 直接撰写, 使用 templates/ 模板
- 相互引用一律用 id: `plan:NNNN` / `iteration_NNNN` / `exp_NNNN`; 不用路径, 不用 latest(latest 会翻转)
- **里程碑 git 提交**(具体触发点): plan 创建/完成 · iteration 创建/关闭 · exp 创建/完成 · 模块注册 · notes 写入 · tests.md 环境变更 · examples/data 登记 · 用户规则写入 · update 应用 → `git -C AGENTSPACE add -A && commit`, 并告知用户
- agentspace 记账的 git 操作只在 AGENTSPACE/ 内; 代码仓库的 commit 受 commit 门约束(见 关键代码仓库 节), 代码状态用 commit sha 记录, 需要时存 diff(对宿主 HEAD)到 data/
- 状态自检: `scripts/status.sh`; 收尾后及怀疑损坏时运行 `scripts/doctor.sh`
- **禁止读取**: 插件开发数据(`skills/agentspace-update/versions/`、`DEVELOPMENT.md`、`marketplace.json` 等)与项目无关, 禁止在项目工作中读取或引用; 这些数据仅用于插件自身开发

## 用户规则

> 本节由用户维护: 只记录经用户确认的固定工作规则; 与 纪律(内置规则) 同级, 同样使用 [MUST]/[SHOULD]/[MAY] 分级, 一条一规则。
> 创建/修改/删除只能由用户驱动; agent 仅可在当前工作显现强规则性质时启发式提议, 经用户确认后写入(见 纪律 节)。

<!-- 用户规则条目从此处追加 -->
