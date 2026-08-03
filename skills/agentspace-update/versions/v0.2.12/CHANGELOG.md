# AGENTSPACE v0.2.12

Upgrade from v0.2.11. Date: 2026-08-04

## Summary

- Notes↔iteration back-link discipline: notes distilled from an iteration's result now carry `iteration_NNNN` as 来源 and back-link the iteration readme in 详情; close-iteration.sh reminds the agent when a result may hold transferable lessons

## Changes

### [Addition] Notes↔iteration back-link discipline

**What**: three coordinated changes —
1. `skills/agentspace-init/assets/agentspace/scripts/close-iteration.sh` gains a "Next [SHOULD]" reminder echo after closing (handled by step 8a — script replaced from assets)
2. `skills/agentspace/SKILL.md` + `skills/agentspace/SKILL.zh-CN.md` (daily skill, plugin-side): the Close Iteration workflow gains a back-link instruction
3. `AGENTSPACE/AGENTS.md` (workspace-facing): the notes module "when/how" bullet gains the back-link clause

**Why**: notes were one-directional (note → source). The 来源 field already accepts `iteration_NNNN`, but nothing told the agent to back-link the iteration readme, so "which iteration produced this note" and "which lessons did this iteration yield" were not greppable both ways. The close script's reminder turns the SHOULD into a prompt at the moment the result is fresh.

**Migration**:

1. **Script (handled by step 8a — no manual work)**: `AGENTSPACE/scripts/close-iteration.sh` is replaced from `skills/agentspace-init/assets/agentspace/scripts/close-iteration.sh`; it now echoes, after the close line:
   ```
   Next [SHOULD]: if the result holds transferable lessons, write a note (templates/note.md) with source iteration_$ID, back-linking this readme in 详情
   ```

2. **Skill text (plugin-side, no workspace action)**: `skills/agentspace/SKILL.md` Close Iteration section — after the "Milestone commit." line, append:
   ```
   If the result holds transferable lessons (SHOULD — knowledge distillation), write a note (templates/note.md) with source `iteration_NNNN`, back-linking this iteration's readme in 详情.
   ```
   `skills/agentspace/SKILL.zh-CN.md` 关闭迭代 section — after the "里程碑提交。" line, append:
   ```
   结果含可迁移教训时 (SHOULD — 知识提炼), 写一条笔记(templates/note.md, 来源 `iteration_NNNN`), 在"详情"中回链本迭代的 readme。
   ```

3. **AGENTS.md content merge (agent task)**: in `AGENTSPACE/AGENTS.md`, 模块 section, replace the notes "when/how" bullet:
   ```
   - **when/how**: plan 完成时回顾 iterations 提炼教训、或发现坑时立即记录; 每条笔记必须带"来源"(plan:NNNN / iteration_NNNN); 建议打主题"标签"便于检索聚合; 模板 templates/note.md
   ```
   with:
   ```
   - **when/how**: plan 完成时回顾 iterations 提炼教训、或发现坑时立即记录; 每条笔记必须带"来源"(plan:NNNN / iteration_NNNN); 由 iteration 提炼的笔记在"详情"中回链该 iteration 的 readme; 建议打主题"标签"便于检索聚合; 模板 templates/note.md
   ```
   Idempotency: if the bullet already contains the 回链 clause (e.g., re-attempt after a refusal), leave it as-is. If the old bullet text is NOT found verbatim and the clause is absent (e.g., user-customized bullet), do not force the replacement — confirm with the user how to merge the clause.

### No structural changes

- Workspace layout, schemas, templates unchanged. architecture.json: version bump only. Existing notes are NOT retrofitted (the discipline applies to new notes).
