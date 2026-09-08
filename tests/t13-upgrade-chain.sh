#!/usr/bin/env bash
# t13: upgrade-chain replay — synthesize a v0.1.0-era legacy workspace from the
# git history, replay every version's 8a/8b/8c migration steps exactly as the
# changelogs specify, and assert convergence (version markers, doctor green,
# the three text points GAP #1-3 fixed). A missing/unmatched changelog anchor
# fails the test — this is the guard t01-t12 + verify-release cannot provide
# (they only validate archive STRUCTURE, not the migration chain).
#
# Maintenance: when a new version adds workspace content changes (AGENTS.md
# text ops), extend the version-op table in the embedded python below.
# Note: v0.4.1-v0.4.4 share the single v0.4.1 archive (marker aliases); the
# replay table mirrors the archive chain — one version-op row per archive.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

SB="$(mktemp -d /tmp/as-test-t13-XXXXXX)" || fail "mktemp"
mkdir -p "$SB/project/AGENTSPACE"
# v0.1.0-era init assets from the git history → legacy workspace
git -C "$REPO" archive 556e00b skills/agentspace-init/assets/agentspace | tar -x -C "$SB" 2>/dev/null
[ -f "$SB/skills/agentspace-init/assets/agentspace/AGENTS.md" ] || fail "v0.1.0 assets not extractable"
cp -R "$SB/skills/agentspace-init/assets/agentspace/." "$SB/project/AGENTSPACE/"
rm -rf "$SB/skills"
CUR="$(python3 -c "import json;print(json.load(open('$REPO/skills/agentspace-init/assets/agentspace/.agentspace-version.json'))['version'])")"
[ -n "$CUR" ] || fail "current version not readable"

# replay the chain (version-op table; exits 1 on a missing/unmatched anchor)
python3 - "$SB/project/AGENTSPACE" "$REPO" "$CUR" <<'PYEOF' || fail "chain replay failed (anchor mismatch — see output above)"
import os, re, shutil, subprocess, sys
WS, REPO, CUR = sys.argv[1], sys.argv[2], sys.argv[3]
ASSET = f"{REPO}/skills/agentspace-init/assets/agentspace"
ARCH = f"{REPO}/skills/agentspace-update/versions"
LEDGER = []
def log(ver, item, status, note=""):
    LEDGER.append((ver, item, status, note))
    print(f"[{ver}] {item}: {status} {note}")
def edit(path, old, new, ver, item, must=True):
    s = open(path, encoding="utf-8").read()
    if old not in s:
        if must:
            log(ver, item, "FAILED", f"anchor missing in {path}: {old[:50]!r}")
            sys.exit(1)
        log(ver, item, "not-applicable", "anchor absent")
        return
    if s.count(old) > 1:
        log(ver, item, "FAILED", f"anchor not unique in {path}: {old[:50]!r}")
        sys.exit(1)
    open(path, "w", encoding="utf-8").write(s.replace(old, new, 1))
    log(ver, item, "applied")
def cp_asset(name, dst):
    shutil.copy2(f"{ASSET}/{name}", f"{WS}/{dst}")
    log("8a", name, "applied")

# ---------- STEP 8a: replace plugin-managed files (current assets) ----------
for f in sorted(os.listdir(f"{ASSET}/scripts")):
    shutil.copy2(f"{ASSET}/scripts/{f}", f"{WS}/scripts/{f}")
    os.chmod(f"{WS}/scripts/{f}", 0o755)
log("8a", "scripts/*.sh", "applied", f"{len(os.listdir(f'{ASSET}/scripts'))} files")
for f in sorted(os.listdir(f"{ASSET}/templates")):
    shutil.copy2(f"{ASSET}/templates/{f}", f"{WS}/templates/{f}")
log("8a", "templates/*.md", "applied")
shutil.copy2(f"{ASSET}/.gitignore", f"{WS}/.gitignore")
log("8a", ".gitignore", "applied")
shutil.copy2(f"{ASSET}/.agentspace-whitelist", f"{WS}/.agentspace-whitelist")
log("8a", ".agentspace-whitelist", "applied")

# ---------- STEP 8b: changelog items in order (exact anchors) ----------
A = f"{WS}/AGENTS.md"

# --- v0.2.0: 禁止读取 bullet ---
# Note: the 状态自检 line reword (一致性检查与修复 → 收尾后及怀疑损坏时运行) was
# introduced by commit 0743251 (v0.2.5-era), not instructed by any changelog —
# reconstructed from the canonical asset (O2, harmless: no later anchor depends
# on the old text).
edit(A, "- 状态自检: `scripts/status.sh`; 一致性检查与修复: `scripts/doctor.sh`",
        "- 状态自检: `scripts/status.sh`; 收尾后及怀疑损坏时运行 `scripts/doctor.sh`\n"
        "- **禁止读取**: 插件开发数据(`skills/agentspace-update/versions/`、`DEVELOPMENT.md`、`marketplace.json` 等)与项目无关, 禁止在项目工作中读取或引用; 这些数据仅用于插件自身开发",
        "v0.2.0", "AGENTS.md 纪律: 禁止读取 bullet")

