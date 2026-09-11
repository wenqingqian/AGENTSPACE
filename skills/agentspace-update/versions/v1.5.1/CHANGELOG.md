# AGENTSPACE v1.5.1

Upgrade from v1.5.0. Date: 2026-09-11

## Summary

- **结果门改内容判据**: close-iteration / complete-plan / complete-exp 的"结果已填"门不再按模板注释是否存在判断, 改为判节内**非注释内容** — 填写时保留指导注释是正常写法, 旧门会把这视为未填(实测同一陷阱六连咬); 纯注释空节仍拒绝, 错误信息指明节名与"注释不算内容"。
- **里程碑 commit 边界由脚本钉定**: 七个流转脚本(new-plan / new-iteration / close-iteration / complete-plan / new-exp / start-exp / complete-exp)在内容工作完成后(提示行置于脚本输出末位 — 教训提炼等同 commit 同一里程碑)打印 `Next [MUST]: ledger-commit now` 与**它刚触碰的精确路径清单**(lib.sh 新增 `as_commit_hint`; 命令钉 `git -C <工作区绝对路径>` 并带建议 `-m` 消息, 任意 cwd 可粘贴, 并行泳道下正是逐路径 add 的输入) — 折叠 commit / reset --soft 重拆 / 创建侧漏提交三类事故的根因是"提交边界只活在 agent 记忆里"。
- **commit 门补两缺口**: 暂存为空时由"空转 PASS"改为前置错误(exit 3, 位于 message 扫描之后 — 带违禁 message 的空暂存仍报 BLOCKED exit 1; 纯删除暂存计为有效暂存, 不误伤 `git rm` 型提交); 新增 `--commit` 模式, 过门后以 `--cleanup=verbatim` **提交刚校验的 message** 并回显落库 sha+标题, 结构性消除"过门文案 ≠ 提交文案"的走样(hook 仍照常运行; 列出的候选行不是阻断, --commit 会带着候选提交, 裁决属调用方)。
- **handoff consume 先读后毁**: 消费时先把快照全文 dump 到 stdout 再删文件与索引行(快照不入 git, 先删后打印 = 内容不可恢复)。
- **小项**: new-iteration 追加 相关迭代 后播报"已追加 + 请重读"(消 Edit 过期读冲突); `as_append_to_section` 在节尾内容与下一标题间保持一个空行; close-iteration 状态异常错误点名它读的是 readme 的 `> 状态:` 行; note 模板在 详情 节以独立注释声明 doctor [8] 回链要求(原要求只活在 doctor 报错里); 资产 .gitignore 新增 `iterations/latest`(脚本运行时状态, 契约禁止引用, 入 git 会常驻脏行)。
- **行为适配两处(非破坏但需知晓)**: ① 旧用法"先过门后暂存"现在得到前置错误而非 PASS — 先 `git add` 再过门; ② agentspace-parallel skill 的泳道自检三连第③步(空暂存探针)已同步改为"先 add 占位文件再探"。
- 无结构/schema 变化; 脚本/模板/.gitignore 全部由 step 8a 自动替换。

## Changes

### [Fix] 结果门: 注释存在性判据 → 节内容判据
- **What**: lib.sh 新增 `as_section_filled <file> <heading>`(剥离 HTML 注释 — 跨行注释区域与行内 `<!-- ... -->` span 均不算内容, 其余文字算 — 后判节内是否有非空白内容行; 标题容忍行尾空白/CR); close-iteration.sh / complete-plan.sh / complete-exp.sh 三处 `grep -Fq "$RESULT_PH_*"` 子串门整体替换为该判据, 错误信息改为 `Results section is empty: <路径> — write the conclusion under '## 结果' (template guidance comments don't count as content)`。`RESULT_PH_*` 常量保留(仍是 doctor [5] 的模板漂移锚), 仅注释更新为"门不再依赖"。
- **Why**: 填了内容但保留指导注释即被拒、删注释才能过门是反向激励; 门要的是"有结论", 不是"没有注释"。
- **Migration**: 脚本由 **step 8a** 自动替换, 工作区无需任何操作。

### [Fix] 里程碑 commit 边界: 转换脚本打印精确提交命令
- **What**: lib.sh 新增 `as_commit_hint <path>...`; 七个流转脚本在转换完成后输出 `Next [MUST]: ledger-commit now` + 逐路径 `git -C AGENTSPACE add <该脚本刚写的路径> && git -C AGENTSPACE commit`。路径为脚本实际写入口径(plan/iterations/exp 三套入口 + 索引 + 条目文件; complete-plan 含 notes 路径 — 教训提炼与完成提交同行)。并行泳道下精确路径正是逐路径 add 的输入, 不诱导 `add -A`。
- **Why**: 台账 24 plan 实测 4 个会话发生折叠 commit 并需 reset --soft 重拆; 无脚本锚定的边界必然靠记忆, 记忆在多 plan 会话中最先失效。
- **Migration**: 脚本由 **step 8a** 自动替换, 工作区无需任何操作。

