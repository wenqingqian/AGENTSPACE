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

Run the scaffolding tool (repo root, dev-only — NOT part of the deployed plugin):

```bash
bash new-version.sh 0.2.11
```

It creates `skills/agentspace-update/versions/v{NEW}/` with a CHANGELOG skeleton and an architecture.json copied from the latest version (version field bumped), and updates the version fields in `.zcode-plugin/plugin.json`, `marketplace.json` (`plugins[0].version`), and the init assets' `.agentspace-version.json` / `.agentspace-architecture.json`.

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

### [Breaking/Schema/Addition/Fix] Change title
- **What**: precise description of the change
- **Why**: design rationale
- **Migration**: exact steps the update agent must execute (see quality requirements below)
```

Tags:
- `[Breaking]` — removes or fundamentally restructures something; data may be lost
- `[Schema]` — table column changes; existing data may need transformation
- `[Addition]` — new files/sections; non-destructive
- `[Fix]` — bug fix or wording correction; non-destructive

**CHANGELOG quality requirements (MUST)**:

The changelog is the update agent's ONLY source of migration guidance. It MUST be detailed enough for the agent to execute the migration without guessing. For each change:

1. **Exact files to create/modify/delete** — full paths relative to workspace root (e.g., `AGENTSPACE/data.md`, `AGENTSPACE/.gitignore`)
2. **Exact text to insert** — for AGENTS.md changes, include the COMPLETE markdown text to insert, not a summary. Include the section heading, bullet points, and code blocks.
3. **Exact insertion points** — specify WHERE in the file to insert (e.g., "before `### utils` in the 模块 section", "after the `iterations/*/data/` line in .gitignore")
4. **Structure tree updates** — for new modules, include the exact line to add to the 结构 code block in AGENTS.md
5. **Handled by update flow** — if a change is automatically handled by step 8a (scripts/templates/.gitignore replacement from assets), state this explicitly. The agent doesn't need to do manual work for these changes.