# --- v0.2.1: data + examples modules (bullet wording per the current v0.2.1 archive) ---
os.makedirs(f"{WS}/data", exist_ok=True); os.makedirs(f"{WS}/examples", exist_ok=True)
cp_asset("data.md", "data.md"); cp_asset("examples.md", "examples.md"); cp_asset("utils.md", "utils.md")
edit(A, "├── utils.md + utils/  ← 复用工具(做图/机器状态/运行状态/日志分析等)",
        "├── data.md + data/    ← 公用数据(训练集/模型权重/软连接; 全部 gitignore)\n├── examples.md + examples/ ← 可复用实验配置(YAML/JSON); 与 tests/ 配合(脚本在 tests/, 配置在 examples/)\n├── utils.md + utils/  ← 复用工具(做图/机器状态/运行状态/日志分析等)",
        "v0.2.1", "AGENTS.md 结构树: data/examples 行")
edit(A, "### utils —— 复用工具 (utils.md + utils/)",
        "### data —— 公用数据 (data.md + data/)\n"
        "- **what**: 项目公用数据(训练集、模型权重、预处理数据等); 也可以是对其他位置的软连接\n"
        "- **when/how**: 多个实验需要同一份数据时放入 data/ 并在 data.md 登记; 大文件/权重默认 gitignore, 小型共享文件可取消注释\n\n"
        "### examples —— 实验配置 (examples.md + examples/)\n"
        "- **what**: 可复用的实验配置文件(YAML/JSON 等); 与 tests/ 配合: tests/ 放入口脚本(如何跑), examples/ 放配置(用什么参数跑)\n"
        "- **when/how**: 有可复用的实验参数/配置时放入 examples/ 并在 examples.md 登记; 测试脚本通过路径引用 examples/ 下的配置\n\n"
        "### utils —— 复用工具 (utils.md + utils/)",
        "v0.2.1", "AGENTS.md 模块节: data/examples 小节")
edit(A, "按需注册的模块登记处(例如 examples.md + examples/ 存放固定测试配置)",
        "按需注册的模块登记处(按项目需要扩展, 如 visualization.md + visualization/)",
        "v0.2.1", "AGENTS.md register 描述")

# --- v0.2.3: iteration redefinition ---
edit(A, "├── iterations/        ← index.md(全量索引) + latest 软连接 + iteration_NNNN/{readme.md, data/}",
        "├── iterations/        ← index.md(全量索引) + latest 软连接 + iteration_NNNN/{readme.md, data/(实验产物+代码diff)}",
        "v0.2.3", "AGENTS.md 结构树: iterations 行")
edit(A, "### iterations —— 实验轮次 (iterations.md + iterations/)\n"
        "- **what**: 一轮实验/迭代的完整记录(readme + data/); **每个 iteration 必属且仅属一个 plan**, 一个 plan 可含多个 iteration\n"
        "- **when**: 开始一轮新的实验尝试/评估时创建; 结果落盘且 readme 完成时关闭\n"
        "- **how**: `scripts/new-iteration.sh <plan-id> \"本轮内容\"` → 工作并及时更新 readme → `scripts/close-iteration.sh <id> \"结果\"`\n"
        "- **data 收集三策略** (产物全量放入 iteration_NNNN/data/, 该目录已被 gitignore):\n"
        "  1. 程序支持设置 output 位置 → 直接指向 `iteration_NNNN/data/`\n"
        "  2. 支持重定向 → `cmd > iteration_NNNN/data/xxx.log`\n"
        "  3. fallback → 在工作区找到本轮产出的结果文件, `mv` 进 `iteration_NNNN/data/`",
        "### iterations —— 代码变更迭代 (iterations.md + iterations/)\n"
        "- **what**: 实现 plan 过程中的一次**代码/仓库状态变更**(递进关系, 一轮接一轮); 常伴随实验验证, 所以有 readme + data/; **每个 iteration 必属且仅属一个 plan**, 一个 plan 可含多个 iteration\n"
        "- **when**: 在 plan 内推进一个有意义的代码变更时创建; 简单改动不建 iteration; 创建前须与用户确认; 结果落盘且 readme 完成时关闭\n"
        "- **how**: `scripts/new-iteration.sh <plan-id> \"本轮内容\"` → 工作并及时更新 readme → `scripts/close-iteration.sh <id> \"结果\"`\n"
        "- **代码 diff**: readme\"环境\"节记录宿主仓库起始/结束 commit sha; 有关键代码变更时把 `git diff <起始>..<结束>` 存到 `iteration_NNNN/data/`\n"
        "- **data 收集三策略** (实验产物全量放入 iteration_NNNN/data/, 该目录已被 gitignore):\n"
        "  1. 程序支持设置 output 位置 → 直接指向 `iteration_NNNN/data/`\n"
        "  2. 支持重定向 → `cmd > iteration_NNNN/data/xxx.log`\n"
        "  3. fallback → 在工作区找到本轮产出的结果文件, `mv` 进 `iteration_NNNN/data/`",
        "v0.2.3", "AGENTS.md 模块节: iterations 小节")

