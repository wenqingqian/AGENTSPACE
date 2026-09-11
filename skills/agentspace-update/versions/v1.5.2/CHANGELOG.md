# AGENTSPACE v1.5.2

Upgrade from v1.5.1. Date: 2026-09-11

## Summary

- **并行原语批次**: 100 轮双泳道实测(FRICTION.md)暴露的四个协调缺口落成脚本原语 — `new-plan.sh --claim NNNN` 原子占位指定 id(并行泳道预告 id 不再被抢先烧掉)、commit-check 把注册仓库的关联 worktree 识别为同一仓库(泳道检出不再需要逐个登记才能过门)、`parallel-workspace.sh --worktree` 按技能唯一合法布局建泳道检出(幂等、复用保留分支、内嵌型未 gitignore 警告)、`doctor [0]` 在泳道活跃时点名泳道名单(脏文件先归属再提交)。
- **--recv 去自回声**: 协同工作台收件箱不再回显本泳道自己发出的广播(行与表头计数一致过滤); `--remove` 级联清理面不变。
- **文档同步**: agentspace-parallel 双语 §3 建树改为规范助手形态、worktree 登记降为可选(门经主仓识别)、§10 清理出册标注条件; 主 skill 双语 quick-ref 行与资产 AGENTS.md plan how 行加 `[--claim NNNN]`(8b 逐字替换一处)。
- **测试**: 新增 t38(占位竞态/自回声/布局助手/门认 worktree/doctor 归属); t31 自回声断言更新到新契约。
- 脚本面全部由 **step 8a** 整体替换; 唯一手工迁移是 AGENTS.md plan how 行的 **8b** 逐字替换; 无 schema/结构变化。

## Changes

### [Addition] new-plan `--claim NNNN` — 指定 id 原子占位
- **What**: `scripts/new-plan.sh "标题" [--claim NNNN]` 在既有 `--base` 之外新增选项: 不取下一个空闲 id 而是占用指定 id。占用要求该 id 完全空闲 — `plan/todo/`、`plan/done/` 无对应文件, 且 plan.md 与 plan/index.md 两张表都无该 id 的普通行(与 `as_next_plan_id` 的并集口径一致; Base 行是 `base:NNNN` 形态, 不参与普通计数也不误挡); 查重与创建在同一把 `as_lock` 锁内完成, 两条泳道争同一 id 时先到者得、后到者收到 `plan:NNNN already exists — a claimed id must be free` 明确报错。非数字参数走 `as_norm_id` 的既有拒绝路径。输出行追加 `(claimed)` 标记; 里程碑提交提示不变。
- **Why**: 双泳道实测中"预告 id 被并行创建抢先烧掉"是真实发生的竞态损耗 — id 是全局递增永不复用的, 烧一个就永久错位; 原子占位让"先宣告后开工"的协作语义有了脚本支撑。
- **Migration**: 脚本由 **step 8a** 从资产整体替换; AGENTS.md plan how 行有一处 **8b** 逐字替换(见下方 AGENTS.md 块)。

### [Fix] commit-check 识别注册仓库的关联 worktree
- **What**: `scripts/commit-check.sh` 在直接登记匹配失败时, 新增一层解析: 经 lib.sh 既有 `as_repo_main_worktree`(v1.2.x 已有, 无新增助手)取该检出所属主仓的规范路径, 再对登记处匹配主仓 — 命中则放行并打印 `note: <worktree> is a linked worktree of registered repo <main> — gated as the same repo`; 主仓也未登记才报 exit 2。门的内容扫描(暂存文件/新增行/ message)始终读取被门检的 worktree 本体, 只有登记归属映射到主仓。空仓/裸仓等取不到主仓的形态回退原报错, 行为不变。
- **Why**: 泳道 worktree 与主检出共享对象库但 toplevel 路径不同, 旧门按路径身份判定登记, 迫使每条泳道逐个 `repos.sh --add` 才能提交 — 实测中两次临场绕过; 门的语义对象是"仓库"而非"检出路径"。
- **Migration**: 脚本由 **step 8a** 整体替换, 工作区无需手工操作。行为适配: 泳道 worktree 过门不再要求登记(agentspace-parallel 双语 §3 已同步该语义); 已登记的 worktree 行为不变, 可按需出册。

### [Addition] parallel-workspace `--worktree` — 泳道布局助手
- **What**: `scripts/parallel-workspace.sh` 新增子命令 `--worktree <plan_id> <repo_path>`(须先 `--init` 登记该 plan): 在技能铁律 1 的唯一合法位置 `<项目根>/worktrees/<plan-id>/<repo-name>/` 建泳道检出, 分支 `plan-<plan-id>`, 起点取主检出当前分支(分离 HEAD 回退 `HEAD`)。前置拒绝三类误用: 仓库路径不存在/非目录(exit 3 — 悬空路径否则会被解析进包含仓, 错误建道)、AGENTSPACE 台账仓库本身(永不建道)、已存在检出但分支不是 `plan-<id>`(印出实际分支, 拒绝重建)。幂等: 同仓库同路径且分支相符的既有 worktree 直接报告成功不重建; 分支已存在时复用而非 `-b` 重建(不满意分层在同一分支迭代、永不重建), 分支尖提交原样保留。项目根位于某 git 仓库内且泳道路径未被其 .gitignore 覆盖时打印 report-only 警告(按主仓相对路径检查, 嵌套内嵌型不误报)。创建后按主仓是否已登记给出对应下一步提示。
- **Why**: 实测中两条泳道各自手搓 `git worktree add`, 路径与命名各异且无脚本收口点; 布局固定后 §10 清理、§8.1 合并、diff 空证明引用的路径才有单一事实源。
- **Migration**: 脚本由 **step 8a** 整体替换, 工作区无需手工操作。

