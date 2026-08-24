---
name: enforce-standards
description: >
  Use to wire the DETERMINISTIC backstop for code standards in repository-evidenced .NET and/or
  Angular code — make suppressions and skipped/focused tests build-breaking. On the .NET side via
  TreatWarningsAsErrors + test-integrity analyzer severities; on the Angular side via ESLint
  linterOptions + rule severities. So the compiler / lint step enforces what AI instructions can
  only request.
  USE FOR: "make warnings errors", "make lint blocking", "fail the build on skipped tests /
  fdescribe", "enforce standards in CI", hardening a repo whose only standards enforcement is
  instructions and review.
  DO NOT USE FOR: dependency-direction rules (that is `enforce-architecture`), or the semantic
  review of a diff (that is `/review`).
---

# Enforce standards deterministically

The write-time guard hook blocks floor violations — .NET: `#pragma warning disable`, skipped tests across xUnit `[Fact(Skip=…)]` and NUnit/MSTest `[Ignore]`, and tautological asserts; Angular: `eslint-disable`, `@ts-ignore`, and `fit`/`xit` — but only on surfaces where hooks run. This skill wires the same floor into the **build / lint step**, where it binds every developer, every agent, and CI. Pairs with `docs/ci-integration.md` (leg 2) and `docs/enforcement-surfaces.md`. First identify applicable ecosystems from committed manifests and configuration, then apply only their section below. A repo-wide hardening covers every evidenced ecosystem; the monorepo delivery profile alone proves neither is present.

### .NET — compiler + analyzers

1. **Warnings as errors**: copy `scripts/ci/Directory.Build.props.sample` to `Directory.Build.props`
   at the repository's evidenced build root (or merge into an existing one — Leanness: don't duplicate). It sets
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
3. **CI**: update `CLAUDE.md > Conventions > Verification Commands` with the exact evidenced build
   and test invocations that exercise these settings, and put those commands in the required build
   (`docs/ci-integration.md`). Do not infer a solution-level `dotnet build` / `dotnet test`. Run the
   recorded command locally and show the result.
4. **Don't weaken to go green** — a pre-existing warning wall is normal in brownfield: keep
   `TreatWarningsAsErrors` scoped (e.g. per-project opt-in or `<WarningsAsErrors>` for specific
   codes first), record the remainder in `TECH_DEBT.md` (Category: Standards), and ratchet up.
   Never fix a violation by adding a suppression — that is the exact move this gate exists to stop.

### Angular — ESLint as the floor

Use the repository's evidenced lint tool and configuration. The recipe below applies when manifests
and configuration show ESLint plus typescript-eslint; adopting a missing lint stack is explicit
scope, not an incidental verification step.

1. **Config**: merge the fragment from `scripts/ci/eslint-standards.sample.mjs` into the repo's
   `eslint.config.js` (flat config; adapt if the repo still uses `.eslintrc`). It sets:
   - `linterOptions.noInlineConfig: true` — `// eslint-disable` comments stop working entirely;
   - `reportUnusedDisableDirectives: 'error'` — any that remain become findings themselves;
   - `@typescript-eslint/ban-ts-comment: 'error'` — `@ts-ignore` / `@ts-nocheck` fail lint;
   - `no-restricted-syntax` banning `fit` / `fdescribe` / `xit` / `xdescribe` in specs.
2. **Make lint part of the gate**: derive the exact configured lint command (for example,
   `npx eslint .` when that is the repository's runner) and put it in the required build
   (`docs/ci-integration.md` leg 2) — lint that doesn't run in CI enforces nothing.
3. **Verify red**: confirm the gate bites — add a temporary `fdescribe` and an
   `// eslint-disable-next-line`, run the evidenced lint command, show both fail, revert. A gate you have not
   watched fail may be miswired (Verification Rule #9 applies to config too).
4. **Don't weaken to go green** — brownfield repos with existing violations: fix the cheap ones,
   record the rest in `TECH_DEBT.md` (Category: Standards), and scope `noInlineConfig` per-glob
   only as a last resort with a burn-down entry. Never fix a violation by re-enabling inline
   disables — that is the exact move this gate exists to stop.
