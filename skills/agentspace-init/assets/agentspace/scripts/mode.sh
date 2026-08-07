#!/usr/bin/env bash
# mode.sh — workspace mode control: hybrid (default) / standalone.
#   mode.sh                    → print current mode + one-line mechanism cue
#   mode.sh --hybrid           → switch to hybrid (idempotent; relax, no clean-up)
#   mode.sh --standalone       → switch to standalone (idempotent; rewrites the
#                                ## agentspace mode block, auto-whitelists large
#                                external refs, runs doctor.sh, reports the rest)
#   mode.sh --list             → print whitelist entries (non-comment lines)
#   mode.sh --allow <path>     → add a whitelist entry (atomic; caller confirms)
#   mode.sh --deny <path>      → remove a whitelist entry (atomic)
#
# The `## agentspace mode` block in AGENTS.md is the single source of truth
# (sessions see it when loading AGENTS.md; doctor reads it to gate [13]).
# The whitelist (.agentspace-whitelist) is the only standalone escape hatch:
# relative-to-project-root or absolute paths, files or directories.
# All writes are locked + atomic (tmp+mv).
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

WHITELIST="$AS_ROOT/.agentspace-whitelist"

usage() { echo "usage: mode.sh [--hybrid|--standalone|--list|--allow <path>|--deny <path>]" >&2; exit 1; }

# --- whitelist add/remove live in lib.sh (shared with doctor.sh [13]) ---

# --- mode switch: rewrite the AGENTS.md block (insert before 项目简介 when
#     the block is missing — legacy workspace); standalone mode additionally
#     auto-whitelists large (≥ WHITELIST_LARGE_BYTES) external refs — copying
#     them is unrealistic — then runs doctor.sh for the rest ---
set_mode() {
  local want="$1" now tmp
  now="$(as_mode)"
  if [ "$now" = "$want" ]; then
    echo "mode already $want (no change)"
    return 0
  fi
  as_lock
  tmp="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
  want="$want" awk '
    /^## agentspace mode[[:space:]]*$/ {
      print "## agentspace mode"; print ENVIRON["want"]
      if (ENVIRON["want"] == "standalone") print "rules"
      f=1; done=1; next
    }
    f { if (NF && $0 !~ /^## /) next; f=0 }
    /^## 项目简介/ && !done {
      print "## agentspace mode"; print ENVIRON["want"]
      if (ENVIRON["want"] == "standalone") print "rules"
      print ""; done=1
    }
    { print }
    END { if (!done) exit 3 }
  ' "$AS_ROOT/AGENTS.md" > "$tmp" || { rm -f "$tmp"; as_die "AGENTS.md mode block rewrite failed (anchor missing)"; }
  as_atomic_write "$AS_ROOT/AGENTS.md" "$tmp"
  echo "mode → $want (AGENTS.md ## agentspace mode block updated)"
  if [ "$want" = "standalone" ]; then
    echo "== standalone: auto-whitelist large external refs (≥ 1G, copy-unrealistic) =="
    while IFS= read -r ref; do
      [ -n "$ref" ] || continue
      as_whitelisted "$ref" && continue
      if [ -e "$ref" ]; then
        sz="$(as_ref_size_bytes "$ref")"
        if [ "${sz:-0}" -ge "$WHITELIST_LARGE_BYTES" ]; then
          add_whitelist_entry "$ref"
        fi
      fi
    done < <(as_external_refs || true)
    echo "== standalone: doctor check =="
    bash "$AS_ROOT/scripts/doctor.sh" || true
  fi
}

case "${1:-}" in
  "")
    m="$(as_mode)"
    echo "mode: $m"
    if [ "$m" = "standalone" ]; then
      echo "standalone rules: 外部依赖必须集成(物理位于 AGENTSPACE/ 内)或白名单; 小文件豁免须用户显式确认; 完整规则可 cue(/agentspace-mode 无参)"
    else
      echo "hybrid: 允许外部数据/脚本(现状); 白名单仅 standalone 生效"
    fi
    ;;
  --hybrid) set_mode hybrid ;;
  --standalone) set_mode standalone ;;
  --list)
    if [ -f "$WHITELIST" ]; then
      n="$(grep -vc '^#' "$WHITELIST" || true)"
      echo "whitelist ($n entries):"
      grep -v '^#' "$WHITELIST" | grep -v '^[[:space:]]*$' || true
    else
      echo "whitelist: (无)"
    fi
    ;;
  --allow)
    [ $# -ge 2 ] || usage
    as_lock
    add_whitelist_entry "$2"
    ;;
  --deny)
    [ $# -ge 2 ] || usage
    as_lock
    remove_whitelist_entry "$2"
    ;;
  *) usage ;;
esac
