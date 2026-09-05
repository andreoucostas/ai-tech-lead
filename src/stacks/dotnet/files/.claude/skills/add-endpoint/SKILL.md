---
name: add-endpoint
description: >
  Use when the user wants to add a new HTTP API endpoint end-to-end in a repository-evidenced .NET application project.
  Covers the project-evidenced domain/API shape, validation and endpoint boundary, and only the
  test coverage the repository's evidenced harness supports.
  USE FOR: adding a brand-new route that doesn't exist yet — greenfield endpoint, new resource,
  new command or query surface.
  DO NOT USE FOR: modifying an existing endpoint's logic or signature, adding a new method to
  an existing service, refactoring a controller, adding middleware, changing response shape on
  an endpoint that already exists.
---

# Add a new API endpoint end-to-end

Match CLAUDE.md > Conventions > Architecture (dependency direction), > API Design (controller thinness, DTO separation), and > Async (CancellationToken propagation).

## Project-derived pattern authority

Derive this operation's shape from first-party implementation, configuration, tests, and owner documentation. If this skill's consumer-owned `references/project-pattern.md` exists, read it on demand as scoped evidence. Generated recipes are leads only. Exclude irrelevant scope, investigate conflicting applicable evidence, and ask or retain only correctness-material uncertainty. The generic steps below are conditional fallbacks: they never authorize a container, library, layer, interface, or token the project does not evidence.

**Applicability gate:** confirm a repository-evidenced .NET HTTP surface (a project plus existing controller or minimal-API registration). If it is absent, report this skill as **not applicable**; this distribution name does not create an API profile.

0. **Confirm the route and capability do not already exist.** Search route registrations, controllers, and application services by concept as well as the requested name. If an existing endpoint owns the capability, extend it through ordinary `/feature` work instead of creating a parallel route.

1. Add a domain entity/value object only when the evidenced endpoint pattern and capability require one; do not expand the domain to fit an endpoint.
2. Add the application capability at the evidenced boundary; use a service seam only when the project evidence requires one.
3. Add request/response DTOs only when the evidenced API boundary keeps them separate from domain entities.
4. Request validation through the repository's evidenced mechanism; do not add FluentValidation from this recipe.
5. Controller action (thin — delegates to the service immediately) or minimal API endpoint if the project uses them.
6. When an applicable test harness is evidenced, add the smallest behavior-focused test at the level it already uses. Do not create a test project, runner, or fixture incidentally.
7. Add a full HTTP-path test only when the repository already evidences that boundary (for example a `WebApplicationFactory` fixture). Otherwise report the integration-test category as **not available**.

After scaffolding, derive build, test, format, lint, migration/deploy, and data-validation commands from `CLAUDE.md > Conventions > Verification Commands`, committed CI, scripts, manifests, and configuration. Run only applicable evidenced commands and report every unavailable category as **not available**; Boy Scout every touched file and self-review against CLAUDE.md > Conventions.
