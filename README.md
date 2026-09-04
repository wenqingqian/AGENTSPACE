# AGENTSPACE

A cross-platform plugin providing git-managed agent workspaces for experiment/iteration-driven projects.

All functionality ships as agent skills — every supported platform (ZCode / Codex / Kimi) loads them from `skills/`; platforms with slash commands (ZCode) additionally get thin `/agentspace-*` command wrappers that delegate to the skills. Initialize explicitly (ZCode: `/agentspace-init`; elsewhere: ask the agent to run the `agentspace-init` skill) to create `AGENTSPACE/` (independent git repo) + root `AGENTS.md` guide in your project. The agent then maintains workspace state automatically in sessions involving experiments, code changes, or project iteration, with milestone commits.

## Core Concepts

- **Plan → Iteration strict one-to-many**: a task becomes one or more plans (globally incrementing index, never reused); each iteration is a code/state change step within a plan, belonging to exactly one plan
- **Entry files are views, filesystem is source of truth**: `plan.md`/`iterations.md` maintain only Todo + latest 10 Done; full history in `plan/index.md`/`iterations/index.md`; all indexes written exclusively by `AGENTSPACE/scripts/`
- **Content documents authored by agent**: plan docs, iteration readmes, notes use `templates/` scaffolds
- **Experiment data saved locally, excluded from git**: `iteration_NNNN/data/` is gitignored regardless of size
- **Commit discipline for key code repos**: key repos are registered in `.agentspace-repos` (user-confirmed); every commit must first pass the `commit-check.sh` gate — bookkeeping ids and experiment artifacts never leak into code repos (see "Key Code Repos & Commit Discipline" below)

## Workspace Structure

```
<project>/
├── AGENTS.md                  # Root guide: project overview + env + key repos + when-to-read rules
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
    ├── templates/  scripts/  .gitignore
```

## Installation

Install this repository through the plugin mechanism supported by your platform, then enable it. The repository includes native manifests for the supported platforms (ZCode / Codex / Kimi); installation remains a user action.

## Usage

### Skills (all platforms)

Skills are the functional delivery unit — they behave identically on every supported platform. Features marked *explicit* trigger only when the user asks for them by name (or via the ZCode command below); nothing explicit ever auto-triggers.

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

After initialization, the agent auto-manages the workspace in relevant sessions (project-unrelated chat does not interfere):

```bash
AGENTSPACE/scripts/new-plan.sh "baseline reproduction"
AGENTSPACE/scripts/new-iteration.sh 1 "run training pipeline"
AGENTSPACE/scripts/close-iteration.sh 1 "acc=0.91, target met"
AGENTSPACE/scripts/complete-plan.sh 1 done "reproduction successful"
AGENTSPACE/scripts/status.sh          # Status summary
AGENTSPACE/scripts/doctor.sh          # Consistency check / repair
```

For deeper audits — per-file content review (`--minor`), cross-cutting history audit against the host repo (`--major`), and tiered repairs (`--fix`) — run the explicit `/agentspace-doctor` command; it is never triggered automatically.

One-shot session handoffs (`/agentspace-handoff-produce` / `/agentspace-handoff-consume`): at session close, produce writes a disposable context snapshot into `AGENTSPACE/handoff/` (semantic name required — conflicts are refused, never auto-renamed); the next session consumes it (reads, then deletes). Any session can produce one, with or without in-progress plans. Doctor covers the module — [10] residue consistency (dangling rows / orphan files / duplicates) and [11] staleness (unconsumed > 7 days; reported with what the handoff is for — never auto-deleted or auto-consumed); `AGENTSPACE/scripts/status.sh` lists pending handoffs with a staleness marker.

## Key Code Repos & Commit Discipline

Experiment projects typically have one or more key code repos alongside the workspace. AGENTSPACE keeps the code repos clean while all bookkeeping stays in the workspace:

- **Registry**: key repos are registered in `AGENTSPACE/.agentspace-repos` (one path per line; registration/removal always requires explicit user confirmation, written only by `scripts/repos.sh`)
- **Commit gate (MUST)**: before any `git commit` in a registered repo, the agent runs `AGENTSPACE/scripts/commit-check.sh <repo> "<message>"` and commits only on PASS. Blocked: bookkeeping ids (`plan:NNNN` / `iteration_NNNN` and variant spellings) in the message **and in ADDED code/comment lines**, experiment-output signatures (`events.out.tfevents.*`, top-level `wandb/` `mlruns/` `lightning_logs/`), blobs ≥ 50MB, and any `AGENTSPACE/` content leaking into the code repo. Blocked experiment output is moved into the iteration's `data/` instead of deleted
- **Commit-text quality**: the title is a one-line description of the actual change — no experiment/run identifiers, no bookkeeping narrative; attribution lives in the iteration readme (host start/end commit SHAs), never in the code repo
- **Ex-post audit**: `scripts/doctor.sh` [14] (registry consistency) and [15] (recent-commit content audit), plus `/agentspace-doctor`, report violations — report-only; history is never rewritten automatically

## Plugin Structure

```
.zcode-plugin/plugin.json         # ZCode manifest
.codex-plugin/plugin.json         # Codex manifest
kimi.plugin.json                  # Kimi manifest
marketplace.json                  # Marketplace listing
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
└── agentspace-code-clean/        # Commit gate & hygiene for registered key repos (situational; no command wrapper)
```

