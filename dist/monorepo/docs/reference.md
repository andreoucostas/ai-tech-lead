# Reference

The exact list of what AI Tech Lead installs: every command, reviewer, skill, hook and script, and
who owns each file. For a walk-through, read [getting-started.md](getting-started.md); for why it
works this way, [playbook.md](playbook.md); for what each client enforces,
[enforcement-surfaces.md](enforcement-surfaces.md).

## Commands

The same names work in Claude Code (`.claude/commands/`, the canonical text) and in Copilot in VS Code
and Copilot CLI (`.agents/skills/`, thin wrappers that defer to it). You rarely need to type them: a
request in plain words is classified and follows the matching workflow.

| Command | What it does |
|---|---|
| `/bootstrap` | Once per repository: analyses the code in parallel passes, asks about what the code leaves ambiguous, then writes `AGENTS.md`, `TECH_DEBT.md` and the code-derived parts of `FRAMEWORK-CONTEXT.md`, and drafts project skills for operations your code repeats. Only a developer can start it. |
| `/adopt` | Instead of `/bootstrap` when the repository already had AI tooling: screens and merges that material, then runs `/bootstrap` for the gaps. Only a developer can start it. |
| `/rebootstrap` | A periodic, deeper re-alignment of `AGENTS.md` with the code. |
| `/feature` | Implements at the boundaries your code already uses; reads `specs/<slug>.md` first if one exists. |
| `/fix` | Cause first; a regression test that fails before the fix, where a test harness exists. |
| `/refactor` | Behaviour-preserving, in verified steps; reports the net change in lines. |
| `/design` | Design only, no code; asks first, weighs at least two approaches, writes `specs/<slug>.md`. |
| `/test` | The smallest risk-relevant tests, in your existing test patterns. |
| `/debt` | Finds tech debt that can ride along with current work, and fixes it. |
| `/review` | Runs the specialist reviewers below on your changes and gives APPROVE or REQUEST CHANGES. |
| `/security-gate` | An OWASP-style review of a change with senior judgement; findings go to `SECURITY_FINDINGS.md` with remediation deadlines. |
| `/docs-sync` | Reports drift between `AGENTS.md`, the other docs and the code, without changing them. |

In Copilot CLI, `/review` is also the CLI's own command; ask for this repository's review by name
("run the review skill from this repository on my staged changes").

## Specialist reviewers

Subagents in `.claude/agents/`, wrapped for Copilot in `.github/agents/`. Each runs in its own context
and returns a findings table.

| Reviewer | Checks | Model |
|---|---|---|
| `convention-check` | The diff against `AGENTS.md > Conventions` | Haiku in a Claude session on another model, else your session's model |
| `solid-check` | The diff against SOLID, judged against your project evidence rather than a framework-imposed shape | your session's model |
| `bloat-radar` | Needless abstraction, the counterweight to Boy Scout cleanups | Haiku in a Claude session on another model, else your session's model |
| `test-critic` | Whether each test would fail if the code under test broke | your session's model |
| `debt-radar` | Which `TECH_DEBT.md` entries the change touches | Haiku in a Claude session on another model, else your session's model |
| `security-auditor` | An OWASP-style scan; feeds `/security-gate` | your session's model |
| `bootstrap-pass` | One analysis pass during `/bootstrap` | Sonnet in a Claude session on another model, else your session's model |

To run every subagent on one model, start Claude Code with `CLAUDE_CODE_SUBAGENT_MODEL=<model>` and
`CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` (Claude Code v2.1.257 or later); that also overrides the Haiku
reviewers.

## Skills

Skills in `.claude/skills/` load only when a task needs them. This distribution ships:

- .NET: `map-warehouse` · `add-warehouse-load` · `perf`
- Both stacks: `add-tests` · `dependency-audit` · `create-adr` · `remember-for-team` · `enforce-architecture` · `enforce-standards`

`AGENTS.md > Common Tasks` describes each in one line, and a skill applies only where your
repository's evidence supports it. Project skills that `/bootstrap` drafts live in the same folder.

## Hooks

PowerShell scripts in `.claude/hooks/`, registered for Claude Code in `.claude/settings.json` and for
Copilot in `.github/hooks/hooks.json`. Registration is not proof that a client runs them: run
`scripts/framework-doctor.ps1`, and see [enforcement-surfaces.md](enforcement-surfaces.md) for what
each client does with each event.

| Hook | Event | What it does |
|---|---|---|
| `session-start.ps1` | session start | Adds the branch, recent commits, a pending `/bootstrap` or `/adopt`, tech debt in recently changed files, open security findings, the wiki index, stale hazard areas and a framework-version reminder. |
| `route-prompt.ps1` | each prompt | Classifies a plain-words request and adds the matching workflow's rules. |
| `guard.ps1` | before a file write | Blocks an editor or file-tool write that adds a warning suppression, a hardcoded secret or a test-defeat. Writes made by shell commands are not inspected. |
| `post-write.ps1` | after a file write | Per file type: a .NET write runs an incremental `dotnet build`; a `.ts` write under `src/` (or a `tsconfig*.json`) runs `tsc --noEmit`, and `ngc --noEmit` for a component template. The agent sees the errors. |
| `audit-trail.ps1` | after a file write | Appends the branch and path to `.claude/ai-audit.log`, a local, ignored file. It is telemetry, not compliance evidence. |
| `boy-scout-check.ps1` | end of turn | Lists cleanup candidates in the files changed, as advice. |

