#!/usr/bin/env bash
# Consistency check: entry tables / full indexes ↔ filesystem.
# Issues reported; tier-1 repairs (latest symlink, orphan table rows, missing
# notes.md rows, dangling handoff index rows) applied with --fix only.
# Semantic issues are always reported, never auto-fixed.
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
  # row travels via ENVIRON, not -v — awk -v would unescape the \| cells
  # produced by as_cell, corrupting the inserted notes row (audit R8)
  row="$row" awk '
    /^\|[ :|-]+\|$/ && !inserted { print; print ENVIRON["row"]; inserted=1; next }
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
# Report-only without --fix: doctor is invoked read-only from status.sh, and an
# unguarded write would make the "read-only workbench" mutate the workspace
# (audit F1). Repairs happen under --fix only, like every other tier-1 item.
echo "[1] iterations/latest"
L="$AS_ROOT/iterations/latest"
if [ -L "$L" ] && [ ! -e "$L" ]; then
  if [ "$FIX" -eq 1 ]; then
    rm -f "$L"
    ok "latest symlink broken, removed"
  else
    warn "latest symlink broken (run --fix to repair)"
  fi
fi
if [ ! -L "$L" ]; then
  last="$(ls -d "$AS_ROOT"/iterations/iteration_[0-9]* 2>/dev/null | sort | tail -1 || true)"
  if [ -n "$last" ]; then
    if [ "$FIX" -eq 1 ]; then
      ln -sfn "$(basename "$last")" "$L"
      ok "latest -> $(basename "$last")"
    else
      warn "iterations/latest missing (run --fix to repair)"
    fi
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
' "$AS_ROOT/plan.md" 2>/dev/null || true)"
for id in $todo_ids; do
  # Normalize before matching files: a hand-written `| 1 |` row must resolve
  # to 0001-*.md — deleting on the raw id would remove a live row (audit R4)
  if [[ "$id" =~ ^[0-9]+$ ]]; then
    id="$(as_norm_id "$id")"
  else
    warn "plan.md Todo row $id malformed (non-numeric id) — not removed"
    continue
  fi
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
' "$AS_ROOT/iterations.md" 2>/dev/null || true)"
for id in $prog_ids; do
  # Normalize before matching dirs — same live-row protection as [2]
  if [[ "$id" =~ ^[0-9]+$ ]]; then
    id="$(as_norm_id "$id")"
  else
    warn "iterations.md in-progress row $id malformed (non-numeric id) — not removed"
    continue
  fi
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

