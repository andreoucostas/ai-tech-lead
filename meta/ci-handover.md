# CI handover — what to wire into the pipeline (team copy)

**Audience:** the team operating repos built from `ai-tech-lead-dotnet` / `ai-tech-lead-angular`
on Bitbucket Data Center with Bamboo/Jenkins.
**Canonical reference:** each repo ships `docs/ci-integration.md` (v0.24.2+) with the full recipe;
this page is the one-screen handover summary across both stacks.

## Why this matters (one paragraph)

Everything the AI framework does *inside* the editor is either an instruction the model is asked
to follow, or a hook that only fires on some tools/versions. The CI required build is the one
gate that binds **every actor** — any AI agent, any IDE, any human, any `git commit --no-verify`.
If the required build is not wired, the framework's standards are requests, not rules.

## The required build — one plan/job per repo, two steps, in this order

| Step | What runs | What it gates | Artifact (ships in the repo) |
|---|---|---|---|
| 1. Framework state | Linux agent: `bash scripts/docs-sync-check.sh` — Windows agent: `pwsh -NoProfile -File scripts/docs-sync-check.ps1` | Adoption completed, CLAUDE.md bootstrapped, AGENTS.md/copilot-instructions mirrors current, version stamps, hook twins + BOM | `scripts/docs-sync-check.sh` / `.ps1` (exit 0 = pass) |
| 2a. Standards gate (.NET repos) | `dotnet build --configuration Release -warnaserror` then `dotnet test --configuration Release --no-build` | Warnings, analyzer findings, skipped tests (`xUnit1004`), failing tests, NetArchTest layering (if wired) | `scripts/ci/Directory.Build.props.sample` — wire via the `enforce-standards` skill |
| 2b. Standards gate (Angular repos) | `npm ci` → `npx eslint .` → `npx ng build --configuration production` → `npx ng test --watch=false --browsers=ChromeHeadless` | `@ts-ignore`, `eslint-disable` (dead via `noInlineConfig`), `fdescribe`/`xit`, lint errors, failing build/specs, dependency-cruiser boundaries (if wired) | `scripts/ci/eslint-standards.sample.mjs` — wire via the `enforce-standards` skill |

**Triggers:** every PR targeting `main`/`master`, and every push to `main`/`master`.

## Bitbucket configuration (repo/project admin — no server plugins needed)

1. Ensure the CI server reports build status to Bitbucket per commit (Bamboo: automatic via the
   application link; Jenkins: Bitbucket Branch Source plugin or a build-status notifier).
2. **Repository settings → Merge checks → Required builds** → require the plan/job above on
   `main`/`master`. The merge button now locks until the build is green.
3. **Enable native secret scanning** (Bitbucket DC 8.12+), blocking mode — push-time secret
   blocking with zero custom code, covers `--no-verify` pushes too.

## Acceptance check (do this once per repo — don't skip)

Open a deliberately-failing PR and confirm the merge button locks:
- .NET repo: add `#pragma warning disable` anywhere, or `[Fact(Skip = "x")]` to a test.
- Angular repo: add an `fdescribe` to any spec, or an `// eslint-disable-next-line`.

If the merge button does not lock, the required-builds merge check is not wired to the right
build key — fix that before trusting anything else on this page.

## What this pipeline does NOT cover (so nobody assumes it does)

- Semantic standards — Leanness, most of SOLID, test *quality* beyond analyzer/lint reach.
  Those are enforced by `/review` + `/security-review` before push and by human PR review.
- The in-editor write guard and prompt routing — those depend on the AI surface
  (Copilot Preview agent-hooks / CLI version); see `docs/enforcement-surfaces.md` in each repo.

## Artifact inventory (quick reference)

Shipped in every consumer repo, maintained by framework updates — do not hand-edit:
- `scripts/docs-sync-check.sh` / `.ps1` — the framework-state check (step 1).
- `scripts/template-checks.sh` / `.ps1` — invoked by step 1 internally; version/mirror/BOM/twin gates.
- `docs/ci-integration.md` — the full recipe (Bamboo task-by-task, Jenkinsfile example).
- `scripts/ci/bitbucket-pipelines.example.yml` — Bitbucket **Cloud** only; not applicable on DC.

Wired once per repo by a developer (via the `enforce-standards` / `enforce-architecture` skills),
then owned by the repo:
- .NET: `Directory.Build.props` (+ `.editorconfig` severities), optional NetArchTest test project.
- Angular: standards fragment merged into `eslint.config.js`, optional `.dependency-cruiser.js`.
