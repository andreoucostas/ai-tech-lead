---
name: add-entity
description: >
  EF Core repos only — verifies before scaffolding. Use when the user wants to add a new EF Core
  entity backed by a new database table.
  Covers entity class placement, IEntityTypeConfiguration, DbContext registration,
  migration generation, and SQL review.
  USE FOR: introducing a completely new domain concept that needs its own table — new entity
  class, new DbSet, new migration from scratch.
  DO NOT USE FOR: adding columns or relationships to an existing entity, modifying an existing
  migration, writing queries against an existing entity, creating value objects with no table,
  warehouse fact/dimension tables (use add-warehouse-load).
---

# Add a new EF Core entity

Match CLAUDE.md > Conventions > Data Access (query placement, AsNoTracking, repository pattern usage) and > Architecture (entities live in the domain layer).

0. **Applicability gate — confirm this repo persists via EF Core.** Confirm a repository-evidenced .NET project, then grep for `DbContext` or `Microsoft.EntityFrameworkCore`. If either is absent, report this skill as **not applicable**; do not introduce EF Core because this distribution includes the recipe. Find the repo's actual persistence pattern (for example, an existing entity/collection pair) and mirror it, or use the project-specific skill `/bootstrap` created.
   Then search entities, mappings, migrations, and tables by concept and business key. If the concept already exists, extend that entity through ordinary `/feature` work rather than creating a second table.
1. Entity class in the domain layer (no infrastructure imports).
2. Configuration class implementing `IEntityTypeConfiguration<T>` — keep mappings out of the entity itself.
3. Add `DbSet<T>` to the DbContext.
4. Derive the exact migration-generation command from `CLAUDE.md > Conventions > Verification Commands`, committed CI, scripts, manifests, or configuration. Run it only when that command and EF Core migration evidence exist; otherwise report migration generation as **not available** and do not infer `dotnet ef`.
5. **Review the generated migration SQL before applying.** Confirm column types, indexes, and any data-affecting changes.

If the entity is read-mostly, plan the typical query path and ensure callers use `.AsNoTracking()`.

Derive build, test, format, lint, migration/deploy, and data-validation commands from `CLAUDE.md >
Conventions > Verification Commands`, committed CI, scripts, manifests, and configuration. Run only
applicable evidenced commands and report every unavailable category as **not available**.
