#!/usr/bin/env bash
# Dev tool — repo root only, NOT part of the deployed plugin.
# Release gate. Read-only. Checks (exit 0 = release-ready):
#   [0] JSON validity            [5] asset <-> architecture file inventory
#   [1] version consistency      [6] section/column contract in assets
#                                (+[6b] reverse AGENTS.md sections)
#   [1b] archive marker          [7] bash -n on all .sh
#   [1c] Codex manifest          [8] bilingual sync (skills)
#   [1d] Kimi manifest           [9] SKILL size budget
#   [2] archive chain            [10] README release history
#                                [11] release rehearsal
#   [3] CHANGELOG quality        [12] realized-literal guard (self-hosting)
#   [4] constants contract (+reverse: lib.sh COMMIT_* → architecture)
#   [13] assets gitignore contracts
#   [14] skill/command frontmatter YAML (real PyYAML parse)
# Usage: bash verify-release.sh
set -euo pipefail
# Byte-exact, locale-independent semantics for the whole gate (grep/sed/python
# included) — mirrors lib.sh's own LC_ALL=C export.
export LC_ALL=C

ROOT="$(cd "$(dirname "$0")" && pwd)"
VERSIONS="$ROOT/skills/agentspace-update/versions"
ASSETS="$ROOT/skills/agentspace-init/assets/agentspace"
issues=0

echo "== AGENTSPACE verify-release: $ROOT =="

# --- [0] JSON validity ------------------------------------------------------
echo "[0] JSON validity"
JSON_FILES=( "$ROOT/.zcode-plugin/plugin.json" "$ROOT/.codex-plugin/plugin.json" "$ROOT/kimi.plugin.json" "$ROOT/marketplace.json" "$ASSETS/.agentspace-version.json" "$ASSETS/.agentspace-architecture.json" "$VERSIONS"/v*/architecture.json )
for f in "${JSON_FILES[@]}"; do
  if ! python3 -m json.tool "$f" >/dev/null 2>&1; then
    echo "  [issue] invalid JSON: ${f#$ROOT/}"
    issues=$((issues+1))
  fi
done

# --- [1-6] metadata & contract checks (single python pass) ------------------
echo "[1] version consistency"
echo "[1b] archive vs deployed marker"
echo "[1c] Codex manifest contract"
echo "[1d] Kimi manifest contract"
echo "[2] archive chain"
echo "[3] CHANGELOG quality"
echo "[4] constants contract"
echo "[5] asset <-> architecture inventory"
echo "[6] section/column contract in assets"
if ! META_OUT="$(python3 - "$ROOT" "$VERSIONS" "$ASSETS" <<'EOF'
import json, os, re, sys
root, versions, assets = sys.argv[1], sys.argv[2], sys.argv[3]
issues = []

def jget(path, fn):
    try:
        return fn(json.load(open(path)))
    except Exception:
        return None

def vkey(s):
    return tuple(int(x) for x in s.split("."))

dirs = [d for d in os.listdir(versions) if re.match(r"^v\d+\.\d+\.\d+$", d)]
dirs.sort(key=lambda d: vkey(d[1:]))

# [1] version consistency across markers
latest = dirs[-1][1:] if dirs else None
marks = {
    ".zcode-plugin/plugin.json": jget(f"{root}/.zcode-plugin/plugin.json", lambda d: d["version"]),
    ".codex-plugin/plugin.json": jget(f"{root}/.codex-plugin/plugin.json", lambda d: d["version"]),
    "kimi.plugin.json": jget(f"{root}/kimi.plugin.json", lambda d: d["version"]),
    "marketplace.json": jget(f"{root}/marketplace.json", lambda d: d["version"]),
    "marketplace.json plugins[0]": jget(f"{root}/marketplace.json", lambda d: d["plugins"][0]["version"]),
    "assets/.agentspace-version.json": jget(f"{assets}/.agentspace-version.json", lambda d: d["version"]),
    "assets/.agentspace-architecture.json": jget(f"{assets}/.agentspace-architecture.json", lambda d: d["version"]),
}
for k, v in marks.items():
    if v != latest:
        issues.append(f"[1] version mismatch: {k}={v}, latest archive v{latest}")