# --- v0.2.5: 纪律 restructure ---
edit(A, "## 纪律\n\n"
        "- plan.md / iterations.md / plan/index.md / iterations/index.md **只能由 scripts/ 改写**, 禁止手工编辑\n"
        "- 内容文档(plan 文档 / iteration readme / notes / utils / tests)由 agent 直接撰写, 使用 templates/ 模板\n"
        "- 相互引用一律用 id: `plan:NNNN` / `iteration_NNNN`; 不用路径, 不用 latest(latest 会翻转)\n"
        "- **里程碑 git 提交**: plan 创建/完成、iteration 创建/关闭、模块注册、重要文档更新 → `git -C AGENTSPACE add -A && commit`, 并告知用户\n"
        "- 只在 AGENTSPACE/ 内做 git 操作; 宿主仓库代码状态用 commit sha 记录, 需要时存 diff(对宿主 HEAD)到 data/\n",
        "## 纪律\n\n"
        "规则分级: `[MUST]` 违反会造成损坏/不可逆; `[SHOULD]` 最佳实践; `[MAY]` 可选。\n\n"
        "- **[MUST] scripts-only**: plan.md / iterations.md / plan/index.md / iterations/index.md **只能由 scripts/ 改写**, 禁止手工编辑\n"
        "- **[MUST] 创建前确认**: plan / iteration 创建前必须经用户明确确认; 简单改动不建 plan/iteration\n"
        "- **[MUST] 收尾协议**: 结束项目工作前依次执行 — ① 更新进行中 readme 的\"当前状态 · 下一步\" ② 运行 `scripts/doctor.sh`(硬错误必须解决, 告警报告用户) ③ 里程碑提交\n"
        "- **[MUST] 脚本报错恢复**: 报错时禁止自行手工编辑表格; 先跑 `scripts/doctor.sh` 定位, 修复方案与用户确认; **经用户明确确认的一次性手工修复是唯一合法例外**\n"
        "- 内容文档(plan 文档 / iteration readme / notes / utils / tests)由 agent 直接撰写, 使用 templates/ 模板\n"
        "- 相互引用一律用 id: `plan:NNNN` / `iteration_NNNN`; 不用路径, 不用 latest(latest 会翻转)\n"
        "- **里程碑 git 提交**(具体触发点): plan 创建/完成 · iteration 创建/关闭 · 模块注册 · notes 写入 · tests.md 环境变更 · examples/data 登记 · update 应用 → `git -C AGENTSPACE add -A && commit`, 并告知用户\n"
        "- 只在 AGENTSPACE/ 内做 git 操作; 宿主仓库代码状态用 commit sha 记录, 需要时存 diff(对宿主 HEAD)到 data/\n",
        "v0.2.5", "AGENTS.md 纪律重构")

# --- v0.2.7: notes 标签 column + when/how bullet (archive now instructs both) ---
edit(A, "- **when/how**: plan 完成产出可迁移教训、或发现坑时立即记录; 每条笔记必须带\"来源\"(plan:NNNN / iteration_NNNN); 模板 templates/note.md",
        "- **when/how**: plan 完成时回顾 iterations 提炼教训、或发现坑时立即记录; 每条笔记必须带\"来源\"(plan:NNNN / iteration_NNNN); 建议打主题\"标签\"便于检索聚合; 模板 templates/note.md",
        "v0.2.7", "AGENTS.md notes when/how bullet(GAP #2 档案指令)")
edit(f"{WS}/notes.md", "| 主题 | 一句话结论 | 来源 | 日期 | 链接 |\n| --- | --- | --- | --- | --- |",
        "| 主题 | 标签 | 一句话结论 | 来源 | 日期 | 链接 |\n| --- | --- | --- | --- | --- | --- |",
        "v0.2.7", "notes.md 表头 6 列")

# --- v0.2.8: entry-file guidance rows ---
cp_asset("data.md", "data.md"); cp_asset("examples.md", "examples.md"); cp_asset("utils.md", "utils.md")

# --- v0.2.12: notes 回链 clause ---
edit(A, "- **when/how**: plan 完成时回顾 iterations 提炼教训、或发现坑时立即记录; 每条笔记必须带\"来源\"(plan:NNNN / iteration_NNNN); 建议打主题\"标签\"便于检索聚合; 模板 templates/note.md",
        "- **when/how**: plan 完成时回顾 iterations 提炼教训、或发现坑时立即记录; 每条笔记必须带\"来源\"(plan:NNNN / iteration_NNNN); 由 iteration 提炼的笔记在\"详情\"中回链该 iteration 的 readme; 建议打主题\"标签\"便于检索聚合; 模板 templates/note.md",
        "v0.2.12", "AGENTS.md notes when/how 回链子句")

# --- v0.4.0: handoff module (structure-tree templates line now instructed) ---
os.makedirs(f"{WS}/handoff", exist_ok=True)
shutil.copy2(f"{ASSET}/handoff/index.md", f"{WS}/handoff/index.md")
log("v0.4.0", "handoff/index.md", "applied")
TMPL = "├── templates/         ← 文档模板(plan / iteration-readme / module-entry / note)"
edit(A, TMPL,
        "├── handoff/           ← 一次性会话交接文件 + index.md(由 scripts/handoff.sh 维护, 文件不入 git)\n" + TMPL,
        "v0.4.0", "AGENTS.md 结构树: handoff 行")
