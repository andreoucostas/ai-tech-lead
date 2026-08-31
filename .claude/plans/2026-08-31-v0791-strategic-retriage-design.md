# v0.79.1 strategic re-triage and bounded repair design

**Status:** LOCKED AFTER ADVERSARIAL CRITIQUE; B-211 AMENDMENT LOCKED AFTER INDEPENDENT SCOPE CRITIQUE (2026-08-31)
**Baseline:** v0.79.0 (`95cadcffa2e15bc046e283098cf5690d28626449`)
**Target:** v0.79.1
**Product items:** B-134 (minimal arm only), B-207
**Supported-host evidence item:** B-211
**Decision-only item:** B-208
**No-growth constraint:** no new suite, test case, helper, fixture, result, CI leg, product subsystem,
or always-loaded rule block. B-211 may correct two existing expressions in the existing shared test
helper; it does not authorize a new helper or abstraction.

## 1. Premise re-triage and selection

The open backlog was reviewed as a set rather than consumed in file order. The current ranked work is:

1. **B-207** — observed supported-host test-truth defect. Native Windows PowerShell 5.1 reproduced
   `31 passed, 1 failed, 1 skipped` with Git Bash interpreting the nested `>/dev/null` argument as
   a repository-relative Windows path. PowerShell 7 passes the same file. The doctor product is not
   implicated.
2. **B-134, minimal arm** — all three stack-specific bootstrap commands still authorize replacing
   `Codebase Context` with “real findings from this codebase”, including users and critical journeys.
   Code can establish an implemented surface but cannot establish product intent, real users, or
   value. The prior independent review accepted this defect and reduced the proportionate remedy to
   roughly one sentence. These command bodies are on demand, so the old static-context blocker does
   not apply.
3. **B-136 and B-174** — retain as the next bounded implementation candidates. B-42 remains the
   highest-value evidence item but requires an independent participant; B-49/B-43 remain the
   deliberate live-fire/cadence lane.

The first critique correctly rejected age, inconvenience, and external execution as closure reasons.
The following entries remain open because their records still name distinct, evidence-bearing work:
B-42, B-43, B-49, B-72, B-112, B-129, B-133, B-136, B-159, B-160, and B-174. In particular B-49
still says `REMAINS OPEN`; B-72/B-112 retain named instrument obligations; B-129 retains its frozen
live batch; B-133 is explicitly sequenced after B-42; and B-159/B-160 retain discriminating
measurements. None is archived merely because it is blocked or `PARTIALLY DONE`.

Twelve entries leave the active backlog only after the following item-specific premise disposition.
Their full histories move intact to `BACKLOG-DONE.md` below a current disposition and reopen trigger:

