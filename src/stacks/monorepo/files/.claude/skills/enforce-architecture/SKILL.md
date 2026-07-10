---
name: enforce-architecture
description: >
  Use to wire the DETERMINISTIC backstop for SOLID's Dependency Inversion and layering — fail the
  build on dependency-direction violations. In this mixed .NET + Angular codebase that means a
  NetArchTest test project on the .NET side and dependency-cruiser on the Angular side.
  USE FOR: "enforce architecture/layering in CI", "add NetArchTest", "add dependency-cruiser",
  making DIP / Clean-Architecture / feature-boundary rules build-breaking rather than review-only.
  DO NOT USE FOR: the semantic SOLID review of a diff — that is the `solid-check` agent / `/review`.
---

# Enforce architecture deterministically (.NET + Angular)

`solid-check` covers SOLID semantically per diff; this makes the *structural* part (DIP / dependency direction) a **build-breaking** CI gate. Pairs with `CLAUDE.md > SOLID`. This repo has two stacks and wires **both** backstops — apply the section for the stack whose layering you are governing (a repo-wide hardening does both).

### .NET — NetArchTest

1. **Test project**: add NetArchTest to an existing test project if one exists (Leanness — don't create a parallel project); otherwise add `tests/ArchitectureTests/ArchitectureTests.csproj` referencing `NetArchTest.Rules` + the projects to govern.
2. **Rules**: copy `scripts/ci/ArchitectureTests.sample.cs` and adjust the namespaces to this solution. Cover at least:
   - Domain has **no** dependency on Application / Infrastructure / API (inward-only).
   - Application does not depend on Infrastructure / API.
   - (Optional, where detectable) controllers/handlers depend on service **interfaces**, not concretes — supports DIP.
3. **CI**: it runs under `dotnet test`, so ensure the architecture project is in the solution / test run. On Bitbucket Data Center, that's your Bamboo/Jenkins/pipeline `dotnet test` step (no GitHub Actions).

### Angular — dependency-cruiser

1. **Install**: `npm i -D dependency-cruiser`.
2. **Config**: copy `scripts/ci/dependency-cruiser.sample.js` to `.dependency-cruiser.js` at the repo root and adjust the globs to this project's layering (core/shared vs features; no feature→feature imports; no deep cross-boundary imports).
3. **npm script + CI**: add `"depcruise": "depcruise src --config .dependency-cruiser.js"` and run it in CI so violations fail the build. On Bitbucket Data Center, that's your Bamboo/Jenkins/pipeline step (no GitHub Actions).

**Don't weaken rules to go green** (either stack) — record current violations in `TECH_DEBT.md` (Category: Architecture) and burn them down via the Trojan Horse.