## Scripts

Run from the repository root with `pwsh -NoProfile -File scripts/<name>.ps1`, or with
`powershell.exe -NoProfile -ExecutionPolicy Bypass -File` where PowerShell 7 is missing.

| Script | Use |
|---|---|
| `framework-doctor.ps1` | Once per developer machine: which controls are live here. Exit 1: a check is `MISSING`; exit 2: none is missing but one the script itself could not examine printed `[CANT-VERIFY]`; exit 0: neither. The agent-host canaries it always lists are not counted. |
| `docs-sync-check.ps1` | The CI guard: `AGENTS.md` populated and within its size budget, `CLAUDE.md` imports it, project skills in `.claude/skills/`, the install complete. Exit 0 pass, 1 fail. See [ci-integration.md](ci-integration.md). |
| `template-checks.ps1` | Framework-state checks, including the version stamp against the `AGENTS.md` header. |
| `metrics.ps1` | A descriptive snapshot of the codebase, as JSON. Not a before-and-after measure. |
| `review-scope.ps1`, `test-weakening-scan.ps1` | Used by `/review` to fix the bytes under review and report removed assertions. |
| `bootstrap-baseline.ps1` | Used by `/bootstrap` and `/rebootstrap` to record what a later re-alignment must re-check. |
| `hazard-check.ps1`, `wiki-check.ps1`, `warehouse-map-check.ps1` | Validate `FRAMEWORK-CONTEXT.md > Known Hazard Areas`, the wiki index and `docs/warehouse-map.md`; `docs-sync-check.ps1` runs the first two. |
| `adoption-archive.ps1` | Used by `/adopt` to verify the archived pre-existing files. |
| `scripts/ci/` | Samples for your own CI. |

## Files and ownership

`framework-ownership.json` in your repository is authoritative: it gives every installed path one of
three classes.

| Class | Meaning |
|---|---|
| `framework-owned/overwritten` | Replaced on every update. Do not edit; your changes would be lost. For `.claude/.gitignore`, an update also keeps out of Git each existing file your own lines there ignored, with one line per file below the framework's; put your own rules in the root `.gitignore`. |
| `consumer-owned/protected` | Yours: created once if absent, never touched again. `CLAUDE.md`, `AGENTS.md`, `TECH_DEBT.md`, `SECURITY_FINDINGS.md`, `LEARNINGS.md`, `FRAMEWORK-CONTEXT.md`, `docs/ARCHITECTURE.md`, `docs/architecture-decisions.md` and `docs/wiki/INDEX.md`. |
| `mixed` | `.claude/settings.json`: the framework's hook registrations next to your own settings, saved to `.claude/.state/settings.json.pre-update` before each update. |

| Path | What it is |
|---|---|
| `AGENTS.md` | Your conventions, architecture and common tasks: the one file you author. Read directly by Copilot agent surfaces, GitHub code review, Codex and Cursor. |
| `CLAUDE.md` | Two import lines: `AGENTS.md` and the framework rules, for Claude Code. |
| `.github/instructions/framework-rules.instructions.md` | The framework's rules (Verification Rules, Leanness, SOLID, Agentic Workflow). Framework-owned. |
| `FRAMEWORK-CONTEXT.md` | Cross-repository context and the Known Hazard Areas. |
| `TECH_DEBT.md`, `SECURITY_FINDINGS.md`, `LEARNINGS.md` | The debt register, the security register with deadlines, the append-only lessons log. |
| `.claude/commands/`, `.agents/skills/` | Workflows, and their Copilot wrappers. |
| `.claude/agents/`, `.github/agents/` | Reviewers, and their Copilot wrappers. |
| `.claude/skills/` | Framework skills and your project skills. |
| `.claude/hooks/`, `.claude/settings*.json`, `.github/hooks/` | Hooks and their registrations (PowerShell 7, with a Windows PowerShell 5.1 fallback). |
| `.github/workflows/` | GitHub Actions; on Bitbucket, see [ci-integration.md](ci-integration.md). |
| `specs/` | Specs written by `/design`. |
| `tests/evals/` | A readable catalogue of the behaviour the framework intends. |
| `docs/` | These guides, `defaults.md` (conventions before `/bootstrap`), and your team's decisions and wiki. |

Other tools: Gemini reads `GEMINI.md` by default and Aider reads these files only when configured to.
Copilot's inline suggestions in VS Code read no instruction file.

## Version

`.claude/framework-version.json` records the installed version and is authoritative when the
`AGENTS.md` header disagrees. Updating: [upgrade-checklist.md](upgrade-checklist.md). Release notes are
in the framework checkout's `CHANGELOG.md` for your distribution.

## GitHub and Bitbucket Data Center

Everything local works the same on both. GitHub-only features do not reach Bitbucket: the Copilot
cloud coding agent, Copilot pull request review and GitHub Actions. On Bitbucket, run `/review` and
`/security-gate` before you push, wire the required build described in
[ci-integration.md](ci-integration.md), and turn on Bitbucket's secret scanning. Atlassian Rovo Dev is
cloud-only. The Copilot cloud coding agent runs no hooks on either host.
