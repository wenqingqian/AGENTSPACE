#!/usr/bin/env bash
# Pre-commit gate for registered key code repos (commit discipline).
#   commit-check.sh <repo-path> "<draft-message>"
# Exit 0 = pass (warnings allowed through, they must be shown to the user);
# exit 1 = blocked (violations listed, one full batch — never drip-feed);
# exit 2 = repo not registered in .agentspace-repos (propose registration to
# the user first; on confirmation: repos.sh --add <path>);
# exit 3 = usage/precondition error (missing draft-message / not inside a git
# worktree) — fails closed, never a silent PASS.
# Checks: staged file paths · staged diff ADDED lines (code/comments/string
# literals — bookkeeping-id ban, same lib.sh single source as the message ban;
# deletions, binary files and pure renames never match) · draft message.
# Plus a report-only wide-net CANDIDATE layer (plan/iteration word adjacent to
# digits, any separator — lib.sh COMMIT_CANDIDATE_*_RE): candidates are listed
# for explicit agent adjudication and NEVER alter the exit code — hard hits
# stay hard hits (exit 1), and the candidate list rides along either way for
# full attribution.
# READ-ONLY: never touches the repo, its index, or the workspace. No --force
# valve by design — a blocked commit is rewritten, not forced through.
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

# The draft message is REQUIRED: the message ban must never be silently
# skipped (an omitted message must not produce a PASS identical to a checked
# one) — fail closed with the usage-error code 3.
[ $# -ge 2 ] || { printf 'error: usage: commit-check.sh <repo-path> "<draft-message>"\n' >&2; exit 3; }
REPO_ARG="$1"; MSG="$2"

REPO="$(as_repo_canon "$REPO_ARG")" || { printf 'error: not inside a git worktree: %s\n' "$REPO_ARG" >&2; exit 3; }
# The AGENTSPACE ledger repo is always exempt (repos.sh refuses it at the
# door) — misapplying the gate to the workspace gets an actionable message,
# not a dead-end "register it first" hint.
if [ "$REPO" = "$AS_ROOT" ]; then
  printf 'error: the AGENTSPACE ledger repo is always exempt — commit discipline applies to registered key code repos only\n' >&2
  exit 2
fi
if ! as_repo_registered "$REPO_ARG"; then
  printf 'error: not a registered key code repo: %s\n' "$REPO" >&2
  printf '       registration requires user confirmation; then: repos.sh --add <path>\n' >&2
  exit 2
fi

blocks=0; warns=0; block_lines=""; warn_lines=""

# ---- staged files (added/copied/modified/renamed/type-changed; -M + R in the
# filter so a rename is one record — a file renamed INTO a blocked path (e.g.
# top-level wandb/) is path-checked under its new name, and rename+edit hunks
# reach the content scan below) ----
staged=0
while IFS= read -r -d '' p; do
  [ -n "$p" ] || continue
  staged=$((staged + 1))
  top="${p%%/*}"; base="$(basename "$p")"; reasons=""
  # workspace content never belongs in a code repo (nested form)
  case "$top" in
    AGENTSPACE) reasons="${reasons}工作区路径混入代码仓库; " ;;
  esac
  # experiment-output signatures: tfevents basename / wandb / mlruns / lightning_logs
  case "$base" in
    events.out.tfevents.*) reasons="${reasons}实验输出特征(tensorboard 事件文件); " ;;
  esac
  for d in $COMMIT_SIG_DIRS; do
    [ "$top" = "$d" ] && { reasons="${reasons}实验输出特征(顶层目录 $d/); "; break; }
  done
  if [ -n "$reasons" ]; then
    blocks=$((blocks + 1)); block_lines="${block_lines}  - $p — ${reasons%; }"$'\n'
    continue
  fi
  # blob size (staged content, not worktree): hard block at/above 50MB
  sz="$(git -C "$REPO" cat-file -s ":$p" 2>/dev/null || printf '0')"
  case "$sz" in ''|*[!0-9]*) sz=0 ;; esac
  if [ "$sz" -ge "$COMMIT_BLOCK_BYTES" ]; then
    blocks=$((blocks + 1))
    block_lines="${block_lines}  - $p ($((sz / 1048576))MB) — 单文件 ≥ $((COMMIT_BLOCK_BYTES / 1048576))MB"$'\n'
    continue
  fi
  # warn level: data/model extensions ≥100KB, top-level output dirs
  w=""
  ext="$(printf '%s' "${base##*.}" | tr 'A-Z' 'a-z')"
  if [ "$ext" != "$base" ] && [ "$sz" -ge "$COMMIT_WARN_BYTES" ]; then
    for e in $COMMIT_DATA_EXTS; do
      [ "$ext" = "$e" ] && { w="数据/模型扩展名 ≥$((COMMIT_WARN_BYTES / 1024))KB — 确认非实验产物泄漏(测试夹具合法)"; break; }
    done
  fi
  for d in $COMMIT_OUT_DIRS; do
    [ "$top" = "$d" ] && { w="${w:+$w; }顶层输出目录 $d/ — 确认非程序写死输出的产物"; break; }
  done
  if [ -n "$w" ]; then
    warns=$((warns + 1)); warn_lines="${warn_lines}  - $p — $w"$'\n'
  fi
done < <(git -C "$REPO" diff --cached -M --name-only -z --diff-filter=ACMRT 2>/dev/null || true)

# ---- draft message: canonical bookkeeping-id ban (whole message, case-insensitive) ----
msg_cands=""
if [ -n "$MSG" ]; then
  hit="$(printf '%s' "$MSG" | grep -inE "$COMMIT_BAN_PLAN_RE|$COMMIT_BAN_ITER_RE|$COMMIT_BAN_EXP_RE" 2>/dev/null || true)"
  if [ -n "$hit" ]; then
    blocks=$((blocks + 1))
    block_lines="${block_lines}  - message: 含工作区记账引用(plan:NNNN / iteration_NNNN / exp_NNNN) — 归属信息由 iteration readme 的宿主 SHA 记录承担, commit message 不得出现:"$'\n'
    while IFS= read -r h; do
      block_lines="${block_lines}      第 ${h%%:*} 行: ${h#*:}"$'\n'
    done <<< "$hit"
  fi
  # ---- draft message: wide-net candidates (report-only — never block) ----
  # Same surface as the ban scan, wider net (COMMIT_CANDIDATE_*_RE). Positional
  # dedup: a line already hard-hit by the canonical pair is owned by the ban
  # scan and filtered out here, so it is never listed twice.
  msg_cands="$(printf '%s' "$MSG" | grep -inE "$COMMIT_CANDIDATE_PLAN_RE|$COMMIT_CANDIDATE_ITER_RE" 2>/dev/null || true)"
  if [ -n "$msg_cands" ] && [ -n "$hit" ]; then
    _banned=" $(printf '%s\n' "$hit" | cut -d: -f1 | tr '\n' ' ')"
    _kept=""
    while IFS= read -r _c; do
      [ -n "$_c" ] || continue
      case "$_banned" in *" ${_c%%:*} "*) continue ;; esac
      _kept="${_kept}${_c}"$'\n'
    done <<< "$msg_cands"
    msg_cands="$(printf '%s' "$_kept")"
  fi
