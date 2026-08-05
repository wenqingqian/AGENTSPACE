---
name: agentspace-handoff
description: Produce or consume one-shot session handoffs (AGENTSPACE/handoff/) — the produce flow writes a disposable context snapshot at session close so the next session starts without rebuilding context; the consume flow reads it and deletes it. Triggered ONLY by the explicit /agentspace-handoff-produce and /agentspace-handoff-consume commands. Never trigger automatically.
---

# AGENTSPACE Handoff

One-shot session handoffs: at session close, produce a disposable context snapshot (`AGENTSPACE/handoff/handoff_<name>.md` + a row in `handoff/index.md`); at the next session start, consume it (read, then delete). Multiple handoffs can coexist; the index (scripts-maintained, committed) lists `name | description | location | time`.

## 0. Trigger Guard

Proceed ONLY when the user explicitly executes `/agentspace-handoff-produce` or `/agentspace-handoff-consume`. Never trigger automatically (not at wrap-up, not at session start). Never run against a project with no AGENTSPACE workspace (state that plainly and stop).

## 1. Produce flow (session close)

1. **Update persistent docs first** (wrap-up protocol ①): refresh the in-progress iteration readme's 当前状态 · 下一步 and any open plan docs — the handoff must snapshot the *updated* state, not the stale one.
2. **Snapshot**: run `AGENTSPACE/scripts/status.sh` and read the latest iteration readme.
3. **Name**: pick a short semantic name — the name is how the next session remembers the handoff ("看名字就能想起来"). Never `xxx-2`/`xxx-3` suffixes. If the user did not supply a name, derive one from the session topic (latest iteration title / plan title / the day's work); the script's fallback `session-<timestamp>` is a last resort only.
4. **Produce**: run `AGENTSPACE/scripts/handoff.sh --produce --name <name> [--description <text>]`. If it refuses (name/location already indexed), pick a distinct semantic name and retry — never rename with numeric suffixes.
5. **Fill content**: the script created the file from `templates/handoff.md`; fill every section — 项目上下文 (from AGENTS.md/tests.md), 当前状态 (status snapshot + resume block), 本次会话 (what was done, decisions, data/ artifacts), 下一步 (the next session's task list), 开放问题, 引用 (plan:NNNN / iteration_NNNN / notes / file paths).
6. **Milestone commit** (the index row is a committed contract; the handoff file itself is gitignored): `git -C AGENTSPACE add -A -- . && git -C AGENTSPACE commit -m "handoff: <name>"`. Tell the user the next session can start with `/agentspace-handoff-consume --name <name>`.

## 2. Consume flow (session start)

1. If the user gave no `--name`: run `AGENTSPACE/scripts/handoff.sh --list` and present the choices (name | description | location | time) — ask the user which to consume.
2. **Read the file fully** (`AGENTSPACE/handoff/handoff_<name>.md`) — it is the context entry: project context, current state, what the previous session did, the task list, open questions.
3. After reading (never before — a crash mid-read must not lose the file): run `AGENTSPACE/scripts/handoff.sh --consume --name <name>` to delete the file and its index row. `--keep` preserves both (debugging / handoff to a second session).
4. If the handoff references plan/iteration/notes, load those as needed per AGENTS.md reading rules.

## 3. Boundaries

- Read-only until the user invokes consume; consume deletes ONLY the named handoff file + its index row
- Never auto-trigger; never consume without reading first; never rename on conflict
- handoff files are gitignored (disposable); `handoff/index.md` is committed (scripts-only writes)
- The handoff is a snapshot, not a source of truth — the workspace files remain authoritative
