# AGENTSPACE v0.6.3

Upgrade from v0.6.2. Date: 2026-08-19

## Summary

- 新增 Kimi Code 摄取所要求的 `kimi.plugin.json`，纳入三清单版本同步、清单校验与回归测试。
- 共享 skills、命令语义、工作区 assets 和用户脚本与 v0.6.2 完全一致；调用符号由平台处理，不进入 skill description 或正文。Kimi 官方文档未公开 marketplace 上架流程，安装走本地 `/plugins install`（zip/GitHub URL 亦可），故无对应的 marketplace 清单文件。

## Changes

### [Addition] Kimi 标准插件清单
- **What**: 仓库根新增 `kimi.plugin.json`，声明 `agentspace` v0.6.3、共享 `./skills/`、作者、首页、许可证、关键字和界面元数据（displayName / shortDescription / longDescription / developerName / websiteURL）。既有 `.zcode-plugin/plugin.json`、`.codex-plugin/plugin.json`、`marketplace.json` 与 `commands/` 原样保留。
- **Why**: Kimi Code 插件摄取要求 manifest（`<plugin_root>/kimi.plugin.json`，`name` 为唯一必填字段且匹配 `[a-z0-9][a-z0-9_-]{0,63}`）；这是平台注册层兼容，不应改变共享 skill 的触发语义或工作区行为。
- **Migration**: plugin-side。现有 `AGENTSPACE/` 工作区无需创建或复制任何插件清单；更新 agent 不修改用户本机 marketplace，也不执行本地安装。

### [Addition] 三清单版本同步与发布校验
- **What**: `new-version.sh` 同步三份 manifest 的版本（zcode / codex / kimi）；`verify-release.sh` 校验 Kimi manifest 契约（name 正则、skills 路径、interface 必填元数据）和跨标记版本一致性；`tests/t20-plugin-manifest.sh` 验证三清单契约、既有 commands 保留，以及共享 skill 未引入平台名称分支。
- **Why**: 新增注册格式后必须防止后续版本漏同步，同时用回归测试固定“manifest 兼容、共享能力不分叉”的边界。
- **Migration**: workspace-side 无脚本、模板、`.gitignore` 或 `AGENTS.md` 内容变化，不执行 step 8a 内容迁移或 step 8b 文本操作。仅执行标准 step 8c：运行 `skills/agentspace-update/scripts/update-version.sh 0.6.3` 更新 `AGENTSPACE/.agentspace-version.json`，再复制 `skills/agentspace-update/versions/v0.6.3/architecture.json` 到 `AGENTSPACE/.agentspace-architecture.json`；架构内容与 v0.6.2 相同，仅版本号更新。