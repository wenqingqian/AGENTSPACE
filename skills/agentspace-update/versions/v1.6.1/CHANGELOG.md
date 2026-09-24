# AGENTSPACE v1.6.1

Upgrade from v1.6.0. Date: 2026-09-24

## Summary

- exp 登记粒度上移为目标级: 一个 exp = 一个大目标下的一组实验轮次, 新的大目标才登记(仍须用户确认), 同一目标的后续小轮次归并进行中 exp, 不再一轮一个 exp
- 新增 `scripts/reopen-exp.sh`: 已关闭 exp 的后续小更新经重开(done→doing)后归并, 此前结论留痕于手册"日志"节
- exp 手册模板新增"轮次"节(每轮: 变更/配置/结果/数据, append-only); 目标级五轴对齐只在登记时做一次, 后续轮次做增量核对
- agentspace-exp skill 双语、命令包装、日 skill 快览、资产 AGENTS.md exp 节/纪律行/里程碑行、根 AGENTS.md 硬规则行同步目标粒度语义

## Changes

### [Addition] exp 目标粒度: 登记门 + 后续轮次归并语义
- **What**: exp 从"一轮实验一个 exp"改为"一个 exp = 一个大目标下的一组实验轮次"。登记门不变且粒度上移: 新的大目标才登记(用户显式要求 /agentspace-exp、或 agent 同会话最多提议一次并经确认); 同一目标下的新参数轮/补测/增量结果追加进**进行中(todo/doing)**的 exp — 手册"轮次"节按轮追加、配置入 examples/exp_spec/(建议按轮命名, 如 run1-baseline.yaml)、数据入 exp_data/(建议按轮建子目录), 不新开 exp、无需再次确认(agent 报备即可); 归属不清(算后续轮次还是新目标)问用户; 已关闭 exp 的后续小更新先 `scripts/reopen-exp.sh <id> ["原因"]` 重开再归并。complete-exp 收紧为**目标有结论时才关闭**(每轮结论留在"轮次"节, "结果"节写目标级最终结论)。exp/index.md 表结构与 exp.md 视图无任何变化。
- **Why**: 原粒度下每有一点新内容就新开 exp, 既稀释记录又让登记确认门形同虚设; 目标级登记一次确认、轮次级报备归并, 才与"登记门管登记、不管推进"的语义一致。
- **Migration**:
  1. (handled by step 8a) `scripts/new-exp.sh` / `start-exp.sh` / `complete-exp.sh` 的提示行与头注、lib.sh 的 as_remove_row_section 修复、新脚本 `scripts/reopen-exp.sh`(新文件随 scripts/ 整体复制)、`templates/exp-manual.md`(新增 轮次 节) — 均随步骤 8a 从资产整体替换/部署, agent 无需手动操作。
  2. **AGENTS.md (step 8b — agent action, exact insertion)**(逐字执行, 共 3 处编辑; 文本与规范资产 `skills/agentspace-init/assets/agentspace/AGENTS.md` 一致, 以资产为校对源):
     - 编辑 1(模块节 exp 小节整节替换)— 定位: 以 `- **what**: 独立登记的实验(度量/验证/调研)。分工:` 开头、以 `互补; 报告与作图走 agentspace-better-exp-report skill` 结尾的现有 4 个 bullet(`what`/`when`/`how`/`commits 语义`)整体替换为:
     ```markdown
     ### exp —— 实验记录 (exp.md + exp/)
     - **what**: 独立登记的实验**大目标**(度量/验证/调研)。**一个 exp = 一个大目标下的一组实验轮次**, 不是一轮一个 exp: 目标登记一次, 各轮在 exp 内推进。分工: plan 管"为什么/做什么", iteration 管"改代码", exp 管"测代码"; exp 可不关联 plan/iteration(纯度量/调研实验), 关联时经索引的 关联 plan / 关联 iteration 列记录(agentspace-exp 是本模块的触发器 — `/agentspace-exp` 命令 + 同名 skill, 持有登记门与生命周期; 设计对齐/报告由 better-exp 系列两个正式 skill 承担)
     - **when**: **新的大目标才登记**: 用户显式要求走 /agentspace-exp, 或 agent 在用户提到要做实验时提议一次并经用户确认; 开发收尾的正确性验证等常规实验默认不登记(除非用户确认); 登记前的设计对齐走 agentspace-better-exp skill。**后续轮次归并**: 同一目标下的新参数轮/补测/增量结果追加进**进行中(todo/doing)**的 exp — 手册"轮次"节按轮追加、配置入 examples/exp_spec/、数据入 exp_data/, 不新开 exp、无需再次确认(agent 报备即可); 归属不清(算后续轮次还是新目标)问用户; **已关闭 exp 的后续小更新先 `scripts/reopen-exp.sh <id> ["原因"]` 重开再归并**, 不为此新开 exp
     - **how**: `scripts/new-exp.sh "标题" [--plan NNNN] [--iteration NNNN]` → 实验配置**必须**写入 `examples/exp_spec/exp_NNNN/`(脚本预创建; 多轮建议按轮命名, 如 run1-baseline.yaml) → 运行与结果**全量**落 `exp/exp_data/exp_NNNN/`(建议按轮建子目录; 关联 iteration 的 data/ 产物复制一份至此; 该目录不入 git, 为本机权威记录) → `scripts/start-exp.sh <id>`(开跑, todo→doing; 小实验可省略) → 每一轮在手册"轮次"节追加记录(变更/配置/结果/数据) → `scripts/complete-exp.sh <id> <done|failed|abandoned> "结果" [--commit "仓库名@sha,..."]`(**目标有结论时才关闭**; 每轮结论留在"轮次"节, "结果"节写目标级最终结论)
     - **轮次记录**: 手册"轮次"节 append-only, 每轮一个三级标题(本轮问题/相对上一轮的变更(单变量)/配置/结果/数据); 目标级五轴设计对齐只在登记时做一次, 后续轮次做增量核对(改了什么、是否仍单变量); 重开经 reopen-exp.sh(done→doing, 此前结论留痕于手册"日志"节)
     - **commits 语义**: exp 记录测试用关键仓库的 commit **点**(repo@sha, 关闭时落定; 重开后再关闭时重新快照), 与 iteration 的 commit 窗口(起始/结束)互补; 报告与作图走 agentspace-better-exp-report skill
     ```
     - 编辑 2(纪律节 创建前确认行)— 旧文本 `exp 只在用户显式要求走 /agentspace-exp、或 agent 提议并经用户确认后创建; 开发收尾的正确性验证等常规实验默认不建 exp` 替换为 `exp 只在用户显式要求走 /agentspace-exp、或 agent 提议并经用户确认后创建(**新的大目标才登记**; 同一目标的后续轮次归并进行中 exp、已关闭的先重开, 不为此新开 — 见 exp 模块节); 开发收尾的正确性验证等常规实验默认不建 exp`。
     - 编辑 3(纪律节 里程碑行)— 旧片段 `exp 创建/完成 · 模块注册` 替换为 `exp 创建/完成/重开 · 模块注册`。
  3. **根 AGENTS.md (step 8b — agent action, exact insertion)**(逐字执行, 共 1 处编辑; 项目根 AGENTS.md 的 硬规则 节, 用户内容保留): 旧片段 `或经确认提议后登记, 设计对齐走 agentspace-better-exp` 替换为 `或经确认提议后登记 — 一个 exp = 一个大目标, 同一目标的后续轮次归并进行中 exp、已关闭的先经 reopen-exp.sh 重开, 不为此新开 exp; 设计对齐走 agentspace-better-exp`。
  4. 既有**进行中**(exp/todo|doing)的 exp 手册不强制改写: 下一次向该 exp 追加轮次时, 在"方案与配置"节之后插入 `## 轮次` 标题(记法参考 `templates/exp-manual.md` 注释), 历史轮次按"日志"节回溯补记, 缺失不阻塞。
  5. 插件侧(skill 双语 / 命令包装 / 日 skill 快览 / README)随插件发布, 工作区无需操作。

