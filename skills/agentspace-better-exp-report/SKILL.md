---
name: agentspace-better-exp-report
description: Experiment-report writing guidance for AGENTSPACE workspaces — figure craft and prose standards when summarizing experiment results (typically from exp/exp_data records). Activate when the user asks for an experiment report, summary, analysis or figures from recorded experiment data, or when a registered exp closes with reporting requested. Covers figures (check the project's utils/ plotting tools first; colorblind-safe palette with one series-to-color mapping reused across all figures; units on every axis; error bars with stated n and std-vs-CI semantics; self-contained labels) and prose (Chinese base with established English technical terms; no ambiguous single-character shorthand like 门 or 臂; completeness over compression; and self-containment as the core rule — readers cannot see the agent's memory or context, so every symbol, acronym, condition and abbreviation is defined at first use, and every claim cites its figure, table and data path).
---

# Better Experiment Reports (agentspace-better-exp-report)

> Guidance for writing experiment reports and their figures from recorded experiment data — usually exp_data/exp_NNNN/ of a registered exp. The prose rules apply to any technical summary written in the workspace; experiment reports just demand them most.

## 0. Before writing

1. **Utils first** — check utils.md / utils/ for the project's existing plotting tools and reuse them; write a fresh matplotlib script only when nothing fits. New scripts you do write go into utils/ and are registered.
2. **Read the complete record** — exp_data holds the full detail (raw logs, per-run metadata, configs); a report built from the summary table alone wastes the data that was captured.
3. **Know the reader** — ask or infer whether the report targets the user, a paper, or an issue tracker; depth and formality follow.

## 1. Figures

### 1.1 Appearance

- Colorblind-safe palette by default (e.g. Okabe-Ito); ONE series-to-color mapping reused across ALL figures — the reader learns it once.
- Units on every axis; readable tick density; label and legend font sizes legible after scaling; no chartjunk (subtle grids, no 3D, no rainbow colormaps).
- Vector output (PDF/SVG) or PNG at 300 dpi or higher; consistent figure size across the report.
- matplotlib is the default stack unless the project already standardized on another — follow the project.

### 1.2 Data handling

- Classify before plotting — main comparison / ablation / scaling / variance; each figure answers exactly one question the report asks.
- Cleaning rules declared, never silent — outlier exclusion criteria stated with the affected run count; dropped runs reported in the text.
- Variance shown — error bars with n and fixed semantics (std or CI, chosen once for the whole report); single-run numbers labeled as single-run.
- Full data used — derived metrics (speedups, normalized scores) computed from the raw records, never eyeballed; every plotted number traceable to a file under exp_data.

### 1.3 Text in figures

- Self-contained labels — a figure plus its legend must survive being quoted alone: series defined (what "A" and "B" actually are), conditions stated, units present.
- No bare symbols — an axis labeled "x" or a legend entry "m3" carries no meaning alone; write what they are.
- Language — Chinese labels with established English technical terms, matching the prose rules in §2.

## 2. Prose

- **Chinese base, selective English** — established technical terms stay English (throughput, gate, expert, top-1 accuracy); a single common English word beats an awkward Chinese compound when it is the community default.
- **No ambiguous shorthand** — single characters like 门 (gate) or 臂 (arm / expert path) carry no meaning out of context; replace with the full common description or the English term itself.
- **Completeness over compression** — do not compress into ambiguity; a longer clear sentence beats a shorter cryptic one. Brevity comes from cutting what does not matter, never from cryptic wording.
- **Self-containment (core rule)** — the reader cannot see your memory or context: every symbol, acronym, condition and abbreviation is defined at first use; every claim carries its evidence (figure or table number plus the data path under exp_data); assumptions stated; negative and inconclusive results reported, not buried.

## 3. Structure

- Conclusion first — the answer to the experiment question in the first paragraph, evidence after.
- Reading guidance per figure — one or two sentences before each figure telling the reader what to notice.
- Conclusion tiers — data-supported conclusions and speculation clearly separated; speculation explicitly marked.
- Provenance — every figure and table cites its data source (path under exp_data plus the config in examples/exp_spec); every figure is referenced from the text, never orphaned.

## 4. Where reports live

- The full report with figures lives in exp_data/exp_NNNN/report.md — local-only like the rest of exp_data.
- Its executive summary mirrors into the exp manual's 结果 section as self-contained text: no relative figure links (they are dead for any reader without the local data); local-only pointers are labeled as such (e.g. "图见本机 exp_data/.../report.md").