fi
# ---- draft message: blank title (deterministic quality rule, single source lib.sh) ----
if as_msg_title_blank "$MSG"; then
  blocks=$((blocks + 1))
  block_lines="${block_lines}  - message: 标题为空或纯空白 — 标题(第一行)必须是一句话的代码改动描述"$'\n'
fi

# ---- staged diff content: bookkeeping-id ban on ADDED lines (code + comments) ----
# Same single-source regexes as the message ban (lib.sh, via as_diff_added_hits):
# what may not be said in the message may not be smuggled in through a comment
# or a string literal. Only ADDED lines are tested — deleting an old leak never
# blocks. Binary files emit no hunks; pure renames carry no added lines. The
# diff runs with --no-ext-diff and pinned prefixes so a repo-local diff driver
# or prefix config cannot blind or mangle the scan; a failed diff read fails
# CLOSED (exit 3) — an unreadable staged diff must never look like "no hits";
# matcher knobs are pinned at the call (ambient AS_* env cannot weaken the
# gate scan).
_d="$(mktemp)"
if ! git -C "$REPO" -c diff.noprefix=false -c diff.mnemonicprefix=false diff --cached --no-ext-diff -M -U0 --diff-filter=ACMRT >"$_d" 2>/dev/null; then
  rm -f "$_d"; printf 'error: staged diff unreadable — fails closed\n' >&2; exit 3
