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
**Effort:** S per cycle, recurring · **Invariants:** #5 · **execution vehicle: B-49's quarterly drill**

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

### B-50 · Copilot CLI 1.0.70 now consumes `postToolUse` context — update the shipped matrix
**Effort:** S · **Priority:** P2 documentation/capability honesty · **Invariants:** #3 #5 #7

**Found by:** B-49 drill #0 host recertification, 2026-07-17. The trusted-folder sentinel canary
performed a real write and the model returned the out-of-band `B49_POST_TOOL_4MV2` token injected
only by `postToolUse`. This reverses the live 1.0.68 observation on which
`docs/enforcement-surfaces.md` currently says the leg is dead. Re-run once in an isolated canary,
then update the shipped matrix/status note and any hook comments that demote Copilot post-write
feedback. Normal release path; do not fold the shipped change into the meta-only drill PR.

**B-52 is DONE (2026-08-18) — answered by live canary; it uncovered a P1, filed as B-147.
See `meta/BACKLOG-DONE.md`.**

**B-147 is DONE — shipped in v0.59.0 (2026-08-18); see `meta/BACKLOG-DONE.md`.**

### B-148 · Nothing stops someone registering a second `userPromptSubmitted` hook, which Copilot silently drops
**Effort:** S · **Priority:** P2 · filed 2026-08-18 as B-147's deliberate residue · **Invariants:** #5

**Why:** B-147 shipped the fix but not the guard. Copilot CLI delivers only the **last**
`userPromptSubmitted` entry (observed 1.0.79/1.0.80), so a second entry means the first one's
`additionalContext` is discarded — the hook still runs, still exits 0, still emits valid JSON, and
its content simply never reaches the model. That is exactly how this went unnoticed across two minor
versions: `validate-dist` check 8 asserts every registered script **exists**, never that its output
is **consumed**, and no fixture had ever registered two hooks on one event.

The fix removed today's instance. It did nothing about the next one, and the next one looks
identical to a reviewer: adding an entry to an array is the obvious way to add a hook.

**Do:** a `validate-dist` check that fails when `.github/hooks/hooks.json` carries more than one
entry under `userPromptSubmitted`, with a message that says *why* (only the last is delivered;
compose into one hook instead). Red-test by adding a second entry to a scratch dist.

**Scope it to `userPromptSubmitted` only.** A blanket "one entry per Copilot event" rule is wrong and
was rejected during B-147's critique: `postToolUse` legitimately carries **two** (`post-write`,
`audit-trail`), verified, because those are side-effecting hooks whose value is not model-facing
`additionalContext`. The constraint is about **context injection**, not about running hooks. If
another injecting event is added later, extend the list deliberately rather than generalising.

**Not:** don't encode this as a vendor-bug workaround with no expiry. If Copilot ever honours every
entry, the composed single hook keeps working and this check becomes a harmless anachronism — say so
in the message so the next reader knows it is a delivery constraint, not a design preference.

**Cross-links:** B-147 (the defect), B-43 (re-run the canary after any Copilot CLI bump), B-55 (the
correction had to land in several surfaces at once — the same restatement problem).

**Implementation RCA (2026-08-18):** No gate caught this because hook-registration check 8 proves
that a registered command exists, not that a vendor consumes every model-facing output when an event
array has multiple entries. The same class could affect another context-injecting Copilot event if
one is added; extend the explicit event list only after live verification, rather than generalising
to side-effecting events such as `postToolUse` where multiple entries are legitimate.

**B-149 is DONE (2026-08-18) — four gates closed; see `meta/BACKLOG-DONE.md`.**

**B-55 is DONE (2026-08-19) — the superseded-claims denylist shipped meta-only; see
`meta/BACKLOG-DONE.md`.** The canonical-source refactor half of its *Do* was deliberately **not**
built: the proportionality case found that stale duplication, not duplication, is what caused all
four incidents. Revisit only on evidence that the class recurs against *live* claims.

### B-44 · Host-native overlap watch — retirement triggers for framework machinery
**Effort:** S · **Invariants:** #7

**Why:** the hosts are absorbing the framework's territory from below: Claude Code has grown
native memory (overlaps B-27 wiki), native code review (overlaps the `/review` fan-out), plan
mode (overlaps plan-first rails), and first-class skills; Copilot keeps moving too. The
framework's value is the **delta over host-native behavior**, and that delta shrinks every
host release. With no deprecation policy, the framework's fate is to become redundant
scaffolding that costs consumers context (the exact failure B-32 exists to measure) while
duplicating what the host does better.

**Do:** add a table (suggest `meta/overlap-watch.md`, linked from this file): one row per
framework mechanism — the host-native feature that would obsolete it, the detection signal
("host X ships Y / doc Z announces"), and the retirement action (drop it, thin it to
configuration of the native feature, or keep with a written justification). Review the table as
part of every B-43 recertification cycle. First candidates to assess honestly: wiki memory vs
Claude Code auto-memory, `/review` agents vs host-native review, `route-prompt` vs improving
native intent handling, `post-write` build feedback vs host-native diagnostics.

**B-46 is DONE — part 1 (verify + disclose) shipped in v0.56.0 and part 2 (version awareness) in v0.57.0; see `meta/BACKLOG-DONE.md`.**

### B-48 · Enforcement-bypass audit — the guard's known end-runs, decided honestly
**Effort:** M · **Invariants:** #3 #5 · needs a WSD record

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

### B-70 · Nothing requires a new test to be exercised on both CI legs before it ships
**Effort:** S · **Priority:** P2

**Why:** CI deliberately runs the `.ps1` twin on Windows and the `.sh` twin on Linux to catch
cross-platform divergence — that split is the point of the two legs. But a test authored and
verified on the maintainer's Windows box passes local review with the Linux path never executed,
and lands red on master. That is exactly what happened to the v0.38.0 test: `existing absolute
wired shell is OK` resolved its interpreter with `Get-Command -CommandType Application` and read
`.Source`; on Linux the command returned multiple matches, so the fixture wrote three paths
space-separated, while Windows returned one. The following RCA-backlog commit inherited the red
because it did not touch the test. This is the test-authoring counterpart to B-64: B-64 asks that
gates and diagnostics be red-tested for the defect they catch; this asks that new tests be shown to
actually run on every leg that will execute them.

**Do:** add to the Definition of done for a test-carrying change that any new or modified test case
is demonstrated running (not merely passing) on both legs — either by running it under bash
locally, or by treating the first CI run as part of the change rather than as a post-hoc check.
Consider a cheap local proxy: enumerate test cases skipped or not reached on the authoring platform
and print them in the suite summary.

**Not:** do not add a third CI leg; the gap is process, not infrastructure.

**Fifth instance, 2026-08-17 (shipping B-77) — and the first where the *implementer* could not reach
the leg at all.** The `hazard-check` twins were written by codex, whose Windows sandbox has neither a
working `bash` (it dies with `CreateFileMapping ... Win32 error 5`) nor Windows PowerShell 5.1. It
reported both legs as **not observed**, which was honest and correct. Running them found two real
bash-only defects: an unquoted `$candidate` in `for part in $candidate` that let the shell
pathname-expand a wildcard against the cwd, and a separator-row test that silently skipped a row whose
cells were all empty while the `.ps1` twin reported it. Neither is visible from the PowerShell side by
construction. The generalisation this entry keeps accumulating now has a sharper form: **when the
authoring environment cannot execute a leg, that leg has no evidence at all — not weak evidence** —
so the reviewer must run it before the diff is reviewable, not after. Same conclusion as the entry's
existing "not done until its first CI run is green", one step earlier in the pipeline.

**Third and fourth instances, 2026-08-04 (shipping B-92) — this entry is now the most-repeated
failure in the log.** A new meta suite was verified green under *both* PowerShell hosts locally and
still took master red on the linux leg twice:

1. `./scripts/validate-dist.sh` → **Permission denied**. The file is mode 644 in git; Windows ignores
   the exec bit and Linux enforces it. Every other caller in the repo already spelled it
   `bash scripts/validate-dist.sh`.
2. `Get-ChildItem -Recurse` **without `-Force` skips `.claude/` and `.github/` on Linux**, because
   PowerShell treats a leading dot as hidden there and not on Windows. `no-meta-leak` would have
   inspected zero hooks and zero skills on Linux while printing a clean pass.

Both are invisible to any local run on a Windows box, which is precisely this entry's thesis. The
cheap local proxy it proposes would not have caught either — the honest fix is that **a change
carrying a new test is not done until its first CI run is green**, which is now how B-92 was
shipped. Consider promoting that from a suggestion to the Definition of done.

