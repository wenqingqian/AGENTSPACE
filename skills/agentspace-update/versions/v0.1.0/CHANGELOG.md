# AGENTSPACE v0.1.0

Initial release. No migration needed — this is the baseline version.

## Summary

- Plan + iteration dual-mainline with globally incrementing indexes
- Entry files (plan.md, iterations.md) as truncated views; full history in index.md
- Scripts as sole writers of index/entry files; agent authors content documents
- Experiment data in iteration_NNNN/data/ (gitignored)
- Modules: plan, iterations, utils, tests, notes, register
- Concurrency locking via mkdir-based spinlock
- Milestone git commits within AGENTSPACE/ repo
