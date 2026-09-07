# AGENTSPACE

[中文文档](README.zh-CN.md)

A cross-platform plugin providing git-managed agent workspaces for experiment/iteration-driven projects.

All functionality ships as agent skills — every supported platform (ZCode / Codex / Kimi) loads them from `skills/`; platforms with slash commands (ZCode) additionally get thin `/agentspace-*` command wrappers that delegate to the skills. Initialize explicitly (ZCode: `/agentspace-init`; elsewhere: ask the agent to run the `agentspace-init` skill) to create `AGENTSPACE/` (independent git repo) + root `AGENTS.md` guide in your project. The agent then maintains workspace state automatically in sessions involving experiments, code changes, or project iteration, with milestone commits.

## Core Concepts

- **Plan → Iteration strict one-to-many**: a task becomes one or more plans (globally incrementing index, never reused); each iteration is a code/state change step within a plan, belonging to exactly one plan
- **Entry files are views, filesystem is source of truth**: `plan.md` keeps Todo + latest 10 Done, `iterations.md` keeps in-progress + latest 10 completed; full history in `plan/index.md`/`iterations/index.md`; all indexes written exclusively by `AGENTSPACE/scripts/`
- **Content documents authored by agent**: plan docs, iteration readmes, notes use `templates/` scaffolds
- **Experiment data saved locally, excluded from git**: `iteration_NNNN/data/` is gitignored regardless of size
- **Commit discipline for key code repos**: key repos are registered in `.agentspace-repos` (user-confirmed); every commit must first pass the `commit-check.sh` gate — bookkeeping ids and experiment artifacts never leak into code repos (see "Key Code Repos & Commit Discipline" below)

## Workspace Structure

```
<project>/
├── AGENTS.md                  # Root guide: project overview + env + key repos + when-to-read rules
├── worktrees/  .locks/        # agentspace-parallel lanes & coordination locks (created on demand; gitignored)
└── AGENTSPACE/                # Independent git repo
    ├── AGENTS.md              # Core entry: structure / module what-when-how / discipline
    ├── plan.md                # Entry: Todo + Done (latest 10)
    ├── plan/{index.md, todo/, done/}
    ├── iterations.md          # Entry: in-progress + latest completed (10)
    ├── iterations/{index.md, latest→, iteration_NNNN/{readme.md, data/}}
    ├── data.md + data/        # Shared data (training sets / model weights / symlinks; gitignored)
    ├── examples.md + examples/ # Reusable experiment configs (YAML/JSON); pairs with tests/
    ├── utils.md + utils/      # Reusable tools (plotting / machine status / log analysis...)
    ├── tests.md + tests/      # Experiment env (container/conda/GPU) + test scripts
    ├── notes.md + notes/      # Persistent knowledge (with source evidence)
    ├── register.md            # On-demand module registry (project-specific extensions)
    ├── handoff/               # One-shot session handoffs (index.md committed; handoff_*.md disposable, gitignored)
    ├── .agentspace-version.json       # Workspace version tracking
    ├── .agentspace-architecture.json  # Current architecture snapshot
    ├── .agentspace-repos              # Key code-repo registry (written only by scripts/repos.sh)
    ├── .agentspace-whitelist          # External-dependency whitelist (standalone mode)
    ├── .agentspace-parallel-workspace.txt  # Parallel-workspace coordination table (doing/test/merge + sticky notes; created on demand, gitignored)
    ├── templates/  scripts/  .gitignore
```

## Installation

Install this repository through the plugin mechanism supported by your platform and enable it — the repository ships native manifests for the supported platforms (ZCode / Codex / Kimi); installation is always performed by the user.

## Usage

### Skills (all platforms)

Skills are the functional delivery unit — they behave identically on every supported platform. Skills marked *Explicit only* trigger only when the user asks for them by name (or via the ZCode command below).

