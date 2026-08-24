---
agent: agent
description: Generate tests for code in this repository, following evidence-derived project patterns.
---

Read `CLAUDE.md` (especially Conventions > Testing and Common Tasks) and `.claude/commands/test.md`, then execute the test workflow defined there for the target below.

`.claude/commands/test.md` is the single source of truth. Follow it exactly: understand what to test → match existing test framework, naming, and mocking patterns → write tests covering happy path, edge cases, error paths → derive and run only evidence-supported **build**, **test**, **format**, **lint**, **migration/deploy**, and **data-validation** commands (report unavailable categories as **not available**) → report.

If no target is given, identify files with the weakest coverage and prioritise those.

## Target

${input:target:Describe what to test, or leave blank to find weakest coverage}