### B-72 · A behavioural probe can be defeated by the guidance it measures, and `angular-form-control` does not reproduce its field report
**Effort:** M · **Priority:** P2 · **Invariants:** #5 · found 2026-07-31 while shipping B-66

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

### B-79 · The maintainer box runs the MSIX build of PowerShell 7, and it is the release's largest single cost
**Effort:** S (environment change, no code) · **Priority:** P3 · found 2026-08-01 profiling the release

**Why:** the release is bound by process creation, not CPU. Measured on the maintainer box:

| spawn | sequential | 8-wide |
|---|---:|---:|
| `pwsh` (MSIX) | **265 ms** | 141 ms |
| `bash` (Git for Windows) | 55 ms | 20 ms |
| `powershell.exe` 5.1 (native Win32) | **143 ms** | — |

PowerShell 7 starting **1.85x slower than Windows PowerShell 5.1** is backwards — 7 is normally the
faster of the two to start. The one install present is the Store/MSIX package
(`C:\Program Files\WindowsApps\Microsoft.PowerShell_7.6.4.0_x64__8wekyb3d8bbwe\pwsh.exe`); there is
no MSI install under `C:\Program Files\PowerShell\7\`. MSIX packages pay per-launch package identity
and app-execution-alias resolution that the MSI build does not.

The hook suites spawn a fresh interpreter per assertion (deliberately — that is what makes each
assertion a real hook invocation with a real exit code), roughly 1350 spawns across the three dists.
At 265 ms a spawn that is most of the ~6-minute gate phase. Parallelism cannot rescue it: measured
throttle sweep on one dist suite was 160.7 s (4 lanes) / 152.6 s (6) / 150.3 s (8) / 151.4 s (12) —
it plateaus, because process creation serialises. Raw spawn throughput only improves ~1.9x from
8-way parallelism.

**Do:** install PowerShell 7 via MSI (`winget install --id Microsoft.PowerShell`, or the .msi from
the PowerShell releases page) so `C:\Program Files\PowerShell\7\pwsh.exe` exists, then re-measure:

```
1..25 | ForEach-Object { & 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -Command "exit 0" }
```

If startup lands near 5.1's 143 ms, that is ~45% off every `pwsh` spawn and the largest available
win on release time — with no code change and no test weakened. Keep both installs and compare
before switching what the hooks register (WSD-026 pins an absolute interpreter path, so that
registration would need updating deliberately, not incidentally).

**Not:** disabling Defender real-time scanning, which also taxes every spawn. Declined by the
maintainer 2026-08-01 as a security decision, not a build tweak. Noted here only so the next person
profiling this does not rediscover it and assume it was missed.

---

**B-75 is DONE — shipped in v0.60.0 (2026-08-18); see `meta/BACKLOG-DONE.md`.**

### B-83 · A backlog entry's *Do* can be contradicted by a later shipped decision, and nothing notices
**Effort:** M · **Priority:** P2 · filed 2026-08-02 (RCA of v0.44.0)

**Sibling defect measured 2026-08-16 — the same rot, in the heading rather than the body.** A full
audit of all 71 claimed-open entries (`meta/backlog-heading-audit-2026-08-16.md`) found **16 whose
work had demonstrably shipped while the heading still read open** — B-61, B-62, B-78, B-80, B-103,
B-104, B-105, B-107, B-110, B-113, B-115, B-116, B-118, B-119, B-120, B-121. Ten of the sixteen
already carried an inline `> **DONE …**` marker *in their own body*, so the entry contradicted its own
heading and nothing noticed. Headings are now corrected. This was found the expensive way: while
picking "the next item to work on", B-80 was selected and turned out to be fully implemented
(`release.ps1` step 5a + `ReleaseStagingGuard.Tests.ps1`, whose header names B-80) — i.e. the backlog
actively misdirected real work. The audit also flagged **13 UNCLEAR** entries (B-50, B-64, B-65,
B-66, B-70, B-72, B-96, B-97, B-98, B-101, B-102, B-112, B-117) where the shipped state only
partially matches the entry's *Do*; those were deliberately NOT auto-closed and each needs a human
read. Whatever mechanism this item lands on should cover heading/body/Done-section agreement, not
just the *Do*-versus-decision drift it was originally filed for.

**Why:** B-62 was filed as a P1 and sat open. Its instruction — "fail on a bare interpreter name in a
shipped settings file" — was *already wrong when read*, because **v0.38.1** had deliberately reverted
absolute-path interpreter pinning, making a bare name the intended shipped value. An implementer
following the entry literally would have written a gate that fails every settings file on purpose,
watched three dists go red, and either weakened the gate until it passed or reverted a correct
shipped decision. It was caught only because a critique pass read v0.38.1's changelog entry.

This is a **staleness class, not a one-off**. Entries are self-contained by design (the file says so
at the top) and are written against the repo as it was on their filing date. Ten versions later the
premise can be false with no signal: no gate reads `BACKLOG.md`, and nothing correlates an entry
against changelog entries that postdate it. The longer an entry waits — and P1s wait longest when
they look expensive — the likelier its premise has rotted.

**Do:** (a) add a dated **"filed against vN"** stamp to every open entry, so the reader knows how much
history to check; (b) require any entry older than ~5 minor versions to be re-validated against the
changelog *before* implementation, and write that into the maintenance model's rule 1 (the critique
pass is the natural home — it is already licensed to reject the premise); (c) sweep the currently
open entries for the same rot. Start with those filed before v0.38.1/v0.39.0, which is where the
interpreter/liveness decisions landed: **B-15, B-17, B-18, B-20, B-26, B-41…B-49** all predate it.

**Not:** do not try to make this a deterministic gate. Whether a decision contradicts an entry is a
reading, not a string match; a check that pretends otherwise is the theatre this repo keeps removing.

**Cross-links:** B-44 (retirement triggers — same "reality moved, the entry did not" shape).

---

**B-84 is DONE (2026-08-18) — `.claude/hooks/tests/_MutationHelper.ps1`; see `meta/BACKLOG-DONE.md`.**

### B-85 · Two gate scripts cannot run from Git Bash on the maintainer box
**Effort:** S · **Priority:** P3 · filed 2026-08-02 (RCA of v0.44.0)

**Why:** `bash scripts/validate-dist.sh <dist>` exits **FATAL at check 4** on this machine —
"neither pwsh nor powershell is available to parse *.ps1 files" — because the session `PATH` is the
corrupted one (a literal unexpanded `${PATH}`), and `pwsh` lives under a `WindowsApps` MSIX path that
Git Bash does not inherit. It works only when the caller manually prepends
`/c/Program Files/WindowsApps/Microsoft.PowerShell_7.6.4.0_x64__8wekyb3d8bbwe`. Same root cause as
the `copilot.cmd` → `'"node"' is not recognized` failure hit in the same session, and as B-71's
`powershell.exe` skip.

The consequence is not "a script is inconvenient": it is that the **bash leg of the twin gates is
effectively unrunnable locally**, so twin parity is verified on CI or not at all, and a local
maintainer will read the FATAL as "this dist is broken" rather than "my PATH is broken". The
`Invoke-BashProbe` vantage-point flaw (B-63) is the same family.

**Do:** have the bash twin, on failing to resolve a PowerShell host, probe the well-known absolute
locations before declaring FATAL — including the `WindowsApps` MSIX path — and, if it still cannot,
say *why* ("no PowerShell host on PATH; this is a host/PATH problem, not a dist problem") rather than
implying the dist failed. Mirror B-71's conclusion: a failure caused by a broken `PATH` is not the
same fact as a host that lacks the tool, and reporting them identically is what lets the gap persist.

**Not:** do not hard-code this box's version-stamped MSIX directory — glob it. And do not silently
skip check 4: an unrunnable check must stay FATAL, only better explained. (B-79 separately proposes
replacing the MSIX build; if that lands, this becomes cheaper but not moot — consumers hit it too.)

---

### B-87 · A commit subject can still be mangled by the shell — B-73's class, outside `release.ps1`
**Effort:** S · **Priority:** P3 · filed 2026-08-02, observed the same day

**Why:** B-73 added a guard against MSYS path conversion corrupting `-Summary`, but it lives inside
`release.ps1` and matches one specific corruption. The class is wider and recurred immediately: the
2026-08-02 docs commit was authored with a PowerShell here-string (`@'…'@`) in a **POSIX sh** shell,
which is not here-string syntax there — so `@` became the subject line and a trailing `@` the last
body line. Caught by eye, after the push, and fixed only by an amend + `--force-with-lease` on
`master` (a public repo). The v0.40.0 subject is permanently corrupted by the sibling defect, so
this is twice that a shell quirk has reached the permanent record through a different door.

**Do:** a `commit-msg` hook (opt-in, maintainer-side — this is *our* repo, not shipped) that rejects
a degenerate subject: shorter than ~10 characters, consisting only of punctuation, or matching the
MSYS-path signature `release.ps1` already knows. That catches both observed instances and does not
depend on remembering which shell you are in. Red-test with a literal `@` subject.

**Not:** don't extend `release.ps1`'s pattern list instead — the release path is exactly the one
that was *already* guarded. The gap is every commit made outside it.

**Cross-links:** B-73 (the in-release guard), B-80 (same script, staged-set integrity — both are
"the commit records something nobody chose").

---

**B-123b is REJECTED ON EVIDENCE (2026-08-18) — the premise is invalid; see `meta/BACKLOG-DONE.md`.**

### B-91 · The release still pushes one commit it never watches
**Effort:** S · **Priority:** P3 · filed 2026-08-02 (RCA of B-88)

**Why:** B-88 made the release wait for CI on the release commit before tagging. The optional agent-eval
block then commits `meta/eval-results.md` and pushes it (`release.ps1`, step 6), **after** the watch —
so `origin/master` ends the run at a commit whose CI nobody observed. v0.44.0's red streak included
exactly this shape: follow-up commits inheriting a break.

It is now *disclosed* — the release prints that master advanced past the watched commit and gives the
one-line command to watch it — which was the honest half of a trade: watching inline would add another
multi-minute wait to an interactive prompt, for a meta-only commit.

**Do:** decide between (a) watching it too and accepting the wait, (b) moving eval-result persistence
out of the release entirely, or (c) leaving the disclosure as the answer and recording that as the
decision. Cheap either way; the point is that the current state is a deliberate gap, not an oversight,
and should be written down as one.

---

### B-94 · The staged-set guard's record overclaims what it does, in three places
**Effort:** S · **Priority:** P3 · filed 2026-08-03 by the B-86 post-ship review

**Why:** the guard (B-80, `release.ps1` step 5a) works and its refusals are correct. But three
statements about it are stronger than its behaviour, all confirmed by execution:

1. **"no longer commits whatever is in the tree" (`CHANGELOG.md`) is broader than the check.** The
   allowlist asks whether a path sits under one of six directories or is one of ten root files, so
   `src/release-notes.tmp`, `meta/review.txt`, `.claude/debug.log` and `dist/scratch.bak` are all
   classified as expected and committed without a warning; only a *top-level* stray is refused.
   The check's own comment is honest about this ("is this file somewhere this repo keeps files at
   all?"); the changelog sentence is not. Mitigating, and worth keeping in view: the staged manifest
   prints unconditionally (`release.ps1:402-406`), so an in-directory stray is **visible** even
   though it is not refused. That is why this is P3 and not a defect in the guard.
2. **"the index is left as found" is false; it is left empty.** On refusal the guard runs an
   unconditional `git reset --quiet`, which also discards staging the maintainer did *before*
   invoking the release. Measured: `BEFORE=src/a.txt` → `AFTER=` (worktree content preserved). The
   claim appears in `release.ps1`'s step-5a comment, in `CHANGELOG.md`, and in B-80's Done entry.
   The test **codifies the weaker property under the stronger name**: the case is called
   *"a stray untracked file is refused, and the index is left as found"* while its assertion is
   `IsNullOrWhiteSpace($idx)` — index *empty* — and the fixture starts with an empty index, so it
   cannot tell the two apart. A fixture that stages something first would.
3. **A git-quoted path is misclassified as unexpected and refuses a legitimate release.** With
   `core.quotepath` at its **default** (the review's one correction to the finding as first written —
   this needs no unusual configuration), a non-ASCII path is emitted by `git diff --cached --raw` as
   `"meta/caf\303\251.txt"`, quotes included. The leading `"` defeats the `^meta/` allowlist, so
   step 5a refuses. Latent today — zero tracked paths contain non-ASCII bytes, and a space alone is
   **not** quoted (measured) — but the failure mode is a correct release refused, which is the shape
   that trains a maintainer to pass `-AllowExtraStagedPaths` reflexively.

