---
name: agentspace-parallel
description: Parallel development on AGENTSPACE-managed projects — per-plan git worktrees with a PR-like, local-only branch lifecycle. One plan = one worktree set = one branch per touched repo; develop + test (unit and e2e) inside the worktree, present results and wait for user confirmation, then merge back as exactly ONE squash commit per repo through a compare-and-swap mainline lock (no merge commits, no fast-forward, no bookkeeping ids on the mainline). Covers refactor-aware absorb (mainline merges INTO the branch), ledger write-contention protocol (scripts self-lock + ledger lock), shared resource (GPU/IO) arbitration, and dissatisfaction tiers (iterate on the same branch — never rebuild the worktree). Use when the user starts or manages a parallel work line on a project whose root has an AGENTSPACE/ workspace (e.g. "并行启动 plan:NNNN", "set up a parallel workspace", "同时做第二个 plan", "work on two plans at once").
---

# Parallel workspaces on AGENTSPACE-managed projects (PR-like, local-only)

> Positioning: this skill is a **project-agnostic** operating system for parallel development.
> Every project specific (repo list, verification gates, dependency wiring, resource tools) is
> read dynamically from that project's AGENTSPACE in step §1 — nothing is hardcoded here.
> Everything is **local**: no push, no remote PR machinery; publishing stays user-gated and
> out of scope. A single-project instantiation usually lands as one note under the project's
> `AGENTSPACE/notes/`.

## 0. Iron rules (invariants)

1. **One plan = one worktree set = one branch name** (`plan-<plan-id>` in every touched repo);
   worktree lifecycle = plan lifecycle (multiple iterations share it). [MUST] a plan's worktrees
   live ONLY at `<project-root>/worktrees/<plan-id>/<repo-name>` — always outside every registered
   repo; any other location is forbidden (ad-hoc paths resolve against whatever the cwd happens to
   be and create worktrees in strange places).
2. **Local-only**: no remote operations anywhere in this skill. Push is the user's separate decision.
3. **The main checkout belongs to the mainline session**; a lane never edits it. The main checkout
   must be clean and untouched only during a merge window (§8.1 step 3) — seconds, not hours.
4. **One shared AGENTSPACE ledger**: index/registry state is written only by `scripts/` (self-locked);
   every other write path goes through the ledger lock (§6). **Never `git add -A` in the ledger repo
   while lanes are active** — it would sweep other sessions' in-flight edits into your commit.
5. **Verification is tiered before it runs** (§8.0) and runs **inside the worktree, before merge**.
   No silent skips.
6. **Merge-back has exactly one legal form** (§8.1): mainline lock → re-check base →
   `merge --squash` → commit gate → commit → diff-empty proof → unlock. No fast-forward, no plain
   merge, no merge commits on the mainline, no "Merge branch xxx" titles — each accepted merge is
   exactly ONE commit whose title reads like a PR name.
7. **Intersecting change surfaces never block development** — file-level or semantic. A lane is
   its owner session's sandbox: develop freely. The ONLY blocking point is merge-back — a conflict
   surfaced by §7 absorb (text hunk / retired-surface hit / structural absorb / retest failure)
   freezes the merge and is settled with the user before the lane updates (§7h). Worktrees isolate
   working directories; intersections are resolved at the mainline's entry point, not at admission.

## 1. Project discovery (parameterize before any operation)

A parallel session **assumes nothing** about the project. Read each row:

