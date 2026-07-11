# ai-tech-lead

**AI Tech Lead** is a per-repository instruction layer — `CLAUDE.md`/`AGENTS.md`, skills,
commands, subagents, and deterministic hooks — that makes AI coding agents (Claude Code and
GitHub Copilot, dual-surface) follow a team's conventions, architecture, and risk posture instead
of inventing their own. It targets .NET and Angular shops running on Bitbucket Data Center and
Windows, and ships enforcement as code (build-time gates, write-time guards, an audit trail) next
to the instructions, not just prose the model might skip.

This repository is the **authoring repo** for the framework, not a consumer project. It used to
be two separate template repos — `ai-tech-lead-dotnet` and `ai-tech-lead-angular` — merged into
one with history preserved. Shared content (conventions, skills, hooks, commands) is authored
**once** under `src/core/`, with per-stack differences layered in from `src/stacks/{dotnet,
angular,monorepo}/`. A deterministic composer (`scripts/build.ps1`/`.sh`) reads that single
source and emits three installable, committed distributions under `dist/`: `dist/dotnet`,
`dist/angular`, and `dist/monorepo` (for repos that mix both stacks — e.g. a .NET API with a
colocated Angular SPA). Consumers never see `src/`; they install straight from a `dist/`.

`dist/` is generated output, `linguist-generated`, and never hand-edited — CI rebuilds all three
dists on every push/PR and fails if the rebuild differs from what's committed, so `dist/` is
always provably fresh against `src/`.

## Installing

There are two ways in: the **root installer**, which auto-detects which stack a target repo
needs, or a **dist installer**, run directly when you already know the stack. Both understand
three install modes on the target repo: **greenfield** (no AI tooling yet — plain copy),
**brownfield** (existing AI tooling — originals are archived to `docs/pre-adoption/` and a
`.claude/adoption-pending.json` is written for `/adopt` to pick up), and **update** (target
already has a `.claude/framework-version.json` stamp — framework machinery is refreshed,
consumer-owned content like `CLAUDE.md` is left alone).

| Dist | Who it's for | Root installer (auto-detect) | Direct dist installer |
|------|---------------|-------------------------------|------------------------|
| `dist/dotnet` | .NET solutions (`*.csproj`/`*.sln` present) | `bash install.sh /path/to/repo` or `pwsh install.ps1 /path/to/repo` | `bash dist/dotnet/scripts/install.sh /path/to/repo` or `pwsh dist/dotnet/scripts/install.ps1 /path/to/repo` |
| `dist/angular` | Angular workspaces (`angular.json` present) | same, auto-detects `angular` | `bash dist/angular/scripts/install.sh /path/to/repo` |
| `dist/monorepo` | Mixed repos — both a `.csproj`/`.sln` **and** an `angular.json` present (searched at the target root and two directory levels below) | same, auto-detects `monorepo` (union of both stacks' rails) | `bash dist/monorepo/scripts/install.sh /path/to/repo` |

Pass `--stack dotnet|angular|monorepo` (`-Stack` on the PowerShell side) to override
auto-detection. On an existing install, the root installer defaults to whatever stack is
recorded in the target's `.claude/framework-version.json` (update mode) rather than
re-detecting. The root installers are a thin dispatcher only — all real copy/detect logic lives
in the chosen dist's own `scripts/install.{sh,ps1}`.

## Quick start

Installing a .NET repo, auto-detected:

```bash
bash install.sh /path/to/your-repo
# or, on Windows:
pwsh install.ps1 C:\path\to\your-repo
```

Installing a mixed .NET + Angular repo, forcing the monorepo dist explicitly:

```bash
bash install.sh --stack monorepo /path/to/your-repo
```

After the copy lands and is committed in the target repo, a developer starts a Claude Code (or
Copilot) session there and runs `/bootstrap` (greenfield) or `/adopt` (brownfield) to populate
`CLAUDE.md`/`TECH_DEBT.md` from the real codebase. See a dist's own `README.md` (e.g.
[`dist/dotnet/README.md`](./dist/dotnet/README.md)) for the full consumer-facing walkthrough —
that's the document a developer actually reads after installing; this root README only covers
getting the framework itself into a repo.

