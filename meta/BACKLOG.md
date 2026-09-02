# Framework backlog — Fable exit audit (2026-07-04, framework v0.25.0)

> **How to use this file.** This is the prioritized work list produced by a full-workspace audit
> before model handover. Every entry is self-contained: problem, evidence, suggested approach,
> effort (S ≤ ½ session, M ≈ 1 session, L = multi-session), and which meta-invariants (#1–#7 in
> the root `CLAUDE.md`) the fix must respect. Before starting any entry, read root `CLAUDE.md`
> (meta-workflows, definition of done) and `DEVELOPING.md` (command recipes). Ship via
> `.claude/scripts/release.ps1` when shipped behavior changes [#7]. Work P1s first; within a
> band, order is the suggested sequence. Complete an entry by moving it intact to
> `meta/BACKLOG-DONE.md` with its closure date and shipped version when one exists.
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
`meta/BACKLOG-DONE.md`. No open P3 items remain from the audit band.** Post-audit entries B-213 and
B-214 were closed 2026-09-02 after premise and proportionality review; see
`meta/BACKLOG-DONE.md`.


## Strategic backlog — post-Fable horizon (added 2026-07-17, Fable strategic review)

> **Why this section exists.** A strategic review (2026-07-17, framework v0.31.0) asked: what are
> the framework's structural shortcomings, and what should the work list look like for a
> maintainer who no longer has Fable-tier review on tap? The audit-band items (P1–P3) are all
> shipped; the "Known deferred work" below is a feature list. This section is different — it
> targets the **gaps between the framework and reality**: no behavioral evidence, no field
> evidence, no legal basis for consumption, one-time host verifications going stale, and a
> maintenance process calibrated to a frontier-model reviewer.
>
> **CURRENT PRIORITIES REVALIDATED 2026-09-02 for v0.80.0 — deliberate, not file order.**
> B-42 and B-49 remain the open strategic items. B-213 and B-214 were closed 2026-09-02 after
> premise and proportionality review; see `meta/BACKLOG-DONE.md`. B-42 has three non-author issue reporters but
> still zero balanced, independent FS2 Module A pairs; run one when a participant exists and let that evidence
> reorder the backlog. B-49 is hard-deferred because WSD-062 invalidated its current instrument;
> no provider work is authorised until a current target, executable oracles, isolation, canaries,
> released tag, and explicit spend authority are freshly locked. B-136 is DONE for v0.80.0; see
> `meta/BACKLOG-DONE.md`. B-212 closed without product change after its
> bounded audit found coherent adaptive depth and no threshold-attributable material harm; WSD-067
> records the residual lifecycle mismatch and reopen trigger. B-72, B-112, B-129, B-133, B-159, B-160,
> and B-174 were individually closed or rejected after premise and proportionality review; their
> exact residuals and reopen triggers are preserved in `meta/BACKLOG-DONE.md`.
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
> and shares every design blind spot. **The three non-author entries in `meta/field-reports.md` are not
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

### B-49 · Quarterly live-fire drill — install into a real OSS repo, verify behavior, measure value-add
**Filed against:** v0.31.0 (2026-07-17)
**Effort:** drill #0 = 1 session (freezes the Appendix) · ~½ session per quarter thereafter ·
**Invariants:** #5 #6 · maintainer-decided 2026-07-17 · host evidence is separately governed by
WSD-066; complements (does **not** replace) B-42

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
> WSD-066 also removes the old instruction to execute a general B-43 recertification cycle here.
> A replacement may include only host evidence required by its freshly locked objective; it does
> not inherit a calendar-driven certification packet.
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
A fixed cadence was also intended to refresh host evidence; WSD-066 supersedes that use of the
drill. Host re-certification is now triggered by a claim or decision, contrary evidence, or a
host-facing mechanism change whose result could alter a decision — not by the calendar alone.

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
4. **Historical only — superseded by WSD-066:** do not run a general host-recertification packet.
   A re-locked drill may include only the capability evidence needed for its own current claim or
   decision.
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
> them rather than treating the existence of prose as execution evidence. WSD-062 later invalidated
> that drill packet, and WSD-066 removed its general host-recertification obligation; this paragraph
> remains historical evidence, not current execution authority.
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

## Known deferred work (previously agreed, converted to entries so it survives handover)

**B-14 shipped in v0.25.3 (2026-07-05) — see `meta/BACKLOG-DONE.md`.**

## Completed entries

Completed entries live in meta/BACKLOG-DONE.md.
