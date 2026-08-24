---
name: add-service
description: >
  Use when the user wants to add a new Angular service (HTTP, business-logic, or signal-based
  store). Covers placement, providedIn scope, typing, and harness-evidenced HTTP test coverage.
  USE FOR: a service that does not exist yet — a new HTTP client for a backend resource, a new
  business-logic service.
  DO NOT USE FOR: adding a method to an existing service (ordinary work — follow CLAUDE.md >
  Conventions, or `/feature`); a signal-based store for shared state (use `add-signal-store`);
  changing an existing service's scope or dependencies (use `/refactor`); backfilling tests (use
  `add-tests`).
---

# Add a new service

Match the conventions in CLAUDE.md > Conventions > API/HTTP and > State Management. If the service is a signal-based store, see also the `add-signal-store` skill for state-shape rules.

**Applicability gate:** confirm a repository-evidenced Angular workspace and that the target belongs
to it. If either is absent, report this skill as **not applicable**; the selected distribution and
template defaults do not establish an Angular project.

0. **Confirm no existing service already owns the backend resource or responsibility.** Search injected services, HTTP paths, and public methods by capability. Extend an existing service through ordinary `/feature` work instead of creating a second client for the same resource.

1. Use a generator only when its exact invocation is evidenced by CLAUDE.md > Conventions >
   Verification Commands, committed scripts, manifests, or workspace configuration. Otherwise
   create the files manually by mirroring an existing service; do not infer `ng generate`.
2. `providedIn: 'root'` for app-wide singletons; feature-level scope for services tied to a route.
3. Type all method signatures — no `any` in or out. HTTP return types are typed interfaces.
4. When an applicable test harness is evidenced, add the smallest behavior-focused test(s) that
   follow its existing HTTP-provider and assertion conventions. Do not introduce a runner, test
   configuration, or HTTP testing infrastructure incidentally; otherwise report the test category
   as **not available**.

If the service is HTTP-facing, prefer one service per backend resource (`UserService`, `OrderService`, etc.).

Derive build, test, format, lint, migration/deploy, and data-validation commands from CLAUDE.md >
Conventions > Verification Commands, committed CI, scripts, manifests, and configuration. Run only
exact evidenced commands and report every unavailable category as **not available**.
