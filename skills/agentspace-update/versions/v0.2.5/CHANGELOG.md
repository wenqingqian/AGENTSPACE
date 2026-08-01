# AGENTSPACE v0.2.5

Upgrade from v0.2.4. Date: 2026-08-02

## Summary

- Agent guidance: wrap-up protocol + result-section quality gates + MUST rule levels + recovery path
- Document management: script-table link validation + files-touched convention + search guidance
- Script behavior changes: doctor.sh (dirty-tree check, link check, fixed tip), close/complete (result gate)

## Changes

### [Addition] Wrap-up protocol (agent discipline, MUST)
- **What**: daily skill requires before ending any project work session: ① update in-progress readme 当前状态·下一步 ② run doctor.sh (hard errors resolved, warnings reported) ③ milestone commit
- **Why**: silent drift (stale readme, skipped commit) was undetectable; doctor was only run "when suspected corrupt"
- **Migration**: behavior-only (SKILL.md/AGENTS.md text). No workspace files change.

### [Addition] doctor.sh dirty-worktree check
- **What**: new check `[0] git worktree` — if `git status --porcelain` shows uncommitted changes, warns "uncommitted changes (N file(s)); run a milestone commit"
- **Why**: cheap enforcement of the wrap-up protocol's commit step
- **Migration**: script replaced by step 8a. Behavior change only.

### [Addition] Result-section quality gates (close-iteration.sh / complete-plan.sh)
- **What**: close-iteration refuses if readme 结果 section still contains the template placeholder comment; complete-plan refuses if plan doc 结果 section contains its placeholder (first line of the two-line comment). Constants `RESULT_PH_ITER` / `RESULT_PH_PLAN` in lib.sh must match template comments exactly.
- **Why**: closing/completing with an untouched (empty) result section produced useless records
- **Migration**: scripts replaced by step 8a. Existing filled documents are unaffected (placeholder absent). Documents never filled will now be refused at close/complete — agent must fill 结果 first (this is the intent).

### [Fix] doctor.sh tip no longer contradicts scripts-only discipline
- **What**: end tip now says: do not hand-edit tables on your own; discuss repair with the user; a one-time manual fix explicitly confirmed by the user is the only allowed exception
- **Why**: old tip ("can be fixed by editing the corresponding rows") directly contradicted the scripts-only rule

### [Addition] MUST/SHOULD/MAY rule levels
- **What**: rule-level legend added to SKILL.md §2 and AGENTS.md 纪律; `[MUST]` tagged on the 5 hard rules (English plan titles, user confirmation, scripts-only, no hand-edit on script errors, wrap-up protocol)
- **Why**: agents could not distinguish hard rules (damage on violation) from best practices
- **Migration**: text-only.

### [Addition] Script-error recovery path (user-confirmed exception)
- **What**: discipline now states: on script errors, do NOT hand-edit tables; run doctor.sh, discuss repair with the user; a one-time manual fix explicitly confirmed by the user is the only allowed exception to scripts-only
- **Why**: "never hand-edit" + report-only doctor left corruption unrecoverable
- **Migration**: text-only.

### [Addition] Milestone commit triggers enumerated
- **What**: trigger list replaced "important document updates" with a concrete list (incl. module registration)
- **Migration**: text-only.

### [Addition] Script-table link validation (doctor.sh)
- **What**: new check `[4] link validity` — extracts `](...)` targets from data rows of plan.md / plan/index.md / iterations.md / iterations/index.md / register.md and warns when the target file does not exist (relative to AS_ROOT). External/anchor links skipped.
- **Why**: renamed/moved files left broken table links undetected
- **Migration**: script replaced by step 8a. Behavior change only. Agent-managed tables (notes/utils/examples/data) are intentionally NOT checked (free-form content).

### [Addition] Files-touched convention (iteration readme template)
- **What**: template "代码变更 (diff)" comment now shows `- 文件: path/to/file.py` example lines; SKILL.md iteration workflow instructs listing touched file paths
- **Why**: makes "which plan touched file Y" greppable
- **Migration**: template replaced by step 8a. Existing readmes not retrofitted (convention applies to new iterations). No script enforces it.

### [Addition] Historical search guidance
- **What**: SKILL.md §2 new subsection: grep for small scope (exclude data/), delegate to a subagent for synonyms/large scope, record reusable findings in notes
- **Why**: a rigid search script was rejected (keyword misses are common; subagents handle large scopes better)
- **Migration**: text-only.

### No structural changes
- No file/schema/table changes to the workspace layout. All changes are script behavior, template comments, or skill/doc text. architecture.json unchanged except version number.
