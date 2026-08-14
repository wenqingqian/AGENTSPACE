#!/usr/bin/env bash
# Key code-repo registry (.agentspace-repos) — the ONLY write entry.
# Rows: repos inside the project root stored root-relative, external repos
# absolute; spelling physical (cd -P) and git-toplevel normalized.
# Registration/removal always requires explicit user confirmation — that rule
# lives in the skill/AGENTS.md layer; this script enforces the mechanics.
# Usage: repos.sh [--add <path> | --remove <path> | --list]
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

action="--list"; arg=""
case "${1:-}" in
  --add|--remove)
    action="$1"; arg="${2:-}"
    [ -n "$arg" ] || as_die "missing path for $1"
    ;;
  --list|"") ;;
  *) as_die "unknown argument: ${1:-}" ;;
esac

FILE="$AS_ROOT/.agentspace-repos"

if [ "$action" = "--list" ]; then
  if [ ! -f "$FILE" ] || ! grep -qvE '^(#.*|[[:space:]]*)$' "$FILE" 2>/dev/null; then
    echo "(无登记仓库)"
    exit 0
  fi
  grep -vE '^(#.*|[[:space:]]*)$' "$FILE"
  exit 0
fi

as_lock

# Spelling normalization (whitelist grammar): strip ./ prefix and one trailing
# /; canonicalize when the path exists. as_repo_canon already resolves to the
# git toplevel, so passing a subdirectory — or a file inside the worktree —
# registers the repo root.
if [ -e "$arg" ]; then
  canon="$(as_repo_canon "$arg" 2>/dev/null || true)"
else
  # Dangling path (only --remove may proceed): physicalize via the parent so
  # the stored spelling can still be matched. Never fall back to git-toplevel
  # resolution here — for a moved-away repo that would wrongly land on the
  # CONTAINING repo (dirname walks up) and --remove would delete its row.
  canon=""
  if [ "$action" = "--remove" ]; then
    d="$(cd -P "$(dirname "$arg")" 2>/dev/null && pwd -P || true)"
    [ -n "$d" ] && canon="$d/$(basename "$arg")"
  fi
fi
if [ -n "$canon" ]; then
  # The AGENTSPACE workspace itself is never a managed code repo — the ledger
  # is exempt from commit discipline by design, so refuse it at the door.
  # Only --add needs the refusal: such a row cannot exist, so --remove of it
  # simply reports "not registered" — accurate.
  if [ "$action" = "--add" ]; then
    case "$canon" in
      "$AS_ROOT"|"$AS_ROOT"/*)
        as_die "refused: the AGENTSPACE workspace itself cannot be registered" ;;
    esac
  fi
  stored="$canon"
else
  # Path missing or not a git worktree: --remove must still work (stale rows
  # are exactly what doctor [14] reports); --add refuses.
  if [ "$action" = "--add" ]; then
    as_die "not inside a git worktree: $arg"
  fi
  stored="$arg"
fi
case "$stored" in
  ./*) stored="${stored#./}" ;;
esac
case "$stored" in
  /) ;;
  */) stored="${stored%/}" ;;
esac
base="$(cd -P "$AS_ROOT/.." 2>/dev/null && pwd -P || echo "$AS_ROOT/..")"
case "$stored" in
  "$base"/*) stored="${stored#"$base"/}" ;;
esac

if [ "$action" = "--add" ]; then
  # Dedup on both spellings (normalized + base-joined absolute) — the same
  # two-spelling check as --remove: a hand-edited absolute row for an in-root
  # repo must not be duplicated by --add.
  if [ -f "$FILE" ] && { grep -Fxq -- "$stored" "$FILE" 2>/dev/null || grep -Fxq -- "$base/$stored" "$FILE" 2>/dev/null; }; then
    echo "already registered: $stored"
    exit 0
  fi
  tmp="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
  chmod 644 "$tmp"
  # Guard against a silent row drop: a failed cat on an unreadable registry
  # would leave a tmp with only the new row and as_atomic_write would replace
  # the registry, losing every existing row.
  if [ -f "$FILE" ] && [ ! -r "$FILE" ]; then
    as_die "registry exists but is unreadable: $FILE (fix permissions)"
  fi
  { cat "$FILE" 2>/dev/null || true; printf '%s\n' "$stored"; } > "$tmp"
  as_atomic_write "$FILE" "$tmp"
  echo "registered: $stored"
  exit 0
fi

# --remove: match the stored spelling, or the base-joined spelling for a
# relative argument written down absolute (and vice versa).
# No registry file is as benign as "not registered" — both exit 0.
[ -f "$FILE" ] || { echo "no registry file — nothing to remove" >&2; exit 0; }
target=""
for cand in "$stored" "$base/$stored"; do
  if grep -Fxq -- "$cand" "$FILE" 2>/dev/null; then
    target="$cand"; break
  fi
done
if [ -z "$target" ]; then
  echo "not registered: $stored"
  exit 0
fi
tmp="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
entry="$target" awk '!/^#/ && $0 == ENVIRON["entry"] { next } { print }' "$FILE" > "$tmp"
as_atomic_write "$FILE" "$tmp"
echo "removed: $target"
