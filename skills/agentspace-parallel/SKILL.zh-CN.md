---
name: agentspace-parallel
description: AGENTSPACE 项目的并行开发 — 每 plan 一组 git worktree, PR-like 纯本地分支生命周期。一 plan = 一组 worktree = 每个被改仓库一个分支; 开发与测试(单测与 e2e)全在 worktree 内, 出结果等用户确认, 然后经 CAS 主线锁以恰好一个 squash commit 合回(主线无 merge commit、无 fast-forward、无记账 id)。覆盖重构感知 absorb(主线合入分支)、台账写竞争协议(scripts 自锁 + 台账锁)、共享资源(GPU/IO)仲裁与不满意分档(同分支迭代, 绝不重建 worktree)。当用户在根目录有 AGENTSPACE/ 工作区的项目上开启或管理并行工作线时使用(如 "并行启动 plan:NNNN"、"set up a parallel workspace"、"同时做第二个 plan"、"两个 plan 一起做")。
---

# AGENTSPACE 项目的并行工作区(PR-like, 纯本地)

> 定位: 本 skill 是**项目无关**的并行开发操作系统。一切项目 specifics(仓库清单、验证门、
> 依赖接线、资源工具)在 §1 项目发现中从该项目的 AGENTSPACE 动态读取, 本 skill 不硬编码任何路径。
> 一切**纯本地**: 不 push、无远端 PR 机制; 发布仍是用户单独的决定, 不在本 skill 范围。
> 单项目实例化后通常落成该项目 `AGENTSPACE/notes/` 下的一篇规范。

## 0. 铁律(不变量)

1. **一 plan 一 worktree 组 一分支名**(每个被改仓库都叫 `plan-<plan-id>`); worktree 生命周期 = plan 生命周期(多 iteration 共用)。
2. **纯本地**: 本 skill 无任何远端操作; push 是用户单独的决定。
3. **主检出属于主线会话**; 泳道永不动它。主检出只在 merge 窗口(§8.1 第 3 步)期间必须干净且不被触碰——秒级, 不是小时级。
4. **AGENTSPACE 台账单实例共享**: 索引/登记状态只经 `scripts/` 写入(自锁); 其余写路径走台账锁(§6)。**泳道活跃期间台账仓库禁止 `git add -A`**——会把其他会话的在途改动卷进你的提交。
5. **验证先量定再执行**(§8.0), 且**在 worktree 内、merge 之前**运行; 禁止沉默跳过。
6. **merge-back 只有一个合法形式**(§8.1): 主线锁 → 复查基准 → `merge --squash` → commit 门 → commit → diff 为空证明 → 放锁。不 fast-forward、不普通 merge、主线无 merge commit、无 "Merge branch xxx" 标题——每个被接受的 merge 恰好一个 commit, 标题读起来像 PR 名。
7. **改动面相交的 plan 不并行**——按仓库, 文件级或语义级(§2)。worktree 隔离工作区, 不隔离语义冲突。

## 1. 项目发现(先把项目参数化, 再开始任何操作)

并行会话**不假设**任何项目事实, 逐项读取:

| 要素 | 来源 | 用途 |
| --- | --- | --- |
| 工作区规则/模式 | 项目根 `AGENTS.md`(或 AGENTSPACE/AGENTS.md) | 常规约束; 确认存在 AGENTSPACE/ |
| 登记仓库清单 | `AGENTSPACE/.agentspace-repos` + `scripts/repos.sh --list` | worktree 候选集; commit 门适用范围 |
| 各仓库主分支 | 各主检出 `git branch --show-current` | worktree 分支的基线 |
| 验证资产 | `AGENTSPACE/tests.md`(测试脚本索引) | §8.0 量定的依据; **项目可能没有长跑门**(只有单测, 或两者皆无) |
| 活跃 plan/iteration 及**改动面声明** | `plan.md` todo 表 + `iterations.md` 进行中表 + 各 plan 文档 | §2 交集判定的对手方 |
| 依赖接线方式 | 各仓库环境脚本(env.sh 类)与 AGENTS.md | §3 步骤 2 的依赖重定向 |
| scripts 并发安全 | `grep -n 'as_lock' AGENTSPACE/scripts/lib.sh` | §6.1 前提; 若无则台账锁范围扩大到脚本调用 |
| 资源工具 | `AGENTSPACE/utils.md` | §9 节点/资源管理工具(若有) |
| 会话交接 | `AGENTSPACE/handoff/index.md` | 若有指向本 plan 的 handoff 先 consume |
| e2e 多实例隔离 | 门脚本本体(端口/输出目录/临时存储) | 两条泳道能否并发跑 e2e; 不隔离则 e2e 归入 §9 占用型资源 |
| **内嵌型检查** | 项目根本身是否落在登记仓库内? | 是则先把 `.locks/` 与 `worktrees/` 写进该仓库 `.gitignore`(铁律——锁 owner 文件含字面记账 id, 一次手滑 `git add -A` 会触 commit 门, 甚至把整个 worktree 卷进宿主) |