## Version Management

Each plugin version maintains a version archive (`CHANGELOG.md` + `architecture.json`) under `skills/agentspace-update/versions/`. The `/agentspace-update` command uses these archives to intelligently migrate workspaces with agent analysis, supporting conservative (confirm destructive changes) and aggressive modes.

See `skills/agentspace-update/DEVELOPMENT.md` for the contributor guide on adding new versions.

## Release History

| Version | Date | What changed |
| --- | --- | --- |
| v0.6.4 | 2026-09-01 | Commit gate extends the bookkeeping-id ban to ADDED diff lines (code comments / string literals; same lib.sh single-source regexes and leading-zero anchor, deletions never block, rename+edit hunks scanned via -M ACMRT) + doctor [15] content audit (first hit per category: message / content / blank-title, added-lines budget) + rubric skill renamed agentspace-commit → agentspace-code-clean (script name commit-check.sh unchanged) + release-tooling self-hosting guard (verify-release [4] reverse pass + [12] realized-literal guard) |
| v0.6.3 | 2026-08-19 | Added the Kimi-compatible manifest (`kimi.plugin.json`) with triple-manifest version sync and release validation; shared skill descriptions, instructions, workspace assets, and command behavior unchanged |
| v0.6.2 | 2026-08-16 | Added the Codex-required plugin manifest and release validation while leaving shared skill descriptions, instructions, workspace assets, and command behavior unchanged |
| v0.6.1 | 2026-08-15 | commit-text quality: gate + doctor [15] blank-title rule (lib.sh single source) + agentspace-commit skill Commit-text Quality rubric (property-based standard: title = one-line description of the change, no experiment/run identifiers, no information-free titles; body explains why; title/body must relate to the actual diff via git show --stat; type prefix recommended not required) + agentspace-doctor Phase C Block 2 three-dimension audit (bookkeeping variants / quality / relevance, sha + dimension + suggestion, report-only) |
| v0.6.0 | 2026-08-15 | commit discipline: key code-repo registry (.agentspace-repos + repos.sh, user-confirmed registration) + agentspace-commit skill + commit-check.sh gate (message bookkeeping-id ban / experiment-output signatures / ≥50MB blobs / AGENTSPACE paths; exit 0/1/2) + doctor [14] registry consistency (stale rows / nested shield via git check-ignore / ls-files+gitlink leak / 7-day hot-repo warning) + [15] ex-post commit audit (recent 20, report-only) + status 关键代码仓库 section + multi-repo 代码提交 (3/repo, empty-registry host fallback) + init registration step + guidance-block gate rule + standalone whitelist exemption for registered repos |
| v0.5.3 | 2026-08-11 | status 近期动态 4-part restructure: 主线 soft slot / host-repo code commits (per-commit stat + iteration linkage via recorded host SHA + per-commit 概括 soft slot) / workspace events / ledger (separate caps) + 会话入口 最近关闭 anchor (title/date/host SHA) + `/agentspace-status` version gate (workspace-script drift warning instead of silent stale output) + third-party verification fixes (whitelist input canonicalization, soft-alert blank lines, doctor [13] small-file note) |
| v0.5.2 | 2026-08-07 | `/agentspace-mode` command: workspace mode control (hybrid default / standalone) + external-dependency whitelist (.agentspace-whitelist, large ≥1G auto-exempt, small needs explicit user confirmation) + doctor [13] standalone external-ref check (minor face, --fix large-only) + AGENTS.md mode block |
| v0.5.1 | 2026-08-06 | risk-audit fixes: complete-plan ENVIRON+shield, doctor guards/id-normalization/latest FIX-gate, handoff consume dual-match, update-version atomic write, python 3.6 compat, atomic index appends + t16 regression + script pattern discipline + status recent-activity event stream + commit summaries |
| v0.5.0 | 2026-08-06 | status workbench: `/agentspace-status` command + skill (hard-script aggregation, strict template, subagent project paragraph) + status.sh rewrite (overview/versions/progress escape-aware/recent-10/soft-alert shape checks/handoffs) + `\|` escape-aware fixes (close-iteration index rewrite, as_row_cell) + zh-CN doc sync (example numbers, two-phase verify gate) + architecture subsections + t15 regression |
| v0.4.1 | 2026-08-05 | handoff doctor audit [10]/[11] + status summary + cleanup batch (--list \| fix, close-iteration diff, doctor [12], --keep marker) + risk-audit fixes + bash ecosystem hardening (env gate, LC_ALL=C) + upgrade-chain GAP fixes + t13 replay test |
| v0.4.0 | 2026-08-05 | handoff module (one-shot session handoffs: produce/consume) + command naming unified to `/agentspace-*` (breaking) |
| v0.3.3 | 2026-08-05 | 24h-review hardening: atomic writes completed, legacy-safe update-version anchor, `--fix` heading-drift tolerance + visible failures |
| v0.3.2 | 2026-08-05 | lesson distillation is now a MUST; update migration ledger (applied/skipped per change block) |
| v0.3.1 | 2026-08-05 | doctor [8] link-level back-links + [9] version metadata; ID union scan; update-version cwd fix; status progress overview; init self-check |
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
