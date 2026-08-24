---
description: "Test workflow: follow project conventions; add the smallest risk-relevant behavior set; reuse existing fixtures. Invoke when the user wants tests added or coverage raised."
argument-hint: "[file, class, or area]"
---

Generate tests for code in this repository. Derive the technology and test conventions from repository evidence; do not infer .NET or Angular from this framework distribution. Follow CLAUDE.md > Conventions > Testing and the test-related Common Tasks recipes.

Match the test level to the **Test shape** heuristic in `docs/defaults.md` (or `CLAUDE.md > Conventions` once bootstrapped) — and match the conventions of the **stack under test** (frontend testing in particular is trophy-shaped, component/integration-weighted). This framework does not mandate test-first for features — but a bug fix or regression test is written **red-first**, and every new behavioral test/spec must be seen to fail before you trust it (Verification Rule #9).

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
- Determine the right test type for the stack: unit, component, integration, or e2e (as the stack allows)

### Step 2 — Follow project patterns
- Match the existing test project/file structure and naming conventions of the stack under test
- Use the same test framework and assertion style as existing tests
- Follow that stack's naming convention — .NET: mirror the repo, or use `MethodName_Scenario_ExpectedResult` if none; Angular: `should [expected behavior] when [condition]`
- Use the same mocking approach as the rest of the codebase

### Step 3 — Write tests
For each target, following the stack under test:

**.NET (only where repository evidence proves it):**
- **Unit tests**: test behavior, not implementation. Mock external dependencies only.
- **Integration tests**: where repository evidence shows an ASP.NET API, use its established integration-test approach (for example `WebApplicationFactory`) to test the full request/response cycle. Otherwise use the repository's documented integration boundary; do not invent one.

**Angular (only where repository evidence proves it):**
- **Service tests**: mirror the repository's established HTTP-test setup (for example `provideHttpClientTesting` where evidenced). Verify request URLs, methods, and response handling.
- **Component tests**: mirror the repository's established component-test setup (for example `TestBed` where evidenced). Test observable rendering and user interactions; use component harnesses where already available.
- **Pipe/utility tests**: pure function tests — straightforward input/output.

**SQL/warehouse (only where repository evidence proves it):**
- Mirror an existing dbt, tSQLt, data-quality, migration-verification, or other SQL test harness and assert observable schema/data behavior. If none exists, report the automated test command as **not available**; do not create an application test project as a substitute.

For every target:
- Write the smallest risk-relevant set: the principal behavior plus only consequential error, edge,
  or boundary cases. Do not create one case for every category or public member.
- Do not test framework behavior (e.g., don't test that DI works)
- Mock only true external boundaries; every test/spec needs a real oracle — a return, rendered output, an emitted value, or state change, never just "the mock/spy was called" or `Assert.True(true)` / `expect(true).toBe(true)` (Test leanness #14–16)

### Step 4 — Verify
Derive the exact applicable build, test, format, lint, migration/deploy, and data-validation commands
from CLAUDE.md, committed CI, scripts, manifests, and configuration. Run only commands supported for
the changed area; .NET and Angular commands apply only when repository evidence proves those stacks
are present. State **not available** for each verification category with no applicable command;
never substitute an invented technology step. All applicable new-test commands must pass.
- If a test fails, it's either a bug in the test or a bug in the code. Determine which.

### Step 5 — Report
- What was tested and what test type was used
- What's still not covered (if anything)
- Any bugs discovered while writing tests (this happens — report them)