**锁命名空间**(本 skill 统一约定, 项目根下): `.locks/mainline/`(§8) · `.locks/ledger/`(§6) ·
`.locks/resource-<name>/`(§9)。全部 **mkdir 原子创建**(NFS 安全, 不用 flock), `owner` 文件写
`plan:<id> iteration:<id> <host> pid:$$ <ISO时间> <用途>`。
**首次用锁前先 `mkdir -p <项目根>/.locks`**——父目录不存在时 `mkdir .locks/<name>` 报 ENOENT,
若配了 `2>/dev/null` 会被误读成"锁被占"(实测踩坑); 原子性只需要最后一级。
**陈旧锁恢复对齐 `as_lock` 语义**: owner pid 不存活即陈旧; 无 pid 的锁超过 5 分钟 mtime 宽限也陈旧
(mkdir 与写 owner 之间崩溃); 接管用 `mv`(恰好一个等待方胜出), 绝不原地 `rm -rf`, 接管后告知用户——禁止静默强拆。

## 2. 适用性检查(动命令之前)

- **改动面交集**: 目标 plan 文档的改动面声明(仓库清单 + 文件/语义面——plan 文档缺该声明时先由属主会话补上) vs 主线 plan 与其他活跃并行 plan, **按仓库逐一比对**。文件级(两侧都改的文件)与语义级(本 plan 消费的接口面被对方重构)任一相交 → 停下, **点名冲突方 plan**, 报告用户, 排队。改动面不相交的 plan 改同一仓库完全合法(git 原生支持同仓库多 worktree, 分支名不同)。
- **对主检出未提交改动的依赖**: worktree 分支从主检出 HEAD 切, **不携带工作区未提交内容**; 有依赖先等其 commit。
- 报告动作清单(worktree 路径 + 分支名 + repos.sh 登记行)取得用户一次确认——该确认同时满足 AGENTSPACE "登记须用户显式确认"的纪律, 之后不再逐步询问。

## 3. 拉起 worktree

1. **建**(固定组织——唯一合法位置, 在项目根, 不管项目根是不是 git 宿主, 永远在所有登记仓库之外):
   ```bash
   cd <项目根>
   git -C <repo> worktree add worktrees/<plan-id>/<repo名> -b plan-<plan-id> <repo主分支>
   AGENTSPACE/scripts/repos.sh --add worktrees/<plan-id>/<repo名>   # 每 worktree 检出都必须登记, 否则 commit 门不识别
   ```
   只为**本 plan 实际要改**的仓库建 worktree; 不改的绝不建。不变量: **plan 是唯一组织轴**(`<plan-id>/` 目录随 plan 生死); 位置永远在所有登记仓库之外(内嵌型项目走 §1 的 .gitignore); 多仓库 plan 在每个仓库用**同一分支名** `plan-<plan-id>`(各自命名空间, 不撞)。
2. **依赖重定向**(通用模式, 接线按项目发现结果): worktree 检出的环境脚本以自身位置为锚解析同级仓库(sibling checkout); 对不建的仓库, 用项目文档载明的 override 变量指回主检出, 或放一个指回主检出的符号链接——二者取项目既有约定。原则: **动的仓库从 worktree 解析, 不动的从主检出解析**。
3. **自检三连**(全过才算拉起成功): ① 环境脚本输出的依赖源指向预期检出; ② 目标包 import 解析到 worktree 路径; ③ `commit-check.sh <worktree路径> "自检"` 退出 0(登记被识别)。
4. **记基准**: iteration readme 环境节每仓库一行——`<repo> plan-<id>:<base-sha>`(**永久锚点**, 在主线上永远可达)。

