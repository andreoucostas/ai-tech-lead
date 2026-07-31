# AI Tech Lead (.NET + Angular monorepo) — Changelog

> Release notes for the mixed .NET + Angular distribution, written for the teams who install it:
> what changed in **your** repo, and what (if anything) you need to do. This distribution carries
> the rails of both stacks, so entries may apply to one side or both.
> Architecture decisions you record live in `docs/architecture-decisions.md`.

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