edit(A, TMPL,
        "├── templates/         ← 文档模板(plan / iteration-readme / module-entry / note / handoff)",
        "v0.4.0", "AGENTS.md 结构树: templates 行追加 / handoff(GAP #1 档案指令)")
edit(A, "### register —— 按需扩展模块 (register.md)\n"
        "- **what**: 按需注册的模块登记处(按项目需要扩展, 如 visualization.md + visualization/)\n"
        "- **how**: 先与用户确认 → `scripts/register-module.sh <name> \"用途\"`\n",
        "### register —— 按需扩展模块 (register.md)\n"
        "- **what**: 按需注册的模块登记处(按项目需要扩展, 如 visualization.md + visualization/)\n"
        "- **how**: 先与用户确认 → `scripts/register-module.sh <name> \"用途\"`\n\n"
        "### handoff —— 一次性会话交接 (handoff/)\n"
        "- **what**: 会话结束时生成的一次性上下文快照, 新会话读取后即销毁(consume); 支持多个 handoff 并存, index.md 登记 name/description/location/time\n"
        "- **when**: 关闭会话前收尾时(任何情况都可用, 不要求有进行中 plan); 新会话开始时消费\n"
        "- **how**: `/agentspace-handoff-produce [--name <名>] [--description <说明>]` → 填充内容 → 新会话 `/agentspace-handoff-consume --name <名> [--keep]`; 所有写操作经 `scripts/handoff.sh`(名字冲突会拒绝, 不会自动加后缀)\n",
        "v0.4.0", "AGENTS.md 模块节: handoff 小节")
edit(A, "2. 任务相关时读 plan.md; 会话续接时读 `iterations/latest/readme.md` 的\"当前状态 · 下一步\"",
        "2. 任务相关时读 plan.md; 会话续接时: 有 handoff 先读 `handoff/index.md` 选最新并 consume, 否则读 `iterations/latest/readme.md` 的\"当前状态 · 下一步\"",
        "v0.4.0", "AGENTS.md 读取规则 2")

# --- v0.4.1: data bullet wording sync (GAP #3) ---
edit(A, "- **when/how**: 多个实验需要同一份数据时放入 data/ 并在 data.md 登记; 大文件/权重默认 gitignore, 小型共享文件可取消注释",
        "- **when/how**: 多个实验需要同一份数据时放入 data/ 并在 data.md 登记; data/ 全部 gitignore(与 .gitignore 行为一致, 无 opt-out)",
        "v0.4.1", "AGENTS.md data bullet 措辞同步")

# --- v0.5.2: agentspace mode block (default hybrid, before 项目简介) ---
edit(A, "## 项目简介",
        "## agentspace mode\nhybrid\n\n## 项目简介",
        "v0.5.2", "AGENTS.md 模式标记块")

# --- v0.6.0: key-repo registry seed (8a) + AGENTS.md 关键代码仓库节/结构树/纪律 (8b) ---
if not os.path.exists(f"{WS}/.agentspace-repos"):
    shutil.copy2(f"{ASSET}/.agentspace-repos", f"{WS}/.agentspace-repos")
    log("v0.6.0", ".agentspace-repos seed", "applied")
SEC = '''## 关键代码仓库

> 登记处 = `.agentspace-repos`(一行一个仓库路径: 项目根内相对路径, 树外绝对路径; 物理路径 + git toplevel 规范化)。
> **只能由 `scripts/repos.sh` 改写**(`--add` / `--remove` / `--list`); 每次登记/出册必须用户显式确认, agent 不得自行登记。
> AGENTSPACE 自身(台账仓库)永远豁免、永不在册。

- **形态**: 内嵌(工作区在代码仓库内 — 宿主须经 .gitignore 或 .git/info/exclude 豁免 AGENTSPACE/, 宿主历史不出现其内容与 gitlink)或分开存放(仓库在树外, 按路径登记)。形态是派生事实, 不存储。
- **commit 门(MUST)**: 在登记仓库执行 `git commit` 前, 必须先运行 `scripts/commit-check.sh <仓库> "<message>"` 并通过(exit 0); 未登记仓库(exit 2)先登记后提交。完整规则见 agentspace-commit skill。
- **message**: 记账 id(plan:NNNN / iteration_NNNN)与记账叙述永不进入代码仓库 commit; 归属由 iteration readme 的宿主 SHA 记录承担。
- **文件**: 实验产物(`events.out.tfevents.*`、顶层 wandb/mlruns/lightning_logs、≥50MB blob)阻断; 数据扩展名 ≥100KB 与顶层输出目录为 WARN(agent 结合仓库上下文判断); 阻断后导流: unstage → `mv` 进 iteration_NNNN/data/ → 建议补 .gitignore(须用户同意)。
- **standalone 模式**: 登记仓库是工作对象, 豁免白名单语义(doctor [13] 不报违规)。
- **审计**: doctor [14](登记一致性/内嵌盾牌/热仓库未登记)与 [15](近期 commit 事后扫描, 只报告不改历史)。

'''
edit(A, "## 结构", SEC + "## 结构",
        "v0.6.0", "AGENTS.md 关键代码仓库节(结构节前插入)")
