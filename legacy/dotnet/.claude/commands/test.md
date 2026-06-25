---
description: "Test-coverage workflow: follow project test conventions; cover happy path, edge cases, and error paths; behavior-first assertions; reuse existing fixtures. Invoke when the user wants tests added or coverage raised."
argument-hint: "[file, class, or area]"
---

Generate tests for code in this .NET codebase. Follow CLAUDE.md > Conventions > Testing and the test-related Common Tasks recipes.

Match the test level to the **Test shape** heuristic in `docs/defaults.md` (or `CLAUDE.md > Conventions` once bootstrapped). This framework does not mandate test-first for features — but a bug fix or regression test is written **red-first**, and every new behavioral test must be seen to fail before you trust it (Verification Rule #9).

## Input
$ARGUMENTS

If no specific target given, identify the files with the weakest test coverage and prioritise those.

## Execution

### Step 1 — Understand what to test
- Read the target code thoroughly
- Identify the public behaviors that need test coverage
- Check for existing tests — don't duplicate, extend
- Determine the right test type: unit, integration, or both

### Step 2 — Follow project patterns
- Match the existing test project structure and naming conventions
- Use the same test framework and assertion style as existing tests
- Follow the naming convention: `MethodName_Scenario_ExpectedResult`
- Use the same mocking approach as the rest of the codebase

### Step 3 — Write tests
For each target:
- **Unit tests**: test behavior, not implementation. Mock external dependencies only.
- **Integration tests**: use `WebApplicationFactory` for API endpoints. Test the full request/response cycle.
- Cover: happy path, edge cases, error paths, boundary conditions
- Do not test framework behavior (e.g., don't test that DI works)
- Mock only true external boundaries; every test needs a real oracle — a return, state change, or thrown exception, never just "the mock was called" or `Assert.True(true)` (Test leanness #14–16)

### Step 4 — Verify
- Run `dotnet build` — tests must compile
- Run `dotnet test` — all new tests must pass
- If a test fails, it's either a bug in the test or a bug in the code. Determine which.

### Step 5 — Report
- What was tested and what test type was used
- What's still not covered (if anything)
- Any bugs discovered while writing tests (this happens — report them)
