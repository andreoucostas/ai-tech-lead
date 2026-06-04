---
name: add-tests
description: >
  Use when the user wants to add or improve test coverage for existing Angular code — a component,
  service, signal store, pipe, guard, or interceptor that already exists. Covers spec structure,
  TestBed, HttpTestingController, component harnesses, signal/store state-transition tests, and
  behavior-first assertions.
  USE FOR: backfilling tests on untested code, adding edge/error-path cases, writing a regression
  test for a bug, raising coverage on an area you're about to change.
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
3. **Cover behavior, not implementation.** Happy path, edge cases, error paths (failed HTTP, empty/loading states), boundary conditions. Do **not** test that `@Input` binds, that `Router.navigate` works, or that change detection runs (Test leanness #11, #12).
4. **Async**: use `fakeAsync`/`tick` or `await whenStable()` per the project's convention; flush `HttpTestingController` and `verify()` no outstanding requests.
5. **Run** `ng test --watch=false --browsers=ChromeHeadless` (scoped if the project supports it) and confirm green. For a regression test, confirm it **fails** against the unfixed code first, then passes after the fix.
6. **Report** what was covered and what remains uncovered — do not claim coverage you didn't add.
