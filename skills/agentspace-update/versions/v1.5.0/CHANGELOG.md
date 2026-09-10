# AGENTSPACE v1.5.0

Upgrade from v1.4.0. Date: 2026-09-10

## Summary

- **base plan(基准计划)**: plan 模块新增不可变方向锚点 — 位置 `plan/base/`, 单独计数(id 形如 `base:NNNN`), 登记于 plan/index.md 与 plan.md 新增的 Base 节; 生命周期 待审核→生效→被取代/废弃 由三个新脚本驱动, 激活时钉定文件 sha256 前 12 位, doctor [17] 对账式审计不可变性(不符=损坏, 只报告永不自动改写)。
- **派生关系**: 普通 plan 的 Todo 表与全量索引新增 `基准` 列, `new-plan.sh --base NNNN` 声明归属; doctor [17] 对"开放 plan 链接到非生效基准"只报告 — 方向分歧显式交用户决断。
- **审核流与不可变规则内置**: 部署 AGENTS.md 的 plan 模块/纪律/结构树/里程碑行改写(逐字迁移见 Changes); commit 门禁令扩展 `base:0NNN`(message 与新增行同扫); 新增第 13 个 skill agentspace-base-plan(双语)持有创建门与"草稿写好后直接结束会话、用户在文件上评论"的审核流契约。
- **schema 迁移(8b)**: plan.md 与 plan/index.md 两张表加列/加节、创建 `plan/base/`(见 Changes 的 Workspace schema 块 — 不迁移则新脚本行为错位, 必须与 8a 同次更新执行)。
- **发布门与测试**: verify-release [8] 新增 base-plan 审核流双语机制配对、[12] 字面量守卫纳入 base 正则; 新增 t36 生命周期测试; t13 回放表补 v1.5.0 ops; 顺手补 v1.4.0 遗留(资产 AGENTS.md message 行缺 exp 枚举)。
- 纯新增能力, 无破坏性变更; 既有 plan/iteration/exp 流程零改动(complete-plan 索引列位随 schema 迁移内部调整)。

## Changes

### [Addition] base plan 组件 — 三脚本 + doctor [17] + status 集成 + commit 门禁令
- **What**: 新增 `scripts/new-base-plan.sh`(产出 待审核 草稿 + 双表登记, 输出审核流 MUST 提示)、`activate-base-plan.sh`(待审核→生效, 方向占位符未填拒绝, python3 sha256 前 12 位钉入索引行 校验 列, 此后任何脚本不再写该文件)、`retire-base-plan.sh <id> <replaced|voided> "原因" [--by NNNN]`(被取代要求后继已生效; 文件永不改写, 退役行只留全量索引)。lib.sh 新增 `SEC_BASE` / `COMMIT_BAN_BASE_RE` / `BASE_PH_DIR` 常量与 `as_next_base_id`(独立计数: 扫 plan/base/ 文件名 + `base:` 行, 与普通 plan 计数器物理隔离)、`as_slug_of`(slug 推导与硬校验单一事实源, new-plan/new-exp 同步收编)、`as_row_key`(行匹配助手接受 `base:NNNN` 形态)。doctor 新增 [17]: 文件↔Base 行双向对账(孤儿行 --fix 删除、孤儿文件只报告)、入口视图与索引开放态双向和解(--fix 依索引重建)、校验和对账(不符=硬报告, --fix 亦不改写)、派生链接审计(目标缺失必报; 非 生效 目标仅在派生 plan 开放时报)。commit 门: `base:0NNN` 加入 message/新增行双扫硬禁令(commit-check.sh 三处 union 与两处人读枚举、doctor [15]、as_diff_added_hits/candidates 默认值)。status.sh: 现状行加 base 计数与 next base id、进行中节首列基准行并在 plan 行尾附 (base:NNNN)、事件流加 基准创建/基准激活、软告警加待审核草稿提醒。普通 plan: `new-plan.sh "标题" [--base NNNN[,NNNN...]]`(校验存在性, 落 基准 列, 缺省 `-`), complete-plan.sh 索引行更新列位随新 schema 调整($4 状态/$7 完成日期/$8 结果/$9 链接)。
- **Why**: 快速迭代下 plan 被反复改写、同一功能多 plan 并行, 结果逐步偏离初衷 — 需要一类"创建后不可变"的方向锚点作为派生任务的最基础约束; 不可变以"激活时哈希钉定 + 对账审计"物理落地, 方向分歧只能由用户决断(新基准取代, 旧文件永不改写)。
- **Migration**: 三脚本与 lib.sh/doctor.sh/status.sh/commit-check.sh/new-plan.sh/complete-plan.sh/new-exp.sh 由 **step 8a** 从资产整体替换, 工作区无需手工操作; 表结构见下方 Workspace schema 块。