## 4. 角色与冻结

| 区域 | 归属 | 约束 |
| --- | --- | --- |
| 主检出各仓库 | 主线会话(若无主线会话则闲置) | 只在 §8.1 第 3 步 merge 窗口期间冻结(不改文件/不切分支/不 checkout) |
| `worktrees/<plan-id>/` | 该 plan 的并行会话 | 本 plan 全部代码改动、单测、评审、commit |
| `AGENTSPACE/` | 全体共享 | scripts 路径自锁; 其余写走台账锁(§6) |
| 项目根 `.locks/`、`worktrees/` | 约定 | 内嵌型时必须入所在登记仓库的 .gitignore(§1) |

## 5. worktree 内工作纪律

- 该 plan 全部代码改动 + 全量单测 + 评审管线在 worktree 内完成; commit 照常过 commit 门(`commit-check.sh <worktree绝对路径> "<message>"`)。
- iteration readme 按仓库记 SHA 行(`<repo> plan-<id>:<sha>`); diff 照常存 `iteration_NNNN/data/`(`git -C <worktree> diff <起>..<止>`——分支内区间只含本 plan 改动)。
- 大数据(数据集/trace/ckpt)绝对路径引用, 不拷贝。
- e2e 在这里跑, merge 之前, 档位按 §8.0 写定的执行。
- [MUST] 需要改主检出正在改的文件 → 停, 报告用户裁决; 不抢文件。

## 6. AGENTSPACE 台账并行协议 ★

### 6.1 已被保护的路径(scripts 自锁, 无需额外协调)

`new-plan.sh / complete-plan.sh / new-iteration.sh / close-iteration.sh / repos.sh / handoff.sh /
register-module.sh / mode.sh / doctor.sh` 内部经 `lib.sh as_lock()`(mkdir 自旋锁 + 陈旧锁恢复:
pid 存活检查 + mtime 宽限 + mv 原子接管)互斥——**并发调用安全**, 索引文件(plan.md、iterations.md、
两个 index.md、.agentspace-repos、latest 链接)只经 scripts 改写的纪律在任何模式下不变。
§1 已验证目标项目 scripts 具备该锁; 不具备时(旧版插件)把脚本调用也纳入 6.2 的台账锁。

### 6.2 台账锁(罩住全部非 scripts 写路径)

`.locks/ledger/`——持有期间允许执行:

1. **内容文档的共享索引行编辑**: notes.md / tests.md / examples.md / utils.md / register 等入口表格的读-改-写(并发追加会丢行); 新建内容文档本体可锁外(唯一文件名——**前缀 plan/iteration id**, 两会话永不撞名), 索引行必须锁内。
2. **AGENTSPACE git 里程碑提交**: `git add <本会话本次里程碑的明确文件清单> && git commit` 的原子窗——**并行期间禁止 `git add -A`**(会把其他会话在途改动卷进自己的提交, 破坏单一关注点归因)。
3. 任何**跨会话共享文档**的非追加式改写(如更正他人 note 的批注行)。

台账锁是短临界区(秒级): 编辑器先在锁外备好新行内容, 锁内只做"读-合并-写/提交"。
等待方读 owner 告知用户被谁占, 锁外工作继续, 不空转。

### 6.3 所有权规则(避免锁也不该发生的写)

- iteration readme 与 plan 文档正文归**属主会话**(创建它的会话)独占写; 其他会话只读, 需要补充时经属主或在台账锁内以 append-only 日志行形式追加, 不改写他人结构。
- 属主会话收尾时更新自己 readme 的"当前状态·下一步"; 该更新在台账锁内做(它常伴随里程碑提交)。

### 6.4 例行与症状

- 每会话每次收尾跑 `doctor.sh`; 竞态症状(索引行丢失/重复/断链)交 doctor 定位, 遵守"脚本报错恢复"纪律——不手改索引, 修复方案与用户确认。
- handoff 每会话独立、name 带 plan-id(handoff 本就支持多条并存)。
- **并行期间会话续接只走 handoff**——latest 软链在泳道间翻转, 并行时无意义。
- 台账里程碑提交的 message 单一关注点; 提交后告知用户(沿 AGENTSPACE 既有纪律)。

