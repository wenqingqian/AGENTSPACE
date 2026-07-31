# AGENTSPACE v0.2.0

Upgrade from v0.1.0. Date: 2026-07-31

## Summary

- All skills now English-primary (Chinese .zh-CN.md variants for reference)
- New `/update-agentspace` command with changelog-driven intelligent migration
- Init now performs workspace analysis and asks goal/runtime/key repos before persisting
- Version tracking: `.agentspace-version.json` + `.agentspace-architecture.json` deployed with init
- Plugin dev data prohibition added to AGENTS.md discipline rules

## Changes

### [Addition] Version tracking files
- **What**: `.agentspace-version.json` and `.agentspace-architecture.json` now deployed with init into every workspace
- **Why**: enables `/update-agentspace` to detect version drift and migrate intelligently
- **Migration**: new workspaces get these automatically; existing v0.1.0 workspaces get them on first update

### [Addition] `/update-agentspace` command + agentspace-update skill
- **What**: new command and skill for changelog-driven workspace updates with conservative/aggressive modes
- **Why**: plugin evolves over time; workspaces need a way to stay in sync without manual intervention
- **Migration**: purely additive — new command available immediately after plugin update

### [Breaking] Skills now English-primary
- **What**: `agentspace-init/SKILL.md` and `agentspace/SKILL.md` rewritten in English; Chinese content moved to `.zh-CN.md` files
- **Why**: plugin documentation standardization; English as default language for ZCode plugin skills
- **Migration**: agent reads SKILL.md (English) for instructions; workspace content (templates, user-facing output) remains Chinese

### [Addition] Init workspace analysis + three questions
- **What**: init flow now includes lightweight workspace analysis (repo discovery) and proactively asks goal/runtime/key repos before persisting to AGENTS.md
- **Why**: ensures project context is captured at init time rather than left as placeholders
- **Migration**: existing workspaces unaffected; new inits get richer initial documentation

### [Schema] AGENTS.md: prohibition rule in discipline section
- **What**: new bullet in 纪律: plugin development data (versions/, DEVELOPMENT.md, marketplace.json) must not be read during project work
- **Why**: clear separation between plugin infrastructure and project data
- **Migration**: update inserts new bullet; existing user content preserved

### [Fix] .gitignore: /AGENTSPACE/ root-only pattern
- **What**: changed `AGENTSPACE/` to `/AGENTSPACE/` in plugin repo .gitignore
- **Why**: on macOS case-insensitive filesystem, `AGENTSPACE/` was matching `assets/agentspace/` directory, preventing version files from being tracked
- **Migration**: applies to plugin repo only; workspace .gitignore unaffected