| Item | Source | Used for |
| --- | --- | --- |
| Workspace rules / mode | project-root `AGENTS.md` (or `AGENTSPACE/AGENTS.md`) | general constraints; confirm AGENTSPACE/ exists |
| Registered repos | `AGENTSPACE/.agentspace-repos` + `scripts/repos.sh --list` | worktree candidate set; commit-gate scope |
| Mainline branch per repo | `git -C <repo> branch --show-current` on each main checkout | branch baseline |
| Verification assets | `AGENTSPACE/tests.md` (test-script index) | basis for §8.0 tiering; **a project may have no long gate** (unit tests only, or neither) |
| Active plans / iterations + **change-surface declarations** | `plan.md` todo table + `iterations.md` in-progress table + each plan doc | input to §2's informational intersection scan (the §7a gap preview) |
| Dependency wiring | each repo's env scripts (env.sh-style) and AGENTS.md | §3 step 2 redirection |
| Scripts self-lock | `grep -n 'as_lock' AGENTSPACE/scripts/lib.sh` | §6.1 precondition; if absent, the ledger lock also covers script calls |
| Resource tools | `AGENTSPACE/utils.md` | §9 node/resource tooling (if any) |
| Session handoff | `AGENTSPACE/handoff/index.md` | consume any handoff pointing at this plan first |
| e2e multi-instance isolation | gate scripts themselves (ports / output dirs / temp stores) | whether two lanes may run e2e concurrently; if not isolated, e2e joins §9 as an occupy-class resource |
| **Embedded-form check** | is the project root itself inside a registered repo? | if yes: [MUST] hard precondition before ANY lock or worktree is created — `.locks/` and `worktrees/` go into that repo's `.gitignore` first (iron rule — lock owner files contain literal bookkeeping ids; a stray `git add -A` would trip the commit gate or sweep whole worktrees into the host) |

