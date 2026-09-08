---
name: agentspace-better-exp
description: Experiment-design interrogation for AGENTSPACE workspaces (x-grilling style). Activate ONLY when BOTH hold — (1) an AGENTSPACE workspace exists in the project root, AND (2) the user explicitly asked for agentspace-exp or has confirmed recording this experiment into exp (an exp manual exists or is about to be created). Interview one question at a time across five axes — fixed and reasonable scope; baseline and control fairness; measurement accuracy (metric definitions, iterations and warmup, timing hygiene, seeds and variance); data completeness (raw logs and configs captured in full to support later reports); reproducibility and stopping criteria — each question with a recommended answer; facts readable from the environment are looked up, never asked; act only after shared understanding is confirmed. Do NOT activate for casual experiment discussion without opt-in, or to enroll correctness-verification runs — enrollment always requires explicit user confirmation, never automatic.
---

# Better Experiments (agentspace-better-exp)

> Experiment-specialized interrogation: align the experiment design with the user BEFORE it runs and BEFORE exp registration. The workspace mechanics (exp scripts, examples/exp_spec/, exp_data/) are owned by the project's AGENTSPACE AGENTS.md — this skill owns the thinking discipline, not the file plumbing.

## 0. Iron rules

1. **Post-consent only** — this skill activates after the user opted into recording the experiment (explicit agentspace-exp request, or accepted your one-time offer). Never activate to make the offer itself; never enroll correctness-verification runs.
2. **One question at a time** — wait for each answer before the next; every question carries your recommended answer (the interviewer is never a blank interrogator).
3. **Facts vs decisions** — anything readable from the environment (repo state, existing configs, tests.md environment, utils tools, prior notes/iterations) is looked up, never asked. Only genuine decisions go to the user.
4. **No launch before consensus** — the experiment is neither registered nor run until the user confirms shared understanding; the manual's 实验问题与范围 and 假设与预期 sections are the written proof of that consensus.
5. **Coverage before depth** — every axis in §1 is touched at least once; an axis is skipped only when the user explicitly says it does not apply.

## 1. The five axes

Walk the axes in order — earlier answers unlock later questions. For each axis: state it, ask, recommend, record the confirmed answer.

### Axis 1 — Scope (fixed, explicit, reasonable)

- The one question this experiment answers; the fixed boundaries (datasets, models, environments, workloads); and what is explicitly OUT of scope. Results outside a fixed test scope are meaningless.
- Reasonableness — can this scope answer the question with the resources at hand (time, hardware, data)? A scope you cannot afford is a wish, not a scope.
- Probing questions — "Which numbers, compared between which systems, would make this experiment conclusive?"; "If the result held on only half the workload, would you still believe it?"

### Axis 2 — Baseline and control fairness

- What is compared against what; the baseline is real, reproducible and equally tuned — same data, same environment, same measurement pipeline on both sides.
- Single-variable principle — one meaningful difference per comparison arm; everything else pinned.
- Seeds, repeats and variance — equal run counts per arm; the seed list pinned in the config; error-bar semantics (std vs confidence interval, with n) decided before launch.
- Probing questions — "Is the baseline number produced by the same code path and harness as the candidate, or quoted from a paper?"; "Are the run counts equal across arms?"

### Axis 3 — Measurement accuracy

- Metric definitions pinned first — exact formula, unit, aggregation, and WHERE in the pipeline each metric is computed. A number without a pinned definition is unfalsifiable.
- Iteration counts and warmup — how many measured iterations, how many warmup iterations discarded, and why exactly those numbers.
- Timing hygiene — the timed region contains only the measured target; setup, IO, logging, compilation and synchronization sit outside it; state what could leak in.
- Environment noise — known noise sources (contention, thermals, background jobs) declared and equalized across arms.
- Probing questions — "Does the timer bracket the kernel only, or does it also swallow the host-to-device copy?"; "Why 10 warmup iterations and not 2 or 50?"

### Axis 4 — Data completeness

- The summary ↔ detail chain — every run's raw logs land in exp/exp_data/exp_NNNN/, configs in examples/exp_spec/exp_NNNN/; per-run metadata (date, commit, seed, duration) recorded alongside.
- Enough detail to re-derive the summary later — a later report (agentspace-better-exp-report) can only be as complete as what was captured now.
- Linked iterations — data that also exists in iteration_NNNN/data/ is copied into exp_data; exp_data is the canonical full record.
- Probing questions — "If a number looks anomalous next week, which file tells you which seed and commit produced it?"; "Could someone else reconstruct the summary table from the files alone?"

### Axis 5 — Reproducibility and stopping

- Exact commands recorded in the manual; tested key-repo commits recorded as points (repo@sha via complete-exp.sh --commit at close).
- Success and falsification criteria written BEFORE launch (假设与预期); budget and abort conditions (runtime/cost ceiling, "stop when X").
- Pilot run — a tiny end-to-end run before the full budget burns (catches pipeline bugs, sizes the real runtime).
- Probing questions — "What result would make you abandon this direction entirely — and is that written down?"; "What is the largest run you can afford to lose to a crash?"

## 2. Output contract

Distill the confirmed answers into the exp manual (templates/exp-manual.md):

- 实验问题与范围 ← Axis 1; 假设与预期 ← Axis 5 (criteria + budget); 方案与配置 ← Axes 2–3, with every config file in examples/exp_spec/exp_NNNN/ registered under a one-line description.

Then register — `scripts/new-exp.sh "title" [--plan NNNN] [--iteration NNNN]` (title slug contract same as plans — lowercase english words, digits, single hyphens). Launch and close follow the workspace AGENTS.md exp module.

## 3. Boundaries

- This skill does not replace plan/iteration workflows — a measurement inside a plan's code change still happens inside iterations; exp records the experiment.
- Report and figure writing belongs to agentspace-better-exp-report.
- If the user declines recording mid-alignment — stop; the experiment proceeds unrecorded, and the offer is not repeated in the same session.
