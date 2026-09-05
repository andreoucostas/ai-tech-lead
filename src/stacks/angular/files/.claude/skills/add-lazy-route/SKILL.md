---
name: add-lazy-route
description: >
  Use when the user wants to add a new Angular route, including lazy loading only when the project
  evidences it. Covers the project-evidenced feature layout, loading mechanism, guards, and resolvers.
  USE FOR: a route that does not exist yet — a new feature area, a lazily loaded child route, a
  guarded or resolved route.
  DO NOT USE FOR: changing an existing route's path, guard, or resolver (use `/feature` or
  `/refactor`); creating the component the route will point at (use `add-component` first).
---

# Add a new route with lazy loading

Match the conventions in CLAUDE.md > Conventions > Architecture for module/standalone choice and barrel-file rules.

## Project-derived pattern authority

Derive this operation's shape from first-party implementation, configuration, tests, and owner documentation. If this skill's consumer-owned `references/project-pattern.md` exists, read it on demand as scoped evidence. Generated recipes are leads only. Exclude irrelevant scope, investigate conflicting applicable evidence, and ask or retain only correctness-material uncertainty. The generic steps below are conditional fallbacks: they never authorize a container, library, layer, interface, or token the project does not evidence.

**Applicability gate:** confirm a repository-evidenced Angular workspace and that the route target
belongs to it. If either is absent, report this skill as **not applicable**; the selected
distribution and template defaults do not establish an Angular project.

0. **Confirm the route and feature area do not already exist.** Search route configs, redirects, and lazy imports by URL and user-visible capability. Extend the existing route tree through ordinary `/feature` work instead of creating a competing path.

1. Create a feature directory/routing config only when the evidenced route pattern owns one.
2. Add the route through the evidenced loading mechanism; do not choose `loadComponent`, `loadChildren`, or eager loading from this recipe.
3. Add guards only where the project’s route policy and the feature’s evidence require them.
4. Add resolvers only where the project’s route pattern requires data before render; otherwise preserve its evidenced loading state.

Derive build, test, format, lint, migration/deploy, and data-validation commands from CLAUDE.md >
Conventions > Verification Commands, committed CI, scripts, manifests, and configuration. Run only
exact evidenced commands and report every unavailable category as **not available**.