### [Addition] reopen-exp.sh 重开已关闭 exp
- **What**: 新增 `scripts/reopen-exp.sh <id> ["原因"]`(模块守卫 as_require_module exp.md exp、参数校验后持锁): 手册 done→doing、exp.md 最近完成行→Doing 行(开始日期=今天; 已跌出最近 10 条视图的关闭行只新增 Doing 行)、exp/index.md 状态→doing 且清空 完成日期/结果 两格(commits/配置 快照保留, 下次关闭时重新落定)、链接改写为 doing 路径; 改写索引**前**在手册"日志"节追加一行留痕此前结论(状态/完成日期/结果); 状态行改写为 `> 状态: doing`。拒绝面: 仍处于 todo/doing 的 exp(提示直接追加轮次)、未知 id、状态行与目录不符(状态异常, 指向 doctor)。重开是里程碑提交(提示经 as_commit_hint)。
- **Why**: 目标已关闭后又有小更新时, 新开 exp 会重新走登记门且拆散同一目标的记录; 重开保持"一个目标一个 exp"。
- **Migration**: (8a 自动) 新脚本随步骤 8a 从资产复制部署(scripts/ 整体替换), agent 无需手动创建。表结构与视图无变化, 已关闭 exp 不受影响。

### [Addition] exp 手册模板"轮次"节
- **What**: `templates/exp-manual.md` 在"方案与配置"与"关联"之间新增 `## 轮次` 节(注释给出每轮三级标题的记法: 本轮问题/变更(单变量)/配置/结果/数据, 按轮命名与子目录建议); "实验问题与范围"/"方案与配置"注释补目标级定位; "data 产物清单"注释补多轮说明; "结果"节锚行(`<!-- 一句话结论; 关闭 exp 前必填 -->`)逐字保留, lib.sh 常量无变化。
- **Why**: 轮次记录需要确定的落点与记法, 模板注释是工作区内的就近纪律。
- **Migration**: (8a 自动) 模板随步骤 8a 整体替换。新登记的 exp 即带"轮次"节; 既有手册见上一变更块的迁移第 4 条(追加轮次时按需补节, 不强制)。

