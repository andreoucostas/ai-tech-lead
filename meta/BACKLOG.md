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
>    a stronger form than written: evidence or its explicit absence is exposed by `release.ps1`'s
>    review ledger rather than left only in prose; quality remains human-judged. B-47 landed MIT root-only;
>    the dist-travel half is deferred and filed separately.
> 2. **B-42** (field pilot) — start it early because its value is elapsed time; it runs in the
>    background while other items proceed, and its evidence should re-prioritize everything else.
> 3. ~~**B-41**~~ (agent-behavior harness) — **done 2026-08-13**, see `meta/BACKLOG-DONE.md`.
> 4. **B-49** (quarterly live-fire drill) — build the drill kit once B-41's first scenarios exist;
>    it becomes the recurring vehicle that *executes* B-43 (and reviews B-44) every quarter.
> 5. Then interleave: **B-15** (CI recipe) from the deferred list — it is
>    the consumer-lifecycle half of the same story — plus **B-44/B-46/B-48** as capacity allows.
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

> **THE PREREQUISITE IS SETTLED, AND THE ANSWER IS NO — 2026-08-21.**
>
> This entry defers to B-98 step 1 on whether `map-warehouse` fires at all on an incident-shaped
> prompt. **That question has been answered twice, both times negatively**, and B-98 is archived:
>
> | probe | result |
> |---|---|
> | B-98 step 1 | `r = 0/6` — neither the skill nor the map was reached |
> | B-127 | **16/16 `ROUTING_NON_REACH`** — `map-warehouse` was never read or selected once |
>
> **Apply this entry's own criterion to that result.** It states: *"if it does not fire, this content
> work does not reach the developer however good it is, and the description change in the design
> (§3.5) is insufficient."* It does not fire. So the design as written is **invalidated by its own
> prerequisite**, and improving `map-warehouse`'s content would produce something correct that nobody
> receives. Do not implement §3.5 as specified.
>
> **The remedy that demonstrably works is the one B-98 found:** moving the guidance onto the
> unprotected always-loaded carrier took map reach from **0/6 to 6/6**. WSD-032 already locks that for
> read-side guidance. That is the shape this entry should take.
>
> **Which makes its real blocker the same as B-99's:** the carrier is counted in `static.claude`
> (`scripts/context-footprint.ps1:246-247`) and monorepo has **83 characters** of headroom. There is
> no room to move this content onto the channel that would deliver it. **B-158(b) gates this entry.**
>
> **GATE RESOLVED 2026-08-29 — the ceilings stay.** WSD-055 retains 40,000/48,000 as stable
> recurring-context budgets. This entry is no longer waiting on a decision, but it has no additive
> budget: proceed only with a named, behavior-preserving displacement or close without shipping.
>
> **Not:** do not respond to the 0/16 by making the skill's description more attractive. That is
> tuning the mechanism measured at zero, and B-160 records that trigger vocabulary did not even
> predict the one middling case (1/6 on prompts that used the skill's own words). The channel is the
> problem, not the wording.

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

**B-99 is DONE (2026-08-29) — matched incident-shaped evaluation passed 4/4; no consumer change was justified; see `meta/BACKLOG-DONE.md`.**
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

**Status: OPUS REVIEW DONE 2026-08-22 — REQUEST CHANGES.** Phase 0 execution and shipped changes remain unauthorised; the findings are below.

> **CLAUDE OPUS REVIEW — 2026-08-22. Verdict: REQUEST CHANGES.** The defect is real and the
> fresh-context review already removed the worst of the first design. Three findings: one blocking,
> one that shrinks the deliverable to roughly a sentence, and one on durability.
>
> **1. BLOCKING — the smallest candidate implementation is unbudgeted, exactly like B-136's.**
> Step 1 says "strengthen the existing compact `Codebase Context`" with purpose, actors, critical
> journeys, domain vocabulary, intended outcomes, constraints/non-goals, sources, authority/owner and
> open questions — then step 2 adds six per-claim dimensions (Basis, Status, Source, Authority, Scope,
> review date). That template text lives in the shipped `CLAUDE.md`, which is **counted in
> `static.claude`** (`scripts/context-footprint.ps1:245`). Measured 2026-08-22: **83 characters** of
> monorepo headroom, 499 on dotnet, against a hard failure since B-110. Nine fields plus a
> six-dimension claim schema is hundreds of characters. **This cannot ship as written**, and the
> plan never checks. Fourth entry routing through B-158(b) — fifth counting B-136.
>
> **BUDGET DECISION 2026-08-29.** WSD-055 retains the ceiling. Only the review's smaller
> instruction correction may proceed, and only against a named, behavior-preserving displacement;
> the larger schema has neither proportionality nor static-context authority.
>
> **2. PROPORTIONALITY — the concrete defect is one instruction, and the fix is close to one
> sentence. The schema is not proportionate to it.** The entry names the harm precisely: all three
> `/bootstrap` variants tell the model to replace `Codebase Context` with *"real findings from this
> codebase"*, so routes, DTOs, forms and test names become unmarked claims about users and intent.
> The minimal correction is to that instruction — **code establishes an implemented surface, never
> why it exists, who should use it, or whether it creates value; label code-derived claims as
> implementation observations and leave product intent explicitly unknown rather than inferred.**
> That removes the false-authority defect. A six-dimension provenance schema is a *different, larger*
> project whose value over the labelled-unknown version is unmeasured. **Recommend shipping the
> instruction correction first and re-testing before designing the schema.**
>
> **3. DURABILITY — an unenforced structured schema decays into something worse than prose.** Six
> dimensions per claim, in a consumer-owned file, with no check, will be filled once at bootstrap and
> then rot — and a stale `Status: supported` with a two-year-old review date is *more* authoritative
> to a reader than the unmarked prose it replaced. This repo has the evidence: `docs/wiki/` carries
> frontmatter **and a machine check** (`wiki-check`), and B-83's filed-against stamps only became
> reliable when made blocking. **If the schema ships at all, it needs an enforcing check or an
> explicit statement that it is advisory and will rot** — WSD-047's rule applied to a record format
> rather than a guard.
>
> **4. Sound, and worth keeping as-is:** the pre-registered stop rules — including *"close with no
> shipped change if the unchanged framework already avoids unsupported intent claims"* — are the right
> shape and are what stop this becoming a capability build in search of a defect. The
> value/usability/feasibility/viability separation and the refusal to treat an AI persona as product
> authority are both correct. The privacy boundary is correct and should be **strengthened one step**:
> `CLAUDE.md` is version-controlled and shared, so the default should be *references to controlled
> systems*, not minimized summaries of sensitive material — a summary in git is permanent.
>
> **5. On Phase 0 authorisation:** clearing this review gate does **not** make Phase 0 runnable. Ten
> scenario classes at three runs per host is live-eval spend, and five entries are already behind that
> budget. Authorise the design, but record that execution waits on the same decision as B-49, B-97,
> B-129 and B-133 — and note that B-112 found **four instruments broken in their first version**, so
> the graders here need red-testing against planted transcripts before any result is banked.
>
> **Disposition:** not authorised as written. Budget the template text against a named displacement
> or B-158(b); ship the `/bootstrap` instruction correction first and measure before building the
> schema; and if the schema ships, decide honestly whether it is enforced or advisory.

**B-130 is PARTIALLY DONE (2026-08-18) — the framework-doctor instance is FIXED and shipped;
the original `ScriptTwinParity` docs-sync-check 5.1 divergence is STILL OPEN. See below.**

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
>
> **SECOND DIRECT OBSERVATION, 2026-08-22 — the framework's REAL codex carrier was probed, and it is
> delivered by HOST INJECTION, not by discovery. This closes limit 2 above.**
>
> The first probe used `.claude/skills/`, which is not what ships for codex; this entry recorded that
> as a stated limit. `AGENTS.md` is the carrier the framework actually ships, and it had never been
> tested.
>
> **Fixture** (`AGENTS.md` only, no `.claude/`, no `CLAUDE.md`): four conventions, one of them
> carrying a token that exists **nowhere else in the repository** — every file added under `src/`
> must begin `// LEDGER: NIMBUS-4471`. The one existing source file deliberately **lacks** the stamp,
> so mimicry cannot produce it. **Prompt:** *"Add a small utility to this project that clamps a number
> between a minimum and a maximum. Follow the conventions of this repository. Then tell me what you
> did."* — naming no file, no rule, no ledger, no token.
>
> **Result: three conventions applied unprompted.** `src/clamp-number.js` (lower-kebab-case) begins
> `// LEDGER: NIMBUS-4471`, and a mirroring test was created under `tests/`.
>
> **The mechanism is the finding, and it differs from the first probe.** Codex's own tool calls show
> it ran `rg --files` (a listing, in which `AGENTS.md` appears as a *name*) and then explicitly read
> only `src/math-utils.js` and `README.md`. **It never opened `AGENTS.md`** — zero `Get-Content`,
> `cat`, or `rg` against it — yet its first planning message already refers to *"the required ledger
> stamp"*. The host put the carrier in context.
>
> | probe | carrier | mechanism |
> |---|---|---|
> | 2026-08-20 | `.claude/skills/SKILL.md` | **discovery** — codex grepped `.claude/` and read the file |
> | 2026-08-22 | `AGENTS.md` | **host injection** — never read, rule applied anyway |
>
> **Why this matters for the scoping question.** Host injection is a *stronger* delivery guarantee
> than grep-discovery: it does not depend on the model choosing to search, so framework rules are in
> context for every prompt rather than for the ones that prompt a search. The delivery precondition
> for running **outcome-graded** scenarios on codex is therefore satisfied — which is the half of
> this entry that the budget argument rests on, and it was previously assumed rather than observed.
>
> **Limits, stated so this is not over-read:** one trial, one tier (`gpt-5.6-sol`), one CLI version
> (0.148.0). The prompt said *"follow the conventions of this repository"* — not a pointer to the rule
> or the token, but not zero-pointer either. And this says nothing about **routing**: it establishes
> that the carrier arrives, not that codex selects skills the way Claude Code does. That distinction
> is exactly the one this entry already draws, and it still holds — routing-attribution scenarios
> remain non-portable.
>
> **PORTABILITY AUDIT, 2026-08-22 — this is the investigation deliverable this entry is scoped for
> (M, investigation only). With delivery now observed, the remaining question was which scenarios
> could actually move, and the answer is most of them.**
>
> **Method:** a scenario is *non-portable as written* if its grader reads `$e.Tools` — the host's typed
> tool-event stream. That stream is Claude Code's; codex emits its own shell-shaped calls and nothing
> equivalent, so any verdict computed from it cannot be reproduced. A scenario whose grader reads only
> the produced artifacts (files, git state, SQL, docs) has no such dependency.
>
> **Result: 8 of 42 scenarios reference `$e.Tools`.** The other **34 grade artifacts only** and are
> therefore *candidate-portable*.
>
> | non-portable as written | what it needs the tool stream for |
> |---|---|
> | `angular-form-control` | `usedSkill` attribution |
> | `archived-redirect` | which installer was invoked |
> | `guard-retry` | the `Write` that the guard blocked |
> | `install-handoff` | whether bootstrap/installer was run |
> | `route-fix` | red-test-then-fix **ordering** of tool events |
> | `skill-add-tests` | `Skill` selection |
> | `warehouse-health-decision-a` | typed decision evidence |
> | `warehouse-partition-mismatch` | typed evidence ordering |
>
> That list is coherent rather than arbitrary: every one of them measures *how the host behaved*, and
> those are precisely the scenarios this entry already said do not port. The 34 that remain measure
> **what the agent produced**, which is host-independent by construction.
>
> **So the scoping answer is:** a codex executor is worth building for the artifact-graded majority,
> and the eight host-behaviour scenarios stay on Claude Code permanently — not as a limitation to fix
> later, but because measuring Claude Code's routing on a different host is a category error, which is
> WSD-042's point.
>
> **Do NOT read this as "34 scenarios are ready to run."** *Candidate-portable* means only that no
> tool-event dependency was found. Each still needs its fixture to build on the codex path, its
> grader to be driven from a codex transcript, and a **red-test against a planted failing transcript**
> before any result is banked — B-112's rule, and the reason four instruments in this repo shipped
> broken. The audit narrows the work; it does not do it.
>
> **Cross-check before building:** `run-agent-evals.ps1` is Claude-Code-hardcoded well beyond the
> graders (invocation, stream parsing, budget flags). The executor is the larger follow-on this entry
> already flags as out of scope; nothing above changes that.


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

### B-165 · Inert-check detection recognises one shape; three others shipped in a single day
**Filed against:** v0.69.0 (2026-08-21)
**Effort:** S (record the shapes) · M (any detection) · **Priority:** P2 · found 2026-08-21 across four deliveries · **Invariants:** #5 #7

**B-59 and B-64 exist to catch checks that cannot fail.** They look for the *syntactic* shape — a
literal `Assert $true`, a source-text grep standing in for a behavioural assertion. On 2026-08-21
three further instances shipped or nearly shipped, and **none of them has that shape**. All three were
caught by deliberately breaking the instrument; none by reading the diff, and I read all three.

| # | where | the shape | why detection missed it |
|---|---|---|---|
| 1 | B-83 | `Assert $true 'advisory finding completed'` | the known shape — caught, and it is the only one that would be |
| 2 | B-163 | **exit-code collision**: the policy filter exited `1` for "no cases matched", and the mutation harness reads any non-zero as "the mutation was caught". With the `secret` tag removed: **4 passed while two mutations tested nothing** | the assertion is real and the code is ordinary; the defect is that two distinct states share one value |
| 3 | B-156 | **the failing path is the passing path**: an unrunnable `grep` yields an empty extraction, and empty means "nothing to check", so the gate passes | no `Assert` is suspicious; the check simply never runs |
| 4 | B-130 | **a comparison that stops comparing**: reading process streams raw fixed one host and, uncaught, would have normalised away real differences. `54 passed / 28 failed` is what a *broken comparison* produces — the same number a genuine regression produces | indistinguishable from success by summary line alone |

**The generalisation, which is the deliverable:** an inert check is not a syntactic pattern, it is a
**semantic property** — *no reachable input makes this check fail*. Shapes 2–4 all satisfy it while
looking completely ordinary. Two of them arrived **inside a performance improvement**, which is the
dangerous packaging: a suite that got 14x faster and a suite that went from failing to passing both
have the same signature as a suite that stopped testing.

**Do:**
1. **Record the four shapes** where check authors meet them, alongside Maintenance model rule 4. That
   rule already says a green result counts only from an instrument seen red — these are the ways an
   instrument *looks* red-capable and is not.
2. **State the two rules the instances actually turn on**, because both are checkable by a human in
   seconds: (a) *when a test's exit code carries data, every new exit path collides with it* —
   B-163's filter needed a sentinel outside the failure-count range; (b) *when an empty result and a
   failed result are the same value, the check has no failing input* — B-156's `grep` and B-165's own
   examples.
3. **Then assess whether detection is possible at all**, honestly. WSD-028: a rule is real only where
   tooling can refuse. A mutation-based check ("does this test fail when its subject is broken?") is
   the only mechanically sound detector, and it is expensive — `GuardPatternErrors` exists precisely
   because that is what it does for one file. Do not assume it generalises cheaply.

**Not:** do not extend B-59/B-64's grep to more patterns. Shapes 2–4 have no shared syntax to grep
for, and a wider denylist would give false confidence — the same failure mode as B-164's site
enumeration, which stopped converging after four entries.

**Proportionality:** four instances in one day is the case for recording the shapes, which costs
almost nothing. It is **not** yet the case for building a general detector — that needs a real
mutation harness per suite, which is exactly the cost B-138 spent the day reducing. Record first;
decide detection separately.

**Cross-links:** B-59 and B-64 (the existing detection and its one shape), B-75 (an assertion too
weak to fail — the nearest recorded relative), B-112 (instruments whose first version could not
produce their claimed result — this is the same defect after shipping rather than before),
B-164 (the sibling: one rule, many mechanisms, enumeration failing to converge), B-163 and B-156 and
B-130 (the instances).

### B-166 · RCA: "verified on both hosts" was mistaken for "verified on both legs", and CI caught what four local instruments could not
**Filed against:** v0.70.0 (2026-08-22)
**Effort:** S · **Priority:** P2 · found 2026-08-22 when v0.70.0's CI went red · **Invariants:** #3 #7

**What happened.** B-130's fix replaced the harness's stderr capture with `Invoke-RawProcess`, to stop
Windows PowerShell 5.1 rendering a child's stderr as an ErrorRecord. That fix was correct and is
shipped. The **delivery also rewired `RunArg`** through the same function — which B-130 never
required — and on Linux, redirecting stdin to a child that never reads it raises **EPIPE**. v0.70.0's
CI failed on `linux-hooks (monorepo)` alone: `[FAIL] missing context skips -- Broken pipe`. One test,
one platform.

**Why no local instrument caught it.** All four that ran were real, and all four were blind here:

| instrument | why it passed |
|---|---|
| `Guard.Tests` on pwsh 7 **and** 5.1 | both are Windows; EPIPE-on-unread-stdin is a POSIX behaviour |
| full 19-file shipped suite | run on Windows only |
| mutation red-test (`exit 2` → `exit 0`) | proves the suite can fail, not that it runs everywhere |
| `validate-dist` on both twin legs | syntax and content, not runtime process semantics |

**The specific error, and it is a reading error not a process gap.** `meta/LEARNINGS.md` and the
maintainer's own memory already say *a twin change is not done until CI is green on both legs*. I
treated **"both PowerShell hosts on Windows"** as satisfying that. It does not: the two legs are
**windows and linux**, and running two editions of PowerShell on one OS tests the host axis while
leaving the platform axis untested. The rule was right; my instantiation of it was wrong.

**The second cause, which is the more general one: scope creep in an accepted delivery.** B-130 was
about `Invoke-Hook`'s byte-for-byte *twin comparison*. `RunArg`'s callers assert on exit codes and
stdout text and never on stderr equality, so raw capture bought them nothing and cost a platform
regression. **I reviewed that diff and did not ask why a function outside the entry's scope had
changed.** Reviewing a diff for correctness is not the same as reviewing it for *scope* — an
unnecessary change is a pure risk contribution, and it is the one that failed.

**What else is exposed to the same class.** Every change to `_HookHarness.ps1` or to process
invocation generally, because the harness runs on Windows locally and on both platforms in CI, and
the local instruments are Windows-only by construction. The concrete gap: **nothing in the local gate
set exercises a POSIX process model**, so any Windows-passing change carries unmeasured Linux risk
until CI. That is not fixable by adding another Windows check.

**Do:**
1. **State the axis explicitly** wherever the both-legs rule appears: the legs are **platforms**
   (windows, linux), not hosts (pwsh 7, 5.1). Both matter and they are independent; today's change
   needed all four cells and only two were covered.
2. **Add a scope question to diff review**: for each changed function, does the entry require it? An
   unrequired change should be justified or reverted before acceptance. Cheap, and it would have
   caught this one by inspection.

**Not:** do not try to reproduce POSIX process semantics locally with a shim. A shim that
approximates EPIPE would be a proxy, and this repo's record with proxies is poor (B-70, B-160). CI is
the real instrument; the fix is to *believe* it is required rather than to simulate it.

**Cross-links:** B-130 (the delivery), B-70 (cheap local proxies that would have caught neither
Linux-only defect — the same finding, two months earlier), B-164 and B-165 (the sibling RCAs from
this campaign: one rule many mechanisms, and inert checks in many shapes).

### B-167 · RCA: the reviewer's own verification was wrong three times, always in the direction of reporting success
**Filed against:** v0.72.0 (2026-08-22)
**Effort:** S · **Priority:** P2 · found 2026-08-22 across one session's deliveries · **Invariants:** #5

**Why this is filed rather than shrugged off.** The maintenance model puts the reviewer between the
implementer and the release: rule 3 says nothing enters the record as observed unless observed, and
rule 4 says a green result counts only from an instrument seen red. Both assume the reviewer's *own*
checking is sound. On 2026-08-22 it was not, three times, and **every failure reported success**:

| # | what I ran | what it reported | what was true |
|---|---|---|---|
| 1 | `AgentEvals.Tests.ps1 \| grep -c '^FAIL'` | `0` | the suite was **throwing** and exiting 1; it signals by exception, not by a FAIL line |
| 2 | a probe grepping for `weaken` to detect "did it report?" | every arm "reported" | the word appears in the *nothing qualifies* line too, so the probe could not distinguish |
| 3 | comparing two twins' output visually | "TWINS AGREE" | the console had folded an em dash into a hyphen; comparing **bytes** showed they differed |

A fourth belongs beside them: a postcondition I wrote asserted the three pinned strings I already
knew about, and two more existed. It could not detect what I had missed, which is B-164's
site-enumeration failure arriving in my own tooling.

**The pattern is one-directional and that is the dangerous part.** A verification that is wrong
randomly produces false alarms, which get investigated. These were all wrong in the direction of
*looks fine* — a grep that finds nothing, a match that is too loose, a comparison the display already
normalised. **A silent verification failure is indistinguishable from a pass**, which is the same
property that makes inert checks dangerous (B-165) and the reason four instruments in this repo
shipped broken (B-112).

**What caught each one:** #1 the exit code, checked separately on a hunch; #2 reading the actual
output instead of the grep's count; #3 `od -c`; #4 running the test rather than trusting the script.
In every case the fix was **looking at the thing itself** rather than at a summary of it.

**Do:**
1. **Check the exit code, not the output, when asking "did this pass?"** A harness that reports by
   exception, or that prints `[FAIL]` in a format your pattern does not match, will answer "0
   failures" to a grep while failing.
2. **A detection grep must be red-tested like any other instrument** — confirm it fires on a known
   positive *and* stays silent on a known negative before trusting either. #2 above would have taken
   one extra run to catch.
3. **Compare bytes, not rendered text**, whenever the question is "are these identical?" The console
   normalises; `cmp` and `od -c` do not. This is the same class as invariant #4's BOM rule.

**Not:** do not add tooling for this. It is a discipline about how the reviewer looks, and a checker
that verified the verifications would need verifying. Recording the three shapes is the deliverable.

**Cross-links:** B-165 (inert checks — the same one-directional failure on the authoring side),
B-112 (instruments that could not produce the result they claimed to test for), B-164 (enumeration
that cannot detect what it did not enumerate), B-166 (the same session's cross-platform blind spot,
also a verification that was real but pointed at the wrong thing).

**B-168 is implemented for v0.73.0 — the installer now derives brownfield collisions from ownership,
preserves persistent state, refuses unsafe archives/dirty worktrees, and upserts GitHub skills; see
`meta/BACKLOG-DONE.md`.**

**B-169 is implemented for planned v0.74.0 — the invalid post-install impact comparison is retired
behind inert compatibility tombstones; see `meta/BACKLOG-DONE.md`.**

**B-170 is implemented in v0.74.0 — local release scheduling no longer duplicates shipped-hook
coverage already required from CI; see `meta/BACKLOG-DONE.md`.**

**B-171 is implemented for planned v0.75.0 — active assurance claims are scoped to observable
surfaces and warehouse-only auto-routing refuses the uncertified lifecycle; see
`meta/BACKLOG-DONE.md`.**

**B-172 is implemented for planned v0.76.0 — updates now plan before mutation, reconcile only
content-qualified cumulative retirements, and refuse implicit downgrades; see
`meta/BACKLOG-DONE.md`.**

**B-173 is implemented for planned v0.77.0 — warehouse-only routing now enters an evidence-selected,
solution-free lifecycle instead of inheriting application assumptions from the delivery profile;
see `meta/BACKLOG-DONE.md`.**

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

### B-176 · Enforce unique warehouse signal-category definitions
**Filed against:** v0.77.0 (2026-08-24)
**Effort:** S · **Priority:** P3

The shipped signal catalog currently has one row per category, but the root selectors and the bash
warehouse checker count matching rows while the PowerShell checker deduplicates category names.
A future duplicate row could therefore inflate the two-category threshold differently across
consumers. Add one catalog-integrity check for unique category keys, make all four runtime readers
count distinct categories, and make the eval's authoritative-catalog fixture reject duplicates too.
Fold a duplicate-row mutation into the existing warehouse map checker suite; do not create a
standalone catalog suite.

### B-210 · Make root meta-test hashing independent of inherited PowerShell module paths
**Effort:** S · **Priority:** P1 · **planned v0.79.0**
**Filed against:** v0.79.0 (2026-08-30)
**Evidence source:** unreleased v0.79.0 candidate whole-range review
**Status:** DESIGN APPROVED — implementation and exact-candidate CI pending
**Plan:** `.claude/plans/2026-08-30-b210-wps51-hash-provider-design.md`

**Why:** whole-range adversarial review launched the existing native-Windows-PowerShell evidence
through the maintainer's real PowerShell 7 → `cmd.exe`/CP437 → Windows PowerShell 5.1 path. Its
inherited PowerShell-7-first `PSModulePath` leaves `Get-FileHash` unavailable, producing 41/10,
2/10, and 4/8 in UpdateDelivery, InstallerConvergence, and RootInstallerWarehouse. With only
`PSModulePath` absent so 5.1 reconstructs its native roots, the same commands return 51/0, 12/0,
and 12/0. This is a root harness false red rather than a product failure, but it makes the current
unqualified 5.1/CP437 release evidence incomplete and is therefore release-blocking.

**Do:** add one dependency-free streaming SHA-256 helper to the already shared root `_HookHarness`,
route the complete five-call census in those three suites through it, and correct one stale watcher
comment that still describes WSD-061's macOS provider as active after WSD-064. Preserve uppercase
64-hex output, literal-path and throw-on-unreadable semantics, explicit disposal, Windows
PowerShell 5.1 syntax/BOM, every existing test body, and result cardinality. Add no test, suite,
fixture, lane, product dependency, or shipped change. Two independent design reviews approved this
as the smallest fix that removes a repeatable maintainer-path false red; module imports and caller
environment rewriting were rejected as unreliable or over-broad.

**Evidence gate:** retain the exact old 41/10, 2/10, and 4/8 runs; require post-fix 51/0, 12/0,
and 12/0 under poisoned 5.1/CP437, native-root 5.1/CP437, and PowerShell 7. Verify fixed binary and
text SHA-256 oracles under both hosts, zero remaining same-class calls, unchanged cardinality,
BOM/AST, full root meta green, first exact-candidate Windows/Linux CI, and fresh immutable
implementation plus whole-release adversarial review before completion.

---

### B-204 · Make RootInstallerWarehouse fixture teardown fail honestly
**Effort:** S · **Priority:** P2 · **planned v0.79.0**
**Filed against:** v0.78.3 (2026-08-30)
**Status:** IMPLEMENTED CANDIDATE — exact supported-host CI green in run `33333912064` at
`dbdc38f508463c3c2fa7cb3d55d830deb7cd014b`; native-Linux dangling-root one-off still pending
**Plan:** `.claude/plans/2026-08-30-b204-root-installer-fixture-teardown-design.md`

**Why:** the unchanged B-203 full maintainer run printed a Windows sharing-violation from
`RootInstallerWarehouse.Tests.ps1` fixture cleanup, then reported 12/0 and contributed a green file
result. Seven GUID-scoped fixture roots remain under the workspace parent; six are empty and one
retains `.git` plus the exact `Nx prose` fixture. The installer assertions remain valid, but this
suite's teardown postcondition can fail without reaching its result counter because `Remove-Item`
errors are non-terminating and the harness records failure only on a thrown exception.

**Do:** add a local exact-path/reparse-safe bounded remover plus a lifecycle wrapper that preserves
body and cleanup failures separately. Route the file's eleven `New-Target` lifecycles and one
broken-jq scratch lifecycle through it. Use at most six `-ErrorAction Stop` attempts with a
cumulative 1.5-second failure-path delay, typed absence, and terminal failure into the existing
`It`; if body and cleanup both fail, report both rather than masking the product assertion. Add no
suite or `It`, no generic cleanup framework, and no stale-root sweeper. Disposable locked-handle,
dual-failure, invalid-path, and interior-link probes must discriminate the boundary; retain 12
results and intended mutation-red diagnostics under PowerShell 7/5.1 plus the standard concurrent
meta runner. The existing mutation callbacks must reject a cleanup-only red by machine-checking and
re-emitting their intended warehouse assertion/sentinel. Also replace only the two same-file
solution-free `Get-ChildItem -Include` expressions with explicit extension filtering: 5.1 otherwise
counts every recursively enumerated file and cannot run this candidate, while the assertion itself
remains valuable. Add no result for that folded prerequisite. Meta-only; first Windows/Linux CI and a
separately recorded native-Linux dangling-link probe still gate completion because the test file and
host-sensitive cleanup contract change.

**Candidate evidence:** exact test-file SHA-256
`C8FB30644FD20B689CF987A4DA0CA30FA31B43DB9BA549699526EA160A13947D`; two independent adversarial
reviews returned KEEP/APPROVE after finding and fixing a Windows PowerShell case-alias deletion and
a masked post-inspection failure. Disposable hostile probes passed under PowerShell 7 and native
Windows PowerShell 5.1. The existing file passed 12/0 under each host and 12/0 in the standard
concurrent runner; the full maintainer battery passed 31 files with zero failures. All three measured
runs left no new fixture path. No suite or `It` was added. Seven historical roots remain untouched.
Native-Linux dangling-link execution and the first Windows/Linux candidate CI remain explicit gaps,
so this item is not complete and is not release-approved.

**Immutable review:** a fresh reviewer approved exact range
`617dd4f6aa909fa1a97d80a973dd3231a9cc3a25..2e72fecd088c85cf0a7c98803aa76d64513b28fd`
from a detached no-hardlinks clone after independently replaying the locked-file false green and the
candidate's retry, containment, case-alias, junction, partial-deletion, post-inspection,
dual-failure, PATH, WPS5-oracle, and mutation anti-vacuity boundaries. Exact SHA/BOM/AST/cardinality,
scope, record gates, and no new residue were reconfirmed. The reviewer had no native-Linux vantage
and did not rerun the full concurrent battery, so approval remains bounded to the immutable Windows
candidate rather than completion or release.

---

### B-207 · Make the doctor Copilot-visibility fixture portable to Windows PowerShell 5.1
**Effort:** S · **Priority:** P2 · **planned >= v0.78.5**
**Filed against:** v0.78.3 (2026-08-30)

**Why:** B-175's required native Windows PowerShell 5.1 run executed its changed doctor matrix
successfully but left the full file at 31/1/1. The existing `Copilot CLI visibility is controlled`
setup invokes Git Bash with a nested `-c` string containing `>/dev/null`; legacy native-argument
marshalling turns that fragment into a repository-relative Windows path. Bash reports
`.../>/dev/null: No such file or directory`, and the constructed `both` world falsely says Copilot
is absent. PowerShell 7 passes 33/0. This is the same transport class as B-201 but a fourth site
outside its already-reviewed candidate, not evidence against B-175 product behavior.

**Do:** revalidate the exact PowerShell-5.1 argument corruption, then replace only this setup probe's
multi-layer `-c` transport with the existing raw-process/stdin mechanism already approved in B-201.
Preserve the four visibility worlds and doctor product code; add no suite, `It`, helper, hard-coded
tool path, or new capability claim. Require the existing result to fail on an unexpected/empty probe
outcome, pass under native 5.1 and PowerShell 7, and retain honest absence. Compose all distributions
and require first modified-test Windows/Linux CI before completion.

---

### B-208 · Decide whether inherited Bash strict mode is a valuable public compatibility contract
**Effort:** S for evidence/decision; M only if support is justified · **Priority:** P2 · no earlier than v0.79.1
**Filed against:** v0.78.4 (2026-08-30)
**Evidence source:** v0.78.4 candidate release-range review

**Why:** v0.78.4 release-range review exported `SHELLOPTS=errexit` into the shipped Bash process
tree. That is materially different from invoking one wrapper with `bash -e`: nested scripts inherit
the option too. The hostile run made ScriptTwinParity fail 8/2 and WarehouseMapCheck fail 0/3;
`warehouse-map-check.sh` silently returned `1` for a normally not-applicable repository, while a
template-checks resource world lost its required `CANT-VERIFY` diagnostic. A bounded source census
also found manual next-line status captures in other shipped scripts, including `wiki-check.sh` and
`framework-doctor.sh`. These are real signals, but exported `SHELLOPTS` is not part of the published
invocation and ordinary CI shells do not automatically export their `-e` setting into nested Bash.
It is therefore evidence for a decision, not a reason to expand B-203 or block v0.79.0.

**Do:** first establish whether inherited strict mode occurs in realistic supported consumer/CI
usage and whether making it a public contract creates net value. If yes, census every shipped Bash
manual-status capture and lock one cross-script design before implementation; do not repair the
observed files piecemeal. Reuse existing behavioral suites and hostile invocation modes wherever
they discriminate, adding no suite merely to count status sites. If evidence does not justify the
contract, record deliberate non-support and close this entry rather than keeping speculative debt.

---
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
(WS-3). Pre-receive hooks / Code Insights: rejected there — do not resurrect without a consumer request.

> **ENVIRONMENT-BLOCKED, checked 2026-08-22.** This entry defines "verified" as *actually executed
> against a local Jenkins container with evidence*, which is the right bar and is why it has not
> quietly shipped as an unverified recipe. **There is no Docker on this machine** — not on `PATH`,
> and Docker Desktop is not installed — so the container cannot be started and the verification
> standard cannot be met here.
>
> Writing the recipe *without* running it would produce exactly what the entry's own wording forbids:
> a pipeline file nobody has seen work, published to consumers who cannot easily tell the difference.
> That is the same failure class as shipping an unvalidated instrument (B-112) or claiming enforcement
> that is really advisory (B-48, WSD-047).
>
> **What it needs:** a host with Docker, or a Jenkins/Bamboo instance to run the recipe against. It is
> not blocked on design, effort, or a decision — only on an execution environment. Grouped with B-42
> and B-43 as the entries requiring something outside this machine rather than something outside this
> session.

**B-16 is implemented for v0.32.0 — see `meta/BACKLOG-DONE.md`.**

**B-17 was REJECTED on evidence 2026-08-17 (WSD-045) — see `meta/BACKLOG-DONE.md`.**

### B-20 · Coverage-as-diagnostic + diff-scoped mutation testing (the former v0.24.0 testing release)
**Filed against:** v0.26.0 (2026-07-12)
**Effort:** L · needs a **new version slot** — ≥ v0.28.0 (0.26.0 = merge, 0.27.0 = B-27 per WSD-012)
Execution-ready plan exists: `<home>\.claude\plans\v0_24_0-shipped-framework-testing.md`
(WS-T9 coverage holes-map + optional off-by-default patch-coverage gate, roll-your-own diff
coverage over `scripts/metrics.*` cobertura ∩ `git diff`; WS-T10 Stryker.NET `--since` /
StrykerJS `--incremental`; WS-T11 wire survivors into `test-critic`; WS-T12 docs/parity).
Key traps recorded there: Angular needs a cobertura reporter wired; CI must fetch the base ref;
"CI-enforced" = runs+reports by default, only the opt-in floor blocks.

> **THE CITED PLAN IS MISSING — verified 2026-08-22, and this changes the entry's status.** The entry
> says *"Execution-ready plan exists: `<home>\.claude\plans\v0_24_0-shipped-framework-testing.md`"*.
> That file does not exist. Searched: the cited path; all 27 plans under `~/.claude/plans/`; every
> `.claude/plans/*.md` in the repo; a filename search across both trees; and git history for a blob
> of that name. The only surviving mention of `WS-T9` anywhere is **this entry itself**. A branch
> named `claude/meta-framework-testing-strategy-ib0583` exists but carries B-33's composer work, not
> this.
>
> **So the four lines above are not a pointer to a design — they ARE the design**, and they are a
> seed, not an execution-ready plan. Maintenance model rule 1 requires a locked design plus
> adversarial critique before implementation of an M+ item, and this is L. **Status corrected from
> "execution-ready" to "needs design from scratch, seeded by the summary below".**
>
> The surviving summary is still worth having and should not be discarded: WS-T9 coverage holes-map
> with an optional off-by-default patch-coverage gate, diff coverage over `scripts/metrics.*`
> cobertura intersected with `git diff`; WS-T10 Stryker.NET `--since` / StrykerJS `--incremental`;
> WS-T11 wire survivors into `test-critic`; WS-T12 docs/parity. Plus the recorded traps — Angular
> needs a cobertura reporter wired, CI must fetch the base ref, and "CI-enforced" means runs-and-
> reports by default with only the opt-in floor blocking.
>
> **Fourth status-rot finding of the day** (after B-99's refuted blocker, B-96's answered
> prerequisite, and B-133's misleading effort estimate) and the most severe, because it is a *missing
> artifact* rather than a stale claim. An entry that says its design is done, when the design is gone,
> will cost whoever picks it up a planning cycle before they discover it.

**B-25-EXEC is DONE — v0.26.0 shipped 2026-07-12 (WSD-018); see `meta/BACKLOG-DONE.md`.**

**B-26 is DONE (2026-08-20) — one bullet was already discharged by B-32 and the other folded into the overlap watch; see `meta/BACKLOG-DONE.md`.**

## Completed entries

Completed entries live in meta/BACKLOG-DONE.md.
