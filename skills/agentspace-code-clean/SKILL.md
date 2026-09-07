---
name: agentspace-code-clean
description: Commit gate and code/comment hygiene for AGENTSPACE-managed key code repos. Activate BEFORE any git commit in a repository registered in AGENTSPACE/.agentspace-repos (or any git repo inside a project that has an AGENTSPACE/ workspace) — staged files, ADDED code/comment lines, and the draft message must all pass AGENTSPACE/scripts/commit-check.sh first. Never commit in unregistered repos; bookkeeping ids (plan:NNNN / iteration_NNNN) and experiment data never enter code-repo commits — not in the message, not in code or comments; the commit text must describe the actual code change (one-line title, no experiment/run identifiers, related to the diff). The gate also prints report-only wide-net candidates (plan/iteration word adjacent to digits, any separator — `plan-12`, `plan_12`, `plan 13`) — they never block; the agent must adjudicate every candidate explicitly and state the verdict with a reason. A batch comment review (whole-file, multi-subagent, report-only) over the files this session's commits touched exists — it runs ONLY on the user's explicit request, never automatically.
---

# AGENTSPACE Code-Clean Commit Gate

Applies to every `git commit` in a **registered key code repo** (`AGENTSPACE/.agentspace-repos`). The AGENTSPACE ledger repo itself is EXEMPT — bookkeeping ids are its native language; never run this gate on it. (Renamed from agentspace-commit in v0.6.4 when the gate's scope grew from the commit message to the committed content; the script name `commit-check.sh` is unchanged.)

## The Gate (MUST)

Before any commit in a registered repo, in order:

1. Stage the intended files.
2. Draft the commit message.
3. Run the gate with BOTH:
   ```bash
   AGENTSPACE/scripts/commit-check.sh <repo-path> "<draft message>"
   ```
4. Exit codes:
   - **0 PASS** — commit with the EXACT message just checked (never check message A and commit message B). A **CANDIDATES** list may ride along (report-only): it is never a reason to block or delay — adjudicate every candidate explicitly and state the verdict (a release needs a stated reason). The verdict is yours to declare; the script only nets the shapes.
   - **1 BLOCKED** — do NOT commit. Show the violation list to the user verbatim, fix, re-run the gate. The CANDIDATES list may be printed alongside the blocks (for full attribution) — candidates alone never block.
   - **2 NOT REGISTERED** — do NOT commit. Propose registration to the user; only after their explicit confirmation: `AGENTSPACE/scripts/repos.sh --add <path>`, then re-run the gate. **Never commit in an unregistered repo under the project root** — registration comes first.
   - **3 USAGE ERROR** — the gate was invoked wrong (draft message missing, or path not inside a git worktree). Re-invoke with BOTH arguments: `AGENTSPACE/scripts/commit-check.sh <repo-path> "<draft message>"`. An omitted message never silently passes — the gate fails closed.

There is no `--force` valve, and you must not emulate one (no `--no-verify`-style bypasses, no deleting rules). A blocked commit is rewritten, never forced through.

## Message Rules

The script deterministically blocks the canonical bookkeeping idioms — `plan:NNNN` / `iteration_NNNN` (the as_norm_id `%04d` zero-padded form: the leading 0 anchors the match, so natural text like "test plan: 3 phases" or "roadmap plan: 2026" passes; whole message incl. body, case-insensitive). On top of that, YOU must semantically reject anything the script cannot see:

- Variant spellings: `plan_0013`, `plan 13`, `plan-0013`, "迭代 3", "对应计划" — any reference to workspace bookkeeping in ANY form. Ids past 0999 lose the leading zero (`plan:1234`) and also land in this layer.
- Bookkeeping narrative: "完成本轮迭代", "update the workspace state" — the message describes the CODE CHANGE, nothing else.
- Context exception: a repo whose business IS agentspace (e.g. the plugin dev repo) may legitimately say "agentspace" ("feat: /agentspace-mode") — the bookkeeping ids stay banned everywhere.

Attribution never dies — it lives where it belongs: the iteration readme records host start/end commit SHAs (`> 宿主起始/结束 commit:`, auto-written by close-iteration.sh). The workspace finds commits by SHA; commits never point back.

## Code & Comment Rules (added lines — deterministic + semantic)

The same idioms are banned in what the commit ADDS — code comments, string literals, any text line (v0.6.4). The script scans ADDED diff lines (renames count only for their edited hunks; case-insensitive; reported as `file:line` + excerpt; at most 5 hits listed per file, then a `+N more` tail). Deletions never block — removing an old leak always passes; binary files and pure renames carry no added lines. On top of that, YOU must semantically reject in added lines:

- Variant spellings in code/comments: `plan_0013`, `plan 13`, "迭代 3" — any workspace-bookkeeping reference in ANY form.
- Bookkeeping narrative in comments ("本轮迭代新增…", "updated per workspace state") — a comment describes the CODE, nothing else.
- Run/experiment identifiers in comments (`# 6-run on .42`) — they belong in the iteration readme / `data/`.
- Diff-shaped content — lines starting `++ `/`-- ` (pasted diffs, xtrace logs) — describe the change, never paste workspace diffs.
- Known-legit shapes that still match (YAML `plan: 0NNN` keys, `iteration_0NNN.pt` file names): rename the key/constant to describe its role — attribution belongs in the iteration readme, and CJK/full-width variants (`：`, `０００１`) are YOUR layer, the script only sees ASCII.
- Process-narrative comments (WARN candidates — YOU adjudicate, never a hard block): comments narrating the editing session rather than the code — (a) date narration, "when it was written" (`# 2026-09-07 修改`, `// added on 2026-09-07`); (b) tool/skill provenance, "what it was based on" (`# based on X skill`). Non-process date uses that state a fact about the code are legitimate and pass (`# since 2026-01: API v2`) — that call is yours: give a verdict per candidate, with the reason, out loud to the user.

Content that must legitimately reference canonical ids (tooling that generates workspace references, fixture snapshots) belongs in `AGENTSPACE/utils/` or the iteration's `data/` — never in the code repo.

## Commit-text Quality (semantic — your judgment, two questions)

Beyond bookkeeping, judge every draft commit text against two questions (title = first line; body optional). Both are YOUR judgment — the script only catches a blank title.

1. **Is the title a one-line description of the code change?** It must answer "what did this commit do" on its own:
   - Good: `add retry to driver launch` / `fix: parse NaN in metrics` — a verb phrase naming the change.
   - Reject: information-free titles (`driver`, `stuff`, `update`); experiment/run identifiers — `(6-run driver launch on .42)` is an experiment-run name (run number, machine address, config tag) and reads like a log line, not a commit. Those details belong in the iteration readme / `data/`, never in the commit.
   - Body, if present, explains WHY (motivation, trade-offs) — not what (the diff already says what). Same ban list as the title: no bookkeeping, no run metadata.
   - Keep the title ≤ 72 chars for readability — a soft guideline, not a gate.

2. **Does the title/body relate to the actual diff?** Read `git show --stat` (staged: `git diff --cached --stat`) BEFORE judging. The theme the title names must land in the changed files/content. A title about "driver launch" over a diff that only touches data cleaning is an experiment name wearing a commit costume — reject it and propose a rewrite describing the real change (`fix: retry driver launcher against .42` keeps the technical point, drops the run bookkeeping).

Action: on any violation, require the title/body rewrite before the commit proceeds (code untouched), then re-run the gate with the exact new message. If the user insists on the original text, honor the call but say it out loud: doctor [15] and `/agentspace-doctor` will report the commit while it is inside the audit window — report-only, but visible.

## File Rules

Hard blocks (must never land): `AGENTSPACE/` paths (nested workspace content or gitlink) · experiment-output signatures (`events.out.tfevents.*`, top-level `wandb/` `mlruns/` `lightning_logs/`) · any single blob ≥ 50MB. Renames are detected (`-M`): a file renamed into a blocked path (e.g. top-level `wandb/`) is blocked under its new name.

WARN (not blocking — judgment is yours, with repo context): data/model extensions ≥ 100KB (.npy/.pt/.ckpt/.h5/.parquet/.safetensors/.onnx/.log …) · top-level output dirs (`runs/ outputs/ checkpoints/ logs/ results/ exps/ experiments/`). Legitimate cases exist (small test fixtures, a logging library's `logs/` source dir) — but every WARN must be shown to the user with your judgment.

## Remediation (MUST when blocked)

- **Content violations** (added lines): rewrite the comment/code line so it describes the change itself — attribution lives in the iteration readme host SHAs, never in the code. Restage and re-run the gate. Never obfuscate an id to slip it past the regex — that is a leak wearing a mask.
- **Data violations**: experiment output does not belong in code repos — move it home instead of deleting:
  1. `git reset -- <path>` (unstage).
  2. Move the payload into the current iteration: `mv <path> AGENTSPACE/iterations/iteration_NNNN/data/` (gitignored — the third of the three collection strategies in AGENTS.md).
  3. If the program hard-codes its output dir, suggest adding that dir to the repo's `.gitignore` — writing host files requires the user's consent, always.
  4. Re-run the gate.

## Batch Comment Review (explicit trigger only — report-only)

A deep review mode, separate from the per-commit gate. It runs ONLY when the user explicitly asks for it (e.g. "对本轮改动做一次批量注释审查") — never automatically, never as a side effect of the gate, and never as a whole-repo sweep.

- **Scope (iron rule):** only the files touched by THIS session's commits, or the exact commit range the user explicitly gives (`git diff --name-only <base>..<head>` over that range). Never widen it to the rest of the repository on your own initiative — no automatic whole-repo scan, ever.
- **Whole-file comments:** each in-scope file is reviewed in FULL — every comment in the file, not just lines added this round — so stock narration the added-line gate cannot see (old date stamps, old provenance notes) is caught too.
- **Multi-subagent:** partition the in-scope files across parallel subagents. Each subagent reads its assigned files and returns findings only (file:line · excerpt · which dimension · suggested direction) — it never edits. Findings aggregate to you, and you present one consolidated report to the user.
- **Dimensions:** everything the semantic layer polices in added lines (bookkeeping references in any spelling, run/experiment identifiers, diff-shaped pastes) plus the process-narrative dimensions (date narration, tool/skill provenance) — evaluated across the whole file, stock comments included.
- **Report-only:** the report ends the mode. Fixing is a SEPARATE, user-driven commit — propose the fix batch and wait for the user's go-ahead; never fold fixes into an in-flight commit unasked.

## Boundaries

- Never install git hooks into managed repos; never write anything into them on your own initiative (the workspace stays invisible to the code repo — 无感).
- Historical violations (already committed), message or content: reported by `doctor.sh` [15] (content: added lines of recent commits, first hit per category — message / content / blank-title) and `/agentspace-doctor` — report-only, forever. Rewriting history (rebase / filter-repo) is the user's decision and the user's action.
- Registration changes (`repos.sh --add/--remove`) require explicit user confirmation, every time.
