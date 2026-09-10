---
name: agentspace-base-plan
description: AGENTSPACE 工作区的基准计划(base plan, 方向锚点)触发器 — 在 plan/base/ 下创建、审核、激活与退役基准计划的工作流入口。基准计划是不可变的方向锚点, 约束由它派生的一切 plan/iteration/exp(派生关系经 new-plan.sh --base NNNN 记录)。当用户要求创建或修改基准计划、提到因 plan 反复漂移需要锚定方向、或询问某基准计划内容时激活。持有审核门 — 草稿文件写好后直接结束 agent 会话, 由用户在文件上以评论形式反馈(绝不走 agent plan 模式审核); 激活只在后续会话经用户明确批准后执行。激活后文件冻结(校验和钉定, doctor 审计) — 基准被证明不可实现或有错时必须如实告知用户; 方向变更只能由用户决定(新基准取代, 旧文件永不改写)。
---

# 基准计划 (agentspace-base-plan)

> 基准计划的工作流入口 — 创建门、用户审核流、生命周期。语义与纪律归工作区 AGENTS.md 的 plan 模块; 本 skill 是触发器并持有审核流契约。

## 0. 启动守卫

按序检查; 任一不成立则静默退出(按普通请求处理):
1. 用户要求创建/修改基准计划、要求锚定某个方向(如同一方向多个 plan 反复漂移)、或询问某基准计划的内容
2. 项目根存在 `AGENTSPACE/` 目录 — 若缺失, 直接说明并停止(工作区只能经 /agentspace-init 创建)

## 1. 创建门 (MUST)

- **仅由用户驱动** — 用户要求方向锚点时才创建基准计划, 绝不自行发起(漂移明显造成损害时可附证据提议一次; 被拒后不再重复)。
- **是方向, 不是实施计划** — 基准计划描述"去哪"; 实施工作留在普通 plan, 经 `--base NNNN` 关联。
- 标题必须英文(标题会成为文件名); 文档内容语言不限。

## 2. 审核流 (MUST — 不走 agent plan 模式审核)

1. `AGENTSPACE/scripts/new-base-plan.sh "English direction title"` → plan/base/ 下的待审核草稿。
2. 填写草稿的 方向 / 约束 / 边界 三节(激活前草稿可改)。
3. **直接结束本会话** — 审核即用户在文件上以评论形式反馈本身。输出文件路径, 请用户在文件上评论; 绝不自批, 绝不在创建会话内激活。
4. 下一会话: 读取用户在文件上的评论。按评论修订草稿(每次修订同样呈交), 或在用户明确批准后运行 `AGENTSPACE/scripts/activate-base-plan.sh <id>`。

## 3. 生命周期

```bash
AGENTSPACE/scripts/new-base-plan.sh "English direction title"   # 待审核草稿 → 填写 → 结束会话呈交用户审核
AGENTSPACE/scripts/activate-base-plan.sh <id>                   # 仅限用户明确批准; 钉定 sha256, 冻结文件
AGENTSPACE/scripts/retire-base-plan.sh <id> <replaced|voided> "原因" [--by NNNN]   # 仅限用户决定的方向变更
```

派生 plan 用 `new-plan.sh "标题" --base NNNN`(关联落在 基准 列; doctor [17] 会报告从非生效基准派生的开放 plan)。

## 4. 不可变与方向变更 (MUST)

- **绝不修改 plan/base/ 下已激活的文件** — 激活时钉定的校验和由 doctor 审计; 不符即损坏而非漂移, 永不自动修复。
- **基准不可实现或有正确性错误 → 如实告知用户并停止** — 方向变更只能由用户决定: 新建后继基准计划, 将旧基准 retire(被取代/废弃); 旧文件永不改写。
