---
description: Deep health check of an existing AGENTSPACE workspace — structure, per-file content, cross-cutting history, repairs. Use ONLY via the explicit /agentspace-doctor command (--minor | --major [--fix]).
argument-hint: "[--minor | --major] [--fix]"
skills: agentspace-doctor
---

Use the `agentspace-doctor` skill to audit the AGENTSPACE workspace in the current project root.

Follow the skill's flow exactly: run the deterministic `AGENTSPACE/scripts/doctor.sh` core first, then the mode-specific layers (minor: per-file content review; major: cross-cutting subagent audit), keep the command read-only unless `--fix` is explicitly given, and report findings in the three-tier format.

$ARGUMENTS
