---
description: AGENTSPACE workspace status workbench — project overview, current state, soft alerts. Use ONLY via the explicit /agentspace-status command.
argument-hint: ""
skills: agentspace-status
---

Use the `agentspace-status` skill to render the workspace status workbench.

Follow the skill's MUST flow exactly: run the deterministic `AGENTSPACE/scripts/status.sh <plugin-version>` core first, produce the project paragraph via the embedded Explore-subagent prompt, assemble the strict template, and never read workspace files in the main context.

$ARGUMENTS