fi
content_hits="$(AS_BAN_RE="$COMMIT_BAN_PLAN_RE|$COMMIT_BAN_ITER_RE|$COMMIT_BAN_EXP_RE" AS_LINE_MAX=0 as_diff_added_hits <"$_d" 2>/dev/null || true)"
# Wide-net candidates on the SAME staged diff, knobs pinned at the call like
# the ban scan. The candidate layer can never fail the gate (no exit-code
# voice), so its read fails open to an empty list; dedup vs the canonical pair
# is enforced inside as_diff_added_candidates — a canonical-hit line is never
# re-listed here.
content_cands="$(AS_BAN_RE="$COMMIT_BAN_PLAN_RE|$COMMIT_BAN_ITER_RE|$COMMIT_BAN_EXP_RE" AS_CAND_RE="$COMMIT_CANDIDATE_PLAN_RE|$COMMIT_CANDIDATE_ITER_RE" AS_LINE_MAX=0 as_diff_added_candidates <"$_d" 2>/dev/null || true)"
rm -f "$_d"
if [ -n "$content_hits" ]; then
  blocks=$((blocks + 1))
  block_lines="${block_lines}  - content: 新增行(代码/注释)含工作区记账引用(plan:NNNN / iteration_NNNN / exp_NNNN) — 代码与注释描述改动本身, 归属由 iteration readme 的宿主 SHA 承担:"$'\n'
  while IFS=$'\t' read -r hp hl hx; do
    [ -n "$hp" ] || continue
    if [ "$hl" = "-more" ]; then
      block_lines="${block_lines}      $hp — $hx"$'\n'
    else
      block_lines="${block_lines}      $hp:$hl — $hx"$'\n'
    fi
  done <<< "$content_hits"
fi

# ---- candidate assembly (report-only — candidates have no exit-code voice) ----
cands=0; cand_lines=""
if [ -n "$msg_cands" ]; then
  while IFS= read -r c; do
    [ -n "$c" ] || continue
    cands=$((cands + 1))
    cand_lines="${cand_lines}  - message 第 ${c%%:*} 行: ${c#*:}"$'\n'
  done <<< "$msg_cands"
fi
if [ -n "$content_cands" ]; then
  while IFS=$'\t' read -r chp chl chx; do
    [ -n "$chp" ] || continue
    if [ "$chl" = "-more" ]; then
      cand_lines="${cand_lines}      $chp — $chx"$'\n'
    else
      cands=$((cands + 1))
      cand_lines="${cand_lines}  - content $chp:$chl — $chx"$'\n'
    fi
  done <<< "$content_cands"
fi

echo "== commit-check: $REPO =="
echo "暂存: $staged 个文件"
if [ "$blocks" -gt 0 ]; then
  echo; echo "BLOCK ($blocks):"
  printf '%s' "$block_lines"
fi
if [ "$warns" -gt 0 ]; then
  echo; echo "WARN ($warns) — 不阻断, 但必须展示给用户并由 agent 结合仓库上下文判断:"
  printf '%s' "$warn_lines"
fi
if [ "$cands" -gt 0 ]; then
  echo; echo "CANDIDATES ($cands) — candidates for agent adjudication (报告层, 永不影响 exit code):"
  printf '%s' "$cand_lines"
  echo "  → agent 语义层必须对以上每个候选逐条显式裁决; 裁决结论(放行/否决)与理由由 agent 向用户陈述 — 脚本不代替判定。放行必须给出理由; 否决则改写文本后重新过门。"
fi
echo
if [ "$blocks" -gt 0 ]; then
  echo "== BLOCKED: $blocks 项阻断 — 修复后重新过门; 门无放行阀门 =="
  exit 1
fi
if [ "$cands" -gt 0 ]; then
  echo "== PASS ($warns 项提醒; $cands 个候选已列上方 — 由 agent 裁决, 不阻断) =="
else
  echo "== PASS ($warns 项提醒) =="
fi
