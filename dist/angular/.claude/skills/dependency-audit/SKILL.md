---
name: dependency-audit
description: >
  Use when the user wants to find vulnerable, deprecated, or outdated npm packages, set up
  automated dependency scanning, or move Angular to a newer major version. Covers npm audit triage,
  Dependabot (GitHub) or Renovate (host-agnostic, works with Bitbucket Data Center), and a
  one-major-a-step `ng update` upgrade with its migrations.
  USE FOR: pre-release dependency audits, a CVE advisory, ongoing automated updates, upgrading
  Angular to a newer major.
  DO NOT USE FOR: adding a package for a feature (just add it).
---

# Dependency audit, automated scanning, and major upgrades

**Applicability gate:** confirm a repository-evidenced npm package manifest. For Angular migration
inventory, separately confirm `@angular/core` and workspace configuration. If either relevant
surface is absent, report it as **not applicable** and do not add npm or Angular tooling merely
because this distribution was selected.

## 1. Scan now

Derive each vulnerability, outdated-package, and Angular-migration-preview command from AGENTS.md >
Conventions > Verification Commands, committed CI, scripts, manifests, and configuration. Record
the exact command and its evidence path before running it. Run only the evidenced form and report
every unavailable scan category as **not available**; do not infer `npm audit`, `npm outdated`,
`npx ng update`, a package manager, or flags (section 4's `ng update` excepted).

Read the output. For each advisory, note the package, severity, the path that pulls it in (direct vs transitive), and the first fixed version.

## 2. Triage

- **Vulnerable**: this is a security finding. Log Critical/High to `SECURITY_FINDINGS.md` if your repo uses the security register (Critical → today + 7 days, High → today + 30 days); otherwise add to `TECH_DEBT.md` (Category: Security). Use a non-breaking remediation only when its exact command is evidenced; review breaking remediations manually. Avoid blanket force upgrades — they can install majors and break the build.
- **Deprecated**: add to `TECH_DEBT.md` (Category: Dependencies) with the recommended replacement.
- **Outdated (no advisory)**: only flag majors or security-relevant updates. For an `@angular/*` major, use section 4; for other `@angular/*` and ecosystem updates, use an exact evidenced migration command so its migrations run. Do not hand-edit `package.json` or infer an Angular CLI command (section 4's `ng update` excepted). Do not churn the lockfile for cosmetic bumps (Leanness — no busywork).

Before recommending the bump, run the exact dependency-install, build, and test commands evidenced by `AGENTS.md > Conventions > Verification Commands`, committed CI, scripts, manifests, and configuration. Report any unavailable category; do not infer Angular CLI, a runner, or flags (section 4's `ng update` excepted).

## 3. Automate (pick one, once per repo)

- **GitHub-hosted**: add `.github/dependabot.yml` with an `npm` ecosystem entry (weekly, grouped minor/patch).
- **Bitbucket Data Center / non-GitHub**: Dependabot is **GitHub-only**. Use **Renovate** (self-hostable, runs in Bitbucket Pipelines / Bamboo / Jenkins) with a `renovate.json`, **or** add a CI step that runs an exact repository-evidenced audit command and fails on the documented threshold. If none is evidenced, report audit automation as **not available**; do not invent one.

Recommend exactly one mechanism; do not configure both.

## 4. Upgrade Angular to a newer major

Move one major per pass, as Angular's release policy requires
(<https://angular.dev/reference/releases>). Each pass ends on a green tree committed on its own,
with no refactoring or feature work mixed in. When a source named below cannot be opened, say so
and ask the developer; never list versions, ranges, or breaking changes from memory. An AngularJS
(`angular` 1.x) app needs a rewrite, not this procedure: report it and stop.

1. **Inventory from files.** Read the `@angular/*`, `@angular/cli`, TypeScript, RxJS, and
   `zone.js` versions from `package.json` and the lockfile (the lockfile names the package
   manager), the builders in `angular.json`, and Node pins (`engines`, `.nvmrc`, committed CI).
   Report the current and next majors with evidence paths and their support dates from the
   releases page.
2. **Blockers before edits.** Run the evidenced install, build, and test commands for a green
   baseline. If no build or test command is evidenced, say so and ask the developer for one before
   editing. Check the next major's Node, TypeScript, and RxJS ranges at
   <https://angular.dev/reference/versions> and, for every third-party Angular library, the release
   whose peer range includes the next major (its registry metadata or changelog); note it for item 4.
   A library with no such release is unsupported. When the next major needs a different Node, ask the
   developer to confirm it is installed wherever the recorded commands run; edit nothing until they
   do. Name Node on other machines and build agents as a developer action. Stop and report a red
   baseline or an unsupported library.
3. **Read the breaking changes** of the next major: the **Breaking Changes** sections of its `.0.0`
   release in the GitHub `CHANGELOG.md` or release page of `angular/angular` and
   `angular/angular-cli`, and of `angular/components` when `@angular/material` or `@angular/cdk` is
   evidenced. Also take the steps the Angular Update Guide (<https://angular.dev/update-guide>) lists
   for this from/to pair; when that page cannot be read, its data is in
   `adev/src/app/features/update/recommendations.ts` of `angular/angular`. List only the items that
   apply to this repository.
4. **Update with the migrations.** From a clean working tree, update in one `ng update` through the
   workspace's own CLI and package manager: `@angular/core` and `@angular/cli` to the next major,
   evidenced first-party packages such as `@angular/material`, and every installed library whose peer
   range excludes the next major, at its release that supports it (for example NgRx N and
   angular-eslint N for Angular N: a peer range on any `@angular/*` package counts, and
   angular-eslint's is on `@angular/cli`; naming one package of a library's `ng-update` package
   group, such as `@ngrx/store`, updates the whole group). `ng update` refuses with "Incompatible
   peer dependencies found" while any package listed in `package.json` has a non-optional peer range
   that excludes the target. This is the one Angular CLI command this skill derives without a
   Verification Commands row, because the Angular documentation names it as the migration path: show
   the exact command and get the developer's go-ahead first. Never add `--force`, which ignores
   peer-dependency mismatches. In an Nx workspace (`nx.json`), `ng update` is not the path: use an
   evidenced `nx migrate` command or report the upgrade as not available. Read the migration output
   beside the breaking changes and review every file the migrations changed.
   Move committed Node pins (`.nvmrc`, `package.json` `engines`, CI YAML) to the next major's range
   in the same pass.
5. **Keep the pass narrow.** Accept the migrations the update requires. Optional modernisations,
   and defaults that apply to new projects (builder, test runner, change detection, standalone), are
   separate `/refactor` or `/design` work.
6. **Verify and commit the pass.** Run the evidenced install, build, lint, and test commands, fix
   what the breaking changes predict, and triage new audit findings as in the Triage section.
   Commit this major alone, then return to item 2 for the next major.
7. **Close out.** Update statements of the old version in `AGENTS.md`,
   `FRAMEWORK-CONTEXT.md > Detected Framework Packages` and docs, except the
   `framework-owned/overwritten` paths in `framework-ownership.json`, and list what the developer
   still has to do (Node on build agents and other machines, deployment). Use `create-adr` only for
   a lasting choice the upgrade forced, such as holding a library on an older major.
