#!/usr/bin/env bash
# AGENTSPACE shared function library. Sourced by sibling scripts, not run directly.
# Convention: AS_ROOT = AGENTSPACE workspace root (parent of this scripts/ directory).

AS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Resolve symlinks to physical path (cd -P + pwd -P)
AS_ROOT="$(cd -P "$AS_LIB_DIR/.." && pwd -P)"

# ---- Runtime environment gate (fail fast, one clear message) ----
# The scripts need bash >= 3.1 (scalar +=) and the core POSIX toolchain; the
# macOS system bash is 3.2, Linux ships 4.x+. A cryptic mid-script error on an
# old bash / missing tool is worse than this upfront gate.
if [ "${BASH_VERSINFO[0]:-0}" -lt 3 ] || { [ "${BASH_VERSINFO[0]:-0}" -eq 3 ] && [ "${BASH_VERSINFO[1]:-0}" -lt 1 ]; }; then
  printf 'error: AGENTSPACE scripts need bash >= 3.1 (found %s) — upgrade bash and re-run.\n' "${BASH_VERSION:-unknown}" >&2
  exit 1
fi
for _as_cmd in grep awk sed find date tr mkdir mktemp git head du; do
  if ! command -v "$_as_cmd" >/dev/null 2>&1; then
    printf 'error: required command not found: %s (AGENTSPACE scripts need the core POSIX toolchain)\n' "$_as_cmd" >&2
    exit 1
  fi
done
unset _as_cmd

# Deterministic byte behavior for mixed CJK/ASCII content: under the ambient
# locale, regex character classes ([a-z]) and sort collation vary by system.
# LC_ALL=C fixes byte-exact semantics; CJK bytes pass through untouched, so
# display and content are unaffected.
export LC_ALL=C

# ---- Table section headings / status marker constants ----
# These MUST match the actual markdown headings in deployed workspace files.
readonly SEC_TODO="Todo"
readonly SEC_DONE="Done (最近 10 条)"
readonly SEC_PROGRESS="进行中"
readonly SEC_RECENT="最近完成 (10 条)"
readonly SEC_RELATED="相关迭代"
readonly SEC_REGISTERED="已注册模块"
readonly SEC_HANDOFF="Handoffs"
readonly STATUS_TODO="> 状态: todo"
readonly STATUS_PROGRESS="> 状态: 进行中"
# Staleness threshold for handoff [11] / status summary (days unconsumed
# before a handoff is flagged 过时). Single source — doctor.sh and status.sh
# both use it (find -mtime +$((STALE_DAYS-1)) = strictly more than STALE_DAYS-1
# whole days = 7 天以上).
readonly STALE_DAYS="7"
# Large-file threshold for the standalone whitelist (bytes): external refs at
# or above this size are auto-whitelisted (copying them is unrealistic — e.g.
# datasets); smaller external refs must be integrated or explicitly exempted
# by the user (mode.sh / doctor.sh [13]).
readonly WHITELIST_LARGE_BYTES="1073741824"
# ---- Placeholder constants (must match template comments exactly; doctor [5] checks drift) ----
# Gate: close-iteration refuses while present. Template: iteration-readme.md "结果"
readonly RESULT_PH_ITER="<!-- 指标 / 结论; 关闭 iteration 前必填 -->"
# Gate: complete-plan refuses while present. Template: plan.md "结果" (first line of 2-line comment)
readonly RESULT_PH_PLAN="<!-- 完成时填写: 一句话结论"
# Warning: doctor flags in-progress readmes while present. Template: iteration-readme.md "当前状态 · 下一步"
readonly RESUME_PH_ITER="<!-- 会话续接块:"

as_die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# Atomic replace: mv is same-filesystem ($AS_TMPDIR lives in $AS_ROOT) and
# atomic, so a crash cannot truncate the target mid-write. mktemp creates
# 0600 — copy the target's mode onto the tmp first so permissions are kept.
as_atomic_write() {
  local file="$1" tmp="$2"
  if [ -e "$file" ]; then
    chmod "$(stat -f '%Lp' "$file" 2>/dev/null || stat -c '%a' "$file" 2>/dev/null || printf '644')" "$tmp" 2>/dev/null || true
  fi
  mv -f "$tmp" "$file"
}

# Host repo HEAD short sha (project root = AS_ROOT/..). Empty if host is not a git repo.
as_host_head() {
  if git -C "$AS_ROOT/.." rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$AS_ROOT/.." rev-parse --short HEAD 2>/dev/null || true
  fi
}

as_today() { date +%F; }

# ---- Workspace mode (hybrid / standalone) ----
# Single source of truth: the `## agentspace mode` block in AGENTS.md (value
# on the line after the heading; `rules` line follows in standalone mode).
# Session agents see the block when loading AGENTS.md — zero-cost mode check;
# scripts grep it; mode.sh rewrites it (scripts-only rule). A missing block
# (legacy workspace) defaults to hybrid — never an error.
as_mode() {
  local m
  m="$(awk '/^## agentspace mode[[:space:]]*$/{f=1; next} f && NF { print; exit }' "$AS_ROOT/AGENTS.md" 2>/dev/null | head -1 || true)"
  case "$m" in
    standalone) echo standalone ;;
    *) echo hybrid ;;
  esac
}

