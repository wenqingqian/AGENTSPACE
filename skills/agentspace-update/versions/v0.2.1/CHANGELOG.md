# AGENTSPACE v0.2.1

Upgrade from v0.2.0. Date: 2026-07-31

## Summary

- New built-in module: data.md + data/ for shared data (training sets, model weights, symlinks)
- New built-in module: examples.md + examples/ for reusable experiment configs (pairs with tests/)

## Changes

### [Addition] data module (data.md + data/)
- **What**: new built-in module for project shared data — training sets, model weights, preprocessed data, or symlinks to external locations
- **Why**: multiple experiments often need the same data; centralizing avoids duplication and makes data provenance clear
- **Conservative migration**: create data/ directory + data.md entry file; no existing content affected
- **Aggressive migration**: same (non-destructive addition)

### [Addition] examples module (examples.md + examples/)
- **What**: new built-in module for reusable experiment configurations (YAML/JSON etc.); pairs with tests/ — tests/ holds entry-point scripts (how to run), examples/ holds configs (what parameters)
- **Why**: separating experiment configs from run scripts improves reusability and clarity
- **Migration**: create examples/ directory + examples.md entry file; if user previously used register-module for examples, suggest migrating configs to the new built-in module
