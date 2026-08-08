# AI Tech Lead (.NET) — Changelog

> Release notes for the .NET distribution, written for the teams who install it: what changed in
> **your** repo, and what (if anything) you need to do.
> Architecture decisions you record live in `docs/architecture-decisions.md`.

## 0.51.4 — Unreleased

- `framework-doctor` now reports capabilities only from the environment it actually observes.
  Registered Claude and Copilot Bash guards make the PowerShell doctor say that their runtime
  parser is unobservable; a Bash doctor reports only on its own environment. Portable hook-shell
  registrations no longer prompt machine-specific absolute paths, stack and Copilot command
  details identify the doctor-process boundary, and a new post-write canary verifies the actual
  agent-hosted build hook. Bash registrations may use shell-valid single quoting or any case of
  the `bash.exe` basename without hiding guard-parser demand.

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

- Warehouse writes now require a current map or equivalent live-schema inventory; pure SQL, SSDT,
  and dbt repositories can be detected and adopted without a solution file.
- Updates preserve local skill exemplars and discovered skills, while disabled framework skills
  remain inactive and receive refreshed content for a future restore.
- Endpoint, entity, and service recipes now search for an existing owner before scaffolding.

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
  it now says so rather than guessing. For example, if your repo has a warehouse map, a schema document, or an integration guide under `docs/`, your assistant will now open it before writing SQL or data-access code against what it describes.
- **This one was measured before it shipped.** On a test repository, the assistant previously opened
  the relevant document in **0 of 6** runs; with this rule it opened it in **6 of 6**.
- **You receive this on your next update** — it ships in `.github/instructions/`, which the installer
  refreshes. No action needed.

## 0.47.0 — 2026-08-06

- No changes to the .NET distribution this release. The skill-description clarifications added in
  v0.47.0 apply only to the Angular and mixed (monorepo) distributions; the .NET skills already
  carried the same `USE FOR` / `DO NOT USE FOR` clauses.

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
  was missing `tests_skipped` and `tautological_assert`, so the JSON it emitted had a different key
  set from the PowerShell version. Anything consuming that JSON now sees both keys regardless of
  which twin produced it.
- **`scripts/docs-sync-check` prints identical wording from either twin.** The PowerShell and bash
  versions had drifted apart in six advisory messages, so the same repo produced different output
  depending on which one your CI happened to run.
- **New `tests/hooks/ScriptTwinParity.Tests.ps1`.** Runs both the `.ps1` and `.sh` version of
  `template-checks`, `docs-sync-check`, `sync-agent-files` and `metrics` against one fixture and
  fails if they disagree. `framework-doctor`'s checks that only run on a fully set-up repo are now
  compared too. This is what caught the three problems above; it protects you from a Windows
  developer and a Linux CI agent silently getting different answers from the same repo.

## 0.40.0 — 2026-07-31

- No changes to the .NET distribution this release. The forms-conventions support added to
  `/bootstrap` and `/adopt` in v0.40.0 applies only to the Angular and mixed (monorepo)
  distributions.

## 0.39.0 — 2026-07-31

- **`framework-doctor` can now tell whether Claude Code hooks have actually run in your .NET
  repo, not only whether their configuration looks correct.** The session-start hook records its
  latest run, giving the doctor observed evidence that the hook wiring is alive. This does not prove
  that every enforcement hook completes successfully; a hook can start and still fail at runtime.

  Run `pwsh scripts/framework-doctor.ps1` or `bash scripts/framework-doctor.sh`. If `Hook liveness`
  reports `CANT-VERIFY` after you have used Claude Code in this repo, your hooks are not firing; check
  the wired interpreter first, then `docs/enforcement-surfaces.md`. That silence matters because the
  same wiring carries the write guard, .NET build feedback, and audit trail.

  **No action required.** Recording starts with your next session. The new `CANT-VERIFY` row does not
  change the doctor's exit code or any CI behaviour.

## 0.38.1 — 2026-07-31

- **Claude Code hook registrations are portable team configuration again.** If you installed 0.38.0
  and committed `.claude/settings.json`, it may contain the installing developer's machine-specific
  PowerShell path. That path will not exist for teammates using another OS or user profile, leaving
  your .NET repo with no write guard, build feedback, routing context, or audit trail.

  **Action required for 0.38.0 installs:** re-run the installer, or hand-edit each hook command back
  to the bare interpreter name (`pwsh`, `powershell`, or `bash` as appropriate), then commit the
  corrected `.claude/settings.json`. Run `pwsh scripts/framework-doctor.ps1` or
  `bash scripts/framework-doctor.sh` on each developer machine to check the wiring.

## 0.38.0 — 2026-07-31

- **Claude Code hooks on Windows now use an absolute PowerShell path.** A bare `pwsh` registration
  can fail with command-not-found in the Git Bash shell Claude Code uses for hooks, even when
  PowerShell is available from another shell. That failure produces no hook output, so the write
  guard, post-write .NET build feedback, Boy Scout check, routing context, and audit trail can all
  appear quiet while never running. `framework-doctor` now reports a bare interpreter name as
  `CANT-VERIFY` instead of claiming it is available.

  **Action required: re-run the installer** so your hook registrations receive an absolute
  interpreter path. If hooks in your .NET repo have seemed to do nothing, this may be why; run
  `pwsh scripts/framework-doctor.ps1` or `bash scripts/framework-doctor.sh` after reinstalling to
  confirm the pinned interpreter is available.

## 0.37.0 — 2026-07-31

- **The write guard now catches skipped tests in NUnit and MSTest, not just xUnit.** It already
  blocked `[Fact(Skip="…")]` at write time; it now also blocks `[Ignore]` and `[Ignore("reason")]`,
  including NUnit's per-case `[TestCase(…, Ignore = "…")]`. If your repo uses NUnit or MSTest you were
  previously getting a weaker floor than an xUnit repo — an agent could silently skip a test and the
  guard would not object. Both the PowerShell and bash versions of the hook were updated together, and
  the message is the same one you already see for xUnit skips.

  **`[Explicit]` is deliberately still allowed.** It is a legitimate NUnit marker for opt-in
  long-running or manual tests, and blocking it would make the framework stricter on NUnit than on
  xUnit. If you use `[Explicit]` to park a broken test, that is a skip in spirit and the no-skipping
  convention still applies — the guard just will not stop you.

  The check looks at attribute lines only, so ordinary code like `public enum Mode { None, Ignore, All }`
  and serialization attributes like `[JsonIgnore]` are unaffected. Known limitation: an attribute list
  split across several lines is not detected — the same limitation the xUnit check has always had.

  **No action required.**

## 0.36.0 — 2026-07-31

- **The framework no longer assumes your tests are xUnit.** If your repo already has a test suite —
  NUnit, MSTest, or xUnit — the agent is now required to detect it and mirror it: the runner, the
  mocking library, the assertion library, the naming convention, and your existing base fixtures.
  Introducing a second test framework alongside the one you already use is now explicitly forbidden;
  if the agent thinks your framework is the wrong choice, it must raise that in `TECH_DEBT.md` for a
  human decision instead of migrating you as a side effect of "add some tests".

  Previously several files stated xUnit + NSubstitute as fact — including
  `.github/copilot-instructions.md`, which Copilot reads on every inline completion. On a non-xUnit
  repo that was simply wrong, and most visible before `/bootstrap` had populated
  `CLAUDE.md > Conventions`. xUnit + NSubstitute now appears only as the greenfield default, for when
  there is no test suite anywhere in the solution. The `MethodName_Scenario_ExpectedResult` naming
  rule moved with it — if your suite names tests differently, the agent follows your convention.

  **No action required.** If you have already run `/bootstrap`, your `Conventions > Testing` section
  was already authoritative and stays so. If you want the Copilot digest regenerated from it, run
  `/generate-copilot`.

- **`add-tests` now starts with an evidence gate.** Before writing a test it reads your test projects'
  package references and greps a sibling test class, and it only proposes a framework after confirming
  the whole solution has no test project — not just the folder next to the code under test.

- **`enforce-standards` covers all three test frameworks.** It previously offered only the xUnit
  skipped-test analyzer, so an NUnit or MSTest repo silently got no build-time protection against
  skipped tests. It now applies the analyzer matching your framework — `xUnit1004` for xUnit,
  `MSTEST0015` for MSTest (note: it ships in MSTest.Analyzers 3.3+ at severity Info and is opt-in from
  3.8, so the `.editorconfig` entry is required). NUnit has no equivalent analyzer, so the skill wires
  a build-failing CI check over your test root instead.

- **`scripts/ci/ArchitectureTests.sample.cs` now tells you how to translate it.** The sample is xUnit
  and gets copied into your test project by `enforce-architecture`; on an NUnit or MSTest repo it would
  not compile. It now carries the attribute and `using` swap for both.

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
  Bad/Good example (`// loop over orders` above a `foreach` vs. `// vendor API caps batches at 50`
  above a chunk-size constant), so the rule reads as concrete guidance rather than an abstract
  imperative. No action needed.

## 0.34.2 — 2026-07-20

- `/bootstrap` now flags data-warehouse repos in its final report. When it detects warehouse signals
  (staging / dimension / fact layers) and keeps the warehouse skills, it points you at
  `/map-warehouse` to produce a full layer / grain / load-ordering / idempotency map before your
  first warehouse change, and names `add-warehouse-load` as the recipe for when you actually add or
  change a load. Repos with no warehouse signals see no change. No runtime behaviour changes.

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

### Added — SQL data-warehouse guidance

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

- The framework now covers repos with no test suite: `add-tests` gains a suite-bootstrap mode;
  `/bootstrap` reports suite absence and states your target test shape.

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
  where it applies, how confident, when last checked).
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

## 0.26.4 — 2026-07-12 (no changes to this distribution)

> Version stamp only. This release fixed a documentation defect in the mixed .NET + Angular
> distribution and added CI checks that verify every command named in the docs actually resolves and
> that the installer states the full handoff contract. Nothing in this distribution changed —
> **nothing to do.**
## 0.26.3 — 2026-07-12 (the installer now gives AI agents the full handoff contract)

> Installer output only — **no change to the files in your repo, nothing to do.** This matters only
> if you have an AI agent perform the install for you.

### Fixed
- **The installer's greenfield "next steps" now tell an AI agent the whole contract.** When an agent
  installed into a repo with no existing AI tooling, the closing message told it not to run
  `/bootstrap` — but never stressed that it must first **commit** the copied files, never said not to
  hand-replicate `/bootstrap`, and never warned that `scripts/docs-sync-check` **fails by design**
  until a developer has run `/bootstrap`. Agents therefore left the copied files sitting uncommitted
  in the working tree, and some treated the expected check failure as a bug to fix. The greenfield
  message now matches the one already shown for repos with existing AI tooling: commit the files,
  hand off to a developer, don't replicate `/bootstrap` by hand, and expect `docs-sync-check` to be
  red until it has run.

