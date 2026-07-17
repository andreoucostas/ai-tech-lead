# ai-tech-lead

> **Want to *use* the framework in your repo? → go to [`dist/`](./dist).** Pick your stack
> (`dist/dotnet`, `dist/angular`, `dist/monorepo`) and read its `README.md` — that is the whole
> product, and it is the only thing that ships. **Everything else in this repo is how the framework
> is *built*, and is written for its maintainers.**

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

The installers run *from a local clone of this repo* against a target repo elsewhere on disk — so
get the framework first, then point it at your codebase:

```bash
git clone https://github.com/andreoucostas/ai-tech-lead.git
cd ai-tech-lead
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
| `src/core/` | Single-source shared content — the common files, with `<!-- @stack:NAME -->` markers where stacks diverge. |
| `src/stacks/{dotnet,angular,monorepo}/` | Per-dist `snippets/` (marker content) and `files/` (whole-file overrides + stack-only files). |
| `dist/{dotnet,angular,monorepo}/` | **Generated**, committed golden output. Never hand-edited — CI rebuilds and diffs it against `src/` on every push/PR. |
| `scripts/` | The composer and its gates, each as a `.ps1`/`.sh` twin: `build`, `validate-dist`, `fidelity-check`. |
| `install.ps1` / `install.sh` | Root installers — detect the target's stack (or read `--stack`) and delegate to the matching dist installer. |
| `meta/` | **The maintainer layer, kept out of the product's way:** `BACKLOG.md` (work list), `workspace-decisions.md` (ADR log), `LEARNINGS.md` (meta-dev log), `ci-handover.md`, `changelogs/` (frozen pre-merge history). Never ships. |
| `.github/workflows/ci.yml` | The CI gate — see below. |
| `CLAUDE.md` / `AGENTS.md` | Governance for developing *this* repo (maintainer instructions — not shipped; distinct from the `CLAUDE.md` templates inside each `dist/`). They must sit at the repo root for Claude Code to load them, so they keep an explicit "you are in the authoring repo" banner as the tie-breaker. |
| `DEVELOPING.md` | Operational runbook: the exact commands behind every gate below. |
| `.claude/` | Maintainer-only Claude Code config (hooks, release automation, plans). Never ships. |

## How it's built and validated

`scripts/build.ps1`/`.sh` is the composer: it reads `src/core` plus the target dist's
`src/stacks/<dist>/` overrides and writes a complete `dist/<dist>/` tree. Two gates run against
that output — `validate-dist` (marker resolution, JSON validity, `bash -n`, PowerShell AST parse,
each dist's own `template-checks` for `CLAUDE.md`↔`AGENTS.md` mirror parity, and `no-meta-leak`,
which fails if maintainer vocabulary reaches a shipped file) and each dist's own hook test suite
(`dist/<dist>/tests/hooks/Invoke-HookTests.ps1`, a dependency-free PowerShell harness that pipes
JSON fixtures at every hook and asserts both the bash and PowerShell twin agree). CI
(`.github/workflows/ci.yml`) runs those, plus a freshness check that the rebuild matches the
committed `dist/`, on two legs — a Windows leg that rebuilds with the `.ps1` composer and a Linux
leg that rebuilds with the `.sh` twin — so composer twin divergence fails a leg on its own.
`scripts/fidelity-check` (byte-compare of `dist/{dotnet,angular}` against the pre-merge
`freeze-v0.25.5` baseline) was **retired from CI at v0.26.0**, which deliberately changed shipped
content; it remains for manual re-audit. Full command recipes, including how to run any single gate
by hand, are in [`DEVELOPING.md`](./DEVELOPING.md).

## Status

Current shipped version is **v0.33.0** across all three dists
(`dist/*/.claude/framework-version.json`). The merge is complete: this repo is the single home for
framework development, and the two legacy repos (`ai-tech-lead-dotnet`, `ai-tech-lead-angular`) are
archived and read-only, frozen at v0.25.5.

## Maintainer docs

- [`CLAUDE.md`](./CLAUDE.md) — how to develop the framework itself: repo map, meta-invariants, workflows.
- [`DEVELOPING.md`](./DEVELOPING.md) — command recipes behind every gate described above.
- [`meta/BACKLOG.md`](./meta/BACKLOG.md) — the prioritized work list.
- [`meta/workspace-decisions.md`](./meta/workspace-decisions.md) — the ADR log for framework-level decisions (merge strategy, mirror strategy, hook semantics, composition rules).
- [`meta/LEARNINGS.md`](./meta/LEARNINGS.md) — the meta-dev log: what went wrong building this and what changed as a result.
