# AGENTSPACE v0.4.4 (合并 v0.4.1-v0.4.3)

Upgrade from v0.4.0. Date: 2026-08-05

> **合并说明**: v0.4.1 / v0.4.2 / v0.4.3 为同日碎片 bug-fix 版, 已合并进本版(用户拍板, 档案压缩)。
> 从 v0.4.0 升级时按本档案一次性应用以下全部变更; 若工作区版本标记落在 v0.4.1-v0.4.3, 内容与本版相同, 直接按本档案升级(update agent: 跳过缺失的中间档案)。

## Summary

- **handoff 纳入 doctor 范围**: 新增 [10] handoff 残留一致性(死行 --fix 按 name+location 双匹配 / 孤儿文件+重复行只报告)+ [11] 过时审核(7 天以上, 只报告含 下一步 预览, 绝不删不 consume); --keep 显式标记(快照文件内, [11]/status 跳过保留项); --list 形状解析修复(转义 \| 不再拆裂, 缺失索引显式报错)。
- **会话入口可见性**: status.sh `## Handoffs (待消费)` 节(含 --keep 保留/文件缺失/过时标记); update 流程两段式 verify 闸门; doctor --major 内容级 handoff 审查。
- **自动化**: close-iteration 自动宿主 diff; doctor [12] register 一致性(只报告); STALE_DAYS 单源常量。
- **bash 生态硬化**: 环境闸门(bash ≥3.1 + 核心工具链)+ LC_ALL=C 确定性 + new-plan python3 显式检查 + CJK 读路径测试。
- **升级链**: 资产 data bullet 与 .gitignore 行为一致(6c439e3 补记); 历史档案锚点修订(v0.2.1/v0.2.7/v0.4.0); t13 全链重放回归测试。

## Changes


### [Addition] doctor checks [10] handoff consistency + [11] handoff staleness
**What**: `AGENTSPACE/scripts/doctor.sh` gains two checks between [9] and the summary:
- **[10] handoff consistency** (仅当 `AGENTSPACE/handoff/` 目录存在时运行; 无 index.md 或无 handoff 文件则静默通过):
  - 有行无文件: 索引行 location 指向的 `handoff_*.md` 不存在(崩溃中断的 consume 残留)→ warn; `--fix` 删除该行(按首列 name 字符串相等、`## Handoffs` 节内删除, 同 consume 的删除模式; 带 before/after 行数守卫, 修复失败不报绿)
  - 有文件无行: `handoff/handoff_*.md` 在磁盘上但索引无对应行(崩溃中断的 produce 残留, 文件被 gitignore 对 git 不可见)→ warn + 报告完整路径, **无 --fix**(文件可能含未读上下文, 用户读完手动删除)
  - 重复行: 同名或同 location 行 >1(手工编辑产物)→ warn, **无 --fix**
  - 行解析按形状定位字段(首列 name / 匹配 `handoff_*.md` 的列 / 末尾日期列), 不用裸 `|` 切分 — 容忍 description 中的 `\|` 转义(v0.4.0 as_insert_row ENVIRON 教训延续)
- **[11] handoff staleness** (阈值 7 天, doctor.sh 内字面量):
  - `find AGENTSPACE/handoff -maxdepth 1 -type f -name 'handoff_*.md' -mtime +7` 检测(BSD/GNU find 兼容, 无日期算术)
  - 对每个过时文件: warn 报告 name + description + 生产日期(索引行)+ 文件路径 + 该 handoff 要干什么(提取文件 `## 下一步` 节首行)+ 处理提示
  - [10] 已报的孤儿文件跳过, 避免双报
  - **无 --fix 分支** — 模块契约: consume 必须人工读完快照后执行, doctor 只报告

**Why**: handoff 文件 gitignored、对 git 不可见, 残留会静默堆积; consume/produce 中途崩溃可产生死行或孤儿文件; v0.4.0 前 doctor 完全未覆盖该模块(t10 注释明言 out of scope)。用户边界(2026-08-05 确认): 过时 handoff 只做分析反馈, 不得私自删除或 consume。

**Migration**:
1. **Script (handled by step 8a — no manual work)**: `AGENTSPACE/scripts/doctor.sh` is replaced from assets.
2. **No data migration**: checks are read-only except `--fix` removing dangling handoff index rows (file already gone). Existing workspaces with consistent handoff pairs pass silently.

