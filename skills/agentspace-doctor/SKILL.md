---
name: agentspace-doctor
description: Deep health check of an existing AGENTSPACE workspace — deterministic consistency, per-file content review, cross-cutting history audit, tiered repairs. Triggered ONLY by the explicit /agentspace-doctor command (--minor | --major [--fix]). Never trigger automatically, and never use it as a substitute for the cheap AGENTSPACE/scripts/doctor.sh gate in the wrap-up protocol.
---

# AGENTSPACE Doctor Command

Audit an existing AGENTSPACE workspace: deterministic consistency (doctor.sh), per-file content review, and — in major mode — a cross-cutting audit of the whole workspace history against the host repo. Read-only by default; `--fix` enables tiered repairs.

## 0. Trigger Guard

Proceed ONLY when the user explicitly executes `/agentspace-doctor`. Never trigger automatically, never run as part of wrap-up (the cheap `AGENTSPACE/scripts/doctor.sh` gate stays there), and never run against a project that has no AGENTSPACE workspace (state that plainly and stop).

## 1. Flags and Modes

- `--minor` (default when no flag is given): structure + per-file content review (Phase A + B)
- `--major`: everything in minor, plus the cross-cutting audit (Phase C); minor ⊂ major. MUST run as the session's sole main task — never in a session that also carries code changes, experiments, or other ledger work; if the current session has work in progress, first suggest running `--major` in a fresh session and continue only after the user explicitly insists. `--minor` is unaffected (still fine to run at session wrap-up)
- `--fix`: enable repairs — tier-1 script auto-fixes plus tier-2 confirmed semantic fixes (§5); composes with either mode
- Unknown flags: say so and ask the user; never guess
- No `--force` valve exists and none is provided — the MUST constraints of this skill (report-only audit findings, plan-document immutability, `--major` as a standalone session) have no override flag

## 2. Phase A — Deterministic Core

Run `AGENTSPACE/scripts/doctor.sh [--fix]` first. Its output is the baseline:
- exit 0 → deterministic layer green; exit 1 → red items listed
- Report every deterministic finding verbatim with the [script] source label — do not re-litigate or paraphrase script output. doctor.sh issues are 红 (hard errors) — never downgrade them to 黄
- Do not skip this phase in major mode; major layers build on top of it

## 3. Phase B — Minor: Per-File Content Review

**Review scope — read fully**:
- Management tables: `plan.md`, `iterations.md`, `exp.md`, `notes.md`, `data.md`, `register.md`
- Entries: `plan/todo/*.md`, `plan/done/*.md`, `iterations/iteration_NNNN/readme.md`, `exp/todo/*.md`, `exp/doing/*.md`, `exp/done/*.md`, `notes/*.md`, `examples/*.md`, `templates/*.md`
- Handoffs: `handoff/index.md` + `handoff/handoff_*.md` — read fully (the session-resume entry; the files are gitignored, so git status will not surface them)
- If a scoped file is absent (e.g. `data.md`/`examples.md` in workspaces predating those modules): note the absence as a 蓝 observation — do not escalate to 红/黄
- Host root `AGENTS.md` — the AGENTSPACE section: internal consistency only (rules and hard rules present and non-contradictory, structure block matches the workspace layout). Do NOT diff against plugin-side templates — plugin dev data is off-limits in user projects
- `utils/`, `tests/` — existence/structure correspondence with their entry tables only (e.g. `utils.md` ↔ `utils/`); `scripts/` — correspondence with the architecture contract (`AGENTS.md` structure block + `.agentspace-architecture.json`), since `scripts/` has no entry table; do NOT prose-review scripts
- `.agentspace-repos` / `.agentspace-whitelist` — script-managed config files (repos.sh / mode.sh only); never prose-review, never hand-edit. Their consistency is doctor.sh [13]/[14]'s job
- `data/` payload: never read
- Plugin dev data (`skills/agentspace-update/versions/`, `DEVELOPMENT.md`, `marketplace.json` etc.): never read (user projects)