| Item | Remaining obligation and current disposition | Reopen trigger |
|---|---|---|
| B-15 | Verify the shipped Jenkins/Bamboo required-build recipe in a local Jenkins container. The premise is superseded: the current reference recipes already separate framework-state and repository-evidenced code legs and explicitly put the real oracle at the consumer's Bitbucket merge check. A local container cannot prove site-specific plugins, agent labels, toolchains, status reporting, or merge blocking. | A consumer reports a concrete recipe defect, or a portable framework-owned oracle can prove the site-independent contract. |
| B-20 | Build coverage/diff-mutation infrastructure from a missing plan. Rejected: no current escaped-defect evidence identifies this as the smallest diagnostic gap, and rebuilding an L-sized coverage/mutation program would be test growth without a decision. | A repeated defect class escapes existing focused gates specifically because changed production paths are unmeasured, and a smaller direct oracle cannot close it. |
| B-96 | Run the old six-run enriched-map arm. Retire it explicitly as incompatible: its frozen contract requires Arm 1's machine-produced map verbatim, but the current runner exposes no produced-map input and its enriched fixture is maintainer-authored. The old host/model/product comparison cannot be reconstructed; later warehouse runs are not substituted as evidence of B-96's effect. | A current decision needs map-content causality and pre-registers a same-run control/treatment with an immutable produced-map handoff and red-tested grader. |
| B-97 | Choose automatic safe migration or formally assisted migration for unmigrated Claude consumers. Choose **assisted**: the update-delivered carrier, doctor `PENDING` row, session discovery, and README already state the one-time manual migration and preserve consumer-owned `CLAUDE.md`. Existing populated context is not rewritten. | A supported host stops delivering/discovering the carrier, or direct evidence shows the documented manual migration is unsafe or materially unusable. |
| B-138 | Replace process-per-assertion execution with persistent runspaces/shells when the ceiling is outgrown. Rejected by the fresh audit: B-170 removed local duplication, the existing runner emits per-file timings, and exact-baseline v0.79.0 CI run `33367125653` passed all eight required jobs without runtime failure. The configured **local** ceilings remain 650 seconds for the meta suite and 1,530 seconds total and are deliberately not CI thresholds. | Repeated configured local-budget breaches on an idle maintainer host, or observed CI process contention that causes release failure; diagnose from existing per-file timings before changing architecture. |
| B-140 | The completed portability census classifies 34/42 scenarios candidate-portable and eight typed-event-dependent. Current Codex 0.149.0 exposes headless `exec`, JSONL, output-schema/last-message, and ephemeral controls but no native spend or timeout flag; WSD-054 already demonstrated one-off programmatic Sol for final-artifact grading. Reject a permanent executor: B-129, the observed budget harm, is routing-dependent and explicitly excluded, while no selected artifact-only decision needs recurring integration. | Repeated artifact-only eval work shows concrete ad-hoc executor cost/defect and has an immutable final-state oracle that can be red-tested on Codex; only then re-probe the current contract and design permanence. |
| B-161 | State the hermetic meta-gate rule and decide enforceability. Add the compact maintainer rule in this delivery; retain it as evidence guidance because no generic gate can distinguish deliberate lifecycle inputs from ambient discovery honestly. | A second live-state meta-gate defect, or a cheap structural boundary that can reject ambient discovery without rejecting explicit lifecycle inputs. |
| B-165 | Record the semantic inert-check shapes and assess detection. Active guidance beside Maintenance rule 4 will map all four: literal/syntactically inert assertions (already covered), exit-domain collisions, empty/absent conflated with cannot-examine, and normalization/comparison that stops comparing (with B-167's byte rule). Reject a generic mutation framework as disproportionate. | The same unaddressed inert shape recurs and a shared subject-level mutation seam can cover it more cheaply than per-suite machinery. |
| B-166 | State Windows/Linux as the two CI platform legs and ask whether each changed function is in frozen scope. The platform rule already exists; add the compact scope question to the maintainer review contract. Add no proxy CI leg. | A new scope-creep or platform-axis escape survives the explicit review question. |
| B-167 | Record reviewer-side false-green disciplines. Preserve the cases in completed history and add the missing maintainer guidance: trust process exit, red-test filters on positive and negative controls, and compare bytes/hashes for equality claims. Add no checker-of-checkers. | A distinct reviewer false-green mechanism not covered by those three disciplines. |
| B-176 | Add duplicate-category handling to four readers for a duplicate that does not exist. Rejected as hypothetical cross-reader/test growth; the catalog is framework-owned and currently unique. | An actual duplicate/disagreement appears, or the catalog becomes an extension surface written outside the composer. |
| B-208 | Decide inherited exported `SHELLOPTS=errexit` support. Record deliberate non-support in WSD-065; ordinary documented executed-child invocations remain supported. | A documented supported invocation exports the option, or a real Windows/Linux consumer incident arises under a documented recipe. |

B-134 and B-207 are not counted in that twelve-entry re-triage set. They and the subsequently
discovered B-211 move separately as completed delivery records only after the candidate is verified,
making the exact movement set fifteen entries and leaving the eleven open items listed above.

## 2. B-134 minimal product correction

Edit the three stack whole-files, including the monorepo sibling required by WSD-015:

- `src/stacks/dotnet/files/.claude/commands/bootstrap.md`
- `src/stacks/angular/files/.claude/commands/bootstrap.md`
- `src/stacks/monorepo/files/.claude/commands/bootstrap.md`

Immediately after the shared “real findings” lead, add the same compact authority boundary:

> Code establishes implemented surfaces, not product intent or actual user behavior or value. Label
> code-derived context as implementation observations. Leave intended purpose and target users
> unknown unless supplied by a named person or role authorized to decide them; leave actual behavior
> and value unknown unless supported by direct research or operational evidence.

Do not add a provenance schema, product frame, journey artifact, research store, product reviewer,
questionnaire, hook, or static `CLAUDE.md` rule. The refreshed bootstrap command reaches greenfield,
brownfield, and update installs, but update preserves an existing consumer-owned `CLAUDE.md` and its
populated `Codebase Context`; disclose that the change is not an automatic correction of existing
context. Do not widen into `/rebootstrap` or `/design`: the
bounded scan found no equivalent “real findings from code” instruction there. No stochastic live
eval is claimed; the deliverable is correction of an objectively invalid evidence/authority rule.

## 3. B-207 existing-result repair

Edit only `src/core/tests/hooks/FrameworkDoctor.Tests.ps1` inside the existing
`Copilot CLI visibility is controlled...` result.

For the Git-for-Windows branch:

1. Preserve the controlled `PATH`, `hash -r`, nested Bash, and four existing visibility worlds.
2. Send the Bash program through `Invoke-RawProcess` with the exact separate arguments
   `@('--noprofile','--norc','-s','_', $posixBin, $posixBash)`. Treat `_` as a placeholder and
   normalize the final two path arguments to `$1`/`$2` inside the stdin program. Do not send shell
   syntax through Windows PowerShell 5.1 native-argument marshalling.
3. Emit an exact case-sensitive `yes` or `no` sentinel from the stdin program.
4. Fail setup on nonzero status, any stderr, empty stdout, or any other stdout. Derive `$sSetup`
   only from the exact sentinel.
5. Leave the non-Git-Bash branch, doctor scripts, harness helper, suite shape, `It` count, skip count,
   and product behavior unchanged.

The existing result is the oracle. No permanent regression case is added. The pre-change native
5.1 run is the observed red world. After the change, mutate only the scratch candidate to emit an
unexpected sentinel and show the same existing result fails before exact restoration.

**Implementation observation amending step 2.** The first candidate made the existing result fail
32/1 under PowerShell 7: this Git-for-Windows launch fixed `$0` to `/usr/bin/bash` and exposed `_` as
`$1`, so the two paths arrived as `$2`/`$3` rather than the reviewed standard-shell assumption. The
stdin program therefore discards leading positional placeholders until exactly the final two path
arguments remain, rejects any other cardinality, and only then uses `$1`/`$2`. This preserves the
reviewed separate-argument transport and works under both observed and standard `bash -s` numbering.
The first legacy-host run then exposed a separate Windows PowerShell 5.1 environment-provider edge:
earlier controlled `$env:PATH` assignments left both inherited `Path` and fixture `PATH`, which made
`Start-Process` reject its environment dictionary. The Git-for-Windows raw branch now collapses that
test-owned duplicate to one controlled process `PATH` before launch and restores one key afterward;
PowerShell 7 and the non-Git branch stay unchanged.

### B-211 amendment: quote-stable interpreter control

The required native-5.1 rerun exposed a second, independent test-truth defect. The documented
`ATL_TEST_PYTHON` override named a real interpreter, but `Resolve-HostPython` passed
`sys.stdout.write("ok")` through Windows PowerShell 5.1 native-argument marshalling as
`sys.stdout.write(ok)`. The interpreter consequently exited one and the invariant branch skipped.
Under the same host and interpreter, `sys.stdout.write(chr(111)+chr(107))` exits zero and emits the
same exact `ok` sentinel.

Change only the two identical Python programs in the existing `Resolve-HostPython` helper to that
observed quote-free form. Preserve JSON parsing, exact output comparison, override/candidate order,
and all failure behavior. Fix both arms so normal `python3`/`python`/`py` discovery is not left with
the same defect. Add no branch, abstraction, test, fixture, or fallback. The independent scope
critique rejected proceeding under the old no-helper-change wording and approved this bounded
amendment as the smallest fix to make a documented supported-host control truthful.

## 4. B-208 deliberate boundary

Record a standing decision: documented executed-script invocations on Windows and Linux remain
supported, including the specifically promised `bash -e scripts/docs-sync-check.sh` boundary.
Sourcing shipped scripts or deliberately exporting `SHELLOPTS=errexit` into their Bash process tree
is not a public compatibility contract.

Evidence: ordinary `set -e` does not export `SHELLOPTS`, a separately invoked Bash child has errexit
off and survives `false`, while `export SHELLOPTS; set -e` alone reproduces inherited errexit. GitHub
Actions documents strict mode on the runner shell itself; repository recipes invoke shipped scripts
as separate Bash children. Supporting the hostile environment would require a cross-script manual-
status rewrite despite no consumer incident. Add no product or test change.

## 5. Records and versioning

- Add WSD-065 for the B-208 support boundary and index it in `meta/decisions-index.md`.
- Amend WSD-054's historical “B-140 follow-on” sentence with the current rejection of a permanent
  executor and the one-off Codex path that already proved sufficient for artifact-only grading.
- Add the bounded B-161/B-165/B-166 maintainer rules to root `CLAUDE.md` and its hand-maintained
  `AGENTS.md` mirror; add B-167's verification discipline to `DEVELOPING.md`. Do not alter shipped
  always-loaded rules for these meta RCAs.
- Move the twelve revalidated closures plus delivered B-134/B-207 and discovered/delivered B-211
  intact to `meta/BACKLOG-DONE.md`, prepend their exact current dispositions, and fix the stale
  B-130 “still open” sentence while moving the surrounding B-134 record. Fifteen items close and
  eleven remain open.
- Replace the stale execution-order note in `meta/BACKLOG.md` with the eleven-item current split:
  field evidence/cadence (B-42/B-43/B-49), bounded implementation (B-136/B-174), retained
  measurement obligations (B-72/B-112/B-129/B-133/B-159/B-160).
- Append one meta learning: `PARTIALLY DONE` and blocked work stays active unless every residual
  obligation is explicitly discharged or rejected; age and inconvenience are not closure evidence.
- Add 0.79.1 unreleased heads to the root and all three consumer changelogs. Consumer notes describe
  the bootstrap authority correction and the shipped Windows PowerShell 5.1 test-suite truth fixes,
  including B-211's quote-stable interpreter control.
- Release through `.claude/scripts/release.ps1`; do not stamp generated files manually.

## 6. Verification contract

### Before product editing

- Native Windows PowerShell 5.1 / CP437: observe B-207 fail for `setup both: Bash visibility=False`
  with `31/1/1` and the `>/dev/null` path error. Already observed on the exact baseline.
- Static B-134 red world: all three source commands contain the false-authority lead and users or
  critical-journey claims. Already observed on the exact baseline.
- B-208 controls: ordinary parent `set -e` leaves `SHELLOPTS` unexported and child errexit off;
  explicit export makes child errexit on. Already observed.
- Native Windows PowerShell 5.1 / CP437 with `ATL_TEST_PYTHON` naming the real interpreter:
  B-211's existing quoted probe reaches Python without the quotes, exits one, and makes the full
  doctor result `32/0/1`; the quote-free control emits exact `ok`. Already observed.

### Candidate evidence

1. Parse every changed PowerShell file under PowerShell 7 and Windows PowerShell 5.1; preserve BOM.
2. Run `FrameworkDoctor.Tests.ps1` under PowerShell 7 and native Windows PowerShell 5.1/CP437 with
   the documented PATH and `PSModulePath` normalization. Require the existing full result green and
   no invariant skip when the documented parser override is available.
3. Directly exercise B-211's explicit override and ordinary candidate-discovery arms under native
   5.1. Apply a wrong-sentinel mutation to a scratch helper and prove an external exact-output
   assertion goes red. Run native-5.1 `Guard.Tests.ps1` and a composed distribution's
   `RoutePrompt.Tests.ps1`, the other direct helper consumers, with their configured parser branches
   exercised rather than skipped. The raw source RoutePrompt hook still contains stack markers and
   is not a truthful security-overlay subject before composition.
4. Apply an unexpected-sentinel mutation to a scratch B-207 candidate, observe the existing result
   red, restore exact bytes, and rerun green.
5. Snapshot the complete three-dist tree, compose all distributions with one composer, snapshot it,
   compose with the twin, and byte-compare the complete trees—not only manifests. Confirm each
   composed bootstrap command carries the authority boundary exactly once and each composed doctor
   result carries the repaired probe.
6. Run both validator twins for all three distributions and require freshness.
7. Exercise greenfield, brownfield, and update delivery for all three distributions with both
   installer twins. Confirm the installed bootstrap command contains the authority boundary; in
   update mode also prove an existing populated consumer `Codebase Context` remains byte-identical.
8. Run the full root meta suite locally. Do not duplicate the six shipped distribution hook suites
   that B-170 assigned to CI; the targeted changed result runs locally on both PowerShell hosts and
   all six full matrices run in the exact-candidate CI workflow.
9. Freeze the candidate commit/range. An independent implementation reviewer starts from this
   contract and the immutable range, forms a blind threat model, applies at least one release-
   specific hostile mutation, observes red, restores exact bytes, and reruns clean.
10. Because an existing shipped test changes, completion requires the first exact-candidate GitHub
   Actions run green on Windows and Linux, including all six distribution hook jobs. Tag only after
   that evidence.

## 7. Proportionality and rejected alternatives

The observed harms are bounded but direct: one supported host cannot produce a truthful doctor-suite
result, the documented interpreter override falsely skips another supported-host branch, and bootstrap
explicitly promotes code observations into product-authority claims that persist in consumer-owned
context. The proposed changes are one existing test branch, two expressions in one existing helper,
and one repeated command sentence. No lower-cost action removes any of the three defects.

Rejected: reused runspaces or persistent shells for B-138; exported strict-mode compatibility for
B-208; new test cases; a general native-argument helper; escaped-quote or exit-status-only B-211
probes; a product provenance schema; static-context growth; live-eval spend for a logical authority
correction; automatic migration of consumer-owned
context; and archive-by-age/blocker. An open entry moves only when its exact remaining obligation is
fulfilled or deliberately rejected on current evidence.

## 8. Delivery RCA questions

- **B-207:** no CI leg invokes the shipped test directly under native Windows PowerShell 5.1; B-201
  swept three similar probes but not this fourth setup site. Bounded follow-up: inspect remaining
  `$bash -c` test sites and file work only for another nested-shell/metacharacter transport or an
  observed legacy-host failure.
- **B-134:** parser/composition gates cannot judge whether prose grants evidence more authority than
  its source supports. The bounded sibling scan found the same defect in exactly the three bootstrap
  whole-files; adjacent commands may consume `Codebase Context` but do not independently authorize
  inferring product intent from code.
- **B-211:** the shared resolver was execution-probed under PowerShell 7 but not under native 5.1,
  so its documented anti-skip override could itself create a false skip. The same quoted probe shape
  exists in two maintainer-only meta tests (`RootInstallerWarehouse.Tests.ps1` and
  `ValidateDist.Tests.ps1`); they run under the PowerShell 7 meta contract and are not silently
  claimed fixed. Reopen that bounded exposure if either test acquires a native-5.1 contract or an
  observed host failure.
