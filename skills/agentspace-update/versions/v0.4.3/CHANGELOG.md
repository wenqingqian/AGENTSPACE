# AGENTSPACE v0.4.3

Upgrade from v0.4.2. Date: 2026-08-05

## Summary

- **v0.4 系列风险审计修复(A1/A2/A3/A6)**: `--list` 缺失索引时报错不再静默空输出; produce 自动重建被删的 `handoff/` 目录; close-iteration 短 sha 提取放宽到 `{4,40}`(core.abbrev<7 不再静默跳过); status.sh 补日期形状校验(与 doctor [10] 对齐)。
- **脚本生态硬性要求(环境闸门 + 确定性 + 显式依赖)**: lib.sh 启动时校验 bash ≥ 3.1 与核心 POSIX 工具链(macOS 系统 bash 3.2 / Linux 4.x+ 均满足), 缺工具/老 bash 时一条清晰报错而非中途晦涩失败; `LC_ALL=C` 固化字节级行为(混合 CJK/ASCII 内容下字符类与排序确定, 显示不受影响); new-plan.sh 对 python3 显式检查。
- **CJK 全读路径测试**: t11 新增中文名 handoff 的 doctor/list/status 读路径断言。

## Changes

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

### No structural changes
- plan/iterations/notes/utils/tests/data/examples/register/handoff schemas unchanged; no new lib.sh constants (the environment gate and `LC_ALL=C` are runtime behavior, not constants); architecture.json unchanged apart from the version field.
