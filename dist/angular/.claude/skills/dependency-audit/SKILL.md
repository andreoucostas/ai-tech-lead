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

## 1. Scan now

Run, from the project root:

```
npm audit
npm outdated
npx ng update            # lists Angular packages with available updates (no changes applied)
```

Read the output. For each advisory, note the package, severity, the path that pulls it in (direct vs transitive), and the first fixed version.

## 2. Triage

- **Vulnerable**: this is a security finding. Log Critical/High to `SECURITY_FINDINGS.md` if your repo uses the security register (Critical → today + 7 days, High → today + 30 days); otherwise add to `TECH_DEBT.md` (Category: Security). Prefer `npm audit fix` for non-breaking fixes; review breaking fixes manually. Avoid blanket `npm audit fix --force` — it can install majors and break the build.
- **Deprecated**: add to `TECH_DEBT.md` (Category: Dependencies) with the recommended replacement.
- **Outdated (no advisory)**: only flag majors or security-relevant updates. Use `ng update` (not hand-edited `package.json`) for `@angular/*` and ecosystem packages so migrations run. Do not churn the lockfile for cosmetic bumps (Leanness — no busywork).

Verify `npm ci` resolves and `ng build` + `ng test` pass before recommending the bump.

## 3. Automate (pick one, once per repo)

- **GitHub-hosted**: add `.github/dependabot.yml` with an `npm` ecosystem entry (weekly, grouped minor/patch).
- **Bitbucket Data Center / non-GitHub**: Dependabot is **GitHub-only**. Use **Renovate** (self-hostable, runs in Bitbucket Pipelines / Bamboo / Jenkins) with a `renovate.json`, **or** add a CI step that runs `npm audit --audit-level=high` and fails the build on advisories. See the "Running on Bitbucket Data Center" section of the README.

Recommend exactly one mechanism; do not configure both.
