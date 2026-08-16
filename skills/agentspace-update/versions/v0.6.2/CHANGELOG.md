# AGENTSPACE v0.6.2

Upgrade from v0.6.1. Date: 2026-08-16

## Summary

- 新增 Codex 摄取所要求的 `.codex-plugin/plugin.json`，并纳入版本同步、清单校验与回归测试。
- 共享 skills、命令语义、工作区 assets 和用户脚本与 v0.6.1 完全一致；调用符号由平台处理，不进入 skill description 或正文。

## Changes

### [Addition] Codex 标准插件清单
- **What**: 仓库根新增 `.codex-plugin/plugin.json`，声明 `agentspace` v0.6.2、共享 `./skills/`、作者、界面元数据、默认提示词和现有 `icons/icon.png` 资源。既有 `.zcode-plugin/plugin.json`、`marketplace.json` 与 `commands/` 原样保留。
- **Why**: Codex 插件摄取要求标准 manifest；这是平台注册层兼容，不应改变共享 skill 的触发语义或工作区行为。
- **Migration**: plugin-side。现有 `AGENTSPACE/` 工作区无需创建或复制任何插件清单；更新 agent 不修改用户本机 marketplace，也不执行本地安装。

### [Addition] 双清单版本同步与发布校验
- **What**: `new-version.sh` 同步两份 manifest 的版本；`verify-release.sh` 校验 Codex manifest 的必填字段、相对资源路径和跨标记版本一致性；`tests/t20-plugin-manifest.sh` 验证清单契约、既有 commands 保留，以及共享 skill 未引入平台名称分支。
- **Why**: 新增注册格式后必须防止后续版本漏同步，同时用回归测试固定“manifest 兼容、共享能力不分叉”的边界。
- **Migration**: workspace-side 无脚本、模板、`.gitignore` 或 `AGENTS.md` 内容变化，不执行 step 8a 内容迁移或 step 8b 文本操作。仅执行标准 step 8c：运行 `skills/agentspace-update/scripts/update-version.sh 0.6.2` 更新 `AGENTSPACE/.agentspace-version.json`，再复制 `skills/agentspace-update/versions/v0.6.2/architecture.json` 到 `AGENTSPACE/.agentspace-architecture.json`；架构内容与 v0.6.1 相同，仅版本号更新。