# [1c] Codex manifest contract: portable release-gate subset of the Codex
# ingestion schema. The release procedure additionally runs the official Codex
# validator; this local check prevents obvious drift on machines without it.
codex = jget(f"{root}/.codex-plugin/plugin.json", lambda x: x)
allowed_top = {
    "id", "name", "version", "description", "skills", "apps", "mcpServers",
    "interface", "author", "homepage", "repository", "license", "keywords",
}
if not isinstance(codex, dict):
    issues.append("[1c] .codex-plugin/plugin.json missing or invalid")
else:
    unknown = sorted(set(codex) - allowed_top)
    if unknown:
        issues.append(f"[1c] unsupported top-level fields: {', '.join(unknown)}")
    for field in ("name", "version", "description"):
        if not isinstance(codex.get(field), str) or not codex[field].strip():
            issues.append(f"[1c] required non-empty field: {field}")
    if codex.get("name") != "agentspace":
        issues.append(f"[1c] plugin name must be agentspace, got {codex.get('name')!r}")
    skills_path = str(codex.get("skills", "")).rstrip("/")
    if skills_path not in ("skills", "./skills"):
        issues.append(f"[1c] skills path must resolve to skills, got {codex.get('skills')!r}")
    author = codex.get("author")
    if not isinstance(author, dict) or not isinstance(author.get("name"), str) or not author["name"].strip():
        issues.append("[1c] author.name is required")
    interface = codex.get("interface")
    required_interface = (
        "displayName", "shortDescription", "longDescription", "developerName", "category",
    )
    if not isinstance(interface, dict):
        issues.append("[1c] interface object is required")
    else:
        for field in required_interface:
            if not isinstance(interface.get(field), str) or not interface[field].strip():
                issues.append(f"[1c] required non-empty interface.{field}")
        caps = interface.get("capabilities")
        if not isinstance(caps, list) or not all(isinstance(x, str) and x.strip() for x in caps):
            issues.append("[1c] interface.capabilities must be an array of non-empty strings")
        prompts = interface.get("defaultPrompt")
        if (not isinstance(prompts, list) or not prompts or len(prompts) > 3
                or not all(isinstance(x, str) and x.strip() and len(x) <= 128 for x in prompts)):
            issues.append("[1c] interface.defaultPrompt must contain 1-3 non-empty strings <=128 chars")
        for field in ("composerIcon", "logo", "logoDark"):
            raw = interface.get(field)
            if raw is None:
                continue
            if not isinstance(raw, str) or not raw.startswith("./") or ".." in raw.split("/"):
                issues.append(f"[1c] interface.{field} must be a safe relative path")
            elif not os.path.isfile(os.path.join(root, raw[2:])):
                issues.append(f"[1c] interface.{field} asset missing: {raw}")

# [1d] Kimi manifest contract: portable release-gate subset of the Kimi
# ingestion schema (kimi.plugin.json — name required, [a-z0-9][a-z0-9_-]{0,63}).
# Kimi installs via /plugins install (local/zip/GitHub); no marketplace file.
kimi = jget(f"{root}/kimi.plugin.json", lambda x: x)
kimi_allowed_top = {
    "name", "version", "description", "keywords", "author", "homepage",
    "license", "interface", "skills", "agents", "commands", "mcpServers",
    "hooks", "sessionStart", "systemPrompt", "systemPromptPath",
}
if not isinstance(kimi, dict):
    issues.append("[1d] kimi.plugin.json missing or invalid")
else:
    unknown = sorted(set(kimi) - kimi_allowed_top)
    if unknown:
        issues.append(f"[1d] unsupported top-level fields: {', '.join(unknown)}")
    for field in ("name", "version", "description"):
        if not isinstance(kimi.get(field), str) or not kimi[field].strip():
            issues.append(f"[1d] required non-empty field: {field}")
    kimi_name = kimi.get("name", "")
    if kimi_name != "agentspace":
        issues.append(f"[1d] plugin name must be agentspace, got {kimi_name!r}")
    elif not re.fullmatch(r"[a-z0-9][a-z0-9_-]{0,63}", kimi_name):
        issues.append(f"[1d] plugin name violates [a-z0-9][a-z0-9_-]{{0,63}}: {kimi_name!r}")
    skills_path = str(kimi.get("skills", "")).rstrip("/")
    if skills_path not in ("skills", "./skills"):
        issues.append(f"[1d] skills path must resolve to skills, got {kimi.get('skills')!r}")
    kimi_interface = kimi.get("interface")
    required_interface_kimi = (
        "displayName", "shortDescription", "longDescription", "developerName", "websiteURL",
    )
    if not isinstance(kimi_interface, dict):
        issues.append("[1d] interface object is required")
    else:
        for field in required_interface_kimi:
            if not isinstance(kimi_interface.get(field), str) or not kimi_interface[field].strip():
                issues.append(f"[1d] required non-empty interface.{field}")

