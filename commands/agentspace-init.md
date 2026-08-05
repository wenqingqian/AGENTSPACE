---
description: Initialize the AGENTSPACE workspace (git-managed file-based project management) in the current project
argument-hint: "(no arguments)"
skills: agentspace-init
---

Use the `agentspace-init` skill to initialize the AGENTSPACE workspace in the current project root.

Follow the skill's initialization flow exactly: guard against re-initialization, run the init script, handle the root AGENTS.md carefully (never overwrite an existing one), and report the result.

$ARGUMENTS
