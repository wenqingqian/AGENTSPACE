---
name: agentspace-code-clean
description: Two-level code, comment, and commit hygiene for AGENTSPACE-managed key code repos. Level 1 (passive, default) — code, comments, and commit text written in a repo registered in AGENTSPACE/.agentspace-repos (or any git repo in a project with an AGENTSPACE/ workspace) follow the rules in this skill, gated before every commit by AGENTSPACE/scripts/commit-check.sh; read this file in full before writing or reviewing — it is the single source of the rules. Level 2 (active, explicit-only) — when the user explicitly asks to clean up past code/comments, run style checks, or rewrite commit messages, read CLEANUP.md in this skill directory and follow it; never auto-triggered.
---

# AGENTSPACE Code-Clean

**Two levels, one entry.** Level 1 (passive, default) — the graded rules below govern every round of code, comments, and commit text you write or review in an AGENTSPACE-managed repo; they load by default, so apply them as you write. Level 2 (active, explicit-only) — post-processing of PAST code over any range lives in a separate procedure document: **if the user explicitly asks to clean up existing code or comments, run style checks, or rewrite existing commit messages, read CLEANUP.md in this skill directory and follow it.** The active level never auto-triggers, and you never widen its scope on your own initiative.

Scope: every git repo registered in `AGENTSPACE/.agentspace-repos`, and any git repo inside a project that has an AGENTSPACE/ workspace. The AGENTSPACE ledger repo itself is EXEMPT — bookkeeping ids are its native language; never run this gate on it. (Named agentspace-commit before v0.6.4, when the gate grew from the message to the committed content; the script `commit-check.sh` is unchanged.)

## The Commit Gate (MUST)

Before any commit in a registered repo, in order: stage the intended files, draft the message, then run the gate with BOTH arguments — `AGENTSPACE/scripts/commit-check.sh <repo-path> "<draft message>"` — and commit with the EXACT message just checked (never check A and commit B).

- **0 PASS** — commit. A CANDIDATES list may ride along (report-only wide-net candidates the script nets beyond the canonical ids): candidates never block and never delay; adjudicate every candidate explicitly and state the verdict with a reason, out loud. The verdict is yours to declare; the script only nets the shapes.
- **1 BLOCKED** — do NOT commit. Show the violation list verbatim, fix, re-run the gate.
- **2 NOT REGISTERED** — do NOT commit. Propose registration; only after explicit user confirmation run `AGENTSPACE/scripts/repos.sh --add <path>`, then re-run. Never commit in an unregistered repo under the project root — registration comes first.
- **3 USAGE ERROR** — the gate was invoked wrong (missing message, or path outside a git worktree). Re-invoke with both arguments; an omitted message never silently passes — the gate fails closed.

There is no `--force` valve and you must not emulate one (no `--no-verify`-style bypasses, no deleting rules). A blocked commit is rewritten, never forced through.

## Commit-Text Rules

The script deterministically blocks canonical bookkeeping ids and blank titles; everything else here is your judgment (title = first line; body optional).