### [Fix] as_remove_row_section 对含正则元字符的节名静默不匹配
- **What**: lib.sh 的 `as_remove_row_section` 此前把节名拼进动态正则(`("^" sec "[[:space:]]*$")`), 含正则元字符的节名(如 `最近完成 (10 条)` 的括号)被编译为分组符, 永不匹配 → 该节内的行删除静默 no-op。修复为字面匹配(节名经 ENVIRON 传入并转义 `[][\\.^$*+?(){}|]` 后匹配)。reopen-exp.sh 的 最近完成→Doing 行迁移依赖该 helper, 由此暴露; 其余现存调用方(Todo/Doing/进行中等无元字符节名)行为不变。
- **Why**: helper 的文档语义是"按节界定删除", 正则化拼接使其在带括号节名上静默失效 — 数据留在原节正是它要防止的形状。
- **Migration**: (8a 自动) scripts 随步骤 8a 整体替换, agent 无需手动操作。

### [Addition] 发版工具与门禁同步
- **What**: verify-release [8] 新增 agentspace-exp 目标粒度机制对(EN/zh 各一短语); tests 新增 t40(exp 目标分组与重开回归: 模板节/提示行/SKILL 与资产文本契约/reopen 全流程与拒绝面/追加轮次后再关闭); t39 模块拒绝面从七个脚本扩为八个(补 reopen-exp.sh); t13 升级链补 v1.6.1 ops(exp 节整节替换等按本文本执行)。均为仓库根开发工具/测试, 不进入部署工作区。
- **Why**: 新语义与机制须有门禁锚点, 防止后续改动静默漂移。
- **Migration**: 开发工具与测试, 工作区无需操作。
