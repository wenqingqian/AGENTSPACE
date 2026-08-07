---
name: agentspace-mode
description: Switch the AGENTSPACE workspace mode (hybrid default / standalone), manage the external-dependency whitelist, cue the mode rules. Triggered ONLY by the explicit /agentspace-mode command; never automatic.
---

# AGENTSPACE Mode

Only when the user explicitly runs `/agentspace-mode`. Never automatic.

Two modes:
- **hybrid** (default): external data/scripts are allowed as-is (current behavior); the mode concept is otherwise absent — no constraints, doctor [13] skipped.
- **standalone**: everything the workspace runs on must be physically inside `AGENTSPACE/`; external refs need whitelist entries; small-file exemptions require explicit user confirmation.

The mode's source of truth is the `## agentspace mode` block in `AGENTSPACE/AGENTS.md` (value on the next line; `rules` follows in standalone). Sessions see it when loading AGENTS.md — zero-cost check. Only `scripts/mode.sh` rewrites it.

## Flow (MUST)

1. MUST run the hard script `bash AGENTSPACE/scripts/mode.sh` with the parsed arguments (no args = query; `--hybrid` / `--standalone` = switch; `--allow <path>` / `--deny <path>` / `--list` = whitelist).
2. **No arguments** → present the script output (current mode + one-line cue). If the mode is standalone, additionally cue the Standalone Rules verbatim (below).
3. **Natural-language whitelist request** (e.g. "这个文件夹内容/这个脚本保持独立, 不需要放入 agentspace") → MUST confirm the exact path(s) with the user first; for small files the exemption requires EXPLICIT user confirmation (the agent never self-decides small-file exemptions). Then run `mode.sh --allow <path>` per confirmed path.
4. **`--standalone` switch** → the script rewrites the mode block, auto-whitelists large external refs (≥ 1G, copy-unrealistic), and runs doctor.sh. Present the report; do NOT auto-resolve the remaining small-file violations — each needs a user decision (integrate or exempt). After presenting, make the milestone commit (`git -C AGENTSPACE add -A && commit` — the switch itself does not commit; doctor [0] stays red until then).
5. **`--hybrid` switch** → the script only switches the block, no cleanup.

## Standalone Rules (cue text — verbatim)

- 工作区运行所依赖的内容(数据/脚本/配置/产物)必须物理位于 `AGENTSPACE/` 内; git 跟踪不算判据(data/ 本就全 gitignore)。
- 外部依赖只有两条合法路径: **集成**(复制进 `AGENTSPACE/`)或**白名单豁免**(`.agentspace-whitelist`)。
- 大文件(≥1G)外部引用自动豁免(doctor --fix / 切换 standalone 时自动)。
- 小文件外部引用默认必须集成; 豁免必须用户显式确认, agent 不得自行豁免。
- 白名单条目: 相对项目根或绝对路径; 文件或目录(目录条目覆盖其下); 由 `scripts/mode.sh` 维护(原子写)。
- 违规发现与修复以 doctor [13] 为准(minor 面: 软连接 + 登记来源列; major 面: 全量路径扫描, 由 /agentspace-doctor --major 执行)。

## Notes

- Hybrid mode: the whole mode concept is absent — do not impose standalone rules, do not reference the whitelist.
- `mode.sh --standalone` is idempotent; switching runs a doctor minor pass by design (user decision).
