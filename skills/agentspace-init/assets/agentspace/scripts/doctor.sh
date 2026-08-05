#!/usr/bin/env bash
# Consistency check: entry tables / full indexes ↔ filesystem.
# Broken latest symlink auto-repaired; other issues reported.
# --fix: additionally auto-repair safe deterministic items (orphan table rows,
# missing notes.md rows); semantic issues are always reported, never auto-fixed.
# Usage: doctor.sh [--fix]
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

FIX=0
for a in "$@"; do
  case "$a" in
    --fix) FIX=1 ;;
    *) printf 'error: unknown argument: %s\n' "$a" >&2; exit 2 ;;
  esac
done

issues=0
fixed=0
# Use printf to avoid echo interpreting leading `-`
# warn/ok only valid in main shell (pipe subshell changes don't propagate)
warn() { printf '  [issue] %s\n' "$*"; issues=$((issues + 1)); }
ok()   { printf '  [fixed] %s\n' "$*"; fixed=$((fixed + 1)); }

# Insert a row into notes.md after the first table separator line.
# notes.md has no "## " section heading, so as_insert_row cannot be used here.
notes_insert_row() {
  local row="$1" tmp
  tmp="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
  awk -v row="$row" '
    /^\|[ :|-]+\|$/ && !inserted { print; print row; inserted=1; next }
    { print }
    END { if (!inserted) exit 3 }
  ' "$AS_ROOT/notes.md" > "$tmp" || { rm -f "$tmp"; warn "notes.md: table separator not found, row not inserted"; return 1; }
  as_atomic_write "$AS_ROOT/notes.md" "$tmp"
}

# Primary source ref (plan:NNNN / iteration_NNNN) of a note file, from its
# "> 来源:" header line — first matching token wins, trailing context ignored.
# The numeric part is zero-pad-normalized (as_norm_id) so hand-written refs
# like plan:1 match the padded index rows / iteration dir names in [7]/[8].
note_primary_ref() {
  local ref
  ref="$(grep -E '^> 来源:' "$1" 2>/dev/null | head -1 | grep -oE 'plan:[0-9]+|iteration_[0-9]+' | head -1 || true)"
  if [ -n "$ref" ]; then
    case "$ref" in
      plan:*)
        if [[ "${ref#plan:}" =~ ^[0-9]+$ ]]; then
          ref="plan:$(as_norm_id "${ref#plan:}")"
        fi ;;
      iteration_*)
        if [[ "${ref#iteration_}" =~ ^[0-9]+$ ]]; then
          ref="iteration_$(as_norm_id "${ref#iteration_}")"
        fi ;;
    esac
  fi
  printf '%s' "$ref"
}

# --fix writes tables → take the same lock the write scripts use
if [ "$FIX" -eq 1 ]; then
  as_lock
fi

echo "== AGENTSPACE doctor: $AS_ROOT =="
echo

# ---- 0. git worktree: uncommitted changes (milestone commit may have been skipped) ----
# F2 (audit): require the workspace's OWN .git dir — rev-parse alone walks up and
# would report the HOST repo's dirty state when the workspace has no own repo.
echo "[0] git worktree"
if [ -e "$AS_ROOT/.git" ]; then  # -e covers git worktrees (.git as file), matches init contract
  dirty="$(git -C "$AS_ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ' || true)"
  [ "${dirty:-0}" -eq 0 ] || warn "uncommitted changes ($dirty file(s)); run a milestone commit"
fi

# ---- 1. latest symlink ----
echo "[1] iterations/latest"
L="$AS_ROOT/iterations/latest"
if [ -L "$L" ] && [ ! -e "$L" ]; then
  rm -f "$L"
  warn "latest symlink broken, removed"
fi
if [ ! -L "$L" ]; then
  last="$(ls -d "$AS_ROOT"/iterations/iteration_[0-9]* 2>/dev/null | sort | tail -1 || true)"
  if [ -n "$last" ]; then
    ln -sfn "$(basename "$last")" "$L"
    ok "latest -> $(basename "$last")"
  fi
fi

# ---- 2. plan: files ↔ entry table ↔ full index ----
echo "[2] plan consistency"
shopt -s nullglob

