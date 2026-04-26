---
mode: agent
description: Refactor code in this .NET codebase without changing behavior. Verified with tests.
---

Read `CLAUDE.md` and `.claude/commands/refactor.md` in this repository, then execute the refactor workflow defined there for the target below.

`.claude/commands/refactor.md` is the single source of truth. Follow it exactly: verify starting state → write baseline tests if missing → refactor incrementally (build + test after each change) → Boy Scout → verify final state → present before/after.

Do not change behavior. If tests fail, you've changed behavior — fix it or revert.

## Target

${input:target:Describe what to refactor — file, class, or area}
