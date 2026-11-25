# B-551 design: an Angular repository's own end-to-end suite, recorded, run and reviewed (DRAFT 2026-11-25)

> **Status: DRAFT, not locked; nothing ships on the design alone.** Trigger: the maintainer, in chat 2026-11-25: "B551 is my
> highest priority. Let's go ahead and design a fix." Entry: `meta/BACKLOG.md` B-551. Made by three designs (measure-first,
> record-first, extend-first), two judges, one synthesis, and two fresh-session attack rounds (round 1: 2 blockers, 5 majors;
> round 2 on the revision: 2 blockers, 9 majors); every finding is applied here; no third round was run. Citations are OBSERVED
> (read or run 2026-11-25) unless marked INFERRED. Binding: root `AGENTS.md`, WSD-020, WSD-102, WSD-138, WSD-139, WSD-141.

## 1. What this fixes

When an Angular project already has its own browser test suite (Playwright or Cypress), the framework may leave the suite out of
the project's list of check commands; nothing asks the agent to run it after changing a screen it covers, so a journey can come
back broken with build and unit tests green; and the framework's test reviewer may block a correct browser test by a unit-test
rule. Separately, the sample lint file disagrees with the agent's write guard on skipped and focused tests. All of this is read
from the shipped text, never observed in a run. So: measure first on a small Angular shop with a Playwright suite, and change text
only where a run shows the harm and shows the change removing it. The most that ships is one sentence in the Angular `/bootstrap`,
one in the test reviewer, and a lint-sample fix; every other gap closes with a reopen trigger.

## 2. Decisions

1. **Measure first; ship only what a reading shows.** Why: WSD-139 binds every edit here except, possibly, the lint sample (11).
2. **One fixture: an Angular 21 shop with its own Playwright suite and a small API server the suite starts.** Why: one app serves
   the run, record and review questions; real HTTP can occur under review; B-550 can reuse the app without the suite.
3. **The primary field is HARM, an outcome (suite not green at hand-back, its order test gone or weakened, or the grader's hidden
   journey check failing); a disclosed red still counts; readings count only runs that attempted the request.** Why: B-539 phase 1
   read NOT EXERCISED with every tree broken because 5 of 6 runs disclosed it (`meta/eval-results.md:10581-10612`).
4. **Phase 1 runs the shipped tree in the C-D state: prompt A1, then A2 only if A1 shows no harm.** Why: A1 can be foreseen by
   searching the page object, so a green A1 does not show the suite gets run; A2 has a correct way that keeps the suite green and
   a careless way that breaks a journey no unit spec, build or search of `e2e/` reveals.
5. **The record fix is one sentence in the single-stack Angular `/bootstrap`: a suite whose own configuration or script starts the
   app it tests goes in the one `test` row, category cell exactly `test`; a suite aimed at a server it does not start stays out.
   The monorepo copy is held.** Why: one row keeps "six-row inventory" true, so `/rebootstrap`, the hook, the always-loaded rules and
   the CI guide need no edit; the hook drops any other label and lists only the first three test commands, then "(and more)"
   (`src/core/.claude/hooks/session-start.ps1:157-166`), which in a monorepo `.NET` test rows can fill.
6. **Phase 2's candidate table is record-only; a when-to-run policy cell is a later arm, labelled an upper bound.** Why: isolate
   the lever; in B-539 a rule moved 0 of 6, a test already in the suite 6 of 6 (`meta/eval-results.md:10800-10837`).
7. **No new skill, no e2e mode in `add-tests` or `/test`, no always-loaded rule; never choose, scaffold or install Playwright or
   Cypress.** Why: WSD-020 ("Do not add a separate testing skill", `meta/decisions-index.md:19`); B-36 plan `:117`; B-173 for the
   last clause; a model-invoked skill grows always-loaded text, WSD-141's reopen trigger (`meta/workspace-decisions.md:4932`).
8. **The review fix is one sentence in test-critic, Playwright only, that keeps the rest of its non-hermetic bullet; the review
   runs must still find three plants: a fixed wait the sentence does not name, a URL-only check, and a request to an outside
   host.** Why: the plants see a carve-out that blinds the reviewer; test-critic never reads Cypress's `*.cy.ts` (`test-critic.md:16`).
9. **No new test cases; Markdown red-first is a shipped-tree reading, as in commit 63fd21fa.** Why: no `.ps1` behaviour changes.
10. **Each paid step (pilots included) has its own stop, approved in chat before its first paid call; runs start from the main
    session.** Why: WSD-138.
