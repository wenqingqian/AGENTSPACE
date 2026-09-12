---
description: Initialize a light AGENTSPACE workspace (plan module only) in the current project
argument-hint: "(no arguments)"
skills: agentspace-init-light
---

Use the `agentspace-init-light` skill to initialize a light AGENTSPACE workspace (plan module only) in the current project root.

Follow the skill's initialization flow exactly: guard against re-initialization, run the init-light script, handle the root AGENTS.md carefully (never overwrite an existing one), and report the result.

$ARGUMENTS
