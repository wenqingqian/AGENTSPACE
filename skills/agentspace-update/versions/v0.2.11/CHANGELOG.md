# AGENTSPACE v0.2.11

Upgrade from v0.2.10. Date: 2026-08-04

## Summary

Update-flow hardening (3 changes, ALL skill text — no workspace files change; findings from the 2026-08-03 update-chain rehearsals + code review):
1. Blank-line normalization guidance when re-attempting a previously refused AGENTS.md insertion
2. Partial-refusal version semantics made explicit and COMPLETE: the version file records the highest fully-applied version, and step 8c writes that version + its architecture snapshot (not the target's)
3. Pre-update rollback tag (`pre-update-v<old>`, `<old>` = step-2 currentVersion) + rollback command in the report

## Changes

### [Fix] Re-attempt insertion: blank-line normalization guidance

**What**: `skills/agentspace-update/SKILL.md` step 8b ("AGENTS.md changes → smart merge" bullet list) gains a last bullet; `skills/agentspace-update/SKILL.zh-CN.md` step 8b (AGENTS.md 变更 bullet) gains the same guidance inline.

**Why**: rehearsal B (conservative-mode partial refusal, 2026-08-03) proved that re-applying a previously refused AGENTS.md insertion leaves residual blank lines at the anchor point (3 consecutive blank lines observed before `### data`); without normalization the re-attempted merge drifts from the full-chain result.

**Migration**: none — skill text (plugin-side, delivered via plugin update). Workspace files unchanged; step 8a runs as usual.

Exact additions:

EN — `skills/agentspace-update/SKILL.md`, step 8b, append as the last bullet of the "**AGENTS.md changes** → smart merge:" list:

````
  - When re-applying a previously refused insertion, the anchor area may carry residual blank lines left by the earlier skip — after inserting, collapse consecutive blank lines to one (verify against the canonical asset `skills/agentspace-init/assets/agentspace/AGENTS.md`)
````

ZH — `skills/agentspace-update/SKILL.zh-CN.md`, step 8b, replace the AGENTS.md bullet with:

````
- AGENTS.md 变更 → 智能合并（新节插入、用户内容保留、结构树更新、常量漂移时更新纪律节；重试此前被拒绝的插入时，锚点处可能残留上次跳过留下的连续空行——插入后把连续空行折叠为一个，与规范资产 `skills/agentspace-init/assets/agentspace/AGENTS.md` 比对确认）
````

### [Fix] Partial-refusal version semantics made explicit and complete (MUST)

**What**: `skills/agentspace-update/SKILL.md` step 7 "**Critical**" paragraph replaced with the prefix formulation; Notes "Partial updates" bullet updated; **step 8c rewritten** — it now writes the step-7-determined version and copies the RECORDED version's architecture.json instead of the target's; step 10 gains a partial-commit note. Same in `skills/agentspace-update/SKILL.zh-CN.md`.

**Why**: the previous wording ("record what was actually applied") was ambiguous; and step 8c still unconditionally wrote the target version, recreating the silent-migration-loss path this release closes. Rehearsal B proved the working semantics: the version file must record the highest version V whose changelogs from `currentVersion + 1` through V were ALL applied; recording the target while vN items are skipped would make the next update start after vN — the skipped items would never be re-attempted. The architecture snapshot must describe what the workspace actually is, so partial updates copy the recorded version's snapshot.

**Migration**: none — skill text.

Exact text:

EN — `skills/agentspace-update/SKILL.md` step 7, replace the "**Critical**:" paragraph with:

````
**Critical**: in conservative mode, if a destructive change (deletion, schema loss) is refused by the user, that change is SKIPPED, not forced. The version file records the highest version V such that every changelog from `currentVersion + 1` through V was fully applied — i.e., if the earliest skipped change comes from vN, record N-1 (or keep the current version); never the target version. Otherwise the next update starts after the skipped version and the refused items are never re-attempted.
````

EN — `skills/agentspace-update/SKILL.md` step 8c, replace with:

````
**c. Update version markers** — pass the version determined in step 7 (targetVersion when every changelog item was applied; otherwise the highest fully-applied version):
```bash
bash skills/agentspace-update/scripts/update-version.sh <recorded-version>
```
Copy the architecture.json of the RECORDED version (not the target — the snapshot must describe what the workspace actually is):
```bash
cp skills/agentspace-update/versions/v<recorded>/architecture.json AGENTSPACE/.agentspace-architecture.json
```
````

EN — `skills/agentspace-update/SKILL.md` step 10, replace "Commit message type: `update`. Report the commit hash to the user." with:

````
Commit message type: `update`. If the recorded version equals the old version (partial refusal), commit as `update: AGENTSPACE partial (v<old>, refused items pending)`. Report the commit hash to the user.
````

EN — `skills/agentspace-update/SKILL.md` Notes, replace the "- **Partial updates**: ..." bullet with:

````
- **Partial updates**: if the user refuses some changes in conservative mode, the workspace is in a mixed state. Record the highest fully-applied version in `.agentspace-version.json` and copy that version's architecture.json (see step 7 Critical + step 8c) — lower than targetVersion. The next update re-reads the skipped version's changelog and re-attempts the skipped changes.
````

ZH — `skills/agentspace-update/SKILL.zh-CN.md` step 7, replace the "**关键**：" paragraph with:

````
**关键**：保守模式下，用户拒绝的破坏性变更被**跳过**而非强制执行。版本文件记录**最高完整应用版本 V**（从 `currentVersion + 1` 到 V 的每个 changelog 都被完整应用）：即最早被跳过的变更若来自 vN，记录 N-1（或保持当前版本），绝不记录目标版本——否则下次更新从被跳过的版本之后开始，被拒绝的项永远不会被重试。
````

ZH — `skills/agentspace-update/SKILL.zh-CN.md` step 8c, replace with:

````
**c. 更新版本标记**——传入 step 7 确定的版本（全部应用则为 targetVersion，否则为最高完整应用版本）：
```bash
bash skills/agentspace-update/scripts/update-version.sh <已记录版本>
```
拷贝**已记录版本**的 architecture.json（快照必须描述工作区实际状态，而非目标版本）：
```bash
cp skills/agentspace-update/versions/v<已记录>/architecture.json AGENTSPACE/.agentspace-architecture.json
```
````

ZH — `skills/agentspace-update/SKILL.zh-CN.md` step 10, replace "提交类型：`update`。告知用户 commit hash。" with:

````
提交类型：`update`。若已记录版本等于旧版本（部分拒绝），提交为 `update: AGENTSPACE partial (v<旧版本>, 被拒项待重试)`。告知用户 commit hash。
````

ZH — `skills/agentspace-update/SKILL.zh-CN.md` 备注, replace the "- **部分更新**：..." bullet with:

````
- **部分更新**：用户在保守模式下拒绝部分变更时，工作区处于混合状态。`.agentspace-version.json` 记录**最高完整应用版本**并拷贝该版本的 architecture.json（见 step 7 关键说明与 step 8c），低于 targetVersion。下次更新重读被跳过版本的 changelog，重试被跳过的变更。
````

### [Addition] Pre-update rollback tag

**What**: `skills/agentspace-update/SKILL.md` step 8 gains a mandatory first action (create/overwrite `pre-update-v<old>` in the workspace repo before any mutation, `<old>` = step-2 currentVersion, `-f` for re-attempts); step 11 report gains the rollback command; Notes "No rollback" bullet replaced by "Rollback" (with an uncommitted-changes caveat). Same in `skills/agentspace-update/SKILL.zh-CN.md`.

**Why**: "no rollback" previously forced the user to hunt the pre-update commit in history; with conservative-mode mixed states this is painful. A versioned tag makes rollback one command and the report always carries it.

**Migration**: none — skill text. Existing workspaces get the tag at their next update (the tag lives in the workspace repo, `AGENTSPACE/.git`; no workspace files change).

Exact text:

EN — `skills/agentspace-update/SKILL.md` step 8, replace the intro paragraph (previously "After confirmation (or immediately in aggressive mode):") with the following, keeping the tag command before "**a. Replace plugin-managed files**":

````
After confirmation (or immediately in aggressive mode), first create the rollback tag in the workspace repo (git by the init contract). `<old>` is the currentVersion read in step 2 — the version being updated FROM. Use `-f` to overwrite: on a re-attempt from the same base version the tag is re-pointed at the current pre-update state, so rollback undoes only the current update. If the tag command fails, abort and report the error.

```bash
git -C AGENTSPACE tag -f pre-update-v<old>
```

Then:
````

EN — `skills/agentspace-update/SKILL.md` step 11, add to the report list (after "- Doctor result"):

````
- Rollback command: `git -C AGENTSPACE reset --hard pre-update-v<old>`
````

EN — `skills/agentspace-update/SKILL.md` Notes, replace the "- **No rollback**: ..." bullet with:

````
- **Rollback**: every update creates/overwrites a `pre-update-v<old>` tag (`<old>` = currentVersion from step 2) before mutating (step 8). Roll back with `git -C AGENTSPACE reset --hard pre-update-v<old>`; delete a tag with `git -C AGENTSPACE tag -d pre-update-v<old>`. Tags are cheap — leave them in place. Before `reset --hard`, check `git status` — uncommitted changes are discarded (stash or commit them first).
````

ZH — `skills/agentspace-update/SKILL.zh-CN.md` step 8, replace the intro paragraph (previously "确认后（或激进模式下直接）执行：") with the following, keeping the tag command before "**a. 替换插件管理文件**":

````
确认后（或激进模式下直接），先在工作区仓库创建回滚 tag（init 契约保证工作区是 git 仓库）。`<旧版本>` = step 2 读到的 currentVersion（本次更新从哪个版本出发）。用 `-f` 覆盖：同一基线版本重试时，tag 重新指向当前更新前的状态，此时回滚只撤销本次更新。tag 命令失败则中止并报告错误：

```bash
git -C AGENTSPACE tag -f pre-update-v<旧版本>
```

然后：
````

ZH — `skills/agentspace-update/SKILL.zh-CN.md` step 11, replace the 总结 line with:

````
总结：版本跨度、替换文件数、schema 变更、内容合并、跳过项（保守模式）、doctor 结果、回滚命令（`git -C AGENTSPACE reset --hard pre-update-v<旧版本>`）、下一步建议。
````

ZH — `skills/agentspace-update/SKILL.zh-CN.md` 备注, replace the "- **无回滚**：..." bullet with:

````
- **回滚**：每次更新在变更前创建/覆盖 `pre-update-v<旧版本>` tag（`<旧版本>` = step 2 的 currentVersion，见 step 8）。回滚：`git -C AGENTSPACE reset --hard pre-update-v<旧版本>`；删除 tag：`git -C AGENTSPACE tag -d pre-update-v<旧版本>`。tag 很便宜，保留即可。`reset --hard` 前先查 `git status`——未提交的改动会被丢弃（先 stash 或提交）。
````

### No structural changes

- Workspace layout, schemas, templates, scripts unchanged. architecture.json: version bump only.
