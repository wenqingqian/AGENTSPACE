# AGENTSPACE v1.2.2

Upgrade from v1.2.1. Date: 2026-09-08

## Summary

- **as_lock 三处加固(expert 审查驱动的安全修复)**: `scripts/lib.sh` 的 `as_lock`(mkdir 自旋锁)补上三个残余风险口子 — ① 获取等待上限: 等活持有者超过 `AS_LOCK_TIMEOUT_SECONDS`(默认 120s)即报出持有者 pid 与锁路径并 exit 非 0, 不再无限自旋(stale 接管不受此限); ② 无 trap 窗口收窄: mkdir 成功后先直接写占位 pid, 该窗口内崩溃留下的锁立即可被下一个 writer 按 stale 接管, 不必等 mtime 宽限; ③ pid 复用二级宽限: 可解析 pid 且进程存活时, 锁龄超过 `AS_LOCK_STALE_HOURS`(默认 6h)即判 stale — 锁 mtime 即获取时刻且持有期从不刷新, 超龄必是死主被 pid 复用。
- 新增两条 lib.sh 常量并录入 architecture.json(逐字):
  - `AS_LOCK_TIMEOUT_SECONDS="120"`
  - `AS_LOCK_STALE_HOURS="6"`

  两条均为 env 可预置(短值便于测试)、非数值/空值回落默认、`readonly`; 消毒形如 `case "$VAR" in ''|*[!0-9]*) VAR="<默认>" ;; esac`。
- 本版本无结构变更: 无模块/结构树/template/schema 变更, 无 AGENTS.md 文本操作(无 step 8b)。

## Changes

### [Fix] as_lock: 获取等待上限 AS_LOCK_TIMEOUT_SECONDS(默认 120s)

- **What**: `as_lock` 进入等锁循环前记 `wait_start="${SECONDS:-0}"`; 每轮发现锁被**存活 pid** 持有且 `SECONDS - wait_start >= AS_LOCK_TIMEOUT_SECONDS` 时, `as_die "as_lock: timed out after ${AS_LOCK_TIMEOUT_SECONDS}s waiting for $AS_ROOT/.scripts.lock (held by pid ${owner:-unknown})"` — exit 非 0, 不再 `sleep 0.2` 自旋。上限只约束**等活持有者**: stale 判定与接管(`mv` + `rm -rf`)完全不受影响, 走原路径。常量逐字:

  ```
  AS_LOCK_TIMEOUT_SECONDS="120"
  ```

  实际声明为 `AS_LOCK_TIMEOUT_SECONDS="${AS_LOCK_TIMEOUT_SECONDS:-120}"` + 数值消毒 + `readonly` — 环境可预置(如测试置短值), 空/非数值回落默认 120。
- **Why**: as_lock 的临界区都是亚秒级; 一个存活超过 120s 的持有者只能是卡死的 writer — 等待者应当报出持有者 pid 与锁路径后退出, 把决策交还上层, 而不是永久自旋拖死整条脚本链。
- **Migration**: **handled by step 8a — 全部 `scripts/*.sh` 由规范 asset 整体替换**(本版本实际变化的仅 `lib.sh` 一个脚本)。无需任何手工工作区动作; 无 step 8b。

### [Fix] as_lock: 无 trap 窗口收窄 — mkdir 后先写占位 pid

- **What**: `mkdir` 成功后、`trap` 安装前, 先 `printf '%s' "$$" > "$AS_ROOT/.scripts.lock/pid"` 直接写占位 pid(单次小写入), 再用原 tmp+mv 原子写细化。此前该窗口内的 TERM/KILL 会留下**无 pid 文件**的锁 — 下一个 writer 读不到 pid, 只能等 5 分钟 mtime 宽限; 现在同窗口崩溃留下的是带 pid 的锁, 下一个 writer 直接 liveness-check 该 shell, **立即**按 stale 接管。
- **Why**: mkdir 与 trap 之间的指令间隙无法消除, 但可以把窗口内崩溃的后果从"5 分钟幽灵锁"缩到"下一次争用即自愈" — 占位 pid 落盘后, 锁永远可被 liveness 检查裁决。
- **Migration**: **handled by step 8a — 同上, `lib.sh` 由规范 asset 整体替换**。无需任何手工工作区动作; 无 step 8b。

### [Fix] as_lock: pid 复用二级宽限 AS_LOCK_STALE_HOURS(默认 6h)

- **What**: 可解析 pid 且 `ps -p` 报活时, 旧逻辑直接判活; 新逻辑追加 mtime 二级宽限: `find "$AS_ROOT/.scripts.lock" -mmin +$((AS_LOCK_STALE_HOURS * 60))` 命中即判 stale 并接管。依据: pid 文件只在获取时写一次、持有期从不刷新, 锁 mtime 即获取时刻 — 进程"活着"但锁龄超阈值, 只能是死主的 pid 已被无关进程复用, 不是真 writer。pid 文件缺失/空/非数值的 5 分钟 mtime 宽限路径**不变**。常量逐字:

  ```
  AS_LOCK_STALE_HOURS="6"
  ```

  同样 env 可预置 + 数值消毒 + `readonly`。
- **Why**: `ps`/`kill -0` 的 liveness 检查天然防不住 pid 复用 — 死主 pid 被回收后 ps 永远报活, 锁被永久卡死且超时上限也无济于事(等的是"活"进程)。mtime 是获取时刻的可靠代理, 二级宽限封死该口子。
- **Migration**: **handled by step 8a — 同上, `lib.sh` 由规范 asset 整体替换**。无需任何手工工作区动作; 无 step 8b。

### [Fix] 结构树、templates、模块清单、表 schema、AGENTS.md: 无变更

- **What**: 本版本除 `lib.sh` 的 as_lock 加固与两条新常量外无任何变化。不新增模块、不删除模块、不改任何表格列; `AGENTSPACE/AGENTS.md` 的 `结构` 代码块不增一行不减一行; 五个 `templates/*.md` 与 `.gitignore` 和 v1.2.1 内容相同; `versions/v1.2.2/architecture.json` 与 v1.2.1 的差异仅限 version 字段与 `constants` 补录 `AS_LOCK_TIMEOUT_SECONDS`/`AS_LOCK_STALE_HOURS` 两条。
- **Why**: 明说以免更新 agent 为本版本虚构结构性工作, 或对 AGENTS.md 发明 8b 文本操作。
- **Migration**: 无 — 无事可做。本版本**没有 step 8b**: 不要改 `AGENTSPACE/AGENTS.md` 的任何一行。若工作区扫描提示需要结构树/模块/schema/AGENTS.md 变更, 均不在 v1.2.2 范围内; 保持工作区原样并报告。
