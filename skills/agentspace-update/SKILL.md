---
name: agentspace-update
description: Update an existing AGENTSPACE workspace to match the current plugin version. Triggered ONLY by the explicit /update-agentspace command. Uses changelog-driven, agent-analyzed migration with conservative/aggressive modes. Never trigger automatically.
---

# AGENTSPACE Update Flow

Triggered ONLY by explicit `/update-agentspace` command. Never run automatically.

## Steps

### 1. Guard

Check if `AGENTSPACE/` exists in the project root. If not, report error and suggest `/init-agentspace`. Do NOT initialize — that is a separate command.

### 2. Read Current State

Read `AGENTSPACE/.agentspace-version.json`:
- If file exists: extract `workspaceVersion`
- If missing: treat as `"0.1.0"` (legacy workspace) and inform user this is the first update

Read `AGENTSPACE/.agentspace-architecture.json`:
- If file exists: use as current architecture reference
- If missing: infer architecture by scanning actual workspace files (read section headings, column headers from markdown tables)

Read plugin version from `.zcode-plugin/plugin.json` → `pluginVersion`

### 3. Version Check

Compare `workspaceVersion` vs `pluginVersion`. If equal:
- Run `AGENTSPACE/scripts/status.sh`
- Report "Already up to date (vX.Y.Z)" and exit

### 4. Determine Update Mode

Default: **conservative** (asks before destructive changes).

Switch to **aggressive** if:
- User passed `--force` argument
- User explicitly says "aggressive update" / "激进更新" in conversation

### 5. Load Target Version Archive

For each version from `workspaceVersion + 1` to `pluginVersion`:
- Read `skills/agentspace-update/versions/vX.Y.Z/CHANGELOG.md` — detailed change descriptions
- Read `skills/agentspace-update/versions/vX.Y.Z/architecture.json` — target architecture snapshot

If multiple version jumps are needed, read ALL intermediate changelogs in order.

### 6. Agent Analysis (Core — NOT a Script)

This is the intelligent analysis step. The agent (you) must:

**a. Understand every change** by reading each CHANGELOG entry carefully:
- What changed at the file/schema/module level
- Why the change was made
- Migration guidance provided (conservative vs aggressive paths)

**b. Diff architectures** — compare current `.agentspace-architecture.json` vs target:
- Files added / removed / renamed
- Sections added / removed / renamed within files
- Column changes in tables (added / removed / reordered)
- `type` changes (view→content, etc.)
- `managedBy` changes
- `constants` drift (SEC_*/STATUS_* strings changed — means lib.sh contract changed)

**c. Scan actual workspace content**:
- Read key files to understand current state
- Check if user has custom content that would be affected
- Count affected data rows for schema changes (how many plan/iteration entries have the old column layout)

**d. Build update plan** — a structured summary of what the update will do:
- **Safe replacements**: scripts/*.sh, templates/*.md, .gitignore (always safe, no user content)
- **Schema transforms**: view files with column changes (show column diff + affected row count)
- **Content merges**: AGENTS.md, tests.md, utils.md, notes.md (describe new sections vs preserved user content)
- **Deletions**: removed modules/files (list every file that will be deleted)

### 7. Conservative Mode Confirmation

Present the update plan to the user in a clear, itemized format:

```
## Update Plan: v0.1.0 → v0.2.0

### Safe (automatic)
- scripts/*.sh — 8 files replaced with latest versions
- templates/*.md — 4 files replaced
- .gitignore — replaced

### Schema Changes
- plan.md: new "Priority" column (affects N existing plan entries)
- plan/index.md: new "Priority" column
- iterations.md: no changes

### Content Merges
- AGENTS.md: new "Version History" section inserted; your 项目简介/根仓库简介 preserved
- tests.md: no changes

### Deletions
- register.md + register/ — module removed (X registered entries will be lost)
```

User responses:
- **"Proceed" / "OK"** → execute all changes
- **Per-item refusal** → skip that change, execute the rest
- **"Cancel" / "不更新"** → abort, no files touched
- **"Use aggressive mode"** → re-run without confirmation prompts

**Critical**: in conservative mode, if a destructive change (deletion, schema loss) is refused by the user, that change is SKIPPED, not forced. The version file should reflect what was actually applied, not the full target version.

### 8. Execute Update

After confirmation (or immediately in aggressive mode):

**a. Replace plugin-managed files**:
```bash
# Scripts
cp -R skills/agentspace-update/../../skills/agentspace-init/assets/agentspace/scripts/*.sh AGENTSPACE/scripts/
chmod +x AGENTSPACE/scripts/*.sh
# Templates
cp -R skills/agentspace-update/../../skills/agentspace-init/assets/agentspace/templates/*.md AGENTSPACE/templates/
# .gitignore
cp skills/agentspace-update/../../skills/agentspace-init/assets/agentspace/.gitignore AGENTSPACE/.gitignore
```

Note: the source is `skills/agentspace-init/assets/agentspace/` (the canonical assets directory). The update skill references the init skill's assets as the source of truth for plugin-managed files.

**b. Apply each changelog item** (agent executes, not a rigid script):
- **New sections/files** → create them in the appropriate locations
- **Deleted modules** → remove all files and directories under that module
- **Schema changes** → rebuild affected view files using current data:
  - Extract data rows from existing view/index files
  - Write new table headers (from target architecture.json)
  - Re-insert data rows (new columns default to empty)
  - Re-apply truncation rules (maxRows from architecture)
- **AGENTS.md changes** → smart merge:
  - Insert new sections at specified positions
  - Preserve user-filled sections (项目简介, 根仓库简介) verbatim
  - Update structural sections (结构 tree, module list) to reflect new architecture
  - Update 纪律 section if constants changed

**c. Update version markers**:
```bash
bash skills/agentspace-update/scripts/update-version.sh <target-version> <plugin-version>
```
Also copy the target architecture.json:
```bash
cp skills/agentspace-update/versions/v<target>/architecture.json AGENTSPACE/.agentspace-architecture.json
```

### 9. Verify

Run `AGENTSPACE/scripts/doctor.sh` and check for consistency issues. If issues found:
- Auto-repairable (broken latest symlink) → doctor handles it
- Data inconsistencies → report to user, suggest manual fix

### 10. Git Commit

```bash
git -C AGENTSPACE add -A && git -C AGENTSPACE commit -m "update: AGENTSPACE v<old> → v<new>"
```

Commit message type: `update`. Report the commit hash to the user.

### 11. Report

Summarize what was done:
- Versions jumped: v旧 → v新
- Files replaced (count)
- Schema changes applied (which files)
- Content merges applied (which files)
- Items skipped (if any, in conservative mode)
- Doctor result
- Next steps suggestion

## Notes

- **Partial updates**: if the user refuses some changes in conservative mode, the workspace is in a mixed state. Record the ACTUAL applied version in `.agentspace-version.json` (may be lower than pluginVersion). The next update will re-attempt skipped changes.
- **No rollback**: there is no built-in rollback mechanism. The AGENTSPACE git history serves as the rollback point — user can `git -C AGENTSPACE reset --hard <pre-update-commit>` if needed.
- **Workspace templates (assets/) stay Chinese**: the workspace language convention is Chinese. The update skill and developer docs are English because they are plugin-infrastructure concerns.