### [Addition] agentspace-base-plan skill(第 13 个, 双语)
- **What**: `skills/agentspace-base-plan/SKILL.md` + `SKILL.zh-CN.md` — 启动守卫、创建门(仅用户驱动, 是方向不是实施计划)、**审核流(草稿写好后直接结束会话, 用户在文件上评论反馈; 绝不自批, 绝不在创建会话内激活; 修订后同样呈交)**、生命周期三脚本、不可变与方向变更规则。主 skill agentspace 双语在 plan 工作流后加指针小节, `new-plan.sh` 行加 `[--base NNNN]`, 相互引用行与里程碑行同步 base(行数 118/120 预算内, MUST/SHOULD/MAY 令牌双语平衡)。
- **Why**: 审核流是本功能的核心机制(不走 agent plan 模式审核) — 值得独立 skill 承载完整契约, 主 skill 只留指针。
- **Migration**: 插件侧 skill, 随插件更新交付; **工作区无需任何操作**。

### [Fix] AGENTS.md 内置 base 规则(8b 精确文本)
- **What**: 资产 AGENTS.md 十处编辑: 结构树 plan.md/plan//templates 三行、plan 模块 how 行 + 新增 基准计划/生命周期 两 bullet、纪律新增 `[MUST] 基准计划不可变`、相互引用行加 `base:NNNN`、里程碑行加 base plan 触发点、关键代码仓库 message 行补全枚举(顺手修复 v1.4.0 遗留: 该行缺 exp 枚举)。root-AGENTS.md 模板硬规则新增基准计划一行; init 双语 SKILL.md 追加块同步该行(均仅新 init 生效, 既有项目根 AGENTS.md 属用户内容不迁移)。
- **Why**: 不可变与审核流是 MUST 级纪律, 必须常驻工作区入口文档, 不能只靠 skill 触达。
- **AGENTS.md (step 8b — agent action, exact insertion)**(逐字执行, 共 9 处编辑; 文本与规范资产 `skills/agentspace-init/assets/agentspace/AGENTS.md` 一致, 以资产为校对源):

  1. 结构树 plan.md 行(整行替换): 将 `├── plan.md            ← plan 入口视图 (Todo + 最近 Done 10 条)` 整行替换为:
     ```markdown
     ├── plan.md            ← plan 入口视图 (Todo + 最近 Done 10 条 + Base 基准计划)
     ```
  2. 结构树 plan/ 行(整行替换): 将 `├── plan/              ← index.md(全量索引) + todo/ + done/(含 完成/失败/放弃)` 整行替换为:
     ```markdown
     ├── plan/              ← index.md(全量索引, 含 Base 节) + todo/ + done/(含 完成/失败/放弃) + base/(基准计划, 激活后不可变)
     ```
  3. 结构树 templates 行(整行替换): 将 `├── templates/         ← 文档模板(plan / iteration-readme / exp-manual / module-entry / note / handoff)` 整行替换为:
     ```markdown
     ├── templates/         ← 文档模板(plan / base-plan / iteration-readme / exp-manual / module-entry / note / handoff)
     ```
  4. plan 模块 how 行(整行替换): 将 `- **how**: `scripts/new-plan.sh "标题"` → 撰写 plan/todo/NNNN-*.md(目标/背景/方案步骤) → `scripts/complete-plan.sh <id> <done|failed|abandoned> "结果"`` 整行替换为:
     ```markdown
     - **how**: `scripts/new-plan.sh "标题" [--base NNNN]` → 撰写 plan/todo/NNNN-*.md(目标/背景/方案步骤) → `scripts/complete-plan.sh <id> <done|failed|abandoned> "结果"`
     ```
  5. plan 模块新增两 bullet(在该模块 `- **how**:` 行之后插入, 保持 bullet 相邻):
     ```markdown
     - **基准计划(base plan)**: 方向锚点, 服务于"同一方向出现多个 plan、且最终结果不得漂移"的场景。位置 plan/base/, 单独计数(id 形如 base:NNNN), 登记于 plan/index.md 与 plan.md 的 Base 节; 语义上作为由它派生的一切任务(plan/iteration/exp)的最基础约束, 派生 plan 用 `--base NNNN` 声明归属(索引 基准 列)
     - **base plan 生命周期**: `scripts/new-base-plan.sh "方向标题"`(产出待审核草稿) → 填写方向/约束/边界 → **直接结束会话呈交用户审核**(不走 agent plan 模式审核; 用户在文件上以评论形式反馈, 待审核期间 agent 可按评论修订草稿) → 用户批准后 `scripts/activate-base-plan.sh <id>`(钉定 sha256 校验, 文件自此**物理不可变**, 任何脚本不再写该文件) → 方向变更只能新建 base plan 后 `scripts/retire-base-plan.sh <id> <replaced|voided> "原因" [--by NNNN]`(旧文件永不改写)。生命周期与审核流细则见 agentspace-base-plan skill
     ```
  6. 纪律节新增一行(在 `- **[MUST] 创建前确认**: ...` 行之后插入):
     ```markdown
     - **[MUST] 基准计划不可变**: plan/base/ 下的 base plan 文件激活后严禁修改(激活时校验和已钉定, 改动即损坏, 由 doctor 报出; agent 不得自行改写或"恢复"); 发现 base plan 不可实现或有正确性错误时必须**显式告知用户**, 方向变更(新基准取代/废弃)只能由用户决定; base plan 的创建与修改必须呈交用户审核 — 草稿写好后直接结束会话, 由用户在文件上以评论形式反馈, 激活须待用户明确批准
     ```
  7. 相互引用行(整行替换): 将 `- 相互引用一律用 id: `plan:NNNN` / `iteration_NNNN` / `exp_NNNN`; 不用路径, 不用 latest(latest 会翻转)` 整行替换为:
     ```markdown
     - 相互引用一律用 id: `plan:NNNN` / `base:NNNN` / `iteration_NNNN` / `exp_NNNN`; 不用路径, 不用 latest(latest 会翻转)
     ```
  8. 里程碑行(整行替换): 将 `- **里程碑 git 提交**(具体触发点): plan 创建/完成 · iteration 创建/关闭 · exp 创建/完成 · ...` 行中的 `plan 创建/完成 · iteration 创建/关闭` 替换为 `plan 创建/完成 · base plan 创建/激活/取代/废弃 · iteration 创建/关闭`(其余不动)。
  9. 关键代码仓库 message 行(整行替换): 将 `- **message**: 记账 id(plan:NNNN / iteration_NNNN)与记账叙述永不进入代码仓库 commit; 归属由 iteration readme 的宿主 SHA 记录承担。` 整行替换为:
     ```markdown
     - **message**: 记账 id(plan:NNNN / base:NNNN / iteration_NNNN / exp_NNNN)与记账叙述永不进入代码仓库 commit; 归属由 iteration readme 的宿主 SHA 记录承担。
     ```

