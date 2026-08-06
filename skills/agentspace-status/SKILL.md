---
name: agentspace-status
description: Render the AGENTSPACE workspace status workbench — project overview + current state + soft alerts. Triggered ONLY by the explicit /agentspace-status command; never automatic.
---

# AGENTSPACE Status Workbench

Only when the user explicitly runs `/agentspace-status`. Never automatic.

The workbench is a current-state snapshot (what the project is, what state it is in). It does NOT push progress and carries no "next step" narrative.

## Flow (MUST)

1. MUST run the hard script: `bash AGENTSPACE/scripts/status.sh <plugin-version>` — plugin version = bare version (no `v`) read from the plugin repo's `.zcode-plugin/plugin.json`. The script prints every mechanical section, including the `- 项目: —` placeholder line.
2. MUST spawn exactly ONE Explore subagent with the project-paragraph prompt below; consume only its `PROJECT_SUMMARY=<paragraph>` line. Subagent failure or empty result → keep `- 项目: —`.
3. MUST replace the script output's `- 项目: —` line with `- 项目: <paragraph>`.
4. MUST present the assembled output verbatim — no added sections, no reformatting, no commentary.
5. MUST NOT read any AGENTSPACE/*.md file in the main context during this command (script output + subagent paragraph are the only sources).
6. Follow-up questions needing workspace content: MUST delegate to an Explore subagent with the extraction prompt below; MUST NOT read workspace files in the main context.

## Output template (verbatim)

```
# AGENTSPACE Status <YYYY-MM-DD>

## 项目总览
- 项目: <paragraph> / —
- 现状: <one line from the script>

## 版本与环境
- <two lines from the script>

## 推进总览
- <one line per plan>

## 进行中
- <one line per item> / ✓ 无进行中

## 近期动态 (最多 10 条)
- <one line per activity — workspace event or commit summary> / (无动态)

## 软告警 (N)
- <one line per alert> / ✓ 无软告警

## 会话入口
- <handoff lines>
```

Section names, order and empty-state placeholders are hard-coded by status.sh — the command side must not modify them.

## Project-paragraph subagent prompt (verbatim)

> Read-only synthesis. Read ONLY these files: AGENTSPACE/AGENTS.md (项目背景 section), AGENTSPACE/plan.md, AGENTSPACE/plan/index.md, AGENTSPACE/iterations.md, AGENTSPACE/iterations/index.md, AGENTSPACE/notes.md. Synthesize ONE paragraph (≤120 Chinese characters) stating what the project is and its current state. Return EXACTLY one line in the form `PROJECT_SUMMARY=<paragraph>`. No file excerpts, no lists, no commentary.

## Follow-up extraction subagent prompt (verbatim)

> Read-only extraction. Read the workspace files needed to answer: <user's question>. Return ONLY the requested facts, one per line, as `FIELD=value`. No prose, no file excerpts, no markdown.

## Notes

- The script output is a complete template even without the paragraph (the line stays `—`).
- Status ≠ progress: never invent "next steps"; if the workspace has no active work, the sections say so.
- 近期动态 is a mechanical activity timeline (max 10, dates shown, no date-window filter): workspace events from the index date columns (plan created/completed, iteration opened/closed, note added, handoff produced) merged with commit summaries (type prefix mapped to a Chinese label, e.g. plan:→计划 / fix:→修复).
