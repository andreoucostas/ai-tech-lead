---
name: dependency-audit
description: >
  Use when the user wants to find vulnerable, deprecated, or outdated NuGet packages, set up
  automated dependency scanning, or move .NET to a newer major version. Covers the evidenced scan,
  register triage, and Dependabot (GitHub) or Renovate (host-agnostic, works with Bitbucket Data
  Center).
  USE FOR: pre-release dependency audits, a CVE advisory, ongoing automated updates, upgrading
  .NET (with ASP.NET Core and EF Core) to a newer major.
  DO NOT USE FOR: adding a new package for a feature (just add it).
---

# Dependency audit, automated scanning, and major upgrades

**Applicability gate:** first confirm a committed `*.csproj` or an actual NuGet manifest/package
graph. A `.sln` alone may contain only SSDT/`*.sqlproj` projects and is not .NET/NuGet evidence. If
none exists, report this skill as not applicable; the dotnet delivery profile alone is not package
evidence, and a warehouse-only repository must not acquire NuGet tooling incidentally.

## 1. Scan now

Derive each vulnerability, deprecated-package, and outdated-package command from `AGENTS.md >
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
`AGENTS.md > Conventions > Verification Commands`, committed CI, scripts, manifests, and
configuration. Report unavailable categories; do not infer a solution-level command.

## 3. Automate (pick one, once per repo)

- **GitHub-hosted**: add `.github/dependabot.yml` with a `nuget` ecosystem entry (weekly, grouped minor/patch) for the evidenced package root.
- **Bitbucket Data Center / non-GitHub**: Dependabot is **GitHub-only**. Use **Renovate** (self-hostable, runs in Bitbucket Pipelines / Bamboo / Jenkins) with a `renovate.json`, **or** add a CI step that runs an exact repository-evidenced audit command and fails on the documented threshold. If none is evidenced, report audit automation as **not available**; do not invent one.

Recommend exactly one mechanism; do not configure both.

## 4. Upgrade .NET to a newer major

Move straight to the target major, the newest LTS unless the developer chooses otherwise; never
commit an intermediate major, because an out-of-support target framework raises NETSDK1138, which
warnings-as-errors turns into a failed build. The upgrade ends on a green tree committed on its
own, with no refactoring or feature work mixed in. When a source named below cannot be opened, say
so and ask the developer; never list versions, dates, or breaking changes from memory. A .NET
Framework project (`net4x`, or a non-SDK-style project file) needs a port, not this procedure:
report it and stop.

1. **Inventory from files.** Read `global.json` (SDK version, `rollForward`), each
   `Directory.Build.props` and `Directory.Packages.props`, every `*.csproj` `TargetFramework(s)`,
   `LangVersion`, `Nullable`, `TreatWarningsAsErrors`, `AnalysisLevel`, `.config/dotnet-tools.json`,
   Dockerfile base images, and SDK or runtime pins in committed CI. Report the current and target
   majors with evidence paths and the support dates from
   <https://dotnet.microsoft.com/platform/support/policy/dotnet-core>.
2. **Blockers before edits.** Run the evidenced build and test commands for a green baseline.
   Confirm every non-Microsoft package supports the target framework (its package page or release
   notes). Ask the developer to confirm the target SDK is installed wherever the recorded commands
   run, and which SDK version to pin; edit nothing until they do. Name the other installs as
   developer actions: the SDK on other machines and build agents, a Visual Studio version that
   supports it (listed on the SDK download page), and the runtime or IIS Hosting Bundle on servers.
   Stop and report a red baseline or an unsupported package; install nothing yourself.
3. **Read the breaking changes** of every major after the current one up to the target, in order,
   from `https://learn.microsoft.com/dotnet/core/compatibility/<major>.0`; each page links that
   major's ASP.NET Core and EF Core pages, which apply when those packages are referenced. List
   only the entries that match code or configuration in this repository.
4. **Move to the target.** Set `global.json` to the SDK version the developer named and change each
   target framework, keeping platform suffixes such as `-windows`; a multi-targeted library adds the
   new target instead of dropping one its consumers still use. Runtime-versioned packages
   (`Microsoft.AspNetCore.*`, `Microsoft.EntityFrameworkCore.*`, `Microsoft.Extensions.*`,
   `System.Net.Http.Json`, and tools such as `dotnet-ef`) move to the target major together; a
   package with its own version line moves to a release that supports the target. Move committed
   runtime pins in the same change: Dockerfile base-image tags and SDK or runtime versions in CI
   YAML. Fix the matched breaking changes.
5. **Treat new warnings as findings.** A new SDK can add analyzer rules under a `latest`
   `AnalysisLevel`, new nullable annotations, and (from .NET 10) audit warnings for transitive
   packages (NU1901–NU1904). Fix them, triaging vulnerabilities as in the Triage section. The only
   permitted deferrals: pin `AnalysisLevel` to the previous major, or lower one analyzer or nullable
   rule's severity by its code, each recorded in `TECH_DEBT.md` (Category: Standards); suppress one
   advisory with `NuGetAuditSuppress` only beside its `SECURITY_FINDINGS.md` row. Never add a
   blanket `NoWarn`, turn warnings-as-errors off, or set `NuGetAuditMode` to `direct` to go green.
6. **Verify and commit.** Run the evidenced build and test commands. Where EF Core migrations are
   evidenced, use only an evidenced non-mutating check for model changes and review any schema
   change before it is applied. Commit the upgrade on its own.
7. **Close out.** Update statements of the old version in `AGENTS.md` and docs, except the
   `framework-owned/overwritten` paths in `framework-ownership.json`, and list what the developer
   still has to do (the SDK on build agents and other machines, the runtime or Hosting Bundle on
   servers, deployment). Use `create-adr` only for a lasting choice the upgrade forced, such as
   holding a package on an older major or pinning `AnalysisLevel`.