# ---- External-dependency whitelist (.agentspace-whitelist) ----
# Entries: relative-to-project-root paths (no leading /) or absolute paths
# (leading /); files or directories — a directory entry covers everything
# under it (`path == entry` or `path` starts with `entry/`). `#` comments.
# Entries are normalized on read/write: `./` prefix stripped, single trailing
# `/` stripped (shell-completion spelling) — a bare `/` is kept.
as_whitelist_norm() {
  local e="$1"
  case "$e" in
    ./*) e="${e#./}" ;;
  esac
  case "$e" in
    /) ;;
    */) e="${e%/}" ;;
  esac
  printf '%s' "$e"
}

# as_whitelisted <abs-path>: canonicalize the path (resolves symlinked
# prefixes like /tmp → /private/tmp; dangling refs keep their raw spelling so
# doctor can report "目标不存在"), normalize project-internal paths to
# project-root-relative, then match entries (equal or dir-prefix).
as_whitelisted() {
  local p="$1" base entry
  base="$(cd -P "$AS_ROOT/.." 2>/dev/null && pwd -P || echo "$AS_ROOT/..")"
  if [ -e "$p" ]; then
    local canon
    canon="$(cd -P "$(dirname "$p")" 2>/dev/null && pwd -P)/$(basename "$p")" || canon="$p"
    p="$canon"
  fi
  case "$p" in
    "$base"/*) p="${p#"$base"/}" ;;
  esac
  [ -f "$AS_ROOT/.agentspace-whitelist" ] || return 1
  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    case "$entry" in \#*) continue ;; esac
    entry="$(as_whitelist_norm "$entry")"
    [ -n "$entry" ] || continue
    if [ "$p" = "$entry" ] || [ "${p#"$entry"/}" != "$p" ]; then
      return 0
    fi
  done < "$AS_ROOT/.agentspace-whitelist"
  return 1
}

# Whitelist entry add/remove (atomic; ENVIRON for the entry — no -v unescape
# hazard). Project-internal paths normalize to project-root-relative.
add_whitelist_entry() {
  local entry="$1" tmp base covered
  [ -n "$entry" ] || return 1
  # 输入规范化: /tmp 拼写 → /private/tmp, 与 as_whitelisted/as_external_refs 一致 —
  # 否则条目以未规范化拼写入库, 匹配时永不命中(真实三方验证发现)
  if [ -e "$entry" ]; then
    local canon
    canon="$(cd -P "$(dirname "$entry")" 2>/dev/null && pwd -P)/$(basename "$entry")" || canon="$entry"
    entry="$canon"
  fi
  base="$(cd -P "$AS_ROOT/.." 2>/dev/null && pwd -P || echo "$AS_ROOT/..")"
  case "$entry" in
    "$base"/*) entry="${entry#"$base"/}" ;;
  esac
  entry="$(as_whitelist_norm "$entry")"
  # 目录条目已覆盖 → 明说, 不加(精确行查重保持静默幂等)
  covered="$(as_whitelist_covering "$entry")"
  if [ -n "$covered" ] && [ "$covered" != "$entry" ]; then
    printf '  already covered by whitelist entry: %s\n' "$covered"
    return 0
  fi
  if grep -Fqx "$entry" "$AS_ROOT/.agentspace-whitelist" 2>/dev/null; then
    return 0
  fi
  [ -n "${AS_TMPDIR:-}" ] || as_die "add_whitelist_entry: as_lock required"
  # Guard against a silent entry drop: a failed cat on an unreadable whitelist
  # would leave a tmp with only the new entry and as_atomic_write would
  # replace the whitelist, losing every existing entry.
  if [ -f "$AS_ROOT/.agentspace-whitelist" ] && [ ! -r "$AS_ROOT/.agentspace-whitelist" ]; then
    as_die "whitelist exists but is unreadable: $AS_ROOT/.agentspace-whitelist (fix permissions)"
  fi
  tmp="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
  chmod 644 "$tmp"
  { cat "$AS_ROOT/.agentspace-whitelist" 2>/dev/null || true; printf '%s\n' "$entry"; } > "$tmp"
  as_atomic_write "$AS_ROOT/.agentspace-whitelist" "$tmp"
  printf '  whitelisted: %s\n' "$entry"
}

remove_whitelist_entry() {
  local entry="$1" tmp base before after
  [ -n "$entry" ] || return 1
  # 输入规范化(同上) — deny 拼写与 allow 不一致时也能命中
  if [ -e "$entry" ]; then
    local canon
    canon="$(cd -P "$(dirname "$entry")" 2>/dev/null && pwd -P)/$(basename "$entry")" || canon="$entry"
    entry="$canon"
  fi
  base="$(cd -P "$AS_ROOT/.." 2>/dev/null && pwd -P || echo "$AS_ROOT/..")"
  case "$entry" in
    "$base"/*) entry="${entry#"$base"/}" ;;
  esac
  entry="$(as_whitelist_norm "$entry")"
  if [ ! -f "$AS_ROOT/.agentspace-whitelist" ]; then
    echo "  no whitelist file — nothing to remove" >&2
    return 1
  fi
  [ -n "${AS_TMPDIR:-}" ] || as_die "remove_whitelist_entry: as_lock required"
  before="$(grep -vcE '^(#.*|[[:space:]]*)$' "$AS_ROOT/.agentspace-whitelist" || true)"
  tmp="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
  entry="$entry" awk '!/^#/ && $0 == ENVIRON["entry"] { next } { print }' "$AS_ROOT/.agentspace-whitelist" > "$tmp"
  after="$(grep -vcE '^(#.*|[[:space:]]*)$' "$tmp" || true)"
  if [ "$before" = "$after" ]; then
    rm -f "$tmp"
    printf '  not in whitelist: %s\n' "$entry"
    return 0
  fi
  as_atomic_write "$AS_ROOT/.agentspace-whitelist" "$tmp"
  printf '  removed: %s\n' "$entry"
}

# The whitelist entry covering <path> (equal or dir-prefix), if any.
as_whitelist_covering() {
  local p="$1" entry base
  base="$(cd -P "$AS_ROOT/.." 2>/dev/null && pwd -P || echo "$AS_ROOT/..")"
  case "$p" in
    "$base"/*) p="${p#"$base"/}" ;;
  esac
  [ -f "$AS_ROOT/.agentspace-whitelist" ] || return 0
  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    case "$entry" in \#*) continue ;; esac
    entry="$(as_whitelist_norm "$entry")"
    [ -n "$entry" ] || continue
    if [ "$p" = "$entry" ] || [ "${p#"$entry"/}" != "$p" ]; then
      printf '%s\n' "$entry"
      return 0
    fi
  done < "$AS_ROOT/.agentspace-whitelist"
  return 0
}

# Size in bytes: dirs → contents size (du -sk), files → stat. The standalone
# large-file grading (≥ WHITELIST_LARGE_BYTES) must see directory contents —
# a dataset dir with a 1G file inside is copy-unrealistic.
as_ref_size_bytes() {
  local p="$1"
  if [ -d "$p" ]; then
    du -sk "$p" 2>/dev/null | awk '{ print $1 * 1024 }' || printf '0'
  else
    stat -f '%z' "$p" 2>/dev/null || stat -c '%s' "$p" 2>/dev/null || printf '0'
  fi
}

# External references (standalone scan, minor face): symlinks under the
# workspace resolving OUTSIDE AS_ROOT, plus absolute path tokens in the
# registration tables' designated columns (data.md 来源/链接, utils.md
# 用法/链接, register.md 入口). Outputs canonicalized absolute paths
# (symlinked prefixes like /tmp → /private/tmp resolved; dangling refs keep
# their raw spelling), internal paths dropped, deduped. The major face
# (whole-file path grep) lives in the /agentspace-doctor --major skill flow.
as_external_refs() {
  local esc base
  esc="$(printf '\037')"
  base="$(cd -P "$AS_ROOT/.." 2>/dev/null && pwd -P || echo "$AS_ROOT/..")"
  {
    # 1) symlinks — relative targets joined to the link's dir (cd -P resolves
    #    ..), then canonicalized by the shared post-filter
    find "$AS_ROOT" \( -path "$AS_ROOT/.git" -o -path "$AS_ROOT/.scripts.lock" -o -path "$AS_ROOT/.scripts-tmp.*" \) -prune -o -type l -print 2>/dev/null \
      | while IFS= read -r l; do
          t="$(readlink "$l" 2>/dev/null || true)"
          [ -n "$t" ] || continue
          case "$t" in
            /*) ;;
            *) t="$(cd -P "$(dirname "$l")/$(dirname "$t")" 2>/dev/null && pwd -P)/$(basename "$t")" || continue ;;
          esac
          printf '%s\n' "$t"
        done
    # 2) registration columns — token extraction, internal-path filter via
    #    ROOT (ENVIRON; canonicalized spelling), /tmp-style prefixes are
    #    canonicalized by the shared post-filter
    for f in data.md utils.md register.md; do
      [ -f "$AS_ROOT/$f" ] || continue
      sed "s/\\\\|/$esc/g" "$AS_ROOT/$f" 2>/dev/null | ROOT="$AS_ROOT" awk -v esc="$esc" -v fname="$f" '
        function scan(s) {
          gsub(/[a-zA-Z][a-zA-Z0-9+.-]*:\/\/[^ )]+/, "", s)   # URL 方案整体摘除(下载自 https://… 不当作路径)
          while (match(s, /(^|[ \/([:space:]])(\/[^ )]+)/)) {
            t = substr(s, RSTART + 1, RLENGTH - 1)
            gsub(/[)\]>,;:]$/, "", t)
            if (t != "" && t ~ /^\//) print t
            s = substr(s, RSTART + RLENGTH)
          }
        }
        /^\| / {
          gsub(esc, "\\|", $0)
          n = split($0, a, "|")
          # split 含前导空: a[1]=""; data.md 数据列: 名称=a[2] 说明=a[3] 来源=a[4] 链接=a[5]
          if (fname == "data.md") scan(a[4] " " a[5])
          else if (fname == "utils.md") scan(a[5] " " a[6])   # 用法=a[5] 链接=a[6]
          else if (fname == "register.md") scan(a[4])         # 入口=a[4]
        }
      '
    done
  } 2>/dev/null | while IFS= read -r p; do
    # shared post-filter: canonicalize existing paths (resolves symlinked
    # prefixes), drop internal ones, keep dangling refs raw (doctor reports
    # them as 目标不存在)
    if [ -e "$p" ]; then
      local canon
      canon="$(cd -P "$(dirname "$p")" 2>/dev/null && pwd -P)/$(basename "$p")" || canon="$p"
      p="$canon"
    fi
    case "$p" in
      "$AS_ROOT"/* | "$AS_ROOT") continue ;;
    esac
    printf '%s\n' "$p"
  done | sort -u || true
}

# ---- Key code-repo registry (.agentspace-repos) + commit discipline ----
# One repo per line: repos inside the project root are stored root-relative,
# external repos absolute; spelling is physical (cd -P) and git-toplevel
# normalized at write time. `#` comments. Written ONLY by scripts/repos.sh;
# consumed by commit-check.sh (gate), doctor.sh ([14]/[15]) and status.sh.
# Message AND content ban — canonical bookkeeping-id forms only (the workspace
# idiom, AGENTS.md 相互引用 rule): canonical ids are as_norm_id %04d zero-padded, so
# the leading 0 anchors the match and spares natural text like
# "test plan: 3 phases" and year mentions like "roadmap plan: 2026". Ids past
# 0999 (no leading zero) and non-canonical variants (plan_0013, 迭代 3) are the
# agent semantic layer's job, not the script's. Since v0.6.4 the SAME pair
# bans ids on ADDED diff lines (code comments, string literals) — an id that
# may not be said in the message may not be smuggled in through content;
# both sides share as_diff_added_hits so they cannot drift. Single source for
# commit-check.sh and doctor [15] — the pre-commit gate and the ex-post audit
# must never drift apart. [15] 为报告型子集: 只查硬阻断规则, message 与 content
# 各报首个命中行; WARN 级(数据扩展名/输出目录)属 agent 语义层, 不在事后扫描内。
readonly COMMIT_BAN_PLAN_RE="plan:[[:space:]]*0[0-9]{3,}"
readonly COMMIT_BAN_ITER_RE="iteration_0[0-9]{3,}"
# Staged-file hard blocks: workspace paths, experiment-output signatures
# (top-level dirs / tfevents basename), and any single blob at/above
# COMMIT_BLOCK_BYTES. Warn level: data extensions at/above COMMIT_WARN_BYTES
# and top-level output dirs — judgment deferred to the agent layer.
readonly COMMIT_BLOCK_BYTES="52428800"    # 50MB (GitHub's own warning line)
readonly COMMIT_WARN_BYTES="102400"       # 100KB
readonly COMMIT_SIG_DIRS="wandb mlruns lightning_logs"
readonly COMMIT_OUT_DIRS="runs outputs checkpoints logs results exps experiments"
readonly COMMIT_DATA_EXTS="npy npz pt pth ckpt h5 hdf5 parquet safetensors onnx log"
readonly COMMIT_AUDIT_N="20"              # doctor [15]: commits scanned per repo
readonly COMMIT_HOT_DAYS="7"              # doctor [14]: recently-active window
readonly COMMIT_SIZE_CHECK_MAX="2000"     # doctor [15]: per-commit path cap — above it the per-file size check is skipped (cost bound)
readonly COMMIT_EXCERPT_CAP="80"          # content hit report: excerpt chars kept per line
readonly COMMIT_FILE_HITS_CAP="5"         # gate: content hits listed per file, then one "+N more" tail
readonly COMMIT_AUDIT_LINE_MAX="100000"   # doctor [15]: added-lines budget per commit — content scan truncates past it (cost bound)
readonly STATUS_REPO_COMMITS="3"          # status 代码提交: commits shown per repo
# Blank-title check — the one deterministic commit-text quality rule: a title
# that says nothing (empty or whitespace-only first line) is never legitimate.
# Everything else about commit-text quality (convention conformance, relevance
# to the diff) is the agent semantic layer's judgment (agentspace-code-clean
# skill rubric). Single source for commit-check.sh (block) and doctor [15] (warn).
as_msg_title_blank() {
  local t
  t="$(printf '%s' "$1" | head -1 2>/dev/null || true)"
  [ -z "$t" ] || [ -z "${t//[[:space:]]/}" ]
}

# Unified-diff added-line matcher — the single content-side detector shared by
# the pre-commit gate (commit-check.sh: staged diff) and the ex-post audit
# (doctor.sh [15]: committed patches). Reads a `git diff`/`git show` `-U0`
# stream on stdin; for every ADDED line matching the ban regexes it emits
#   <path> TAB <new-file line no> TAB <excerpt, AS_EXCERPT_CAP chars>
# plus one `<path> TAB -more TAB +N …` tail per file past AS_FILE_HITS_CAP
# hits, and a `TAB -budget TAB …` line when the AS_LINE_MAX added-line budget
# (doctor cost bound) truncates the scan. Knobs arrive via ENVIRON (never
# awk -v — pattern discipline #1); matching lowercases both sides (BSD awk has
# no IGNORECASE). Deletions, context, binary files and pure renames emit
# nothing by construction: only '+' content lines are tested. One stream, one
# awk — no per-file forks (the fork-per-path cost shape is why doctor caps
# per-file checks at COMMIT_SIZE_CHECK_MAX). Hunk counting (remaining new-side
# lines from the @@ header) disambiguates a real `+++ b/<path>` header from an
# ADDED line whose text starts with `++ ` — a spoofed header inside a hunk is
# scanned as content, never eaten as a file switch. The counting is exact only
# because all call sites use -U0 (no context lines); a future -U<n> call site
# must revisit it.
as_diff_added_hits() {
  (
    export AS_BAN_RE="${AS_BAN_RE:-$COMMIT_BAN_PLAN_RE|$COMMIT_BAN_ITER_RE}"
    export AS_EXCERPT_CAP="${AS_EXCERPT_CAP:-$COMMIT_EXCERPT_CAP}"
    export AS_FILE_HITS_CAP="${AS_FILE_HITS_CAP:-$COMMIT_FILE_HITS_CAP}"
    export AS_LINE_MAX="${AS_LINE_MAX:-0}"
    awk '
      function flush_more() {
        if (pending > 0) { printf "%s\t-more\t+%d more hit(s) suppressed\n", f, pending; pending = 0 }
      }
      function body(line) {
        if (rem_new > 0) rem_new--
        added++
        if (lmax > 0 && added > lmax) {
          if (!budget_note) { printf "%s\t-budget\tadded-line budget (%d) reached — scan truncated\n", f, lmax; budget_note = 1 }
          pending = 0; exit 0
        }
        if (tolower(line) ~ re) {
          fhits++
          if (fcap > 0 && fhits > fcap) { pending++; lineno++; return }
          printf "%s\t%d\t%s\n", f, lineno, substr(line, 1, ecap)
        }
        lineno++
      }
      BEGIN { re = tolower(ENVIRON["AS_BAN_RE"]); ecap = ENVIRON["AS_EXCERPT_CAP"] + 0
              fcap = ENVIRON["AS_FILE_HITS_CAP"] + 0; lmax = ENVIRON["AS_LINE_MAX"] + 0
              f = ""; fhits = 0; pending = 0; added = 0; budget_note = 0; rem_new = 0 }
      /^diff --git/  { rem_new = 0; next }
      /^index |^similarity|^dissimilarity|^rename |^copy |^old mode|^new mode|^Binary files|^\\/ { next }
      /^@@/          { if (match($0, /\+[0-9]+(,[0-9]+)? @@/)) {
                         n = substr($0, RSTART + 1, RLENGTH - 4); cnt = n
                         sub(/^[0-9]+,?/, "", cnt); sub(/,.*/, "", n)
                         lineno = n + 0; rem_new = (cnt == "" ? 1 : cnt + 0)
                       } else rem_new = 0
                       next }
      /^--- /        { next }
      /^\+\+\+ /     { if (rem_new == 0) { flush_more(); f = substr($0, 7); fhits = 0 } else body(substr($0, 2)); next }
      /^\+/          { body(substr($0, 2)); next }
      /^-/           { next }
                     { if (rem_new > 0) rem_new--; lineno++ }
      END            { flush_more() }
    ' 2>/dev/null
  )
}