### [Addition] status.sh: handoff summary section
**What**: `AGENTSPACE/scripts/status.sh` gains a `## Handoffs (待消费)` section (after 推进总览): one line per indexed handoff — `name | description | produced-date`, with a `⚠ 过时(>7 天未消费)` marker for files older than 7 days (`find -mtime +7`, same threshold as doctor [11]).
**Why**: handoffs are the session-resume entry (AGENTS.md 读取规则) but were invisible outside `handoff/`; status.sh is the session-start summary, so the pending-consumption list belongs there.
**Migration**:
1. **Script (handled by step 8a — no manual work)**: `AGENTSPACE/scripts/status.sh` is replaced from assets.
2. **No data migration**: read-only view; row parsing is shape-based (first name cell / last date cell, tolerates escaped `\|` in descriptions), consistent with doctor [10].

### [Addition] update flow: doctor verify gate (step 9)
**What**: `skills/agentspace-update/SKILL.md` step 9 becomes a two-phase gate: pre-commit `doctor.sh --fix` + `doctor.sh` (red items other than [0] uncommitted-changes must be resolved; only [0] may remain), then post-commit re-run that must exit 0 before the update is declared complete.
**Why**: step 9 previously reported issues without blocking; a naive all-red gate would deadlock on doctor [0] (files are modified at step 8, committed at step 10). The two-phase design catches version-marker drift ([9]) pre-commit and final consistency post-commit.
**Migration**:
1. **Plugin-side (no workspace action)**: ships with the plugin.

### [Addition] doctor --major: content-level handoff staleness review
**What**: `skills/agentspace-doctor/SKILL.md` Phase B review scope now includes `handoff/index.md` + `handoff/handoff_*.md`; a handoff whose 引用/下一步 no longer match current state (referenced plan completed, 下一步 already done, resume block superseded by `iterations/latest`) is a 黄 finding with a concrete suggestion (consume / delete / re-produce) — never auto-deleted or auto-consumed. Phase C Block 1 (host outcome verification) also covers handoff 下一步 claims.
**Why**: script check [11] only detects age; content-level staleness is agent judgment, which belongs to the --major content review tier (scripts enforce contracts, agents judge content).
**Migration**:
1. **Plugin-side (no workspace action)**: ships with the plugin.

### [Fix] handoff.sh: name `name` reserved; staleness check/message exactness
**What**: `AGENTSPACE/scripts/handoff.sh` refuses `name` as a handoff name — a handoff named `name` collides with the index table-header filter (`| name |`) used by `--list`, doctor [10]/[11] and the status summary, making the row invisible to all read paths. `AGENTSPACE/scripts/doctor.sh` [11] and `AGENTSPACE/scripts/status.sh` now use `find -mtime +6` so the check and the ">7 天" messages agree exactly (`find -mtime +N` = strictly more than N whole days; `+6` ⇒ 7 天以上, previously `+7` flagged only ≥8 days).
**Migration**:
1. **Scripts (handled by step 8a — no manual work)**: `AGENTSPACE/scripts/handoff.sh`, `AGENTSPACE/scripts/doctor.sh`, `AGENTSPACE/scripts/status.sh` are replaced from assets.
2. **No data migration**.
### [Fix] handoff.sh --list: escaped-`|` descriptions corrupt the output
**What**: `AGENTSPACE/scripts/handoff.sh --list` parsed rows with `awk -F'|'`, which splits inside the escaped `\|` cells written by `as_cell` — a description like `a | b` rendered as `a \ | b` and the trailing **date column was dropped entirely** (the date landed in the discarded 6th field). This shipped since v0.4.0; it was hidden by a silently-broken test assertion (fixed in v0.4.1). `--list` now uses the same shape-based parsing as doctor [10]/[11] (first name cell / last date cell, tail-anchored), tolerating escaped pipes.
**Why**: third occurrence of the `\|` field-splitting lesson (v0.4.0 insert fix, v0.4.1 doctor/status parse — list was missed).
**Migration**:
1. **Script (handled by step 8a — no manual work)**: `AGENTSPACE/scripts/handoff.sh` is replaced from assets.
2. **No data migration**.

