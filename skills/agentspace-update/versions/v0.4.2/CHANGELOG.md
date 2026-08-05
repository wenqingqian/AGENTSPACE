# AGENTSPACE v0.4.2

Upgrade from v0.4.1. Date: 2026-08-05

## Summary

- **handoff --list 修复**: desc 含 `\|` 时列表输出损坏(desc 被拆、日期列丢失, v0.4.0 遗留)— 改用与 doctor [10]/[11] 相同的形状解析, `\|` 教训第三处收口。
- **close-iteration 自动收集宿主 diff**: 关闭迭代时按 readme 记录的起始/结束 commit 自动保存 `data/diff-<start>..<end>.patch`。
- **doctor [12] register 一致性检查**: register.md 模块行 ↔ `NAME.md` + `NAME/` 文件(只报告, 不自动修复 — 注册需用户确认)。
- **handoff --keep 显式标记**: --keep 在快照文件内写 `> 状态: kept(...)` 标记, doctor [11] 跳过有意保留的快照(不再报过时红)。
- **STALE_DAYS 单源化**: 过时阈值从 doctor.sh/status.sh 双字面量收敛为 lib.sh 常量(architecture.json constants 同步)。
- **doctor [11] 预览增强**: `下一步` 节预览跳过多行注释块(与 status.sh 状态机一致)。

## Changes

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

### No structural changes
- plan/iterations/notes/utils/tests/data/examples/register/handoff schemas unchanged; new constant `STALE_DAYS` registered in architecture.json (lib.sh ↔ constants sync).
