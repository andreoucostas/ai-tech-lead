---
name: dependency-audit
description: >
  Use when the user wants to find vulnerable, deprecated, or outdated npm packages and/or set up
  automated dependency scanning. Covers npm audit triage, Angular update guidance, and wiring up
  Dependabot (GitHub) or Renovate (host-agnostic, works with Bitbucket Data Center).
  USE FOR: pre-release dependency audits, responding to a CVE advisory, or establishing ongoing
  automated dependency updates.
  DO NOT USE FOR: adding a package for a feature (just add it), or a major Angular version upgrade
  (that is a planned `ng update` migration, not an audit).
---

# Dependency audit + automated scanning

**Applicability gate:** confirm a repository-evidenced npm package manifest. For Angular migration
inventory, separately confirm `@angular/core` and workspace configuration. If either relevant
surface is absent, report it as **not applicable** and do not add npm or Angular tooling merely
because this distribution was selected.

## 1. Scan now

Derive each vulnerability, outdated-package, and Angular-migration-preview command from CLAUDE.md >
Conventions > Verification Commands, committed CI, scripts, manifests, and configuration. Record
the exact command and its evidence path before running it. Run only the evidenced form and report
every unavailable scan category as **not available**; do not infer `npm audit`, `npm outdated`,
`npx ng update`, a package manager, or flags.

Read the output. For each advisory, note the package, severity, the path that pulls it in (direct vs transitive), and the first fixed version.

## 2. Triage

- **Vulnerable**: this is a security finding. Log Critical/High to `SECURITY_FINDINGS.md` if your repo uses the security register (Critical → today + 7 days, High → today + 30 days); otherwise add to `TECH_DEBT.md` (Category: Security). Use a non-breaking remediation only when its exact command is evidenced; review breaking remediations manually. Avoid blanket force upgrades — they can install majors and break the build.
- **Deprecated**: add to `TECH_DEBT.md` (Category: Dependencies) with the recommended replacement.
- **Outdated (no advisory)**: only flag majors or security-relevant updates. For `@angular/*` and ecosystem packages, use an exact evidenced migration command so its migrations run; do not hand-edit `package.json` or infer an Angular CLI command. Do not churn the lockfile for cosmetic bumps (Leanness — no busywork).

Before recommending the bump, run the exact dependency-install, build, and test commands evidenced by `CLAUDE.md > Conventions > Verification Commands`, committed CI, scripts, manifests, and configuration. Report any unavailable category; do not infer Angular CLI, a runner, or flags.

## 3. Automate (pick one, once per repo)

- **GitHub-hosted**: add `.github/dependabot.yml` with an `npm` ecosystem entry (weekly, grouped minor/patch).
- **Bitbucket Data Center / non-GitHub**: Dependabot is **GitHub-only**. Use **Renovate** (self-hostable, runs in Bitbucket Pipelines / Bamboo / Jenkins) with a `renovate.json`, **or** add a CI step that runs an exact repository-evidenced audit command and fails on the documented threshold. If none is evidenced, report audit automation as **not available**; do not invent one. See the "Running on Bitbucket Data Center" section of the README.

Recommend exactly one mechanism; do not configure both.