### [Fix] commit 门: 空暂存前置错 + --commit 原样提交
- **What**: commit-check.sh 在 message 扫描与暂存内容扫描之后、裁决之前加前置检查: 暂存为 0 且无阻断 → `error: nothing staged ... git add first` (exit 3); 暂存为 0 但 message 已违禁 → 仍走 BLOCKED (exit 1, 禁令优先发声); 纯删除(`git rm`)计为有效暂存。新增用法 `commit-check.sh <repo> --commit "<message>"`: 全部扫描通过后以 `git commit --cleanup=verbatim` 提交该 message 并回显 `committed: <sha> <subject>`, blocked 时不产生任何 commit; 头部 READ-ONLY 声明改为"默认只读, --commit 显式写"。
- **Why**: 先过门后暂存得到的是无意义 PASS; 过门文案与提交文案的复制走样无任何机制可查(实测发生过一次, 靠自觉补救)。
- **Migration**: 脚本由 **step 8a** 自动替换, 工作区无需任何操作。

### [Fix] handoff consume: 先 dump 后销毁
- **What**: consume 动作在删除文件与索引行之前先把快照全文(带 `---- handoff content ----` 包裹行)输出到 stdout; `--keep` 路径同样先 dump。
- **Why**: 快照不入 git, 先删后不打印 = 交接内容不可恢复地丢失(实测一泳道只能靠调度简报重建)。
- **Migration**: 脚本由 **step 8a** 自动替换, 工作区无需任何操作。

### [Fix] 追加播报 / 节尾空行 / 状态异常报错 / note 回链提示
- **What**: (1) new-iteration.sh 追加 相关迭代 后输出 `appended 相关迭代 → <plan 文档路径> (re-read that file before further edits ...)`; (2) lib.sh `as_append_to_section` 在节尾内容与下一个 `## ` 标题之间保持恰好一个空行(重复追加不产生连续空行, 节在 EOF 时不留尾随空行); (3) close-iteration.sh 状态异常错误改为点名 `> 状态:` 行并给出修复动作("set its status line back to '> 状态: 进行中'"); (4) 资产 templates/note.md 的 详情 节新增一条独立注释: 由 iteration 提炼的笔记必须回链该 iteration 的 readme(doctor [8] 审计)。
- **Why**: 追加后 Edit 过期读冲突 16 连; 追加行紧贴下一标题违 CommonMark 习惯; "状态异常"不说所读行导致重复踩; 回链要求只活在 doctor 报错里则永远后置。
- **Migration**: 脚本与 note 模板由 **step 8a** 自动替换, 工作区无需任何操作; 既有 notes/ 内容不迁移。

### [Fix] 资产 .gitignore: iterations/latest 不入 git
- **What**: 资产 .gitignore 在 `iterations/*/data/` 后新增 `iterations/latest` 行(new-iteration.sh 每次创建都翻转该软连接; 它是运行时状态, 工作区契约禁止引用 latest, 入 git 会在逐路径提交纪律下常驻脏行)。
- **Why**: 提示行给的是精确路径, latest 的翻转不应成为永不落账的噪音。
- **Migration**: .gitignore 由 **step 8a** 自动替换, 工作区无需任何操作。

### [Fix] agentspace-parallel skill: 自检探针对齐空暂存前置错
- **What**: skills/agentspace-parallel/SKILL.md 与 SKILL.zh-CN.md 的"自检三连"第③步改为: 先 `git add` 一个占位文件再跑 `commit-check.sh <worktree路径> "自检"`(门对空暂存报 exit 3 前置错, 那是流程顺序问题而非登记失败)。
- **Why**: 空暂存新语义下, 文档化的探针步骤按原文执行必然失败并误导排障方向。
- **Migration**: 插件侧 skill, 随插件更新交付; **工作区无需任何操作**。

### [Test] t37 回归 + 夹具对齐
- **What**: 新增 `tests/t37-gate-criteria-v151.sh`(内容判据三门 / 行内注释内容行 / 跨行注释空节 / 提示语与 -m 消息 / exp 脚本提示路径 / 追加播报与节尾空行 / 空暂存 exit 3 / 纯删除暂存放行 / --commit 双向与回显 / consume dump 与 --keep / 状态异常点名); t12 / t15 夹具从"删除占位注释"改为"替换为真实内容"(严格门下删除注释留空节=拒绝, 两处旧夹具钻的正是本次堵上的空节漏洞)。
- **Why**: 行为变化必须带回归; 旧夹具的空节过关恰是漏洞的活证据。
- **Migration**: 插件侧测试, 随插件更新交付; **工作区无需任何操作**。