- **MUST be bookkeeping-free.** Beyond the script's canonical `plan:NNNN` / `iteration_NNNN` / `exp_NNNN` bans, reject every variant it cannot see — `plan_0013`, `plan 13`, `plan-0013`, "迭代 3", "对应计划", ids past 0999 that lose the leading zero — and bookkeeping narrative ("完成本轮迭代", "update the workspace state"). The message describes the CODE CHANGE, nothing else. Context exception: a repo whose business IS agentspace may legitimately say "agentspace" ("feat: /agentspace-mode"); the bookkeeping ids stay banned everywhere. Attribution never dies — it lives in the iteration readme host SHAs; the workspace finds commits by SHA, commits never point back.
- **MUST be run-free and diff-grounded.** No experiment/run identifiers — `(6-run driver launch on .42)` is a run name (run number, machine address, config tag) reading like a log line; those belong in the iteration readme / `data/`. Read `git show --stat` (staged: `git diff --cached --stat`) BEFORE judging: the theme the title names must land in the changed files — a title about "driver launch" over a diff that only touches data cleaning is an experiment name wearing a commit costume; reject and propose a rewrite describing the real change.
- **MUST apply the Comment Rules below to commit text too.** Every line of the title and body is judged by the Comment Rules further down — feedback residue, context-missing references, redundant restatement, test-instance citations, process narration, machine fingerprints, and secrets are the same offenses in a commit message as in a code comment; the body is not a side door around them. Carve-out: a commit IS the description of a change — delta statements ("X renamed to Y, update callers"), before/after numbers, and migration facts are legitimate because the diff they ship with is present context; what stays banned is narrating the review process ("per review discussion", "as requested").
- **SHOULD title format.** `<type>: <summary>`, or `<type>(<scope>): <summary>` when the repo's log uses scopes; types follow the repo's own vocabulary (feat fix refactor docs test chore perf build ci style). Imperative mood ("add", not "added"), lowercase summary, no trailing period; summary ≤ 50 chars soft target, 72 hard limit; no issue numbers in the title — references go to the body footer. Reject information-free titles (`driver`, `stuff`, `update`).
- **SHOULD be one coherent purpose.** A tightly coupled change set (the feature plus its tests and docs) is one commit; split only unrelated changes. "and" in the title is fine when the parts serve one purpose; it signals a split when they do not.
- **SHOULD earn the body.** Most commits ship title-only. Write a body only when the why is not inferable from title plus diff, or it carries reviewer-relevant facts (trade-offs, compat/migration notes, perf numbers, known limits). Blank line after the title, wrap at 72; why before what (the diff already says what); behavior, not a file-by-file tour; concrete beats vague ("cuts cold start from 340ms to 120ms", not "improves performance"); no filler (no "this commit", no restating the title).

On any violation: rewrite the text (code untouched), re-run the gate with the exact new message. If the user insists on the original, honor the call but say it out loud — doctor [15] will report the commit inside its audit window; report-only, but visible.

## Comment Rules

The bookkeeping/run bans apply equally to what the commit ADDS — code comments, string literals, any text line (the script scans added diff lines; renames count only for edited hunks; deletions never block; at most 5 hits listed per file). On top, every comment you write or touch obeys:

- **MUST make every comment self-contained in the current code — no feedback-driven, no context-missing comments.** Write each comment as if composed specifically for the code as it stands after this change; the code as it was before the change is missing context, and a comment that depends on it is residue. The canonical residue: explaining why the code is not written some other way — "why not alternative X" answers a past review question no future reader shares. Same family: "no longer does X", "changed from Y to Z", comments narrating this round's diff for the reviewer. Boundary: a "why not" citing a concrete failure mode of this code ("a wider group would elementwise all-reduce different vocab shards — silent embedding-gradient corruption") is a design note, keep it; a bare alternative-comparison ("not a load-balancing choice") is feedback residue, delete it.
- **MUST delete redundant restatement.** Comments that restate the code or a sibling docstring verbatim go — what the code already says clearly is not said twice.
- **MUST trim over-explanation.** Over-explained prose collapses to the core what/why — drop defensive hedges and repeated clauses; multi-paragraph docstrings usually collapse to 1–2 sentences. Docstrings follow the same rule, except: keep a one-line purpose statement on public functions/classes so the API stays readable.
- **MUST keep what earns its place.** Non-obvious what/why, interface contracts, section dividers, and license headers (always keep) are not casualties of cleanup; fix only factual errors or non-local assumptions — no style rewriting under hygiene's name.
- **MUST NOT cite test instances.** Comments quoting concrete test instances (model names, hyper-parameters, parallel layouts, datasets) carry no code semantics and go stale — delete. If the code genuinely only works under a specific config, express the restriction with an `assert` (executes, fails loudly, cannot rot) plus at most one short comment pointing at it; a comment that merely claims a restriction is unenforced and stale. Teaching examples differ: keep them, written relatively ("TP member 0/1"), never framed as "under config X".
- **MUST describe the code, not the session.** No bookkeeping narrative in comments ("本轮迭代新增…", "updated per workspace state"); no diff-shaped pastes (lines starting `++ `/`-- `); no run/experiment identifiers (`# 6-run on .42`). Known-legit shapes that still match the script (YAML `plan: 0NNN` keys, `iteration_0NNN.pt` names): rename the key/constant to describe its role. CJK/full-width variants (`：`, `０００１`) are your layer — the script only sees ASCII. Content that must legitimately reference canonical ids (tooling, fixture snapshots) belongs in `AGENTSPACE/utils/` or the iteration's `data/`.
- **MUST stay process-free.** Comments narrating the editing session rather than the code are banned outright: date narration ("# 2026-09-07 修改", "// added on 2026-09-07") and tool/skill provenance ("# based on X skill") never get written, and existing ones are cleaned out on touch. Non-process dates stating a fact about the code remain fine ("# since 2026-01: API v2"). The script does not net these shapes — you are the enforcement layer.
- **MUST carry no machine fingerprints or secrets.** No IP addresses, hostnames, intranet topology, machine-bound endpoints (host:port), or username/home-dir paths in comments — machine-bound information turns to noise the moment the code moves environments; no tokens, keys, or passwords. When a slot must be referenced, use a readable placeholder name (`<endpoint>`, not `10.1.2.3:8000`).

