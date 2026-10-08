# AI Tech Lead (.NET + Angular monorepo) — Changelog

> Release notes for the mixed .NET + Angular distribution, written for the teams who install it:
> what changed in **your** repo, and what (if anything) you need to do. This distribution carries
> the rails of both stacks, so entries may apply to one side or both.
> Architecture decisions you record live in `docs/architecture-decisions.md`.

## 0.94.0 — Unreleased

- **The write guard no longer refuses ordinary kebab-case names as secret keys.** Its `sk-` key rule matched inside
  names such as `task-list-item-renderer-component` or a route path such as `risk-assessment-history-details`, refused
  the write as "an API secret key", and stopped the agent on correct code. It now looks for `sk-` only where a key
  starts (after a space, quote, `=`, `:` or other punctuation, at the start of a line, or after an escape such as
  `\n`, a JSON-escaped quote or a URL-encoded character), so OpenAI (`sk-proj-…`) and Anthropic (`sk-ant-…`) keys are
  still refused. A key written directly after any other letter or digit, for example after a twice URL-encoded
  character or a terminal colour code, is no longer refused. A name that itself starts with `sk-` and runs to 20 or
  more characters, such as an `sk-`-prefixed component selector, is still refused: write that line yourself. An update
  refreshes the guard; you do not need to do anything.

- **Copilot needs PowerShell 7 on every machine that runs it, and `framework-doctor` now says so.**
  `.github/hooks/hooks.json` runs every hook with `pwsh`. In our test on Copilot CLI 1.0.89, a machine without
  PowerShell 7 had every tool call refused ("Denied by preToolUse hook … (hook errored)"), so the agent could not
  change anything. On such a machine, run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File
  scripts/framework-doctor.ps1`: its `Copilot surface` row now reports the gap. `docs/enforcement-surfaces.md` also
  spells out the write-guard check the doctor prints. An update refreshes both; install PowerShell 7 wherever Copilot
  runs.

- **The write guard now refuses a password in `appsettings.json`'s `ConnectionStrings` section.** Until now it caught
  a connection-string password only under a `connectionString` key, so the standard .NET layout `"ConnectionStrings":
  { "Main": "Server=…;Password=…" }` was written without a word. Any entry with `Password=`, `Pwd=` or a
  `user:password@` address is now refused, except in test, sample and `Development` files such as
  `appsettings.Development.json`, and a placeholder such as `<from-vault>` or `${DB_PASSWORD}`, or a release-pipeline
  token such as `#{DbPassword}#`, `__DbPassword__` or `$(DbPassword)` used as the password itself, still passes; a
  token elsewhere in the string does not excuse a real password beside it. A local-only password in a non-Development
  settings file is refused too: keep it in user secrets or `appsettings.Development.json`.
  `docs/enforcement-surfaces.md` now lists exactly what the guard matches and what it does not. An update refreshes
  both.

- **Copilot in VS Code keeps the slash commands: they now ship as skills in `.agents/skills/`.** VS Code 1.140
  (2026-09-30) began making its Copilot harness the default, and that harness does not load prompt files, so `/feature`,
  `/fix`, `/review` and the other commands left Copilot chat with a prompt to convert them to skills. Each
  `.github/prompts/<name>.prompt.md` is now `.agents/skills/<name>/SKILL.md`, a wrapper that runs the same
  `.claude/commands/<name>.md` workflow with that command's description and argument hint. VS Code and Copilot CLI read
  this folder (Copilot CLI 1.0.92 lists the wrappers in place of the `.claude/commands/` files); Claude Code does not,
  and keeps running `.claude/commands/` directly. An update removes the prompt files you have not changed (an install
  too old to have a `framework-ownership.json` keeps them all and lists each); one you edited is kept and reported, and
  you can delete it after moving what you need into `AGENTS.md` or a project skill. If `.agents/skills/` already holds a
  skill of your own at one of these names, or a file or link where one of these folders goes (a linked `.agents/skills`
  that shares skills with other agents, say), the install or update keeps it, writes nothing through the link, and says
  so instead of installing that wrapper; a copy of the framework's own prompt there, edited or not, is saved under
  `.claude/framework-update-backup/agents-skills/` before the wrapper replaces it, beside any earlier save there rather
  than over it, and kept out of Git if you had gitignored the original. If you already used VS Code's **Convert to
  Skills** on these prompts, delete the skills it made from them: this release ships its own, and `docs-sync-check`
  fails while a `.github/skills/` folder exists. On github.com, Copilot code review can also pick up repository skills,
  including the `/review` wrapper; we have not tested what it does with one.

- **`/bootstrap` and `/rebootstrap` ask about each hazard in its own question again.** Copilot's `ask_user` question
  tool takes one question per call in its default form, and the instruction to ask everything "in a single message" led
  the agent to fold every hazard into one long question. The clarifying questions, the hazard confirmation and
  `/rebootstrap`'s hazard re-confirmation now ask one question per item at the same pause: as many per call as your
  host's question tool takes, then the next call straight away. The hazard questions also offer "skip the rest", so the
  answers you already gave stand; the clarifying questions keep their "skip" or "proceed" answer. Without a question
  tool they stay numbered questions in one message. An update refreshes both commands.

- **The security pass now names this framework's `security-review` skill, not a bare `/security-review`.** On
  Copilot CLI, `security-review` is also the name of the CLI's built-in Security Review Agent, and Copilot CLI's own
  instructions send `/security-review` to it. The always-loaded rules and the per-prompt security reminder said "run
  `/security-review`", so the pass the agent runs by itself could reach the CLI's agent instead of this framework's
  review, which records critical and high findings in `SECURITY_FINDINGS.md`. Both now name this repository's
  `security-review` skill (`.claude/commands/security-review.md`), say that on Copilot CLI it is not the CLI's built-in
  security agent, and keep the `security-auditor` agent as the alternative. This is not measured on either host, and
  Claude Code reads the same new wording. Typing `/security-review` yourself behaves as before. An update refreshes the
  rules and the hook; you do not need to do anything.

- **Plans now name how the next instance keeps an easy-to-miss step.** When a change adds an extension point, or
  the third instance of something your repository does repeatedly, and adding the next one has a step that is easy to
  miss (a flag, a grant, a registration), the plan names one record it will add for that step: a test that fails when an
  instance skips it, otherwise one `AGENTS.md > Conventions` line, otherwise, once three or more instances exist, a
  project skill draft marked `DRAFT, pending PR review:`. You approve it with the plan, and a skill draft still needs
  your PR review. For other changes the rule asks for no record. This is not measured on either host. An update
  refreshes the rules file; you do not need to do anything.

## 0.93.0 — 2026-10-04

- **In Copilot CLI, `/review` and `/security-review` may run the CLI's own review instead of this framework's.** Copilot CLI has
  built-in commands with those names. In our test on Copilot CLI 1.0.89, run with the .NET distribution's copies of these files, the CLI turned either command into an instruction to use
  its built-in review agent; with this framework's `.claude/commands/review.md` and `security-review.md` present, the model ran this
  framework's file in 4 of 5 runs and the CLI's agent in 1, so a review started that way in Copilot CLI may not have been this
  framework's gate. To run this framework's version there, ask for it by name, for example *"Run the security-review skill from
  this repository on my staged changes."*, which reached this framework's file in 3 of 3 runs for each command. In Claude Code,
  the project's commands replaced its built-ins when we tested (Claude Code 2.1.281, non-interactive).

- **`/bootstrap` now looks for minimal APIs, Hangfire or Quartz.NET jobs and OpenTelemetry on the
  .NET side, and zoneless change detection and `@defer` blocks on the Angular side.** The .NET
  passes ask whether your endpoints are controllers or minimal APIs, whether background work runs in
  hosted services or as Hangfire or Quartz.NET jobs, and whether OpenTelemetry sits beside your
  logging; the Angular component-design pass checks whether your app is zoneless
  (`provideZonelessChangeDetection`, or Angular 21 or later without `provideZoneChangeDetection`),
  whether `angular.json` still lists `zone.js` in `polyfills`, and where your templates use `@defer`.
  Like every pass, these are told to record only what your code shows. An update does not rewrite
  your `AGENTS.md`: run `/rebootstrap full` to re-analyse with these checks. We have not yet watched
  a `/bootstrap` run on a repository that uses them, so check what it writes about them.

- `docs/ci-integration.md` now shows how to review a pull request locally. Its "What CI still cannot
  gate" section ends with `git fetch origin`, `git switch --detach origin/<source>`, then
  `/review origin/<target>...HEAD` in Claude Code, which reviews only what the pull request adds since
  it left its target branch and lets `/review`'s verification run on that code. For a pull request
  from a fork, it adds the fork as a remote and fetches it first. An update refreshes the page.

- **On the Angular side, saving a component template now gets build feedback.** When the post-write hook is live, writing an `.html` file under `src/`
  (other than `index.html`) runs the Angular compiler's template type-check (`ngc --noEmit`, from your installed
  `@angular/compiler-cli`, with your app's tsconfig). It reports a broken binding to the agent the way a `.ts` type error is
  reported today. Before, template writes were not checked, because `tsc` does not read templates. The check writes no files, is
  skipped when the nearest `node_modules` at or above your app's tsconfig holds no `@angular/compiler-cli`, and shares the 45-second budget (`ATL_POSTWRITE_BUDGET_SEC`). On our
  500-component sample project it took about 7 seconds a write on a mid-range laptop. A check that runs past the budget is
  stopped, reports nothing and waits five minutes, without pausing the `.ts` check. A `.ts` edit that breaks a template, or an
  inline template, is still checked by `tsc` only. The framework doctor's build-feedback canary also passes on
  `## ngc --noEmit failed` if you plant the error in a template. Nothing to do.

- **`/bootstrap` and `/adopt` also run in GitHub Copilot CLI.** The installer's next steps and the README said they need a Claude
  Code session. In Copilot CLI, start an interactive session in your repository (`copilot`) and type the command; in our test,
  `copilot -p` did not run slash commands. We tested this with the .NET distribution on Copilot CLI 1.0.89: `/bootstrap` ran to the end and `/adopt` started the same way. This distribution's `/bootstrap` is the same kind of command file but was not run there.

## 0.92.0 — 2026-10-02

- **The framework no longer ships `add-endpoint`, `add-entity`, `register-service`, `add-component`,
  `add-service`, `add-lazy-route`, or `add-signal-store`.** These were generic "add an endpoint,
  entity, service, component, route or store" recipes the framework gave every .NET and Angular
  install, whether or not your code has that shape; their steps mostly said "follow what the
  repository already does", and we never measured them helping. Instead, `/bootstrap` and
  `/rebootstrap` draft a project skill for an operation your own code repeats at least three times
  and that has at least one step specific to your repository: at most three drafts per run, each
  built from your instances, its description starting `DRAFT, pending PR review:`, and each ending
  with the Common Tasks line to add once your team approves it. Each draft's description is quoted
  or folded and at most 1,024 characters, the form GitHub Copilot CLI can load. A repository with
  nothing repeated that often gets no draft, which is expected. In three of our test runs on Claude
  Code, on a sample repository with two such operations and four look-alike patterns, `/bootstrap`
  drafted both each time and nothing for the look-alikes. The drafts varied in completeness, and one
  left out a registration step every instance has, so check each draft against the instances it
  lists before you approve it. On update, the installer removes each of these `SKILL.md` files only
  when it is exactly a version we shipped, and prints a `NOTICE`. A copy that you or a `/bootstrap`
  older than 0.77.0 edited is kept, still loads as a skill, and is reported: delete it after review
  unless it is your own. Any other file in that skill's folder, such as a
  `references/project-pattern.md` that `/bootstrap` wrote, is yours and stays (in
  `.claude/disabled-skills/` if your `LEARNINGS.md` disables that skill); `/rebootstrap full` reads
  it as a lead. An update never rewrites your `AGENTS.md`: delete the `add-endpoint`, `add-entity`,
  `register-service`, `add-component`, `add-service`, `add-lazy-route` and `add-signal-store` lines
  from your Common Tasks list, or run `/rebootstrap full`, which drops lines for skills that are no
  longer installed (a plain `/rebootstrap` stops when only framework files changed).
- **`AGENTS.md > Common Tasks` no longer assumes a test setup.** A new install lists `add-tests` as
  working in the project's evidenced shape, instead of promising TestBed with
  `HttpTestingController`; the skill already worked from your repository's evidence. An update never
  rewrites your `AGENTS.md`. If your `add-tests` line still carries the old wording, change only the
  text after the dash to match `dist/monorepo/AGENTS.md` in your framework clone.
- **`/bootstrap` is now told not to say in `AGENTS.md` whether the warehouse map exists.** In one of
  our runs `AGENTS.md` still said no map existed after `/map-warehouse` had written
  `docs/warehouse-map.md`, because `/map-warehouse` does not edit `AGENTS.md`. If your `AGENTS.md`
  says no warehouse map exists and `docs/warehouse-map.md` is there, delete that remark.
- **GitHub Copilot CLI could not load the `add-tests` skill.** Its description was 1,078 characters,
  over the 1,024 the Agent Skills specification (agentskills.io) allows, and Copilot CLI refuses such
  a skill: `copilot skill list` (1.0.89) reports "Skill description must be at most 1024
  characters". So on Copilot, `add-tests` was missing from 0.77.0 to 0.91.0. Its description is now
  within the limit, so this update restores it; what the skill does is unchanged. Claude Code cuts
  listing text only above 1,536 characters, so it loaded there.
- The `perf` skill no longer points at a `/benchmark` command; there is none.
- `docs/enforcement-surfaces.md` now records the Claude Code write guard blocking a key-shaped file
  write end-to-end on Claude Code 2.1.281 (2026-09-30), while the same task without the framework
  left the key on disk; that covers the `Write` tool, not shell writes or split edits. An update
  refreshes the page.
- **Your agent is now told to use a matching skill even when your `AGENTS.md` does not say so.**
  Version 0.89.1 added a sentence telling your agent to invoke a matching skill before planning or
  editing, and its notes said there was nothing for you to do. That was true only for a new
  install: an update never rewrites your `AGENTS.md` (before 0.90.0, your `CLAUDE.md`), so a
  repository installed before 0.89.1 never received the sentence. It now also ships in
  `.github/instructions/framework-rules.instructions.md`, which every update replaces, so this
  update delivers it through that file. Claude Code reads the file through the import line in
  `CLAUDE.md`. GitHub Copilot reads it through its `applyTo: "**"` header, although VS Code is not
  documented to attach it on a turn that edits no file. Agents that read only `AGENTS.md`, such as
  Codex, reach it through the **Framework rules** line at the top of `AGENTS.md`. A new install's
  `AGENTS.md` keeps the sentence at the top of `## Common Tasks`, the only place our test runs
  measured it; whether the copy in the rules file moves your agent to a skill as reliably has not
  been measured. To match a new install, add "When a task matches a skill below, invoke that skill
  with your skill tool before planning or editing." as the first line under your `## Common Tasks`.
- A new install's `AGENTS.md` no longer says that a `.github/skills/` folder must move to
  `.claude/skills/`. `docs-sync-check` and `template-checks` still fail while one exists and say so.
