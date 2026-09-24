# Changelog-driven update rehearsal — v1.6.1

Date: 2026-09-24
Old ref: 92a08b3 (workspace v1.6.0)
Changelog: versions/v1.6.1/CHANGELOG.md (5 change blocks, 1 8a-covered)
8a: PASS (scripts replaced from assets, templates/.gitignore verified)
8b: PASS — agent executed the text ops in the kept sandbox per the changelog (3 edits in AGENTSPACE/AGENTS.md: exp 模块节整节替换 / 创建前确认行 / 里程碑行; root-AGENTS.md op applied to a copy of the v1.6.0 asset and verified byte-identical to the canonical asset — the sandbox carries no project-root file), then milestone-committed; doctor green; AGENTS.md byte-identical to the canonical asset (modulo HTML comments)
8c: PASS (version markers + architecture.json)
Convergence: PASS (scripts byte-identical, doctor green, status renders)
Result: PASS
