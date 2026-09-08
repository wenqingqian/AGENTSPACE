---
name: agentspace-exp
description: Experiment-record (exp module) trigger for AGENTSPACE workspaces — the workflow entry for recording an experiment into exp; the design and report disciplines live in the separate skills it delegates to (agentspace-better-exp, agentspace-better-exp-report). Activate when the user invokes /agentspace-exp, asks to record an experiment into exp, or mentions an upcoming experiment (this skill then makes the one-time enrollment offer). Owns the enrollment gate — exp is opt-in only; correctness-verification runs at development close are never enrolled; if the offer is declined, the experiment proceeds unrecorded and the offer is not repeated. After the user opts in, hand design alignment to agentspace-better-exp, then drive the manual lifecycle (new-exp.sh, start-exp.sh, complete-exp.sh; configs must land in examples/exp_spec/, full records in exp_data/). Not every experiment needs an exp record — only measurements, verifications or investigations the user chose to register.
---

# Experiment Records Trigger (agentspace-exp)

> Workflow entry for the exp module — enrollment gate plus manual lifecycle. This skill is a trigger, not the discipline: design alignment belongs to agentspace-better-exp, reports and figures to agentspace-better-exp-report.

## 0. Activation guard

Check in order; if any condition fails, exit silently (handle as a normal request):
1. The user invoked `/agentspace-exp`, asked to record an experiment into exp, or mentioned an upcoming experiment (in the last case this skill makes the one-time enrollment offer)
2. `AGENTSPACE/` directory exists in project root — if the user explicitly invoked the command and the workspace is missing, state that plainly and stop (the workspace is created only via /agentspace-init)

## 1. Enrollment gate (MUST)

- **Opt-in only** — register an exp only when the user explicitly asks for agentspace-exp, or accepts your one-time offer made when they mentioned an upcoming experiment. Offer at most once per session; if declined, the experiment proceeds unrecorded and the offer is not repeated.
- **Not every experiment qualifies** — routine correctness-verification runs at development close stay out unless the user confirms. exp records measurements, verifications and investigations the user chose to register; plan/iteration workflows are unaffected.
- Context and discipline rules (AGENTS.md reading sequence, scripts-only indexes) follow the agentspace skill and the workspace AGENTS.md exp module.

## 2. Lifecycle (after opt-in)

1. **Design alignment first** — run the agentspace-better-exp skill (five axes); its output contract fills the exp manual, then register:
```bash
AGENTSPACE/scripts/new-exp.sh "English experiment title" [--plan NNNN] [--iteration NNNN]   # configs must land in examples/exp_spec/exp_NNNN/
AGENTSPACE/scripts/start-exp.sh <id>                     # launch todo→doing (small exps may skip); full records → exp/exp_data/exp_NNNN/
AGENTSPACE/scripts/complete-exp.sh <id> <done|failed|abandoned> "result" [--commit "repo@sha,..."]
```
2. Mechanics (exp_spec contract, exp_data as the canonical full record, commits-as-points semantics) are owned by the workspace AGENTS.md exp module — follow it, never hand-edit indexes.
3. **Reports on close** — when the user wants a report or figures from the recorded data, run the agentspace-better-exp-report skill.

## 3. Division of labor

- plan = why/what, iteration = change the code, exp = measure the code; an exp needs no plan/iteration; a linked exp copies iteration data/ into exp_data.
- If the user declines recording mid-alignment — stop; the experiment proceeds unrecorded and the offer is not repeated this session.
