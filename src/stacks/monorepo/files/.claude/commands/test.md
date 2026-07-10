---
description: "Test-coverage workflow: follow project test conventions; cover happy path, edge cases, and error paths; behavior-first assertions; reuse existing fixtures. Invoke when the user wants tests added or coverage raised."
argument-hint: "[file, class, or area]"
---

Generate tests for code in this mixed .NET + Angular codebase. Follow CLAUDE.md > Conventions > Testing and the test-related Common Tasks recipes.

Match the test level to the **Test shape** heuristic in `docs/defaults.md` (or `CLAUDE.md > Conventions` once bootstrapped) — and match the conventions of the **stack under test** (frontend testing in particular is trophy-shaped, component/integration-weighted). This framework does not mandate test-first for features — but a bug fix or regression test is written **red-first**, and every new behavioral test/spec must be seen to fail before you trust it (Verification Rule #9).

## Input
$ARGUMENTS

If no specific target given, identify the files with the weakest test coverage and prioritise those.

## Execution

### Step 1 — Understand what to test
- Read the target code thoroughly
- Identify the public behaviors that need test coverage
- Check for existing tests — don't duplicate, extend
- Determine the right test type for the stack: unit, component, integration, or e2e (as the stack allows)

### Step 2 — Follow project patterns
- Match the existing test project/file structure and naming conventions of the stack under test
- Use the same test framework and assertion style as existing tests
- Follow that stack's naming convention — .NET: `MethodName_Scenario_ExpectedResult`; Angular: `should [expected behavior] when [condition]`
- Use the same mocking approach as the rest of the codebase

### Step 3 — Write tests
For each target, following the stack under test:

**.NET:**
- **Unit tests**: test behavior, not implementation. Mock external dependencies only.
- **Integration tests**: use `WebApplicationFactory` for API endpoints. Test the full request/response cycle.

**Angular:**
- **Service tests**: mock HTTP via `HttpClientTestingModule` / `provideHttpClientTesting`. Verify request URLs, methods, and response handling.
- **Component tests**: use `TestBed`. Test template rendering, input/output binding, user interactions. Use component harnesses where available.
- **Pipe/utility tests**: pure function tests — straightforward input/output.

For every target:
- Cover: happy path, edge cases, error paths, boundary conditions
- Do not test framework behavior (e.g., don't test that DI works)
- Mock only true external boundaries; every test/spec needs a real oracle — a return, rendered output, an emitted value, or state change, never just "the mock/spy was called" or `Assert.True(true)` / `expect(true).toBe(true)` (Test leanness #14–16)

### Step 4 — Verify
Run the touched stack's gates — .NET: `dotnet build` then `dotnet test`; Angular: `ng build` then `ng test --watch=false --browsers=ChromeHeadless`. Tests must compile and all new tests must pass.
- If a test fails, it's either a bug in the test or a bug in the code. Determine which.

### Step 5 — Report
- What was tested and what test type was used
- What's still not covered (if anything)
- Any bugs discovered while writing tests (this happens — report them)
