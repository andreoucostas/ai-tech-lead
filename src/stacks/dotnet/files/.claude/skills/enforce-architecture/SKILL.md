---
name: enforce-architecture
description: >
  Use to wire the DETERMINISTIC backstop for SOLID's Dependency Inversion and layering — fail the
  build on dependency-direction violations using a NetArchTest test project.
  USE FOR: "enforce architecture/layering in CI", "add NetArchTest", making DIP / Clean-Architecture
  rules build-breaking rather than review-only.
  DO NOT USE FOR: the semantic SOLID review of a diff — that is the `solid-check` agent / `/review`.
---

# Enforce architecture deterministically (.NET — NetArchTest)

`solid-check` covers SOLID semantically per diff; this makes the *structural* part (DIP / dependency direction) a **build-breaking** CI gate. Pairs with `CLAUDE.md > SOLID`.

1. **Test project**: add NetArchTest to an existing test project if one exists (Leanness — don't create a parallel project); otherwise add `tests/ArchitectureTests/ArchitectureTests.csproj` referencing `NetArchTest.Rules` + the projects to govern.
2. **Rules**: copy `scripts/ci/ArchitectureTests.sample.cs` and adjust the namespaces to this solution. Cover at least:
   - Domain has **no** dependency on Application / Infrastructure / API (inward-only).
   - Application does not depend on Infrastructure / API.
   - (Optional, where detectable) controllers/handlers depend on service **interfaces**, not concretes — supports DIP.
3. **CI**: it runs under `dotnet test`, so ensure the architecture project is in the solution / test run. On Bitbucket Data Center, that's your Bamboo/Jenkins/pipeline `dotnet test` step (no GitHub Actions).
4. **Don't weaken rules to go green** — record current violations in `TECH_DEBT.md` (Category: Architecture) and burn them down via the Trojan Horse.
