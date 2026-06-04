---
name: add-endpoint
description: >
  Use when the user wants to add a new HTTP API endpoint end-to-end in a .NET solution.
  Covers domain shape, application service, DTOs, FluentValidation, thin controller action,
  and the integration test via WebApplicationFactory.
  USE FOR: adding a brand-new route that doesn't exist yet — greenfield endpoint, new resource,
  new command or query surface.
  DO NOT USE FOR: modifying an existing endpoint's logic or signature, adding a new method to
  an existing service, refactoring a controller, adding middleware, changing response shape on
  an endpoint that already exists.
---

# Add a new API endpoint end-to-end

Match CLAUDE.md > Conventions > Architecture (dependency direction), > API Design (controller thinness, DTO separation), and > Async (CancellationToken propagation).

1. Domain entity / value object (only if new — don't expand domain to fit an endpoint).
2. Application service method + interface (the work happens here, not in the controller).
3. Request and response DTOs (separate from domain entities).
4. FluentValidation validator for the request.
5. Controller action (thin — delegates to the service immediately) or minimal API endpoint if the project uses them.
6. Unit tests for the service logic.
7. Integration test via `WebApplicationFactory` covering the full HTTP path.

After scaffolding, follow the standard `/feature` flow: build/test/format after each subtask, Boy Scout every touched file, self-review against CLAUDE.md > Conventions.
