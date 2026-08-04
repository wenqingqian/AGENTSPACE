# AGENTSPACE v0.3.0

Upgrade from v0.2.12. Date: 2026-08-04

## Summary

- New `/doctor-agentspace` command: deep workspace health check — deterministic core + per-file content review (minor) + cross-cutting audit against the host repo (major); read-only by default, tiered `--fix` repairs
- `doctor.sh` gains deterministic cross-reference checks: iteration→plan ownership [6], notes integrity (来源 + file↔table) [7], note back-links [8]
- `doctor.sh --fix`: safe deterministic auto-repairs (orphan table rows, missing notes.md rows) on top of the existing broken-symlink repair

## Changes

### [Addition] /doctor-agentspace command + agentspace-doctor skill
**What**: three plugin-side additions —
1. `commands/doctor-agentspace.md` (new): slash-command entry, argument-hint `[--minor | --major] [--fix]`, binds skill `agentspace-doctor`
2. `skills/agentspace-doctor/SKILL.md` + `SKILL.zh-CN.md` (new): the command's flow — Phase A deterministic core (doctor.sh); Phase B minor per-file content review (scope + criterion "current-state assertions vs historical records", red/yellow/blue severity with [script]/[agent] source labels); Phase C major cross-cutting audit (5 parallel subagent blocks: host code+git outcome check / workspace git audit / full-history discipline trace / version-metadata claims / environment call-chain dry-run; auto-memory read-only cross-check by the main agent); tiered `--fix` (§5); stdout-only three-tier report; boundaries
3. `skills/agentspace/SKILL.md` + `SKILL.zh-CN.md`: status self-check line gains a pointer to the new command

**Why**: workspace state maintenance previously relied on ad-hoc agent edits plus the deterministic doctor.sh script — no unified entry point, no content-level judgment (stale claims, contradictions, filler), no cross-cutting verification of the workspace against the host repo. The command layers an agent judgment layer on top of the deterministic script core, which remains the cheap wrap-up gate.

**Migration**:
1. **Skill + command (plugin-side, no workspace action)**: the new `commands/doctor-agentspace.md` and `skills/agentspace-doctor/` (EN + ZH) are delivered with the plugin; nothing to copy into the workspace.
2. **Main skill pointer (plugin-side, no workspace action)** — replace the EN line in `skills/agentspace/SKILL.md`:
   Old: `- Status self-check: `AGENTSPACE/scripts/status.sh`; run `AGENTSPACE/scripts/doctor.sh` after wrap-up and whenever you suspect corruption`
   New: `- Status self-check: `AGENTSPACE/scripts/status.sh`; run `AGENTSPACE/scripts/doctor.sh` after wrap-up and whenever you suspect corruption; for deeper audits (per-file content, cross-cutting history, repairs) run the explicit `/doctor-agentspace` command (--minor | --major [--fix]) — it is never triggered automatically`
   And the ZH line in `skills/agentspace/SKILL.zh-CN.md`:
   Old: `- 状态自检 `AGENTSPACE/scripts/status.sh`; 收尾后及怀疑损坏时运行 `AGENTSPACE/scripts/doctor.sh``
   New: `- 状态自检 `AGENTSPACE/scripts/status.sh`; 收尾后及怀疑损坏时运行 `AGENTSPACE/scripts/doctor.sh`; 需要深度审计(逐文件内容、跨历史交叉、修复)时显式运行 `/doctor-agentspace` 命令(--minor | --major [--fix])— 该命令绝不自动触发`
   Idempotency: if the line already contains `/doctor-agentspace`, leave it as-is.
3. **Workspace (no action)**: workspace files unchanged; doctor.sh is replaced in step 8a (see next block).

### [Addition] doctor.sh cross-reference checks [6][7][8]
**What**: `AGENTSPACE/scripts/doctor.sh` gains three check sections after [5]:
- [6] iteration→plan ownership: each iteration readme's `> plan: NNNN` header must match the entry-table row's plan and the parent plan must exist in `plan/index.md`
- [7] notes integrity: `notes/*.md` files ↔ `notes.md` entry rows (bidirectional), each note's `> 来源:` line must carry a primary `plan:NNNN` / `iteration_NNNN` ref whose target exists
- [8] note back-links: iteration-sourced notes must contain `iteration_NNNN/readme.md` in 详情 (v0.2.12 discipline); notes created before 2026-08-04 are exempt (v0.2.12 promised existing notes are NOT retrofitted)