**Do:** correct (1) and (2) in the record rather than the code — the behaviours are defensible, the
sentences are not — and add the pre-staged fixture so (2)'s test asserts what its name says. For (3),
unquote the path before classifying (`git -c core.quotepath=false diff --cached --raw` is the cheap
form), and red-test with a non-ASCII path.

**Not:** don't widen the allowlist to file-level rules for (1). "Is this file part of a release?" was
already judged unanswerable, and the first cut written that way would have refused every release
from v0.39.0 to v0.43.0.

**Live instance of (1), 2026-08-06 during the v0.47.0 release — and it adds a wrinkle worth having.**
A design document (`.claude/plans/2026-08-06-b98-step2-routing-remedy-design.md`) was authored *while
the release gates were running*, in the same working tree. `git add -A` swept it into the release
commit: `46 files changed` including `create mode 100644 .claude/plans/…`. Step 5a did not refuse,
correctly per its own rules — `.claude/` is one of the six allowed directories, so this is an
in-directory stray, exactly the case this entry says is committed without a warning.

**The wrinkle:** the file was **mid-edit**. The release captured a draft that was superseded minutes
later by amendments from its adversarial critique, so the committed artifact is a *stale version of a
document that was actively changing*, and the amendments then had to land in a follow-up commit. That
is worse than the "stray scratch file" this entry anticipates: a stray is merely noise, whereas this
is a real artifact captured at a misleading point in its life, with nothing in the release output
indicating it was unfinished. The staged manifest *did* print it (`release.ps1:402-406`), which is
the mitigation this entry credits — but a filename in a 46-line manifest does not distinguish
"deliberately part of this release" from "happened to be open in the editor".

**What this suggests for the fix,** beyond what is already written: the useful signal is not only
*where* a staged path sits but *whether it was modified during the release run itself*. The release
knows its own start time; a file whose mtime falls inside the run and which is not one of the paths
the release deliberately rewrites (stamps, `dist/`, the footprint baseline) is a strong candidate for
"the maintainer was working on this, it is probably not part of the release". Cheap to compute, and
it catches the concurrent-authoring case that directory allowlisting structurally cannot.

**Not (addition):** do not respond to this by forbidding work during a release. The gates take ~25
minutes; expecting an idle maintainer is the kind of process rule that gets ignored and then relied
upon.

---

### B-96 · `map-warehouse` maps the ETL, not the warehouse
**Effort:** M · **Priority:** P2 · found 2026-08-04 (maintainer field report) · **Design:** `.claude/plans/2026-08-05-b96-warehouse-schema-map-design.md` (LOCKED)

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

### B-98 · A prompt that matches no skill description fails silently
**Effort:** S (step 1) · M (the general question) · **Priority:** P2 · found 2026-08-05

> **v0.51.0 decision:** no always-on router or no-match hook. Stage A selected
> `add-warehouse-load` 6/6 and selected `add-entity` 0/4 counted runs, while the earlier read-side
> case remained 0/6. Routing remains probabilistic; dead destinations are hygiene defects, not a
> behavior proof. Future body boundaries require an observed overlapping-fixture misroute.

**Why:** routing is the model matching a prompt against skill descriptions. When nothing matches,
the framework emits **nothing** — no warning, no degraded path, no "I have no recipe for this". The
developer receives a plausible answer produced with no framework guidance, and cannot tell that from
one produced with it. Silence is indistinguishable from success, which is the worst shape a failure
can take: there is no signal to act on, so the gap never surfaces except as a bad outcome downstream.

The trigger is B-96's field report, and it is genuinely unresolved. `map-warehouse`'s USE FOR already
includes "what feeds this report"
(`src/stacks/dotnet/files/.claude/skills/map-warehouse/SKILL.md:10`), so the skill was **eligible** to
fire — but no transcript exists, so nobody knows whether it did. Both outcomes are findings, and they
have different owners:

- **It fired** → the map had nothing useful to say. Content gap; B-96 owns it.
- **It did not fire** → B-96's content work never reaches the developer regardless of quality, and the
  remedy is routing, not content.

This is the same shape as **B-97**: a general framework defect that surfaced through a
warehouse-specific symptom. B-97 earned its own entry on those grounds and so does this.

> **Second live confirmation, 2026-08-15 (B-127 Phase 0, WSD-040).** All 16 baseline trials (8
> plain, non-telegraphing, no-skill-named prompts × n=2) against unchanged `map-warehouse` came back
> `ROUTING_NON_REACH` — the skill was never read or selected once. Claude Code solved every sampled
> case correctly anyway via direct DDL/view inspection, at a fixture scale where that brute-force
> path is cheap. This is "it did not fire," settling that outcome a second time independent of B-96's
> original trigger. Full detail: `meta/eval-results.md` "B-127 Phase 0" sections.

