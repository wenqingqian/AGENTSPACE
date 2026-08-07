# AGENTSPACE v0.5.2

Upgrade from v0.5.1. Date: 2026-08-07

## Summary

- **/agentspace-mode 命令**: 工作区模式控制 — 默认 hybrid(外部数据/脚本按现状允许)/ standalone(运行依赖必须物理集成进 AGENTSPACE/); 切换、外部依赖白名单管理、规则 cue。
- **standalone 三件套**: 静态检查(doctor [13])+ 行为纪律(AGENTS.md 标记块 + skill 规则)+ 白名单豁免(大文件 ≥1G 自动豁免; 小文件豁免必须用户显式确认)。
- **低摩擦哲学**: 前置约束 = AGENTS.md 一行标记块(hybrid 下模式概念整体"不存在"); 严格性后置到 doctor(minor 面收敛 / major 面全量)。

## Changes

### [Feature] /agentspace-mode 命令 + skill(模式控制)
**What**: 新命令 `commands/agentspace-mode.md` + `skills/agentspace-mode/`(双语):
- 无参: 返回当前 mode; hybrid 轻 cue(一行简述)、standalone 全 cue(Standalone 规则逐字)。
- 自然语言白名单请求(如"这个文件夹保持独立, 不需要放入 agentspace"): agent 解析 → 与用户确认确切路径(小文件豁免必须显式确认)→ `mode.sh --allow`。
- `--standalone` 切换 = 改写标记块 + 大文件自动白名单 + 一次 doctor minor(报告剩余小文件违规, 不自动处理); `--hybrid` 仅切标记, 不整理。
**Why**: 用户设计(0.5.2): mode 约束的是运行过程产生/引入的外部依赖, 不是 init 时的事; mode 值作为工作区状态保存(后续版本统一)。
**Migration**:
1. **Script (handled by step 8a — no manual work)**: `AGENTSPACE/scripts/mode.sh` is new from assets; `AGENTSPACE/scripts/lib.sh` and `doctor.sh` are replaced from assets.
2. **New workspace file (step 8a)**: `AGENTSPACE/.agentspace-whitelist` is created from the asset template (empty, hybrid-read-only).
3. **AGENTS.md (step 8b — agent action, exact replace)**: in `AGENTSPACE/AGENTS.md`, insert before the `## 项目简介` heading the block:
   ```
   ## agentspace mode
   hybrid
   ```
   (i.e. `## agentspace mode\nhybrid\n\n` immediately before `## 项目简介`; upgraded v0.5.1 workspaces have no such block yet. Future switches are done by `scripts/mode.sh`, never by hand.)
4. **No data migration**.

### [Feature] mode.sh: 切换 / 查询 / 白名单管理
**What**: `AGENTSPACE/scripts/mode.sh` — 模式唯一真相源 = AGENTS.md 的 `## agentspace mode` 块(会话加载 AGENTS.md 即见, 零成本; 脚本读它, mode.sh 改它)。`--hybrid|--standalone` 幂等切换(无块时插入, 原子写); standalone 切换时自动白名单 ≥1G 外部引用(`WHITELIST_LARGE_BYTES`, 复制不现实)并跑 doctor.sh; `--allow/--deny/--list` 白名单管理(原子写, ENVIRON 传参)。全部写操作走 as_lock。
**Why**: 用户澄清: 切换 mode 不是 init 的事, 而是"运行规则注入 + 工作区整理"(历史遗留/迁移场景), 整理 = 一次 doctor minor。
**Migration**:
1. **Script (handled by step 8a — no manual work)**: `AGENTSPACE/scripts/mode.sh` is new from assets.

### [Feature] doctor [13]: standalone 外部引用检查
**What**: 仅 standalone 启用(as_mode = standalone; hybrid 下整节跳过 — 模式概念不存在)。扫描面(minor): 软连接指向 AGENTSPACE 外 + data.md/utils.md/register.md 登记来源/链接列的绝对路径 token(major 面全量路径扫描在 /agentspace-doctor --major skill 流程)。判定: 白名单命中 → 豁免; 未命中 → 按大小分级(≥1G 违规 + 自动豁免路径; <1G 违规, 必须集成或用户显式豁免)。`--fix` 边界: 只自动白名单大文件引用; 小文件/软连接不自动处理。白名单卫生: 失效条目(目标不存在)报告不删; 小文件条目提示"需用户显式确认"。
**Why**: "前置约束轻、严格性后置" — 违规发现与修复以 doctor 为准, 不给 agent 加每次访问判断白名单的高摩擦约束。
**Migration**:
1. **Script (handled by step 8a — no manual work)**: `AGENTSPACE/scripts/doctor.sh` is replaced from assets.

### [Addition] lib.sh 模式与白名单辅助
**What**: `as_mode()`(读标记块, 缺块默认 hybrid)/ `as_whitelisted()`(相对项目根或绝对路径, 目录条目覆盖其下)/ `as_external_refs()`(外部引用 minor 面扫描)/ `add_whitelist_entry()` / `remove_whitelist_entry()`(原子写, ENVIRON 传参) + `WHITELIST_LARGE_BYTES`(1G, 单源常量)。mode.sh 与 doctor.sh 共用 — 不重复实现(脚本模式纪律)。
**Migration**:
1. **Script (handled by step 8a — no manual work)**: `AGENTSPACE/scripts/lib.sh` is replaced from assets.

### [Addition] AGENTS.md 模板标记块 + .agentspace-whitelist 模板
**What**: 资产 AGENTS.md 在 `## 项目简介` 前加 `## agentspace mode` + `hybrid` 两行块(新工作区默认 hybrid); 新资产文件 `.agentspace-whitelist`(注释头说明语义, 空条目)。architecture.json 同步 files(whitelist + mode.sh)与 sections(agentspace mode)。
**Migration**:
1. **Asset-side (handled by step 8a/8b — see the command block above)**: templates ship with init; upgraded workspaces get the block via 8b.

### No structural changes
- plan/iterations/notes/utils/tests/data/examples/register/handoff schemas unchanged; AGENTS.md 增加一个两行标记块(8b 覆盖); 新增空白名单文件(8a); t13 重放表扩展(8a whitelist 复制 + 8b 标记块锚点)。
