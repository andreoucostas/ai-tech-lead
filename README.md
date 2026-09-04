# ai-tech-lead

> **Want to *use* the framework in your repo? → go to [`dist/`](./dist).** Pick your stack
> (`dist/dotnet`, `dist/angular`, `dist/monorepo`) and read its `README.md` — that is the whole
> product, and it is the only thing that ships. **Everything else in this repo is how the framework
> is *built*, and is written for its maintainers.**

**AI Tech Lead** is a per-repository instruction layer — `CLAUDE.md`/`AGENTS.md`, skills,
commands, subagents, and deterministic hooks — that makes AI coding agents (Claude Code and
GitHub Copilot, dual-surface) follow a team's conventions, architecture, and risk posture instead
of inventing their own. It targets .NET and Angular shops running on Bitbucket Data Center and
Windows, and ships machine checks plus scoped write-time guards and local hook-dependent telemetry
next to the instructions. Exact guarantees depend on the client and host prerequisites documented
in each dist's `docs/enforcement-surfaces.md`.

The supported and release-tested host platform is **native Windows**. Claude Code 2.1.141 or newer
is required. PowerShell 7 is preferred; Windows PowerShell 5.1 is the installer and framework-script fallback. Linux, WSL, macOS, BSD, and
Copilot cloud hook execution are unsupported and untested; incidental execution is not a guarantee.

This repository is the **authoring repo** for the framework, not a consumer project. It used to
be two separate template repos — `ai-tech-lead-dotnet` and `ai-tech-lead-angular` — merged into
one with history preserved. Shared content (conventions, skills, hooks, commands) is authored
**once** under `src/core/`, with per-stack differences layered in from `src/stacks/{dotnet,
angular,monorepo}/`. A deterministic PowerShell composer (`scripts/build.ps1`) reads that single
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
already has a `.claude/framework-version.json` stamp). Update has three ownership classes:
consumer-owned protected paths such as `CLAUDE.md` are restored, framework-owned machinery is
overwritten, and mixed-ownership `.claude/settings.json` is backed up to
`.claude/.state/settings.json.pre-update` before it is refreshed and adapted to the host. Preserve
local edits to framework-owned files before updating, and review the resulting diff before commit.

