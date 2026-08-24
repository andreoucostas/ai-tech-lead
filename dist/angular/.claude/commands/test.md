---
description: "Test workflow: follow project conventions; add the smallest risk-relevant behavior set; reuse existing fixtures. Invoke when the user wants tests added or coverage raised."
argument-hint: "[file, class, or area]"
---

Generate tests for code in this repository. Derive its technology and test conventions from repository evidence; do not infer Angular from this framework distribution. Follow CLAUDE.md > Conventions > Testing and the test-related Common Tasks recipes.

Match the test level to the **Test shape** heuristic in `docs/defaults.md` (or `CLAUDE.md > Conventions` once bootstrapped) — frontend testing is trophy-shaped (component/integration-weighted). This framework does not mandate test-first for features — but a bug fix or regression test is written **red-first**, and every new behavioral spec must be seen to fail before you trust it (Verification Rule #9).

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
- Determine the right test type: unit, component, integration, or e2e

### Step 2 — Follow project patterns
- Match the existing test file structure and naming conventions
- Use the same test framework and assertion style as existing tests
- Follow the repository's existing naming convention; if the repository demonstrates Angular specs and no local convention, `should [expected behavior] when [condition]` is an acceptable fallback.
- Use the same mocking approach as the rest of the codebase

### Step 3 — Write tests
For each target:
- **Service tests**: where repository evidence shows Angular HTTP services, use its established HTTP-test approach (for example `HttpClientTestingModule` / `provideHttpClientTesting`). Verify request URLs, methods, and response handling.
- **Component tests**: where repository evidence shows Angular components, use its established component-test approach (for example `TestBed`) to test template rendering, input/output binding, and user interactions.
- **Pipe/utility tests**: where applicable, use straightforward input/output tests.
- Write the smallest risk-relevant set: the principal behavior plus only consequential error, edge,
  or boundary cases. Do not create one case for every category or public member.
- Do not test framework behavior (for example, don't test that DI works)
- Mock only true external boundaries; every spec needs a real oracle — rendered output, an emitted value, or state, never just "the spy was called" or `expect(true).toBe(true)` (Test leanness #14–16)

### Step 4 — Verify
- Derive exact applicable build, test, format, lint, migration/deploy, and data-validation commands
  from CLAUDE.md, committed CI, scripts, manifests, and configuration. Run only commands supported
  for the changed area; `ng build`, `ng test`, and browser selection apply only when repository
  evidence proves the configured Angular targets.
- State **not available** for each verification category with no applicable command; never substitute an invented Angular step.
- All applicable new-test commands must pass.
- If a test fails, it's either a bug in the test or a bug in the code. Determine which.

### Step 5 — Report
- What was tested and what test type was used
- What's still not covered (if anything)
- Any bugs discovered while writing tests (this happens — report them)
