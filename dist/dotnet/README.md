# AI Tech Lead — .NET

This distribution sets up Claude Code and GitHub Copilot to work in a .NET application, a SQL data warehouse, or both, the way your team does. This page describes the distribution; it stays in the framework checkout, and the installer
copies the framework into your repository, not this README.

**Installing it?** Follow the install steps in the framework repository's root `README.md`: clone at
the newest release tag, run the root installer against your repository's Git root, commit, and hand
`/bootstrap` (or `/adopt`) to a developer. [For AI agents](#for-ai-agents) below says the same in
agent terms.

## What it adds to your repository

- **Conventions written from your code.** `/bootstrap` reads the repository and writes `AGENTS.md`:
  your architecture, patterns and rules. Every AI tool in the repository follows it, so the agent
  writes code that looks like yours.
- **Workflows instead of improvisation.** A request in plain words follows the matching workflow
  (fix, feature, refactor, test, design, debt, review): the agent asks what is unclear, plans, waits
  for your go-ahead, verifies each step with your repository's own build and test commands, and
  reviews its own work.
- **No invented code.** The agent must confirm that a class, method, package, route or SQL object
  exists before it uses one.
- **Guard rails on file writes.** Where hooks run, writing a `.cs` file triggers an incremental
  `dotnet build`, and a write that adds `#pragma warning disable` or a hardcoded secret is blocked.
- **Your own recipes.** For an operation your code repeats (adding an endpoint, a load, an entity),
  `/bootstrap` drafts a project skill from your existing instances for your team to approve.
- **Data warehouses.** `/map-warehouse` maps layers, grain, load ordering and idempotency before the
  first warehouse change, and `add-warehouse-load` follows your existing load patterns.
- **Review and security passes.** `/review` runs specialist reviewers in parallel (conventions, SOLID
  judged against your project evidence rather than a framework-imposed shape, bloat, test quality,
  tech debt) and gives a verdict; `/security-gate` is an OWASP-style pass, which the agent is also prompted to run when a change touches authentication, money or secrets.
- **Debt paid down as you go**, recorded in `TECH_DEBT.md`, with a counterweight against needless
  abstraction.

Hooks need native Windows with PowerShell, and Claude Code 2.1.141 or newer or GitHub Copilot. What
each client enforces is listed in [docs/enforcement-surfaces.md](docs/enforcement-surfaces.md); the
Copilot cloud coding agent runs none of the hooks. A colocated Angular frontend? Install the monorepo distribution instead; it carries both stacks' rules.

## Its documentation

These are installed into your repository under `docs/`:

| Document | For | What it is |
|---|---|---|
| [getting-started.md](docs/getting-started.md) | developers | From the install to a first reviewed fix |
| [REVIEW-GUIDE.md](docs/REVIEW-GUIDE.md) | developers, reviewers | Reviewing a change or a pull request |
| [upgrade-checklist.md](docs/upgrade-checklist.md) | whoever maintains it | Updating to a newer release, and removing the framework |
| [ci-integration.md](docs/ci-integration.md) | tech lead, build owner | The required build on Bitbucket Data Center (Bamboo, Jenkins) |
| [reference.md](docs/reference.md) | everyone | Every command, reviewer, skill, hook, script and file, and who owns it |
| [enforcement-surfaces.md](docs/enforcement-surfaces.md) | tech lead | What each client and host enforces, with dated evidence |
| [playbook.md](docs/playbook.md) | tech lead | Why it works this way, what is guaranteed, what it costs, its limits |

Release notes: [CHANGELOG.md](CHANGELOG.md).

## Installing this distribution directly

The root installer chooses the distribution for you. To install this one directly, run from this
`dist/dotnet` directory:

```powershell
pwsh -NoProfile -File scripts/install.ps1 -Target 'C:\path\to\consumer-repo'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/install.ps1 -Target 'C:\path\to\consumer-repo'
```

Use the second line only without PowerShell 7, and add `-WhatIf` to preview. If the repository
already has the framework (`.claude/framework-version.json`), this is an update: follow
[docs/upgrade-checklist.md](docs/upgrade-checklist.md). `CLAUDE.md` and `AGENTS.md` are
protected consumer paths and are never overwritten; `.github/instructions/framework-rules.instructions.md` is
framework-owned and is replaced on each update.

## For AI agents

**Asked to install this into a repository:** clone the framework at its newest release tag outside
that repository, run the root `install.ps1` against the repository's Git root, and commit the
installed files there; a request to install is a request to commit, so do not stop to ask. Then
stop: `/bootstrap` (new to AI tooling) or `/adopt` (the installer found existing AI tooling) can only
be started by a developer, and must not be run or imitated. Tell the developer to start a Claude Code
or interactive Copilot CLI session in their repository and type `/bootstrap` (or `/adopt`, whichever
the installer named). Until they do, new sessions
show a reminder and `scripts/docs-sync-check.ps1` fails CI; that is expected.

**Working in a repository that has this installed:** your source of truth is `AGENTS.md`, with the
framework rules in `.github/instructions/framework-rules.instructions.md`; Claude Code loads both
through `CLAUDE.md`. Follow the Agentic Workflow there: classify the intent, post a plan and wait for
the go-ahead, execute in verified subtasks, and self-review with a verification line.
