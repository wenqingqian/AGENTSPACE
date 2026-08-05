# AGENTSPACE v0.4.1

Upgrade from v0.4.0. Date: 2026-08-05

## Summary

- **handoff 纳入 doctor 范围**: doctor 新增检查 [10] handoff consistency(索引行 ↔ 文件一致性)与 [11] handoff staleness(过时审核)。过时 handoff **只分析反馈**(报告名称/描述/生产日期/下一步内容), doctor 绝不删除、绝不 consume; --fix 仅移除"有行无文件"的死索引行(文件已不存在, 无数据损失, 同 [2]/[3] 孤儿行先例)。
- **status.sh 会话入口可见性**: 新增 `## Handoffs (待消费)` 摘要节(名称/描述/生产日期 + 过时标记)。
- **update 流程 verify 闸门**: 第 9 步升级为两段式闸门, 升级完成必须 post-commit doctor 全绿。
- **doctor --major 内容级 handoff 过时审查**: 引用/下一步已与现状矛盾的快照 → 黄 + 具体建议(consume/删除/重建), 不自动处理。

## Changes

### [Addition] doctor checks [10] handoff consistency + [11] handoff staleness
**What**: `AGENTSPACE/scripts/doctor.sh` gains two checks between [9] and the summary:
- **[10] handoff consistency** (仅当 `AGENTSPACE/handoff/` 目录存在时运行; 无 index.md 或无 handoff 文件则静默通过):
  - 有行无文件: 索引行 location 指向的 `handoff_*.md` 不存在(崩溃中断的 consume 残留)→ warn; `--fix` 删除该行(按首列 name 字符串相等、`## Handoffs` 节内删除, 同 consume 的删除模式; 带 before/after 行数守卫, 修复失败不报绿)
  - 有文件无行: `handoff/handoff_*.md` 在磁盘上但索引无对应行(崩溃中断的 produce 残留, 文件被 gitignore 对 git 不可见)→ warn + 报告完整路径, **无 --fix**(文件可能含未读上下文, 用户读完手动删除)
  - 重复行: 同名或同 location 行 >1(手工编辑产物)→ warn, **无 --fix**
  - 行解析按形状定位字段(首列 name / 匹配 `handoff_*.md` 的列 / 末尾日期列), 不用裸 `|` 切分 — 容忍 description 中的 `\|` 转义(v0.4.0 as_insert_row ENVIRON 教训延续)
- **[11] handoff staleness** (阈值 7 天, doctor.sh 内字面量):
  - `find AGENTSPACE/handoff -maxdepth 1 -type f -name 'handoff_*.md' -mtime +7` 检测(BSD/GNU find 兼容, 无日期算术)
  - 对每个过时文件: warn 报告 name + description + 生产日期(索引行)+ 文件路径 + 该 handoff 要干什么(提取文件 `## 下一步` 节首行)+ 处理提示
  - [10] 已报的孤儿文件跳过, 避免双报
  - **无 --fix 分支** — 模块契约: consume 必须人工读完快照后执行, doctor 只报告

**Why**: handoff 文件 gitignored、对 git 不可见, 残留会静默堆积; consume/produce 中途崩溃可产生死行或孤儿文件; v0.4.0 前 doctor 完全未覆盖该模块(t10 注释明言 out of scope)。用户边界(2026-08-05 确认): 过时 handoff 只做分析反馈, 不得私自删除或 consume。

**Migration**:
1. **Script (handled by step 8a — no manual work)**: `AGENTSPACE/scripts/doctor.sh` is replaced from assets.
2. **No data migration**: checks are read-only except `--fix` removing dangling handoff index rows (file already gone). Existing workspaces with consistent handoff pairs pass silently.

### [Addition] status.sh: handoff summary section
**What**: `AGENTSPACE/scripts/status.sh` gains a `## Handoffs (待消费)` section (after 推进总览): one line per indexed handoff — `name | description | produced-date`, with a `⚠ 过时(>7 天未消费)` marker for files older than 7 days (`find -mtime +7`, same threshold as doctor [11]).
**Why**: handoffs are the session-resume entry (AGENTS.md 读取规则) but were invisible outside `handoff/`; status.sh is the session-start summary, so the pending-consumption list belongs there.
**Migration**:
1. **Script (handled by step 8a — no manual work)**: `AGENTSPACE/scripts/status.sh` is replaced from assets.
2. **No data migration**: read-only view; row parsing is shape-based (first name cell / last date cell, tolerates escaped `\|` in descriptions), consistent with doctor [10].

### [Addition] update flow: doctor verify gate (step 9)
**What**: `skills/agentspace-update/SKILL.md` step 9 becomes a two-phase gate: pre-commit `doctor.sh --fix` + `doctor.sh` (red items other than [0] uncommitted-changes must be resolved; only [0] may remain), then post-commit re-run that must exit 0 before the update is declared complete.
**Why**: step 9 previously reported issues without blocking; a naive all-red gate would deadlock on doctor [0] (files are modified at step 8, committed at step 10). The two-phase design catches version-marker drift ([9]) pre-commit and final consistency post-commit.
**Migration**:
1. **Plugin-side (no workspace action)**: ships with the plugin.

### [Addition] doctor --major: content-level handoff staleness review
**What**: `skills/agentspace-doctor/SKILL.md` Phase B review scope now includes `handoff/index.md` + `handoff/handoff_*.md`; a handoff whose 引用/下一步 no longer match current state (referenced plan completed, 下一步 already done, resume block superseded by `iterations/latest`) is a 黄 finding with a concrete suggestion (consume / delete / re-produce) — never auto-deleted or auto-consumed. Phase C Block 1 (host outcome verification) also covers handoff 下一步 claims.
**Why**: script check [11] only detects age; content-level staleness is agent judgment, which belongs to the --major content review tier (scripts enforce contracts, agents judge content).
**Migration**:
1. **Plugin-side (no workspace action)**: ships with the plugin.

### [Fix] handoff.sh: name `name` reserved; staleness check/message exactness
**What**: `AGENTSPACE/scripts/handoff.sh` refuses `name` as a handoff name — a handoff named `name` collides with the index table-header filter (`| name |`) used by `--list`, doctor [10]/[11] and the status summary, making the row invisible to all read paths. `AGENTSPACE/scripts/doctor.sh` [11] and `AGENTSPACE/scripts/status.sh` now use `find -mtime +6` so the check and the ">7 天" messages agree exactly (`find -mtime +N` = strictly more than N whole days; `+6` ⇒ 7 天以上, previously `+7` flagged only ≥8 days).
**Migration**:
1. **Scripts (handled by step 8a — no manual work)**: `AGENTSPACE/scripts/handoff.sh`, `AGENTSPACE/scripts/doctor.sh`, `AGENTSPACE/scripts/status.sh` are replaced from assets.
2. **No data migration**.

### No structural changes
- plan/iterations/notes/utils/tests/data/examples/register/handoff schemas unchanged; no new constants in lib.sh (staleness threshold is a doctor.sh literal); architecture.json unchanged apart from the version field.
