---
description: "Test workflow: follow project conventions; add the smallest risk-relevant behavior set; reuse existing fixtures. Invoke when the user wants tests added or coverage raised."
argument-hint: "[file, class, or area]"
---

Generate tests for code in this repository. Derive the technology and test conventions from repository evidence; do not infer .NET from this framework distribution. Follow CLAUDE.md > Conventions > Testing and the test-related Common Tasks recipes.

Match the test level to the **Test shape** heuristic in `docs/defaults.md` (or `CLAUDE.md > Conventions` once bootstrapped). This framework does not mandate test-first for features — but a bug fix or regression test is written **red-first**, and every new behavioral test must be seen to fail before you trust it (Verification Rule #9).

## Input
$ARGUMENTS

If no specific target is given, identify consequential unprotected behavior from recent changes,
known hazards, defects, and branching boundaries; present the shortlist before adding tests. Do not
optimise for a coverage number.

## Execution

### Step 1 — Understand what to test
- Read the target code thoroughly
- Identify the behaviors whose failure would have a meaningful consequence
- Check for existing tests — don't duplicate, extend
- Determine the right test type: unit, integration, or both

### Step 2 — Follow project patterns
- Match the existing test project structure and naming conventions
- Use the same test framework and assertion style as existing tests
- Follow the repo's existing test naming convention; if none exists, use `MethodName_Scenario_ExpectedResult`.
- Use the same mocking approach as the rest of the codebase

### Step 3 — Write tests
For each target:
- **Unit tests**: test behavior, not implementation. Mock external dependencies only.
- **Integration tests**: where repository evidence shows an ASP.NET API, use its established integration-test approach (for example `WebApplicationFactory`) to test the full request/response cycle. Otherwise use the repository's documented integration boundary; do not invent one.
- **SQL/warehouse tests**: where the repository already has dbt tests, tSQLt, data-quality assertions, migration verification, or another SQL test harness, mirror it and assert observable schema/data behavior. If none exists, report the automated test command as **not available**; do not create a .NET test project as a substitute.
- Write the smallest risk-relevant set: the principal behavior plus only consequential error, edge,
  or boundary cases. Do not create one case for every category or public member.
- Do not test framework behavior (e.g., don't test that DI works)
- Mock only true external boundaries; every test needs a real oracle — a return, state change, or thrown exception, never just "the mock was called" or `Assert.True(true)` (Test leanness #14–16)

### Step 4 — Verify
- Derive the exact applicable build, test, format, lint, migration/deploy, and data-validation
  commands from CLAUDE.md, committed CI, scripts, manifests, and configuration. Run only commands
  supported for the changed area; `dotnet build` and `dotnet test` apply only when repository
  evidence proves a .NET project.
- State **not available** for each verification category with no applicable command; never substitute an invented .NET step.
- All applicable new-test commands must pass.
- If a test fails, it's either a bug in the test or a bug in the code. Determine which.

### Step 5 — Report
- What was tested and what test type was used
- What's still not covered (if anything)
- Any bugs discovered while writing tests (this happens — report them)
