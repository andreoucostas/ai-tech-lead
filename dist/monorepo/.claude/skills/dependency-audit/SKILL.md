---
name: dependency-audit
description: >
  Use when the user wants to find vulnerable, deprecated, or outdated NuGet and/or npm packages
  in this mixed .NET + Angular codebase, and/or set up automated dependency scanning. Covers the
  dotnet vulnerability scan, npm audit triage, Angular update guidance, and wiring up Dependabot
  (GitHub) or Renovate (host-agnostic, works with Bitbucket Data Center) across both ecosystems.
  USE FOR: pre-release dependency audits, responding to a CVE advisory, or establishing ongoing
  automated dependency updates.
  DO NOT USE FOR: adding a new package for a feature (just add it), upgrading the .NET SDK/TFM, or
  a major Angular version upgrade (that is a planned `ng update` migration, not an audit).
---

# Dependency audit + automated scanning

This repo has two package ecosystems. Scan and automate the one(s) whose manifests the change touches; for a repo-wide audit, do **both**.

## 1. Scan now

**.NET** — from the solution root:

```
dotnet list package --vulnerable --include-transitive
dotnet list package --deprecated
dotnet list package --outdated
```

**Angular** — from the project root:

```
npm audit
npm outdated
npx ng update            # lists Angular packages with available updates (no changes applied)
```

Read the output. For each **vulnerable** or **deprecated** package, note the package, current version, the advisory severity, the path that pulls it in (direct vs transitive), and the first fixed version.

## 2. Triage

- **Vulnerable (transitive or direct)**: this is a security finding. Append a row to `SECURITY_FINDINGS.md` if your repo uses the security register (Critical → today + 7 days, High → today + 30 days, per the register's SLA); otherwise add to `TECH_DEBT.md` (Category: Security).
  - **.NET:** prefer bumping the direct dependency that pulls in the vulnerable transitive; only add an explicit top-level pin as a last resort.
  - **Angular:** prefer `npm audit fix` for non-breaking fixes; review breaking fixes manually. Avoid blanket `npm audit fix --force` — it can install majors and break the build.
- **Deprecated**: add to `TECH_DEBT.md` (Category: Dependencies) with the recommended replacement.
- **Outdated (no advisory)**: only flag majors or security-relevant updates. Do not churn the lockfile for cosmetic bumps (Leanness — no busywork). On the Angular side, use `ng update` (not hand-edited `package.json`) for `@angular/*` and ecosystem packages so migrations run.

Verify the fix builds and tests pass before recommending the bump — .NET: `dotnet build` + `dotnet test`; Angular: `npm ci` resolves and `ng build` + `ng test` pass.

## 3. Automate (pick one mechanism, once per repo — cover both ecosystems)

- **GitHub-hosted**: add `.github/dependabot.yml` with **both** a `nuget` entry **and** an `npm` entry (weekly, grouped minor/patch).
- **Bitbucket Data Center / non-GitHub**: Dependabot is **GitHub-only**. Use **Renovate** (self-hostable, runs in Bitbucket Pipelines / Bamboo / Jenkins) with a `renovate.json` — Renovate auto-detects both the .NET and npm manifests — **or** add CI steps that run `dotnet list package --vulnerable --include-transitive` and `npm audit --audit-level=high` and fail the build on any advisory. See the "Running on Bitbucket Data Center" section of the README.

Recommend exactly one mechanism, covering both ecosystems; do not configure both Dependabot and Renovate.
