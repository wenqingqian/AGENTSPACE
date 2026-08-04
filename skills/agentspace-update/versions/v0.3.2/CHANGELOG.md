# AGENTSPACE v0.3.2

Upgrade from v0.3.1. Date: 2026-08-05

## Summary

- complete-plan.sh: lesson distillation upgraded from SHOULD to MUST (every completed plan's transferable lessons must land in notes/ before the milestone commit)
- update skill: a per-item migration ledger is now maintained and reported — every changelog change block gets an explicit applied / skipped / not-applicable status, instead of relying on session memory

## Changes

### [Fix] complete-plan.sh: lesson distillation is now a MUST
**What**: `AGENTSPACE/scripts/complete-plan.sh` output now reads `Next [MUST]: review this plan's iterations (结果/code-diff) and distill transferable lessons into notes with source plan:$ID` (was `[SHOULD]`). A code comment records the v0.3.2 decision.
**Why**: plan-completion without notes distillation repeatedly lost transferable lessons; the wrap-up protocol's "distill lessons" step was only a soft reminder. Upgrading to MUST makes the instruction unambiguous at the exact moment the plan closes.
**Migration**:
1. **Script (handled by step 8a — no manual work)**: `AGENTSPACE/scripts/complete-plan.sh` is replaced from assets.
2. **No data migration**: behavior unchanged; only the closing prompt text differs.

### [Fix] update skill: migration ledger for applied/skipped items
**What**: `skills/agentspace-update/SKILL.md` / `SKILL.zh-CN.md` — Step 8 now instructs maintaining a migration ledger (per changelog change block: `applied` / `skipped` / `not-applicable`, with reasons for skips), and Step 11 report now includes the per-item ledger one line per block.
**Why**: the update flow previously summarized skipped items from memory; the ledger makes every update an auditable trail (which blocks applied, which were refused and why) and feeds the partial-update retry logic.
**Migration**:
1. **Plugin-side (no workspace action)**: the skill text ships with the plugin.

### No structural changes
- Workspace layout, schemas, templates, and architecture.json (constants/sections/files) unchanged — architecture.json: version bump only. No workspace file changes during the update.
