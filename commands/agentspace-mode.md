---
description: AGENTSPACE workspace mode control — hybrid (default) / standalone. Switch modes, manage the external-dependency whitelist, cue the mode rules. Use ONLY via the explicit /agentspace-mode command.
argument-hint: ""
skills: agentspace-mode
---

Use the `agentspace-mode` skill to control the workspace mode.

Follow the skill's MUST flow exactly: run the deterministic `AGENTSPACE/scripts/mode.sh` core, present the current mode (and the standalone rules when in standalone mode), confirm the user's explicit exemption decisions before any small-file whitelist entry, and never auto-resolve small-file violations.

$ARGUMENTS