REG_LINE = "├── register.md        ← 按需扩展模块注册表"
edit(A, REG_LINE,
        REG_LINE + "\n├── .agentspace-repos  ← 关键代码仓库登记处(一行一路径; 只能由 scripts/repos.sh 改写)",
        "v0.6.0", "AGENTS.md 结构树: 登记处行")
edit(A, "└── scripts/           ← 状态流转脚本(索引与条目的唯一写入口)",
        "└── scripts/           ← 状态流转与登记脚本(索引/条目/登记处的唯一写入口) + commit 检查门(commit-check.sh)",
        "v0.6.0", "AGENTS.md 结构树: scripts 行")
edit(A, "- **[MUST] scripts-only**: plan.md / iterations.md / plan/index.md / iterations/index.md **只能由 scripts/ 改写**, 禁止手工编辑",
        "- **[MUST] scripts-only**: plan.md / iterations.md / plan/index.md / iterations/index.md 与 .agentspace-repos **只能由 scripts/ 改写**, 禁止手工编辑",
        "v0.6.0", "AGENTS.md 纪律: scripts-only 行")
CREATE_LINE = "- **[MUST] 创建前确认**: plan / iteration 创建前必须经用户明确确认; 简单改动不建 plan/iteration"
edit(A, CREATE_LINE,
        CREATE_LINE + "\n- **[MUST] commit 门**: 登记仓库 commit 前必过 `scripts/commit-check.sh <仓库> \"<message>\"`(见 关键代码仓库 节); 未登记仓库先登记后提交; 登记/出册必须用户显式确认",
        "v0.6.0", "AGENTS.md 纪律: commit 门行")
edit(A, "- 只在 AGENTSPACE/ 内做 git 操作; 宿主仓库代码状态用 commit sha 记录, 需要时存 diff(对宿主 HEAD)到 data/",
        "- agentspace 记账的 git 操作只在 AGENTSPACE/ 内; 代码仓库的 commit 受 commit 门约束(见 关键代码仓库 节), 代码状态用 commit sha 记录, 需要时存 diff(对宿主 HEAD)到 data/",
        "v0.6.0", "AGENTS.md 纪律: git 操作行")

# --- v0.6.4: gate scope grew to committed content; the rubric skill renamed
#     (agentspace-commit → agentspace-code-clean). The script name
#     commit-check.sh is unchanged; the AGENTS.md bullet only delegates, so the
#     sole text op is the trailing skill reference swap. ---
edit(A, "完整规则见 agentspace-commit skill。", "完整规则见 agentspace-code-clean skill。",
     "v0.6.4", "AGENTS.md commit 门行: skill 引用更名")

# --- v1.0.0: AGENTS.md 纪律 gains the parallel-workspace bullet (8b). The bullet
#     text is read from the canonical asset at replay time — inlining a copy here
#     would be a second source of truth that can silently drift. ---
PAR_BULLET = [l for l in open(f"{ASSET}/AGENTS.md").read().splitlines()
              if l.startswith("- **[MUST] 并行工作区约定**")][0]
GATE_LINE = '- **[MUST] commit 门**: 登记仓库 commit 前必过 `scripts/commit-check.sh <仓库> "<message>"`(见 关键代码仓库 节); 未登记仓库先登记后提交; 登记/出册必须用户显式确认'
edit(A, GATE_LINE, GATE_LINE + "\n" + PAR_BULLET,
     "v1.0.0", "AGENTS.md 纪律: 并行工作区约定行")

# --- v1.1.0: AGENTS.md 用户规则 split (8b). Exact line text is read from the
#     canonical asset at replay time — inlining a copy here would be a second
#     source of truth that can silently drift. The replayed 纪律 section holds
#     only built-in lines (every earlier op inserted asset text), so per
#     changelog Step 3 the split migration has nothing to move. ---
al = open(f"{ASSET}/AGENTS.md").read().splitlines()
guard = [l for l in open(A, encoding="utf-8").read().splitlines()
         if l.startswith("- **[MUST] 脚本报错恢复**")][0]
m1 = [l for l in al if l.startswith("- **[MUST] 用户规则守护**")][0]
# the 注释卫生 line is pinned inline, NOT sourced from the live asset —
# v1.4.0 renames it to 代码卫生 in the asset, so live sourcing would find
# nothing; the pinned text is the v1.1.0-era original the later v1.4.0 op
# transforms (same inline pattern as the other historical ops below).
m2 = ("- **[MUST] 注释卫生**: 注释只描述代码意图与约束, 禁止过程叙述(写作日期、所用工具/skill、"
      "记账与会话上下文); 违规由 commit 门语义层与 code-clean 审查报出, 修复由用户驱动")
edit(A, guard, guard + "\n" + m1 + "\n" + m2,
     "v1.1.0", "AGENTS.md 纪律: 用户规则守护/注释卫生行")
# milestone trigger token: the changelog pins the substring swap
wl = open(A, encoding="utf-8").read().splitlines()
ms_old = [l for l in wl if l.startswith("- **里程碑 git 提交**")][0]
ms_new = ms_old.replace("examples/data 登记 · update 应用",
                        "examples/data 登记 · 用户规则写入 · update 应用")
if ms_new == ms_old:
    log("v1.1.0", "AGENTS.md 里程碑行: 用户规则写入触发词", "FAILED", "substring not found")
    sys.exit(1)
