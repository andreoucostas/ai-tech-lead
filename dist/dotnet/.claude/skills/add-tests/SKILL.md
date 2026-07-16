---
name: add-tests
description: >
  Use when the user wants to add or improve test coverage for existing .NET code — a service,
  handler, controller, or endpoint that already exists. Covers unit tests (xUnit) and integration
  tests (WebApplicationFactory), behavior-first assertions, and fixture reuse.
  USE FOR: backfilling tests on untested code, adding edge/error-path cases, writing a regression
  test for a bug, raising coverage on a module you're about to change, or pinning the current
  behavior of untested legacy code before a refactor (characterization mode).
  DO NOT USE FOR: scaffolding a brand-new endpoint (use add-endpoint, which already includes its
  tests), or runtime profiling/benchmarking.
---

# Add tests following project patterns

Match `CLAUDE.md > Conventions > Testing` and the Test leanness rules in `CLAUDE.md > Leanness`. If conventions are unbootstrapped, follow `docs/defaults.md`.

1. **Find the existing pattern first.** `Grep` for a sibling test to mirror: framework (xUnit/NUnit/MSTest), mocking library (NSubstitute/Moq), naming convention, and any base fixtures, builders, or `WebApplicationFactory` subclasses. Reuse them — do not introduce parallel test infrastructure (Verification Rule #6, Test leanness #13). If no test project exists at all, switch to **Suite bootstrap mode** below.
2. **Decide the level.** Pure logic / branching → unit test against the concrete class. Full HTTP path (routing, model binding, middleware, auth, serialization) → integration test via `WebApplicationFactory<Program>`.
3. **Cover behavior, not implementation.** Happy path, edge cases, error paths, boundary conditions. Do **not** test getters/setters, DI resolution, or that EF Core/model-binding works (Test leanness #11, #12). Mock only true external boundaries — never the type under test or owned collaborators you can construct cheaply (Test leanness #14). Every test needs a real oracle: assert a return value, state change, or thrown exception — not merely that a mock was called or that `Assert.True(true)` (Test leanness #15–16).
4. **Financial domain**: if the code touches money/balances/ledgers, add cases for decimal precision, negative amounts, duplicate transaction IDs (idempotency), and rounding (`MidpointRounding`). These are the highest-value tests in this codebase.
5. **Arrange-Act-Assert**, one logical assertion focus per test. Descriptive names per the project convention (e.g. `Method_Scenario_ExpectedResult`).
6. **Run** `dotnet test` (scoped to the affected project) and confirm green — then confirm each new test can **fail**. A test you have not watched go red may be over-mocked or tautological (Verification Rule #9): for a regression test, confirm it fails against the unfixed code first; for any other new test, briefly break the code under test (or assert a deliberately wrong value) to see it fail for the right reason, then restore.
7. **Report** what was covered and what remains uncovered — do not claim coverage you didn't add.

---

## Characterization mode — pinning legacy behavior before a refactor

When the goal is to make untested legacy code *safe to change* (e.g. before `/refactor`), you are pinning **what the code currently does**, not asserting what it *should* do. This is different from normal test-writing:

- **Label every test as characterization.** Put this header on the test class/file: `// CHARACTERIZATION — pins OBSERVED behavior, not VERIFIED-correct behavior. A failure may mean the refactor changed behavior, OR that this test pinned a pre-existing bug. Do not "fix" the assertion without human review.`
- **You cannot pin behavior you have not run.** Without an oracle you would be guessing. Generate the test *skeleton* (wire the real dependencies, call the method, capture the result), run it once to obtain the actual values, and assert those. Never invent expected values.
- **Flag every nondeterministic input you had to pin** — `DateTime.Now`/`UtcNow`, `Guid.NewGuid()`, random, file/network/DB I/O — with `// TODO: stub for a stable snapshot` so the developer seals it before relying on the test.
- **HALT on money / safety-critical code.** If it touches `decimal` money, balances, ledgers, idempotency keys, or regulatory figures, STOP before treating any characterization test as a contract: present the captured behavior and ask the developer to confirm it is *correct*, not merely *current*. Pinning a wrong rounding mode or an off-by-one balance as "approved" is a financial-domain hazard — if confirmed wrong-but-load-bearing, record it in `FRAMEWORK-CONTEXT.md > Known Hazard Areas`.
- These tests are scaffolding for a safe refactor, not a substitute for behavior-first tests. Once the intended behavior is understood, prefer real behavioral assertions.

---

## Suite bootstrap mode — when no test project exists

1. **Confirm before scaffolding.** In one message, ask the developer to confirm the test framework and test-project location. Prefer `CLAUDE.md > Conventions > Testing`; if it is unbootstrapped, propose xUnit + NSubstitute. This is a real checkpoint — do not create files until they answer.
2. **Scaffold the minimum.** Create one unit-test project referencing the primary domain/application project and add it to the solution with `dotnet sln add`. Only when the repo exposes an HTTP surface, add one integration fixture using a `WebApplicationFactory<Program>` subclass; minimal APIs may require `public partial class Program` or `InternalsVisibleTo`. Add no E2E project, coverage tooling, or extra test layers on day one.
3. **Wire it so it cannot rot.** Ensure `dotnet test` runs the new project(s) in the repo's existing CI/build, following `docs/ci-integration.md`. If no CI exists, flag that and route CI setup to the `enforce-standards` skill; do not build CI in this task.
4. **Start risk-first, not coverage-first.** Test in this order: `FRAMEWORK-CONTEXT.md > Known Hazard Areas`; financial-domain invariants from step 4 above when present; critical journeys from `CLAUDE.md > Codebase Context`; then pure domain logic with branching. Write only a handful that prove the harness end to end, and apply step 6's red-check to every test.
5. **Record the remainder honestly.** Add one `TECH_DEBT.md` entry: `Test suite bootstrapped <date>; backfill areas: …`. Do not imply broader coverage. Update `CLAUDE.md > Conventions > Testing` with the real framework, naming, and fixture location, and flag that documentation drift under Agentic Workflow §6.