- **Some framework wording in your instruction files is out of date and contradicts the
  framework's own files.** An update keeps your `AGENTS.md`, `FRAMEWORK-CONTEXT.md` and
  `docs/architecture-decisions.md` exactly as they are, apart from the one-time move described
  under 0.90.0, so wording the template changed after you installed is still there. The framework's
  own files already carry the current rule for each line below. Search for these lines and replace
  them, unless your team keeps one on purpose:
  - Boy Scout item 17 ending "Service interfaces/abstractions are required by SOLID/DIP even with
    one implementation; never inline those." (changed in 0.84.0). The framework no longer requires
    an interface or abstraction for every service. The item now reads: "17. Inline single-consumer
    interfaces or abstract bases that are not a project-evidenced DI service seam — per Leanness.
    Preserve an existing project boundary when its evidence or correctness need requires it."
  - The Boy Scout opening "When touching any file, leave it cleaner than you found it.", the
    heading ending "do these on every touched file", items 1 and 2 ("Missing `CancellationToken`
    propagation (.NET)", "Replace string-interpolated log messages with structured logging (.NET)")
    and the "**When to skip**" paragraph that asks for a `// TODO: Boy Scout skipped` comment
    (changed in 0.86.0). A bug fix now makes only the edits the requested behaviour, compatibility
    or verification needs, and adds no such TODO. `docs/upgrade-checklist.md` step 7 gives the
    replacement opening and heading; items 1 and 2 now read "`CancellationToken` (.NET) only when
    outcome/compatibility requires it" and "Structured logging (.NET) only when
    outcome/verification requires it".
  - Under `## Common Tasks`, "Skills are mirrored to `.github/skills/` by `/generate-copilot` (and
    `scripts/sync-agent-files`) so Copilot CLI/agent see them too." (changed in 0.82.0). Neither
    exists any more and your skills live only in `.claude/skills/`; delete the sentence.
  - In `FRAMEWORK-CONTEXT.md > Precedence`, "`CLAUDE.md` (this repo's authoritative source) wins",
    and at the top of `docs/architecture-decisions.md`, "The one-line index lives in
    `CLAUDE.md > Architecture Decisions`" (changed in 0.90.0). Both name `CLAUDE.md`, which is now
    only the import stub; replace `CLAUDE.md` with `AGENTS.md` in those two lines.
  - In the comment at the top of `AGENTS.md`, "When you sync template updates, bump these fields
    and update .claude/framework-version.json." (changed in 0.90.0). The installer writes
    `.claude/framework-version.json` on every install and update; you copy `version` and `applied`
    from it into that comment, not the other way round. The line now reads "After a framework
    update, copy these fields from .claude/framework-version.json."
- **If you merged `CLAUDE.md` into `AGENTS.md` by hand, check the top of `AGENTS.md`.** When 0.90.0
  moved your instructions into `AGENTS.md` itself, it also added a line that points agents reading
  only `AGENTS.md` at the framework rules. A merge you made yourself may not have it. If your
  opening note has no **Framework rules** line, add the one `docs/upgrade-checklist.md` step 8
  quotes as its second line:
  `> **Framework rules** (Verification Rules, Leanness, SOLID, Agentic Workflow) are in [.github/instructions/framework-rules.instructions.md](./.github/instructions/framework-rules.instructions.md). If your agent has not already loaded that file, read it before planning or editing.`
  Claude Code does not need it: it loads the rules through the
  `@.github/instructions/framework-rules.instructions.md` line in `CLAUDE.md`, and `template-checks`
  fails when that line is missing.
- **`dependency-audit` now has a procedure for upgrading .NET or Angular to a newer major
  version**, one stack per pass. Ask for it by name, for example "use the dependency-audit skill to
  upgrade the API to .NET 10": we have not tested whether your agent picks the skill for an upgrade
  request that does not name it. The skill now tells your agent to read that stack's breaking
  changes on the vendor's pages first, to ask you for a build and test command before editing if
  your repository records none, to build and test each pass with the commands your repository
  records, and to commit it on its own. On the .NET side the agent is to move straight to the
  target, normally the newest long-term-support release, so no commit targets an out-of-support
  version; after you confirm the target SDK is installed where your recorded commands run, it is to
  move target frameworks, ASP.NET Core, EF Core and the other runtime-versioned packages, and
  committed Dockerfile and CI versions together. Where you have a `global.json`, it is to change its
  SDK version and keep its `rollForward`, and not to add one unless you ask. New SDK warnings,
  including .NET 10's audit of transitive packages, are to be fixed or deferred on the record the
  way `enforce-standards` handles an existing warning wall (an `AnalysisLevel` pin or a per-rule
  severity change, noted in `TECH_DEBT.md` and raised again later rather than kept as a permanent
  suppression, or a `NuGetAuditSuppress` entry beside its `SECURITY_FINDINGS.md` row), never by a
  blanket `NoWarn`, by turning warnings-as-errors off, or by setting `NuGetAuditMode` to `direct`.
  On the Angular side it is to move one major version per pass, as Angular requires, with
  `ng update` so its migrations run: the one Angular CLI command the skill names without a row in
  your Verification Commands, shown to you first and never with `--force`; in an Nx workspace it is
  to use an `nx migrate` command your repository records, or report the upgrade as not available.
  It is to install nothing: SDK, Node, Visual Studio and server prerequisites are listed as your
  actions, and mentions of the old version in `AGENTS.md`, `FRAMEWORK-CONTEXT.md` and your docs are
  to be updated. No upgrade has been run with it yet; review the result as you would a hand-made
  upgrade. An update does not change your `AGENTS.md`; to name the upgrade in your Common Tasks
  list, change the `dependency-audit` line to:
  ``- `dependency-audit` — scan for vulnerable/deprecated/outdated NuGet and npm packages, set up automated scanning, or upgrade .NET or Angular to a newer major``

## 0.91.0 — 2026-09-30

- **The installer stops when the framework clone you run it from is out of date.** Before it changes
  anything, it asks the clone's remote whether a newer release tag exists and, when your checkout
  tracks a branch, whether that branch has moved ahead. If so it exits with code 4, names the newer
  release or how far behind you are, and gives the `git` command that updates the clone. Add
  `-AllowOutdated` to install the older copy on purpose; a deliberate downgrade to an older release
  now needs it as well as `-AllowDowngrade`. The question is one `git ls-remote`: it downloads
  nothing, turns off Git's prompts, and the whole check gives up after 10 seconds. When the check
  cannot be made (offline, no Git, a copy that is not part of a clone) the install goes ahead with a
  NOTE saying so.

## 0.90.0 — 2026-09-29

- **`/rebootstrap` re-analyses only what changed since the last run.** `/bootstrap` now ends by
  recording a baseline, `.claude/bootstrap-baseline.tsv`; commit it with the other artifacts. It holds
  a content hash of your files and, for each convention written to `AGENTS.md`, the files that
  convention rests on. `/rebootstrap` compares your working tree with it through
  `scripts/bootstrap-baseline.ps1`. When nothing outside the framework's own files changed and no
  line of `AGENTS.md` was added or edited, it stops before any analysis. Otherwise it re-analyses only
  the changed areas, checks each edited line, rechecks only the conventions whose files changed, and
  carries the rest forward. It runs a profile in full when
  a project manifest was added or removed, or a solution file, `angular.json`, `nx.json` or
  `dbt_project.yml` changed, or more than half of that profile's conventions are affected, and it
  records a new baseline at the end. A repository bootstrapped before this version has no baseline,
  so its first `/rebootstrap` runs in full and records one; `/rebootstrap full` always forces a full
  run. A convention a run finds out of date but you leave unchanged is reported again by the next run
  rather than skipped, and `/bootstrap` lists each convention it could not tie to files, which an
  incremental run will not recheck. Moving or renaming a file without changing it no longer
  rechecks the conventions resting on it, unless one names its old folder or file name, and a Known
  Hazard Areas row that names it is re-pointed to the new path without a question, keeping its
  status and review date. The repository-knowledge discovery pass is unchanged.

- **`AGENTS.md` is now the one instruction file you edit; `CLAUDE.md` only imports it.** Your
  conventions, verification commands, architecture index, common tasks and Boy Scout rules live in
  `AGENTS.md`, which GitHub Copilot, Codex and Cursor read directly. `CLAUDE.md` is a stub with two
  import lines, `@AGENTS.md` and `@.github/instructions/framework-rules.instructions.md`, so Claude
  Code loads the same text. Nothing is generated from `CLAUDE.md` any more, and `docs-sync-check`
  checks the stub instead of comparing two copies. GitHub Copilot, which also reads `CLAUDE.md`,
  stops loading the framework rules and your conventions twice: its always-loaded instructions shrink by about 40% before
  `/bootstrap` adds your conventions, and by more after. Codex and Cursor now reach the framework
  rules through the pointer at the top of `AGENTS.md` instead of an inline copy.
  **What the update does to your repository:** when `AGENTS.md` is still the generated copy (its
  first line is the `GENERATED FILE` banner), the installer moves your `CLAUDE.md` text into `AGENTS.md` once,
  rewrites only the opening lines that described the old layout, writes the `CLAUDE.md` stub, and
  keeps both originals in `.claude/framework-update-backup/instruction-files/`. Review the diff and
  bump the version stamp at the top of `AGENTS.md` before committing. If you wrote your own
  `AGENTS.md`, the installer leaves both files as they are and says so; merge `CLAUDE.md` into
  `AGENTS.md` yourself and replace `CLAUDE.md` with the stub (`docs/upgrade-checklist.md`, step 8).
  Until then the session-start hook and `template-checks` remind you.

- **`.github/copilot-instructions.md` and `/generate-copilot` are gone.** The framework no longer
  ships or regenerates the slim Copilot digest, and `docs-sync-check` no longer fails without it.
  VS Code's Copilot inline suggestions never read it, and VS Code chat, the Copilot CLI, the cloud
  agent and GitHub code review read `AGENTS.md` as well, so they were loading your conventions twice.
  `/bootstrap` and `/adopt` no longer write it, `/docs-sync` no longer compares it, and `/bootstrap`
  no longer stops because one of your own is still in place.
  **What the update does to your repository:** it deletes `.claude/commands/generate-copilot.md` and
  `.github/prompts/generate-copilot.prompt.md` when they match a framework release, and keeps and
  reports an edited copy. It never touches your `.github/copilot-instructions.md`: delete it, or keep
  it as your own file if your team uses Copilot in Visual Studio or Copilot Chat on github.com, which
  are not documented to read `AGENTS.md`. Nothing regenerates it any more.

- **The framework rules your agent loads on every turn are shorter.** A few sentences in
  `.github/instructions/framework-rules.instructions.md` described what hooks can and cannot be shown
  to do, rather than telling your agent anything to do; they are gone, and "a delivery profile proves
  no command" is no longer repeated where "run only exact recorded invocations" already says it. No
  rule changed: workflow rails stay binding, the security pass still applies whether or not a hook
  reminder appears, and the team wiki is still read on demand.
- **Plain-language test and feature requests get the full workflow rules again.** When you ask for
  tests or a new feature without a slash command, the prompt hook's reminder now carries two rules the
  framework rules already required but the reminder had dropped: see each new behavioral test fail
  before trusting it, and do not add a test harness just for a feature. Nothing else in it changed.

- **A first install no longer overwrites files you already have.** If your repository already has a
  file where the framework installs one (a `.github/PULL_REQUEST_TEMPLATE.md`, a `.claude/settings.json`,
  a `.claude/commands/review.md`), even one you gitignore or one outside Git, the installer now moves it
  to `docs/pre-adoption/` before copying and tells you to run `/adopt`, which merges it with the
  framework's version. Before, it replaced the file without a backup. A file identical to the
  framework's does not count. Check `docs/pre-adoption/` for secrets before you commit: it can now hold
  files you had kept out of Git.

- **The installer now installs into a folder with square brackets in its name.** Given a path such
  as `C:\src\app[v2]`, it read the brackets as a wildcard: it could install into a neighbouring folder
  that matched, such as `C:\src\app2`, and still report success, or stop with an unhelpful error when
  nothing matched. It now uses the path exactly as you give it. On a machine without PowerShell 7,
  such a folder now also gets the Windows PowerShell 5.1 hooks, as any other folder does.

- **`-AllowDirtyTree` now works through the framework's root `install.ps1`.** When the installer
  stops because your repository has uncommitted changes, it tells you to re-run with `-AllowDirtyTree`
  once you have committed, stashed or copied them; the root installer used to reject that switch.
  Under Windows PowerShell 5.1, typing `.\install.ps1` inside a framework copy whose folder name has
  square brackets, such as `ai-tech-lead[2]`, now runs that copy's installer, not the one in a
  neighbouring folder such as `ai-tech-lead2`. Starting it with `powershell.exe -File` from such a
  folder can still run the neighbour's copy, because Windows PowerShell reads the brackets before the
  installer starts: use PowerShell 7, or a folder name without brackets.

- **The brownfield installer says exactly what it moved.** When your repository already has AI
  tooling, the installer now lists the files it moved to `docs/pre-adoption/` because it would have
  overwritten them, and the files it left where they were, such as `.cursorrules`. It used to say your
  originals had been moved even when nothing was, and named `CLAUDE.md` twice. The reminder at the
  start of each session no longer says originals were archived when none were.

- **Retired framework files are now removed from Windows clones too.** When an update retires a
  framework file, it deletes your copy only if you have not changed it. Git on Windows usually checks
  files out with Windows line endings, and the installer counted that as a change, so it kept retired
  files such as the `/generate-copilot` command and reported them as edited by you. It now ignores line
  endings in that comparison; any other difference still keeps the file. Files retired by updates you
  have already run are not revisited: the installer keeps listing them for you to remove.

- **`/adopt` no longer commits configuration files Git ignores.** Tool configs such as
  `.aider.conf.yml` or `.continue/config.json` are often kept out of Git because they hold API keys.
  `/adopt` could move such a file into `docs/pre-adoption/`, where it could be committed with the
  adoption, and could quote its contents in its report. It now lists an ignored file by path only and
  leaves it where it is. It also leaves in place a tracked file whose archive path your `.gitignore`
  excludes, instead of committing its removal with an archive nobody else can see.

- **The installer keeps your gitignored files out of Git and says when your ignore rules hide
  framework files.** If a file the framework has to replace was one you had gitignored, such as a
  personal `CLAUDE.md` or a `.claude/settings.json` holding keys, its copy in `docs/pre-adoption/` is now
  listed in `docs/pre-adoption/.gitignore`, so committing the install does not commit it, and the
  installer names these files. If your `.gitignore` hides framework files, for example with a `/.claude/`
  rule, the installer warns and lists them: committing the install would leave them out and your
  teammates would not get the hooks, commands or rules. The framework's `.claude/.gitignore` now also
  ignores `.claude/settings.local.json`, Claude Code's per-developer settings file.
- **Corrected: VS Code's agent hooks are on by default.** The docs said they were off by default;
  VS Code turns them on (`chat.useHooks`) in a trusted workspace, and your organization can turn them
  off. Until a canary on your host confirms a hook control there, plan on it being instruction-only;
  `docs/enforcement-surfaces.md` shows what has been observed and advises leaving `chat.useClaudeHooks`
  off. A new install's `docs/ARCHITECTURE.md` no longer points you at a README, changelog or installer
  script that the install does not copy into your repository. An update keeps your existing copy, so
  correct its hooks sentence in section 9 and those pointers by hand. The review guide,
  `/security-review`, the `dependency-audit` skill and `docs/ci-integration.md` no longer point at the
  framework's README or changelog either; an update refreshes those. The docs-sync-check message about
  a pending adoption now names the right `/adopt` step.
- **`/adopt` now finds the history of a moved file you committed under a different letter case.** If
  a file the install had to move to `docs/pre-adoption/` was committed as, for example,
  `.github/pull_request_template.md`, `.claude/adoption-pending.json` now records it as Git spells it,
  so `/adopt` reads its author and history instead of flagging it as untracked. When Git reports that
  none of the moved files was gitignored, the installer no longer also asks you to check
  `docs/pre-adoption/` for gitignored secrets.
