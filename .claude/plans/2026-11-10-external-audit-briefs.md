# Plan: external audit 2026-11-10, execution briefs for B-485 to B-497

**Status:** findings captured 2026-11-10 by a maintainer-requested audit (one auditing session plus six
read-only sub-sessions). Basis: HEAD `d0458f42` (v0.98.4 plus three commits), clean tree, pwsh 7.6.9 and
Windows PowerShell 5.1. Nothing is fixed here; each brief is one fresh session's work.

**Evidence key.** `REPRODUCED`: the auditing session ran it on an installed scratch copy and saw the
result. `SUB-SESSION`: an audit sub-session ran it and reported the result; re-run it before changing
anything. `READ`: the text was read at that HEAD, the behaviour is predicted. Every `path:line` was
read at `d0458f42`; re-read before freezing a change. The scratch repro scripts are gone; each brief
states its repro.

**How to use a brief.** Take one brief per session. Read the tier off the changed paths (`AGENTS.md`,
"Two tiers"), follow its required steps and the "Verification" recipe for those paths. `Red case` is
the test to see fail on the unfixed tree. `Done when` is the acceptance. `Not in scope` is binding.
Never edit `dist/`; rebuild it. A brief marked **DECISION FIRST** needs the maintainer's choice in chat
before any code.

**Left out on the maintainer's word (2026-11-10):** the VS Code trusted-folder hook outage. It is B-475
and waits on the upstream fix.

**Recommended order:** B-486, B-492, B-485, B-488, B-487, B-491, B-495, B-496, B-493, B-497, then the
three decision items B-489, B-490, B-494.

---

## B-485 · The README's guarantee sentence and the briefing deck claim more than ships

- **Evidence.** REPRODUCED for the guard's reach (see B-487, B-488). READ for the deck:
  `dist/dotnet/presentation/framework-briefing.html:116` ("measurable"), `:247` and `:342` (CI
  "publish to PRs through Bitbucket Code Insights"; nothing shipped does), `:320`, `:331`, `:362`
  (`/impact`, retired in 0.88.0), `:388` ("a measurable quality delta");
  `dist/dotnet/presentation/TALKING-POINTS.md:19`, `:115` ("measurable"), `:76` (Code Insights),
  `:127` ("Copilot's digest is generated from it"; the digest is gone). Root `README.md:91-93` says "a
  file write that adds a warning suppression or a hardcoded secret is blocked" with no qualifier.
- **Files.** Root `README.md`; `src/core/presentation/*` (grep the phrases, source lines differ);
  any `src/stacks/*/files/README.md` or `src/core/docs/*` line repeating the README sentence.
- **Change.** (1) README: name what the guard matches (`#pragma warning disable`, `eslint-disable`,
  `@ts-ignore`/`@ts-nocheck`, a skipped-test attribute, and the credential formats listed in
  `docs/enforcement-surfaces.md`), and say a required CI build with secret scanning is the gate for
  everything else. (2) Deck and talking points: remove `/impact`, the Code Insights claim, the digest
  sentence and every "measurable" that no shipped measurement backs; keep the deck's own honest line
  that adoption creates no before/after.
- **Red case.** Text-only: no behaviour to show red; say so in the commit.
- **Done when.** `git grep -n "/impact\|Code Insights\|digest is generated" -- src dist` returns
  nothing outside changelogs and retirements; the README sentence lists the matched forms; `dist/*`
  rebuilt; `DocTruth`, `DocClaims`, `ClaimTruth` and `VendorClaims` test files green.
- **Not in scope.** Rewriting `docs/enforcement-surfaces.md`; any new measurement; B-475's wording.
- **Tier.** Ordinary (Markdown and HTML under `src/core/presentation`, root README). Invariant #7:
  consumer-voice changelog head in all three stacks.

## B-486 · An update removes a team's own keys from `.claude/settings.json`

