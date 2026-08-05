---
description: Produce a one-shot session handoff (AGENTSPACE/handoff/) so the next session starts without rebuilding context; the file is consumed (deleted) by the next session
argument-hint: "[--name <name>] [--description <text>]"
skills: agentspace-handoff
---

Use the `agentspace-handoff` skill (produce flow) to write a one-shot session handoff into `AGENTSPACE/handoff/`.

Produce flow: update the persistent docs first (iteration readme 当前状态 · 下一步), take a `status.sh` snapshot, pick a semantic name (the name is what the next session remembers the handoff by — never `xxx-2` suffixes; conflicts are refused), then run `AGENTSPACE/scripts/handoff.sh --produce --name <name> [--description <text>]` and fill the generated file's content sections.

$ARGUMENTS