| Skill | Trigger | What it does |
| --- | --- | --- |
| `agentspace` | Automatic (guarded) | Daily workspace management in sessions involving experiments, code changes, or iteration; stays out of project-unrelated chat |
| `agentspace-init` | Explicit only | Initialize the workspace — the only entry, idempotent; analyzes the project, asks for goal / experiment env / key code repos |
| `agentspace-update` | Explicit only | Migrate the workspace to the current plugin version; conservative by default, `--force` for aggressive |
| `agentspace-doctor` | Explicit only | Deep health check: deterministic consistency, `--minor` per-file review, `--major` cross-history audit, `--fix` tiered repairs; never auto-triggered |
| `agentspace-status` | Explicit only | Status workbench: project overview + current state + soft alerts (a snapshot — never a "next steps" narrative) |
| `agentspace-mode` | Explicit only | Switch workspace mode (hybrid default / standalone); manage the external-dependency whitelist |
| `agentspace-handoff` | Explicit only | One-shot session handoffs: produce a context snapshot at session close, consume it (read, then delete) at the next session start |
| `agentspace-code-clean` | Situational — before every commit in a registered key repo | Commit gate and hygiene: staged files, ADDED code/comment lines, and the draft message must all pass `AGENTSPACE/scripts/commit-check.sh`; bookkeeping ids and experiment data never enter code repos |
| `agentspace-parallel` | Situational — when multiple plans proceed in parallel | Local PR-like parallel workspaces: one worktree lane per plan (`worktrees/<plan-id>/<repo>/`, branch `plan-<id>`) forked from a recorded mainline base; implementation and verification run inside the lane; after user confirmation a CAS squash merge lands exactly one commit on mainline; purely local — push stays user-gated. Multi-agent coordination runs through `AGENTSPACE/scripts/parallel-workspace.sh` (shared plan-state table: doing/test/merge + async sticky notes) |

### Commands (ZCode convenience)

On ZCode, each explicit skill also has a slash command that delegates to it via the command's `skills:` frontmatter. On platforms without slash commands, ask the agent directly — e.g. "run the agentspace-doctor skill with --minor".

```text
/agentspace-init                                # initialize          (skill agentspace-init)
/agentspace-update [--force]                    # migrate workspace   (skill agentspace-update)
/agentspace-doctor [--minor | --major] [--fix]  # deep health check   (skill agentspace-doctor)
/agentspace-status                              # status workbench    (skill agentspace-status)
/agentspace-mode                                # mode control        (skill agentspace-mode)
/agentspace-handoff-produce [--name <name>] [--description <text>]  # session close (skill agentspace-handoff)
/agentspace-handoff-consume [--name <name>] [--keep]                # session start (skill agentspace-handoff)
```

After initialization, the agent manages the workspace in relevant sessions:

```bash
AGENTSPACE/scripts/new-plan.sh "baseline reproduction"
AGENTSPACE/scripts/new-iteration.sh 1 "run training pipeline"
AGENTSPACE/scripts/close-iteration.sh 1 "acc=0.91, target met"
AGENTSPACE/scripts/complete-plan.sh 1 done "reproduction successful"
AGENTSPACE/scripts/status.sh          # Status summary
AGENTSPACE/scripts/doctor.sh          # Consistency check / repair
```

Plan titles must yield a compliant filename slug — lowercase english words, digits and single hyphens only (spaces become hyphens; titles with CJK, uppercase or punctuation are refused before anything is written, never consuming an id); iteration titles are free-form.

One-shot session handoffs work in any session, with or without in-progress plans: `/agentspace-handoff-produce` names the snapshot semantically — conflicts are refused, never auto-renamed. Doctor audits the module (residue consistency; staleness — unconsumed > 7 days is reported, never auto-deleted); `AGENTSPACE/scripts/status.sh` lists pending handoffs.

## Key Code Repos & Commit Discipline

Experiment projects typically have one or more key code repos alongside the workspace. AGENTSPACE keeps the code repos clean while all bookkeeping stays in the workspace:

