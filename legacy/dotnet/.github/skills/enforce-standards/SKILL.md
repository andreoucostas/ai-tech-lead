---
name: enforce-standards
description: >
  Use to wire the DETERMINISTIC backstop for code standards — make warnings, skipped tests, and
  analyzer findings build-breaking via TreatWarningsAsErrors + .editorconfig severities +
  xunit.analyzers, so the compiler enforces what AI instructions can only request.
  USE FOR: "make warnings errors", "fail the build on skipped tests", "enforce standards in CI",
  hardening a repo whose only standards enforcement is instructions and review.
  DO NOT USE FOR: dependency-direction rules (that is `enforce-architecture`), or the semantic
  review of a diff (that is `/review`).
---

# Enforce standards deterministically (.NET — compiler + analyzers)

The write-time guard hook blocks `#pragma warning disable`, `[Fact(Skip=…)]`, and tautological
asserts — but only on surfaces where hooks run. This skill wires the same floor into the
**build**, where it binds every developer, every agent, and CI. Pairs with `docs/ci-integration.md`
(leg 2) and `docs/enforcement-surfaces.md`.

1. **Warnings as errors**: copy `scripts/ci/Directory.Build.props.sample` to `Directory.Build.props`
   at the solution root (or merge into an existing one — Leanness: don't duplicate). It sets
   `TreatWarningsAsErrors`, `AnalysisLevel=latest-recommended`, and `EnforceCodeStyleInBuild`.
2. **Test-integrity severities**: append the `.editorconfig` fragment from the same sample's
   header comment — at minimum raise `xUnit1004` (skipped test) to `error` so a `Skip=` that
   slipped past the hook fails `dotnet build`. The xunit analyzers ship with the `xunit`
   metapackage; verify the version this repo pins actually includes them before claiming coverage.
3. **CI**: nothing extra to add — `dotnet build` / `dotnet test` in the required build
   (`docs/ci-integration.md`) now enforce it. Run the build once locally and show the result.
4. **Don't weaken to go green** — a pre-existing warning wall is normal in brownfield: keep
   `TreatWarningsAsErrors` scoped (e.g. per-project opt-in or `<WarningsAsErrors>` for specific
   codes first), record the remainder in `TECH_DEBT.md` (Category: Standards), and ratchet up.
   Never fix a violation by adding a suppression — that is the exact move this gate exists to stop.
