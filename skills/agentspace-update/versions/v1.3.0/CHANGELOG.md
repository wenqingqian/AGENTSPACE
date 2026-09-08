# AGENTSPACE v1.3.0

Upgrade from v1.2.5. Date: 2026-09-08

## Summary

- **新内置模块: exp 实验记录(agentspace-exp)**: 独立登记的实验(度量/验证/调研), 与 plan(为什么/做什么)、iteration(改代码)正交 — exp 管"测代码", 可不关联 plan/iteration。**登记仅限主动**: 用户显式要求走 agentspace-exp, 或 agent 提议一次并经用户确认; 开发收尾的正确性验证等常规实验默认不登记。形态: `exp.md` 入口视图(Todo/Doing/最近完成 10 条) + `exp/index.md` 全量索引(11 列: 实验/状态/关联 plan/关联 iteration/关键 commits/配置/日期/结果) + `exp/{todo,doing,done}/` 实验手册(exp_NNNN-<slug>.md) + `exp/exp_data/exp_NNNN/` 完整实验记录(本机全量, 不入 git; 关联 iteration 的 data/ 产物复制至此)。
- **examples exp_spec 契约**: examples 模块新增硬规则 — 所有经 agentspace-exp 登记的实验, 其配置必须写入 `examples/exp_spec/exp_NNNN/`(由 new-exp.sh 预创建); complete-exp 对空目录(仅 .gitkeep)拒绝关闭, 该子树由 exp 索引的配置列登记, 不在 examples.md 配置清单表登记。
- **三个新脚本**: `new-exp.sh`(登记: 手册 + exp_data/exp_spec 预创建 + 表行 + 索引 + iteration readme 回链) / `start-exp.sh`(开跑: todo→doing, 行节迁移 + 链接重写) / `complete-exp.sh`(关闭: 结果占位门 + 配置门 + commits 点/配置名快照落索引; 接受 doing 或 todo 中的手册 — 小实验可省略 start)。
- **commit 门扩展**: 记账 id 禁令新增 `exp_0NNN`(新常量 COMMIT_BAN_EXP_RE, 前导零锚定零误报), message 与新增行同禁; 不加 exp 候选层扩网(词贴数字误报率高, 每个误报都消耗 agent 裁决)。
- **doctor [16] exp 一致性**: 手册 ↔ exp.md 节 ↔ 索引 ↔ exp_spec(exp_data 本机目录单向检查); --fix 是对账式 — 节↔目录错位先迁行, 无手册才删行; 另守卫 .gitignore 缺 exp/exp_data/ 行(缺行会让下一次里程碑提交把全量实验产物卷进台账历史)。[4] 链接检查名单纳入 exp 表; [7] notes 接受 exp_NNNN 来源。
- **status exp 槽位**: 总览计数(待跑/在跑) + next exp id + 进行中 Doing 行 + 工作区事件(实验登记/完成)。
- **新 skill ×2(双语)**: `agentspace-better-exp`(登记前五轴实验设计讯问: 范围/基线对照/测量准确/数据完整/可复现终止, x-grilling 风格 — 每问带推荐答案, 事实查环境不问用户, 共识确认后才行动)与 `agentspace-better-exp-report`(报告规范: utils 优先复用/色盲配色/一套系列-颜色映射/误差棒注明 n; 文字 — 中文为主保留术语、禁"门/臂"歧义单字、完整优先于精简、**自完备为核心规则**: 阅读者看不到 agent 记忆, 每个符号首现即定义, 每个结论带图/表与数据路径)。
- **close-iteration / complete-plan 关联提醒**: 关闭 iteration 时若有引用它的开放实验, 提醒把 data/ 复制进 exp_data; 完成 plan 时提醒关联实验保持开放(exp 可长于 plan)。
- iteration-readme 模板新增"相关实验"节(new-exp.sh 自动追加, 存量 readme 由脚本按需插入节头); 里程碑提交触发点新增 exp 创建/完成; 根目录 AGENTS.md 模板(仅新 init 生效)同步。
- 无破坏性变更; plan/iteration 既有流程零改动。

## Changes

