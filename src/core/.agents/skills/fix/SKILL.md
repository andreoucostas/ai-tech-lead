---
name: fix
description: "Bug-fix workflow: diagnose and reproduce first, use a red regression test when an evidenced harness exists, apply the minimal fix, and Boy Scout the blast radius only. Invoke for bugs, crashes, failing tests, and regressions."
argument-hint: "[bug description or failing test]"
---

Read `AGENTS.md` and `.claude/commands/fix.md` in this repository, then execute the fix workflow defined there for the bug below.

<!-- @stack:summary -->

Do not skip reproduction before the fix. Use a red-first regression test when an applicable repository-evidenced harness exists; otherwise use the strongest evidenced validation, report tests as **not available**, and do not introduce a foreign harness solely for this fix.

## Bug

The bug is the text after `/fix`, or the bug the developer reported: symptoms, reproduction steps, expected versus actual. Use it wherever `.claude/commands/fix.md` says `$ARGUMENTS`. If there is none, ask for it.