# [1b] deployed marker must not drift from the latest archive (modulo version)
if latest:
    arch_doc = jget(f"{versions}/v{latest}/architecture.json", lambda x: x)
    marker_doc = jget(f"{assets}/.agentspace-architecture.json", lambda x: x)
    if arch_doc is None or marker_doc is None:
        issues.append("[1b] archive or deployed marker unreadable")
    else:
        a = dict(arch_doc); m = dict(marker_doc)
        a.pop("version", None); m.pop("version", None)
        if a != m:
            issues.append(f"[1b] deployed .agentspace-architecture.json differs from v{latest} archive (files/constants/modules drift)")

# [2] archive chain: starts at v0.1.0, contiguous, architecture version matches
if not dirs:
    issues.append("[2] no version archives found")
else:
    if dirs[0] != "v0.1.0":
        issues.append(f"[2] chain must start at v0.1.0, found {dirs[0]}")
    for i, d in enumerate(dirs):
        arch = jget(f"{versions}/{d}/architecture.json", lambda x: x)
        if arch is None:
            issues.append(f"[2] {d}: architecture.json invalid/missing")
        elif arch.get("version") != d[1:]:
            issues.append(f"[2] {d}: architecture.json version={arch.get('version')} != dir name")
        clpath = f"{versions}/{d}/CHANGELOG.md"
        if not os.path.exists(clpath):
            issues.append(f"[2] {d}: CHANGELOG.md missing")
        elif i > 0 and f"Upgrade from v{dirs[i-1][1:]}" not in open(clpath).read():
            issues.append(f"[2] {d}: CHANGELOG does not declare 'Upgrade from v{dirs[i-1][1:]}'")

# [3] CHANGELOG quality (v0.1.0 is the baseline release note — no migration duty)
for d in dirs:
    if d == "v0.1.0":
        continue
    clpath = f"{versions}/{d}/CHANGELOG.md"
    if not os.path.exists(clpath):
        continue
    cl = open(clpath).read()
    if "## Summary" not in cl or "## Changes" not in cl:
        issues.append(f"[3] {d}: CHANGELOG missing ## Summary / ## Changes")
    if "### [" not in cl:
        issues.append(f"[3] {d}: CHANGELOG has no '### [Tag]' change blocks")
    if "**Migration" not in cl:
        issues.append(f"[3] {d}: CHANGELOG has no '**Migration' guidance")
    # Chinese-language policy (DEVELOPMENT.md: CHANGELOG.md is Chinese;
    # historical English archives are not retro-fitted — the consistently
    # Chinese era starts at v0.4.1). Robust heuristic: the ## Summary section
    # must carry CJK characters.
    if vkey(d[1:]) >= (0, 4, 1):
        sec = re.search(r"## Summary\n(.*?)(?:\n## |\Z)", cl, re.S)
        if not sec or not re.search(r"[\u4e00-\u9fff]", sec.group(1)):
            issues.append(f"[3] {d}: Summary section has no CJK characters (CHANGELOG.md must be Chinese per DEVELOPMENT.md)")

