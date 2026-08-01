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

**Rule levels**: `[MUST]` = violation causes damage or is irreversible — always follow; `[SHOULD]` = best practice; `[MAY]` = optional.

### New Task → Create Plan (one task may span multiple plans)

**Plan creation rules (MUST)**:
- **English titles ONLY** — plan titles become filenames; CJK characters cause encoding issues. Content inside the plan doc can be any language.
- **Confirm with user first** — never create a plan without the user's explicit approval. Describe what the plan covers and ask before proceeding.
- **Plans are for specific, bounded events** — do NOT create plans for trivial tasks like: quick confirmation, verification, searching, reading files, answering questions. Plans are for: implementing a feature, fixing a bug, refactoring code, running an experiment, making structural changes.

```bash
AGENTSPACE/scripts/new-plan.sh "English plan title"   # Outputs plan:NNNN
```
Then write the generated `plan/todo/NNNN-*.md`: goal / background / plan steps. Milestone commit (see §4).

### Start an Iteration → Create Iteration (plan-id required: each iteration belongs to exactly one plan)

**Iteration = a code/state change step within a plan** (progressive: one after another). It often carries experiment validation — hence readme + data/.

**Iteration creation rules (MUST)**:
- **Only for a plan** — iterations exist to implement a plan; never create one without a plan-id
- **Confirm with user first** — never create an iteration without the user's explicit approval
- **Only for meaningful code changes** — simple edits, quick fixes, file moves do NOT need iterations. Iterations are for: implementing a feature step, refactoring, a significant change with experiment validation
- **No 1:1 mapping to commits** — a plan often spans 1+ commits, a commit may span multiple iterations, and some commits are made by the user directly. plan/iteration/commit have NO necessary correspondence

```bash
AGENTSPACE/scripts/new-iteration.sh <plan-id> "This iteration's content"   # Outputs iteration_NNNN
```
- Update readme: goal / code-change summary / environment (host start + end commit sha)
- **Files touched**: list changed file paths in the "代码变更 (diff)" section as `- 文件: path/to/file.py` (one per line) — makes "which plan touched file Y" greppable later
- **Code diff**: when the change involves code, save the host repo diff to data/: `git -C <host> diff <start>..<end> > data/diff-<start>..<end>.patch`; register it in the "代码变更 (diff)" section
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

### Historical Search (results / which plan touched file Y)
- Small scope: `grep -rn <keyword> plan iterations notes` (exclude `data/`)
- Keywords may not match (synonyms, descriptive wording) or scope may be large: delegate to a subagent (Explore) to read the "代码变更 (diff)" / "结果" sections of readmes and summarize
- If the finding is reusable knowledge → record in notes (with source)

### Tools / Environment / Knowledge / Extensions
- Need a utility tool (plotting / machine status / runtime status / log analysis)? Check `utils.md` first — reuse, don't rewrite. New tools go into `utils/` and are registered in `utils.md`
- Shared data (training sets, model weights, symlinks)? Put in `data/` and register in `data.md`; entire data/ is gitignored
- Reusable experiment configs (YAML/JSON)? Put in `examples/` and register in `examples.md`; test scripts in `tests/` reference these configs
- Environment change (container / conda / machine / dependency)? Update `tests.md` the same day. Test scripts go in `tests/` and are registered
- Pitfalls / transferable conclusions → `notes/` (template `templates/note.md`), **must include source** (plan:NNNN / iteration_NNNN)
- New module (not built-in): **confirm with user first** → `AGENTSPACE/scripts/register-module.sh <name> "purpose"`

## 3. Discipline

- `plan.md` / `iterations.md` / `plan/index.md` / `iterations/index.md` **may only be modified by scripts** — always call scripts, never hand-edit tables
- Content documents (plan docs / iteration readmes / notes / utils / tests) are written directly by you, using `templates/` templates
- Cross-references always use ids: `plan:NNNN` / `iteration_NNNN`; never paths, never latest (latest flips)
- `data/` not in git (gitignored); all output saved locally
- **[MUST] Wrap-up protocol** — before ending any project work session, in order: ① update the in-progress iteration readme's "当前状态 · 下一步" (the re-entry point for the next session — replace the template guidance comment with real content) ② run `AGENTSPACE/scripts/doctor.sh` (hard errors must be resolved; warnings must be reported to the user) ③ milestone commit (§4)
- **[MUST] On script errors** (e.g., "Section not found"): do NOT hand-edit tables. Run `doctor.sh` to locate the issue, then discuss a repair plan with the user. **A one-time manual fix explicitly confirmed by the user is the only allowed exception** to the scripts-only rule. This applies to plan.md / iterations.md / plan/index.md / iterations/index.md / register.md and any content documents
- **[MUST] Scripts-only** — `plan.md` / `iterations.md` / `plan/index.md` / `iterations/index.md` may only be modified by scripts; never hand-edit tables (except the user-confirmed exception above)
- Status self-check: `AGENTSPACE/scripts/status.sh`; run `AGENTSPACE/scripts/doctor.sh` after wrap-up and whenever you suspect corruption
- **Do not read plugin development data**: `skills/agentspace-update/versions/`, `DEVELOPMENT.md`, `marketplace.json` etc. are plugin infrastructure, unrelated to the project — never read or reference during project work

## 4. Milestone Git Commits

Triggers (specific): plan created/completed · iteration created/closed · module registered · notes written · tests.md environment changed · examples/data entries registered · update applied · scripts/templates updated.
```bash
git -C AGENTSPACE add -A && git -C AGENTSPACE commit -m "<type>: <summary>"
```
Type examples: `plan` / `iteration` / `notes` / `data` / `examples` / `utils` / `tests` / `register` / `docs`.
Report to user after commit (commit summary). **Only operate on the AGENTSPACE repo**; never add/commit the host repo. Host code state recorded via commit sha; diff (against host HEAD) saved to data/ when needed.