### [Addition] close-iteration: auto-collect host code diff
**What**: `AGENTSPACE/scripts/close-iteration.sh` reads the iteration readme's `> 宿主起始 commit:` / `> 宿主结束 commit:` lines (recorded at creation/close) and, when both exist and differ, saves `git -C <host> diff <start>..<end>` to `iterations/iteration_NNNN/data/diff-<start>..<end>.patch`. Non-empty diffs print `code diff saved → ...`; no git host / missing commits / empty diff silently skip. Best-effort metadata — guards make failure impossible under lock.
**Why**: the "save the diff to data/" discipline was manual and routinely missed (the v0.4.1 diff was hand-collected after the fact); the start/end commits were already being recorded, so the diff is a deterministic script operation.
**Migration**:
1. **Script (handled by step 8a — no manual work)**: `AGENTSPACE/scripts/close-iteration.sh` is replaced from assets.
2. **No data migration**: existing iterations are untouched; only iterations closed from now on collect diffs.

### [Addition] doctor [12]: register module consistency
**What**: `AGENTSPACE/scripts/doctor.sh` gains check [12] (after [11]): for every row in `register.md`'s `## 已注册模块` section, the module's `NAME.md` file and `NAME/` directory must exist in the workspace root (the `register-module.sh` contract). Malformed names (not lowercase alphanumeric/hyphen) are reported too. **Report-only, no `--fix`** — re-creating a module requires user confirmation (register discipline).
**Why**: register-module.sh creates `NAME.md` + `NAME/` atomically, but nothing verified the pair afterwards; a hand-edit or partial cleanup silently breaks the contract. Empty register tables pass silently.
**Migration**:
1. **Script (handled by step 8a — no manual work)**: `AGENTSPACE/scripts/doctor.sh` is replaced from assets.
2. **No data migration**: read-only check; modules registered via `register-module.sh` already satisfy the contract.

### [Addition] handoff --keep marks the snapshot; doctor [11] skips kept handoffs
**What**: `AGENTSPACE/scripts/handoff.sh --consume --keep` now appends `> 状态: kept(--keep, YYYY-MM-DD)` to the handoff file. Doctor [11] skips files carrying the marker — a kept snapshot is intentionally preserved, not abandoned, so it is no longer reported as stale (previously an old `--keep`-ed handoff went red like any other).
**Why**: `--keep` is the module's explicit "preserve this" contract; the marker lives in the gitignored snapshot file (which `--keep` preserves by definition), not the index — no schema change. Side effect: the append refreshes mtime, which also pushes the staleness window out.
**Migration**:
1. **Scripts (handled by step 8a — no manual work)**: `AGENTSPACE/scripts/handoff.sh`, `AGENTSPACE/scripts/doctor.sh` are replaced from assets.
2. **No data migration**: handoffs kept before this version lack the marker and are treated as normal (stale-checkable) — re-`--keep` if you want the marker.

### [Addition] STALE_DAYS single-source constant
**What**: the staleness threshold (7 days) moves from duplicated literals in `AGENTSPACE/scripts/doctor.sh` and `AGENTSPACE/scripts/status.sh` into `AGENTSPACE/scripts/lib.sh` as `readonly STALE_DAYS="7"`; both scripts compute `find -mtime +$((STALE_DAYS - 1))` (strictly more than 6 whole days = 7 天以上, matching the messages). Registered in `architecture.json` constants.
**Why**: two literals with a cross-reference comment (v0.4.1) were a drift risk; the constants ↔ architecture.json sync rule makes the single source mechanical.
**Migration**:
1. **Scripts (handled by step 8a — no manual work)**: `AGENTSPACE/scripts/lib.sh`, `AGENTSPACE/scripts/doctor.sh`, `AGENTSPACE/scripts/status.sh` are replaced from assets.
2. **No data migration**: behavior unchanged (7 天以上).