## Repo layout

| Path | What it is |
|------|-----------|
| `src/core/` | Single-source shared content — the common files, with `@@INCLUDE:NAME@@` markers where stacks diverge. |
| `src/stacks/{dotnet,angular,monorepo}/` | Per-dist `snippets/` (marker content) and `files/` (whole-file overrides + stack-only files). |
| `dist/{dotnet,angular,monorepo}/` | **Generated**, committed golden output. Never hand-edited — CI rebuilds and diffs it against `src/` on every push/PR. |
| `scripts/` | The composer and its gates, each as a `.ps1`/`.sh` twin: `build`, `validate-dist`, `fidelity-check`. |
| `install.ps1` / `install.sh` | Root installers — detect the target's stack (or read `--stack`) and delegate to the matching dist installer. |
| `docs/` | `BACKLOG.md` (work list), `workspace-decisions.md` (ADR log), `ci-handover.md`, legacy changelogs. |
| `.github/workflows/ci.yml` | The CI gate — see below. |
| `CLAUDE.md` / `AGENTS.md` | Governance for developing *this* repo (maintainer instructions — not shipped; distinct from the `CLAUDE.md` templates inside each `dist/`). |
| `DEVELOPING.md` | Operational runbook: the exact commands behind every gate below. |
| `.claude/` | Maintainer-only meta layer (hooks, release automation, plans). Never ships. |

## How it's built and validated

`scripts/build.ps1`/`.sh` is the composer: it reads `src/core` plus the target dist's
`src/stacks/<dist>/` overrides and writes a complete `dist/<dist>/` tree. Three gates run against
that output — `validate-dist` (marker resolution, JSON validity, `bash -n`, PowerShell AST parse,
and each dist's own `template-checks` for `CLAUDE.md`↔`AGENTS.md` mirror parity), `fidelity-check`
(a strict byte-for-byte comparison of `dist/dotnet` and `dist/angular` against the frozen
`freeze-v0.25.5` baseline from the pre-merge legacy repos — green until the v0.26.0 release
deliberately changes shipped content and retires that baseline; `dist/monorepo` has no baseline,
it's a new capability), and each dist's own hook test suite
(`dist/<dist>/tests/hooks/Invoke-HookTests.ps1`, a dependency-free PowerShell harness that pipes
JSON fixtures at every hook and asserts both the bash and PowerShell twin agree). CI
(`.github/workflows/ci.yml`) runs all of it on two legs — a Windows leg that rebuilds with the
`.ps1` composer and a Linux leg that rebuilds with the `.sh` twin — so composer twin divergence
fails a leg on its own. Full command recipes, including how to run any single gate by hand, are
in [`DEVELOPING.md`](./DEVELOPING.md).

## Status

Current shipped version is **v0.25.5** across all three dists (`dist/*/.claude/framework-version.json`).
This is the fidelity-frozen migration baseline inherited from the legacy repos — no shipped
content changes until **v0.26.0**, which is pending final migration validation (Phase 6 of the
merge plan: rerun the full gate matrix, then consciously retire the v0.25.5 fidelity baseline and
fold in queued shipped-workflow updates). The two legacy repos, `ai-tech-lead-dotnet` and
`ai-tech-lead-angular`, are still live but frozen at v0.25.5 pending that release; they will be
archived with a pointer to this repo once v0.26.0 ships.

## Maintainer docs

- [`CLAUDE.md`](./CLAUDE.md) — how to develop the framework itself: repo map, meta-invariants, workflows.
- [`DEVELOPING.md`](./DEVELOPING.md) — command recipes behind every gate described above.
- [`docs/BACKLOG.md`](./docs/BACKLOG.md) — the prioritized work list.
- [`docs/workspace-decisions.md`](./docs/workspace-decisions.md) — the ADR log for framework-level decisions (merge strategy, mirror strategy, hook semantics, composition rules).
