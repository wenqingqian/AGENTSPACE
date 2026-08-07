# AGENTSPACE

A ZCode plugin providing git-managed agent workspaces for experiment/iteration-driven projects.

Initialize with explicit `/agentspace-init` to create `AGENTSPACE/` (independent git repo) + root `AGENTS.md` guide in your project. The agent then maintains workspace state automatically in sessions involving experiments, code changes, or project iteration, with milestone commits.

## Core Concepts

- **Plan → Iteration strict one-to-many**: a task becomes one or more plans (globally incrementing index, never reused); each iteration is a code/state change step within a plan, belonging to exactly one plan
- **Entry files are views, filesystem is source of truth**: `plan.md`/`iterations.md` maintain only Todo + latest 10 Done; full history in `plan/index.md`/`iterations/index.md`; all indexes written exclusively by `AGENTSPACE/scripts/`
- **Content documents authored by agent**: plan docs, iteration readmes, notes use `templates/` scaffolds
- **Experiment data saved locally, excluded from git**: `iteration_NNNN/data/` is gitignored regardless of size

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
    ├── templates/  scripts/  .gitignore
```

## Installation

Install this repository as a ZCode plugin (plugin marketplace or local plugin directory), then enable it.

## Usage

```text
/agentspace-init              # Explicit initialization (only entry, idempotent; analyzes workspace, asks goal/env/key repos)
/agentspace-update [--force]  # Update workspace to match plugin version (conservative by default, --force for aggressive)
/agentspace-doctor [--minor | --major] [--fix]  # Deep health check (explicit command only, never auto-triggered)
/agentspace-handoff-produce [--name <name>] [--description <text>]  # Session close: write a one-shot context snapshot
/agentspace-handoff-consume [--name <name>] [--keep]  # Session start: read a handoff, then delete it
/agentspace-status          # Status workbench: project overview + current state + soft alerts (current-state snapshot, no next-step narrative)
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

## Plugin Structure

```
.zcode-plugin/plugin.json        # Manifest
commands/agentspace-init.md        # /agentspace-init command
commands/agentspace-update.md      # /agentspace-update command
commands/agentspace-doctor.md      # /agentspace-doctor command (deep health check)
commands/agentspace-handoff-produce.md  # /agentspace-handoff-produce command (session close)
commands/agentspace-handoff-consume.md  # /agentspace-handoff-consume command (session start)
skills/agentspace-init/          # Init skill (explicit command only) + init script + all template assets
skills/agentspace-update/        # Update skill + version archives + update scripts
skills/agentspace/               # Daily management skill (auto-triggered, with guards)
skills/agentspace-doctor/        # Deep audit skill (explicit command only, never auto-triggered)
skills/agentspace-handoff/       # Handoff skill (explicit commands only, never auto-triggered)
```

## Version Management

Each plugin version maintains a version archive (`CHANGELOG.md` + `architecture.json`) under `skills/agentspace-update/versions/`. The `/agentspace-update` command uses these archives to intelligently migrate workspaces with agent analysis, supporting conservative (confirm destructive changes) and aggressive modes.

See `skills/agentspace-update/DEVELOPMENT.md` for the contributor guide on adding new versions.

## Release History

| Version | Date | What changed |
| --- | --- | --- |
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
