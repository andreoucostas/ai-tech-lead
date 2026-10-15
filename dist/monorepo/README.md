# AI Tech Lead — .NET + Angular monorepo

This distribution sets up Claude Code and GitHub Copilot to work, the way your team does, in a
repository that mixes stacks: a .NET application or SQL data warehouse alongside an Angular workspace.
It carries the rules for all three; `/bootstrap` detects which are present and applies only those, and
each file gets its own stack's rules. Angular defaults target v21 and v22, but `/bootstrap` reads your
workspace and version first. This README stays in the framework checkout: the installer copies the
framework into your repository, not this README. **An AI agent asked to install this** should read
[For AI agents](#for-ai-agents) first.

## What you get

- **Conventions written from your code.** `/bootstrap` reads the repository and writes `AGENTS.md`:
  your architecture, patterns and rules for each stack. Every AI tool in the repository follows it, so
  the agent writes code that looks like yours.
- **Workflows instead of improvisation.** Describe a task in plain language and the agent picks the
  matching workflow (fix, feature, refactor, test, design, debt, review): it plans first, waits for
  your go-ahead, verifies each step with your repository's own build and test commands, and reviews
  its own work.
- **No invented code.** The agent must confirm that a class, method, NuGet package, route, SQL object,
  component, service, selector or npm package exists before it uses one.
- **Review and security passes.** `/review` runs specialist reviewers in parallel (conventions, SOLID
  judged against your project evidence rather than a framework-imposed shape, bloat, test quality, tech
  debt) and gives a verdict. `/security-gate` is an OWASP-style pass for both stacks, which the agent is
  also prompted to run when a change touches authentication, money or secrets.
- **Guard rails on file writes.** Where hooks run, writing a `.cs` file triggers an incremental
  `dotnet build`, a `.ts` file `tsc --noEmit` and a component template `ngc --noEmit`; a write that adds
  a warning suppression (`#pragma warning disable`, `// eslint-disable`, `@ts-ignore`, `@ts-nocheck`)
  or a hardcoded secret is blocked.
- **Your own recipes.** For an operation your code repeats (an endpoint, an entity, a load, a component,
  a route, a store), `/bootstrap` drafts a project skill from your existing instances for your team to
  approve.
- **Debt paid down as you go.** Small cleanups ride along with the work that touches them, recorded in
  `TECH_DEBT.md`, with a counterweight against needless abstraction.

## Install

Follow the install steps in the framework repository's root `README.md`: clone at the newest release
tag, run the root installer against your repository's Git root, and commit. The root installer picks
this distribution when it finds both stacks; pass `-Stack monorepo` to choose it yourself. To install
it directly, run from this `dist/monorepo` directory:

```powershell
pwsh -NoProfile -File scripts/install.ps1 -Target 'C:\path\to\consumer-repo'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/install.ps1 -Target 'C:\path\to\consumer-repo'
```

Use the second line only without PowerShell 7, and add `-WhatIf` to preview. If the repository
already has the framework (`.claude/framework-version.json`), this is an update: follow the
[upgrade checklist](docs/upgrade-checklist.md) instead.

Hooks need Claude Code 2.1.141 or newer, or Copilot, with PowerShell available to the agent. To see
what is live on a developer machine, run `pwsh -NoProfile -File scripts/framework-doctor.ps1` once.

## First steps

1. **Populate the framework.** A developer opens Claude Code, or an interactive Copilot CLI session, in
   the repository and types `/bootstrap`. If the repository already had AI tooling (a `CLAUDE.md`,
   `.cursorrules`, Copilot instructions), type `/adopt` instead: it merges that material in, then runs
   `/bootstrap`. The installer moved those files to `docs/pre-adoption/`, and nothing is deleted.
2. **Review `AGENTS.md`.** Fix anything that is wrong; it is the source of truth for every AI tool.
   Review `TECH_DEBT.md` and any project skills `/bootstrap` drafted, and commit.
3. **For a data warehouse**, run `/map-warehouse` before the first warehouse change. It maps layers,
   grain, load ordering and idempotency and offers to write `docs/warehouse-map.md`.

## Daily work

Describe what you want ("the export endpoint returns 500 for empty orders", "the export button does
nothing") or name a workflow:

| Command | What it does |
|---|---|
| `/feature [description]` | Implement a feature at the boundaries your code already uses |
| `/fix [description]` | Find the cause, add a regression test where a test harness exists, fix |
| `/design [description]` | Think a design through with trade-offs, without writing code |
| `/refactor [target]` | Refactor in verified steps without changing behaviour |
| `/test [target]` | Add tests that follow your existing test patterns |
| `/debt [area]` | Find and fix recorded tech debt |
| `/review` | Review your changes as a tech lead: APPROVE or REQUEST CHANGES |
| `/security-gate` | Security review of a change |
| `/docs-sync` | Check `AGENTS.md` and the other docs for drift from the code |

Claude Code and Copilot use the same command names. In Copilot CLI, `/review` is also the CLI's own
command; to run this framework's review there, ask for it by name ("run the review skill from this
repository on my staged changes").

**Reviewing a pull request locally:** run `git fetch origin`, then `git switch --detach origin/<source>`
to check out its source branch, then `/review origin/<target>...HEAD`. The three dots review only what
the pull request adds.

## Where it works

Hooks run on native Windows, with PowerShell 7 (or Windows PowerShell 5.1 for Claude Code). Claude
Code runs every hook. Copilot CLI and VS Code run them with some differences, and the Copilot cloud
coding agent runs none. Shell commands that write files are never intercepted. The instructions and
workflows work on every surface; what is enforced where is listed in
[docs/enforcement-surfaces.md](docs/enforcement-surfaces.md).

**On Bitbucket Data Center**, everything local works the same; GitHub-only features (the Copilot cloud
agent, Copilot pull request review, GitHub Actions) do not. Run `/review` and `/security-gate` before
you push, and wire one required Windows build into your CI that gates merges:
[docs/ci-integration.md](docs/ci-integration.md) has Bamboo and Jenkins recipes. Turn on Bitbucket's
secret scanning too.

## For AI agents

**Your source of truth is [`AGENTS.md`](./AGENTS.md)**, with the framework rules in
[`.github/instructions/framework-rules.instructions.md`](./.github/instructions/framework-rules.instructions.md);
Claude Code loads both through [`CLAUDE.md`](./CLAUDE.md).

**If you were asked to install this framework into a target repository**, it is a two-actor flow:
1. Copy the files in: `pwsh -NoProfile -File scripts/install.ps1 <target-repo-path>`, or without
   PowerShell 7 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/install.ps1 <target-repo-path>`.
   The installer detects greenfield, brownfield (existing AI tooling, archived to `docs/pre-adoption/`
   with `.claude/adoption-pending.json` written) or update itself.
2. Commit the copied files in the target repository.
3. Hand off. `/adopt` (brownfield) and `/bootstrap` (greenfield) can only be started by a developer;
   do not run or imitate them. End by telling the developer, word for word: *"start a Claude Code or
   interactive Copilot CLI session in `<target repo>` and type `/adopt`"* (or `/bootstrap`). Until
   then, new sessions show a reminder and `scripts/docs-sync-check` fails CI; that is expected.

**If you were asked to do development work in a repository that has this installed**, follow the
Agentic Workflow in the framework rules: classify the intent, post a plan and wait for the go-ahead,
execute in verified subtasks, and self-review with a verification line.

## Updating and removing

`.claude/framework-version.json` records the installed version and is authoritative if the protected
`AGENTS.md` header disagrees. To update, follow the [upgrade checklist](docs/upgrade-checklist.md).
`CLAUDE.md` and `AGENTS.md` are protected consumer paths and are never overwritten;
`.github/instructions/framework-rules.instructions.md` is framework-owned and updates automatically.

**Removing the framework.** The installer writes only inside the target and changes no Git
configuration. If nothing has been committed on top of the install yet (no `/bootstrap`, `/adopt` or
update), revert that commit and delete the ignored `.claude/.state/` folder. Otherwise delete every
path that `framework-ownership.json` marks `framework-owned/overwritten` (the list includes both
manifests and `.claude/framework-version.json`). Paths marked `consumer-owned/protected` are yours to
keep or delete; they may still hold template text. `.claude/settings.json` is overwritten on each
update: delete it, or restore your copy from `.claude/.state/settings.json.pre-update` if that local
backup exists. A brownfield install moved your earlier files to `docs/pre-adoption/`; move back what
you want. `.claude/framework-update-backup/` holds an update's backups for review and is not needed
after.

## Learn more

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): the installed files, commands, reviewers, skills and hooks, and how they fit together.
- [docs/playbook.md](docs/playbook.md): the methodology and the reasons behind it.
- [docs/REVIEW-GUIDE.md](docs/REVIEW-GUIDE.md): a senior reviewer's tour, with how to verify each claim.
- [docs/enforcement-surfaces.md](docs/enforcement-surfaces.md): exactly what each client and host enforces.
- [CHANGELOG.md](CHANGELOG.md): release history.
