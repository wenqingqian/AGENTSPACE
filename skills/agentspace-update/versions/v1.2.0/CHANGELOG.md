# AGENTSPACE v1.2.0

Upgrade from v1.1.0. Date: 2026-09-07

## Summary

- **新增 `AGENTSPACE/scripts/parallel-workspace.sh`(协同 agent workspace 表)**: 共享 plan 状态表(PLAN 行, 状态 doing/test/merge)+ 异步便签(MSG 行, 点对点或 `all` 广播); 单把文件锁覆盖全程 + 逐写原子 mv; merge 态全表独占(短窗铁律: 至多一个 plan 持 merge, 占用等 60 秒重检一次), MERGELOCK 时间戳超 15 分钟判 stale 自动回退 doing 接管。数据文件 `AGENTSPACE/.agentspace-parallel-workspace.txt`(台账内, gitignore)。
- **`AGENTSPACE/.gitignore` 新增 `.agentspace-parallel-workspace.txt` 行**: 运行期数据文件必须挡在 git 之外 — 由 step 8a 的 .gitignore 整体替换自动带入, 无手工动作(精确行见下)。
- **agentspace-parallel skill 四项增强(仅插件侧 skill 文本)**: ① 固定 worktree 路径 MUST(铁律 1 + §3: 只能 `<项目根>/worktrees/<plan-id>/<repo名>`, 其他位置一律禁止); ② 历史改写探测(§7a + §8.1: `git merge-base --is-ancestor <base> <主线>`, 纯元数据改写 → 重指锚点继续, 改写动了内容 → 走正常 absorb; 其本身绝不构成冻结); ③ 合回前后双报告挂点(§4 收尾: 泳道全 diff 的 commit 门语义层全维审查, 报告层不阻塞; §8.1 step 4 合回后: code-clean 批量注释审查, 只报告); ④ 新增 §6.5 协同 agent workspace(协同表登记: 启动 `--init` / 收尾 `--remove` 为 MUST, 其余按需)。**工作区无迁移动作。**
- 本版本无模块清单、结构树、template、表 schema 变更; **AGENTS.md 无任何文本操作(本版无 step 8b)**。

## Changes

### [Addition] scripts/parallel-workspace.sh(协同 agent workspace 表)

- **What**: 工作区新增第 13 个脚本 `AGENTSPACE/scripts/parallel-workspace.sh`, 由 agentspace-parallel skill §6.5 调用。行式数据文件 `AGENTSPACE/.agentspace-parallel-workspace.txt`(`|` 分隔, 自由文本经 as_cell 转义存储、读取时原样呈现), 两类行:

  ```
  PLAN|<plan_id>|<state>|<plan_desc>|<any_info>     plan_id 数字 0001 形(as_norm_id); state ∈ {doing,test,merge}
  MSG|<src_plan_id>|<dst_plan_id|all>|<iso_time>|<msg>
  ```

  API: `--init <id> <desc> [info]`(登记, 重复 id 报错)/ `--remove <id>`(删行并级联清该 plan 全部 MSG 行)/ `--show [--state s] [--plan id]`(过滤打印; 读也在锁内, 快照一致)/ `--update <id> [--any_info x] [--state doing|test] [--plan_desc x]`(`--state merge` 在此禁止 — merge 只能由 `--merge` 进入)/ `--merge <id>`(merge 态独占; 已是 merge 则幂等成功; 占用时放锁 sleep 60 秒重检一次, 仍占用则报占用者并退出非 0)/ `--send --src <id> --dst <id|all> --msg x` / `--recv <id>`(`--revc` 兼容别名)/ `--withdraw <id>`(撤回自己发出的 MSG 行)。MERGELOCK 时间戳行超 900 秒判 stale: 下一次 `--merge` 自动把占用者回退 doing、警告、视为槽位空闲。
