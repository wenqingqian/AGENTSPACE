# AGENTSPACE

A ZCode plugin providing git-managed agent workspaces for experiment/iteration-driven projects.

Initialize with explicit `/init-agentspace` to create `AGENTSPACE/` (independent git repo) + root `AGENTS.md` guide in your project. The agent then maintains workspace state automatically in sessions involving experiments, code changes, or project iteration, with milestone commits.

## Core Concepts

- **Plan → Iteration strict one-to-many**: a task becomes one or more plans (globally incrementing index, never reused); each iteration belongs to exactly one plan
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
    ├── .agentspace-version.json       # Workspace version tracking
    ├── .agentspace-architecture.json  # Current architecture snapshot
    ├── templates/  scripts/  .gitignore
```

## Installation

Install this repository as a ZCode plugin (plugin marketplace or local plugin directory), then enable it.

## Usage

```text
/init-agentspace              # Explicit initialization (only entry, idempotent; analyzes workspace, asks goal/env/key repos)
/update-agentspace [--force]  # Update workspace to match plugin version (conservative by default, --force for aggressive)
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

## Plugin Structure

```
.zcode-plugin/plugin.json        # Manifest
commands/init-agentspace.md      # /init-agentspace command
commands/update-agentspace.md    # /update-agentspace command
skills/agentspace-init/          # Init skill (explicit command only) + init script + all template assets
skills/agentspace-update/        # Update skill + version archives + update scripts
skills/agentspace/               # Daily management skill (auto-triggered, with guards)
```

## Version Management

Each plugin version maintains a version archive (`CHANGELOG.md` + `architecture.json`) under `skills/agentspace-update/versions/`. The `/update-agentspace` command uses these archives to intelligently migrate workspaces with agent analysis, supporting conservative (confirm destructive changes) and aggressive modes.

See `skills/agentspace-update/DEVELOPMENT.md` for the contributor guide on adding new versions.

## License

MIT
