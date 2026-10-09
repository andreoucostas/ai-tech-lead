---
name: enforce-standards
description: >
  Use to wire the DETERMINISTIC backstop for code standards — make @ts-ignore, eslint-disable,
  and focused/skipped specs build-breaking via ESLint linterOptions + rule severities, so the
  lint step enforces what AI instructions can only request.
  USE FOR: "make lint blocking", "fail the build on fdescribe or .only", "enforce standards in CI",
  hardening a repo whose only standards enforcement is instructions and review.
  DO NOT USE FOR: layer/boundary rules (that is `enforce-architecture`), or the semantic
  review of a diff (that is `/review`).
---

# Enforce standards deterministically (evidenced Angular + ESLint only)

The write-time guard hook blocks `eslint-disable`, `@ts-ignore`, and focused or skipped tests
(`fit`/`xit`/`xtest`/`xcontext`/`xspecify`; `.only` and a declared `.skip` on `it`, `test`,
`describe`, `suite`, `context` or `specify`, and a declared `test.fixme`, chained forms included) in
`*.spec.*`, `*.test.*` and `*.cy.*` files — but only on surfaces where hooks run. This skill wires
the same floor into the **lint step**, where it binds every developer, every agent, and CI. Pairs
with `docs/ci-integration.md` (leg 2) and `docs/enforcement-surfaces.md`.

1. **Applicability and command evidence**: proceed only when repository manifests/configuration
   evidence an Angular workspace and an ESLint installation/configuration. The delivery profile is
   not that evidence. Derive the package manager and exact lint command from committed lockfiles,
   `packageManager`, scripts, CI, and config. If Angular is absent, report **not applicable**. If
   Angular exists but ESLint or a lint command does not, report lint as **not available** and ask for
   explicit agreement before establishing new lint infrastructure; never infer npm or `npx`.
2. **Config**: merge the fragment from `scripts/ci/eslint-standards.sample.mjs` into the repo's
   `eslint.config.js` (flat config; adapt if the repo still uses `.eslintrc`). It sets:
   - `linterOptions.noInlineConfig: true` — `// eslint-disable` comments stop working: ESLint reports
     each as a warning and applies none, so the violation it meant to hide still fails lint;
   - `@typescript-eslint/ban-ts-comment: 'error'` — `@ts-ignore` / `@ts-nocheck` fail lint. Put a
     plugin rule only in an object whose `files` match where the repository's config registers that
     plugin (`ng add angular-eslint` registers typescript-eslint under `**/*.ts`); an unscoped rule
     also reaches `*.html` and ESLint aborts with `Could not find plugin`;
   - `no-restricted-syntax` banning `fit` / `fdescribe` / `xit` / `xdescribe` / `xtest` and `.only`
     / `.skip` declarations, chained forms included (`it.concurrent.only`, `test.only.each`), in
     `*.spec.ts`, `*.test.ts` and `*.cy.ts` (Vitest, the default runner for projects created on
     Angular 21 or later, runs `*.spec.ts` and `*.test.ts` and has no `fit`/`xit`).
3. **Make lint part of the gate**: put the exact repository-evidenced lint command in the required
   build (`docs/ci-integration.md` leg 2) — lint that doesn't run in CI enforces nothing.
4. **Verify red**: confirm the gate bites — add a temporary focused spec in the form the repository's
   runner uses (`fdescribe` for Karma/Jasmine, `describe.only` for Vitest or Jest) with an `//
   eslint-disable-next-line` above it, run that exact lint command, show it still fails on the
   focused spec the comment cannot hide, revert. On hook surfaces the write guard refuses this edit
   through the editor tools: ask the developer to make and revert it. A gate you have not watched
   fail may be miswired (Verification Rule #9 applies to config too).
5. **Don't weaken to go green** — brownfield repos with existing violations: fix the cheap ones,
   record the rest in `TECH_DEBT.md` (Category: Standards), and scope `noInlineConfig` per-glob
   only as a last resort with a burn-down entry. Never fix a violation by re-enabling inline
   disables — that is the exact move this gate exists to stop.
6. **Verification inventory**: derive applicable build, test, format, lint, migration/deploy, and
   data-validation commands from repository evidence; run only applicable commands and report each
   unsupported category as **not available**.