# ---- 10. handoff: index rows ↔ handoff files (residue) ----
# The index row and the handoff file are produced and consumed as a pair; a
# crash between the two leaves a dangling row or an orphan file, both
# gitignored (invisible to git, silent drift). --fix only removes dead index
# rows (the file is already gone — no data loss, same pattern as [2]/[3]);
# orphan files may still hold unread context, so they are reported with their
# path and left for the user to read and remove — doctor never deletes handoff
# files and never consumes (reading the snapshot first is the module contract).
echo "[10] handoff consistency"
HO_DIR="$AS_ROOT/handoff"
HO_INDEX="$HO_DIR/index.md"
rows=""
names=""
locs=""
indexed=""
if [ -d "$HO_DIR" ]; then
  if [ -f "$HO_INDEX" ]; then
    rows="$(awk -v sec="## $SEC_HANDOFF" '
      $0 ~ ("^" sec "[[:space:]]*$") { in_sec=1; next }
      /^## / { in_sec=0 }
      in_sec && /^\| / && !/^\| *name *\|/ && !/^\|[ :|-]+\|$/ { print }
    ' "$HO_INDEX" 2>/dev/null || true)"
  fi
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    # Fields located by shape (first name cell / last date cell), not by a bare
    # | split — descriptions may hold escaped \| (as_cell, v0.4.0 ENVIRON fix)
    tmp="${line#| }"; name="${tmp%% | *}"; rest="${tmp#* | }"
    date="${rest##* | }"; date="${date% |}"
    nodate="${rest% | *}"; loc="${nodate##* | }"; desc="${nodate%% | *}"
    if [ -z "$name" ] || [ -z "$loc" ] || [[ "$name" == *'|'* ]] || [[ "$loc" != handoff_*.md ]] || [[ "$loc" == */* ]] || [[ "$date" != [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] ]]; then
      warn "handoff index row malformed (expected \"| name | description | location | time |\"): $line"
      continue
    fi
    names+="$name"$'\n'; locs+="$loc"$'\n'
    indexed+="$loc"$'\t'"$name"$'\t'"$desc"$'\t'"$date"$'\n'
    if [ ! -e "$HO_DIR/$loc" ]; then
      if [ "$FIX" -eq 1 ]; then
        before="$(wc -l < "$HO_INDEX")"
        tmpf="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
        # Match on name AND the row's location cell: with duplicate names a
        # name-only first match could delete the LIVE row instead of the
        # dangling one. index() is literal (no regex metachars in loc).
        awk -F'|' -v sec="## $SEC_HANDOFF" -v name="$name" -v loc="$loc" '
          $0 ~ ("^" sec "[[:space:]]*$") { in_sec=1; print; next }
          /^## / { in_sec=0 }
          in_sec && /^\|/ && !done { c=$2; gsub(/^ +| +$/, "", c); if (c == name && index($0, loc)) { done=1; next } }
          { print }
        ' "$HO_INDEX" > "$tmpf" && as_atomic_write "$HO_INDEX" "$tmpf"
        if [ "$(wc -l < "$HO_INDEX")" -lt "$before" ]; then
          ok "removed dangling handoff row $name (file $loc missing)"
        else
          # v0.3.3 discipline: a failed repair must not report green
          warn "handoff row $name NOT removed (section \"$SEC_HANDOFF\" missing or drifted)"
        fi
      else
        warn "handoff index row $name → missing file $loc (dangling row — a crashed consume? --fix removes the row)"
      fi
    fi
  done <<< "$rows"
  # duplicate rows (hand-edit artifact; consume removes only the first match)
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    warn "duplicate handoff index rows: \"$d\" ($(printf '%s' "$names" | grep -Fxc -- "$d" || true)×) — keep one row, confirm with the user"
  done < <(printf '%s' "$names" | sort | uniq -d)
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    warn "duplicate handoff index locations: \"$d\" ($(printf '%s' "$locs" | grep -Fxc -- "$d" || true)×) — keep one row, confirm with the user"
  done < <(printf '%s' "$locs" | sort | uniq -d)
  # files without rows (orphans) — reported, never auto-deleted
  for f in "$HO_DIR"/handoff_*.md; do
    [ -e "$f" ] || continue
    loc="$(basename "$f")"
    if ! printf '%s\n' "$locs" | grep -Fx "$loc" >/dev/null; then
      warn "handoff file not indexed (orphan): $f — read it, then remove manually (doctor never deletes handoff files)"
      orphans+="$loc"$'\n'
    fi
  done
fi

# ---- 11. handoff staleness: unconsumed handoffs older than STALE_DAYS ----
# A handoff waits for the next session to consume it; one lingering past the
# threshold is likely abandoned, and being gitignored it would otherwise pile
# up invisibly. Report-only: consuming requires reading the snapshot first —
# doctor analyzes what the handoff is for and never deletes or consumes it.
echo "[11] handoff staleness"
if [ -d "$HO_DIR" ]; then
  # line-wise iteration — find output must not be word-split (a space anywhere
  # in the workspace path would fragment it) or glob-expanded.
  # find -mtime +N = strictly more than N whole days; +$((STALE_DAYS-1)) ⇒
  # STALE_DAYS 天以上(默认 7), so the check and the messages agree exactly.
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    loc="$(basename "$f")"
    # orphans were already reported by [10] — do not double-report
    if [ -n "${orphans:-}" ] && printf '%s\n' "$orphans" | grep -Fx "$loc" >/dev/null; then
      continue
    fi
    # --keep'd snapshots are intentionally preserved (marker written by
    # handoff.sh consume --keep) — not abandoned, so not stale
    if grep -Fq '> 状态: kept(--keep,' "$f" 2>/dev/null; then
      continue
    fi
    info="$(printf '%s\n' "$indexed" | grep -F "$loc"$'\t' | head -1 || true)"
    name="?"; desc=""; date="?"
    if [ -n "$info" ]; then
      # tab-split preserving empty cells — IFS=$'\t' read would collapse an
      # empty description and shift the date into the description slot
      rest="${info#*$'\t'}"
      name="${rest%%$'\t'*}"; rest="${rest#*$'\t'}"
      desc="${rest%%$'\t'*}"; rest="${rest#*$'\t'}"
      date="$rest"
    fi
    # first non-empty, non-comment line under ## 下一步 (comment blocks may be
    # multi-line — same state machine as status.sh)
    todo="$(awk '/^## 下一步[[:space:]]*$/ {in_todo=1; next}
                 in_todo && /^## / {exit}
                 in_todo && /^<!--/ { if ($0 !~ /-->/) inc=1; next }
                 inc && /-->/ { inc=0; next }
                 inc { next }
                 in_todo && /^[[:space:]]*$/ { next }
                 in_todo { print; exit }' "$f" 2>/dev/null || true)"
    [ -n "$todo" ] || todo="—"
    warn "stale handoff $name ($date, $loc): $desc — 下一步: $todo (consume it, or decide to keep/delete — doctor only reports)"
  done <<< "$(find "$HO_DIR" -maxdepth 1 -type f -name 'handoff_*.md' -mtime "+$((STALE_DAYS - 1))" 2>/dev/null || true)"
fi

# ---- 12. register: module rows ↔ module files ----
# register-module.sh contract: a registered module owns NAME.md + NAME/ in the
# workspace root. Report-only — re-creating a module requires user
# confirmation (register discipline), so doctor never auto-repairs here.
echo "[12] register consistency"
if [ -f "$AS_ROOT/register.md" ]; then
  mods="$(awk -F'|' -v sec="## $SEC_REGISTERED" '
    $0 ~ ("^" sec "[[:space:]]*$") { in_sec=1; next }
    /^## / { in_sec=0 }
    in_sec && /^\| / && !/^\| *模块 *\|/ && !/^\|[ :|-]+\|$/ {
      c=$2; gsub(/^ +| +$/, "", c); print c
    }
  ' "$AS_ROOT/register.md" 2>/dev/null || true)"
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    if [[ ! "$m" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
      warn "register.md malformed module name: \"$m\" (expected lowercase alphanumeric/hyphen)"
      continue
    fi
    [ -f "$AS_ROOT/$m.md" ] || warn "register.md: module $m missing $m.md (register-module.sh contract: NAME.md + NAME/)"
    [ -d "$AS_ROOT/$m/" ] || warn "register.md: module $m missing $m/ directory (register-module.sh contract: NAME.md + NAME/)"
  done <<< "$mods"
fi

# ---- 13. standalone external-dependency discipline ----
# Active only in standalone mode (## agentspace mode block in AGENTS.md);
# hybrid mode: the whole mode concept is absent — check skipped.
# External refs (as_external_refs: symlinks resolving outside the workspace +
# absolute path tokens in registration source/link columns) are matched
# against the whitelist: hit → exempt; miss → violation, graded by size —
# large (≥ WHITELIST_LARGE_BYTES) refs have an auto-exempt path (--fix adds
# them; copying them is unrealistic), small refs --fix never touches
# (integration or explicit user exemption required). Whitelist hygiene:
# dead entries are reported, never deleted; small-file entries are flagged
# as user-confirmation-only.
echo "[13] standalone external refs"
if [ "$(as_mode)" = "standalone" ]; then
  while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    if as_whitelisted "$ref"; then
      printf '  [ok] whitelisted: %s\n' "$ref"
      continue
    fi
    if [ -e "$ref" ]; then
      sz="$(as_ref_size_bytes "$ref")"
      if [ "${sz:-0}" -ge "$WHITELIST_LARGE_BYTES" ]; then
        warn "外部大文件引用未白名单: $ref (≥1G — 自动豁免路径: doctor --fix 或切换 standalone 时自动)"
        if [ "$FIX" -eq 1 ]; then
          add_whitelist_entry "$ref" >/dev/null
          ok "大文件引用已自动白名单: $ref"
        fi
      else
        warn "外部引用未白名单: $ref (<1G — 必须集成到 AGENTSPACE/ 或用户显式豁免; --fix 不自动处理)"
      fi
    else
      warn "外部引用目标不存在: $ref (引用失效)"
    fi
  done <<< "$(as_external_refs || true)"
  if [ -f "$AS_ROOT/.agentspace-whitelist" ]; then
    while IFS= read -r entry; do
      [ -n "$entry" ] || continue
      case "$entry" in \#*) continue ;; esac
      entry="$(as_whitelist_norm "$entry")"
      target="$entry"
      case "$entry" in
        /*) ;;
        *) target="$(cd -P "$AS_ROOT/.." 2>/dev/null && pwd -P || echo "$AS_ROOT/..")/$entry" ;;
      esac
      if [ ! -e "$target" ]; then
        warn "白名单条目失效(目标不存在): $entry (换机器后外部盘未挂载? 不自动删除)"
      elif [ -d "$target" ] || [ -f "$target" ]; then
        sz="$(as_ref_size_bytes "$target")"
        if [ "${sz:-0}" -lt "$WHITELIST_LARGE_BYTES" ]; then
          # 提示不计数: 用户显式豁免的小文件是合法状态, 不应让 doctor 恒红 —
          # 该条目的"用户显式确认"属性由流程纪律保证, doctor 只做提醒
          printf '  [note] 白名单小文件条目(需用户显式确认): %s\n' "$entry"
        fi
      fi
    done < "$AS_ROOT/.agentspace-whitelist"
  fi
else
  echo "  (hybrid — 检查不启用)"
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