for f in "$AS_ROOT"/plan/todo/[0-9]*.md; do
  id="$(basename "$f" | cut -d- -f1)"
  [ -n "$(as_row_cell "$AS_ROOT/plan.md" "$id" 3)" ] \
    || warn "plan.md Todo missing $id ($(basename "$f"))"
  grep -q "^| *$id *|" "$AS_ROOT/plan/index.md" \
    || warn "plan/index.md missing $id ($(basename "$f"))"
done

for f in "$AS_ROOT"/plan/done/[0-9]*.md; do
  id="$(basename "$f" | cut -d- -f1)"
  grep -q "^| *$id *|" "$AS_ROOT/plan/index.md" \
    || warn "plan/index.md missing completed $id ($(basename "$f"))"
done

# Todo rows must have corresponding files
todo_ids="$(awk -F'|' -v sec="$SEC_TODO" '
  $0 ~ ("^## " sec "[[:space:]]*$") { f=1; next }
  /^## / { f=0 }
  f && /^\| [0-9]/ { gsub(/ /, "", $2); print $2 }
' "$AS_ROOT/plan.md")"
for id in $todo_ids; do
  # compgen -G: nullglob is on for the forward loops, which would turn a bare
  # unmatched glob into an empty arg and make `ls` succeed on cwd (silent no-op)
  if compgen -G "$AS_ROOT/plan/todo/$id-*.md" >/dev/null; then
    :
  elif [ "$FIX" -eq 1 ]; then
    before="$(wc -l < "$AS_ROOT/plan.md")"
    as_remove_row_section "$AS_ROOT/plan.md" "$SEC_TODO" "$id"
    if [ "$(wc -l < "$AS_ROOT/plan.md")" -lt "$before" ]; then
      ok "removed orphan Todo row $id (no file)"
    else
      # v0.3.3: a failed repair must not report green — surface it instead
      warn "plan.md orphan row $id NOT removed (section \"$SEC_TODO\" missing or drifted)"
    fi
  else
    warn "plan.md Todo row $id has no corresponding file (orphan row)"
  fi
done

# ---- 3. iterations: dirs ↔ entry table ↔ full index ----
echo "[3] iterations consistency"
for d in "$AS_ROOT"/iterations/iteration_[0-9]*; do
  [ -d "$d" ] || continue
  id="$(basename "$d" | sed 's/iteration_//')"
  [ -f "$d/readme.md" ] || warn "iteration_$id missing readme.md"
  grep -q "^| *$id *|" "$AS_ROOT/iterations/index.md" \
    || warn "iterations/index.md missing $id"
  # Only in-progress iterations must appear in entry table (completed may be truncated)
  if grep -q "^$STATUS_PROGRESS$" "$d/readme.md" 2>/dev/null; then
    grep -q "^| *$id *|" "$AS_ROOT/iterations.md" \
      || warn "iterations.md missing in-progress $id"
    # Resume-block freshness — wrap-up protocol step ①
    grep -Fq "$RESUME_PH_ITER" "$d/readme.md" \
      && warn "iteration_$id: 当前状态 · 下一步 not updated (resume placeholder still present)"
    # F1 backstop (audit): v0.2.3-era readmes may carry duplicated sections —
    # a duplicated 结果 section with a leftover placeholder would block close.
    dup="$(grep -c '^## 结果$' "$d/readme.md" 2>/dev/null || true)"
    [ "${dup:-0}" -le 1 ] || warn "iteration_$id: duplicated '## 结果' section (${dup}×, v0.2.3-era template) — a leftover placeholder in the duplicate blocks closing; ask the user before cleaning"
  fi
done

# In-progress rows must have corresponding dirs
prog_ids="$(awk -F'|' -v sec="$SEC_PROGRESS" '
  $0 ~ ("^## " sec "[[:space:]]*$") { f=1; next }
  /^## / { f=0 }
  f && /^\| [0-9]/ { gsub(/ /, "", $2); print $2 }