# [4] constants contract: SEC_/STATUS_ in lib.sh, RESULT_/RESUME_ in templates.
# Reverse pass: every constant declared readonly in lib.sh must exist in the
# architecture snapshot — the forward pass only catches arch→lib drift; a new
# lib.sh constant shipped without its architecture record would pass silently.
arch = jget(f"{versions}/v{latest}/architecture.json", lambda x: x) if latest else None
if arch:
    lib_sh = open(f"{assets}/scripts/lib.sh").read()
    tmpls = "".join(open(f"{assets}/templates/{f}").read()
                    for f in os.listdir(f"{assets}/templates") if f.endswith(".md"))
    for name, val in arch.get("constants", {}).items():
        if f'{name}="{val}"' not in lib_sh:
            issues.append(f"[4] constant {name}={val!r} (name=value pair) missing in assets/scripts/lib.sh")
        if name.startswith(("RESULT_", "RESUME_")) and val not in tmpls:
            issues.append(f"[4] constant {name}={val!r} missing in assets/templates/*.md")
    for m in re.finditer(r'readonly ([A-Z][A-Z0-9_]+)=', lib_sh):
        if m.group(1) not in arch.get("constants", {}):
            issues.append(f"[4] lib.sh constant {m.group(1)} missing from architecture constants (reverse pass)")

# [5] file inventory: every architecture file exists in assets, and vice versa
if arch:
    for path, meta in arch.get("files", {}).items():
        if not os.path.exists(f"{assets}/{path}"):
            issues.append(f"[5] architecture file missing in assets: {path}")
    for root_dir, _dirs, files in os.walk(assets):
        for fn in files:
            rel = os.path.relpath(os.path.join(root_dir, fn), assets)
            if rel not in arch.get("files", {}):
                issues.append(f"[5] asset file not in architecture: {rel}")

# [6] section/column contract: architecture sections/columns exist in asset files
if arch:
    for path, meta in arch.get("files", {}).items():
        fpath = f"{assets}/{path}"
        if not os.path.exists(fpath):
            continue
        text = open(fpath).read()
        secs = meta.get("sections", {})
        if isinstance(secs, dict):
            for name, spec in secs.items():
                if name == "_default":
                    if isinstance(spec, dict) and "columns" in spec:
                        for col in spec["columns"]:
                            if col not in text:
                                issues.append(f"[6] {path}: column '{col}' missing in asset")
                    continue
                if f"## {name}" not in text:
                    issues.append(f"[6] {path}: section '## {name}' missing in asset")
                if isinstance(spec, dict):
                    for sub in spec.get("subsections", []):
                        if f"### {sub}" not in text:
                            issues.append(f"[6] {path}: subsection '### {sub}' missing in asset")
                    for col in spec.get("columns", []):
                        if col not in text:
                            issues.append(f"[6] {path}: column '{col}' missing in asset")
        elif isinstance(secs, list):
            for name in secs:
                if f"## {name}" not in text:
                    issues.append(f"[6] {path}: section '## {name}' missing in asset")

# [6b] reverse section alignment (AGENTS.md): [6] only walks archive→asset,
# so a section added to the ASSET AGENTS.md without its architecture record
# would pass silently (the constants analog is the [4] reverse pass). A
# heading inside a fenced code block is not a section. NOTE: this heredoc
# body must stay free of backticks, dollar-paren, and unpaired quotes —
# the bash 3.2 scanner tracks them even here (macOS system bash).
if arch:
    ag_secs = arch.get("files", {}).get("AGENTS.md", {}).get("sections", {})
    if isinstance(ag_secs, dict):
        # fence marker built via chr(96): a literal backtick inside this
        # heredoc derails the bash 3.2 parser (macOS system bash)
        fence = chr(96) * 3
        in_fence = False
        for line in open(f"{assets}/AGENTS.md"):
            s = line.rstrip("\n")
            if s.startswith(fence):
                in_fence = not in_fence
                continue
            if not in_fence and s.startswith("## "):
                name = s[3:].strip()
                if name not in ag_secs:
                    issues.append(f"[6b] asset AGENTS.md section '## {name}' missing from architecture AGENTS.md sections")

print("latest: v" + (latest or "?"))
for msg in issues:
    print("issue: " + msg)
EOF
)"; then
  echo "  [issue] meta-check script failed"
  issues=$((issues+1))
fi

LATEST="$(printf '%s\n' "$META_OUT" | sed -n 's/^latest: //p' | head -1)"
if [ -z "$LATEST" ]; then
  echo "  [issue] latest version unresolvable (meta-check failed?) — skipping [10]"
  issues=$((issues+1))
