---
name: enforce-standards
description: >
  Use to wire the DETERMINISTIC backstop for code standards — make warnings, skipped tests, and
  analyzer findings build-breaking via TreatWarningsAsErrors + .editorconfig severities +
  test-integrity analyzer severities, so the compiler enforces what AI instructions can only request.
  USE FOR: "make warnings errors", "fail the build on skipped tests", "enforce standards in CI",
  hardening a repo whose only standards enforcement is instructions and review.
  DO NOT USE FOR: dependency-direction rules (that is `enforce-architecture`), or the semantic
  review of a diff (that is `/review`).
---

# Enforce standards deterministically (.NET — compiler + analyzers)

The write-time guard hook blocks `#pragma warning disable`, skipped tests across xUnit
`[Fact(Skip=…)]` and NUnit/MSTest `[Ignore]`, and tautological asserts — but only on surfaces where hooks run. This skill wires the same floor into the
**build**, where it binds every developer, every agent, and CI. Pairs with `docs/ci-integration.md`
(leg 2) and `docs/enforcement-surfaces.md`.

1. **Warnings as errors**: copy `scripts/ci/Directory.Build.props.sample` to `Directory.Build.props`
   at the solution root (or merge into an existing one — Leanness: don't duplicate). It sets
   `TreatWarningsAsErrors`, `AnalysisLevel=latest-recommended`, and `EnforceCodeStyleInBuild`.
   The sample's `.editorconfig` fragment is xUnit-specific; use step 2 for NUnit or MSTest.
2. **Test-integrity severities**: detect the test framework from package references and apply only
   its branch. Verify the versions this repo pins include the stated analyzer before claiming
   coverage.
   - **If xUnit:** add `dotnet_diagnostic.xUnit1004.severity = error` for skipped tests. The xunit
     analyzers ship with the `xunit` metapackage.
   - **If MSTest:** add `dotnet_diagnostic.MSTEST0015.severity = error` ("Test method should not be
     ignored"). It ships in `MSTest.Analyzers` 3.3+ with default severity Info and became opt-in
     from 3.8.
   - **If NUnit:** there is no equivalent analyzer. NUnit1xxx rules are structural, NUnit2xxx are
     assertion rules, and NUnit3xxx are suppressors; none flags an ignored test. Wire a
     build-failing CI step that rejects `[Ignore]`, pointed at this repo's test root:
     ```bash
     if grep -rn --include=*.cs '^\s*\[.*\bIgnore\b' tests/; then
       echo "NUnit [Ignore] is forbidden"; exit 1
     fi
     ```
3. **CI**: nothing extra to add — `dotnet build` / `dotnet test` in the required build
   (`docs/ci-integration.md`) now enforce it. Run the build once locally and show the result.
4. **Don't weaken to go green** — a pre-existing warning wall is normal in brownfield: keep
   `TreatWarningsAsErrors` scoped (e.g. per-project opt-in or `<WarningsAsErrors>` for specific
   codes first), record the remainder in `TECH_DEBT.md` (Category: Standards), and ratchet up.
   Never fix a violation by adding a suppression — that is the exact move this gate exists to stop.