' "$AS_ROOT/iterations.md")"
for id in $prog_ids; do
  if [ -d "$AS_ROOT/iterations/iteration_$id" ]; then
    :
  elif [ "$FIX" -eq 1 ]; then
    before="$(wc -l < "$AS_ROOT/iterations.md")"
    as_remove_row_section "$AS_ROOT/iterations.md" "$SEC_PROGRESS" "$id"
    if [ "$(wc -l < "$AS_ROOT/iterations.md")" -lt "$before" ]; then
      ok "removed orphan in-progress row $id (no dir)"
    else
      # v0.3.3: a failed repair must not report green — surface it instead
      warn "iterations.md in-progress row $id NOT removed (section \"$SEC_PROGRESS\" missing or drifted)"
    fi
  else
    warn "iterations.md in-progress row $id has no corresponding dir (orphan row)"
  fi
done

# ---- 4. link validity: script-managed tables only (links are script contract output) ----
echo "[4] link validity"
# shellcheck disable=SC2016
for t in plan.md plan/index.md iterations.md iterations/index.md register.md; do
  tfile="$AS_ROOT/$t"
  [ -f "$tfile" ] || continue
  # Only table data rows (| ...) — header pointers like the latest symlink are out of scope
  while IFS= read -r target; do
    [ -n "$target" ] || continue
    case "$target" in
      http://*|https://*|mailto:*|\#*) continue ;;
    esac
    # F5 (audit): strip #anchor suffixes — target must be a real file path
    [ -e "$AS_ROOT/${target%%#*}" ] || warn "$t: broken link → $target"
  done < <(grep '^| ' "$tfile" | grep -o ']([^)]*)' | sed 's/^](//; s/)$//')
done

# ---- 5. contract: placeholder constants must still match templates ----
echo "[5] placeholder contract"
for pair in "RESUME_PH_ITER:templates/iteration-readme.md" "RESULT_PH_ITER:templates/iteration-readme.md" "RESULT_PH_PLAN:templates/plan.md"; do
  const="${pair%%:*}"; tpl="${pair##*:}"
  val="$(eval "printf '%s' \"\${$const}\"")"
  grep -Fq "$val" "$AS_ROOT/$tpl" || warn "constant $const no longer matches $tpl (contract drift — update the constant or the template)"
done

# ---- 6. cross-reference: iteration → plan ownership ----
echo "[6] iteration→plan ownership"
for d in "$AS_ROOT"/iterations/iteration_[0-9]*; do
  [ -d "$d" ] || continue
  id="$(basename "$d" | sed 's/iteration_//')"
  [ -f "$d/readme.md" ] || continue  # missing readme already reported by [3]
  # readme declares the parent plan: "> plan: NNNN"
  rd_plan="$(grep -E '^> plan: [0-9]+' "$d/readme.md" 2>/dev/null | head -1 | grep -o '[0-9][0-9]*' | head -1 || true)"
  if [ -z "$rd_plan" ]; then
    warn "iteration_$id: readme missing '> plan:' header (iteration must belong to a plan)"
    continue
  fi
  # zero-pad-normalize hand-written refs (plan:1 → 0001) before table/index lookups
  if [[ "$rd_plan" =~ ^[0-9]+$ ]]; then
    rd_plan="$(as_norm_id "$rd_plan")"
  fi
  # entry table row (进行中 / 最近完成) declares the plan: "| ID | plan:NNNN | ..."
  tb_plan="$(as_row_cell "$AS_ROOT/iterations.md" "$id" 3 | grep -o 'plan:[0-9][0-9]*' | cut -d: -f2 | head -1 || true)"
  if [ -n "$tb_plan" ] && [ "$tb_plan" != "$rd_plan" ]; then
    warn "iteration_$id: readme says plan:$rd_plan but iterations.md row says plan:$tb_plan (mismatch)"
  fi
  # parent plan must exist in the full index
  grep -q "^| *$rd_plan *|" "$AS_ROOT/plan/index.md" \
    || warn "iteration_$id: parent plan $rd_plan not found in plan/index.md"
done

