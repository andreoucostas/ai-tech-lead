---
name: add-tests
description: >
  Use when the user wants to add or improve test coverage for existing Angular code — a component,
  service, signal store, pipe, guard, or interceptor that already exists. Covers spec structure,
  TestBed, HttpTestingController, component harnesses, signal/store state-transition tests, and
  behavior-first assertions.
  USE FOR: backfilling tests on untested code, adding edge/error-path cases, writing a regression
  test for a bug, raising coverage on an area you're about to change, or pinning the current
  behavior of untested legacy code before a refactor (characterization mode).
  DO NOT USE FOR: scaffolding a brand-new component/service (use add-component/add-service, which
  include their tests), or e2e flows (use the project's Cypress/Playwright setup directly).
---

# Add tests following project patterns

Match `CLAUDE.md > Conventions > Testing` and the Test leanness rules in `CLAUDE.md > Leanness`. If conventions are unbootstrapped, follow `docs/defaults.md`.

1. **Find the existing pattern first.** `Grep` for a sibling `*.spec.ts` to mirror: runner (Karma/Jasmine, Jest, or Vitest), `TestBed` setup, `HttpTestingController` usage, component harnesses, and any shared fixtures/builders/HTTP mocks. Reuse them — do not introduce parallel test infrastructure (Verification Rule #6, Test leanness #13).
2. **Decide the level and approach.**
   - **Service / signal store**: instantiate via `TestBed.inject`; mock HTTP with `HttpTestingController`; for stores, assert **state transitions** (input → resulting signal/computed values), not getters.
   - **Component**: prefer the component's public behavior via a harness or DOM query over inspecting internals. Mock injected services via `{ provide, useValue }`.
   - **Pipe / guard / interceptor**: test the transform / decision / passthrough directly.
3. **Cover behavior, not implementation.** Happy path, edge cases, error paths (failed HTTP, empty/loading states), boundary conditions. Do **not** test that `@Input` binds, that `Router.navigate` works, or that change detection runs (Test leanness #11, #12). Mock only true external boundaries (HTTP via `HttpTestingController`, time, storage) — never the component/service under test or owned collaborators you can provide cheaply; render the real template for component behavior (Test leanness #14). Every spec needs a real oracle: assert rendered output, an emitted value, or state — not merely that a spy was called or that `expect(true).toBe(true)` (Test leanness #15–16).
4. **Async**: use `fakeAsync`/`tick` or `await whenStable()` per the project's convention; flush `HttpTestingController` and `verify()` no outstanding requests.
5. **Run** `ng test --watch=false --browsers=ChromeHeadless` (scoped if the project supports it) and confirm green — then confirm each new spec can **fail**. A spec you have not watched go red may be over-mocked or tautological (Verification Rule #9): for a regression test, confirm it fails against the unfixed code first; for any other new spec, briefly break the code under test (or assert a deliberately wrong value) to see it fail for the right reason, then restore.
6. **Report** what was covered and what remains uncovered — do not claim coverage you didn't add.

---

## Characterization mode — pinning legacy behavior before a refactor

When the goal is to make untested legacy code *safe to change* (e.g. before `/refactor`), you are pinning **what the code currently does**, not asserting what it *should* do. This is different from normal spec-writing:

- **Label every spec as characterization.** Put this header on the spec / `describe`: `// CHARACTERIZATION — pins OBSERVED behavior, not VERIFIED-correct behavior. A failure may mean the refactor changed behavior, OR that this spec pinned a pre-existing bug. Do not "fix" the expectation without human review.`
- **You cannot pin behavior you have not run.** Generate the spec *skeleton* (configure `TestBed`, drive the component/service, capture emitted values / rendered output via `HttpTestingController` and harnesses), run it once to obtain the actual values, and assert those. Never invent expected values.
- **Flag every nondeterministic input you had to pin** — `Date.now()`/`new Date()`, `Math.random()`, timers/`setTimeout`, animation timing, real HTTP — with `// TODO: stub for a stable snapshot` (fake the clock, flush `HttpTestingController`) so the developer seals it.
- **HALT on security- / money-sensitive code.** If it touches auth, tokens, sanitisation / `bypassSecurityTrust*`, PII, or monetary values, STOP before treating any characterization spec as a contract: present the captured behavior and ask the developer to confirm it is *correct*, not merely *current*. Pinning an insecure or wrong behavior as "approved" is a hazard — if confirmed wrong-but-load-bearing, record it in `FRAMEWORK-CONTEXT.md > Known Hazard Areas`.
- These specs are scaffolding for a safe refactor, not a substitute for behavior-first tests. Once the intended behavior is understood, prefer real behavioral assertions.
