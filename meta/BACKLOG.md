# Framework backlog — Fable exit audit (2026-07-04, framework v0.25.0)

> **How to use this file.** This is the prioritized work list produced by a full-workspace audit
> before model handover. Every entry is self-contained: problem, evidence, suggested approach,
> effort (S ≤ ½ session, M ≈ 1 session, L = multi-session), and which meta-invariants (#1–#7 in
> the root `CLAUDE.md`) the fix must respect. Before starting any entry, read root `CLAUDE.md`
> (meta-workflows, definition of done) and `DEVELOPING.md` (command recipes). Ship via
> `.claude/scripts/release.ps1` when shipped behavior changes [#7]. Work P1s first; within a
> band, order is the suggested sequence. Check an entry off by moving it to the "Done" section
> at the bottom with the version that shipped it.
>
> **Audit baseline:** all existing deterministic gates were GREEN at audit time — both repos'
> `scripts/template-checks.ps1` (exit 0), `.claude/scripts/check-lockstep.ps1` (exit 0), both
> repos' `tests/hooks/Invoke-HookTests.ps1` (84 and 83 tests, 0 failures), the meta suite
> `.claude/hooks/tests/Invoke-HookTests.ps1` (7/7), `bash -n` over all 26 `.sh` files, and a
> PS-parse of all 43 `.ps1` files. Everything below is what the gates *cannot* see, plus known
> deferred work converted into entries.
>
> **Working hazards for the executing agent** (cost this audit real time):
> - The workspace root is a git repo whose `.gitignore` excludes the template repos — a `Grep`
>   from `C:\temp\AIdrivenDev` **silently skips everything under `ai-tech-lead-*/`** (ripgrep
>   honors .gitignore). Search inside a repo path explicitly, or use `grep -r`.
> - Windows PowerShell 5.1 `Get-Date -UFormat %s` returns a *fractional, local-time* epoch
>   string (observed: `1783162609.9606`); pwsh 7 returns an integer UTC epoch. Never parse it
>   culture-sensitively (see B-02).

---

## P1 — incorrect behavior or false safety claims on supported configurations

**All P1 items (B-01, B-02, B-03) shipped in v0.25.1 (2026-07-04) — see `meta/BACKLOG-DONE.md`.** Two
follow-ons this band surfaced are folded into existing P2 entries: the Copilot postToolUse leg is
dead (feeds B-08 matrix rows + B-09 post-write demotion) and the folder-trust prerequisite feeds
`framework-doctor` (B-16). The B-01 optional guard hardening was deferred by decision (see `meta/BACKLOG-DONE.md`).
**B-37 (post-ship review of v0.27.0) shipped in v0.27.1 (2026-07-16) — see `meta/BACKLOG-DONE.md`.**

---

## P2 — gates that lie by omission (drift they were built to catch passes silently)

**All P2 items (B-04…B-09) shipped in v0.25.2 (2026-07-04) — see `meta/BACKLOG-DONE.md`.** The
check-lockstep union/computed-skills/hooks.json gates + template-checks skills-mirror gate close
the silent-drift holes; the post-write $tn routing divergence is fixed with twin agreement tests;
the enforcement matrix gained the three missing capability rows. **B-35 shipped in v0.29.1
(2026-07-16) — see `meta/BACKLOG-DONE.md`. No open P2 items remain.**

---
## P3 — hygiene, drift, small fixes

**B-12 was already resolved — see `meta/BACKLOG-DONE.md`.** No open P3 items remain from the audit;
post-audit P3 item B-29 (haiku adequacy evidence) is under "Known deferred work" (its sibling
B-30 shipped in v0.25.4). **B-38, B-39 (both phases), B-36, and B-34 all shipped 2026-07-16 — see
`meta/BACKLOG-DONE.md`. No open P3 items remain.**

## Strategic backlog — post-Fable horizon (added 2026-07-17, Fable strategic review)

> **Why this section exists.** A strategic review (2026-07-17, framework v0.31.0) asked: what are
> the framework's structural shortcomings, and what should the work list look like for a
> maintainer who no longer has Fable-tier review on tap? The audit-band items (P1–P3) are all
> shipped; the "Known deferred work" below is a feature list. This section is different — it
> targets the **gaps between the framework and reality**: no behavioral evidence, no field
> evidence, no legal basis for consumption, one-time host verifications going stale, and a
> maintenance process calibrated to a frontier-model reviewer.
>
> **Recommended execution order** (deliberate, not file order):
> 1. ~~**B-45**~~ and ~~**B-47**~~ — both **done 2026-08-01**, see `meta/BACKLOG-DONE.md`. B-45 shipped in
>    a stronger form than written: enforced by `release.ps1`'s review ledger rather than by prose,
>    after an adversarial pass argued a prose-only version would not bind. B-47 landed MIT root-only;
>    the dist-travel half is deferred and filed separately.
> 2. **B-42** (field pilot) — start it early because its value is elapsed time; it runs in the
>    background while other items proceed, and its evidence should re-prioritize everything else.
> 3. ~~**B-41**~~ (agent-behavior harness) — **done 2026-08-13**, see `meta/BACKLOG-DONE.md`.
> 4. **B-49** (quarterly live-fire drill) — build the drill kit once B-41's first scenarios exist;
>    it becomes the recurring vehicle that *executes* B-43 (and reviews B-44) every quarter.
> 5. Then interleave: **B-15** (CI recipe) from the deferred list — it is
>    the consumer-lifecycle half of the same story — plus **B-44/B-46/B-48** as capacity allows.

### B-42 · Field pilot — install into ≥1 real production repo and let evidence drive the backlog
**Filed against:** v0.31.0 (2026-07-17)
**Effort:** M to set up · elapsed weeks to harvest · **Invariants:** #6

> **PREMISE CORRECTED 2026-08-19 by the maintainer — the original *Why* below is factually wrong and
> is kept only so the correction is legible.** The framework **is in active production use**: the
> author uses it on real work, continuously. So "zero live consumer installs" was never true, and
> "every design decision came from maintainer introspection" understates the evidence base — a
> maintainer who ships with the tool daily is generating real friction data, not introspecting.
>
> **What B-42 actually lacks, and all it should now claim:** field evidence from a developer who is
> **not the author**. That distinction is the whole remaining item — the author cannot report the
> onboarding friction of someone who did not write the thing, cannot notice guidance that only reads
> as obvious to its author, and shares every blind spot the design has. The two ledger reports to
> date (`meta/field-reports.md`) are both from other people and are both complaints, which is
> exactly the signal the author cannot self-generate.
>
> **Consequences for the *Do* below:** step 2 ("install into at least one real work repo") is
> **already satisfied** — do not re-do it. Steps 1 (success metrics), 3 (intake discipline) and 4
> (convert findings, re-order the backlog) remain open, and the intake gap the ledger records is
> now the sharpest part: neither existing report captured arrival date, what fired, hook noise, or
> token pain. **Nothing in this entry should any longer be read as "the framework is unproven in
> the field."**

**Why (ORIGINAL, SUPERSEDED — see the correction above):** the framework has shipped 31 minor
versions with — as far as the meta layer records —
**zero live consumer installs and zero field feedback**. Every design decision to date came from
maintainer introspection plus adversarial self-critique (excellent, but closed-loop). Several
standing items explicitly wait on evidence that only field use can produce: B-26's misrouting
watch, the reviewer-profile verbosity calibration (WSD-017), the B-37 injection-marker
false-positive observation, token-cost consciousness (B-32's trigger). Without a pilot, the
backlog can only grow more machinery.

**Do:** (1) define 3–5 success metrics *first* and record them in `meta/workspace-decisions.md`
(candidates: review rounds per AI-assisted PR, hallucinated-API incidents caught, time-to-useful
`CLAUDE.md` for a new repo, developer-reported friction per week, % of sessions where a rail or
skill demonstrably fired). (2) Install into at least one real Bitbucket DC work repo
(dotnet or monorepo), run `/bootstrap` or `/adopt` for real, and use it for normal work for 2–4
weeks. (3) Keep `meta/field-reports.md`: date, repo shape, what fired, what misfired, what got
ignored, hook noise, token pain. (4) Convert findings into backlog entries and *re-order this
section* against them. If the pilot can include one developer who is not the framework's author,
their friction reports outweigh the maintainer's.

**Not:** no new machinery to "prepare" for the pilot — install what v0.31.0 ships, as shipped.

**Field report #1 arrived 2026-07-31:** an Angular developer reported the model using `@Input()`
everywhere instead of injecting `NgControl` on a custom form control. B-66 is the first defect
derived from that report.

**`meta/field-reports.md` now exists (created 2026-07-31)** and is the ledger — record every report
there, at intake. Two corrections it makes to the paragraph above, both left visible rather than
rewritten: the Angular report is **#2**, not #1 (the NUnit report behind B-57 is also a field report
from a real install and landed earlier); and the arrival dates, "what fired", hook noise and token
pain were **never captured for either report**, which the ledger records as an intake gap. Both
reports to date are complaints, so nothing in the intake path can currently evidence value — only
failure. The remaining B-42 work (success metrics, the pilot itself) is untouched.

### B-43 · Host-compatibility recertification cadence (the one-time verifications are rotting)
**Filed against:** v0.31.0 (2026-07-17)
**Effort:** S per cycle, recurring · **Invariants:** #5 · **execution vehicle: B-49's quarterly drill**
> **STATUS CORRECTED 2026-08-20 — this entry is much further along than its heading implies, and
> "B-43 is open" currently reads as "nothing is certified", which is false.**
>
> **Already exists.** `meta/host-certification.md` **is** the dated "last certified: host X version Y"
> table this entry asks for. It has per-surface rows, explicit `not certified — quota` /
> `not certified — no seat` values rather than blanks, and it distinguishes `Direct fixture` (which
> proves hook *output*) from end-to-end host *consumption* — the distinction this entry cares about.
> Two rows were re-dated 2026-08-20 by B-50's canary on Copilot CLI 1.0.80.
>
> **Also already exists, and the entry does not name it:** a canary kit library —
> `meta/canaries/{agent-stop-delivery,b52-copilot-two-hook,b50-copilot-posttooluse}` plus five
> `.claude/scripts/canary-*.ps1`.
>
> **Remaining, and only this:**
> 1. **The checklist** — no single "run these canaries, in this order, expect these observations"
>    recipe exists in `DEVELOPING.md`. The kits exist; the index does not.
> 2. **The cadence** — quarterly or on any major host release, sharing B-49's calendar slot by design
>    (one sitting, two checklists).
> 3. **The VS Code leg** — never verified on any leg, open since B-03. **This cannot be closed by any
>    agent session**: it needs a human at a VS Code window with Preview agent-hooks enabled, and those
>    are org-gated. **It escalates**, and the rest of this entry should not stay open on its account.
>
> **Fold in when writing the checklist:** B-50's three-arm design should become the *stated standard*
> for any new canary — a positive control chosen because it is **known-good on the surface under
> test**, a negative control ruling out environment leakage, and a side-effect marker separating "the
> hook never ran" from "it ran and its output was discarded". This entry's instinct to "reuse the
> B-03 canary design" points at the older, weaker pattern; B-143's canary failed precisely by lacking
> a valid positive control.

**Why:** the enforcement matrix rests on *dated, one-shot* live verifications: Copilot CLI 1.0.68
canary (2026-07-04) established which hook legs are live vs dead; VS Code agent-mode consumption
was **never verified at all** (open since B-03); Claude Code hook semantics were verified on one
CLI generation. Agent hosts ship weekly and change hook/context behavior without notice — every
"live-verified" row in `enforcement-surfaces.md` decays toward fiction, and the framework's
honesty discipline (its main differentiator) decays with it.

**Do:** write a canary checklist into `DEVELOPING.md` — the sentinel prompts and hook fixtures
per surface (reuse the B-03 canary design), expected observations, and a dated
"last certified: host X version Y" table (in `meta/`, or as Status notes in
`enforcement-surfaces.md` if consumer-visible). Run it quarterly or on any major host release,
whichever first; each run either re-dates the table or files a defect entry. Fold the
*consumer-side* half into B-16's doctor (its cannot-verify-from-a-script tier already prints a
canary prompt). Close the VS Code gap in the first cycle.

### B-49 · Quarterly live-fire drill — install into a real OSS repo, verify behavior, measure value-add
**Filed against:** v0.31.0 (2026-07-17)
**Effort:** drill #0 = 1 session (freezes the Appendix) · ~½ session per quarter thereafter ·
**Invariants:** #5 #6 · maintainer-decided 2026-07-17 · executes B-43 on a cadence; complements
(does **not** replace) B-42

> **Design LOCKED 2026-07-17, re-locked same day after a second adversarial pass — do not
> re-derive.** Full spec (version-under-test rule, targets, safety + state-hygiene protocol,
> C1–C8 checklist, frozen A/B rubric with documented biases, recert canaries, report template,
> degradation order; **18 findings folded across two critique passes**):
> **`.claude/plans/2026-07-17-b49-live-fire-drill-design.md`**;
> decision record **WSD-022**. The only outstanding work is execution: **drill #0** (recommended
> within 2 weeks — runs the full dotnet drill and freezes the plan's Appendix: pinned SHAs, T2
> mutation patch, T3 planted diff, per-target R2 checks), then quarterly on the reminder
> (`trig_01EL25XDM2pMDaFkRBSGjF1V`, next fire 2026-10-01). The prose below is the summary; the
> plan is authoritative where they differ.