fi
while IFS= read -r line; do
  case "$line" in latest:*) continue ;; esac
  echo "  $line"
  issues=$((issues+1))
done <<< "$META_OUT"

# --- [7] script syntax ------------------------------------------------------
echo "[7] script syntax (bash -n)"
count=0
while IFS= read -r f; do
  count=$((count+1))
  if ! bash -n "$f" 2>/dev/null; then
    echo "  [issue] bash -n failed: ${f#$ROOT/}"
    issues=$((issues+1))
  fi
done < <(find "$ROOT" -name '*.sh' -not -path "$ROOT/AGENTSPACE/*" -not -path '*/.git/*')
echo "  checked $count scripts"

# --- [8] bilingual sync -----------------------------------------------------
echo "[8] bilingual sync"
bilingual() {
  local d="$1" name en zh
  name="$(basename "$d")"
  en="$(mktemp "/tmp/ag-verify-en.XXXXXX")" || return 1
  zh="$(mktemp "/tmp/ag-verify-zh.XXXXXX")" || { rm -f "$en"; return 1; }
  # strip fenced code blocks first — their pseudo-headings (e.g. the update
  # skill's "## Update Plan:" example) must not pollute the heading sequence.
  # Guards + explicit cleanup: a missing SKILL.md must surface as an issue,
  # not abort the gate and leak the /tmp files (audit R8)
  if ! awk '/^```/{f=!f} !f' "$d/SKILL.md" 2>/dev/null | grep -o '^#\+' > "$en"; then
    echo "  [issue] $name: SKILL.md unreadable"
    rm -f "$en" "$zh"
    issues=$((issues+1))
    return 0
  fi
  if ! awk '/^```/{f=!f} !f' "$d/SKILL.zh-CN.md" 2>/dev/null | grep -o '^#\+' > "$zh"; then
    echo "  [issue] $name: SKILL.zh-CN.md unreadable"
    rm -f "$en" "$zh"
    issues=$((issues+1))
    return 0
  fi
  if ! diff -q "$en" "$zh" >/dev/null; then
    echo "  [issue] $name: heading-level sequence mismatch (EN vs zh-CN)"
    issues=$((issues+1))
  fi
  rm -f "$en" "$zh"
}
# derived from the skills/ directory (a hardcoded list would silently stop
# covering the next skill someone adds without editing it)
for _skill_dir in "$ROOT"/skills/*/; do
  bilingual "${_skill_dir%/}"
done
# mechanism-parity spot checks: load-bearing upgrade rules must exist in BOTH
# languages — heading/token parity cannot catch a missing rule paragraph
# (e.g. the skip-missing-archive rule once existed only in SKILL.md).
# Each pair belongs to ONE skill; grep that skill's two files.
for pair in "skills/agentspace-update|skip to the next existing archive|跳过缺失的中间档案" \
            "skills/agentspace-code-clean|rewrite the comment/code line so it describes the change itself|改写该注释/代码行, 使其描述改动本身" \
            "skills/agentspace-code-clean|read CLEANUP.md in this skill directory|阅读本 skill 目录内的 CLEANUP.md" \
            "skills/agentspace-better-exp|enrollment always requires explicit user confirmation, never automatic|登记必须经用户显式确认, 绝不自动进行" \
            "skills/agentspace-exp|at most once per session|同一会话内最多提议一次"; do
  skill="${pair%%|*}"; rest="${pair#*|}"
  en="${rest%%|*}"; zh="${rest#*|}"
  grep -Fq -- "$en" "$ROOT/$skill/SKILL.md" || {
    echo "  [issue] ${skill##*/} SKILL.md missing mechanism phrase: $en"
    issues=$((issues+1))
  }
  grep -Fq -- "$zh" "$ROOT/$skill/SKILL.zh-CN.md" || {
    echo "  [issue] ${skill##*/} SKILL.zh-CN.md missing mechanism phrase: $zh"
    issues=$((issues+1))
  }
