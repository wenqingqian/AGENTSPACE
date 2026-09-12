# AGENTSPACE 工作区

> 本文件是 AGENTSPACE 的入口: 结构总览 + 模块 what/when/how + 操作纪律。
> 进行任务规划 / 项目迭代安排相关工作前必读;
> 并确保本文件内容在上下文中(丢失则重读)。

## agentspace mode
hybrid

## agentspace edition
light

## 项目简介

<!-- 一句话: 这个项目做什么 -->

## 根仓库简介

<!-- 宿主项目(上一层目录)的结构与关键路径。
     关系: AGENTSPACE 是独立 git 管理的工作区; 代码在宿主仓库, 这里只管理任务计划状态。
     工作区常有多个代码仓库: 写明与项目强相关的关键代码仓库、职责与关键入口文件(init 时经分析+用户确认填写)。 -->

## 关键代码仓库

> 登记处 = `.agentspace-repos`(一行一个仓库路径: 项目根内相对路径, 树外绝对路径; 物理路径 + git toplevel 规范化)。
> **只能由 `scripts/repos.sh` 改写**(`--add` / `--remove` / `--list`); 每次登记/出册必须用户显式确认, agent 不得自行登记。
> AGENTSPACE 自身(台账仓库)永远豁免、永不在册。

- **形态**: 内嵌(工作区在代码仓库内 — 宿主须经 .gitignore 或 .git/info/exclude 豁免 AGENTSPACE/, 宿主历史不出现其内容与 gitlink)或分开存放(仓库在树外, 按路径登记)。形态是派生事实, 不存储。
- **commit 门(MUST)**: 在登记仓库执行 `git commit` 前, 必须先运行 `scripts/commit-check.sh <仓库> "<message>"` 并通过(exit 0); 未登记仓库(exit 2)先登记后提交。commit 门与全部代码/注释/commit 文本卫生规则见 agentspace-code-clean skill(被动层默认生效; 主动清理既有代码/历史仅经用户显式要求)。
- **message**: 记账 id(plan:NNNN / base:NNNN / iteration_NNNN / exp_NNNN)与记账叙述永不进入代码仓库 commit; 归属由代码仓库的 commit 记录承担。
- **文件**: 实验产物(`events.out.tfevents.*`、顶层 wandb/mlruns/lightning_logs、≥50MB blob)阻断; 数据扩展名 ≥100KB 与顶层输出目录为 WARN(agent 结合仓库上下文判断)。
- **standalone 模式**: 登记仓库是工作对象, 豁免白名单语义(doctor [13] 不报违规)。
- **审计**: doctor [14](登记一致性/内嵌盾牌/热仓库未登记)与 [15](近期 commit 事后扫描, 只报告不改历史)。

## 结构

```
AGENTSPACE/
├── AGENTS.md          ← 本文件
├── plan.md            ← plan 入口视图 (Todo + 最近 Done 10 条 + Base 基准计划)
├── plan/              ← index.md(全量索引, 含 Base 节) + todo/ + done/(含 完成/失败/放弃) + base/(基准计划, 激活后不可变)
├── .agentspace-repos  ← 关键代码仓库登记处(一行一路径; 只能由 scripts/repos.sh 改写)
├── templates/         ← 文档模板(plan / base-plan / iteration-readme / exp-manual / module-entry / note / handoff)
└── scripts/           ← 状态流转与登记脚本(索引/条目/登记处的唯一写入口) + commit 检查门(commit-check.sh); 未初始化模块的脚本会拒绝并提示
```

## 模块: what / when / how

### plan —— 任务计划 (plan.md + plan/)
- **what**: 一个任务写成一个或多个 plan; 索引自项目创建起全局递增、永不复用
- **when**: 有新任务/目标时创建; 到达明确终点(完成/失败/放弃)时关闭
- **how**: `scripts/new-plan.sh "标题" [--base NNNN] [--claim NNNN]` → 撰写 plan/todo/NNNN-*.md(目标/背景/方案步骤) → `scripts/complete-plan.sh <id> <done|failed|abandoned> "结果"`
- **基准计划(base plan)**: 方向锚点, 服务于"同一方向出现多个 plan、且最终结果不得漂移"的场景。位置 plan/base/, 单独计数(id 形如 base:NNNN), 登记于 plan/index.md 与 plan.md 的 Base 节; 语义上作为由它派生的一切任务(plan/iteration/exp)的最基础约束, 派生 plan 用 `--base NNNN` 声明归属(索引 基准 列)
- **base plan 生命周期**: `scripts/new-base-plan.sh "方向标题"`(产出待审核草稿) → 填写方向/约束/边界 → **直接结束会话呈交用户审核**(不走 agent plan 模式审核; 用户在文件上以评论形式反馈, 待审核期间 agent 可按评论修订草稿) → 用户批准后 `scripts/activate-base-plan.sh <id>`(钉定 sha256 校验, 文件自此**物理不可变**, 任何脚本不再写该文件) → 方向变更只能新建 base plan 后 `scripts/retire-base-plan.sh <id> <replaced|voided> "原因" [--by NNNN]`(旧文件永不改写)。生命周期与审核流细则见 agentspace-base-plan skill

### 未初始化模块(light 工作区)