### [Addition] exp 模块 — 文件与目录
- **What**: 新增内置模块 `exp`。工作区新文件: `AGENTSPACE/exp.md`(入口视图, scripts 维护)与 `AGENTSPACE/exp/index.md`(全量索引, scripts 维护); 新目录: `AGENTSPACE/exp/todo/`、`AGENTSPACE/exp/doing/`、`AGENTSPACE/exp/done/`(各放 .gitkeep); `AGENTSPACE/exp/exp_data/`(不入 git, 由 new-exp.sh 按需创建 exp_NNNN/ 子目录, 迁移无需预建)与 `AGENTSPACE/examples/exp_spec/`(由 new-exp.sh 按需创建 exp_NNNN/ 子目录, 迁移无需预建)。索引 11 列表头: `| ID | 实验 | 状态 | 关联 plan | 关联 iteration | 关键 commits | 配置 | 创建日期 | 完成日期 | 结果 | 链接 |`。
- **Why**: 实验此前只能寄生在 iteration 的 readme/data 里 — 纯度量/调研实验没有归宿, 数据散落; exp 提供独立登记位与权威全量记录。三目录(todo/doing/done)是因为"跑着"是实验的长驻中间态, 目录位置是最廉价的可见信号。
- **Migration**:
  1. **handled by step 8a**(scripts/templates/.gitignore 从资产整体替换 — 含新脚本 new-exp.sh / start-exp.sh / complete-exp.sh 与模板 exp-manual.md, 以及 .gitignore 的 `exp/exp_data/` 行)。
  2. 复制两个新入口文件(新文件, 无合并问题): `skills/agentspace-init/assets/agentspace/exp.md` → `AGENTSPACE/exp.md`; `skills/agentspace-init/assets/agentspace/exp/index.md` → `AGENTSPACE/exp/index.md`。
  3. 创建三个目录(各放 .gitkeep):
     ```bash
     mkdir -p AGENTSPACE/exp/todo AGENTSPACE/exp/doing AGENTSPACE/exp/done
     touch AGENTSPACE/exp/todo/.gitkeep AGENTSPACE/exp/doing/.gitkeep AGENTSPACE/exp/done/.gitkeep
     ```