## Code and File Rules

- **SHOULD keep imports at module top level.** Legitimate exceptions exist (conditional `if TYPE_CHECKING:` imports, forced-late imports in scripts) — say so when they are.
- **MUST hard file blocks** (never land): `AGENTSPACE/` paths (nested workspace content or gitlink) · experiment-output signatures (`events.out.tfevents.*`, top-level `wandb/` `mlruns/` `lightning_logs/`) · any single blob ≥ 50MB. Renames are detected (`-M`): a file renamed into a blocked path blocks under its new name.
- **WARN — your judgment, with repo context, shown to the user**: data/model extensions ≥ 100KB (.npy/.pt/.ckpt/.h5/.parquet/.safetensors/.onnx/.log …) · top-level output dirs (`runs/ outputs/ checkpoints/ logs/ results/ exps/ experiments/`). Legitimate cases exist (small test fixtures, a logging library's `logs/` source dir); every WARN is shown with your judgment.

## When Blocked

- **Content violations (added lines):** rewrite the comment/code line so it describes the change itself — attribution lives in the iteration readme host SHAs, never in the code. Restage, re-run the gate. Never obfuscate an id to slip it past the regex — that is a leak wearing a mask.
- **Data violations:** experiment output moves home, it is not deleted — `git reset -- <path>` (unstage) → `mv <path> AGENTSPACE/iterations/iteration_NNNN/data/` (gitignored) → for hard-coded output dirs, suggest a `.gitignore` line (host files need user consent, always) → re-run the gate.

## Batch Comment Review (explicit trigger only)

A deep whole-file review mode, separate from the per-commit gate: scope = this session's commit-touched files or the exact commit range the user gives; report-only. It runs ONLY on the user's explicit request — never automatically, never as a side effect of the gate, never widened to a whole-repo sweep on your own initiative. The full procedure (scope iron rule, multi-subagent partition, dimensions, consolidated report) lives in CLEANUP.md — read it before running this mode.

## Boundaries

- Never install git hooks into managed repos; never write anything into them on your own initiative (the workspace stays invisible to the code repo — 无感).
- Historical violations (already committed), message or content, are reported by `doctor.sh` [15] and `/agentspace-doctor` — report-only, forever. Rewriting published history is the user's decision; when the user explicitly asks for it, follow the history-rebuild safety protocol in CLEANUP.md (backup first, unpushed-or-acknowledged rules, post-verify).
- Registration changes (`repos.sh --add/--remove`) require explicit user confirmation, every time.
