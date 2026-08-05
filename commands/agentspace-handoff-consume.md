---
description: Consume a one-shot session handoff — read it to rebuild session context, then delete it (and its index row); --keep preserves both
argument-hint: "[--name <name>] [--keep]"
skills: agentspace-handoff
---

Use the `agentspace-handoff` skill (consume flow) to read a handoff and rebuild session context.

Consume flow: run `AGENTSPACE/scripts/handoff.sh --list` (or specify `--name`), read the handoff file fully, build context from it, then run `AGENTSPACE/scripts/handoff.sh --consume --name <name>` to delete the file and its index row (`--keep` preserves both).

$ARGUMENTS
