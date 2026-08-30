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

Two decisions are non-negotiable: always run the framework-state leg, and explicitly identify the
repository-evidenced code gates for every profile that is actually present. Do not infer that both
application stacks exist from the installed distribution, and do not turn a missing command into a
false green.

### Leg 1 — framework-state check (shipped with this repo)

`docs-sync-check` also runs `wiki-check`, validating the team wiki schema, index, and injection screen.
It also runs `hazard-check`, validating hazard-table Status tokens, Reviewed dates, and named paths.
`framework-doctor` is a developer-machine diagnostic, not a CI gate; keep `docs-sync-check` as the required build check.


```
bash scripts/docs-sync-check.sh          # Linux build agents
pwsh -NoProfile -File scripts/docs-sync-check.ps1   # Windows build agents
```

On supported Windows/Linux hosts, there are no dependencies beyond bash **or** PowerShell. Exit `0` = pass, non-zero = fail,
findings printed to stdout. It verifies the framework itself is healthy: adoption completed (no
`adoption-pending.json`), `CLAUDE.md` bootstrapped, `AGENTS.md` / `copilot-instructions.md`
mirrors current, version stamps in sync, hook twins and BOM intact (via `template-checks`).

**What it does *not* do: gate your code.** A commit with a hardcoded secret, a skipped test, a
suppressed warning, an `fdescribe`, or an `eslint-disable` passes leg 1. That is leg 2's job.

### Leg 2 — code-standards gate (your toolchain)

Use the exact build, test, format, lint, migration/deploy, and data-validation commands recorded by
`/bootstrap` in `CLAUDE.md > Conventions > Verification Commands`. That six-category inventory must
cite committed evidence: an existing CI definition, repository script/task runner, documented
command, manifest, or tool configuration.
The installed `monorepo` distribution is not evidence that either application stack—or its usual
commands—exists.

An evidenced .NET or Angular application may already use `dotnet`, `npm`, `npx eslint`, or `ng`
commands; run only the exact commands the repository supports, and only for profiles present in the
change. For SQL/SSDT/dbt or warehouse sources, preserve their existing project-native
migration/deploy and data-validation checks when evidenced. Do not introduce any tool merely to
fill this recipe.

Inventory is not execution authority. Add a migration/deploy command to a PR build only when the
repository already establishes that exact command as a controlled CI validation/deployment gate
with a known target, or when it is explicitly evidenced as a non-mutating validation/dry-run.
Otherwise keep it documented as `manual/CI-only` and do not add or run it as PR verification.

If a verification category has no evidenced command, record `not available` in the build result and
CI documentation. Leg 1 can still gate framework state, but it is not a code-validation pass;
creating a real code gate is an explicit follow-up rather than a success claim.

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

Start from `scripts/ci/bamboo-spec.example.yaml`. Replace its project/plan keys and link the plan
to this repository. The sample creates branch plans, but it does **not** make itself blocking:
enable the Bitbucket repository trigger and configure the required-build merge check above for
the reported Bamboo build key.

One plan, one job, two script tasks (order matters — fail fast on framework state):

- **Task 1 (Script)**: inline, interpreter *Shell* on Linux agents — `bash scripts/docs-sync-check.sh`
  — or *Windows PowerShell* on Windows agents — `pwsh -NoProfile -File scripts/docs-sync-check.ps1`.
- **Task 2 (Script)**: the exact applicable commands from `CLAUDE.md > Conventions > Verification
  Commands` whose execution policy permits this CI context. If it says `not available` or marks a
  command manual/CI-only without an established controlled CI target, omit that command and record
  the gap; do not substitute distribution-default commands.
- Trigger: *Bitbucket Server repository triggered*; branch plan creation for PRs enabled, so every
  PR branch gets a build and therefore a build status for the merge check.

## Jenkins recipe

```groovy
// Reference shape — use only repository-evidenced profiles and commands.
pipeline {
  agent any
  stages {
    stage('Framework state') {
      steps { sh 'bash scripts/docs-sync-check.sh' }   // or: pwsh 'scripts/docs-sync-check.ps1'
    }
  }
}
```

Add a second `Repository-evidenced code gates` stage only when `/bootstrap` recorded applicable
commands; put those exact commands in its `steps`. If they are `not available`, leave the stage
out and report the code-gate gap.

With the Bitbucket Branch Source plugin, PR branches build automatically and the build status
feeds the required-builds merge check.

> These recipes are **reference configurations**: they document the expected shape, but your
> agent labels, tool provisioning, and plan naming are yours. Verify the first run end-to-end —
> open a deliberately-failing PR using a failure your evidenced code gate detects and confirm the
> merge button locks. If the command inventory says `not available`, do not claim this verification.

## Recommended alongside (not part of the required build)

- **Native secret scanning** — Bitbucket DC 8.12+ ships push-time secret scanning; a project
  admin can enable blocking mode. Zero custom code; covers every push including `--no-verify`.
- **Code Insights** — optionally publish leg 1/leg 2 verdicts to the PR view via the REST API
  (`/rest/insights/1.0/...`). Cosmetic on top of required builds, not a substitute.
- **Renovate / Semgrep or SonarQube** — dependency and SAST scanning; see the README's
  "Standing scanners on Bitbucket" section.

## What CI still cannot gate

Semantic standards — Leanness, SOLID beyond dependency direction, test *quality* beyond what the
analyzers and lint rules catch — have no deterministic check. They are enforced by `/review` +
`/security-review` before push and by human PR review. The required build is the floor, not the
ceiling; see `docs/enforcement-surfaces.md` for the full guaranteed-vs-instructed matrix.
