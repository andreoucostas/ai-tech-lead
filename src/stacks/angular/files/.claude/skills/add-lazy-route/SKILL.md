---
name: add-lazy-route
description: >
  Use when the user wants to add a new Angular route, especially a lazy-loaded one. Covers feature
  directory layout, loadComponent/loadChildren choice, guards, and resolvers.
  USE FOR: a route that does not exist yet — a new feature area, a lazily loaded child route, a
  guarded or resolved route.
  DO NOT USE FOR: changing an existing route's path, guard, or resolver (use `/feature` or
  `/refactor`); creating the component the route will point at (use `add-component` first).
---

# Add a new route with lazy loading

Match the conventions in CLAUDE.md > Conventions > Architecture for module/standalone choice and barrel-file rules.

1. Create a feature directory with its own routing config.
2. Add the lazy route in the parent: `loadComponent` (standalone) or `loadChildren` (NgModule).
3. Add guards if the route is auth- or role-gated.
4. Add resolvers only if data MUST load before render — otherwise prefer in-component loading with explicit loading state.

Justify any eagerly-loaded route in the PR description; lazy is the default.
