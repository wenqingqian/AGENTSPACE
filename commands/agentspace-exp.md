---
description: Record an experiment into the AGENTSPACE exp module (enrollment gate plus manual lifecycle; delegates design alignment to agentspace-better-exp and reports to agentspace-better-exp-report)
argument-hint: "[english experiment title]"
skills: agentspace-exp
---

Use the `agentspace-exp` skill to decide enrollment (opt-in only — correctness-verification runs are never enrolled; one exp = one goal, so registering a NEW exp means a new goal) and drive the experiment-record lifecycle — design alignment via agentspace-better-exp, registration and lifecycle via `AGENTSPACE/scripts/new-exp.sh` / `start-exp.sh` / `complete-exp.sh` / `reopen-exp.sh` (follow-up rounds under the same goal fold into the open exp, never a new exp per round; a closed goal reopens), reports via agentspace-better-exp-report.

$ARGUMENTS
