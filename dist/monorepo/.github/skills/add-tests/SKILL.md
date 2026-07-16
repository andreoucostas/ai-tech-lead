---
name: add-tests
description: >
  Use when the user wants to add or improve test coverage for existing code in this mixed
  .NET + Angular codebase — on the .NET side a service, handler, controller, or endpoint; on the
  Angular side a component, service, signal store, pipe, guard, or interceptor that already exists.
  Covers .NET unit tests (xUnit) and integration tests (WebApplicationFactory), Angular spec
  structure (TestBed, HttpTestingController, component harnesses, signal/store state-transition
  tests), and behavior-first assertions on both.
  USE FOR: backfilling tests on untested code, adding edge/error-path cases, writing a regression
  test for a bug, raising coverage on an area you're about to change, or pinning the current
  behavior of untested legacy code before a refactor (characterization mode).
  DO NOT USE FOR: scaffolding a brand-new endpoint (use add-endpoint) or a brand-new
  component/service (use add-component/add-service) — those include their own tests — or e2e flows
  (use the project's Cypress/Playwright setup directly).
---

# Add tests following project patterns

Match `CLAUDE.md > Conventions > Testing` and the Test leanness rules in `CLAUDE.md > Leanness`. If conventions are unbootstrapped, follow `docs/defaults.md`. Apply the section for the stack of the code under test.

1. **Find the existing pattern first.** `Grep` for a sibling test to mirror, and reuse what you find — do not introduce parallel test infrastructure (Verification Rule #6, Test leanness #13).
   - **.NET:** a sibling test class — framework (xUnit/NUnit/MSTest), mocking library (NSubstitute/Moq), naming convention, and any base fixtures, builders, or `WebApplicationFactory` subclasses.
   - **Angular:** a sibling `*.spec.ts` — runner (Karma/Jasmine, Jest, or Vitest), `TestBed` setup, `HttpTestingController` usage, component harnesses, and any shared fixtures/builders/HTTP mocks.
   - If no test project or spec files exist at all for the touched stack, switch to **Suite bootstrap mode** below.
2. **Decide the level.**
   - **.NET:** Pure logic / branching → unit test against the concrete class. Full HTTP path (routing, model binding, middleware, auth, serialization) → integration test via `WebApplicationFactory<Program>`.
   - **Angular:**
     - **Service / signal store**: instantiate via `TestBed.inject`; mock HTTP with `HttpTestingController`; for stores, assert **state transitions** (input → resulting signal/computed values), not getters.
     - **Component**: prefer the component's public behavior via a harness or DOM query over inspecting internals. Mock injected services via `{ provide, useValue }`.
     - **Pipe / guard / interceptor**: test the transform / decision / passthrough directly.
3. **Cover behavior, not implementation.** Happy path, edge cases, error paths, boundary conditions. Mock only true external boundaries — never the type under test or owned collaborators you can construct cheaply (Test leanness #14). Every test needs a real oracle: a return value, state change, rendered output, emitted value, or thrown exception — not merely that a mock/spy was called or a tautology like `Assert.True(true)` / `expect(true).toBe(true)` (Test leanness #15–16).
   - **.NET:** Do **not** test getters/setters, DI resolution, or that EF Core/model-binding works (Test leanness #11, #12).
   - **Angular:** Do **not** test that `@Input` binds, that `Router.navigate` works, or that change detection runs (Test leanness #11, #12); mock external boundaries (HTTP via `HttpTestingController`, time, storage) but render the real template for component behavior. Include failed-HTTP and empty/loading-state error paths.
4. **Arrange-Act-Assert**, one logical assertion focus per test. Descriptive names per the project convention (e.g. .NET `Method_Scenario_ExpectedResult`).
5. **Financial domain (.NET backend)**: if the code touches money/balances/ledgers, add cases for decimal precision, negative amounts, duplicate transaction IDs (idempotency), and rounding (`MidpointRounding`). These are the highest-value tests in this codebase.
6. **Async (Angular)**: use `fakeAsync`/`tick` or `await whenStable()` per the project's convention; flush `HttpTestingController` and `verify()` no outstanding requests.
7. **Run** the touched stack's tests (scoped to the affected project where supported) and confirm green — then confirm each new test can **fail**. .NET: `dotnet test`; Angular: `ng test --watch=false --browsers=ChromeHeadless`. A test you have not watched go red may be over-mocked or tautological (Verification Rule #9): for a regression test, confirm it fails against the unfixed code first; for any other new test, briefly break the code under test (or assert a deliberately wrong value) to see it fail for the right reason, then restore.
8. **Report** what was covered and what remains uncovered — do not claim coverage you didn't add.

---

## Characterization mode — pinning legacy behavior before a refactor

When the goal is to make untested legacy code *safe to change* (e.g. before `/refactor`), you are pinning **what the code currently does**, not asserting what it *should* do. This is different from normal test-writing:

- **Label every test as characterization.** Put this header on the test class/file (.NET) or spec / `describe` (Angular): `// CHARACTERIZATION — pins OBSERVED behavior, not VERIFIED-correct behavior. A failure may mean the refactor changed behavior, OR that this test pinned a pre-existing bug. Do not "fix" the assertion without human review.`
- **You cannot pin behavior you have not run.** Without an oracle you would be guessing. Generate the test *skeleton*, run it once to obtain the actual values, and assert those — never invent expected values.
  - **.NET:** wire the real dependencies, call the method, capture the result.
  - **Angular:** configure `TestBed`, drive the component/service, capture emitted values / rendered output via `HttpTestingController` and harnesses.
- **Flag every nondeterministic input you had to pin** with `// TODO: stub for a stable snapshot` so the developer seals it before relying on the test.
  - **.NET:** `DateTime.Now`/`UtcNow`, `Guid.NewGuid()`, random, file/network/DB I/O.
  - **Angular:** `Date.now()`/`new Date()`, `Math.random()`, timers/`setTimeout`, animation timing, real HTTP (fake the clock, flush `HttpTestingController`).
- **HALT on money- / security-sensitive code.** If it touches `decimal` money, balances, ledgers, idempotency keys, or regulatory figures (.NET), or auth, tokens, sanitisation / `bypassSecurityTrust*`, PII, or monetary values (Angular), STOP before treating any characterization test as a contract: present the captured behavior and ask the developer to confirm it is *correct*, not merely *current*. Pinning a wrong rounding mode, an off-by-one balance, or an insecure behavior as "approved" is a hazard — if confirmed wrong-but-load-bearing, record it in `FRAMEWORK-CONTEXT.md > Known Hazard Areas`.
- These tests are scaffolding for a safe refactor, not a substitute for behavior-first tests. Once the intended behavior is understood, prefer real behavioral assertions.

---

## Suite bootstrap mode — when a stack has no tests

1. **Confirm before scaffolding.** In one message, ask the developer to confirm the test framework and location. Prefer `CLAUDE.md > Conventions > Testing`. If unbootstrapped, propose xUnit + NSubstitute for .NET; for Angular, inspect `angular.json` and propose the workspace's configured builder and runner (Jasmine/Karma or Jest). This is a real checkpoint — do not create files until they answer.
2. **Scaffold the minimum.**
   - **.NET:** create one unit-test project referencing the primary domain/application project and add it with `dotnet sln add`. Only for an HTTP surface, add one `WebApplicationFactory<Program>` fixture; minimal APIs may require `public partial class Program` or `InternalsVisibleTo`.
   - **Angular:** keep specs colocated and create only the configuration and shared setup needed for `ng test`; add one integration-style fixture only for an HTTP surface.
   - Add no E2E project, coverage tooling, or extra test layers on day one.
3. **Wire it so it cannot rot.** Ensure the repo's existing CI/build runs the new tests: .NET `dotnet test`; Angular `ng test --watch=false`. Follow `docs/ci-integration.md`. If no CI exists, flag it and route setup to the `enforce-standards` skill; do not build CI in this task.
4. **Start risk-first, not coverage-first.** Test in this order: `FRAMEWORK-CONTEXT.md > Known Hazard Areas`; financial-domain invariants from step 5 above when present; critical journeys from `CLAUDE.md > Codebase Context`; then pure domain logic or state transitions with branching. Write only a handful that prove the harness end to end, and apply step 7's red-check to every test.
5. **Record the remainder honestly.** Add one `TECH_DEBT.md` entry: `Test suite bootstrapped <date>; backfill areas: …`. Do not imply broader coverage. Update `CLAUDE.md > Conventions > Testing` with the real framework, naming, and fixture location, and flag that documentation drift under Agentic Workflow §6.
