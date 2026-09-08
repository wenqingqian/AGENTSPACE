#!/usr/bin/env bash
# Close an experiment: move manual doing|todo→done, move row into 最近完成
# (truncate to 10), snapshot the config names from examples/exp_spec/exp_NNNN/
# and the tested commit points into exp/index.md, rewrite the status line.
# Usage: complete-exp.sh <id> <done|failed|abandoned> "result" [--commit "repo@sha[,repo@sha...]"]
#   A manual still in exp/todo/ is accepted (small experiments may skip the
#   start ceremony). --commit records the tested key-repo commit POINTS
# (repo@sha, complementary to an iteration's commit window).
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

ID="$(as_norm_id "${1:-}")"
STATUS_ARG="${2:-}"
RESULT="${3:-}"
shift 3 || true

case "$STATUS_ARG" in
  done)       STATUS_CN="完成" ;;
  failed)     STATUS_CN="失败" ;;
  abandoned)  STATUS_CN="放弃" ;;
  *) as_die "Status must be done|failed|abandoned" ;;
esac
[ -n "$RESULT" ] || as_die "Usage: complete-exp.sh <id> <done|failed|abandoned> \"result\" [--commit \"repo@sha[,repo@sha...]\"]"

COMMIT_ARG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --commit) [ $# -ge 2 ] || as_die "--commit needs a value"; COMMIT_ARG="$2"; shift 2 ;;
    *) as_die "unknown argument: $1 (Usage: complete-exp.sh <id> <done|failed|abandoned> \"result\" [--commit \"repo@sha[,repo@sha...]\"])" ;;
  esac
done

# Locate the manual: doing/ first, then todo/ (start ceremony is optional).
SRC=""
STATUS_OLD=""
for cand in doing todo; do
  f="$(ls "$AS_ROOT/exp/$cand"/exp_"$ID"-*.md 2>/dev/null | head -1 || true)"
  if [ -n "$f" ]; then SRC="$f"; STATUS_OLD="$cand"; break; fi
done
[ -n "$SRC" ] || as_die "exp_$ID not in exp/todo|doing/ (does not exist or already completed)"

# Gate: status line must match the directory the manual sits in
if [ "$STATUS_OLD" = "doing" ]; then
  grep -qx "$STATUS_EXP_DOING" "$SRC" || as_die "exp_$ID status line is not $STATUS_EXP_DOING (status anomaly — run doctor.sh)"
else
  grep -qx "$STATUS_TODO" "$SRC" || as_die "exp_$ID status line is not $STATUS_TODO (status anomaly — run doctor.sh)"
fi
# Gate: results section must be filled (template placeholder gone)
if grep -Fq "$RESULT_PH_EXP" "$SRC"; then
  as_die "Results section not filled (template placeholder still present): $SRC"
fi

# Gate: the config contract — every registered experiment carries its configs in
# examples/exp_spec/exp_NNNN/; refusing to close on an empty dir is the MUST's
# teeth (a one-line README in that dir satisfies it). Pre-guard the dir itself:
# find on a missing dir dies non-zero under pipefail and would kill the script
# BEFORE this crafted message — the missing-dir state is exactly doctor [16]'s
# "missing examples/exp_spec" warning.
SPEC_DIR="$AS_ROOT/examples/exp_spec/exp_$ID"
if [ ! -d "$SPEC_DIR" ]; then
  as_die "examples/exp_spec/exp_$ID/ does not exist — every registered exp must put its experiment configs there (re-run scenarios: restore the dir, or ask the user before recreating it)"
fi
CONFIGS="$(find "$SPEC_DIR" -maxdepth 1 -type f ! -name '.gitkeep' 2>/dev/null | while IFS= read -r c; do basename "$c"; done | paste -sd, -)"
[ -n "$CONFIGS" ] || as_die "no configs in examples/exp_spec/exp_$ID/ — every registered exp must put its experiment configs there (add the config files, or at minimum a README describing the run settings)"

# Soft notice: exp_data is the canonical full record — an empty one is usually a
# forgotten copy (analysis-only exps legitimately produce little; never a block).
if [ -z "$(find "$AS_ROOT/exp/exp_data/exp_$ID" -type f 2>/dev/null | head -1)" ]; then
  echo "notice: exp/exp_data/exp_$ID/ holds no files — the complete record belongs there (copy logs/results before they age out)"
fi

