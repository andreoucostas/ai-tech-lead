---
mode: agent
description: Diagnose and fix a bug in this .NET codebase. Writes a failing regression test first.
---

Read `CLAUDE.md` and `.claude/commands/fix.md` in this repository, then execute the fix workflow defined there for the bug below.

`.claude/commands/fix.md` is the single source of truth. Follow it exactly: diagnose the root cause → write a failing regression test FIRST → apply the minimal fix → verify (`dotnet build`, `dotnet test`, format) → Boy Scout within blast radius → report.

Do not skip the regression test step. The test is the proof the fix works.

## Bug

${input:bug:Describe the bug — symptoms, reproduction steps, expected vs actual}