- **`framework-doctor` no longer reports retired files that are not there** when your repository's
  folder name holds square brackets and you run it with Windows PowerShell 5.1. It used to list absent
  retired hook helpers as `[PENDING]` and 18 absent retired paths as `[CANT-VERIFY]`.
- **`/bootstrap` and `/rebootstrap` agree on what a hazard row's `Reviewed` date means:** the day the
  row was added, or a person last confirmed or dismissed it; nothing else changes it. `/bootstrap` dates
  the rows it adds, `[UNVERIFIED]` ones included, and keeps an existing row's date unless you answer it;
  `/rebootstrap`'s "skip all", which a run with nobody to answer takes, adds no new candidate.
- **The architecture-test sample no longer breaks your build.** `scripts/ci/ArchitectureTests.sample.cs`
  is now `scripts/ci/ArchitectureTests.cs.sample`. A project file at your repository root compiled the old
  one with every other `.cs` file, and it needs NetArchTest and xUnit, so `dotnet build` failed after
  installing. An update deletes the old file unless you edited it or your install predates v0.65.0; in
  either case delete `scripts/ci/ArchitectureTests.sample.cs` yourself. The `enforce-architecture` skill copies
  the sample into your test project as `ArchitectureTests.cs`.
- **A never-restored .NET repository no longer reads as a broken build.** When `post-write` runs
  `dotnet build` before the NuGet packages were ever restored (NETSDK1004/1005), it now tells your agent
  the build was not verified and to run `dotnet restore` once, instead of "dotnet build failed -- fix
  before continuing", and waits five minutes before trying again.
- **An update stops cleanly when it cannot delete a retired framework file**, for example because
  another program is reading it. It used to fail with a raw PowerShell error part-way through removing
  retired files. It now names the file and the error, puts back any retired file it had already removed,
  and stops before copying anything, so your repository is unchanged and re-running the installer after
  you resolve the cause finishes the update.
- **An update that cannot remove the active copy of a skill you disabled now finishes everything else
  and says what is left.** Before, it stopped part-way with a raw PowerShell error. The skill's files are
  already kept under `.claude/disabled-skills/`; the installer names the folder and the error, and
  deleting that folder once nothing holds it finishes the update.
- **An update cut short while backing up your skills now takes that backup again.** The one-time
  backup under `.claude/framework-update-backup/skills/` is taken before framework skills are
  overwritten. When a file another program held cut it short, a later update skipped it and could
  overwrite a skill you had edited with no copy left. The backup now stays marked unfinished until
  its last copy, and a held file stops the update, naming the file, before any skill is overwritten.
- **The presentation deck no longer installs into your repository.** An update removes the four
  unmodified `docs/presentation/` files (about 97 KB) that v0.65.0 or later installed. A copy you edited,
  or one from an older install, is kept, and each update names it until you delete it. The deck and its
  talking points stay in the framework checkout under `dist/<stack>/presentation/`.
- **Re-running an update no longer replaces your saved settings.** `.claude/.state/settings.json.pre-update`
  holds your `.claude/settings.json` from before the update. A later run of the same update, which finds
  the framework's own settings in place, now keeps that backup instead of overwriting it with them.
- **New feature logic now goes where its responsibility belongs.** When a feature adds a new
  responsibility, the agent puts it in its own class or Angular service, even with one consumer,
  instead of adding it to the nearest existing one or subclassing it. Code that belongs to an existing
  class's job still goes there, and UI state used by one component stays in it. The framework rules,
  the feature prompt rails, `/feature`, `add-service`, `register-service` and the SOLID review now agree.

## 0.89.2 — 2026-09-24

- **The README in the framework download now starts with what you get and who does what.** A new
  table walks through install, `/bootstrap` or `/adopt`, review and daily work, naming who runs each
  step and what it produces; the `/map-warehouse` step appears only when `/bootstrap` selects the
  warehouse-SQL profile. Host and platform limits sit in one Host support section, and the
  instructions for an AI agent installing the framework follow Quick Start. The README is not
  copied into your repository, so nothing in your repository changes.

## 0.89.1 — 2026-09-21

- **Your agent is now told to use a matching skill, not only shown the list.** On GitHub Copilot CLI
  the skills under `.claude/skills/` were loaded and listed to the agent, but in our test runs it
  never opened one: it planned and edited from the general rules alone, so recipes such as
  `add-warehouse-load` never reached the work. `CLAUDE.md > Common Tasks` and `AGENTS.md` now say to
  invoke the matching skill before planning or editing. In our runs Claude Code already opened the
  matching skill without being told. Nothing for you to do.

## 0.89.0 — 2026-09-21

- **The write guard now really stops the write on Claude Code for Windows.** Since 0.83.0
  (2026-09-04) the hook registrations have asked Claude Code to run each hook through an outer
  PowerShell, and that shell reports any failing command as exit code 1. The guard blocks with exit
  code 2 — so Claude Code saw a non-blocking hook *error* rather than a block: it printed the reason
  ("Blocked write to …") and then performed the write anyway. A hardcoded secret, an
  `// eslint-disable`, or a weakened test could reach disk with the block message sitting right
  there in the transcript. This release restores the block.
- **The post-write `dotnet build` and `tsc --noEmit` checks were being dropped the same way.** A
  build or type-check that failed after a write printed its errors but was never fed back to the
  agent, which then carried on over a broken build. They now reach the agent again.
- **To get the fix, update this repo.** The installer refreshes `.claude/settings.json` and saves
  your current copy to `.claude/.state/settings.json.pre-update` first: if your team added its own
  hooks or settings to that file, re-apply them from that backup afterwards.
  `.claude/settings.windows.json`, the Windows PowerShell 5.1 fallback, carries the same fix.

## 0.88.0 — 2026-09-20

- **The `/impact` command is retired.** Its A/B runner was removed in 0.83.0, so what remained was
  a descriptive report under a name most developers read as "what does this change affect?" — which
  it never did. On update, an unmodified `.claude/commands/impact.md` and its Copilot twin
  `.github/prompts/impact.prompt.md` are deleted; a copy you edited is preserved and reported so
  you can remove it yourself.
- **For the same numbers, run `scripts/metrics.ps1` directly.** It is unchanged and still reports a
  current-state scorecard. It is a snapshot, not a before/after measurement.
- **Updates now report every retired framework file you still have.** Previously only a few
  categories were mentioned, so a file retired in a later release could sit in your repo with no
  notice. Your files are not deleted by this: a copy you edited is still preserved, now with a line
  saying it is retired and what to do about it.
- **Retired files with no successor no longer point you at another retired file.** Where a `.sh` and
  its `.ps1` twin were retired together, the message either named the dead twin or was missing
  entirely; it now says plainly that there is no replacement command.
- Anything already written to `docs/impact/` is left exactly as it is. Nothing writes there now, and
  the directory is safe to delete.

## 0.87.0 — 2026-09-20

- **The post-write `dotnet build` or `tsc --noEmit` type-check can no longer hold up the agent for minutes.** It now gets 45
  seconds. A run that takes longer is stopped, along with every process it started, and reports
  nothing; the next check then waits five minutes. To give a large solution more time, set
  `ATL_POSTWRITE_BUDGET_SEC` (whole seconds, up to 600) in the environment the agent runs in. The
  Claude Code hook registration also carries a 90-second timeout as a backstop.
- **The write guard now blocks two Azure secret shapes in every file, test files included**: a
  storage account key (`AccountKey=` followed by an 88-character key) and a SAS token signature
  (`sv=<date>` together with `sig=`). The Azurite emulator's published development key is still
  allowed.
- **Hardcoded credentials are now blocked in files whose names merely contain "test", "spec" or
  "mock".** Before this release, any path containing one of those letter sequences skipped the
  check, for example `LatestRatesClient.cs` or `Specification.cs`. Test, spec, mock, fixture,
  sample, example and `Development` files are still exempt when the word is a separate part of the
  file or folder name: `AuthServiceTests.cs`, `Api.UnitTests/`, `app.spec.ts`, `__mocks__/`,
  `appsettings.Development.json`, `.env.example`. If a write is now refused, move the value to
  user-secrets, environment variables or a vault.
- **The generated `docs/architecture.html` view is retired.** It rendered its diagrams by loading
  third-party script from a content delivery network every time you opened it, with no integrity
  checking. `docs/ARCHITECTURE.md` is unchanged and remains the canonical architecture map — read it
  in your editor or your Git host, which render the Mermaid diagrams that page used to draw.
- On update, `docs/architecture.html` is replaced by a short placeholder pointing at the Markdown, so
  existing links and bookmarks keep working. The placeholder is safe to delete.
- `scripts/build-architecture-html.ps1` is removed. An unmodified copy is deleted on update; a copy
  you have edited is preserved and reported so you can review it before removing it yourself.
- HTML you generated with that script previously — including any `/impact` report — is left exactly
  as it is. This release does not repair or delete those files; regenerate or remove them yourself.
- `scripts/docs-sync-check.ps1` no longer checks `architecture.html` freshness.
- **`docs/enforcement-surfaces.md` now states what the write guard does not see.** The guard checks
  the text of a write: a whole file's content, or the replacement text of an edit — never the file
  that edit produces. So a credential whose key sits in the surrounding line, with only its value
  replaced, and a secret split across two edits, are not caught. This is a stated limit, not a change
  in behaviour: nothing that was refused before is allowed now. Keep `/security-review`, code review
  and your own platform's secret scanning in place for the rest.

## 0.86.7 — 2026-09-11

- The MIT licence now credits `ai-tech-lead contributors`. Updates replace the exact previous
  framework licence automatically; locally modified licence files still require manual resolution.
  The MIT terms are unchanged.

## 0.86.6 — 2026-09-11

- Mutable `.claude/ai-audit.log` telemetry is now ignored. For an already tracked log, follow the
  upgrade checklist to stop tracking it while keeping the local file; prior Git history remains.
- Bootstrap reconciles specific debt references in `CLAUDE.md` before generating `AGENTS.md` and
  Copilot instructions. Generated references retain the canonical identifier and qualifications.
- Warehouse findings and proposed remedies must stay within explicitly inspected tables and
  source evidence. Inventory-only objects remain unresolved; missing declarations alone do not
  justify schema changes. Refresh existing maps to apply this guidance.

## 0.86.5 — 2026-09-11

- Wiki drafting guidance now asks descriptions to preserve the whole entry's scope and uncertainty,
  using the same text in the wiki index.

## 0.86.4 — 2026-09-09

- Quick Start now uses the supported installer from the matching monorepo distribution, routes
  stamped targets to the upgrade checklist, and preserves the commit plus developer bootstrap/adopt handoff.

## 0.86.3 — 2026-09-09

- Updates now install `docs/upgrade-checklist.md` and point to it after completion. Use it to
  preview file operations, reconcile protected local rules, regenerate derived instructions, and
  verify the result without replacing intentional project policy.

## 0.86.2 — 2026-09-09

- Adoption guidance now distinguishes keeping the pending marker when verification fails before bootstrap from restoring its saved bytes after removal.

## 0.86.1 — 2026-09-09

- Adoption now shows the complete archive-plan JSON object with its required `entries`
  array before freezing. Include every selected candidate, including quarantines, in
  that one plan. Archive verification and recovery safeguards are unchanged.

## 0.86.0 — 2026-09-07

- Bug fixes now keep cleanup tied to the requested outcome, compatibility, or verification. Existing
  APIs and components do not need cancellation-token, logging, or subscription-cleanup rewrites just
  because they changed. Updates keep your `CLAUDE.md`, `AGENTS.md`, and Copilot instructions protected
  while refreshing framework rules.

## 0.85.0 — 2026-09-07

- `/adopt` now preserves every archived original **byte-for-byte** and proves it. The installer
  records a raw SHA-256, byte length and Git provenance for each file it moves into
  `docs/pre-adoption/`, and `/adopt` re-verifies those bytes with `scripts/adoption-archive.ps1
  -Verify` both before it runs `/bootstrap` and again after the bootstrap documentation check — it
  will not report adoption complete if an archived file was changed, is missing, or cannot be
  examined. Screen an installer-archived original at its recorded pre-move revision, not at the
  post-install commit. Nothing changes for greenfield installs or framework updates.

## 0.84.0 — 2026-09-06

- Bootstrap and rebootstrap now discover consequential repository facts and operations beyond
  recurring recipes, capture grounded findings as review drafts in the existing wiki/skill/map
  locations, and recheck changed evidence without treating generated text as authority. Ordinary
  changes selectively consult matching project knowledge and retain unresolved scope.
- The .NET and Angular instance-shaped operation skills now derive their concrete patterns from
  first-party project evidence. Optional consumer-owned `references/project-pattern.md` files can
  record local variants and are preserved across lifecycle operations; the framework ships no
  placeholders that could overwrite them. Skill refresh decodes BOM-less UTF-8 explicitly so
  non-ASCII project examples survive Windows PowerShell 5.1 updates.
- Full reviews now give every auditor and the test-weakening advisory one hashed frozen change
  bundle, distinguish invalid input from inability to examine it, and stop if the subject drifts.
  Financial review now judges applicable invariants, tolerances, preconditions and demonstrated
  outcomes instead of assigning severity from numeric types or named locking mechanisms alone.
- The retired installer `-GitHooks` argument has been removed. Existing consumer-owned hooks and
  the framework doctor's historical-helper diagnostics remain unchanged.

## 0.83.0 — 2026-09-04

- Framework installation, hooks, checks, and supplied CI now use PowerShell on Windows. PowerShell
  7 is preferred and Windows PowerShell 5.1 remains the supported fallback for framework scripts.
  Linux, WSL, macOS, BSD, and Copilot cloud hook execution are no longer supported.
- Claude Code 2.1.141 or newer is required. Project settings enable its native PowerShell tool and
  select PowerShell explicitly for hooks. Local Copilot hooks require PowerShell 7 on Windows.
- The optional Git pre-commit hook installer is retired. Existing consumer-owned hooks are never
  deleted automatically; dependent legacy helpers are preserved and reported until you review and
  remove or replace the hook. Protected documentation, local settings, and custom CI that still
  reference retired shell commands are reported without being overwritten.

## 0.82.0 — 2026-09-04

- Project skills now ship once under `.claude/skills/`, which current Claude Code and GitHub
  Copilot skill surfaces both support. The generated `.github/skills/` copy and
  `scripts/sync-agent-files.*` are removed, along with their update and parity machinery.
- Updating removes known-clean historical mirror and sync-script files when prior ownership can be
  verified. A known retired file that cannot be safely removed is preserved and named with
  migration guidance; unknown consumer-only skills remain untouched. An old GitHub skill can
  shadow its canonical Claude copy, and an old sync script can recreate that shadow. Move
  intentional skills to `.claude/skills/` and remove the old copy after review. Framework checks
  stay red while `.github/skills/` remains.
- A brownfield repository containing `.github/skills/` now enters adoption. Interactive and
  headless adoption report the untrusted paths and stop before archiving, moving, deleting, or
  executing them so a person can migrate conflicts safely.
- `AGENTS.md` remains a full rules carrier for Codex and GitHub code review. Documentation no longer
  claims that Copilot CLI, Gemini, or Aider uniquely or automatically require it; the other GitHub
  adapters remain because prompts, cloud agents, inline completion, path instructions, hooks, CI,
  and pull requests have separate host contracts.

## 0.81.0 — 2026-09-03

- Framework-maintainer hook tests are no longer installed under `tests/hooks/`, preventing them
  from being selected or reported as your application's test suite. Existing known-clean copies
  are removed on update; locally changed or unverifiable copies are preserved and reported.