# --commit: repo@sha points, comma-joined. sha format enforced; unregistered
# repo names pass with a notice (third-party test targets are legitimate).
# Registry rows are paths, so the name check matches on basename.
COMMITS_CELL="-"
if [ -n "$COMMIT_ARG" ]; then
  COMMITS_CELL=""
  IFS=',' read -r -a _cms <<< "$COMMIT_ARG"
  for c in "${_cms[@]}"; do
    [ -n "$c" ] || continue
    [[ "$c" =~ ^[A-Za-z0-9._/-]+@[0-9a-f]{4,40}$ ]] \
      || as_die "bad --commit item: \"$c\" (expected repo@sha, e.g. myrepo@a1b2c3d)"
    _rn="${c%%@*}"
    _reg=0
    while IFS= read -r _row; do
      [ -n "$_row" ] || continue
      [ "$(basename "$_row")" = "$_rn" ] && { _reg=1; break; }
    done < <(as_repos)
    [ "$_reg" -eq 1 ] || echo "notice: \"$_rn\" is not a registered key repo (fine for third-party test targets)"
    COMMITS_CELL="${COMMITS_CELL:+$COMMITS_CELL, }$c"
  done
  [ -n "$COMMITS_CELL" ] || COMMITS_CELL="-"
fi

TITLE="$(as_row_cell "$AS_ROOT/exp.md" "$ID" 3)"
[ -n "$TITLE" ] || as_die "exp_$ID not found in exp.md Todo/Doing table"
DATE="$(as_today)"
RESULT_CELL="$(as_cell "$RESULT")"
CONFIG_CELL="$(as_cell "$CONFIGS")"
DEST="exp/done/$(basename "$SRC")"

as_lock

# exp.md: remove the open row (file-wide — the id is unique while open), insert
# into 最近完成, truncate to 10
as_remove_row "$AS_ROOT/exp.md" "$ID"
as_insert_row "$AS_ROOT/exp.md" "$SEC_RECENT" \
  "| $ID | $TITLE | $STATUS_CN | $RESULT_CELL | $DATE | [$DEST]($DEST) |"
as_truncate_section "$AS_ROOT/exp.md" "$SEC_RECENT" 10

# exp/index.md: status/commits/configs/completed-date/result/link snapshot.
# Escape-aware: \| cells are shielded before the -F'|' split and restored
# after; cells travel via ENVIRON, not -v (awk -v unescapes the \| produced
# by as_cell — same hazard as lib.sh::as_insert_row).
tmp="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
ESC="$(printf '\037')"
sed "s/\\\\|/$ESC/g" "$AS_ROOT/exp/index.md" \
  | RESULT_CELL="$RESULT_CELL" CONFIG_CELL="$CONFIG_CELL" COMMITS_CELL="$COMMITS_CELL" \
    awk -F'|' -v id="$ID" -v st="$STATUS_CN" -v d="$DATE" -v link="[$DEST]($DEST)" -v esc="$ESC" '
    BEGIN { pat="^\\| *" id " *\\|"; found=0; r=ENVIRON["RESULT_CELL"]; cfg=ENVIRON["CONFIG_CELL"]; cm=ENVIRON["COMMITS_CELL"] }
    $0 ~ pat {
      $4=" " st " "; $7=" " cm " "; $8=" " cfg " "; $10=" " d " "; $11=" " r " "; $12=" " link " "
      out=$1; for (i=2; i<=NF; i++) out=out "|" $i
      print out; found=1; next
    }
    { print }
    END { if (!found) exit 3 }
  ' | sed "s/$ESC/\\\\|/g" > "$tmp" || { rm -f "$tmp"; as_die "index missing exp_$ID"; }
as_atomic_write "$AS_ROOT/exp/index.md" "$tmp"

# Move file + update status line (only after the table operations succeed)
mv "$SRC" "$AS_ROOT/$DEST"
if [ "$STATUS_OLD" = "doing" ]; then
  as_replace_line "$AS_ROOT/$DEST" "$STATUS_EXP_DOING" "> 状态: $STATUS_CN ($DATE)"
else
  as_replace_line "$AS_ROOT/$DEST" "$STATUS_TODO" "> 状态: $STATUS_CN ($DATE)"
fi

echo "exp_$ID → $STATUS_CN ($DEST)"
echo "Next [SHOULD]: reports/figures follow the agentspace-better-exp-report skill; transferable conclusions go to notes with source exp_$ID"
