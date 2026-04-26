---
mode: agent
description: Generate tests for code in this .NET codebase, following project patterns.
---

Read `CLAUDE.md` (especially Conventions > Testing and Common Tasks) and `.claude/commands/test.md`, then execute the test workflow defined there for the target below.

`.claude/commands/test.md` is the single source of truth. Follow it exactly: understand what to test → match existing test framework, naming, and mocking patterns → write tests covering happy path, edge cases, error paths → verify (`dotnet build`, `dotnet test`) → report.

If no target is given, identify files with the weakest coverage and prioritise those.

## Target

${input:target:Describe what to test, or leave blank to find weakest coverage}
