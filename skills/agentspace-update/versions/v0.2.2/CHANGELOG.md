# AGENTSPACE v0.2.2

Upgrade from v0.2.1. Date: 2026-07-31

## Summary

- All scripts converted to English (comments, messages, error strings)
- CJK slug truncation bug fixed (cut/awk byte-aware → python3 character-aware)
- Constants (SEC_*/STATUS_*) remain Chinese — they match deployed markdown headings

## Changes

### [Fix] CJK slug truncation producing invalid filenames
- **What**: `new-plan.sh` slug generation used `cut -c` / `awk substr` which are byte-aware on macOS, splitting CJK characters mid-byte and creating invalid UTF-8 filenames
- **Why**: `cut -c` and macOS awk `substr` operate on bytes in C/UTF-8 locales, not characters
- **Migration**: replaced with `python3 -c "print(s[:40])"` which is character-aware regardless of locale

### [Breaking] All scripts converted to English
- **What**: comments, echo messages, and error strings in all 9 scripts converted from Chinese to English
- **Why**: code must be in English for maintainability and international readability
- **Migration**: purely cosmetic — no functional change; constants (SEC_TODO, STATUS_PROGRESS, etc.) remain Chinese as they match deployed markdown headings