**Judgment criterion — 状态断言 vs 历史记录** (current-state assertions vs historical records):
- 矛盾 (contradiction): two places in the same system claim conflicting current states → **红**
- Current-state assertion contradicted by reality (version marker, index, script behavior) → **红/黄** (红 when clearly provable, 黄 when judgment-based). In minor, "reality" = workspace-internal state (tables, indexes, version markers, script outputs) plus directly observable host facts (file presence, git status); deep host code/git verification belongs to Phase C (major)
- Historical records (closed iterations, completed features, reverted attempts, old-version behavior): **never an issue**; only flag when they mislead without context, and suggest adding context (**黄**)
- Handoff snapshots are historical records by nature, but one whose 引用 / 下一步 no longer matches current state (referenced plan completed, 下一步 already done, resume block superseded by `iterations/latest`) misleads a resuming session → **黄**, with a concrete suggestion: consume it now (read → delete via `/agentspace-handoff-consume`), delete it, or re-produce a fresh snapshot. Never auto-delete or auto-consume — reading the snapshot before consuming is the module contract
- Filler / no-information placeholders → **黄**
- Optimization opportunities (dedup, distillation gaps, missing context) → **蓝** (suggestions only)

Every finding carries a source label — `[script]` (from doctor.sh) or `[agent]` (your judgment) — plus file path and evidence.

## 4. Phase C — Major: Cross-Cutting Audit

Everything in Phase A + B, plus dispatch **parallel subagents** (one per block — the main agent does not do block work itself), then synthesize their reports. If the session has no subagent tooling, run the blocks serially and note the deviation in the report. Subagent instructions MUST include: read-only (never modify the workspace), never read plugin dev data in user projects, report findings with file:line evidence, return a structured list.

