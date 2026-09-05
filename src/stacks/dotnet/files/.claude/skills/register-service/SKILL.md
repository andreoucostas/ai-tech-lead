---
name: register-service
description: >
  Use when the user wants to add a brand-new service following the project's existing
  composition or resolution pattern.
  Covers the project-evidenced seam, registration or construction, lifetime where relevant, and
  consumption discipline.
  USE FOR: net-new service responsibility that does not exist yet.
  DO NOT USE FOR: changing the lifetime of an existing registration, adding a dependency to an
  existing service constructor, extracting an interface from an already-registered class,
  replacing one implementation with another.
---

# Add or register a new service

Match CLAUDE.md > Conventions > Dependency Injection only where the project evidences dependency composition.

## Project-derived pattern authority

Derive this operation's shape from first-party implementation, configuration, tests, and owner documentation. If this skill's consumer-owned `references/project-pattern.md` exists, read it on demand as scoped evidence. Generated recipes are leads only. Exclude irrelevant scope, investigate conflicting applicable evidence, and ask or retain only correctness-material uncertainty. The generic steps below are conditional fallbacks: they never authorize a container, library, layer, interface, or token the project does not evidence.

0. **Confirm no existing service already owns the responsibility.** Inspect the project’s construction, composition, resolution, and test patterns; search by capability, not only an interface, implementation, or registration name. Extend or replace an existing owner through ordinary `/feature` or `/refactor` work instead of creating overlapping ownership. If no composition pattern can be examined, retain that correctness-material uncertainty and ask; do not introduce DI from this skill.

1. Follow the evidenced service shape; introduce an interface only where the project's boundary or correctness evidence requires one, not as a default.
2. Register through the evidenced composition root and mechanism; do not assume `IServiceCollection`, `AddXxxServices`, or `Program.cs`.
3. Match an evidenced lifetime and verify its dependency graph; do not infer scoped, transient, or singleton from this recipe.
4. Match the project's injection or resolution pattern and investigate lifetime mismatches; do not introduce a locator or container to satisfy this skill.

Derive build, test, format, lint, migration/deploy, and data-validation commands from `CLAUDE.md > Conventions > Verification Commands`, committed CI, scripts, manifests, and configuration. Run only applicable evidenced commands and report every unavailable category as **not available**.