## 0.26.2 — 2026-07-12 (fixes a mangled character in a hook comment)

> Comment text only — **no behavior change, nothing to do.**

### Fixed
- **A mangled character in the header comment of `.claude/hooks/post-write.sh`.** A stray byte
  introduced while editing that comment in v0.26.1 left an invalid character that rendered as `�`.
  The hook itself always behaved correctly — only the comment was affected. Text restored.

## 0.26.1 — 2026-07-12 (these release notes are now written for you)

> Documentation and comments only — **no behavior change, nothing to do**. Re-run the installer
> whenever convenient.

### Changed
- **These release notes were rewritten for the teams who install the framework.** Previous versions
  of this file were the framework maintainers' own engineering log: internal tracking ids, a
  codename, references to two predecessor repositories and to tooling that does not exist in your
  repo. Every version entry is still here — the framing is now "what changed in your repo, and what
  you need to do."
- **Internal tracking ids removed from the comments in shipped code** — the hooks
  (`.claude/hooks/post-write.*`), the scripts (`scripts/template-checks.*`,
  `scripts/build-architecture-html.ps1`), and the hook tests. Comments now state the rule the code
  enforces instead of the ticket that produced it, so they read as intended in *your* repo. Behavior
  is untouched; the hook test suites pass unchanged.
- **Stale cross-references removed** from `README.md`. Advice about running a second stack now points
  at the mixed .NET + Angular distribution rather than at repositories that are archived.

## 0.26.0 — 2026-07-12 (the framework now ships from a single repo)

> The .NET and Angular distributions are now built from one source, so both stay in step by
> construction. Moving to this version is an **update, not a behavior change** — the .NET
> distribution is unchanged apart from the CI note below.
>
> **What you need to do:** nothing. Re-run the installer to update; it reads your existing
> `.claude/framework-version.json` and refreshes the framework machinery without touching content
> you own (`CLAUDE.md`, `TECH_DEBT.md`, and the rest).

### Changed
- The framework's own CI workflows (`template-ci.yml`, `docs-sync-check.yml`) now pin
  `actions/checkout@v5`, following GitHub's Node 20 runtime deprecation. No change to your
  application code.

---

## 0.25.5 — 2026-07-06 (version alignment — no .NET behavior change)

> A hook-registration gap was fixed in the Angular distribution. Nothing changed for .NET; this
> release only keeps both distributions on the same version number.

---

## 0.25.4 — 2026-07-05 (small-items sweep: generator twin parity, broader build triggers, doc honesty)

> The architecture-diagram generator now produces identical output on Windows and Linux,
> `post-write` catches broken project files (not just `.cs` sources), and three documentation
> claims were corrected.

### Fixed
- **`scripts/build-architecture-html.ps1` and its `.sh` counterpart produced different output**,
  so `architecture.html` showed spurious diffs depending on which machine regenerated it last:
  differing line endings, a BOM under PowerShell 5.1, a stray `<script>` tag joined onto the first
  line, and the generating script's own filename stamped into the file. Both now emit
  byte-identical output, and a test locks that parity so it cannot drift again.
- **`docs/ARCHITECTURE.md` §5 agents table listed 6 of the 7 shipped agents** — `test-critic`
  was missing. Row added; `architecture.html` regenerated with the fixed generator.
- **`docs/enforcement-surfaces.md` still marked the audit trail "dotnet only"** — stale
  since v0.25.3 shipped the Angular port. Corrected to "both stacks since v0.25.3".