- Verification-command discovery now excludes framework-owned and retired commands, including
  wrapped or differently quoted/path-separated forms. Explicit framework checks remain available
  through their documented workflows and are reported separately from application verification.

## 0.80.0 — 2026-09-01

- The shared Agentic Workflow now makes reconciliation of affected repository truth part of
  completing a change. The agent must update affected writable canonical artifacts, regenerate
  derivatives from source, respect each artifact's ownership, evidence, history, and security rules
  without inferring human intent, and report none affected, reconciled artifacts, or blockers. An
  affected artifact it cannot read or safely update is a blocker. This reaches Copilot and new or
  migrated Claude installations through the shared instructions. Legacy unmigrated Claude
  installations retain the existing assisted-migration limitation. Exact delivery is verified
  structurally; model compliance is unmeasured.

## 0.79.2 — 2026-08-31

- Host compatibility evidence is now stated per capability. Copilot CLI 1.0.80 remains observed
  for single-entry prompt delivery and post-tool context, but the registered `agentStop` Boy Scout
  scan has not been observed firing end-to-end and is no longer described as guaranteed. VS Code
  Preview-hook prompt, post-tool, and Stop lifecycles remain unverified; its 2026-06-25 guard-deny
  observation is retained as historical evidence because the host and extension versions were not
  recorded. Installer file arrival is now stated separately from dated host-consumption evidence.
  Hook logic and registration are unchanged. Direct fixtures, diagnostics, hook comments, and the
  architecture diagram now distinguish script output from host firing and consumption; a missing
  canary response is inconclusive rather than proof of one host failure.

## 0.79.1 — 2026-08-31

- `/bootstrap` now treats code as evidence of implemented surfaces, not product intent or actual
  user behavior or value. Intended purpose and target users require a named person or role authorized
  to decide them; actual behavior and value require direct research or operational evidence. New and
  refreshed bootstrap commands receive this boundary, but updates preserve your existing populated
  `CLAUDE.md > Codebase Context`; review that context manually because it is not rewritten.

- The shipped framework-doctor test suite now constructs its Copilot CLI visibility fixtures
  portably under Windows PowerShell 5.1. The four visibility cases and doctor behavior are unchanged;
  running the suite through the documented legacy-host command no longer fails because nested Bash
  redirection was mis-marshalled as a Windows path. Its working-Python control is also quote-stable,
  so a configured real interpreter is exercised instead of being reported as unavailable.

## 0.79.0 — 2026-08-31

- Supported and release-tested hosts are now explicitly Windows and Linux. macOS is unsupported and
  untested; any compatibility there is incidental and carries no release guarantee. This withdraws
  the previous “works out of the box” macOS claim. Teams using macOS should evaluate the framework
  independently before upgrading.

- The framework doctor now reports deterministic-check findings separately from checks it could
  not complete. `scripts/template-checks` uses exit `0` for clean, `3` for one or more verified
  findings, and `2` when required input could not be inspected; the printed finding count is
  unchanged. The doctor maps only `3` to `MISSING`, tells you to run the checker and follow its
  exact findings, and reports other nonzero exits as non-failing `CANT-VERIFY`. If custom automation
  treated the old exit code as the finding count, read the printed summary or handle `3` instead.
  `scripts/docs-sync-check` retains its documented `0` pass / `1` fail contract: in template repos
  it preserves checker output but maps every nonzero checker status to wrapper `1`. Automation that
  relied on the wrapper passing through child status `2` or `3` must invoke `template-checks`
  directly if it needs that diagnostic distinction.

- The Bash Copilot skill-mirror script no longer uses recursive globbing to calculate a decorative
  count. Its completion message is now `Synced skills: .claude/skills -> .github/skills`; the count was
  removed from both script variants because it did not affect mirroring. If automation parses the
  old count-bearing message, update it to match the new verdict. Mirrored files are unchanged.

- The Bash installer no longer uses Bash-4-only arrays or lowercase expansion while validating its
  ownership and retirement inventories. ASCII case-variant duplicate paths are still rejected
  before target changes; PowerShell behavior and the installed file set are unchanged. This is
  best-effort portability and does not establish macOS or stock-Bash-3.2 support.

- The Bash installer now treats every temporary file as one exact owned path, so `TMPDIR` names
  containing spaces or glob characters are no longer word-split or expanded during cleanup. The
  previous behavior could delete an unrelated caller-directory path and leave the real temporary
  files behind. Cleanup attempts every retained path, reports its own failures without hiding an
  earlier installer failure, and exits `3` when target work succeeds but cleanup does not. A
  `TMPDIR` that resolves inside the selected target now refuses with exit `3` and no persistent
  target change instead of causing a false dirty-tree refusal; set `TMPDIR` outside the target and
  rerun.

- Warehouse-map checking no longer recognizes the undocumented
  `## Declined artifact: warehouse-map` heading. An applicable warehouse without
  `docs/warehouse-map.md` now reports `missing` even when that old heading is present. The map stays
  optional: `docs-sync-check` remains advisory, and warehouse work can still proceed from the
  equivalent live table, key, relationship, and load-order evidence. Updates leave existing
  `LEARNINGS.md` bytes untouched. If custom CI calls the checker directly and relied on the heading
  to force exit 0, handle the ordinary missing-map exit 1 instead.

- When the warehouse-map checker cannot examine your repository, `docs-sync-check` now says the
  map could not be verified and that this is not evidence it is missing or stale. A checker that
  verifies a missing or stale map keeps the existing refresh note. The warehouse branch remains
  advisory and the overall docs-sync exit policy is unchanged. The same classifications now remain
  reachable when custom automation invokes `bash -e scripts/docs-sync-check.sh`; an interpreted
  child status no longer terminates the wrapper before its advisory or final verdict. This does not
  make inherited strict mode a general framework contract.

- Bash session start now consumes a final security row even when the file has no trailing newline,
  so an overdue security finding retains its red SLA warning. Where the existing 90-day cutoff is
  available, the Bash hazard reader also consumes a final unterminated row and recognizes ordinary
  CRLF plus trailing spaces/tabs already accepted on the exact `Known Hazard Areas` heading; an
  incomplete row without its closing pipe remains ignored. This change does not alter host cutoff
  availability. PowerShell behavior, thresholds, messages, consumer input files, and advisory exit
  0 are unchanged.

- Bash updates now keep a framework skill disabled when protected `LEARNINGS.md` starts with the
  standard UTF-8 BOM commonly written by Windows PowerShell 5.1, or when the exact disabled-skill
  heading uses CRLF or admitted trailing whitespace. The file stays byte-identical, malformed or
  misplaced BOMs do not broaden the syntax, and PowerShell behavior is unchanged. If an earlier
  Bash update reactivated such a skill, update again to move the current framework copy back under
  `.claude/disabled-skills/`.

- The hazard completion check now fails when `FRAMEWORK-CONTEXT.md` is missing, still pending,
  lacks exactly one `## Known Hazard Areas` section, retains the exact bootstrap placeholder, or
  contains neither real rows nor the exact no-notable sentence. It also rejects mixing that
  sentence with real rows. These states mean discovery is incomplete rather than successfully
  complete. If an update exposes one, finish `/bootstrap` or `/rebootstrap` and rerun the documented
  completion command.
- Path evidence now handles backticked text safely, treats balanced bracket patterns as globs,
  reads a final row even without a newline, and rejects drive-prefixed or exact `.`/`..` segments
  before sentence punctuation is removed. Valid dot-named paths such as `.github/...` and
  `.cache/...` remain accepted.
- Update and brownfield installation now works on a plain non-Git target under Windows PowerShell
  5.1 as well as PowerShell 7 and Bash. Git remains optional when the target and its ancestors
  contain no repository evidence.
- Before changing an update or brownfield target, both installers now refuse with `CANT-VERIFY`
  when ambient `GIT_DIR`, `GIT_WORK_TREE`, `GIT_COMMON_DIR`, or `GIT_INDEX_FILE` can redirect
  inspection, repository metadata cannot be
  classified, Git is unavailable despite repository evidence, or worktree status cannot be read.
  Unset the routing variables or repair/install Git, then rerun. Existing dirty-tree refusal and its
  explicit override are unchanged.
- On Windows, the Bash installer applies the same refusal to case variants such as
  `git_index_file` under both legacy and current Git-for-Windows Bash host identities. Unknown
  non-empty Cygwin/`MSYSTEM` identities fail closed rather than being treated as ordinary POSIX;
  generic Cygwin remains outside the supported host contract.

## 0.78.3 — 2026-08-27

- `scripts/hazard-check.ps1` and `.sh` now require every real `Known Hazard Areas` row to name an
  exact resolving repository-root-relative path. Pure prose, labels, symbols, URLs, and globs may
  accompany that path but cannot replace it; a bare filename now means a file at the repository root.
- Hazard statuses must be complete case-sensitive tokens. A
  `[REVIEWED: not a hazard — YYYY-MM-DD]` date must be calendar-valid and match the `Reviewed` column.
  Existing placeholder, pending, and missing-section skip behavior is unchanged. If the stricter
  check finds an older row, replace its area with an exact path and reconcile its review dates.

## 0.78.2 — 2026-08-27

- `/bootstrap`, `/rebootstrap`, and `/generate-copilot` now show separate copy-pasteable completion
  commands for Windows PowerShell 5.1, PowerShell 7, and bash. On Windows without `pwsh`, use the
  `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/docs-sync-check.ps1` command.
- Completion still requires exit code 0 and the exact final success line; this change adds a
  supported invocation and does not weaken the gate.

## 0.78.1 — 2026-08-27

- Updates now preserve `docs/architecture-decisions.md` byte-for-byte, and brownfield installation
  leaves it at its project-owned path for in-place screening. A missing file is still seeded for a
  new installation.
- If you already updated through v0.78.0 after recording decisions, inspect version-control history
  or another backup and restore any lost ADR content; the framework cannot reconstruct overwritten
  decisions.

## 0.78.0 — 2026-08-27

- `/bootstrap`, `/rebootstrap`, `/adopt`, and `/generate-copilot` now run the installed
  deterministic documentation checks before claiming completion. A failing generated artifact is
  repaired when it is in scope; otherwise the workflow reports failure or `CANT-VERIFY`. Hazard rows
  require a supported bare status token and at least one resolving repository path.
- `TECH_DEBT.md` retains dismissed proposals separately from active debt. Matching claims remain
  suppressed until materially changed evidence is named; reopening preserves the dismissal and
  records the specific delta.
- Brownfield adoption screens mature architecture and ADR documents in place. Clean documents keep
  their original bytes, paths, and links; flagged content is quarantined; broken references are
  reported; and competing indexes require your choice.
- Project-specific skill discovery excludes framework-owned carriers through
  `framework-ownership.json` while keeping eligible consumer-owned and corroborated mixed evidence.
  Finite debt is no longer copied into the always-loaded Boy Scout list.
- Asking why something is technical debt is answer-only and no longer triggers cleanup; the
  existing security overlay and queued Boy Scout behavior remain intact.
- Updates protect a pre-existing project `docs/ARCHITECTURE.md`, and Bash skill synchronization no
  longer resolves Windows `FIND.EXE` accidentally.
- Boy Scout, hazard, and wiki checks now select POSIX `sort`/`find` under non-login Git Bash, where
  Windows commands could previously hide findings or reject a clean index. Audit logs redact every
  path outside the repository, including existing paths.

## 0.77.0 — 2026-08-24

- Bootstrap now selects only the .NET, Angular, and warehouse-SQL profiles evidenced from the Git
  root. Warehouse-only and partial-stack repositories no longer need an absent application
  workspace or receive analysis for one.
- Exact repository-evidenced commands are recorded under `CLAUDE.md > Conventions > Verification
  Commands` for build, test, format, lint, migration/deploy, and data validation; unsupported
  categories remain `not available`. Feature, fix, refactor, review, test, debt, rebootstrap,
  routing, verification-bearing skills, defaults, and CI guidance no longer infer both application
  stacks or their commands from this distribution's name. Migration/deploy inventory remains
  manual/CI-only unless the exact command is non-mutating or explicitly authorized for a known target.
- `framework-doctor` requires toolchains only for evidenced application markers, including
  structurally valid Angular workspace/package/Nx evidence. SQL-only repositories report application tooling and its app canary as not
  applicable; incomplete bounded marker scans are `CANT-VERIFY` and generated/dependency trees are
  excluded. A `.sln` containing only SSDT/`*.sqlproj` projects is not .NET application evidence and
  does not activate the dotnet post-write branch.
- Brownfield `/adopt` still owns archive and merge, then passes the detected profiles into its
  Phase-7 `/bootstrap` run. It excludes every current path in `framework-ownership.json` from
  legacy archival and retains the pending marker until immediately before that handoff.
- Root auto-detection selects this distribution for Angular plus warehouse evidence so neither
  profile is lost. Testing defaults prefer the smallest risk-relevant set and do not create a
  foreign harness as an incidental side effect.
- Framework-shipped skills remain installed byte-stable as an applicability-gated superset;
  bootstrap advertises only evidenced tasks and adds separate project-specific skills instead of
  deleting or tailoring shipped recipes.

## 0.76.0 — 2026-08-23

**Updates are now inspectable and converge across skipped releases.** The installer prints a
deterministic create/replace/preserve/archive/delete plan before changing your repository. Use
`-WhatIf` or `--dry-run` to inspect the same operation set without changing target bytes. Installing
an older framework release now refuses before mutation unless you deliberately pass
`-AllowDowngrade` or `--allow-downgrade`; the root installer forwards both controls.
The plan also names settings backup and each skill backup, disable, and mirror write; installer-
owned side paths are checked for symlink/junction escape before any change.

The retired `impact-run` scripts and three `tests/impact/` compatibility files are removed on update
only when your previous ownership manifest names them as framework-owned and their bytes match a
known shipped framework version. A custom or edited file at one of those names is preserved. Missing,
malformed, unsafe, or unexaminable previous metadata enters a named additive compatibility mode and
performs no stale deletion.

## 0.75.0 — 2026-08-23

**The documentation now matches what the installed controls can prove.** Editor/file-write guards
and local telemetry are explicitly hook- and client-dependent; shell/external writes remain outside
that surface, and `.claude/ai-audit.log` is mutable local telemetry rather than compliance evidence.
NetArchTest and `dependency-cruiser` are scaffoldable backstops and become enforcement only after you
wire them into blocking CI. Copilot CLI evidence is dated, while VS Code hooks are Preview, off by
default, organization-gated, and not certified across the full lifecycle.

Install counts now come from `framework-ownership.json`, and the README names the licence and notice
that ship in this distribution. `/impact` remains an optional descriptive current-state report; it
does not create an adoption baseline or A/B result.

Root auto-detection now refuses a warehouse-only repository before changing it because solution-free
adoption is not yet certified. If you have reviewed that limitation and deliberately want the .NET
lifecycle, select `dotnet` explicitly; ordinary mixed-repository detection is unchanged.

## 0.74.0 — 2026-08-22

**Impact A/B retirement.** Adoption no longer requires an impact baseline, an agent CLI, or an
impact report to finish. The previous pre/post comparison was invalid because its supposed
pre-adoption reference was captured after installation. `/impact` can still create a descriptive
archive-to-capability inventory and current repository scorecard, but neither is an A/B result or
proof that adoption caused a change.

The retained `impact-run` scripts now safely stop with a clear non-zero retirement message and do
not start agents, tools, or worktrees. Compatibility files remain until a later framework update
removes them safely.

## 0.73.0 — 2026-08-22

