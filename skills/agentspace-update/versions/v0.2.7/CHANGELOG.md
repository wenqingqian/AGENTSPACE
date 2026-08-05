# AGENTSPACE v0.2.7

Upgrade from v0.2.6. Date: 2026-08-02

## Summary

- Knowledge distillation: plan completion now includes a review-and-notes workflow (SHOULD)
- notes.md 条目 table gains a 标签 (tag) column; note.md template gains a 标签 header line (optional)

## Changes

### [Schema] notes.md 条目 table: 标签 column

**What**: notes.md entry table gains a 标签 column — header becomes `| 主题 | 标签 | 一句话结论 | 来源 | 日期 | 链接 |`. The note.md template gains an optional `> 标签:` header line.

**Why**: tagging notes by topic enables aggregation and retrieval via the v0.2.5 historical-search guidance.

**Migration (conservative mode — agent task)**:
1. notes.md is agent-maintained (no script owns it) — the table header will be re-formatted by the agent on the next note write. No forced migration.
2. The update agent SHOULD update the notes.md header to the 6-column layout when applying this update (mechanical, one line), and MAY backfill tags on existing rows if the user wants.
3. Existing note files without a 标签 line are fine — the field is optional.

### [Addition] Plan completion: knowledge distillation workflow

**What**: daily skill's Complete Plan workflow now has: a pre-requisite note (fill 结果 before running — enforced by the v0.2.5 gate), and a post-completion SHOULD workflow (review this plan's iterations → distill transferable lessons into notes with source plan:NNNN → milestone commit).

**Why**: previously notes were only written "when there are transferable lessons" — a passive reminder with no review step; distillation was easily skipped.

**Migration**: behavior-only (SKILL.md ×2, AGENTS.md text, complete-plan.sh reminder message). Script replaced by step 8a.

### [Addition] AGENTS.md: notes 模块 when/how bullet 更新(标签检索建议)
**What**: `AGENTSPACE/AGENTS.md` 模块节的 notes when/how bullet 措辞更新为知识蒸馏工作流, 并加入「建议打主题"标签"便于检索聚合」。
**Why**: the notes 标签 column (this version's [Schema] change) is only useful if the guidance tells agents to tag; the bullet is the guidance.
**Migration (agent task — exact replace)**: in `AGENTSPACE/AGENTS.md`, 模块 section (`### notes —— 持久知识`), replace the notes "when/how" bullet:
```
- **when/how**: plan 完成产出可迁移教训、或发现坑时立即记录; 每条笔记必须带"来源"(plan:NNNN / iteration_NNNN); 模板 templates/note.md
```
with:
```
- **when/how**: plan 完成时回顾 iterations 提炼教训、或发现坑时立即记录; 每条笔记必须带"来源"(plan:NNNN / iteration_NNNN); 建议打主题"标签"便于检索聚合; 模板 templates/note.md
```
Idempotency: if the bullet already contains 建议打主题"标签", leave it as-is (a later version re-applied). If the anchor line is absent (user customized it), keep the user's version and ensure the 标签子句 is present.
