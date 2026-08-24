---
agent: agent
description: Diagnose and fix a bug in this repository. Writes a failing regression test first where the repository supports one.
---

Read `CLAUDE.md` and `.claude/commands/fix.md` in this repository, then execute the fix workflow defined there for the bug below.

`.claude/commands/fix.md` is the single source of truth. Follow it exactly: diagnose the root cause → write a failing regression test FIRST where supported → apply the minimal fix → derive and run only evidence-supported **build**, **test**, **format**, **lint**, **migration/deploy**, and **data-validation** commands (report unavailable categories as **not available**) → Boy Scout within blast radius → report.

Do not skip reproduction before the fix. Use a red-first regression test when an applicable repository-evidenced harness exists; otherwise use the strongest evidenced validation, report tests as **not available**, and do not introduce a foreign harness solely for this fix.

## Bug

${input:bug:Describe the bug — symptoms, reproduction steps, expected vs actual}