# ---- 7. notes: files ↔ entry table + source contract ----
echo "[7] notes integrity"
for f in "$AS_ROOT"/notes/*.md; do
  [ -f "$f" ] || continue
  slug="$(basename "$f")"
  ref="$(note_primary_ref "$f")"
  if grep -qF "notes/$slug" "$AS_ROOT/notes.md"; then
    :
  elif [ "$FIX" -eq 1 ]; then
    topic="$(grep -E '^# ' "$f" | head -1 | sed 's/^# *//' || true)"
    date="$(grep -E '^> 创建:' "$f" | head -1 | sed 's/^> 创建:[[:space:]]*//' || true)"
    if notes_insert_row "| $(as_cell "$topic") |  |  | $ref | $(as_cell "$date") | [notes/$slug](notes/$slug) |"; then
      ok "notes.md: inserted row for $slug"
    fi
  else
    warn "notes.md missing row for $slug (add a row with 来源/日期/链接)"
  fi
  if [ -z "$ref" ]; then
    warn "notes/$slug: 来源 missing or malformed (need plan:NNNN / iteration_NNNN)"
  else
    case "$ref" in
      plan:*)
        pid="${ref#plan:}"
        grep -q "^| *$pid *|" "$AS_ROOT/plan/index.md" \
          || warn "notes/$slug: 来源 $ref not found in plan/index.md" ;;
      iteration_*)
        iid="${ref#iteration_}"
        [ -d "$AS_ROOT/iterations/iteration_$iid" ] \
          || warn "notes/$slug: 来源 $ref target dir not found" ;;
    esac
  fi
done
# entry rows must point at existing files (agent-maintained table → same link check as [4])
while IFS= read -r target; do
  [ -n "$target" ] || continue
  case "$target" in
    http://*|https://*|mailto:*|\#*) continue ;;
  esac
  [ -e "$AS_ROOT/${target%%#*}" ] || warn "notes.md broken link → $target"
done < <(grep '^| ' "$AS_ROOT/notes.md" | grep -o ']([^)]*)' | sed 's/^](//; s/)$//')

# ---- 8. back-link discipline: iteration-sourced notes must link their readme ----
echo "[8] note back-links (iteration-sourced)"
for f in "$AS_ROOT"/notes/*.md; do
  [ -f "$f" ] || continue
  ref="$(note_primary_ref "$f")"
  case "$ref" in
    iteration_*)
      # v0.2.12 promised existing notes are NOT retrofitted — only notes
      # created on/after the discipline's adoption date must back-link
      created="$(grep -E '^> 创建:' "$f" 2>/dev/null | head -1 | sed 's/^> 创建:[[:space:]]*//' || true)"
      if [ -n "$created" ] && [ "$created" \< "2026-08-04" ]; then
        continue  # pre-discipline note — exempt
      fi
      # link-level check: a real markdown link target must point at the source
      # readme — exact "iteration_NNNN/readme.md" or a relative form ending in
      # "/iteration_NNNN/readme.md" (e.g. ../iterations/iteration_NNNN/readme.md).
      # Plain-text mentions are NOT a back-link; links to another iteration's
      # readme are NOT a back-link either.
      # Capture the match list instead of grep -q: an early-exit -q would SIGPIPE
      # the upstream grep under pipefail on large notes (false "no back-link").
      # || true absorbs the head-1 SIGPIPE case; no -q means grep never exits early.
      link="$(grep -o ']([^)]*)' "$f" | sed 's/^](//; s/)$//; s/#.*$//' \
               | grep -E "(^|/)$ref/readme\.md$" | head -1 || true)"
      [ -z "$link" ] && warn "notes/$(basename "$f"): 来源 $ref but no back-link to $ref/readme.md in 详情 (v0.2.12 discipline)" ;;
  esac
done

# ---- 9. version metadata: version marker ↔ architecture snapshot must agree ----
echo "[9] version metadata"
ver="$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$AS_ROOT/.agentspace-version.json" 2>/dev/null | head -1 | sed 's/.*: *"//; s/"$//' || true)"
arch="$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$AS_ROOT/.agentspace-architecture.json" 2>/dev/null | head -1 | sed 's/.*: *"//; s/"$//' || true)"
if [ -n "$ver" ] && [ -n "$arch" ] && [ "$ver" != "$arch" ]; then
  warn "version marker v$ver vs architecture snapshot v$arch (mismatch — run /agentspace-update, or fix once with user confirmation)"
fi

echo
echo "== Done: $issues issues, $fixed auto-repaired =="
if [ "$issues" -eq 0 ]; then
  echo "Workspace consistent ✓"
else
  echo "Tip: do NOT hand-edit tables on your own. Discuss a repair plan with the user first;"
  echo "     a one-time manual fix explicitly confirmed by the user is the only allowed exception."
  exit 1
fi