**Lock namespaces** (this skill's convention, under the project root): `.locks/mainline/` (§8) ·
`.locks/ledger/` (§6) · `.locks/resource-<name>/` (§9). All created by **atomic `mkdir`** (NFS-safe,
no flock). The `owner` file inside carries `plan:<id> iteration:<id> <host> pid:$$ <ISO-time> <purpose>`.
**`mkdir -p <project-root>/.locks` before first use** — when the parent is missing,
`mkdir .locks/<name>` fails with ENOENT, which a `2>/dev/null` then misreads as "lock held"
(observed in the field); atomicity is needed only at the last component.
**Stale-lock recovery mirrors `as_lock` semantics**: a lock whose owner pid is dead is stale; a
pid-less lock older than a 5-minute mtime grace is stale (crash between mkdir and owner write);
take over by `mv` (exactly one waiter wins), never `rm -rf` a lock in place, and report the
takeover to the user — never silently break a lock.

## 2. Applicability check (before touching any command)

- **Change-surface intersection (informational — never a gate)**: the target plan doc's
  change-surface declaration (repo list + file/semantic surface — if the plan doc lacks one, the
  owner session writes it first) vs the mainline plan and every other active parallel plan, per
  repo. Name any intersecting plan explicitly and record the finding in the iteration readme —
  that is all. Admission never stops or queues on an intersection (iron rule 7); the scan exists
  to give §7a's gap analysis a preview, because every intersection materializes and is handled at
  merge-back (§7/§8). Multiple lanes touching the SAME repo are legal, intersecting or not (git
  supports multiple worktrees per repo; branch names differ).
- **Dependency on uncommitted main-checkout changes**: a worktree branch forks from the mainline
  HEAD and does NOT carry uncommitted content; wait for that commit first.
- Report the action list (worktree paths + branch names + repos.sh registration rows) and get the
  user's one-time confirmation — this also satisfies AGENTSPACE's "registration requires explicit
  user confirmation" discipline; no per-step asking afterwards.

## 3. Bringing up worktrees

1. **Create** — [MUST] exactly this fixed path and command form (fixed organization — the ONLY
   legal location, at the project root which may or may not be a git host, always outside every
   registered repo; no other location is legal — iron rule 1):
   ```bash
   cd <project-root>
   git -C <repo> worktree add worktrees/<plan-id>/<repo-name> -b plan-<plan-id> <repo mainline>
   AGENTSPACE/scripts/repos.sh --add worktrees/<plan-id>/<repo-name>   # every worktree checkout must be registered, or the commit gate won't recognize it
   ```
   Build worktrees only for repos this plan actually changes — never for untouched ones.
   Invariants: **plan is the only organization axis** (the `<plan-id>/` dir lives and dies with the
   plan); the location is always outside all registered repos (embedded-form projects: `.gitignore`,
   see §1); multi-repo plans reuse the SAME branch name `plan-<plan-id>` in each repo (separate
   namespaces, no collision).
2. **Dependency redirection** (generic pattern; wiring per discovery): env scripts in a worktree
   resolve sibling checkouts relative to their own location; for repos without a worktree, use the
   project-documented override variable pointing back at the main checkout, or place a symlink to
   it — whichever the project already does. Principle: **repos you change resolve from the
   worktree, repos you don't change resolve from the main checkout**.
3. **Self-check triple** (all three must pass): ① env-script output points dependency sources at
   the expected checkouts; ② the target package imports resolve to worktree paths; ③
   `commit-check.sh <worktree-path> "self-check"` exits 0 (registration recognized).
4. **Record the base**: one row per repo in the iteration readme's environment section —
   `<repo> plan-<id>:<base-sha>` (a PERMANENT anchor; it stays reachable on the mainline forever).

## 4. Roles and freezing

| Area | Owner | Constraint |
| --- | --- | --- |
| Main checkouts | the mainline session (idle if none) | frozen only during a §8.1 step-3 merge window (no file edits, no branch switches, no checkouts while it runs) |
| `worktrees/<plan-id>/` | that plan's parallel session | all of the plan's code changes, unit tests, reviews, commits |
| `AGENTSPACE/` | shared by all | scripts paths self-lock; all other writes under the ledger lock (§6) |
| `.locks/`, `worktrees/` at project root | convention | gitignored in the containing registered repo when embedded-form (§1) |

## 5. In-worktree discipline

- All of the plan's code changes + full unit tests + review pipeline happen inside the worktree;
  every commit passes the gate as usual (`commit-check.sh <worktree-abs-path> "<message>"`).
- iteration readme records per-repo SHA rows as `<repo> plan-<id>:<sha>`; diffs go to
  `iteration_NNNN/data/` as usual (`git -C <worktree> diff <start>..<end>` — the in-branch range
  contains only this plan's changes).
- Big data (datasets / traces / checkpoints) is referenced by absolute path, never copied.
- e2e runs HERE, pre-merge, at the tier written down per §8.0.
- [MUST] Before entering §8.1 merge-back (development wrap-up): run the commit gate's semantic
  review across ALL dimensions over the lane's whole diff (bookkeeping ids / comment hygiene /
  commit-quality rubric). Report layer — findings go to the user and do NOT block the merge; the
  §8.1 commit gate keeps its blocking role.
- [MUST] Need to change a file the mainline is editing → stop and report to the user for
  arbitration; never snatch files.

## 6. AGENTSPACE ledger parallel protocol ★

### 6.1 Already-protected paths (scripts self-lock — no extra coordination)

`new-plan.sh / complete-plan.sh / new-iteration.sh / close-iteration.sh / repos.sh / handoff.sh /
register-module.sh / mode.sh / doctor.sh` are internally mutexed via `lib.sh as_lock()` (mkdir
spinlock + stale-lock recovery: pid liveness + mtime grace + atomic `mv` takeover) — **concurrent
calls are safe**, and the discipline that index files (`plan.md`, `iterations.md`, both
`index.md`, `.agentspace-repos`, the `latest` symlink) are written only by scripts is unchanged
in any mode. §1 verified the target project's scripts have this lock; if they don't (older
plugin), script calls also fall under §6.2's ledger lock.

### 6.2 The ledger lock (covers every non-scripts write path)

`.locks/ledger/` — while held, you may:

1. **Read-modify-write shared index rows of content docs**: entry tables in notes.md / tests.md /
   examples.md / utils.md / register etc. (concurrent appends lose rows). Creating a new content
   doc body may happen outside the lock (unique filename — **prefix it with the plan/iteration
   id** so two sessions can never collide); its index row goes in under the lock.
2. **AGENTSPACE git milestone commits**: the atomic window of `git add <explicit file list of THIS
   session's milestone> && git commit` — `git add -A` is forbidden while lanes are active (it
   would pull other sessions' in-flight edits into your commit and destroy single-concern
   attribution).
3. Any **non-append rewrite of a cross-session shared doc** (e.g. correcting an annotation line in
   someone else's note).

The ledger lock is a short critical section (seconds): prepare the new row content outside the
lock; inside, only read-merge-write / commit. A waiter reads `owner`, tells the user who holds it,
and keeps working outside the lock — no spinning.

### 6.3 Ownership rules (writes that shouldn't happen even with a lock)

- An iteration readme or plan doc body belongs to its **owner session** (the one that created it);
  other sessions read-only — to add something, go through the owner, or append a log-only line
  under the ledger lock; never restructure someone else's doc.
- The owner session updates its own readme's "当前状态 · 下一步" at wrap-up; that update happens
  under the ledger lock (it usually accompanies a milestone commit).

### 6.4 Routine and symptoms

- Every session runs `doctor.sh` at every wrap-up; race symptoms (lost/duplicated index rows,
  broken links) go to doctor — per the script-error discipline, never hand-edit indexes; repair
  plans are confirmed with the user.
- One handoff per session, named with the plan-id (handoffs already support coexistence).
- **Session re-entry while lanes are active goes ONLY through handoff** — the `latest` symlink
  flips between lanes and means nothing during parallelism.
- Ledger milestone messages stay single-concern; tell the user after committing (standing
  AGENTSPACE discipline).

### 6.5 Collaborative agent workspace (collaboration table)

Any parallel work based on this skill registers itself in the collaboration table: [MUST] call
`AGENTSPACE/scripts/parallel-workspace.sh --init <plan_id> <desc> [info]` at start-up (§3
bring-up), and [MUST] `--remove <plan_id>` at wrap-up. Everything else is on-demand, never a
mandated loop: `--show` gives lane-to-lane status visibility and `--send`/`--recv` pass async
sticky notes — no forced polling. Merge-back goes through the script's merge state — short-window
iron rule: attempt the merge / resolve conflicts BEFORE calling `--merge`; `--merge` is called
only at zero impediment; sequence = set the merge state → do the real merge outside the table
fast → `--remove` releases the slot; never sit in the merge state blocking others. Data file:
`AGENTSPACE/.agentspace-parallel-workspace.txt` (inside the ledger, gitignored).

## 7. Refactor-aware absorb (alignment protocol, in the worktree, lock-free)

> The most dangerous outcome is not a git conflict — it's a **zero-conflict auto-merge**: branch
> code landing "cleanly" on structures the mainline refactored away (retired APIs / removed keys /
> moved declarations). Text doesn't collide; semantics are already dead.

The absorb direction is ALWAYS **mainline → branch** (the branch re-bases its intent onto current
mainline; never the reverse).

a. **Gap profile**: `MB=$(git merge-base HEAD <mainline>)`; walk `git log --oneline $MB..<mainline>`
   commit by commit, reading the diff of any commit touching this plan's change surface;
   `git diff --stat $MB..<mainline>` for the panorama.
   [MUST] History-rewrite probe (before absorbing, besides the existing HEAD-movement detection):
   `git merge-base --is-ancestor <base> <mainline>` — is the lane-recorded base SHA still a
   mainline ancestor? False → the mainline's history was rewritten (rebase / amend /
   title-and-body polish class). Disposition — never a freeze by itself (§7h's freeze list stays
   closed): `git diff <base>..<mainline>` empty (pure metadata rewrite, zero content change) →
   report to the user "mainline history rewritten but content unchanged" + re-point the lane's
   base anchor at the new SHA + continue the absorb; non-empty (the rewrite moved content) → the
   normal absorb path — pull the gap back into the worktree, resolve conflicts, retry the merge.
   Motive: better-commit-style title/body rewrites swap SHAs and invalidate anchors, but as long
   as the content is unchanged, the squash's net diff is unaffected.
b. **Intersection verdict**: file intersection (both sides' name-only diffs) + **semantic
   intersection** (is an interface surface this plan consumes changed on the mainline — moved or
   re-signed counts). Both empty → plain merge + full unit tests. Either non-empty → c–e.
   Write the verdict honestly — "file intersection empty" with a semantic touch (e.g. the mainline
   tightened a config/flag surface the branch EXTENDS) is a semantic intersection, not a clean
   absorb.
c. **Conflict resolution = porting, not picking sides**: understand both intents per hunk and port
   this plan's intent onto the new structure; never mechanically keep old blocks or take one side
   wholesale.
d. **Check retired surfaces even at zero conflicts**: when the intersection is non-empty, grep the
   symbols/keys/entry points deleted in the mainline diff; confirm this plan's changes still land
   somewhere valid — no dead code, no references to removed APIs.
e. **Code-review triggers (any suffices)**: ① any conflict hunk resolved; ② semantic intersection
   non-empty (even with zero text conflicts); ③ the mainline gap is a structural change inside
   this plan's blast radius. Timing = after post-absorb unit tests are green, before entering the
   §8.1 lock; object = the absorb result (merge commit's diff against both parents + this plan's
   final absorbed shape); focus = ported-away semantics / references to retired surfaces /
   invariants introduced by the mainline refactor still holding after the merge. The review report
   is archived into the iteration's data/.
f. **Record**: the absorb merge commit's message is a meaningful one-liner — absorb point + gap
   summary (e.g. `merge: absorb mainline <sha> — <what changed there in one phrase>`). NEVER the
   default `Merge branch/commit ...` template, NEVER bookkeeping ids in any spelling (`plan:NNNN`
   or `plan-NNNN`), and strip `# Conflicts:` comment lines (default `git commit` cleanup does;
   never commit with `--cleanup=verbatim`). The gap profile itself goes to the readme's log
   section — process narration belongs in the ledger, not in commit text.
g. **Retest tier after absorb**: file AND semantic intersections both empty → T1 quick pass is
   enough; either non-empty → rerun the ORIGINAL §8.0 tier. When in doubt, round up.
h. **The blocking point (the only one in this skill)**: ANY of — a conflict hunk, a semantic
   intersection finding (even at zero text conflicts, e.g. a retired-surface hit in d), a
   structural absorb, a retest failure — FREEZES the merge: stop, present the gap profile and a
   handling plan to the user, update the lane per the agreed plan, retest, then re-enter §8.1.
   Only a zero-intersection absorb with green tests proceeds under the original "merge when green"
   confirmation without re-asking.

## 8. Merge-back: CAS squash (the only legal sequence)

### 8.0 Verification tiering (written before anything runs)

**Not every project has an e2e gate, and not every merge needs the full suite.** The tiering basis
= the branch's **net change surface** (`git diff <mainline>..<branch>` — this plan's net effect;
the mainline's own changes were verified when they landed) × the project's verification assets
(§1 discovery; possibly empty).

| Tier | Applies when | Content |
| --- | --- | --- |
| T0 exempt | pure docs/comments/test-self/non-runtime paths | run no gate; a **written argument** that the change cannot affect any behavior the verification assets certify, filed in the iteration readme |
| T1 full unit | the default floor for ALL code changes | the project's whole unit-test suite |
| T2 targeted subset | narrow surface with a matching integration/GPU subset | T1 + targeted subset (subset choice justified in writing) |
| T3 full gate | the change touches behavior the gate certifies (runtime/numerics/communication/performance) | T1 + the project's full verification gate (gate script + judge) |

Discipline: **the tier (with reasons) is written into the readme BEFORE execution** — tier first,
run second; never pick a tier after the fact or skip silently; when unsure → round up, or ask the
user. The tier also drives resource needs (§9).

### 8.1 The CAS loop (compare-and-swap; the mainline lock covers seconds, not hours)

**Why the lock still exists**: the final check-and-merge must be atomic — if the mainline moves
between "user confirmed" and "merge", the tested state is no longer the merged state. What the
lock does NOT cover anymore: verification — that already happened in the worktree.

```
loop:
  1. If the mainline moved since the recorded absorb point: absorb (§7) + retest per §7g.
  2. Present results → user confirms merge (confirmation semantics: "merge when green").
  3. Under .locks/mainline/ (one acquisition; multi-repo plans: ALL repos inside the SAME window):
     per repo: mainline HEAD still == the recorded absorbed point?
       yes → [MUST] history-rewrite probe:
               git merge-base --is-ancestor <base> <mainline>   # base = the lane-recorded base SHA
               no  → mainline history rewritten → dispose per §7a's rewrite rule (metadata-only:
                     re-anchor + continue; content moved: normal absorb path) — never a freeze by
                     itself → unlock → back to 1
             → git merge --squash plan-<id>          # stages the plan's net diff
             → commit-check.sh <repo> "<PR-name title>"   # gate BEFORE commit; the content scan
             → git commit -m "<PR-name title>"            #   doubles as a final net over the plan's whole diff
             → git diff plan-<id> <mainline>  →  MUST BE EMPTY
               (the merged tree == the tested branch tree; anything else = hooks/filters/wrong
                branch — abort and report)
       no  → unlock → back to 1
     unlock; done
  4. Bookkeeping (lock-free): close the iteration with the tier+reasons, the post-merge mainline
     squash SHA per repo (PERMANENT anchor), and the branch name.
     [MUST] After the merge-back is accepted (report layer): run the code-clean batch comment
     review — multi-subagent walk over ALL comments in every file this round's lane touched,
     report-only; fixes go in a separate follow-up commit, never folded into the squash.
  5. Verification failure at any point: fix-forward on the branch → back to 1. Never hotfix the
     main checkout (attribution stays clean).
```

Fine print:

- **Squash commit title = the PR name**: one line, describes the change itself, type prefix per
  the repo's convention (`feat:` / `fix:` / ...). No bookkeeping ids in any spelling, no process
  narration, no "Merge branch" form — attribution lives in the ledger (readme anchors), never in
  repo history.
- **Empty net diff** (the branch's final tree == the mainline tree, e.g. everything was reverted
  during iteration): do NOT create an empty commit — close as a no-op merge and record it in the
  readme.
- **Multi-round plans** (accepted once, then iterated further and merged again): right after each
  accepted squash, absorb the mainline back into the branch — the merge-base resets, so the next
  round's net diff contains only new changes.
- **Lock discipline**: mkdir-atomic + owner file + `trap`-released (a session has no resident
  shell — the lock's lifetime is the command's lifetime; every exit path releases). Stale lock →
  pid liveness → report to the user before removing (§1 recovery semantics). A merge-vs-merge
  collision backstop already exists: git's `index.lock` (the loser re-absorbs per §7).
- The main checkout must be clean entering step 3 (coordinate a commit or stash with the mainline
  session first if it's around).

## 9. Shared-resource arbitration (nodes / IO / big data)

- Three resource classes: **occupy-class** (GPU nodes), **throughput-class** (shared FS / NFS
  bandwidth), **read-only-class** (public datasets — no arbitration).
- If the project has resource tools (registered in utils.md — node monitors, occupiers), use them;
  otherwise `.locks/resource-<name>/` mkdir locks, owner stating purpose and expected duration.
- Occupy-class: occupy before use, and take resources BEFORE the mainline lock (§8.1 ordering) —
  never hold the lock while waiting.
- Throughput-class: **measurement validity beats mutual exclusion** — bandwidth-sensitive
  calibrations/benchmarks must not run concurrently with other heavy IO jobs, or the measurement
  is polluted (not "will they collide" but "does the data count").
- e2e gates that are NOT multi-instance-safe (§1 discovery row) join the occupy class.

## 10. Lifecycle endings (dissatisfaction tiers — never rebuild a worktree)

- **Not satisfied before merge** → keep iterating on the SAME branch; each review round is logged
  in the readme (results → user verdict → continue/merge).
- **Satisfied** → §8.1 CAS squash; record the squash SHA per repo (permanent anchor).
- **Dissatisfied after merge, before cleanup** → fix-forward on the same (retained) branch, repeat
  confirm + CAS.
- **Regret after cleanup** → a new iteration (plan still open) or a new plan (plan closed);
  whether to revert the squash commit is the user's call. There is NO reopen machinery — the
  one-way plan/iteration state machine is the ledger's deterministic backbone.
- **Cleanup** (only after an accepted merge, with user confirmation, and lazy — keep the branch
  through the post-merge dissatisfaction window):
  ```bash
  git -C <repo> worktree remove worktrees/<plan-id>/<repo-name>
  AGENTSPACE/scripts/repos.sh --remove worktrees/<plan-id>/<repo-name>   # de-registration is user-confirmed
  git -C <repo> branch -D plan-<plan-id>   # squash means -d always refuses; the basis for -D is the §8.1 diff-empty proof + the readme record
  ```
  No push anywhere unless the user explicitly asks. Before destroying: the squash landed (readme
  has the SHA), iteration data archived, no one references the worktree path (grep the ledger).
- After cleanup the branch-tip SHAs dangle by design; the content archive is the data/ diffs, and
  the permanent anchors (base SHA, squash SHA) bracket the plan on the mainline.

## 11. Failure & recovery quickref

| Symptom | Handling |
| --- | --- |
| ledger/mainline/resource lock unavailable | read `owner`, tell the user who holds it; keep working outside the lock (alignment / reviews / docs); never spin |
| stale lock (session killed) | pid liveness check; pid-less → 5-min mtime grace; takeover by `mv`, report to user; never silent force-remove |
| "lock held" but owner file empty | first check whether `.locks/` exists at all — a missing parent yields ENOENT misread as contention (§1) |
| CAS recheck fails (mainline moved) | unlock → absorb → retest per §7g → re-enter; this is the normal loop, not an error |
| diff-empty proof fails after squash | abort, report — something external touched the merge (hooks/filters/wrong branch) |
| retest FAIL after absorb | fix-forward on the branch; never hotfix the main checkout |
| tiering uncertainty | round up, or ask the user (argument cost < gate rerun cost) |
| lost/duplicated index rows (race symptom) | doctor.sh locates; repair plan confirmed with the user; never hand-edit indexes |
| worktree dir deleted by hand | `git -C <repo> worktree prune` cleans the metadata; then re-add if still needed |
| scripts self-lock missing (older plugin) | the ledger lock also covers script calls (§6.1) |

## 12. Boundaries

- This skill replaces NO existing gate (commit gate / the project's own verification gates /
  lab-manual disciplines) — it orders workspaces and the ledger under parallelism; §8.0 tiering is
  a **scheduling layer** over the project's own gate discipline, whose semantics stay authoritative.
- Single-session projects don't need this skill; a mainline session only observes §4's
  merge-window discipline and §6's commit hygiene.
- One-off A/B anchor worktrees (pinned SHA, zero commits, delete-after-use) live at
  `worktrees/_anchor-<name>/` (underscore = not a plan) and follow NEITHER the registration nor
  the merge protocol of this skill.
- Local-only: pushing, remote PRs, and publishing are outside this skill and remain user-gated.

---

### Appendix A: relationship with the agentspace plugin

This skill is a **session-side convention**: the ledger/mainline/resource locks are implemented by
the skill at the project root `.locks/` and do not modify the plugin. If the plugin ever sinks the
ledger lock into scripts (as_lock extended to content-doc commits), §6 shrinks to "call the
plugin's capability".

### Appendix B: why §8.1 is the only legal form (war story)

A preview of this flow once let a lane merge back by fast-forward: the absorb merge commit
("merge main into plan-0025") landed AS the mainline HEAD, another lane's absorb ("Merge commit
'0107e1d' into plan-0030", default template, `# Conflicts:` lines baked in) rode along into
mainline history, and the mainline's first-parent chain started reading through lane internals
(dev commits and merge commits), demoting real mainline commits to second parents. Content was
correct; history was unusable. The CAS squash sequence exists so the mainline always tells one
story: one accepted merge, one PR-named commit.