11. **The lint sample is made to agree with the guard on every spec-file row of the guard's cases, checked by a free probe; it
    waits for the maintainer's ruling on WSD-139.** Why: WSD-141 exempts a new opt-in capability, not a shipped sample
    (`meta/workspace-decisions.md:4929-4931`); the sample's skill claims "the same floor" and that claim reached tags.
12. **Changelog lines name only measured hosts and suites; Copilot cells wait for the CLI update, which is the maintainer's.** Why:
    the Copilot CLI here is 1.0.68 (`npm ls -g`), below the 1.0.72 floor (`src/stacks/angular/files/CHANGELOG.md:9`).

## 3. Measurement: draft pre-registration

B-539's form (`meta/eval-results.md:10505-10579`). Committed to `meta/eval-results.md` only after the maintainer approves the
spend. Amendment part 1 (before P0) freezes versions, sha256s, the harness, allowlists and the premise and probe lines; part 2
(after P0, before 1a) freezes P0's files, C-D's normalisation diff and the R state. The registration ships nothing.

**Questions.** On an Angular workspace with a Playwright suite covering a journey: (1) does an agent on the shipped tree hand back
a change that breaks that journey? (2) if so, does the suite's command in the `test` row change that? (3) does the shipped
`/bootstrap` leave the command out, and does the candidate sentence put it in without inventing one where none exists or recording
a suite aimed at someone else's server? (4) does `/review` block a correct Playwright spec for hermeticity, and does the candidate
sentence stop that without losing real findings?

**Fixture** `meta/eval-fixtures/b551-e2e/files/`, hand-written; built and installed under `%TEMP%\b551\` only. The repository holds
the hand-written files, `package-lock.json` and a fixture `.gitignore` (`node_modules/`, `.angular/`, `dist/`, `test-results/`,
`playwright-report/`); the root `.gitignore` has no `node_modules` line.
- **Stack.** Angular 21.2, latest patch pinned exactly (global CLI here 21.2.19); standalone; `@angular/build:application`; unit
  specs on Vitest with jsdom through `@angular/build:unit-test`; angular-eslint, `lintFilePatterns` exactly as `ng add` writes them.
- **App.** Routes `''` (products), `cart`, `checkout`, `confirmation/:id`, `help`. `CartStore`, a signal store, `providedIn:
  'root'`, is injected by the products, cart and checkout pages only: not by confirmation, help, the root shell or any service.
  `OrderService` POSTs to `/api/orders`; `api/server.mjs` (Node `http`, in-memory, port 4301) serves it through `proxy.conf.json`.
- **Unit specs.** `cart.store`, `order.service` (`provideHttpClientTesting`), `products.page`, `checkout.page` ("Enter a valid
  email"). Each provides `CartStore` in its own TestBed; none submits the form.
- **Playwright.** `@playwright/test` 1.57.0, whose `playwright-core` names chromium 1200, cached here (OBSERVED: npx cache
  `playwright-core 1.57.0 -> chromium 1200`; `%LOCALAPPDATA%\ms-playwright\chromium-1200` and its headless shell).
  `playwright.config.ts`: `testDir: 'e2e'`, chromium only, `reporter: 'list'`, `retries: 0`, `actionTimeout: 5000`,
  `baseURL: 'http://localhost:4300'`, two `webServer` entries (the API, url `http://localhost:4301/health`; `npm run start --
  --port 4300`, `timeout: 180000`), each `reuseExistingServer: !process.env.CI`.
- **Suite.** Page objects `e2e/pages/{shop,checkout}.page.ts` (role and label locators); `e2e/fixtures.ts` (`test.extend`);
  `e2e/browse.spec.ts`; `e2e/place-order.spec.ts`: add "Blue mug", see it in the cart and in the checkout summary, fill in the
  customer, Place order, see "Order placed". No credential anywhere (keeps B-552 out).
- **Scripts and CI.** `start`, `build`, `test` (`ng test --watch=false`), `lint`, `e2e` (`playwright test`); `.github/workflows/ci.yml`
  runs `npm ci`, lint, build, `npm test`, `npx playwright install --with-deps chromium`, `npm run e2e`.
- **Variants.** `no-suite.patch` (no `e2e/`, config, package, script or CI steps; B-550 reuses it); `remote-suite.patch` (no
  `webServer`; `baseURL` from `E2E_BASE_URL`, which CI sets to `https://staging.example.test`); `review.patch`; `table-e2e.patch`.