edit(A, ms_old, ms_new, "v1.1.0", "AGENTS.md 里程碑行: 用户规则写入触发词")
# append the user-owned section verbatim (asset heading to EOF, placeholder
# intact) after the current last line — per changelog Step 4
uidx = al.index("## 用户规则")
USER_SEC = "\n".join(al[uidx:])
wl = open(A, encoding="utf-8").read().splitlines()
edit(A, wl[-1], wl[-1] + "\n\n" + USER_SEC,
     "v1.1.0", "AGENTS.md: 用户规则节追加")

# --- v1.3.0: exp module (8a scripts/templates/.gitignore already applied as
#     current assets above; here: new entry files + dirs + AGENTS.md/examples.md
#     8b ops per the v1.3.0 changelog) ---
for d in ("todo", "doing", "done"):
    os.makedirs(f"{WS}/exp/{d}", exist_ok=True)
    open(f"{WS}/exp/{d}/.gitkeep", "w").close()
cp_asset("exp.md", "exp.md")
cp_asset("exp/index.md", "exp/index.md")
edit(A, "├── data.md + data/    ← 公用数据(训练集/模型权重/软连接; 全部 gitignore)",
        "├── exp.md             ← exp 入口视图 (Todo + Doing + 最近完成 10 条)\n"
        "├── exp/               ← index.md(全量索引) + todo/ + doing/ + done/ + exp_data/exp_NNNN/(完整实验记录, 不入 git)\n"
        "├── data.md + data/    ← 公用数据(训练集/模型权重/软连接; 全部 gitignore)",
        "v1.3.0", "AGENTS.md 结构树: exp 行")
edit(A, "├── examples.md + examples/ ← 可复用实验配置(YAML/JSON); 与 tests/ 配合(脚本在 tests/, 配置在 examples/)",
        "├── examples.md + examples/ ← 可复用实验配置(YAML/JSON); exp_spec/exp_NNNN/ 为登记实验的专属配置位",
        "v1.3.0", "AGENTS.md 结构树: examples 行")
edit(A, "├── templates/         ← 文档模板(plan / iteration-readme / module-entry / note / handoff)",
        "├── templates/         ← 文档模板(plan / iteration-readme / exp-manual / module-entry / note / handoff)",
        "v1.3.0", "AGENTS.md 结构树: templates 行")
edit(A, "### data —— 公用数据 (data.md + data/)",
        "### exp —— 实验记录 (exp.md + exp/)\n"
        "- **what**: 独立登记的实验(度量/验证/调研)。分工: plan 管\"为什么/做什么\", iteration 管\"改代码\", exp 管\"测代码\"; exp 可不关联 plan/iteration(纯度量/调研实验), 关联时经索引的 关联 plan / 关联 iteration 列记录(agentspace-exp 即本模块工作流的称谓, 非斜杠命令)\n"
        "- **when**: **用户显式要求走 agentspace-exp, 或 agent 在用户提到要做实验时提议并经用户确认**; 开发收尾的正确性验证等常规实验默认不登记(除非用户确认); 登记前的设计对齐走 agentspace-better-exp skill\n"
        "- **how**: `scripts/new-exp.sh \"标题\" [--plan NNNN] [--iteration NNNN]` → 实验配置**必须**写入 `examples/exp_spec/exp_NNNN/`(脚本预创建) → 运行与结果**全量**落 `exp/exp_data/exp_NNNN/`(关联 iteration 的 data/ 产物复制一份至此; 该目录不入 git, 为本机权威记录) → `scripts/start-exp.sh <id>`(开跑, todo→doing; 小实验可省略) → `scripts/complete-exp.sh <id> <done|failed|abandoned> \"结果\" [--commit \"仓库名@sha,...\"]`\n"
        "- **commits 语义**: exp 记录测试用关键仓库的 commit **点**(repo@sha, 关闭时落定), 与 iteration 的 commit 窗口(起始/结束)互补; 报告与作图走 agentspace-better-exp-report skill\n\n"
        "### data —— 公用数据 (data.md + data/)",
        "v1.3.0", "AGENTS.md 模块节: exp 小节")
edit(A, "- **when/how**: 有可复用的实验参数/配置时放入 examples/ 并在 examples.md 登记; 测试脚本通过路径引用 examples/ 下的配置",
        "- **when/how**: 有可复用的实验参数/配置时放入 examples/ 并在 examples.md 登记; 测试脚本通过路径引用 examples/ 下的配置\n"
        "- **exp_spec 契约**: 所有经 agentspace-exp 登记的实验, 其配置必须写入 `examples/exp_spec/exp_NNNN/`(由 new-exp.sh 预创建, 关闭时空目录会被 complete-exp.sh 拒绝); 该子树由 exp/index.md 的配置列索引, 不在 examples.md 登记",
        "v1.3.0", "AGENTS.md examples 小节: exp_spec 契约行")
edit(A, "每条笔记必须带\"来源\"(plan:NNNN / iteration_NNNN)",
        "每条笔记必须带\"来源\"(plan:NNNN / iteration_NNNN / exp_NNNN)",
        "v1.3.0", "AGENTS.md notes 小节: exp 来源")
