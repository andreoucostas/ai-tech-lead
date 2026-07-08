---
name: add-entity
description: >
  Use when the user wants to add a new EF Core entity backed by a new database table.
  Covers entity class placement, IEntityTypeConfiguration, DbContext registration,
  migration generation, and SQL review.
  USE FOR: introducing a completely new domain concept that needs its own table — new entity
  class, new DbSet, new migration from scratch.
  DO NOT USE FOR: adding columns or relationships to an existing entity, modifying an existing
  migration, writing queries against an existing entity, creating value objects with no table.
---

# Add a new EF Core entity

Match CLAUDE.md > Conventions > Data Access (query placement, AsNoTracking, repository pattern usage) and > Architecture (entities live in the domain layer).

1. Entity class in the domain layer (no infrastructure imports).
2. Configuration class implementing `IEntityTypeConfiguration<T>` — keep mappings out of the entity itself.
3. Add `DbSet<T>` to the DbContext.
4. Generate the migration: `dotnet ef migrations add MigrationName`.
5. **Review the generated migration SQL before applying.** Confirm column types, indexes, and any data-affecting changes.

If the entity is read-mostly, plan the typical query path and ensure callers use `.AsNoTracking()`.