### [Fix] `--recv` 去自回声
- **What**: `ws_recv_rows` 与收件箱计数(`ws_count_msgs` 的 dst 模式)统一过滤 `src==id` — 泳道不再在 `--recv`/`--update`/`--merge` 自动回执里看见自己发出的广播, 行数与表头计数保持一致。`--withdraw`、`--remove` 级联(both 模式)仍看到自己的全部行, 清理面不变。
- **Why**: 广播在发送时已到达受众, 发送者自己再收到只是回声 — 实测中它污染收件箱计数并诱发重复处理。
- **Migration**: 脚本由 **step 8a** 整体替换。行为适配: 依赖"收件箱含自己广播"旧语义的流程会看到更小的收件箱(这正是修复); 插件自带 t31 断言已同步新契约, 工作区自建脚本如有同断言请照改。

### [Fix] doctor [0] 泳道活跃时脏文件归属提示
- **What**: `scripts/doctor.sh` [0] 在台账工作树有未提交改动且协同工作台(`.agentspace-parallel-workspace.txt`)存在活跃 PLAN 行时, 警告从单一的"run a milestone commit"扩展为附泳道名单(`<id>:<state>` 逗号分隔)与归属指引 — 脏文件可能属于某条泳道的工作或 merge 窗口(merge 态归属持锁泳道), 先归属再提交; 泳道非活跃时警告与原文逐字一致。
- **Why**: 并行期台账脏文件是多会话共享面, 主线会话按旧提示直接里程碑提交会把邻泳道的在途改动扫进自己的 commit(§6.2 明令禁止 `git add -A` 的同源风险)。
- **Migration**: 脚本由 **step 8a** 整体替换, 工作区无需手工操作。

### [Fix] agentspace-parallel 双语文档对齐新原语
- **What**: `skills/agentspace-parallel/SKILL.md` + `SKILL.zh-CN.md`: §3 建树命令块改为 `--worktree` 规范形态(手工形态降为等价注释)、`repos.sh --add` 注释从"必须登记否则门不识别"改为"自 v1.5.2 起可选"; 自检三连 ③ 措辞改为"泳道检出经登记的主检出被识别"; §10 清理命令的 `repos.sh --remove` 标注"仅当 §3 登记过时"。主 skill `skills/agentspace/SKILL.md` + `SKILL.zh-CN.md` quick-ref 行与资产 AGENTS.md plan how 行同步 `[--claim NNNN]`。
- **Why**: 技能是会话侧行为的事实源 — 门与脚本语义变了, 流程文档必须同轮收敛, 否则 agent 按旧 MUST 继续逐 worktree 登记。
- **Migration**: 插件侧 skill, 随插件更新交付; **工作区无需任何操作**(资产 AGENTS.md 的 8b 行替换见下块, 由更新流程执行)。

- **AGENTS.md (step 8b — agent action, exact insertion)**(逐字执行, 共 1 处编辑; 文本与规范资产 `skills/agentspace-init/assets/agentspace/AGENTS.md` 一致, 以资产为校对源):

  1. plan 模块 how 行(整行替换): 将 `- **how**: \`scripts/new-plan.sh "标题" [--base NNNN]\` → 撰写 plan/todo/NNNN-*.md(目标/背景/方案步骤) → \`scripts/complete-plan.sh <id> <done|failed|abandoned> "结果"\`` 整行替换为:
     ```markdown
     - **how**: `scripts/new-plan.sh "标题" [--base NNNN] [--claim NNNN]` → 撰写 plan/todo/NNNN-*.md(目标/背景/方案步骤) → `scripts/complete-plan.sh <id> <done|failed|abandoned> "结果"`
     ```

### [Test] t38 并行原语回归 + t31 契约同步
- **What**: 新增 `tests/t38-parallel-primitives-v152.sh`: --claim 的占位/三种占用拒绝(todo/done/索引行)/计数跳位/非数字拒绝; --recv 自回声过滤与直送投递; --worktree 建树/内嵌警告/幂等/未登记 plan 拒绝/保留分支复用; commit-check 对注册仓 worktree 放行、未注册仓 worktree 仍 exit 2; doctor [0] 泳道名单随 `--remove` 递减。`tests/t31-parallel-workspace.sh` 的收件箱计数断言更新为去自回声后的新契约。
- **Why**: 四个原语都是行为契约变更, 需要各自的负向用例钉住; 旧断言与新语义冲突处只改断言不改语义。
- **Migration**: 测试为插件开发侧资产, **工作区无需任何操作**。