- **Registry**: key repos are registered in `AGENTSPACE/.agentspace-repos` (one path per line; registration/removal always requires explicit user confirmation, written only by `scripts/repos.sh`)
- **Commit gate (MUST)**: before any `git commit` in a registered repo, the agent runs `AGENTSPACE/scripts/commit-check.sh <repo> "<message>"` and commits only on PASS. Blocked: bookkeeping ids (`plan:NNNN` / `iteration_NNNN` and variant spellings) in the message **and in ADDED code/comment lines**, experiment-output signatures (`events.out.tfevents.*`, top-level `wandb/` `mlruns/` `lightning_logs/`), blobs ≥ 50MB, and any `AGENTSPACE/` content leaking into the code repo. Blocked experiment output is moved into the iteration's `data/` instead of deleted
- **Commit-text quality**: the title is a one-line description of the actual change — no experiment/run identifiers, no bookkeeping narrative; attribution lives in the iteration readme (host start/end commit SHAs), never in the code repo
- **Ex-post audit**: `scripts/doctor.sh` (key-repo registry consistency, recent-commit discipline audit) plus `/agentspace-doctor` report violations — report-only; history is never rewritten automatically

## Plugin Structure

```
.zcode-plugin/plugin.json         # ZCode manifest
.codex-plugin/plugin.json         # Codex manifest
kimi.plugin.json                  # Kimi manifest
marketplace.json                  # Marketplace listing
.agents/plugins/marketplace.json    # Agents-plugin marketplace listing
icons/icon.png                    # Marketplace icon
commands/                         # ZCode slash commands (thin wrappers delegating via skills: frontmatter)
├── agentspace-init.md
├── agentspace-update.md
├── agentspace-doctor.md
├── agentspace-status.md
├── agentspace-mode.md
├── agentspace-handoff-produce.md
└── agentspace-handoff-consume.md
skills/                           # The functional unit — portable across platforms
├── agentspace/                   # Daily management (automatic, guarded)
├── agentspace-init/              # Initialization (explicit only) + init script + all template assets
├── agentspace-update/            # Update/migration (explicit only) + version archives + DEVELOPMENT.md
├── agentspace-doctor/            # Deep audit (explicit only)
├── agentspace-status/            # Status workbench (explicit only)
├── agentspace-mode/              # Mode control (explicit only)
├── agentspace-handoff/           # Session handoffs (explicit only)
├── agentspace-code-clean/        # Commit gate & hygiene for registered key repos (situational; no command wrapper)
└── agentspace-parallel/          # Local PR-like parallel workspaces (situational; no command wrapper)
tests/  self-test.sh  verify-release.sh  rehearse-update.sh  new-version.sh  push-retry.sh   # Release tooling (repo-side, not part of the plugin)
```

## Version Management

Each plugin version maintains a version archive (`CHANGELOG.md` + `architecture.json`) under `skills/agentspace-update/versions/`. The `/agentspace-update` command uses these archives to migrate workspaces with agent analysis, supporting conservative (confirm destructive changes) and aggressive modes.

See `skills/agentspace-update/DEVELOPMENT.md` for the contributor guide on adding new versions.

## Release History

