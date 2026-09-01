# AGENTSPACE v0.6.4

Upgrade from v0.6.3. Date: 2026-09-01

## Summary

- commit 门的记账 id 禁令从 message 扩展到**新增 diff 行**(代码注释 / 字符串字面量): 同一套 lib.sh 单源正则, 同一前导零锚定(零误报); 删除行 / 二进制 / 纯改名永不命中; rename+edit 的编辑 hunk 照扫(`-M`, diff-filter `ACMRT`)
- doctor [15] 事后审计同步扩展内容类: 每 commit 按类首命中(message / 内容 / 空标题 三类互不遮蔽), 新增行预算封顶(成本界)
- rubric skill 更名: agentspace-commit → **agentspace-code-clean**(脚本名 `commit-check.sh` 不变; 触发条件不变 — 登记仓库 commit 前)
- 发布校验: verify-release [4] 反向(lib.sh `COMMIT_*` 常量须入 architecture)+ [12] 已实现字面量守卫(自食防护)
- 行为变化: 路径规则启用改名检测(`-M` + `ACMRT`)— 改名进入阻断路径(如顶层 `wandb/`)按新路径阻断

## Changes

### [Addition] commit 门内容扫描(新增行记账 id 禁令)

- **What**: commit-check.sh 新增 "staged diff content" 段: 扫描暂存 diff 的**新增行**(`git diff --cached -M -U0 --diff-filter=ACMRT`), 命中 `COMMIT_BAN_PLAN_RE` / `COMMIT_BAN_ITER_RE`(lib.sh 单源, 经新增共享匹配器 `as_diff_added_hits`)即 BLOCK(exit 1), 报告 `文件:行号` + 摘录(80 字符; 每文件至多 5 条命中 + `+N more` 尾注)。lib.sh 新增常量 `COMMIT_EXCERPT_CAP` / `COMMIT_FILE_HITS_CAP` / `COMMIT_AUDIT_LINE_MAX`(已记入 architecture constants, 见下方 [Schema] 块)。路径规则趟同步 `-M ACMRT`。
- **Why**: 用户实证的泄漏向量 — agent 把 `plan:0001` 式记账 id 写进代码注释, 旧门只查 message, 内容畅通无阻。同一 idiom 出现在 message 与内容里是同一类泄漏; 前导零锚定在内容上同样零误报("test plan: 3 phases" 注释照常通过)。删除行永不阻断 — 清除旧泄漏永远放行(fix-forward); 二进制无文本 hunk, 纯改名无新增行, 均天然不命中。
- **Migration**: 无工作区手工操作 — scripts 由更新流程 step 8a 自动替换(handled by step 8a)。

### [Addition] doctor [15] 内容事后审计

- **What**: [15] 对窗口内(`COMMIT_AUDIT_N` 条)每个 commit 增加内容扫描(`git show -M -U0 --diff-filter=ACMRT --format=`, 同 `as_diff_added_hits`), 报告首个内容命中(`文件:行 + 摘录`); 与 message 命中、空标题并列 — **每类各报首条, 互不遮蔽**。新增行预算 `COMMIT_AUDIT_LINE_MAX=100000` 封顶(超大 patch 截断并输出 note)。路径清单趟(`git show --name-only`)同步 `-M ACMRT`。
- **Why**: 用户发现的是**已落历史**的内容泄漏 — 门只能防增量, [15] 是唯一确定性事后网(只报告, 永不改写历史)。按类首命中保证混合违规 commit 的内容面不被 message 面遮蔽(两者的处置路径不同: message = 历史改写决策; 内容 = 活代码可 fix-forward)。
- **Migration**: handled by step 8a(doctor.sh 替换)。

### [Addition] skill 更名 agentspace-commit → agentspace-code-clean