> **Third confirmation, and a more diagnostic one, 2026-08-15 (B-126 retroactive correction).**
> B-126's own live baseline (WSD-041, closed 2026-08-14) never gated its grader on skill invocation;
> retroactively checking its recorded `skill=` field shows `add-warehouse-load` fired in only 1 of 6
> counted trials. The diagnostic value here is the **contrast**, not just another non-fire: B-124's
> near-identically write-task-phrased prompts routed 4/4, on the same skill, in the same fixture
> family. The plausible difference is that B-126's fixture stages `docs/schema-evolution-premise.md`
> and `docs/product-consumer-closure.md` directly and prominently — an equally-relevant non-skill path
> that B-124's fixture didn't offer. If true, routing reliability here isn't just a function of prompt
> phrasing (this item's original framing) but of what evidence already happens to be staged in
> context — worth checking directly (does a fixture with an on-point doc file suppress routing to a
> skill that would otherwise fire?) before this item's own "Do" step 2 design work begins. Full
> detail: `meta/BACKLOG.md` B-126 "Correction (2026-08-15)".

**Do:**

1. **Settle the warehouse instance — cheapest, and it gates B-96.** Run an incident-shaped prompt
   ("replicate this report, here is the source SQL") against a warehouse fixture with the current dist
   installed, and observe whether `map-warehouse` fires and whether `docs/warehouse-map.md` enters
   context. Reuse the B-41 harness; do not build a second one.
2. **Then the general question: is silence acceptable when no skill matches?** Weigh — a `route-prompt`
   fallback that names the nearest skills and states that none matched; accepting silence but auditing
   whether descriptions carry **read/consumption** verbs at all (most real tasks are reads; most skill
   descriptions are framed around writes — that asymmetry is what produced the warehouse gap); or a
   periodic description-coverage audit against a corpus of realistic prompts. Note the fallback option
   costs context on every turn, so it is not obviously right.
3. **Sweep the class — write-side-only capabilities.** `add-endpoint` and `add-entity` cover
   *authoring*; is *consuming* an existing endpoint or entity correctly covered anywhere? B-40 shipped
   `map-warehouse` + `add-warehouse-load` and nothing for querying. Check whether the same asymmetry
   runs through the rest of the skill roster.

> **STEP 3 DONE — RUN 2026-08-06, immediately after step 1. The asymmetry is real and worse than
> this bullet assumed.** Swept all 16 shipped skills (`dist/monorepo`, the superset) and all 14
> commands.
>
> **Every skill is named and framed by the artifact it *produces*, never by the question it
> answers.** Nine of sixteen begin with `add-`; six of those say "new"/"brand-new"/"doesn't exist
> yet" in the first clause. Only **two** are read-side at all — `perf` (a defect-hunting scan) and
> `map-warehouse`. And `map-warehouse` is itself framed as *producing a document*: its headline is
> "Map a warehouse codebase … refreshing `docs/warehouse-map.md`". A developer with a question does
> not have a map-authoring task.
>
> **This is a better explanation of step 1's `r=0` than description tuning.** The three probe prompts
> are all shaped *"Write that query and save it as `analysis/X.sql`"* — surface form: author a file.
> No skill in the roster claims query authoring. Stated precisely, because the overclaim is
> tempting: the two warehouse skills do **not** forbid it — they mention queries only to exclude
> *tuning* (`add-warehouse-load` → "report/query tuning"; `map-warehouse` → "tuning a single slow
> query"). So the task is **unclaimed, and the only query-adjacent language in reach is exclusionary**.
> That is a routing gap by omission, not by misdescription — which is why rewriting
> `map-warehouse`'s description (design §3.5) was never going to be sufficient, and step 1's
> §3.4.1 sharpening already said so from the other direction.
>
> **Orphaned exclusions — the sharper structural defect.** `DO NOT USE FOR` clauses name ~17 tasks.
> Five route somewhere real (`add-warehouse-load`→`add-entity`/`map-warehouse`,
> `add-tests`→`add-endpoint`, `enforce-standards`→`enforce-architecture`,
> `enforce-architecture`→`/review`). The rest name a task and offer **no destination, because none
> exists**: *writing queries against an existing entity* (`add-entity`), *modifying an existing
> endpoint's logic or signature*, *adding a method to an existing service*, *adding middleware*
> (`add-endpoint`), *changing a registration's lifetime*, *adding a dependency to an existing
> service constructor*, *extracting an interface from a registered class*, *replacing one
> implementation with another* (`register-service`), *one-off data corrections*, *report/query
> tuning* (`add-warehouse-load`), *tuning a single slow query* (`map-warehouse`). The roster tells
> the model where **not** to go far more often than where to go, and most of those signposts point
> at nothing.
>
> **Incidental find, worth its own fix:** four skills carry **no `USE FOR`/`DO NOT USE FOR` clause
> at all** — `add-component`, `add-lazy-route`, `add-service`, `add-signal-store`, i.e. every
> Angular authoring skill except `add-tests`. They ship a single descriptive sentence while their
> .NET counterparts carry full routing clauses. Whatever step 2 decides about routing, this is an
> unarguable inconsistency in the delivered product and cheap to close.
>
> **What this does NOT establish:** that adding a read-side skill fixes `r=0`. `map-warehouse` is
> read-side and still did not fire, so "add a consumption skill" is a hypothesis, not a conclusion —
> it needs the same pre-registered treatment step 1 got, on the same harness, before anything ships.
> Commands were checked too and cover none of this: all 14 are lifecycle/workflow
> (`/feature`, `/fix`, `/refactor`, `/design`, `/review`…), and none claims "answer a question about
> existing code" either.

**Cross-links:** B-96 (gated by step 1), B-41 (the eval harness steps 1–2 depend on), B-97 (the other
general defect found through the same symptom), B-76 (shipped descriptions matching what they
describe — accuracy, where this is coverage), B-78 (warehouse-map signals that reach nobody).

> **STEP 1 IS DONE — RUN 2026-08-06. `r = 0` of 6. Routing gap CONFIRMED; B-96 is BLOCKED; step 2
> owns the remedy.** Six registered runs on `-Model sonnet` (three paraphrases × two batches),
> framework v0.46.0, Claude Code 2.1.223, all six `category=NEITHER` — `Skill` never invoked,
> `docs/warehouse-map.md` never opened. Full record and caveats: `meta/eval-results.md`
> (2026-08-06 blocks). The pre-registered rule fired as written; nothing was tuned to the outcome.
>
> Four things this establishes, and one it does not:
> 1. **Fixture valid** — verified on disk in the retained scratch (12 skills incl. `map-warehouse`,
>    the map file, population-A `CLAUDE.md`), not inferred.
> 2. **The negative is the sharp form (§3.4.1).** `map-warehouse` is named at `CLAUDE.md:71` in
>    always-loaded Common Tasks and its USE FOR already covers "what feeds this report". So the gap
>    is **a named, in-context skill was not reached**, not an unmatched description — which means
>    step 2 must not assume description tuning is the fix, and a later positive must not be credited
>    to it.
> 3. **The model brute-forces instead.** p1 tool census: 12 `Read`, 7 `Glob`, 0 `Skill`. It
>    re-derived the map from raw DDL. That path exists on a 9-table fixture and not on the warehouse
>    behind the field reports — so the probe understates the cost of the gap rather than overstating
>    it.
> 4. **Co-observed:** `usedDeadColumn=True` in 4/6 (field report #3's shape) with
>    `joinedDimension=True` in 6/6. Kept as a signal, **not** banked as evidence — p2/p3 flipped
>    between batches (high variance at n=2/paraphrase) and B-72 has caught this scenario family
>    telegraphing before.
>
> **What it does not establish:** that the *content* fix is wrong or unnecessary. B-96's content gap
> was established structurally by reading the skill; this says only that the content would not have
> been reached. Fix routing first, then ship the content — that ordering is now evidenced rather
> than assumed. Cost: $2.23 for six runs.
>
> **Also confirmed while running this (Phase 1 premise re-validation, and it corrects B-96 §3.6):**
> `.claude/skills/` is **not** in the installer's `$protected` list (`dist/dotnet/scripts/install.ps1:30-31`)
> and is copied wholesale on update (`:83-85`). So B-96's *skill* content — the whole map, the edge
> list, the read-side rules — **does** reach already-installed consumers. Only the one-line
> `Conventions > Data Access` pointer is behind B-97's wall. §3.6's "reaches greenfield installs
> only" is true of that line and must not be read as true of the item. The v0.45.0
> `.github/instructions/` carrier is **not** the rescue for it either: that file is genuinely
> unprotected and does deliver, but it is framework-owned and unconditional (`applyTo: "**"`) while
> the pointer is conditional on the repo having a warehouse — and B-96's own "Not" forbids
> DW-specific text in static context.

**Step 1 status, 2026-08-05 — instrument BUILT and verified; the six live runs are PENDING.**
Design: `.claude/plans/2026-08-05-b98-step1-routing-probe-design.md` (rev 2, adversarially reviewed,
12 findings dispositioned). Phase 1 shipped in commit `abaa7a2` (meta-only): warehouse fixture,
`warehouseRouting` grader, three prompt paraphrases, 19 self-test assertions green on pwsh 7.6.4 and
red-tested by breaking the Conventions replacement regex, the shipped step-0 table, and the shipped
`CLAUDE.md` pointer count.

**Deferred to 2026-08-06+ for weekly usage quota (96% consumed), not for cost.** Run all six as
designed — do not silently shrink n, and do not substitute a non-Claude host: verified 2026-08-05
that codex/terra has **no skill mechanism at all** and emits an unrelated event schema
(`thread.started`/`turn.started`/`item.completed`/`agent_message`/`turn.completed`), so `Skill`
routing cannot fire and `Read-Transcript` rejects the stream. A terra run would score `NEITHER` six
times for host reasons and the decision rule would misread that as a confirmed routing gap.

Command: `pwsh -NoProfile -File .claude/evals/run-agent-evals.ps1 -Live -Scenario warehouse-route-p1,warehouse-route-p2,warehouse-route-p3 -TimeoutSeconds 420`, twice.

**Haiku pilot — PRE-REGISTERED 2026-08-05, before running, and it does NOT satisfy step 1.**
Weekly quota is effectively spent, so the six registered runs cannot happen today. A cheaper model is
worth attempting, but only under a rule fixed in advance, because the registered rule below names no
model and the harness defaults to `sonnet` (`run-agent-evals.ps1:9`) — swapping the model silently
would corrupt the one property that rule exists to protect.

- **The pilot is `-Model haiku` on `warehouse-route-p1..p3`. It is a pilot, not the experiment.**
- **Positive (guidance demonstrably enters context in ≥5 of 6):** provisional evidence that routing
  works, since a weaker model succeeding makes success on a stronger one likely. **Provisional only**
  — it still requires one `sonnet` confirmation run before B-96 is unblocked.
- **Negative (r low or zero): UNINTERPRETABLE. Discard it. Do not record it as `r`, and do not let
  it confirm a routing gap.** It cannot distinguish "no framework guidance reached the model" from
  "this model is weaker at tool selection" — the identical confound that already ruled out a terra
  substitution below.
- **Known weakness in the transfer assumption, stated up front:** it presumes routing capability is
  monotonic in model strength. Plausible, unproven, and arguably backwards — a stronger model may
  answer directly where a weaker one reaches for a tool. This is why even a positive is provisional.

**Haiku pilot RESULT, 2026-08-05: 3 runs, all negative — and DISCARDED per the rule above.**
`-Model haiku` on p1/p2/p3. All three: `Skill` tool never used, `docs/warehouse-map.md` never opened,
`category=NEITHER`. The string `map-warehouse` appears in every transcript only because
`CLAUDE.md > Common Tasks` names it — i.e. the skill was **visible in always-loaded context and not
invoked**.

**This does not count as `r=0` and must not be cited as a confirmed routing gap.** The pre-registration
said a negative here cannot separate a routing gap from a weaker model's tool selection, and that
still holds now that the negative is in hand. The registered `sonnet` runs remain owed. Recording the
constraint costs a result I would otherwise like to claim, which is the point of registering it first.

Three things it *does* establish, none model-dependent:

1. **Fixture validity — this is not the terra-style host confound.** Verified on disk in the retained
   scratch: `target/` carries a 24 KB `CLAUDE.md`, all 12 skills including `map-warehouse`, and
   `docs/warehouse-map.md`. The probe put the framework in front of the model correctly. (`tokensIn=42`
   in the PASS line is a token-accounting artifact, not empty context — checked, not assumed.)
2. **The probe has now been exercised live for the first time** and works end to end: spawn, grade,
   categorise. It was previously "BUILT and verified" with no live run behind it.
3. **Cost envelope:** ~$0.056 per run on haiku against a $1.25 budget. The six registered runs are
   affordable; cost was never the reason to defer them.

**Finding filed against the probe itself: `PASS` is a misleading label here.** The harness printed
`PASS warehouse-route-p3: … category=NEITHER` — `PASS` means "the run completed and was graded", not
"routing worked". In an instrument whose entire job is to settle a binary routing question, a line
reading `PASS … NEITHER` invites exactly the misreading the pre-registered rule exists to prevent.
Rename to `GRADED`/`DONE`, or print the category first. Cheap, and it is the same failure family as
B-74/B-75 — a report whose shape suggests success.

**Also found: the recorded run command cannot execute on the maintainer box as written.** `claude` is
not resolvable — the session `PATH` holds three entries, the third being the literal unexpanded string
`${PATH}`; the binary is at `<home>\.local\bin\claude.exe`. The harness fails fast and
clearly (`claude CLI is not installed or not on PATH`), which is good instrument behaviour, but the
runs were parked believing quota was the only obstacle and it was not the first one hit. Prepend that
directory to `PATH` for the child process; do **not** "fix" the registry, which is a known false fix.

**Absolute paths for every agent host on this box** (all three are invisible to a bare name because
of the `${PATH}` corruption — record them here so no future session re-derives them):

| Tool | Path | Note |
|---|---|---|
| Claude Code | `<home>\.local\bin\claude.exe` | |
| Copilot CLI | `<home>\AppData\Roaming\npm\copilot.cmd` | **needs `C:\Program Files\nodejs` on `PATH` too** — the npm shim shells out to `node`, and its failure is the misleading `'"node"' is not recognized`, which looks like a broken Copilot install rather than a PATH problem |
| GitHub CLI | `C:\Program Files\GitHub CLI\gh.exe` | |
| pwsh 7.6.4 | `C:\Program Files\WindowsApps\Microsoft.PowerShell_7.6.4.0_x64__8wekyb3d8bbwe\pwsh.exe` | MSIX build, cf. B-79 |

This is worth a line in `DEVELOPING.md` rather than only here — three separate host lookups were
needed in one session, and each failed with a different and misleading error.

**The decision rule is PRE-REGISTERED and binding** (design §2.1) — it was written before any run
precisely so it cannot be tuned to the outcome. Let `r` = runs where framework warehouse guidance
demonstrably entered context: `r=0` → routing gap confirmed, **B-96 blocked**, step 2 owns the
remedy; `1≤r≤4` → routing real but unreliable, B-96 proceeds with a stated reliability ceiling;
`r≥5` → routing works, **B-96 unblocked**, the gap is content.

**Design correction found during implementation (§3.4.1), and it changes what a negative means.**
`dist/dotnet/CLAUDE.md:132` names `map-warehouse` in **Common Tasks** — always-loaded context that
`/bootstrap` never rewrites, because it replaces *Conventions*, not the skills list. So a consumer
with "no pointer at all" **cannot exist**, and the design's population table varies only in the
Conventions section. This sharpens a negative result: if a skill that is named and described in
static context on every turn, whose USE FOR already covers "what feeds this report", still does not
fire, the gap is not "the description was not matched" but "a named, in-context skill was not
reached". A positive result is correspondingly attributable to the skills list rather than to
description tuning, and must not be cited as evidence the description is well-written.

---

### B-99 · Nothing tells the model not to re-do a resolution an earlier stage already performed
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

### B-100 · A file created by a shell command passes no hook — the guard is not a floor
**Effort:** M · **Priority:** P2 · found 2026-08-05 (RCA on three red CI runs) · **Invariants:** #4 #5

> **AND AGAIN, SAME RELEASE, DIFFERENT GATE.** The second v0.57.0 attempt was refused by
> `RepositoryPrivacy.Tests`: the implementer's own report carried a concrete
> `C:\Users\<name>\AppData\Local\Temp\...` fixture path into `.claude/plans/`, which is
> committed and public (B-122's class). Two refusals, two different gates, one delivery — and
> **both gates that caught it are whole-tree sweeps that never ask how the file arrived**, while
> every hook-based check saw nothing. That is the argument for sweeps over hooks, stated in
> evidence rather than in principle. Cost so far: two refused releases in one delivery.

> **RECURRED 2026-08-17, caught by the BOM gate.** Shipping B-46 part 2, the implementer created
> `src/core/tests/hooks/SessionStartVersionAwareness.Tests.ps1` through its own sandbox rather than
> through a tool call, so `bom-fix` (a PostToolUse hook on Write/Edit) never saw it and the file
> shipped BOM-less into all three dists. `release.ps1` refused the release; nothing was committed.
> This is the second recorded instance of the class and it now has a measured cost: one refused
> release. **What worked:** the repo-wide BOM sweep is a genuine floor precisely because it does not
> depend on how the file arrived. **What still does not:** any hook-based check remains unreachable
> for shell- and sandbox-authored files, which is exactly this entry's thesis. Note the delivery
> model has changed since this entry was filed — an external implementer now writes most files
> without passing a single tool call, so the exposure is larger than "a file created by a shell
> command", not smaller.

**The incident.** `.claude/scripts/canary-import-resolution.ps1` was committed without a UTF-8 BOM,
breaking meta-invariant #4 and reddening CI for **five consecutive pushes** before anyone looked —
runs `30992016878`, `30992071114`, `30992915143`, `30993263252`, `30993847982`. (Recorded as "three"
when first filed; two more were still in flight at the time and also went red. Corrected here rather
than left, because the count is the measure of how long the signal went unread.)
One line, one file, caught only by the repo-wide BOM gate in the meta suite:
`[FAIL] every .ps1 in the repo carries a UTF-8 BOM (invariant #4) -- BOM missing in:
.claude\scripts\canary-import-resolution.ps1`.

**Why no gate caught it before the push — two independent failures:**

1. **The `bom-fix` hook never had a chance.** It is a PostToolUse hook on Write/Edit. That file was
   created in the repo with `Copy-Item` from a scratchpad — a **shell** copy, which fires no tool
   hook at all. Every other `.ps1` added the same day went through `Write`, was auto-fixed, and
   passed. The auto-fixer worked perfectly and was simply never invoked.
2. **Targeted verification gave false confidence.** A BOM check *was* run that day and reported
   `BOM present: OK` — on `build-block-manifest.ps1`, the file created via `Write`. Checking the
   file that went through the hook proves nothing about the file that bypassed it. The meta suite,
   which checks the whole repo, was not run before pushing.

**What else is exposed to the same class — this is the part worth acting on.** The defect is not
about BOMs. **Every hook-based enforcement in this repo is bypassed by a file that arrives without a
Write/Edit tool call.** That includes:

- **The `guard` hook** — PreToolUse on Write/Edit, the deterministic block on secrets, test-defeats
  and suppressions. A file produced by `Copy-Item`, by `Set-Content` inside a Bash/PowerShell call,
  by `git checkout`, or by an external tool never passes it. The guard is documented as a floor
  (`docs/enforcement-surfaces.md`); for shell-created content it is **not a floor at all**.
- **Implementer rounds specifically.** codex/terra writes files directly to disk. So every
  externally-implemented change bypasses the guard entirely. The working model already compensates
  ("Claude alone reviews diffs"), but that is a *human* control standing in for a deterministic one,
  and nothing in the record says so.

**Do:** decide where the second line of defence belongs, given the hook cannot be it. Candidates:
fold a BOM + guard-pattern scan into the **staged set** at commit time (B-80's guard already
inspects the staged set — the cheapest place to add this); extend **B-18**'s opt-in git-hook net,
which is the same idea already scoped; or accept it and make "run the meta suite before pushing" an
explicit step in `DEVELOPING.md` rather than tribal habit. The first is enforcement, the third is
process — do not pretend the third is the second.

**Cross-links:** B-80 (staged-set guard — the natural host), B-18 (opt-in git hooks), B-48
(enforcement-bypass audit — **this is a concrete, demonstrated entry for that list**), B-88 (nothing
tells you a release broke CI; three runs went red here before it was raised by the maintainer, not by
tooling).

**B-101 is DONE (2026-08-18) — measured, fixed and re-red-tested 2026-08-06; the remaining
per-assertion-spawn class is tracked as B-138. See `meta/BACKLOG-DONE.md`.**

**B-102 is DONE — the core fix shipped in v0.45.0 and its three unshipped residues became B-104, B-105 and B-106, all since delivered; see `meta/BACKLOG-DONE.md`.**

### B-111 · Post-ship review owed for v0.47.0
**Effort:** S · **Priority:** P2 · filed automatically by `release.ps1` on 2026-08-06

**Why:** v0.47.0 shipped with `-NoIndependentReview`, so no second session re-ran a gate or a
red-test against it. Maintenance model #2 requires the review to be filed rather than assumed when
it did not happen. Summary of what shipped: Angular authoring skills gained the routing clauses every other skill already had

**Do:** review the v0.47.0 diff as an independent session -- re-run at least one gate and one
red-test yourself, do not read the release output as evidence -- and file whatever it finds. Then
close this entry, recording what was re-run.

---
### B-112 · RCA: every behavioural instrument's first version could not produce the result it claimed to test for
**Effort:** S (the rule) · M (the sweep) · **Priority:** P2 · filed 2026-08-06 · **Invariants:** #5
· generalises B-72; sibling of B-64/B-74/B-75 on the deterministic side

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

### B-123 · Post-ship review owed for v0.48.0
**Effort:** S · **Priority:** P2 · filed automatically by `release.ps1` on 2026-08-06

**Why:** v0.48.0 shipped with `-NoIndependentReview`, so no second session re-ran a gate or a
red-test against it. Maintenance model #2 requires the review to be filed rather than assumed when
it did not happen. Summary of what shipped: Verification Rule 11: read the repo's own description of a subsystem before writing against it (r=6/6, measured pre-ship)

**Do:** review the v0.48.0 diff as an independent session -- re-run at least one gate and one
red-test yourself, do not read the release output as evidence -- and file whatever it finds. Then
close this entry, recording what was re-run.

---
### B-117 · Every `DO NOT USE FOR` cross-reference rides the channel measured at 0/6, and no fixture tests one
**Effort:** M · **Priority:** P2 · found 2026-08-07 · **Cross-link:** B-98, B-60

> **PAIR CLOSED in v0.51.0.** The mixed fixture observed `add-warehouse-load` and never
> `add-entity`; no frontmatter was added. The wider class remains evidence-gated under B-98.

**Why:** sibling skills disambiguate each other exclusively in **frontmatter** — `add-entity` says
*"DO NOT USE FOR … warehouse fact/dimension tables (use `add-warehouse-load`)"* and
`add-warehouse-load` says *"DO NOT USE FOR: OLTP entities (use `add-entity`)"*. Frontmatter is the
channel v0.48.0/v0.49.0 measured firing **0/6**. So the disambiguation is *asserted* and has never
been *observed* to work.

Worse, it could not have been: until 2026-08-07 **no fixture placed two plausible competitors in one
repo.** The warehouse fixture has no EF Core, so `add-entity` was never a candidate there; the dotnet
fixture has no warehouse. A skill roster's most likely failure — the wrong one firing — was
structurally unobservable across the whole eval suite.

The `warehouse-mixed` fixture and the `reachedAddEntity` outcome close this for **one pair**. The
class is wider: every `DO NOT USE FOR` in the roster is in the same position.

**Do:** once Stage A's baseline reports `reachedAddEntity`, decide whether mis-routing is real at
rates worth fixing. If it is, the remedy is *not* more frontmatter — the budget is 116 chars and the
channel does not fire. Sweep the roster for pairs whose triggers overlap on a plausible prompt, and
carry the boundary in skill **bodies**, which are free and are read once the skill is open.

---
### B-129 · Design and review the warehouse reporting consumption layer
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
### B-132 · Agent-eval runner's PowerShell 7 boundary is implicit, inviting invalid 5.1 verification
**Effort:** S–M · **Priority:** P3 · filed 2026-08-09 from B-124 RCA · **Scope:** maintainer layer

**Why:** the B-124 verification attempted the eval self-test under hostile code page 437 on both
PowerShell hosts. PowerShell 7 passed; Windows PowerShell 5.1 stopped at the first
`-Encoding utf8NoBOM` because that value is unavailable in Windows PowerShell 5.1. The incompatibility predates
B-124: there are **200** `utf8NoBOM` call sites in the runner at the 2026-08-11 HEAD, not the stale
94 originally recorded here. More importantly, this is not an accidental caller mismatch:
`AgentEvals.Tests.ps1`, `release.ps1`, and both documented maintainer commands deliberately launch
the runner with `pwsh`. Root verification policy asks that **at least one** relevant suite be run
under both hosts and a hostile code page; it does not require every maintainer tool to support 5.1.

**Current guidance and observed baseline (researched 2026-08-11):** Microsoft documents that
Windows PowerShell 5.1's `-Encoding UTF8` always emits a BOM, while PowerShell 6+ defaults to
BOMless UTF-8 and exposes `utf8NoBOM`; therefore substituting `UTF8` is not byte-equivalent. (The
value exists in PowerShell 6+, while this repository's explicit `pwsh` maintainer baseline is 7+.) It also
describes Desktop and Core as different runtime editions and says the only true compatibility proof
is tests on every claimed version/edition; PSScriptAnalyzer's syntax, command, cmdlet, and type rules
are useful screening, not that proof. `#Requires -Version` is the native fail-fast declaration for a
script's minimum host. Sources: [about Character Encoding](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_character_encoding?view=powershell-7.5),
[about PowerShell Editions](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_powershell_editions?view=powershell-7.5),
[Using PSScriptAnalyzer](https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/using-scriptanalyzer?view=ps-modules),
[UseCompatibleSyntax](https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/rules/usecompatiblesyntax?view=ps-modules),
and [about Requires](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_requires?view=powershell-7.5).
The direct Windows PowerShell 5.1 `-SelfTest` was also observed red at the first `Set-Content
-Encoding utf8NoBOM` with exit 1; the ordinary `pwsh` invocation is already the release path.

**Approaches considered:**

1. **Make the whole runner dual-edition.** Introduce a narrowly specified `Write-Utf8NoBom` /
   append helper backed by `.NET` UTF-8 encoding without a BOM, migrate the 200 writes by operation
   shape, run all four PSScriptAnalyzer compatibility rules configured for a pinned 5.1 version /
   platform target, then prove
   every self-test under Desktop 5.1 and Core 7 with hostile and normal code pages. Rejected for now:
   it is not a safe enum substitution; `Set-Content`, `Add-Content`, arrays, newlines, and overwrite /
   append semantics all need preservation, compatibility rules cannot prove behavior, and no user or
   release path needs the older host.
2. **Declare the existing PowerShell 7 boundary and repair verification routing — selected.** Add
   `#Requires -Version 7.0` to the runner, retain explicit `pwsh` calls, and state the boundary beside
   the self-test/live commands in `DEVELOPING.md`. Do not change the accurate generic hook-test host
   fallback or root cross-host policy. Use `.claude/hooks/tests/ReleaseCiWatch.Tests.ps1 -SelfTest`
   for the representative dual-host/hostile-code-page leg: on 2026-08-11 it directly exercised its
   subject under Desktop 5.1.26100.8875 and Core 7.6.4 at code page 437, reporting 21 passed, 0 failed,
   0 skipped on each host, and its four planted mutations prove red reachability. Do not launch a
   test under 5.1 if it merely shells back out to `pwsh`.
3. **Split a 5.1-compatible grader core from the PS7 fixture/live driver.** This could preserve some
   cross-host value while keeping BOMless fixture generation in PS7, but creates a second invocation
   contract and proves only the extracted portion. Keep it as a later option only if a real consumer
   or defect shows value not covered by approach 2 and the representative cross-host suite.

**Implementation plan (after the review gate):**

1. Freeze `ReleaseCiWatch.Tests.ps1 -SelfTest` as the representative cross-host suite. Retain its
   current direct-subject behavior and planted red probes; rerun it under Desktop 5.1 and Core 7 at
   code page 437 for the implementing delivery rather than treating this design-time run as future
   acceptance evidence.
2. Add the minimum-version declaration to `run-agent-evals.ps1`. Extend the canonical
   `AgentEvals.Tests.ps1` recurrence wrapper with a Windows-only direct 5.1 probe that distinguishes
   the fix from the current failure: require the version-prerequisite error identity/text and reject
   today's `CannotConvertArgumentNoMessage` encoding failure. Make `release.ps1` invoke this wrapper,
   not the runner directly, so the boundary oracle is release-reachable; retain an explicit `pwsh`
   outer host. Direct PS7 `-SelfTest` must remain green. Because the selected change does not touch
   fixture writers and no fixture-byte oracle currently exists, verify that the diff changes none of
   the 200 encoding operations; do not claim the self-test proves BOMless fixture bytes.
3. Update `DEVELOPING.md` and the canonical verification wording only as needed to distinguish the
   PS7-only agent-eval harness from the repository-level representative dual-host obligation. Verify
   references with `rg`, run the normal self-test/release recurrence path, and record the named
   cross-host suite, host versions, code page, commands, red mutation, and green results. Do not
   change root `CLAUDE.md` / `AGENTS.md`: their representative-suite policy is already correct.

**Required closure RCA:** no gate caught this because every supported release/live caller already
selected `pwsh`; the defect lived in a later plan's overly broad host-verification claim, outside the
ordinary release path. Sweep remaining maintainer-only scripts and open designs for language copied
from the repository-level “at least one suite” rule, and distinguish declared host support from a
wrapper that silently delegates to another host.

**Proportionality:** the observed harm is an inaccurate verification promise and wasted 5.1 attempt,
not a failed supported release path. A fail-fast declaration plus honest routing removes that harm in
S effort. Reworking 200 byte-sensitive writes and accepting perpetual dual-edition test ownership
would be M+ risk without a consumer; reopen that choice only on concrete demand or a defect that the
representative cross-host suite cannot expose.

**Done when:** the PS7 prerequisite is machine-enforced and documented; a direct 5.1 run fails
clearly with the prerequisite failure rather than the old encoding error; PS7 self-test remains
green; all callers and prose agree; and the named, red-proven `ReleaseCiWatch` suite directly
exercises its own subject under both hosts and hostile code page 437, satisfying the unchanged
repository-level cross-host policy.

**Design/review gate:** write and lock a design before implementation, including the proportionality
case and at least two approaches. Then obtain an independent adversarial review with **Claude Opus**;
the review may reject the premise or split the scope. If Opus is rate- or spend-limited, mark the
review **WAITING — OPUS LIMIT** and continue only independent design/backlog work. Do not substitute
a lower tier and call the review complete.

**Fresh-context adversarial review (Codex, 2026-08-11):** **REJECTED the first design as written.**
It found that the claimed BOMless-fixture oracle did not exist, a nonzero 5.1 assertion was already
green before the proposed fix, the recurrence wrapper was not release-reachable, the replacement
cross-host success world was unnamed, the generic hook fallback/root policy were already accurate,
and the closure RCA was absent. The revision above removes the false byte claim, asserts the changed
failure identity, routes release through the recurrence wrapper, names and independently reruns the
red-proven `ReleaseCiWatch` suite on both hosts at CP437, narrows the prose edit, and supplies the RCA.
This independent Codex review **does not satisfy the required Claude Opus gate**.

**Status: AWAITING OPUS REVIEW.** This revised design is not locked and authorises no implementation.
If Opus is genuinely unavailable due to limits, record `WAITING — OPUS LIMIT`.

---

### B-133 · Make durable-learning promotion part of normal work, without turning reuse into truth
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
**Effort:** S · **Priority:** P3 · filed 2026-08-08 · **Invariants:** #3

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
**Effort:** M · **Priority:** P2 · filed 2026-08-13 · **Invariants:** #3 #4

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

### B-143 · We advise consumers into an `applyTo` glob syntax we have never verified
**Effort:** S · **Priority:** P2 · filed 2026-08-17 while critiquing B-17 · **Invariants:** #5

**Why:** two shipped READMEs tell a consumer to path-scope Copilot instructions using **brace**
syntax — `src/stacks/dotnet/files/README.md:257` says to create
`.github/instructions/typescript.instructions.md` with `applyTo: "**/*.{ts,html}"`. Nothing here has
ever verified that Copilot honours a brace glob. Canary 3 (2026-08-05) tested exactly one form,
`"**/*.cs"`, and the single most important thing it established is that **a non-matching `applyTo`
fails silently** — the instructions simply never arrive, and the developer sees a correctly installed
file either way. So if braces are unsupported, we are walking consumers into a config that delivers
nothing and looks fine. That is the framework's own worst failure mode, in advice we hand out.

Grep confirms no shipped `.instructions.md` uses a comma or brace `applyTo`; the syntax appears only
in prose we give consumers (`applyTo:.*[,{]` over `src`/`dist`).

**Do:** extend `.claude/scripts/canary-applyto-scope.ps1` with brace and comma arms against a repo
containing a matching file, run it once, and record the result in the host-certification table. Then
either keep the advice (verified) or correct both READMEs. Cheap: the canary harness already exists
and Copilot CLI runs are not on the constrained Claude budget.

**Not:** do not "fix" the READMEs by guessing a safer syntax — the point is to know, and an
unverified replacement is the same defect wearing different punctuation.

> **RUN 2026-08-18 on Copilot CLI 1.0.80. The brace question is MOOT ON THIS SURFACE, and what
> replaces it is worse for the advice.** New canary: `.claude/scripts/canary-applyto-brace.ps1`
> (three arms — `"**/*.ts"`, `"**/*.{ts,html}"`, `"**/*.ts,**/*.html"` — matching `.ts` and `.html`
> files present in every arm, and a prompt that **names** `app.ts`).
>
> **All three arms missed**, so the canary reported INVALID and refused to let the brace result be
> read. That refusal was correct and is the useful part: the script's own "positive control" was
> itself a **narrow** glob, i.e. the very form already known to fail. A positive control has to be a
> form known to succeed. Re-running `canary-applyto-scope.ps1` the same day confirmed the baseline
> still holds on 1.0.80 — `"**"` **HIT**, `"**/*.cs"` **MISS**, no-frontmatter **HIT**.
>
> **Jointly these establish something stronger than the question asked:** on Copilot CLI in `-p`
> mode a narrow `applyTo` delivers nothing **even when a matching file exists and the prompt names
> it** — this canary names `app.ts` and still missed; canary 3 names no file and missed. So
> narrowness alone defeats delivery, whatever the punctuation, and **no run on this surface can
> separate braces from commas from any other narrow form.** Braces are neither confirmed nor
> refuted here.
>
> **What this means for the advice, which is the actual item.** The READMEs' instruction to create
> `typescript.instructions.md` with `applyTo: "**/*.{ts,html}"` is aimed at **VS Code agent mode**,
> where `applyTo` scoping is the documented mechanism and the file-context model differs. That
> surface remains **unverified** (shared with B-43, which has never verified VS Code at all). So the
> honest state is: the syntax is still unverified *for the surface it targets*, and on the surface we
> *can* test, any narrow scoping — this syntax included — delivers nothing. Both halves belong in the
> README caveat.
>
> **Still open:** verify on VS Code agent mode, or downgrade the advice to say plainly that scoped
> instruction files are unverified outside `"**"`. Do not swap the canary's control to `"**"` to make
> it report VALID — it would then measure nothing while blaming the braces.

### B-150 · `release.ps1` parks forever on the post-release eval prompt when nothing can answer it
**Effort:** S · **Priority:** P2 · filed 2026-08-19 during the v0.61.0 release · **Invariants:** #3 #7

**Why — observed, not hypothetical.** The v0.61.0 release ran detached (`Start-Process
-WindowStyle Hidden`, stdout+stderr redirected, **stdin not redirected**). It completed every real
step — gates green, commit pushed, CI green on all 8 legs, `v0.61.0` tagged and confirmed on origin
at `release.ps1:850` — and then sat blocked for **~57 minutes at 0.7s CPU** on line 858's
`Read-Host "Release succeeded. Run optional B-41 live agent evals now? [y/N]"`, waiting for a
keystroke at a hidden window nobody could type into. It had to be killed manually.

The guard is `if ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected)`. Both
halves are true for a detached `Start-Process`: `UserInteractive` reports the *session* type, not
whether a human is watching a window, and stdin was never redirected because only stdout/stderr
were. So the script concluded an operator was present when the opposite was true.

**Why no gate caught it:** every gate had already passed — this is strictly *after* the release
succeeds, so no instrument was still watching. `ReleaseGateWaiver.Tests` and friends cover gate
logic, and nothing covers the post-success tail. The failure is also silent by construction: the
log's last line is a success message, so a watcher tailing for failure signatures sees a clean
finish and a process that simply never exits. My own monitor would have reported "gone without
sentinel" only after a kill.

**Same class exposed:** any `Read-Host` / `[Environment]::UserInteractive` branch in
`.claude/scripts/`. Sweep them — a release path that can block indefinitely is the one place it
matters most, because the operator has already been told the release succeeded and has walked away.

**Do:** make the interactivity test honest. `[Console]::IsOutputRedirected` is the reliable signal
here — a redirected stdout means no one is reading a prompt — so require an attended console on
*all* streams, and/or add an explicit `-NoEvals` / `-NonInteractive` switch that the detached runner
passes. Whichever is chosen, the non-interactive path must print the skip line that already exists
(`"Agent evals skipped. Run later: $agentEvalCommand"`) so the evidence trail still says what was
not run. Red-test it the way the defect actually occurred: launch via `Start-Process` with stdout
redirected and stdin left alone, and show the process exits instead of parking.

**Not:** do not simply delete the prompt. The evals are deliberately opt-in and off the release gate
(they are stochastic and consume model budget, see the comment at `release.ps1:853`), and an
interactive maintainer running a release by hand should still be offered them.

### B-151 · `dist-gates` can say it blew its budget but not which file did — the meta suite's old blind spot
**Effort:** S · **Priority:** P3 · filed 2026-08-19 · **Invariants:** #3 #4

**Why:** the budget gate names the *stage* and the aggregate, never the file. For the meta suite
that gap cost three diagnosis cycles in one session (see B-138's measured correction): two fixes
were designed and one was implemented against a bottleneck that measurement later refuted, because
every reading available was inference. `Invoke-HookTests.ps1` now emits `TIMING <file> <seconds>`
and the question became trivial. `dist-gates` is the larger stage (557.8s of a 700s ceiling in the
v0.61.0 run, vs the meta suite's 524.3s of 650s), has the identical parallel-Start-Job shape, and
still has **no per-file attribution at all**. When it breaches — and B-138 argues it eventually
must — the same guessing starts over.

**Do:** emit the same per-file `TIMING` line from the dist-gate runner. Copy the meta-suite shape,
including the reason it is a *separate line*: `release.ps1:549` parses
`^RESULT\s+(\S+)\s+(\d+)\s*$` anchored at **both** ends, so a third field on `RESULT` does not get
ignored — it matches nothing, and `-AllowFailingGate` then reports "emitted no per-file RESULT
lines" and refuses a waiver that is actually valid. Cheap and mechanical; the value is that the
next breach is *read* rather than inferred.

**Proportionality:** this is instrumentation, not optimisation, and deliberately so — it is the
prerequisite that makes B-138's remaining scope diagnosable. Do it before, not instead of.

**B-146 is DONE (2026-08-18) — check B shipped, check A dropped on evidence; see `meta/BACKLOG-DONE.md`.**

**B-144 is DONE (2026-08-18) — see `meta/BACKLOG-DONE.md`.**

## Known deferred work (previously agreed, converted to entries so it survives handover)

**B-14 shipped in v0.25.3 (2026-07-05) — see `meta/BACKLOG-DONE.md`.**

### B-15 · WS-3: one *verified* Jenkins/Bamboo required-build recipe (P1 of the self-sufficiency roadmap)
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
**Effort:** M
`scripts/setup-git-hooks.ps1/.sh` (+ `install.ps1 -GitHooks` flag), added-lines-only staged
scan reusing guard's patterns; must detect and refuse on existing `core.hooksPath`/husky;
documented as bypassable convenience, **not** enforcement. Silent default wiring was explicitly
rejected — keep it opt-in.

### B-20 · Coverage-as-diagnostic + diff-scoped mutation testing (the former v0.24.0 testing release)
**Effort:** L · needs a **new version slot** — ≥ v0.28.0 (0.26.0 = merge, 0.27.0 = B-27 per WSD-012)
Execution-ready plan exists: `<home>\.claude\plans\v0_24_0-shipped-framework-testing.md`
(WS-T9 coverage holes-map + optional off-by-default patch-coverage gate, roll-your-own diff
coverage over `scripts/metrics.*` cobertura ∩ `git diff`; WS-T10 Stryker.NET `--since` /
StrykerJS `--incremental`; WS-T11 wire survivors into `test-critic`; WS-T12 docs/parity).
Key traps recorded there: Angular needs a cobertura reporter wired; CI must fetch the base ref;
"CI-enforced" = runs+reports by default, only the opt-in floor blocks.

**B-25-EXEC is DONE — v0.26.0 shipped 2026-07-12 (WSD-018); see `meta/BACKLOG-DONE.md`.**

### B-26 · Accepted-debt watch list (no action unless symptoms appear)
- `route-prompt` keyword-grep intent classification is brittle by design (accepted 2026-07-01);
  revisit only with evidence of misrouting.
- CLAUDE.md §1 rails reach the model up to 3× per prompt on Claude Code (CLAUDE.md +
  session-start + route-prompt) — token cost accepted for salience. **The "re-measure if
  context budgets tighten" trigger fired 2026-07-11** (consumer token-cost consciousness);
  the watch item is superseded by **B-32** (context-footprint gate, design LOCKED — WSD-017),
  which makes the re-measurement permanent. The salience-over-bytes trade itself stands.

## Completed entries

Completed entries live in meta/BACKLOG-DONE.md.