| Version | Date | What changed |
| --- | --- | --- |
| v1.2.3 | 2026-09-08 | parallel-workspace.sh three fixes (audit + expert consultation): MERGELOCK stamp parsing gains a GNU `date -d` fallback (fixes the stale-merge takeover silently never firing on Linux — BSD-only `date -j -f` failed and was swallowed, so a wedged merge slot degraded to a 60s wait + manual lever every time); free-text fields ending with a backslash are refused at parse time with exit 3 (a trailing `\` fuses with the row's `\|` separator and silently merges the desc/info columns on the next read-modify-write); idempotent `--merge` now re-stamps MERGELOCK — semantic change: the 15-min stale window runs from the holder's LAST merge activity (re-entry is proof of life; the threshold detects a dead holder, it never caps a busy merge); scripts-only (handled by step 8a), no structure/AGENTS.md changes |
| v1.2.2 | 2026-09-08 | as_lock hardening (expert-review security fixes): bounded acquire wait (`AS_LOCK_TIMEOUT_SECONDS`, default 120s — a live holder outlasting it is a stuck writer; the waiter names the pid and exits non-zero, stale takeover is never capped), placeholder pid written immediately after mkdir to shrink the no-trap crash window (a lock left by that window is instantly stale-takeover-able instead of ghosting for the mtime grace), and a pid-reuse second-level mtime grace (`AS_LOCK_STALE_HOURS`, default 6h — lock mtime is the acquisition time and never refreshes during a hold, so a live pid on an old lock is a recycled pid); both constants env-pre-settable, sanitized, readonly, recorded in architecture.json; scripts-only (handled by step 8a), no structure/AGENTS.md changes |
| v1.2.1 | 2026-09-07 | new-plan slug hard-check: a plan title must yield a compliant slug (lowercase english words, digits, single hyphens); CJK / uppercase / underscore / trailing-hyphen / empty-slug titles are refused before anything is written and never consume an id — future plans only, existing plan files and index rows untouched |
| v1.2.0 | 2026-09-07 | Collaborative agent workspace: new `AGENTSPACE/scripts/parallel-workspace.sh` — shared plan-state table (doing/test/merge) + async sticky notes, one file lock + atomic writes, exclusive merge slot under the short-window iron rule with a 15-min stale-MERGELOCK takeover; data file `.agentspace-parallel-workspace.txt` (ledger-local, gitignored) + agentspace-parallel skill four enhancements: fixed worktree path MUST, mainline history-rewrite probe (never a freeze by itself), pre/post merge-back report-layer hooks, §6.5 collaboration-table registration |
| v1.1.0 | 2026-09-07 | AGENTS.md gains a user-owned User Rules section and Discipline gains two MUSTs (user-rules guardianship / comment hygiene; one-time split migration via /agentspace-update step 8b) + commit gate report-only wide-net candidates (plan/iteration word adjacent to digits, any separator — never block; the agent adjudicates each with a stated reason) + doctor --major Blocks 6/7 (notes content-quality audit with evidence chains; cross-plan conflict audit — duplication is explicitly not a finding) + code-clean batch comment review (whole-file, multi-subagent, report-only, explicit trigger only) |
| v1.0.1 | 2026-09-05 | agentspace-parallel behavior fix: change-surface intersections (file-level or semantic) never block admission — the §2 scan is now informational only, and the single blocking point is pinned to merge-back (§7h: any conflict hunk / retired-surface hit / structural absorb / retest failure freezes the merge for a user-decided handling plan, then the lane updates and retests) |
| v1.0.0 | 2026-09-05 | New skill `agentspace-parallel` — local PR-like parallel workspaces (per-plan worktree lanes, in-lane verification, CAS squash merge-back of exactly one commit per lane, purely local) + lock-before-id race fix in plan/iteration creators + doctor parallel-workspace audit coverage + status lane dedupe + change-surface section in the plan template and PR bookkeeping guidance in the iteration readme |
| v0.6.4 | 2026-09-01 | Commit gate extends the bookkeeping-id ban to ADDED diff lines (code comments / string literals; deletions never block) + doctor added-lines content audit + rubric skill renamed agentspace-commit → agentspace-code-clean (script name commit-check.sh unchanged) + release-tooling self-hosting guards (verify-release reverse constants check + realized-literal guard) |
| v0.6.3 | 2026-08-19 | Added the Kimi-compatible manifest (`kimi.plugin.json`) with triple-manifest version sync and release validation; shared skill descriptions, instructions, workspace assets, and command behavior unchanged |
| v0.6.2 | 2026-08-16 | Added the Codex-required plugin manifest and release validation while leaving shared skill descriptions, instructions, workspace assets, and command behavior unchanged |
| v0.6.1 | 2026-08-15 | Commit-text quality: gate + doctor blank-title rule (lib.sh single source) + agentspace-commit quality rubric (title = one-line description of the change; no experiment/run identifiers; title/body must match the diff) + doctor three-dimension commit audit |
| v0.6.0 | 2026-08-15 | Commit discipline: key code-repo registry (.agentspace-repos + repos.sh, user-confirmed registration) + agentspace-commit skill + commit-check.sh gate + doctor registry-consistency and ex-post-commit audits + status key-repo section + init registration step + standalone whitelist exemption |
| v0.5.3 | 2026-08-11 | status recent-activity 4-part restructure (mainline soft slot / host code commits / workspace events / ledger) + session-entry last-closed anchor + `/agentspace-status` version gate + third-party verification fixes |
| v0.5.2 | 2026-08-07 | `/agentspace-mode` command: workspace mode control (hybrid default / standalone) + external-dependency whitelist (.agentspace-whitelist, large ≥1G auto-exempt, small needs explicit user confirmation) + doctor standalone external-ref check (minor face, --fix large-only) + AGENTS.md mode block |
| v0.5.1 | 2026-08-06 | risk-audit fixes: complete-plan ENVIRON+shield, doctor guards/id-normalization/latest FIX-gate, handoff consume dual-match, update-version atomic write, python 3.6 compat, atomic index appends + regression tests + script pattern discipline + status recent-activity event stream + commit summaries |
| v0.5.0 | 2026-08-06 | status workbench: `/agentspace-status` command + skill (hard-script aggregation, strict template, subagent project paragraph) + status.sh rewrite (overview/versions/progress escape-aware/recent-10/soft-alert shape checks/handoffs) + `\|` escape-aware fixes (close-iteration index rewrite, as_row_cell) + zh-CN doc sync (example numbers, two-phase verify gate) + architecture subsections + regression tests |
| v0.4.1 | 2026-08-05 | handoff doctor audits (consistency, staleness) + status summary + cleanup batch (--list \| fix, close-iteration diff, doctor register-consistency check, --keep marker) + risk-audit fixes + bash ecosystem hardening (env gate, LC_ALL=C) + upgrade-chain GAP fixes + replay regression test |
| v0.4.0 | 2026-08-05 | handoff module (one-shot session handoffs: produce/consume) + command naming unified to `/agentspace-*` (breaking) |
| v0.3.3 | 2026-08-05 | 24h-review hardening: atomic writes completed, legacy-safe update-version anchor, `--fix` heading-drift tolerance + visible failures |
| v0.3.2 | 2026-08-05 | lesson distillation is now a MUST; update migration ledger (applied/skipped per change block) |
| v0.3.1 | 2026-08-05 | doctor link-level back-links + version metadata checks; ID union scan; update-version cwd fix; status progress overview; init self-check |
| v0.3.0 | 2026-08-04 | `/agentspace-doctor` deep health check (deterministic core + per-file review + cross-cutting audit, tiered `--fix`) |
| v0.2.12 | 2026-08-04 | notes↔iteration back-link discipline |
| v0.2.11 | 2026-08-04 | update-flow hardening (skill text) |
| v0.2.10 | 2026-08-02 | audit-fix release (5 external-audit findings) |
| v0.2.9 | 2026-08-02 | daily skill slimmed; CN skill fixed |
| v0.2.8 | 2026-08-02 | host start/end commits auto-recorded in iteration readmes |
| v0.2.7 | 2026-08-02 | knowledge distillation workflow (SHOULD); notes tag column |
| v0.2.6 | 2026-08-02 | doctor resume-block freshness + placeholder-drift checks |
| v0.2.5 | 2026-08-02 | wrap-up protocol + result-section gates + MUST rule levels |
| v0.2.4 | 2026-08-02 | v0.2.3 template regression fixed (duplicated sections) |
| v0.2.3 | 2026-08-02 | iteration redefined as a code/state change step; template → code change |
| v0.2.2 | 2026-08-02 | scripts converted to English; CJK slug truncation fixed |
| v0.2.1 | 2026-08-02 | data + examples modules |
| v0.2.0 | 2026-07-31 | skills English-primary; `/agentspace-update` changelog-driven migration |
| v0.1.0 | 2026-07-31 | initial release: plan + iteration dual mainline, entry views, scripts-only indexes |

Per-version change notes and migration guidance live in `skills/agentspace-update/versions/`.

## License

MIT
