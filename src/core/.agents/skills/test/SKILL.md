---
name: test
description: "Test workflow: follow project conventions; add the smallest risk-relevant behavior set; reuse existing fixtures. Invoke when the user wants tests added or coverage raised."
argument-hint: "[file, class, or area]"
---

Read `AGENTS.md` (especially Conventions > Testing and Common Tasks) and `.claude/commands/test.md`, then execute the test workflow defined there for the target below.

<!-- @stack:summary -->

## Target

The target is the text after `/test`, or the code the developer asked to test. Use it wherever `.claude/commands/test.md` says `$ARGUMENTS`; with none, follow the command's rule for an empty target.