done
# rule-level token parity (daily skill only, per DEVELOPMENT.md Step 6)
for t in MUST SHOULD MAY; do
  en=$(grep -o "$t" "$ROOT/skills/agentspace/SKILL.md" | wc -l | tr -d ' ')
  zh=$(grep -o "$t" "$ROOT/skills/agentspace/SKILL.zh-CN.md" | wc -l | tr -d ' ')
  if [ "$en" != "$zh" ]; then
    echo "  [issue] agentspace: token parity $t en=$en zh=$zh"
    issues=$((issues+1))
  fi
done

# --- [9] SKILL size budget --------------------------------------------------
echo "[9] SKILL size budget (<=120 lines)"
for f in "$ROOT/skills/agentspace/SKILL.md" "$ROOT/skills/agentspace/SKILL.zh-CN.md"; do
  n=$(wc -l < "$f" | tr -d ' ')
  if [ "$n" -gt 120 ]; then
    echo "  [issue] $(basename "$f"): $n lines > 120 budget"
    issues=$((issues+1))
  fi
done

# --- [10] README release history coverage ----------------------------------
echo "[10] README release history"
if [ -n "$LATEST" ]; then
  for f in README.md README.zh-CN.md; do
    if ! grep -Fq "| v${LATEST#v} |" "$ROOT/$f"; then
      echo "  [issue] $f Release History 缺 v${LATEST#v} 行(手动维护, 需随发版同步)"
      issues=$((issues+1))
    fi
  done
fi

# --- [11] changelog-driven rehearsal record ---------------------------------
# MUST (user rule): every release that adds a changelog must first be
# rehearsed — sandbox built from the previous version's assets, the new
# changelog's Migration instructions applied, convergence verified. The
# record lives in the version archive; without a PASSING one the release is
# not ready (written by rehearse-update.sh).
echo "[11] changelog-driven rehearsal record"
if [ -n "$LATEST" ]; then
  REH="$VERSIONS/v${LATEST#v}/rehearsal.md"
  if [ -f "$REH" ] && grep -q '^Result: PASS' "$REH" 2>/dev/null; then
    echo "  rehearsal record present (v${LATEST#v})"
  else
    echo "  [issue] v${LATEST#v} 缺 PASS 演练留痕 — 新增 changelog 必须先演练: bash rehearse-update.sh <old-ref> ${LATEST#v}"
    issues=$((issues+1))
  fi
fi