edit(A, "- 内容文档(plan 文档 / iteration readme / notes / utils / tests)由 agent 直接撰写, 使用 templates/ 模板",
        "- 内容文档(plan 文档 / iteration readme / exp 手册 / notes / utils / tests)由 agent 直接撰写, 使用 templates/ 模板",
        "v1.3.0", "AGENTS.md 纪律: 内容文档行")
edit(A, "- **[MUST] scripts-only**: plan.md / iterations.md / plan/index.md / iterations/index.md 与 .agentspace-repos **只能由 scripts/ 改写**, 禁止手工编辑",
        "- **[MUST] scripts-only**: plan.md / iterations.md / exp.md / plan/index.md / iterations/index.md / exp/index.md 与 .agentspace-repos **只能由 scripts/ 改写**, 禁止手工编辑",
        "v1.3.0", "AGENTS.md 纪律: scripts-only 行")
edit(A, "- **[MUST] 创建前确认**: plan / iteration 创建前必须经用户明确确认; 简单改动不建 plan/iteration",
        "- **[MUST] 创建前确认**: plan / iteration 创建前必须经用户明确确认; 简单改动不建 plan/iteration。exp 只在用户显式要求走 agentspace-exp、或 agent 提议并经用户确认后创建; 开发收尾的正确性验证等常规实验默认不建 exp(agent 最多提议一次, 用户未确认不登记)",
        "v1.3.0", "AGENTS.md 纪律: 创建前确认行")
edit(A, "- 相互引用一律用 id: `plan:NNNN` / `iteration_NNNN`; 不用路径, 不用 latest(latest 会翻转)",
        "- 相互引用一律用 id: `plan:NNNN` / `iteration_NNNN` / `exp_NNNN`; 不用路径, 不用 latest(latest 会翻转)",
        "v1.3.0", "AGENTS.md 纪律: 相互引用行")
ms = open(A, encoding="utf-8").read()
if ms.count("iteration 创建/关闭 · 模块注册") != 1:
    log("v1.3.0", "AGENTS.md 里程碑行: exp 触发词", "FAILED", "anchor not unique")
    sys.exit(1)
edit(A, "iteration 创建/关闭 · 模块注册", "iteration 创建/关闭 · exp 创建/完成 · 模块注册",
     "v1.3.0", "AGENTS.md 里程碑行: exp 触发词")
edit(A, "2. 任务相关时读 plan.md; 会话续接时: 有 handoff 先读 `handoff/index.md` 选最新并 consume, 否则读 `iterations/latest/readme.md` 的\"当前状态 · 下一步\"",
        "2. 任务相关时读 plan.md(有登记实验时读 exp.md); 会话续接时: 有 handoff 先读 `handoff/index.md` 选最新并 consume, 否则读 `iterations/latest/readme.md` 的\"当前状态 · 下一步\"",
        "v1.3.0", "AGENTS.md 读取规则 2")
edit(f"{WS}/examples.md", "> tests/ 放入口脚本(如何跑), examples/ 放配置(用什么参数跑)。",
        "> tests/ 放入口脚本(如何跑), examples/ 放配置(用什么参数跑)。\n> exp_spec 子树除外: 所有经 agentspace-exp 登记的实验, 其配置必须写入 `examples/exp_spec/exp_NNNN/`(由 new-exp.sh 预创建); 该子树由 exp/index.md 的配置列索引, 不在本表登记。",
        "v1.3.0", "examples.md: exp_spec 说明行")

# --- v1.3.1: exp 模块触发器措辞 (8b per the v1.3.1 changelog — agentspace-exp
#     becomes a command+skill trigger, no longer a bare workflow name) ---
edit(A, "(agentspace-exp 即本模块工作流的称谓, 非斜杠命令)",
        "(agentspace-exp 是本模块的触发器 — `/agentspace-exp` 命令 + 同名 skill, 持有登记门与生命周期; 设计对齐/报告由 better-exp 系列两个正式 skill 承担)",
        "v1.3.1", "AGENTS.md exp 模块: what 行触发器表述")
edit(A, "- **when**: **用户显式要求走 agentspace-exp, 或 agent 在用户提到要做实验时提议并经用户确认**; 开发收尾的正确性验证等常规实验默认不登记(除非用户确认); 登记前的设计对齐走 agentspace-better-exp skill",
        "- **when**: **用户显式要求走 /agentspace-exp, 或 agent 在用户提到要做实验时提议一次并经用户确认**; 开发收尾的正确性验证等常规实验默认不登记(除非用户确认); 登记前的设计对齐走 agentspace-better-exp skill",
        "v1.3.1", "AGENTS.md exp 模块: when 行 /agentspace-exp")
edit(A, "exp 只在用户显式要求走 agentspace-exp、或 agent 提议并经用户确认后创建",
        "exp 只在用户显式要求走 /agentspace-exp、或 agent 提议并经用户确认后创建",
        "v1.3.1", "AGENTS.md 纪律: 创建前确认行 /agentspace-exp")

