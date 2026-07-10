---
name: enforce-standards
description: >
  Use to wire the DETERMINISTIC backstop for code standards in this mixed .NET + Angular codebase —
  make suppressions and skipped/focused tests build-breaking. On the .NET side via
  TreatWarningsAsErrors + .editorconfig severities + xunit.analyzers; on the Angular side via ESLint
  linterOptions + rule severities. So the compiler / lint step enforces what AI instructions can
  only request.
  USE FOR: "make warnings errors", "make lint blocking", "fail the build on skipped tests /
  fdescribe", "enforce standards in CI", hardening a repo whose only standards enforcement is
  instructions and review.
  DO NOT USE FOR: dependency-direction rules (that is `enforce-architecture`), or the semantic
  review of a diff (that is `/review`).
---

# Enforce standards deterministically (.NET + Angular)

The write-time guard hook blocks floor violations — .NET: `#pragma warning disable`, `[Fact(Skip=…)]`, and tautological asserts; Angular: `eslint-disable`, `@ts-ignore`, and `fit`/`xit` — but only on surfaces where hooks run. This skill wires the same floor into the **build / lint step**, where it binds every developer, every agent, and CI. Pairs with `docs/ci-integration.md` (leg 2) and `docs/enforcement-surfaces.md`. This repo has two stacks; apply the section for the stack you are hardening (a repo-wide hardening does both).

### .NET — compiler + analyzers

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

### Angular — ESLint as the floor

Zero new dependencies — everything below is core ESLint + typescript-eslint, which angular-eslint projects already have.

1. **Config**: merge the fragment from `scripts/ci/eslint-standards.sample.mjs` into the repo's
   `eslint.config.js` (flat config; adapt if the repo still uses `.eslintrc`). It sets:
   - `linterOptions.noInlineConfig: true` — `// eslint-disable` comments stop working entirely;
   - `reportUnusedDisableDirectives: 'error'` — any that remain become findings themselves;
   - `@typescript-eslint/ban-ts-comment: 'error'` — `@ts-ignore` / `@ts-nocheck` fail lint;
   - `no-restricted-syntax` banning `fit` / `fdescribe` / `xit` / `xdescribe` in specs.
2. **Make lint part of the gate**: `npx eslint .` must run in the required build
   (`docs/ci-integration.md` leg 2) — lint that doesn't run in CI enforces nothing.
3. **Verify red**: confirm the gate bites — add a temporary `fdescribe` and an
   `// eslint-disable-next-line`, run `npx eslint .`, show both fail, revert. A gate you have not
   watched fail may be miswired (Verification Rule #9 applies to config too).
4. **Don't weaken to go green** — brownfield repos with existing violations: fix the cheap ones,
   record the rest in `TECH_DEBT.md` (Category: Standards), and scope `noInlineConfig` per-glob
   only as a last resort with a burn-down entry. Never fix a violation by re-enabling inline
   disables — that is the exact move this gate exists to stop.
