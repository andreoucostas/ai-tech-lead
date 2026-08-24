---
agent: agent
description: Refactor code without changing behavior, using only repository-evidenced verification and reporting unavailable checks.
---

Read `CLAUDE.md` and `.claude/commands/refactor.md` in this repository, then execute the refactor workflow defined there for the target below.

`.claude/commands/refactor.md` is the single source of truth. Follow it exactly: derive and verify the starting validation state → write characterization coverage only when an applicable harness exists, otherwise report tests as **not available** and use the strongest evidenced validation → refactor incrementally with applicable checks → Boy Scout → verify final state → present before/after.

Do not change behavior. If an applicable test or other evidenced validation fails, fix the change or revert; never introduce a foreign harness solely for this refactor.

## Target

${input:target:Describe what to refactor — file, class, or area}