### Changed
- **`post-write` triggers on build-relevant files, not just `.cs`**: the filter now
  accepts `.cs|.csproj|.sln|.props|.targets|.razor|.cshtml` in both twins — everything
  `dotnet build` actually consumes — so a broken project/build-file edit surfaces a build
  failure instead of silence. Throttle and surface routing unchanged; extensions the build
  cannot validate stay excluded by design (a triggered build can't catch their breakage).
- **README "Framework versioning" points at the installer's update mode** instead of promising
  a future `/framework-update` command: `install.sh/.ps1` already detect an existing
  `.claude/framework-version.json` and refresh framework machinery without touching
  consumer-owned content.
- **Boy Scout stop-nudge dedup semantics documented** in `docs/enforcement-surfaces.md`:
  the sorted finding set is hashed per machine; an unchanged set is silenced on later fires
  (silence = already flagged, **not** resolved), and any change re-surfaces the full set.

### Added
- **README hook-prerequisite note**: the shell wired in the committed
  `.claude/settings.json` (pwsh as shipped) must exist on **every** developer machine — a
  machine without it gets no Claude Code hooks, silently. The installers' per-box fallbacks
  (bash twins via `install.sh`, Windows PowerShell 5.1 via `install.ps1`) are documented
  alongside, with the caveat that whichever variant the team commits becomes the team-wide
  prerequisite.

---

## 0.25.3 — 2026-07-05 (the audit-trail hook now ships for Angular too)

> The `audit-trail` hook, previously .NET-only, was ported to the Angular distribution.
> No .NET behavior change — .NET already had it.

---

## 0.25.2 — 2026-07-04 (a `post-write` routing bug, and two checks that passed when they shouldn't)

> Fixes a PowerShell-only bug that sent build failures where nobody would see them, and closes two
> gaps where a check reported green while the drift it existed to catch slipped through.

### Fixed
- **`post-write.ps1` misrouted build failures to the wrong surface on malformed/empty payloads.**
  `$tn` (tool name) was assigned only inside the JSON-parse `try`, so a malformed payload with the
  `CLAUDE_FILE_PATH` env fallback left it `$null`; `$null -eq ''` is `$false` in PowerShell, so the
  Claude empty-case exit-2 branch was skipped and a failed build was emitted to the Copilot
  (exit-0) branch instead — the model never saw it, diverging from the `.sh` twin's `case … "")`.
  Pre-declared `$tn = ''`. Added `tests/hooks/PostWriteRouting.Tests.ps1` (static guard + build-free
  twin agreement).

### Added (deterministic gates)
- **Skills-mirror gate** in `scripts/template-checks.ps1/.sh`: `.claude/skills` must match
  `.github/skills` (Copilot reads the `.github` copy), EOL-normalized. Editing one and forgetting
  the other previously shipped stale Copilot guidance with every check green.

### Changed
- **`post-write` timeout raised to 120s** in `.github/hooks/hooks.json`. The ceiling bounds a single
  build, and a value set too low kills a cold build part-way through.
- **The enforcement matrix** (`docs/enforcement-surfaces.md`) gained three capability rows — build /
  type-check feedback, the Boy Scout stop-nudge, and the audit trail — recording a live finding:
  Copilot does **not** consume `postToolUse` output, so `post-write`'s build feedback does not reach
  the Copilot model (the audit trail's file side-effect still happens). Claude Code is unaffected.

## 0.25.1 — 2026-07-04 (a hook that crashed on non-English Windows, and two overstated claims)

> Fixes a shipped hook that crashed on every write for developers in comma-decimal locales, and
> corrects two places where the docs claimed a control fires where it actually doesn't.

### Fixed
- **`post-write.ps1` crashed on every write under Windows PowerShell 5.1 in comma-decimal
  locales** (de-DE/el-GR/fr-FR). The throttle epoch used
  `[int][double]::Parse((Get-Date -UFormat %s))`; on 5.1 `-UFormat %s` returns a fractional
  local-time string and `[double]::Parse` is culture-sensitive, so the dot parsed as a group
  separator, overflowed `Int32`, and threw a terminating error `SilentlyContinue` does not
  swallow. Replaced with `[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()` — culture-free, integer,
  UTC — which also removes a UTC/local throttle-stamp skew against the `.sh` twin's `date +%s`.
  Added `tests/hooks/PostWrite.Tests.ps1` (host-independent regression, red before green).

### Changed (enforcement honesty)
- **Guard write hard-block scoped to editor/file-write tools.** `docs/enforcement-surfaces.md`
  now carries a caveat that `guard.*` only sees `Write`/`Edit` (Claude Code) and file-path/content
  (Copilot) tool calls — a write routed through a terminal/shell tool (`sed -i`, `echo >>`,
  heredoc, `Set-Content`) carries no such payload and is **not** intercepted. Softened the
  Verification-Rule-7 parenthetical in `CLAUDE.md`/`AGENTS.md` accordingly.
- **Copilot `additionalContext` consumption live-verified** (Copilot CLI 1.0.68, sentinel canary):
  `userPromptSubmitted` additionalContext **is** consumed (routing/plan-gate/security salience
  reaches the CLI model); `postToolUse` additionalContext is **not** consumed by the model, and
  repo hooks fire **only after the workspace folder is trusted**. Updated the
  `enforcement-surfaces.md` Status notes and corrected the now-falsified "consumes postToolUse
  feedback" comment in the `post-write` twins.

## 0.25.0 — 2026-07-02 (toolchain-first enforcement: `enforce-standards` skill + Copilot prompt injection)

> First slice of a review into how much of the framework holds without a human driving it. Two
> P0s: (1) the compiler/analyzer toolchain becomes the surface-independent standards floor —
> deterministic in the IDE, every local build, and CI, binding humans and every AI tool alike;
> (2) the `route-prompt` salience layer — believed Copilot-inert since 0.7.2 removed its
> registration — is ported to Copilot, whose hooks now consume `userPromptSubmitted`
> `additionalContext` (CLI ≥ v1.0.65 per its changelog; VS Code agent mode per the official
> agent-hooks docs).

### Added
- **`enforce-standards` skill** + `scripts/ci/Directory.Build.props.sample` — makes warnings,
  analyzer findings, and skipped tests (`xUnit1004` → error) build-breaking via
  `TreatWarningsAsErrors` + `AnalysisLevel` + `EnforceCodeStyleInBuild` and `.editorconfig`
  severities. Mirrors the `enforce-architecture` delivery pattern; referenced from Common Tasks,
  README, and `docs/ci-integration.md` leg 2. Brownfield ratchet guidance included.
- **Copilot prompt injection**: `.github/hooks/hooks.json` registers `userPromptSubmitted` →
  `route-prompt.*`. `route-prompt.*` and `session-start.*` now self-detect the surface — Claude
  Code events carry `hook_event_name` and keep plain stdout (behavior unchanged); everything
  else gets dual-shape JSON (`additionalContext` + `hookSpecificOutput` wrapper, mirroring
  `guard.*`). Older Copilot versions ignore the JSON — a harmless no-op. The `.sh` twins need
  `jq`/`python3` to JSON-encode (same posture as `guard.sh`); without either they fall back to
  plain stdout, the pre-port behavior.
- `tests/hooks/RoutePrompt.Tests.ps1` — 10 surface-shape cases: plain-vs-JSON dispatch, plan
  gate, security overlay, slash-command and answer-only no-ops, twin decision agreement.

### Changed
- **Stale enforcement claims fixed** (the class 0.23.0 purged): the hooks.json `_comment` no
  longer says Copilot discards `userPromptSubmitted` stdout; `docs/enforcement-surfaces.md`
  routing/plan-gate/security rows now show per-prompt injection on Copilot **where hooks are
  enabled**, with an explicit status note that the injection path is fixture-tested but not yet
  live-verified on a real Copilot install (the github.com hooks-reference still lags — verify
  with the canary prompt); CLAUDE.md/AGENTS.md §1 "on Copilot only this text reaches the model"
  is now conditional on hooks being off.

## 0.24.2 — 2026-07-02 (CI integration doc: the required build consumers are expected to wire)

> On Bitbucket Data Center — the primary consumer profile — the team's own CI is the framework's
> only enforcement point that constrains every actor (any agent, any IDE, any human, any
> `--no-verify`). The README stated that expectation as four bullets ("wire `docs-sync-check` in
> whichever way fits your DC setup") with no recipe, and never said that the framework-state check
> alone does not gate code standards.

### Added
- `docs/ci-integration.md` — the required-build recipe: leg 1 = `scripts/docs-sync-check.sh`/`.ps1`
  (framework state), leg 2 = `dotnet build -warnaserror` + `dotnet test` (code-standards gate);
  Bamboo and Jenkins reference configurations; blocking via Bitbucket DC's **required builds**
  merge check (repo/project admin only — no server plugins); pointers to native secret scanning
  (DC 8.12+) and Code Insights; an explicit "what CI still cannot gate" boundary.

### Changed
- README › "Running on Bitbucket Data Center": the guardrail section now states the required-build
  expectation explicitly and links `docs/ci-integration.md`. The pre-receive-hook suggestion moved
  out of the primary path — it needs DC *system* admin most consumer teams don't have; required
  builds don't.
- `scripts/ci/bitbucket-pipelines.example.yml` — DC note points at `docs/ci-integration.md`.

## 0.24.1 — 2026-07-02 (session-start: fix `grep -c` stderr error in the security preload)

> Found while measuring the framework's token footprint. `session-start.sh` counted open security
> findings with `grep -c … || echo 0` — but `grep -c` prints `0` even when it exits 1 on no match,
> so the fallback produced `"0\n0"` and an integer-comparison error on stderr in every session of
> a repo with zero open findings. Harmless to behavior (the note was just skipped) but noisy, and
> a silent twin divergence: `session-start.ps1` was unaffected. Caught red-first by a new
> twin-parity regression test.

### Fixed
- `.claude/hooks/session-start.sh` — open-findings count no longer double-emits `0`; stderr is
  clean in the no-open-findings case.

### Added
- `tests/hooks/TwinParity.Tests.ps1` — session-start security-preload regression cases: twins must
  agree on the security note (none / one open finding) and emit clean stderr, run from fixture CWDs.

## 0.24.0 — 2026-07-01 (deterministic self-enforcement: template CI + machine-checked framework invariants)

> 0.23.3 fixed the drift a forensic self-audit found; this release adds the machine gates that
> keep it fixed. Until now the template repo had **zero effective CI** — its only workflow ran
> `docs-sync-check`, which exits silently on `.template-repo`, so every invariant rested on the
> maintainer remembering a manual checklist. That is the exact failure mode this framework exists
> to prevent in consumer repos.

### Added
- `scripts/template-checks.ps1` / `.sh` — deterministic framework checks: version-stamp sync (CLAUDE.md header == framework-version.json == CHANGELOG head; pair-check in consumer repos, which carry no CHANGELOG), **verbatim CLAUDE.md ↔ AGENTS.md mirror diff** (the four portable-rule sections + Agentic Workflow §1 — the `/docs-sync` "hard drift finding" is now a machine check, not a model instruction), copilot-instructions.md present and ≤ 80 lines, UTF-8 BOM sweep, hook `.ps1`/`.sh` twin existence, and script syntax.
- `.github/workflows/template-ci.yml` — the first CI that actually gates this repo: windows + linux legs run the hook test suite (the linux leg drives every `.sh` twin via real bash) and the framework checks on every push/PR.

### Changed
- `scripts/docs-sync-check.ps1`/`.sh` no longer goes silent in the template repo: `.template-repo` now routes to `template-checks` instead of skipping everything (the silent skip is how the 0.23.x stamp/mirror drift shipped unnoticed). Consumer runs additionally invoke `template-checks` as check 6b — the same invariants hold after install.
- `docs-sync-check` and `template-checks` anchor to their own script location instead of the caller's cwd/git root — running them from outside the repo can no longer silently audit the wrong directory.

### Fixed
- `docs-sync-check.ps1` counted lines with `Measure-Object -Line`, which skips blank lines and diverges from the `.sh` twin's `wc -l` (checks 1b and 3 could pass on one surface and fail on the other near the limit); both twins now count identically.

## 0.23.3 — 2026-07-01 (self-application fixes: stamp sync, verbatim AGENTS.md mirror, guard.sh honesty)

> A forensic self-audit found the framework failing its own drift rules in ways no deterministic
> check covered. This release fixes the shipped artifacts; the next minor adds the machine checks
> that keep them fixed.

### Fixed
- `CLAUDE.md` header stamp had drifted two releases behind `.claude/framework-version.json` (0.23.0 vs 0.23.2) — the release recipe bumped the json but never the HTML comment. Both now read 0.23.3.
- `AGENTS.md > Agentic Workflow §1` was paraphrased, violating the `/generate-copilot` "copy §1 VERBATIM" mandate (§1 is Copilot's only routing surface). All portable-rule sections (Verification Rules, Leanness, SOLID, Boy Scout Rule, and §1) are now byte-identical to CLAUDE.md; steps 2–6 stay condensed by design under a `### Steps 2–6` heading.
- `AGENTS.md` claimed "seven workflows" while §1 defines six (the security pass is cross-cutting, not a workflow); the count claim is removed.
- `guard.sh` header claimed the secret patterns "FAIL CLOSED", but with neither `jq` nor `python3` on PATH the hook allowed everything silently. It still allows in that state (blocking would brick every write) but now prints a loud `write-guard INACTIVE` warning to stderr, and the header + `docs/enforcement-surfaces.md` state the parser dependency honestly. (`guard.ps1` is unaffected — PowerShell parses JSON natively.)
- CHANGELOG header pointed at `project_framework_architecture.md`, a maintainer-workspace file that never ships; now points at `docs/architecture-decisions.md`.

### Added
- `.github/copilot-instructions.md` — the slim inline-completion digest mandated by `/generate-copilot` Part A had never been generated. It now ships (pre-bootstrap content sourced from `docs/defaults.md`), so `AGENTS.md`'s Quick-reference link and consumer `docs-sync-check` check #3 no longer dangle.
- `docs/architecture-decisions.md` — seeded empty so the `CLAUDE.md > Architecture Decisions` link resolves before the first `create-adr` run.

## 0.23.2 — 2026-06-29 (hook test harness: cross-platform `Get-BashPath` fix)

> Follow-up to 0.23.1, caught by a `/code-review` pass. The harness's bash resolver (`Get-BashPath` in `tests/hooks/_HookHarness.ps1`) built its candidate list with `Join-Path $env:ProgramFiles …`, which **throws** when `$env:ProgramFiles` is null/empty — the case on every non-Windows `pwsh` host (and a Windows box lacking the x86 var). That crashed the suite on Linux/macOS CI *before* the `bash`-on-`PATH` fallback could run, exactly where the `.sh` twin tests matter most. Now the candidate list is built null-safe (a Git path is added only when its env var is set), then falls back to `bash` on `PATH`.

### Fixed
- `tests/hooks/_HookHarness.ps1` — `Get-BashPath` no longer throws on hosts without `%ProgramFiles%`; it resolves `bash` from `PATH` on Unix so the `.sh` twin-parity tests run there instead of erroring.

## 0.23.1 — 2026-06-29 (hook test harness: automated, twin-parity-checked tests for the framework's own hooks)

> The framework's own hooks and scripts had **zero automated tests** — only manual recipes — and that gap had already shipped a real defect: in 0.23.0 the bash `guard.sh` was found missing the test-defeat blocks its `guard.ps1` twin enforced (a silent twin-drift the manual process didn't catch). This release adds a **dependency-free PowerShell test harness** (no Pester, so it runs air-gapped and under Windows PowerShell 5.1) that pipes JSON events to each hook and asserts exit code + per-surface output (Claude `exit 2`+stderr vs Copilot `permissionDecision` JSON), plus **behavioural twin-parity** tests that run the `.ps1` and `.sh` on the same input and assert the same decision — the check that would have caught the `guard.sh` regression.

### Added
- **`tests/hooks/` hook test harness** — `_HookHarness.ps1` (dependency-free runner: pipes an event to a hook, captures exit/stdout/stderr, normalises to a BLOCK/DENY/ALLOW decision; drives `.sh` twins via Git's `bin\bash.exe` for full-PATH fidelity; falls back to `powershell.exe` when `pwsh` is absent; `.sh` tests self-skip when no bash is present), `Guard.Tests.ps1` (surface matrix over every block pattern + clean inputs, incl. the RxJS `skip()` and `*Tests*`-file false-positive allowances), `TwinParity.Tests.ps1` (deep `guard` `.ps1`↔`.sh` decision parity on both surfaces + empty/malformed-stdin robustness parity for every twin pair), a shared fixture library (`fixtures/guard-cases.ps1`), and `Invoke-HookTests.ps1` (suite runner; exit code = failing-test count).

### CI
- Run as a **dedicated step**: `pwsh -NoProfile -File tests/hooks/Invoke-HookTests.ps1` (fail the build on non-zero exit). Intentionally **not** wired into `docs-sync-check` (which early-exits on `.template-repo` and is a framework-state guardrail, not a test runner).

## 0.23.0 — 2026-06-25 (workflow disciplines made reachable on Copilot; deterministic write-floor extended to VS Code; false enforcement claims removed)

> The framework's value is gated behind workflow commands the target developers won't type, and on the primary surface (GitHub Copilot in VS Code against a local Bitbucket Data Center) the picture was worse than assumed: routing/plan-gate/security context **cannot** be injected there (Copilot discards `sessionStart`/`userPromptSubmitted` stdout; VS Code agent-hooks are Preview-only), and the one Copilot write-block we shipped used a JSON shape (`{decision,reason}`) that **no longer matches the current Copilot spec** — i.e. the v0.22.0 Copilot guard had silently become a no-op. This release (a) inlines every workflow's non-negotiables into the always-on `CLAUDE.md`/`AGENTS.md` §1 so classification leads to discipline on Copilot without a slash command, (b) fixes the guard deny shape and extends the deterministic write-floor to VS Code agent mode, and (c) stops the framework claiming enforcement on surfaces where it doesn't fire. Researched against the Claude Code, Copilot CLI, and VS Code agent-hooks references (June 2026).

> **Migration note:** *when* discipline fires has changed. The `route-prompt` per-prompt rails now point at `CLAUDE.md §1` as the canonical source (they remain a just-in-time salience copy, not an independent fork), and a question-shaped prompt with no imperative verb is now treated as answer-only (no workflow ceremony). If you relied on the old keyword-listed session-start primer "routing on Copilot," note that it never did — see `docs/enforcement-surfaces.md`.

### Fixed
- **`guard.ps1`/`.sh` Copilot deny shape was a no-op.** It emitted `{"decision":"deny","reason":…}`; current Copilot honours `{"permissionDecision":"deny","permissionDecisionReason":…}`. Now emits a **superset** (top-level *and* `hookSpecificOutput`-nested `permissionDecision`) so a single output blocks on **both Copilot CLI and VS Code agent mode**. The Claude Code `exit 2` path is unchanged.
- **The guard no-opped on VS Code entirely** — its tool-name switch only matched Claude/CLI names, never VS Code's camelCase tools. It now gates on *"the payload carries a file path + content"* (surface-agnostic), so secret-writes and test-defeats are blocked under VS Code agent mode too (when Preview agent-hooks are enabled).

### Added
- **`CLAUDE.md`/`AGENTS.md` §1 now carries each workflow's non-negotiables inline** (fix → root-cause-then-regression-test-first; refactor → green-before-touch + net LOC delta; test → red-before-green, no over-mocking; etc.). Previously these lived only in `commands/*.md`, which Copilot never auto-loads — so a Copilot dev who never typed `/fix` got "follow the fix workflow" with no reachable definition. §1 is now the **canonical routing definition** and the load-bearing surface on Copilot.
- **`docs/enforcement-surfaces.md`** — the honest guaranteed-vs-instructed matrix per surface (Claude Code / Copilot CLI / Copilot VS Code). Linked from §1 and `hooks.json`.
- **Answer-only carve-out** in `route-prompt` + §1: a question-shaped prompt with no imperative verb is answered directly, no plan-gate ceremony (reduces false-positive routing without advertising an override keyword).

### Changed
- **`route-prompt.ps1`/`.sh` intro now names `CLAUDE.md §1` as the canonical source** the rails mirror (the rails stay for just-in-time salience on Claude; they are bound to §1, not deleted).
- **`session-start.ps1`/`.sh` no longer re-lists a routing keyword vocabulary** and no longer claims to route on Copilot (Copilot discards its stdout); it now points at §1. Comment in `.github/hooks/hooks.json` corrected accordingly.
- **`generate-copilot.md`** now mandates the §1 block be copied **verbatim** into `AGENTS.md` (carved out of the "may be condensed to one line per step" license) — otherwise regeneration would erase the inline non-negotiables from the one surface that needs them.
- **`/docs-sync`** gained two binding checks: AGENTS.md §1 must match `CLAUDE.md` §1 verbatim, and the `route-prompt` rails must stay substance-consistent with §1.

### Verification
- `guard.*` re-verified on all three surfaces: Claude `Edit` + AWS key → `exit 2` + stderr; Copilot CLI `edit` + key → `permissionDecision` JSON (exit 0); VS Code `create`/`str_replace` + key **or** `Assert.True(true)` → superset `permissionDecision` JSON (exit 0, the newly-covered surface); clean content → exit 0. `guard.*` byte-identical across both repos; UTF-8 BOM preserved.
- All four edited hooks (`route-prompt`, `session-start`) parse clean under Windows PowerShell 5.1 + pwsh 7 and `bash -n`; answer-only suppression confirmed (a pure "why does this throw?" emits no rails; "fix the login crash" routes).
- **Task 0 (VS Code Preview-hook spike) was run and confirmed agent-hooks DO fire in VS Code agent mode.** The captured payload uses the Anthropic text-editor tool schema — `create` (`toolArgs.path` + `toolArgs.file_text`), `str_replace`/`insert` (`new_str`) — field names the guard's extractor did **not** previously read, so VS Code writes would have slipped the floor. Added `file_text` / `new_str` / `path` to the field extraction (both `guard.ps1` and `guard.sh`, jq + python paths); re-verified the guard blocks a `create`+secret and `str_replace`+private-key under the real VS Code shape. **Verified end-to-end:** a `create` of a deny-listed path in VS Code agent mode was blocked at runtime with the hook's reason surfaced to the model — the superset `permissionDecision` deny is honored. (Enablement remains org-gated: where Preview agent-hooks are disabled, VS Code degrades to instruction-only, as documented.)
- **`guard.sh` brought to parity with `guard.ps1`:** the bash path was missing the v0.22.0 test-defeat blocks, so the same write was blocked under PowerShell but allowed under bash. It now also blocks `[Fact/Theory(Skip=…)]`, `Assert.True(true)`/`Assert.False(false)`, `fit`/`fdescribe`/`.only`, `xit`/`xdescribe`/`.skip`, and `expect(true).toBe(true)` — verified firing on Claude (exit 2) and Copilot (`permissionDecision` JSON), and verified to still ALLOW the RxJS `skip()` operator and clean files.

## 0.22.0 — 2026-06-25 (test integrity: defend against the test pathologies AI assistants are most prone to)

> The framework had a strong testing *philosophy* (behaviour-first, lean, characterization-before-refactor) but three structural gaps: no guidance on test *shape* (only test types); no defence against the failure mode its own users are most exposed to — AI assistants routinely emit over-mocked, tautological tests that pass even when the code is broken (2026 empirical studies across Claude/Copilot/Cursor; majority-incorrect LLM oracles); and an enforcement asymmetry where architecture had a deterministic CI gate but testing had only soft review. This release closes the doctrine + cheap-enforcement gaps. Coverage-as-diagnostic and CI-enforced diff-scoped mutation testing are scoped for 0.23.0.

### Added
- **`test-critic` review agent** (`.claude/agents/test-critic.md` + `.github/agents/test-critic.agent.md`), spawned by `/review` alongside the existing four auditors. Its single question per test: *would this fail if the code under test broke?* Flags oracle-invalid (would-not-fail) tests, over-mocking, weak assertions, missing error/edge paths, implementation-coupling, nondeterminism, and financial-domain gaps — a separate context from the code author, per the "the agent doing the work isn't the one grading it" principle. `/review`'s output block is renamed **Test Quality & Coverage** with a would-fail-if-broken verdict.
- **Test-integrity rules** (`CLAUDE.md` / `AGENTS.md` > Leanness > Test leanness #14–#16): no over-mocking (mock only true external boundaries; prefer fakes/in-memory for owned code), no tautological assertions, assert behaviour not implementation — each with its plain-language *why*.
- **Verification Rule #9 — red before green**: a new behavioral test must be *seen to fail* against broken/pre-fix code before it is trusted; generalised from the bug-fix-only habit already in `fix.md`. The cheapest defence against vacuous tests.
- **Test shape + determinism defaults** (`docs/defaults.md`): an architecture-conditioned shape heuristic (push each test to the lowest level that runs real behaviour; unit-dense domain logic, integration for cross-cutting paths via `WebApplicationFactory`, sparse full-stack; honeycomb/risk-based for boundary-heavy services; the inverted / ice-cream-cone anti-shape) plus a determinism/hermeticity stanza. Bootstrap-overridable.

### Changed
- **`guard.ps1` PreToolUse hook now hard-blocks test-defeats** (deterministic floor; both surfaces/shells preserved — exit 2 + stderr for Claude, JSON deny for Copilot, `-ceq`, UTF-8 BOM): `[Fact/Theory(Skip=…)]` and `Assert.True(true)`/`Assert.False(false)` in `*.cs`; `fit`/`fdescribe`/`.only`/`xit`/`xdescribe`/`.skip` and `expect(true).toBe(true)` in `*.spec.ts`. Enforces the previously-unenforced "no focused/skipped tests" convention.
- **`add-tests` skill and `/test`** gained the over-mocking/real-oracle guidance and the red-before-green check; `/test` now points at the Test shape heuristic and states the TDD position (no test-first mandate for features; red-first for fixes and regressions).
- **`/feature` final subtask** reworded from "integration test" to integration / end-to-end verification exercising the real pipeline as a caller would (Anthropic field finding: agents pass unit/integration but miss end-to-end) — parity with the Angular workflow.
- **§5 Verification & confidence line** now requires showing the evidence — the command run and its observed pass/fail counts — not the bare claim "tests pass."
- **`metrics.ps1`** discloses two new anti-pattern counts (`tests_skipped`, `tautological_assert`) for `/impact` — disclosure, not a gate. A `test-integrity-real-oracle` probe was added to `tests/impact/tasks.json` so the change is measurable through the framework's own A/B harness.

### Verification
- `guard.ps1` re-verified under Windows PowerShell 5.1 and pwsh 7: blocks `[Fact(Skip=…)]`, `Assert.True(true)`, `fit(`, `it.only`, `expect(true).toBe(true)` (exit 2); passes clean tests and the RxJS `skip()` operator (exit 0); existing `#pragma` / `@ts-ignore` blocks unaffected; UTF-8 BOM preserved.
- `guard.ps1` and `metrics.ps1` parse cleanly (0 errors); `metrics.ps1` runs and emits the new keys; `tests/impact/tasks.json` is valid JSON with the new probe.
- `.github/skills` re-synced and byte-identical to `.claude/skills`; `test-critic` mirrored to `.github/agents`; `AGENTS.md` updated with Rule #9 and Test leanness #14–#16; both repos stamped `0.22.0`; `docs-sync-check` clean. The impact A/B run itself (`impact-run.ps1`, needs Copilot CLI + two git refs) was not executed this session.

## 0.21.0 — 2026-06-12 (hook feedback actually reaches the model; PowerShell 5.1 hooks un-broken)

> Field finding (consumer report): "hooks always exit with 0 — build failures silently get ignored." Confirmed, and the audit found three distinct silent-failure mechanisms, all in the feedback path between a hook and the model. The hooks *ran* fine; their output went nowhere. Verified against the Claude Code hooks reference (exit-code/stdout semantics per event) and the GitHub Copilot hooks reference (stdout parsed as JSON only).

### Fixed
- **`post-write` build failures never reached the model** (`post-write.sh` + `.ps1`). Claude Code feeds PostToolUse output to the model only via **exit 2 + stderr** — plain exit-0 stdout goes to the debug log; Copilot consumes postToolUse stdout only as **JSON** (`{"additionalContext": …}`). The hook printed plain text and exited 0: invisible on both surfaces, so the agent kept working on top of a broken build. Now: Claude surface → failure tail on stderr + exit 2; Copilot surface (`edit`/`create` tool names) → `additionalContext` JSON on stdout. The throttle stamp is also cleared on failure so the next write rebuilds instead of skipping the known-broken build for the rest of the 60 s window (previously the failure wouldn't even resurface). `post-write.sh` additionally gained a `tool_name` initialisation — under `set -u` the new surface branch would otherwise abort on the python3 fallback path.
- **`boy-scout-check` Stop-hook findings were equally invisible** (`boy-scout-check.sh` + `.ps1`). Findings addressed to the agent ("address them … before considering the work complete") were emitted as plain exit-0 stdout, which Stop hooks send to the debug log only. Now emitted as `{"hookSpecificOutput": {"hookEventName": "Stop", "additionalContext": …}}` — the model sees the findings, and the hook stays *soft* (no forced continuation). Switch to `{"decision":"block","reason":…}` for strict enforcement, as before.
- **`guard.ps1` failed open for Claude's `Edit` tool.** PowerShell `-eq` is case-insensitive, so `'Edit' -eq 'edit'` routed Claude's Edit through the **Copilot** branch: a JSON deny on stdout with exit 0, which Claude Code does not honour as a block — the write went through. Now `-ceq` (the bash twin was never affected; `case` patterns are case-sensitive). The same comparison in the new `post-write` surface branch uses `-ceq` from the start. `Write` was unaffected, which is why the guard appeared to work.
- **No `.ps1` in the repo parsed under Windows PowerShell 5.1** where it contained non-ASCII. All `.ps1` files were BOM-less UTF-8; 5.1 reads those as ANSI, so the em-dashes inside `guard.ps1`'s string literals mangled into multi-byte garbage and produced a **hard parse error** — on `settings.windows.json` installs (the no-pwsh fallback) the guard never blocked anything, exiting 1 (which PreToolUse treats as non-blocking). UTF-8 BOM added to **every** `.ps1` in the repo (hooks + scripts); required by 5.1, harmless under pwsh 7.

### Verification
- All four post-write paths exercised with a stubbed failing/passing toolchain under pwsh 7, Windows PowerShell 5.1, and bash: Claude failure → exit 2 + stderr; Copilot failure → `additionalContext` JSON + exit 0; success → silent exit 0, stamp kept. Guard re-verified blocking on both surfaces and both shells; boy-scout JSON verified well-formed from both shells; all 23 `.ps1` files across both template repos re-parse cleanly.

## 0.20.0 — 2026-06-11 (mode-aware installer; adoption-pending becomes durable, machine-checked state)

> Field finding: an agent (Opus 4.8) given this repo and asked to "implement the framework" ran the install script and stopped — `/adopt` never happened. Root causes: `/adopt` is deliberately not model-invocable and didn't exist in the installing session anyway; every pointer to it was ephemeral stdout or README prose addressed to a human; and the only durable post-install state (`BOOTSTRAP_PENDING`) steered the *wrong* way (`/bootstrap`). Worse, on brownfield targets the installer overwrote the very artifacts `/adopt` exists to merge (the consumer's `CLAUDE.md`, `AGENTS.md`, `TECH_DEBT.md`, …). This release makes the installer mode-aware and turns "adoption pending" into durable state that the SessionStart hook, CI, and `/bootstrap` all enforce — with an explicit handoff contract for installing agents.

### Added
- **Installer mode detection** (`scripts/install.ps1`/`.sh`): **greenfield** / **brownfield** / **update**, decided from an `/adopt`-Phase-1-style artifact scan and the presence of `.claude/framework-version.json`. The mode is printed and drives the next-steps output.
- **Brownfield: originals preserved + durable marker.** Files the copy would clobber (`CLAUDE.md`, `AGENTS.md`, `TECH_DEBT.md`, `SECURITY_FINDINGS.md`, `LEARNINGS.md`, `FRAMEWORK-CONTEXT.md`, `.github/copilot-instructions.md`, `docs/ARCHITECTURE.md`) are moved to `docs/pre-adoption/` *before* the copy, and `.claude/adoption-pending.json` records the detected artifacts and the archive mapping.
- **SessionStart adoption warning** (`session-start.ps1`/`.sh`): while the marker exists, every new session opens with 🔴 ADOPTION PENDING — next step is `/adopt`, **not** `/bootstrap`; the model cannot invoke it, so agents must stop and hand off to the developer. Takes precedence over the `BOOTSTRAP_PENDING` warning, which previously pointed brownfield repos at the wrong command.
- **CI guardrail**: `docs-sync-check.ps1`/`.sh` gained check 0 — fail while `.claude/adoption-pending.json` exists.
- **`/bootstrap` pre-flight guard** (check 0, `bootstrap.md`): aborts and redirects to `/adopt` when the marker exists, or when live AI artifacts (`.cursorrules`, `.clinerules`, `GEMINI.md`, …) exist without `docs/pre-adoption/`. `/adopt`'s own Phase-7 bootstrap run is unaffected — its Phase 3 clears both conditions first.
- **Agent handoff contract** (installer output + README §1): an installing agent's task ends with copy + commit + telling the developer verbatim to start a Claude Code session in the target repo and type `/adopt` (or `/bootstrap`); it must not attempt the command or replicate it by hand. The installer's brownfield output now addresses the agent case explicitly ("IF YOU ARE AN AI AGENT running this installer: …").

### Changed
- **`/adopt` consumes the marker** (`adopt.md`): Phase 0 reads `.claude/adoption-pending.json` as a discovery seed; Phase 1 treats installer-archived originals as merge candidates at their original paths (the repo-root `CLAUDE.md` is now the template — the consumer's original lives in `docs/pre-adoption/`); Phase 3 deletes the marker; the definition of done includes its removal.
- **Update runs no longer clobber consumer content**: re-running the installer on a repo stamped with `.claude/framework-version.json` refreshes the framework machinery but restores the consumer-owned content files listed above (previously a re-run overwrote a populated `CLAUDE.md` with the template).
- **Installer no longer ships template-repo meta files**: `README.md`, `CHANGELOG.md`, `.gitignore`, `.gitattributes` are excluded from the copy — previously they overwrote the consumer's own README/changelog/gitignore. This aligns the installer with the documented copy list in README Quick Start §1.

## 0.19.0 — 2026-06-10 (slash commands exposed to model-driven invocation)

> Previously none of the 14 `.claude/commands/*.md` files had frontmatter, so Claude Code's SlashCommand tool could not surface them to the model: in natural-language chat the model could never escalate from the condensed `route-prompt` rails to the full workflow — even when those rails explicitly told it to ("Run /security-review on the diff"). The architecture is hook-as-floor, command-as-ceiling; this release makes the ceiling model-reachable. The `route-prompt` hook keeps injecting the deterministic floor on every prompt; the model can now invoke the full command (e.g. `/review`'s four-auditor fan-out) when the condensed rails aren't enough.

### Added
- **`description:` frontmatter on all 14 command files**, written as routing guidance (when to invoke, what the command spawns and produces). This exposes the workflow commands — `/feature`, `/fix`, `/refactor`, `/test`, `/design`, `/debt`, `/review`, `/security-review`, `/generate-copilot`, `/docs-sync` — to model-driven invocation via the SlashCommand tool.
- **`argument-hint:` frontmatter** on the workflow commands that take `$ARGUMENTS`, for slash-menu autocomplete.

### Changed
- **Setup/maintenance commands opted out of model invocation**: `/bootstrap`, `/rebootstrap`, `/adopt`, and `/impact` carry `disable-model-invocation: true` — they reshape the framework configuration or run the A/B harness, and stay developer-initiated.

## 0.18.0 — 2026-06-10 (FRAMEWORK-CONTEXT.md fully auto-drafted by `/bootstrap`)

> Previously `/bootstrap` populated only two of FRAMEWORK-CONTEXT.md's seven sections (Detected Framework Packages, Known Hazard Areas); the five context sections (Production Architecture, Shared Libraries, Multi-Tenancy, Dashboard Integration, Cross-Service Communication) stayed as "_Not yet populated_" placeholders waiting on a maintainer — and in practice stayed empty (observed in real adoptions). They are now auto-drafted from single-repo evidence with explicit honesty about scope: the draft describes what *this repo's code shows*, opens with a comment handing the cross-repo half to a maintainer, and a section with no signals gets a verified negative ("no multi-tenancy signals found — checked X, Y, Z") instead of a placeholder.

### Added
- **`/bootstrap` Phase 3d-ter** (`bootstrap.md`). Drafts the five context sections from Read/Grep evidence: repo classification + consumes/exposes (Production Architecture); per-detected-package consumed-surface entries titled "Consumed API surface (observed in this repo)" — never "latest" (Shared Libraries); tenant signals such as `TenantId`, tenant claims, `HasQueryFilter` (Multi-Tenancy); health-check/registration wiring (Dashboard Integration); `AddHttpClient`/resilience/message-bus/correlation-ID wiring (Cross-Service Communication). Non-interactive — drafts land in the PR diff for content review, same path as mined skills. Never touches a section a maintainer has written (per-section `*_PENDING` markers gate it).
- **Per-section `*_PENDING` markers** in the FRAMEWORK-CONTEXT.md template, so drafting is gated per section and maintainer-written content deterministically survives re-runs.
- **Phase 4 report bullet**: one line per drafted section (what was found, or the verified negative) with the reminder that cross-repo facts still need a maintainer.

### Changed
- **FRAMEWORK-CONTEXT.md header**. Maintenance note reflects that every section is now bootstrap-drafted; versioning caveat distinguishes auto-drafted entries (consumed surface at the pinned version) from maintainer entries (may document latest).
- **`/docs-sync` Step 4** (`docs-sync.md`). Per-section drift now re-checks the four architecture/communication sections against the 3d-ter evidence lists and proposes updates in the report (still never rewrites in place).
- **`/adopt` Phase 7** (`adopt.md`). Explicitly drafts the still-unpopulated context sections; sections filled by merged content in Phase 4 are left untouched.

### Fixed
- **`bootstrap.prompt.md` wrapper had drifted**: claimed seven analysis passes (now eight, A8 added in 0.16.0) and "do not ask for confirmation between phases" (contradicting the 0.17.0 interactive gates). Now defers to the workflow's own pauses.
- **CLAUDE.md template version stamp** had drifted from `.claude/framework-version.json` (0.13.2 vs 0.17.0); both now read 0.18.0.

## 0.17.0 — 2026-06-10 (interactive gates in `/bootstrap` and `/adopt`)

> `/bootstrap` now pauses at two points for developer input rather than running end-to-end and deferring all review to a PR. Phase 2b collects ≤5 targeted questions (convention contradictions, pattern intent, financial domain scope) in a single message before generating any artifact — the developer's answers are baked in, not deferred. Phase 3d-bis asks each candidate hazard as a plain engineering question before writing it to FRAMEWORK-CONTEXT.md; answers map to `[VERIFIED]`, `[REVIEWED: not a hazard — <date>]`, or `[UNVERIFIED]` — no row is dropped (audit trail preserved). `/adopt` Phase 4a reframes contradiction-resolution from an AI-artifact-merge question into a plain engineering choice with a safe default and an "accept all defaults" escape.

### Changed
- **`/bootstrap` Phase 2b** (`bootstrap.md`). New clarify-before-writing gate: ≤5 questions in one message, covering convention contradictions, pattern intent, and financial domain scope (.NET only). Skip signal ("proceed", "accept defaults") continues without markers; `<!-- INFERRED -->` reserved for genuine code ambiguity only.
- **`/bootstrap` Phase 3d-bis** (`bootstrap.md`). Rewrites the hazard-confirmation step: each candidate hazard is asked in-session before being written, not after. Answered rows get `[VERIFIED]` or `[REVIEWED: not a hazard — <date>]`; unanswered rows remain `[UNVERIFIED]`. All rows are written (none dropped).
- **`/bootstrap` Phase 4 reminder** (`bootstrap.md`). Narrowed from "review CLAUDE.md before using any other commands" to "Verify the Conventions section — `<!-- INFERRED -->` marks areas where code analysis was genuinely ambiguous."
- **`/adopt` Phase 4a** (`adopt.md`). Contradiction-resolution reframed as a plain engineering question: "Your existing codebase has [A] for [area]; your `[filename]` says [B]. Which is intended?" Safe default keeps the in-code pattern. "Accept all defaults" escape applies it to all contradictions without per-item prompting.

## 0.16.0 — 2026-06-09 (project-specific skill discovery + exemplar grounding)

> `/bootstrap` now mines each codebase for its own tribal-knowledge recipes — multi-step operations that recur with non-obvious, repo-specific steps no shipped template can predict. Found candidates are auto-written as skills with `origin: discovered` frontmatter (visible in the PR diff for review). Instance-shaped skills (`add-endpoint`, `add-entity`, `register-service`, and any mined `add-X`) are grounded in a real repo exemplar so the agent reproduces the project's conventions and structure, not an abstract template. The resurrection guard in `/rebootstrap` records removed mined skills as declined recipes in `LEARNINGS.md` so they are not re-proposed.

### Added
- **A8 pass: project-specific skill discovery** (`bootstrap-pass.md`, `bootstrap.md`). Runs unconditionally in every repo — mines naming/directory clusters whole-tree (no recency sampling), applies a tribal-knowledge criterion + framework-exclusion list, proposes ≤3–5 candidates. Respects `## Declined recipe:` entries in `LEARNINGS.md`.
- **Exemplar grounding** (`bootstrap.md` Phase 3a). For instance-shaped skills, pins a `see also` prose line to a real file in the repo. Quality-gated against Phase-2 synthesis: patterns flagged as debt are routed to `TECH_DEBT.md` instead.
- **Phase 4 mined-skills report** (`bootstrap.md`). PR-reviewable listing of discovered skills in plain engineering language.
- **Resurrection guard** (`rebootstrap.md`). Detects deleted mined skills and appends `## Declined recipe:` blocks to `LEARNINGS.md`; reported in Phase-4 final report.
- **Exemplar re-pinning in `/rebootstrap`**. Proposes updated `see also` lines when exemplar files move or a cleaner instance exists.
- **`LEARNINGS.md` declined-recipe convention**. Header now documents the auto-managed `## Declined recipe:` format so maintainers know not to remove these entries.

## 0.15.0 — 2026-06-06 (spec-driven development: explicit Tasks artifact)

> A targeted alignment after reviewing how the frontier labs and institutions (AWS Kiro, GitHub Spec-Kit, Google Antigravity, OpenAI Codex) frame AI-driven SDLC: they have converged on Spec → Plan → **Tasks** → Implement. The framework already had the spec lifecycle (`/design → spec → /feature → /review`, with CLAUDE.md as the "constitution") and is ahead on governance / calibration / eval — this adds the one element it underweighted: a persisted, checkable Tasks breakdown.

### Added
- **Tasks checklist in the spec lifecycle.** The `specs/<slug>.md` template now carries an ordered, checkable **Tasks** section (the *how* — distinct from acceptance criteria, the *what*). `/design` drafts it; `/feature` works through it and checks each `- [ ]` → `- [x]` **in the spec file** as it lands, so implementation progress survives across sessions and tools; `/review` flags any unchecked Task as incomplete work. No new command or artifact — an extension of the existing flow, and the lean answer to industry spec-driven development.

## 0.14.0 — 2026-06-06 (AI-driven SDLC hardening: security, calibration, brownfield safety)

> Bakes best-practice findings from METR, Google DORA 2025, Anthropic's Claude Code guidance, and Thoughtworks/Böckeler into the framework so they are **LLM-driven, not left to each developer**. Reframed after a multi-reviewer critique: the highest-leverage gaps were security and trust-calibration, not the originally-planned ones. LSP-over-MCP symbol grounding was evaluated and **deferred** (no maintained offline bridge for Windows/Bitbucket DC; 8–15 s/query; orphaned-process lifecycle) — `Read`/`Grep` + Verification Rules #1–2 remain the fallback.

### Added
- **`/adopt` trust-boundary + safety screen.** Discovered AI-config/doc files (`.cursorrules`, `AGENTS.md`, etc.) are now treated as **untrusted input**: the agent never obeys instructions found inside them, and a provenance + adversarial-content scan (override phrasing, hidden-comment imperatives, exfiltration URLs) with **raw-content review** gates every merge into the canonical CLAUDE.md. Closes a prompt-injection hole on brownfield adoption.
- **Security-sensitive routing.** The `route-prompt` hook injects a security overlay (run `/security-review` / `security-auditor`; `decimal`-money/idempotency/TOCTOU reminders) whenever a prompt touches payments, balances, ledgers, auth, or secrets — stacked on top of any workflow rails, and standalone when no workflow matched. DORA: AI amplifies weaknesses fastest here.
- **Enforced plan-review & clarify gate.** For fix/feature/refactor/test the agent must present a plan, surface clarifying questions, and **wait for the developer's go-ahead before writing code** (CLAUDE.md Agentic Workflow + `route-prompt`). The human-in-the-loop checkpoint that also counters METR's perception gap.
- **Perception-gap feedback loop.** A "Verification & confidence" line (verified-by-running vs asserted) is now required on completed work (`workflow.md` + CLAUDE.md self-review); `/impact` gains a predicted-vs-actual calibration section and a "confidence is not correctness" honesty rule; two financial-correctness eval cases added (`decimal` for money; check-then-act + idempotency on a balance debit).
- **Known Hazard Areas.** A `/bootstrap`-drafted section in `FRAMEWORK-CONTEXT.md` capturing the repo's "here be dragons" (load-bearing workarounds, undocumented invariants, tests that don't pin behaviour) with required epistemic status (`[UNVERIFIED]`/`[SUSPECTED]`/`[VERIFIED]`) and a 90-day re-confirm rule — the lean form of brownfield hazard capture (no new doc, no new subagent).
- **Characterization mode** in the `add-tests` skill: pin **observed** (not verified-correct) behaviour before a refactor, skeleton-then-run (never invent expected values), with a mandatory "OBSERVED not VERIFIED" header and a **HALT for human review on money/idempotency** so a characterization test can't silently bless a pre-existing financial bug. `/refactor` Step 2 now points at it.
- **AI-readiness disclosure.** `scripts/metrics.{ps1,sh}` emit a `readiness` block (CI present, measured coverage % or `null`=not-measured, `Nullable`/`TreatWarningsAsErrors`, tests present); `/impact` surfaces it as a **capability disclosure, never a gate** — a weak substrate is exactly where teams most need help.

### Notes
- LSP-over-MCP symbol grounding: **deferred** behind a spike with explicit kill criteria — cold-start >10 s, 8–15 s/query, orphaned language-server processes, and air-gapped install of `csharp-ls`/`typescript-language-server` + an MCP bridge infeasible on Bitbucket DC. Fallback: `Read`/`Grep` + Verification Rules #1–2.

## 0.13.2 — 2026-06-05 (hooks fire on Windows: PowerShell-default + CRLF-safe)

### Fixed
- **Claude Code hooks silently no-opped on Windows.** The default `.claude/settings.json` invoked `bash .claude/hooks/*.sh`; on a Windows box without git-bash on PATH (or with CRLF-mangled `.sh` files), the hooks failed quietly — so the framework's enforcement (secret/suppression blocking via the PreToolUse guard, the PostToolUse build + audit log, the Stop boy-scout check) **wasn't actually running**. The default now uses the PowerShell (`pwsh`) twins, which don't depend on bash. `scripts/install.ps1` falls back to Windows PowerShell 5.1 (`settings.windows.json`) when `pwsh` is absent; `scripts/install.sh` switches to the bash twins when `pwsh` is absent. Copilot's `.github/hooks/hooks.json` already declared both interpreters and was unaffected — this brings Claude Code to parity. (Reported from a real implementation.)
- **`.sh` hooks corrupted to CRLF on Windows checkout.** Added `.gitattributes` pinning `*.sh` (and `*.ps1`) to LF, so `core.autocrlf=true` can't rewrite the shebang line to `bash\r` and break the bash twins — the second reason the bash hooks failed on Windows.

## 0.13.1 — 2026-06-05 (impact harness: exclude build artifacts from the A/B diff)

### Fixed
- **Build artifacts leaked into the behavioral A/B file list.** `scripts/impact-run.{sh,ps1}` now exclude `bin/`, `obj/`, `node_modules/`, `dist/`, `.angular/`, `.vs/`, `TestResults/`, and `coverage/` from the captured diff via git pathspec exclusions (`:(exclude,glob)**/…/**`). Without it, a consumer repo that doesn't gitignore those dirs fed generated files — including generated `.cs` under `obj/` (`*.AssemblyInfo.cs`, `GlobalUsings.g.cs`) — into the acceptance asserts and the `metrics.sh` scorecard, corrupting the A/B signal and inflating file/LOC counts. We filter the file list rather than clean the tree — note `git clean -fd` does **not** remove ignored dirs like `bin`/`obj`; that needs `-fdx`. (Reported from a real implementation.)

## 0.13.0 — 2026-06-05 (presentation deck + impact-harness Windows/Copilot fixes)

### Added
- **Presentation deck** — `docs/presentation/framework-briefing.html`, a self-contained, offline HTML briefing (keyboard nav, built-in speaker-notes overlay, print-to-PDF) for pitching the framework to tech leads and their teams: overview + practical implications for both audiences. Companion **`docs/presentation/TALKING-POINTS.md`** carries two runs-of-show (leads vs teams), a pre-meeting checklist, per-slide notes, and anticipated Q&A. Listed in the README "What's in the box" table.

### Fixed
- **Impact harness was skipped during `/adopt`** (observed in a real Opus-4.6 adoption). `/adopt` Phase 9 is now **mandatory**, with a "Definition of done" that gates completion on `docs/impact/IMPACT.md` existing, and Phase 8 explicitly hands off to it — the report can no longer be silently dropped.
- **Copilot CLI not detected on Windows.** `scripts/impact-run.{sh,ps1}` now resolve the agent robustly — probing `copilot`, `copilot.cmd`, `copilot.exe`, and npm-global locations (`npm prefix -g`, `%APPDATA%\npm`) — instead of a single `command -v copilot`, which missed the npm-global `.cmd` shim. `/impact` now tells the agent to trust the runner's exit code (`3` = genuinely absent) rather than pre-judging availability with a bare PATH check.
- **`git worktree` failed on Windows long paths (MAX_PATH).** The behavioral A/B now creates worktrees at a short drive-root base (`<drive>:/iwt/wN`) with `core.longpaths=true`, instead of deep temp+GUID paths that overflowed the 260-char limit once a deep source tree was checked out.

## 0.12.0 — 2026-06-04 (CLAUDE.md review + README-drift check)

### Added
- **`docs-sync-check` README-drift check** — advisory NOTE when a skill (`.claude/skills/`) or agent (`.claude/agents/`) isn't mentioned in `README.md`, so the hand-maintained What's-in-the-box / subagents tables can't silently fall behind (the gap that had let the README drift to 0.7.2).

### Fixed
- **Boy Scout rule "inline single-consumer interfaces" contradicted mandatory SOLID/DIP.** Reworded in CLAUDE.md + AGENTS.md to carve out DI service seams: service interfaces are required even with one implementation and must never be inlined; only data/internal abstractions are inline candidates.
- **CLAUDE.md Agentic Workflow** now references persisting a `specs/<slug>.md` spec for larger features (it lagged the AGENTS.md mirror and the `/design`→`/feature` flow).
- **CLAUDE.md drift note** now says to regenerate `copilot-instructions.md` **and** `AGENTS.md` (both are generated by `/generate-copilot`).

## 0.11.1 — 2026-06-04 (README accuracy)

### Fixed
- **README reference sections brought up to date** with the current toolset: What's-in-the-box now lists `solid-check`, `enforce-architecture`, the impact-harness scripts, and `docs/ARCHITECTURE.md` / `REVIEW-GUIDE.md`; the subagents table shows all six (incl. `solid-check`, now "six … five user-facing"); `/impact` added to the command list. The embedded changelog had drifted to 0.7.2 — it now points to `CHANGELOG.md` instead of duplicating it.

## 0.11.0 — 2026-06-04 (deterministic SOLID backstop + PowerShell parity)

### Added
- **`enforce-architecture` skill** — scaffolds the **deterministic** DIP/layering CI gate that complements the semantic `solid-check` agent: a NetArchTest test project enforcing dependency direction (Domain ⊄ Infrastructure, Application ⊄ Infrastructure/API), with a copy-paste sample at `scripts/ci/ArchitectureTests.sample.cs`. Referenced from `CLAUDE.md > SOLID` and Common Tasks.
- **PowerShell twins** for the impact harness — `scripts/metrics.ps1` and `scripts/impact-run.ps1` — so Windows-only / PowerShell shops get full parity (the bash versions remain primary).

## 0.10.0 — 2026-06-04 (impact harness)

### Added
- **Impact harness** — a fully automated before/after of the framework's value, run by `/adopt` (and standalone via `/impact`), with **no user input**.
  - **`/impact` command** (+ Copilot prompt wrapper): writes `docs/impact/IMPACT.md` and a generated `docs/impact/impact.html`.
  - **Tier 1 (always):** a capability diff (old setup archived in `docs/pre-adoption/` vs this framework) + a deterministic codebase scorecard via `scripts/metrics.sh` (anti-pattern / SOLID-DIP / security / test counts → JSON), baselined at adoption (`docs/impact/baseline.json`).
  - **Tier 2 (if Copilot CLI is present):** a behavioral A/B — `scripts/impact-run.sh` runs `tests/impact/tasks.json` through the headless agent **twice**, in throwaway git worktrees at the `pre-adoption` tag (old framework) vs `HEAD` (this one), N trials each, capturing build / acceptance-asserts / anti-patterns-on-diff per run. Only the framework differs between arms.
  - `/adopt` Phase 0 freezes the baseline and tags `pre-adoption` **before any change**; Phase 9 runs `/impact`.
- **`scripts/build-architecture-html.{sh,ps1}` generalized** to `[src] [out] [title]`, so `/impact` renders `impact.html` from the same drift-safe generator.

### Note
- Tier 2 needs a headless agent (Copilot CLI), authenticated once; without it, Tier 1 still runs. Results are stochastic — read trials as a distribution and pin the same model in both arms. PowerShell twins of `metrics`/`impact-run` are a follow-up (the harness already requires git-bash, a framework prerequisite).

## 0.9.1 — 2026-06-04 (architecture docs + AI install path)

### Added
- **`docs/ARCHITECTURE.md`** — canonical, human-readable architecture map with Mermaid diagrams (three-tier model, source→generated flow, hook lifecycle, GitHub-vs-Bitbucket surface split, repo map). Renders on GitHub/Bitbucket; AI agents still read CLAUDE.md/AGENTS.md, not this.
- **`docs/architecture.html`** — generated from ARCHITECTURE.md by `scripts/build-architecture-html.{sh,ps1}` (renders diagrams via marked + mermaid; embeds the source so it cannot silently drift). Cross-tool `src-sha1` marker; `docs-sync-check` flags staleness.
- **`docs/REVIEW-GUIDE.md`** — a senior reviewer's annotated tour: reading order, what each piece guarantees, how to verify it, and the tradeoffs worth probing.
- **`scripts/install.{sh,ps1}`** — install the framework into a target repo (excludes `.git` and the `.template-repo` marker), then prints next steps; plus an "Implementing this framework (for an AI agent)" entrypoint in the README.
- **`docs-sync-check`** gains an `architecture.html` freshness check.

## 0.9.0 — 2026-06-04 (literal SOLID)

### Added
- **SOLID is now mandatory** — a standing `## SOLID` section in CLAUDE.md (mirrored to AGENTS.md): an interface for **every injected service** (DIP), plus SRP / OCP / LSP / ISP rules. Literal classic SOLID, per tech-lead mandate. Data carriers (DTOs, entities, value objects, `Options`) are exempt — they are not services.
- **`solid-check` subagent** (`.claude/agents/` + `.github/agents/` mirror), dispatched by `/review` Step 1 alongside convention-check / bloat-radar / debt-radar. Covers the five principles semantically; self-skips in repos without a `## SOLID` section.
- **`docs/architecture-decisions.md`** is now the home for full ADRs; `docs/defaults.md` DI section mandates interface-per-service for greenfield.

### Changed
- **Leanness #2 reconciled with SOLID**: interfaces are now expected for injected services; the anti-bloat teeth remain on *data* (never interface a DTO/entity/value object) and on *speculation* (no abstractions for hypothetical variation).
- **`bloat-radar` recalibrated**: it no longer flags a single-implementation interface on an injected service (required by DIP now); it still flags interfaces/abstractions on non-service types, speculative bases, and helper classes. The SOLID lens moved to `solid-check`.
- **`/generate-copilot`** now emits a SOLID block into `copilot-instructions.md` and copies the full SOLID section into the `AGENTS.md` mirror.
- **Eval suite** flipped to the new policy: `dotnet-001` now requires `IEmailNotifier`; `dotnet-004` requires `ISmsService` **and** still forbids a speculative provider factory (DIP yes, future-proofing no).

### Fixed
- **`/adopt` ADR merge** now appends full ADRs to `docs/architecture-decisions.md` with a one-line index in CLAUDE.md (was pasting them inline), matching the `create-adr` skill and `/bootstrap` Phase 3a — keeps CLAUDE.md within budget and the prompt cache warm.

### Note
- Deterministic DIP backstop is **NetArchTest** (dependency-direction tests in CI); the semantic SOLID gate is the `solid-check` agent. Wire NetArchTest into your test project to fail builds on layer violations.

## 0.8.0 — 2026-06-04 (cross-tool parity + Bitbucket + spec-driven)

### Added
- **AGENTS.md is now a generated full mirror** of CLAUDE.md's portable rules (Verification, Leanness, Conventions, Boy Scout, Agentic Workflow) — not a pointer — so AGENTS.md-native tools (GitHub Copilot agent mode & CLI, Codex, Cursor, Gemini, Aider) get the real ruleset. Emitted by `/generate-copilot` Part B; produced by `/bootstrap` Phase 3f; checked for drift by `/docs-sync` Step 2 and the CI guardrail.
- **Skills now reach Copilot.** `.claude/skills/` is mirrored byte-for-byte to `.github/skills/` (Copilot CLI / cloud agent read that path; VS Code Copilot already reads `.claude/skills/`). New `scripts/sync-agent-files.{sh,ps1}` regenerates the mirror, `/generate-copilot` Part C runs it, and the CI guardrail enforces parity.
- **Subagents exposed to Copilot** as custom agents: `.github/agents/{security-auditor,convention-check,bloat-radar,debt-radar}.agent.md` — thin wrappers delegating to the canonical `.claude/agents/` definitions (same single-source pattern as the prompt files).
- **PreToolUse guard hook** (`guard.sh` + `.ps1`) — hard-blocks any write that adds `#pragma warning disable` or a hardcoded secret (private key, cloud token, credential literal). Registered in `.claude/settings.json`, `.claude/settings.windows.json`, and `.github/hooks/hooks.json` (Claude Code: exit-2 block; Copilot: JSON deny). Deterministic enforcement of Verification Rule #7.
- **Spec-driven development**: a `specs/` directory with `specs/README.md` (template + lifecycle). `/design` persists a spec to `specs/<slug>.md`, `/feature` implements against it, `/review` verifies conformance. CLAUDE.md is framed as the project "constitution".
- **New skills**: `add-tests` (xUnit + `WebApplicationFactory`), `dependency-audit` (vulnerable NuGet + Dependabot/Renovate setup), `create-adr` (inline ADRs in CLAUDE.md > Architecture Decisions).
- **Bitbucket Data Center support**: a README "Running on Bitbucket Data Center" section (what works locally vs what's GitHub-only — incl. Atlassian Rovo Dev being Cloud-only); host-agnostic `scripts/docs-sync-check.{sh,ps1}`; `scripts/ci/bitbucket-pipelines.example.yml`; and Code Insights / pre-receive / Bamboo wiring guidance. `/security-review` gains a "Standing scanners" note (CodeQL on GitHub; Semgrep/SonarQube + Code Insights on Bitbucket).

### Fixed
- **A7 bootstrap pass was dead.** `/bootstrap` dispatched seven passes (incl. **A7 Financial Domain Invariants**) but `bootstrap-pass` only accepted A1–A6 and Phase 2 synthesised "six" — so the financial-domain analysis silently never ran. `bootstrap-pass`, Phase 2, the README agents table, and the `/bootstrap` + `/rebootstrap` prompt wrappers now all agree on **seven (A1–A7)**.

### Changed
- `.github/workflows/docs-sync-check.yml` is now a thin caller of `scripts/docs-sync-check.sh` (host-agnostic) and is marked GitHub-only. The script also verifies the AGENTS.md mirror is current and that `.github/skills` matches `.claude/skills`.
- `/generate-copilot` now regenerates **both** `.github/copilot-instructions.md` (slim) and `AGENTS.md` (full mirror), and syncs the skills mirror.

### Token economy
- **Model routing**: `convention-check`, `bloat-radar`, and `debt-radar` now run on **Haiku** (recurring, pattern-based work); `security-auditor` and `bootstrap-pass` stay on the inherited strong model (high-stakes / one-time-high-leverage). Cuts per-`/review` cost without losing security or bootstrap quality.
- **Quiet-on-success hooks**: `post-write.{sh,ps1}` emit `dotnet build` output **only on failure** — a successful write no longer injects a build summary into context.
- **CLAUDE.md size budget**: `docs-sync-check.{sh,ps1}` prints an advisory NOTE when CLAUDE.md exceeds ~400 lines (it loads on nearly every turn and anchors the prompt cache); `/bootstrap` Phase 3a documents the budget.
- **ADRs out of the hot path**: the `create-adr` skill now appends full ADRs to `docs/architecture-decisions.md` with a one-line index in CLAUDE.md, instead of pasting them inline — stops the always-loaded file from growing and avoids busting the prompt cache on every recorded decision. `/bootstrap` Phase 3a follows the same split.

## 0.7.2 — 2026-05-16 (Copilot routing parity)

### Fixed
- **Natural-language routing in Copilot was a silent no-op.** Per the [GitHub Copilot hooks reference](https://docs.github.com/en/copilot/reference/hooks-configuration), the `userPromptSubmitted` event is fire-and-forget — stdout is discarded, so `route-prompt.sh|ps1` couldn't inject workflow rails on the Copilot side regardless of schema correctness. Removed the misleading `userPromptSubmitted` entry from `.github/hooks/hooks.json`.

### Added
- **Workflow-routing primer in `SessionStart`** (both `session-start.sh` and `session-start.ps1`). Once per session, the hook emits the seven workflow names with their trigger vocabulary so the model can self-classify natural-language prompts in Copilot. In Claude Code the per-prompt `route-prompt` router still runs and dominates; the primer is harmless reinforcement there.

### Changed
- **README "Deterministic hooks" table** now flags `UserPromptSubmit` and `Stop` as Claude Code only and distinguishes per-prompt routing (Claude Code) from session primer + self-classification (Copilot).

## 0.7.1 — 2026-05-15 (hook plumbing forensic-fix batch)

### Fixed
- **`.claude/settings.json` hook schema** (both bash and PowerShell variants). Restructured to the documented Claude Code form: each event entry now wraps handlers in a nested `hooks` array with explicit `"type": "command"`. The previous flattened form was non-conformant and likely failed to register hooks on recent Claude Code versions.
- **`.github/hooks/hooks.json` schema**. Added the required `"version": 1` field; converted the top-level `hooks` from an array to an object keyed by event name; added `"type": "command"` to every handler; added `timeoutSec` per event. The prior shape did not match the GitHub Copilot hooks reference and the hooks almost certainly weren't being loaded by the cloud agent.
- **Tool-name filter in hook scripts** (`post-write.{sh,ps1}`, `audit-trail.{sh,ps1}`). The filter previously accepted only Claude Code's `Write`/`Edit` (PascalCase); GitHub Copilot uses `edit`/`create` (lowercase). Every Copilot file-write event was being silently dropped before path extraction. Filter now accepts both surfaces.
- **`toolArgs` parsing** in the same scripts. Per the Copilot hooks spec, `toolArgs` is a parsed object, not a JSON-encoded string. The previous `jq fromjson` / `ConvertFrom-Json` paths threw and were silently swallowed by `2>/dev/null`, so file-path extraction from Copilot payloads returned empty. Switched to direct object access, with a fallback string-parse for legacy payload shapes.
- **Prompt-file frontmatter** — `mode: agent` → `agent: agent` across all 13 `.github/prompts/*.prompt.md` files. `mode` was deprecated by VS Code in favor of `agent` (see `github/awesome-copilot#464`).
- **`settings.windows.json` audit-trail parity** — the bash variant registered two `PostToolUse` hooks (post-write + audit-trail); the PowerShell variant only registered post-write, so Windows-only PowerShell teams had no SR 11-7 / DORA audit log. Added the audit-trail handler.
- **Bogus `$schema` URL** in `framework-version.json`. Removed — the URL pointed to a non-existent GitHub org.
- **Tracked runtime state** — removed `.claude/.state/last-build-ts` from the working tree. It is gitignored but had been committed before the rule was added.
- **`post-write` throttle window** — raised from 5 s to 60 s. Real `dotnet build` runs take 30 s+; the 5 s throttle expired long before the in-flight build finished, so burst writes still stomped on the running compile.
- **Boy-scout `!` (null-forgiving) detector** false-positive on `x!=y` (no surrounding spaces). Now requires the `!` to be in postfix-operator position.

### Changed
- **README hook-compatibility table**. The "VS Code Copilot reads `.claude/settings.json` directly" row was unfounded — VS Code Copilot's surfaces are `.github/copilot-instructions.md`, `.github/instructions/`, `.github/prompts/`, and `.github/hooks/`. The table is now two rows: Claude Code (CLI + VS Code extension) and GitHub Copilot (cloud + CLI), with the exact payload shape per surface.

### Added
- **Cleanly bail-out guard** in `post-write`: skip if the `dotnet` CLI is not on PATH, instead of failing noisily.

## 0.5.0 — 2026-04-28 (anti-bloat batch)

### Added
- **Leanness conventions** in `CLAUDE.md`. Counterweight to Boy Scout's add-bias: no interface without a second consumer, wrappers must add behavior, prefer editing over creating, deletion is a contribution.
- **`bloat-radar` subagent**. Scans diffs for speculative abstractions, shallow wrappers, parallel implementations, comment debris, defensive over-coding, trivial tests, and net-LOC density. Wired into `/review` alongside `convention-check` and `debt-radar`.
- **Anti-bloat rails** appended to `feature` and `refactor` workflow rails (route-prompt bash + PowerShell). Refactor now reports net LOC delta; growth requires explicit reason.
- **Boy Scout: Subtract** subsection in `CLAUDE.md`. Always-apply subtractions (unused usings, commented-out blocks, unreferenced privates) and primary-target subtractions (inline single-consumer interfaces, collapse shallow wrappers).
- **Stop hook** (`boy-scout-check.sh` + `.ps1`) now flags commented-out code blocks (2+ contiguous code-like `//` lines).
- **`/security-review` command + `security-auditor` subagent**. OWASP-style scan: injection / XSS / auth-authz / secrets / sensitive data / crypto / transport / dependencies. Wired into Copilot via `.github/prompts/security-review.prompt.md`.
- **Eval harness** (`tests/evals/`). Tiny regression suite that probes the rules CLAUDE.md + FRAMEWORK-CONTEXT.md encode (Verification, Leanness, Boy Scout, no future-proofing, no defensive over-coding). Two grading layers per case: deterministic regex + Haiku-graded rubric. Uses prompt caching with a `cache_control` breakpoint at end of CLAUDE.md so subsequent cases hit cache. Five cases, run quarterly or after framework version bumps.

### Changed
- `/feature` Step 1 includes a Leanness check before scoping the work.
- `/refactor` Step 7 now requires reporting net LOC delta.

## 0.4.0 — 2026-04-28

### Added
- **PowerShell hook variants** for Windows-only PowerShell teams. Ships `.ps1` equivalents of `session-start`, `route-prompt`, `boy-scout-check`, `post-write`, and `audit-trail` alongside the bash versions, plus a `settings.windows.json` users can swap into `.claude/settings.json` (or `.claude/settings.local.json`). Uses Windows PowerShell 5.1 — preinstalled on every Windows machine, no extra install. (Resolves the "hooks disabled on PowerShell-only Windows" caveat in the README compatibility table.)
- **`FRAMEWORK-CONTEXT.md` template**. Cross-repo context file for shared library APIs, multi-tenancy conventions, dashboard contracts, and cross-service patterns. Maintainer-curated; bootstrap auto-populates the "Detected Framework Packages" table from `*.csproj` / `Directory.Packages.props`. CLAUDE.md still wins on conflicts; agent flags contradictions.
- **`/bootstrap` Phase 3d**: detects framework packages and populates `FRAMEWORK-CONTEXT.md > Detected Framework Packages`. Removes the `DETECTED_FRAMEWORK_PACKAGES_PENDING` marker on success.
- **`/docs-sync` Step 4**: re-scans for framework package add/remove/version-bump and flags drift in FRAMEWORK-CONTEXT.md.
- **CI guardrail check**: `docs-sync-check.yml` now verifies `FRAMEWORK-CONTEXT.md` exists and the bootstrap marker has been removed.

### Fixed
- **`route-prompt.sh` JSON parsing** no longer truncates on prompts containing escaped quotes (`\"`). Now prefers `jq` (handles all JSON escapes), falls back to `python3` / `python`, and finally to a regex that decodes common escapes. Same fix applied to the PowerShell variant via `ConvertFrom-Json`.

### Decided
- **Multi-repo architecture (Option B chosen)**: framework context is baked into each template via `FRAMEWORK-CONTEXT.md` rather than a central `ai-framework-context` repo. Self-contained repos avoid the unverified `--add-dir` mechanism and the silent-failure onboarding risk. Drift mitigated by `/docs-sync` and the CI guardrail. See `project_framework_architecture.md` for the full rationale.

---

## How to update this changelog

- One section per release (or per "Unreleased" working window). Date the heading.
- Group entries by **Added / Changed / Fixed / Removed / Decided**.
- One line per change. Reference the file or workflow touched, not the implementation detail.
- Keep entries scoped to this repo. Decisions that shaped the code belong in `docs/architecture-decisions.md`.
- Write for the next person on your team who has to upgrade — not for whoever made the change.
