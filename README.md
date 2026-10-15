# AI Tech Lead

AI Tech Lead makes AI coding agents (Claude Code and GitHub Copilot) work in your repository the way
your team does. It installs instruction files, workflow commands, specialist review agents and guard
hooks; then one command reads your codebase and writes down its conventions, so the agent follows your
patterns instead of inventing its own. It is built for .NET and Angular teams on Windows, including
teams hosting on Bitbucket Data Center.

## Install it into your repository

These steps are written so that you, or an AI agent you hand this page to, can follow them exactly.

**You need:** Windows; Git; PowerShell 7 (`pwsh`), or Windows PowerShell 5.1 as a fallback; and
Claude Code 2.1.141 or newer, or GitHub Copilot (VS Code or Copilot CLI). Your repository's working
tree must be clean: commit or stash first, or the installer stops.

1. **Get the framework at its newest release**, outside your repository and at a short path:

   ```powershell
   git clone https://github.com/andreoucostas/ai-tech-lead.git C:\src\ai-tech-lead
   cd C:\src\ai-tech-lead
   git checkout "$(git describe --tags --abbrev=0)"
   ```

   A deep folder (an agent's scratch or temp directory, say) can push the clone's paths past Windows'
   260-character limit, and `git clone` then fails with "Filename too long". Install from a release
   tag, not from `master`: `master` carries unreleased work stamped with the previous version, which
   confuses later updates. The installer checks the clone against its remote and stops if a newer
   release exists.

2. **Run the installer against your repository's Git root:**

   ```powershell
   pwsh -NoProfile -File install.ps1 C:\path\to\your-repo
   ```

   Without PowerShell 7: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File install.ps1 C:\path\to\your-repo`.
   Add `-WhatIf` first to preview without changing anything.

   The installer picks the distribution from what it finds in your repository:

   | Your repository | Distribution |
   |---|---|
   | A .NET application, or a SQL data warehouse | `dotnet` |
   | An Angular workspace | `angular` |
   | Both .NET (or a warehouse) and Angular | `monorepo` |

   Pass `-Stack dotnet`, `-Stack angular` or `-Stack monorepo` to choose it yourself.

3. **Review and commit the installed files** in your repository. They are shared team configuration,
   not build output: every developer who clones needs them.

4. **Populate it from your codebase.** A developer starts a Claude Code session, or an interactive
   Copilot CLI session, in the repository and types one command:
   - `/bootstrap` if the repository had no AI tooling before;
   - `/adopt` if it already had some (a `CLAUDE.md`, `.cursorrules`, Copilot instructions and so on).
     The installer says which: it moves any file it would have overwritten to `docs/pre-adoption/`
     and writes `.claude/adoption-pending.json`. `/adopt` merges that earlier material in; nothing is
     deleted.

   The command analyses the code and writes `AGENTS.md` (your conventions and architecture) and
   `TECH_DEBT.md`.

5. **Review `AGENTS.md`** and correct anything that is wrong. Every AI tool in the repository follows it.

> **If you are an AI agent installing this:** do steps 1 to 3, then stop. `/bootstrap` and `/adopt`
> can only be started by a developer, and must not be imitated by hand. End by telling the developer,
> word for word: *"Start a Claude Code or interactive Copilot CLI session in `<your repo>` and type
> `/adopt`"* (or `/bootstrap`, whichever the installer reported). Until they do, new sessions in the
> repository show a reminder.

## After that

Describe tasks in plain language ("the export endpoint returns 500 for empty orders", "add paging to
the customer list") and the agent follows the matching workflow: it asks what is unclear, plans,
waits for your go-ahead, makes verified changes and reviews its own work. You can also name a
workflow directly: `/feature`, `/fix`, `/design`, `/refactor`, `/test`, `/debt`, `/review`,
`/security-gate`.

Developers start with `docs/getting-started.md` in their repository, which walks from the install to
a first reviewed fix; every installed guide is listed in your distribution's README:
[.NET](./dist/dotnet/README.md) · [Angular](./dist/angular/README.md) · [Monorepo](./dist/monorepo/README.md).

## What is guaranteed, and what it costs

- **Guaranteed only where hooks run:** on native Windows, in a client that fires the event, a file
  write that adds a warning suppression or a hardcoded secret is blocked and a compile error is shown
  to the agent. Writes made by shell commands are not inspected, and the Copilot cloud coding agent
  runs no hooks.
- **Instructed everywhere else:** planning first, verifying before referencing, a failing test
  before a fix, reviewing its own work. The agent is told to; it can still skip an instruction.
- **The one gate for every person and tool** is a required build in your CI; each distribution's
  `docs/ci-integration.md` has the recipe for Bitbucket Data Center.
- **Costs:** one `/bootstrap` session per repository and the time to review what it writes; an
  `AGENTS.md` of up to 16 KB loaded on every turn; the wait for the plan gate and for `/review`'s
  reviewers on each change; someone who applies updates.

Why it works this way, and its limits: `docs/playbook.md` in each distribution
([.NET](./dist/dotnet/docs/playbook.md)).

## What the install changes

The installer writes only inside your repository and changes no Git configuration. Each
distribution's `framework-ownership.json` is authoritative for what it installs, giving every path one
of three ownership classes:

| Class | What it means for you |
|---|---|
| `framework-owned/overwritten` | Replaced on every update. Do not edit; your changes would be lost. |
| `consumer-owned/protected` | Yours. Created once if absent, never touched again. |
| `mixed` | Shared: `.claude/settings.json` holds the framework's hook registrations next to your own settings, and is backed up before each update. |

**Updating:** follow `docs/upgrade-checklist.md` in your repository; it starts from a fresh clone at
the newest release tag. **Removing:** the same checklist ends with "Remove the framework".

## Where it runs

Native Windows is the supported and release-tested platform. Linux, WSL and macOS are not supported,
and Copilot's cloud coding agent does not run the hooks. What each client enforces differs; each
distribution's `docs/enforcement-surfaces.md` lists it surface by surface.

## Status

Current shipped version is **v0.96.1** across all three distributions. Release history:
[CHANGELOG.md](./CHANGELOG.md).

## For maintainers

This repository is also where the framework is built. Shared content is authored once under
`src/core/`, with per-stack differences in `src/stacks/`. `scripts/build.ps1` composes the three
installable distributions under `dist/`, which are generated, committed and never edited by hand; CI
rebuilds them on every push and fails if they differ. Only `dist/` ships. The maintainer rules are in
[`AGENTS.md`](./AGENTS.md), the command recipes in [`DEVELOPING.md`](./DEVELOPING.md), and the work
list in [`meta/BACKLOG.md`](./meta/BACKLOG.md).

## Licence

[MIT](./LICENSE). This covers this repository; from 0.96.0 the distributions install no licence or
notice file into your repository.
