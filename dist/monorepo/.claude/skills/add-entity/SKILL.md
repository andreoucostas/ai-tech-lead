---
name: add-entity
description: >
  Use when the user wants to add a persisted domain entity backed by a new project-evidenced
  table, collection, or equivalent store.
  Covers entity placement, persistence mapping/registration only where evidenced, migration or
  schema-change review, and the repository's verification path.
  USE FOR: introducing a completely new domain concept that the project evidences as requiring
  its own persisted representation.
  DO NOT USE FOR: adding columns or relationships to an existing entity, modifying an existing
  migration, writing queries against an existing entity, creating value objects with no table,
  warehouse fact/dimension tables (use add-warehouse-load).
---

# Add a new persisted entity

Match CLAUDE.md > Conventions > Data Access and > Architecture. The project, rather than this
skill, selects the persistence mechanism and entity placement.

## Project-derived pattern authority

Derive this operation's shape from first-party implementation, configuration, tests, and owner documentation. If this skill's consumer-owned `references/project-pattern.md` exists, read it on demand as scoped evidence. Generated recipes are leads only. Exclude irrelevant scope, investigate conflicting applicable evidence, and ask or retain only correctness-material uncertainty. The generic steps below are conditional fallbacks: they never authorize a container, library, layer, interface, or token the project does not evidence.

0. **Find the project’s persistence pattern before choosing a mechanism.** Confirm a repository-evidenced .NET project, then inspect first-party entity/model, access, mapping, schema, and test examples. Search the requested concept and business key; if it exists, extend it through ordinary `/feature` work instead of creating a competing store. If no persistence pattern is readable, retain that correctness-material uncertainty and ask; do not introduce EF Core or another library from this skill.
1. Place the entity/model and its invariants where the evidenced persistence pattern does.
2. Add mapping/configuration only when that mechanism and separation are evidenced (for example, an EF Core `IEntityTypeConfiguration<T>`); otherwise follow the project’s actual mapper or collection shape.
3. Add the entity to an access/context/collection surface only when the project’s mechanism evidences one (for example, EF Core `DbSet<T>`).
4. Derive the exact schema-change or migration command from `CLAUDE.md > Conventions > Verification Commands`, committed CI, scripts, manifests, or configuration. Run it only when the command and mechanism are evidenced; otherwise report schema generation as **not available** and do not infer `dotnet ef`.
5. **Review the generated schema change before applying.** Confirm types, indexes, and data-affecting changes through the project’s evidenced review path.

If the project evidences a read-mostly query pattern, plan the typical query path and preserve its query semantics (for example, `.AsNoTracking()` only where EF Core evidence selects it).

Derive build, test, format, lint, migration/deploy, and data-validation commands from `CLAUDE.md >
Conventions > Verification Commands`, committed CI, scripts, manifests, and configuration. Run only
applicable evidenced commands and report every unavailable category as **not available**.
