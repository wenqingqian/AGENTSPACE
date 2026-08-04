# AGENTSPACE v0.3.1

Upgrade from v0.3.0. Date: 2026-08-05

## Summary

- doctor.sh [8] back-link check upgraded from plain-text grep to link-level validation (a real markdown link to the source readme is required — plain-text mentions and links to other iterations no longer pass)
- doctor.sh gains [9] version-metadata consistency: `.agentspace-version.json` ↔ `.agentspace-architecture.json` version mismatch is now a red (was silently green)
- new-plan/new-iteration ID allocation scans table rows too (an orphan row can no longer collide with a fresh index)
- update flow hardening: update-version.sh auto-locates the project root (no more cwd trap), and the update skill warns on uncommitted workspace changes up front
- init now self-checks with doctor after the first commit; status.sh gains a 推进总览 (per-plan iteration counts, recent closes, next step)

## Changes

### [Fix] doctor.sh [8]: link-level back-link check (plain-text mentions no longer pass)
**What**: `AGENTSPACE/scripts/doctor.sh` [8] previously accepted any occurrence of the string `iteration_NNNN/readme.md` anywhere in the note file. It now extracts real markdown link targets (`](...)`) and requires one to point at the source readme — exact `iteration_NNNN/readme.md` or a relative form ending in `/iteration_NNNN/readme.md` (e.g. `../iterations/iteration_NNNN/readme.md`). Plain-text mentions, anchored links, and links to a *different* iteration's readme are all reported as missing back-links.
**Why**: found by the synthetic third-party eval — a note whose 详情 merely mentioned the readme path passed [8] while its actual link pointed elsewhere.
**Migration**:
1. **Script (handled by step 8a — no manual work)**: `AGENTSPACE/scripts/doctor.sh` is replaced from assets.
2. **No data migration**: notes whose back-link is an actual link to the source readme stay green; notes that only *mention* the path will newly report red — fix by turning the mention into a real link (agent-side, user-confirmed).

### [Addition] doctor.sh [9]: version-metadata consistency check
**What**: `AGENTSPACE/scripts/doctor.sh` gains `[9] version metadata` after [8]: compares the `version` field of `.agentspace-version.json` and `.agentspace-architecture.json`; mismatch → red. Missing files (legacy workspaces) are skipped silently.
**Why**: found by the synthetic third-party eval — a workspace whose version marker said v0.3.0 while the architecture snapshot said v0.2.12 passed every check.
**Migration**:
1. **Script (handled by step 8a — no manual work)**: `AGENTSPACE/scripts/doctor.sh` is replaced from assets.
2. **No data migration**: a workspace with mismatched markers now reports red. Fix = run `/update-agentspace` (step 8c copies the recorded version's architecture snapshot), or one-time user-confirmed manual fix.

### [Fix] new-plan/new-iteration ID allocation: orphan table rows can no longer collide
**What**: `AGENTSPACE/scripts/lib.sh` `as_next_plan_id` / `as_next_iteration_id` now take the union of (filesystem ids, entry-table row ids, full-index row ids) before max+1, instead of filesystem only. A plan.md Todo row whose file is gone no longer causes the next new-plan to reuse that id.
**Why**: found by the synthetic eval runner — an orphan Todo row (0004) plus a fresh plan both claiming 0004 produces duplicate index rows and broken links.
**Migration**:
1. **Script (handled by step 8a — no manual work)**: `AGENTSPACE/scripts/lib.sh` is replaced from assets.

### [Fix] update-version.sh: auto-locate the project root (cwd trap)
**What**: `skills/agentspace-update/scripts/update-version.sh` now walks up from the current directory until it finds `AGENTSPACE/scripts/doctor.sh`, instead of requiring `pwd` to be the project root. Invoking it from `AGENTSPACE/` or any subdir works; a clear error is raised when no workspace is found.
**Why**: the v0.3.0 real-world update failed once with exit 1 because the script was invoked from the workspace dir instead of the project root.
**Migration**:
1. **Plugin-side (no workspace action)**: the script ships with the plugin; no workspace change.

### [Fix] update skill: uncommitted-changes guard up front
**What**: `skills/agentspace-update/SKILL.md` / `SKILL.zh-CN.md` Step 1 (Guard) now checks `git -C AGENTSPACE status --porcelain` and tells the user about uncommitted changes before the update proceeds — recommending a milestone commit first, and warning that rollback (`git -C AGENTSPACE reset --hard pre-update-v<old>`) discards uncommitted work.
**Why**: the v0.3.0 update ran with uncommitted files present; rollback would silently reset them.
**Migration**:
1. **Plugin-side (no workspace action)**: the skill text ships with the plugin.

### [Addition] init self-check after first commit
**What**: `skills/agentspace-init/scripts/init-agentspace.sh` runs `AGENTSPACE/scripts/doctor.sh` at the end of a successful init and prints the result (`初始化一致性 ✓` or a NOTICE with the issues). Non-blocking — init still exits 0 on a fresh workspace (which is green).
**Why**: initialization previously had no verification step.
**Migration**:
1. **Plugin-side (no workspace action)**.

### [Addition] status.sh 推进总览
**What**: `AGENTSPACE/scripts/status.sh` gains a `## 推进总览` block (per-plan iteration counts from the full index, closed vs total), a `## 最近关闭` block (latest 3 closes from the entry view), and a `## 下一步` block (latest iteration's 当前状态 · 下一步 first line).
**Why**: project-progress tracking previously required manually reading indexes.
**Migration**:
1. **Script (handled by step 8a — no manual work)**: `AGENTSPACE/scripts/status.sh` is replaced from assets.

### No structural changes
- Workspace layout, schemas, templates, and architecture.json (constants/sections/files) unchanged — architecture.json: version bump only. No workspace file changes during the update.
