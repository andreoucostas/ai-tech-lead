---
name: add-lazy-route
description: Use when the user wants to add a new Angular route, especially a lazy-loaded one. Covers feature directory layout, loadComponent/loadChildren choice, guards, and resolvers.
---

# Add a new route with lazy loading

Match the conventions in CLAUDE.md > Conventions > Architecture for module/standalone choice and barrel-file rules.

1. Create a feature directory with its own routing config.
2. Add the lazy route in the parent: `loadComponent` (standalone) or `loadChildren` (NgModule).
3. Add guards if the route is auth- or role-gated.
4. Add resolvers only if data MUST load before render — otherwise prefer in-component loading with explicit loading state.

Justify any eagerly-loaded route in the PR description; lazy is the default.