### [Addition] AGENTS.md — exp 模块节/结构树/纪律/读取规则(8b 精确文本)
- **What**: 工作区 AGENTS.md 五处变更: 结构树 3 行、模块节 exp 小节、examples 小节 exp_spec 契约行、纪律 4 行改写、读取规则 1 行改写。
- **Why**: prompt 体系的入口 — 登记/触发规则(opt-in)、scripts-only 边界、交叉引用 id、里程碑触发点都必须落在 AGENTS.md 才能被每个会话稳定看到。
- **AGENTS.md (step 8b — agent action, exact insertion)**(逐字执行, 共 12 处编辑):

  1. 结构树 exp 行: 找到 `├── data.md + data/    ← 公用数据(训练集/模型权重/软连接; 全部 gitignore)` 一行, 在其**前**插入两行:
     ```markdown
     ├── exp.md             ← exp 入口视图 (Todo + Doing + 最近完成 10 条)
     ├── exp/               ← index.md(全量索引) + todo/ + doing/ + done/ + exp_data/exp_NNNN/(完整实验记录, 不入 git)
     ```
  2. 结构树 examples 行: 将 `├── examples.md + examples/ ← 可复用实验配置(YAML/JSON); 与 tests/ 配合(脚本在 tests/, 配置在 examples/)` 整行替换为:
     ```markdown
     ├── examples.md + examples/ ← 可复用实验配置(YAML/JSON); exp_spec/exp_NNNN/ 为登记实验的专属配置位
     ```
  3. 结构树 templates 行: 将 `├── templates/         ← 文档模板(plan / iteration-readme / module-entry / note / handoff)` 整行替换为:
     ```markdown
     ├── templates/         ← 文档模板(plan / iteration-readme / exp-manual / module-entry / note / handoff)
     ```
  4. 模块节 exp 小节: 找到 `### data —— 公用数据 (data.md + data/)` 标题行, 在其**前**插入(空行分隔):
     ```markdown
     ### exp —— 实验记录 (exp.md + exp/)
     - **what**: 独立登记的实验(度量/验证/调研)。分工: plan 管"为什么/做什么", iteration 管"改代码", exp 管"测代码"; exp 可不关联 plan/iteration(纯度量/调研实验), 关联时经索引的 关联 plan / 关联 iteration 列记录(agentspace-exp 即本模块工作流的称谓, 非斜杠命令)
     - **when**: **用户显式要求走 agentspace-exp, 或 agent 在用户提到要做实验时提议并经用户确认**; 开发收尾的正确性验证等常规实验默认不登记(除非用户确认); 登记前的设计对齐走 agentspace-better-exp skill
     - **how**: `scripts/new-exp.sh "标题" [--plan NNNN] [--iteration NNNN]` → 实验配置**必须**写入 `examples/exp_spec/exp_NNNN/`(脚本预创建) → 运行与结果**全量**落 `exp/exp_data/exp_NNNN/`(关联 iteration 的 data/ 产物复制一份至此; 该目录不入 git, 为本机权威记录) → `scripts/start-exp.sh <id>`(开跑, todo→doing; 小实验可省略) → `scripts/complete-exp.sh <id> <done|failed|abandoned> "结果" [--commit "仓库名@sha,..."]`
     - **commits 语义**: exp 记录测试用关键仓库的 commit **点**(repo@sha, 关闭时落定), 与 iteration 的 commit 窗口(起始/结束)互补; 报告与作图走 agentspace-better-exp-report skill
     ```
  5. examples 小节契约行: 找到 `- **when/how**: 有可复用的实验参数/配置时放入 examples/ 并在 examples.md 登记; 测试脚本通过路径引用 examples/ 下的配置` 一行, 在其**后**追加一行:
     ```markdown
     - **exp_spec 契约**: 所有经 agentspace-exp 登记的实验, 其配置必须写入 `examples/exp_spec/exp_NNNN/`(由 new-exp.sh 预创建, 关闭时空目录会被 complete-exp.sh 拒绝); 该子树由 exp/index.md 的配置列索引, 不在 examples.md 登记
     ```
  6. notes 小节来源(局部替换): 在 notes 小节的 when/how 行内把 `必须带"来源"(plan:NNNN / iteration_NNNN)` 替换为 `必须带"来源"(plan:NNNN / iteration_NNNN / exp_NNNN)`。
  7. 纪律 内容文档行(整行替换): 将 `- 内容文档(plan 文档 / iteration readme / notes / utils / tests)由 agent 直接撰写, 使用 templates/ 模板` 替换为:
     ```markdown
     - 内容文档(plan 文档 / iteration readme / exp 手册 / notes / utils / tests)由 agent 直接撰写, 使用 templates/ 模板
     ```
  8. 纪律 scripts-only 行: 将 `- **[MUST] scripts-only**: plan.md / iterations.md / plan/index.md / iterations/index.md 与 .agentspace-repos **只能由 scripts/ 改写**, 禁止手工编辑` 整行替换为:
     ```markdown
     - **[MUST] scripts-only**: plan.md / iterations.md / exp.md / plan/index.md / iterations/index.md / exp/index.md 与 .agentspace-repos **只能由 scripts/ 改写**, 禁止手工编辑
     ```
  9. 纪律 创建前确认 行: 将 `- **[MUST] 创建前确认**: plan / iteration 创建前必须经用户明确确认; 简单改动不建 plan/iteration` 整行替换为:
     ```markdown
     - **[MUST] 创建前确认**: plan / iteration 创建前必须经用户明确确认; 简单改动不建 plan/iteration。exp 只在用户显式要求走 agentspace-exp、或 agent 提议并经用户确认后创建; 开发收尾的正确性验证等常规实验默认不建 exp(agent 最多提议一次, 用户未确认不登记)
     ```
  10. 纪律 相互引用行: 将整行 `- 相互引用一律用 id: \`plan:NNNN\` / \`iteration_NNNN\`; 不用路径, 不用 latest(latest 会翻转)` 替换为:
     ```markdown
     - 相互引用一律用 id: `plan:NNNN` / `iteration_NNNN` / `exp_NNNN`; 不用路径, 不用 latest(latest 会翻转)
     ```
  11. 纪律 里程碑行(局部替换): 在该行内把 `iteration 创建/关闭 · 模块注册` 替换为 `iteration 创建/关闭 · exp 创建/完成 · 模块注册`。
  12. 读取规则 2(整行替换): 将 `2. 任务相关时读 plan.md; 会话续接时: 有 handoff 先读 \`handoff/index.md\` 选最新并 consume, 否则读 \`iterations/latest/readme.md\` 的"当前状态 · 下一步"` 整行替换为:
     ```markdown
     2. 任务相关时读 plan.md(有登记实验时读 exp.md); 会话续接时: 有 handoff 先读 `handoff/index.md` 选最新并 consume, 否则读 `iterations/latest/readme.md` 的"当前状态 · 下一步"
     ```