- **Evidence.** REPRODUCED. Greenfield dotnet install, commit; add top-level
  `"permissions": { "deny": ["Read(./secrets/**)"] }` to `.claude/settings.json`, commit; re-run
  `install.ps1 <target>`. After: top-level keys are `_comment, env, defaultShell, hooks`; the deny rule
  is gone; the only notice is `Done (update). … .claude/settings.json was backed up and refreshed.`
  The copy survives in `.claude/.state/settings.json.pre-update` (git-ignored, so one machine only).
  Root `README.md:116` calls the file "mixed … next to your own settings".
- **Files.** `src/core/scripts/install.ps1` (`:2408-2411` backup, `:3172` Done line; find the settings
  write between them); `src/core/docs/upgrade-checklist.md:69-70`; test in
  `.claude/hooks/tests/InstallerConvergence.Tests.ps1` or `UpdateDelivery.Tests.ps1`.
- **Change.** On update, carry every top-level key of the consumer's file that the framework's file
  does not define into the refreshed file, unchanged. For a key both define (`env`, `hooks`,
  `defaultShell`), keep today's behaviour and print one line per consumer value the refresh replaced
  or dropped, naming the backup. Update the checklist step to match.
- **Smaller fix rejected, say why in the commit.** Printing the dropped keys only: the deny rule
  still stops applying for every teammate until someone re-merges by hand.
- **Red case.** The repro above as a test: after the update `permissions.deny` still holds the rule.
- **Done when.** Red case green on pwsh and 5.1; a consumer `env` entry the framework does not set is
  either kept or named on a printed line; `-WhatIf` prints the same lines; greenfield and brownfield
  smoke installs pass.
- **Not in scope.** Merging individual hook entries inside `hooks`; `/adopt`'s handling of an archived
  settings file; moving the backup (B-469).
- **Tier.** Guarded, step 4 (installer). Harm class: a team's safety rule silently stops applying.

## B-487 · The write guard passes the commonest .NET and TypeScript credential forms

- **Evidence.** REPRODUCED for one form: a `Write` of a `.cs` file calling
  `UseSqlServer` with a connection-string literal that holds a `Password=` pair exits 0 with no
  output, while the control, a quoted value assigned to a field named `password`, exits 2.
  SUB-SESSION for the rest, all exit 0: the same literal passed to `new SqlConnection` or assigned
  to `var connStr`, a verbatim (`@`-prefixed) value, an indexer assignment through
  `config["Password"]`, a TypeScript field named `password` with a `string` type annotation before
  its value, a ServiceBus `SharedAccessKey=` string.
- **Files.** `src/core/.claude/hooks/guard.ps1` (`:344` generic key-then-quote rule, `:353` the rule
  that reads connection strings only inside a JSON `ConnectionStrings` section, `:319-331` the
  placeholder exemption to reuse); cases in `src/core/tests/hooks/guard-cases.ps1`.
- **Change.** (1) Apply the connection-string value test to any quoted literal that holds
  `Password=` or `Pwd=` after a `;`-separated pair, not only inside the `ConnectionStrings` section.
  (2) Let the generic rule see a verbatim-string prefix, an indexer key (`["Password"] =`) and a
  TypeScript type annotation between key and value. Keep the placeholder exemption as is.
- **Red case.** One case per form above in `guard-cases.ps1`, each expecting a block, on both
  surfaces' event shapes.
- **Done when.** The new cases block on pwsh and 5.1 plus one CP437 leg; every existing case is
  unchanged; a 2 MB write still decides inside Copilot's 10 s.
- **Not in scope.** Vendor token formats (JWT, PAT, Stripe, npm); `.env` and YAML; shell writes. Those
  stay documented limits with CI secret scanning as the gate.
- **Tier.** Guarded, step 4 (`guard.ps1`). What could be let through: nothing new; risk is new false
  blocks, so add two allowed cases (an empty password, a `Password=` inside prose in a `.md`).

## B-488 · The guard blocks an edit that only keeps a suppression or skip already in the file