- **Why**: 多 agent 并行泳道需要跨会话的共享状态与异步便签, 但台账文件(plan/iterations 索引)是 scripts-only 的记账面, 不该承载高频运行态; 独立数据文件 + 单锁 + 原子写把运行态与记账面隔开。merge 态全表至多一个, 短窗铁律保证不阻塞他人; stale 接管解决"持 merge 态的 agent 死亡后槽位永久卡死"(锁层有 stale 恢复, 表层此前没有)。
- **Migration**: **handled by step 8a — 全部 `scripts/*.sh` 由规范 asset 整体替换**, `parallel-workspace.sh` 随该步落入 `AGENTSPACE/scripts/`; 本版本实际新增的就是这一个脚本, 其余十二个脚本与 v1.1.0 逐字节相同。无需任何手工工作区操作。
- **结构树/scripts 清单(精确行)**: `AGENTSPACE/AGENTS.md` 的 `结构` 代码块**不增一行不减一行**(scripts/ 仍是单行条目, 本版无新模块)。结构清单的唯一变化在 `versions/v1.2.0/architecture.json` 的 `files` 中新增一条精确记录:

  ```json
  "scripts/parallel-workspace.sh": {
    "type": "script",
    "managedBy": "plugin"
  }
  ```

### [Addition] .gitignore: 协同表数据文件行

- **What**: `AGENTSPACE/.gitignore` 末尾(handoff 块之后)追加一个新块, 精确文本:

  ```gitignore
  # ---- 并行协同工作区表(运行数据; 由 scripts/parallel-workspace.sh 维护, 不入 git) ----
  .agentspace-parallel-workspace.txt
  ```

- **Why**: 数据文件是运行期状态, 落在台账目录内; 不挡住的话一次 `git add -A` 就会把它扫进台账仓库(与锁目录 gitignore 同理)。
- **Migration**: **handled by step 8a — `.gitignore` 由规范 asset 整体替换**, 该行随替换自动带入。无需任何手工动作。

### [Behavior] agentspace-parallel skill 四项增强(仅插件侧 skill 文本)

- **What**: `skills/agentspace-parallel/SKILL.md` 与 `SKILL.zh-CN.md` 四处增强: ① 铁律 1 与 §3 建立把固定 worktree 路径 `<项目根>/worktrees/<plan-id>/<repo名>` 钉为 [MUST](任何其他位置禁止 — 随手路径按 cwd 解析会把 worktree 建到奇怪的地方); ② §7a gap profile 与 §8.1 step 3 新增 [MUST] 历史改写探测(`git merge-base --is-ancestor <base> <主线>`; 纯元数据改写 → 报告用户 + 重指泳道 base 锚点 + 继续; 内容被改写 → 正常 absorb 路径; 其本身绝不触发 §7h 冻结); ③ 两个报告层挂点 — §4 收尾[进 §8.1 合回前]对泳道全 diff 跑 commit 门语义层全维审查(只报告不阻塞, §8.1 commit 门保持阻断职责), §8.1 step 4 [合回被接受后]跑 code-clean 批量注释审查(multi-subagent 全量注释, 只报告, 修复另起提交); ④ 新增 §6.5 协同 agent workspace: 启动(§3 拉起)[MUST] `--init`、收尾 [MUST] `--remove`, `--show`/`--send`/`--recv` 按需不强制轮询, 合回走脚本 merge 态并遵守短窗铁律。
- **Why**: worktree 落点漂移、主线历史改写后的锚点失效、注释卫生与 commit 质量在合回窗口缺审查挂点, 都是真实并行场景的坑; 协同表让多 agent 并行从"各干各的"升级为可见、可协调。
- **Migration**: **仅插件侧 skill 文本 — 本块工作区无需任何迁移动作。** 四项增强没有任何对应的工作区文件: 不要为此创建、编辑或查找任何工作区文件。(工作区脚本中的 parallel-workspace.sh 由上面第一块的 step 8a 落地。)

### [Fix] 结构树、templates、模块清单、表 schema、AGENTS.md: 无变更

- **What**: 本版本不新增模块、不删除模块、不改任何表格列。`AGENTSPACE/AGENTS.md` 的 `结构` 代码块不增一行不减一行; 五个 `templates/*.md` 与 v1.1.0 内容相同; `versions/v1.2.0/architecture.json` 与 v1.1.0 的差异仅限 version 字段与 `files` 新增 `scripts/parallel-workspace.sh` 一条。(assets 的 lib.sh 本批次仅注释卫生修复, 无任何行为变化。)
- **Why**: 明说以免更新 agent 为本版本虚构结构性工作, 或对 AGENTS.md 发明 8b 文本操作。
- **Migration**: 无 — 无事可做。本版本**没有 step 8b**: 不要改 `AGENTSPACE/AGENTS.md` 的任何一行。若工作区扫描提示需要结构树/模块/schema/AGENTS.md 变更, 均不在 v1.2.0 范围内; 保持工作区原样并报告。
