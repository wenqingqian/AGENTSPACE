# AGENTSPACE v0.6.0

Upgrade from v0.5.3. Date: 2026-08-15

## Summary

- **关键代码仓库登记处**: 新管理态文件 `AGENTSPACE/.agentspace-repos`(一行一路径, `#` 注释合法) + 唯一写入口 `scripts/repos.sh`(`--add`/`--remove`/`--list`, 物理路径 + git toplevel 规范化, 拒绝登记 AGENTSPACE 自身)。登记/出册必须用户显式确认(规则在 skill/AGENTS.md 层)。形态语义定案: 内嵌(宿主 .gitignore 或 .git/info/exclude 豁免 AGENTSPACE/)与分开存放(树外仓库绝对路径登记); 形态是派生事实, 不存储。
- **agentspace-commit 门(新 skill + 新脚本 `scripts/commit-check.sh`)**: 登记仓库的一切 commit 前先过门(exit 0 放行 / 1 阻断 / 2 未登记)。message 禁标准记账 id `plan:0\d{3,}` / `iteration_0\d{3,}`(as_norm_id %04d 零填充形、前导 0 锚定, 整条 message、大小写不敏感; 自然文本与年份不误伤, 变体归 agent 语义层); 文件硬阻断 = `AGENTSPACE/` 路径 + 实验输出特征(`events.out.tfevents.*`、顶层 `wandb/`/`mlruns/`/`lightning_logs/`) + 单 blob ≥ 50MB; WARN(不阻断, agent 判断) = 数据/模型扩展名 ≥100KB + 顶层输出目录(runs/outputs/checkpoints/logs/results/exps/experiments)。阻断后导流: unstage → mv 进 iteration_NNNN/data/ → 建议补 .gitignore(须用户同意)。台账仓库永远豁免; 门无 --force 阀门; 不装 git hook。
- **doctor [14]/[15]**: [14] 登记一致性(行有效性 / 内嵌盾牌 git check-ignore 行为检测 / ls-files+gitlink 泄漏 / 项目根 maxdepth 2 热仓库 7 天窗口未登记告警(登记处非空才启用 — 空登记处=未选择纳入管理, 软提示在 status); 嵌套于已登记仓库内的仓库仅当父仓库以 gitlink 跟踪(真 submodule)才豁免); [15] 每登记仓库最近 20 条 commit 的 message + 触碰路径事后扫描(规则与 commit-check.sh 同源 lib.sh 常量)。[15] 永远只报告, 任何 tier 不改写历史。doctor [13] 对登记仓库内的外部引用豁免白名单语义。
- **status 多仓库**: `## 项目总览` 新增 `### 关键代码仓库` 分区(每仓库一行: name/path/分支/脏数/最新 commit/↑↓); `### 代码提交` 分区登记处驱动(每仓库 `####` 小块、最近 3 条、stat/关联反查/概括软槽不变); 登记处为空回退旧单宿主行为并标注"(未登记 …)"。
- No structural module changes(模块清单不变; 新文件均为管理态/脚本)。

## Changes

### [Addition] `.agentspace-repos` 登记处 + `scripts/repos.sh`
- **What**: 新管理态文件 `AGENTSPACE/.agentspace-repos`(种子 = 5 行注释头, 无数据行; 其中一行说明: 项目根自身(宿主)的登记行存绝对路径 — 根不在 '根内' 相对范围, 移动项目目录后该行失效, 由 doctor [14] 报告, 重新 --add 即可)与新脚本 `scripts/repos.sh`。项目根内仓库存相对路径、树外存绝对路径; 入册时 `cd -P` 物理化 + `git rev-parse --show-toplevel` 归一到仓库根。
- **Why**: 关键代码仓库此前只以散文存在于 AGENTS.md — 脚本无法消费; commit 门 / doctor / status 全部改为消费登记处。
- **Migration**:
  1. `scripts/repos.sh` 由 **step 8a** 自动部署(scripts 整体替换含新增文件, chmod +x 已覆盖)。
  2. 种子文件(8a 的 scripts/templates/.gitignore 替换不含它, 必须显式): 若 `AGENTSPACE/.agentspace-repos` 不存在, 复制 `skills/agentspace-init/assets/agentspace/.agentspace-repos` → `AGENTSPACE/.agentspace-repos`。已存在则不动。
  3. **登记回填(agent 分析 + 用户确认, 缺一不可)**:
     a. 宿主探测: `git -C AGENTSPACE/.. rev-parse --show-toplevel` 成功且 != AGENTSPACE 自身 → 向用户提议登记宿主(默认建议, 用户可拒): `bash AGENTSPACE/scripts/repos.sh --add <宿主根>`。
     b. 读根 `AGENTS.md` 的 AGENTSPACE 区块(若有仓库散文)与 `AGENTSPACE/AGENTS.md` "根仓库简介"节的散文, 提取其中提到的仓库路径, 逐个验证是 git 仓库后**逐个向用户确认**, 确认一个登记一个(`repos.sh --add`)。
     c. 用户全部拒绝 = 空登记处, 合法状态(status 回退单宿主探测, 不产生告警)。
  4. 登记后运行 `bash AGENTSPACE/scripts/repos.sh --list` 展示最终结果。