本工作区由 /agentspace-init-light 创建, **仅含 plan 模块**; iterations / exp / data / examples / utils / tests / notes / register / handoff 均未初始化 — 相关流转脚本(如 new-iteration.sh、new-exp.sh、handoff.sh、register-module.sh)会拒绝并提示。需要这些能力时运行 `/agentspace-update` 扩展为完整工作区(扩展保留全部已有 plan 数据与用户内容)。

## 读取规则

1. **上下文常驻**: 本文件。丢失(如 compact 后)或不确定 → 重新读取
2. 任务相关时读 plan.md; light 工作区无 iterations / exp / handoff 模块, 不读其入口文件
3. 文件夹内部(plan/ 等)**按需读取**, 不预加载

## 纪律

规则分级: `[MUST]` 违反会造成损坏/不可逆; `[SHOULD]` 最佳实践; `[MAY]` 可选。

- **[MUST] scripts-only**: plan.md / plan/index.md 与 .agentspace-repos **只能由 scripts/ 改写**, 禁止手工编辑
- **[MUST] 创建前确认**: plan 创建前必须经用户明确确认; 简单改动不建 plan
- **[MUST] 基准计划不可变**: plan/base/ 下的 base plan 文件激活后严禁修改(激活时校验和已钉定, 改动即损坏, 由 doctor 报出; agent 不得自行改写或"恢复"); 发现 base plan 不可实现或有正确性错误时必须**显式告知用户**, 方向变更(新基准取代/废弃)只能由用户决定; base plan 的创建与修改必须呈交用户审核 — 草稿写好后直接结束会话, 由用户在文件上以评论形式反馈, 激活须待用户明确批准
- **[MUST] commit 门**: 登记仓库 commit 前必过 `scripts/commit-check.sh <仓库> "<message>"`(见 关键代码仓库 节); 未登记仓库先登记后提交; 登记/出册必须用户显式确认
- **[MUST] 并行工作区约定**: 多 plan 并行开发走 agentspace-parallel skill(PR-like 本地泳道)。固定位置 `worktrees/<plan-id>/<仓库名>/` 与锁目录 `.locks/` 在**项目根**(非 AGENTSPACE/ 内); 内嵌形态下宿主仓库必须先经 .gitignore 豁免这两个路径(锁 owner 文件含记账 id 字面量, 被 `git add -A` 扫入会触发 commit 门)。并行期台账写操作: 脚本自带锁, 内容文档写前取 `.locks/ledger/`; 永不 `git -C AGENTSPACE add -A` 一把梭(逐路径 add)
- **[MUST] 收尾协议**: 结束项目工作前依次执行 — ① 更新进行中 plan 文档(方案步骤/结果) ② 运行 `scripts/doctor.sh`(硬错误必须解决, 告警报告用户) ③ 里程碑提交
- **[MUST] 脚本报错恢复**: 报错时禁止自行手工编辑表格; 先跑 `scripts/doctor.sh` 定位, 修复方案与用户确认; **经用户明确确认的一次性手工修复是唯一合法例外**
- **[MUST] 用户规则守护**: 用户规则节的写入/修改/删除只能经用户显式确认; agent 永不自动创建或改写用户规则; agent 提议仅限当前会话内工作或用户指示显现强规则性质时启发式提出(附现象证据), 用户拒绝后同一提议不再重复
- **[MUST] 代码卫生**: 登记仓库内写入的代码、注释与 commit 文本默认遵循 agentspace-code-clean 被动层规则 — 注释只描述代码意图与约束, 禁止过程叙述(写作日期、所用工具/skill、记账与会话上下文), 禁止 why-not-alternative 反馈残留与测试实例引用, 禁止 IP/主机名等机器标识与秘密(token、密钥); 违规由 commit 门语义层与 code-clean 审查报出, 修复由用户驱动; 既有代码/历史的清理与重建仅在用户显式要求时按该 skill 的 CLEANUP 流程执行
- 内容文档(plan 文档)由 agent 直接撰写, 使用 templates/ 模板
- 相互引用一律用 id: `plan:NNNN` / `base:NNNN` / `iteration_NNNN` / `exp_NNNN`; 不用路径, 不用 latest(latest 会翻转)
- **里程碑 git 提交**(具体触发点): plan 创建/完成 · base plan 创建/激活/取代/废弃 · 用户规则写入 · update 应用 → `git -C AGENTSPACE add -A && commit`, 并告知用户
- agentspace 记账的 git 操作只在 AGENTSPACE/ 内; 代码仓库的 commit 受 commit 门约束(见 关键代码仓库 节), 代码状态用 commit sha 记录
- 状态自检: `scripts/status.sh`; 收尾后及怀疑损坏时运行 `scripts/doctor.sh`
- **禁止读取**: 插件开发数据(`skills/agentspace-update/versions/`、`DEVELOPMENT.md`、`marketplace.json` 等)与项目无关, 禁止在项目工作中读取或引用; 这些数据仅用于插件自身开发

## 用户规则

> 本节由用户维护: 只记录经用户确认的固定工作规则; 与 纪律(内置规则) 同级, 同样使用 [MUST]/[SHOULD]/[MAY] 分级, 一条一规则。
> 创建/修改/删除只能由用户驱动; agent 仅可在当前工作显现强规则性质时启发式提议, 经用户确认后写入(见 纪律 节)。

<!-- 用户规则条目从此处追加 -->
