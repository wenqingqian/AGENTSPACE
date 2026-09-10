---
name: agentspace-base-plan
description: Base-plan (direction anchor) trigger for AGENTSPACE workspaces — the workflow entry for creating, reviewing, activating and retiring base plans under plan/base/. A base plan is an immutable direction anchor that spans and constrains every plan, iteration and experiment derived from it (new-plan.sh --base NNNN records the lineage). Activate when the user asks to create or change a base plan, mentions anchoring a direction because plans keep drifting, or asks what a base plan says. Owns the review gate — the draft file is written, then the agent session ends so the user can comment directly on the file (never the agent-plan-mode review); activation runs only on the user's explicit approval in a later session. After activation the file is frozen (checksum pinned, doctor-audited) — if the anchor proves unimplementable or wrong, tell the user plainly; only the user changes direction (a new base plan supersedes, the old file is never edited).
---

# Base Plans (agentspace-base-plan)

> Workflow entry for base plans — creation gate, user review flow, lifecycle. Semantics and discipline live in the workspace AGENTS.md plan module; this skill is the trigger and holds the review-flow contract.

## 0. Activation guard

Check in order; if any condition fails, exit silently (handle as a normal request):
1. The user asked to create or change a base plan, to anchor a direction (e.g. many plans for one direction keep drifting), or asked what a base plan says
2. `AGENTSPACE/` directory exists in project root — if missing, state that plainly and stop (the workspace is created only via /agentspace-init)

## 1. Creation gate (MUST)

- **User-driven only** — create a base plan when the user asks for a direction anchor, never on your own initiative (you may propose once when drift is visibly hurting, with evidence; a declined proposal is not repeated).
- **Direction, not a plan of record** — a base plan describes where to go; implementation work stays in regular plans, linked via `--base NNNN`.
- English titles only (the title becomes the filename); content language is free.

## 2. Review flow (MUST — not the agent-plan-mode review)

1. `AGENTSPACE/scripts/new-base-plan.sh "English direction title"` → a 待审核 draft under plan/base/.
2. Fill the draft's 方向 / 约束 / 边界 sections (the draft is mutable until activation).
3. **Immediately end the session** — the review IS the user commenting directly on the file. Output the file path, ask the user to review it with inline comments; never self-approve, never activate in the creating session.
4. Next session: read the user's comments on the file. Revise the draft accordingly (each revision is re-submitted the same way) or, on the user's explicit approval, run `AGENTSPACE/scripts/activate-base-plan.sh <id>`.

## 3. Lifecycle

```bash
AGENTSPACE/scripts/new-base-plan.sh "English direction title"   # 待审核 draft → fill → end session for user review
AGENTSPACE/scripts/activate-base-plan.sh <id>                   # explicit user approval only; pins sha256, freezes the file
AGENTSPACE/scripts/retire-base-plan.sh <id> <replaced|voided> "reason" [--by NNNN]   # user-driven direction change only
```

Derived plans carry `new-plan.sh "title" --base NNNN` (linkage lands in the 基准 column; doctor [17] reports open plans deriving from a non-active anchor).

## 4. Immutability & direction changes (MUST)

- **Never modify an activated file under plan/base/** — the checksum pinned at activation is audited by doctor; a mismatch is corruption, not drift, and is never auto-repaired.
- **Unimplementable or wrong anchor → tell the user and stop** — the user alone decides the direction change: create a successor base plan, retire the old one as replaced/voided; the old file is never edited.
