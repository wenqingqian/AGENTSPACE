# AGENTSPACE v1.6.0

Upgrade from v1.5.3. Date: 2026-09-13

## Summary

- 新增 `/agentspace-init-light`: 仅创建 plan 模块的轻量工作区(plan.md + plan/ 含 base plan 生命周期), scripts/templates 整套照常部署
- light 工作区自描述: AGENTS.md 带 `## agentspace edition: light` 块, architecture.json 为 modules=["plan"] 的子集快照
- 未初始化模块的流转脚本经 lib.sh `as_require_module` 统一拒绝并提示扩展路径; complete-plan 在无 notes 模块时适配收尾提示
- update 流新增 light 工作区检测与扩展契约(扩展为完整形态后再走 changelog 链)

## Changes

### [Addition] agentspace-init-light skill 与 /agentspace-init-light 命令
- **What**: 新增第 14 个 skill `agentspace-init-light`(SKILL.md + SKILL.zh-CN.md + scripts/init-agentspace-light.sh + assets/)与斜杠命令 `commands/agentspace-init-light.md`。light 初始化只创建 plan 模块: AGENTSPACE/AGENTS.md(light 版, 带 edition 标记)、plan.md、plan/{index.md,todo,done,base}、.gitignore、.agentspace-version.json、.agentspace-architecture.json(light 子集快照)、.agentspace-repos、.agentspace-whitelist、scripts/ 与 templates/ 整套(与 /agentspace-init 同源复制); 根 AGENTS.md 从 light 模板创建。
- **Why**: 只需要任务计划管理的项目不必携带其余 9 个模块。
- **Migration**: 纯插件侧新增, 工作区无需任何操作。

### [Addition] light 工作区脚本守卫与 complete-plan 适配
- **What**: lib.sh 新增 `as_require_module <入口路径> <模块名>`(入口路径存在即模块已初始化的契约; handoff 以目录为入口 — index.md 缺席时脚本会自重建, 目录缺席才是未初始化); new-iteration.sh / close-iteration.sh(守 iterations.md)、new-exp.sh / start-exp.sh / complete-exp.sh(守 exp.md)、register-module.sh(守 register.md)、handoff.sh(守 handoff/ 目录)在参数校验后、任何读写前调用该守卫 — light 工作区拒绝并提示运行 /agentspace-update。complete-plan.sh 收尾提示分支: notes.md 在场(完整工作区)输出与既往逐字相同的 MUST 行与 commit 提示; 不在场(light)输出 light 适配行且 commit 提示不含 notes 路径。doctor [7] 对缺失 notes.md 静默跳过; status.sh 最近关闭锚点读取对缺失 iterations/index.md 容错。init-agentspace.sh 本体无行为变化。
- **Why**: light 工作区下模块脚本此前会死在 awk "section not found"; 完整工作区下守卫恒放行、行为不变。
- **Migration**: scripts 由 update 流步骤 8a 从资产整体替换, agent 无需手动操作。工作区 AGENTS.md / 表结构 / .gitignore 无任何变化(纯 8a + 8c 发布)。

### [Addition] light 工作区检测与扩展契约(update 流)
- **What**: agentspace-update skill(SKILL.md 步骤 6c2 / SKILL.zh-CN.md)新增 light 检测与扩展规则 — 检测: AGENTS.md 带 `## agentspace edition` 块(值 `light`), 或工作区 architecture.json 的 modules 是同版本档案 modules 的真子集; 扩展(应用 changelog 链之前): 从规范资产 `skills/agentspace-init/assets/agentspace/` 复制缺失模块文件(iterations.md + iterations/、exp.md + exp/、data.md + data/、examples.md + examples/、utils.md + utils/、tests.md + tests/、notes.md + notes/、register.md、handoff/index.md), AGENTS.md 按规范资产智能合并到完整形态并删除 edition 块(项目简介/根仓库简介/用户规则逐字保留), 迁移台账记 `applied — light expansion`; 已扩展模块的 changelog 条目改为对照目标 architecture.json 验证终态后记 `not-applicable`, 不盲目重放; 用户拒绝属于缺失模块的条目时该模块保持缺失。
- **Why**: light 是起点而非永久形态, 更新链的 diff 与迁移需要一个确定性的扩展契约。
- **Migration**: 纯插件侧规则新增, 本次更新(workspace v1.5.3)不涉及 — 该契约服务于未来对 light 工作区的更新。

### [Addition] 发版工具与门禁同步
- **What**: new-version.sh 版本标记面 7→8(新增 init-light 资产 architecture.json); verify-release [1] 版本一致性纳入同一标记; 新增 [15] light 资产契约检查(light architecture 文件集 == 最新完整档案 − 未初始化模块文件、modules==["plan"]、version/constants 与完整档案一致、light AGENTS.md 带 edition 标记、[8] 新增 light 扩展机制对)。tests 新增 t39(light 工作区全契约回归)。均为仓库根开发工具/测试, 不进入部署工作区。
- **Why**: light 资产是派生快照, 没有门禁会在完整架构演进时静默漂移。
- **Migration**: 开发工具与测试, 工作区无需操作。