- **Evidence.** REPRODUCED: an `Edit` whose `old_string` is `#pragma warning disable CS0618` plus one
  line, and whose `new_string` is the same two lines plus a third, exits 2 with "adds '#pragma warning
  disable'". SUB-SESSION: the same for an existing `[Fact(Skip=…)]`, and for a whole-file `Write`
  that keeps an existing pragma.
- **Files.** `src/core/.claude/hooks/guard.ps1` (`:48-49` reads only the new text; `:150`
  `Test-GuardPattern`; `:232-247` the suppression and skip patterns); `guard-cases.ps1`.
- **Change.** For the suppression and skipped-test patterns only: on an edit event, block when the
  pattern's match count in the new text exceeds its count in the old text (`old_string` and the
  per-surface equivalents); on a whole-file write to an existing file, compare with the file on disk.
  Credential patterns are untouched: a secret already in the file is still blocked.
- **Red case.** The three events above, expecting allow; plus one expecting block where the edit adds
  a second pragma beside an existing one.
- **Done when.** Those four cases pass on pwsh, 5.1 and CP437; no existing case changes verdict.
- **Not in scope.** B-489's credential false blocks; `[Ignore]` on non-test types.
- **Tier.** Guarded, step 4. What could be let through: an edit that moves a suppression to a new
  line of code while the count stays equal; state it.

## B-489 · The guard blocks UI labels, vault references and documentation samples — DECISION FIRST

- **Evidence.** REPRODUCED: a `Write` of an i18n JSON file whose `password` key holds the sentence
  *Enter your password* exits 2 as a hardcoded credential. SUB-SESSION, all blocked: a TypeScript
  label map whose `password` key holds the word *Password*, a `ClientSecret` setting holding an
  `@Microsoft.KeyVault(…)` reference, a CSS class starting `sk-` (20+ characters),
  a Cypress test login, a `docs/*.md` sample, an ESLint config naming a rule whose id contains
  `eslint-disable`. No allowlist or waiver exists; the shell is unguarded, so a false block teaches
  the bypass.
- **Decision needed (a secret-leak relaxation needs a WSD, not WSD-106).** Option A: the generic rule
  requires a secret-shaped value (no whitespace, not equal to its key name, not a vault reference).
  Lets through a passphrase containing spaces. Option B: a PR-reviewed allowlist file of paths or
  exact lines. Costs a new consumer-owned file and installer ownership work. Recommend A first.
- **Files.** `src/core/.claude/hooks/guard.ps1:344`; `guard-cases.ps1`.
- **Red case.** The i18n and label-map events, expecting allow; the control credential still blocks.
- **Done when.** The decision is recorded as a WSD; the chosen cases pass on both hosts and CP437;
  `docs/enforcement-surfaces.md` states the new limit in one line.
- **Tier.** Guarded, step 4.

## B-490 · With `pwsh` missing the guard's registered command exits 0; the agent can rewrite the registrations — DECISION FIRST

- **Evidence.** SUB-SESSION: the registered string
  `pwsh -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/guard.ps1 ; exit $LASTEXITCODE`
  (`"shell": "powershell"`), run through `powershell.exe` with PowerShell 7 off `PATH` and a
  key-shaped write, exits 0 with only "The term 'pwsh' is not recognized" on stderr; the route,
  session and audit commands exit 1 there. REPRODUCED: a `Write` of `{ "hooks": {} }` to
  `.claude/settings.json` exits 0; SUB-SESSION: so do writes to `.claude/hooks/guard.ps1` and
  `settings.local.json`.
- **Decision needed.** (a) Fail closed (`if ($null -eq $LASTEXITCODE) { stderr line; exit 2 }`) stalls
  a teammate without PowerShell 7 on every write, as Copilot already does (B-352); fail open is a
  false green. (b) Blocking agent writes to `.claude/settings*.json` would stop `/adopt` and the
  upgrade checklist's settings step when an agent performs them; a narrower rule blocks only a result
  that no longer registers `guard.ps1`, and any write to `.claude/hooks/*.ps1` or
  `.github/hooks/hooks.json`.
