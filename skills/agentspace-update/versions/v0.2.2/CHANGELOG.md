# AGENTSPACE v0.2.2

Upgrade from v0.2.1. Date: 2026-07-31

## Summary

- All scripts converted to English (comments, messages, error strings)
- CJK slug truncation bug fixed (cut/awk byte-aware → python3 character-aware)
- Constants (SEC_*/STATUS_*) remain Chinese — they match deployed markdown headings

## Changes

### [Fix] CJK slug truncation producing invalid filenames

**What**: `new-plan.sh` slug generation used `cut -c` / `awk substr` which are byte-aware on macOS, splitting CJK characters mid-byte and creating invalid UTF-8 filenames.

**Why**: `cut -c` and macOS awk `substr` operate on bytes in C/UTF-8 locales, not characters.

**Migration**: this is handled automatically by step 8a of the update flow (scripts are replaced from assets). No manual intervention needed. The new `new-plan.sh` uses `python3 -c "print(s[:40])"` for character-aware truncation.

### [Breaking] All scripts converted to English

**What**: comments, echo messages, and error strings in all 9 scripts converted from Chinese to English.

**Why**: code must be in English for maintainability and international readability.

**Migration**: this is handled automatically by step 8a of the update flow (all scripts are replaced from assets). No manual intervention needed. Constants (SEC_TODO, STATUS_PROGRESS, etc.) remain Chinese as they match deployed markdown headings — the workspace content is unchanged.

### No structural changes

This version does NOT change the workspace file structure, table schemas, or AGENTS.md content. Only scripts are updated. The update flow's step 8a (copy scripts from assets) + step 8c (copy architecture.json) is sufficient.
