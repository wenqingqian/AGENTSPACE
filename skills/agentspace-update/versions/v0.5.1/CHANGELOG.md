# AGENTSPACE v0.5.1

Upgrade from v0.5.0. Date: 2026-08-06

## Summary

- **24h 风险审计 8 项修复**(高置信实证): complete-plan `-v` 反转义(ENVIRON+shield)、doctor 裸 awk 守卫 / `--fix` id 归一化 / [1] latest FIX 门控、handoff consume 双匹配、update-version 原子写、new-plan python 3.6 兼容、produce 孤儿清理、index 追加原子化。
- **同构扫描收口**: 审计后全仓模式扫描再抓出第 7 处 `-v` 转义漏洞(doctor notes_insert_row)与 3 处 `>>` 非原子追加,一并修复。
- **t16-audit-regressions 回归**: 五项审计修复的永久护栏。
- **方法论沉淀**: DEVELOPMENT.md 新增「脚本模式纪律」六条契约(ENVIRON 传参/双匹配/原子写/守卫/FIX 门控/闸门清单),防同类问题再现。
- **status 近期动态重做**: 工作区事件流(计划/迭代/笔记/交接, 不依赖 commit)+ 提交摘要(类型前缀映射中文), 不再裸列 commit 名字。

## Changes

### [Fix] complete-plan.sh index 改写转义感知(ENVIRON + \037 shield)
**What**: `AGENTSPACE/scripts/complete-plan.sh` 的 plan/index.md 状态/完成日期/结果/链接改写与 close-iteration 同构,但漏迁 v0.5.0 的修复模式: `-v r="$RESULT_CELL"` 会被 awk 反转义,结果文本含 `|` 时索引行劈裂(7 列变 8+, 后续列错位), doctor 0 issues 完全无感, 仅 status 软告警可发现。现改为: 文件先 sed 屏蔽 `\|` → \037, RESULT_CELL 经 ENVIRON 传入, 改写后 sed 还原。
**Why**: 审计 R1(高) — 与嵌套工作区 iteration_0009 事故(c955df1)同一 bug 类在 plan 侧的漏网。
**Migration**:
1. **Script (handled by step 8a — no manual work)**: `AGENTSPACE/scripts/complete-plan.sh` is replaced from assets.
2. **No data migration**: existing corrupted rows (if any) need a one-time user-confirmed repair; t16 guards the path.