- **Files.** `src/stacks/*/files/.claude/settings.json` and `settings.windows.json`; `guard.ps1`;
  `src/core/scripts/framework-doctor.ps1` if it lives there (the doctor reports only `CANT-VERIFY`
  when the wired interpreter is not on `PATH`; make that a failing row).
- **Red case.** Re-run the sub-session probe first; then a test that runs the registered string with
  a `PATH` holding no `pwsh` and expects the decided exit.
- **Tier.** Guarded (`settings*.json`, `hooks/**`), step 4 for `guard.ps1`.

## B-491 · `route-prompt` routes approvals and questions as new work, and matches sensitive terms inside other words

- **Evidence.** REPRODUCED on the installed hook (Claude event shape): "yes, go ahead and implement
  the plan" and "What does the build pipeline do?" both return `## Routed intent: feature` with the
  plan gate (about 2,900 characters); "fix the concurrency bug in the cache" returns the security
  overlay (about 4,000 characters). SUB-SESSION: "add a CancellationToken to GetOrdersAsync" and "why
  is the load balancer health check red?" also get the overlay; the rails repeat on every matching
  prompt.
- **Files.** `src/core/.claude/hooks/route-prompt.ps1` (`:149-155` intent chain, `:161-163` question
  rule, whose imperative list holds `build`, `test`, `create`);
  `src/stacks/*/snippets/.claude/hooks/route-prompt.ps1/sensitive-regex` (`currency`, `token`,
  `balance` unbounded); `src/core/tests/hooks/RoutePrompt.Tests.ps1`.
- **Change.** (1) A prompt that opens with an approval (`yes`, `ok`, `go ahead`, `proceed`, `looks
  good`, `approved`, `lgtm`) gets no intent. (2) In a question-shaped prompt an imperative counts only
  as the first word or after `please`, `can you`, `could you`. (3) Word-bound `currency`, `token` and
  `balance` so `concurrency`, `CancellationToken` and `balancer` do not match. Review the monorepo
  snippet sibling.
- **Red case.** The five prompts above, expecting empty output (exit 0) or no overlay; "can you fix
  the login bug?" still routes to fix with the overlay.
- **Done when.** Cases pass in the source test and against the dist copy by piped fixture event on
  both surfaces, pwsh and 5.1, plus CP437; `rail-sync` is untouched because no rail text changes.
- **Not in scope.** Injecting once per session (needs state and a measurement); B-476.
- **Tier.** Guarded (`hooks/**`, stack snippets).

## B-492 · Three shipped texts contradict each other: `/feature` to `debt-radar`, the debt register's format, the PR template

- **Evidence.** READ, each line seen at `d0458f42`. (1) `dist/dotnet/.claude/commands/feature.md:24`
  says to spawn `debt-radar` via `Task` before scoping; `dist/dotnet/.claude/agents/debt-radar.md:13`
  rejects any call without a parent-supplied `-ScopePath <bundle>` and manifest hash as `CANNOT
  EXAMINE`; its description (`:3`) says "Invoke before work in an area". (2) `src/core/TECH_DEBT.md`
  ships a table; `bootstrap.md` writes `## DEBT-001:` blocks (dist `:298`); `debt.md:31` says items
  are per-block and to "follow the template at the top"; the `perf` skill appends a table row;
  `debt-radar` reads blocks. (3) `.github/PULL_REQUEST_TEMPLATE.md:14` offers "or skip reason noted in
  code" while the rules file's bug-fix scope forbids a TODO for deferred cleanup.
- **Files.** `src/core/.claude/commands/feature.md`, `debt.md`; `src/core/.claude/agents/debt-radar.md`
  and its `.github/agents` wrapper source; `src/core/TECH_DEBT.md`;
  `src/stacks/dotnet/files/.claude/skills/perf/SKILL.md`; `src/core/.github/PULL_REQUEST_TEMPLATE.md`.
