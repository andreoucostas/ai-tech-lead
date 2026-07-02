---
name: enforce-standards
description: >
  Use to wire the DETERMINISTIC backstop for code standards — make @ts-ignore, eslint-disable,
  and focused/skipped specs build-breaking via ESLint linterOptions + rule severities, so the
  lint step enforces what AI instructions can only request.
  USE FOR: "make lint blocking", "fail the build on fdescribe", "enforce standards in CI",
  hardening a repo whose only standards enforcement is instructions and review.
  DO NOT USE FOR: layer/boundary rules (that is `enforce-architecture`), or the semantic
  review of a diff (that is `/review`).
---

# Enforce standards deterministically (Angular — ESLint as the floor)

The write-time guard hook blocks `eslint-disable`, `@ts-ignore`, and `fit`/`xit` — but only on
surfaces where hooks run. This skill wires the same floor into the **lint step**, where it binds
every developer, every agent, and CI. Pairs with `docs/ci-integration.md` (leg 2) and
`docs/enforcement-surfaces.md`. Zero new dependencies — everything below is core ESLint +
typescript-eslint, which angular-eslint projects already have.

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
