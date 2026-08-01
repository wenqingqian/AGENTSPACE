# AGENTSPACE v0.2.8

Upgrade from v0.2.7. Date: 2026-08-02

## Summary

- Host repo start/end commits auto-recorded into iteration readme 环境 section (creation/close)
- Agent-table entry guidance (example rows) added to utils.md / data.md / examples.md

## Changes

### [Addition] Host commit auto-recording (new-iteration.sh / close-iteration.sh)

**What**: on iteration creation, `new-iteration.sh` inserts `> 宿主起始 commit: <short-sha>` after the readme's `## 环境` heading; on close, `close-iteration.sh` inserts `> 宿主结束 commit: <short-sha>`. New helper `as_host_head()` in lib.sh returns the host repo (project root = `AS_ROOT/..`) HEAD short sha, empty when the host is not a git repo.

**Why**: the 环境 section previously relied on the agent manually recording commits (easy to skip); the start/end shas are needed for the diff convention (`git -C <宿主> diff <起始>..<结束> > data/diff-<起始>..<结束>.patch`).

**Migration**:
1. Scripts replaced by step 8a (guarded inserts: host must be a git repo, `## 环境` section must exist, and the line must not already be present — idempotent, never dies on old readmes).
2. **Asymmetric records**: pre-existing in-progress readmes have no auto-recorded start line. That's acceptable — the agent can add the start sha manually when saving a diff, or the close step records only the end sha.
3. The template comment and SKILL.md wording now state commits are auto-recorded; agents only need to save diffs for uncommitted host changes (`git -C <宿主> diff > data/code.diff`).

### [Addition] Agent-table entry guidance
- **What**: example-row HTML comments above the entry tables in utils.md, data.md, examples.md
- **Why**: these tables are agent-maintained free-form; an example row reduces format drift
- **Migration**: entry files are agent content — the update agent updates the headers/comments per the new assets (no forced migration)

### No structural changes
- Table schemas, templates sections, and the workspace layout are unchanged.
