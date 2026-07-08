# CI integration — the required build we expect on every repo

The framework's local layer (hooks, instructions, skills) shapes what the AI agent does **while
it works** — but every local control is either instruction-shaped (the model is told, not forced)
or attached to a specific tool (Claude Code, Copilot CLI, VS Code Preview hooks) that a given
developer may not be running. The only gate that constrains **every actor** — any agent, any IDE,
any human, any `--no-verify` — is your CI server.

**So the expectation is explicit: every repo using this framework wires one *required build* in
its own CI (Bamboo, Jenkins, TeamCity — whatever the team already runs) that must pass before a
PR can merge.** This document is the recipe. It assumes Bitbucket Data Center; on GitHub the
shipped `docs-sync-check.yml` workflow already does the equivalent.

## What the required build must run

Two legs. Both are non-negotiable; each gates a different thing.

### Leg 1 — framework-state check (shipped with this repo)

```
bash scripts/docs-sync-check.sh          # Linux/macOS build agents
pwsh -NoProfile -File scripts/docs-sync-check.ps1   # Windows build agents
```

Host-agnostic, no dependencies beyond bash **or** PowerShell. Exit `0` = pass, non-zero = fail,
findings printed to stdout. It verifies the framework itself is healthy: adoption completed (no
`adoption-pending.json`), `CLAUDE.md` bootstrapped, `AGENTS.md` / `copilot-instructions.md`
mirrors current, version stamps in sync, hook twins and BOM intact (via `template-checks`).

**What it does *not* do: gate your code.** A commit with a hardcoded secret, an `fdescribe`, or an
`eslint-disable` passes leg 1. That is leg 2's job.

### Leg 2 — code-standards gate (your toolchain)

```
npm ci
npx eslint .
npx ng build --configuration production
npx ng test --watch=false --browsers=ChromeHeadless
```

Lint rules configured as **errors** (`@typescript-eslint/ban-ts-comment`, `noInlineConfig`,
focused/disabled-spec bans) are what make `@ts-ignore`, `eslint-disable`, and `fdescribe`
*build-breaking* instead of advisory — the compiler and lint layer are the deterministic
enforcement that AI instructions can never be. Wire them with the `enforce-standards` skill
(`scripts/ci/eslint-standards.sample.mjs`). If the repo has the dependency-cruiser boundary
gate (see the `enforce-architecture` skill), add `npx depcruise src --config .dependency-cruiser.js`
as a step here.

## When it runs

- Every pull request targeting `main`/`master`.
- Every push to `main`/`master` (catches direct pushes and post-merge state).

## Making it blocking on Bitbucket Data Center

Bitbucket DC's **required builds** merge check needs only repository/project admin — no system
admin, no server plugins:

1. Your CI server must report build status to Bitbucket for each commit (Bamboo does this
   automatically via the application link; Jenkins via the Bitbucket Branch Source plugin or a
   build-status notifier).
2. In Bitbucket: **Repository settings → Merge checks → Required builds** → add the build key of
   the plan/job below and require it on `main`/`master`.
3. From then on the merge button stays disabled until the build passes. This is the DC
   equivalent of a required GitHub check.

## Bamboo recipe

One plan, one job, two script tasks (order matters — fail fast on framework state):

- **Task 1 (Script)**: inline, interpreter *Shell* on Linux agents — `bash scripts/docs-sync-check.sh`
  — or *Windows PowerShell* on Windows agents — `pwsh -NoProfile -File scripts/docs-sync-check.ps1`.
- **Task 2 (Script)**: `npm ci && npx eslint . && npx ng build --configuration production && npx ng test --watch=false --browsers=ChromeHeadless`.
- Trigger: *Bitbucket Server repository triggered*; branch plan creation for PRs enabled, so every
  PR branch gets a build and therefore a build status for the merge check.

## Jenkins recipe

```groovy
// Reference configuration — adapt agent labels and Node/Chrome provisioning to your controller.
pipeline {
  agent any
  stages {
    stage('Framework state') {
      steps { sh 'bash scripts/docs-sync-check.sh' }   // or: pwsh 'scripts/docs-sync-check.ps1'
    }
    stage('Lint + build + test (standards gate)') {
      steps {
        sh 'npm ci'
        sh 'npx eslint .'
        sh 'npx ng build --configuration production'
        sh 'npx ng test --watch=false --browsers=ChromeHeadless'
      }
    }
  }
}
```

With the Bitbucket Branch Source plugin, PR branches build automatically and the build status
feeds the required-builds merge check.

> These recipes are **reference configurations**: they document the expected shape, but your
> agent labels, Node/Chrome provisioning, and plan naming are yours. Verify the first run
> end-to-end — open a deliberately-failing PR (e.g. add an `fdescribe` or `// eslint-disable`
> somewhere) and confirm the merge button locks.

## Recommended alongside (not part of the required build)

- **Native secret scanning** — Bitbucket DC 8.12+ ships push-time secret scanning; a project
  admin can enable blocking mode. Zero custom code; covers every push including `--no-verify`.
- **Code Insights** — optionally publish leg 1/leg 2 verdicts to the PR view via the REST API
  (`/rest/insights/1.0/...`). Cosmetic on top of required builds, not a substitute.
- **Renovate / Semgrep or SonarQube** — dependency and SAST scanning; see the README's
  "Standing scanners on Bitbucket" section.

## What CI still cannot gate

Semantic standards — Leanness, SOLID beyond dependency direction, test *quality* beyond what the
lint rules catch — have no deterministic check. They are enforced by `/review` +
`/security-review` before push and by human PR review. The required build is the floor, not the
ceiling; see `docs/enforcement-surfaces.md` for the full guaranteed-vs-instructed matrix.