| Dist | Who it's for | Root installer (auto-detect) | Direct dist installer |
|------|---------------|-------------------------------|------------------------|
| `dist/dotnet` | Repositories with `.NET` application evidence, or warehouse-SQL repositories with at least two independent warehouse signal categories | `pwsh -NoProfile -File install.ps1 C:\path\to\repo` | `pwsh -NoProfile -File dist/dotnet/scripts/install.ps1 -Target C:\path\to\repo` |
| `dist/angular` | Angular workspaces evidenced by `angular.json`, an exact-case `"@angular/core"` dependency-map key, or an exact-case Angular token in an Nx/project plugin, executor, generator, schematic, or target-default field | same, auto-detects `angular` | `pwsh -NoProfile -File dist/angular/scripts/install.ps1 -Target C:\path\to\repo` |
| `dist/monorepo` | Mixed repositories with both .NET and Angular evidence, or Angular plus warehouse-SQL evidence | same, auto-detects `monorepo` (union of the applicable profiles' rails) | `pwsh -NoProfile -File dist/monorepo/scripts/install.ps1 -Target C:\path\to\repo` |

Pass `-Stack dotnet|angular|monorepo` to override
auto-detection. On an existing install, the root installer defaults to whatever stack is
recorded in the target's `.claude/framework-version.json` (update mode) rather than
re-detecting. If the repository's evidenced profiles change, rerun the root installer with the
appropriate explicit `-Stack` (usually `monorepo` when profiles coexist) before
running `/rebootstrap`. Application markers are searched at the target root and two directory levels below;
warehouse evidence is classified repository-wide while generated and dependency directories are
pruned. The PowerShell dispatcher uses an embedded strict JSON reader. The root installer is a thin
dispatcher only — all real copy logic lives in the install script under the chosen dist's `scripts/`
directory.

### What the install adds, and why it is committed

Each dist's generated **`framework-ownership.json` is authoritative** for the installed path set and ownership class; review that manifest rather than relying on a hard-coded file count. The installed framework files are meant to be committed.
That is not incidental: hooks have to exist in the tree for every developer who clones, skills and
commands have to be on disk for the agent to find them, and `CLAUDE.md` plus the instructions
carrier *are* the product. Nothing here is build output.

Each dist ships **`framework-ownership.json`**, a generated manifest listing every installed path
with one of three ownership classes:

| class | what it means for you |
|---|---|
| `framework-owned/overwritten` | replaced on every update — do not edit, your changes will be lost |
| `consumer-owned/protected` | yours; created once if absent, never touched again |
| `mixed` | shared — `.claude/settings.json` carries our hook registrations alongside your settings |

Read that file rather than the diff when reviewing the first commit, and consult it before editing
anything under `.claude/` or `scripts/` if you want the edit to survive an update. It is generated
during composition and cross-checked against the installer's own preservation lists, so it cannot
quietly disagree with what the installer actually does.
## Quick start

The installers run *from a local clone of this repo* against a target repo elsewhere on disk — so
get the framework first, then point it at your codebase:

```powershell
git clone https://github.com/andreoucostas/ai-tech-lead.git
cd ai-tech-lead
pwsh -NoProfile -File install.ps1 C:\path\to\your-repo
# Windows PowerShell 5.1 fallback:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File install.ps1 C:\path\to\your-repo
```

Installing a mixed .NET + Angular repo, forcing the monorepo dist explicitly:

```powershell
pwsh -NoProfile -File install.ps1 -Stack monorepo C:\path\to\your-repo
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
| `scripts/` | PowerShell composer/gates: `build`, `validate-dist`, `context-footprint`; `fidelity-check.ps1` remains a manual historical re-audit tool. |
| `install.ps1` | Root installer — detects the target's stack (or reads `-Stack`) and delegates to the matching dist installer. |
| `meta/` | **The maintainer layer, kept out of the product's way:** `BACKLOG.md` (work list), `workspace-decisions.md` (ADR log), `LEARNINGS.md` (meta-dev log), `ci-handover.md`, `changelogs/` (frozen pre-merge history). Never ships. |
| `.github/workflows/ci.yml` | The CI gate — see below. |
| `CLAUDE.md` / `AGENTS.md` | Governance for developing *this* repo (maintainer instructions — not shipped; distinct from the `CLAUDE.md` templates inside each `dist/`). They must sit at the repo root for Claude Code to load them, so they keep an explicit "you are in the authoring repo" banner as the tie-breaker. |
| `DEVELOPING.md` | Operational runbook: the exact commands behind every gate below. |
| `.claude/` | Maintainer-only Claude Code config (hooks, release automation, plans). Never ships. |

## How it's built and validated

`scripts/build.ps1` is the composer: it reads `src/core` plus the target dist's
`src/stacks/<dist>/` overrides and writes a complete `dist/<dist>/` tree. Two gates run against
that output — `validate-dist.ps1` (marker resolution, JSON validity, PowerShell-only topology and AST parse,
each dist's own `template-checks` for `CLAUDE.md`↔`AGENTS.md` mirror parity, and `no-meta-leak`,
which fails if maintainer vocabulary reaches a shipped file) and each dist's own hook test suite
(`dist/<dist>/tests/hooks/Invoke-HookTests.ps1`, a dependency-free PowerShell harness that pipes
JSON fixtures at every hook and asserts the PowerShell semantics). CI (`.github/workflows/ci.yml`)
runs those plus a freshness check under eight Windows contexts: root and all three distributions
under PowerShell 7, then the same four under native Windows PowerShell 5.1.
`scripts/fidelity-check.ps1` (byte-compare of `dist/{dotnet,angular}` against the pre-merge
`freeze-v0.25.5` baseline) was **retired from CI at v0.26.0**, which deliberately changed shipped
content; it remains for manual re-audit. Full command recipes, including how to run any single gate
by hand, are in [`DEVELOPING.md`](./DEVELOPING.md).

## Status

Current shipped version is **v0.83.0** across all three dists
(`dist/*/.claude/framework-version.json`). The merge is complete: this repo is the single home for
framework development, and the two legacy repos (`ai-tech-lead-dotnet`, `ai-tech-lead-angular`) are
archived and read-only, frozen at v0.25.5.

## Maintainer docs

- [`CLAUDE.md`](./CLAUDE.md) — how to develop the framework itself: repo map, meta-invariants, workflows.
- [`DEVELOPING.md`](./DEVELOPING.md) — command recipes behind every gate described above.
- [`meta/BACKLOG.md`](./meta/BACKLOG.md) — the prioritized work list.
- [`meta/workspace-decisions.md`](./meta/workspace-decisions.md) — the ADR log for framework-level decisions (merge strategy, mirror strategy, hook semantics, composition rules).
- [`meta/LEARNINGS.md`](./meta/LEARNINGS.md) — the meta-dev log: what went wrong building this and what changed as a result.

## Licence

[MIT](./LICENSE) — copyright (c) 2026 Costas Andreou. Every dist also ships
`LICENSES/ai-tech-lead-MIT.txt` and `NOTICE-ai-tech-lead.md`, so the licence and notice travel with
the installed framework files.
