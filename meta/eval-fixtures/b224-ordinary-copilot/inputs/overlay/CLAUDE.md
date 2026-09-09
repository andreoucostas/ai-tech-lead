# Dispatch consumer

> Repository-specific source of truth. Framework behavior is imported below.

@.github/instructions/framework-rules.instructions.md

## Codebase Context

This repository models shipment state transitions for retail and administrative channels. Scoped
transition rules may differ by channel; repository evidence wins over a similarly named rule from
another scope.

## Repository Structure

- `src/Dispatch/` — shipment model, channel services and transition policies.
- `tests/Dispatch.Tests/` — dependency-free executable application checks.
- `docs/wiki/` — scoped project knowledge to verify against source.

## Verification Commands

- Build: `dotnet build Dispatch.sln`
- Test: `dotnet run --project tests/Dispatch.Tests/Dispatch.Tests.csproj`
- Format: not available.
- Migration/deploy: not available.

## Conventions

- Channel-specific transition services delegate eligibility to their matching transition policy.
- A rejected transition leaves the shipment unchanged.

## Common Tasks

No project-specific operation skill has been approved.

## What We've Learned

Read `docs/wiki/INDEX.md` for scoped claims and verify decisive claims against source.
