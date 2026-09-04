# AGENTSPACE v1.0.1

Upgrade from v1.0.0. Date: 2026-09-05

## Summary

- **agentspace-parallel 行为规则修正**: 改动面交集(文件级或语义级)**不再在准入时阻塞并行** — §0 铁律 7 重写("相交不并行" → "相交绝不阻塞开发, 唯一阻塞点在合回"), §2 交集检查降级为纯信息动作(仍点名对方 plan 并记入 readme, 作为 §7a 差距画像的预判输入, 但绝不拦停/排队), §7h 强化为全 skill 唯一阻塞点(冲突 hunk / 语义交集命中 / 结构性 absorb / 重测失败任一 → 冻结 merge, 与用户讨论处理计划后在泳道内更新重测; 零交集常规 absorb 不打扰用户)。
- 无脚本/模板/工作区文件变化; 架构快照与 v1.0.0 一致, 仅版本号前进。

## Changes

### [Behavior] agentspace-parallel: 交集不阻塞准入, 阻塞点钉死在合回
- **What**: `skills/agentspace-parallel/SKILL.md` 与 `SKILL.zh-CN.md` 三处同步改写 — ① §0 铁律 7: "Plans whose change surfaces intersect do not run in parallel" → "Intersecting change surfaces never block development"; ② §2 首条: 交集检查从"stop + report + queue"改为"点名 + 记 readme, 仅此而已", 并明示同仓库多泳道相交与否皆合法; ③ §7h: 从"重测失败或结构性 absorb 回到用户"扩展为唯一阻塞点清单(冲突 hunk / 语义交集命中含零文本冲突 / 结构性 absorb / 重测失败 → 冻结 merge + 与用户讨论处理计划 + 泳道内更新 + 重测)。§1 发现表"交集判定的对手方"措辞同步改为"信息性交集扫描的输入"。
- **Why**: worktree 天然隔离工作区, 开发阶段无需任何保护; 需要保护的是主线进入口。文件级相加式相交(两 plan 各往同一 argparse/注册表/配置文件加自己的项)是真实开发最常见形态, 准入拦截会让热点文件下并行几乎不可用; 一切交集由合回的 CAS + absorb + 移植 + 重测机械承担(t24 的强制同行冲突 absorb 即该路径的实测证据)。v1.0.0 的"任一相交 → 排队"继承自草案铁律 7 原文, 与真实用法不符(sga 预览版即同文件并行 + 合回冲突处理)。
- **Migration**: 插件侧 skill 文本, 随插件更新交付; **工作区无需任何操作** — 架构快照、scripts、templates、AGENTS.md 全部不变(step 8a 替换的文件内容与 v1.0.0 逐字节相同, step 8c 仅前进版本标记)。
