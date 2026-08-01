# AGENTSPACE v0.2.4

Upgrade from v0.2.3. Date: 2026-08-02

## Summary

- Fixed v0.2.3 regression: iteration-readme.md template had duplicated 结果 and data 产物清单 sections

## Changes

### [Fix] iteration-readme.md template duplicate sections

**What**: the v0.2.3 template update accidentally duplicated the "## 结果" and "## data 产物清单" sections (two copies each). Generated readmes had 9 sections instead of 7, and any exact-match script logic on those sections became ambiguous.

**Why**: regression from the v0.2.3 template rewrite (incomplete string replacement).

**Migration**:
1. Handled automatically by update flow step 8a: the template is replaced from assets (`skills/agentspace-init/assets/agentspace/templates/iteration-readme.md`). No manual work needed.
2. **Agent check** (conservative mode): if any existing `iterations/iteration_NNNN/readme.md` was generated from the buggy template and contains duplicated 结果/data 产物清单 sections, ask the user whether to clean them (delete the duplicate pair). Only in-progress readmes matter; closed readmes keep their content but duplicates can still be cleaned on request.
