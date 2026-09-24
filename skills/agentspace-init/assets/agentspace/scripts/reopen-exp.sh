#!/usr/bin/env bash
# Reopen a completed experiment: move manual done→doing, move row 最近完成→Doing
# in exp.md (开始日期 = today; a closed exp past the 10-row view simply gains a
# Doing row), reset exp/index.md state to doing and clear the completion snapshot
# (完成日期/结果 — the previous conclusion is preserved as a 日志 line in the
# manual BEFORE the index is rewritten), rewrite the status line.
# Usage: reopen-exp.sh <id> ["原因"]
#   One exp = one goal holding a group of runs: a follow-up round under a CLOSED
#   goal reopens it here instead of registering a new exp — the enrollment gate
#   (user-confirmed) covers new GOALS, not continuation of an enrolled one.
#   Open (todo/doing) exps take follow-up rounds directly — reopen refuses them.
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

[ $# -ge 1 ] && [ $# -le 2 ] || as_die "Usage: reopen-exp.sh <id> [\"原因\"]"
ID="$(as_norm_id "$1")"
REASON="${2:-}"

# Light-workspace guard (lib.sh): refuse before any read or mutation.
as_require_module exp.md exp

# Locate the manual. Open states refuse with the append hint (the round belongs
# INSIDE the open exp); only done/ reopens.
for cand in todo doing; do
  [ -n "$(ls "$AS_ROOT/exp/$cand"/exp_"$ID"-*.md 2>/dev/null | head -1 || true)" ] \
    && as_die "exp_$ID is still open ($cand) — append the follow-up round into it (manual 轮次 section + examples/exp_spec/ + exp_data/); no reopen needed"
done
SRC="$(ls "$AS_ROOT/exp/done"/exp_"$ID"-*.md 2>/dev/null | head -1 || true)"
[ -n "$SRC" ] || as_die "exp_$ID not in exp/done/ (does not exist or not closed — run doctor.sh on status anomalies)"

# Gate: status line must be a closed form written by complete-exp.sh
grep -Eq '^> 状态: (完成|失败|放弃) \(' "$SRC" \
  || as_die "exp_$ID status line is not a closed form (完成|失败|放弃) — status anomaly, run doctor.sh"

# Previous closure snapshot, read BEFORE any mutation (the index cells are
# cleared below; the manual 日志 line is their surviving record).
PRE_ST="$(as_row_cell "$AS_ROOT/exp/index.md" "$ID" 4)"
PRE_DATE="$(as_row_cell "$AS_ROOT/exp/index.md" "$ID" 10)"
PRE_RESULT="$(as_row_cell "$AS_ROOT/exp/index.md" "$ID" 11)"

# Title: entry view first (row present while the closure is within the last 10),
# full index as fallback (closed past the truncated view).
TITLE="$(as_row_cell "$AS_ROOT/exp.md" "$ID" 3)"
[ -n "$TITLE" ] || TITLE="$(as_row_cell "$AS_ROOT/exp/index.md" "$ID" 3)"
[ -n "$TITLE" ] || as_die "exp_$ID not found in exp.md / exp/index.md"

DATE="$(as_today)"
DEST="exp/doing/$(basename "$SRC")"

as_lock

# Manual first (still at the done/ path): append-only 日志 line preserving the
# previous closure — the index cells it came from are about to be cleared.
ENTRY="- $DATE 重开: 后续轮次归并${REASON:+ — $REASON}(此前${PRE_DATE:+ $PRE_DATE}以 ${PRE_ST:-已}关闭${PRE_RESULT:+, 结论: $PRE_RESULT})"
as_append_to_section "$SRC" "日志" "$ENTRY"

# exp.md: remove the 最近完成 row (section-bounded; silently nothing to remove
# when the closure already fell out of the truncated view), insert the Doing row
as_remove_row_section "$AS_ROOT/exp.md" "$SEC_RECENT" "$ID"
as_insert_row "$AS_ROOT/exp.md" "$SEC_EXP_DOING" \
  "| $ID | $(as_cell "$TITLE") | $DATE | [$DEST]($DEST) |"

# exp/index.md: state→doing, clear 完成日期/结果 (kept: commits/configs — the
# points tested so far; the next complete-exp re-snapshots them), link→doing.
# Escape-aware \| shield + ENVIRON — same shape as start/complete-exp passes.
tmp="$(mktemp "$AS_TMPDIR/tmp.XXXXXX")"
ESC="$(printf '\037')"
sed "s/\\\\|/$ESC/g" "$AS_ROOT/exp/index.md" \
  | awk -F'|' -v id="$ID" -v st="doing" -v link="[$DEST]($DEST)" -v esc="$ESC" '
    BEGIN { pat="^\\| *" id " *\\|"; found=0 }
    $0 ~ pat {
      $4=" " st " "; $10="  "; $11="  "; $12=" " link " "
      out=$1; for (i=2; i<=NF; i++) out=out "|" $i
      print out; found=1; next
    }
    { print }
    END { if (!found) exit 3 }
  ' | sed "s/$ESC/\\\\|/g" > "$tmp" || { rm -f "$tmp"; as_die "index missing exp_$ID"; }
as_atomic_write "$AS_ROOT/exp/index.md" "$tmp"

# Move file + rewrite the status line (only after the table operations succeed)
mv "$SRC" "$AS_ROOT/$DEST"
tmp="$(mktemp "$AS_TMPDIR/tmp.XXXXXX")"
awk -v new="$STATUS_EXP_DOING" '
  !done && /^> 状态: (完成|失败|放弃) \(/ { print new; done=1; next }
  { print }
  END { if (!done) exit 3 }
' "$AS_ROOT/$DEST" > "$tmp" || { rm -f "$tmp"; as_die "closed status line not found in $DEST"; }
as_atomic_write "$AS_ROOT/$DEST" "$tmp"

echo "exp_$ID → doing ($DEST) — 后续轮次归并: 手册\"轮次\"节追加 + 配置入 examples/exp_spec/ + 数据入 exp_data/"
echo "Next: close again only when the GOAL is concluded (complete-exp.sh $ID <done|failed|abandoned> \"result\")"
as_commit_hint "exp: reopen $ID" exp.md exp/index.md exp/done "$DEST"
