---
name: enforce-architecture
description: >
  Use to wire the DETERMINISTIC backstop for SOLID's Dependency Inversion and layering — fail the
  build on dependency-direction violations. For repository-evidenced .NET and/or Angular code,
  that can mean NetArchTest on the .NET side and dependency-cruiser on the Angular side.
  USE FOR: "enforce architecture/layering in CI", "add NetArchTest", "add dependency-cruiser",
  making DIP / Clean-Architecture / feature-boundary rules build-breaking rather than review-only.
  DO NOT USE FOR: the semantic SOLID review of a diff — that is the `solid-check` agent / `/review`.
---

# Enforce architecture deterministically

`solid-check` covers SOLID semantically per diff; this makes the *structural* part (DIP / dependency direction) a **build-breaking** CI gate. Pairs with the framework rules (`.github/instructions/framework-rules.instructions.md` › SOLID; `AGENTS.md` › SOLID on AGENTS.md-native tools). First identify applicable ecosystems from committed manifests and configuration, then apply only their section below. A repo-wide hardening covers every evidenced ecosystem; the monorepo delivery profile alone proves neither is present.

### .NET — NetArchTest

1. **Test project**: add NetArchTest to an existing test project if one exists (Leanness — don't create a parallel project); otherwise add `tests/ArchitectureTests/ArchitectureTests.csproj` referencing `NetArchTest.Rules` + the projects to govern.
2. **Rules**: copy `scripts/ci/ArchitectureTests.sample.cs`, translate it to the repo's existing
   test framework if that is not xUnit, and adjust the namespaces to this repository's project graph. Cover at least:
   - Domain has **no** dependency on Application / Infrastructure / API (inward-only).
   - Application does not depend on Infrastructure / API.
   - (Optional, where detectable) controllers/handlers depend on service **interfaces**, not concretes — supports DIP.
3. **CI**: derive the exact scoped command that runs the new architecture project in this repo
   (for example a targeted `dotnet test` when that is the established runner), record it under
   `CLAUDE.md > Conventions > Verification Commands`, and put that exact command in the required
   build. Do not assume a solution-level invocation or add the project to a nonexistent solution.

### Angular — dependency-cruiser

Enter this branch only when manifests/configuration evidence Angular. Derive the package manager,
install syntax, source roots, script invocation, and CI command from committed repository evidence;
the monorepo profile does not prove npm, `src`, or any exact command.

1. **Install**: add `dependency-cruiser` with the evidenced package manager's development-dependency
   command. If no package manager/install command is evidenced, report it **not available** and stop.
2. **Config**: copy `scripts/ci/dependency-cruiser.sample.js` to `.dependency-cruiser.js` at the repo root and adjust the globs to this project's evidenced layering and source roots (core/shared vs features; no feature→feature imports; no deep cross-boundary imports).
3. **Script + CI**: add a package script targeting those evidenced roots, then put its exact
   repository-evidenced invocation in the repository's Bamboo/Jenkins/pipeline step.

**Don't weaken rules to go green** in any applicable ecosystem — record current violations in `TECH_DEBT.md` (Category: Architecture) and burn them down via the Trojan Horse.

Finally derive applicable build, test, format, lint, migration/deploy, and data-validation commands
from repository evidence; run only applicable commands and report every unsupported category as
**not available**.
