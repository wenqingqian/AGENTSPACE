# AGENTSPACE Plugin Development Guide

Guide for plugin contributors on how to maintain and release new versions.

## Architecture Overview

The AGENTSPACE plugin uses a **changelog-driven, agent-analyzed** update system:

- Each version has an **architecture snapshot** (architecture.json) and a **changelog** (CHANGELOG.md)
- The update agent reads changelogs, compares architectures, and intelligently transforms workspaces
- No rigid migration scripts — the agent adapts based on actual workspace content

### Version Files

| File | Location | Purpose |
|---|---|---|
| `.agentspace-version.json` | In user's AGENTSPACE/ | Tracks installed version |
| `.agentspace-architecture.json` | In user's AGENTSPACE/ | Current architecture snapshot |
| `versions/vX.Y.Z/CHANGELOG.md` | In plugin (skills/agentspace-update/) | Detailed changes for that version |
| `versions/vX.Y.Z/architecture.json` | In plugin (skills/agentspace-update/) | Full architecture snapshot for that version |

### Key Principle: Scripts ↔ Markdown Contract

The scripts (`lib.sh` constants like `SEC_TODO`, `STATUS_PROGRESS`) must EXACTLY match the section headings and status lines in the deployed markdown files. When you change either side, you must change both AND create a new version archive documenting the change.

## Adding a New Version

When the workspace structure changes (new files, schema changes, removed modules, etc.):

### Step 1: Create Version Directory

```
skills/agentspace-update/versions/v{NEW}/
├── CHANGELOG.md
└── architecture.json
```

### Step 2: Write CHANGELOG.md

Follow this structure:

```markdown
# AGENTSPACE v{NEW}

Upgrade from v{PREVIOUS}. Date: YYYY-MM-DD

## Summary
- Bullet list of high-level changes

## Changes

### [Breaking/Schema/Addition] Change title
- **What**: precise description of the change
- **Why**: design rationale
- **Conservative migration**: what the agent should do in conservative mode (list affected content, ask user)
- **Aggressive migration**: what the agent should do in aggressive mode (direct action)
```

Tags:
- `[Breaking]` — removes or fundamentally restructures something; data may be lost
- `[Schema]` — table column changes; existing data may need transformation
- `[Addition]` — new files/sections; non-destructive
- `[Fix]` — bug fix or wording correction; non-destructive

### Step 3: Create architecture.json

Snapshot the FULL architecture. Use the format from `versions/v0.1.0/architecture.json` as a template.

Key fields:
- `files` — every file in the workspace with `type` (view/index/content/template/script/config) and `managedBy` (scripts/agent/plugin)
- `sections` — for table files: section name → column array + maxRows
- `modules` — active module list
- `constants` — exact strings from `lib.sh` (SEC_*/STATUS_*)

**Important**: section headings and column names must be the ACTUAL strings as they appear in deployed markdown files (typically Chinese for workspace files).

### Step 4: Update Plugin Assets

1. Update `skills/agentspace-init/assets/agentspace/.agentspace-architecture.json` with the new snapshot
2. Bump `workspaceVersion` in `skills/agentspace-init/assets/agentspace/.agentspace-version.json`
3. If new files added: include them in `skills/agentspace-init/assets/agentspace/`
4. If files removed: remove from `skills/agentspace-init/assets/agentspace/`
5. If table schemas changed: update the corresponding template files in `assets/agentspace/templates/`

### Step 5: Update Scripts

1. Update `lib.sh` constants (`SEC_*`, `STATUS_*`) to match new architecture
2. Update write scripts (`new-plan.sh`, `complete-plan.sh`, etc.) to emit correct row formats
3. Update `doctor.sh` / `status.sh` to parse new schemas
4. All scripts must pass `bash -n` syntax check

### Step 6: Update Documentation

1. Update `SKILL.md` and `SKILL.zh-CN.md` if the update flow itself changes
2. Update `DEVELOPMENT.md` if the development process changes
3. Update `README.md` / `README.zh-CN.md` for user-facing changes

### Step 7: Test

1. `bash -n` on all `.sh` files
2. `/tmp` init → verify new workspace has correct structure
3. `/tmp` update from old version → verify migration works in both modes
4. `doctor.sh` green after update
5. `python3 -m json.tool` on all `.json` files

## File Ownership Matrix

| File | Writer | Notes |
|---|---|---|
| plan.md, iterations.md | scripts only | View files, truncated from index |
| plan/index.md, iterations/index.md | scripts only | Full history, source of truth |
| register.md | scripts only | Module registry |
| AGENTS.md | agent (smart merge) | User content preserved during updates |
| tests.md, utils.md, notes.md | agent | User-maintained content |
| scripts/*.sh | plugin (replace) | Always overwritten on update |
| templates/*.md | plugin (replace) | Always overwritten on update |
| .gitignore | plugin (replace) | Always overwritten on update |
| .agentspace-version.json | scripts (update-version.sh) | Version tracking |
| .agentspace-architecture.json | plugin (copy) | Architecture snapshot |

## Bilingual Policy

| Content type | Language |
|---|---|
| Workspace templates (assets/) | Chinese |
| Workspace AGENTS.md | Chinese |
| Plugin SKILL.md (update) | English (primary) + Chinese (.zh-CN.md) |
| Plugin SKILL.md (init, daily) | Chinese (workspace convention) |
| DEVELOPMENT.md | English |
| README.md | English (primary) + Chinese (.zh-CN.md) |
| CHANGELOG.md | English |
| architecture.json | English keys, Chinese section headings |