## 7. 重构感知 absorb(对齐协议, worktree 内, 无锁)

> 最危险的不是 git 报冲突, 而是**零冲突自动合并**——分支代码"干净地"落在被重构掉的旧结构上(旧 API / 退役键 / 搬走的声明位置), 文本不撞、语义已死。

absorb 方向永远是**主线 → 分支**(分支把自己的意图重定基到当前主线上; 永不反向)。

a. **差距画像**: `MB=$(git merge-base HEAD <主分支>)`; `git log --oneline $MB..<主分支>` 逐条过, 涉及本 plan 改动面的 commit 读 diff; `git diff --stat $MB..<主分支>` 全景。
b. **交集判定**: 文件交集(两侧 name-only diff 的交) + **语义交集**(本 plan 消费的接口面在主线上是否被改, 挪位置/改签名都算)。两者皆空 → 普通 merge + 全量单测; 任一非空 → 走 c–e。判定要诚实——"文件交集为空"但存在语义触碰(如主线收紧了分支**正在扩展**的配置/flag 面)就是语义交集, 不是干净 absorb。
c. **冲突解决 = 移植, 不是选边**: 每个 hunk 同时理解两侧意图, 把本 plan 的意图移植到新结构上; 禁止机械保留旧块或整段取一侧。
d. **零冲突也查退役面**: 交集非空时 grep 主线 diff 中删掉的符号/键/入口, 确认本 plan 改动在新结构下落点仍有效、无死代码、无引用已删 API。
e. **code review 触发(满足任一)**: ① 解决过任何 conflict hunk; ② 语义交集非空(即使零文本冲突); ③ 主线差距属结构性大改且在本 plan 辐射范围。时机 = absorb 后单测绿、进入 §8.1 锁之前; 对象 = absorb 结果(merge commit 对两侧 parent 的差异 + absorb 后本 plan 改动最终形态); 重点 = 移植丢语义 / 引用退役面 / 主线重构引入的不变式合并后是否仍立。评审报告归档进 iteration data/。
f. **记录**: absorb merge commit 的消息是有意义的一行——absorb 点 + 差距一句话(如 `merge: absorb mainline <sha> — <那边改了什么的一句话>`)。**禁止**默认 `Merge branch/commit ...` 模板, **禁止**任何拼写的记账 id(`plan:NNNN` 与 `plan-NNNN` 都算), `# Conflicts:` 注释行必须剥掉(git commit 默认 cleanup 会剥; 永不用 `--cleanup=verbatim`)。差距画像本体进 readme 日志节——过程叙述归台账, 不归 commit 文本。
g. **absorb 后重测档位**: 文件+语义交集皆空 → T1 快测即可; 任一非空 → 重跑 §8.0 原档位。拿不准就高。
h. **二次确认边界**: 重测失败或结构性 absorb → 回到用户; 例行 absorb + 全绿不再重复请示, 按原确认("绿了就合")继续。

## 8. merge 回主线: CAS squash(唯一合法序列)

### 8.0 验证量定(先量后跑)

**并非每个项目都有 e2e 门, 也并非每次 merge 都需要全量验证。** 量定依据 = 分支的**净改动面**(`git diff <主分支>..<本分支>`——本 plan 的净效果; 主线自身改动已在主线落档时验证过, 不重复计) × 项目验证资产(§1 发现结果, 可能为空)。

| 档 | 适用 | 内容 |
| --- | --- | --- |
| T0 豁免 | 纯文档/注释/测试自身/非运行时路径 | 不跑门; **书面论证**"改动不可能影响验证资产认证的行为面", 落 iteration readme |
| T1 全量单测 | 一切代码改动的默认最低档 | 项目单测套件全跑 |
| T2 定向子集 | 改动面窄且有对应集成/GPU 子集 | T1 + 定向子集(子集选择写明理由) |
| T3 全量门 | 改动触及门认证的行为面(运行时/数值/通信/性能) | T1 + 项目全量验证门(门脚本 + 判定器) |

