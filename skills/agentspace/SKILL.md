---
name: agentspace
description: Work with the AGENTSPACE workspace (plans, iterations, utils, tests, notes) in projects that have one. Activate ONLY when BOTH hold — (1) an AGENTSPACE/ directory exists in the project root, AND (2) the conversation involves this project's experiments, code changes, project iteration, or state tracking. Do NOT activate for project-unrelated chat or Q&A with no state change. Never create or initialize AGENTSPACE — init happens only via the explicit /init-agentspace command.
---

# AGENTSPACE Daily Management

## 0. Activation Guard

Check in order; if any condition fails, exit silently (do not mention this skill, handle as a normal request):
1. `AGENTSPACE/` directory exists in project root
2. Current session involves this project's **experiments / code changes / project iteration / state changes** — project-unrelated sessions (Q&A, casual chat, pure queries with no state change) do not activate

Never: auto-initialize AGENTSPACE (only explicit `/init-agentspace` can do that).

## 1. Context Self-Preservation (Model Judgment, No Hook)

While working, ensure the following three files' content is in the current context; if unsure (e.g., after compact) or **before any state change**, re-read them first:
1. `AGENTSPACE/AGENTS.md` — structure, module rules, and discipline
2. `AGENTSPACE/tests.md` — experiment environment
3. `AGENTSPACE/iterations.md` — iteration status

Recovery sequence (session start / uncertain state): `AGENTS.md` → `tests.md` → `iterations.md` → `plan.md` (when task-related) → `iterations/latest/readme.md` "当前状态 · 下一步".

## 2. Workflows

### New Task → Create Plan (one task may span multiple plans)
```bash
AGENTSPACE/scripts/new-plan.sh "Plan title"        # Outputs plan:NNNN
```
Then write the generated `plan/todo/NNNN-*.md`: goal / background / plan steps. Milestone commit (see §4).

### Start an Iteration → Create Iteration (plan-id required: each iteration belongs to exactly one plan)
```bash
AGENTSPACE/scripts/new-iteration.sh <plan-id> "This iteration's content"   # Outputs iteration_NNNN
```
- Update readme: goal / change summary / environment (host commit sha)
- **Data collection — three strategies** (all output goes to `iteration_NNNN/data/`, gitignored):
  1. Program supports setting output location → point directly to `iteration_NNNN/data/`
  2. Supports redirection → `cmd > iteration_NNNN/data/xxx.log`
  3. Fallback → find output files in workspace, `mv` into `iteration_NNNN/data/`
- During work, keep readme's "当前状态 · 下一步" and "日志" (append-only) updated

### Close Iteration
After writing results in the readme's "结果" section:
```bash
AGENTSPACE/scripts/close-iteration.sh <id> "One-line result"
```
Milestone commit.

### Complete Plan
```bash
AGENTSPACE/scripts/complete-plan.sh <id> <done|failed|abandoned> "One-line result"
```
Fill the plan document's "结果" section; if there are transferable lessons → record in notes; milestone commit.

### Tools / Environment / Knowledge / Extensions
- Need a utility tool (plotting / machine status / runtime status / log analysis)? Check `utils.md` first — reuse, don't rewrite. New tools go into `utils/` and are registered in `utils.md`
- Environment change (container / conda / machine / dependency)? Update `tests.md` the same day. Test scripts go in `tests/` and are registered
- Pitfalls / transferable conclusions → `notes/` (template `templates/note.md`), **must include source** (plan:NNNN / iteration_NNNN)
- New module (e.g., examples for fixed test configs): **confirm with user first** → `AGENTSPACE/scripts/register-module.sh <name> "purpose"`

## 3. Discipline

- `plan.md` / `iterations.md` / `plan/index.md` / `iterations/index.md` **may only be modified by scripts** — always call scripts, never hand-edit tables
- Content documents (plan docs / iteration readmes / notes / utils / tests) are written directly by you, using `templates/` templates
- Cross-references always use ids: `plan:NNNN` / `iteration_NNNN`; never paths, never latest (latest flips)
- `data/` not in git (gitignored); all output saved locally
- Before ending a work session: update the in-progress iteration readme's "当前状态 · 下一步" — this is the re-entry point for the next session
- Status self-check: `AGENTSPACE/scripts/status.sh`; suspected corruption: `AGENTSPACE/scripts/doctor.sh`
- **Do not read plugin development data**: `skills/agentspace-update/versions/`, `DEVELOPMENT.md`, `marketplace.json` etc. are plugin infrastructure, unrelated to the project — never read or reference during project work

## 4. Milestone Git Commits

Triggers: plan creation/completion, iteration creation/closure, module registration, important document updates.
```bash
git -C AGENTSPACE add -A && git -C AGENTSPACE commit -m "<type>: <summary>"
```
Type examples: `plan` / `iteration` / `notes` / `utils` / `tests` / `register` / `docs`.
Report to user after commit (commit summary). **Only operate on the AGENTSPACE repo**; never add/commit the host repo. Host code state recorded via commit sha; diff (against host HEAD) saved to data/ when needed.
