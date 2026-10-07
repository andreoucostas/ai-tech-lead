---
name: test
description: "Test workflow: follow project conventions; add the smallest risk-relevant behavior set; reuse existing fixtures. Invoke when the user wants tests added or coverage raised."
argument-hint: "[file, class, or area]"
---

Read `AGENTS.md` (especially Conventions > Testing and Common Tasks) and `.claude/commands/test.md`, then execute the test workflow defined there for the target below.

`.claude/commands/test.md` is the single source of truth. Follow it exactly: understand what to test → match existing test framework, naming, and mocking patterns → write tests covering happy path, edge cases, error paths → derive and run only evidence-supported **build**, **test**, **format**, **lint**, **migration/deploy**, and **data-validation** commands (report unavailable categories as **not available**) → report.

## Target

The target is the text after `/test`, or the code the developer asked to test. Use it wherever `.claude/commands/test.md` says `$ARGUMENTS`; with none, follow the command's rule for an empty target.
