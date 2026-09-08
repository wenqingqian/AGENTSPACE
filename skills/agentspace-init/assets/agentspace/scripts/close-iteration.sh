#!/usr/bin/env bash
# Close an iteration: move row from 进行中 to 最近完成 (truncate to 10),
# update iterations/index.md status/result, freeze readme and append close log.
# Usage: close-iteration.sh <id> "result"
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

ID="$(as_norm_id "${1:-}")"
RESULT="${2:-}"
[ -n "$RESULT" ] || as_die "Usage: close-iteration.sh <id> \"result\""

DIR="iterations/iteration_$ID"
README="$AS_ROOT/$DIR/readme.md"
[ -f "$README" ] || as_die "iteration_$ID does not exist"
# Gate: exact match on status line
grep -qx "$STATUS_PROGRESS" "$README" || as_die "iteration_$ID is not in progress (already closed or status anomaly)"
# Gate: results section must be filled (template placeholder gone)
if grep -Fq "$RESULT_PH_ITER" "$README"; then
  as_die "Results section not filled (template placeholder still present): $README"
fi

PLANREF="$(as_row_cell "$AS_ROOT/iterations.md" "$ID" 3)"
TITLE="$(as_row_cell "$AS_ROOT/iterations.md" "$ID" 4)"
[ -n "$TITLE" ] || as_die "iteration_$ID not found in iterations.md 进行中 table"
DATE="$(as_today)"
RESULT_CELL="$(as_cell "$RESULT")"

as_lock

# F3+F4 (audit): record host end commit BEFORE mutations (best-effort metadata;
# guards make failure impossible under lock). Inserted BELOW the start line when present.
HOST_HEAD="$(as_host_head)"
if [ -n "$HOST_HEAD" ] && grep -q '^## 环境$' "$README" \
   && ! grep -q '^> 宿主结束 commit: ' "$README"; then
  if grep -q '^> 宿主起始 commit: ' "$README"; then
    as_insert_after_prefix "$README" "> 宿主起始 commit: " "> 宿主结束 commit: $HOST_HEAD"
  else
    as_insert_after "$README" "## 环境" "> 宿主结束 commit: $HOST_HEAD"
  fi
fi

# Auto-collect the host code diff (best-effort metadata): the start/end commits
# recorded at creation/close delimit this iteration's window; save `git diff
# start..end` to data/ when non-empty. No git host / missing commits / empty
# diff → silently skip (guards keep failure impossible under lock).
# {4,40}: as_host_head writes `git rev-parse --short HEAD`, whose abbrev honors
# core.abbrev (floor 4) — a {7,40} reader would silently skip short SHAs.
START="$(grep -E '^> 宿主起始 commit: [0-9a-f]+' "$README" | head -1 | grep -oE '[0-9a-f]{4,40}' || true)"
END="$(grep -E '^> 宿主结束 commit: [0-9a-f]+' "$README" | head -1 | grep -oE '[0-9a-f]{4,40}' || true)"
if [ -n "$START" ] && [ -n "$END" ] && [ "$START" != "$END" ] \
   && git -C "$AS_ROOT/.." rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  [ -d "$AS_ROOT/$DIR/data" ] || mkdir -p "$AS_ROOT/$DIR/data"
  PATCH="$AS_ROOT/$DIR/data/diff-$START..$END.patch"
  if git -C "$AS_ROOT/.." diff "$START".."$END" > "$PATCH" 2>/dev/null && [ -s "$PATCH" ]; then
    echo "code diff saved → $DIR/data/diff-$START..$END.patch"
  else
    rm -f "$PATCH"
  fi
fi

# iterations.md: remove 进行中 row, insert into 最近完成, truncate to 10
as_remove_row "$AS_ROOT/iterations.md" "$ID"
as_insert_row "$AS_ROOT/iterations.md" "$SEC_RECENT" \
  "| $ID | $PLANREF | $TITLE | $RESULT_CELL | $DATE | [$DIR/readme.md]($DIR/readme.md) |"
as_truncate_section "$AS_ROOT/iterations.md" "$SEC_RECENT" 10

# iterations/index.md: update status/completed-date/result.
# Escape-aware: \| cells (title/result) are shielded before the -F'|' split and
# restored after, so an escaped pipe cannot shift the fixed column positions.
tmp="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
ESC="$(printf '\037')"
# RESULT_CELL travels via ENVIRON, not -v — awk -v would unescape the `\|`
# cells produced by as_cell, silently corrupting escaped pipes (same hazard
# documented at lib.sh::as_insert_row).
sed "s/\\\\|/$ESC/g" "$AS_ROOT/iterations/index.md" \
  | RESULT_CELL="$RESULT_CELL" awk -F'|' -v id="$ID" -v d="$DATE" -v esc="$ESC" '
    BEGIN { pat="^\\| *" id " *\\|"; found=0; r=ENVIRON["RESULT_CELL"] }
    $0 ~ pat {
      $5=" 已完成 "; $7=" " d " "; $8=" " r " "
      out=$1; for (i=2; i<=NF; i++) out=out "|" $i
      print out; found=1; next
    }
    { print }
    END { if (!found) exit 3 }
  ' | sed "s/$ESC/\\\\|/g" > "$tmp" || { rm -f "$tmp"; as_die "iterations/index.md missing iteration_$ID"; }
as_atomic_write "$AS_ROOT/iterations/index.md" "$tmp"

# Atomic: replace status line + append close log in single awk pass
tmp2="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
awk -v status_old="$STATUS_PROGRESS" -v status_new="> 状态: 已完成 ($DATE)" -v log_line="- $DATE 关闭: $RESULT_CELL" '
  $0 == status_old && !done { print status_new; done=1; next }
  { print }
  END {
    if (!done) exit 3
    print log_line
  }
' "$README" > "$tmp2" || { rm -f "$tmp2"; as_die "readme status line $STATUS_PROGRESS not found"; }
as_atomic_write "$README" "$tmp2"

echo "iteration_$ID closed → $DIR/readme.md (frozen)"
# Soft reminder: linked open experiments keep their full record in exp_data
# (reverse lookup on exp/index.md 关联 iteration column; report-only). The read
# is escape-aware (\| in titles shielded before the -F'|' split) — same
# discipline as status.sh's exp event stream.
_RE="$(printf '\037')"
OPEN_EXPS="$(sed "s/\\\\|/$_RE/g" "$AS_ROOT/exp/index.md" 2>/dev/null | awk -F'|' -v iid="iteration_$ID" '
  /^\| [0-9]/ {
    iter=$6; gsub(/^ +| +$/, "", iter); state=$4; gsub(/^ +| +$/, "", state)
    if (index(iter, iid) && (state == "todo" || state == "doing")) n++
  }
  END { print n+0 }
' || true)"
if [ "${OPEN_EXPS:-0}" -gt 0 ]; then
  echo "note: $OPEN_EXPS linked open experiment(s) reference iteration_$ID — copy this iteration's data/ artifacts into exp/exp_data/exp_*/ before closing the exp"
fi
echo "Next [SHOULD]: if the result holds transferable lessons, write a note (templates/note.md) with source iteration_$ID, back-linking this readme in 详情"