# --- [12] realized-literal guard (self-hosting) ------------------------------
# The plugin repo is itself a registered key repo under its own gate: a
# REALIZED canonical bookkeeping id in the working tree would (a) block every
# future edit of that very line at the valveless commit gate and (b) be
# reported by doctor [15] forever. The walk is find-based and covers untracked
# files too, by design — mirrors gate semantics. Prose uses plan:NNNN
# placeholder forms; test fixtures construct ids at runtime (printf %04d).
# Frozen version archives, the nested ledger and local client state are out
# of scope.
echo "[12] realized-literal guard"
# derived from lib.sh — single source with the gate (a regex tightening there
# must not silently desync this guard); -i mirrors the gate's case-insensitive
# message scan.
LIT_RE="$(sed -n 's/^readonly COMMIT_BAN_PLAN_RE="\(.*\)"$/\1/p' "$ASSETS/scripts/lib.sh")|$(sed -n 's/^readonly COMMIT_BAN_ITER_RE="\(.*\)"$/\1/p' "$ASSETS/scripts/lib.sh")|$(sed -n 's/^readonly COMMIT_BAN_EXP_RE="\(.*\)"$/\1/p' "$ASSETS/scripts/lib.sh")"
lit_hits="$(find "$ROOT" -type f \
  -not -path "$ROOT/.git/*" \
  -not -path "$ROOT/AGENTSPACE/*" \
  -not -path "$ROOT/.agents/*" \
  -not -path "$ROOT/.zcode/*" \
  -not -path "$ROOT/skills/agentspace-update/versions/*" \
  -exec grep -IinE "$LIT_RE" {} + 2>/dev/null || true)"
if [ -n "$lit_hits" ]; then
  printf '%s\n' "$lit_hits" | sed 's/^/  [issue] realized bookkeeping id: /'
  issues=$((issues+1))
fi

# --- [13] assets gitignore contracts -----------------------------------------
# Two runtime-data contracts pair a script/feature with the shipped .gitignore —
# step 8a replaces .gitignore wholesale, so the assets pairing is the only thing
# standing between a user workspace and a `git add -A` that sweeps run-state or
# full experiment output into the ledger repo:
# (a) the collaboration-table script writes WS_FILE="$AS_ROOT/<name>" into the
#     ledger dir — the filename is parsed from the script itself so a rename
#     flips this check red instead of silently passing;
# (b) exp/exp_data/ holds the complete local-only experiment record (created by
#     new-exp.sh) — a missing ignore line lets the next milestone commit absorb
#     every experiment log into the ledger's git history.
echo "[13] assets gitignore contracts"
if [ -f "$ASSETS/scripts/parallel-workspace.sh" ]; then
  ws_data="$(sed -n 's/^WS_FILE="\$AS_ROOT\/\([^"]*\)"$/\1/p' "$ASSETS/scripts/parallel-workspace.sh")"
  if [ -z "$ws_data" ]; then
    echo "  [issue] cannot read WS_FILE from assets/scripts/parallel-workspace.sh"
    issues=$((issues+1))
  elif ! grep -Fq "$ws_data" "$ASSETS/.gitignore"; then
    echo "  [issue] assets/.gitignore misses the parallel-workspace data file: $ws_data"
    issues=$((issues+1))
  fi
fi
if ! grep -Fqx "exp/exp_data/" "$ASSETS/.gitignore"; then
  echo "  [issue] assets/.gitignore misses the exp/exp_data/ line (complete experiment output would enter the ledger repo)"
  issues=$((issues+1))
fi

# --- [14] skill/command frontmatter YAML -------------------------------------
# Every SKILL.md / SKILL.zh-CN.md / commands/*.md carries a YAML frontmatter
# the host parses at load time; an unquoted description containing a ": "
# sequence (e.g. "candidates (...): they never block") breaks the mapping and
# the skill fails to load for users — invisible to every text-level check, so
# it must be parsed for real here. Descriptions are capped at 1000 characters
# (user-set limit with headroom under the host's 1024 hard refusal), enforced
# on the same pass.
# PyYAML's error class matches the hosts'; a missing yaml module fails closed
# (pip install pyyaml) rather than letting the gate pass unverified.
echo "[14] skill/command frontmatter YAML"
FM_PY="$(cat <<'EOF'
import re, sys, yaml
bad = 0
for f in sys.argv[1:]:
    t = open(f, encoding="utf-8").read()
    m = re.match(r"^---\n(.*?)\n---\n", t, re.S)
    if not m:
        print(f"  [issue] no frontmatter: {f}"); bad += 1; continue
    try:
        yaml.safe_load(m.group(1))
    except Exception as e:
        mark = str(e).replace("\n", " | ")
        print(f"  [issue] invalid frontmatter YAML: {f}: {mark}"); bad += 1
        continue
    d = re.search(r"^description:\s*(.*)$", m.group(1), re.M)
    if d and len(d.group(1)) > 1000:
        print(f"  [issue] description over 1000 chars ({len(d.group(1))}): {f}"); bad += 1
sys.exit(1 if bad else 0)
EOF
)"
FM_FILES="$(find "$ROOT/skills" "$ROOT/commands" -name 'SKILL.md' -o -name 'SKILL.zh-CN.md' -o -name '*.md' -path "$ROOT/commands/*" 2>/dev/null | sort -u || true)"
if [ -z "$FM_FILES" ]; then
  echo "  [issue] no skill/command files found"
  issues=$((issues+1))
elif ! python3 -c 'import yaml' 2>/dev/null; then
  echo "  [issue] PyYAML required for [14] — pip install pyyaml"
  issues=$((issues+1))
else
  # shellcheck disable=SC2086
  if ! python3 -c "$FM_PY" $FM_FILES; then
    issues=$((issues+1))
  fi
fi

# --- summary ----------------------------------------------------------------
dirty=$(git -C "$ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ' || true)
echo ""
if [ "$issues" -eq 0 ]; then
  echo "[pass] release-ready (v${LATEST#v})"
  [ "${dirty:-0}" -gt 0 ] && echo "[note] working tree has $dirty uncommitted change(s) — commit after passing"
  exit 0
else
  echo "[fail] $issues issue(s) — fix before release"
  exit 1
fi
