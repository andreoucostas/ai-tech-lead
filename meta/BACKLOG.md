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
> **CURRENT PRIORITIES REVALIDATED 2026-08-31 against v0.79.0 — deliberate, not file order.**
> B-134, B-207, and B-211 are delivered in v0.79.1. Pursue B-42's independent field evidence as
> soon as a participant exists; its value is elapsed time and it should re-prioritize everything
> else. B-136 and B-174 are the next bounded implementation candidates. B-49 remains
> open but its old protocol is invalid under WSD-062; re-lock it before using its session to execute
> B-43's cadence. B-72, B-112, B-129, B-133, B-159, and B-160 retain specific measurement
> obligations and are not generic implementation work. No entry is closed merely for age, blockage,
> or `PARTIALLY DONE` status.
>
> **REVIEW QUALIFICATION REVALIDATED 2026-08-29.** WSD-057 prospectively supersedes any still-visible
> rank-only or “Opus only” qualification in open-entry history. Completed Opus findings and their
> dispositions remain evidence. Future plan critique and implementation review follow the current
> evidence-bound rule; high-risk surfaces retain the orthogonal-vantage requirement.

### B-42 · Field pilot — install into ≥1 real production repo and let evidence drive the backlog
**Filed against:** v0.31.0 (2026-07-17)
**Effort:** M to set up · elapsed weeks to harvest · **Invariants:** #6

> **PREMISE CORRECTED 2026-08-19 by the maintainer — the original *Why* below is factually wrong and
> is kept only so the correction is legible.** The framework **is in active production use**: the
> author uses it on real work, continuously. So "zero live consumer installs" was never true, and
> "every design decision came from maintainer introspection" understates the evidence base — a
> maintainer who ships with the tool daily is generating real friction data, not introspecting.
>
> **What B-42 actually lacks, and all it should now claim:** balanced protocol evidence from a
> developer who is **not the author**. The author cannot report the onboarding friction of someone
> who did not write the framework, cannot notice guidance that only reads as obvious to its author,
> and shares every design blind spot. **The two non-author entries in `meta/field-reports.md` are not
> a satisfaction sample:** the maintainer recorded actionable defects and did not record the positive
> feedback that was also received. That issue-only ledger therefore supports defect diagnosis, not a
> positive or negative adoption claim.
>
> **Consequences for the *Do* below:** step 2 ("install into at least one real work repo") is
> **already satisfied** — do not re-do it. WSD-053/WSD-058 fix the success metrics and separate what
> a maintainer can measure from the independent-user claims they cannot. The ready-to-run FS2 packet is
> `meta/field-study-kit.md`, with a sanitised response form and balanced result ledger. Remaining:
> ask a non-author to run it, then re-order the backlog from the returned evidence. The required
> corrected maintainer replay completed validly on 2026-08-26; see the execution note below.
> **Nothing here should be read as "the framework is unproven in the field"; the unresolved question
> is independent, balanced outcome evidence.**

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

**`meta/field-reports.md` now exists (created 2026-07-31)** as the improvement-only issue ledger.
Two corrections it makes to the paragraph above remain visible rather than rewritten: the Angular
report is **#2**, not #1 (the NUnit report behind B-57 landed earlier); and arrival dates, "what
fired", hook noise and token pain were not captured for either external report. **Status correction
2026-08-26:** its complaint-only contents are deliberate selection, not evidence of negative
sentiment. WSD-053 and `meta/field-study-{kit,response-template,results}.md` now provide the balanced
measurement path; the pilot execution itself remains open.