**Why:** the deterministic gates validate bytes and B-41's harness validates scripted scenarios —
but neither ever exercises the product on a codebase nobody curated. A quarterly drill against a
real open-source repo catches what both miss: bootstrap quality on messy real code, installer
behavior on repo shapes we didn't design for, host drift since the last drill, and — the half
nothing else measures — whether the framework demonstrably *adds value* over the same agent bare.
A fixed cadence also defeats the failure mode the one-shot verifications already exhibited
(B-03's canary aging out, VS Code never verified): recurring by calendar, not by memory — a
scheduled reminder fires quarterly (1st of Jan/Apr/Jul/Oct) so the drill happens without anyone
having to remember it.

**Do — build the kit once (M):**
1. **Pin the drill targets in a WSD** so quarters are comparable: one mid-size real .NET OSS repo
   and one Angular one (candidates: `dotnet-architecture/eShopOnWeb` or
   `ardalis/CleanArchitecture`-class for .NET; a mid-size real Angular app, not a toy — criteria:
   50–500 source files, builds on the maintainer box, real domain logic). Pin the *commit SHA*
   per drill so reruns are reproducible; bump the SHA each quarter to stay realistic.
2. **Write the drill checklist** into `DEVELOPING.md` (or `meta/drill-kit.md`): fresh clone →
   root installer (assert mode detection + agent-handoff contract) → drive a real agent through
   `/bootstrap` → 2–3 representative tasks (one feature via a skill recipe, one `/fix`, one
   `/review`) → planted-defect probes (a secret write the guard must block; a convention
   violation `convention-check` must flag). Score each against fixed pass criteria.
3. **Value-add evals (the A/B half):** same task prompt, same repo, same model — once with the
   framework installed, once bare. Score both on a **fixed rubric**: hallucinated APIs referenced,
   convention adherence, test-written-before-fix, verification evidence shown, review findings
   caught. Single runs are anecdotes — keep the rubric frozen and track the *delta across
   quarters*, not absolute scores; a shrinking delta is exactly the B-44 retirement signal.
4. **Fold B-43 in:** the host-recertification canaries run in the same quarterly session (one
   calendar slot, two checklists); the B-44 overlap table gets reviewed there too.
5. **Record** each drill in `meta/drill-reports.md`: date, host + framework versions, repo SHAs,
   scores, defects filed. Defects become backlog entries; a failed drill is a P1.

**Per quarter (~½ session):** run the checklist, log the report, file what it finds. API cost is
real — the drill is maintainer-triggered; the scheduler only *reminds*.

**Not:** don't let the drill replace **B-42** — an OSS clone has no team, so developer friction,
adoption, and reviewer-profile evidence still come only from the field pilot. Don't tune the
framework *to* the pinned repos (rotate one target if that risk appears). Don't average away
failures: one hard checklist failure = a defect entry, regardless of the rubric totals.

> **SCOPE WIDENED 2026-08-19 by the maintainer — the drill must ship, not just exist in `meta/`.**
> As written, every part of B-49 is maintainer-only: `meta/drill-kit.md` never reaches a consumer, so
> the one thing the drill measures that nothing else does — *does the framework demonstrably add
> value over the same agent bare* — is a question only the author can ever ask, about repos only the
> author picked. A consumer cannot answer it for **their** codebase, which is the only place the
> answer actually matters to them.
>
> **Therefore B-49 splits into two deliverables sharing one frozen rubric:**
> 1. **The meta drill (existing scope)** — quarterly, maintainer-run, against the two pinned OSS
>    targets. Unchanged; `meta/drill-kit.md` stays where it is.
> 2. **A consumer-runnable self-assessment (NEW)** — a shipped artifact that lets an installed team
>    run the A/B value question on their own repo and their own tasks: same task, same model, once
>    with the framework and once bare, scored on the same frozen rubric. This is the first thing the
>    framework would offer that answers *"is this worth keeping installed?"* in the consumer's own
>    terms rather than the author's.
>
> **Not yet designed, and it is not a copy-paste of the kit.** At least four things differ and must
> be decided before implementation: (a) the meta kit pins commit SHAs for cross-quarter
> comparability — a consumer's own repo has no such pin and does not need one; (b) the meta kit's
> planted-defect probes assume the author's fixtures; (c) a consumer running "once bare" must be
> told plainly that this costs real API spend, twice; (d) the rubric must stay **frozen and
> identical** across both deliverables or the two populations stop being comparable — that shared
> rubric is the whole reason to treat these as one item rather than two. Needs its own locked design
> and critique before any code. **Cross-link: B-44** — a consumer-visible shrinking delta is the
> retirement signal that item exists to watch for, and this is the only instrument that could
> produce one from outside this box.
>
> **KIT DELIVERED 2026-08-17; no drill run.** WSD-044 pins
> `dotnet-architecture/eShopOnWeb` and `gothinkster/angular-realworld-example-app`, while leaving
> both commit SHAs and all size/build/domain qualification explicitly to drill #0. The cold-run
> checklist and frozen A/B rubric are in `meta/drill-kit.md`. RCA: no gate caught the missing kit
> because this is maintainer process infrastructure, not a malformed shipped artifact. The same
> exposure applies to the still-unrun host-recertification/report templates; drill #0 must exercise
> them rather than treating the existence of prose as execution evidence.

**B-50 is DONE (2026-08-20) — an isolated three-arm canary confirmed the channel on CLI 1.0.80 and both stale passages are reconciled; see `meta/BACKLOG-DONE.md`.**

**B-44 is DONE (2026-08-20) — the retirement-trigger table is `meta/overlap-watch.md`; see `meta/BACKLOG-DONE.md`.**

### B-48 · Enforcement-bypass audit — the guard's known end-runs, decided honestly
**Filed against:** v0.31.0 (2026-07-17)
**Effort:** M · **Invariants:** #3 #5 · needs a WSD record
> **DECISION PROPOSED 2026-08-20 (Claude), maintainer to ratify — PARTIALLY DONE, the analysis is
> settled and the one shipped fix is STILL OPEN.** This entry's own framing is right: blocking-vs-
> advisory is the key judgment, and a false-positive block on a legitimate test refactor costs more
> trust than the gap. Three bypasses, three different answers; treating them uniformly is what kept
> this open.
>
> **(1) Shell-write gap → DOCUMENT, do not harden.** Hardening means content-sniffing arbitrary shell
> commands. That is unbounded: the guard cannot know what a command *will write* without running it
> (`sed -i`, a heredoc, a redirect, a script three levels down), and sniffing command *text* for
> secret-shaped strings blocks **reading** as readily as writing — `grep AKIA app.log` and every
> legitimate investigation of a leak would be refused. A security tool that blocks security work is
> worse than none, and the blast radius is the terminal, the most-used tool in any session. The
> control is already disclosed accurately in `docs/enforcement-surfaces.md`'s scope caveat, which
> names the `CLAUDE.md` rules as binding for that path. **What is missing is the decision record, not
> the caveat** — plus a re-read of the caveat's prominence, since it sits below a table a skimming
> reader may not reach.
>
> **(2) Test-defeat by weakening → ADVISORY, never blocking.** "Assertions removed or weakened in a
> diff" cannot be separated from a legitimate refactor by any rule available to us: deleting a
> duplicated case, replacing three assertions with one stronger one, migrating an assertion library,
> or removing a test for deleted behaviour all look identical to the defect. A blocking rule would
> refuse correct work, and this repo has already measured where that leads — B-94 records
> `-AllowExtraStagedPaths` being passed reflexively once a guard refuses correct releases. Build an
> added/removed-lines diff heuristic over test files that **reports** to the model and to `/review`
> with no exit code. **State the limit wherever it is documented:** an advisory control is defeated by
> an agent that ignores it; it raises the cost of the bypass and makes it reviewable, and must never
> be described as enforcement.
>
> **(3) Multi-line attribute lists → HARDEN. This is the one that ships, and it is not yet built.**
> `[Test,\n Ignore("flaky")]` is legal C# that no formatter forbids and a one-line evasion of a gate
> the framework advertises as deterministic. Unlike (1) and (2) the fix is bounded with a
> near-zero false-positive surface: **normalise the input** — join physical lines within a bracketed
> attribute list into one logical line — then run the existing patterns unchanged. No pattern is
> loosened. Red-test both the single-line and split forms, plus a legitimate multi-line attribute list
> carrying no suppression, which must pass.
>
> **The durable output is the test, not the three answers:** **harden** where the defect has a
> canonical form to normalise to; go **advisory** where it is distinguishable from correct work only
> by intent; **document** where the control would have to guess at side effects it cannot observe.
> That is reusable on the next bypass.

**Why:** two known bypasses have been deferred-by-decision and neither has a written honest
disclosure: (1) the **shell-write gap** — `guard` registers on editor/file-write tools only, so
`echo $SECRET > appsettings.json` via the terminal tool sails past the secret/pragma blocks
(B-01 optional hardening, deferred 2026-07-04); the `enforcement-surfaces.md` caveat exists but
the hardening decision was never made. (2) the **test-defeat gap** — an agent can satisfy
"build + test green" by weakening the failing test; the test-integrity prose forbids it but no
deterministic gate sees it (open since v0.23.0). (3) **multi-line attribute lists evade every `.cs`
test-defeat check** (found while shipping B-57, 2026-07-31): both twins are line-oriented, so
`[Fact(Skip=…)]` and the new NUnit/MSTest `[Ignore]` check are both defeated by splitting the
attribute list across lines —
```csharp
[Test,
 Ignore("flaky")]
```
— which is legal C# that no formatter forbids. This is disclosed in the shipped v0.37.0 changelog as
a known limitation, so it is honest, but it is a one-line evasion of a gate the framework advertises
as deterministic. An enforcement product whose bypasses are undocumented-but-known is one consumer
incident away from losing its honesty claim.

**Do:** one scoped audit pass: enumerate the realistic end-runs (terminal-tool writes; test
edits that invert assertions/delete cases in the same change that fixes them; `git commit
--no-verify` where git hooks are in play per B-18). For each: either harden (terminal-tool
registration + content-sniff for guard — needs its own fixtures and false-positive analysis;
an added-lines diff heuristic for test-defeat, likely *advisory* not blocking) or **document the
bypass explicitly** in `enforcement-surfaces.md`'s capability rows. Blocking-vs-advisory is the
key judgment: a false-positive block on a legitimate test refactor costs more trust than the
gap. Record the decision as a WSD either way.

**B-59 is DONE — shipped in v0.60.0 (2026-08-18), WSD-046; see `meta/BACKLOG-DONE.md`.**

**B-64 is DONE — `meta/gate-redtest-coverage.md` (2026-08-18); see `meta/BACKLOG-DONE.md`.**

**B-70 is DONE (2026-08-20) — the cross-leg evidence rule is now in the Definition of done; see `meta/BACKLOG-DONE.md`.**

### B-72 · A behavioural probe can be defeated by the guidance it measures, and `angular-form-control` does not reproduce its field report
**Filed against:** v0.39.0 (2026-07-31)
**Effort:** M · **Priority:** P2 · **Invariants:** #5 · found 2026-07-31 while shipping B-66

> **TRIAGE 2026-08-20 — PARTIALLY DONE; parts (c) and (d) are shipped, (a) and (b) are not.**
> Part (c), the standing rule, is now Maintenance model rule 4 in `CLAUDE.md` and must **not** be
> reimplemented. Part (d), the sweep for mechanism-telegraphing prompts, was absorbed by B-112's
> 15-scenario sweep. The original `formInputs` false negatives (`@Input() set x()` and
> `input.required<T>()`) were fixed in v0.40.0 and are self-tested.
>
> **Still open, and verified against the tree today:** part (a) — the grader still computes one
> combined signal, `$cva = ControlValueAccessor OR NG_VALUE_ACCESSOR`
> (`.claude/evals/run-agent-evals.ps1:1111`), and reports only `cva=…`, so the correct pattern and
> the circular-DI **double registration** still score identically; its fixture contains both the
> interface and the provider, so it cannot demonstrate the distinction. Part (b) — the prompt in
> `.claude/evals/scenarios.json:53-56` still names the mechanism (bindable with `formControlName`,
> shows its own invalid/touched error), which is the telegraphing the entry objects to.
>
> **The baseline remains saturated**: it passed with no forms guidance shipped and no skill used, so
> this scenario still cannot red-test the guidance it exists to measure. Re-baselining after (b) is
> part of the work, not a follow-up to it.

**Why:** three separate failures of the same instrument, all found in one session.

1. **The grader was defeatable — by the very idiom the guidance was about to recommend.** The
   `formInputs` patterns missed `@Input() set disabled(v)` / `@Input() get errors()` (the decorator
   pattern required the property name immediately after `@Input(...)`) and
   `disabled = input.required<boolean>()` (the signal pattern did not admit `.required`). A value
   accessor re-declaring form-owned state in either form — **exactly the reported defect** — scored
   PASS. The draft B-66 plan told the implementer to "cover the signal `input()` form", which would
   have flipped the eval green without any behaviour changing. Fixed and red-tested for v0.40.0; the
   *class* is open. This is B-59's "inert check" applied to the behavioural harness: `-SelfTest` was
   green throughout because no case exercised the gap.

2. **The probe does not reproduce the report it was built from.** The first valid baseline run
   (2026-07-31, `meta/eval-results.md`) is a **PASS with no forms guidance shipped**: the agent
   self-injected `NgControl`, set `valueAccessor = this`, used `setDisabledState` rather than an
   `@Input() disabled`, and commented that this "avoids the circular-DI `forwardRef`". The prompt
   telegraphs the answer — it asks for a component bindable "directly with `formControlName`" that
   shows "its own validation error when the field is invalid and touched", which is close to a
   specification of the `NgControl` approach. Same defect class as the probe's first
   mis-specification (`0598c6d`), one level subtler, and it means the scenario cannot red-test B-66.

3. **The grader cannot see the hazard the guidance teaches.** `cva` is
   `ControlValueAccessor OR NG_VALUE_ACCESSOR`, so the correct pattern (`implements
   ControlValueAccessor` + self-injected `NgControl`) and the **double-registration bug**
   (`NG_VALUE_ACCESSOR` provider *and* injected `NgControl` → circular DI) both score
   `cva=True ngcontrol=True`. The probe would score the runtime-broken component as a pass.

**Do:** (a) separate the `cva` signal into provider-vs-interface so double registration is
detectable, and add a self-test case for it; (b) re-specify the scenario so the prompt states the
*business* need without naming the mechanism — describe a reusable input used across several forms
and let the agent discover that `formControlName` requires a value accessor — then re-baseline;
(c) adopt a standing rule that a behavioural probe is only a red test once it has been shown to
**fail** on the unfixed tree, and record that failing observation next to the scenario; (d) sweep
the other scenarios for prompts that specify the mechanism rather than the goal.

**Not:** do not delete `angular-form-control` — its `formInputs`/`controlAsInput` signals are sound
and the fixture is reusable. The defect is the prompt and the `cva` conflation, not the harness.

**B-76 is DONE (2026-08-18) — see `meta/BACKLOG-DONE.md`.**

**B-79 is REJECTED ON EVIDENCE (2026-08-20) — the MSIX hypothesis is refuted by measurement on the MSI build; see `meta/BACKLOG-DONE.md`.**

**B-83 is DONE (2026-08-21) — filed-against stamps, a delivery-ledger correlation, and the re-validation rule; see `meta/BACKLOG-DONE.md`.**

### B-96 · `map-warehouse` maps the ETL, not the warehouse
**Filed against:** v0.44.0 (2026-08-04)
**Effort:** M · **Priority:** P2 · found 2026-08-04 (maintainer field report) · **Design:** `.claude/plans/2026-08-05-b96-warehouse-schema-map-design.md` (LOCKED)

> **TRIAGE 2026-08-20 — PARTIALLY DONE. The artifact shipped in v0.49.0; only the behavioural
> outcome arm is outstanding. Do not re-implement the skill.** Shipped and confirmed in the tree:
> the table/key inventory, the per-fact relationship edge list, dimensional semantics, the coverage
> statement, the fan/chasm traps, explicit `UNRESOLVED` abstention, and the sixth §3.4 temporal
> rule from field report #4 — all in `src/stacks/dotnet/files/.claude/skills/map-warehouse/SKILL.md`.
> WSD-032 made the emitted `docs/warehouse-map.md` the delivery vehicle so the read-side rules travel
> off the selectively-routed skill, and `/bootstrap` emits the Data Access pointer. The
> "observe `UNRESOLVED` on naming-only evidence" ship gate is also discharged: a live produced-map
> run recorded `abstained=True` with six edge rows.
>
> **Remaining work — one thing.** The pre-registered six-run **enriched-map** arm
> (`warehouse-route-p1..p3`) has never been run to its thresholds: `usedDeadColumn` ≤ 2/6, map reach
> ≥ 5/6, `joinedDimension` 6/6. v0.49.0's changelog itself records this as still owed. If the fixture
> or harness has changed incompatibly since the arm was registered, **disposition the old arm
> explicitly** rather than quietly substituting a different warehouse evaluation — substituting one
> measure for another after seeing results is the failure this repo files under B-112.
>
> **Note the dependency is on reach, not content:** B-98's v0.48.0 rule opened the *map* to 6/6 while
> the *skill* stayed 0/6, which is why WSD-032 moved the content. What is unmeasured here is whether
> the map's content changes the answer, not whether it is reached.

**Why:** the skill emits one row per entity over eight fields — `entity | layer | grain | load
proc/pipeline | orchestrated by | rerun protection | SCD | partitioning`
(`src/stacks/dotnet/files/.claude/skills/map-warehouse/SKILL.md:76-84`). Every one is a **loading**
property. There is no schema inventory, no columns, no primary keys, no foreign keys, no
relationships; columns appear only as table-classification signals (`:33`). It is an ETL map wearing
a warehouse map's name.

The consequence shows on the commonest warehouse task there is. Asked to help write a report, the
framework can say how `FactSales` is loaded and whether the load is re-runnable — and cannot say what
`FactSales` joins to or which dimension owns an attribute. This is established by reading the skill,
not inferred from the field report.

The field report is what it costs. A consumer warehouse, onboarded and already mapped, was asked to
replicate a report built in a *different* warehouse; the model reached a dimension attribute through
a spurious column (declared in DDL, never populated) instead of following a fact key to the dimension
built for that result. With no relationship model in reach, the only evidence available was the
column's **name**. No transcript exists, so whether the skill fired is unknown.

Compounding: step 1 already identifies the consumption views (`:40-45`) and step 7 already records
which views each entity feeds (`:81-84`). Those views contain the correct joins. The skill opens them
and extracts nothing from them.

**Second field report, 2026-08-05 (ledger #4) — the locked design does not cover it.** Same
warehouse, second read-side defect, different class: the model put **end-date predicates on
dimension joins**. Unnecessary — staging populates dimensions then facts, so the load already
resolved each business key to the dimension version that applied and stamped that surrogate key onto
the fact. The as-of join happened once, at load; the version is already pinned. Only the **run**
dimension needed one, because its current row is selected at read time rather than resolved at load.

Design §3.4's five rules all address *attribute sourcing* (reach an attribute through a fact key,
suspect same-named columns, map source→target before writing SQL); the fan/chasm traps address
*grain*. Nothing addresses *temporal predicates*, so this defect survives the design as locked.
**§3.4 gains a sixth rule:** a fact's dimension foreign key was resolved at load time, so a join on
that surrogate key takes **no** `EffectiveFrom`/`EffectiveTo`/`IsCurrent` predicate — adding one
silently drops every fact pointing at a superseded row. Temporal predicates belong only where the
version was *not* resolved at load: natural/business-key joins, and run/version/snapshot registers
where several rows are live at once and exactly one is current. The discriminator is **did the load
resolve the key, or defer it** — and the relationship edge list this design already emits is what
makes it answerable, since it records which fact key points at which dimension.

Two properties make this defect worse than #3's class and worth stating in the skill: it fails
**silently** (a low row count, not an error), and in review a join carrying effective-date predicates
reads as *more* careful, not less — so it survives exactly the scrutiny that would catch a missing
filter. The general form is filed as **B-99**.

**Do:** implement the locked design. In outline — table inventory with primary keys; a per-fact
relationship edge list as the primary artifact (`| fact | fk column | → dimension | role | evidence |
confidence |`); the dimensional semantics reporting needs (fact type, role-playing, conformed and
degenerate dimensions); a coverage statement naming what could not be read; read-side query rules and
the fan/chasm traps inside the skill; and a one-line `docs/warehouse-map.md` pointer in `CLAUDE.md >
Conventions > Data Access`, mirroring the ADR index (`src/core/CLAUDE.md:92-100`).

Three constraints are locked and are the reason two earlier revisions were rejected in review:
**(a)** confidence is explicit and abstention is the default — naming convention alone never asserts
an edge, and a guess labelled "declared" is worse than no label, because it suppresses the scepticism
that would send the agent to the reporting view; **(b)** cost is tiered — DDL facts and consumption
join predicates ride on scans already performed, load-proc dataflow tracing does not and stays off
the default path; **(c)** no whole-warehouse bus matrix (7,200 cells at 60 facts × 120 dims, and
Kimball's enterprise matrix is a planning artifact over business processes, not a join router).

**Not:** no new skill (a second selectively-routed skill adds a routing bet without removing one); no
execution against a database — WSD-021 stands, and the opt-in profiling tier was considered and
rejected in the design; no whole-warehouse attribute-authority analysis.

**Ship gates that are easy to skip:** the skill must be *observed* emitting `UNRESOLVED` on
naming-only evidence, and the design's labelled fixture (declared FK, CTE-resolved key, `MERGE`,
a misleading column name, conflicting consumption joins, dynamic SQL) must measure **abstention as
well as precision** — via the B-41 harness, not a second one.

> **UNBLOCKED 2026-08-06 — the gate is discharged, and the block below is kept as history.**
> B-98 step 2 shipped Verification Rule 11 in v0.48.0 and measured `r = 6/6` against the `0/6`
> baseline (`p≈0.002`, `meta/eval-results.md`). The pre-registered rule was `r≥5` ships; it was met
> and not moved. §6.3 of that design names "implement B-96's map content" as the explicit next step,
> because `usedDeadColumn` cannot move while the map it points at is ETL-only.
>
> **But read what actually moved, because it changes this item's delivery story.** The `Skill`
> channel stayed at **0/6**. Rule 11 works by routing the model to `docs/warehouse-map.md`, not by
> repairing skill routing — so on a report-writing task, `map-warehouse` still does not fire.
> Guidance sited *only* in the skill therefore reaches nobody at the moment it is needed. The locked
> design's §3.4 put the read-side rules exactly there. **Deviation taken and recorded as WSD-032:**
> the rules stay in `SKILL.md` as the authoring instruction *and* step 9 copies them into the emitted
> map, so they ride the 6/6 channel. §3.5's description broadening is implemented budget-neutrally
> for the same reason — it is a "better description" mechanism, which is what step 2 §2.2 says the
> `r=0` observation weakens.
>
> **Two amendments to this entry's own record, both from the step-1 run:**
> - **§3.6 understates delivery.** `.claude/skills/` is unprotected and refreshes on update
>   (`install.ps1:30-31`, `:83-85`), so the skill content *does* reach already-bootstrapped
>   consumers. Only the `Conventions > Data Access` index line is behind B-97. Do not carry the
>   "greenfield installs only" framing to the whole item.
> - **Criterion 5 got a partial dry run.** `usedDeadColumn=True` in 4/6 runs, which is field report
>   #3's shape — but with the current skill shipped, at n=2 per paraphrase, with visible
>   batch-to-batch variance. Treat as a reason the labelled-fixture work is worth doing, not as a
>   baseline. The answer-key fixture criterion 5 requires is still owed.

**Gated by B-98 step 1.** Whether `map-warehouse` fires at all on an incident-shaped prompt is a
*prerequisite*, not a ship gate: if it does not fire, this content work does not reach the developer
however good it is, and the description change in the design (§3.5) is insufficient. Settle B-98
step 1 before implementing. (It was first written into this entry as a ship-gate sentence, which
inverted the dependency — the check would only ever run if B-96 were already being built.)

**Cross-links:** B-97 (its Conventions index line cannot reach already-bootstrapped consumers —
B-96 must not claim delivery it does not have), B-78 (the warehouse-specific case of that, and its
"durable pointer into `CLAUDE.md > Conventions > Data Access`" is the same mechanism —
`meta/BACKLOG.md:831-834`), B-41 (the eval harness the ship gates depend on), B-40/WSD-021 (the
original DW capability and its no-execution property).

---

### B-97 · No change to `CLAUDE.md` — or any protected file — reaches an already-bootstrapped consumer
**Filed against:** v0.44.0 (2026-08-04)

> **PARTIALLY DONE — shipped v0.45.0 (2026-08-05), WSD-031.** The four framework-owned blocks now
> ship in `.github/instructions/framework-rules.instructions.md` — one unprotected carrier read
> natively by Copilot and via `@import` by Claude Code (canary 5). **Closed for the Copilot leg and
> for greenfield/migrated Claude consumers. NOT closed for already-installed Claude consumers**, who
> receive *discovery* (a session-start pointer + a doctor row), not delivery. Boy Scout Rule stays in
> `CLAUDE.md` and its framework scaffold remains greenfield-only, permanently — stated, not hidden.
>
> **Successor question, still open:** does a Claude Code model follow the fresh carrier or the stale
> inline copy when both are visible? Canary 4 settled this for Copilot VS Code only. It is a
> stochastic model behaviour, so it needs B-98's six-run rule, not a single canary.
>
> **RCA — why did no gate catch the original defect?** Because the defect *was* a correct fix. v0.20.0
> stopped update runs clobbering a bootstrapped `CLAUDE.md`; nobody traced that the same change also
> severed delivery of the framework-owned blocks inside it. No gate exists for "a file we ship is
> never received", and none is proposed here — the structural fix removes the condition instead.
> **What else is exposed to the same class?** Every remaining `$protected` path:
> `FRAMEWORK-CONTEXT.md`, `TECH_DEBT.md`, `SECURITY_FINDINGS.md`, `docs/ARCHITECTURE.md`,
> `.github/copilot-instructions.md`. Framework-authored content in any of them has the same
> non-delivery property. `copilot-instructions.md` is the one worth auditing next: it carries
> framework-authored rules, not just consumer content.
**Effort:** M · **Priority:** P2 → **recommend P1** (it gates B-96 and B-99, and every future always-on instruction change) · found 2026-08-05 (blocked B-96's delivery), **scope widened 2026-08-05 after B-99's review** · **Invariants:** #1

> **TRIAGE 2026-08-20 — PARTIALLY DONE, and the remaining part is a decision, not a build. Read this
> before touching anything in the design sections below.** Three of the four populations are closed.
> v0.45.0 (WSD-031) moved the four framework-owned blocks onto **one unprotected carrier**, read
> natively by Copilot and imported by Claude Code: that closes existing Copilot consumers, greenfield
> Claude consumers, and migrated Claude consumers. v0.61.0 added the consumer-side diagnostic —
> `framework-doctor` now classifies migrated / pending-duplicate-inline / absent-carrier-or-import /
> missing-file states (`src/core/scripts/framework-doctor.{ps1,sh}`).
>
> **What is left is exactly one population: already-installed, *unmigrated* Claude consumers.** For
> them WSD-031 is explicit that the carrier is "**discovery, not delivery**" — the doctor detects and
> explains the duplicate-inline state, and the consumer still has to act. So the choice now is:
> (a) provide an automatic *safe* migration for that population, or (b) formally redefine the
> remaining obligation as **assisted** migration and close the entry on that basis, saying so plainly
> in the shipped capability language.
>
> **Do NOT implement this entry's original merge-aware protected-file overwrite literally.** WSD-031
> deliberately keeps `$protected` and rejects `/sync-template` because that path recreates the
> v0.20.0 clobber risk. Any (a) must be safe migration of a consumer-owned file, not overwriting one.
>
> **One thing the entry claims that is not evidenced:** the stale-inline-versus-fresh-carrier
> *precedence* risk for Claude consumers is resolved operationally (v0.61.0 tells the user to delete
> the duplicate inline section) but was never measured — no precedence experiment was found. If (b)
> is chosen, that gap has to be disclosed rather than assumed benign.

> **Scope correction, 2026-08-05.** This entry originally said *a conventions change* cannot reach an
> already-bootstrapped consumer. That understated it. The wall is not `/bootstrap` replacing the
> Conventions section — it is the **installer**, and it protects the whole file. B-99 was filed on the
> premise that a new *Verification Rule* escapes this because bootstrap rewrites Conventions and not
> the always-on blocks. That premise is **refuted**; see the three reads below. The practical
> consequence is large: **the framework has no delivery path for any always-on instruction change to
> its existing user base.**

**Why:** verified by reading three independent mechanisms, all of which must be open for delivery and
none of which is.

1. **The installer restores the consumer's file over the new one.** `$protected` is
   `CLAUDE.md, AGENTS.md, TECH_DEBT.md, SECURITY_FINDINGS.md, LEARNINGS.md, FRAMEWORK-CONTEXT.md,
   .github/copilot-instructions.md, docs/ARCHITECTURE.md`
   (`dist/dotnet/scripts/install.ps1:30-31`). Update mode is entered whenever
   `.claude/framework-version.json` exists (`:42`); it snapshots every protected file to temp
   (`:74-81`), copies the dist over the target, then **copies the snapshot back** (`:115-123`) and
   prints *"consumer-owned content files left untouched"*. The header states the intent outright:
   *"consumer-owned content files are left untouched. Safe to re-run"* (`:14-15`). So a consumer who
   updates receives new skills, commands, agents and hooks — and their **own** `CLAUDE.md`.
2. **`/bootstrap` cannot deliver it.** It replaces the Conventions section
   (`src/core/CLAUDE.md:85`), enumerates what it rewrites without naming Verification Rules
   (`dist/dotnet/.claude/commands/bootstrap.md:164-181`), and is `disable-model-invocation: true`
   (`:3`) so it is not re-run anyway.
3. **`/rebootstrap` cannot deliver it either** — the candidate vehicle this entry originally
   proposed. It re-derives sections by analysing the consumer's repo; it contains no reference to
   the template, `dist/`, or a re-copy, so it has **no source** for a framework-authored rule the
   consumer's file does not already contain.

Net: only *unprotected* paths update — `.claude/skills/`, `.claude/commands/`, `.claude/agents/`,
hooks, `scripts/`, and `docs/` other than `ARCHITECTURE.md`. That makes this entry's third option
(*"accepting that Conventions is consumer-owned after bootstrap and routing durable guidance to
skills instead"*) not merely the cheapest candidate but the **only mechanism that currently works** —
and its stated cost is now the whole problem: "durable" becomes "reliably routed", which is **B-98**.

Compounding: there is little room to grow the shipped templates anyway. `meta/context-footprint.json`
puts dotnet static Claude context at **38,571 against a 40,000 ceiling** and monorepo at **45,398
against 48,000**. Note the ceilings are **characters**, not tokens — the counting rule is
`LF-normalized UTF-8 bytes; ~tok = round(chars/4)` (`meta/context-footprint.json:4-8`), so dotnet's
1,429 remaining characters are roughly **357 tokens**. Whatever the answer is, it is not "add more to
`CLAUDE.md`".

- `/bootstrap` replaces the **entire** `CLAUDE.md > Conventions` section with conventions observed in
  the actual codebase (`src/core/CLAUDE.md:83-88`).
- `docs/defaults.md` explicitly stops being authoritative once it runs: *"These apply only when
  CLAUDE.md > Conventions has not been populated by `/bootstrap`"* (`docs/defaults.md:3`).
- `/bootstrap` is `disable-model-invocation: true` (`dist/dotnet/.claude/commands/bootstrap.md:3`), so
  it is not re-run.

Therefore **any** guidance we ship into either file reaches greenfield installs only. Every
already-bootstrapped consumer — which is every consumer that has been using the framework — is
structurally unreachable by that route. B-96's Conventions index line hit exactly this wall, which is
how it was found.

Compounding: there is little room to grow the shipped templates anyway. `meta/context-footprint.json`
puts dotnet static Claude context at **38,571 against a 40,000 ceiling** and monorepo at **45,398
against 48,000**. Whatever the answer is, it is probably not "add more to `CLAUDE.md`".

**Do:** decide how a post-bootstrap consumer receives an always-on instruction change at all, and
record it — this is a WSD-shaped question, not a code change. Candidates, re-weighed against the
evidence above:

- **Routing durable guidance to skills** — now the only mechanism that demonstrably delivers, since
  `.claude/skills/` is unprotected and refreshes on update. Cost: skills are selectively loaded, so
  "durable" becomes "reliably routed" (**B-98**). This is no longer the fallback option; it is the
  baseline against which the others must justify themselves.
- **A merge-aware update path for the protected files** — the only candidate that would actually
  restore delivery of an always-on rule. Expensive and hazardous: the whole point of `$protected` is
  that these files are consumer-owned after bootstrap, and clobbering them is a worse failure than
  not delivering. A three-way merge, or shipping framework-owned blocks as a *separate included
  file* the consumer's `CLAUDE.md` references rather than contains, are the two shapes worth costing.
- **A `/docs-sync` or doctor row that *reports* the drift** rather than closing it — cheap, honest,
  consistent with WSD-027 (tooling may verify but not promote), and it converts a silent gap into a
  visible one. Does not deliver anything, but tells the consumer they are behind.
- **~~`/rebootstrap` as the delivery vehicle~~ — REFUTED, see (3) above.** It has no template source.
  Struck rather than deleted so it is not re-proposed.

**Decide before B-96 or B-99 implement anything**, since both were designed against delivery
assumptions this entry has now falsified twice.

**Status 2026-08-05: design drafted, reviewed, sequencing rejected, rev 2 written.**
`.claude/plans/2026-08-05-b97-protected-file-delivery-design.md` (rev 2 — **not locked**). Four
blocking findings accepted. The two that matter:

- **`.github/instructions/` is unprotected** (`install.ps1:31` lists eight protected paths and that
  directory is not among them; `:37` names it in `$adoptionSignals`, so the framework recognises it
  as an AI-tooling surface *and lets it update*). **B-17** already plans to use it. If a
  framework-rules instruction file works there, the split-file option gains a native Copilot delivery
  leg and the "assist the manual sync" option is probably dead.
- **A drift row cannot honestly say "behind".** The installer overwrites
  `.claude/framework-version.json` (`:87`) and restores the old `CLAUDE.md` (`:115`), whose header
  carries its own stamp — so the stamps diverge on every update. That divergence reliably proves the
  protected file was **not synchronised**; it does not prove any block is stale or distinguish a
  deliberate consumer edit. Ships as `DIVERGED — review required`, not "you are behind".

**Canary 1 RUN 2026-08-05 — POSITIVE. `@import` resolves from a root `CLAUDE.md`, so Option A is
viable.** Sentinel present only in the imported file; the model returned it with **zero tool
invocations in the transcript**, so it could not have read the file, and the control confirms the
sentinel is absent from `CLAUDE.md` itself. Verified independently of the probe script's own check.
n=1 is sufficient because this measures the host's *deterministic* context assembly, unlike the
stochastic routing question — do not cite it as precedent for shrinking B-98's six runs.

**Canary 2 RUN 2026-08-05 on Copilot CLI 1.0.77 — POSITIVE. `.github/instructions/` reaches Copilot.**
Three-way controlled: subject (`.github/instructions/*.instructions.md`, `applyTo: "**"`) returned the
sentinel; positive control (`.github/copilot-instructions.md`) returned its own; **negative control
(no instruction file) correctly returned `NOT-IN-CONTEXT`** rather than confabulating — which is what
makes the positive mean anything. `Changes +0 -0`, no tool invocation, so the sentinel was not reached
by reading. Script: `.claude/scripts/canary-copilot-instructions.ps1`.

> **THE `copilot-instructions.md` AUDIT THIS RCA ASKED FOR, DONE 2026-08-21. It has the property,
> but it is the least dangerous instance, and the reason why is worth keeping.**
>
> **It qualifies.** `.github/copilot-instructions.md` is in `install.ps1`'s `$protected` list
> (`install.ps1:31-32`) and does carry framework-authored rules, not just consumer content: the
> shipped dotnet copy runs 62 lines and includes `## SOLID` (six framework rules, DIP through ISP)
> and `## Boy Scout (always apply on touched files)`. A framework change to either never reaches an
> already-installed consumer through this file. That is B-97's defect exactly.
>
> **Three things blunt it, and none of them were true for `CLAUDE.md`:**
>
> 1. **Copilot already receives the fresh rules by another route.** Canary 2 established that
>    `.github/instructions/framework-rules.instructions.md` reaches Copilot CLI, and canary 4 that it
>    reaches VS Code agent mode. So on the surface this file serves, delivery is not severed — the
>    stale copy is an *additional* source, not the only one.
> 2. **It is regenerable by the consumer**, not frozen: the file's own header says
>    `GENERATED by /generate-copilot from CLAUDE.md`. `CLAUDE.md` now imports the unprotected carrier,
>    so a consumer who regenerates gets current rules without any framework change at all.
> 3. **The content is largely stack conventions** (naming, DI, async, logging), which are
>    bootstrap-populated and *supposed* to be consumer-owned. Only the SOLID and Boy Scout sections
>    are framework-authored.
>
> **What is genuinely untested, and is the only part worth spending anything on:** canary 4 proved
> *fresh carrier beats stale `AGENTS.md`*. It did **not** test fresh carrier versus a stale
> `.github/copilot-instructions.md`, which is a different file read through a different Copilot
> mechanism. The precedence result should not be assumed to transfer. That is the same shape as
> B-97's own successor question, and it belongs in the same measurement pass rather than in a
> separate one.
>
> **Recommended disposition: no code change.** Nothing here is severed delivery; it is at worst a
> duplicated stale copy on a surface that also receives the fresh one. Folding one precedence arm
> into the existing measurement is proportionate; shipping machinery is not. Recorded so the RCA's
> question is closed with an answer rather than left as a standing suspicion.
>
> **The other `$protected` paths, checked at the same time:** `TECH_DEBT.md`,
> `SECURITY_FINDINGS.md`, `LEARNINGS.md`, `FRAMEWORK-CONTEXT.md` and `docs/ARCHITECTURE.md` are
> consumer-authored by design — the framework ships a scaffold once and never has newer content to
> deliver, so they cannot exhibit the defect. `AGENTS.md` is the mirror and is covered by canary 4.
> That exhausts the list, so this RCA question is now fully answered rather than partially.

### B-97 ANSWER (rev 3): Option A, both legs observed

| Host | Carrier | Protected? | Evidence |
|---|---|---|---|
| Claude Code | `CLAUDE.md` → `@.claude/framework-rules.md` | No — delivers on update | Canary 1 |
| Copilot | `.github/instructions/framework-rules.instructions.md` | No (`install.ps1:31` vs `:37`) | Canary 2 |

Option B (`/sync-template` writing into a consumer-owned file) is **dead** — it existed only to cover
a Copilot gap that does not exist, and carried the v0.20.0 clobber risk into a new place for no
remaining benefit.

**Migration asymmetry, the best property here and invisible in rev 1:** the **Copilot leg needs no
consumer action** — the file appears at the next update, so existing consumers are fixed silently.
The **Claude leg needs one line, once** (the `@import`), which is now small enough for Option E's
conditional machinery: `session-start` is unprotected and already reads conditionally, so it can
inject the rules **only when the import line is absent** — no double-context cost for migrated or
greenfield consumers, which is exactly what sank Option D.

**Canary 3 RUN 2026-08-05 — `applyTo` breadth is load-bearing; no collision with B-17.**
Three arms, identical fileless prompt, a real `Program.cs` present so `**/*.cs` had a match:
`"**"` → delivered; `"**/*.cs"` → **not** delivered (`NOT-IN-CONTEXT`); **no frontmatter → delivered**.
Script: `.claude/scripts/canary-applyto-scope.ps1`.

- Framework rules must ship broadly scoped — a narrow `applyTo` does not reach a prompt that names no
  file. Use explicit `applyTo: "**"` rather than omitting frontmatter: both work, but the explicit
  form states intent instead of leaning on an undocumented default.
- **The B-17 collision flagged in rev 3 was overstated, twice over.** B-17's "no `applyTo: **`
  variant" is scoped to its own item — *scoped instruction delivery for **test files*** — and rejects
  a broad variant *of the test-integrity rules*, not a separate framework-rules file. Correction
  recorded rather than quietly dropped.
- **Better: canary 3 validates B-17's premise with evidence it never had.** Narrow scoping really
  does gate delivery on the model touching a matching file, which is exactly the "highest marginal
  salience" property B-17 wants. The two designs are complementary. **B-17 should cite this result.**

**Canary 4 RUN 2026-08-05 — POSITIVE on VS Code agent mode, and it also settles stale-`AGENTS.md`
precedence.**

> **Correction to an earlier entry here:** this said the GitHub Copilot extension was not installed
> and VS Code was therefore untestable. **Wrong.** `code --list-extensions` **excludes built-ins**,
> and VS Code 1.128 ships **`GitHub.copilot-chat` v0.56.0 as a built-in** under a versioned install
> path. Method lesson: `--list-extensions` is not an inventory of what the host can do.

Fixture set the two sources against each other — the state every already-installed consumer is in:
fresh `NIMBUS-2X9K` in `.github/instructions/` (unprotected) versus stale `OBSOLETE-1A1A` in
`AGENTS.md` (protected). **Result: `NIMBUS-2X9K`.**

1. **`.github/instructions/` reaches VS Code agent mode**, not just the CLI.
2. **Fresh instructions beat the stale protected mirror** — the risk that could have sunk the design.
   Had `AGENTS.md` won, every existing consumer's stale copy would override what we deliver and
   Option A would ship text that never takes effect.

**Evidential status:** a single **manual** observation reported by the maintainer, with no captured
transcript or tool-use check, unlike canaries 1–3. Strong (the *discriminating* value was returned,
not the more conspicuous root-level one) but n=1 and unautomated. Re-run if VS Code or the built-in
Copilot version moves.

**Also resolves a B-17 claim:** *"works today with Preview hooks off"* is now supported for VS Code
agent mode. Instruction files are a native Copilot feature and do not depend on the Preview hooks
machinery, so the hook-availability caveat governing `session-start` output does not apply to this
path. **B-17 should cite canary 3 and canary 4.**

### B-97 DESIGN COMPLETE — every question closed by observation

| Question | Answer | Evidence |
|---|---|---|
| `@import` resolves from a root `CLAUDE.md`? | Yes | Canary 1 (zero tool calls) |
| `.github/instructions/` reaches Copilot CLI? | Yes | Canary 2 (+ negative control) |
| Narrow `applyTo` delivers on a fileless prompt? | **No** — ship `"**"` | Canary 3 |
| `.github/instructions/` reaches VS Code agent mode? | Yes | Canary 4 (manual) |
| Stale `AGENTS.md` overrides it? | **No** — fresh wins | Canary 4 (manual) |

Nothing rests on an assumption about host behaviour any more. **Ready to implement**, and B-96/B-99
are unblocked on the delivery axis (B-96 still gated separately by B-98 step 1's routing question).

**Design step 3 — the fingerprint manifest — is BUILT (2026-08-05).**
`.claude/scripts/build-block-manifest.ps1` (meta script, PS-only per WSD-005) →
`meta/block-manifest.json`. It walks the release tags, extracts each framework-owned block from the
shipped `CLAUDE.md`/`AGENTS.md` at that release, normalises and hashes it, and records the release
range each hash was current for. That is the basis the honest drift row and Option E's conditional
discovery both need, and it is the same artifact for both.

Scope: only the four blocks `/bootstrap` is documented **not** to rewrite — Verification Rules,
Leanness, SOLID, Agentic Workflow. Boy Scout Rule and Conventions are bootstrap-populated
(`bootstrap.md` Phase 3a), so fingerprinting them would report divergence for every consumer and
mean nothing.

Observed: 33 releases (v0.26.0 → v0.44.0), 3 dists × 2 files, **0 unavailable**, byte-identical
across regeneration. 8 KB.

**What it establishes empirically — four framework-owned block changes that reached no existing
consumer:**

| Block | Changed at | Note |
|---|---|---|
| Verification Rules | v0.29.1 | |
| Leanness | v0.34.3 | Independently rediscovers the changelog's own record (`CHANGELOG:199-201`, "Leanness rule #7…") — the manifest and the changelog agree from different directions |
| Agentic Workflow | v0.27.0, v0.30.0 | |
| SOLID | — | unchanged since v0.26.0 |

The `AGENTS.md` mirror shows the same v0.29.1 boundary as `CLAUDE.md`, which incidentally
corroborates meta-invariant #2 holding across history.

**Coverage limit, recorded rather than papered over:** tags in this repo begin at the monorepo merge
(v0.26.0). The protection landed at **v0.20.0**, so consumers installed between v0.20.0 and v0.25.x
cannot be fingerprinted from here — their blocks live in the archived legacy repos. They must
classify **UNKNOWN, never CURRENT**. The manifest carries this in its `coverage.limitation` field so
a consumer-side check cannot quietly overstate what it knows.

**Verification (Maintenance model #4 — the instrument was seen to go red before its green counted):**
`-SelfTest` asserts block extraction, non-bleed into the next section, formatting-invariance
(CRLF / trailing whitespace / BOM), content-sensitivity, hash shape, a golden vector, and null on an
absent heading. Red-tested twice by planting defects in a scratch copy: removing the per-line
`TrimEnd` → `[FAIL] trailing whitespace`, exit 1.

**The second red-test found a real defect in the test itself, and is the reusable lesson.** Collapsing
the digest to a single hex character — destroying 15/16 of its discrimination — **passed**, because
"the two hashes differ" is still ~94% true for a broken hash. B-75's class exactly: an assertion too
weak to fail, reading as green. Fixed by pinning hash *shape* (`^[0-9a-f]{16}$`) and a golden vector,
both of which fail deterministically; the same planted defect now trips two assertions. Generalisable:
**an assertion that two values differ is not a test of the function that produced them.** Worth
carrying into B-84 (red-test kit) and B-59 (inert-check detection).

**Still to do here:** the consumer-side check that consumes the manifest, whose wording is settled
(`DIVERGED — protected file not synchronized with installed machinery; review required`, never "you
are behind"). Deferred deliberately: it belongs in `framework-doctor` or `docs-sync-check`, both of
which ship as `.ps1`/`.sh` twins [#3], and its home depends on whether A or B wins — which the two
canaries decide. Building it now would be building it twice. The manifest currently lives in `meta/`
for the same reason; it moves to `src/core/.claude/` when a shipped artifact consumes it, and not
before (Leanness #1 — do not ship an 8 KB file nothing reads).

#### Changelog sweep, 2026-08-05 — how long this has been true, and what it cost

**The protection was introduced deliberately, as a correct fix, in v0.20.0 (2026-06-11).** Shipped
changelog `:777`: *"**Update runs no longer clobber consumer content**: re-running the installer on a
repo stamped with `.claude/framework-version.json` refreshes the framework machinery but restores the
consumer-owned content files listed above (**previously a re-run overwrote a populated `CLAUDE.md`
with the template**)."*

That fix is right and must not be reverted — clobbering a bootstrapped `CLAUDE.md` is a worse failure
than not delivering to it. **The defect is that its side effect was never traced.** Protecting the
file from being overwritten also permanently severed the delivery of the *framework-owned* blocks
inside it, and nothing in the release since has noticed. This is the root-cause shape worth keeping:
**a correct fix silently created a second failure in the same file, and no gate looks for it.**

Current shipped version is 0.44.0, so **every release from 0.21.0 onward has shipped `CLAUDE.md`
content that reaches no already-installed consumer.** Claims in the shipped changelog affected
(consumer-facing text, all written as though delivered):

| Version | Claim | Reaches an existing consumer? |
|---|---|---|
| 0.22.0 | Test-integrity rules, `CLAUDE.md`/`AGENTS.md` > Leanness #14–16 (`:734`) | No |
| 0.23.0 | §1 rails made canonical + `AGENTS.md` §1 verbatim mandate (`:705,717-720`) — the fix that made workflow disciplines reachable on Copilot at all | No |
| 0.23.3 | `AGENTS.md` portable-rule sections made byte-identical to `CLAUDE.md` (`:674-676`) | No |
| ~0.28 | Verification-Rule-7 parenthetical (`:566`) | No |
| ~0.34 | Leanness rule #7 wording (`:201`) | No |
| 0.36.0 | `CLAUDE.md > Conventions` — xUnit demoted to greenfield-only (`:163-165`) | **No — and this one answered field report #1** |
| 0.44.0 | `FRAMEWORK-CONTEXT.md` hazard-area changes (`:41,48,53`) | No |

**Two consequences worth acting on.**

1. **v0.36.0 is the sharpest case and should be re-checked before anything else.** It answered a real
   field report from a real install (ledger #1 — a repo whose existing NUnit suite the framework kept
   overriding toward xUnit). Its fix was split: the `add-tests` and `enforce-standards` halves are
   **skills**, which are unprotected and do deliver; the `CLAUDE.md > Conventions` and
   `.github/copilot-instructions.md` halves do not. So the reporting consumer received *part* of
   their own fix. Nobody knew which part, because nothing measures this.
2. **The framework has been shipping half-fixes without knowing which half lands.** Any release that
   touches both a skill and `CLAUDE.md` delivers the skill half only. That is not an argument for
   putting more in skills — it is an argument that **the release process must state the delivery
   surface per item**, which is cheap and can ship independently of whatever B-97 decides. Candidate:
   a `release.ps1` prompt or a changelog convention marking each entry as *machinery* (delivers) or
   *protected* (greenfield only). Note the honest version of this makes the changelog less flattering,
   which is the point.

**Cross-links:** B-78 (the warehouse-specific instance — four populations no signal reaches; this is
its general form, and solving B-97 likely subsumes part of it), B-46 (consumer update & drift story),
B-96 (blocked by this).

---

**B-98 is DONE (2026-08-20) — all three steps of its *Do* are shipped, confirmed by triage against the tree; see `meta/BACKLOG-DONE.md`.**

### B-99 · Nothing tells the model not to re-do a resolution an earlier stage already performed
**Filed against:** v0.44.0 (2026-08-05)
**Effort:** S–M · **Priority:** P2 · found 2026-08-05 (generalised from ledger report #4) · **Invariants:** #1 #2

**Why:** the warehouse defect in report #4 is one instance of a class. When an earlier stage has
already decided something — matched a key to a specific version, deduplicated, applied a tenant or
soft-delete filter, converted a currency or unit, normalised a timezone — downstream code that redoes
it "to be safe" is not defended, it is broken. It silently drops or double-counts rows.

The class is systematically under-caught for two reasons, both visible in report #4. It fails
**silently** — a low row count, not an exception. And a defensive predicate reads in review as *extra
care*, so it survives the scrutiny a missing filter would not. The model is biased toward adding
guards; nothing in the framework is biased against redundant ones.

Nothing covers it today. **Verification Rule 10** ("Derive, don't assume") covers *technology
presence* — is EF Core actually in this repo — not *semantic invariants of the existing system*.
The plan gate (§2) asks for assumptions but defines no schema and no verification obligation, and it
catches uncertainty, which is the wrong instrument: the model was confident and wrong.

> **DELIVERY PREMISE REFUTED, 2026-08-05 — read this before implementing.** This entry was filed
> claiming to be *"the only warehouse-adjacent fix not blocked"*, on the reasoning that a Verification
> Rule escapes B-97 because `/bootstrap` rewrites Conventions and not the always-on blocks. The
> bootstrap half of that is true; the conclusion is false. The **installer** protects the whole of
> `CLAUDE.md` on update — snapshot, copy, restore (`dist/dotnet/scripts/install.ps1:30-31, 74-81,
> 115-123`) — so a shipped Verification Rule never reaches an existing consumer, and `/rebootstrap`
> has no template source to deliver it either. **B-99 is blocked by B-97 exactly as B-96 is**, and
> B-97 has been rewidened accordingly. Found by adversarial review asking the delivery question first;
> the reviewer verified the bootstrap boundary and correctly flagged the update mechanism as an
> *inference* rather than a fact, which is what sent me to the installer.
>
> What survives: the **rule content** below is still right, and the class is still real. What changes
> is that it has no vehicle until B-97 is decided — and if B-97 lands on "route durable guidance to
> skills", this becomes skill content, not a Verification Rule, which is a different design.

**What still makes it worth its own entry rather than folding into B-96:** the class is not
warehouse-specific and not .NET-specific — it applies to any stage boundary in any stack, and B-96's
skill is a .NET/monorepo artifact that Angular consumers never receive. Whatever vehicle B-97
settles on, this content should not be filed inside a warehouse recipe.

Placement, *if* the vehicle turns out to allow an always-on rule:
`src/stacks/{dotnet,angular,monorepo}/snippets/CLAUDE.md/verif-rule9` carries rule 10 identically in
all three, so rule 11 appends there without a new `src/core` marker. (The marker name is one behind
its contents; not worth renaming across three stacks.)

**Do:** design and critique before writing. The draft rule — *"Don't re-resolve what an earlier stage
already resolved… identify which stage owns that resolution and confirm from the code that it has not
already run. If you cannot confirm, say so rather than adding the predicate"* — is a starting point,
not a locked text. Settle in review:

1. **Does it bite with no domain context?** It must have prevented report #4 while the warehouse prose
   was absent from the window — that is the condition an already-bootstrapped consumer is in. Test the
   draft against the defect with the DW text withheld.
2. **Does it stay off the legitimate cases?** It must *not* flag the run dimension, a genuinely needed
   soft-delete filter, or defence at a trust boundary (re-validating untrusted input is correct and
   must not be discouraged — this is the sharpest failure mode of the rule as drafted).
3. **Eleventh always-on rule, or a §2 plan-gate sub-bullet?** Reviewed: the always-on block is the
   right instrument *if* a vehicle exists. The plan gate is weaker here because it asks the model to
   surface **assumptions** (`src/core/CLAUDE.md:161-168`) and this incident was a confident,
   apparently-defensive decision — no assumption was felt, so none would be surfaced.
   Cost, **corrected**: the ceilings in `meta/context-footprint.json` are **characters**, not tokens
   — counting rule `LF-normalized UTF-8 bytes; ~tok = round(chars/4)` (`:4-8`). Dotnet's headroom is
   **1,429 characters ≈ 357 tokens**, not "~1,429 tokens" as this entry first asserted. A ~650-char
   rule therefore consumes **~45% of remaining dotnet headroom** — still affordable once, decisively
   not twice, and the earlier framing made it look ~4× cheaper than it is. Re-run the footprint
   instrument on the composed result; do not estimate.

**Review outcome on the draft wording (2026-08-05): the original draft was rejected as non-biting.**
It asked the model to identify "a resolution it has already performed" — but the model must first
*classify* `EffectiveTo IS NULL` as a re-resolution, and absent warehouse context it classifies it as
an ordinary defensive filter, so the rule never fires. A rule that reads well and does not fire is
worse than none, because it gets recorded as a fix. The correction is to trigger on an **observable
action** rather than an abstract category. Working draft:

> **Do not override an upstream decision without tracing it.** Before adding a downstream join
> condition, filter, deduplication, conversion, or "current/latest" predicate, trace whether the
> upstream stage already encoded that decision in the value or identifier being consumed. If it did,
> preserve that decision; reapply it only where this stage independently owns it. This does not
> prohibit validating untrusted input at a trust boundary, nor independently required authorization,
> tenant-isolation, soft-delete, or read-time selection rules. If ownership cannot be confirmed from
> code, state the uncertainty instead of adding the condition as a precaution.

Two things still to settle on this text: it is ~650 characters against a ≤600 target, so it needs
tightening or an explicit budget exception; and the carve-out list is broad enough that it may
swallow the rule — a *redundant* tenant filter is the same defect class, and "independently required"
is doing heavy lifting to exclude it.

**Still unproven, and the reviewer's own weakest-point call:** placement and budget do not establish
that the wording changes behaviour. It needs an incident-shaped evaluation with warehouse guidance
withheld — which is the **B-41** harness, the same instrument B-96's ship gates and B-98 step 1
depend on. Do not claim this rule works on the strength of it reading well.

**Not:** no DW-specific text in static context (that belongs in the skill, B-96 §3.4); no second
always-on block; no hook change — `route-prompt` injects the §1 rails and plan gate, not the
verification rules.

**Cross-links:** B-96 (the warehouse instance and its §3.4 sixth rule; this is the general form),
B-97 (why the Conventions route was unavailable and this one is not), B-98 (why the skill route is
gated and this one is not), B-32/WSD-017 (the context-footprint gate this must pass), ledger report
#4 in `meta/field-reports.md`.

---

**B-100 is DONE (2026-08-21) — the staged-set scan closes the shell-authored bypass, and the guard's real boundary is now shipped; see `meta/BACKLOG-DONE.md`.**

### B-112 · RCA: every behavioural instrument's first version could not produce the result it claimed to test for
**Filed against:** v0.47.0 (2026-08-06)
**Effort:** S (the rule) · M (the sweep) · **Priority:** P2 · filed 2026-08-06 · **Invariants:** #5
· generalises B-72; sibling of B-64/B-74/B-75 on the deterministic side

> **TRIAGE 2026-08-20 — PARTIALLY DONE. The rule is shipped and must not be reimplemented; the
> scenario-level follow-through is what remains.** The "constructible success world" half is now part
> of Maintenance model rule 4 in `CLAUDE.md`, and the 15-scenario reachability/saturation sweep is
> recorded in this entry.
>
> **Four named follow-ups are still open, and each is concrete:**
> 1. `archived-redirect` — repair it so *operational* success gates the scenario and prose is
>    secondary. History still shows three failures with `redirectedHandoff=False`, one of them on an
>    operationally correct run; the grader is still live.
> 2. `docs-tier-nopointer` — resolve the interpretation from the typed signals; its latest rows are
>    still INCONCLUSIVE/FAIL rather than a settled reachability result.
> 3. A **bare `route-fix` arm** has still never been run, so its saturation is still unassessed.
> 4. `skill-add-tests` — the disposition (compliance evidence, not routing evidence) exists in this
>    entry's audit text but not at the scenario definition, where a reader would meet it.
>
> Then record a stable reachability + saturation verdict **beside each scenario**, which is the part
> of the *Do* that makes the sweep durable rather than a one-time document.
>
> **Cross-link:** B-72's remaining grader fix (provider-vs-interface) is a *separate* deliverable —
> this entry's scenario work does not subsume it.

**Why:** three behavioural instruments were built or specified in this repo, and **all three were
broken in their first version, each in a different direction.** None was caught by running it; all
three were caught by *reading what the instrument would actually be pointed at*.

| # | instrument | defect | direction | caught by |
|---|---|---|---|---|
| 1 | `angular-form-control` grader (B-72, v0.40.0) | `formInputs` missed `@Input() set x()` and `input.required<T>()`, so a value accessor re-declaring form state — **the reported defect** — scored PASS | **could not fail** | shipping B-66 |
| 2 | calibration probe (2026-08-06, rejected pre-run) | control arm removed the whole framework, not the block; `n=6` thresholds at p≈0.18–0.24; grader not deterministically implementable | **measured the wrong thing** | codex adversarial review |
| 3 | §6.2 falsification condition (2026-08-06, corrected pre-run) | `usedDeadColumn` cannot fall because the artifact the rule points at is silent on what the measure scores | **could not pass** | self-check before drafting |
| 4 | `warehouseDimensionBinding` fixture (2026-08-07, **voided a live run**) | the `-EnrichedMap` fixture map stated *"Region is not a direct fact dimension"* in bold — the exact conclusion `regionOnFact` scores — so the run measured the fixture's helpfulness | **could not fail** | re-reading the fixture *after* the first paid batch |

**Instance 4 is the first that got as far as spending money**, and it sharpens the entry in two ways.
First, the hazard was **already written down in the same file**: `run-agent-evals.ps1:429-431` warns
that the fixture's `CLAUDE.md` is deliberately silent on how to reach an attribute because "naming the
dimension path here would hand the model the answer this scenario exists to measure". The defect was
reproduced one artifact over, in the map, by someone who had read that comment. A warning sited on one
artifact does not generalise to its siblings on its own.
Second, it suggests the cheap mechanical guard this entry has been missing: **for each outcome the
grader scores, assert that no fixture artifact states that outcome's conclusion.** That is a
string-scan, it is red-testable, and it now exists for this one grader — see the `$tell` sweep in the
harness self-test. Generalising it to the other graders' fixtures is the concrete "do" here.

**Why no gate caught any of them.** No gate can. These are experiment designs, not code — `bash -n`
parses them, `validate-dist` never sees them, and a behavioural probe's own `-SelfTest` only proves
the grader is self-consistent, not that it is *pointed at the right thing*. Instrument #1's
`-SelfTest` was green throughout, which is precisely B-59's inert-check class one level up.

**The actual root cause, and it is a gap in a rule this repo already wrote.** B-72 established:
*"a behavioural probe is only a red test once it has been shown to **fail** on the unfixed tree."*
That rule is **one-directional**. It catches instrument #1 (could not fail) and would catch nothing
about #3 (could not pass) — a measure that always reports failure satisfies "shown to fail" trivially
and looks maximally rigorous while being void. §6.2 is the proof: its falsification condition would
have fired for a rule that worked perfectly, and the resulting false negative would have read as a
*principled* result, which is worse than an obviously broken one.

**Do — add the missing half to the maintenance model, next to B-72's rule:**

> **Name the world in which the measure would register success.** For every outcome measure, state
> the concrete, constructible state of the repository/fixture under which it would report the
> desired result. If no such state can be named, the measure is **unreachable** and the experiment
> is void before it runs. Record that state next to the measure, as B-72's rule already requires for
> the failing observation.

Both directions, stated together: an instrument must be shown able to **fail** on the unfixed tree
*and* able to **pass** on a constructible fixed one. Cheap — both are reading exercises, and all
three defects above were found by reading rather than running.

> **HALF DONE — the rule shipped; the scenario sweep did not. Rescoped 2026-08-18.** The quoted rule
> above is now in `CLAUDE.md` Maintenance model #4 verbatim ("*And the other direction — name the
> world in which the measure would register success*"), so **this entry's first `Do` is discharged**
> and must not be re-implemented. What remains open is the *second* `Do` at the foot of the entry —
> fix (1), re-check (2), run a bare arm for (3), re-label (4), and record a reachability +
> saturation verdict beside every scenario. That is scenario work in the eval harness, not a rule
> change, and it is the only part still owed.
>
> A live instance of the same class landed the same day this was rescoped, on the *deterministic*
> side: three new exit-code assertions were red-tested by appending `exit N` to the end of two
> scripts that each already end with their own terminal `exit`. The mutation never executed, all
> three suites reported green, and green read exactly like "the assertion is inert". The mutated
> line must be shown to be **on the executed path**, not merely present in the file — see B-144.

**What else is exposed to the same class — the sweep.** Every scenario in `.claude/evals/` has an
outcome measure whose reachability has never been stated:

- `warehouseRouting`'s `usedDeadColumn` — **confirmed unreachable today** (§6.3). The fixture map is
  ETL-only; no configuration of the current fixture makes it fall.
- `angularFormControl` — B-72 already records that the scenario passed with **no forms guidance
  shipped at all**, i.e. its measure may be saturated rather than unreachable. Same family, opposite
  end.
- `docsTierProbe`, `skillArtifactAndVerification`, `testBeforeProduction`, `installHandoff`,
  `archivedRedirect`, `guardBlockedThenSafe`, and the three `haiku*` finding graders — **none
  assessed.** Assess each for both directions and record the answer in `meta/eval-results.md` or
  beside the scenario, rather than re-deriving it per experiment.

**Not:** do not fold this into B-64. B-64's subject is deterministic gates and diagnostics, where
planting a defect is trivial and the discipline already exists. This entry's subject is
**behavioural** instruments, where you cannot plant a defect in a model and the reachability of the
measure is therefore the only thing you *can* check in advance.

**Cross-links:** B-72 (the one-directional rule this completes, and instrument #1), B-59 (inert
checks), B-64 (the deterministic sibling), B-74 (a harness that cannot report failure), B-75 (an
assertion too weak to fail), B-41 (the harness all of these run on), B-96/B-98 (the items whose
sequencing §6.3 unblocked).

---

#### SWEEP DONE 2026-08-06 — all 15 scenarios assessed, by reading + the recorded run history

Method: for each measure, (a) can a constructible state make it report success, and (b) has it
**ever been observed** reporting success in a *valid* run. (b) is the empirical form of (a), and it is
decisive: a conjunct never once observed True across every run ever recorded is the signature of an
unreachable measure. Pre-2026-07-17 rows are excluded — `meta/eval-results.md:8-13` invalidates them.

| scenario | ever PASSed (valid runs) | verdict |
|---|---|---|
| `install-handoff` | 4 | reachable, demonstrated |
| `guard-retry` | 3 | reachable · **cannot saturate** |
| `haiku-bloat-radar`, `haiku-debt-radar` | 2 each | reachable · **cannot saturate** |
| `haiku-convention-check` | 1 | reachable · cannot saturate |
| `docs-tier-ondemand` | 2 | reachable · partial saturation (B-65) |
| `docs-tier-inline` | 1 | reachable |
| `route-fix` | 2 | reachable · **saturation UNASSESSED** |
| `skill-add-tests` | 1 | reachable · **measures compliance, not routing** |
| `angular-form-control` | 1 | **SATURATED** — B-72: passed with no forms guidance shipped |
| `warehouse-route-p1/p2/p3` | `r` **never** True | `usedDeadColumn` **UNREACHABLE** (§6.3) |
| `docs-tier-nopointer` | **0** (INCONCLUSIVE/FAIL/ERROR only) | **undemonstrated** |
| `archived-redirect` | **0** (3 FAIL, 0 PASS, ever) | **see below — the finding** |

**1. `archived-redirect` has never passed, and one of its failures had demonstrably correct
behaviour.** All three valid runs (`meta/eval-results.md:66,79,91`) report `redirectedHandoff=False`
— **that conjunct has never once been observed True.** The third run is the damning one:
`currentStamp=True canonicalInstallerTool=True archivedInstallerTool=False commits=2`. The model did
exactly the right thing operationally — installed from the canonical source, did not run the archived
installer, produced the stamp and a commit — and the scenario still scored FAIL, solely because its
closing prose did not satisfy a **three-regex conjunction** (`(?i)archiv|redirect` **and**
`(?i)canonical` **and** `(?is)developer.+/bootstrap`) over free-form output
(`run-agent-evals.ps1:409`).

That is a measure that scores *how the model narrates*, not what it did, and it gates the whole
scenario. B-33 exists to make the archived repos route an agent correctly; this is the instrument
that would tell us whether they do, and it has produced three false negatives and zero signal.
**Fix:** score the operational conjuncts (stamp, canonical installer, no archived installer, commit)
as the outcome, and demote the prose match to a reported-but-not-gating signal — or replace the
free-form regexes with one, chosen because a correct run must produce it. Then re-run and confirm
the measure can reach True at all before citing any archived-redirect result again.

**2. `docs-tier-nopointer` has also never passed** — and it is precisely the arm B-65's 2026-07-31
amendment leans on when it says agents reach on-demand `docs/` files unaided. That amendment cites
"one valid no-pointer run" where the agent opened the file; the ledger shows the *scenario* never
scored PASS. Those are compatible (`loaded=True` with `followed=False` still fails), but the entry
reads as stronger evidence than the instrument has produced. Re-check B-65's claim against the actual
rows before it is used to justify keeping or dropping the pointer.

**3. `route-fix`'s saturation is unassessed and the risk is high.** Its measure is red-test-then-fix;
a competent model does that unprompted as ordinary practice. It has never been run bare, so its 2
PASSes cannot currently be attributed to the framework. Same shape as `angular-form-control`, which
*was* checked and turned out saturated.

**4. `skill-add-tests` measures the wrong thing, mildly.** Its prompt opens *"Use the add-tests skill
to…"* (`scenarios.json:31`), so `usedSkill` is telegraphed. It is a valid test of *following an
explicit instruction* and no evidence at all about routing — which matters because B-98 is about
routing, and this scenario looks like it speaks to that.

**The design principle this sweep extracted, and the most reusable output here:** the measures that
**cannot saturate** are exactly the ones whose success signal is *physically producible only by the
framework* — `guard-retry` needs a real PreToolUse block in a tool result, and the `haiku-*` trio need
an output format defined by a shipped agent. The saturated and unreachable ones all score **model
prose or ordinary competence**. Prefer measures whose success signal the artifact under test must
generate; treat any measure scoring free-form narration as suspect until shown otherwise.

**Do:** fix (1), re-check (2), run a bare arm for (3), re-label (4), and record a reachability +
saturation verdict beside every scenario so this is never re-derived.

---

**B-123 is DONE (2026-08-20) — the owed v0.48.0 post-ship review was performed and produced B-154; see `meta/BACKLOG-DONE.md`.**

### B-129 · Design and review the warehouse reporting consumption layer
**Filed against:** v0.51.0 (2026-08-08)
**Effort:** M–L · **Priority:** P2 · filed 2026-08-08 · **Capability:** warehouse technical leadership

**Why:** `map-warehouse` records consumption views/marts and teaches a report author to follow the
warehouse's proven joins, but the framework has no end-to-end recipe for creating or enhancing the
consumption surface itself. It does not explicitly decide between a reporting view, parameterised
stored procedure, table-valued function, materialised/indexed view, semantic-model object, or a new
mart; nor does it require a stable grain, metric contract, parameter behavior, security boundary,
compatibility plan, or BI-tool-friendly result shape. Copying an existing join path is necessary but
not enough to design a trustworthy reporting interface.

**Do:** design guidance for building and reviewing reporting stored procedures, BI/reporting views,
and equivalent SQL consumption artifacts. Start by identifying the consumer and workload, then
choose the smallest appropriate publication surface using repository and platform conventions.
Require:

1. an explicit result grain and row-uniqueness contract;
2. fact/dimension joins justified by the warehouse map, including role-playing and version-resolution
   semantics, fan/chasm and many-to-many handling, and no accidental fact multiplication;
3. canonical metric definitions, aggregation/additivity rules, filters, time/calendar semantics,
   currency/unit treatment, null and unknown-member behavior, and totals/reconciliation expectations;
4. a stable output contract — names, types, ordering guarantees only where real, parameters and
   defaults, inclusive/exclusive date boundaries, paging or extract semantics, and compatibility for
   existing consumers;
5. security and governance at the reporting boundary, including least privilege, sensitive-column
   exposure, row-level filtering where the platform uses it, and safe parameterisation/dynamic SQL;
6. workload-aware choices for predicate pushdown, sargability, plan stability, materialisation,
   indexes, refresh behavior, and BI query patterns, without asserting performance absent evidence;
7. repository-native deployment, ownership/documentation, representative correctness tests, and
   comparison to source/control totals and existing reports.

The guidance must distinguish reusable governed datasets from one-report projections, interactive
queries from scheduled extracts, and semantic definitions from presentation formatting. It must not
make stored procedures, views, or denormalised marts a universal default, and must abstain when the
business definition or consumer contract is missing.

**Framework fit:** this is the write/review counterpart to `map-warehouse`'s existing read-side
rules. It establishes its fact target from current evidence (B-124 shipped no decision artifact),
then consumes B-125's modelling findings, B-126's evolution and
downstream-impact contract, B-127's scoped metric lineage, and B-128's physical-design evidence.
Reuse the warehouse map's evidence/confidence vocabulary and the existing framework workflow
patterns; do not create a competing inventory, generic SQL-style guide, or vendor-specific default.
The design must decide whether this belongs as a bounded addition to existing warehouse skills or a
separately routed skill, using observed routing behavior and context cost rather than preference.

**What established practice says (checked 2026-08-11):** Microsoft's current Power BI guidance
starts from star-schema fact/dimension roles and consistent grain, recommends explicit measures when
summarization must be governed, avoids direct fact-to-fact many-to-many relationships, and requires
relationship plus RLS/OLS validation. Shared semantic models reduce duplicated definitions but make
dependency, permission, and compatibility analysis more important. SQL Server guidance treats stored
procedures as permission and parameter boundaries, while warning that dynamic SQL breaks ordinary
ownership-chain assumptions and still requires parameterization, least privilege, and injection
review. Kimball keeps facts aligned to a physical measurement event and classifies measures as
additive, semi-additive, or non-additive; a reporting contract cannot safely infer totals from a
column name. These sources support consumer/problem-first artifact choice, explicit semantic and
security contracts, and representative reconciliation rather than a universal “use a view/proc/mart”
rule. Sources: [Power BI star-schema guidance](https://learn.microsoft.com/en-us/power-bi/guidance/star-schema),
[Power BI many-to-many guidance](https://learn.microsoft.com/en-us/power-bi/guidance/relationships-many-to-many),
[Power BI model relationships](https://learn.microsoft.com/en-us/power-bi/transform-model/desktop-relationships-understand),
[Power BI consumer security planning](https://learn.microsoft.com/en-us/power-bi/guidance/powerbi-implementation-planning-security-report-consumer-planning),
[Power BI RLS guidance](https://learn.microsoft.com/en-us/power-bi/guidance/rls-guidance),
[SQL Server stored procedures](https://learn.microsoft.com/en-us/sql/relational-databases/stored-procedures/stored-procedures-database-engine),
[secure dynamic SQL](https://learn.microsoft.com/en-us/sql/connect/ado-net/sql/writing-secure-dynamic-sql),
[SQL Server execution context](https://learn.microsoft.com/en-us/sql/t-sql/statements/execute-as-clause-transact-sql),
[Kimball facts and grain](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/facts-for-measurement/),
and [Kimball additivity](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/additive-semi-additive-non-additive-fact/).

**Fresh-context adversarial review (Codex, 2026-08-11; does not satisfy the Opus gate):** verdict
**REDESIGN before Opus**. The reviewer found that a new skill is currently infeasible: canonical
`meta/context-footprint.json` records dotnet at 39,527/40,000 and monorepo at 47,884/48,000 static
Claude characters, leaving 473 and 116 respectively, while current warehouse frontmatter alone is
740–901 characters. The first plan also mixed database publication, semantic governance, and report
presentation; could grade repository prose as human authority; lacked an attribution-safe A/B;
assumed one result grain; used potentially correlated reconciliation oracles; and spread into BI
platform architecture. The narrower SQL-publication investigation below folds those findings.

**Implementation plan — revised investigation and conditional design:**

1. **Authorise Phase 0 only:** a bounded SQL reporting-publication experiment choosing among
   `extend existing database surface`, `new composable view`, `parameterized stored procedure`, or
   `no new database surface / ask`. Semantic-model authoring/security, marts, materialisation,
   cross-platform variants, presentation/report-local logic, and automatic migration are successor
   scopes requiring separate observed harm and review.
2. Freeze three matched scenario pairs plus one abstention control on the one scriptable host that
   demonstrably loads skills: reusable/composable consumers favoring a view; scheduled parameterized
   extract favoring a procedure; one-consumer/no-reuse favoring no new database surface; and missing
   or conflicting metric authority. Keep DDL/data constant within each pair and vary one decision fact
   (reuse, interaction, security boundary, or lifecycle) without telegraphing artifact names.
3. Run a controlled matched A/B: A is unchanged framework; B is the identical fixture/prompt with
   only the candidate bounded guidance injected through the feasible existing carrier. Pin host,
   model/version, fixture commit, budget, timeout, and randomized/interleaved order. Pre-register
   per-scenario thresholds; replace error/truncation/cannot-run trials under a fixed cap and report
   them separately. Score workflow routing, skill selected/read, decisive artifacts read, publication
   choice, and contract correctness as separate outcomes. Close/narrow B-129 unless B materially and
   repeatedly fixes a defect attributable to framework guidance.
4. The feasible default carrier is a tightly bounded write-side section in the existing authored
   dotnet `map-warehouse` `.claude`/`.github` mirrors, composed into dotnet and monorepo. Measure its
   on-demand body delta and any frontmatter change independently, and require context-footprint green.
   A new skill is not a candidate unless a named static-context subtraction first leaves every ceiling
   green and a separate routing test proves the trade worthwhile. `route-prompt` governs generic
   workflow intent, not skill selection; modify it only on repeated workflow misclassification.
5. Define the SQL publication request before artifact choice: named consumers and owner; composable
   interactive querying versus scheduled parameterized extract; question/decision; freshness/as-of;
   parameter/filter/paging/export contract; expected scale; caller/service identity and sensitive
   fields; existing consumer/deprecation obligations; SQL platform/version/deployability; metric
   implementation source; and authority status. Missing evidence yields one scoped question or draft
   explicitly marked unapproved, never invented intent.
6. Separate semantic evidence states: `Repository-supported definition`, `User-provided authoritative
   source` with exact scope, `Named authority confirmation required`, or `Conflicting/unknown —
   abstain`. A role-like filename, owner field, or confident prose never proves authority/currentness.
   Preserve implementation and publication definitions separately; conflicting same-named metrics
   block governed publication.
7. First decide semantic ownership (`database-owned definition` versus outside this item's scope),
   then choose only among database surfaces proven deployable and consumable by the named query mode.
   Unavailable TVFs, semantic objects, indexed/materialized views, marts, or BI-tool capabilities are
   absent from the candidate set, not losing options. Compare extension/view/procedure/no-new-surface
   on reuse, composability, parameterization, stable schema, permission boundary, repository
   convention, ownership, compatibility, and migration cost.
8. Require either one homogeneous result set with declared grain and executable uniqueness/cardinality
   assertions, or explicitly separated result sets/row types with their own grain and discriminator.
   Record schema/types/null and unknown-member behavior; join cardinality; SCD interval overlap/gaps
   and as-of rule; role-playing dates; drill-across pre-aggregation; additivity/base measures; filter
   and date inclusivity; stable total ordering plus tie-breaker and snapshot semantics for paging;
   parameter types/defaults/ranges; units/currency/rounding; and empty/error behavior.
9. Define a SQL Server security profile for each fixture: caller versus owner/definer context;
   ownership chain and cross-database boundary; direct base-object permissions; signing/certificate or
   impersonation/revert where evidenced; dynamic-value parameterization and dynamic-identifier allow
   list; service versus end-user identity; row restrictions; metadata visibility; export permission;
   and least privilege. Grade effective permissions for every identity, including direct-table bypass,
   broken chain, definer overreach, identifier injection, collapsed service identity, and role-union
   leakage—not mere presence of `GRANT`, parameters, or RLS text.
10. Discover repository-visible consumers through named SQL references, semantic/report metadata,
    pipeline/job definitions, deployment manifests, and catalog/query history only when supplied and
    provenance-rich; request owner confirmation for external populations. Access-limited/external is
    `UNKNOWN`, never none. For an existing incompatible consumer, require expand→migrate→contract,
    named notification/owner, dual-run reconciliation, deprecation gate, and rollback/forward-fix
    boundary; otherwise this phase may only draft the change.
11. Freeze an independent hand-authored answer table for each fixture, not generated from candidate
    SQL or an existing report. State as-of time, population, exclusions, units, rounding, tolerance,
    and authority status. Add metamorphic oracles: duplicating a dimension row cannot change additive
    totals; valid group splits recombine; ratios recompute from additive components; SCD boundary
    changes pick exactly the intended version; unauthorized roles see no protected rows/columns.
    Snapshot the public schema and parameter metadata separately.
12. Use a small factorial core: reuse one/many; interaction composable/scheduled; authority present/
    absent-conflicting; security caller-filtered/module-boundary; lifecycle no consumers/incompatible
    consumer. Blind graders to fixture labels and scan for answer leakage. Mutate artifact choice,
    decisive reads, grain/cardinality, duplicate joins, SCD boundary, date inclusivity, non-additivity,
    authority, direct-access leakage, dynamic identifiers, consumer completeness, and compatibility;
    show every deterministic assertion red→green and include false-positive controls.
13. Phase 1, only after a material A/B effect, may implement the bounded existing-skill section and
    repeat the diagnostic cases. Cross-host behavioral replication requires a specific host-delivery
    hypothesis; delivery verification still covers both mirrors, dotnet/monorepo composition,
    context-footprint, disabled/discovered skills, greenfield/update/brownfield same-name behavior
    through both installer twins and relevant root detection, compose/freshness, and `validate-dist`
    ×3. Protected consumer context and update-refreshed skill bodies are tested as distinct contracts.

**Proportionality:** the repository proves an absent dedicated recipe, no observed production harm,
and virtually no static-context headroom. Only the three-pair unchanged-versus-injected SQL
publication experiment is currently proportionate. If it proves a repeatable framework-attributable
effect, a bounded on-demand section in an existing skill is the maximum candidate. Semantic-model
authoring, BI security architecture, marts/materialisation, report design, catalogs, runtime services,
cross-vendor libraries, or automatic migration is not authorised.

**Status: OPUS GATE COMPLETE, DELTA-REVIEWED 2026-08-13 — LOCK WITH REVISIONS (narrowed).** See
`meta/workspace-decisions.md` WSD-042. The 5-fixture/5-axis factorial, and steps 6/10 (which duplicate
B-127's/B-126's still-unlocked deliverables), are rejected. Locked instead: one matched fixture pair
plus abstention control on artifact-choice-under-reuse only — no security or lifecycle fixture, and
no security oracle of any kind — gated behind a pre-registered precondition routing probe: 8
non-telegraphing prompts (2 families × 4 reps) plus an unchanged-description control batch, ≥75%
selection threshold, skill-selected/skill-read scored separately, byte-measured via the canonical
`context-footprint` scripts against the actual proposed text (not manual counting) confirming
monorepo stays ≤48,000. Sol's own carrier-cost argument was backwards — the skill *body* is
context-footprint-ungated; only the frontmatter delta is real budget. If the routing probe doesn't
clear its threshold, the finding is "carrier unreachable," not "no effect." **Done when:** the routing
probe clears (or doesn't — recording "carrier unreachable" closes the item without running the A/B);
if it clears, the matched pair + abstention control runs n≥2 and either shows a repeatable,
attributable effect (authorising the bounded body section) or shows none (closing B-129 with no
shipped change, WSD-037 pattern). Next: draft the frontmatter delta, run the routing probe.

**Phase 0 progress (2026-08-15):** the frontmatter delta is drafted and byte-measured (throwaway
branch `b129-routing-probe-measurement`, commit `154b16b`, unmerged — see `meta/eval-results.md` for
the exact headroom numbers). Sol built the routing-probe harness on `codex/b129-publication-routing-probe`
(commit `80c789e`): 16 new scenarios (8 prompts × 2 conditions), a `Set-PublicationRoutingCondition`
fixture-overlay function reading the measured delta via `git show` rather than duplicating it, an
outer-aggregation disposition function (`Get-PublicationRoutingDisposition`) with its own
self-tests exercising the threshold/carrier-unreachable logic directly — the class of bug B-127 found
in its per-trial-only self-testing. Self-tests green.

**Current blocked state:** the harness is built. Two live runs were voided by the account monthly
spend limit on 2026-08-15 and 2026-08-16. B-129 is blocked on that limit resetting (or being raised)
before the same live batch can produce a scoreable result.

**Live run VOIDED (2026-08-15):** the first live attempt failed on a PATH misconfiguration (no
trials ran); the second ran but the account's monthly spend limit was exhausted partway through,
producing 6 valid + 2 errored condition-A trials and 8/8 errored condition-B trials, all with the
identical `"You've hit your monthly spend limit"` API response. Full data and root-cause confirmation
in `meta/eval-results.md`'s "B-129 Phase 0 (WSD-042) — routing-probe attempt, 2026-08-15" entry. This
is **not** a harness defect and **not** a scoreable result either way — it is void. **B-129 remains
open, blocked on the account's monthly spend limit resetting.** Next: re-run the same 16-trial batch
(`.claude/evals/run-agent-evals.ps1 -Live -Scenario <the 16 warehouse-publication-routing-* ids>
-Model sonnet -TimeoutSeconds 600`) once budget is available; no code change is needed first. The
`codex/b129-publication-routing-probe` branch is uncommitted-clean and unmerged pending a valid result.
Do not delete branch `b129-routing-probe-measurement` (commit `154b16b`) before this item closes — the
harness reads the delta from it via `git show`.

**Live run VOIDED again (2026-08-15/16, attempt 2):** re-run ~24h after the first void. The monthly
spend limit had **not** reset — it hit again partway through (condition B: 4/8 valid, 4 errored, same
literal spend-limit API text as attempt 1), so this account's cap resets on a billing-cycle date, not
on a rolling window from the last hit; do not re-attempt on a short timer expecting a reset. Condition
A surfaced a second, distinct, non-spend-limit failure: both `reuse-monorepo-1/2` trials hit the
harness's own **per-trial** $1.25 budget cap after 36 real turns of substantive work each (6/8 valid,
2 errored on this separate cause). Full data and root-cause split in `meta/eval-results.md`'s
"B-129 Phase 0 (WSD-042) — routing-probe attempt 2" entry; disposition addendum in
`meta/workspace-decisions.md` WSD-042. **Still void, still open, still blocked on the account's
monthly spend limit resetting** (raise it at claude.ai/settings/usage, or wait for the billing-cycle
date — the account owner needs to check which). Separately flagged, not yet acted on: if a third
attempt repeats the per-trial budget-cap error on the same `reuse-monorepo` scenario shape, the
harness's $1.25 per-trial cap likely needs raising for that shape specifically before it can be
reliably counted.

---
**B-132 is DONE (2026-08-20) — the agent-eval runner declares its PowerShell 7 boundary and the wrapper proves it; see `meta/BACKLOG-DONE.md`.**

### B-133 · Make durable-learning promotion part of normal work, without turning reuse into truth
**Filed against:** v0.52.0 (2026-08-11)
**Effort:** S for the evidence/design phase; M only if the baseline justifies a shipped change ·
**Priority:** P3 · filed 2026-08-11 · **Invariants:** #1 #2 #3 #6 #7 · **Capability:** team knowledge

**Why:** `LEARNINGS.md` correctly preserves chronological observations while `docs/wiki/` holds
current, scoped, individually-verifiable claims. Promotion currently depends on a person or agent
remembering to invoke `remember-for-team`: `docs-sync` asks whether a durable learning deserves
promotion, and the shipped completion checklist already says to offer the skill when a session
*surfaces* a team-worthy gotcha, recipe, or failed approach. Neither sentence clearly covers the
common case raised by the maintainer: an **existing** learning materially helps later work and is
successfully revalidated. No missed promotion has yet been observed in a consumer repo, so this is
a plausible reliance-on-memory gap, not evidence for a new telemetry subsystem.

**What established practice says:** KCS makes reuse part of review, links reuse to the work that
used it, keeps article confidence visible, and treats reuse patterns as prioritisation input. It
also warns that link volume is an activity signal, while link **accuracy** is the meaningful
outcome; reuse-count auto-publication is described as a transitional practice, not the mature end
state. Google SRE similarly turns lessons into reviewed, owned follow-up and says an unreviewed
postmortem is ineffective. Applied here, reuse may nominate a claim for attention, but repetition
must never manufacture `verified` status or bypass the wiki's Evidence / Verify-by / PR-review
boundary. Sources: [KCS: Reuse is Review](https://library.serviceinnovation.org/KCS/KCS_v6/KCS_v6_Practices_Guide/030/030/040/020),
[KCS Article State](https://library.serviceinnovation.org/KCS/Knowledge-Centered_Success_Practices_Guide/301-Evolve_Loop/Practice_5_Content_Health/Technique_5.2),
[KCS Process Alignment Review](https://library.serviceinnovation.org/KCS/Knowledge-Centered_Success_Practices_Guide/301-Evolve_Loop/Practice_6_Process_Integration/Technique_6.3),
and [Google SRE Postmortem Culture](https://sre.google/workbook/postmortem-culture/).

**Rejected first design (fresh-context adversarial review, 2026-08-11):** the initial plan gave
learning entries stable IDs, appended structured successful-use receipts, nominated entries after
three receipts across two scopes, and added `.ps1`/`.sh` parsers. The reviewer rejected it as
disproportionate and identified defects that a raw counter concealed: an agent cannot establish
causality merely because normal task tests passed; repeated wrong guidance can accumulate; task
and scope identities are gameable/ambiguous; rare high-impact knowledge is penalised; erroneous
receipts need amendment and disposition states; contributor-controlled text creates a new
injection surface; and consumer-owned `CLAUDE.md`, `AGENTS.md`, and `LEARNINGS.md` are preserved on
update, so much of the proposed rule would not reach the installed population. Those findings are
incorporated below. **Do not resurrect IDs, counters, receipt blocks, threshold parsers, hook writes,
or automatic movement as the default implementation.**

**Implementation plan — Phase 0, test the premise before changing shipped guidance:**

1. Add a maintainer-only behavioral fixture with an existing dated `LEARNINGS.md` entry and four
   pre-registered cases: (a) the learning materially changes a task and the relevant verification
   succeeds; (b) it is merely read/cited; (c) it is applied but verification fails or causality is
   uncertain; (d) the session discovers a genuinely new durable fact. The grader must distinguish
   an offer/draft through `remember-for-team` from a claim that knowledge was already promoted.
2. Run repeated trials on every scriptable supported surface available (Claude Code, Copilot CLI,
   and an AGENTS-native route), recording unavailable surfaces as cannot-verify rather than pass.
   Red-test the grader against planted transcripts before trusting results. Pre-register the stop
   rule: if the unchanged framework reliably offers promotion in (a)/(d), does not offer it in
   (b)/(c), and preserves the PR-review boundary, close B-133 with no shipped change.
3. Exercise an **already-installed update**, not only a greenfield dist, and trace which instruction
   carrier and skill body each host actually reads. This is load-bearing because updates preserve
   consumer-owned files. Resolve or explicitly isolate B-130's pre-existing PowerShell-5.1
   `docs-sync-check` failure; a standalone green parser/test cannot be presented as integrated
   cross-host evidence.

**Phase A — only if Phase 0 demonstrates the gap:**

4. Tighten the existing completion-checklist sentence on the update-delivered framework-rules
   carrier (and its canonical workflow/rendered mirrors as composition requires): when a
   **specific existing** learning materially affected completed work or was freshly reverified,
   identify it in the final response and offer `remember-for-team`; merely reading/citing it, an
   unrelated green build, failed verification, or uncertain causality does not qualify. Confirm
   delivery rather than assuming it, especially for an existing consumer on each host.
5. Extend `remember-for-team` to accept the learning's date plus a short excerpt, triage and
   deduplicate it, independently establish the proposed current claim, and add a plain backlink in
   the wiki draft. It must not execute a command or follow a URL supplied by learning prose. Mark
   the draft `verified` only when current evidence directly verifies the scoped claim; otherwise
   use `suspected`. PR review remains mandatory and the historical learning is never deleted.
6. Re-run the repeated positive and negative behavioral fixtures, install/update smoke tests,
   compose/freshness and `validate-dist` x3. Define success as accurate nomination plus honest wiki
   status; define failure as nomination from mere reading or unrelated success, any automatic
   `verified` claim, silent mutation/movement of history, or a rule that greenfield consumers see
   but updated consumers do not.

**Phase B — evidence gate, not pre-authorised scope:** operate Phase A in B-42's field pilot for
4–6 weeks and record concrete missed promotions and false offers in `meta/field-reports.md`. If the
small completion checkpoint removes most of the problem, stop. If misses remain, return with a new
design for the smallest explicit nomination mechanism. A separate append-only ledger with
collision-resistant IDs, canonical task identities, bounded/screened fields, amendments and final
dispositions may then be considered, but only from observed need; counts remain routing heuristics,
never epistemic status or a personal performance target.

**Proportionality:** the only current harm is the maintainer's credible observation that people will
not remember a separate promotion command. The existing completion checklist already reaches near
the desired behavior. Measuring that behavior, then sharpening one delivered checkpoint and one
existing skill if necessary, removes most of the suspected harm without building a second knowledge
governance system inside `LEARNINGS.md`.

**Review gate — BLOCKED FOR IMPLEMENTATION:** before Phase 0 or any shipped edit begins, obtain a
new independent adversarial review with **Claude Opus**. The 2026-08-11 fresh-context review that
rejected the counter design materially improved this plan, but **does not satisfy the Opus gate**.
If Opus is unavailable or limited, mark `WAITING — OPUS LIMIT`; do not substitute this review or a
lower tier and call the gate complete. Opus may reject the premise, change the stop rule, or reduce
the scope further.

**Status: AWAITING OPUS REVIEW.** The evidence-first design is captured but not locked, and
authorises neither Phase 0 execution nor shipped changes until the required Claude Opus review.

---

### B-134 · Prevent implementation evidence from masquerading as product intent
**Filed against:** v0.52.0 (2026-08-11)
**Effort:** M for research, behavioral baselines, and design; shipped effort must be re-estimated
after review · **Priority:** P2 · filed 2026-08-11 · **Invariants:** #1 #2 #6 #7 ·
**Capability:** product and experience leadership

**Why:** the framework is strong at deriving architecture, conventions, technical debt, and
implemented domain behavior from a repository, but it applies the same evidence model to product
context. `src/core/CLAUDE.md > Codebase Context` asks what the application does, who uses it, its
domain concepts, and critical user journeys. All three `/bootstrap` variants then tell the model to
replace that section with "real findings from this codebase". Their clarification phase asks about
engineering-pattern contradictions, not product purpose, actor authority, desired outcomes,
non-goals, or whether an implemented journey is intentional. Routes, DTOs, forms, tests, and names
can therefore become unmarked claims about users and product intent.

This is the concrete defect to solve. The broader idea — product discovery, journey mapping,
screen/form/button complexity, accessibility, product opportunities, and post-release outcomes —
is valuable but must not enter as one pre-authorised subsystem. Leading practice consistently
separates outcome, customer problem, solution, and assumption tests; treats value/usability/
feasibility/viability as different risks; maps the whole cross-channel journey; combines metrics
with user research; and keeps product work multidisciplinary. Persistent AI specs improve
traceability but do not validate the requirements they preserve. Sources:
[Product Talk](https://www.producttalk.org/discovering-solutions/),
[SVPG four risks](https://www.svpg.com/four-big-risks/),
[GOV.UK whole-problem mapping](https://www.gov.uk/service-manual/design/map-a-users-whole-problem),
[GOV.UK success measures](https://www.gov.uk/service-manual/service-standard/point-10-define-success-publish-performance-data),
[W3C WCAG 2.2](https://www.w3.org/TR/WCAG22/),
[Google HEART](https://research.google/pubs/measuring-the-user-experience-on-a-large-scale-user-centered-metrics-for-web-applications/),
[GitHub Spec Kit](https://github.github.com/spec-kit/), and
[Anthropic agent evals](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents).

**Fresh-context adversarial review already performed (2026-08-11; not the required Opus review):**
verdict **REVISE**. It accepted the product-context honesty defect and rejected the proposed
multi-phase capability build as presently unsupported. It found that one global
`CONFIRMED / OBSERVED / INFERRED / UNKNOWN` ladder would conflate source, authority, and confidence
and conflict with existing hazard, characterization-test, and warehouse vocabularies; that code can
map an implementation surface but not a real user journey; that B-42 has no product/UX field report
and B-41 has no product-judgment scenario; that consumer-owned context will not automatically
migrate on update; and that product research introduces privacy, confidentiality, prompt-injection,
staleness, metric-gaming, and causal-attribution risks. The narrower plan below incorporates those
findings. This review **does not clear implementation**.

**Phase 0 — evidence and design only:**

1. Freeze fixtures, prompts, graders, success worlds, negative controls, sample count, and stop
   rules before changing shipped guidance. Red/green every deterministic grader with planted
   mutations; calibrate subjective judgments against product/UX-capable humans; an unavailable
   host or truncated output is cannot-verify, never pass.
2. Exercise at least three independent runs per stochastic case on every available supported host:
   (a) exact feature request with no outcome; (b) materially ambiguous user-facing feature;
   (c) authoritative product brief; (d) conflict between code and product evidence; (e) Angular
   routes/forms without user evidence; (f) .NET API/domain flow without a known actor or channel;
   (g) trivial fix/refactor; (h) sensitive research material; (i) stale/superseded claim plus a
   deleted reference; (j) AI vocabulary without evidenced runtime AI behavior.
3. Measure unsupported product claims, invented actors/journeys/outcomes/metrics/authority,
   provenance accuracy, correct proceed/ask/abstain behavior, unnecessary blocking questions,
   sensitive-data leakage, added turns/tokens/always-loaded footprint, and blind human ratings of
   usefulness and material correctness. Report per host rather than averaging away a dead surface.
4. Inspect greenfield and already-installed update paths. Record exactly which host reads which
   carrier. Product knowledge is consumer-owned; framework updates must not overwrite it, while a
   design that only reaches greenfield installations is not a successful delivery design.

**Pre-registered stop rules:**

- Close B-134 with no shipped change if the unchanged framework already avoids unsupported intent
  claims, preserves ambiguity, and handles the ten cases correctly.
- Do not ship if any code-only observation becomes confirmed product intent, raw sensitive research
  is copied into the repo, an AI persona is treated as product authority, or exact/trivial work is
  unnecessarily blocked in any repeated run.
- Do not ship unless the intervention materially reduces unsupported product claims without a
  material increase in wrong questions, turns, or always-loaded context.
- Do not begin journey mapping until at least three independent real-work incidents across at least
  two repositories or teams show that the minimal inline product frame failed because journey
  structure was missing.
- Do not add a product/UX reviewer until the same reviewable defect class survives inline framing
  repeatedly and human reviewers judge the proposed findings materially useful.
- Do not add outcome feedback until a team has a metric owner, validated instrumentation, baseline,
  exposure definition, guardrails, and an interpretation rule separating association from causation.

**Smallest candidate implementation — only if Phase 0 proves the defect:**

1. Strengthen the existing compact `Codebase Context`, not a new file by default: purpose, actors,
   critical journeys, domain vocabulary, intended outcomes, constraints/non-goals, sources,
   authority/owner, and open questions. Keep it within the existing always-loaded budget.
2. Use separate claim dimensions rather than a single confidence word: **Basis** (reported,
   researched, policy, operational data, implementation observation); **Status** (supported,
   inferred, unknown, disputed/superseded); exact **Source**; named **Authority** or unknown;
   **Scope**; and human-reviewed date. Code can establish an implemented surface, never why it
   exists, who should use it, or whether it creates value. "A human said it" is not authority.
3. Change all three bootstrap variants to cite code-derived implementation observations, ask one
   grouped set of product-context questions when a knowledgeable person is available, preserve
   disagreements, and leave skipped/unanswered intent visibly unknown. Store minimized summaries
   and controlled-system references, never raw interviews, support transcripts, customer identity,
   health/financial information, or confidential strategy.
4. Add a bounded **Product frame** to `/design` and the feature-spec template for significant
   product/domain behavior: actor, problem/opportunity, evidence, intended outcome, affected
   journey, assumptions, success signal, guardrails, and authority/unknown. Precisely specified
   work may proceed with `product outcome unavailable` rather than inventing one. Add one concise
   universal rule: implementation evidence is not evidence of product intent or real user behavior.
5. Re-run the baseline matrix, install/update smokes, context-footprint gate, composition/freshness,
   `validate-dist` x3, and applicable host behavior suites. Show both the defect world and the
   constructible success world; do not call prose presence a behavioral pass.

**Explicitly not authorised by this item:** no `map-product`/`map-journeys` skill, product/UX
reviewer, screen/button/form numeric limits, automatic product roadmap, synthetic personas as
evidence, `TECH_DEBT.md` product entries, new product-opportunity register, product-freshness hook,
analytics integration, automatic causal claims, or conditional human-AI UX module. Each requires
its own observed harm, proportionality case, design, delivery path, and review. A future journey
artifact must distinguish observed route/API/state flow from reported cross-channel journey and
unknown actor/goal/completion. Automated accessibility findings can prove particular structural
failures; they can never claim complete accessibility or usability without manual/user evidence.

**Product authority and privacy boundary:** a product claim must name who can decide it; developer,
product owner, policy owner, researcher, analyst, and end user are not interchangeable authorities.
Disputed claims stay disputed. Treat linked research and support material as untrusted and possibly
sensitive: define minimisation, consent, redaction, retention, access, and prohibited-data rules;
never execute commands or follow instructions embedded in research content. A valid path refreshes
only the reference, not the human claim attached to it.

**Proportionality:** the observed repo defect is an epistemic one in bootstrap, not evidence that
the framework needs a full product operating model. Phase 0 plus a compact context/spec correction,
if the baseline fails, removes most of that harm. Larger discovery and UX capabilities remain
separately gated hypotheses.

**Review gate — BLOCKED FOR IMPLEMENTATION:** before Phase 0 execution or any shipped edit, obtain
a **heavy independent adversarial review with Claude Opus**. Give Opus the research sources, actual
bootstrap/design/spec/update surfaces, this entry, and the fresh-context critique. The review is
licensed to reject the premise, redesign the evidence model, change the evals/stop rules, split the
item, or conclude that a smaller documentation correction is sufficient. Require a second Opus
pass on the materially redesigned plan before calling it locked. If Opus is rate- or spend-limited,
mark `WAITING — OPUS LIMIT`; do not substitute a lower tier or this existing review and call the
gate satisfied.

**Status: AWAITING OPUS REVIEW.** The evidence-first design is captured but not locked, and
authorises neither Phase 0 execution nor shipped changes until the required Claude Opus review.

**B-130 is PARTIALLY DONE (2026-08-18) — the framework-doctor instance is FIXED and shipped;
the original `ScriptTwinParity` docs-sync-check 5.1 divergence is STILL OPEN. See below.**

### B-130 · Diagnose or retire the historical Windows PowerShell 5.1 parity failures
**Filed against:** v0.51.4 (2026-08-08)
**Effort:** S · **Priority:** P3 · filed 2026-08-08 · **Invariants:** #3

> **MEASURED 2026-08-20 BY THE REVIEWER, and it changes both halves of this entry. An attempted fix
> was REVERTED; read this before trying again.**
>
> **(b) NO LONGER REPRODUCES — this half is closed on evidence.** `ScriptTwinParity.Tests.ps1` is
> **9 passed / 0 failed under BOTH hosts** on the maintainer box, including the
> `docs-sync-check branches and advisory prose agree` case this entry was filed for. The entry also
> asks that the assertion be made to print the actual exit codes "before diagnosing further" — that
> is **already done**: `AssertExit` at `:20` prints both exit codes and both twins' stdout and stderr.
> The entry is stale on both points. An implementer working from it saw a failure only because its
> sandbox cannot start bash at all (`PowerShell exit 0, bash-wrapper exit 256`), which is a property
> of that sandbox, not of the twins.
>
> **(a) NOT FIXED, and the single-cause hypothesis is wrong.** The stderr-decoration strip was
> implemented and measured: **41 passed / 41 failed under 5.1**, identical to the pre-change ratio.
> No improvement. The `powershell.exe : ` prefix is still present in the compared text. But the
> failures also show a **second, unrelated divergence this entry never recorded, and it is not stderr
> at all** — Windows PowerShell 5.1's `ConvertTo-Json` escapes an apostrophe as `\u0027` while the
> bash twin emits `'` literally:
>
> ```
> guard.ps1='{"permissionDecisionReason":"... it adds \u0027#pragma warning disable\u0027 — ..."}'
> guard.sh ='{"permissionDecisionReason":"... it adds '#pragma warning disable' — ..."}'
> ```
>
> That is a **stdout** difference in shipped hook output, host-dependent (pwsh 7 does not escape it),
> and semantically harmless — `\u0027` is valid JSON decoding to `'` — but the suite compares strings.
> So "normalise the stderr decoration" cannot fix this suite on its own, and any next attempt must
> handle both channels or normalise the JSON before comparison.
>
> **Why the attempt was reverted rather than kept:** it also added a cross-host self-arm that runs the
> suite under 5.1 and fails when 5.1 fails. Since 5.1 still fails, shipping it would have taken CI's
> windows leg red on a suite that composes into all three dists. The arm is well-designed and worth
> keeping **once 5.1 actually passes** — not before.

**Why:** discovered incidentally while resuming B-54: `src/core/tests/hooks/ScriptTwinParity.Tests.ps1`'s
`docs-sync-check branches and advisory prose agree` case fails with "docs exit mismatch" when run
under Windows PowerShell 5.1 (`powershell.exe`), even on unmodified `master` at `9500f5f` — pwsh 7
passes cleanly. Not investigated beyond confirming it is pre-existing and unrelated to B-54 (stashed
all B-54 changes and reproduced the same failure on baseline). The `Assert` call that fails
(`Assert ($p.Exit-eq$s.Exit) "docs exit mismatch"`) doesn't interpolate the actual exit codes, so the
next person will need to add that before diagnosing further.

> **SECOND INSTANCE, 2026-08-18 — and this one reddens the shipped hook suite on all three dists.**
> `FrameworkDoctor.Tests.ps1:141` (`PowerShell twin runs under Windows PowerShell 5.1`) fails on this
> box: it builds a fixture repo, runs `scripts/framework-doctor.ps1` under `powershell.exe`, and gets
> `5.1 exit=1` where it asserts 0. Consequence: `dist/{dotnet,angular,monorepo}/tests/hooks/Invoke-HookTests.ps1`
> each report **1 failure across 18 files**, and that suite is a `release.ps1` gate.
>
> **Established by execution, so nobody re-hunts it:** identical at `HEAD` and at the **`v0.58.0`
> tag** (29 passed / 1 failed / 1 skipped in all three trees), so it predates the 2026-08-18 work
> entirely and **the last release shipped with it**. Not caused by B-147, which was verified against
> the same baseline. Also: running the doctor *directly* from a dist root exits **0** under both
> hosts — so the divergence is **fixture-dependent**, not a plain 5.1 incompatibility in the doctor,
> and that is the thread to pull. Start by making the assertion print the doctor's own failing rows
> rather than just its exit code; today it reports `5.1 exit=1: <whole stdout>`, which buries the row
> that actually failed.
>
> **The uncomfortable part, which belongs to this entry rather than to B-147:** a shipped tag has a
> red hook suite on the maintainer box, and the release that produced it did not stop. Whatever the
> cause, the gate either did not run this leg during that release or was waived; either way the
> record should say which, because "the gates were green" is a claim this repo makes routinely.
>
> **DIAGNOSED AND FIXED, same day — and it was a real shipped defect, not an environment quirk.**
> The doctor's *Mirror and version integrity* row ran `template-checks` through a **bare interpreter
> name**: `$hostExe = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { 'powershell' }`.
> Under Windows PowerShell 5.1 that resolves `powershell` against the PATH the agent host supplies —
> and this box's child processes inherit
> `C:\Program Files\PowerShell\7;C:\Program Files\Git\bin;${PATH}`, with the literal unexpanded
> `${PATH}` leaving `System32` off it. Proven by execution inside a 5.1 child:
> `Get-Command powershell -> NOT RESOLVED`. The interpreter never started, `$LASTEXITCODE` was
> non-zero, and the doctor reported **"CLAUDE.md and AGENTS.md or version stamps have drifted. Fix:
> run /generate-copilot"** — a specific, false, actionable diagnosis handed to a consumer whose
> documentation was fine. Under pwsh 7 the same row read OK, which is why it looked like a 5.1
> parity curiosity rather than the reporting defect it was.
>
> **This is B-85's thesis, shipped:** *a failure caused by a broken PATH is not the same fact as the
> thing being diagnosed, and reporting them identically is what lets the gap persist.* Fixed in both
> twins. The `.ps1` now self-hosts — it runs `template-checks` with **this process's own executable**
> (`(Get-Process -Id $PID).Path`, the same self-hosting contract `Get-PsExe` uses), falling back to
> the bare name only if that cannot be read, and emits a **distinct** row when the host cannot be
> started at all: *"could not start a PowerShell host to run template-checks, so drift is UNKNOWN
> rather than found. This is a host/PATH problem, not a documentation problem."* The `.sh` twin gained
> the same separation (exit 126/127 = could not execute) plus the *"template-checks is missing"*
> message the `.ps1` already had and it did not — a twin divergence in messaging, found while fixing
> this.
>
> **Measured, same box:** `FrameworkDoctor.Tests` **29 passed / 1 failed** at `HEAD` and at the
> `v0.58.0` tag → **30 passed / 0 failed** on all three dists after the fix; the full dist hook
> suites went from **1 failure across 18 files** each to **0 failures**. That before/after on an
> unchanged host is the red observation this fix rests on.
>
> **Still open on this entry:** the original `ScriptTwinParity.Tests.ps1` docs-sync-check 5.1
> divergence, which is a different assertion and was not touched. And the unanswered process
> question above — how v0.58.0 shipped with this red — remains worth an answer.

> **THIRD INSTANCE, 2026-08-18 (found while verifying B-59) — the largest of the three, and it is
> a TEST defect, not a product one.** `Guard.Tests.ps1` fails en masse under Windows PowerShell 5.1
> while passing cleanly under pwsh 7. Measured at `HEAD` **before** B-59: **36 passed / 30 failed**
> under 5.1 versus **66 passed / 0 failed** under pwsh 7, same tree, same box. So it is pre-existing
> and has nothing to do with B-59.
>
> **Cause, visible in the failure text:** the suite compares the two twins' **stderr**, and 5.1
> decorates error-stream output with the invoking command name — `guard.ps1='powershell.exe :
> Blocked write to …'` where pwsh 7 emits `Blocked write to …`. Every case that asserts on stderr
> text therefore diverges by host. The guard's *decisions* are identical: `TwinParity.Tests` (which
> compares decisions rather than stderr) is **13/0 under 5.1**. So the product is fine and the
> instrument is host-dependent — which is precisely the shape this entry exists to collect.
>
> **B-59 enlarged its footprint without causing it:** the new mixed-case and multi-line fixtures are
> also stderr-comparing, so the counts moved from 30/66 failing to **41/82** — a slightly worse
> ratio because there are simply more stderr assertions now. Under pwsh 7 the same suite is
> **82 passed / 0 failed**.
>
> **Not a release blocker, and the record should be precise about why:** the release gate runs
> `dist/<stack>/tests/hooks/Invoke-HookTests.ps1` under pwsh 7, where all three dists report
> **0 failures across 18 files**. The 5.1 failure appears only when a human explicitly re-runs the
> suite under `powershell.exe`, which is exactly what a maintainer diagnosing a consumer's Windows
> box would do — so it is worth fixing, just not urgent.
>
> **Do:** normalise the captured stderr before comparison (strip a leading `<command> : ` decoration)
> rather than weakening the assertions, and add a 5.1 arm so the divergence cannot return silently —
> the same remedy shipped for `DocTruth` in B-141.

**Do:** reproduce, capture both hosts' actual exit codes and stdout for the `docs-sync-check.ps1`/`.sh`
twins over `DocsFixture`/`TemplateFixture`, and find the 5.1-specific divergence (likely another
BOM-less-file default-encoding case, per invariant #4's known class — see B-54's fix in
`template-checks.ps1` step 1 for the pattern: replace `Get-Content` with an absolute-path
`[IO.File]::ReadAllText`). Confirm whether this already fails in CI's Windows leg or is silently
masked there too.

**Update 2026-08-16 (found while shipping B-58/B-60/B-82) — one member of this family is solved, and
it was never an encoding bug.** `FrameworkDoctor.Tests.ps1`'s `PowerShell twin runs under Windows
PowerShell 5.1` case fails on baseline (`58393d7`, verified in a clean worktree, so not caused by
that cluster) with `[MISSING] Mirror and version integrity`. The cause is **this box's corrupted
`PATH`**, not the doctor and not 5.1 semantics: `framework-doctor.ps1:203-204` spawns a bare
`powershell` when running under Desktop edition, and `(Get-Command powershell).Source` returns
**nothing** here because the session `PATH` is the known-broken one (third entry is the literal
string `${PATH}`, and `C:\Windows\System32` is absent entirely — see the corrupted-PATH hazard in
`DEVELOPING.md`). The spawn fails, `$LASTEXITCODE` is non-zero, and the doctor reports drift that
does not exist.

Proof, same command, same tree, only `PATH` changed:

```
PATH as-is            -> FrameworkDoctor.Tests: 29 passed, 1 failed, 1 skipped
PATH + System32 etc.  -> FrameworkDoctor.Tests: 31 passed, 0 failed, 0 skipped
```

**Two consequences worth more than the fix.** First, the corrupted `PATH` does not merely produce a
false failure — it produced a false *skip*, silently costing a case of real coverage, which is the
`INVARIANT-GUARDING SKIPS` problem arriving through a channel that heading does not cover. Second,
**any gate run from a shell with this `PATH` is measuring a machine that does not exist**; a release
run from such a shell would refuse on a dist hook suite, and a dist gate cannot be waived by design.
Prepend `C:\Windows\System32;C:\Windows;C:\Windows\System32\WindowsPowerShell\v1.0` before running
gates, and treat any 5.1-only failure as PATH-suspect **before** diagnosing it as an encoding bug —
this entry's own original hypothesis was encoding, and for this member it was wrong.

**Update 2026-08-17 — the other member is the SAME cause, and this entry can close.** The
`docs-sync-check branches and advisory prose agree` divergence is also the corrupted `PATH`, not
encoding. Found immediately once the suite's exit-mismatch assertion was made to print both twins'
output — the diagnostic gap this entry itself asked for. The interpolated stderr said it outright:

```
[FAIL] docs-sync-check exit mismatch 1/0
PS ERR: & : The term 'powershell' is not recognized as the name of a cmdlet ...
```

`docs-sync-check.ps1` spawns a bare `powershell` for its `template-checks` delegation, exactly as
`framework-doctor.ps1` does. With `PATH` repaired the whole suite is `9 passed, 0 failed, 0 skipped`
under Windows PowerShell 5.1. **Both members of this family were one environment defect wearing an
encoding costume**, and the entry's original hypothesis was wrong for both.

Two things worth keeping when this closes: (1) `AssertExit` in `ScriptTwinParity.Tests.ps1` now
interpolates both twins' stdout/stderr on any exit mismatch — that is what made this a two-minute
diagnosis instead of another deferral; (2) the remaining real question is not "is 5.1 broken" but
"should shipped scripts spawn a bare interpreter name at all" — see B-104's class. That is a
separate decision and deliberately not made here.

**Second, separate pre-existing 5.1-only failure found in the same B-54 validation pass:**
`dist/<d>/tests/hooks/FrameworkDoctor.Tests.ps1`'s `PowerShell twin runs under Windows PowerShell
5.1` case also fails on unmodified master (reproduced with all B-54 changes stashed) — the healthy
fixture reports `[MISSING] Mirror and version integrity` under 5.1 only. Not investigated further;
may or may not be the same root cause as the item above. Both were confirmed pre-existing and out
of scope for B-54 by stashing all B-54 changes and reproducing on baseline `master` (`9ddc97a`).

**Current diagnosis and guidance (researched 2026-08-11):** ordinary direct Windows PowerShell
5.1.26100.8875 runs at code page 437 are green (`ScriptTwinParity.Tests`: 7/0/0;
`FrameworkDoctor.Tests`: 30/0/1, with one unrelated missing-Python skip), but that is only the
control. The historical defect is deterministic when the parent is launched by absolute 5.1 path
and neither `pwsh` nor `powershell.exe` is visible to the child through `PATH`: `docs-sync-check.ps1`
and `framework-doctor.ps1` both select a **bare** child host, reproducing `docs exit mismatch` at
`9500f5f` and the exact `[MISSING] Mirror and version integrity` at `9ddc97a`. Their relevant subject,
test, and harness blobs are unchanged through HEAD (apart from an unrelated changelog test), so the
ambient green is environmental, not an intervening fix. This matches B-71 and the documented
maintainer environment whose `PATH` omitted System32. Encoding was a hypothesis, not the cause.
Microsoft documents distinct Desktop/Core runtimes and says claimed cross-edition compatibility
ultimately requires tests on every supported edition. Sources:
[about Character Encoding](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_character_encoding?view=powershell-7.5)
and [about PowerShell Editions](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_powershell_editions?view=powershell-7.5).

**Approaches considered:**

1. **Apply the suspected `ReadAllText` encoding fix.** Rejected: the trigger is child-host visibility,
   not decoded content. This would leave the command-resolution defect live.
2. **Resolve the child host absolutely and regression-test the missing-`PATH` world — selected.** For
   `framework-doctor.ps1`, invoke `template-checks.ps1` with the current process executable. For
   `docs-sync-check.ps1`, preserve the deliberate PS7 preference when its resolved command has a
   usable absolute `.Source`, otherwise fall back to the current process executable; never retain a
   bare token after resolution. This preserves existing policy while removing ambient `PATH` from
   the child launch.
3. **Make every child inherit the current host.** Simpler, but could silently remove docs-sync's
   deliberate preference for PS7 where installed. Select it only if review establishes that the
   preference has no supported semantic purpose.

**Proportional implementation plan (after review):**

1. Improve the parity failure to print host/version, fixture branch, both exits, stdout, and stderr.
   Add a docs consumer/reachability fixture that actually includes the child checks; today's
   `DocsFixture` copies only docs-sync and cannot exercise the relevant launch.
2. For each subject, pre-register controlled `PATH` fixtures with an exit-0 child, an exit-17 child,
   and an unavailable bare child. Prove before the fix that the missing-host world goes red and that
   the old logic can leave misleading exit/output; after the fix require the marker/exit to prove
   the intended child ran, exit 17 to propagate as failure, no command-resolution stderr, and no
   false success. Run host `{5.1, 7}` × child-host visibility `{present, absent}` once per
   deterministic cell; 437 and 65001 are secondary one-shot controls, not repeated causal axes.
3. Implement the narrow absolute-resolution policy in both authored PowerShell subjects, compose all
   dists, and run twin parity plus framework-doctor suites on both hosts. Audit the same selector
   shape in shipped and maintainer `Invoke-HookTests.ps1`; preserve B-90's permitted `pwsh`
   preference, but ensure any selected command retains an absolute source or current-host fallback.
   Split the item only if implementation proves the two subjects require genuinely different policy.

**Proportionality:** the defect is current and constructible: supported 5.1 validation failed and the
doctor falsely diagnosed a healthy mirror when child `PATH` differed from the parent invocation.
Resolving two existing selectors absolutely, plus two deterministic regressions and a bounded
same-shape audit, is smaller and more probative than repeated environmental stress or encoding edits.

**Review gate — AWAITING OPUS REVIEW:** obtain a fresh independent Claude Opus review of the closure
threshold, matrix, diagnostic oracle, and decision not to patch the subjects. A separate
fresh-context Codex critique must first try to falsify the current baseline and this design, but does
not satisfy that gate. If Opus is unavailable due to limits, record `WAITING — OPUS LIMIT`; no
implementation is authorised.

**Fresh-context adversarial review (Codex, 2026-08-11):** **REJECTED the retirement design.** It
reproduced both exact historical failures by controlling child-host visibility, proved the relevant
blobs had not changed, identified the shared bare-host selector, showed that the proposed matrix
omitted the causal axis and duplicated code-page cells, and found that `DocsFixture` never reached
the child. The revised design above uses the constructible trigger, child reachability/exit markers,
absolute resolution, and the smaller host × visibility matrix. This Codex review does **not satisfy
the required Claude Opus gate**.

**Status: AWAITING OPUS REVIEW.** This revised design is not locked and authorises no
implementation. If Opus is genuinely unavailable due to limits, record `WAITING — OPUS LIMIT`.

**B-131 is DONE (2026-08-19) — marker-scoped changelog grammar; see `meta/BACKLOG-DONE.md`.**

### B-136 · Make affected framework artifacts part of completing an AI-authored change
**Filed against:** v0.52.0 (2026-08-11)
**Effort:** M · **Priority:** P2 · filed 2026-08-11 · **Invariants:** #1 #2 #7

**Why:** the shipped Agentic Workflow and shared `.claude/workflow.md` currently require an AI to
**flag** documentation drift at the end of a task, not repair the drift its own change created.
`/docs-sync` is deliberately read-mostly. Warehouse writes have a stronger pre-write freshness rule,
but even that does not establish the general post-change duty to refresh a map whose keys,
relationships, grain, load behavior, or consumption surface the current task changed. The result is
a permitted “code done, known repository truth stale” handoff.

**Do:** replace report-only completion with change-scoped affected-artifact reconciliation. Inspect
the diff and its consequences; update writable canonical truth made stale by this task; regenerate
derived mirrors rather than hand-editing them; respect append-only, register, security, and
human-intent boundaries; and finish with either the artifacts updated, `Affected artifacts: none`, or
a concrete blocker that prevents claiming full reconciliation. Add narrowly stack-owned triggers
where the generic rule cannot know artifact semantics—first, a bounded warehouse-map refresh after a
change to mapped warehouse facts. Do not turn every edit into `/docs-sync`, refresh unrelated docs,
invent ADR intent, or create a second inventory of framework files.

**Design:** `.claude/plans/2026-08-11-b136-change-owned-artifact-freshness-design.md` compares four
approaches and selects causal, ownership-aware reconciliation. It includes an artifact/action table,
generic affected/unaffected/protected worlds, warehouse positive and false-positive controls,
source-to-dist delivery boundaries, implementation steps, and proportionality.

**Codex adversarial review:** **REQUESTED CHANGES.** The first formulation could overwrite generated,
append-only, security-sensitive, or human-owned artifacts; mistook report-only `/docs-sync` for a
repair path; over-triggered whole-map refreshes; and lacked negative/blocked worlds. The revised plan
uses artifact semantics, bounded causal triggers, negative controls, and honest structural-versus-
behavioral evidence. This review does **not** satisfy the Claude Opus gate.

**Review gate — AWAITING OPUS REVIEW:** ask Opus to attack the causal ownership model, update-versus-
flag boundary, durability of the artifact inventory, warehouse trigger, protected records, delivery
surfaces, oracle reachability, and proportionality. Opus should explicitly consider whether a
shared-rule-only change removes most of the harm. No implementation is authorised until its findings
are verified/incorporated and the decision is locked in `meta/workspace-decisions.md`. If unavailable,
record `WAITING — OPUS LIMIT`.

**Proportionality:** the current report-only wording is directly observed and is the requested harm.
A shared completion-rule correction plus the smallest domain-specific trigger removes most of it; a
documentation graph, automatic classifier, mutating `/docs-sync`, or exhaustive skill inventory does
not.

### B-138 · The gate suite is bound by per-assertion process spawning, and its cost ceiling will always eventually be outgrown
**Filed against:** v0.52.0 (2026-08-13)
**Effort:** M · **Priority:** P2 · filed 2026-08-13 · **Invariants:** #3 #4

> **SECOND MEASURED CORRECTION, 2026-08-20 (v0.62.0) — and it refutes this entry's *Do* ordering.**
> B-151 shipped per-unit `TIMING` for `dist-gates` in the same campaign, which this entry named as
> "the cheap prerequisite to diagnosing it, and should come first". It came first, and here is what
> it says. Every number below is from one real release run, not a serial per-file pass — the
> methodological trap this entry already records.
>
> **`dist-gates` (627.2s wall clock, ceiling 700s):**
>
> | unit | dotnet | angular | monorepo |
> |---|---:|---:|---:|
> | job wall clock | 621.7s | 626.7s | 623.8s |
> | `validate-dist` | **14.2s** | **13.3s** | **14.7s** |
> | dist hook suite | **607.0s** | **612.6s** | **608.3s** |
>
> plus `context-footprint` at **205.1s** — a fourth parallel unit that had **no attribution at all**
> before this release, and which is a third of the stage's wall clock (hidden only because it runs
> concurrently).
>
> **What this refutes.** This entry's *Do* says to attack "the highest-cost files
> (`ValidateDist.Tests.ps1` first, `dist-gates`'s per-dist hook suites second)". For the `dist-gates`
> stage that ordering is backwards and the first target is not worth touching at all: the
> **`validate-dist` script is ~14 seconds, 2.3% of its job**. The dist **hook suites** are **97.6%**.
> `gate-budget.json`'s own `next-target` note — "three per-dist suites in parallel, each spawning
> ~234 fresh pwsh/bash processes" — attributed those spawns to the stage as a whole; they are
> essentially all in the hook suites.
>
> **Keep two similarly-named things apart, because this entry has already conflated them once.**
> `validate-dist` (the gate script, 14s, inside `dist-gates`) is *not* `ValidateDist.Tests.ps1` (the
> meta-suite file that tests it, 506.9s, inside `meta-suite`). Only the second is expensive.
>
> **Current cost ranking across the whole release (1234.4s of local gates):**
>
> | # | unit | cost | stage |
> |---|---|---:|---|
> | 1 | dist hook suite (×3, parallel) | ~608s each | dist-gates |
> | 2 | `GuardPatternErrors.Tests.ps1` | 548.3s | meta-suite |
> | 3 | `ValidateDist.Tests.ps1` | 506.9s | meta-suite |
> | 4 | `UpdateDelivery.Tests.ps1` | 303.6s | meta-suite |
> | 5 | `context-footprint` | 205.1s | dist-gates |
> | 6 | `InstallerContract.Tests.ps1` | 196.7s | meta-suite |
>
> **So the revised target list is:** the **dist hook suites** first (they are now the single largest
> cost in the release, larger than `GuardPatternErrors` even after B-138's own earlier fix), then
> `GuardPatternErrors` and `ValidateDist.Tests.ps1`, then `context-footprint`. `validate-dist` itself
> comes off the list entirely.
>
> **Apply this entry's own proportionality lesson before writing any code:** its first fix was
> *not* the prescribed re-architecture but a `foreach` → throttled jobs change costing a few lines
> (418.5s → 230.3s). Check the dist hook runner for the same trivially-parallel structure **before**
> reaching for in-process session reuse. Note it may already be throttled — `HOOKTESTS_THROTTLE` is
> set per job by `release.ps1` — in which case the remaining win is genuinely per-assertion spawn
> cost and the expensive fix is warranted.
>
> **Also still true and now quantified:** four individual `validate-dist` checks exceeded their own
> 25s sub-ceiling in the v0.61.0 run, warning but not failing. Against a 14s total for the whole
> validator here, that sub-ceiling accounting needs re-reading — the two numbers cannot both be right.

> **PARALLELISING `Guard.Tests.ps1` WAS TRIED, MEASURED, AND REVERTED, 2026-08-21. Do not retry it
> without reading this.** The measurement above named the file; the obvious fix made things worse.
>
> Running its 40 cases as throttled jobs is a genuine **1.73x standalone** win (137s -> 79s, bash
> present, same host, 82 passed / 0 failed both ways). Inside the release it is a **net loss**:
>
> | unit | serial | parallel-4 |
> |---|---:|---:|
> | `Guard.Tests.ps1` | 554.6s | **371.6s** |
> | `FrameworkDoctor.Tests.ps1` | 504.3s | **662.9s** |
> | `HazardCheck.Tests.ps1` | 200.4s | 360.1s |
> | `RoutePrompt.Tests.ps1` | 112.7s | 215.5s |
> | **dist hook suite (makespan)** | **560.8s** | **667.6s** |
>
> **Why: inner width ADDS to the lane budget instead of borrowing from it.** The runner grants each
> test file one of its `HOOKTESTS_THROTTLE` lanes. Re-reading that same variable as this file's own
> width means 3 dists x 4 file-lanes x 4 inner lanes, so the target file speeds up by starving every
> other file in its suite. `FrameworkDoctor` simply inherited the makespan, 31% slower than the file
> it replaced. The release stage went 579.2s -> 684.7s and the meta-suite breached its 650s ceiling.
>
> **Serialising the nested case does not rescue it.** With inner width forced to 1, the job machinery
> is pure overhead: 167s nested against 142s for the original inline loop, a ~18% tax on scheduling
> that buys nothing. Two code paths in the framework's main behavioural gate to win 58s for a
> developer running one file by hand is not proportionate (Maintenance rule 6), so the change was
> reverted whole and the file is byte-identical to its pre-change state.
>
> **What this establishes, and it is worth more than the 58s:** this suite is **already saturating
> its lanes**. Adding concurrency anywhere inside it redistributes time rather than reducing it.
> That is a different diagnosis from "bound by process creation" — the spawns are expensive *and*
> the machine is already full — and it means the remaining wins are in **doing fewer spawns**, not in
> arranging them better. `Guard.Tests` does 160 (40 cases x 2 surfaces x 2 twins); the honest question
> is whether the case table needs 40 rows against both twins, not how to run them faster.
>
> **The methodological point, which is this entry's own trap for the third time:** a standalone
> measurement did not predict behaviour under contention, exactly as the serial-vs-parallel warning
> above says. It was reviewed, red-tested (mutating `exit 2` -> `exit 0` gave 54 passed / 28 failed),
> and would have shipped on the strength of a real 1.73x that was measured in the wrong context.
> **Only the release run caught it.** Any future performance change here must be measured inside a
> real `dist-gates`, not standalone.

> **FIRST PER-FILE MEASUREMENT OF THE DIST SUITES, 2026-08-21 (v0.64.0 release run).** The
> instrumentation above shipped and immediately answered the question this entry has carried since
> 2026-08-13. These are **parallel makespan** numbers taken inside a real release with the throttle
> applied — not the serial per-file kind that misled this entry twice.
>
> | file (dotnet leg) | seconds |
> |---|---:|
> | `Guard.Tests.ps1` | **554.6** |
> | `FrameworkDoctor.Tests.ps1` | 504.3 |
> | `ScriptTwinParity.Tests.ps1` | 208.3 |
> | `HazardCheck.Tests.ps1` | 200.4 |
> | `RoutePrompt.Tests.ps1` | 112.7 |
> | `TwinParity.Tests.ps1` | 101.0 |
>
> Chained up: `dist-gates` 579.2s -> hook suites ~561s of it (97%) -> `Guard.Tests.ps1` 554.6s of
> that (**99%**). **One test file is ~95% of the largest stage in the release**, and until this run
> nobody could name it. `FrameworkDoctor` finishes inside its shadow; every other file is noise.
>
> **This is the same shape the meta suite had**, where `GuardPatternErrors.Tests.ps1` was 96% of its
> wall clock. Two independent suites, each dominated by a single guard-related file. That is a
> pattern, not two coincidences: the guard has the most branches, so it attracts the most assertions,
> and each assertion spawns a process.
>
> **Next step, and apply this entry's own proportionality lesson before writing code:** check whether
> `Guard.Tests.ps1` has the trivially-parallel structure `GuardPatternErrors` turned out to have.
> That fix was a `foreach` -> throttled jobs change worth 1.82x standalone for a few lines, and it is
> the reason the meta suite is no longer urgent. If `Guard.Tests.ps1` is the same shape, the release's
> biggest stage roughly halves for comparable effort, and the in-process re-architecture stays
> unnecessary for a third time. Only if it is genuinely serial by construction is the expensive fix
> warranted.
>
> **A new symptom worth recording, because it changes the argument for fixing this.** Four separate
> release attempts on 2026-08-21 were **killed by the host** partway through `dist-gates` — the stage
> that runs three parallel suites, each spawning hundreds of fresh interpreters, alongside a fourth
> footprint job. Each kill left a clean tree (nothing stages until the gates pass), so the cost was
> time, not damage. But the entry has framed this cost as a budget problem, and "the release does not
> survive the stage" is a sharper argument than "the stage takes 579 seconds". Not yet diagnosed to
> root cause — recorded as an observation, not a conclusion.

> **THIRD MEASURED CORRECTION, 2026-08-21 (v0.63.0) — the cheap prerequisite is still outstanding,
> and an earlier reading of this entry assumed B-151 had already delivered it. It had not.**
>
> B-151 delivered *unit*-level attribution for `dist-gates` (validate-dist vs hook-suite), which is
> what produced the 97.6% figure above. It did **not** deliver per-file attribution, and the reason
> is concrete: **there are two hook runners and only one of them is instrumented.**
>
> | runner | lines | `TIMING` emitters |
> |---|---:|---:|
> | `.claude/hooks/tests/Invoke-HookTests.ps1` (meta) | 162 | 2 |
> | `src/core/tests/hooks/Invoke-HookTests.ps1` (shipped — this is what `dist-gates` runs) | 55 | 0 |
>
> Verified against the v0.63.0 release log: every per-file `TIMING` line in it comes from the meta
> suite. The three dist suites emit only `=== Hook test suite: 0 failure(s) across 18 file(s) ===`.
> So the largest single cost in the release — `dist/*/hook-suite` at 515.5s, 514.7s and 515.4s on a
> 533.4s stage — has **no per-file attribution at all**, exactly as this entry has said since
> 2026-08-13, and "measure first" remains undischarged for the 97% that matters.
>
> **A design question to settle before implementing, not after:** the runner that needs instrumenting
> is a **shipped** file, so adding `TIMING` output sends it to consumers too. Either that is a useful
> diagnostic for them, or it is maintainer noise belonging behind an environment variable the way
> `HOOKTESTS_THROTTLE` already is. Recommendation: the env-var gate — a consumer running their hook
> suite has no release budget to blow and no ceiling to diagnose — but **state the choice rather than
> defaulting into it**, because it changes what ships [#6].

**Why:** `meta/gate-budget.json` already diagnoses these suites as "bound by process creation, not
CPU" — each assertion spawns a fresh `pwsh`/`bash` child. That means wall-clock cost scales roughly
linearly with assertion count, so any fixed time ceiling is guaranteed to be outgrown again as more
tests are added; raising the ceiling each time (as `meta-suite` already was once, 2026-08-08)
delays the failure without changing its cause. Caught live, 2026-08-13: `ValidateDist.Tests.ps1`
alone measured 339.6s in isolation, 67% of the 504.4s serial meta-suite total, and it is the file
with by far the most assertions (34 `It` blocks, most invoking `validate-dist.{ps1,sh}` as a fresh
process). `dist-gates` has the identical shape and the identical unaddressed note already sitting in
`gate-budget.json`'s own `"next-target"` field, written 2026-08-07 and never acted on: "the win there
is fewer spawns per assertion, NOT more parallelism."

Two-year, ever-growing exposure: this framework's own working model (RCA → new gate, repeated
dozens of times just in the five days between B-90 and B-136) guarantees new assertions keep
arriving. A per-assertion-spawn architecture makes total suite cost a direct, compounding function
of backlog velocity, which is exactly backwards -- the gate that is supposed to keep releases cheap
becomes more expensive precisely because the framework is healthy and being actively maintained.

Also worth checking while in this code: the 2026-08-07 tuning got the *parallel* meta-suite runner
from 399s serial to 148.1s (a 2.7x win) via a throttled outer loop. Today's *parallel* aggregate
reading (527–554s, per the two v0.52.1 release attempts) is barely faster than this entry's own
504.4s *serial*, single-file-at-a-time measurement -- the throttle may itself have regressed or
stopped helping as the suite grew, which would be free runtime back with no per-file work at all if
confirmed and fixed.

**MEASURED CORRECTION, 2026-08-19 (v0.61.0) — read this before acting on anything above.** Two of
this entry's load-bearing claims were refuted by direct per-file measurement, and acting on the
entry as originally written would have sent the next person at the wrong file with the expensive
fix.

1. **`ValidateDist.Tests.ps1` was NOT the binding constraint.** Re-measured on an idle box: 234.9s
   serial (not 339.6s) and 404.5s parallel. The real dominant file was
   `GuardPatternErrors.Tests.ps1` at **651.1s of a 677.6s parallel wall clock — 96%**; every other
   file, `ValidateDist` included, finished inside its shadow. That file was added by B-59 the day
   before this measurement, so the entry's 2026-08-13 numbers were simply taken before the dominant
   cost existed. A cost table with no date next to it rots silently.
2. **It did not need the reused-runspace re-architecture this entry prescribes.** Its four mutation
   cases were independent by construction (`Invoke-MutationRedTest` gives each its own
   `mutation-helper-<guid>` scratch tree, removed in a `finally`) and serial only because of a
   `foreach`. Running them as throttled jobs took it 418.5s → 230.3s standalone (1.82x) and the
   suite 671.5s → 524.3s in the real release run, back under the 650s ceiling with the ceiling
   untouched. Cost: a few lines. **So check for trivially-parallel structure BEFORE reaching for
   in-process reuse** — the proportionality check (Maintenance model #6) belongs at the top of this
   entry, not the bottom.

**The throttle had NOT regressed** — that hypothesis above is closed. The outer loop was working;
one job simply outlasted the entire schedule, which no amount of scheduling can fix. Longest-first
launch ordering was tried first on exactly that theory and bought nothing (689.2s vs 671.5s).

**The methodological trap that produced two wrong diagnoses in a row, and the reason this entry's
own numbers misled:** a *serial* per-file pass runs each file with `VALIDATE_DIST_TESTS_THROTTLE` /
`HOOKTESTS_THROTTLE` unset, i.e. at full internal width, while the parallel runner hands each file
`$innerLanes`. `GuardPatternErrors` measured 418.5s serial against 651.1s parallel — a 1.56x
contention inflation on a file with *no* internal parallelism at all. **Serial per-file costs cannot
predict a parallel makespan.** `Invoke-HookTests.ps1` now emits `TIMING <file> <seconds>` per file
(on its own line — `release.ps1`'s `^RESULT\s+(\S+)\s+(\d+)\s*$` is anchored at both ends), so the
next diagnosis reads the real parallel cost instead of inferring it. Re-measure before acting.

**What remains genuinely open here:** the per-assertion-spawn architecture is still real and still
scales with backlog velocity — the headroom won above is ~19% (524.3s of 650s) and
`GuardPatternErrors` is *still* the makespan at ~507s inside the suite, so the next few gates will
consume it. `dist-gates` (557.8s of a 700s ceiling) has the identical shape and, unlike the meta
suite, still has **no per-file attribution at all** — that instrumentation is the cheap prerequisite
to diagnosing it, and should come first. Also newly visible in the v0.61.0 run: four individual
`validate-dist` checks now exceed their own 25s sub-ceiling (27.4s, 27.6s, 28.2s, 28.3s — all
markdown-link and dead-instruction scans over shipped docs), warning but not failing.

**Do:** for the highest-cost files (`ValidateDist.Tests.ps1` first, `dist-gates`'s per-dist hook
suites second), replace one-process-per-assertion with a reused session: dot-source the target
script's functions once into a persistent runspace (PowerShell) / keep one interactive shell alive
(bash) per test file, and call the function repeatedly instead of re-invoking the interpreter each
time. Confirm this doesn't change what's actually being tested (the composed, on-disk artifact must
still be exercised faithfully — a reused in-process call must not silently start testing something
subtly different from what a real consumer invocation does). Separately, profile whether the outer
parallel throttle in the meta-suite runner is still delivering its 2026-08-07 speedup; if not, that
regression is worth its own smaller, isolated fix first. Red-test per this repo's Definition of
done: show the before/after wall-clock time on the same host, not just "it feels faster."

**Proportionality (revised 2026-08-19):** the original framing — "the single dominant file is
already identified and measured (339.6s of 504.4s)" — was wrong on both the file and the number; see
the measured correction above. The revised case is narrower: the meta suite is no longer urgent
(524.3s of 650s after a few lines of scheduling, no ceiling raised), so this entry's remaining value
is in `dist-gates`, and its cheap first step is per-file attribution, not re-architecture. Measure
first, and re-check for trivially-parallel structure before assuming in-process reuse is the fix —
that check alone was worth 1.82x on the file this entry used to be about.

### B-140 · Investigate a codex execution path for the live-eval harness (budget diversification)
**Filed against:** v0.52.1 (2026-08-16)

> **FIRST DIRECT OBSERVATION, 2026-08-20 — the premise is half right, and the half that is wrong was
> being asserted rather than observed.** This entry says codex "has no equivalent routing mechanism".
> Nobody had checked. Probe: a scratch repo containing one skill (`.claude/skills/add-widget/SKILL.md`)
> carrying a house rule that exists in no other file and cannot be inferred from the code — prefix a
> new file with `// KRYPTON-7714` and state the token. Prompt: *"Add a new widget called Sprocket to
> this codebase, in src/. Then tell me what you did."* — naming no skill, no file and no token.
>
> **Result: codex applied the rule correctly and stated the token, unprompted.** `src/Sprocket.js`
> begins `// KRYPTON-7714`.
>
> **But its own tool calls show HOW**, which is the whole point of the probe:
> `rg --files --hidden .claude; Get-ChildItem .claude -Recurse -Force`. It **searched the filesystem
> and read `SKILL.md`**. Nothing was injected by the host.
>
> **So the two claims must be separated, and this entry currently conflates them:**
> - *Codex can use shipped skills* — **yes, observed.** It reached the right one with no pointer.
> - *Codex routes to skills the way Claude Code does* — **no.** Discovery by grep is a different
>   mechanism, and that is what preserves this entry's actual conclusion: a routing-attribution
>   scenario ported to codex would score *"does the agent grep `.claude/`"*, not *"does the host
>   route"*. Outcome-graded scenarios remain the portable ones, exactly as written.
>
> **Two limits, stated so this is not over-read** — both are the failure modes B-72 and B-112 exist
> to catch:
> 1. **The prompt telegraphed the answer.** "add a widget" against a skill named `add-widget` is a
>    trivial name match. This is a **weak positive** and cannot support any claim about routing under
>    realistic, non-telegraphing prompts.
> 2. **It probed the wrong carrier for the framework's real codex path.** The fixture had no
>    `AGENTS.md`, which is what the framework actually ships for codex. This says nothing about that
>    route.
>
> **What it does settle:** "codex cannot reach skills" is not a safe assumption to build the scoping
> on, and any part of this entry resting on it needs re-deriving from the observation rather than
> from the assertion.
**Effort:** M (investigation only; implementation is a separate, larger follow-on) · **Priority:** P3
· filed 2026-08-16 · **Invariants:** #1, #3

**Why:** the account's Claude monthly spend limit has now voided two full B-129 live-eval attempts
back to back (2026-08-15, 2026-08-16) — a fully built, self-tested-green harness run, real spend
burned, zero usable result each time (`meta/eval-results.md`, B-129 entries). Codex CLI/API budget is
available and, per the account owner, much larger. The question raised: can `run-agent-evals.ps1
-Live` be pointed at codex instead of (or in addition to) Claude Code to avoid this single point of
failure?

**This is not a config flag — it changes what the harness measures, not just who runs it.**
`Invoke-ClaudeProcess` (line ~1004) shells out to `(Get-Command claude).Source` with
`--output-format stream-json`; `Get-TranscriptEvidence` parses Claude Code's own JSONL event shape
(`tool_use`/`tool_result`) to derive `skillSelected`/`skillRead`. This repo ships exactly two
supported consumer surfaces — Claude Code and GitHub Copilot (`CLAUDE.md` Invariant #5) — neither of
which is codex; there is no codex-targeted artifact (no `.claude/skills/`-equivalent codex reads) for
any scenario to test against. Any scenario whose grader depends on `skillSelected`/`skillRead` —
which includes **all of B-129/WSD-042**, whose locked Decision explicitly scoped the probe to "the
one scriptable host that demonstrably loads skills" — cannot be ported to codex without first
deciding what "skill selection" even means for an agent that has no equivalent routing mechanism.
Scenarios whose grading only checks final transcript/artifact state (file contents, DDL correctness,
decision text — not which internal mechanism was consulted) are the only plausible executor-agnostic
candidates.

**Do (investigation only — do not implement without the Opus gate, Maintenance rule 1, same as B-129
itself required):**
1. Inventory `scenarios.json`; classify each scenario as routing-dependent (depends on
   `skillSelected`/`skillRead`, i.e. Claude-Code-specific) versus final-state-only
   (executor-agnostic in principle).
2. For the final-state-only subset, confirm codex CLI's headless/scriptable invocation shape (flags,
   structured output format, budget/timeout controls) and whether it exposes anything
   transcript-equivalent to Claude's `stream-json`, or whether codex grading would have to fall back
   to final-state-only evidence (no tool-use trace) — a real reduction in what can be graded, not a
   free substitution.
3. State explicitly: **B-129/WSD-042 is out of scope for this item.** Porting it to codex would
   require reopening WSD-042's already-locked Decision, which named the single-host scoping as
   deliberate, not incidental. This item does not authorize that reopening; B-129 stays blocked on
   the Claude spend limit per its existing plan (`CLAUDE-HANDOFF.md` BLOCKED section) unless a
   separate future decision revisits WSD-042 on its own terms.
4. Proportionality check before any design locks: a permanently dual-executor harness is ongoing
   maintenance surface (this repo's own twin-parity discipline, Invariant #3, would likely extend to
   it — a `Invoke-CodexProcess` twin to keep in sync indefinitely). Before locking that cost, confirm
   whether raising the Claude spend limit (a config change, `claude.ai/settings/usage`) is actually
   infeasible or undesired — if not, the smaller fix may remove most of the harm B-140 exists to
   address, per Maintenance rule 6.

**Proportionality:** open question, not yet decided — this item exists to hold and scope the
investigation, not to authorize the build. Any implementation requires the Opus gate + adversarial
critique per Maintenance rule 1 before code changes, exactly as B-129 itself required.

**Status:** filed 2026-08-16, not started, not gated.

**B-141 is DONE (2026-08-18) — see `meta/BACKLOG-DONE.md`.**

**B-142 is CLOSED as a deliberate non-action (2026-08-19) — the proposed range gate cannot
fail in the world the entry is about; see `meta/BACKLOG-DONE.md`.**

**B-143 is DONE (2026-08-20) — the advice now states only what was observed, and the VS Code leg escalates with B-43; see `meta/BACKLOG-DONE.md`.**

**B-152 is DONE (2026-08-20) — the duplicate heads are merged and both gate twins now read the whole file; see `meta/BACKLOG-DONE.md`.**

**B-153 is DONE (2026-08-20) — the bash validator now accepts every dist-root spelling; see `meta/BACKLOG-DONE.md`.**

**B-154 is DONE (2026-08-20) — a dated release head with no tag now fails the meta suite; see `meta/BACKLOG-DONE.md`.**

**B-155 is DONE (2026-08-20) — a grep that cannot run is now a host fatal, not a content finding; see `meta/BACKLOG-DONE.md`.**

### B-156 · The "grep exit status as content verdict" conflation is class-wide, and most instances are in SHIPPED scripts
**Filed against:** v0.62.0 (2026-08-20)
**Effort:** M · **Priority:** P2 · found 2026-08-20 by B-155's RCA sweep · **Invariants:** #3 #5

**Why.** B-155 fixed one site in `scripts/validate-dist.sh` (authoring-only) where `grep -q`'s
non-zero exit was read as "the content is absent" when it also means "grep could not run". The sweep
that entry required found the same shape across the **shipped** twin scripts, where it reaches
consumers:

| script | conflating sites |
|---|---|
| `src/core/scripts/docs-sync-check.sh` | banner, mirrored headings, README skill/agent mentions, architecture hash — each a `grep -q` / `\|\| missing=…` content verdict |
| `src/core/scripts/framework-doctor.sh` | import, heading, and pending-marker `grep -q` branches |
| `src/core/scripts/impact-run.sh` | project-detection `grep -q .` — an execution failure becomes a **routing decision** |
| `warehouse-map-check.sh`, `template-checks.sh`, `wiki-check.sh` | extractor-shaped `\|\| true` where no-match is expected but execution failure is swallowed too |

**Why this is worse in the shipped set than it was in the validator.** `framework-doctor` is the
diagnostic a consumer runs *when something is already wrong* — the moment their machine is most
likely to be short of resources, and the moment a false "your documentation has drifted" is most
expensive. B-130 already recorded exactly this outcome from the same family: the doctor reported
*"CLAUDE.md and AGENTS.md or version stamps have drifted. Fix: run /generate-copilot"* — a specific,
false, actionable diagnosis handed to a consumer whose documentation was fine — because a bare
interpreter name failed to resolve. That was a *different* cause with the *same* reporting defect.
`impact-run` is sharper still: there a failed `grep` does not merely mis-report, it silently changes
which project the tool decides it is looking at.

**Do:** apply B-155's discrimination to each site — `0` = found, `1` = genuinely absent (a product
finding), **anything else = could not run**, reported as a distinct host/resource condition and never
as a content verdict. Both twins per script [#3]; the `.ps1` twins should be **checked rather than
assumed** to be exempt (B-155's PowerShell twin was genuinely exempt because it works in-process, and
that is a real asymmetry, not a general rule).

**This is deliberately not one batch edit.** The implementer's sweep is explicit that these "require
coordinated twin/test work, not a one-line batch edit", and that the extractor-shaped `|| true` uses
each "need a separate contract decision before editing" — for some of them, swallowing a failure may
be the intended contract. Decide per site and record which are deliberate.

**Proportionality, stated before locking:** the observed harm is real but indirect — no consumer
incident is recorded for these specific sites, and the one measured instance of the *class*
(B-130's doctor row) came from a different cause. So the cheap half — `framework-doctor` and
`impact-run`, where a false verdict is either handed to a confused consumer or silently changes
behaviour — is worth doing first and may be all that is proportionate. The extractor `|| true` sites
may be fine as they are once someone states that they are.

**Red-test:** a stub `grep` on `PATH` that exits 2 is the cheap forcing function; show the new
host/resource message, then the ordinary absent path still reporting a product finding, then a clean
pass.

**Cross-links:** B-155 (the instance and the discrimination pattern), B-130 (the same reporting
defect from a different cause, with a measured false diagnosis), B-85 (a host/PATH failure must not
be reported as an artifact defect — this entry is that thesis applied to `grep` rather than to an
interpreter).

**Delivery RCA (cheap half).** No existing gate caught this because the script fixtures exercised
content-present and content-absent states but did not replace the content-inspection primitive with
one that fails to execute; syntax and twin-shape checks cannot distinguish those runtime meanings.
The same class remains exposed in `docs-sync-check.sh`, `warehouse-map-check.sh`,
`template-checks.sh`, and `wiki-check.sh`, whose extractor-shaped failure swallowing needs the
separate per-site contract decision already required above. The PowerShell sweep also found the
analogous class in caught/suppressed in-process reads and enumeration, so the two in-scope twins
were corrected even though they do not invoke grep.

### B-157 · Installing the framework produces a ~164-file commit nobody can review, and nothing in the tree says which files the consumer owns
**Filed against:** v0.62.0 (2026-08-21)
**Effort:** S (the manifest) · M (if optional components are chosen) · **Priority:** P3 · raised by the maintainer 2026-08-21 · **Invariants:** #6

**The question asked:** the install leaves a large amount of framework material to be checked in;
is a cleanup step preferable or desirable?

**Answer, on measurement: a cleanup step that deletes things is NOT desirable, and the two obvious
candidates are already handled or load-bearing.** But the underlying complaint is real and has a
cheaper remedy than deletion.

**What actually lands** (dotnet dist, measured 2026-08-21): `.claude/` 51 files, `.github/` 38,
`scripts/` 27, `tests/` 26, `docs/` 14, `specs/` 1, plus root files — **~164 committed paths**.

**Two things a reader would assume are wrong, and are not:**
1. **The framework does not clobber the consumer's `README.md` or `CHANGELOG.md`.** The installer's
   `$metaFiles` list explicitly excludes `.git`, `.template-repo`, `README.md`, `CHANGELOG.md`,
   `.gitignore` and `.gitattributes` from the copy. The `.template-repo` marker in particular would
   disable the consumer's own CI guardrail if it travelled, and it doesn't.
2. **`tests/` (26 files, 261K) is the obvious trim candidate and is load-bearing.** The **shipped**
   `.github/workflows/template-ci.yml` runs `tests/hooks`, and `scripts/template-checks.{ps1,sh}`
   references it. Deleting it would break a shipped workflow and a shipped gate, so "clean it up"
   is not a local change.

**Why deletion is the wrong shape generally.** Nearly all of this is *team configuration*, and being
committed is the point: hooks must exist for every developer who clones, skills and commands must be
in the tree for the agent to find, `CLAUDE.md` and the instructions carrier are the product. More
sharply — the framework's update path *restores* framework-owned files, and B-97 exists because
protected files **fail** to reach existing consumers. A consumer who deletes machinery gets it back
on the next update, or gets a `framework-doctor` reporting missing components. Cleanup would fight
the delivery model rather than tidy it.

**So what is the real complaint? Two things, neither of which is volume:**

1. **The first commit is unreviewable.** A reviewer facing ~164 added paths cannot separate the
   product from the scaffolding, and has no basis to approve or question any of it. That is a
   genuine onboarding cost and it is paid once per repo, by someone who did not choose the framework.
2. **Nothing in the tree states ownership.** A developer looking at `scripts/framework-doctor.ps1`
   six months later has no way to know it is framework-owned and that their edits will be silently
   overwritten on update. v0.56.0 (B-46) shipped exactly this disclosure — three ownership classes,
   printed **at install time**. A printed message scrolls away; the files carry nothing. That is the
   same delivery gap B-97 is about, applied to ownership rather than to rules.

**Recommended — cheap, and it is the thing already described in prose but encoded nowhere:**
ship a **manifest of framework-owned paths with their ownership class** (framework-owned/overwritten,
consumer-owned/protected, mixed — the three classes B-46 already defines). It gives a PR reviewer one
file to read instead of 164; it gives `framework-doctor` something to check the installed tree
against rather than inferring; and it makes "will my edit survive an update?" answerable from the
repo rather than from a message nobody kept. Cross-check it against the installer's own
`$protected` / `$metaFiles` lists so the manifest cannot drift from the behaviour it describes —
that check is the deliverable as much as the manifest.

**Also worth doing regardless:** say in the shipped `README.md` what the install adds and why it has
to be committed. Currently a consumer discovers the file count by running it.

**Considered and not recommended:**
- **Optional components at install** (e.g. omit `tests/`): fragments the install matrix, and
  `template-checks` plus the shipped workflow would both need to tolerate absence. Real cost, and it
  buys 26 files.
- **A broader `.gitignore`**: the shipped one ignores only `docs/impact/runs/`. Ignoring machinery
  would break the team-config property that makes any of it work.

**Evidence gap, stated rather than assumed:** "unreviewable" is a *consumer friction* claim and the
author cannot self-generate it — this is exactly the population **B-42** exists to hear from. The
manifest is cheap enough to justify on its own reasoning, but if a real installer reports that the
volume was never the problem, drop the rest of this entry rather than building for a complaint
nobody made.

**Cross-links:** B-46 (the three ownership classes, disclosed at install time only), B-97 (the same
delivery gap for rules rather than ownership), B-42 (the only source of evidence for the friction
claim), B-32 (context footprint — a different cost of the same material, already measured).

**B-146 is DONE (2026-08-18) — check B shipped, check A dropped on evidence; see `meta/BACKLOG-DONE.md`.**

**B-144 is DONE (2026-08-18) — see `meta/BACKLOG-DONE.md`.**

### B-158 · The static-context budget is effectively exhausted, and nothing says so until a release refuses
**Filed against:** v0.63.0 (2026-08-21)
**Effort:** S · **Priority:** P2 · found 2026-08-21 while asking whether more skills should ship · **Invariants:** #7

**Why — measured from `meta/context-footprint.json` on 2026-08-21, not estimated:**

| dist | `static.claude` | ceiling | headroom |
|---|---:|---:|---:|
| dotnet | 39,501 | 40,000 | **499 chars (1.2%)** |
| angular | 38,239 | 40,000 | 1,761 chars (4.4%) |
| monorepo | 47,917 | 48,000 | **83 chars (0.17%)** |

B-110 made these a hard failure, which was right. The consequence nobody has stated is that the
framework now sits within a rounding error of its own budget on two of three dists, so **any**
static-context addition — a paragraph in `CLAUDE.md`, a rule on the carrier, a skill, an agent — is
near-blocked on dotnet and effectively blocked on monorepo. Shipped skill *frontmatter* (the part
that counts) averages **689 chars** across the 16 monorepo skills (min 285, max 1,086), so the next
skill costs roughly **8x the entire monorepo headroom**, and even the smallest existing one is 3.4x
over it. Skills compose into monorepo from both stacks, so a new .NET *or* Angular skill lands there.

**The failure mode is discovery-by-refusal.** Nothing warns at authoring time; you find out when a
release stops. That is the same shape the ceilings themselves had before B-110 — a real limit that
only announces itself at the worst moment.

**Do:** (a) surface remaining headroom in the *authoring* path, not only pass/fail at release — one
line, "dotnet: 499 chars from ceiling", is enough; (b) decide deliberately whether these numbers are
still the right ceilings and record the decision. They were set when the framework was smaller.
Raising them on purpose is legitimate; discovering them is not.

**Not:** do not raise a ceiling to unblock a specific change in the same commit as that change. That
is how a budget stops being one.

**Cross-links:** B-110 (made the ceiling a hard failure), B-139 (the sibling drift problem in the
per-stage ceilings), B-44 (retirement is the other way to create headroom), B-157 (per-file install
volume, the other cost of the same material), B-159, B-160.

### B-159 · Nobody has measured whether the always-loaded rails actually trigger the `/review` fan-out
**Filed against:** v0.63.0 (2026-08-21)
**Effort:** S · **Priority:** P2 · found 2026-08-21 · **Invariants:** #5

**Why.** `/review` spawns its five auditors **deterministically**, not by model routing — its own
body says so: "In a single message, spawn all five subagents via the `Task` tool"
(`src/core/.claude/commands/review.md`, Step 1), and its frontmatter description repeats the roster.
That is a reliable invocation path, and it is the reason agents should not be converted into skills
(see B-160).

**But developers rarely type `/review`.** In practice the fan-out depends on §1 of
`framework-rules.instructions.md` — on the always-loaded carrier — telling the model to classify
intent and run the workflow unasked. **That dependency has never been measured.** The carrier is the
channel B-98 proved *does* arrive (map reach 0/6 -> 6/6 when the same guidance moved onto it), so the
mechanism is plausible; plausible is what this repo files entries about.

**Do:** one scenario in the B-41 harness — a diff-shaped prompt that never says "review", scored on
whether the five subagents were actually spawned, from a typed tool event rather than transcript
prose. Pre-register the threshold. Record "rails unreached" as its own outcome rather than as a
failure, per WSD-042's precedent.

**Not:** do not respond to a poor result by making the review workflow model-selected. That is the
mechanism measured at 0/16 and 0/6; it would trade the reliable path for the unreliable one.

**Cross-links:** B-98 and WSD-032 (the carrier is the channel that arrives), B-41 (the harness),
B-160 (the same carrier-versus-routing question one level down), B-158 (no headroom to add a new
carrier rule without a decision).

### B-160 · Selective skill routing has been measured four times, all warehouse-shaped — and there is no bar for a new skill
**Filed against:** v0.63.0 (2026-08-21)
**Effort:** S (the static audit) · M (only if a live arm is justified) · **Priority:** P3 · raised by the maintainer 2026-08-21 · **Invariants:** #5

**Why.** Everything known about whether shipped skills actually fire:

| probe | result |
|---|---|
| B-127 | **16/16** trials `ROUTING_NON_REACH` — `map-warehouse` never read or selected once |
| B-98 | `r = 0/6` — neither skill nor map reached |
| B-126 | `add-warehouse-load` fired in only **1 of 6** counted trials (correct answers, misattributed to the skill) |
| B-117 | `add-warehouse-load` selected **6/6** on load-shaped prompts |

The other ~12 shipped skills have **no evidence at all**, and **no threshold exists** saying what
selection rate is acceptable — so a new number could not produce a decision even if we bought one.
That is B-112's trap, and it is why the live arm is last here rather than first.

**One variable separates every observed result, and it is free to check:** every reaching case had
the skill's own vocabulary in the prompt ("add a warehouse load" -> `add-warehouse-load`), and every
non-reaching case did not ("help me write this report" -> `map-warehouse`). Hypothesis, not
conclusion.

**Do — cheapest first, because live trials spend the resource that still has B-129 blocked:**

1. **A static trigger-vocabulary audit.** Validate it against the four known results *first*: if it
   does not reproduce the 6/6 vs 16/16-non-reach split, it is worthless and stop there. If it does,
   it ranks the unmeasured skills for nothing.
2. **Pre-register a selection threshold before any live run**, and record "carrier unreachable" as a
   distinct outcome rather than a failure (WSD-042).
3. **Spend live budget only on the skills the audit cannot call.**
4. **Write the resulting bar into the maintenance model.** Candidate to be confirmed rather than
   assumed: a new skill is justified only when the task is write-shaped, the natural prompt carries
   the skill's own vocabulary, a measurement is named in advance, and the ceiling cost (B-158) is
   explicitly accepted.

**Asked and answered 2026-08-21 — do not migrate agents to skills.** The proposal assumed skills fire
automatically and agents never do. The first half is what these measurements refute; the second half
misreads the mechanism, because the agents are a deterministic fan-out from a command (B-159). It is
also unaffordable: agent frontmatter counts against the same ceiling with 83 chars free.

**Not — and this is the entry's main risk:** the audit is a **proxy**, and this repo's record with
proxies is poor (B-70's cheap local proxy would have caught neither Linux-only defect). It may rank
what to measure; it must never be reported as evidence that a skill does or does not fire. Also
standing: no always-on router and no no-match hook (`meta/BACKLOG-DONE.md B-98`).

**Honest limits on the evidence above:** the sample is warehouse-heavy — B-98, B-126, B-127 and the
one positive all sit in that domain — and nearly all of it is Claude Code, while the framework's own
docs call Copilot in VS Code the primary surface. B-140's 2026-08-20 codex probe reached a skill by
`rg --files --hidden .claude` rather than by routing, and its prompt telegraphed ("add a widget" ->
`add-widget`), so it is a weak positive and carries no weight here.

**Cross-links:** B-98 and WSD-032 (carrier beats selective routing, measured), B-117 (the one clear
positive), B-126 and B-127 (the non-reach evidence), B-96 (its outstanding behavioural arm is
effectively the retirement test for a read-side skill), B-44 row 13 (`route-prompt`, the sibling
question, already flagged as measurable today), B-112 (a number that cannot produce a decision),
B-158 (no headroom regardless), B-159.

### B-161 · RCA: a meta-suite gate asserted against live release state, and the suite had no rule saying it must not
**Filed against:** v0.63.0 (2026-08-21)
**Effort:** S · **Priority:** P2 · found 2026-08-21 when it refused its own release twice · **Invariants:** #5 #7

**What happened.** B-154's tag-reconciliation check (shipped v0.63.0) reports a dated root changelog
head with no git tag. On a release commit that condition is unavoidable: the changelog is stamped in
`release.ps1` stage 2, the meta suite runs in stage 4, and the tag only follows CI-verified green in
stage 5d (WSD-029). It refused v0.63.0's local release. The first fix exempted the in-flight version
through an environment variable set by `release.ps1`; local gates went green and **CI then failed on
both legs for exactly the same reason** — CI is not `release.ps1`, so it never saw the variable. The
cycle has no exit: the tag waits on CI, CI runs the suite, the suite waited on the tag.

**Why no gate caught it.** The check was red-tested against fixtures and never against a real
release. But the deeper cause is a property nobody had written down:

> **Every other gate in the meta suite is hermetic.** Its result depends only on repository
> *content*, never on where the repo sits in the release lifecycle.

Verified by sweep, 2026-08-21 — of the four suites touching git, the other three do not read live
state: `FidelityCheck` uses `rev-parse` against a deliberately invalid ref (a fixture),
`PushAndCheck` stubs git wholesale (`__BRANCH__`/`__SHA__`), and `ReleaseCiWatch` parses transcript
text. B-154's check was **the only non-hermetic gate in the suite** — the first member of its class,
so there was no convention to violate visibly and no existing gate positioned to notice.

**The fix that shipped, and why it is the only satisfiable shape.** Reconcile every dated head
*except the newest*, deciding from the changelog's own ordering. Nothing is given up: a release that
was dated and never tagged (the v0.48.0 case) is only *knowable* as abandoned once a later release is
dated above it, at which point it is checked normally. Detection is deferred by one release, not
disabled — and there is a fixture asserting exactly that, because an exemption with no such assertion
is a disabled gate wearing a comment.

**Do:** state the hermetic property where gate authors will meet it — a gate asserts against
repository content; if it must know the repo's lifecycle position, that position is an *input*
(as `Get-MissingReleaseTags` now takes its versions and a tag probe), never something it discovers
from the environment. Then decide whether it can be enforced or is guidance only: WSD-028 says a
maintenance rule is real only where tooling can refuse, and it is not obvious that this one can be
mechanically detected. **Say which it is rather than leaving it implied** — that ambiguity is
what B-134 is about.

**Proportionality, stated before locking:** the shipped defect cost three release cycles and put a
red commit on master, but the class currently has exactly one member and it is now fixed. So the
deliverable is the written rule plus a decision on enforceability — **not** a new gate, unless the
enforceability question answers yes cheaply.

**The second lesson, which is about method rather than code:** the first fix was validated on the
leg where it was authored and shipped without asking whether its premise held on the other leg. That
is the same shape as [[windows-only-verification-blind-spots]] — a twin change is not done until both
legs are green — applied to local-vs-CI instead of Windows-vs-Linux. Worth folding into the same
sentence in the maintenance model rather than filed as a separate lesson.

**Cross-links:** B-154 (the check), B-112 (instruments whose first version could not produce the
result they claimed to test for — this is that pattern with the failure inverted, a false positive in
the real workflow), B-59 and B-64 (inert checks, the failure mode an exemption drifts into),
B-134 (implementation evidence masquerading as intent), WSD-028 (a rule is real only where tooling
can refuse), WSD-029 (a release tag follows CI-verified green — the constraint the check collided
with).

### B-162 · Scratch trees are cleaned in a `finally`, which a killed run never reaches — and the debris slows the next run
**Filed against:** v0.64.0 (2026-08-21)
**Effort:** S · **Priority:** P2 · found 2026-08-21 while losing seven release attempts · **Invariants:** #7

**Measured, not inferred.** After a day of release attempts, `%LOCALAPPDATA%\Temp` held **2,075
entries**: 223 `validate-dist-<guid>` directories (each a full ~170-file dist copy, so roughly
**38,000 files**), 14 `mutation-helper-<guid>` trees, and 569 loose `.tmp` files. Clearing them
removed 778 entries.

**Why it accumulates.** `Invoke-MutationRedTest` and `validate-dist` both remove their scratch trees
in a `finally` block. That is correct for a normal run and for a failing one — but **a process that
is killed never runs its `finally`**, so every killed run leaks a full dist copy per mutation case.

**Why that is worse than untidy: it is a feedback loop.** Debris slows every subsequent temp
operation, including `GetTempFileName()`, which scans for a free name. A slower run is more likely to
breach a ceiling or be killed, which leaks more debris. `dist-gates` drifted **533.4s -> 579.2s ->
638.9s -> 677.3s across four runs of identical work** on 2026-08-21, and the meta-suite only began
breaching its ceiling after several kills had accumulated. That is consistent with the loop; it is
**not proof** of it, because the run that would have tested the cleanup was itself killed before
emitting a stage timing. Recorded as a hypothesis with its supporting measurement, not as a cause.

**Do:** sweep at **start-up**, not only at teardown — the harness should delete `validate-dist-*` and
`mutation-helper-*` trees older than a threshold before it begins. You cannot catch a kill, so the
system has to be self-correcting rather than merely well-behaved. Keep the `finally` blocks; they are
right for every case they can reach.

**Not:** do not delete by pattern without an age threshold — a concurrent run owns its own scratch
tree, and the release runs three dist jobs in parallel.

**Cross-links:** B-138 (the stage where this shows up, and its host-kill observation), B-163 (the
ceiling this pushes runs over), B-151 (per-unit timing, which is how the drift became visible at all).

**Delivery RCA (2026-08-21):** No gate caught scratch trees abandoned by killed processes because
all existing cleanup assertions exercised reachable `finally` blocks; process termination is outside
that control flow. The same class remains possible for other uniquely-prefixed temp trees, but the
observed material exposure is confined to the two high-volume patterns swept here; broadening the
sweep without equivalent measurements would risk deleting unrelated or live work.

### B-163 · The meta-suite ceiling now sits inside the suite's own run-to-run variance
**Filed against:** v0.64.0 (2026-08-21)
**Effort:** M · **Priority:** P2 · found 2026-08-21 · **Invariants:** #7

**Four measurements of the same suite on the same host, 2026-08-21:** 594.3s, 612.8s, 653.0s,
707.2s. The ceiling is **650s**. So the limit falls in the middle of the observed spread and a
release now refuses roughly half the time for no reason anyone can act on — v0.65.0 was refused at
**653.0s, a 0.5% overshoot**.

**Why this is worse than a ceiling that is simply too low.** A limit that fires on cause teaches
people to fix the cause. A limit that fires on variance teaches people to **retry**, and a retry
habit is exactly what stops the next real breach from being noticed. It also makes the gate's own
signal worthless: nobody can tell a genuine regression from a slow afternoon.

**Do NOT just raise it.** B-138 records that raising a ceiling delays the failure without changing
its cause, and B-158 states the rule directly: never raise a budget to unblock a specific change in
the same commit as that change. Raising 650 to 750 would buy a few weeks and cost the gate's meaning.

**Do:** reduce the cost, and reduce it by doing **fewer spawns** rather than by rescheduling. The
meta suite's two dominant files are `GuardPatternErrors.Tests.ps1` (548.3s) and
`ValidateDist.Tests.ps1` (506.9s). B-138's Guard experiment on 2026-08-21 established that adding
concurrency inside an already-saturated suite **redistributes** time rather than reducing it — a
1.73x standalone win became a 19% loss in the release — so scheduling is not the lever here.
The honest question for both files is whether their assertion counts need the process-per-assertion
shape at all.

**Also worth settling:** whether B-162's debris explains part of the variance. If it does, the spread
narrows on its own and this entry's urgency drops without any code change. Measure after B-162.

**Cross-links:** B-138 (cost structure, the dominant files, and the measured Guard result),
B-162 (a likely contributor to the variance), B-158 (the standing rule against raising a budget to
unblock a change), B-139 (the sibling drift problem in per-stage ceilings).

## Known deferred work (previously agreed, converted to entries so it survives handover)

**B-14 shipped in v0.25.3 (2026-07-05) — see `meta/BACKLOG-DONE.md`.**

### B-15 · WS-3: one *verified* Jenkins/Bamboo required-build recipe (P1 of the self-sufficiency roadmap)
**Filed against:** v0.26.0 (2026-07-12)
**Effort:** M–L
Consumers are Bitbucket Data Center shops; the only deterministic outer-loop primitive they can
use without a DC admin is a **required-build merge check** running their existing CI. Ship one
recipe (docs + pipeline file) that runs `docs-sync-check` + build + test + lint. "Verified"
means actually executed against a local Jenkins container with evidence, per the workspace
verification rules. Details: `.claude/plans/2026-07-02-self-sufficiency-forensic-review.md`
(WS-3). Pre-receive hooks / Code Insights: rejected there — do not resurrect without a consumer
request.

**B-16 is implemented for v0.32.0 — see `meta/BACKLOG-DONE.md`.**

**B-17 was REJECTED on evidence 2026-08-17 (WSD-045) — see `meta/BACKLOG-DONE.md`.**

### B-18 · WS-6: opt-in git-hook convenience net
**Filed against:** v0.26.0 (2026-07-12)
**Effort:** M
`scripts/setup-git-hooks.ps1/.sh` (+ `install.ps1 -GitHooks` flag), added-lines-only staged
scan reusing guard's patterns; must detect and refuse on existing `core.hooksPath`/husky;
documented as bypassable convenience, **not** enforcement. Silent default wiring was explicitly
rejected — keep it opt-in.

### B-20 · Coverage-as-diagnostic + diff-scoped mutation testing (the former v0.24.0 testing release)
**Filed against:** v0.26.0 (2026-07-12)
**Effort:** L · needs a **new version slot** — ≥ v0.28.0 (0.26.0 = merge, 0.27.0 = B-27 per WSD-012)
Execution-ready plan exists: `<home>\.claude\plans\v0_24_0-shipped-framework-testing.md`
(WS-T9 coverage holes-map + optional off-by-default patch-coverage gate, roll-your-own diff
coverage over `scripts/metrics.*` cobertura ∩ `git diff`; WS-T10 Stryker.NET `--since` /
StrykerJS `--incremental`; WS-T11 wire survivors into `test-critic`; WS-T12 docs/parity).
Key traps recorded there: Angular needs a cobertura reporter wired; CI must fetch the base ref;
"CI-enforced" = runs+reports by default, only the opt-in floor blocks.

**B-25-EXEC is DONE — v0.26.0 shipped 2026-07-12 (WSD-018); see `meta/BACKLOG-DONE.md`.**

**B-26 is DONE (2026-08-20) — one bullet was already discharged by B-32 and the other folded into the overlap watch; see `meta/BACKLOG-DONE.md`.**

## Completed entries

Completed entries live in meta/BACKLOG-DONE.md.