纪律: **量定在执行前写下**(档位 + 理由)入 readme——先量后跑, 禁止跑完再挑档或沉默跳过;
拿不准 → 就高不就低, 或问用户。量定同时决定资源需求(§9)。

### 8.1 CAS 循环(compare-and-swap; 主线锁罩秒级, 不罩小时级)

**锁为什么还在**: 最后的 check-and-merge 必须原子——若主线在"用户确认"与"merge"之间动了, 已测状态就不再是合入状态。锁不再罩的东西: 验证——它已经在 worktree 内完成了。

```
loop:
  1. 主线相对记录的 absorb 点动了 → absorb(§7) + 按 §7g 档位重测。
  2. 出结果 → 用户确认 merge(确认语义 = "绿了就合")。
  3. 持 .locks/mainline/(一次获取; 多仓库 plan: 所有仓库在同一窗口内):
     每仓库: 主线 HEAD 仍 == 记录的 absorb 点?
       是 → git merge --squash plan-<id>          # 暂存本 plan 净 diff
            → commit-check.sh <repo> "<PR名标题>"    # 先过门再 commit; 内容扫描顺带
            → git commit -m "<PR名标题>"               #   成为全 plan 净 diff 的兜底网
            → git diff plan-<id> <主分支>  →  必须为空
              (合入树 == 已测分支树; 非空 = 钩子/过滤/合错分支 — 中止并报告)
       否 → 放锁 → 回 1
     放锁; 完成
  4. 记账(锁外): 关闭 iteration, 记量定档位与理由、merge 后各仓库主线 squash SHA(永久锚点)与分支名。
  5. 任一点验证失败: fix-forward 回分支 → 回 1; 不在主检出 hotfix(保持归因)。
```

细则:

- **squash commit 标题 = PR 名**: 一行、描述改动本身、type 前缀随仓库惯例(`feat:` / `fix:` / ...)。任何拼写的记账 id、过程叙述、"Merge branch" 形式一律不进——归属由台账(readme 锚点)承担, 永不进仓库历史。
- **净 diff 为空**(分支最终树 == 主线树, 如迭代中改动被全部回滚): **不产生空 commit**——按无净改动关闭合并流程并记 readme。
- **多轮 merge 的 plan**(确认过一次、继续迭代再合): 每轮 accepted squash 后立刻 absorb 回分支——merge-base 重置, 下一轮净 diff 只含新改动。
- **锁纪律**: mkdir 原子 + owner 文件 + `trap` 释放(会话无常驻 shell, 锁生命周期 = 命令生命周期, 任何退出路径都释放)。陈旧锁 → pid 存活检查 → 报告用户后才删(§1 恢复语义)。merge-vs-merge 撞车兜底 = git `index.lock`(后到者重走 §7 对齐)。
- 主检出工作区必须干净才进第 3 步(主线会话在场先协调其提交或 stash)。

## 9. 共享资源仲裁(节点 / IO / 大数据)

- 资源三态: **占用型**(GPU 节点)、**吞吐型**(共享 FS / NFS 带宽)、**只读型**(公用数据集——无需仲裁)。
- 项目有资源工具(utils.md 登记, 如节点监控/占用器) → 用之; 没有 → `.locks/resource-<name>/` mkdir 锁, owner 写明用途与预计时长。
- 占用型: 先占后用, 先资源后主线锁(§8.1 顺序)——不持锁干等。
- 吞吐型: **测量有效性问题优先于互斥问题**——带宽敏感校准/基准不与其他重 IO 作业同跑, 否则测量被污染(不是"会不会撞"而是"数据作不作数")。
- 不多实例安全的 e2e 门(§1 发现行)归入占用型。

## 10. 生命周期收尾(不满意分档——绝不重建 worktree)

