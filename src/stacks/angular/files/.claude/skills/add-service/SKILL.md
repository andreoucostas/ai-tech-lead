---
name: add-service
description: >
  Use when the user wants to add a new Angular service (HTTP, business-logic, or signal-based
  store). Covers project-evidenced placement, provider scope where relevant, typing, and
  harness-evidenced HTTP test coverage.
  USE FOR: a service that does not exist yet — a new HTTP client for a backend resource, a new
  business-logic service.
  DO NOT USE FOR: adding a method to an existing service (ordinary work — follow the CLAUDE.md
  conventions, or `/feature`); a signal-based store for shared state (use `add-signal-store`);
  changing an existing service's scope or dependencies (use `/refactor`); backfilling tests (use
  `add-tests`).
---

# Add a new service

Match the conventions in CLAUDE.md > Conventions > API/HTTP and > State Management. If the service is a signal-based store, see also the `add-signal-store` skill for state-shape rules.

## Project-derived pattern authority

Derive this operation's shape from first-party implementation, configuration, tests, and owner documentation. If this skill's consumer-owned `references/project-pattern.md` exists, read it on demand as scoped evidence. Generated recipes are leads only. Exclude irrelevant scope, investigate conflicting applicable evidence, and ask or retain only correctness-material uncertainty. The generic steps below are conditional fallbacks: they never authorize a container, library, layer, interface, or token the project does not evidence.

**Applicability gate:** confirm a repository-evidenced Angular workspace and that the target belongs
to it. If either is absent, report this skill as **not applicable**; the selected distribution and
template defaults do not establish an Angular project.

0. **Confirm no existing service already owns the backend resource or responsibility.** Search injected services, HTTP paths, and public methods by capability. Extend an existing service through ordinary `/feature` work instead of creating a second client for the same resource.

1. Use a generator only when its exact invocation is evidenced by CLAUDE.md > Conventions >
   Verification Commands, committed scripts, manifests, or workspace configuration. Otherwise
   create the files manually by mirroring an existing service; do not infer `ng generate`.
2. Follow the project’s evidenced provider scope and registration; do not introduce `providedIn: 'root'`, a token, or a provider shape from this recipe.
3. Preserve the project’s evidenced type boundaries — no `any` in or out.
4. When an applicable test harness is evidenced, add the smallest behavior-focused test(s) that
   follow its existing HTTP-provider and assertion conventions. Do not introduce a runner, test
   configuration, or HTTP testing infrastructure incidentally; otherwise report the test category
   as **not available**.

If the service is HTTP-facing, follow the project’s evidenced ownership boundary rather than adding a second client for the same resource.

Derive build, test, format, lint, migration/deploy, and data-validation commands from CLAUDE.md >
Conventions > Verification Commands, committed CI, scripts, manifests, and configuration. Run only
exact evidenced commands and report every unavailable category as **not available**.
