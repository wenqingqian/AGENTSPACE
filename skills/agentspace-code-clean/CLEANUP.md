# Code-Clean Post-Processing Procedures (active level)

The procedure half of agentspace-code-clean. SKILL.md carries the standing rules (the commit gate, commit-text rules, comment tiers, file rules); this document carries the workflows for cleaning up code that ALREADY EXISTS. It is read only via the pointer rule in SKILL.md — the user explicitly asked to clean up past code or comments, run style checks, rewrite commit messages, or rebuild history. Never auto-trigger this level; never widen scope on your own initiative. Default posture: report first, edit only after the user confirms (an explicit "just fix it" from the user skips the report step).

## Scope (define before touching anything)

- **Git-range mode** — the user names a commit range. Verify it first: `git log --oneline <start>..<head>` must be linear (merges inside → ask the user to restate the range); `git diff --stat <start>..<head>` gives the file list.
- **File mode** — the user names files or directories.
- **Batch-review mode** — this session's commit-touched files, or the exact commit range the user explicitly gives (`git diff --name-only <base>..<head>`).
- **Scope correction (critical)** — a git range only shows lines modified AFTER the start commit; comments created BY the start commit are invisible in the diff. For a file created inside the range, ask the user whether to review its whole content (recommended) or only the diff lines.
- **Iron rule** — scope is exactly what the user gave you. Never widen it to the rest of the repository.

## Extract candidates

- Python is parsed exactly (tokenize/ast): full comments, inline comments, docstrings.
- Other languages use per-extension comment-marker heuristics — treat those results as candidate lists and verify against the real files.
- Whatever the method, the report cites real `file:line` and real text read from the working tree (in range mode: `git show <end>:<file>`), never from the extractor's word alone.

## Classify (SKILL.md tiers, applied to existing comments)

- **① Delete — feedback-driven "why not alternative X".** Recognizable phrasing: negations ("not a load-balancing choice"); defensive hedges ("kept as a safeguard", "normally unreachable"); alternative-comparisons ("without using retain_graph=True", "deliberately does not implement `__getattr__`"); notes explaining why two functions do not share code; session-directed rules ("do not duplicate these checks elsewhere"); test-instance citations ("we tested with the 4b config").
- **② Delete — redundant comments** that restate the code or a sibling docstring verbatim.
- **③ Trim — over-long prose** to the core what/why (drop hedges and repeated clauses).
- **④ Keep / fine-tune — non-obvious what/why, interface contracts, section dividers, one-line purpose docstrings, license headers (always keep; fix only factual errors or non-local assumptions).** Long docstrings are not automatically bad: file-format contracts, WARNING/caveat blocks, and design notes with real invariants stay. A "why not" that cites a concrete failure mode of this code is a design note → tier ④, not ①.
- **Assert-vs-example** — before deleting a config-citing comment, check whether the restriction is real: if real but unasserted, the fix is to add the `assert`, not to keep the comment. Teaching examples keep their numbers, written relatively ("TP member 0/1").
- **Pitfalls** — do not "improve" tier-④ comments to look busy; keeping ~90% unchanged is the healthy outcome. When in doubt between trim and delete, trim to the factual core. Checkers and agents report; they do not judge — never drop a finding because you can imagine a justification.

## Report (before any edit)

- **Changes (tiers ①–③)**: `file:line` + original text (abridged) + tier + replacement text (verbatim for tier ③ trims).
- **Kept (tier ④)**: one compact line per file listing line numbers and a 3–6 word reason ("non-obvious why", "interface contract").
- End with a summary count (delete N / trim N / keep N). Do not edit until the user confirms.

## Apply and verify

- Edit each accepted item with exact working-tree matches.
- Syntax gate per language: Python `python3 -m py_compile`; Shell `bash -n`; YAML parse via python3 yaml.safe_load; C/C++/others — skip if no toolchain and say so.
- Self-check with `git diff`: only comments/classified findings changed — no behavior drift.
- Commit only when the user asks; the cleanup commit message itself obeys the SKILL.md commit-text rules and passes the commit gate (e.g. `Trim feedback-driven and redundant comments in <area>`).

## Style checkers (on request)

When the user asks for style checks (e.g. imports not at module top level), findings are reported like tier items — JSON-shaped `{checker, file, line, column, text, message}` when produced by tooling, or the equivalent facts when you checked by hand. Report ALL findings; the user decides. Checkers only find; fixes go through the same report-then-confirm flow.

## Commit-message rewrite

- **Draft from staged/uncommitted work**: `git status --porcelain` + `git diff --cached` (fall back to `git diff`); learn the repo's type vocabulary from `git log --oneline -10`; draft per the SKILL.md commit-text rules; commit with a heredoc message. Skip for throwaway WIP snapshots the user explicitly wants committed fast, and for merge commits / rebase artifacts generated by tooling.
- **Amend the last message**: only when the branch has no upstream or the commit is unpushed (`git log @{u}..HEAD`). If already pushed, print the improved message and warn instead of amending.
- **Improve an existing commit `<rev>`**: print the improved message; never rewrite history on your own initiative.
- Every rewrite in a registered repo re-passes the commit gate with the exact new message before committing.

## History rebuild (user decision, explicit request only)

Already-committed violations (bookkeeping ids in messages or content, landed experiment data) are otherwise report-only (doctor [15]). Rebuilding history — rebase / filter-repo — rewrites commit SHAs and belongs to the user; run it ONLY on their explicit request, and then:

1. **Back up first**: `git branch backup/pre-clean-<scope>` before anything; prefer a fresh clone when the rebuild touches many refs or a pushed branch.
2. **Choose the tool by shape**: interactive rebase (`git rebase -i <base>`, reword/edit) for a short recent linear window; `git filter-repo --replace-text <map-file>` for bulk text replacement across deep history (one literal per line, `old==>new`, deletion via empty replacement); `--tree-filter`/`--index-filter` only when file moves are needed.
3. **Guard rails**: never rewrite pushed/shared history without the user explicitly acknowledging the force-push consequences (teammates' clones diverge). The rebuild runs in the code repo, never inside AGENTSPACE/ — but after a rebuild the host SHAs change, so record the new HEAD SHA in the iteration readme the same session (the ledger must point at reality).
4. **Verify after**: re-scan the rebuilt window for the removed shapes (`git log -p -- <paths>`), syntax-gate any file whose comments changed, confirm a clean working tree, and run the project's tests when available.

## Batch comment review (full procedure)

A deep review mode over the files this session's commits touched (or the user's explicit commit range) — report-only, separate from the per-commit gate.

- **Scope (iron rule):** only those files — `git diff --name-only` over the session's commits or the given range. Never widen to the rest of the repository on your own initiative; no automatic whole-repo scan, ever.
- **Whole-file comments:** each in-scope file is reviewed in FULL — every comment in the file, not just lines added this round — so stock narration the added-line gate cannot see (old date stamps, old provenance notes) is caught too.
- **Multi-subagent:** partition the in-scope files across parallel subagents. Each subagent reads its assigned files and returns findings only (file:line · excerpt · which dimension · suggested direction) — it never edits. Findings aggregate to you, and you present one consolidated report to the user.
- **Dimensions:** everything the semantic layer polices in added lines (bookkeeping references in any spelling, run/experiment identifiers, diff-shaped pastes) plus the process-narrative dimensions (date narration, tool/skill provenance) — evaluated across the whole file, stock comments included, plus the four tiers of SKILL.md.
- **Report-only:** the report ends the mode. Fixing is a SEPARATE, user-driven commit — propose the fix batch and wait for the user's go-ahead; never fold fixes into an in-flight commit unasked.
