---
name: dependency-audit
description: >
  Use when the user wants to find vulnerable, deprecated, or outdated NuGet and/or npm packages
  evidenced by the repository, and/or set up automated dependency scanning. Covers applicable
  dotnet and npm scans, Angular update guidance when Angular is present, and wiring up Dependabot
  (GitHub) or Renovate (host-agnostic, works with Bitbucket Data Center).
  USE FOR: pre-release dependency audits, responding to a CVE advisory, or establishing ongoing
  automated dependency updates.
  DO NOT USE FOR: adding a new package for a feature (just add it), upgrading the .NET SDK/TFM, or
  a major Angular version upgrade (that is a planned `ng update` migration, not an audit).
---

# Dependency audit + automated scanning

First identify package ecosystems from committed manifests and lock files. Scan and automate only
the evidenced ecosystem(s) the change touches; for a repo-wide audit, cover every evidenced
ecosystem. The monorepo delivery profile alone proves neither NuGet nor npm is present.

**Applicability gate:** if neither a committed .NET/NuGet surface nor an npm package manifest is
evidenced, report this skill as **not applicable** and do not add package-management tooling.

## 1. Scan now

**.NET** — only when a committed `*.csproj` or an actual NuGet manifest/package graph is evidenced;
a `.sln` alone may contain only SSDT/`*.sqlproj` projects and does not qualify. Derive each
vulnerability, deprecated-package, and outdated-package command from CLAUDE.md > Conventions >
Verification Commands, committed CI, scripts, manifests, and configuration. Record the exact
command and its evidence path before running it. Run only the evidenced form and report every
unavailable scan category as **not available**; do not infer a `dotnet` command, target, or flag.

**Angular/npm** — only when the relevant package manifest and configured targets are evidenced.
Derive each vulnerability, outdated-package, and Angular-migration-preview command from the same
evidence inventory. Record the exact command and its evidence path before running it. Run only the
evidenced form and report every unavailable scan category as **not available**; do not infer `npm`,
`npx`, an Angular CLI command, or flags.

Read the output. For each **vulnerable** or **deprecated** package, note the package, current version, the advisory severity, the path that pulls it in (direct vs transitive), and the first fixed version.

## 2. Triage

- **Vulnerable (transitive or direct)**: this is a security finding. Append a row to `SECURITY_FINDINGS.md` if your repo uses the security register (Critical → today + 7 days, High → today + 30 days, per the register's SLA); otherwise add to `TECH_DEBT.md` (Category: Security).
  - **.NET:** prefer bumping the direct dependency that pulls in the vulnerable transitive; only add an explicit top-level pin as a last resort.
  - **Angular:** use a non-breaking remediation only when its exact command is evidenced; review breaking remediations manually. Avoid blanket force upgrades — they can install majors and break the build.
- **Deprecated**: add to `TECH_DEBT.md` (Category: Dependencies) with the recommended replacement.
- **Outdated (no advisory)**: only flag majors or security-relevant updates. Do not churn the lockfile for cosmetic bumps (Leanness — no busywork). On the Angular side, use an exact evidenced migration command for `@angular/*` and ecosystem packages so migrations run; do not hand-edit `package.json` or infer an Angular CLI command.

Before recommending the bump, run the exact dependency-install, build, and test commands evidenced for each touched ecosystem by `CLAUDE.md > Conventions > Verification Commands`, committed CI, scripts, manifests, and configuration. Report unavailable categories; do not infer a stack command from this distribution.

## 3. Automate (pick one mechanism, once per repo)

- **GitHub-hosted**: add `.github/dependabot.yml` with an entry for each evidenced package ecosystem (`nuget`, `npm`, or both), weekly and grouped minor/patch.
- **Bitbucket Data Center / non-GitHub**: Dependabot is **GitHub-only**. Use **Renovate** (self-hostable, runs in Bitbucket Pipelines / Bamboo / Jenkins) with a `renovate.json` and let it detect committed manifests, **or** add only exact repository-evidenced audit commands to CI. If none is evidenced, report audit automation as **not available**; do not invent one. See the "Running on Bitbucket Data Center" section of the README.

Recommend exactly one mechanism covering every evidenced ecosystem; do not configure both Dependabot and Renovate.