- **Block 1 — 宿主代码+git 成果核对**: verify outcome claims in iterations/notes and handoff 下一步 items ("implemented / fixed / landed / 重试 push" etc.) against the host code and git log
- **Block 2 — 工作区 git 审计**: workspace repo commit hygiene (milestone-shaped, not fragmented), host start/end commits recorded at close-iteration exist and are on the right branch, pre-update tags sane, `.agentspace-version.json` lastUpdatedAt not stale; PLUS semantic review of recent commit messages (最近 20 条 commit message, 与 doctor [15] 同窗口) in the registered key repos (`.agentspace-repos`), three dimensions per the agentspace-code-clean rubric: (a) bookkeeping variants the regexes cannot see — `plan_0013`, "迭代 3", bookkeeping narrative in any language form; (b) commit-text quality — title is a one-line description of the actual change (no experiment/run identifiers like `(6-run driver launch on .42)`, no machine addresses, no information-free titles); (c) relevance — title/body themes land in the actual diff (check `git show --stat`). Report each violation as: sha + dimension + concrete suggestion (e.g. a proposed rewritten title). Report-only.
- **Block 3 — 全历史纪律审计**: full-history discipline trace across ALL closed plans/iterations/notes — 回链 completeness, `plan:NNNN` / `iteration_NNNN` reference validity, notes 来源, index consistency
- **Block 4 — 版本元数据断言核对**: version/metadata claims in notes/AGENTS.md/readmes vs `.agentspace-version.json` and actual script behavior
- **Block 5 — 环境/脚本调用链 dry-run**: for `scripts/`, `utils/`, `tests/` — trace the call chain (source relations, dependencies, template references), judge whether each script can run and whether its intent matches what tests.md / plan / iterations claim; do NOT execute anything
- **Block 6 — notes 内容质量审核**: scope = the `notes.md` index plus every `notes/*.md` file. Two judgment categories: **outdated** (superseded by facts the workspace has since updated) and **wrong** (falsified by evidence). Method: note-vs-note cross-review plus notes × plan × commit × iteration cross-validation (evidence-chain checks). Each finding reports: note identifier, judgment category, evidence chain (`plan:NNNN` / `iteration_NNNN` / host commit), and a suggested action (delete / rewrite / keep with awareness). Report-only forever (§5)
- **Block 7 — 跨 plan 冲突审核** (pre-code review: intercept conflicts at the plan source; NOT a code-quality review): **report conflicts only — duplication / overlap is explicitly not a finding**. Two dimensions: (a) plan-vs-plan contradictions (mutually exclusive goals, scope, or conclusions); (b) plan-vs-knowledge conflicts (a plan's approach contradicts notes conclusions or iteration-verified facts)

Blocks 6 and 7 each get their own subagent, dispatched in parallel with Blocks 1-5 in the same pattern; when the data volume is large, a block may batch internally. The main agent only slices, synthesizes, and presents — never review large volumes of notes or plan full texts in the main context.

**Auto-memory (main agent only)**: subagents do not share your context — cross-check your loaded auto-memory entries against workspace notes (read-only). Contradictory or stale memory entries are reported to the user as 黄; never modify auto-memory.

Synthesize: dedupe findings, merge into the three-tier report, note per-block coverage.

## 5. Repair (--fix)

- **Tier 1 — script layer (automatic)**: run `doctor.sh --fix` — repairs the broken latest symlink, removes orphan table rows (orphan rows only, never completed rows — full history stays in `plan/index.md`), backfills missing notes.md rows. Results are [script] fixes, reported as such
- **Tier 2 — semantic layer (agent, user-confirmed)**: for each 红/黄 agent finding, propose a concrete repair (exact file + exact change), get the user's confirmation (per item or as one batch), then execute:
  - Content documents (readmes, notes, examples, templates): edit directly — plan documents are never edited (any mode, any tier; see below)
  - Tables (`plan.md` / `iterations.md` / `plan/index.md` / `iterations/index.md` / `register.md`): scripts only, or the one-time user-confirmed manual exception
- **Optimization (蓝)**: list as suggestions; never execute without an explicit user request
- **[14]/[15] findings**: [14] repairs (removing stale registry rows via repos.sh, writing the host shield into .gitignore / .git/info/exclude) are always tier-2 — user-confirmed, never automatic. [15] findings (bookkeeping ids / experiment data already in a code repo's HISTORY) are report-only forever — no tier rewrites git history; rebuilding (rebase/filter-repo) is the user's decision, and on explicit request it runs per the history-rebuild protocol in agentspace-code-clean's CLEANUP.md
- **Block 6 / Block 7 findings** (notes content-quality judgments, cross-plan conflicts): report-only forever, same level as [15] — no tier auto-repairs them, and doctor must not fix them in place during the run even when the right action gets incidentally confirmed along the way; disposition is user-driven, separate work after the report
- **Plan documents are user-owned — all modes, all tiers**: doctor never modifies plan document content (`plan/todo/*.md` and other plan prose), with or without `--fix`; findings involving plan are report-only, and any plan revision is the user's own separate work. The scripts-only structural hygiene of view rows (tier-1 orphan-row cleanup in `plan.md` via `doctor.sh --fix`) is unchanged — it is index hygiene on a scripts-only view, not plan-document editing
- **Never**: modify in-progress plan/iteration state fields, `data/` payload, host project files (host root AGENTS.md only with explicit user approval), auto-memory

## 6. Report

stdout only — never write report files into the workspace (the workspace repo must stay clean):

```
## /agentspace-doctor <mode> report
### 红 (must fix) — N
- [script|agent] <path>: <finding>
### 黄 (warning) — M
### 蓝 (optimization suggestions) — K
### 结论: 全绿 / 红 N · 黄 M · 蓝 K (有红 = 不绿)
```

## 7. Boundaries

- Read-only unless `--fix` is explicitly given
- No workspace file writes, no report files, no auto-memory writes
- `data/` payload never read; plugin dev data never read (user projects)
- Environment claims are verified by static dry-run analysis — never execute the test suite
- doctor.sh remains the wrap-up gate; this command is explicit on-demand only