- **Change.** (1) `feature.md`: replace the sub-agent call with "read `TECH_DEBT.md` for entries
  naming the touched files or area"; make `debt-radar`'s descriptions say it runs inside `/review`.
  (2) One register format, the `## DEBT-NNN` block: the template shows one example block, `perf`
  appends a block. (3) PR template: drop "or skip reason noted in code".
- **Red case.** Text-only: none; say so.
- **Done when.** `git grep -n "debt-radar" -- src/core/.claude/commands/feature.md` is empty; the
  template, `bootstrap.md`, `debt.md` and `perf` name one format; `dist/*` rebuilt and validated;
  `context-footprint -Check` green.
- **Not in scope.** Giving reviewers a no-bundle mode; any `bootstrap.md` change beyond none needed.
- **Tier.** Ordinary unless a `src/stacks/*/files/.claude/**` file changes (the `perf` skill does:
  guarded, text-only).

## B-493 · `dependency-audit` forbids inferring the scan commands, so on a typical repository it scans nothing

- **Evidence.** READ: `dist/dotnet/.claude/skills/dependency-audit/SKILL.md:22-26` ("Run only the
  evidenced form and report every unavailable scan category as **not available**; do not infer a
  `dotnet` command, target, or flag"); the Angular copy says the same of `npm audit` and `npm
  outdated`. The six Verification Commands categories have no dependency-scan slot, so `/bootstrap`
  records none. Behaviour predicted, not run; `ng update` is already the one derived exception (see
  `meta/decisions-index.md`, "The major-version upgrade is `dependency-audit` section 4").
- **Files.** `src/stacks/{dotnet,angular,monorepo}/files/.claude/skills/dependency-audit/SKILL.md`.
- **Change.** Once the skill's own package-evidence gate passes, allow the read-only scans without a
  recorded row: `dotnet list package --vulnerable --include-transitive`, `--deprecated`, `--outdated`;
  for Angular the audit and outdated commands of the package manager the lockfile evidences. Keep
  "do not infer" for build, test, restore and any command that writes.
- **Red case.** Text-only. If the maintainer wants a measurement first: one eval scenario, a .NET
  fixture with a vulnerable pinned package and no recorded scan command, graded on whether the scan
  ran.
- **Done when.** The three copies agree; the skill stays under the 1,024-character description limit;
  `dist/*` rebuilt and validated.
- **Tier.** Guarded (`src/stacks/*/files/.claude/**`), text-only.

## B-494 · The installer moves a team's own same-named documents and scripts aside as "AI tooling" — DECISION FIRST

- **Evidence.** SUB-SESSION: a repository with no AI tooling but its own `docs/ARCHITECTURE.md`,
  `docs/getting-started.md`, `docs/reference.md`, `LEARNINGS.md`, `scripts/metrics.ps1` and
  `tests/evals/README.md` installed as `brownfield (pre-existing AI tooling, or files this install
  would overwrite: …)`; five files moved to `docs/pre-adoption/`, the framework's took their paths,
  exit 0, and the Done block said the repository "has pre-existing AI tooling that must be
  consolidated with /adopt". Those paths are `framework-owned/overwritten`, so a restored file is
  replaced on the next update; `/adopt` has a restore rule for `docs/ARCHITECTURE.md` only.
- **Decision needed.** Option A: move framework documents and scripts under a namespaced folder
  (largest change; retirements for every moved path, references in every command). Option B: stop
  before any change when a tracked, non-agent-tooling file occupies a framework-owned path, naming
  the paths and an override switch. Option C: keep the move, correct the wording, and give every
  displaced non-AI file a restore line. Recommend B now, A as a planned release.
- **Files.** `src/core/scripts/install.ps1`; `src/core/scripts/adoption-archive.ps1`; any
  `framework-ownership.json` source; `.claude/hooks/tests/InstallerConvergence.Tests.ps1`.
- **Red case.** Re-run the sub-session scenario first; then the same as a test expecting the decided
  outcome.
- **Tier.** Guarded, step 4, with greenfield and brownfield smoke installs.

## B-495 · The installer accepts three states the README says it refuses or warns about

- **Evidence.** SUB-SESSION. (1) Run from `master` at `v0.98.4-3-gd0458f42` it printed `source: checked
  against origin: no release newer than v0.98.4, not behind origin/master` and stamped `"version":
  "0.98.4"`, though `git diff --shortstat v0.98.4 HEAD -- dist/dotnet` shows ten changed files; root
  `README.md:30-33` says to install from a tag. (2) A greenfield install into a dirty tree, and into
  a folder that is not a Git repository, exits 0 with no warning; `README.md:18` says "or the
  installer stops"; the preflight is inside `if ($adoptMode -or $updateMode)`
  (`src/core/scripts/install.ps1:1814`). (3) An update that reverted a team's edits to three
  framework-owned files named none of them, and printed 91 `PLAN replace` lines for a byte-identical
  update.
- **Files.** `src/core/scripts/install.ps1` (`:333` source check, `:1814` preflight); root
  `install.ps1` if the check lives in the dispatcher; root `README.md`.
- **Change.** (1) Warn, in the `source:` line, when HEAD is not exactly at a `v*` tag. (2) Greenfield:
  warn on a dirty tree and on a target that is not a Git root, or correct the README sentence; pick
  the smaller. (3) In the plan, print `unchanged` for a byte-identical file and `replace (differs from
  the last installed copy)` for one the team edited.
- **Red case.** One test per item: off-tag source line; dirty greenfield warning; an edited
  framework-owned file named on the update.
- **Done when.** The three cases pass on pwsh and 5.1 plus CP437; smoke installs pass; exit codes are
  unchanged for every existing case.
- **Not in scope.** Refusing an off-tag install (the maintainer installs from `master`); B-469.
- **Tier.** Guarded, step 4.

## B-496 · "Remove the framework" leaves every agent session calling deleted hooks

- **Evidence.** SUB-SESSION: following `docs/upgrade-checklist.md`, "Remove the framework" (source
  `src/core/docs/upgrade-checklist.md:194-204`), by hand took 90 deletions read from
  `framework-ownership.json` and left `.claude/settings.json` still registering the six deleted hooks,
  `CLAUDE.md` still importing the deleted rules file, 37 empty directories, and `.claude/.state/` and
  `.claude/ai-audit.log` newly untracked because `.claude/.gitignore` was itself deleted. The
  checklist's "restore your copy from `.claude/.state/settings.json.pre-update`" restores a file that
  registers `hooks/guard.ps1`. Reverting the install commit works but leaves the audit log.
- **Files.** `src/core/docs/upgrade-checklist.md`.
- **Change.** Rewrite the section as numbered steps: revert the install commit when nothing else
  changed since; otherwise delete the paths `framework-ownership.json` lists as framework-owned, then
  remove the framework's entries under `hooks` in `.claude/settings.json` (and
  `.github/hooks/hooks.json`), then the two import lines in `CLAUDE.md`, then `.claude/.state/` and
  `.claude/ai-audit.log`; say that the pre-update settings copy still holds the registrations.
- **Larger candidate, for the maintainer.** An installer `-Uninstall` that does those steps and
  prints what remains: guarded, step 4, its own entry if wanted.
- **Red case.** Text-only: none.
- **Done when.** A fresh session following only the rewritten section on a scratch install ends with
  no file that names `.claude/hooks/`; `dist/*` rebuilt and validated; `DocTruth` green.
- **Tier.** Ordinary.

## B-497 · `/review` hands back six reviewers' findings with no merge, de-duplication or verdict rule

- **Evidence.** SUB-SESSION, READ only: `review.md` has no severity thresholds or de-duplication step
  where `security-gate.md:106-109` has thresholds; severity scales differ per reviewer;
  `bloat-radar.md:24` flags a single-delegation method `high` while `solid-check.md:21` flags a
  controller action "carrying logic beyond delegating"; `bloat-radar.md:46` flags net lines "more
  than ~3× the count of changed non-test files" against a `/design` budget `design.md` never sets;
  commented-out code is owned by three texts with two thresholds (`AGENTS.md:97` more than 1 line,
  `bloat-radar.md:34` more than 2). Noise is predicted, not measured: verify each quote first.
- **Files.** `src/core/.claude/commands/review.md`; `src/core/.claude/agents/bloat-radar.md`,
  `solid-check.md` (and stack snippets that compose them).
- **Change.** (1) `review.md`: after the reviewers return, merge findings on the same `file:line`,
  keep the highest severity, map every reviewer's scale to one (blocker, should-fix, note), and end
  with one verdict line stating the blocker count. (2) Remove the lines-per-file heuristic. (3) One
  commented-out-code threshold everywhere.
- **Red case.** Text-only. Measurement, if the maintainer wants one: the retained B-412 tree, graded
  on a single verdict line and no duplicate `file:line`.
- **Done when.** The command names the merge and the verdict; the two reviewer texts no longer give
  opposite advice on delegation; `dist/*` rebuilt and validated; `context-footprint -Check` green.
- **Not in scope.** New reviewers; reviewer context size (B-467); the plain-words review (B-425).
- **Tier.** Ordinary unless a `src/stacks/*/files/.claude/**` file changes.

---

## Findings with no brief: the maintainer's decisions

These came out of the same audit and are not work for a fresh session without direction.

1. **Evidence of value.** The one valid real-repository replay (`meta/field-study-results.md`,
   FS-20260826-RERUN-02) found no detectable difference at about twice the cost; measured wins are
   test-first on Claude Code and the secret guard, on synthetic fixtures at n of 6 or less. B-416 is
   the cheapest decisive step and has been rank 1 since 2026-10-19. Ask for the
   `.claude/framework-version.json` stamp with every field report.
2. **Where the effort goes.** Of the 24 entries open before this audit, ten harden self-found edge
   cases, eight measure wording, one is directly field-raised.
3. **Hook cost.** SUB-SESSION: about 1.8 s of hook process time per edit on Claude Code (four
   processes, half of it the outer shell), and three hook processes on every Copilot tool call
   because `hooks.json` has no matcher. A single dispatcher per event is the candidate.
4. **Coverage.** No reviewer or skill covers data access (N+1), concurrency, API compatibility,
   accessibility or i18n; Angular ships six skills to .NET's nine, none stack-specific. No workflow
   drafts a PR, reviews a teammate's PR on Bitbucket, explains a codebase, or investigates without
   fixing.
5. **Always-loaded text.** The rules file is 15.6 KB of dense prose with gapped numbering; the same
   workflow is stated in the rules file, the per-prompt rail and the command.
6. **Team-level signal.** Guard blocks are counted nowhere; `.claude/ai-audit.log` holds timestamp,
   branch and path, is per machine, and nothing reads it; `metrics.ps1` reports `ci_present: true` on
   a bare install because the framework installs `.github/workflows` itself.
7. **Release notes.** The consumer changelog is 290 KB with no "action required" marker; the install
   commit turns the shipped docs-sync workflow red until `/bootstrap` merges.
8. **Packaging and platform (web research by a sub-session, 2026-11-10, not re-verified).** Claude
   Code, Copilot CLI and VS Code read one plugin and marketplace format that a Bitbucket repository
   can host; official .NET and Angular skill packs exist; gitleaks could replace the hand-written
   secret patterns; PowerShell 7 on Linux would open dev containers, Linux CI agents and Copilot's
   cloud agent.
