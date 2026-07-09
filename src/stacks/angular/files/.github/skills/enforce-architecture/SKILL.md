---
name: enforce-architecture
description: >
  Use to wire the DETERMINISTIC backstop for SOLID's Dependency Inversion and layering — fail CI on
  module / layer / feature dependency-direction violations using dependency-cruiser.
  USE FOR: "enforce layering/boundaries in CI", "add dependency-cruiser", making DIP / feature-boundary
  rules build-breaking rather than review-only.
  DO NOT USE FOR: the semantic SOLID review of a diff — that is the `solid-check` agent / `/review`.
---

# Enforce architecture deterministically (Angular — dependency-cruiser)

`solid-check` covers SOLID semantically per diff; this makes the *structural* part (layer / feature dependency direction) a **build-breaking** CI gate. Pairs with `CLAUDE.md > SOLID`.

1. **Install**: `npm i -D dependency-cruiser`.
2. **Config**: copy `scripts/ci/dependency-cruiser.sample.js` to `.dependency-cruiser.js` at the repo root and adjust the globs to this project's layering (core/shared vs features; no feature→feature imports; no deep cross-boundary imports).
3. **npm script + CI**: add `"depcruise": "depcruise src --config .dependency-cruiser.js"` and run it in CI so violations fail the build. On Bitbucket Data Center, that's your Bamboo/Jenkins/pipeline step (no GitHub Actions).
4. **Don't weaken rules to go green** — record current violations in `TECH_DEBT.md` (Category: Architecture) and burn them down via the Trojan Horse.