**Why**: these cross-reference contracts were previously enforced by discipline text only — no deterministic gate. Sinking them into the script layer makes them part of the wrap-up/update green gate and regression-testable (tests t06).

**Migration**:
1. **Script (handled by step 8a — no manual work)**: `AGENTSPACE/scripts/doctor.sh` is replaced from assets. New sections run automatically on the next doctor invocation; a consistent workspace stays green.
2. **No data migration**: no workspace file changes; new failure modes only fire on genuinely inconsistent states (e.g. readme/table plan mismatch, notes without 来源, iteration-sourced notes without back-link).

### [Addition] doctor.sh --fix (safe deterministic auto-repairs)
**What**: `doctor.sh [--fix]` — default remains read-only; with `--fix` the script additionally auto-repairs safe deterministic items:
- broken latest symlink (already auto-repaired regardless — existing contract)
- orphan table rows in `plan.md` (Todo) and `iterations.md` (进行中) whose files no longer exist — removed via the standard row helpers under the same lock as write scripts
- missing `notes.md` rows for existing note files — backfilled from the note file (title / 来源 / date / link)
Semantic issues stay report-only; the agentspace-doctor skill (§5) governs tier-2 confirmed repairs.

**Why**: HANDOFF-planned "doctor --fix (safe items auto-repair)" — deterministic safe fixes belong in the script layer (testable, gate-consistent); judgment repairs stay agent-side with user confirmation.

**Migration**:
1. **Script (handled by step 8a — no manual work)**: `AGENTSPACE/scripts/doctor.sh` is replaced from assets; `--fix` is available on the next invocation.
2. **No data migration**: `--fix` only acts on items it reports; nothing changes unless the user runs `doctor.sh --fix` (or `/doctor-agentspace --fix`).

### [Fix] Stale-lock recovery in as_lock
**What**: `AGENTSPACE/scripts/lib.sh` `as_lock` now detects stale locks: a lock whose owner PID is dead is removed immediately; a pid-less lock older than 5 minutes (crash mid-acquire) is removed too. The owner PID is recorded in `.scripts.lock/pid` on acquire. `.gitignore` gained `.scripts.lock/` and `.scripts-tmp.*/` patterns so a killed writer no longer pollutes `git status`.
**Why**: a SIGKILLed writer left `.scripts.lock` behind forever — every subsequent write (close-iteration, new-plan, doctor --fix, …) spun in `while ! mkdir` with no timeout, permanently deadlocking workspace operations.
**Migration**:
1. **Script (handled by step 8a — no manual work)**: `AGENTSPACE/scripts/lib.sh` and `.gitignore` are replaced from assets.
2. **No data migration**: if a stale lock exists, the next write recovers it automatically.

### [Fix] Atomic file writes (no truncate-then-write window)
**What**: all lib.sh in-place write helpers (`as_insert_row`, `as_remove_row`, `as_remove_row_section`, `as_truncate_section`, `as_replace_line`, `as_insert_after`, `as_insert_after_prefix`, `as_append_to_section`) and `doctor.sh`'s notes backfill now replace files via `as_atomic_write` — same-filesystem `mv` with the target's permissions preserved. `as_fill_template` stays direct by design (its target is always a new file).
**Why**: the previous `cat "$tmp" > "$file"` truncated the target before writing; a crash mid-write (OOM/SIGKILL/disk full) could leave core view files (plan.md, iterations.md, notes.md) truncated with no recovery short of git.
**Migration**:
1. **Script (handled by step 8a — no manual work)**: `AGENTSPACE/scripts/lib.sh` and `AGENTSPACE/scripts/doctor.sh` are replaced from assets.
2. **No data migration**: behavior is transparent; permissions preserved.

### No structural changes
- Workspace layout, schemas, templates, and architecture.json (constants/sections/files) unchanged — only `scripts/doctor.sh` content grew. architecture.json: version bump only. No workspace file changes during the update.
