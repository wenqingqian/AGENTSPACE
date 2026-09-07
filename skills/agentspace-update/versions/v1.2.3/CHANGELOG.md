# AGENTSPACE v1.2.3

Upgrade from v1.2.2. Date: 2026-09-08

## Summary

- **`scripts/parallel-workspace.sh` 三处修复(audit + expert 咨询驱动)**: ① MERGELOCK 戳解析补 GNU date 回退 — 修复 stale-merge 接管在 Linux 上静默失效(此前 `date -u -j -f` 是 BSD 专有, GNU 上报错被吞、戳恒为空、接管永不触发, 与 v1.2.0 的自动接管承诺相悖); ② 自由文本字段尾随反斜杠写入侧硬拒(exit 3) — 此前 desc 以 `\` 结尾会与行内 `|` 分隔符融合成 `\|` 转义, 下一次读改写把 desc/info 两列静默合并; ③ 幂等 `--merge` 重写 MERGELOCK 戳(语义变更: 15 分钟 stale 窗从"首进时刻"改为"最后一次 merge 活动起算" — 活跃持有者重入即续期, 阈值只检测死亡、不再误杀超长 merge)。
- 设计确认(无代码变更): `--init` 保持哑表定位, 不交叉核对 plan/index.md 的 id 存在性 — 运行态表不依赖记账面 schema; 幽灵行由 `--show` 可见、`--remove` 可清, 未来若需要由 doctor 以报告项承担。
- 本版本无结构变更: 无模块/结构树/template/schema 变更, 无 AGENTS.md 文本操作(无 step 8b), 无 constants 变更(`MERGE_STALE_SECONDS=900` 数值不变, 仅语义起算点变化)。

## Changes

### [Fix] MERGELOCK 戳解析: GNU date 回退(修复 Linux 上 stale 接管静默失效)

- **What**: `AGENTSPACE/scripts/parallel-workspace.sh` 的 `ws_merge_stamp_epoch` 函数体替换为 BSD/GNU 双回退链, 逐字:

  ```
  ws_merge_stamp_epoch() {  # <id> -> epoch or empty
    [ -f "$WS_FILE" ] || return 0
    ID="$1" awk -F'|' '$1 == "MERGELOCK" && $2 == ENVIRON["ID"] { print $3; exit }' "$WS_FILE" \
      | { IFS= read -r iso || true
          [ -n "${iso:-}" ] || return 0
          date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$iso" +%s 2>/dev/null \
            || date -u -d "$iso" +%s 2>/dev/null || true
        }
  }
  ```

  BSD `date -j -f` 在前(主平台成功即短路), GNU `date -d` 在后; 两侧都失败时行为与修复前一致(戳空 → 不接管 → 60s 等待 + 报错 + 手动杠杆), 失败方向不变(fail-dead 有手动出口, 不误判活人 stale)。同文件头注释第 5 行的 "this script adds nothing platform-specific" 同步改写为如实描述双回退; stale 注释块尾部残留句 "UTC ISO-8601 compares correctly as plain strings" 删除(实现从未做字符串比较)。
- **Why**: `date -u -j -f` 是 BSD 专有选项, GNU coreutils date 无 `-j`, 报错被 `2>/dev/null || true` 吞掉 → Linux 上戳恒解析为空 → stale 接管永不触发, 卡死的 merge 槽每次都退化为 60s 等待 + 手动恢复, 与 v1.2.0 "MERGELOCK 时间戳超 15 分钟判 stale 自动回退 doing 接管"的无条件承诺相悖。lib.sh 自身处处 stat 双回退, 本脚本却引入了无回退的平台分支。
- **Migration**: **handled by step 8a — 全部 `scripts/*.sh` 由规范 asset 整体替换**(本版本实际变化的仅 `parallel-workspace.sh` 一个脚本)。无需任何手工工作区动作; 无 step 8b。

### [Fix] 自由文本尾随反斜杠写入侧硬拒(exit 3)

- **What**: `AGENTSPACE/scripts/parallel-workspace.sh` 新增参数解析期守卫 `ws_cell_check`, 对四个自由文本面拒绝以 `\` 结尾的值, 逐字:

  ```
  ws_cell_check() {  # <value> <field-label>
    case "$1" in
      *\\) ws_usage_err "$2 must not end with a backslash — it would fuse with the row's | separator into a literal \\| escape (drop the trailing backslash and retry)" ;;
    esac
  }
  ```

  接线四处(均在锁前的参数解析段, 与既有 usage 错误同层): `--init` 的 `<plan_desc>` 与 `[any_info]`; `--update` 的 `--plan_desc` 与 `--any_info`(仅在对应 `U_*_SET=1` 时检查); `--send` 的 `--msg`。全部走 `ws_usage_err` → exit 3, 数据文件零写入。头注释 exit code 契约行同步补 "free-text field ending with a backslash"。
- **Why**: 行内字段无空格垫片(`PLAN|<id>|<state>|<desc>|<info>`), desc 以 `\` 结尾时与后随分隔符构成 `\|` 序列, 读路径 `ws_field` 的盾把它当转义管道吞掉 — desc 与 info 合并、info 内容丢失, 且下一次 `--update` / stale 接管回写把腐蚀固化(实测: `--init 9 'trailing\' 'keepme'` → `--update 9 --state test` 后 desc=`trailing\|keepme`、info 丢失)。拒绝而非静默修正, 与 new-plan slug 硬拒同风格; info/msg 是末字段今日免疫, 一并拒绝是防未来行格式加字段的保险。已腐蚀的历史行无需迁移: 数据文件是 gitignore 的运行态, 最坏 `--remove` + `--init` 重建。
- **Migration**: **handled by step 8a — 同上, `parallel-workspace.sh` 由规范 asset 整体替换**。无需任何手工工作区动作; 无 step 8b。

### [Fix] 幂等 --merge 重写 MERGELOCK 戳(语义变更: stale 窗按最后活动起算)

- **What**: `AGENTSPACE/scripts/parallel-workspace.sh` 的 `op_merge` 幂等分支(计划行已是 merge 时)在返回前重写戳, 并更新提示文案, 逐字:

  ```
  if [ "$(ws_plan_state "$1")" = "merge" ]; then
    ws_set_merge_stamp "$1"   # renewal: the stale window runs from the LAST merge activity — an idempotent re-entry is proof of life
    printf 'already merge: plan %s (idempotent, merge window renewed — 短窗铁律: finish the real merge, then --remove %s)\n' "$1" "$1"
    ws_print_inbox "$1" "auto-return after --merge"
    return 0
  fi
  ```

  `ws_set_merge_stamp` 走既有的单锁 + mktemp + 原子 mv 管线, 不引入新竞态。
- **Why**: 900s 阈值的设计意图是死者检测("持 merge 态的 agent 死亡后槽位永久卡死")。旧实现下 15 分钟窗是首进时刻起的墙钟, 活跃持有者(冲突调停超 15 分钟)会被下一个 `--merge` 抢槽并回退状态 — 用死者检测器兼职执法活人。幂等重入是持有者持锁内的主动动作, 是天然的 proof-of-life: 重入即续期, 死者不续期、照常被接管。**语义变更**: stale 窗从"首进时刻起算"变为"最后一次 merge 活动起算"; 阈值 `MERGE_STALE_SECONDS=900` 数值不变。
- **Migration**: **handled by step 8a — 同上, `parallel-workspace.sh` 由规范 asset 整体替换**。无需任何手工工作区动作; 无 step 8b。

### [Fix] 结构树、templates、模块清单、表 schema、AGENTS.md、constants: 无变更

- **What**: 本版本除 `parallel-workspace.sh` 的三处修复与 `tests/t31-parallel-workspace.sh` 三类新断言(GNU 仿真 date 的 stale 接管 / 尾随反斜杠四面拒绝 / 幂等续戳覆盖旧戳)外无任何变化。不新增模块、不删除模块、不改任何表格列; `AGENTSPACE/AGENTS.md` 的 `结构` 代码块不增一行不减一行; 五个 `templates/*.md` 与 `.gitignore` 和 v1.2.2 内容相同; `versions/v1.2.3/architecture.json` 与 v1.2.2 的差异仅限 version 字段; 无新 constants(`MERGE_STALE_SECONDS` 数值不变, 且按先例不入 architecture.json)。
- **Why**: 明说以免更新 agent 为本版本虚构结构性工作, 或对 AGENTS.md 发明 8b 文本操作。
- **Migration**: 无 — 无事可做。本版本**没有 step 8b**: 不要改 `AGENTSPACE/AGENTS.md` 的任何一行。若工作区扫描提示需要结构树/模块/schema/AGENTS.md 变更, 均不在 v1.2.3 范围内; 保持工作区原样并报告。
