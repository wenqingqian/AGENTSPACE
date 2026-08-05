#!/usr/bin/env bash
# Dev tool — repo root only, NOT part of the deployed plugin.
# Release gate. Read-only. Checks (exit 0 = release-ready):
#   [0] JSON validity            [5] asset <-> architecture file inventory
#   [1] version consistency      [6] section/column contract in assets
#   [2] archive chain            [7] bash -n on all .sh
#   [3] CHANGELOG quality        [8] bilingual sync (skills)
#   [4] constants contract       [9] SKILL size budget
# Usage: bash verify-release.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
VERSIONS="$ROOT/skills/agentspace-update/versions"
ASSETS="$ROOT/skills/agentspace-init/assets/agentspace"
issues=0

echo "== AGENTSPACE verify-release: $ROOT =="

# --- [0] JSON validity ------------------------------------------------------
echo "[0] JSON validity"
JSON_FILES=( "$ROOT/.zcode-plugin/plugin.json" "$ROOT/marketplace.json" "$ASSETS/.agentspace-version.json" "$ASSETS/.agentspace-architecture.json" "$VERSIONS"/v*/architecture.json )
for f in "${JSON_FILES[@]}"; do
  if ! python3 -m json.tool "$f" >/dev/null 2>&1; then
    echo "  [issue] invalid JSON: ${f#$ROOT/}"
    issues=$((issues+1))
  fi
done

# --- [1-6] metadata & contract checks (single python pass) ------------------
echo "[1] version consistency"
echo "[1b] archive vs deployed marker"
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
    "plugin.json": jget(f"{root}/.zcode-plugin/plugin.json", lambda d: d["version"]),
    "marketplace.json": jget(f"{root}/marketplace.json", lambda d: d["plugins"][0]["version"]),
    "assets/.agentspace-version.json": jget(f"{assets}/.agentspace-version.json", lambda d: d["version"]),
    "assets/.agentspace-architecture.json": jget(f"{assets}/.agentspace-architecture.json", lambda d: d["version"]),
}
for k, v in marks.items():
    if v != latest:
        issues.append(f"[1] version mismatch: {k}={v}, latest archive v{latest}")

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

# [4] constants contract: SEC_/STATUS_ in lib.sh, RESULT_/RESUME_ in templates
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
  # skill's "## Update Plan:" example) must not pollute the heading sequence
  awk '/^```/{f=!f} !f' "$d/SKILL.md" | grep -o '^#\+' > "$en"
  awk '/^```/{f=!f} !f' "$d/SKILL.zh-CN.md" | grep -o '^#\+' > "$zh"
  if ! diff -q "$en" "$zh" >/dev/null; then
    echo "  [issue] $name: heading-level sequence mismatch (EN vs zh-CN)"
    issues=$((issues+1))
  fi
  rm -f "$en" "$zh"
}
bilingual "$ROOT/skills/agentspace"
bilingual "$ROOT/skills/agentspace-update"
bilingual "$ROOT/skills/agentspace-doctor"
# mechanism-parity spot checks: load-bearing upgrade rules must exist in BOTH
# languages — heading/token parity cannot catch a missing rule paragraph
# (e.g. the skip-missing-archive rule once existed only in SKILL.md)
for pair in "skip to the next existing archive|跳过缺失的中间档案"; do
  en="${pair%%|*}"; zh="${pair##*|}"
  grep -Fq -- "$en" "$ROOT/skills/agentspace-update/SKILL.md" || {
    echo "  [issue] agentspace-update SKILL.md missing mechanism phrase: $en"
    issues=$((issues+1))
  }
  grep -Fq -- "$zh" "$ROOT/skills/agentspace-update/SKILL.zh-CN.md" || {
    echo "  [issue] agentspace-update SKILL.zh-CN.md missing mechanism phrase: $zh"
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
