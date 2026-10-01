---
name: dependency-audit
description: >
  Use when the user wants to find vulnerable, deprecated, or outdated NuGet and/or npm packages
  evidenced by the repository, set up automated dependency scanning, or move .NET or Angular to a
  newer major version. Covers applicable dotnet and npm scans, Dependabot (GitHub) or Renovate
  (host-agnostic, works with Bitbucket Data Center), and the upgrade of each evidenced stack.
  USE FOR: pre-release dependency audits, a CVE advisory, ongoing automated updates, upgrading
  .NET (with ASP.NET Core and EF Core) or Angular to a newer major.
  DO NOT USE FOR: adding a new package for a feature (just add it).
---

# Dependency audit, automated scanning, and major upgrades

First identify package ecosystems from committed manifests and lock files. Scan and automate only
the evidenced ecosystem(s) the change touches; for a repo-wide audit, cover every evidenced
ecosystem. The monorepo delivery profile alone proves neither NuGet nor npm is present.

**Applicability gate:** if neither a committed .NET/NuGet surface nor an npm package manifest is
evidenced, report this skill as **not applicable** and do not add package-management tooling.

## 1. Scan now

**.NET** — only when a committed `*.csproj` or an actual NuGet manifest/package graph is evidenced;
a `.sln` alone may contain only SSDT/`*.sqlproj` projects and does not qualify. Derive each
vulnerability, deprecated-package, and outdated-package command from AGENTS.md > Conventions >
Verification Commands, committed CI, scripts, manifests, and configuration. Record the exact
command and its evidence path before running it. Run only the evidenced form and report every
unavailable scan category as **not available**; do not infer a `dotnet` command, target, or flag.

**Angular/npm** — only when the relevant package manifest and configured targets are evidenced.
Derive each vulnerability, outdated-package, and Angular-migration-preview command from the same
evidence inventory. Record the exact command and its evidence path before running it. Run only the
evidenced form and report every unavailable scan category as **not available**; do not infer `npm`,
`npx`, an Angular CLI command, or flags (section 4's `ng update` excepted).

Read the output. For each **vulnerable** or **deprecated** package, note the package, current version, the advisory severity, the path that pulls it in (direct vs transitive), and the first fixed version.

## 2. Triage

- **Vulnerable (transitive or direct)**: this is a security finding. Append a row to `SECURITY_FINDINGS.md` if your repo uses the security register (Critical → today + 7 days, High → today + 30 days, per the register's SLA); otherwise add to `TECH_DEBT.md` (Category: Security).
  - **.NET:** prefer bumping the direct dependency that pulls in the vulnerable transitive; only add an explicit top-level pin as a last resort.
  - **Angular:** use a non-breaking remediation only when its exact command is evidenced; review breaking remediations manually. Avoid blanket force upgrades — they can install majors and break the build.
- **Deprecated**: add to `TECH_DEBT.md` (Category: Dependencies) with the recommended replacement.
- **Outdated (no advisory)**: only flag majors or security-relevant updates. Do not churn the lockfile for cosmetic bumps (Leanness — no busywork). On the Angular side, an `@angular/*` major uses section 4; for other `@angular/*` and ecosystem updates, use an exact evidenced migration command so migrations run; do not hand-edit `package.json` or infer an Angular CLI command (section 4's `ng update` excepted).

Before recommending the bump, run the exact dependency-install, build, and test commands evidenced for each touched ecosystem by `AGENTS.md > Conventions > Verification Commands`, committed CI, scripts, manifests, and configuration. Report unavailable categories; do not infer a stack command from this distribution (section 4's `ng update` excepted).

## 3. Automate (pick one mechanism, once per repo)

- **GitHub-hosted**: add `.github/dependabot.yml` with an entry for each evidenced package ecosystem (`nuget`, `npm`, or both), weekly and grouped minor/patch.
- **Bitbucket Data Center / non-GitHub**: Dependabot is **GitHub-only**. Use **Renovate** (self-hostable, runs in Bitbucket Pipelines / Bamboo / Jenkins) with a `renovate.json` and let it detect committed manifests, **or** add only exact repository-evidenced audit commands to CI. If none is evidenced, report audit automation as **not available**; do not invent one.

Recommend exactly one mechanism covering every evidenced ecosystem; do not configure both Dependabot and Renovate.

## 4. Upgrade .NET or Angular to a newer major

Upgrade only the evidenced stack the user named, one stack per pass: each pass ends on a green tree
committed on its own, with no refactoring, feature work, or change to the other stack mixed in.
When a source named below cannot be opened, say so and ask the developer; never list versions,
dates, ranges, or breaking changes from memory.

### .NET

Move straight to the target major, the newest LTS unless the developer chooses otherwise; never
commit an intermediate major, because an out-of-support target framework raises NETSDK1138, which
warnings-as-errors turns into a failed build. A .NET Framework project (`net4x`, or a non-SDK-style
project file) needs a port, not this procedure: report it and stop.

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

### Angular

Move one major per pass, as Angular's release policy requires
(<https://angular.dev/reference/releases>). An AngularJS (`angular` 1.x) app needs a rewrite, not
this procedure: report it and stop.

1. **Inventory from files.** Read the `@angular/*`, `@angular/cli`, TypeScript, RxJS, and
   `zone.js` versions from `package.json` and the lockfile (the lockfile names the package
   manager), the builders in `angular.json`, and Node pins (`engines`, `.nvmrc`, committed CI).
   Report the current and next majors with evidence paths and their support dates from the
   releases page.
2. **Blockers before edits.** Run the evidenced install, build, and test commands for a green
   baseline. Check the next major's Node, TypeScript, and RxJS ranges at
   <https://angular.dev/reference/versions> and every third-party Angular library's peer range for
   that major. When the next major needs a different Node, ask the developer to confirm it is
   installed wherever the recorded commands run; edit nothing until they do. Name Node on other
   machines and build agents as a developer action. Stop and report a red baseline or an
   unsupported library.
3. **Read the breaking changes** of the next major: the **Breaking Changes** sections of its
   `.0.0` release in the GitHub `CHANGELOG.md` or release page of `angular/angular` and
   `angular/angular-cli`, and of `angular/components` when `@angular/material` or `@angular/cdk` is
   evidenced. List only the items that apply to this repository.
4. **Update with the migrations.** From a clean working tree, update `@angular/core` and
   `@angular/cli` to the next major, plus evidenced first-party packages such as
   `@angular/material`, with `ng update` through the workspace's own CLI and package manager. This
   is the one Angular CLI command this skill derives without a Verification Commands row, because
   the Angular documentation names it as the migration path: show the exact command and get the
   developer's go-ahead first. Never add `--force`, which ignores peer-dependency mismatches. Read
   the migration output beside the breaking changes and review every file the migrations changed.
   Move committed Node pins (`.nvmrc`, `package.json` `engines`, CI YAML) to the next major's range
   in the same pass.
5. **Keep the pass narrow.** Accept the migrations the update requires. Optional modernisations,
   and defaults that apply to new projects (builder, test runner, change detection, standalone), are
   separate `/refactor` or `/design` work.
6. **Verify and commit the pass.** Run the evidenced install, build, lint, and test commands, fix
   what the breaking changes predict, and triage new audit findings as in the Triage section.
   Commit this major alone, then return to item 2 for the next major.
7. **Close out.** Update statements of the old version in `AGENTS.md` and docs, except the
   `framework-owned/overwritten` paths in `framework-ownership.json`, and list what the developer
   still has to do (Node on build agents and other machines, deployment). Use `create-adr` only for
   a lasting choice the upgrade forced, such as holding a library on an older major.
