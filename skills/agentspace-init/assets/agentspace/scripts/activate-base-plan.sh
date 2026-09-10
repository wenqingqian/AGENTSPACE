#!/usr/bin/env bash
# Activate a base plan: 待审核 → 生效, pin the file's sha256 (12 hex) into the
# plan/index.md Base row. From this point the file is immutable — no script
# ever writes it again and doctor [17] reports any checksum drift.
# Usage: activate-base-plan.sh <id>
#   Runs ONLY after the user explicitly approved the reviewed file (the
#   review flow itself lives in the agentspace-base-plan skill / AGENTS.md:
#   draft written → session ended → user comments on the file → approval).
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

ID="$(as_norm_id "${1:-}")"
KEY="base:$ID"
DATE="$(as_today)"

SRC=( "$AS_ROOT"/plan/base/"$ID"-*.md )
[ -e "${SRC[0]}" ] || as_die "$KEY not found in plan/base/"

STATE="$(as_row_cell "$AS_ROOT/plan/index.md" "$KEY" 4)"
[ "$STATE" = "待审核" ] || as_die "$KEY state is \"$STATE\" — only a 待审核 base plan can be activated"

# Gate: the direction section must be filled (template placeholder gone) —
# an activated anchor is frozen, so it cannot ship as an empty skeleton.
grep -Fq "$BASE_PH_DIR" "${SRC[0]}" \
  && as_die "$KEY direction section still holds the template placeholder — fill 方向 before activation"
command -v python3 >/dev/null 2>&1 || as_die "activate-base-plan.sh needs python3 (sha256 checksum)"

as_lock

HASH="$(PYTHONIOENCODING=utf-8 python3 -c "import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest()[:12])" "${SRC[0]}")"

# plan/index.md Base row: $4=状态 $6=审核日期 $7=校验 (escape-aware split for
# consistency with the other row updaters; hash/date carry no escapes).
tmp="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
ESC="$(printf '\037')"
sed "s/\\\\|/$ESC/g" "$AS_ROOT/plan/index.md" \
  | awk -F'|' -v id="$KEY" -v d="$DATE" -v h="$HASH" -v esc="$ESC" '
    BEGIN { pat="^\\| *" id " *\\|"; found=0 }
    $0 ~ pat {
      $4=" 生效 "; $6=" " d " "; $7=" " h " "
      out=$1; for (i=2; i<=NF; i++) out=out "|" $i
      print out; found=1; next
    }
    { print }
    END { if (!found) exit 3 }
  ' | sed "s/$ESC/\\\\|/g" > "$tmp" || { rm -f "$tmp"; as_die "index missing $KEY"; }
as_atomic_write "$AS_ROOT/plan/index.md" "$tmp"

# plan.md Base row: state cell only ($4). Escape-aware split — the 方向 cell
# may carry an escaped pipe from as_cell (same shield as the index pass above).
tmp="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
ESC2="$(printf '\037')"
sed "s/\\\\|/$ESC2/g" "$AS_ROOT/plan.md" \
  | awk -F'|' -v id="$KEY" -v esc="$ESC2" '
    BEGIN { pat="^\\| *" id " *\\|"; found=0 }
    $0 ~ pat {
      $4=" 生效 "
      out=$1; for (i=2; i<=NF; i++) out=out "|" $i
      print out; found=1; next
    }
    { print }
    END { if (!found) exit 3 }
  ' | sed "s/$ESC2/\\\\|/g" > "$tmp" || { rm -f "$tmp"; as_die "plan.md Base section missing $KEY"; }
as_atomic_write "$AS_ROOT/plan.md" "$tmp"

echo "$KEY → 生效 (checksum pinned: $HASH)"
echo "The file is now immutable — any modification is reported by doctor [17]; a direction change can only be a NEW base plan superseding this one (retire-base-plan.sh $ID replaced \"reason\" --by <new-id>)"
