#!/usr/bin/env bash
# t17: agentspace-mode — hybrid default / standalone switch, AGENTS.md mode
# block maintenance (scripts-only, incl. legacy insert path), whitelist
# add/list/deny (trailing-slash normalization, no false "removed"), doctor
# [13] standalone external-ref discipline (large auto-exempt via --fix AND
# via switch, small report-only, relative-symlink escape detection, internal
# refs not flagged, URL/prose not flagged, whitelist hygiene), hybrid = check
# skipped entirely.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

SB="$(build_sandbox t17)"
# 与 as_external_refs 同款 canonicalize(/tmp → /private/tmp), 断言路径拼写一致
SB="$(cd -P "$SB" 2>/dev/null && pwd -P)"
WS="$SB/AGENTSPACE"
MODE="$WS/scripts/mode.sh"
EXT_RAW="$(mktemp -d /tmp/as-t17-ext-XXXXXX)"
# 规范化 /tmp → /private/tmp — as_external_refs 的 canonicalize 同款, 断言路径拼写一致
EXT="$(cd -P "$EXT_RAW" 2>/dev/null && pwd -P)"
trap 'rm -rf "$SB" "$EXT_RAW"' EXIT

# --- 0) 默认 hybrid + legacy insert 路径: 无块工作区 --standalone 应把标记块
#         插到 ## 项目简介 之前 ---
OUT="$(bash "$MODE")"
assert_output_contains "$OUT" "mode: hybrid"
awk '/^## agentspace mode/{f=1; next} f && /^$/{f=0; next} {print}' "$WS/AGENTS.md" > "$WS/AGENTS.md.tmp" && mv "$WS/AGENTS.md.tmp" "$WS/AGENTS.md"
grep -q "## agentspace mode" "$WS/AGENTS.md" && fail "mode block removal failed"
bash "$MODE" --standalone >/dev/null 2>&1
if ! awk '/^## agentspace mode/{found=1} /^## 项目简介/{exit} END{exit !found}' "$WS/AGENTS.md"; then
  fail "mode block not inserted BEFORE ## 项目简介 (legacy insert path)"
fi
grep -A2 "^## agentspace mode" "$WS/AGENTS.md" | grep -q "^standalone$" || fail "standalone value missing after insert"
grep -A3 "^## agentspace mode" "$WS/AGENTS.md" | grep -q "^rules$" || fail "standalone rules marker missing"

# --- 1) 幂等 + 无外部引用时 [13] 干净 ---
OUT="$(bash "$MODE" --standalone)"
assert_output_contains "$OUT" "already standalone"
OUT="$(bash "$WS/scripts/doctor.sh" 2>&1 || true)"
assert_output_contains "$OUT" "[13] standalone external refs"
assert_output_not_contains "$OUT" "外部引用未白名单"

# --- 2) 外部依赖 fixture: 大文件(1G 稀疏)+ 小文件 + 相对逃逸链接 + 内部链接
#         + URL 散文(负向: 不误报) ---
dd if=/dev/zero of="$EXT/big.bin" bs=1 seek=1073741824 count=0 2>/dev/null
printf 'tool\n' > "$EXT/small.sh"
printf 'rel\n' > "$SB/ext-rel.txt"
mkdir -p "$WS/data"
ln -s "$EXT/big.bin" "$WS/data/big-link"
ln -s "$EXT/small.sh" "$WS/data/small-link"
ln -s "../../ext-rel.txt" "$WS/data/rel-link"       # 相对链接逃逸出工作区
ln -s "../notes" "$WS/data/in-link"                 # 指向工作区内 → 不报
printf '| big | 大 | 软连接到 %s | [link](data/big-link) |\n' "$EXT/big.bin" >> "$WS/data.md"
printf '| small | 小 | 软连接到 %s | [link](data/small-link) |\n' "$EXT/small.sh" >> "$WS/data.md"
printf '| url | 参考 https://github.com/example/repo | 官网 | [link](data/big-link) |\n' >> "$WS/data.md"
printf '| url2 | 数据 | 下载自 https://example.com/a/b | [link](data/big-link) |\n' >> "$WS/data.md"

OUT="$(bash "$WS/scripts/doctor.sh" 2>&1 || true)"
assert_output_contains "$OUT" "外部大文件引用未白名单"
assert_output_contains "$OUT" "外部引用未白名单: $EXT/small.sh"
assert_output_contains "$OUT" "外部引用未白名单: $SB/ext-rel.txt"   # R4: 相对逃逸被检出
assert_output_not_contains "$OUT" "外部引用未白名单: $WS/notes"      # R3: 内部链接不报
assert_output_not_contains "$OUT" "/github.com"                      # R1: 说明列 URL 不扫
assert_output_not_contains "$OUT" "/example.com"                     # 来源列 URL 方案摘除

