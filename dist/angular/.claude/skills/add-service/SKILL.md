---
name: add-service
description: >
  Use when the user wants to add a new Angular service (HTTP, business-logic, or signal-based
  store). Covers placement, providedIn scope, typing, and HTTP-mocked unit tests.
  USE FOR: a service that does not exist yet — a new HTTP client for a backend resource, a new
  business-logic service.
  DO NOT USE FOR: adding a method to an existing service (ordinary work — follow CLAUDE.md >
  Conventions, or `/feature`); a signal-based store for shared state (use `add-signal-store`);
  changing an existing service's scope or dependencies (use `/refactor`); backfilling tests (use
  `add-tests`).
---

# Add a new service

Match the conventions in CLAUDE.md > Conventions > API/HTTP and > State Management. If the service is a signal-based store, see also the `add-signal-store` skill for state-shape rules.

0. **Confirm no existing service already owns the backend resource or responsibility.** Search injected services, HTTP paths, and public methods by capability. Extend an existing service through ordinary `/feature` work instead of creating a second client for the same resource.

1. `ng generate service` in the appropriate feature or core directory.
2. `providedIn: 'root'` for app-wide singletons; feature-level scope for services tied to a route.
3. Type all method signatures — no `any` in or out. HTTP return types are typed interfaces.
4. Write a service test with `provideHttpClientTesting` (preferred) or `HttpClientTestingModule` (legacy). Verify URLs, methods, and response handling.

If the service is HTTP-facing, prefer one service per backend resource (`UserService`, `OrderService`, etc.).