### [Fix] doctor [11]: `下一步` preview skips multi-line comment blocks
**What**: the preview extraction previously stripped only single-line `<!-- ... -->` comments (sed line filter); a multi-line comment under `## 下一步` could surface comment guts. The extraction is now an awk state machine (same as status.sh): skip comment blocks until their closing `-->`, skip blank lines, print the first real content line.
**Migration**:
1. **Script (handled by step 8a — no manual work)**: `AGENTSPACE/scripts/doctor.sh` is replaced from assets.
2. **No data migration**.
### [Fix] handoff.sh --list: missing index now dies loudly instead of empty output
**What**: `AGENTSPACE/scripts/handoff.sh --list` on a missing `handoff/index.md` silently printed nothing with exit 0 (a user would conclude there are no handoffs). It now fails with `as_die "handoff index missing"` — the same guard `--consume` uses. Also: `--produce` now runs `mkdir -p AGENTSPACE/handoff/` before writing, so a manually-deleted `handoff/` directory is recreated instead of dying on a raw `cat` error.
**Why**: found by the v0.4-series read-only risk audit (A1/A2, sandbox-probe verified).
**Migration**:
1. **Script (handled by step 8a — no manual work)**: `AGENTSPACE/scripts/handoff.sh` is replaced from assets.
2. **No data migration**.

### [Fix] close-iteration: short-SHA extraction widened to {4,40}
**What**: the auto-diff's START/END extraction (`grep -oE '[0-9a-f]{7,40}'`) rejected SHAs shorter than 7 chars, silently skipping the diff on hosts with `core.abbrev=4..6`. The reader now accepts `{4,40}` — matching `git rev-parse --short`'s floor of 4.
**Why**: audit finding A3 (probe: `core.abbrev=4` yields a 4-char short SHA; default `auto` yields 7+).
**Migration**:
1. **Script (handled by step 8a — no manual work)**: `AGENTSPACE/scripts/close-iteration.sh` is replaced from assets.
2. **No data migration**.

### [Fix] status.sh: date-shape validation parity with doctor [10]
**What**: the status summary's malformed-row check now also validates the date cell (`YYYY-MM-DD`), matching doctor [10] and `--list` — a hand-edited row with a broken date no longer renders as a normal handoff in the summary.
**Why**: audit finding A6 (probe: bad-date row showed as a normal empty-date entry in status while doctor flagged it).
**Migration**:
1. **Script (handled by step 8a — no manual work)**: `AGENTSPACE/scripts/status.sh` is replaced from assets.
2. **No data migration**.

### [Addition] runtime environment gate + deterministic locale
**What**: `AGENTSPACE/scripts/lib.sh` now runs an upfront environment gate on source: bash ≥ 3.1 (the scripts use scalar `+=`, added in 3.1; the macOS system bash is 3.2, Linux ships 4.x+) and the core toolchain (`grep awk sed find date tr mkdir mktemp git`) must be on PATH — otherwise a single clear error message and exit, instead of a cryptic mid-script failure. It also exports `LC_ALL=C`: regex character classes and sort collation become byte-exact, so behavior is identical on every system/locale for mixed CJK/ASCII content (CJK bytes pass through untouched — display unaffected).
**Why**: user requirement for the bash-script ecosystem: system/syntax support detection + deterministic CJK handling + graceful failure instead of raw errors. `AGENTSPACE/scripts/new-plan.sh` additionally checks `python3` explicitly (its CJK-aware title truncation needs it).
**Migration**:
1. **Scripts (handled by step 8a — no manual work)**: `AGENTSPACE/scripts/lib.sh`, `AGENTSPACE/scripts/new-plan.sh` are replaced from assets.
2. **No data migration**: byte behavior is deterministic under all locales; nothing user-visible changes on macOS/Linux defaults.

### [Addition] tests: CJK handoff full read-path coverage
**What**: `tests/t11-handoff-doctor.sh` gains a Chinese-named handoff (`中文交接`) exercised through the whole read path — produce, stale detection (doctor [11]), `--list`, status summary — then consumed.
**Why**: the environment/locale hardening is only meaningful if the CJK paths are regression-tested.
**Migration**:
1. **Dev-only (no workspace action)**: ships with the repo.
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
- plan/iterations/notes/utils/tests/data/examples/register/handoff schemas unchanged; new constant `STALE_DAYS` registered in architecture.json (lib.sh ↔ constants sync); AGENTS.md bullet wording is content, not schema. 本版为 v0.4.1-v0.4.4 四版合并, 无额外结构变化。
