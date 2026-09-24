---
name: agentspace-exp
description: Experiment-record (exp module) trigger for AGENTSPACE workspaces — workflow entry for recording an experiment goal into exp; design/report disciplines live in the delegated skills (agentspace-better-exp, agentspace-better-exp-report). Activate on /agentspace-exp, a request to record an experiment into exp, or an upcoming-experiment mention (then this skill makes the one-time enrollment offer). One exp = one goal holding a group of experiment rounds — registering a NEW exp means a new goal and stays opt-in (explicit user confirmation); follow-up rounds under the same goal fold into the existing exp (no new exp, no re-confirmation), reopening it via reopen-exp.sh when closed. Correctness-verification runs at development close are never enrolled. After opt-in, design alignment goes to agentspace-better-exp, then the manual lifecycle runs (new-exp.sh, start-exp.sh, complete-exp.sh; configs in examples/exp_spec/, full records in exp_data/).
---

# Experiment Records Trigger (agentspace-exp)

> Workflow entry for the exp module — enrollment gate plus manual lifecycle. This skill is a trigger, not the discipline: design alignment belongs to agentspace-better-exp, reports and figures to agentspace-better-exp-report.

## 0. Activation guard

Check in order; if any condition fails, exit silently (handle as a normal request):
1. The user invoked `/agentspace-exp`, asked to record an experiment into exp, or mentioned an upcoming experiment (in the last case this skill makes the one-time enrollment offer)
2. `AGENTSPACE/` directory exists in project root — if the user explicitly invoked the command and the workspace is missing, state that plainly and stop (the workspace is created only via /agentspace-init)

## 1. Enrollment gate (MUST)

- **One exp = one goal** — an exp registers a BIG GOAL (a group of experiment rounds under it), never one round. Register at goal granularity and confirm the GOAL with the user — only when the user explicitly asks for agentspace-exp, or accepts your one-time offer made when they mentioned an upcoming experiment. Offer at most once per session; if declined, the experiment proceeds unrecorded and the offer is not repeated.
- **Fold follow-up rounds into the open exp, never a new exp per round** — a new parameter round, re-measurement or incremental result under the SAME goal belongs to the open (todo/doing) exp: append a run entry in the manual's 轮次 section, add run-prefixed configs to examples/exp_spec/exp_NNNN/, land data in exp/exp_data/exp_NNNN/ (per-run subdirectory). State what you are appending — no new confirmation (the goal-level enrollment already covers it), no new exp. Goal already closed: reopen it first (`reopen-exp.sh <id>`), then append. Ambiguous whether it is a follow-up or a NEW goal — ask the user; a new goal goes through the full gate above.
- **Not every experiment qualifies** — routine correctness-verification runs at development close stay out unless the user confirms. exp records measurements, verifications and investigations the user chose to register; plan/iteration workflows are unaffected.
- Context and discipline rules (AGENTS.md reading sequence, scripts-only indexes) follow the agentspace skill and the workspace AGENTS.md exp module.

## 2. Lifecycle (after opt-in)

1. **Design alignment first** — run the agentspace-better-exp skill (five axes) ONCE, at goal registration; its output contract fills the exp manual. Later rounds need only a delta check (what changed vs the last round, still single-variable), recorded in the run entry:
```bash
AGENTSPACE/scripts/new-exp.sh "English experiment title" [--plan NNNN] [--iteration NNNN]   # configs must land in examples/exp_spec/exp_NNNN/
AGENTSPACE/scripts/start-exp.sh <id>                     # launch todo→doing (small exps may skip); full records → exp/exp_data/exp_NNNN/
AGENTSPACE/scripts/reopen-exp.sh <id> ["reason"]         # done→doing: a closed goal takes late follow-ups by reopening, never a new exp
AGENTSPACE/scripts/complete-exp.sh <id> <done|failed|abandoned> "result" [--commit "repo@sha,..."]   # only when the GOAL is concluded
```
2. Mechanics (exp_spec contract, exp_data as the canonical full record, commits-as-points semantics) are owned by the workspace AGENTS.md exp module — follow it, never hand-edit indexes.
3. **Reports on close** — when the user wants a report or figures from the recorded data, run the agentspace-better-exp-report skill.

## 3. Division of labor

- plan = why/what, iteration = change the code, exp = measure the code; an exp needs no plan/iteration; a linked exp copies iteration data/ into exp_data.
- If the user declines recording mid-alignment — stop; the experiment proceeds unrecorded and the offer is not repeated this session.