### [Feature] `scripts/commit-check.sh` commit 门
- **What**: 新脚本。用法 `commit-check.sh <repo-path> "<draft-message>"`(message 为必填参数 — 漏传即 exit 3, 绝不静默跳过 message 检查); exit 0 放行 / exit 1 阻断(打印全量违规清单) / exit 2 未登记 / exit 3 用法或前置错误(缺 message / 不在 git 工作树)。规则常量单点定义在 `lib.sh`(`COMMIT_BAN_PLAN_RE` / `COMMIT_BAN_ITER_RE` / `COMMIT_BLOCK_BYTES` / `COMMIT_WARN_BYTES` / `COMMIT_SIG_DIRS` / `COMMIT_OUT_DIRS` / `COMMIT_DATA_EXTS`)。
- **Why**: 真实观察到的两类事故 — 代码仓库 commit message 混入 plan:/iteration_ 记账 id; 程序写死输出导致实验数据被 commit。脚本层拦标准形(零误报目标), 变体与自然语言归 agent 语义层(agentspace-commit skill)。
- **Migration**: handled by step 8a(scripts 整体替换含新增文件)。

### [Feature] doctor.sh [14][15] + [13] 登记仓库豁免
- **What**: [14] key repo registry(登记行有效性/内嵌盾牌/热仓库未登记(登记处非空才启用, 嵌套仓库须父仓库 gitlink 跟踪才豁免) — 修复一律 tier-2 用户确认, --fix 不自动动登记处与宿主文件); [15] commit discipline audit(最近 20 条, 只报告); [13] 对 `as_repo_covered` 覆盖的外部引用打印 `[ok] 登记仓库内` 并跳过白名单判定。lib.sh 新增函数: `as_repo_canon` / `as_repos` / `as_repo_registered` / `as_host_root` / `as_repo_covered`。
- **Why**: 登记处需要一致性守门; 门是前置, [15] 是事后兜底网(手动 commit / agent 失守)。
- **Migration**: handled by step 8a(lib.sh / doctor.sh 整体替换)。注意: 更新后 [15] 可能对**已存在的历史违规**报红 — 这是事后审计的正常产出, 只报告, 处置由用户决定。

### [Feature] status.sh 关键代码仓库 + 多仓库代码提交
- **What**: `## 项目总览` 下新增 `### 关键代码仓库` 分区; `### 代码提交` 分区改为登记处驱动(标题 `### 代码提交 (关键代码仓库 · 每仓库最近 3 条)`, 每仓库 `#### <name> (<path>)` 小块); 登记处为空时回退旧格式 `### 代码提交 (宿主仓库 · 最近 5 条)` 并首行标注 `  (未登记 — 回退宿主仓库探测; 建议登记关键代码仓库)`。常量 `STATUS_REPO_COMMITS=3`。
- **Why**: 多仓库项目的代码动态此前只见单一宿主; 登记仓库(尤其树外仓库)完全不可见。
- **Migration**: handled by step 8a(status.sh 整体替换)。/agentspace-status skill 侧模板与子代理提示词已同步(plugin-side, 工作区无需操作)。

