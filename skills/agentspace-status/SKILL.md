---
name: agentspace-status
description: Render the AGENTSPACE workspace status workbench — project overview + current state + soft alerts. Triggered ONLY by the explicit /agentspace-status command; never automatic.
---

# AGENTSPACE Status Workbench

Only when the user explicitly runs `/agentspace-status`. Never automatic.

The workbench is a current-state snapshot (what the project is, what state it is in). It does NOT push progress and carries no "next step" narrative.

## Flow (MUST)

0. MUST check the workspace script version gate FIRST: read the `version` field of `AGENTSPACE/.agentspace-version.json` and compare with the plugin version (bare version, no `v`, from the plugin repo's `.zcode-plugin/plugin.json`). If the workspace version differs from the plugin version, or the version file is missing, present the status.sh output verbatim prefixed with EXACTLY this line — no subagent synthesis, no replacement steps:
   `⚠ 工作区脚本 v<workspace> 落后于插件 v<plugin> — 以下为旧版格式输出, 建议先运行 /agentspace-update`
   (Missing version file → `v?`.) If versions match, continue with steps 1–5.
1. MUST run the hard script: `bash AGENTSPACE/scripts/status.sh <plugin-version>`. The script prints every mechanical section, including the soft slots as fixed placeholders: `- 项目: —`, `- 近期主线: —`, and one `  概括[<sha>]: —` line per listed commit.
2. MUST collect the commit SHA → repo mapping from the script output: every line matching `^  概括\[([0-9a-f]+)\]: —`, paired with the repo path from the nearest preceding `#### <name> (<path>)` header (single-host fallback output: the host repo path from the 版本与环境 section's context — locate it via `git -C AGENTSPACE/.. rev-parse --show-toplevel`).
3. MUST spawn exactly ONE Explore subagent with the project-paragraph prompt below (it must receive the SHA list); consume only its `PROJECT_SUMMARY=`, `RECENT_SUMMARY=` and `COMMIT_SUMMARY_<sha>=` lines. Subagent failure or empty result → keep all placeholders.
4. MUST replace the placeholders in the script output: `- 项目: —` → `- 项目: <PROJECT_SUMMARY>`; `- 近期主线: —` → `- 近期主线: <RECENT_SUMMARY>`; each `  概括[<sha>]: —` → `  概括: <COMMIT_SUMMARY_<sha>>` (missing per-SHA result → keep that line's `—`).
5. MUST present the assembled output verbatim — no added sections, no reformatting, no commentary.
6. MUST NOT read any AGENTSPACE/*.md file in the main context during this command (script output + subagent lines are the only sources).
7. Follow-up questions needing workspace content: MUST delegate to an Explore subagent with the extraction prompt below; MUST NOT read workspace files in the main context.

## Output template (verbatim)

```
# AGENTSPACE Status <YYYY-MM-DD>

## 项目总览
- 项目: <paragraph> / —
- 现状: <one line from the script>

### 关键代码仓库
- <one line per registered repo: name (path) · 分支 · 脏 N · 最新: sha date subject ↑a/↓b> / (无登记仓库)

## 版本与环境
- <two lines from the script>

## 推进总览
- <one line per plan>

## 进行中
- <one line per item> / ✓ 无进行中

## 近期动态
### 主线
- 近期主线: <2-3 句合成> / —
### 代码提交 (关键代码仓库 · 每仓库最近 3 条) — 空登记时回退 (宿主仓库 · 最近 5 条) 并标注 (未登记 …)
#### <repo name> (<path>) — 回退模式无此行, 为旧式单宿主列表
- <sha> · <date> · <subject>
  改动: <N> files, +A/-D · 关联: <iteration_N · plan:XXXX 标题> / —
  概括: <2-3 句, 按 sha 分析> / —
### 工作区事件 (最近 10 条)
- <one line per event> / (无动态)
### 台账 (agentspace 记账 · 最近 5 条)
- <one line per ledger commit> / (无台账)

## 软告警 (N)
- <one line per alert> / ✓ 无软告警

## 会话入口
- 最近关闭: <latest closed iteration, if any> / ✓ 无已关闭迭代
- <handoff lines>
```

Section names, order and empty-state placeholders are hard-coded by status.sh — the command side must not modify them.

## Project-paragraph subagent prompt (verbatim; replace <SHA1> <SHA2> … with the collected list)

> Read-only synthesis. Read ONLY these files: AGENTSPACE/AGENTS.md (项目背景 section), AGENTSPACE/plan.md, AGENTSPACE/plan/index.md, AGENTSPACE/iterations.md, AGENTSPACE/iterations/index.md, AGENTSPACE/notes.md. Produce THREE deliverables:
> 1. `PROJECT_SUMMARY=<paragraph>` — ONE paragraph (≤120 Chinese characters) stating what the project is and its current state.
> 2. `RECENT_SUMMARY=<2-3 句>` — what the recent activity (events + commits) means as a whole: what converged, what was reverted, what is pending. Do not enumerate — synthesize.
> 3. For EACH `SHA@REPO` pair in this list: <SHA1>@<REPO1> <SHA2>@<REPO2> — inspect it via `git -C <REPO> show --stat <sha>` and `git -C <REPO> log -1 --format='%s' <sha>`; write `COMMIT_SUMMARY_<sha>=<2-3 句中文>` — what the change does and why, linking to its iteration/plan when the workspace records it. If a SHA cannot be inspected, omit its line.
> Return EXACTLY one line per deliverable as `FIELD=value` (values must not contain newlines). No file excerpts, no lists of facts, no commentary.

## Follow-up extraction subagent prompt (verbatim)

> Read-only extraction. Read the workspace files needed to answer: <user's question>. Return ONLY the requested facts, one per line, as `FIELD=value`. No prose, no file excerpts, no markdown.

## Notes

- The script output is a complete template even without soft content (every soft slot stays `—`).
- Status ≠ progress: never invent "next steps"; if the workspace has no active work, the sections say so.
- Soft slots (项目 paragraph, 近期主线, per-commit 概括) are hard-coded placeholders whose CONTENT is agent-analyzed — the slot is template-fixed, the content is soft. Everything else (events, ledger, stats, linkage, anchors) is mechanical.
- 近期动态 is a mechanical activity timeline: workspace events from the index date columns (plan created/completed, iteration opened/closed, note added, handoff produced), code commits from the REGISTERED key repos (`.agentspace-repos`, 3 per repo — with per-commit stats and iteration linkage; empty registry falls back to single-host probing with a 未登记 marker), and the workspace's own ledger commits (type prefix mapped to a Chinese label, e.g. plan:→计划 / fix:→修复).
- Version gate: the workspace's scripts are workspace-side assets updated only by /agentspace-update; an old workspace produces old-format output even under a new plugin, and the old script itself cannot warn about drift — the gate is the only place this can be caught.
