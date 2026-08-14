---
name: agentspace-commit
description: Commit gate for AGENTSPACE-managed key code repos. Activate BEFORE any git commit in a repository registered in AGENTSPACE/.agentspace-repos (or any git repo inside a project that has an AGENTSPACE/ workspace) — staged files and the draft message must pass AGENTSPACE/scripts/commit-check.sh first. Never commit in unregistered repos; bookkeeping ids (plan:NNNN / iteration_NNNN) and experiment data never enter code-repo commits.
---

# AGENTSPACE Commit Gate

Applies to every `git commit` in a **registered key code repo** (`AGENTSPACE/.agentspace-repos`). The AGENTSPACE ledger repo itself is EXEMPT — bookkeeping ids are its native language; never run this gate on it.

## The Gate (MUST)

Before any commit in a registered repo, in order:

1. Stage the intended files.
2. Draft the commit message.
3. Run the gate with BOTH:
   ```bash
   AGENTSPACE/scripts/commit-check.sh <repo-path> "<draft message>"
   ```
4. Exit codes:
   - **0 PASS** — commit with the EXACT message just checked (never check message A and commit message B).
   - **1 BLOCKED** — do NOT commit. Show the violation list to the user verbatim, fix, re-run the gate.
   - **2 NOT REGISTERED** — do NOT commit. Propose registration to the user; only after their explicit confirmation: `AGENTSPACE/scripts/repos.sh --add <path>`, then re-run the gate. **Never commit in an unregistered repo under the project root** — registration comes first.
   - **3 USAGE ERROR** — the gate was invoked wrong (draft message missing, or path not inside a git worktree). Re-invoke with BOTH arguments: `AGENTSPACE/scripts/commit-check.sh <repo-path> "<draft message>"`. An omitted message never silently passes — the gate fails closed.

There is no `--force` valve, and you must not emulate one (no `--no-verify`-style bypasses, no deleting rules). A blocked commit is rewritten, never forced through.

## Message Rules

The script deterministically blocks the canonical bookkeeping idioms — `plan:NNNN` / `iteration_NNNN` (the as_norm_id `%04d` zero-padded form: the leading 0 anchors the match, so natural text like "test plan: 3 phases" or "roadmap plan: 2026" passes; whole message incl. body, case-insensitive). On top of that, YOU must semantically reject anything the script cannot see:

- Variant spellings: `plan_0013`, `plan 13`, `plan-0013`, "迭代 3", "对应计划" — any reference to workspace bookkeeping in ANY form. Ids past 0999 lose the leading zero (`plan:1234`) and also land in this layer.
- Bookkeeping narrative: "完成本轮迭代", "update the workspace state" — the message describes the CODE CHANGE, nothing else.
- Context exception: a repo whose business IS agentspace (e.g. the plugin dev repo) may legitimately say "agentspace" ("feat: /agentspace-mode") — the bookkeeping ids stay banned everywhere.

Attribution never dies — it lives where it belongs: the iteration readme records host start/end commit SHAs (`> 宿主起始/结束 commit:`, auto-written by close-iteration.sh). The workspace finds commits by SHA; commits never point back.

## File Rules

Hard blocks (must never land): `AGENTSPACE/` paths (nested workspace content or gitlink) · experiment-output signatures (`events.out.tfevents.*`, top-level `wandb/` `mlruns/` `lightning_logs/`) · any single blob ≥ 50MB.

WARN (not blocking — judgment is yours, with repo context): data/model extensions ≥ 100KB (.npy/.pt/.ckpt/.h5/.parquet/.safetensors/.onnx/.log …) · top-level output dirs (`runs/ outputs/ checkpoints/ logs/ results/ exps/ experiments/`). Legitimate cases exist (small test fixtures, a logging library's `logs/` source dir) — but every WARN must be shown to the user with your judgment.

## Remediation (MUST when blocked by data)

Experiment output does not belong in code repos — move it home instead of deleting:

1. `git reset -- <path>` (unstage).
2. Move the payload into the current iteration: `mv <path> AGENTSPACE/iterations/iteration_NNNN/data/` (gitignored — the third of the three collection strategies in AGENTS.md).
3. If the program hard-codes its output dir, suggest adding that dir to the repo's `.gitignore` — writing host files requires the user's consent, always.
4. Re-run the gate.

## Boundaries

- Never install git hooks into managed repos; never write anything into them on your own initiative (the workspace stays invisible to the code repo — 无感).
- Historical violations (already committed): reported by `doctor.sh` [15] and `/agentspace-doctor` — report-only, forever. Rewriting history (rebase / filter-repo) is the user's decision and the user's action.
- Registration changes (`repos.sh --add/--remove`) require explicit user confirmation, every time.
