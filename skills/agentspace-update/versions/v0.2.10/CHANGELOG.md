# AGENTSPACE v0.2.10

Upgrade from v0.2.9. Date: 2026-08-02

## Summary

Audit-fix release (5 findings from an external 24h risk audit, all verified): doctor dirty-tree boundary (F2), close-iteration host-commit insert ordering (F3/F4), link-check anchor false positives (F5), duplicated-section gate interaction (F1).

## Changes

### [Fix] F2 — doctor [0] dirty-tree check no longer walks up to the host repo

**What**: the check now requires the workspace's OWN `.git` (`[ -e "$AS_ROOT/.git" ]`, covering git worktrees where .git is a file — consistent with init's contract) instead of `git rev-parse --is-inside-work-tree`, which returns true inside ANY enclosing repo and would report the HOST repo's dirty state. The `git status` pipeline also got `|| true` so a corrupt/missing git can never abort the whole doctor run under `set -euo pipefail`.

**Migration**: handled by step 8a (script replacement). Behavior change only.

### [Fix] F3/F4 — close-iteration host end-commit insert moved before mutations, ordered below start line

**What**: the `> 宿主结束 commit:` insert now runs right after `as_lock` (BEFORE the readme freeze / iterations.md / index mutations), so a failure can no longer produce a "failed-but-close-completed" contradiction. When a start-commit line exists it is inserted BELOW it (new `as_insert_after_prefix` helper for dynamic-content prefixes); otherwise after the 环境 heading. Guards (section exists, line absent) make failure impossible under lock.

**Migration**: handled by step 8a. Existing readmes unaffected.

### [Fix] F5 — link check strips #anchor suffixes

**What**: `[ -e "$AS_ROOT/${target%%#*}" ]` — targets like `](file.md#anchor)` no longer false-positive as broken links.

**Migration**: handled by step 8a. Behavior change only.

### [Fix] F1 — doctor backstop for v0.2.3-era duplicated sections

**What**: doctor [3] warns when an in-progress readme contains more than one `## 结果` section (v0.2.3 template regression), naming the close-blocking interaction (a leftover placeholder in the duplicate) and asking the user before cleaning.

**Migration**: handled by step 8a. Existing readmes with duplicates now surface a warning with guidance instead of a confusing close refusal.

### Behavior notes (design intent, re-stated)

- doctor-green now implies "just committed": uncommitted changes count as issues (v0.2.5 semantics, unchanged).
- close/complete refuse while result placeholders remain (v0.2.5 semantics, unchanged).

### No structural changes
- Workspace layout, schemas, templates unchanged. architecture.json: version bump only.
