# AGENTSPACE v0.4.4

Upgrade from v0.4.3. Date: 2026-08-05

## Summary

- **AGENTS.md data bullet 措辞同步**: 模块节的 data when/how bullet 改为 `data/ 全部 gitignore(与 .gitignore 行为一致, 无 opt-out)` — 消除与真实行为(.gitignore 全量 ignore `data/`)及结构树行(`全部 gitignore`)的自相矛盾。历史 commit 6c439e3(2026-07-31, 无版本档案)将 .gitignore 改为全量 ignore 但遗漏该 bullet, 本版补记并同步。
- **历史 CHANGELOG 档案修订(升级链兼容性, 管理改进不 bump 版本)**: v0.2.1(data bullet 精确文本与资产一致)、v0.2.7(补 notes when/how bullet 精确替换指令 — v0.2.12 的回链替换锚点依赖它)、v0.4.0(补结构树 templates 行追加 `/ handoff` 指令)。
- **t13-upgrade-chain.sh 回归测试**: 从 v0.1.0 资产合成 legacy 工作区 → 按档案重放全部版本迁移步骤 → 断言版本标记收敛、doctor 全绿、三个文本点一致。

## Changes

### [Fix] AGENTS.md: data bullet 措辞与 .gitignore 行为一致
**What**: `AGENTSPACE/AGENTS.md` 模块节的 data when/how bullet 从 `大文件/权重默认 gitignore, 小型共享文件可取消注释` 改为 `data/ 全部 gitignore(与 .gitignore 行为一致, 无 opt-out)`。`.gitignore` 自 commit 6c439e3(2026-07-31)起已全量 ignore `data/`(含 `iterations/*/data/`), 无 opt-out; 结构树行早已写 `全部 gitignore`, 唯独模块节 bullet 保留旧 opt-out 措辞 — 自相矛盾且误导用户。
**Why**: 升级链兼容性审计(GAP #3 附带项)发现: 该 bullet 与真实行为矛盾; 6c439e3 是一次无版本档案的结构变更, 本版补记。
**Migration**:
1. **AGENTS.md (step 8b — agent action, exact replace)**: in `AGENTSPACE/AGENTS.md`, 模块 section (`### data —— 公用数据`), replace the "when/how" bullet:
   ```
   - **when/how**: 多个实验需要同一份数据时放入 data/ 并在 data.md 登记; 大文件/权重默认 gitignore, 小型共享文件可取消注释
   ```
   with:
   ```
   - **when/how**: 多个实验需要同一份数据时放入 data/ 并在 data.md 登记; data/ 全部 gitignore(与 .gitignore 行为一致, 无 opt-out)
   ```
   Idempotency: if the bullet already contains 全部 gitignore, leave it as-is. If the anchor line is absent (user customized it), keep the user's version and ensure the 全部 gitignore 子句 is present.
2. **No data migration**: behavior unchanged — this is a doc-context fix.

### [Fix] 历史 CHANGELOG 档案修订: 升级链文本点补全(GAP #1-3)
**What**: three historical changelogs gained the exact migration text they were missing (found by the upgrade-chain compatibility audit — a strict replay of v0.1.0 → v0.4.3 failed at these anchors):
- `versions/v0.2.1/CHANGELOG.md`: the data module insert text now matches the asset wording (`大文件/权重默认 gitignore, 小型共享文件可取消注释`) instead of `data/ 全部 gitignore`.
- `versions/v0.2.7/CHANGELOG.md`: added the notes when/how bullet exact-replace instruction (old → new, 模块 section) — the v0.2.12 back-link replace anchors on the new text, so skipping v0.2.7's AGENTS.md change breaks v0.2.12.
- `versions/v0.4.0/CHANGELOG.md`: added the structure-tree `├── templates/` line update (append `/ handoff`) alongside the existing `handoff/` insert line.
**Why**: the changelogs are read at upgrade time; precise anchors make a strict upgrade deterministic instead of agent guesswork (the audit's sandbox replay FAILED at the v0.2.12 anchor and only passed via asset-diff backfill).
**Migration**:
1. **Plugin-side (no workspace action)**: ships with the plugin; existing workspaces are unaffected (the fixes only matter for future upgrades through these versions).
2. **No data migration**.

### [Addition] tests: t13-upgrade-chain.sh — full-chain replay regression
**What**: `tests/t13-upgrade-chain.sh` synthesizes a v0.1.0-era legacy workspace from the git history (`git archive` of the v0.1.0 commit's init assets), replays every version's 8a/8b/8c migration steps exactly as the changelogs specify (8b text ops use the archives' exact anchors — a missing anchor fails the test), and asserts: version markers converge to the current version, `doctor.sh` is green, and the three text points (structure-tree templates line contains `/ handoff`; notes when/how bullet contains the back-link clause and 标签子句; data bullet matches the canonical asset wording).
**Why**: t01-t12 + verify-release only validate archive *structure*, not the migration chain — the three GAPs were invisible to them. t13 turns the audit into a permanent guard: any future changelog edit or new version that breaks the chain fails here.
**Migration**:
1. **Dev-only (no workspace action)**: ships with the repo.
2. **Maintenance note**: when a new version adds workspace content changes (AGENTS.md text ops), extend the version-op table in the test.

### No structural changes
- plan/iterations/notes/utils/tests/data/examples/register/handoff schemas unchanged; no new lib.sh constants; architecture.json unchanged apart from the version field (AGENTS.md bullet wording is content, not schema).
