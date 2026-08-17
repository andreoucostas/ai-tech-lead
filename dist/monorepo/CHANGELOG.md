# AI Tech Lead (.NET + Angular monorepo) — Changelog

> Release notes for the mixed .NET + Angular distribution, written for the teams who install it:
> what changed in **your** repo, and what (if anything) you need to do. This distribution carries
> the rails of both stacks, so entries may apply to one side or both.
> Architecture decisions you record live in `docs/architecture-decisions.md`.

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

## 0.56.0 — Unreleased

- Updates now warn before replacing framework-owned files, including `.claude/settings.json`, and
  tell you to preserve local edits first and review the resulting diff. Before settings are
  refreshed, the prior copy is saved at `.claude/.state/settings.json.pre-update`. Past updates may
  already have discarded local edits to shipped framework files.
- The enforcement-surface guide now identifies on-demand documentation as discoverable but not
  guaranteed to load; `docs/defaults.md` is the example.

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
