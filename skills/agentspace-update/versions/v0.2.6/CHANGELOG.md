# AGENTSPACE v0.2.6

Upgrade from v0.2.5. Date: 2026-08-02

## Summary

- doctor.sh: resume-block freshness check for in-progress iterations (enforces wrap-up protocol step ①)
- doctor.sh: placeholder-constant drift backstop [5] (constant ↔ template contract)
- lib.sh: RESUME_PH_ITER constant; placeholder constants consolidated with gate annotations
- SKILL.md ×2: wrap-up step ① clarified (replace guidance comment with real content)

## Changes

### [Addition] Resume-block freshness check (doctor.sh)

**What**: for in-progress iterations (readme status line `> 状态: 进行中`), doctor warns when the "当前状态 · 下一步" section still contains the template guidance comment (`<!-- 会话续接块:` — matched via constant `RESUME_PH_ITER`).

**Why**: the wrap-up protocol step ① (update the resume block before ending a session) previously had no script-detectable signal — a stale resume block looks identical to a fresh one.

**Migration**:
1. Script replaced by step 8a. Behavior change only.
2. **Advisory warning only** — counted into issues (doctor exits 1) but does not block anything.
3. Pre-existing in-progress readmes that were never updated will now warn. This is intended: fill the resume block (or note it intentionally empty) to silence.
4. Closed readmes are exempt (check gated on in-progress status line).

### [Addition] Placeholder-constant drift backstop (doctor.sh [5])

**What**: doctor verifies `RESUME_PH_ITER` / `RESULT_PH_ITER` / `RESULT_PH_PLAN` still appear in their template files; warns on mismatch.

**Why**: the placeholder-gate system (v0.2.5) silently breaks if a template comment is rewritten without updating the constant.

**Migration**: script replaced by step 8a. No workspace files change.

### [Addition] Constants recorded in architecture.json

**What**: the three placeholder constants added to `constants` in architecture.json (v0.2.6 snapshot).

**Migration**: none (metadata).

### No structural changes
- Workspace layout, table schemas, and templates unchanged (one template comment clarified in the guidance wording only — the placeholder first lines are untouched).