# --- 3) doctor --fix: 大文件自动白名单([fixed]), 小文件仍报(不自动) ---
OUT="$(bash "$WS/scripts/doctor.sh" --fix 2>&1 || true)"
assert_output_contains "$OUT" "大文件引用已自动白名单"
assert_output_contains "$OUT" "外部引用未白名单: $EXT/small.sh"
[ "$(printf '%s\n' "$OUT" | grep -c '\[fixed\] 大文件' || true)" -ge 1 ] || fail "--fix did not whitelist the large ref"
OUT="$(bash "$MODE" --list)"
assert_output_contains "$OUT" "$EXT/big.bin"

# --- 4) 白名单卫生: 小文件条目提示 + 失效条目报告不删 + deny 归一化/不误报 ---
bash "$MODE" --allow "$EXT/small.sh" >/dev/null 2>&1
OUT="$(bash "$WS/scripts/doctor.sh" 2>&1 || true)"
assert_output_contains "$OUT" "白名单小文件条目(需用户显式确认): $EXT/small.sh"
bash "$MODE" --deny "$EXT/small.sh" >/dev/null 2>&1
OUT="$(bash "$MODE" --deny "$EXT/never-existed" 2>&1 || true)"
assert_output_contains "$OUT" "not in whitelist: $EXT/never-existed"   # R7: 不谎报 removed
printf '%s\n' "$EXT/gone-dir" >> "$WS/.agentspace-whitelist"
OUT="$(bash "$WS/scripts/doctor.sh" 2>&1 || true)"
assert_output_contains "$OUT" "白名单条目失效(目标不存在)"
grep -Fq "$EXT/gone-dir" "$WS/.agentspace-whitelist" || fail "dead entry deleted by doctor"
# R6: 尾斜杠条目归一化 — --allow 目录条目, --deny 带尾斜杠拼写应能删
bash "$MODE" --allow "$EXT" >/dev/null 2>&1
bash "$MODE" --deny "$EXT/" >/dev/null 2>&1
grep -Fqx "$EXT" "$WS/.agentspace-whitelist" && fail "trailing-slash deny did not remove the entry"

# --- 5) 切回 hybrid: [13] 整节跳过 ---
bash "$MODE" --hybrid >/dev/null 2>&1
grep -A1 "^## agentspace mode" "$WS/AGENTS.md" | grep -q "^hybrid$" || fail "hybrid block not restored"
OUT="$(bash "$WS/scripts/doctor.sh" 2>&1 || true)"
assert_output_contains "$OUT" "[13] standalone external refs"
assert_output_contains "$OUT" "(hybrid — 检查不启用)"

# --- 6) 切换时自动豁免: 切换前已存在的大文件引用 → --standalone 自动白名单 ---
dd if=/dev/zero of="$EXT/big2.bin" bs=1 seek=1073741824 count=0 2>/dev/null
ln -s "$EXT/big2.bin" "$WS/data/big2-link"
printf '| big2 | 大2 | 软连接到 %s | [link](data/big2-link) |\n' "$EXT/big2.bin" >> "$WS/data.md"
OUT="$(bash "$MODE" --standalone 2>&1 || true)"
assert_output_contains "$OUT" "whitelisted: $EXT/big2.bin"
OUT="$(bash "$MODE" --list)"
assert_output_contains "$OUT" "$EXT/big2.bin"

# --- 7) 输入规范化: /tmp 拼写 --allow 也必须命中(真实三方验证发现: 未规范化
#          拼写入库的条目永不匹配) ---
printf 'x\n' > "$EXT_RAW/small2.sh"
ln -s "$EXT_RAW/small2.sh" "$WS/data/small2-link"
printf '| small2 | 小2 | 软连接到 %s | [link](data/small2-link) |\n' "$EXT_RAW/small2.sh" >> "$WS/data.md"
OUT="$(bash "$WS/scripts/doctor.sh" 2>&1 || true)"
assert_output_contains "$OUT" "外部引用未白名单: $EXT/small2.sh"
bash "$MODE" --allow "$EXT_RAW/small2.sh" >/dev/null 2>&1
OUT="$(bash "$WS/scripts/doctor.sh" 2>&1 || true)"
assert_output_not_contains "$OUT" "外部引用未白名单: $EXT/small2.sh"

echo "PASS t17"