> **MAINTAINER PROTOCOL GATE PASSED 2026-08-26; INDEPENDENT PILOT IS NOW THE ONLY B-42 EXECUTION
> REMAINING.** FS-20260826-RERUN-02 used history-free neutral roots, same-day Sonnet task arms, three
> R2 checks independent of test discipline/leanness, and green `44/44` baselines. Both arms returned
> the same acceptable, byte-identical fix and regression test with zero intervention. FRAMEWORK
> demonstrated the test red first and scored `10/10`; BARE changed production first and scored
> `9/10`. The `+1` delta is below the frozen `2/10` threshold, so this one valid maintainer replay
> is **no detectable difference**, not benefit. It does not answer non-author onboarding, team
> friction, or team value.
>
> Onboarding was not clean: Opus usage was unavailable, so the developer ran bootstrap on Sonnet;
> it needed 11 follow-ups across 23.9 minutes and claimed completion while `docs-sync-check` was
> red. B-177 tracks that product defect. The protocol now records setup model separately, refuses
> exit-zero test commands that did not execute the expected probe, and forbids force-adding ignored
> post-build artifacts. The next action is one independent Module A run, not another maintainer
> replay.
>
> **PROTOCOL PREMISE REVALIDATED 2026-08-29 — THE NEXT RUN STARTS FS2.** The maintainer clarified
> that historic decisions should be challenged when current models or evidence change and doing so
> improves value. RERUN-02 stays valid and unchanged, but its one-line bounded fix exposed a low-
> discrimination task shape: fabrication, leanness, and most convention behavior had little room to
> vary, while three convention checks were compressed into two points. WSD-058 prospectively replaces
> the next paired task with the first objectively eligible convention-rich historical change while
> traversing a frozen window newest-to-oldest and recording exclusions: 3–8 files, at least two
> architectural areas, three independent
> pre-change-grounded decisions, executable acceptance, enforced setup/task isolation, an allowlisted
> post-setup diff, and one targeted rejecting oracle world per decision. Every pre-change-supported
> alternative must pass the complete primary oracle stack (executable acceptance plus applicable
> D1–D3), or an immutable contract must prove none exist. Executable acceptance separately needs observed
> valid-pass and invalid/pre-change-fail worlds. It remains one two-arm run with equal per-arm caps,
> preserves the privacy/onboarding/diary controls, and never aggregates FS1 with FS2. The next action
> is one independent FS2 Module A pair; equal valid outcomes remain an honest null, never a reason to
> tune and retry.

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