# --- v1.4.0: code-clean 内置为 AGENTS.md 规则 (8b per the v1.4.0 changelog — the
#     passive layer becomes the default requirement, active cleanup stays
#     explicit-only) ---
edit(A, "未登记仓库(exit 2)先登记后提交。完整规则见 agentspace-code-clean skill。",
        "未登记仓库(exit 2)先登记后提交。commit 门与全部代码/注释/commit 文本卫生规则见 agentspace-code-clean skill(被动层默认生效; 主动清理既有代码/历史仅经用户显式要求)。",
        "v1.4.0", "AGENTS.md 关键代码仓库: commit 门行两层表述")
edit(A, "- **[MUST] 注释卫生**: 注释只描述代码意图与约束, 禁止过程叙述(写作日期、所用工具/skill、记账与会话上下文); 违规由 commit 门语义层与 code-clean 审查报出, 修复由用户驱动",
        "- **[MUST] 代码卫生**: 登记仓库内写入的代码、注释与 commit 文本默认遵循 agentspace-code-clean 被动层规则 — 注释只描述代码意图与约束, 禁止过程叙述(写作日期、所用工具/skill、记账与会话上下文), 禁止 why-not-alternative 反馈残留与测试实例引用; 违规由 commit 门语义层与 code-clean 审查报出, 修复由用户驱动; 既有代码/历史的清理与重建仅在用户显式要求时按该 skill 的 CLEANUP 流程执行",
        "v1.4.0", "AGENTS.md 纪律: 注释卫生升级为代码卫生")

# ---------- STEP 8c: version markers ----------
r = subprocess.run(f"cd {WS} && bash {REPO}/skills/agentspace-update/scripts/update-version.sh {CUR}",
                   shell=True, capture_output=True, text=True)
if r.returncode != 0:
    log("8c", f"update-version.sh {CUR}", "FAILED", r.stdout.strip())
    sys.exit(1)
log("8c", f"update-version.sh {CUR}", "applied")
shutil.copy2(f"{ARCH}/v{CUR}/architecture.json", f"{WS}/.agentspace-architecture.json")
log("8c", ".agentspace-architecture.json", "applied", CUR)

print("\n===== LEDGER =====")
for ver, item, status, note in LEDGER:
    print(f"{ver}\t{item}\t{status}\t{note}")
PYEOF

WS="$SB/project/AGENTSPACE"
# --- convergence assertions (the three GAP text points) ---
assert_contains "$WS/AGENTS.md" "module-entry / note / handoff"          # GAP #1: templates 行
assert_contains "$WS/AGENTS.md" "回链该 iteration 的 readme"               # GAP #2: 回链子句
assert_contains "$WS/AGENTS.md" '建议打主题"标签"'                          # GAP #2: 标签子句
assert_contains "$WS/AGENTS.md" "data/ 全部 gitignore(与 .gitignore 行为一致"  # GAP #3: data bullet(唯一子串)
assert_contains "$WS/.agentspace-version.json" "\"version\": \"$CUR\""
assert_contains "$WS/.agentspace-architecture.json" "\"version\": \"$CUR\""
assert_contains "$WS/AGENTS.md" "## agentspace mode"
assert_contains "$WS/AGENTS.md" "hybrid"
assert_contains "$WS/AGENTS.md" "## 关键代码仓库"
assert_contains "$WS/AGENTS.md" "commit 检查门(commit-check.sh)"
assert_contains "$WS/AGENTS.md" "agentspace-code-clean skill"        # v0.6.4 rename swap
assert_not_contains "$WS/AGENTS.md" "agentspace-commit"              # v0.6.4: no stale reference survives
assert_contains "$WS/AGENTS.md" "并行工作区约定"                        # v1.0.0: 纪律 bullet (8b)
assert_contains "$WS/AGENTS.md" "用户规则守护"                          # v1.1.0: 纪律 MUST (8b)
assert_contains "$WS/AGENTS.md" "## 用户规则"                          # v1.1.0: user-owned section (8b)
[ -f "$WS/.agentspace-repos" ] || fail ".agentspace-repos seed missing after v0.6.0 replay"
[ -f "$WS/scripts/repos.sh" ] && [ -f "$WS/scripts/commit-check.sh" ] \
  || fail "v0.6.0 scripts missing after 8a"
[ -f "$WS/.agentspace-whitelist" ] || fail "whitelist file missing after 8a"
# --- final byte-diff vs the canonical asset (normalized: HTML comment blocks
#     are init-time user content, not part of the migration chain) — catches
#     any future drift in the changelog archives or this table (R2) ---
if ! diff -q <(awk '/^<!--/{c=1} c&&/-->/ {c=0; next} !c' "$WS/AGENTS.md") \
             <(awk '/^<!--/{c=1} c&&/-->/ {c=0; next} !c' "$REPO/skills/agentspace-init/assets/agentspace/AGENTS.md") >/dev/null; then
  diff <(awk '/^<!--/{c=1} c&&/-->/ {c=0; next} !c' "$WS/AGENTS.md") \
       <(awk '/^<!--/{c=1} c&&/-->/ {c=0; next} !c' "$REPO/skills/agentspace-init/assets/agentspace/AGENTS.md") | head -20
  fail "replayed AGENTS.md 与规范资产不一致(链漂移或档案漂移, 见上方 diff)"
fi
assert_ok bash "$WS/scripts/doctor.sh"

rm -rf "$SB"
echo "PASS t13"
