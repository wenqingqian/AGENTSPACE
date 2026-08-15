# AGENTSPACE v0.6.1

Upgrade from v0.6.0. Date: 2026-08-15

## Summary

commit 文本质量检查: 门与事后审计新增"标题为空/纯空白"确定性规则(lib.sh 单源); agentspace-commit 语义层扩两问(规范符合度 + 与代码改动相关性), doctor 审计同 rubric。脚本侧 8a 替换, skill 插件侧, 工作区无结构变更。

## Changes

### [Feature] commit-check.sh: 标题空/纯空白阻断(8a)
- **What**: 草稿 message 第一行为空或纯空白 → exit 1 阻断。新增 lib.sh 辅助函数 `as_msg_title_blank`(取首行, 空或纯空白即命中), commit-check.sh(阻断)与 doctor [15](warn)同源。
- **Why**: 真实事故样本是实验 run 名冒充 commit(`(6-run driver launch on .42)`) — 质量判断本质是语义的, 归 agent 语义层; 脚本层只加这一条**零误报**确定性规则(空标题在任何情况下都不合法)。
- **Migration**: handled by step 8a(scripts 整体替换, lib.sh 含新函数)。

### [Feature] doctor [15]: 标题空/纯空白事后 warn(8a)
- **What**: 审计窗口内每条 commit 检查标题: 空/纯空白 → warn(只报告, 同 [15] 既有语义)。
- **Why**: 门是前置, [15] 是事后兜底 — 手动/绕过门产生的空标题 commit 必须可见。
- **Migration**: handled by step 8a。

### [Addition] agentspace-commit skill: Commit-text Quality 语义检查(插件侧)
- **What**: Message Rules 之后新增 "Commit-text Quality" 节 — 两问 rubric: ① **规范符合度**(性质标准) — 标题(第一行)必须是一句话的代码改动描述: 合格如 `add retry to driver launch`; 拒绝无信息标题(`driver`/`stuff`)、实验/run 标识(`(6-run driver launch on .42)` — run 编号/机器地址/配置标签, 属 iteration readme 与 data/)、正文解释 why 不重复 what、≤72 字符为软线; ② **与 diff 相关性** — 先读 `git show --stat`/`git diff --cached --stat` 再判, 标题主题必须落在实际改动里(标题说 driver 而 diff 只动数据清洗 = 实验名穿 commit 外套)。处置: 命中 → 门内要求重写标题/正文(代码不动)后重新过门; 用户坚持原文本 → 尊重但明示 doctor 审计窗口内持续可见。类型前缀(feat:/fix:…)推荐不强制。
- **Why**: 用户真实观察 — agentspace 管理仓库出现实验名 commit; v0.6.0 语义层只覆盖记账引用, 没有文本质量维度。
- **Migration**: plugin-side, 工作区无需操作。

### [Addition] agentspace-doctor skill: Phase C Block 2 审计 rubric 扩展(插件侧)
- **What**: 登记仓库最近 20 条 commit message 的语义审计从"记账变体"扩为三维: (a) 记账引用变体(`plan_0013`/"迭代 3"/任何语言记账叙述) (b) 文本质量(标题是否真实改动的一句话描述, 无实验/run 标识/机器地址/无信息标题) (c) 与 diff 相关性(核对 `git show --stat`)。每条违规报告: sha + 维度 + 具体建议(如拟改写的标题)。只报告。
- **Why**: 门内 agent 判定 + 事后审计同 rubric, 与 commit-check.sh/[15] 的"同源不漂移"结构一致。
- **Migration**: plugin-side, 工作区无需操作。