**Installer safety fix: existing repository files and audit history are no longer disposable
framework inputs.** On brownfield installation, every incoming file collision the copy would
replace is discovered from the shipped ownership manifest and archived at its exact relative path under
`docs/pre-adoption/` before framework files are copied. If an archive destination already exists,
installation refuses before changing the target instead of replacing the earlier archive.
Archive sources and destinations that traverse a symlink or junction are also refused before any
move, so `docs/pre-adoption/` cannot redirect your originals outside the repository.

An existing `.claude/ai-audit.log` now remains byte-for-byte unchanged through installation and
update. Unknown GitHub-only skills under `.github/skills/` also survive framework skill syncing.
The consumer-owned `docs/wiki/INDEX.md` remains active and unarchived, as its copy-if-absent policy
requires.

Brownfield and update installs into a dirty Git worktree now refuse with a commit/stash/copy
recovery action. If you have deliberately reviewed those changes, the stack installer provides the
explicit `-AllowDirtyTree` / `--allow-dirty-tree` override and names its use on stdout. Greenfield
non-Git installation is unchanged.

## 0.72.0 — 2026-08-22

**New: a test-weakening advisory, consulted during `/review`.** Run
`pwsh scripts/test-weakening-scan.ps1` (or the `.sh` twin) and it reports test files whose staged
diff removes more assertion-shaped lines than it adds — the shape of a test being quietly gutted
rather than refactored.

**It never fails anything.** It prints what it found and exits 0, every time, including when it
reports. That is deliberate: removing assertions is not by itself wrong. Deleting a duplicated case,
replacing three weak assertions with one strong one, migrating to a different assertion library, or
removing a test for behaviour you deleted all look exactly like weakening a test, and no rule can
tell them apart. A check that blocked on this would refuse correct work, and you would quickly learn
to skip it.

So treat it as a prompt to look, not a verdict. It is a reviewable signal that can be defeated by
ignoring it; it is not enforcement, and it is not a substitute for reading the diff.

One limit worth knowing: it counts *lines*, so three assertions written on one line and then deleted
register as a single removal.

## 0.71.0 — 2026-08-22

**Security fix: the write guard no longer misses a test suppression split across two lines.** Writing

```csharp
[Test,
 Ignore("flaky")]
```

was blocked on Windows but **allowed** wherever the hooks run through Bash — macOS, Linux, or WSL.
Same for `[Fact(` on one line and `Skip="flaky")]` on the next. It is legal C# that no formatter
objects to, so it was a quiet way past a guard you were told was deterministic.

Both implementations now agree. The Bash guard joins lines *inside* a bracketed attribute list before
matching, so the two halves are seen as the one construct they are. No pattern changed, and nothing
became stricter: an ordinary multi-line attribute list such as

```csharp
[Theory,
 InlineData(1),
 InlineData(2)]
```

still passes, on both implementations. If you write attributes across lines for readability, nothing
about your code needs to change.

## 0.70.0 — 2026-08-22

**`docs-sync-check` will no longer tell you your documentation has drifted when the real problem is
your machine.** The check looks inside `AGENTS.md` for a banner and a set of headings. If that search
could not *run* — a missing tool, a locked file, a machine short of resources — it saw no matches and
concluded the file had drifted, then told you to run `/generate-copilot` to regenerate a file it had
never actually read.

Both the PowerShell and Bash versions now tell the difference. A genuinely stale `AGENTS.md` reports
exactly as before, with the same fix. A search that could not execute reports a host or resource
problem instead, and says plainly that it is not evidence your documentation has drifted.

## 0.69.0 — 2026-08-22

**The hook test suite now passes on Windows PowerShell 5.1.** If you ran `tests/hooks/` with
`powershell.exe` rather than `pwsh`, you would have seen roughly half the guard cases fail — 41 of
82 — with messages showing two apparently identical strings. Those failures were not real. Windows
PowerShell 5.1 was adding its own decoration to the captured output, including a stack trace, so the
comparison was of PowerShell's formatting rather than of the hooks themselves.

The test harness now reads the hooks' output directly, so both PowerShell editions see the same
thing, and line endings are normalised between the PowerShell and Bash implementations, which
legitimately differ. Nothing about the hooks themselves changed, and the suite still fails when it
should: it was re-checked against a deliberately broken guard and reported the failures correctly on
both editions.

If you skipped the suite because it looked broken, it is worth running again.

## 0.68.0 — 2026-08-21

**New, and off unless you ask for it: a pre-commit convenience net.** Install it with
`-GitHooks` (PowerShell) or `--git-hooks` (bash) when you run the installer, or run
`scripts/setup-git-hooks.ps1` / `.sh` later. Nothing is wired up unless you choose it.

What it does: before a commit, it sends **only the lines you are adding** through the same guard the
agent already uses, and stops the commit if one of them contains something that should not be
committed — a token, a key, a hardcoded credential. Lines already in the file are not examined, so
editing a file that has a pre-existing problem will not block you for someone else's code.

**It is a convenience, not a guarantee.** `git commit --no-verify` skips it, and any client or
workflow that does not run local hooks never sees it. Treat it as a helpful catch on the way past,
not as a control you can rely on — if you need enforcement, that belongs in CI where it cannot be
bypassed.

**It will not touch an existing hook setup.** If you already use `core.hooksPath`, have your own
`.git/hooks/pre-commit`, or use husky, setup stops and tells you what it found rather than
overwriting it. Your existing checks are yours.

## 0.67.0 — 2026-08-21

**Three more checks stopped reporting success for work they never did.** `warehouse-map-check`,
`template-checks` and `wiki-check` each search a file or a file list to decide what to inspect. If
that search could not *run* — a missing tool, a machine short of resources — they saw an empty result
and read it as "nothing to check here", then passed. `warehouse-map-check` would conclude your repo
was not a data warehouse; `template-checks` would find no changelog headings and therefore no
problems with them; `wiki-check` would find no wiki entries and therefore no bad ones.

All three now tell the difference between *nothing found* and *could not look*. A genuinely empty
result behaves exactly as before — a repo with no warehouse files, or a wiki index with no entries,
is still perfectly valid and still passes. A search that could not execute now stops with a message
naming the file and saying it is a host or resource problem, not a verdict about your repository.

This completes the change begun in v0.64.0 for `framework-doctor` and `impact-run`.

## 0.66.0 — 2026-08-21

**`tests/hooks/Guard.Tests.ps1` can now run a subset of its cases.** Set `GUARD_TEST_POLICY` to a
policy name to run only the guard cases tagged with it, which is useful when you are iterating on one
pattern and do not want to wait for the whole table. Unset — the normal case — nothing changes: the
full suite runs exactly as before.

If the value you set matches no cases the suite stops with exit 111 and says so, rather than
reporting a pass for work it never did.

## 0.65.0 — 2026-08-21

**New: `framework-ownership.json` tells you which files in your repository the framework owns.**
Installing this framework adds around 164 files to your repository, and until now nothing in the tree
told you which ones are ours and which are yours. That matters in two places: a reviewer facing the
first commit has no way to separate the product from the scaffolding, and six months later a
developer editing something like `scripts/framework-doctor.ps1` has no way to know their change will
be replaced the next time you update.

The manifest lists every installed path with one of three ownership classes:

| class | what it means for you |
|---|---|
| `framework-owned/overwritten` | We replace this on every update. Do not edit it — your changes will be lost. |
| `consumer-owned/protected` | Yours. We create it once if it is absent and never touch it again. |
| `mixed` | Shared. `.claude/settings.json` carries our hook registrations alongside your own settings. |

It is generated when the distribution is built rather than maintained by hand, so it always describes
the version you actually installed. If you want to know whether an edit will survive an update, this
file is the answer.

## 0.64.0 — 2026-08-21

**`framework-doctor` and `impact-run` no longer report a machine problem as a problem with your
files.** Both used a text search whose failure to *run* looked identical to the searched text being
*absent*. So on a machine short of resources — often exactly when you are running the doctor,
because something is already wrong — you could be told your documentation had drifted when it had
not, with a confident fix to apply. `impact-run` was worse: a failed search there silently changed
which project type it decided your repository was, and it carried on.

Both now separate the two. A genuine absence still reports as a finding with the same fix as
before; a search that could not execute reports as a host or resource condition and never as a
verdict about your files. `impact-run` stops rather than guessing at your project type.

**Optional per-file timing for the hook test suite.** Set `HOOKTESTS_TIMING=1` to have
`tests/hooks/Invoke-HookTests.ps1` print `TIMING <file> <seconds>` for each test file. It is off by
default and output is unchanged when unset — it is there for when a suite has grown slow enough
that you want to know which file is responsible.

## 0.63.0 — 2026-08-21

- The enforcement-surface guide now says explicitly that the write guard is a deterministic floor
  only for editor/file-write tool calls. Shell-authored and externally written files bypass it, so
  it is not an all-writes guarantee.

## 0.62.0 — 2026-08-20

- Changelog validation now examines every semantic-version heading. It rejects duplicate release
  headings and any `Unreleased` heading for a version that is already shipped, while still allowing
  the next version's normal pre-release authoring heading.
- The duplicate `0.56.0` entry has been merged into its dated release entry without losing the
  detailed update-safety guidance.
- Changelog validation also rejects a **dated** heading for a version above your installed framework
  version. Previously only the first heading in the file was examined, so a stray or future-dated
  release heading below it was invisible.
- **The enforcement-surface guide no longer contradicts itself about Copilot's post-write feedback.**
  One table row said the channel was version-dependent while two nearby passages said flatly that it
  was broken. Re-measured on **Copilot CLI 1.0.80**: post-write hook output **does** reach the model.
  On CLI 1.0.68 it did not. Check your installed CLI version before relying on it — and note that the
  Boy Scout nudge never depended on this channel, so it is unaffected either way.
- **The mixed-stack `applyTo` advice is now honest about what has actually been verified.** The
  READMEs told you that path-scoped instruction files are honoured. We have not been able to confirm
  that on any surface we can test, and a scoped file that does not reach the model **fails silently** —
  it installs correctly and simply never arrives. On Copilot CLI 1.0.80 a *narrow* `applyTo` delivered
  nothing at all, even with a matching file named in the prompt, whether written with braces, commas
  or a plain glob; only `applyTo: "**"` arrived. VS Code agent mode, which is what this advice is aimed
  at, remains unverified. The advice is kept — the mechanism is documented by the vendor — but it now
  comes with a one-minute check you can run to see whether your own scoped file is reaching your agent.

## 0.61.0 — 2026-08-19

**`framework-doctor`'s "Protected-file sync" row now tells you something you can act on.** It used
to compare the version stamp inside your `CLAUDE.md` against the version of the installed machinery.
Since 0.45.0 that comparison has meant nothing: `CLAUDE.md` is yours, and its stamp is *expected* to
lag behind the framework. The practical result was a permanent `DIVERGED` for anyone who installed
before their current version — no explanation of what had diverged, and no way to make it stop.

The row now reports whether the framework-rules migration actually finished:

- **OK — migrated.** Your `CLAUDE.md` imports the rules carrier and no longer carries its own copies
  of Verification Rules, Leanness, SOLID, or Agentic Workflow.
- **PENDING — migration incomplete.** You added the import, but one or more of those four sections
  are still written out inline in `CLAUDE.md`. The row names exactly which ones. They duplicate the
  carrier and can conflict with it, so delete them from `CLAUDE.md`.
- **Deferred.** If the import or the carrier is missing entirely, this row stays quiet and the
  `Framework rules delivery` row above it tells you what to do — it already owns that case, and
  saying it twice helps nobody.
- **MISSING.** Your `CLAUDE.md` is absent or unreadable, so the state cannot be inspected.

**What you may need to do.** If you have been carrying a `DIVERGED` row, run
`scripts/framework-doctor.ps1` (or `.sh`) again. If it now says PENDING, delete the named sections
from your `CLAUDE.md` — the carrier is the current version of those rules and your inline copies are
frozen at whatever version you installed. If it says OK, nothing is required; the old row was
telling you about a mismatch that did not matter.

**Also fixed:** an empty or unreadable `CLAUDE.md` used to make the PowerShell doctor drop two rows
from its report without saying why, while the Bash doctor still printed them. Both now behave the
same and report the problem.

**Your `CHANGELOG.md` is no longer checked against our release format.** `scripts/template-checks`
used to parse the first heading of any `CHANGELOG.md` it found and require our dated
`## X.Y.Z — YYYY-MM-DD` form. That is our release convention, not yours — if your team follows
Keep a Changelog (`## Unreleased` above the versions) or anything else, the check was failing your
build over a style we have no standing to impose. It now parses the changelog **only** in the
framework's own template repository, which your installed copy is not. Nothing to do; this only
removes a false failure.

## 0.60.0 — 2026-08-18

**The write guard now inspects mixed-case file extensions on every surface.** A file named
`Foo.CS` or `app.TS` was checked by the PowerShell guard and silently skipped by the Bash one,
so on Copilot CLI (which runs the Bash hook) such a file was not guarded at all. Both now
inspect it. If your repository uses mixed-case extensions anywhere, expect the guard to start
speaking up about files it previously ignored — that is the fix, not a regression.

**The guard no longer stops enforcing without telling you.** Its checks are regular expressions,
and a broken one used to be indistinguishable from "nothing to report": the check simply stopped
blocking and the write went through. Now a pattern that cannot run says so, and what happens next
depends on how confident that check is. The secret-scanning rules — private keys, cloud and
service tokens — **block the write** if their pattern is broken, because a security floor that
has quietly stopped checking is worse than a refused write. The lower-confidence rules that flag
skipped tests, tautological assertions and suppression pragmas **warn and let the write through**,
so a defect in our pattern cannot block an ordinary refactor. Either way the message names the
pattern and its category, so you can tell us.

**Fewer false blocks on wrong-case text.** Content matching is now exact, matching the languages
themselves: C#, ESLint directives and TypeScript pragmas are all case-sensitive. Text like
`ASSERT.True(true)` or `// ESLINT-DISABLE` — which is not valid code in the first place — no
longer trips the guard, and both hook implementations now agree on every case tested.

**You do not need to do anything.** Updating picks this up. If you have added your own patterns to
a local copy of the guard, note the new convention: content patterns are matched case-sensitively,
and anything that decides *which files to inspect* folds case deliberately and says so inline.

## 0.59.0 — 2026-08-18

**GitHub Copilot CLI: the workflow-routing nudge was not reaching the model, and now does.**
Copilot CLI delivers only the *last* of the repository's `userPromptSubmitted` hooks. This framework
registered two, with the routing hook first — so on Copilot CLI the per-prompt nudge that classifies
your request and restates the plan-gate and security-pass rails was being dropped before it reached
the model, while the end-of-turn cleanup nudge (registered second) arrived normally. Verified live
against Copilot CLI 1.0.80 on 2026-08-18.

The framework now registers a single hook that carries both messages, routing first. **You do not
need to do anything** — the change is in the installed hook wiring, and updating picks it up. If you
hand-edited `.github/hooks/hooks.json` to add your own `userPromptSubmitted` entry, be aware that
only the last one registered will reach the model; fold your content into one entry rather than
adding a second.

What this did *not* affect: Claude Code, which consumes every registered hook and was always
receiving both; the write guard, which runs on a different event; and the always-on rules in
`AGENTS.md` and the instructions carrier, which reach the model on every turn regardless. Those
rules are why the routing rails were still described to the model even while the per-prompt nudge
was being dropped. `docs/enforcement-surfaces.md` has been corrected — it previously claimed the
per-prompt injection worked on Copilot CLI.

**`framework-doctor` could report documentation drift that did not exist.** Its mirror-and-version
check ran the template checker through a bare interpreter name. On a machine whose `PATH` does not
resolve that name, the check could not start — and the doctor reported that your `CLAUDE.md` and
`AGENTS.md` had drifted, telling you to regenerate them, when nothing was wrong. It now runs the
checker with the interpreter already running it, and when it genuinely cannot run one it says so
plainly: drift is *unknown*, not *found*, and the problem is your host, not your documentation.

