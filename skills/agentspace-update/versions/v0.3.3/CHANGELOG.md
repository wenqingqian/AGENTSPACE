# AGENTSPACE v0.3.3

Upgrade from v0.3.2. Date: 2026-08-05

## Summary

- 24h code review (F1/F2/F4) hardening: the last three inline truncating writes are now atomic; update-version.sh anchors on the scripts/ dir (legacy-safe) instead of doctor.sh; doctor --fix tolerates drifted section headings and never reports green on a failed repair

## Changes

### [Fix] close-iteration.sh / complete-plan.sh: remaining inline writes are now atomic
**What**: `AGENTSPACE/scripts/close-iteration.sh` (iterations/index.md + readme.md) and `AGENTSPACE/scripts/complete-plan.sh` (plan/index.md) replaced their `cat "$tmp" > file && rm` inline writes with `as_atomic_write` — the same atomic replace (same-filesystem mv, permissions preserved) used everywhere else since v0.3.0.
**Why**: found by the 24h review (F1) — the v0.3.0 atomic-write hardening covered lib.sh helpers and doctor.sh but missed these three direct writes; a crash mid-write could truncate the full index, which is the only complete history (entry views keep only the latest 10).
**Migration**:
1. **Script (handled by step 8a — no manual work)**: both scripts are replaced from assets.
2. **No data migration**: behavior is transparent.

### [Fix] update-version.sh: anchor on the scripts/ dir (legacy-safe) instead of doctor.sh
**What**: `skills/agentspace-update/scripts/update-version.sh` root-search now looks for `AGENTSPACE/scripts/` (a directory present in every workspace version) instead of `AGENTSPACE/scripts/doctor.sh`. A pre-doctor-era workspace (or one with a damaged doctor.sh) can no longer be silently skipped while an ancestor workspace gets stamped instead.
**Why**: found by the 24h review (F2) — the doctor.sh anchor could walk past an old-format workspace and write the version marker into a wrong ancestor workspace with exit 0.
**Migration**:
1. **Plugin-side (no workspace action)**: the script ships with the plugin.

### [Fix] doctor --fix: heading-drift tolerance + no silent green on failed repair
**What**: `AGENTSPACE/scripts/doctor.sh` — orphan-row detection ([2] Todo, [3] 进行中) and `as_remove_row_section` (lib.sh) now match section headings with trailing-whitespace tolerance (`^## <sec>[[:space:]]*$`). Additionally, if a `--fix` removal does not change the file, doctor now reports a warning instead of printing "Workspace consistent ✓".
**Why**: found by the 24h review (F4) — a drifted heading (e.g. `## Todo `) made the fix branch silently no-op while doctor still exited 0, blinding the health gate in fix mode.
**Migration**:
1. **Script (handled by step 8a — no manual work)**: `AGENTSPACE/scripts/doctor.sh` and `AGENTSPACE/scripts/lib.sh` are replaced from assets.
2. **No data migration**: fix-mode behavior only gets stricter (failed repairs are now visible).

### No structural changes
- Workspace layout, schemas, templates, and architecture.json (constants/sections/files) unchanged — architecture.json: version bump only. No workspace file changes during the update.