- **merge 前不满意** → 同分支继续迭代; 每轮评审记 readme(结果 → 用户裁决 → 继续/合入)。
- **满意** → §8.1 CAS squash; 记各仓库 squash SHA(永久锚点)。
- **merge 后、清理前不满意** → 同(保留的)分支 fix-forward, 重走确认 + CAS。
- **清理后后悔** → 新 iteration(plan 开)/新 plan(plan 闭); 是否 revert squash commit 由用户定。**不做 reopen 机制**——plan/iteration 单向状态机是台账的确定性基石。
- **清理**(仅在被接受的 merge 之后, 用户确认, 且懒——分支保留过 merge 后不满意窗):
  ```bash
  git -C <repo> worktree remove worktrees/<plan-id>/<repo名>
  AGENTSPACE/scripts/repos.sh --remove worktrees/<plan-id>/<repo名>   # 出册须用户确认
  git -C <repo> branch -D plan-<plan-id>   # squash 后 -d 必拒; -D 的依据 = §8.1 diff 为空证明 + readme 记录
  ```
  不 push 远端, 除非用户明确要求。销毁前确认: squash 已落档(readme 有 SHA)、iteration data 已归档、无他人引用(grep 台账中 worktree 路径)。
- 清理后分支尖 SHA 按设计 dangling; 内容档案 = data/ diff, 永久锚点(base SHA、squash SHA)在主线上把 plan 夹住。

## 11. 故障与恢复速查

| 症状 | 处置 |
| --- | --- |
| 台账锁/主线锁/资源锁取不到 | 读 owner 告知用户被谁占; 锁外工作继续(对齐/评审/文档); 不空转 |
| 锁残留(会话被 kill) | pid 存活检查; 无 pid → 5 分钟 mtime 宽限; `mv` 接管并报告用户; 禁止静默强拆 |
| "锁被占"但 owner 为空 | 先鉴别真伪: `.locks/` 整体不存在 ⇒ 父目录缺失的 ENOENT 误读(§1), 不是真持锁 |
| CAS 复查失败(主线动了) | 放锁 → absorb → 按 §7g 重测 → 重进; 这是正常循环, 不是错误 |
| squash 后 diff 为空证明失败 | 中止并报告——merge 被外部碰过(钩子/过滤/合错分支) |
| absorb 后重测 FAIL | fix-forward 回分支; 不在主检出 hotfix |
| 量定档位拿不准 | 就高不就低; 或与用户确认(论证成本 < 重跑门成本) |
| 索引行丢失/重复(竞态症状) | doctor.sh 定位; 修复方案与用户确认; 不手改索引 |
| worktree 目录被手工删 | `git -C <repo> worktree prune` 清元数据; 仍需则重 add |
| scripts 自锁不存在(旧版插件) | 台账锁范围扩大到 scripts 调用(§6.1) |

## 12. 边界

- 本 skill 不替代任何既有门(commit 门 / 项目自有验证门 / 实验手册类纪律)——只管并行下的工作区与台账秩序; 验证量定(§8.0)是对项目既有门纪律的**调度层**, 档位语义以项目自身规则为准。
- 单会话项目用不上本 skill; 主线会话仅需遵守 §4 merge 窗口纪律与 §6 提交卫生。
- 一次性 A/B 对照用的锚 worktree(挂特定 SHA、零 commit、用完即删)固定放 `worktrees/_anchor-<name>/`(下划线 = 非 plan), 不走本 skill 的登记与 merge 协议。
- 纯本地: push、远端 PR、发布都在本 skill 之外, 仍由用户门控。

---

### 附录 A: 与 agentspace 插件的关系

本 skill 是**会话侧约定**: 台账锁/主线锁/资源锁由 skill 在项目根 `.locks/` 实现, 不改动 agentspace 插件本体。若日后插件把台账锁下沉为 scripts 内建(as_lock 同款机制扩展到内容文档提交), 本 skill §6 相应收缩为"调用插件能力"。

### 附录 B: 为什么 §8.1 是唯一合法形式(战例)

本流程的预览版曾让一条泳道用 fast-forward 合回: absorb merge commit("merge main into plan-0025")成了主线 HEAD, 另一条泳道的 absorb("Merge commit '0107e1d' into plan-0030", 默认模板, `# Conflicts:` 注释行烤进正文)也随之混入主线历史, 主线的 first-parent 链开始从泳道内部(开发 commit 与 merge commit)穿行, 真正的主线 commit 反被贬进第二父。内容全对, 历史没法读。CAS squash 序列存在的意义, 就是让主线永远只讲一个故事: 一次被接受的 merge, 一个 PR 名 commit。
