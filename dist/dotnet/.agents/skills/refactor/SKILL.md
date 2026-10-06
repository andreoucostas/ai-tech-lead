---
name: refactor
description: "Behavior-preserving refactor workflow: derive applicable verification from repository evidence, establish a green baseline, add characterization coverage where a harness exists, refactor incrementally, and report net LOC delta."
argument-hint: "[target code and goal]"
---

Read `AGENTS.md` and `.claude/commands/refactor.md` in this repository, then execute the refactor workflow defined there for the target below.

`.claude/commands/refactor.md` is the single source of truth. Follow it exactly: derive and verify the starting validation state → write characterization coverage only when an applicable harness exists, otherwise report tests as **not available** and use the strongest evidenced validation → refactor incrementally with applicable checks → Boy Scout → verify final state → present before/after.

Do not change behavior. If an applicable test or other evidenced validation fails, fix the change or revert; never introduce a foreign harness solely for this refactor.

## Target

The target is the text after `/refactor`, or the code the developer asked to refactor: a file, class, or area, and the goal. Use it wherever `.claude/commands/refactor.md` says `$ARGUMENTS`. If there is none, ask what to refactor.