Example of a GOOD migration instruction:
```markdown
**Migration**:
1. Create directory: `mkdir -p AGENTSPACE/data`
2. Copy template: `skills/agentspace-init/assets/agentspace/data.md` → `AGENTSPACE/data.md`
3. Update `.gitignore`: add `data/` after the `iterations/*/data/` line
4. Update `AGENTSPACE/AGENTS.md`:
   - In 结构 code block, add before `utils.md`: `├── data.md + data/    ← 公用数据`
   - In 模块 section, add before `### utils`:
     ```markdown
     ### data —— 公用数据 (data.md + data/)
     - **what**: ...
     - **when/how**: ...
     ```
```

Example of a BAD migration instruction:
```markdown
**Migration**: create data/ directory + data.md entry file; no existing content affected
```
(too vague — doesn't specify where, how, or what to put in AGENTS.md)

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
2. Bump `version` in `skills/agentspace-init/assets/agentspace/.agentspace-version.json` (single field since v0.2.0)
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

**SKILL size budget (MUST)**: `skills/agentspace/SKILL.md` stays ≤ 120 lines. New guidance goes into `assets/agentspace/AGENTS.md` (which the skill keeps in context via §1) unless it is an ACTION (what to do), not background. If the budget is exceeded, move detail down to AGENTS.md.

**Bilingual sync check (MUST, every release)**: `SKILL.md` and `SKILL.zh-CN.md` must have the same section structure and order. Compare heading LEVEL sequences (text differs by language, so compare `#`/`##`/`###` markers only):
```bash
grep -o '^#\{1,3\}' skills/agentspace/SKILL.md > /tmp/skill-en
grep -o '^#\{1,3\}' skills/agentspace/SKILL.zh-CN.md > /tmp/skill-zh
diff /tmp/skill-en /tmp/skill-zh && echo "bilingual structure OK"
```
Also check rule-level token parity (a rule tagged [MUST] in one language must exist in the other):
```bash
for t in MUST SHOULD MAY; do
  en=$(grep -o "$t" skills/agentspace/SKILL.md | wc -l | tr -d ' ')
  zh=$(grep -o "$t" skills/agentspace/SKILL.zh-CN.md | wc -l | tr -d ' ')
  [ "$en" = "$zh" ] || echo "MISMATCH: $t en=$en zh=$zh"
done
```
Any mismatch means a rule exists in one language only — fix before release.

### Step 7: Test

0. Run the release gate (repo root dev tool, read-only): `bash verify-release.sh` — checks JSON validity, version consistency, archive chain continuity, CHANGELOG quality, the assets↔architecture contract, `bash -n` on all scripts, bilingual sync, and SKILL size budgets. Fix any issue it reports.
1. `bash -n` on all `.sh` files (covered by the gate)
2. `/tmp` init → verify new workspace has correct structure
3. `/tmp` update from old version → verify migration works in both modes
4. `doctor.sh` green after update
5. `python3 -m json.tool` on all `.json` files (covered by the gate)
6. Bilingual sync check (see Step 6) (covered by the gate)
7. SKILL size budget (covered by the gate)
8. Run the regression suite (repo root dev tool): `bash self-test.sh` — plan/iteration lifecycle, close/complete gates, doctor red states (broken link, placeholder drift, duplicate-section backstop), version-marker mechanics. Each scenario runs the real init script in an isolated /tmp sandbox.

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
| Plugin SKILL.md (all skills) | English (primary) + Chinese (.zh-CN.md) |
| DEVELOPMENT.md | English |
| README.md | English (primary) + Chinese (.zh-CN.md) |
| CHANGELOG.md | Chinese (project working language; historical English archives are not retro-fitted) |
| architecture.json | English keys, Chinese section headings (as deployed) |

## Release Cadence (batching discipline)

- **Batch small changes**: fixes and small optimizations accumulate into ONE release — never ship a version per fix. Four small fix batches on one day, each with its own changelog, is the anti-pattern; a release is for a meaningful capability step or an accumulated batch.
- **Capability-only bumps**: bump the version only when the plugin's capability changes; dev-tooling and doc changes (new-version.sh, verify-release.sh, tests, SKILL text, historical changelog anchors) ship without a version — management improvements.
- **Archive count is a cost**: every version adds a CHANGELOG+architecture pair that the upgrade chain replays (t13) and users carry. Prefer fewer, richer archives over many thin ones.

## Script pattern discipline (MUST)

Hard-won contracts from the 2026-08-06 risk audit (8 findings + same-pattern sweep). Every workspace script MUST follow these; new code that violates one is a release blocker — the patterns already exist as helpers, reuse them instead of re-implementing:

1. **as_cell-escaped content passes to awk via ENVIRON, never `-v`** — `awk -v` processes backslash escapes and eats the `\` of `\|` (corrupted plan/index.md and iterations/index.md rows; the hazard is documented at `as_insert_row`). Same for any variable that may contain `\|`.
2. **Row deletion/matching is dual-condition or normalized** — delete by `name AND location` (handoff consume, doctor [10]) or `as_norm_id` before matching files/dirs (doctor --fix orphan rows). Name-only or raw-id matching deletes the wrong row.
3. **Every write is atomic** — `as_atomic_write` (tmp+mv in $AS_TMPDIR), never `cat >`, `>`, or `>>` on a live file (crash windows leave half-written rows/markers; `update-version.sh` once silently lost the version marker this way).
4. **Every `$(...)` read path is guarded** — `2>/dev/null || true` (a bare awk/grep on a missing file aborts the whole script under `set -euo pipefail` and skips remaining checks).
5. **Read-only commands must not write** — anything declared read-only (status.sh workbench) must stay read-only; write paths belong behind explicit gates (`--fix`) or dedicated scripts.
6. **New tools join the environment gate** — lib.sh's toolchain list must include every external command the scripts use (head, cut, wc, ...).

