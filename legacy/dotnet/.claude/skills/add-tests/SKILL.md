---
name: add-tests
description: >
  Use when the user wants to add or improve test coverage for existing .NET code — a service,
  handler, controller, or endpoint that already exists. Covers unit tests (xUnit) and integration
  tests (WebApplicationFactory), behavior-first assertions, and fixture reuse.
  USE FOR: backfilling tests on untested code, adding edge/error-path cases, writing a regression
  test for a bug, raising coverage on a module you're about to change.
  DO NOT USE FOR: scaffolding a brand-new endpoint (use add-endpoint, which already includes its
  tests), or runtime profiling/benchmarking.
---

# Add tests following project patterns

Match `CLAUDE.md > Conventions > Testing` and the Test leanness rules in `CLAUDE.md > Leanness`. If conventions are unbootstrapped, follow `docs/defaults.md`.

1. **Find the existing pattern first.** `Grep` for a sibling test to mirror: framework (xUnit/NUnit/MSTest), mocking library (NSubstitute/Moq), naming convention, and any base fixtures, builders, or `WebApplicationFactory` subclasses. Reuse them — do not introduce parallel test infrastructure (Verification Rule #6, Test leanness #13).
2. **Decide the level.** Pure logic / branching → unit test against the concrete class. Full HTTP path (routing, model binding, middleware, auth, serialization) → integration test via `WebApplicationFactory<Program>`.
3. **Cover behavior, not implementation.** Happy path, edge cases, error paths, boundary conditions. Do **not** test getters/setters, DI resolution, or that EF Core/model-binding works (Test leanness #11, #12).
4. **Financial domain**: if the code touches money/balances/ledgers, add cases for decimal precision, negative amounts, duplicate transaction IDs (idempotency), and rounding (`MidpointRounding`). These are the highest-value tests in this codebase.
5. **Arrange-Act-Assert**, one logical assertion focus per test. Descriptive names per the project convention (e.g. `Method_Scenario_ExpectedResult`).
6. **Run** `dotnet test` (scoped to the affected project) and confirm green. For a regression test, confirm it **fails** against the unfixed code first, then passes after the fix.
7. **Report** what was covered and what remains uncovered — do not claim coverage you didn't add.
