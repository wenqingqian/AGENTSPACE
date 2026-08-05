---
name: agentspace-update
description: Update an existing AGENTSPACE workspace to match the current plugin version. Triggered ONLY by the explicit /agentspace-update command. Uses changelog-driven, agent-analyzed migration with conservative/aggressive modes. Never trigger automatically.
---

# AGENTSPACE Update Flow

Triggered ONLY by explicit `/agentspace-update` command. Never run automatically.

## Steps

### 1. Guard

Check if `AGENTSPACE/` exists in the project root. If not, report error and suggest `/agentspace-init`. Do NOT initialize — that is a separate command.

Also check the workspace git state: if `git -C AGENTSPACE status --porcelain` shows uncommitted changes, tell the user before proceeding — recommend committing the pending milestone first, and warn that rollback (`git -C AGENTSPACE reset --hard pre-update-v<old>`) will discard uncommitted changes.

### 2. Read Current State

Read `AGENTSPACE/.agentspace-version.json` → `currentVersion`:
- If file exists: extract `version`
- If missing: treat as `"0.1.0"` (legacy workspace) and inform user this is the first update

Read `AGENTSPACE/.agentspace-architecture.json`:
- If file exists: use as current architecture reference
- If missing: infer architecture by scanning actual workspace files (read section headings, column headers from markdown tables)

Read plugin version from `.zcode-plugin/plugin.json` → `targetVersion`

### 3. Version Check

Compare `currentVersion` vs `targetVersion`. If equal:
- Run `AGENTSPACE/scripts/status.sh`
- Report "Already up to date (vX.Y.Z)" and exit

### 4. Determine Update Mode

Default: **conservative** (asks before destructive changes).

Switch to **aggressive** if:
- User passed `--force` argument
- User explicitly says "aggressive update" / "激进更新" in conversation

### 5. Load Version Archives

For each version from `currentVersion + 1` to `targetVersion` (chronological order):
- Read `skills/agentspace-update/versions/vX.Y.Z/CHANGELOG.md` — what changed from the previous version
- Read `skills/agentspace-update/versions/vX.Y.Z/architecture.json` — target architecture snapshot

Each CHANGELOG is a diff from its predecessor. Example: updating from v0.2.0 to v0.2.2 reads v0.2.1/CHANGELOG.md (0.2.0→0.2.1) then v0.2.2/CHANGELOG.md (0.2.1→0.2.2). The agent applies changes in this chronological order.

If a changelog entry does not affect the current workspace (e.g., a change to a module the user hasn't registered), the agent may skip it.

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
- scripts/*.sh — all scripts replaced with latest versions (9 at v0.4.x)
- templates/*.md — all templates replaced (5 at v0.4.x)
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

**Critical**: in conservative mode, if a destructive change (deletion, schema loss) is refused by the user, that change is SKIPPED, not forced. The version file records the highest version V such that every changelog from `currentVersion + 1` through V was fully applied — i.e., if the earliest skipped change comes from vN, record N-1 (or keep the current version); never the target version. Otherwise the next update starts after the skipped version and the refused items are never re-attempted.

### 8. Execute Update

After confirmation (or immediately in aggressive mode), first create the rollback tag in the workspace repo (git by the init contract). `<old>` is the currentVersion read in step 2 — the version being updated FROM. Use `-f` to overwrite: on a re-attempt from the same base version the tag is re-pointed at the current pre-update state, so rollback undoes only the current update. If the tag command fails, abort and report the error.

```bash
git -C AGENTSPACE tag -f pre-update-v<old>
```

Then:

**Maintain a migration ledger** as you apply the changelog: for every change block, record `applied` / `skipped` / `not-applicable` (with the reason for skipped items). The ledger is the audit trail for the Step 11 report — do not rely on session memory alone.

**a. Replace plugin-managed files** (relative paths below are from the PLUGIN REPO ROOT — run them there, or use absolute paths when working from a subdirectory):
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
  - When re-applying a previously refused insertion, the anchor area may carry residual blank lines left by the earlier skip — after inserting, collapse consecutive blank lines to one (verify against the canonical asset `skills/agentspace-init/assets/agentspace/AGENTS.md`)

**c. Update version markers** — pass the version determined in step 7 (targetVersion when every changelog item was applied; otherwise the highest fully-applied version):
```bash
bash skills/agentspace-update/scripts/update-version.sh <recorded-version>
```
Copy the architecture.json of the RECORDED version (not the target — the snapshot must describe what the workspace actually is):
```bash
cp skills/agentspace-update/versions/v<recorded>/architecture.json AGENTSPACE/.agentspace-architecture.json
```

### 9. Verify (gate)

Run `AGENTSPACE/scripts/doctor.sh --fix` (tier-1 repairs: latest symlink, orphan table rows, missing notes.md rows, dangling handoff index rows), then run `AGENTSPACE/scripts/doctor.sh`:
- Red items other than [0] (uncommitted changes — expected mid-update; committed in step 10) must be resolved before proceeding: discuss repairs with the user per doctor's Tip, never hand-edit tables. Only [0] may remain.
- Proceed to step 10, then re-run `AGENTSPACE/scripts/doctor.sh` — it must exit 0 (全绿). If red: fix (doctor.sh --fix or a user-confirmed repair) and commit the fixup. The update is NOT complete until the post-commit doctor is green — never announce success with red items pending.

### 10. Git Commit

```bash
git -C AGENTSPACE add -A && git -C AGENTSPACE commit -m "update: AGENTSPACE v<old> → v<new>"
```

Commit message type: `update`. If the recorded version equals the old version (partial refusal), commit as `update: AGENTSPACE partial (v<old>, refused items pending)`. Report the commit hash to the user.

### 11. Report

Summarize what was done:
- Versions jumped: v旧 → v新
- Files replaced (count)
- Schema changes applied (which files)
- Content merges applied (which files)
- Items skipped (if any, in conservative mode)
- Per-item migration ledger: one line per changelog change block with its status (applied / skipped / not-applicable)
- Doctor result
- Rollback command: `git -C AGENTSPACE reset --hard pre-update-v<old>`
- Next steps suggestion

## Notes

- **Partial updates**: if the user refuses some changes in conservative mode, the workspace is in a mixed state. Record the highest fully-applied version in `.agentspace-version.json` and copy that version's architecture.json (see step 7 Critical + step 8c) — lower than targetVersion. The next update re-reads the skipped version's changelog and re-attempts the skipped changes.
- **Rollback**: every update creates/overwrites a `pre-update-v<old>` tag (`<old>` = currentVersion from step 2) before mutating (step 8). Roll back with `git -C AGENTSPACE reset --hard pre-update-v<old>`; delete a tag with `git -C AGENTSPACE tag -d pre-update-v<old>`. Tags are cheap — leave them in place. Before `reset --hard`, check `git status` — uncommitted changes are discarded (stash or commit them first).
- **Workspace templates (assets/) stay Chinese**: the workspace language convention is Chinese. The update skill and developer docs are English because they are plugin-infrastructure concerns.
