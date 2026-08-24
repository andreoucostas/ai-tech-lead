---
name: dependency-audit
description: >
  Use when the user wants to find vulnerable, deprecated, or outdated NuGet packages and/or set up
  automated dependency scanning. Covers the dotnet vulnerability scan, triage into the right register,
  and wiring up Dependabot (GitHub) or Renovate (host-agnostic, works with Bitbucket Data Center).
  USE FOR: pre-release dependency audits, responding to a CVE advisory, or establishing ongoing
  automated dependency updates.
  DO NOT USE FOR: adding a new package for a feature (just add it), or upgrading the .NET SDK/TFM.
---

# Dependency audit + automated scanning

**Applicability gate:** first confirm a committed `*.csproj` or an actual NuGet manifest/package
graph. A `.sln` alone may contain only SSDT/`*.sqlproj` projects and is not .NET/NuGet evidence. If
none exists, report this skill as not applicable; the dotnet delivery profile alone is not package
evidence, and a warehouse-only repository must not acquire NuGet tooling incidentally.

## 1. Scan now

Derive each vulnerability, deprecated-package, and outdated-package command from `CLAUDE.md >
Conventions > Verification Commands`, committed CI, scripts, manifests, and configuration. Record
the exact command and its evidence path before running it. Run only the evidenced form and report
every unavailable scan category as **not available**; do not infer a `dotnet` command, target, or
flag.

Read the output. For each **vulnerable** or **deprecated** package, note the package, current version, the advisory severity, and the first fixed version.

## 2. Triage

- **Vulnerable (transitive or direct)**: this is a security finding. Append a row to `SECURITY_FINDINGS.md` (Critical → today + 7 days, High → today + 30 days, per the register's SLA). Prefer bumping the direct dependency that pulls in the vulnerable transitive; only add an explicit top-level pin as a last resort.
- **Deprecated**: add to `TECH_DEBT.md` (Category: Dependencies) with the recommended replacement.
- **Outdated (no advisory)**: only flag majors or security-relevant minors. Do not churn the lockfile for cosmetic bumps (Leanness — no busywork).

Before recommending the bump, run the exact dependency, build, and test commands evidenced by
`CLAUDE.md > Conventions > Verification Commands`, committed CI, scripts, manifests, and
configuration. Report unavailable categories; do not infer a solution-level command.

## 3. Automate (pick one, once per repo)

- **GitHub-hosted**: add `.github/dependabot.yml` with a `nuget` ecosystem entry (weekly, grouped minor/patch) for the evidenced package root.
- **Bitbucket Data Center / non-GitHub**: Dependabot is **GitHub-only**. Use **Renovate** (self-hostable, runs in Bitbucket Pipelines / Bamboo / Jenkins) with a `renovate.json`, **or** add a CI step that runs an exact repository-evidenced audit command and fails on the documented threshold. If none is evidenced, report audit automation as **not available**; do not invent one. See the "Running on Bitbucket Data Center" section of the README.

Recommend exactly one mechanism; do not configure both.