### [Addition] examples.md — exp_spec 说明行(8b 精确文本)
- **What**: `AGENTSPACE/examples.md` 头部说明区新增一行(配置清单表结构不变)。
- **Why**: examples.md 是 examples 模块入口, exp_spec 子树的归属规则须在入口可见。
- **Migration**(step 8b, 逐字执行): 在 `AGENTSPACE/examples.md` 中找到 `> tests/ 放入口脚本(如何跑), examples/ 放配置(用什么参数跑)。` 一行, 在其**后**追加:
  ```markdown
  > exp_spec 子树除外: 所有经 agentspace-exp 登记的实验, 其配置必须写入 `examples/exp_spec/exp_NNNN/`(由 new-exp.sh 预创建); 该子树由 exp/index.md 的配置列索引, 不在本表登记。
  ```

### [Schema] 模板: exp-manual 新模板 + iteration-readme 相关实验节
- **What**: 新模板 `templates/exp-manual.md`(节: 实验问题与范围 / 假设与预期 / 方案与配置 / 关联 / 结果 / data 产物清单 / 日志; 结果节含占位注释 `<!-- 一句话结论; 关闭 exp 前必填 -->` = 新常量 RESULT_PH_EXP); `templates/iteration-readme.md` 在"代码变更 (diff)"与"环境"之间新增 `## 相关实验` 节(由 new-exp.sh 自动追加 id 引用; 存量 readme 无需回填, 脚本按需插入节头)。
- **Why**: better-exp 的对齐产出需要确定性落点(问题/假设/方案三节对应五轴); iteration↔exp 的关联需要回链位。
- **Migration**: handled by step 8a(templates 整体替换)。存量文档不强制回填。

### [Addition] agentspace-better-exp skill(第 10 个 skill)
- **What**: `skills/agentspace-better-exp/SKILL.md` + `SKILL.zh-CN.md`。内容: 铁律(确认后才启动/每次一问带推荐答案/事实查环境/无共识不开跑/先覆盖后深挖) + 五轴审讯(范围固定合理 · 基线对照公平含种子与方差 · 测量准确含指标定义/warmup/计时口径/环境噪声 · 数据完整含汇总↔细节链 · 可复现与终止含 pilot 与预算) + 产出契约(沉淀进手册三节后经 new-exp.sh 登记) + 边界(不替代 plan/iteration; 放弃登记即止, 同会话不再提议)。
- **Why**: "抛开固定范围的实验结果没有意义" — 与其在报告阶段发现测量口径错了, 不如开跑前把五个失败模式问穿; x-grilling 的方法(单问+推荐答案+事实/决策分离)证明有效, 实验场景需要特化版。
- **Migration**: 插件侧 skill, 随插件更新交付; **工作区无需任何操作**。触发: 仅在用户选择登记实验后激活(显式要求走 agentspace-exp 或接受提议), 提议本身由主 agentspace skill §2 承担。