### [Addition] `AGENTSPACE/AGENTS.md` 关键代码仓库节 + 结构树 + 纪律(8b 精确文本)
- **What**: 工作区 AGENTS.md 三处改动。
- **AGENTS.md (step 8b — agent action, exact insertions)**(逐字执行):
  1. **插入新节**: 在 `## 结构` 行之前插入(完整文本, 逐字):

     ```markdown
     ## 关键代码仓库

     > 登记处 = `.agentspace-repos`(一行一个仓库路径: 项目根内相对路径, 树外绝对路径; 物理路径 + git toplevel 规范化)。
     > **只能由 `scripts/repos.sh` 改写**(`--add` / `--remove` / `--list`); 每次登记/出册必须用户显式确认, agent 不得自行登记。
     > AGENTSPACE 自身(台账仓库)永远豁免、永不在册。

     - **形态**: 内嵌(工作区在代码仓库内 — 宿主须经 .gitignore 或 .git/info/exclude 豁免 AGENTSPACE/, 宿主历史不出现其内容与 gitlink)或分开存放(仓库在树外, 按路径登记)。形态是派生事实, 不存储。
     - **commit 门(MUST)**: 在登记仓库执行 `git commit` 前, 必须先运行 `scripts/commit-check.sh <仓库> "<message>"` 并通过(exit 0); 未登记仓库(exit 2)先登记后提交。完整规则见 agentspace-commit skill。
     - **message**: 记账 id(plan:NNNN / iteration_NNNN)与记账叙述永不进入代码仓库 commit; 归属由 iteration readme 的宿主 SHA 记录承担。
     - **文件**: 实验产物(`events.out.tfevents.*`、顶层 wandb/mlruns/lightning_logs、≥50MB blob)阻断; 数据扩展名 ≥100KB 与顶层输出目录为 WARN(agent 结合仓库上下文判断); 阻断后导流: unstage → `mv` 进 iteration_NNNN/data/ → 建议补 .gitignore(须用户同意)。
     - **standalone 模式**: 登记仓库是工作对象, 豁免白名单语义(doctor [13] 不报违规)。
     - **审计**: doctor [14](登记一致性/内嵌盾牌/热仓库未登记)与 [15](近期 commit 事后扫描, 只报告不改历史)。
     ```

  2. **结构树**: 在 `## 结构` 代码块内 `├── register.md        ← 按需扩展模块注册表` 行之后插入:
     `├── .agentspace-repos  ← 关键代码仓库登记处(一行一路径; 只能由 scripts/repos.sh 改写)`
     并把 `└── scripts/           ← 状态流转脚本(索引与条目的唯一写入口)` 整行替换为:
     `└── scripts/           ← 状态流转与登记脚本(索引/条目/登记处的唯一写入口) + commit 检查门(commit-check.sh)`
  3. **纪律节**: 把 `- **[MUST] scripts-only**: plan.md / iterations.md / plan/index.md / iterations/index.md **只能由 scripts/ 改写**, 禁止手工编辑` 整行替换为:
     `- **[MUST] scripts-only**: plan.md / iterations.md / plan/index.md / iterations/index.md 与 .agentspace-repos **只能由 scripts/ 改写**, 禁止手工编辑`
     并在 `- **[MUST] 创建前确认**: …` 行之后插入(完整文本, 逐字):

     ```markdown
     - **[MUST] commit 门**: 登记仓库 commit 前必过 `scripts/commit-check.sh <仓库> "<message>"`(见 关键代码仓库 节); 未登记仓库先登记后提交; 登记/出册必须用户显式确认
     ```
     把 `- 只在 AGENTSPACE/ 内做 git 操作; 宿主仓库代码状态用 commit sha 记录, 需要时存 diff(对宿主 HEAD)到 data/` 整行替换为:
     `- agentspace 记账的 git 操作只在 AGENTSPACE/ 内; 代码仓库的 commit 受 commit 门约束(见 关键代码仓库 节), 代码状态用 commit sha 记录, 需要时存 diff(对宿主 HEAD)到 data/`

### [Addition] 根 AGENTS.md commit 门铁律行(8b)
- **What**: 根 AGENTS.md 的 AGENTSPACE 区块加 commit 门铁律。
- **Migration** (step 8b): 在根 `AGENTS.md` 的 `### 硬规则` 节(若根 AGENTS.md 是 init 追加的标记块, 则块内 `- 硬规则: …` 行系)中, 在"索引/条目状态只能由 scripts 改写"那条规则行之后插入一行:
  - 模板新建形态(有 `### 硬规则` 节), 插入(完整文本, 逐字):

    ```markdown
    - commit 门: 在已登记关键代码仓库(AGENTSPACE/.agentspace-repos)执行 `git commit` 前, 必须先运行 `AGENTSPACE/scripts/commit-check.sh <仓库> "<message>"` 并通过; 未登记仓库先登记(用户确认)后提交
    ```
  - 标记块形态(`<!-- AGENTSPACE -->` 块, 行为 `- 硬规则: …` 样式): `- 硬规则(commit 门): 在已登记关键代码仓库(.agentspace-repos)执行 git commit 前, 必须先运行 AGENTSPACE/scripts/commit-check.sh <仓库> "<message>" 并通过; 未登记仓库先登记后提交`
  - 用户当初拒绝了引导块且根 AGENTS.md 不是模板形态 → 本条 not-applicable, 跳过(不擅自改用户文件)。

### [Addition] plugin 侧: agentspace-commit skill + init/status/mode skill 更新
- **What**: 新增 `skills/agentspace-commit/SKILL.md` + `SKILL.zh-CN.md`(门的完整规则: 流程/message 语义层/文件规则/导流/边界); `skills/agentspace-init`(第 3 步引导块铁律行 + 第 5 步树外仓库显式询问 + 第 7 步登记动作); `skills/agentspace-status`(多仓库模板 + SHA@REPO 配对提示词); `skills/agentspace-mode`(登记仓库豁免白名单语义的 cue 行); `skills/agentspace`(纪律节 commit 门指针, 中英各一行)。
- **Why**: 门要生效必须在会话入口(引导块/日常 skill)与触发描述两层落地; init 把登记动作变成初始化流程的一等公民。
- **Migration**: plugin-side only(工作区无需操作; 工作区侧对应物 = 上方 AGENTS.md 与根 AGENTS.md 的 8b 条目)。