# Canonical repo root for any path: git toplevel, physical spelling (cd -P
# resolves symlinked prefixes like /tmp → /private/tmp — the eacbeda lesson).
# Contract: a DANGLING path (no longer existing) resolves via dirname to the
# CONTAINING repo's toplevel — the exact previously-fixed trap. Callers must
# pre-guard with `[ -d ]` / `[ -e ]` before calling; only repos.sh --remove
# may pass a dangling path, and it never falls back to git-toplevel
# resolution (parent-physicalize instead).
as_repo_canon() {
  local p="$1" top
  [ -d "$p" ] || p="$(dirname "$p")"
  [ -d "$p" ] || return 1
  top="$(git -C "$p" rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$top" ] || return 1
  (cd -P "$top" 2>/dev/null && pwd -P) || return 1
}

# as_repos: registered rows, one absolute path per line (root-relative rows
# joined to the physical project root). Missing file → empty, never an error.
as_repos() {
  local base line
  [ -f "$AS_ROOT/.agentspace-repos" ] || return 0
  base="$(cd -P "$AS_ROOT/.." 2>/dev/null && pwd -P || echo "$AS_ROOT/..")"
  while IFS= read -r line; do
    case "$line" in ''|\#*) continue ;; esac
    case "$line" in
      /*) printf '%s\n' "$line" ;;
      *)  printf '%s/%s\n' "$base" "$line" ;;
    esac
  done < "$AS_ROOT/.agentspace-repos"
}

# as_repo_registered <path>: 0 when the canonical toplevel containing <path>
# is an exact registry row.
as_repo_registered() {
  local canon row
  canon="$(as_repo_canon "$1")" || return 1
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    [ "$row" = "$canon" ] && return 0
  done < <(as_repos)
  return 1
}

# Host repo root (workspace nested form): toplevel of AS_ROOT's parent when it
# is a git worktree other than AS_ROOT itself. Same rule status.sh and
# close-iteration (as_host_head) apply — single-sourced here.
as_host_root() {
  local top as_p hp
  top="$(git -C "$AS_ROOT/.." rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$top" ] || return 1
  as_p="$(cd -P "$AS_ROOT" && pwd -P)"
  hp="$(cd -P "$top" && pwd -P)"
  [ "$hp" != "$as_p" ] || return 1
  printf '%s\n' "$hp"
}

# as_repo_covered <abs-path>: the registered repo containing <path>, if any
# (equal or dir-prefix — the whitelist matching grammar). Registered repos are
# work OBJECTS, not external dependencies — doctor [13] exempts them from
# whitelist semantics via this.
as_repo_covered() {
  local p="$1" row
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    if [ "$p" = "$row" ] || [ "${p#"$row"/}" != "$p" ]; then
      printf '%s\n' "$row"
      return 0
    fi
  done < <(as_repos)
  return 1
}

# Table cell sanitization: | and newlines break markdown tables.
as_cell() { printf '%s' "$1" | sed 's/|/\\|/g' | tr '\n\t' '  ' | tr -d '\r'; }

# Normalize to 4-digit zero-padded id; input must be numeric.
as_norm_id() {
  [ $# -ge 1 ] || as_die "Missing id argument"
  [[ "$1" =~ ^[0-9]+$ ]] || as_die "Id must be numeric: $1"
  printf "%04d" "$((10#$1))"
}

# Numeric ids from script-managed table rows (entry view + full index).
# Union scan prevents reusing an id that only exists as an orphan table row.
as_row_ids() {
  grep -hoE '^\| *[0-9]+' "$@" 2>/dev/null | grep -oE '[0-9]+' || true
}

# Next plan index (scan plan/todo + plan/done + tables, max+1, monotonically increasing, never reused).
as_next_plan_id() {
  local max=0 f base n
  while IFS= read -r -d '' f; do
    base="$(basename "$f")"
    n="${base%%-*}"
    [[ "$n" =~ ^[0-9]+$ ]] || continue
    (( 10#$n > max )) && max=$((10#$n))
  done < <(find "$AS_ROOT/plan/todo" "$AS_ROOT/plan/done" -maxdepth 1 \
    -name '[0-9][0-9][0-9][0-9]-*.md' -print0 2>/dev/null)
  while IFS= read -r n; do
    [[ "$n" =~ ^[0-9]+$ ]] || continue
    (( 10#$n > max )) && max=$((10#$n))
  done < <(as_row_ids "$AS_ROOT/plan.md" "$AS_ROOT/plan/index.md")
  printf "%04d" $((max + 1))
}

# Next iteration index (scan iterations/iteration_NNNN + tables).
as_next_iteration_id() {
  local max=0 d base n
  while IFS= read -r -d '' d; do
    base="$(basename "$d")"
    n="${base#iteration_}"
    [[ "$n" =~ ^[0-9]+$ ]] || continue
    (( 10#$n > max )) && max=$((10#$n))
  done < <(find "$AS_ROOT/iterations" -maxdepth 1 -type d \
    -name 'iteration_[0-9][0-9][0-9][0-9]*' -print0 2>/dev/null)
  while IFS= read -r n; do
    [[ "$n" =~ ^[0-9]+$ ]] || continue
    (( 10#$n > max )) && max=$((10#$n))
  done < <(as_row_ids "$AS_ROOT/iterations.md" "$AS_ROOT/iterations/index.md")
  printf "%04d" $((max + 1))
}

# Insert a row after the separator line of a "## SECTION" table (becomes first data row).
# Usage: as_insert_row <file> <section> <row>
# NOTE: the row travels via ENVIRON, not -v — awk -v would unescape the `\|`
# cells produced by as_cell, silently corrupting escaped pipes.
as_insert_row() {
  local file="$1" tmp
  tmp="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
  ROW="$3" awk -v sec="## $2" '
    $0 == sec { in_sec=1; print; next }
    /^## / { in_sec=0 }
    in_sec && /^\|[ :|-]+\|$/ && !inserted { print; print ENVIRON["ROW"]; inserted=1; next }
    { print }
    END { if (!inserted) exit 3 }
  ' "$file" > "$tmp" || { rm -f "$tmp"; as_die "Table section not found: ## $2 ($file)"; }
  as_atomic_write "$file" "$tmp"
}

# Delete table rows whose first column equals id.
# Usage: as_remove_row <file> <id>
as_remove_row() {
  local file="$1" tmp
  [[ "$2" =~ ^[0-9]+$ ]] || as_die "as_remove_row: id must be numeric: $2"
  tmp="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
  awk -v id="$2" '
    BEGIN { pat="^ *\\| *" id " *\\|" }
    $0 ~ pat { next }
    { print }
  ' "$file" > "$tmp" && as_atomic_write "$file" "$tmp"
}

# Delete table rows whose first column equals id, bounded to one "## SECTION".
# Rows outside the section are never touched — the same id may legitimately
# appear in several sections (e.g. a plan id in Todo and in Done).
# Usage: as_remove_row_section <file> <section> <id>
as_remove_row_section() {
  local file="$1" tmp
  [[ "$3" =~ ^[0-9]+$ ]] || as_die "as_remove_row_section: id must be numeric: $3"
  tmp="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
  awk -v sec="## $2" -v id="$3" '
    BEGIN { pat="^ *\\| *" id " *\\|" }
    $0 ~ ("^" sec "[[:space:]]*$") { in_sec=1; print; next }
    /^## / { in_sec=0 }
    in_sec && $0 ~ pat { next }
    { print }
  ' "$file" > "$tmp" && as_atomic_write "$file" "$tmp"
}

# Keep only the first <keep> data rows in a section table.
# Note: data rows matched by "| digit" prefix — designed for numeric-ID tables.
# Usage: as_truncate_section <file> <section> <keep>
as_truncate_section() {
  local file="$1" tmp
  tmp="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
  awk -v sec="## $2" -v keep="$3" '
    $0 == sec { in_sec=1; n=0; print; next }
    /^## / { in_sec=0 }
    in_sec && /^\| [0-9]/ { n++; if (n > keep) next }
    { print }
  ' "$file" > "$tmp" && as_atomic_write "$file" "$tmp"
}

# Read the Nth |-delimited field of the row whose first column equals id.
# Escape-aware: \| cells are shielded before splitting and restored verbatim,
# so a title/desc containing an escaped pipe cannot shift the column positions.
# Usage: as_row_cell <file> <id> <colnum>
as_row_cell() {
  [[ "$2" =~ ^[0-9]+$ ]] || as_die "as_row_cell: id must be numeric: $2"
  local esc
  esc="$(printf '\037')"
  sed "s/\\\\|/$esc/g" "$1" | awk -F'|' -v id="$2" -v c="$3" -v esc="$esc" '
    BEGIN { pat="^\\| *" id " *\\|" }
    $0 ~ pat {
      gsub(/^ +| +$/, "", $c)
      gsub(esc, "\\|", $c)
      print $c
      exit
    }
  '
}

# Fill template placeholders {{ID}} {{TITLE}} {{DATE}} {{PLAN_ID}} {{NAME}} {{PURPOSE}}.
# Usage: PH_ID=.. PH_TITLE=.. as_fill_template <src> <dst>
# Intentionally direct (no tmp+mv): dst is always a NEW file — there is no
# existing content that a crash could truncate.
as_fill_template() {
  PH_ID="${PH_ID:-}" PH_TITLE="${PH_TITLE:-}" PH_DATE="${PH_DATE:-}" \
  PH_PLAN_ID="${PH_PLAN_ID:-}" PH_NAME="${PH_NAME:-}" PH_PURPOSE="${PH_PURPOSE:-}" \
  awk '
    function esc(s) { gsub(/\\/, "\\\\", s); gsub(/&/, "\\\\&", s); return s }
    {
      line=$0
      gsub(/{{ID}}/, esc(ENVIRON["PH_ID"]), line)
      gsub(/{{TITLE}}/, esc(ENVIRON["PH_TITLE"]), line)
      gsub(/{{DATE}}/, esc(ENVIRON["PH_DATE"]), line)
      gsub(/{{PLAN_ID}}/, esc(ENVIRON["PH_PLAN_ID"]), line)
      gsub(/{{NAME}}/, esc(ENVIRON["PH_NAME"]), line)
      gsub(/{{PURPOSE}}/, esc(ENVIRON["PH_PURPOSE"]), line)
      print line
    }
  ' "$1" > "$2"
}

# Replace a single line in-place (exact match old → new). Errors if not found.
# Usage: as_replace_line <file> <old> <new>
as_replace_line() {
  local file="$1" tmp
  tmp="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
  awk -v old="$2" -v new="$3" '
    $0 == old && !done { print new; done=1; next }
    { print }
    END { if (!done) exit 3 }
  ' "$file" > "$tmp" || { rm -f "$tmp"; as_die "Line not found: $2 ($file)"; }
  as_atomic_write "$file" "$tmp"
}

# Insert a line after the first occurrence of a heading.
# Usage: as_insert_after <file> <heading> <line>
as_insert_after() {
  local file="$1" tmp
  tmp="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
  awk -v heading="$2" -v line="$3" '
    $0 == heading && !done { print; print line; done=1; next }
    { print }
    END { if (!done) exit 3 }
  ' "$file" > "$tmp" || { rm -f "$tmp"; as_die "Line not found: $2 ($file)"; }
  as_atomic_write "$file" "$tmp"
}

# Insert a line after the first line that STARTS WITH prefix (dynamic content safe).
# Usage: as_insert_after_prefix <file> <prefix> <line>
as_insert_after_prefix() {
  local file="$1" tmp
  tmp="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
  awk -v pre="$2" -v line="$3" '
    index($0, pre) == 1 && !done { print; print line; done=1; next }
    { print }
    END { if (!done) exit 3 }
  ' "$file" > "$tmp" || { rm -f "$tmp"; as_die "Prefix line not found: $2 ($file)"; }
  as_atomic_write "$file" "$tmp"
}

# Append a line at the end of a section (before next ## or EOF).
# Usage: as_append_to_section <file> <section> <line>
as_append_to_section() {
  local file="$1" tmp
  tmp="$(mktemp "$AS_TMPDIR/tmp.XXXXXXXX")"
  awk -v sec="## $2" -v line="$3" '
    function flush_buf() {
      for (i=1; i<=b; i++) print buf[i]
      if (!inserted) { print line; inserted=1 }
      b=0
    }
    $0 == sec { in_sec=1; print; next }
    in_sec && /^## / { flush_buf(); in_sec=0; print; next }
    in_sec { buf[++b] = $0; next }
    { print }
    END {
      if (in_sec) flush_buf()
      if (!inserted) exit 3
    }
  ' "$file" > "$tmp" || { rm -f "$tmp"; as_die "Section not found: ## $2 ($file)"; }
  as_atomic_write "$file" "$tmp"
}

# ---- Concurrency lock + temp cleanup ----
# mkdir-based spinlock called by the write scripts.
# Also creates $AS_TMPDIR and installs an EXIT trap to clean both.
# Stale-lock recovery: a SIGKILLed writer leaves the lock behind and every
# subsequent writer would spin forever. A lock whose owner PID is dead is
# stale; a pid-less lock (crash mid-acquire) older than the grace window is
# treated as stale too. A pid file that is empty / unreadable / non-numeric
# (crash between mkdir and pid write, or a partial write) also falls back to
# the mtime grace path — never spin forever on it (fail-open). Liveness is
# checked with `ps -p PID -o pid=` (empty output = no such process), which
# answers across users where `kill -0` would fail with EPERM.
as_lock() {
  local owner stale pidtmp
  while ! mkdir "$AS_ROOT/.scripts.lock" 2>/dev/null; do
    owner="$(cat "$AS_ROOT/.scripts.lock/pid" 2>/dev/null || true)"
    stale=""
    if [ -n "$owner" ] && [[ "$owner" =~ ^[0-9]+$ ]]; then
      # parseable owner PID: stale iff the process no longer exists
      [ -n "$(ps -p "$owner" -o pid= 2>/dev/null)" ] || stale=1
    elif [ -n "$(find "$AS_ROOT/.scripts.lock" -mmin +5 2>/dev/null | head -1)" ]; then
      # pid file missing / empty / unreadable / non-numeric → mtime grace path
      stale=1
    fi
    if [ -n "$stale" ]; then
      # Atomic claim: mv IS the claim — exactly one waiter wins it; losers
      # find the source gone, re-loop, and see the new holder's live lock.
      # Never `rm -rf` the lock in place: a concurrent claimant could then
      # delete a freshly re-acquired live lock.
      if mv "$AS_ROOT/.scripts.lock" "$AS_ROOT/.scripts.lock.stale.$$" 2>/dev/null; then
        rm -rf "$AS_ROOT/.scripts.lock.stale.$$"
      fi
      continue
    fi
    sleep 0.2
  done
  # Write the owner PID atomically (tmp + mv): a crash mid-write can never
  # leave an empty or half-written pid file behind.
  pidtmp="$(mktemp "$AS_ROOT/.scripts.lock/pid.XXXXXXXX")"
  printf '%s' "$$" > "$pidtmp"
  mv -f "$pidtmp" "$AS_ROOT/.scripts.lock/pid"
  AS_TMPDIR="$(mktemp -d "$AS_ROOT/.scripts-tmp.XXXXXXXX")"
  trap '
    rm -rf "$AS_TMPDIR" 2>/dev/null || true
    # Ownership guard: only the recorded owner PID may tear the lock down,
    # so a process whose lock was legitimately taken over (stale-claim race)
    # can never delete the new holder live lock on EXIT.
    if [ "$(cat "$AS_ROOT/.scripts.lock/pid" 2>/dev/null || true)" = "$$" ]; then
      rm -rf "$AS_ROOT/.scripts.lock" 2>/dev/null || true
    fi
  ' EXIT
}
