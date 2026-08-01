# AGENTSPACE v0.2.9

Upgrade from v0.2.8. Date: 2026-08-02

## Summary

- Daily skill slimmed (110 lines): data-collection detail moved to AGENTS.md (kept in context by skill §1)
- CN skill fixed: duplicated 新任务 heading block removed (drift caught by the new bilingual check)
- DEVELOPMENT.md release process: SKILL size budget (≤120 lines, mechanized in Step 7) + bilingual sync check (heading level sequence + MUST/SHOULD/MAY token parity)

## Changes

### [Breaking] SKILL slimming — data strategies now in AGENTS.md only

**What**: `skills/agentspace/SKILL.md` (and zh) replaced the three data-collection strategies with a pointer to AGENTS.md (iterations module), which already contains the full strategies. 5 lines removed per language; SKILL is now 110 lines (budget 120).

**Why**: the daily skill must stay action-oriented; detail belongs in AGENTS.md, which skill §1 already requires in context during work.

**Migration**: behavior-level (skill text). The update agent replaces the skill files via step 8a (skills are plugin files, not workspace files — no workspace migration). Agents now get data strategies from AGENTS.md, which is already in context per §1.

### [Fix] CN skill duplicate heading removed

**What**: `SKILL.zh-CN.md` had a duplicated "### 新任务 → 建 plan" heading block (from an earlier edit). Removed; structure now matches EN (1 H1 / 5 H2 / 6 H3 both).

**Migration**: none (skill text).

### [Addition] Release-process requirements (DEVELOPMENT.md)

**What**: every release must pass — (a) SKILL size budget ≤120 lines (mechanized), (b) bilingual sync check: heading level sequences identical + MUST/SHOULD/MAY token counts identical between SKILL.md and SKILL.zh-CN.md.

**Why**: prevents skill bloat and bilingual drift (the CN duplicate was exactly this class of bug).

**Migration**: none (plugin-dev documentation).