> **STATUS REVALIDATED 2026-08-30 — EXECUTION DESIGN INVALIDATED; B-49 REMAINS OPEN.** Two
> independent audits found that running the current packet would spend provider quota on an
> instrument that cannot support its claimed verdict. The kit omits required C-rows/canaries and
> invokes nonexistent convention-check scripts; July's real quota-stopped partial conflicts with
> later “no drill”/unfrozen-pin records; task oracles and modern-agent isolation are incomplete; and
> the primary target is archived while no replacement has passed Step 0. WSD-062 supersedes the
> execution authority of WSD-022/WSD-044 without erasing their history. Do not resume the July run
> or execute the packet. Re-lock only after a current target, executable valid/invalid oracles,
> credential-free isolation, ordered canaries, latest released tag, and explicit model/time/credit
> authority exist. This is a deferral of an invalid instrument, not completion of the value goal.
>
> **HISTORICAL design lock: locked 2026-07-17, re-locked same day after a second adversarial pass — do not
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
> **HISTORICAL STATUS CORRECTION:** the 2026-08-17 statement “no drill run” was false. A real but
> incomplete July attempt had already executed C1 and parts of C3/C6 before quota stopped it; it is
> now closed as incomplete and non-comparable, with no A/B or value claim. WSD-044 pins
> `dotnet-architecture/eShopOnWeb` and `gothinkster/angular-realworld-example-app`, while leaving
> both commit SHAs and all size/build/domain qualification explicitly to drill #0. The cold-run
> checklist and frozen A/B rubric are in `meta/drill-kit.md`. RCA: no gate caught the missing kit
> because this is maintainer process infrastructure, not a malformed shipped artifact. The same
> exposure applies to the still-unrun host-recertification/report templates; drill #0 must exercise
> them rather than treating the existence of prose as execution evidence.
>
> **FIELD-STUDY DESIGN AND META PILOT PACKET DELIVERED 2026-08-26; FIRST DRY RUN COMPLETE BUT VOID.**
> WSD-053 and `.claude/plans/2026-08-26-b42-field-evidence-study-design.md` lock a controlled
> historical-fix replay plus a three-consecutive-task diary. `meta/field-study-kit.md` is the
> execution packet, `meta/field-study-response-template.md` returns sanitised scores only, and
> `meta/field-study-results.md` records benefit, harm, mixed, no-difference, and void outcomes.
> This is intentionally meta-only until a dry run and independent run show that the protocol is
> usable; promoting it into `dist/` still requires an independent design review and a shipped
> surface decision.
>
> **Dry-run result 2026-08-26:** the pinned .NET fixture's wrong result was reachable; both arms had
> the same 44-test green baseline; exact v0.77.0 installed, bootstrapped, and passed docs sync. The
> installer-command defect was corrected (`/bootstrap`, not the packet's hard-coded `/adopt`). Both
> Claude Sonnet 5 arms then produced acceptable fixes and passed the same private verifier.
> FRAMEWORK added a red-first regression test and scored a raw 9/10 in 6.43 minutes with one
> intervention; BARE added no test and scored 6/10 in 1.23 minutes with none.
>
> **No value direction is claimed.** The result is void because the planted latest commit exposed
> its clean parent and exact mutation; BARE read that answer through `git show`. FRAMEWORK also read
> the exact diagnosis generated by bootstrap—real mechanism reach, but not separable task-time
> evidence. Two frozen R2 checks additionally duplicated R3 test discipline. The packet now uses
> history-free neutral snapshots, discloses bootstrap task discovery, and forbids R2/R3/R5 overlap.
> RCA: a remote-less detached clone was mistaken for history isolation, and plausible rubric rows
> were reviewed individually rather than for cross-dimension independence. A corrected maintainer
> replay was the next gate and is now recorded below. The same history flaw affected B-49's frozen
> planted T2, so `meta/drill-kit.md`, the locked B-49 plan, and WSD-022 now carry the same neutral-
> snapshot amendment; otherwise the quarterly instrument would knowingly repeat the void run.
>
> **RCA found while sharing the rubric:** `meta/drill-kit.md` called its table the frozen B-49
> rubric but omitted the locked design's R5 leanness dimension and substituted review findings.
> No gate caught it because the same rubric was duplicated in prose and meta process docs have no
> semantic parity check. `meta/value-rubric.md` is now the one executable copy used by both kits;
> the review task's planted-findings score remains separate, as the locked design requires. The
> wider exposure is any supposedly shared prose contract copied between maintainer artifacts.
>
> **CORRECTED FIELD REPLAY COMPLETE 2026-08-26.** The neutral-history rerun is valid and classified
> `no detectable difference`: acceptable outcomes `2/2`, rubric `10/9`, active participant time
> `<1/<1` minutes, interventions `0/0`. Both final code/test files were byte-identical and both
> independent applicable suites passed `45/45`. FRAMEWORK's observable difference was red-first
> sequencing and broader verification; the `+1` score is below the frozen material threshold.
> This clears the protocol gate for an independent participant but does not execute B-49 drill #0.
> The rerun also proved that exit zero is not enough for a test instrument: Windows Application
> Control blocked one rebuilt assembly while `dotnet test` said no test matched and exited zero.
> The drill kit and locked plan now require expected-test execution evidence.
>
> **WSD-058 SERIES BOUNDARY (2026-08-29).** B-49 retains its frozen longitudinal drill rubric.
> FS2 preserves R1–R5 only as descriptive continuity data and uses a separate convention-rich
> primary outcome contract; its results must not be aggregated with FS1 or the B-49 quarterly
> series. The older requirement that both populations share one composite rubric is therefore
> superseded for B-42, not silently imposed on the redesigned field pilot.

**B-50 is DONE (2026-08-20) — an isolated three-arm canary confirmed the channel on CLI 1.0.80 and both stale passages are reconciled; see `meta/BACKLOG-DONE.md`.**

**B-44 is DONE (2026-08-20) — the retirement-trigger table is `meta/overlap-watch.md`; see `meta/BACKLOG-DONE.md`.**

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
> interface and the provider, so it cannot demonstrate the distinction. Part (b) — the prompt in `.claude/evals/scenarios.json` still names the mechanism (bindable with
`formControlName`, shows its own invalid/touched error), which is the telegraphing the entry objects
to.

> **PART (b) DELIBERATELY NOT DONE, 2026-08-22 — and the reasoning is not "later", it is a
> constraint.** The obvious objection to deferring is that the scenario is already **SATURATED**
> (B-112: it passed with no forms guidance shipped), so its prior results attribute to nothing and
> invalidating them costs nothing. That much is true, and it was recorded on the scenario itself
> today as a `measures` field.
>
> **The blocker is different: de-telegraphing the prompt without being able to run it would ship an
> unvalidated instrument.** A rewritten prompt is a new measuring device, and B-112's whole finding is
> that **every behavioural instrument in this repo was broken in its first version** — four of them,
> each in a different direction, none caught by reading. Editing the prompt now would produce a
> scenario nobody has observed either passing or failing, which is precisely the state that entry
> exists to prevent. The saturation argument removes the *cost* of the change; it does not supply the
> *validation* the change needs.
>
> **So part (b) is correctly sequenced with the measurement pass, not before it** — rewrite the
> prompt and run it in the same pass, with a bare arm to test whether de-telegraphing actually
> un-saturates the scenario. That is one question, and splitting it across two sessions answers
> neither half.
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
> 1. `archived-redirect` — **GRADER REPAIRED 2026-08-22.** The operational conjuncts (stamp,
>    canonical installer, no archived installer, commit) now gate the scenario, and the three-regex
>    prose conjunction is reported in `Detail` as `(reported, not gating)`. It had never once been
>    True across three valid runs — including one operationally perfect run
>    (`currentStamp=True canonicalInstallerTool=True archivedInstallerTool=False commits=2`) that
>    scored FAIL purely on how it narrated. Three false negatives and zero signal, for the instrument
>    B-33 depends on. **Still to do, and it needs live budget: confirm the repaired measure can reach
>    True at all before citing any archived-redirect result.** An instrument that has never passed is
>    not evidence of anything — which is this entry's own thesis.
> 2. `docs-tier-nopointer` — resolve the interpretation from the typed signals; its latest rows are
>    still INCONCLUSIVE/FAIL rather than a settled reachability result.
> 3. A **bare `route-fix` arm** has still never been run, so its saturation is still unassessed.
> 4. `skill-add-tests` — **DONE 2026-08-21.** Its disposition now sits on the scenario itself as a
>    `measures` field: COMPLIANCE, not routing, because the prompt names the skill outright ("Use the
>    add-tests skill"). `angular-form-control` carries its SATURATED verdict the same way — it passed
>    with no forms guidance shipped, so a PASS there attributes to nothing. `archived-redirect` and
>    `docs-tier-nopointer` are deliberately **not** annotated: their interpretation is still open
>    (follow-ups 1 and 2), and recording a verdict for an unsettled scenario would be this entry's own
>    defect inverted — an instrument asserting a result it cannot support.
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

**2. `docs-tier-nopointer` has also never passed — RE-CHECKED 2026-08-22 against the actual rows.
B-65's claim is narrowly true and generally overstated, and the correction is a rate, not a
retraction.**

The three recorded runs (`meta/eval-results.md:124,145,152`):

| run | outcome | signals |
|---|---|---|
| 1 | **ERROR** — stream schema | no evidence obtained |
| 2 | **INCONCLUSIVE** | `loaded=True followed=False` |
| 3 | **FAIL** | `loaded=False`, class `OrderFulfillmentOrchestrator` |

**What B-65 actually says:** *"in one valid no-pointer run, the agent opened the file unaided."* That
is **true** — run 2 has `loaded=True`. And "the scenario never scored PASS" is **not** evidence
against it, because `loaded=True` with `followed=False` scores INCONCLUSIVE by design; the two
statements are compatible, exactly as this entry supposed.

**What overstates it** is the sentence before: *"Agents do reach on-demand `docs/` files in
bootstrapped repos"* — a categorical drawn from **1 of 2 valid runs**, the other of which was
`loaded=False`. The honest form is *"in 1 of 2 valid runs (a third ERRORed), the agent opened the
file unaided"*. At n=2 that is a signal, not a property.

**B-65 is partly self-limiting already** — the same paragraph says the causal question "needs more
runs before the framework asserts anything about pointers in shipped documentation", which is the
right posture. The defect is that the categorical sentence is what a reader carries away.

**Disposition: no re-run needed for this follow-up.** State the rate where the claim is made and stop
citing the categorical. Whether the pointer *increases load probability* remains the open causal
question and does need budget — but that was always B-65's own caveat, not a new finding.

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

> **BLOCKED ON EVAL BUDGET — checked 2026-08-22. The effort estimate misleads about what is
> currently possible.** The header reads *"S for the evidence/design phase"*, which invites the next
> person to pick this up as tractable. It is not: Phase 0 step 2 requires **repeated trials on every
> scriptable supported surface**, which is live-eval spend, and step 1's fixture only has value as
> input to those trials. There is no design work that can be usefully completed ahead of the
> measurement, because the entry's own stop rule is defined in terms of what the trials show.
>
> That makes **five** entries behind the same budget — B-49, B-97, B-129, B-134 and this one — which
> is the majority of what remains open and is not a coincidence: the deterministic work has largely
> been done, and what is left is the work that requires observing model behaviour.
>
> Nothing here needs re-deciding first. The rejected first design is recorded, its defects are
> incorporated, and the standing prohibition (no IDs, counters, receipt blocks, threshold parsers,
> hook writes, or automatic movement) still holds. This entry is waiting on spend, not on thought.
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

**Status: OPUS REVIEW DONE 2026-08-22 — design APPROVED, Phase 0 DEPRIORITISED.** Findings below.

> **CLAUDE OPUS REVIEW — 2026-08-22. Verdict: APPROVED AS DESIGN, BUT DEPRIORITISE PHASE 0.** The
> design is sound and the fresh-context review already removed the dangerous version. The finding is
> about *ordering*, not correctness.
>
> **1. The entry's own harm statement is the argument against spending on it now.** It says plainly:
> *"No missed promotion has yet been observed in a consumer repo, so this is a plausible
> reliance-on-memory gap, not evidence for a new telemetry subsystem."* That is the right posture —
> and it means Phase 0 would spend **constrained live-eval budget measuring a mechanism for a harm
> nobody has yet observed**, while B-129 and B-134 wait on the same budget for defects that *are*
> observed. Maintenance rule 6 asks whether cost matches harm; here the harm is hypothetical and the
> cost is the scarcest resource in the project.
>
> **Recommendation: B-133 yields budget priority to B-134 and B-129.** Nothing about the design needs
> revisiting when it comes back up. This is a queue decision, not a rejection.
>
> **2. The evidence that would actually justify it comes from B-42, not from an eval.** Phase 0 tests
> whether the *framework offers promotion*; it cannot tell you whether a real team lost a durable
> learning, which is the harm this entry exists for. That evidence is a field observation, and B-42
> (field pilot, install into ≥1 real production repo) is the entry that produces it. **Sequence:
> B-42 → observed instance → Phase 0.** Running Phase 0 first risks a precise measurement of
> something nobody needs.
>
> **3. Budget warning, inherited from the sibling reviews.** Whatever Phase 0 concludes, the shipped
> change lands in the completion checklist — carrier text counted in `static.claude`, with **83
> characters** of monorepo headroom (measured 2026-08-22). B-136 and B-134 both hit this. Budget the
> wording before designing it, or the first release refuses.
>
> **4. Sound and worth preserving verbatim:** the standing prohibition — no IDs, counters, receipt
> blocks, threshold parsers, hook writes, or automatic movement — and the KCS-derived principle that
> **reuse may nominate a claim for attention but repetition must never manufacture `verified`
> status**. That second point is the load-bearing one: it is what separates this from a popularity
> counter, and it should survive any future redesign. The four pre-registered cases (materially
> helped / merely cited / applied-but-unverified / genuinely new) are well chosen, and case (c) is the
> one that makes the grader honest.
>
> **5. One addition.** The grader must distinguish *offering* `remember-for-team` from *claiming
> knowledge was already promoted* — the entry says this. Add the third state it omits: **the agent
> could not determine whether the learning applied**, which must not be scored as either. This
> session shipped four fixes for the same conflation (maintenance rule 7): "I could not examine it"
> is not "it is fine".
>
> **Disposition:** design approved, Phase 0 deprioritised behind B-134 and B-129, and sequenced after
> B-42 rather than ahead of it. No redesign required.

---

### B-136 · Make affected framework artifacts part of completing an AI-authored change
**Filed against:** v0.52.0 (2026-08-11)
**Effort:** M · **Priority:** P2 · filed 2026-08-11 · **Invariants:** #1 #2 #7

**Why:** the shipped Agentic Workflow and shared `.claude/workflow.md` currently require an AI to
**flag** documentation drift at the end of a task, not repair the drift its own change created.
`/docs-sync` is deliberately read-mostly. Warehouse writes have a stronger pre-write freshness rule,
but even that does not establish the general post-change duty to refresh a map whose keys,
relationships, grain, load behavior, or consumption surface the current task changed. The result is
a permitted “code done, known repository truth stale” handoff.

> **CONSTRAINED BY THE CONTEXT CEILING — checked 2026-08-21.** This entry rewrites the shipped
> **Agentic Workflow**, which lives on `.github/instructions/framework-rules.instructions.md` — the
> carrier counted in `static.claude` (`scripts/context-footprint.ps1:246-247`). Measured headroom is
> **83 characters on monorepo**, 499 on dotnet.
>
> That does not block this entry the way it blocks B-96 and B-99, because a *replacement* can be
> size-neutral: report-only text goes out as reconciliation text comes in. But it does impose a hard
> design constraint that the entry does not currently state — **the new wording must be no larger than
> the old**, and "add narrowly stack-owned triggers" is net-additive by definition. Budget it before
> designing, not after, or the first release will refuse.
>
> Third entry found routing through B-158(b). That decision is now gating a category, not an item.
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

**Review gate — OPUS REVIEW DONE 2026-08-22: REQUEST CHANGES.** Recorded in full at the end of
`.claude/plans/2026-08-11-b136-change-owned-artifact-freshness-design.md`. **Implementation is not
authorised.** Two blockers and one scope reduction:

1. **Step 1 is unbudgeted.** The Agentic Workflow lives on the carrier counted in `static.claude`,
   and "reconcile" wording is necessarily longer than "flag" wording — against **83 characters** of
   monorepo headroom. Either author it size-neutral against a *named* displacement, or wait on
   B-158(b). This is the fourth entry found routing through that decision. **WSD-055 resolved the
   decision on 2026-08-29 by retaining the ceiling; a named size-neutral displacement is therefore
   required.**
2. **The artifact/action table must not ship as a table.** It is the second inventory this entry
   forbids, and B-164 measured that shape failing: four entries enumerated the scripts they knew
   about and a fifth defect appeared in an unlisted one. Ship the durable principle; leave
   file-specific triggers with the artifacts that own them. Keep the table in the plan as rationale.
3. **The behavioural half is unbuildable now** — five entries are already behind the eval budget and
   B-112 found four instruments broken on first version. Ship the rendered contract, prove delivery
   structurally, and record compliance as **UNMEASURED** rather than implying it was tested.

**Proportionality, answered as asked: yes, a shared-rule-only change removes most of the harm.**
B-98 measured carrier-delivered guidance going 0/6 → 6/6 while the same content in a routed skill
stayed 0/6. Ship step 1 alone; defer the warehouse trigger until the general rule is observed — it is
additive text on the same budget and its marginal value is unmeasured. Note it would cost the
monorepo twice, since skills compose there from both stacks.

**Confirmed sound:** carrier placement genuinely reaches installed consumers (B-97 Option A), which
is the opposite of what `CLAUDE.md` placement would do — state that reasoning in the change so a
later editor does not "tidy" it into the protected file. **One addition:** an artifact the agent
cannot *read* must report a blocker, never `Affected artifacts: none` — maintenance rule 7.

**Proportionality:** the current report-only wording is directly observed and is the requested harm.
A shared completion-rule correction plus the smallest domain-specific trigger removes most of it; a
documentation graph, automatic classifier, mutating `/docs-sync`, or exhaustive skill inventory does
not.

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

> **STEP (a) DONE 2026-08-21 — the static trigger-vocabulary audit, run and validated against the
> four known results first, as this entry requires. VERDICT: it reproduces the extremes and fails in
> the middle, so it may rank candidates and must not be used to predict any single skill.**
>
> **Validation against the measured cases:**
>
> | case | measured | vocabulary match | agrees? |
> |---|---|---|---|
> | `add-warehouse-load` (B-117) | **6/6** | description opens *"Add a new fact or dimension load"*; natural prompt is "add a warehouse load" — direct | ✅ |
> | `map-warehouse` (B-127) | **0/16** | description says *"Map a warehouse codebase"*; the prompts asked to trace an attribute or write a report and never said "map" | ✅ |
> | `add-entity` (B-117) | **0/4** counted | correctly not selected on a warehouse-load prompt — a true negative, not a miss | ✅ |
> | `add-warehouse-load` (B-126) | **1/6** | description explicitly covers *"or extend an existing one"* and *"slowly-changing-dimension"*, which the enhancement prompts did use | ❌ |
>
> **The B-126 row is the finding.** Vocabulary overlap was present and selection was still 1 in 6, on
> the *same skill* that scored 6/6 elsewhere. So trigger vocabulary is not sufficient: the same words
> in a differently-shaped task produced a sixfold difference. The audit therefore discriminates
> *confident match* from *confident mismatch* but has **no resolution in the middle** — which is
> exactly where the unmeasured skills mostly sit. Recorded as a limit on the instrument rather than
> discovered later as a wrong prediction.
>
> **Ranking of the 16 shipped skills, for choosing what to measure — NOT evidence of behaviour:**
>
> - **Write-shaped with direct vocabulary** (the `add-warehouse-load` 6/6 shape): `add-component`,
>   `add-endpoint`, `add-entity`, `add-lazy-route`, `add-service`, `add-signal-store`, `add-tests`,
>   `add-warehouse-load`, `register-service`. A developer asking for these says the skill's own noun.
> - **Read/analysis-shaped** (the `map-warehouse` 0/16 shape): `map-warehouse`, `perf`,
>   `dependency-audit`, `enforce-architecture`, `enforce-standards`. Natural phrasing is "is this
>   slow?", "check my dependencies", "does this follow our architecture" — none of which carries the
>   skill's trigger words.
> - **Ambiguous**: `create-adr`, `remember-for-team`. Write-shaped, but the natural prompt ("we
>   decided X", "remember this for the team") only partly overlaps.
>
> **What this changes about the plan.** The read-shaped group is where the risk is concentrated and
> it is also the group the audit is *least* able to call, given the B-126 result. So the live budget,
> when it exists, should buy measurements of **read-shaped skills on naturally-phrased prompts** —
> `perf` and `dependency-audit` first, since unlike `map-warehouse` they have no measurement at all
> and are not warehouse-domain, which would also break the warehouse-heavy sampling bias this entry
> already records.
>
> **Cost: zero.** No live trials were spent to produce this, which was the point of doing it first.

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

### B-174 · Normalize duplicate-key and wrong-root JSON semantics across doctor/installer parsers
**Filed against:** v0.77.0 (2026-08-24)
**Effort:** S–M · **Priority:** P3

v0.77.0 aligns the accepted JSON *syntax* across PowerShell, `jq`, and Python, including comments,
single quotes, unquoted keys, trailing commas, non-finite constants, and leading-zero integers.
Three lower-value semantic edges remain: duplicate or case-colliding object keys are not rejected
consistently across the three parsers; a syntactically valid scalar or array Copilot hook file is
treated as “no registration” rather than diagnosed as the wrong root shape; and the doctor can
mistake a `command`, `bash`, or `powershell` property under an unrelated object for a real hook
registration. Choose one fail-closed duplicate-member/root-shape and registration-schema contract,
apply it recursively to all three parser paths, and fold case-colliding keys, scalar/array hook
roots, and unrelated nested properties into the existing strict-JSON matrices.
Also distinguish “`jq` parsed this input as invalid” from “the installed `jq` passed
the basic probe but cannot execute the required query,” so the latter can try a working Python
fallback. Do not add a fourth parser or a standalone suite.

## Known deferred work (previously agreed, converted to entries so it survives handover)

**B-14 shipped in v0.25.3 (2026-07-05) — see `meta/BACKLOG-DONE.md`.**

## Completed entries

Completed entries live in meta/BACKLOG-DONE.md.