### [Schema] plan.md / plan/index.md 表结构与 plan/base/ 目录(8b — 必须执行)
- **What**: 两表加列/加节 + 新目录。**step 8a 不会替换这两个文件**(它们是数据文件; 资产种子只服务新工作区), 已有工作区必须按下述逐字迁移, 否则新脚本列位错位。
- **Workspace schema (step 8b — agent action, exact rebuild)**:

  1. `AGENTSPACE/plan.md` Todo 表: 表头行替换为 `| ID | 计划 | 基准 | 创建日期 | 链接 |`, 分隔行替换为 `| --- | --- | --- | --- | --- |`; 既有 Todo 数据行在 `计划` 单元格之后、`创建日期` 之前插入 ` - `(无关联基准)。
  2. `AGENTSPACE/plan.md` 文件末尾追加(逐字):
     ```markdown

     ## Base 基准计划

     > 方向锚点: 待审核 / 生效; 退役(被取代/废弃)只留全量索引。生效后的文件不可变 — 修改即损坏(doctor 报出)。

     | ID | 方向 | 状态 | 创建日期 | 链接 |
     | --- | --- | --- | --- | --- |
     ```
  3. `AGENTSPACE/plan/index.md` 默认表: 表头行替换为 `| ID | 计划 | 状态 | 基准 | 创建日期 | 完成日期 | 结果 | 链接 |`, 分隔行同步 8 列; 既有数据行在 `状态` 单元格之后、`创建日期` 之前插入 ` - `。
  4. `AGENTSPACE/plan/index.md` 文件末尾追加(逐字):
     ```markdown

     ## Base 基准计划

     | ID | 方向 | 状态 | 创建日期 | 审核日期 | 校验 | 备注 | 链接 |
     | --- | --- | --- | --- | --- | --- | --- | --- |
     ```
  5. 创建目录: `mkdir -p AGENTSPACE/plan/base && touch AGENTSPACE/plan/base/.gitkeep`。
  6. plan.md 头部 blockquote 的维护脚本清单行同步为 `由 scripts/ 维护(new-plan.sh / complete-plan.sh / new-base-plan.sh / activate-base-plan.sh / retire-base-plan.sh)`(该行同时含 `plan/base/ 下` 的指引更新: 将 `单个计划内容在 plan/todo|done/ 下, 按需读取。` 替换为 `单个计划内容在 plan/todo|done/ 下, 基准计划(base plan)在 plan/base/ 下, 按需读取。`); plan/index.md 头部 blockquote 末尾追加一行 `> 基准计划(base plan)单独计数(id 形如 base:NNNN), 登记在下方 Base 节; 状态: 待审核 / 生效 / 被取代 / 废弃, 校验列为激活时钉定的文件 sha256 前 12 位 — 生效后的 base plan 文件不可变, 校验不符即损坏。`(与资产种子逐字一致)。
