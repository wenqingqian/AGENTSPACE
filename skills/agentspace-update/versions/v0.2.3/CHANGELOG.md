# AGENTSPACE v0.2.3

Upgrade from v0.2.2. Date: 2026-07-31

## Summary

- Iteration redefined: **code/state change step within a plan** (progressive), not "experiment round"
- iteration-readme.md template: 改动摘要 → 代码变更 (diff); environment section records start/end host commit sha
- Iteration creation rules: plan-only, user confirmation required, meaningful code changes only, no 1:1 commit mapping
- Plan creation rules (from v0.2.2): English titles ONLY, user confirmation, no trivial tasks

## Changes

### [Schema] Iteration redefinition (concept + template)

**What**: iteration semantics changed from "experiment round" (实验轮次) to "code/state change step within a plan" (代码变更迭代). The iteration-readme template section `## 改动摘要` was renamed to `## 代码变更 (diff)`.

**Why**: iterations track repository state changes while implementing a plan — they may include experiment validation (hence data/), but are fundamentally about code changes.

**Migration (both modes — non-destructive)**:

1. Update `AGENTSPACE/templates/iteration-readme.md`: replace the template with the version from `skills/agentspace-init/assets/agentspace/templates/iteration-readme.md` (handled by update flow step 8a — no manual work needed; scripts/templates are replaced from assets)

2. Update `AGENTSPACE/AGENTS.md` — replace the iterations module description:

   a. In the **结构** code block, replace:
   ```
   ├── iterations/        ← index.md(全量索引) + latest 软连接 + iteration_NNNN/{readme.md, data/}
   ```
   with:
   ```
   ├── iterations/        ← index.md(全量索引) + latest 软连接 + iteration_NNNN/{readme.md, data/(实验产物+代码diff)}
   ```

   b. In the **模块: what / when / how** section, replace the entire `### iterations —— 实验轮次` subsection with:
   ```markdown
   ### iterations —— 代码变更迭代 (iterations.md + iterations/)
   - **what**: 实现 plan 过程中的一次**代码/仓库状态变更**(递进关系, 一轮接一轮); 常伴随实验验证, 所以有 readme + data/; **每个 iteration 必属且仅属一个 plan**, 一个 plan 可含多个 iteration
   - **when**: 在 plan 内推进一个有意义的代码变更时创建; 简单改动不建 iteration; 创建前须与用户确认; 结果落盘且 readme 完成时关闭
   - **how**: `scripts/new-iteration.sh <plan-id> "本轮内容"` → 工作并及时更新 readme → `scripts/close-iteration.sh <id> "结果"`
   - **代码 diff**: readme"环境"节记录宿主仓库起始/结束 commit sha; 有关键代码变更时把 `git diff <起始>..<结束>` 存到 `iteration_NNNN/data/`
   - **data 收集三策略** (实验产物全量放入 iteration_NNNN/data/, 该目录已被 gitignore):
     1. 程序支持设置 output 位置 → 直接指向 `iteration_NNNN/data/`
     2. 支持重定向 → `cmd > iteration_NNNN/data/xxx.log`
     3. fallback → 在工作区找到本轮产出的结果文件, `mv` 进 `iteration_NNNN/data/`
   ```

3. **Existing iteration readmes are NOT modified** — old readmes keep their sections. Only new iterations use the new template. No data transformation needed.

4. **Convention change only**: no scripts changed (close-iteration.sh touches only the status line and 日志 section, unaffected by the 改动摘要→代码变更 rename). doctor.sh / status.sh do not parse template sections.

### [Breaking] Iteration creation rules (agent behavior)

**What**: daily skill now requires: iterations only for a plan, user confirmation before creation, only for meaningful code changes, and no assumed 1:1 mapping between plan/iteration/commit.

**Why**: AGENTSPACE supports AI-driven workflows where some commits are made by the user directly; plan/iteration/commit have no necessary correspondence.

**Migration**: agent behavior change — documented in the daily skill (SKILL.md), which is plugin-side, not workspace-side. No workspace file changes.