**Prompts.**
- **A1:** "Add a checkbox labelled 'I accept the terms' to the checkout form, and keep the Place order button disabled until it is
  ticked." Always springs: build and unit stay green; `place-order.spec.ts` stops at the disabled button until its page object
  ticks the box. **DONE** (static): the checkout template gains a checkbox, and Place order's disabled binding references it or its
  form control. A run that adds no checkbox is **DECLINED**.
- **A2:** "Only the products, cart and checkout pages use CartStore, but it is provided for the whole app. Provide it only for
  those three pages." Correct: one provider whose subtree is exactly those routes (a componentless parent route with
  `providers: [CartStore]`); the suite stays green. Careless: `providers: [CartStore]` on each route; route injectors are cached per
  route (INFERRED from the Angular 21.1 router source, `getOrCreateRouteInjectorIfNeeded`), so each page gets its own store, every
  page opens, unit specs stay green, and the suite goes red at the cart page. **DONE**: `CartStore` is not `providedIn` `'root'`,
  `'any'` or `'platform'`, and is absent from the App component, `main.ts` and `appConfig`. **SCOPE-WIDE**: a provider whose
  subtree includes `help` or `confirmation`; reported and replaced like DECLINED.
- **Leg 2,** only when leg 1 left `src/` unchanged (the plan gate): "Go ahead." on `--resume`.
- **`/bootstrap` cells:** B-539 phase 4's legs and fixed answer, at most four legs.
- **R cells:** one leg, `/review`, in the **R state**: C-D's tree committed as the baseline, `review.patch` applied uncommitted.
  The patch holds A1's change with its page-object step; one good new spec making real HTTP calls to the API server the suite
  starts; `e2e/confirmation.spec.ts` planting `await new Promise(r => setTimeout(r, 2000))` and an oracle that checks only the
  URL; and `e2e/stock.spec.ts` planting `request.get('https://api.example.test/stock')`.

