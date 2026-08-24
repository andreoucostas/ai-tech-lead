---
name: enforce-architecture
description: >
  Use to wire the DETERMINISTIC backstop for SOLID's Dependency Inversion and layering — fail CI on
  module / layer / feature dependency-direction violations using dependency-cruiser.
  USE FOR: "enforce layering/boundaries in CI", "add dependency-cruiser", making DIP / feature-boundary
  rules build-breaking rather than review-only.
  DO NOT USE FOR: the semantic SOLID review of a diff — that is the `solid-check` agent / `/review`.
---

# Enforce architecture deterministically (evidenced Angular only)

`solid-check` covers SOLID semantically per diff; this makes the *structural* part (layer / feature dependency direction) a **build-breaking** CI gate. Pairs with the framework rules (`.github/instructions/framework-rules.instructions.md` › SOLID; `AGENTS.md` › SOLID on AGENTS.md-native tools).

1. **Applicability**: proceed only when manifests/configuration evidence an Angular workspace. If it
   is absent, report **not applicable** and change nothing. Derive the package manager, install
   syntax, source roots, script invocation, and CI command from committed repository evidence; the
   delivery profile does not prove npm, a `src` root, or any exact command.
2. **Install**: add `dependency-cruiser` with the evidenced package manager's development-dependency
   command. If no package manager/install command is evidenced, report it **not available** and stop.
3. **Config**: copy `scripts/ci/dependency-cruiser.sample.js` to `.dependency-cruiser.js` at the repo root and adjust the globs to this project's evidenced layering and source roots (core/shared vs features; no feature→feature imports; no deep cross-boundary imports).
4. **Script + CI**: add a package script whose command targets those evidenced roots, then put the
   exact repository-evidenced invocation in CI so violations fail the build. On Bitbucket Data
   Center, that is the repository's Bamboo/Jenkins/pipeline step, not an invented GitHub Action.
5. **Verification inventory**: derive applicable build, test, format, lint, migration/deploy, and
   data-validation commands from repository evidence; run only applicable commands and report each
   unsupported category as **not available**.
6. **Don't weaken rules to go green** — record current violations in `TECH_DEBT.md` (Category: Architecture) and burn them down via the Trojan Horse.