### [Addition] agentspace-better-exp-report skill(第 11 个 skill)
- **What**: `skills/agentspace-better-exp-report/SKILL.md` + `SKILL.zh-CN.md`。内容: 动笔之前(utils 优先复用/读全量记录/认清读者) + 作图(外观: 色盲友好默认 Okabe-Ito、全套图一套系列-颜色映射、坐标轴带单位、矢量或 ≥300dpi; 数据: 先分类、清洗规则写明不静默、误差棒注明 n 与语义、派生指标可回溯; 图内文字: 自完备标注、不留裸符号) + 文字(中文为主保留公认英文术语/禁"门""臂"歧义单字/完整优先于精简/**自完备核心规则**) + 结构(结论先行/每图配读法/结论分级/溯源) + 报告落位(完整报告进 exp_data 本机保存, 执行摘要以自完备文字镜像进手册结果节, 不放死链)。
- **Why**: 报告的两大失败模式 — 图不可读(配色随意/无方差/标签孤立)与文不可解(agent 的记忆读者看不见, 裸符号与缺定义的缩写遍布); 训成规范比事后补救便宜。
- **Migration**: 插件侧 skill, 随插件更新交付; **工作区无需任何操作**。

### [Addition] commit 门 exp_NNNN 禁令 + doctor [15] 同步
- **What**: lib.sh 新常量 `COMMIT_BAN_EXP_RE="exp_0[0-9]{3,}"`; commit-check.sh 的 message 扫描与新增行扫描(AS_BAN_RE 默认值与两处调用点)、lib.sh as_diff_added_hits/as_diff_added_candidates 的 AS_BAN_RE 默认值、doctor [15] 的 message 审计全部纳入。不加 exp 候选层(COMMIT_CANDIDATE 不扩展)。
- **Why**: exp id 进入代码仓库 commit 与 plan/iteration id 同罪; 前导零锚定与既有两禁令同构, 零误报。
- **Migration**: handled by step 8a(scripts 整体替换)。

### [Addition] doctor [16] exp 一致性 + [4]/[5]/[7] 扩展
- **What**: 新检查 [16](手册↔exp.md 节↔索引↔exp_spec 双向; exp_data 目录单向; --fix 对账式: 节↔目录错位迁行, 无手册删行; .gitignore 缺 exp/exp_data/ 行告警); [4] 链接检查名单加入 exp.md/exp/index.md; [5] 占位契约加入 RESULT_PH_EXP↔exp-manual.md; [7]/notes 来源契约接受 exp_NNNN([8] 回链纪律仍限 iteration 来源)。
- **Why**: 四个一致性面(目录位置/入口表/全量索引/配置位)跨脚本写入, 中断窗口需要确定性检查兜底; exp_data 本机目录在 fresh clone 缺席, 方向性检查避免恒红。
- **Migration**: handled by step 8a(scripts 整体替换)。

### [Addition] status.sh exp 槽位 + close-iteration/complete-plan 关联提醒
- **What**: status.sh 项目总览加 `exp N 待跑 / M 在跑` 计数与 next exp id, 进行中节加 Doing 行, 工作区事件加实验登记/完成流, 软告警行形状校验名单加 exp.md/exp/index.md; close-iteration.sh 关闭时若有引用本 iteration 的开放实验则提醒复制 data/ 进 exp_data; complete-plan.sh 完成时提醒关联实验保持开放。
- **Why**: 实验是长驻状态, 工作台不可见即不可管理; 数据复制与独立关闭是跨模块衔接最易漏的两步。
- **Migration**: handled by step 8a(scripts 整体替换)。

### [Addition] 主 skill(agentspace)§2 实验工作流
- **What**: `skills/agentspace/SKILL.md` + `SKILL.zh-CN.md` 新增"跑实验 → 登记 exp(仅限主动登记)"小节(提议一次性规则/分工模型/三脚本/报告指向 better-exp-report), 纪律与里程碑行同步 exp 文件与触发点; 为守行数预算(≤120)删除两行冗余(重复的 scripts-only 行与独立的"Milestone commit."行)。
- **Why**: 触发规则("agent 提议一次")必须放在主 skill — better-exp 自身只在确认后激活, 由它提议会自相矛盾。
- **Migration**: 插件侧 skill, 随插件更新交付; **工作区无需任何操作**。

### [Addition] verify-release 门禁扩展(插件侧)
- **What**: [8] 双语名单纳入两个新 skill(并补齐此前遗漏的 agentspace-handoff), 新增机制配对断言(better-exp 的"登记必须经用户显式确认"双语同在); [12] 实字面量守卫派生纳入 COMMIT_BAN_EXP_RE; [13] 更名"assets gitignore contracts"并新增 exp/exp_data/ 行存在性断言。新增测试 t33(exp 生命周期)/t34(doctor [16] + commit 门 + status 槽位)。
- **Why**: 新面必须有门禁覆盖 — [8] 名单是硬编码的, 漏加即无双语校验; [12] 派生是 sed 锚定的, 常量漏派即守卫静默失明; exp_data gitignore 缺行是唯一能静默破坏用户数据卫生的缺口。
- **Migration**: 插件侧, **工作区无需任何操作**。

### 无变更块
- **[Fix] 结构树/模块清单/schema 兼容性**: plan.md / plan/index.md / iterations.md / iterations/index.md / register.md / notes.md / data.md / tests.md / utils.md / handoff 表结构与既有脚本行为**无变更**; .agentspace-repos / .agentspace-whitelist 无变更; 三平台 manifest 结构无变更(仅版本号); commands/ 无新增(两个新 skill 为情境触发, 无命令包装)。Migration: 无 — 无事可做。
