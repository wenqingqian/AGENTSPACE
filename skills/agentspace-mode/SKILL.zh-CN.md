---
name: agentspace-mode
description: 切换 AGENTSPACE 工作区模式(默认 hybrid / standalone), 管理外部依赖白名单, cue 模式规则。仅由显式 /agentspace-mode 命令触发, 绝不自动运行。
---

# AGENTSPACE 模式

仅在用户显式执行 `/agentspace-mode` 时运行。绝不自动触发。

两种模式:
- **hybrid**(默认): 外部数据/脚本按现状允许; 模式概念整体"不存在" — 无约束, doctor [13] 跳过。
- **standalone**: 工作区运行所依赖的一切必须物理位于 `AGENTSPACE/` 内; 外部引用需要白名单条目; 小文件豁免必须用户显式确认。

模式的唯一真相源 = `AGENTSPACE/AGENTS.md` 中的 `## agentspace mode` 块(下一行是模式值; standalone 时还有 `rules` 行)。会话加载 AGENTS.md 时即见 — 零成本检查。只有 `scripts/mode.sh` 可改写。

## 执行流程 (MUST)

1. MUST 运行硬脚本 `bash AGENTSPACE/scripts/mode.sh` 并传入解析后的参数(无参 = 查询; `--hybrid` / `--standalone` = 切换; `--allow <路径>` / `--deny <路径>` / `--list` = 白名单)。
2. **无参数** → 呈现脚本输出(当前模式 + 一行简述)。若为 standalone, 附加逐字 cue 下方"Standalone 规则"。
3. **自然语言白名单请求**(如"这个文件夹内容/这个脚本保持独立, 不需要放入 agentspace")→ MUST 先与用户确认确切路径; **小文件豁免必须用户显式确认**(agent 绝不自行决定小文件豁免)。确认后逐条执行 `mode.sh --allow <路径>`。
4. **`--standalone` 切换** → 脚本改写模式块、自动白名单大文件外部引用(≥1G, 复制不现实)、并运行 doctor.sh。呈现报告; 剩余小文件违规**不自动处理** — 每项需用户决策(集成或豁免)。呈现后执行里程碑提交(`git -C AGENTSPACE add -A && commit` — 切换本身不提交; 在此之前 doctor [0] 恒红)。
5. **`--hybrid` 切换** → 脚本仅改写模式块, 不整理。

## Standalone 规则 (cue 文本 — 逐字)

- 工作区运行所依赖的内容(数据/脚本/配置/产物)必须物理位于 `AGENTSPACE/` 内; git 跟踪不算判据(data/ 本就全 gitignore)。
- 外部依赖只有两条合法路径: **集成**(复制进 `AGENTSPACE/`)或**白名单豁免**(`.agentspace-whitelist`)。
- 大文件(≥1G)外部引用自动豁免(doctor --fix / 切换 standalone 时自动)。
- 小文件外部引用默认必须集成; 豁免必须用户显式确认, agent 不得自行豁免。
- 白名单条目: 相对项目根或绝对路径; 文件或目录(目录条目覆盖其下); 由 `scripts/mode.sh` 维护(原子写)。
- 已登记关键代码仓库(`.agentspace-repos`)是工作**对象**, 不是外部依赖 — 天然豁免白名单语义(doctor [13] 对登记仓库内的引用不报违规)。
- 违规发现与修复以 doctor [13] 为准(minor 面: 软连接 + 登记来源列; major 面: 全量路径扫描, 由 /agentspace-doctor --major 执行)。

## 备注

- Hybrid 模式: 整个模式概念"不存在" — 不施加 standalone 规则, 不引用白名单。
- `mode.sh --standalone` 幂等; 切换即一次 doctor minor(用户决策)。