## 0.58.0 — 2026-08-17

- `docs-sync-check` now rejects Known Hazard Areas rows with invalid Status tokens, invalid Reviewed
  dates, or named paths that do not exist, so a hazard row pointing at a file you deleted or renamed
  stops looking current. Update those rows before the required build check runs. A cell naming just a
  filename matches that filename anywhere in the repo; a cell naming a path resolves it from the repo
  root; a cell with a wildcard checks only the directory prefix before the first wildcard. Prose and
  symbol names in that cell are ignored. The check never edits the table — statuses stay yours.

## 0.57.0 — 2026-08-17

- Once every seven days, session start now names your installed framework version and points you to
  the releases page to check for updates. It makes no network request and does not claim that a
  newer version exists. If the local throttle state cannot be written, the hook stays quiet and
  does not disrupt the session.

## 0.56.0 — 2026-08-17

- **Updating is now explicit about what it replaces — and you should know it always did.** Running
  the installer over an existing install overwrites framework-owned files: skills, hooks, `scripts/`,
  and `.claude/settings.json`. That is how fixes reach you, and it has always worked this way — but
  the run said nothing, and its closing line ("consumer-owned content files untouched") named only
  the eight protected files. **If your team edited a shipped skill, hook, or `.claude/settings.json`
  in the past, an earlier update may already have discarded it** — check your git history if that
  matters to you.
  From this release: the update prints a preflight notice **before** it changes anything, telling you
  to commit, stash or copy local edits first; it saves your current `.claude/settings.json` to
  `.claude/.state/settings.json.pre-update` before refreshing it, and names that path; and its
  closing line says what it actually did.
- Ownership is now documented as three classes rather than two: consumer-owned protected paths
  (restored on update), framework-owned machinery (overwritten), and `.claude/settings.json`
  (mixed — backed up, refreshed, then adapted to your host).
- `docs/enforcement-surfaces.md` gained the missing **on-demand / discoverable** tier, covering
  supporting material such as `docs/defaults.md`: available for the model to open, but loading is
  task- and model-dependent and not guaranteed.

## 0.55.0 — 2026-08-17

- Greenfield Angular defaults now cover **forms**: reactive with typed controls, where validators
  live, and how a custom form control should integrate — including an honest trade-off between
  providing `NG_VALUE_ACCESSOR` and injecting `NgControl`, since neither is an anti-pattern. The
  `add-component` skill gained a matching custom-form-control branch. Forms are the largest surface
  of a line-of-business Angular app and the framework previously said nothing about them. These are
  greenfield defaults: if your repo already has a forms approach, the guidance tells the agent to
  mirror yours rather than introduce a second.

## 0.54.0 — 2026-08-17

- **Fixed a broken update on the Bash installer.** Running `bash scripts/install.sh` against an
  existing install aborted part-way with exit code 1 and no error message: the files were copied,
  but the run stopped before finishing and never printed its "Done (update)" summary. If you wired
  the installer into CI, it reported a red build on a successful update; if you ran it through an AI
  agent, the agent saw a bare failure. `install.ps1` was unaffected, so the two installers disagreed
  about whether the same update had worked. Updates now complete and exit 0 on both.
- Framework installs now include `LICENSES/ai-tech-lead-MIT.txt` and
  `NOTICE-ai-tech-lead.md`, so the framework's MIT terms travel with its files. Updates refresh the
  framework-owned notice but refuse to overwrite a conflicting licence or unmarked notice; resolve
  any named collision and run the installer again.

## 0.53.0 — 2026-08-16

- Fixed: on a repository checked out with CRLF line endings, `docs-sync-check` could report
  `## Verification Rules`, `## Leanness`, `## SOLID` and `## Boy Scout Rule` as missing from
  `CLAUDE.md` when they were present and correct. The Bash and PowerShell checks now agree on
  CRLF input. If you have been ignoring those four findings, re-run the check — it should now
  be quiet, and any finding it still reports is real.
- `docs-sync-check` now verifies that `CLAUDE.md` and `AGENTS.md` list the same skill slugs under
  `## Common Tasks`, so adding a skill to only one agent surface is caught. Descriptions may remain
  condensed and are deliberately not compared. No action is required unless the check reports a
  one-sided or duplicate skill entry.

## 0.52.1 — 2026-08-13

- The framework's behavior cases are now a readable catalogue rather than an API-backed runner.
  Documentation now describes how to inspect or reuse those cases; no action is required.
- Security review no longer records active or suspected credential incidents in Git or echoes their
  protected detail. Ordinary findings use minimised rows; legacy registers require human migration.

## 0.52.0 — 2026-08-10

- `map-warehouse` now reports evidence-ranked modelling-health findings and offers a bounded
  deepening for allocation and multi-fact consumption risks. SCD findings now require a complete
  load that proves the mismatch instead of relying on absent markers.

## 0.51.5 — 2026-08-09

