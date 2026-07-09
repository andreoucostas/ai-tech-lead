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

## 1. Scan now

Run, from the solution root:

```
dotnet list package --vulnerable --include-transitive
dotnet list package --deprecated
dotnet list package --outdated
```

Read the output. For each **vulnerable** or **deprecated** package, note the package, current version, the advisory severity, and the first fixed version.

## 2. Triage

- **Vulnerable (transitive or direct)**: this is a security finding. Append a row to `SECURITY_FINDINGS.md` (Critical → today + 7 days, High → today + 30 days, per the register's SLA). Prefer bumping the direct dependency that pulls in the vulnerable transitive; only add an explicit top-level pin as a last resort.
- **Deprecated**: add to `TECH_DEBT.md` (Category: Dependencies) with the recommended replacement.
- **Outdated (no advisory)**: only flag majors or security-relevant minors. Do not churn the lockfile for cosmetic bumps (Leanness — no busywork).

Verify the fix builds and tests pass before recommending the bump.

## 3. Automate (pick one, once per repo)

- **GitHub-hosted**: add `.github/dependabot.yml` with a `nuget` ecosystem entry (weekly, grouped minor/patch).
- **Bitbucket Data Center / non-GitHub**: Dependabot is **GitHub-only**. Use **Renovate** (self-hostable, runs in Bitbucket Pipelines / Bamboo / Jenkins) with a `renovate.json`, **or** add a CI step that runs `dotnet list package --vulnerable --include-transitive` and fails the build on any advisory. See the "Running on Bitbucket Data Center" section of the README.

Recommend exactly one mechanism; do not configure both.
