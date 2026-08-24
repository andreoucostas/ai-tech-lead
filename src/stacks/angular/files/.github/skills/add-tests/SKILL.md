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
  assess tests only against an evidenced harness), or e2e flows (use the project's
  Cypress/Playwright setup directly).
---

# Add tests following project patterns

Match `CLAUDE.md > Conventions > Testing` and the Test leanness rules in the framework rules (`.github/instructions/framework-rules.instructions.md` › Leanness; `AGENTS.md` › Leanness on AGENTS.md-native tools). If conventions are unbootstrapped, follow `docs/defaults.md`.

**Applicability gate:** confirm a repository-evidenced Angular workspace and that the code under
test belongs to it. If either is absent, report this skill as **not applicable**; suite bootstrap
remains available only after the explicit developer agreement below.

1. **Evidence gate — derive, don't assume.** Apply Verification Rule #10 before writing a spec:
   inspect `angular.json` and test configuration, then `Grep` a sibling `*.spec.ts`. Detect the
   runner, assertion style, naming convention, `TestBed` setup, `HttpTestingController` usage,
   component harnesses, and shared fixtures/builders/HTTP mocks. Mirror everything found; never
   introduce a second runner or parallel infrastructure (Verification Rule #6, Test leanness #13).
   If nothing is found anywhere in the workspace, switch to **Suite bootstrap mode** below.
2. **Decide the level and approach.**
   - **Service / signal store**: instantiate via `TestBed.inject`; mock HTTP with `HttpTestingController`; for stores, assert **state transitions** (input → resulting signal/computed values), not getters.
   - **Component**: prefer the component's public behavior via a harness or DOM query over inspecting internals. Mock injected services via `{ provide, useValue }`.
   - **Pipe / guard / interceptor**: test the transform / decision / passthrough directly.
3. **Cover behavior, not implementation.** Choose the smallest risk-relevant set: the principal behavior plus only consequential error, edge, or boundary cases (such as failed HTTP or empty/loading state when they materially change behavior). Do not create one spec per category or public member. Do **not** test that `@Input` binds, that `Router.navigate` works, or that change detection runs (Test leanness #11, #12). Mock only true external boundaries (HTTP via `HttpTestingController`, time, storage) — never the component/service under test or owned collaborators you can provide cheaply; render the real template for component behavior (Test leanness #14). Every spec needs a real oracle: assert rendered output, an emitted value, or state — not merely that a spy was called or that `expect(true).toBe(true)` (Test leanness #15–16).
4. **Async**: use `fakeAsync`/`tick` or `await whenStable()` per the project's convention; flush `HttpTestingController` and `verify()` no outstanding requests.
5. **Run** the exact scoped test command supported by `CLAUDE.md > Conventions > Verification Commands`, committed CI, scripts, manifests, and runner configuration; do not infer Angular CLI, a browser, or flags. Confirm green, then confirm each new spec can **fail**. A spec you have not watched go red may be over-mocked or tautological (Verification Rule #9): for a regression test, confirm it fails against the unfixed code first; for any other new spec, briefly break the code under test (or assert a deliberately wrong value) to see it fail for the right reason, then restore. If no executable command is evidenced, report tests as **not available** rather than claiming a pass.
6. **Report** what was covered and what remains uncovered — do not claim coverage you didn't add.

---

## Characterization mode — pinning legacy behavior before a refactor

When the goal is to make untested legacy code *safe to change* (e.g. before `/refactor`), you are pinning **what the code currently does**, not asserting what it *should* do. This is different from normal spec-writing:

- **Label every spec as characterization.** Put this header on the spec / `describe`: `// CHARACTERIZATION — pins OBSERVED behavior, not VERIFIED-correct behavior. A failure may mean the refactor changed behavior, OR that this spec pinned a pre-existing bug. Do not "fix" the expectation without human review.`
- **You cannot pin behavior you have not run.** Generate the spec *skeleton* (configure `TestBed`, drive the component/service, capture emitted values / rendered output via `HttpTestingController` and harnesses), run it once to obtain the actual values, and assert those. Never invent expected values.
- **Flag every nondeterministic input you had to pin** — `Date.now()`/`new Date()`, `Math.random()`, timers/`setTimeout`, animation timing, real HTTP — with `// TODO: stub for a stable snapshot` (fake the clock, flush `HttpTestingController`) so the developer seals it.
- **HALT on security- / money-sensitive code.** If it touches auth, tokens, sanitisation / `bypassSecurityTrust*`, PII, or monetary values, STOP before treating any characterization spec as a contract: present the captured behavior and ask the developer to confirm it is *correct*, not merely *current*. Pinning an insecure or wrong behavior as "approved" is a hazard — if confirmed wrong-but-load-bearing, record it in `FRAMEWORK-CONTEXT.md > Known Hazard Areas`.
- These specs are scaffolding for a safe refactor, not a substitute for behavior-first tests. Once the intended behavior is understood, prefer real behavioral assertions.

---

## Suite bootstrap mode — when no spec files exist

1. **Confirm before scaffolding.** In one message, ask the developer to confirm the test framework and spec location. Prefer `CLAUDE.md > Conventions > Testing`; if it is unbootstrapped, inspect `angular.json` and propose the workspace's configured builder and runner (Jasmine/Karma or Jest). This is a real checkpoint — do not create files until they answer.
2. **Scaffold the minimum.** Keep specs colocated and create only the configuration and shared setup needed for the developer-confirmed runner to execute. Add one integration-style fixture only when the app exposes an HTTP surface. Add no E2E project, coverage tooling, or extra test layers on day one.
3. **Wire it so it cannot rot.** Record the new exact test command in `CLAUDE.md > Conventions > Verification Commands` and ensure the repo's existing CI/build runs it, following `docs/ci-integration.md`. If no CI exists, flag that and route CI setup to the `enforce-standards` skill; do not build CI in this task.
4. **Start risk-first, not coverage-first.** Test in this order: `FRAMEWORK-CONTEXT.md > Known Hazard Areas`; financial-domain invariants when present; critical journeys from `CLAUDE.md > Codebase Context`; then pure domain logic and state transitions with branching. Write only a handful that prove the harness end to end, and apply step 5's red-check to every spec.
5. **Record the remainder honestly.** Add one `TECH_DEBT.md` entry: `Test suite bootstrapped <date>; backfill areas: …`. Do not imply broader coverage. Update `CLAUDE.md > Conventions > Testing` with the real framework, naming, and fixture location, and flag that documentation drift under Agentic Workflow §6.