- **Why**: 基准列与 Base 节是派生关系和单独计数的登记面; 加列而非另立文件, 保持 plan 模块单一入口。
- **Migration**: 即上述 6 步; 完成后 `doctor.sh` 应全绿([17] 对空 Base 节静默)。

### [Addition] templates/base-plan.md 模板
- **What**: 新模板 方向/约束/边界/用户审核记录 四节, 头部 blockquote 声明不可变契约; `BASE_PH_DIR` 占位符为激活闸门(方向未填拒绝激活)。init 脚本 mkdir 清单加 `plan/base` 与其 .gitkeep。
- **Why**: 基准计划文档形状与普通 plan 不同(无状态行、无结果节 — 状态只活在表格, 文件创建后脚本零写入)。
- **Migration**: 模板与 init 脚本由 **step 8a** 替换; `plan/base/` 目录创建见 Workspace schema 第 5 步。

### [Fix] 发布门与测试 — [8]/[12] 扩展 + t36 新增 + t13 回放补 op
- **What**: `verify-release.sh` [8] 机制配对清单新增 skills/agentspace-base-plan 的 `Immediately end the session` / `直接结束本会话` 双语对; [12] 字面量守卫的 LIT_RE 提取纳入 `COMMIT_BAN_BASE_RE`。新增 `tests/t36-base-plan.sh`(生命周期: 草稿登记/占位符与 slug 拒绝/独立计数/激活钉哈希/篡改 doctor 红/退役与后继校验/--base 联链与非法拒绝/链接非生效基准只报告/孤儿行 --fix/入口视图和解); `tests/t13-upgrade-chain.sh` 回放表补 v1.5.0 ops(AGENTS.md 十处 + 两表 schema 重建, 文本自资产实时取行); `tests/t18-commit-gate.sh` 补 base: 消息禁令断言; AGENTSPACE/tests.md 登记 t36。
- **Why**: 审核流与 base 禁令是载荷机制 — 机制配对防双语漂移, t36 防结构回退, t13 是升级链第二事实源。
- **Migration**: 仅仓库侧开发工具; **工作区无需任何操作**。

### 无变更块
- iterations/exp/data/examples/utils/tests/notes/register/handoff 模块的文件、表结构与脚本行为**零改动**(exp/index.md、iterations/index.md 等不受 基准 列影响); 三平台 manifest 结构无变更(仅版本号); skills/agentspace-status 的输出模板形状无变更(新增行均为既有节内数据行)。本版本 step 8a(脚本/模板)+ 8b(AGENTS.md 十处 + schema 六步)+ 8c(标记)齐全。
