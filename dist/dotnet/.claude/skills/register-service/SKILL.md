---
name: register-service
description: >
  Use when the user wants to create and register a brand-new service in the DI container.
  Covers interface + implementation pair, lifetime choice, the project's DI extension pattern,
  and constructor-injection discipline.
  USE FOR: net-new service that doesn't exist yet — new interface, new implementation class,
  new DI registration.
  DO NOT USE FOR: changing the lifetime of an existing registration, adding a dependency to an
  existing service constructor, extracting an interface from an already-registered class,
  replacing one implementation with another.
---

# Register a new service

Match CLAUDE.md > Conventions > Dependency Injection (lifetimes, registration via extension methods, IOptions variants).

**Applicability gate:** confirm a repository-evidenced .NET project and an existing DI registration pattern (`IServiceCollection`, `AddXxxServices`, or equivalent). If either is absent, report this skill as **not applicable**; do not introduce a DI framework because this distribution includes the recipe.

0. **Confirm no existing service already owns the responsibility.** Search interfaces, implementations, and registrations by capability, not only the proposed class name. Extend or replace an existing registration through ordinary `/feature` or `/refactor` work instead of creating overlapping ownership.

1. Create the interface and implementation. Interface is meaningful — don't create an interface just to mock it; consider whether a sealed class would do.
2. Add registration in the project's DI extension method (`AddXxxServices(this IServiceCollection)` per project), not directly in `Program.cs`.
3. Pick the lifetime deliberately:
   - **Scoped** — default for services holding per-request state.
   - **Transient** — factories and stateless helpers.
   - **Singleton** — caches and config.
4. Inject via constructor — never resolve from `IServiceProvider` directly. Watch for lifetime mismatches (singleton holding scoped is a leak).

Derive build, test, format, lint, migration/deploy, and data-validation commands from `CLAUDE.md > Conventions > Verification Commands`, committed CI, scripts, manifests, and configuration. Run only applicable evidenced commands and report every unavailable category as **not available**.