- **What**: `skills/agentspace-commit/` → `skills/agentspace-code-clean/`(SKILL.md + SKILL.zh-CN.md 同步重写): 新增 Code & Comment Rules 节(确定性层说明 + 语义层三禁: 变体拼写 / 记账叙述 / run 标识; 必须引用标准 id 的内容归 `AGENTSPACE/utils/` 或 iteration `data/`)、内容违规整改路径(改写注释使其描述改动本身 → 重新暂存 → 重新过门; 禁止把 id 变形混过正则)。触发条件与退出码协议(0/1/2/3)不变; **脚本名 `commit-check.sh` 不变** — AGENTS.md 硬规则锚定的是脚本路径而非 skill 名, 更名是表达层, 安全校验在路径引用上。
- **Why**: 门的能力从"commit 文本"长成"提交卫生(内容 + 文本)", 名字反映范围; description 保持"登记仓库 commit 前必触发"为第一分句(en/zh 双语), 防止路由漂移。
- **Migration**: 插件侧(skill 目录随插件安装)无需工作区操作。工作区 AGENTS.md 一处引用更名:
  **AGENTS.md (step 8b — 关键代码仓库节, commit 门行, 仅句尾 skill 引用替换)**:
  将整行
  ```
  - **commit 门(MUST)**: 在登记仓库执行 `git commit` 前, 必须先运行 `scripts/commit-check.sh <仓库> "<message>"` 并通过(exit 0); 未登记仓库(exit 2)先登记后提交。完整规则见 agentspace-commit skill。
  ```
  替换为
  ```
  - **commit 门(MUST)**: 在登记仓库执行 `git commit` 前, 必须先运行 `scripts/commit-check.sh <仓库> "<message>"` 并通过(exit 0); 未登记仓库(exit 2)先登记后提交。完整规则见 agentspace-code-clean skill。
  ```
  (唯一差异是句尾 skill 名; 门语义行、脚本路径一律不动。)
  **DO-NOT-TOUCH(历史记录, 严禁顺手改写)**: README Release History 的 v0.6.0 / v0.6.1 行、versions/v0.6.0–v0.6.3 档案、台账文档(iterations / plan 文档)中的旧名 — 它们记录当时的事实, 更名不追溯。

### [Fix] 发布校验与自食防护(dev-only, 不部署)

- **What**: verify-release [4] 反向(assets lib.sh 的每个 `COMMIT_*` 常量必须已记入最新 architecture constants — 原正向只查 architecture→lib 单向); 新增 [12] 已实现字面量守卫(tracked 文件不得出现已实现的标准记账 id 字面量; 排除 versions/ 档案、嵌套台账、.git/.agents/.zcode); [8] 机制短语对新增 agentspace-code-clean 双语对; t14 改为**工作树快照**(发布门在提交前运行, 负例必须针对待提交树)并新增 [12] 与 [4] 反向负例; DEVELOPMENT.md 纪律 #7(正文用 `plan:NNNN` 占位形, 测试夹具用 `printf %04d` 运行时构造); 存量测试夹具(t06 / t07 / t16 / t18 / t19)全部去字面量化。
- [4] 反向泛化到全部 lib.sh 常量, 并补记存量缺口 `WHITELIST_LARGE_BYTES`(lib 有 / architecture 无, v0.5.2 起)。
- **Why**: 本仓库自身登记在册且门无放行阀门 — 夹具 / 文档里的已实现字面量会让未来每一次编辑被自己的门堵死(v0.6.5 起无法开发), doctor [15] 也会永久报告它们; 守卫把这类漂移拦在发布门, 而不是无阀门的 commit 现场。
- **Migration**: dev-only — 无工作区操作。

### [Schema] architecture constants 增补

- **What**: constants 新增 `COMMIT_EXCERPT_CAP="80"`(内容命中摘录字符上限)、`COMMIT_FILE_HITS_CAP="5"`(门: 每文件列出命中上限)、`COMMIT_AUDIT_LINE_MAX="100000"`([15]: 每 commit 新增行预算)。
- **Why**: 脚本常量与 architecture 快照的既定契约(verify-release [4] 正反向); 上限同时是输出的有界性与审计成本界。
- **Migration**: handled by step 8c(.agentspace-architecture.json 由更新流程复制为新版快照)。