**Premise check** (no model call; three fresh copies; result lines in amendment part 1).
- Baseline: build exit 0; unit specs pass; `ng lint` exit 0; `CI=1 npm run e2e` passes, downloads nothing, cold wall time recorded
  (must finish well under 120 s, the host's default command timeout). A grep confirms only the three shop pages inject `CartStore`.
- A1 reference without e2e edits: build and unit green, `place-order.spec.ts` red; with the page object updated: all green. A2
  careless reference: build and unit green, `place-order.spec.ts` red at the cart page; A2 correct reference: all green.
- The grader's hidden journey spec, run under the grader's own frozen config and `webServer` entries: green on the baseline, on
  both A1 references and on the A2 correct reference; red on the A2 careless reference. (A1's careless tree reads HARM through the
  suite, not the hidden spec.)
- The installed guard passes the references' writes (piped Write events, `EXIT=0`).
- `esbuild.exe`, the rollup and lmdb native bindings, `ng serve`, Vitest and the headless shell run under code integrity; refused in
  all three copies: stop, CANNOT EXAMINE on this host, and the maintainer picks another.

**Lint probe** (free, in a premise copy). Merge the shipped `eslint-standards.sample.mjs` into `eslint.config.js` as
`enforce-standards` says; lint one probe spec per row holding **every** spec-file row of `src/core/tests/hooks/fixtures/
guard-cases.ps1`, blocked and allowed: **MISSED** (a blocked row passes lint), **OVER** (an allowed row fails). Known before the
probe: MISSED on titled `test.fixme('t', …)`, `test.describe.fixme`, `test.describe.serial.only`, `test.skip(true, …)`,
`test.skip.concurrent('t')`, `test.skip.failing('t')`, `xcontext`, `xspecify`, `specify.only`; OVER on Vitest's
`context.skip('flaky on CI')` (`:154`), which the guard allows because no argument follows the title. Then plant a `test.only` in
`e2e/` and run `npm run lint`: **UNREACHED** if no error, a property of the `ng add` default. Before and after the candidate; the
probe spec and its sha256 are kept with the registration as the re-runnable case.

**Framework under test.** `dist/angular` of the registration commit from a `git archive` export, installed by its own
`install.ps1` with `ATL_SOURCE_CHECK=off`.
- **P0** (paid, inside 1a's stop): one shipped `/bootstrap` on the fixture, reported as a first look at R1 (its row and its
  `Conventions > Testing`, quoted).
- **C-D**: P0's tree with every invocation of the suite (`npm run e2e`, `npx playwright test`, `playwright test`) stripped from every
  file P0 wrote, framework names kept, and the `test` row left holding `npm test` alone; the diff goes verbatim in part 2. The worst
  case `bootstrap.md:22` and `:181` allow.

**Arms**, each differing from its comparison in one thing: **C-D**; **T-table** (C-D with the `test` row holding
`` `npm test` `` and `` `npm run e2e` ``, both evidence paths, policy "non-mutating; `npm run e2e` starts its own servers", no
when-to-run wording); **C-B** (unbootstrapped, shipped tree); **T-B** (C-B plus `meta/eval-fixtures/target-patches/
b551-bootstrap-e2e.patch`, section 4's sentence); **T-B0** (T-B on `no-suite.patch`); **T-B-remote** (T-B on `remote-suite.patch`);
**C-R / T-R** (the R state with the shipped test-critic or `b551-critic.patch`). Patches cut per `DEVELOPING.md` from a fresh
install.

**Harness**, rebuilt from B-467's amendment, which needed five failed pilots to run `/review` headless
(`meta/eval-results.md:7066-7076`); its `approve-readonly.ps1` lives outside the repository (`%TEMP%\b467\`, sha256
`f6bc93af1231`), reused if present, else rewritten from that description. Same in every arm and cell:
- Claude Code at a frozen version, `--model sonnet`, `--setting-sources project,local`, `--permission-mode acceptEdits`, an
  allowlist; `DISABLE_AUTOUPDATER=1`, `PLAYWRIGHT_HTML_OPEN=never`; `CLAUDE*` and `ANTHROPIC*` removed; `CI` unset.
- Each run's TEMP and TMP in its own folder, passed with `--add-dir`; call-form prefix rules for `scripts/review-scope.ps1` and
  `scripts/test-weakening-scan.ps1`; the read-only approval hook in the fixture's git-ignored `.claude/settings.local.json`, extended
  with `Select`, `Select-Object`, `ForEach-Object` and their aliases and the npm commands below, seen right on allow and deny cases
  before any run. A command it does not approve is refused (DENIED). It approves read-only segments in the nested session; a
  consumer's `/review` runs under the consumer's own permissions, which this does not reproduce.
- **Allowed:** Read, Grep, Glob, Edit, Write (not in R cells), Skill, Agent, TodoWrite; `npm test`; `npm run build|lint|start`;
  `npm run e2e` and `npx playwright test` without `--ui`, `--debug`, `--reporter=html` or `show-report`; `npx ng build|test|serve|lint`;
  `node api/server.mjs`; read-only `git`; web requests to `localhost` and `127.0.0.1`; B-539's helper cmdlets, `Stop-Process -Id`
  only. **Refused:** `npm install|i|ci|add`, `npx playwright install`, `npx cypress`, `npm init`, any other `node`; an install
  attempt is reported as INSTALL-TRIED, not invalid.
- **Caps:** 1.00 USD a leg (A), 2.00 (R), 3.00 (`/bootstrap`, counted as 4.00 in the start rule).
- **Hygiene:** one run per invocation from a fresh copy; arms alternate; `node_modules` from one prepared install, its
  `.package-lock.json` sha256 checked before and after; ports 4300 and 4301 free before each run. Driver, grader, hidden spec, hook,
  allowlists and evidence in `%TEMP%\b551\`.

**Valid run.** Every leg ends in a terminal success `result`; one Claude Code version and model across `system/init`; leg 1's
SessionStart and UserPromptSubmit hooks succeeded; A cells: `src/` changed; T-table: the session-start context names both commands;
R cells: test-critic returned its table, else the run is repeated once and a second miss leaves the slot not settled (other missing
reviewers are reported). Invalid: **POLICY-BLOCKED** (repeat, at most four attempts a slot); **DENIED** (a refused build, test,
lint or e2e; repeat once); **MUTATED-DEPS**; **USAGE-LIMIT**; **ENV** (a missing browser, a server failing on an unmodified tree,
or, from a per-run scan of CodeIntegrity events 3077 and 3033 and of tool results for `0x800711C7` or "Application Control", any
refusal on a run-folder, `node_modules` or `ms-playwright` path; void, repeat once). DECLINED and SCOPE-WIDE runs are replaced, at
most two a cell.

**Graded fields** (after the runs, on retained trees and transcripts; hand-read fields blind under random ids, sentence quoted).
- **HARM** (primary, A cells), any of: on a copy of the final tree with both ports free, `CI=1 npm run e2e` is not green or skips
  or fixmes a test; the order test is absent from the list reporter's executed titles, skipped, or no longer asserts "Order placed";
  the hidden journey spec fails. A policy block, busy port or unrelated server failure is CANNOT-EXAMINE, retried once, never harm.
- **RAN-E2E**: after the last write under `src/` or `e2e/`, `npm run e2e` or `playwright test` returned a non-refused result;
  **NARROWED** if it named a spec, `--grep` or `--project`. **CORRECT-DESIGN** (A2): one provider whose subtree is exactly the
  three shop routes.
- Reported: SAID (the closing message says the suite was not run, is red, or a journey is unverified); E2E-EDITED; REUSED (through
  the existing page object or fixture); NEW-HARNESS (a new runner, config or test dependency, or INSTALL-TRIED); build and unit
  results; cost, wall time, output tokens; Fisher's p (3/6 v 0/6 = 0.18; 6/6 v 0/6 = 0.002).
- **`/bootstrap` cells** (mechanical). Command classes: unit = `npm test`, `npm run test`, `ng test`, `npx ng test`; e2e =
  `npm run e2e`, `npx playwright test`, `playwright test`; the spelling is reported. **HOOK-SHOWN**: the frozen `session-start.ps1`
  on the final tree lists exactly one command of each class and no install command. **UNIT-KEPT**; **SIX** (six categories, one row
  each); **CLEAN** (only documents changed); **INVENTED** (T-B0: any e2e or browser command anywhere in `AGENTS.md`);
  **REMOTE-RECORDED** (T-B-remote: any Verification Commands row, or any `AGENTS.md` text telling the agent to run the suite, holding
  an e2e-class invocation).
- **R cells:** **WRONG-BLOCK** (a `high` test-critic row or a `/review` blocker on the good spec or its page object, for
  non-hermetic code, real HTTP, the served app or browser, over-mocking, no TestBed, or "should be a unit test"); **FOUND-WAIT**,
  **FOUND-ORACLE**, **FOUND-EXTERNAL** (each plant flagged at any severity); CITES (reported: what the wrong finding cites).

**Readings**, fixed now, on 6 valid runs a cell unless stated; a cell the stop leaves short reads "not settled". Shipping is the
maintainer's call.
- **1a** (A1 on C-D): **REPRODUCED**, HARM in 3 or more: phase 2 on A1. **NO HARM**, HARM in at most 1: run A2. 2: not settled.
  Reported: **EXTENDS WITHOUT REUSE** (3 or more edit `e2e/` around the page object, or any NEW-HARNESS), R3's trigger.
- **A2** (on C-D, after 1a NO HARM): **REPRODUCED**, HARM in 3 or more: phase 2 on A2. **NO HARM**, at most 1: R1 and R2 close
  (CORRECT-DESIGN and RAN-E2E reported). 2: not settled.
- **Phase 2** (C-D and T-table interleaved, on the prompt that reproduced): C HARM in 2 or fewer: **C NOT STABLE**, nothing else
  read. **RECORD FIXES IT**: T HARM at most 1 and at least 3 fewer than C: phase 3. **NO DIFFERENCE**: within 1; the record lever
  closes, and a policy-cell arm may be registered as its own entry, an upper bound. Otherwise **INCONCLUSIVE**.
- **Phase 3** (C-B and T-B interleaved, 6 each; then T-B0 and T-B-remote, 3 each): **C RECORDS IT**, C-B HOOK-SHOWN in 5 or more:
  R1 closes. **C DROPS IT**, in 3 or fewer (4: not settled). **T ADDS IT**: HOOK-SHOWN, UNIT-KEPT, SIX and CLEAN in 5 or more T-B,
  HOOK-SHOWN at least 3 more than C-B. **SAFE**: in 0 of 3 T-B0 runs INVENTED or a failed SIX or CLEAN, and in 0 of 3 T-B-remote
  runs REMOTE-RECORDED or a failed SIX or CLEAN. A does-no-harm check, not a proof: 0 of 3 still occurs at a true 30% rate with
  p = 0.34. Fit to propose: C DROPS IT, T ADDS IT and SAFE.
- **1b** (C-R): **REPRODUCED**, WRONG-BLOCK in 3 or more: phase 2R. **NOT SHOWN**, at most 1: R5 closes. 2: not settled.
  **NOT AUDITED** (no `e2e/` file named in 5 or more): reported, R5 closes.
- **Phase 2R** (T-R 6, C-R 3, interleaved): C-R WRONG-BLOCK 0 of 3: **C NOT STABLE**. **LENS FIXES**: T-R WRONG-BLOCK at most 1 and
  at least 3 fewer than 1b, and each FOUND field no lower than 1b's count minus 1. **LENS BLINDS**: any FOUND field drops by 2 or
  more; nothing ships. Otherwise **INCONCLUSIVE**.

**Stops.** A run starts only if its step's spend plus the run's caps stays within the stop. Stops leave room for two replacements.
Use-run cost is INFERRED (B-539's .NET runs 0.19 to 0.26 USD; no Angular fixture has run).

| step | runs | expected USD | stop USD |
|---|---|---|---|
| 1a, with P0 | 1 + 6 (+2) | 3.0 to 5.7 | 8.50 |
| A2, after 1a NO HARM | 6 (+2) | 2.0 to 4.9 | 7.50 |
| R pilots (uncounted) | up to 5 | 1.0 to 6.6 | 8.00 |
| 1b, after a clean pilot | 6 | 6.1 to 7.9 (a review 1.02 to 1.31, `meta/eval-results.md:9750`) | 11.00 |
| 2 | 12 (+4) | 4.0 to 9.8 | 12.00 |
| 3 | 18 valid, about 27 attempts | 18.6 to 22.7 (B-539 phase 4: 0.69 to 0.84 a run, 22 attempts for 14 valid) | 32.00 |
| 2R | 9 | 9.2 to 11.8 | 15.00 |

Ceiling about 94 USD; if 1a, A2, the pilots and 1b close their items, about 12 to 25.

**Copilot CLI**, after 2026-12-01, the CLI at 1.0.72 or later, and the driver extended (B-539's is Claude-only): 1a only, plus
phase 2's T-table if 1a reproduces there; valid runs also need the session-start context; 20 attempts. No R cell: the review skill
loaded in none of 39 field sessions (`meta/field-reports.md:399`; B-530).

**Not shown:** Cypress; slow or flaky suites (this one is fast: an upper bound); a machine without the suite's browsers; a suite
aimed at a shared server beyond T-B-remote's recording check; an explicit request to write an e2e test; `/feature` step 4
(natural-language runs never load `feature.md`); `/rebootstrap`; the CI guide's merge gate; the monorepo, where `.NET` test rows
share the hook's three-command list and a .NET Playwright project is recorded by the per-project rule whatever server it targets
(monorepo `bootstrap.md:22`); VS Code; other models.

**Order of work:** the maintainer's yes to the npm download; build the fixture, premise check and lint probe; registration commit
with amendment part 1; approvals in chat; P0, then part 2; 1a, then A2 if 1a reads NO HARM; R pilots, then 1b; results commits;
conditional phases; Copilot cells after 2026-12-01; ship commits. No registration, results or ship commit while a release is
between push and tag. B-551's closure rides in the last results or ship commit.

## 4. Changes, each gated by a reading

**R1: the suite's command can be left out of the table** (`bootstrap.md:22`, `:181`; the hook and the CI guide's merge gate read
only the table, `session-start.ps1:157-166`, `ci-integration.md:49-50`).
- **File:** `src/stacks/angular/files/.claude/commands/bootstrap.md:22`. Monorepo sibling reviewed and held (decision 5; section 6).
  Not edited: `rebootstrap.md` (it re-applies `/bootstrap`'s rules; "six-row" stays true), `:181`, the hook, the rules, the CI guide.
- **Wording**, after "a manifest script may be recorded as its package-manager invocation.": "When the evidence also runs a
  Playwright or Cypress suite whose own configuration or script starts the application it tests, put its exact command in the
  command cell and its evidence path in the evidence cell of the one **test** row, whose category cell stays exactly `test`: an
  end-to-end suite is not a seventh category. A suite aimed at a server it does not start stays out of the table."
- **Tier:** guarded. **Gated by:** 1a or A2 REPRODUCED, phase 2 RECORD FIXES IT, phase 3 C DROPS IT, T ADDS IT and SAFE.

**R5: the test reviewer counts real HTTP as non-hermetic**, `high` if it will flake (`test-critic.md:28`), and a `high` finding
becomes a blocker (`src/core/.claude/commands/review.md:112-113`).
- **Files:** `src/stacks/angular/files/.claude/agents/test-critic.md:28`; monorepo `src/stacks/monorepo/files/.claude/agents/test-critic.md:31`,
  labelled "(Angular)" because .NET tests share the bullet, unmeasured. The Copilot wrapper reads the file (`test-critic.agent.md:9`).
- **Wording**, appended to the non-hermetic bullet: "A Playwright spec in its configuration's test folder drives the application,
  and any server, that its own configuration starts: requests to those are not by themselves non-hermetic. The rest of this bullet
  still applies, and a request to any other host, including a shared or third-party backend the started application forwards to,
  stays non-hermetic."
- **Tier:** guarded. **Gated by:** 1b REPRODUCED, then 2R LENS FIXES and not LENS BLINDS.

**R6a: the lint sample disagrees with the guard** on the rows listed under the lint probe, while `enforce-standards/SKILL.md:15-19`
claims "the same floor".
- **File:** `src/stacks/angular/files/scripts/ci/eslint-standards.sample.mjs` (reaches `dist/monorepo` through the overlay,
  `scripts/build.ps1:54`).
- **Change:** selectors and `RUNNER`/`FOCUS_SKIP_ALIAS` lists widened until the probe reads no MISSED, and the declaration-form skip
  branch at `:52` requiring an argument after the title (`[arguments.1]`), as the guard does, so `context.skip('reason')` passes;
  the `:32-38` comment and the `:53` message updated. Exact selectors are frozen from the probe's after-run, not designed here
  (esquery behaviour INFERRED, not executed).
- **Tier:** ordinary; an escaped defect (the claim, `b1e23f1c`, is in every tag from v0.95.0 to v0.99.0), so the commit body names the probe spec and its
  sha256 as the case that would have caught it, the cause, why no gate caught it (no ESLint harness in the repository), and "check
  added: none, accepted because the probe is free and re-runnable". **Gated by:** MISSED or OVER before, neither after, and the
  maintainer's ruling (question 1).

**Changelog lines**, root `CHANGELOG.md` and the current `## <version> — Unreleased` head of each affected stack changelog (dotnet
gets no line).
- R1 (Angular only): "**`/bootstrap` now records your end-to-end suite.** If CI or `package.json` runs a Playwright or Cypress suite
  that starts your app itself, the **test** row of `AGENTS.md` › Verification Commands names both commands, so the agent sees the
  suite at the start of each session. Checked with a Playwright suite on Claude Code."
- R5 (Angular; monorepo "in the Angular part of your repository"): "**`/review` no longer treats your Playwright suite's own app as a
  network dependency.** The test reviewer judged Playwright specs by the unit-test rule that real HTTP is unstable, which could block
  a correct browser test; requests to the app and servers the suite starts no longer count, while calls to any other host still
  do. Checked on Claude Code."
- R6a (Angular, monorepo): "**The standards lint sample now agrees with the write guard on focused and skipped tests,** including
  Playwright's titled `test.fixme('…', …)` and `test.describe.fixme`, `test.describe.serial.only`, `xcontext`, `xspecify` and
  `specify.only`, and no longer flags Vitest's `context.skip('reason')`. If you merged `scripts/ci/eslint-standards.sample.mjs`,
  merge it again, and check that your lint target covers your end-to-end folder."

**Footprint.** No always-loaded text changes (`static.claude` 34,013 of 40,000 Angular, `meta/context-footprint.json`); command
and agent bodies are ondemand-info, "reported but never policy-gated" (`scripts/context-footprint.ps1:457`): review, then `-Update`.

## 5. Tests and verification

- **No new test cases** (decision 9); `src/core/tests/hooks/SessionStartTestEntryPoints.Tests.ps1` and `BootstrapBaseline.Tests.ps1`
  stay green under `pwsh` for the R1 ship.
- **Guarded commits** (R1; R5): body of at most six lines (what changed; the harm, citing the `meta/eval-results.md` entry; the
  smaller fix rejected, a seventh category or a rule; what could be let through: an `e2e`-labelled row the hook drops, a browser
  suite copied into a merge gate with no browser, a suite started against the wrong server; cost-benefit: "no always-loaded change,
  about 450 characters in an on-demand body; unmeasured: `/rebootstrap`" plus, for R5, "the monorepo copy"). Red-first trailer in
  63fd21fa's form: "Red-first: shipped tree, phase 3 C-B HOOK-SHOWN n of 6 and phase 2 C HARM n of 6 (meta/eval-results.md);
  text-only Markdown has no unit test to show red." R5: 1b C-R WRONG-BLOCK n of 6. Guarded step 4 does not apply: it names only the
  installers, `adoption-archive.ps1`, `guard.ps1`, the policy files and root `AGENTS.md`.
- **R6a** (ordinary): the probe's before and after lines and the escaped-defect sentences in the commit body.
- Every ship follows root `AGENTS.md` › Verification for `src/**`; records follow it for `meta/*.md`. Gate from the repository when
  the tree holds only this work's edits, else from a worktree outside it; push with `.claude/scripts/push-and-check.ps1`.

## 6. Closed without change, each with its reopen trigger

One WSD entry (at most ten lines, indexed in `meta/decisions-index.md`) in the commit that closes B-551 carries the triggers people
would re-litigate: R1 and R2, R3, R5, R5b. The rest go as CLOSED lines in `meta/BACKLOG-DONE.md` (WSD-106).
- **R1 and R2** close on A2 NO HARM, NO DIFFERENCE or C RECORDS IT. Reopen: a field report or run in which a bootstrapped Angular
  repository's evidenced e2e suite is handed back red or unrun after a change to a journey it covers.
- **R2's narrowing half, the suite runs only whole** (`feature.md/verify:1` and siblings). Reopen: an agent skipping an evidenced
  suite for its length, or reporting a narrowed run as the suite.
- **R3, extending the suite** (`add-tests/SKILL.md:12`; `test.md:33-35`). Reopen: EXTENDS WITHOUT REUSE or any NEW-HARNESS, or a
  field report of an explicit e2e-test request declined or misrouted. Candidate then: Test leanness #13 adds "and an end-to-end
  suite's page objects and fixtures", measured as its own arm.
- **R5** closes on NOT SHOWN or NOT AUDITED. Reopen: a run or field report of `/review` blocking a browser spec for hermeticity,
  Copilot included once B-530 shows the review running there.
- **R5b, the defaults' "no real network" names no test level** (`defaults.md:137`). In the R state test-critic reads `AGENTS.md >
  Conventions > Testing` (`test-critic.md:17`), not the defaults, so no arm sees this edit; an unbootstrapped repository's
  Conventions points to the defaults. Reopen: CITES names the defaults or a Conventions line built from them in 2 or more
  WRONG-BLOCK runs. Candidate then: "Unit and component tests must be …", with an arm in an unbootstrapped state.
- CLOSED lines: **R4**, single-stack `/feature` step 4 (angular `subtasks:4` against monorepo `subtasks:13`; reopen: a
  `/feature`-invoked Angular run on a repository with no harness that adds Playwright or Cypress or claims e2e verification it did
  not run). **R1's monorepo copy** (reopen: R1 ships and a monorepo run or field report shows the e2e command hidden or dropped).
  **R6b**, lint may not reach `e2e/` (reopen: a field report of a focused or skipped e2e spec passing a team's lint; if the probe
  reads UNREACHED on the `ng add` default, it is filed only as a false green ordinary use triggers, per WSD-124). **The CI guide's
  merge gate, the pre-bootstrap entry-point list, `/adopt`'s toolchain list** (`ci-integration.md:49-50`; `session-start.ps1:138-141`;
  `src/stacks/angular/snippets/.claude/commands/adopt.md/adopt-toolchain-files` and its monorepo sibling; reopen: an e2e step dropped
  from a merge gate built from the guide, or an adoption that misses an existing suite). **The hook's multi-command `test` row has
  no test case** (reopen: any change to its test-row parsing adds one).

## 7. Out of scope

B-552 (this fixture holds no credential); B-550 (shares only the base app); everything in decision 7; a hook that runs any suite
(WSD-102); a seventh category; .NET; VS Code cells; a Cypress fixture.

## 8. Open questions for the maintainer

1. **May the free lint probe count as WSD-139's failing check for the lint sample?** It runs the shipped file against the guard's
   own cases, and the sample's skill claims "the same floor". Recommended: yes; ship R6a on MISSED or OVER before and neither after,
   whatever UNREACHED reads.
2. **Approve the npm download and the first stop?** The fixture needs Angular 21.2, Vitest, angular-eslint and `@playwright/test`
   1.57.0 from the npm registry; no browser download. Recommended: yes to the download and to 1a's 8.50 USD stop now; A2 (7.50),
   the R pilots (8.00) and 1b (11.00) asked separately when reached.
3. **Ship on Claude Code readings alone?** Recommended: yes, changelog lines naming Claude Code only (as WSD-140); the Copilot 1a
   cell in December after you update the CLI, ahead of B-530 only if 1a reproduces on Claude Code.
