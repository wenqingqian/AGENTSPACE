#!/usr/bin/env bash
# Register a new experiment: allocate global index, instantiate exp/todo/exp_NNNN-slug.md,
# pre-create exp/exp_data/exp_NNNN/ and examples/exp_spec/exp_NNNN/ (the config contract),
# insert row in exp.md Todo table, append to exp/index.md, and append id references to
# each linked iteration's "相关实验" section.
# Usage: new-exp.sh "Experiment title" [--plan NNNN[,NNNN...]] [--iteration NNNN[,NNNN...]]
#   Enrollment is user-confirmed BEFORE this script runs (AGENTS.md exp module rule):
#   correctness-verification runs are never auto-enrolled. The title slug contract
#   is the same as new-plan.sh (lowercase english words, digits, single hyphens).
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

TITLE="${1:-}"
[ -n "$TITLE" ] || as_die "Usage: new-exp.sh \"Experiment title\" [--plan NNNN[,NNNN...]] [--iteration NNNN[,NNNN...]]"
shift || true

PLAN_ARG=""
ITER_ARG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --plan)      [ $# -ge 2 ] || as_die "--plan needs a value"; PLAN_ARG="$2"; shift 2 ;;
    --iteration) [ $# -ge 2 ] || as_die "--iteration needs a value"; ITER_ARG="$2"; shift 2 ;;
    *) as_die "unknown argument: $1 (Usage: new-exp.sh \"Experiment title\" [--plan NNNN[,NNNN...]] [--iteration NNNN[,NNNN...]])" ;;
  esac
done

# Slug derivation + contract — as_slug_of (same single source as new-plan.sh;
# title becomes filename).
SLUG="$(as_slug_of "$TITLE" exp)"

# Lock BEFORE id allocation (t21 contract — same critical-section shape as new-plan/new-iteration).
as_lock

# --plan: comma-separated ids, each normalized; the plan must exist in the FULL index
# (completed plans included — an exp may outlive its plan's active phase, unlike an
# iteration). Cell form "plan:NNNN, plan:NNNN", or "-" when unlinked.
PLAN_CELL="-"
if [ -n "$PLAN_ARG" ]; then
  PLAN_CELL=""
  IFS=',' read -r -a _pids <<< "$PLAN_ARG"
  for p in "${_pids[@]}"; do
    [ -n "$p" ] || continue
    pid="$(as_norm_id "$p")"
    grep -q "^| *$pid *|" "$AS_ROOT/plan/index.md" 2>/dev/null \
      || as_die "plan:$pid not found in plan/index.md (linked plans must exist; completed plans are allowed)"
    PLAN_CELL="${PLAN_CELL:+$PLAN_CELL, }plan:$pid"
  done
  [ -n "$PLAN_CELL" ] || PLAN_CELL="-"
fi

# --iteration: comma-separated ids, each normalized; the iteration dir must exist
# (open or closed — a closed iteration's data may still be the exp's subject).
ITER_CELL="-"
ITER_IDS=""
if [ -n "$ITER_ARG" ]; then
  ITER_CELL=""
  IFS=',' read -r -a _iids <<< "$ITER_ARG"
  for it in "${_iids[@]}"; do
    [ -n "$it" ] || continue
    iid="$(as_norm_id "$it")"
    [ -d "$AS_ROOT/iterations/iteration_$iid" ] \
      || as_die "iteration_$iid does not exist (linked iterations must exist; closed ones are allowed)"
    ITER_CELL="${ITER_CELL:+$ITER_CELL, }iteration_$iid"
    ITER_IDS="$ITER_IDS$iid"$'\n'
  done
  [ -n "$ITER_CELL" ] || ITER_CELL="-"
fi

ID="$(as_next_exp_id)"
DATE="$(as_today)"
CELL="$(as_cell "$TITLE")"
FILE="exp/todo/exp_${ID}-${SLUG}.md"

PH_ID="$ID" PH_TITLE="$TITLE" PH_DATE="$DATE" \
  as_fill_template "$AS_ROOT/templates/exp-manual.md" "$AS_ROOT/$FILE"

# exp_data is the local-only full-record tree (gitignored via exp/exp_data/) —
# created on demand, no .gitkeep (an ignored tree has nothing to track).
mkdir -p "$AS_ROOT/exp/exp_data/exp_$ID"
# examples/exp_spec/exp_NNNN/ is TRACKED and is the config contract: every
# registered exp carries its configs here (complete-exp refuses to close while
# the dir holds nothing besides .gitkeep). .gitkeep keeps the empty dir in git.
mkdir -p "$AS_ROOT/examples/exp_spec/exp_$ID"
touch "$AS_ROOT/examples/exp_spec/exp_$ID/.gitkeep"

as_insert_row "$AS_ROOT/exp.md" "$SEC_TODO" \
  "| $ID | $CELL | $DATE | [$FILE]($FILE) |"

# Index append via tmp+mv: atomic (audit R8) — a half-written index row is
# unrepairable by doctor [16]. 11 columns; commits/配置 stay "-" until close.
tmp="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
{ cat "$AS_ROOT/exp/index.md" 2>/dev/null || true; \
  echo "| $ID | $CELL | todo | $PLAN_CELL | $ITER_CELL | - | - | $DATE |  |  | [$FILE]($FILE) |"; } > "$tmp" \
  && as_atomic_write "$AS_ROOT/exp/index.md" "$tmp"

# Backlink into each linked iteration's readme (id reference only — the manual
# later moves todo→doing→done, so a path link would go stale; AGENTS.md
# cross-reference rule says id, never path). Legacy readmes without the
# 相关实验 section get the header inserted after 代码变更 (diff) on demand.
ENTRY="- exp_$ID — $CELL ($DATE)"
while IFS= read -r iid; do
  [ -n "$iid" ] || continue
  README="$AS_ROOT/iterations/iteration_$iid/readme.md"
  [ -f "$README" ] || continue
  if ! grep -qx "## 相关实验" "$README"; then
    as_insert_after "$README" "## 代码变更 (diff)" "## 相关实验"
    as_append_to_section "$README" "相关实验" "<!-- 由 new-exp.sh 自动追加(关联本 iteration 的 exp), 请勿手工编辑 -->"
  fi
  as_append_to_section "$README" "相关实验" "$ENTRY"
done <<< "$ITER_IDS"

echo "exp_$ID created → $FILE (plan: $PLAN_CELL / iteration: $ITER_CELL)"
echo "Next: run the agentspace-better-exp alignment if not done yet, fill the manual, put configs into examples/exp_spec/exp_$ID/; launch with start-exp.sh $ID"