- `template-checks` (one of the framework's own quality gates) now fails if this file's top entry
  carries your installed version number but still says `Unreleased` instead of a date -- a
  safeguard against ever seeing a placeholder date here. Nothing to do unless it flags this file.

## 0.51.4 — 2026-08-08

- `framework-doctor` now reports capabilities only from the environment it actually observes.
  Registered Claude and Copilot Bash guards make the PowerShell doctor say that their runtime
  parser is unobservable; a Bash doctor reports only on its own environment. Portable hook-shell
  registrations no longer prompt machine-specific absolute paths, stack and Copilot command
  details identify the doctor-process boundary, and a new post-write canary verifies the actual
  agent-hosted build hook. Bash registrations may use shell-valid single quoting or any case of
  the `bash.exe` basename without hiding guard-parser demand.
- The Copilot-skill sync script (`sync-agent-files`) no longer crashes with a raw error under
  Windows PowerShell 5.1 when run outside a Git repository -- it now falls back cleanly to the
  current directory, the same fix already shipped for the architecture-HTML generator.

## 0.51.3 — 2026-08-08

- Shipped documentation is now checked for dangling relative inline links as well as dead script
  commands. Bootstrap's warehouse-map example is shown as literal Markdown syntax, so the command
  page no longer renders a broken link while preserving the exact link agents should write.

## 0.51.2 — 2026-08-08

- The shipped hook test suite's Windows PowerShell 5.1 compatibility case no longer depends on
  `powershell.exe` being directly on `PATH` — it falls back to the well-known
  `%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe`, so a host where 5.1 exists but
  isn't PATH-exposed now gets a genuine test run instead of a silent skip.

## 0.51.1 — 2026-08-08

- The shipped PowerShell test harness now keeps child scripts on the same PowerShell host as an
  individual suite invoked directly. Such a test file run under Windows PowerShell 5.1 now
  genuinely exercises 5.1 instead of silently switching its children to PowerShell 7; the aggregate
  runner still selects its preferred host. The architecture HTML generator also now falls back to
  its current directory cleanly when run outside a Git worktree under 5.1.

## 0.51.0 — 2026-08-08

- Warehouse writes now require a current map or equivalent live-schema inventory; pure SQL/SSDT/dbt
  sides can be detected and adopted without a solution file.
- Updates preserve exemplars and discovered skills, and refresh disabled skills without activation.
- Instance-shaped .NET and Angular recipes now search for an existing owner before scaffolding.

## 0.50.0 — 2026-08-07

- **`add-warehouse-load` now asks whether the dimension already exists — before it designs one.**
  The recipe used to go from "find an existing load to copy" straight to "design the entity", so a
  new fact was scaffolded without anyone deciding *which dimensions it should reach*. Most new loads
  need **no new dimension at all**, and a duplicate one is the expensive mistake: it splits a single
  business entity across two surrogate-key spaces, and nothing in the load fails — the numbers just
  stop agreeing between two reports, months later.
- **The new step sorts every non-measure source column into one of three buckets**: it reaches an
  existing dimension, it is degenerate (an invoice or order number that stays on the fact), or it is
  genuinely new — and that last branch now has to be justified out loud, naming what was searched.
  Matching is on the **concept and its business key, not the column name**: your source's `cust_ref`
  and `DimCustomer.CustomerCode` are one key under two names, and two same-named columns routinely
  are not the same thing. The table inventory in `docs/warehouse-map.md` is the list it searches.
- **Three checks that a name match will not catch**, each of which produces a wrong warehouse rather
  than an error:
  - **Indirect reach.** An attribute may be owned by a dimension reached *through* another
    dimension. If region is already reached via `DimCustomer.RegionKey`, putting a `RegionKey` on
    your new fact creates a second, contradictory path to the same dimension.
  - **Grain compatibility.** A dimension at a coarser grain than the fact needs silently loses
    detail; at a finer grain it multiplies rows. The right entity at the wrong grain is a
    conversation to have, not grounds for a second dimension.
  - **Conformed use.** If another fact already reaches this dimension, join it the way that fact
    does — same key, same role — rather than inventing a second edge to the same table.
- **The load step now decides what a failed dimension lookup does.** Every foreign key is resolved
  by joining your staging business key to the dimension's — and where history is kept, to the
  version that applied, using your repo's own as-of rule copied from a sibling load. A lookup that
  finds nothing is a **late-arriving member, not a row to drop**: an inferred/stub member, a
  reserved `Unknown`/`-1`, or fail-and-retry, whichever your warehouse already does. Silently
  discarding unmatched rows makes a fact's totals wrong in a way that reconciles against nothing.
- **Two new sign-off items**: no dimension was created that duplicates an existing one, and every
  fact foreign key resolves — with the count sent to the unknown/inferred member **reported**, not
  assumed to be zero.
- **If your repo has both an application database and a warehouse**, the recipe now states the
  boundary in its own body rather than only in its trigger description: it governs warehouse tables
  in the SQL tree, while a table backed by your ORM model or its migrations belongs to the OLTP
  entity recipe.
- **What you need to do:** nothing — the updated skill arrives with your next update. It works best
  when `docs/warehouse-map.md` is current, since that is where it looks up each dimension's business
  key; if you have not built or refreshed one recently, run `map-warehouse` first.

## 0.49.0 — 2026-08-06

- **`map-warehouse` now maps the warehouse, not just how it is loaded.** Until now the map told you
  how `FactSales` is loaded and whether that load is re-runnable — and could not tell you what
  `FactSales` joins to, or which dimension owns an attribute. Every one of its eight columns was a
  loading property. The map now also carries a **table inventory with primary, surrogate and
  natural keys**, a **fact → dimension relationship list** as its primary artifact, the dimensional
  semantics a report depends on (fact type, role-playing and conformed dimensions, degenerate
  dimensions, measure additivity), and a **Coverage** section naming what could not be read.
- **Every relationship says how it was learned, and "I do not know" is a valid answer.** Each edge
  is labelled `Declared` (a real foreign key or dbt relationship test), `In use` (a join an existing
  reporting view actually performs), `Load-derived`, `UNRESOLVED`, or `CONFLICTING`. **A naming
  convention alone is never enough to assert a relationship** — `CustomerKey` looking like it points
  at `DimCustomer` is recorded as an unresolved candidate, not as a fact. A wrong label is worse
  than no label: it retires exactly the doubt that would have sent someone to check the view.
- **The map now carries its own "Querying this warehouse" section**, so the rules are in the
  document you open when you are about to write a report. They cover the two ways a warehouse query
  goes wrong *quietly* — producing a plausible number instead of an error:
  - Reaching an attribute off a column that merely sits on an already-joined table. A column
    declared in DDL but never populated by any load looks identical to a real one in a `SELECT`
    list, and returns blanks rather than failing.
  - Putting `EffectiveFrom`/`EffectiveTo`/`IsCurrent` predicates on a join whose key already
    identifies one dimension version. That **silently drops every fact row pointing at a superseded
    version** — a low row count, not an error — and in review the extra predicate reads as *more*
    careful, so it survives the scrutiny that would catch a missing filter. The map records, per
    relationship, whether the version was pinned when the fact was loaded or is still to be chosen
    at query time, which is the only thing that settles it.
  - Plus the fan and chasm traps, and the rule that you copy an existing reporting view's join path
    before inventing one.
- **After `/bootstrap`, CLAUDE.md > Conventions > Data Access gets a one-line pointer to
  `docs/warehouse-map.md`**, the same index-then-detail split already used for architecture
  decisions. The detail stays in the map so it does not sit in context on every turn.
- **What you need to do:** nothing to install — the updated skill arrives with your next update.
  To get the new content into your map, **re-run `map-warehouse`**; it refreshes
  `docs/warehouse-map.md` in place. Existing maps are not upgraded automatically.
- **No changes to the Angular side of this release.**
## 0.48.0 — 2026-08-06

- **Your assistant now reads what your repository already says about a subsystem before writing
  code against it.** A new always-on rule (Verification Rules #11) tells it to check `docs/` for a
  file describing the database schema, warehouse, integration, or shared library it is about to work
  against, and to read that file first — and that what your repository records about its own
  structure outranks what can be inferred from names. If the document is missing, stale, or silent,
  it now says so rather than guessing. For example, if your repo has a warehouse map, a schema document, or an API contract under `docs/`, your assistant will now open it before writing code against what it describes.
- **This one was measured before it shipped.** On a test repository, the assistant previously opened
  the relevant document in **0 of 6** runs; with this rule it opened it in **6 of 6**.
- **You receive this on your next update** — it ships in `.github/instructions/`, which the installer
  refreshes. No action needed.


## 0.47.0 — 2026-08-06

- **Four Angular-side skills now state when to use them — and when not to.** `add-component`,
  `add-lazy-route`, `add-service` and `add-signal-store` each carried only a one-line description,
  so your assistant had less to go on when choosing between them than it did for `add-tests` or the
  audit skills. Each now says what it is for — something that does not exist yet — and what it is
  not for, naming where to go instead: changing an existing component or route goes to `/feature`
  or `/refactor`, backfilling tests goes to `add-tests`, a stateless HTTP service goes to
  `add-service`, and shared cross-component state goes to `add-signal-store`. The .NET-side skills
  already carried these clauses and are unchanged.
- **No action needed.** The recipes themselves are unchanged — only the descriptions your assistant
  reads when deciding which one applies.

## 0.46.0 — 2026-08-05

- **Fixed: on Windows without `jq`, the prompt-routing hook silently did nothing.** If your machine
  has no `jq` installed, `route-prompt.sh` fell back to looking for a Python interpreter by name. A
  standard python.org install on Windows provides `python.exe` and **no `python3.exe`**, so the hook
  went on to try plain `python` — which on most Windows machines resolves to the Microsoft Store
  placeholder, a stub that is not an interpreter. Having picked it, the hook could no longer fall
  back to its last-resort path, so it produced **no output at all** and exited successfully. The
  workflow rails it exists to inject never reached the model, and nothing said so.

  There was a quieter second case: with a real interpreter installed as `python`, the hook read your
  prompt correctly but still emitted plain text instead of JSON, which GitHub Copilot discards.

  It now finds a JSON parser by **running** each candidate rather than trusting its name, and only
  when `jq` is genuinely absent — so nothing changes, and nothing slows down, if you have `jq`.
  **No action required.** If you were affected you will simply notice the routing context appearing
  again.

- **Fixed: `framework-doctor` reported your write guard as inactive when it was working.** With no
  `jq` but a usable Python present, the guard was correctly blocking secret writes while the doctor
  told you the floor was OFF and advised installing `jq`. The doctor now asks the same question the
  guard asks, and reports `CANT-VERIFY` where it genuinely cannot observe the answer rather than
  guessing. It also now distinguishes "your `hooks.json` is invalid" from "there is no parser here to
  check it with" — previously both produced the same message.
## 0.45.0 — 2026-08-05

- **Action required (one line, once): your always-on rules now live in a file the installer can
  update.** Until now, `CLAUDE.md` was protected on update — the installer restored your copy so it
  could never overwrite your conventions. That protection is right and is unchanged, but it also
  meant framework changes to the **Verification Rules**, **Leanness**, **SOLID** and **Agentic
  Workflow** sections inside that file never reached you: if you installed before this release, the
  copies in your `CLAUDE.md` are as old as your first install.

  Those four sections now ship in `.github/instructions/framework-rules.instructions.md`, which is
  **not** protected and therefore updates from now on. Your repo-specific sections — Conventions,
  Boy Scout Rule, Codebase Context, everything `/bootstrap` wrote — stay in `CLAUDE.md` and are
  still never touched.

  - **GitHub Copilot users: nothing to do.** Copilot reads that file natively, in both the CLI and
    VS Code agent mode. It is already current.
  - **Claude Code users: add one line to `CLAUDE.md`**, where those four sections are, then delete
    the stale sections themselves:

    ```
    @.github/instructions/framework-rules.instructions.md
    ```

    Until you do, your session start will remind you once per session, and
    `scripts/framework-doctor.*` will report the delivery row as `[MISSING]`. Nothing breaks in the
    meantime — you simply keep reading your older copy of the rules.

- **Fixed: on Windows, the write guard could be silently inactive.** `guard.sh` blocks writes that
  contain secrets, test-defeats or suppressions. It needs a JSON parser: `jq` first, with Python as
  the fallback. The fallback only ever looked for `python3` — but a standard Windows Python install
  provides `python.exe` and no `python3.exe`. **So on a Windows machine without `jq`, the guard
  printed `write-guard INACTIVE` and allowed the write, even with Python installed.** It now finds
  `python3`, `python` or the `py` launcher, and confirms each actually runs before trusting it —
  which also rules out the Microsoft Store placeholder that looks like Python but is not.

  **Worth checking:** if your team runs the `.sh` hooks (Git Bash / WSL / macOS / Linux) and does not
  have `jq` installed, your write guard may not have been enforcing. Run
  `bash scripts/framework-doctor.sh` and look at the `Guard JSON parser` row. Installing `jq`
  remains the most reliable option on any platform.

- Fixed: a documentation link inside the moved rules pointed at a path that no longer resolved from
  its new location.

## 0.44.0 — 2026-08-02

- **New: `tests/hooks/HarnessIntegrity.Tests.ps1` — the test harness now proves it can report
  failure.** Every other file in `tests/hooks/` tests a hook. This one tests the scoreboard they are
  scored on, because a defect there is the quietest kind: every suite still prints its results and
  every exit code lies. A real one shipped — under Windows PowerShell 5.1, `Write-TestSummary`
  returned `$null` instead of a failure count, so a file with **exactly one** failing test printed
  `[FAIL]` and still exited `0`, and the runner scored it green. That was fixed previously; this
  adds the test that would have caught it, at both levels (a suite file's own exit code, and the
  runner's sum).
- **If you run the hook suite in CI, run it on the PowerShell host your developers actually use.**
  The above was invisible under PowerShell 7, which returns a real integer for the same expression.
  A green PowerShell 7 run does not tell you the harness behaves correctly on Windows PowerShell
  5.1. The new test runs its fixtures under whichever host is running it, so a 5.1 run genuinely
  exercises 5.1.
- No action required. Nothing about your hooks, rails, or conventions changed.

## 0.43.0 — 2026-08-01

- **`tests/hooks/Invoke-HookTests.ps1` now sizes itself to your machine.** The lane count was fixed
  at 4 regardless of hardware. It now defaults to your logical core count (capped at 8), and honours
  a `HOOKTESTS_THROTTLE` environment variable if you run several suites at once and want to hand
  each a share. Nothing about what is tested changed.
- **`Guard.Tests.ps1` now drives both the `.ps1` and `.sh` guard twins from one pass.** The `.sh`
  twin's decision parity used to be checked in `TwinParity.Tests.ps1`, which re-ran every `.ps1`
  case a second time to compare against. Each guard case is now executed once per twin instead of
  three times in total, and a broken `.sh` twin reports the wrong decision directly rather than only
  "differs from .ps1". Coverage is unchanged: both twins are still checked against the expected
  decision and against each other, and guard still gets full `.ps1` coverage on hosts with no bash.

## 0.42.0 — 2026-08-01

- **`/rebootstrap` now re-confirms your Known Hazard Areas — it always claimed to, and never did.**
  Its description said it refreshes "hazards", but no step in it touched
  `FRAMEWORK-CONTEXT.md > Known Hazard Areas`. It now has a Phase 3c that makes three passes: it
  checks whether the files each row names still exist (a row pointing at a deleted or renamed file
  looked fresh indefinitely — the session-start warning only reads the review date), proposes
  hazards this run's analysis found, and re-asks about rows older than ~90 days. It asks everything
  in one message, proposes changes through the same accept/reject gate as the rest of Phase 3, and —
  as before — **only you can confirm a hazard**: it will never upgrade an `[UNVERIFIED]` row or
  re-date one you did not answer.
- **`FRAMEWORK-CONTEXT.md` and `README.md` no longer claim `/docs-sync` refreshes Known Hazard
  Areas.** It never did. "Detected Framework Packages" genuinely is refreshed by `/docs-sync`, which
  is why the sentence read plausibly for so long; the hazard half of it was simply wrong. Hazard
  areas are now attributed to `/rebootstrap`, which actually does the work.
- **The Copilot `/docs-sync` prompt described four of the six checks.** It omitted the
  `FRAMEWORK-CONTEXT.md` drift check and the `AGENTS.md` / routing-rails half of the derived-files
  check, so Copilot ran a narrower documentation sync than Claude Code did from the same command.
  Corrected.
- **`docs/warehouse-map.md` is now treated as a snapshot, not a live view.** `add-warehouse-load`
  read that map as the authoritative source for the load pattern to copy, and nothing kept the map
  current — so a warehouse that had moved on could push a stale pattern into new ETL code. The skill
  now tells you to confirm the entities and load procs the map names still exist in the SQL tree
  before copying from it, and that the code wins where the two disagree. `/docs-sync` additionally
  flags the map as stale when the SQL tree has changed since it was written, and points you at
  `map-warehouse` to refresh it.

## 0.41.0 — 2026-08-01

- **Your test suite could report green while a test failed — fixed.** If you run
  `tests/hooks/Invoke-HookTests.ps1` under **Windows PowerShell 5.1** (the fallback used on machines
  without PowerShell 7), a test file containing exactly *one* failing test printed `[FAIL]` but
  still exited 0, so CI scored the run as a pass. Two or more failures in the same file were
  reported correctly, which is why this only ever hid a single fresh regression. If you gate a
  pipeline on this suite, re-run it after updating — it may surface a failure that was previously
  invisible.
- **`scripts/metrics.sh` now reports the same counters as `scripts/metrics.ps1`.** The bash version
  was missing `tests_skipped`, `tautological_assert`, `tests_skipped_focused` and
  `tautological_expect`, so the JSON it emitted had a different key set from the PowerShell version.
  Anything consuming that JSON now sees all four keys regardless of which twin produced it.
- **`scripts/docs-sync-check` prints identical wording from either twin.** The PowerShell and bash
  versions had drifted apart in six advisory messages, so the same repo produced different output
  depending on which one your CI happened to run.
- **New `tests/hooks/ScriptTwinParity.Tests.ps1`.** Runs both the `.ps1` and `.sh` version of
  `template-checks`, `docs-sync-check`, `sync-agent-files` and `metrics` against one fixture and
  fails if they disagree. `framework-doctor`'s checks that only run on a fully set-up repo are now
  compared too. This is what caught the three problems above; it protects you from a Windows
  developer and a Linux CI agent silently getting different answers from the same repo.

## 0.40.0 — 2026-07-31

Angular-side changes only; the .NET rails are unchanged this release.

- **`/bootstrap` and `/adopt` now capture your Angular forms conventions.** Until this release
  neither command had any notion of forms, so the `Conventions` section they write for your repo
  said nothing about them — and an agent working on a form had nothing repo-specific to follow. Both
  commands now author a `Forms` subsection on the Angular side, and `/bootstrap`'s component-design
  analysis pass looks for what belongs in it: whether you use reactive or template-driven forms,
  where your validators live, and whether any of your components are custom form controls and how
  they plug into the forms API.
- **A correction to the component guidance.** `.github/copilot-instructions.md` and
  `docs/defaults.md` both stated that presentational components take data via `@Input` and emit via
  `@Output` — stated flatly enough to read as covering *every* component. It does not cover a
  component that is itself a form control: to be usable with `formControlName` a component has to
  participate in the forms API, either by providing `NG_VALUE_ACCESSOR` or by injecting `NgControl`
  and assigning its `valueAccessor`. Both files now carry that exception.
- **`docs/defaults.md` gains a `Forms` section** under the Angular defaults. It is deliberately a set
  of detection notes rather than a prescribed default: it tells the analysis what to look for in
  *your* codebase, in the same style as the existing SSR / Hydration section. Your own conventions,
  once bootstrapped, remain the authority.
- **Nothing to do.** Re-running `/bootstrap` or `/adopt` will pick up forms conventions on the next
  pass; an existing `CLAUDE.md` is not rewritten by installing this version.

## 0.39.0 — 2026-07-31

- **`framework-doctor` can now confirm that Claude Code hooks have really run at your monorepo
  root, not just that they appear to be configured.** The unconditional session-start hook records
  its latest run, providing observed evidence that the shared hook wiring is alive. It does not
  guarantee that enforcement succeeds after startup; an individual hook can still fail at runtime.

  Run `pwsh scripts/framework-doctor.ps1` or `bash scripts/framework-doctor.sh` from the monorepo
  root. If `Hook liveness` is `CANT-VERIFY` after you have used Claude Code there, your hooks are not
  firing. Check the wired interpreter first, followed by `docs/enforcement-surfaces.md`. The affected
  wiring carries the shared write guard and audit trail as well as .NET build feedback and Angular
  TypeScript feedback.

  **No action required.** The record appears automatically on your next session. The new row changes
  neither the doctor's exit code nor CI behaviour.

## 0.38.1 — 2026-07-31

- **Claude Code hook configuration is portable across the team again.** A 0.38.0 install may have
  written the installing developer's absolute PowerShell path into the committed
  `.claude/settings.json`. Teammates on another OS or user profile cannot use that path and get no
  hooks, silently, across both the .NET and Angular sides of the workspace.

  **Action required for 0.38.0 installs:** re-run the installer at the monorepo root, or hand-edit
  every hook command back to its bare interpreter name (`pwsh`, `powershell`, or `bash`), then commit
  the resulting `.claude/settings.json`. Run `pwsh scripts/framework-doctor.ps1` or
  `bash scripts/framework-doctor.sh` per developer machine to check the shared write guard, stack
  feedback, routing context, and audit wiring.

## 0.38.0 — 2026-07-31

- **Claude Code hooks on Windows now use an absolute PowerShell path across the workspace.** A bare
  `pwsh` registration can fail with command-not-found in the Git Bash shell Claude Code uses for
  hooks, even when PowerShell is available from another shell. The failure emits nothing, so the
  shared write guard and audit trail, .NET build feedback, Angular type-check feedback, Boy Scout
  check, and routing context can all appear quiet while never running. `framework-doctor` now
  reports a bare interpreter name as `CANT-VERIFY` rather than `OK`.

  **Action required: re-run the installer** at the monorepo root so every hook registration receives
  an absolute interpreter path. If hooks on either the .NET or Angular side have seemed to do
  nothing, this may be why; run `pwsh scripts/framework-doctor.ps1` or
  `bash scripts/framework-doctor.sh` after reinstalling to confirm the pinned interpreter is
  available.

## 0.37.0 — 2026-07-31

- **(.NET) The write guard now catches skipped tests in NUnit and MSTest, not just xUnit.** It already
  blocked `[Fact(Skip="…")]` at write time; it now also blocks `[Ignore]` and `[Ignore("reason")]`,
  including NUnit's per-case `[TestCase(…, Ignore = "…")]`. If your .NET side uses NUnit or MSTest you
  were previously getting a weaker floor than an xUnit repo — an agent could silently skip a test and
  the guard would not object. Both the PowerShell and bash versions of the hook were updated together.

  **`[Explicit]` is deliberately still allowed.** It is a legitimate NUnit marker for opt-in
  long-running or manual tests, and blocking it would make the framework stricter on NUnit than on
  xUnit. If you use it to park a broken test, the no-skipping convention still applies — the guard
  just will not stop you.

  The check looks at attribute lines only, so ordinary code like `public enum Mode { None, Ignore, All }`
  and `[JsonIgnore]` are unaffected. Known limitation: an attribute list split across several lines is
  not detected — the same limitation the xUnit check has always had. Angular's spec checks
  (`fit`/`fdescribe`/`xit`/`.only`/`.skip`) are unchanged.

  **No action required.**

## 0.36.0 — 2026-07-31

- **(.NET) The framework no longer assumes your tests are xUnit.** If your .NET side already has a
  test suite — NUnit, MSTest, or xUnit — the agent is now required to detect it and mirror it: the
  runner, the mocking library, the assertion library, the naming convention, and your existing base
  fixtures. Introducing a second test framework alongside the one you already use is now explicitly
  forbidden; if the agent thinks your framework is the wrong choice it must raise that in
  `TECH_DEBT.md` for a human decision rather than migrating you as a side effect of "add some tests".

  Previously several files stated xUnit + NSubstitute as fact — including
  `.github/copilot-instructions.md`, which Copilot reads on every inline completion. On a non-xUnit
  repo that was simply wrong, and most visible before `/bootstrap` had populated
  `CLAUDE.md > Conventions`. xUnit + NSubstitute now appears only as the greenfield default, for when
  there is no .NET test project anywhere in the solution, and the
  `MethodName_Scenario_ExpectedResult` naming rule moved with it.

  **No action required.** If you have already run `/bootstrap`, your `Conventions > Testing` section
  was already authoritative. Run `/generate-copilot` if you want the Copilot digest regenerated.

- **`add-tests` now starts with an evidence gate on both stacks.** On .NET it reads test-project
  package references and greps a sibling test class before writing anything, and only proposes a
  framework after confirming the whole solution is test-free. On Angular it establishes the runner
  (Karma/Jasmine, Jest, or Vitest) from your workspace config and existing specs. The .NET branch had
  been hardcoding while the Angular branch already derived — they now behave the same way.

- **(.NET) `enforce-standards` covers all three test frameworks.** It previously offered only the
  xUnit skipped-test analyzer, so an NUnit or MSTest repo silently got no build-time protection
  against skipped tests. It now applies the analyzer matching your framework — `xUnit1004` for xUnit,
  `MSTEST0015` for MSTest (it ships in MSTest.Analyzers 3.3+ at severity Info and is opt-in from 3.8,
  so the `.editorconfig` entry is required). NUnit has no equivalent analyzer, so the skill wires a
  build-failing CI check over your test root instead.

- **(.NET) `scripts/ci/ArchitectureTests.sample.cs` now tells you how to translate it.** The sample is
  xUnit and gets copied into your test project by `enforce-architecture`; on an NUnit or MSTest repo
  it would not compile. It now carries the attribute and `using` swap for both.

## 0.35.0 — 2026-07-30

- In GitHub Copilot, the Boy Scout nudge now runs when a turn ends instead of at the start of every
  prompt. It no longer interrupts read-only questions or reports work before it is done; findings
  are handed to the next prompt so the model still sees them. The new timing requires Copilot CLI
  v1.0.72 or newer; older versions simply keep the previous behaviour. VS Code agent mode depends
  on Preview agent hooks and remains unverified. No action is required.

- `framework-doctor` no longer reports the write guard as inactive on Windows when `jq` is
  installed in a way Windows PATH lookup cannot see. It now checks the way the guard itself would.

## 0.34.3 — 2026-07-21

- `CLAUDE.md`/`AGENTS.md` — Leanness rule #7 ("no comments that restate code") now carries a short
  Bad/Good example so the rule reads as concrete guidance rather than an abstract imperative. No
  action needed.

## 0.34.2 — 2026-07-20

- `/bootstrap` now flags data-warehouse repos in its final report. When it detects warehouse signals
  (staging / dimension / fact layers) on the .NET/SQL side and keeps the warehouse skills, it points
  you at `/map-warehouse` to produce a full layer / grain / load-ordering / idempotency map before
  your first warehouse change, and names `add-warehouse-load` as the recipe for when you actually add
  or change a load. Repos with no warehouse signals see no change. No runtime behaviour changes.

## 0.34.1 — 2026-07-20

- The technical presentation now teaches the framework through a concrete CSV-export feature from
  installation to merge. It shows the real event payloads, files, hook decisions, build/audit
  output, verification loop, review questions, failure paths, and responsibilities for developers,
  reviewers, tech leads, platform owners, and product/security partners.
- The one-page system map is now a functional twelve-stage event trace and machine-operation guide
  rather than an abstract architecture summary. Runtime behaviour is unchanged.

## 0.34.0 — 2026-07-20

- `docs/presentation/framework-technical.html` adds an offline technical architecture deck covering
  request routing, workflow contracts, engineering standards, enforcement strength, tool-surface
  differences, project memory, framework composition, adoption, and inspectable evidence.
- `docs/presentation/framework-system-map.html` provides the same operating model as a printable
  one-page reference. No runtime behaviour or adoption action changes in this release.

## 0.33.0 — 2026-07-17

- Copilot CLI receives Boy Scout candidates at the next prompt, with the same dedup behavior as
  Claude Code. Hook scans now work from subdirectories and Git worktrees.
- The write guard blocks fine-grained and all classic GitHub PAT forms. Passwordless connection
  strings no longer false-positive; keyed passwords and URI userinfo credentials still block.
- `docs-sync-check` fails when the enforcement matrix is missing and advises when the optional CI
  guide is absent. A Bamboo Specs example provides an explicitly non-blocking starting point.

## 0.32.2 — 2026-07-17

### Fixed — hook test suite on Linux

- The framework-doctor "no JSON parser" test now builds its restricted-PATH sandbox portably, so
  the shipped hook test suite passes on Linux machines as well as Windows.

## 0.32.1 — 2026-07-17

### Fixed — framework doctor on minimal PATH

- `scripts/framework-doctor.sh` now locates the repository root using shell builtins only, so it
  still produces a full report on machines with a broken or minimal PATH — exactly the machines
  it exists to diagnose.

## 0.32.0 — 2026-07-17

### Added — developer-machine framework doctor

- Run `pwsh scripts/framework-doctor.ps1` or `bash scripts/framework-doctor.sh` to see which
  enforcement prerequisites are live on your machine, what is missing, and the exact canaries
  needed for agent settings that a script cannot observe. The doctor diagnoses only and is not a
  CI gate; `docs-sync-check` remains the required build check.

## 0.31.0 — 2026-07-17

### Added — SQL data-warehouse guidance (.NET side)

- Two new skills recognize and govern warehouse repos. `map-warehouse` maps the warehouse —
  layers (staging → warehouse → marts), fact/dimension entities and their grain, load
  orchestration and ordering, batch/watermark control, slowly-changing-dimension strategy,
  partitioning — and can write the result to `docs/warehouse-map.md`. `add-warehouse-load`
  adds or extends a fact/dimension load following your existing patterns, with idempotent,
  re-runnable loads that never load the same data twice.
- `/bootstrap` and `docs/defaults.md` now detect SQL-project / stored-procedure repos and
  data-warehouse repos, with matching conventions for each. Nothing applies unless your repo
  shows the signals — guidance is derived from what your codebase actually contains.

## 0.30.1 — 2026-07-16

### Fixed — hook message rendering parity

- Hook messages now render identically whether your team runs PowerShell or bash hooks — no
  functional change.

## 0.30.0 — 2026-07-16

### Changed — testing strategy for repos with no suite

- The framework now covers repos with no test suite on either stack: `add-tests` gains a
  suite-bootstrap mode; `/bootstrap` reports suite absence and states each stack's target test
  shape.

### Changed — faster hook test suite

- The hook test suite that ships with this distribution now runs its isolated test files in
  parallel, with no change to its test coverage, output, or failure behavior.

## 0.29.1 — 2026-07-16

### Fixed — data-access guidance now follows your codebase

- The framework no longer assumes EF Core; data-access guidance is derived from your codebase.

## 0.29.0 — 2026-07-16

### Added — `/adopt` can now run unattended (headless), preparing a PR for you to review

- **You can finish adoption without opening a session and typing `/adopt` by hand.** An installing
  agent — or an operator running `claude -p` / `copilot -p` with no developer at the keyboard — can
  run adoption **headless** by passing a `--headless` directive. Headless adoption does the
  mechanical, reversible work for you: it creates an `adopt-ai-framework` branch, archives your
  existing AI files, runs the provenance + safety screen, captures the impact baseline, and
  **stages** every proposed change to `CLAUDE.md` and `TECH_DEBT.md` as a clearly-marked, attributed
  proposal on that branch.
- **A human still applies the merges — the trust boundary is unchanged.** Headless adoption never
  merges discovered content into your canonical `CLAUDE.md` / `TECH_DEBT.md` on its own, and never
  opens or merges the PR. It hands you a PR-ready branch: you review the proposed changes (and
  anything it quarantined as suspicious) and apply them at PR review. Files that trip the safety
  screen are excluded entirely and listed at the top of the report — they are never auto-approved.
- **Nothing changes for the normal interactive flow.** Run `/adopt` in a session as before and you
  still get the show-each-merge gates. The installer's next-step message and the adoption marker now
  mention the headless option alongside the developer path.

No action required — this is additive.

## 0.28.0 — 2026-07-16

### Added — judgment calls no longer get lost between bootstrap/adopt and review

- **`/bootstrap` and `/adopt` now end with a "Paste this into your PR (or commit message)"
  checklist** — a short, prioritized list of the specific decisions the run made for you, each a
  plain yes/no question with a file pointer (e.g. "The code gave mixed signals on error handling;
  I wrote X. Is that the team's intent?"). Paste it into your PR description so reviewers see
  exactly what needs a human answer. If the run resolved everything against your code, it says so
  in one line. `/adopt` also records any convention contradiction it resolved by default, so that
  choice shows up in the checklist instead of disappearing.
- **Session start now flags stale hazard areas.** When `FRAMEWORK-CONTEXT.md > Known Hazard Areas`
  has an entry whose `Reviewed` date is more than 90 days old, a new session reminds you to
  confirm it (or mark it "not a hazard"). Settled non-hazards and not-yet-drafted tables are left
  alone.
- **The Known Hazard Areas table is easier to read at review time.** It now shows a plain-English
  legend (Verified = a person confirmed it; Suspected = a person thinks so; Unverified = only the
  tooling flagged it) and states that **merging the PR does not confirm these** — an item is
  confirmed only when a person answers its question and updates its status. Hazard `Reviewed`
  dates are written as `YYYY-MM-DD`.

No action required. These are additive: existing `FRAMEWORK-CONTEXT.md` files keep working, and
the new session-start reminder only appears once a hazard entry is over 90 days old.

## 0.27.1 — 2026-07-16

### Fixed — team wiki checks
- `wiki-check` no longer requires GNU `date`: on macOS build agents, valid `last-verified`
  dates were previously rejected as invalid, failing `docs-sync-check` as soon as your team
  had a single wiki entry. Date validity is now checked the same way on every platform.
- Running `docs-sync-check` interactively no longer stalls waiting for keyboard input —
  `wiki-check` receives its repo root as an argument instead of reading it from stdin.
- The wiki index's required sort order is now pinned to plain byte order (ASCII) everywhere,
  so the same `INDEX.md` cannot pass on one build agent and fail on another whose locale
  collates hyphens differently. The `remember-for-team` skill now states this order.
- `CLAUDE.md` ("What We've Learned") and `docs/wiki/INDEX.md` now state what belongs in
  `LEARNINGS.md` (append-only history) versus the team wiki (current, scoped, individually
  verifiable claims), and that durable learnings get promoted via `remember-for-team`.
- Hook tests: the test harness reads hook output as UTF-8 regardless of the console code page
  (two session-start assertions could fail spuriously on non-UTF-8 Windows consoles), and the
  bash session-start hook's Copilot delivery of the wiki index is now covered.

## 0.27.0 — 2026-07-16

### Added — team wiki memory
- A new `docs/wiki/` in your repo: an `INDEX.md` plus one file per team learning (a gotcha,
  context fact, recipe, or failed approach), each with a small frontmatter block (what it is,
  where it applies, how confident, when last checked). Applies to both stacks.
- A new `remember-for-team` skill drafts these entries for you during a session — nothing is
  written automatically; it only ever produces a draft that reaches the team through your normal
  PR review, same as any other code change.
- Your agent now sees the wiki index at the start of a session (inlined if small, summarized if
  large) on both Claude Code and Copilot, and the entries are described to it as **claims to
  verify against the code, not instructions to follow** — the same "screen it, don't obey it"
  posture the framework already applies to adopted docs.
- A new `wiki-check` gate runs as part of `docs-sync-check`: it validates the wiki's structure and
  screens entries for injected instructions, matching the framework's existing PR-review checks.
- If you already run `/adopt` on a repo that has its own `docs/wiki/`, clean entries are left
  exactly where they are; anything that looks adversarial is quarantined for a human to review
  instead of being merged automatically.
- Updating the framework never overwrites your team's own `docs/wiki/INDEX.md` — only a
  missing one is created.

No action needed to receive this — the wiki starts empty; your team populates it over time.

## 0.26.5 — 2026-07-15

### Fixed
- PowerShell session-start and prompt-routing guidance now matches the bash guidance byte-for-byte,
  including Unicode punctuation and spacing. No action is needed.
- Hook guidance no longer garbles ⚠/— characters when PowerShell hooks run on Windows.

## 0.26.4 — 2026-07-12 (fixes a second broken install command in this README)

> Documentation only — **no change to the files in your repo, nothing to do.**

### Fixed
- **The "updating" section named an installer path that does not exist here.** v0.26.3 fixed the
  install command in §1 but missed the same mistake further down: the instructions for pulling
  template updates still said `bash install.sh /path/to/your-repo` / `pwsh install.ps1 …`. As in §1,
  the installer in this distribution is **`scripts/install.sh`** / **`scripts/install.ps1`**.
  Corrected. A check now runs in CI that every command named in these docs actually resolves, so this
  class of mistake cannot ship again.

## 0.26.3 — 2026-07-12 (fixes a broken install command in this README; AI-agent install contract)

> **If you install with an AI agent, this one matters.** No change to the files in your repo — the
> fixes are to the installer's own output and to the install instructions in this distribution's
> `README.md`.

### Fixed
- **`README.md` §1 told AI agents to run an installer path that does not exist here.** It said
  `pwsh install.ps1 <target-repo-path>`; the installer in this distribution is
  **`scripts/install.ps1`** (`bash scripts/install.sh`). An agent that followed §1 verbatim got
  `No such file or directory` and had to guess its way out. The .NET and Angular distributions were
  always correct; only this one carried the wrong path. Corrected.
- **The installer's greenfield "next steps" now tell an AI agent the whole contract.** When an agent
  installed into a repo with no existing AI tooling, the closing message told it not to run
  `/bootstrap` — but never stressed that it must first **commit** the copied files, never said not to
  hand-replicate `/bootstrap`, and never warned that `scripts/docs-sync-check` **fails by design**
  until a developer has run `/bootstrap`. Agents therefore left the copied files sitting uncommitted
  in the working tree, and some treated the expected check failure as a bug to fix. The greenfield
  message now matches the one already shown for repos with existing AI tooling: commit the files,
  hand off to a developer, don't replicate `/bootstrap` by hand, and expect `docs-sync-check` to be
  red until it has run.

## 0.26.2 — 2026-07-12 (housekeeping)

> No behavior change, nothing to do. Keeps this distribution's version in step with the .NET and
> Angular distributions, which had a mangled character repaired in a hook comment.

## 0.26.1 — 2026-07-12 (these release notes are now written for you)

> Documentation and comments only — **no behavior change, nothing to do**. Re-run the installer
> whenever convenient.

### Changed
- **These release notes are written for the teams who install the framework**, not for its
  maintainers: what changed in your repo, and what you need to do.
- **Internal tracking ids removed from the comments in shipped code** — the hooks
  (`.claude/hooks/post-write.*`), the scripts (`scripts/template-checks.*`,
  `scripts/build-architecture-html.ps1`), and the hook tests. Comments now state the rule the code
  enforces instead of the ticket that produced it, so they read as intended in *your* repo. Behavior
  is untouched; the hook test suites pass unchanged.
- **Stale cross-references removed** from `README.md` and this changelog — they pointed at two
  predecessor repositories that are now archived.

## 0.26.0 — 2026-07-12 (first release of the mixed .NET + Angular distribution)

> This is the first release of the monorepo distribution — for repos that hold **both** a .NET
> solution and an Angular workspace. It carries the union of both stacks' rails, and dispatches
> per file type: a `.cs` edit runs the .NET gate, a `.ts` edit runs the Angular one.
>
> **What you need to do:** if you have a mixed repo, the installer now auto-detects it and selects
> this distribution. Pass `--stack monorepo` to force it.

### Changed
- The framework's own CI workflows (`template-ci.yml`, `docs-sync-check.yml`) now pin
  `actions/checkout@v5`, following GitHub's Node 20 runtime deprecation. No change to your
  application code.

---

## 0.25.5 — 2026-07-06 (monorepo template debut)

> First release of the combined template for repos that carry **both** a .NET backend and an
> Angular frontend in one repository. It ships both stacks' rails — conventions, hooks, skills,
> subagents, and workflows — from a single source of truth, at parity with the two per-stack
> templates as of v0.25.5.

### Added
- **Monorepo template** installing both stacks' rails together: the .NET Common-Task skills
  (add-endpoint, add-entity, register-service, perf) alongside the Angular ones (add-component,
  add-service, add-lazy-route, add-signal-store), the shared skills (add-tests, dependency-audit,
  create-adr, enforce-architecture, enforce-standards), the seven subagents, and the seven
  workflow commands — one `CLAUDE.md` / `AGENTS.md` covering both stacks.
- **Both stacks' deterministic hooks** wired in one `.claude/settings.json`: the PreToolUse guard
  (blocks warning-suppressions & secrets in `.cs` and `.ts`), the PostToolUse `dotnet build`
  (`.cs`) and `tsc --noEmit` (`.ts`) checks, the SR 11-7 / DORA audit trail, and the Stop Boy
  Scout scanner with each stack's always-apply patterns.
- **Merged CI guardrail and Bitbucket Data Center guidance** covering both legs — .NET
  (`dotnet build -warnaserror` + `dotnet test`) and Angular (`eslint` + `ng build` + `ng test`) —
  in `docs/ci-integration.md`.
