#!/usr/bin/env bash
# Dev tool — repo root only, NOT part of the deployed plugin.
# Retry `git push origin main` in a loop until it succeeds. The GitHub 443
# connectivity failures are transient; this runs unattended (background) so a
# blocked push retries itself instead of waiting for manual attempts.
# Every attempt is logged (timestamped) to /tmp/push-retry.log.
# Usage: bash push-retry.sh [--interval <seconds>] [--max-attempts <n>]
#   defaults: interval 60, max-attempts 0 (= retry forever)
set -uo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
INTERVAL=60
MAX=0
while [ $# -gt 0 ]; do
  case "$1" in
    --interval) INTERVAL="${2:?}"; shift 2 ;;
    --max-attempts) MAX="${2:?}"; shift 2 ;;
    *) echo "usage: push-retry.sh [--interval <sec>] [--max-attempts <n>]" >&2; exit 1 ;;
  esac
done
[[ "$INTERVAL" =~ ^[0-9]+$ ]] || { echo "error: --interval must be a number" >&2; exit 1; }
[[ "$MAX" =~ ^[0-9]+$ ]] || { echo "error: --max-attempts must be a number" >&2; exit 1; }

LOG=/tmp/push-retry.log
attempt=0
while :; do
  attempt=$((attempt+1))
  if [ "$MAX" -gt 0 ] && [ "$attempt" -gt "$MAX" ]; then
    echo "$(date '+%F %T') give up after $attempt attempts (network still down)" >> "$LOG"
    exit 1
  fi
  echo "$(date '+%F %T') attempt #$attempt: git push origin main" >> "$LOG"
  if git -C "$REPO" push origin main >> "$LOG" 2>&1; then
    echo "$(date '+%F %T') push OK" >> "$LOG"
    exit 0
  fi
  sleep "$INTERVAL"
done
