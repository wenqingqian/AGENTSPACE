# AGENTSPACE v0.4.0

Upgrade from v0.3.3. Date: 2026-08-05

## Summary

- **New module: handoff** — one-shot session handoffs (`AGENTSPACE/handoff/`): `/agentspace-handoff-produce` writes a disposable context snapshot at session close (semantic name required, conflicts refused — never auto-renamed), `/agentspace-handoff-consume` reads it and deletes it (`--keep` preserves). Index (`handoff/index.md`) is scripts-maintained and committed; handoff files are gitignored. Any session can produce, with or without in-progress plans.
- **Command naming unified**: `/init-agentspace` → `/agentspace-init`, `/update-agentspace` → `/agentspace-update`, `/doctor-agentspace` → `/agentspace-doctor` (breaking rename — old names are gone; all docs, skills, and commands updated).

## Changes

### [Addition] handoff module: produce/consume one-shot session handoffs
**What**: new module under `AGENTSPACE/handoff/`:
- `handoff/index.md` — table `name | description | location | time`, written ONLY by `AGENTSPACE/scripts/handoff.sh` (committed contract, same discipline as plan.md)
- `handoff/handoff_<name>.md` — the disposable snapshot (gitignored via `handoff/handoff_*.md`)
- `AGENTSPACE/scripts/handoff.sh` — `--produce --name X [--description Y]` (validates name/location free, refuses on conflict — no `-2`/`-3` auto-renaming; creates the file from the template + indexes it), `--list`, `--consume [--keep] --name X` (deletes file + index row; `--keep` keeps both)
- `AGENTSPACE/templates/handoff.md` — content template (项目上下文 / 当前状态 / 本次会话 / 下一步 / 开放问题 / 引用)
- Commands `/agentspace-handoff-produce` and `/agentspace-handoff-consume` + skill `agentspace-handoff` (EN + ZH): produce flow = update persistent docs → status snapshot → semantic name → `handoff.sh --produce` → fill sections → milestone commit; consume flow = `--list` or `--name` → read fully → `--consume`

**Why**: sessions previously rebuilt context from scratch (AGENTS.md + tests.md + iterations.md + indexes); closing a session lost anything not written into the resume block. A one-shot handoff makes the next session start from a purpose-built context snapshot, with the disposable file deleted on consumption.

**Migration**:
1. **Scripts/templates/.gitignore (handled by step 8a — no manual work)**: `AGENTSPACE/scripts/handoff.sh`, `AGENTSPACE/templates/handoff.md`, and the updated `.gitignore` are replaced from assets.
2. **New module (step 8b — agent action)**: create `AGENTSPACE/handoff/index.md` by copying `skills/agentspace-init/assets/agentspace/handoff/index.md` from the plugin assets. `handoff.sh` also self-initializes the index if absent (belt and braces).
3. **AGENTS.md (step 8b — agent action, exact insertions)**:
   - In the 结构 tree block, insert this line BEFORE the `├── templates/` line:
     `├── handoff/           ← 一次性会话交接文件 + index.md(由 scripts/handoff.sh 维护, 文件不入 git)`
   - Also update the existing `├── templates/` line — append `/ handoff` to its description (the templates dir gained `handoff.md`):
     `├── templates/         ← 文档模板(plan / iteration-readme / module-entry / note / handoff)`
   - In the 模块 section, insert this block AFTER the `### register` bullet block:
     `### handoff —— 一次性会话交接 (handoff/)`
     `- **what**: 会话结束时生成的一次性上下文快照, 新会话读取后即销毁(consume); 支持多个 handoff 并存, index.md 登记 name/description/location/time`
     `- **when**: 关闭会话前收尾时(任何情况都可用, 不要求有进行中 plan); 新会话开始时消费`
     `- **how**: `/agentspace-handoff-produce [--name <名>] [--description <说明>]` → 填充内容 → 新会话 `/agentspace-handoff-consume --name <名> [--keep]`; 所有写操作经 `scripts/handoff.sh`(名字冲突会拒绝, 不会自动加后缀)`
   - In 读取规则 item 2, replace the second half after "任务相关时读 plan.md;" with:
     `会话续接时: 有 handoff 先读 `handoff/index.md` 选最新并 consume, 否则读 `iterations/latest/readme.md` 的"当前状态 · 下一步"`
   Idempotency: if the structure tree already contains `handoff/`, leave it as-is.
4. **Command renames (plugin-side, no workspace action — but read on)**: `/init-agentspace` → `/agentspace-init`, `/update-agentspace` → `/agentspace-update`, `/doctor-agentspace` → `/agentspace-doctor`. Old command names no longer exist. Workspace docs written by the agent (AGENTS.md content, notes) may still mention old names — update them opportunistically when touched (agent-side, not a gate).
5. **No data migration**: handoff starts empty; nothing else changes.

### [Breaking] Command naming: agentspace- prefix
**What**: the three existing commands were renamed to the unified `agentspace-` prefix: `/init-agentspace` → `/agentspace-init`, `/update-agentspace` → `/agentspace-update`, `/doctor-agentspace` → `/agentspace-doctor`. Command files renamed accordingly (`commands/agentspace-init.md` etc.); all skill descriptions, guard text, README (EN+ZH), plugin/marketplace descriptions, and the init asset `root-AGENTS.md` updated. No aliases are kept.
**Why**: consistent command namespace (`/agentspace-*`) across the plugin, matching the two new handoff commands.
**Migration**:
1. **Plugin-side (no workspace action)**: ships with the plugin.
2. **Users**: invoke the new names; the agent should prefer the new names everywhere (update stale references in workspace AGENTS.md / notes opportunistically).

### [Fix] as_insert_row: escaped `\|` cells preserved (root cause found by v0.4.0 review)
**What**: `AGENTSPACE/scripts/lib.sh` `as_insert_row` now passes the row via `ENVIRON["ROW"]` instead of `awk -v row=...`. `awk -v` unescapes `\|` back to `|`, so cells sanitized by `as_cell` (pipes in titles/descriptions) silently corrupted the table into extra columns — this affected the new handoff index and was a latent defect in `register-module.sh` too.
**Why**: found while fixing the v0.4.0 handoff review findings (R2) — a `|` in a handoff description produced a 5-cell row.
**Migration**:
1. **Script (handled by step 8a — no manual work)**: `AGENTSPACE/scripts/lib.sh` is replaced from assets.
2. **No data migration**: rows previously corrupted by this bug (rare) are fixed by re-registering them.

### No structural changes beyond the handoff module
- plan/iterations/notes/utils/tests/data/examples/register schemas unchanged; constants gained `SEC_HANDOFF` (verified by doctor [5]-style contract via verify-release [4]).