### [Fix] doctor.sh: 入口表缺失守卫 + --fix id 归一化 + [1] latest FIX 门控 + notes_insert_row ENVIRON
**What**: 四处修复:
- [2]/[3] 的 `todo_ids`/`prog_ids` 提取裸 awk 无守卫 — plan.md/iterations.md 缺失时 exit 2 中止, 跳过 [3]-[12] 全部检查(审计 R3)。加 `2>/dev/null || true`, 缺失时由既有 per-file warn 报告。
- [2]/[3] 孤儿行删除前 id 未归一化 — 手工 `| 1 |` 行(文件 0001-*.md 存在)会被误判孤儿删除(审计 R4)。现先 `as_norm_id` 再 compgen/目录匹配; 非数字 id 只 warn 不删。
- [1] latest 软链修复无 FIX 守卫 — status.sh(v0.5.0)内嵌调用 doctor 使"只读"命令产生写入(审计 R7/F1)。现无 `--fix` 只报告, 修复仅限 `--fix`(与其他 tier-1 项一致); 头注释同步更新。
- notes_insert_row 的 `-v row="$row"` 反转义 as_cell 内容 — 笔记主题含 `|` 时 --fix 插入的行劈裂(同构扫描新发现)。改 ENVIRON。
**Why**: 审计 R3/R4/R7 + 同构扫描; 修 doctor 是修复工具, 其自身崩溃/误删影响所有工作区。
**Migration**:
1. **Script (handled by step 8a — no manual work)**: `AGENTSPACE/scripts/doctor.sh` is replaced from assets.
2. **No data migration**: behavior change — broken `iterations/latest` now reports instead of auto-repairing without `--fix` (status.sh's embedded doctor call is now truly read-only).

### [Fix] handoff.sh: consume 双匹配 + produce 孤儿清理 + --keep 原子追加 + index 创建原子化
**What**: 四处修复:
- `--consume` 的预检与行删除仅按 name 匹配 — 索引出现重名行(手工编辑/旧版遗留)时删错行: 文件与行不是同一项, 产生 dangling+orphan 并存(审计 R5)。现与 doctor [10] 一致: name + location 双匹配(`c == name && index($0, loc)`), 只消费指向派生文件的那一行。
- `--produce` 模板缺失时 as_fill_template 失败留下 0 字节孤儿文件(审计 R8)。失败分支补 `rm -f`。
- `--keep` 的 `>>` 追加改 tmp+mv 原子写; index.md 首次创建的 `cat >` 同改。
**Why**: 审计 R5/R8; consume 的删除是模块最危险路径, 必须与 doctor [10] 的既有守卫一致。
**Migration**:
1. **Script (handled by step 8a — no manual work)**: `AGENTSPACE/scripts/handoff.sh` is replaced from assets.
2. **No data migration**.

### [Fix] new-plan.sh python 3.6 兼容 + index 追加原子化; new-iteration.sh 同
**What**: 两处修复:
- `PYTHONUTF8=1` 是 Python 3.7+ 特性(PEP 540), 3.6 上被忽略 — 结合 v0.4.3 导出的 `LC_ALL=C`, 3.6 系统上 CJK 标题读 stdin 抛 UnicodeDecodeError, new-plan.sh 整体中止(审计 R2, 本窗口自造回归)。现同时设 `PYTHONIOENCODING=utf-8`(3.6 亦识别), 注释更新。
- `plan/index.md` / `iterations/index.md` 的 `>>` 追加改 tmp+mv 原子写(审计 R8) — 崩溃窗口不再留下半行畸形索引行。
**Why**: 审计 R2/R8; 跨端兼容是用户硬性要求(bash 生态硬化续)。
**Migration**:
1. **Scripts (handled by step 8a — no manual work)**: `AGENTSPACE/scripts/new-plan.sh`, `AGENTSPACE/scripts/new-iteration.sh` are replaced from assets.
2. **No data migration**.

### [Fix] update-version.sh 原子写
**What**: `skills/agentspace-update/scripts/update-version.sh` 的 `.agentspace-version.json` 写入从 `cat >` 直写改为同目录 mktemp + mv 原子写(审计 R6)。崩溃窗口不再产生空 marker — 此前空文件会让 doctor [9] 静默通过(空串 grep 双跳过), status 显示 `v?` + 漂移。
**Why**: 审计 R6; 版本 marker 是升级链的锚, 静默丢失最危险。
**Migration**:
1. **Plugin-side (no workspace action)**: ships with the plugin's update flow.

### [Fix] verify-release.sh [8] 守卫 + 临时文件清理
**What**: `bilingual()` 的 awk 读取无守卫 — SKILL.md 缺失时 set -e + pipefail 裸中止且泄漏 /tmp 临时文件(v0.5.0 把作用域扩到新 skill 后暴露面变大, 审计 R8)。现每个读取失败转为显式 `[issue]` + 清理 + 计数。
**Why**: 审计 R8; 发布门禁自身必须 fail-closed 而非裸崩。
**Migration**:
1. **Dev-only (no workspace action)**: ships with the repo.

### [Addition] tests: t16-audit-regressions.sh
**What**: `tests/t16-audit-regressions.sh` 五项回归: ① complete-plan 含 `|` 结果 → plan/index.md 行完整(NF=10)且 doctor 绿; ② doctor --fix 非补零 id 活行保留、真孤儿(0999)仍删; ③ doctor [1] latest 无 --fix 只报告、--fix 才修; ④ handoff consume 重名双匹配只消费正确项; ⑤ doctor [7] --fix 插入含 `|` 主题的笔记行转义完整。
**Why**: 审计修复需要永久护栏; 每项都是可复现的旧缺陷(修复前实测失败)。
**Migration**:
1. **Dev-only (no workspace action)**: ships with the repo.

### [Addition] DEVELOPMENT.md 脚本模式纪律(方法论)
**What**: `skills/agentspace-update/DEVELOPMENT.md` 新增「Script pattern discipline」六条契约: ① as_cell 转义内容传 awk 必须 ENVIRON(禁止 -v); ② 行删除/匹配必须双条件(name+location)或先归一化 id; ③ 所有写必须原子(tmp+mv / as_atomic_write); ④ 所有 `$(...)` 读路径必须 `2>/dev/null || true`; ⑤ 只读命令不得有写路径(写必须 FIX 门控); ⑥ 新工具必须入环境闸门。
**Why**: 审计 8 项 + 同构扫描的根因是"既有正确模式未被一致复用"; 方法论契约 + t16 护栏双管齐下防再现。
**Migration**:
1. **Plugin-side (no workspace action)**: ships with the plugin.

### [Feature] status.sh 近期动态重做: 工作区事件流 + 提交摘要(不再裸列 commit)
**What**: `/agentspace-status` 的「近期动态」从"最近 10 条 commit 标题"改为"最多 10 条带日期的活动时间线", 两条数据流合并取前 10 — 按日期倒序, 同日之内按各流"新→旧"稳定排序(非字节序, 忙碌日不会丢掉最新活动; 跨流同日顺序 = 流发射顺序); 显示日期, 不按日期窗口筛选:
- **工作区事件**(索引表自带日期列, 不依赖 commit): 计划创建/完成(失败/放弃)、迭代开启/关闭、笔记新增、交接生成 — "不是 commit 的活动也是近期动态"。
- **提交摘要**: 工作区 git 提交按类型前缀映射中文摘要(plan→计划 / iteration→迭代 / notes→笔记 / handoff→交接 / update→升级 / fix→修复 / feat→功能 / docs→文档 / test→测试 / chore→杂项 / refactor→重构 / merge→合并 / release→发布 / revert→回退, 未识别前缀归"提交"), 不再列举无意义的 commit 名字。
空态由 `(无提交)` 改为 `(无动态)`; 节头 `(最近 10 条)` → `(最多 10 条)`; 所有读取守卫, 缺文件自然为空流。
**Why**: 用户反馈"近期动态仅仅是列举一些 commit 没有意义" — 动态应是活动时间线, 且 commit 至少要总结在干什么。
**Migration**:
1. **Script (handled by step 8a — no manual work)**: `AGENTSPACE/scripts/status.sh` is replaced from assets.
2. **No data migration**: t01/t15 断言与 SKILL 模板(EN/zh-CN)同步更新节头后缀。

### No structural changes
- plan/iterations/notes/utils/tests/data/examples/register/handoff schemas unchanged; no new constants; AGENTS.md 无内容操作(t13 重放表无需扩展); 全部改动为脚本行为层(近期动态重做只改 status.sh 输出, 无结构变化)。
