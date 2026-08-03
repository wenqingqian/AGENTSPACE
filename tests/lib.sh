#!/usr/bin/env bash
# Test infrastructure for the AGENTSPACE regression suite (dev-only, NOT deployed).
# build_sandbox <tag>: creates /tmp/as-test-<tag>-XXXXXX/project/AGENTSPACE from the
# init assets (the mechanical output of init), initializes git in both host and
# workspace, and echoes the project root path. Tests operate on the sandbox copy —
# the plugin repo is never modified.

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSETS="$REPO/skills/agentspace-init/assets/agentspace"

fail() {
  echo "FAIL: $*" >&2
  echo "sandbox left at: ${SB:-<none>}" >&2
  exit 1
}

assert_ok() { "$@" || fail "command failed: $*"; }
assert_fails() { "$@" && fail "expected failure (exit 0): $*"; return 0; }
assert_contains() { grep -Fq "$2" "$1" || fail "expected '$2' in $1"; }
assert_not_contains() { grep -Fq "$2" "$1" && fail "unexpected '$2' in $1"; return 0; }
assert_output_contains() { printf '%s' "$1" | grep -Fq "$2" || fail "expected '$2' in command output"; }
assert_output_not_contains() { printf '%s' "$1" | grep -Fq "$2" && fail "unexpected '$2' in command output"; return 0; }

build_sandbox() {
  local tag="$1" sb
  sb="$(mktemp -d "/tmp/as-test-${tag}-XXXXXX")" || return 1
  mkdir -p "$sb/project"
  # run the REAL init script — the sandbox is the mechanical output of /init-agentspace
  (cd "$sb/project" && bash "$REPO/skills/agentspace-init/scripts/init-agentspace.sh" >/dev/null 2>&1) || return 1
  # host repo (for host-commit recording): init AFTER the workspace so the
  # workspace keeps its own .git; gitignore the nested workspace like a real host
  printf '/AGENTSPACE/\n' > "$sb/project/.gitignore"
  git -C "$sb/project" init -q -b main
  git -C "$sb/project" -c user.name=test -c user.email=test@test add -A >/dev/null 2>&1
  git -C "$sb/project" -c user.name=test -c user.email=test@test commit -qm init >/dev/null 2>&1
  echo "$sb/project"
}
