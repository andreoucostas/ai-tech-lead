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

**All P1 items (B-01, B-02, B-03) shipped in v0.25.1 (2026-07-04) — see the Done section.** Two
follow-ons this band surfaced are folded into existing P2 entries: the Copilot postToolUse leg is
dead (feeds B-08 matrix rows + B-09 post-write demotion) and the folder-trust prerequisite feeds
`framework-doctor` (B-16). The B-01 optional guard hardening was deferred by decision (see Done).
**B-37 (post-ship review of v0.27.0) shipped in v0.27.1 (2026-07-16) — see the Done section.**

---

## P2 — gates that lie by omission (drift they were built to catch passes silently)

**All P2 items (B-04…B-09) shipped in v0.25.2 (2026-07-04) — see the Done section.** The
check-lockstep union/computed-skills/hooks.json gates + template-checks skills-mirror gate close
the silent-drift holes; the post-write $tn routing divergence is fixed with twin agreement tests;
the enforcement matrix gained the three missing capability rows. **B-35 shipped in v0.29.1
(2026-07-16) — see the Done section. No open P2 items remain.**

---
## P3 — hygiene, drift, small fixes

**B-12 was already resolved — see the Done section.** No open P3 items remain from the audit;
post-audit P3 item B-29 (haiku adequacy evidence) is under "Known deferred work" (its sibling
B-30 shipped in v0.25.4). **B-38, B-39 (both phases), B-36, and B-34 all shipped 2026-07-16 — see
the Done section. No open P3 items remain.**

### B-33 · Make the archived legacy repos route an *agent* to the merged repo — **DONE 2026-07-12, see Done section**

**Why:** consumers adopt this framework by pointing an LLM at a repo URL and saying "install this
into our repository". For 25 versions those URLs were `ai-tech-lead-dotnet` and
`ai-tech-lead-angular`, whose READMEs opened with §1 *"For AI agents (LLMs)"*. Both are now archived
(read-only) with pointer READMEs. **Nobody has verified those pointers work on the audience that
actually uses them** — an agent, not a human. If a pointer README is a human-voice "this repo has
moved" line with no agent-addressed instruction, an agent told to install from the old URL will
either install the **frozen v0.25.5 template** it can still see in the tree, or improvise. Old URLs
are plausibly still the *majority* of inbound traffic.

**Do:** read both pointer READMEs (they could not be verified from the maintainer's box — local
clones are frozen at `bd8bb2f`, the pointers were added on GitHub). If they do not tell an agent, in
imperative voice, to go to `andreoucostas/ai-tech-lead` and install from `dist/<stack>/` — and to
**not** install what it finds in the archived tree — then: unarchive → fix → re-archive. Both repos.

**Not:** any other change to the legacy repos. They stay frozen at v0.25.5.

**Evidence trail:** v0.26.3 (2026-07-12), `meta/LEARNINGS.md` — "a merge can preserve every artifact
and still retire the entrypoint they were reached through". This is the same defect class, on the
one door that could not be fixed from here.

---

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
> 1. **B-45** first — it is process-only, cheap, and every later item is shipped under it.
> 2. **B-47** (LICENSE) — one decision + one file; until it lands, public consumption is legally
>    void, which makes every other consumer-facing investment moot.
> 3. **B-42** (field pilot) — start it early because its value is elapsed time; it runs in the
>    background while other items proceed, and its evidence should re-prioritize everything else.
> 4. **B-41** (agent-behavior harness) — the flagship; absorbs B-23 and B-29.
> 5. **B-49** (quarterly live-fire drill) — build the drill kit once B-41's first scenarios exist;
>    it becomes the recurring vehicle that *executes* B-43 (and reviews B-44) every quarter.
> 6. Then interleave: **B-16** (doctor) and **B-15** (CI recipe) from the deferred list — they are
>    the consumer-lifecycle half of the same story — plus **B-44/B-46/B-48** as capacity allows.

### B-41 · Agent-behavior eval harness — close the "prose steers a model" blind spot
**Effort:** L · **Invariants:** #5 #6 #7 · absorbs B-23 and B-29 (cross-link, don't duplicate)

**Why:** every deterministic gate this repo has validates *bytes* (composition, parity, parse,
mirrors) — none validates *behavior*. The blind spot is written into `DEVELOPING.md` and
`meta/LEARNINGS.md` (2026-07-12, 2026-07-16): the only two post-merge defects that mattered to
consumers (an installing agent mistaking the authoring repo for its target; archived-repo agents
installing frozen v0.25.5) were found **only** by driving a real agent end-to-end, both times by
accident of manual testing rather than by a gate. Meanwhile `tests/evals/run_evals.py` has never
gated a release (B-23), and the WSD-011 haiku-tier downgrade claim has never been evidenced
(B-29). The product *is* prose-for-models; a framework whose entire value proposition is
"the model behaves differently with this installed" has zero automated evidence that it does.

**Do:** build a scripted, non-interactive harness (maintainer-triggered — API cost — not CI):
drive `claude -p` (and the Copilot CLI where scriptable) through fixture scenarios in temp repos
and assert **observable outcomes**, not transcript vibes: files created/committed, installer STOP
obeyed, `/fix` rails produce a regression test before the fix, verification lines present in
output, guard-blocked writes actually retried differently. Start with the 3–5 scenarios that
encode past real failures (install-handoff contract, archived-repo redirect, route-prompt rail
injection, one skill recipe followed end-to-end). Record per-version results in
`meta/eval-results.md`; wire `release.ps1` to *prompt* (not force) a run, per B-23's original
shape. Then extend with B-29's planted-defect agent cases (convention-check / bloat-radar /
debt-radar on Haiku). Treat thresholds, not single runs, as signal — outcomes are stochastic.

**Not:** don't make releases hard-fail on a stochastic outcome; don't build a general eval
platform — fixture scenarios + a results log is the whole product.

### B-42 · Field pilot — install into ≥1 real production repo and let evidence drive the backlog
**Effort:** M to set up · elapsed weeks to harvest · **Invariants:** #6

**Why:** the framework has shipped 31 minor versions with — as far as the meta layer records —
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

### B-45 · Post-Fable maintenance model — codify the implementer/reviewer split (do this first)
**Effort:** S · process-only · **Invariants:** none retargeted, all inherited

**Why:** the shipping quality of the last ten versions depended on frontier-tier review, and the
record proves it: B-37's post-ship review of a lower-tier implementation found **six real
defects** including a false "gates green" (harness code-page bug); every codex-implemented item
(B-32, B-21, B-35, B-36, B-27) had 2–5 real review findings caught **before** ship; two locked
specs had stale file-layout assumptions only caught by a reviewer verifying the live tree. If
Fable-tier access ends, the process that produced this quality must be written down or it
evaporates — the backlog's self-containedness was designed for exactly this handover
(this file's own header says so) but the *review discipline* is currently tribal.

**Do:** add a "Maintenance model" section to the root `CLAUDE.md` (+ regenerate `AGENTS.md`
mirror): (1) every M+ item gets a locked design with an adversarial critique pass before
implementation; (2) implementer and reviewer must be different sessions (different model tier
when available); (3) the reviewer independently re-runs at least one gate and one red-test —
never trusts the implementer's self-report (the B-27/B-36 pattern); (4) when reviewer tier ≤
implementer tier, auto-file a post-ship review entry (the B-37 pattern) instead of pretending
the review was sufficient; (5) verify a spec's file-layout claims against the live tree before
briefing (the B-21/B-22 lesson); (6) re-run at least one suite under a hostile code page before
claiming "gates green" (the F6 lesson). Most of these exist as LEARNINGS entries — this item
promotes them from war stories to binding process.

### B-46 · Consumer update & drift story — what actually happens to a consumer who diverges?
**Effort:** M · investigate-first · **Invariants:** #3 #5 #6 #7

**Why:** install is polished (three modes, smoke-tested ×3 dists) but *operate-and-upgrade* is
not: (1) update mode "refreshes framework machinery, leaves consumer-owned content" — but a
consumer who locally tweaked a shipped skill or hook (which the docs implicitly invite — it's
their repo) gets either silently clobbered or silently left stale; which one is **unverified**.
(2) There is **no channel by which a consumer ever learns a new framework version exists** —
no notification, no check, nothing; realistic consumer version lag is "forever". (3) The B-24
residual (teammate without the wired shell gets no hooks, silently) is documented but not
detected — that detection belongs to B-16's doctor, keep it there.

**Do:** first *verify*: run update mode over a fixture repo carrying a consumer-modified shipped
skill and a consumer-modified hook; record the actual outcome. Then decide policy and document
it honestly in the consumer README (options: clobber-with-preserved-copy à la brownfield
archive; skip-with-warning; three-way-diff note in the update output). For version awareness:
consider a low-noise `session-start` line ("framework v0.31.0 installed; check for updates: <URL>")
throttled to once per N days via the existing `.claude/.state/` mechanism — offline-tolerant,
no network call, just a nudge. Record the design as a WSD before implementing.

### B-47 · LICENSE + distribution posture (blocked on a maintainer decision — but the block is cheap)
**Effort:** S · **Invariants:** #6 #7

**Why:** `github.com/andreoucostas/ai-tech-lead` is **public** with **no LICENSE file**
(verified 2026-07-17). Default copyright means all rights reserved: the README invites teams to
install something they have no legal right to use, and no serious shop's OSS-compliance scan
will let it in. This has been open since the 2026-07-01 forensic audit and it silently caps
adoption at zero-diligence consumers.

**Do:** the maintainer decides the posture: (a) real OSS — MIT or Apache-2.0 (Apache adds a
patent grant; both are corporate-friendly), or (b) employer-internal — then the repo should
arguably be private and the Bitbucket-DC specificity stays a feature, or (c) source-available
with restrictions. Then: add `LICENSE` at root, decide whether each dist ships a copy (consumers
copy dist contents into their repos — the license needs to travel or explicitly not need to),
and add the one-line README statement. If (a), also decide the copyright holder line.

### B-48 · Enforcement-bypass audit — the guard's known end-runs, decided honestly
**Effort:** M · **Invariants:** #3 #5 · needs a WSD record

**Why:** two known bypasses have been deferred-by-decision and neither has a written honest
disclosure: (1) the **shell-write gap** — `guard` registers on editor/file-write tools only, so
`echo $SECRET > appsettings.json` via the terminal tool sails past the secret/pragma blocks
(B-01 optional hardening, deferred 2026-07-04); the `enforcement-surfaces.md` caveat exists but
the hardening decision was never made. (2) the **test-defeat gap** — an agent can satisfy
"build + test green" by weakening the failing test; the test-integrity prose forbids it but no
deterministic gate sees it (open since v0.23.0). An enforcement product whose bypasses are
undocumented-but-known is one consumer incident away from losing its honesty claim.

**Do:** one scoped audit pass: enumerate the realistic end-runs (terminal-tool writes; test
edits that invert assertions/delete cases in the same change that fixes them; `git commit
--no-verify` where git hooks are in play per B-18). For each: either harden (terminal-tool
registration + content-sniff for guard — needs its own fixtures and false-positive analysis;
an added-lines diff heuristic for test-defeat, likely *advisory* not blocking) or **document the
bypass explicitly** in `enforcement-surfaces.md`'s capability rows. Blocking-vs-advisory is the
key judgment: a false-positive block on a legitimate test refactor costs more trust than the
gap. Record the decision as a WSD either way.

---

## Known deferred work (previously agreed, converted to entries so it survives handover)

**B-14 shipped in v0.25.3 (2026-07-05) — see the Done section.**

### B-15 · WS-3: one *verified* Jenkins/Bamboo required-build recipe (P1 of the self-sufficiency roadmap)
**Effort:** M–L
Consumers are Bitbucket Data Center shops; the only deterministic outer-loop primitive they can
use without a DC admin is a **required-build merge check** running their existing CI. Ship one
recipe (docs + pipeline file) that runs `docs-sync-check` + build + test + lint. "Verified"
means actually executed against a local Jenkins container with evidence, per the workspace
verification rules. Details: `.claude/plans/2026-07-02-self-sufficiency-forensic-review.md`
(WS-3). Pre-receive hooks / Code Insights: rejected there — do not resurrect without a consumer
request.

### B-16 · WS-4: honest `framework-doctor` (P1 of the self-sufficiency roadmap)
**Effort:** M

> **Design LOCKED 2026-07-17 — do not re-derive.** Full spec (three-tier row model, 9-row check
> catalog, canary catalog with refusal-vs-block semantics, survival constraints — 5.1-clean
> `.ps1`, parserless `.sh` fallback — reuse boundaries, docs/installer touchpoints, fixture
> tests; 10 adversarial findings folded):
> **`.claude/plans/2026-07-17-b16-framework-doctor-design.md`**; decision record **WSD-023**.
> Implement ≥ v0.32.0 under the B-45 maintenance model. The paragraph below is the original
> summary; the plan is authoritative where they differ.
Consumers can't tell which enforcement tier is live (Preview hooks off = silent degradation;
`guard.sh` without jq/python3 = loud warning nobody reads — WSD-006). Ship a doctor with three
honest tiers: verified-present (reuse `template-checks`, don't reimplement), verified-absent,
and **cannot-verify-from-a-script** (the Copilot org-policy hook toggle — print a
paste-into-agent-mode canary prompt the developer observes). Include the surface-choice
guidance (guard works today on GA Copilot CLI — cheapest coverage win, finding F9 in the WS
plan). Maintainer meta-checks stay out of the shipped doctor.

### B-17 · WS-5: scoped instruction delivery for test files
**Effort:** M
`.github/instructions/` files with `applyTo: **/*Tests.cs` / `**/*.spec.ts` carrying the
test-integrity rules — highest marginal salience, works today with Preview hooks off. Generated
by `/generate-copilot`; extend the `template-checks` mirror gate in the same task [#2]. No
`applyTo: **` variant (decided — salience dilution).

### B-18 · WS-6: opt-in git-hook convenience net
**Effort:** M
`scripts/setup-git-hooks.ps1/.sh` (+ `install.ps1 -GitHooks` flag), added-lines-only staged
scan reusing guard's patterns; must detect and refuse on existing `core.hooksPath`/husky;
documented as bypassable convenience, **not** enforcement. Silent default wiring was explicitly
rejected — keep it opt-in.

### B-20 · Coverage-as-diagnostic + diff-scoped mutation testing (the former v0.24.0 testing release)
**Effort:** L · needs a **new version slot** — ≥ v0.28.0 (0.26.0 = merge, 0.27.0 = B-27 per WSD-012)
Execution-ready plan exists: `C:\Users\Costas\.claude\plans\v0_24_0-shipped-framework-testing.md`
(WS-T9 coverage holes-map + optional off-by-default patch-coverage gate, roll-your-own diff
coverage over `scripts/metrics.*` cobertura ∩ `git diff`; WS-T10 Stryker.NET `--since` /
StrykerJS `--incremental`; WS-T11 wire survivors into `test-critic`; WS-T12 docs/parity).
Key traps recorded there: Angular needs a cobertura reporter wired; CI must fetch the base ref;
"CI-enforced" = runs+reports by default, only the opt-in floor blocks.

### B-21 · Reviewer-profile systemic fixes — **DONE (shipped v0.28.0, 2026-07-16) — see Done section**
**Effort:** M–L · **P0 design complete 2026-07-06** (WSD-013) · **Invariants:** #1 #3 #4 #5

> **Design LOCKED — do not re-derive.** Full spec (adversarially critiqued, LOCK WITH
> AMENDMENTS, findings folded): **`.claude/plans/2026-07-06-b21-reviewer-profile-design.md`**;
> decision record **WSD-013**. Implement from that doc **post-merge, ≥ v0.28.0**, as single
> `src/core` edits in the merged repo; independent of B-27. Frozen under WSD-012's shipped-work
> freeze until the merge lands.

Consumers are competent engineers with limited AI understanding; the pipeline must make every
AI-architecture call so reviewers only answer plain questions about their own code. The design
found the original framing partly stale (adopt-4a contradiction prompts + bootstrap 3d-bis plain
hazard questions already shipped) and re-scoped to the residual gap — judgment items scatter and
expire silently. Three fixes: **D1** a prioritized "needs a human decision" checklist into the
PR/commit (bootstrap Phase 4 + adopt Phase 8, single-emitter, durable `<!-- DEFAULTED -->`
marker for adopt-4a); **D2** session-start hazard-staleness resurface (real interval math,
ISO-pinned, inside `$body`/`emit_body`); **D3** rendered legend + "merge ≠ verified" line, ladder
tokens kept. The remaining backlog work is the implementation (M–L).
**Implementation checklist addition (2026-07-11, WSD-017):** while editing the report emitters,
sanity-check each report's verbosity against the reviewer profile — output leanness applies only
where it doesn't cost the plain-engineering explanations the profile requires (WSD-013). No
standalone "output leanness" backlog item exists, by decision.

### B-23 · Evals as a release gate — **absorbed by B-41** (strategic section above); kept for its open question about `tests/evals` shipping to consumers
**Effort:** M
`tests/evals/run_evals.py` has never gated a release. Wire `release.ps1` to *prompt* to run it
(human-triggered — API cost), and record per-version results in `docs/eval-results.md`.
Related open question: `tests/` including `tests/evals/` **ships to consumers** via the
installer (verified 2026-07-01, accepted-for-now) — revisit whether evals should be excluded
from the consumer install.

### B-25-EXEC · Execute the monorepo merge (Phases 0–6 of MERGE-MIGRATION-PLAN.md)
**Effort:** L (5–7 focused sessions) · **Invariants:** all — this task retargets them · added 2026-07-06
· **IN PROGRESS since 2026-07-08 — Phases 0–3 COMPLETE.** Phase 0: freeze ON, `freeze-v0.25.5`
tags pushed (fidelity baseline: dotnet `bd8bb2f`, angular `e0f7782`), filter-repo verified,
`ai-tech-lead` repo created (private). Phase 1: both repos filter-repo'd into `legacy/{dotnet,angular}`,
merged (`--allow-unrelated-histories`, zero conflicts) → merge commit `305d69e`, 276 files, history
preserved, tagged `pre-restructure`, pushed (branch = `master`). Phase 2 COMPLETE (`218acac`):
classification reproduced WSD-012 (51 identical / 77 differing / 10+10 stack-only), twin extraction
done, **138/138 reproduced for both dist stacks, mismatch=0/missing=0/extra=0** — zero-behaviour-change
proof for both single-stack dists. **Phase 3 COMPLETE 2026-07-09 (`6acb8e5`, pushed;
independently re-verified by Fable first):** `build.ps1` composer twin (byte-identical to `build.sh`
across PS 5.1 + pwsh 7 × both stacks; pwsh 7.3 `-split` trap found+fixed), STRICT fidelity twins
(missing fails; allowlist EMPTY — 138/138 with no exclusions), `validate-dist` twins (marker/JSON/
bash -n/PS-AST/per-dist template-checks; red-tested ×4 defect classes), golden `dist/` committed
(`linguist-generated`), CI (`ci.yml`: rebuild+diff freshness, validate, fidelity, hook suites ×2 legs),
thin root installer wrappers delegating to the frozen dist installers (9-scenario smoke matrix).
**Phase 4 COMPLETE 2026-07-10 (WSD-015):** `dist/monorepo` (148 files) composes via
concat-by-default + authored-override + collision-error (111 authored snippets, 38 whole-file
overrides, 5 derived markers); D4 token gate 1.17× (no fallback); hook union + post-write dispatch
fixture-proven on 3 hosts (the `.ps1` sensitive-regex was NOT additive-safe — authored `-or`
merge, see LEARNINGS); installers auto-detect mixed→monorepo (smoke-tested both legs); validate-dist
green ×3, fidelity 138/138 ×2, hook suites 0 failures ×3, composer twins byte-identical ×3 hosts;
CI gained monorepo legs. **Phase 5 COMPLETE 2026-07-11 (WSD-016):** D7 executed — governance
layer (CLAUDE.md/AGENTS.md/DEVELOPING.md, rewritten single-repo; invariant #1 → single-source
composition) + bom-fix twins (rescoped `ai-tech-lead-*` → `ai-tech-lead/`, twin-agreement tested
9/9) + meta suite (WorkspaceBom now repo-wide; `-File` trap: snippet dirs are *named* `*.ps1`) +
BACKLOG/workspace-decisions/plans/LEARNINGS all moved into the merged repo; `check-lockstep` +
its tests retired; `release.ps1` retargeted (one stamp/CHANGELOG; gates = compose ×3 +
validate-dist ×3 + hook suites ×3 + meta suite; fidelity deliberately NOT a release gate);
root README + root CHANGELOG (v0.26.0 Unreleased) + legacy changelog freezes (diff-verified);
CI gained the meta-suite leg; workspace root reduced to a pointer stub. Verified: build ×3 +
dist freshness empty, validate-dist ×3 exit 0, fidelity ×2 exit 0 (dist untouched), meta suite
0 failures. **Next: Phase 6** (validation → archive legacies → tag v0.26.0 — the release must
retire/re-baseline the CI fidelity legs + fold the checkout v4→v5 bump). See WSD-012 deltas.
Post-freeze follow-up: bump `actions/checkout` v4→v5 (GitHub Node 20 deprecation notice) in the
**shipped** workflows (`src/core/.github/workflows/template-ci.yml` + `docs-sync-check.yml`, and
thereby `dist/`) at the first release that deliberately changes shipped content (≥ v0.26.0) — they
are fidelity-frozen until then. The authoring repo's own `ci.yml` was bumped 2026-07-09.
**Phase 6 COMPLETE — v0.26.0 SHIPPED 2026-07-12 (WSD-018); B-25-EXEC DONE.** Validation ran green
(deterministic gates; all installer stack-resolution paths + `docs-sync-check` — real-toolchain
re-run against `dotnet new webapi` / `ng new` / a real mixed repo after the maintainer installed
dotnet 8.0.422 + ng 21; monorepo `route-prompt` overlay both stacks both twins; per-stack exemplar
routing dynamically confirmed disjoint — `.cs` under `api/`, `.ts` under `web/`). Release execution:
`actions/checkout` v4→v5 in the shipped workflows, CI strict-fidelity legs retired, v0.26.0 CHANGELOG
(root + 3 shipped stack changelogs), released via `release.ps1` → `ad717c7` (11/11 gates green; the
first run correctly REFUSED — the shipped changelogs weren't stamped — fixed then green). `master`
+ tag **v0.26.0** (`dcca7dd`) pushed; pointer READMEs on both legacy repos (dotnet `f018085`,
angular `433f258`); **both legacy GitHub repos archived** (`isArchived:true`). Evals deliberately
skipped for this release (not a gate, zero-behaviour-change, Anthropic-key-only harness — feeds
B-23); full interactive `/bootstrap` stays developer-gated. Acceptance 1–6 met; abort rule never
fired. **Next: B-27 (team wiki memory) as v0.27.0 in this repo.**

The decision half is DONE: D1–D7 signed off 2026-07-06 (**WSD-012**), plan refreshed against
v0.25.5 with fresh evidence, phase reorder (archive/tag only after Phase 6 validation), a
binding **abort rule**, and the fidelity baseline pinned to Phase-0 freeze tags. Execute
`MERGE-MIGRATION-PLAN.md` exactly — do not re-derive; deltas get appended to WSD-012.
**Phase 0 first** (freeze both repos + record freeze-tag SHAs). **Freeze scope:** while this
runs, all shipped-repo backlog items (B-15…B-23, B-29) pause; meta-only design work
(B-21/B-22 P0 design docs, WSD entries) remains allowed. First merged version **v0.26.0**;
B-27 follows as v0.27.0 in the merged repo.

### B-26 · Accepted-debt watch list (no action unless symptoms appear)
- `route-prompt` keyword-grep intent classification is brittle by design (accepted 2026-07-01);
  revisit only with evidence of misrouting.
- CLAUDE.md §1 rails reach the model up to 3× per prompt on Claude Code (CLAUDE.md +
  session-start + route-prompt) — token cost accepted for salience. **The "re-measure if
  context budgets tighten" trigger fired 2026-07-11** (consumer token-cost consciousness);
  the watch item is superseded by **B-32** (context-footprint gate, design LOCKED — WSD-017),
  which makes the re-measurement permanent. The salience-over-bytes trade itself stands.

### B-29 · Haiku-tier agent adequacy evidence (P3) — **absorbed by B-41** (strategic section above) as its planted-defect extension
**Area:** both repos' `tests/evals/` · **Effort:** M · **Invariants:** #1 · added 2026-07-05

The v0.8.0 model-routing entry claims the haiku downgrade of `convention-check`, `bloat-radar`,
and `debt-radar` comes "without losing security or bootstrap quality" — that claim has never
been evidenced (no eval covers these agents; evals have never gated a release, B-23). Add eval
cases with planted defects each agent must catch on Haiku: known convention violations for
`convention-check`, over-abstraction patterns for `bloat-radar`, seeded TECH_DEBT references for
`debt-radar`. Mirror to both repos [#1]. If Haiku misses at a meaningful rate, revisit the
tiering (WSD-011) rather than the eval. Cross-links: B-23 (evals as release gate), WSD-011
(token-policy record that filed this gap).

**Amended 2026-07-11 (B-32 design pass, WSD-017):** rising consumer token-cost consciousness
raises this item's value — it is the enabler for safely *extending* the WSD-011 tiering to more
agents (the cheapest cost lever available; extension without evidence would repeat the original
unevidenced claim). Scope addition: decide/verify whether the shipped `.github/agents/*.agent.md`
wrappers should pin GitHub's documented `model:` field — tiering currently reaches Claude Code
only (WSD-011 implementation fact), so the Copilot half of every consumer surface gets no benefit.
A wrong pin is consumer-visible: verify on a live Copilot surface before shipping.

---

## Done

- **B-40** — shipped **v0.31.0** (2026-07-17). SQL / data-warehouse guidance (WSD-021, design
  `.claude/plans/2026-07-16-b40-sql-dw-guidance-design.md` — locked and implemented same-day
  after an adversarial review of the implementation plan folded in 11 findings). Two new
  dotnet-stack skills: **`map-warehouse`** (discovery: layers incl. consumption views/marts,
  fact/dim entities + grain statements, load orchestration/ordering, batch/watermark control,
  SCD strategy, partitioning; offers `docs/warehouse-map.md`) and **`add-warehouse-load`**
  (recipe: mirror the sibling load, grain-first entity design, idempotent loads — watermark /
  batch-ID dedup / delete-window / merge+row-hash / versioned-runs semantics — SCD mechanics,
  dims-before-facts orchestration, partition alignment, deployment vehicle, sign-off
  checklist). Both gated Step-0 on two-tier evidence (SQL-repo artifacts AND ≥2 DW signals
  grepped inside SQL artifacts only — hardened against xUnit `[Fact]`/prose false positives).
  `/bootstrap` A2 detects SQL-project/stored-proc repos + DW signals; Phase 3a got a three-way
  keep/delete rule and exemplar-pins `add-warehouse-load`; `defaults.md` gained raw-SQL and DW
  evidence blocks; `add-entity` cross-routes warehouse tables. Ships to dotnet + monorepo
  (angular untouched bar the every-version changelog entry). All B-35-consistent; T-SQL as
  evidence-gated illustration only.

- **B-34** — shipped **v0.30.1** (2026-07-16). Implemented via a codex (gpt-5.6-sol) implementer
  under principal-engineer review, closing the render-parity gap B-32 left open on `guard` and
  `audit-trail`. **`guard`**: aligned the PowerShell twin's secret-type labels from ASCII `...` to
  the canonical ellipsis `…` (matching `guard.sh` exactly — e.g. `AKIA…` not `AKIA...`), and
  switched the Copilot deny-JSON construction from a plain `@{}` hashtable to `[ordered]@{}` so key
  order is deterministic and matches the bash twin's fixed `printf` format
  (`permissionDecision`/`permissionDecisionReason`/`hookSpecificOutput`) byte-for-byte — without
  `[ordered]`, PowerShell hashtable enumeration order is hash-based and not guaranteed to match.
  **`audit-trail`**: confirmed it has **no model-visible output at all** (both twins produce empty
  stdout/stderr on a real write event) — its drift was comment-only (`--`/`—`), fixed as a Boy
  Scout pass rather than a behavior change. **Test coverage**: extended the existing
  `guard-cases.ps1`-driven `TwinParity.Tests.ps1` block (not a new fixture table) to assert ordinal
  byte-equality of both stdout and stderr across all 16 guard cases × both surfaces (Claude/
  Copilot), on top of the pre-existing decision-only check. **Red-tested for real**: transiently
  reverted the `AKIA…` fix back to `AKIA...`, confirmed the new assertion caught it on both
  surfaces (`RED_EXIT=2`), then restored and reran clean. Left `post-write`/`session-start`/
  `route-prompt` untouched (out of scope — the backlog's "consider extending to post-write" note
  was optional; the primary deliverable came first and codex correctly didn't let it crowd that
  out). **Verified:** build ×3 + freshness; `validate-dist` ×3 exit 0; all three dists' hook suites
  0 failures across two independent full runs; PS-AST parse + BOM independently spot-checked (not
  just trusted codex's report). Released via `release.ps1`, all gates green, pushed.

- **B-36** — shipped **v0.30.0** (2026-07-16). Implemented the LOCKED WSD-020 design
  (`.claude/plans/2026-07-15-b36-testing-strategy-design.md`) via a codex (gpt-5.6-sol)
  implementer under principal-engineer review. **D1** — `add-tests` (all three stacks × `.claude`/
  `.github` mirrors, 6 files) gains a new symmetric **Suite bootstrap mode** section, entered from
  Step 1 when Grep finds no test project/spec files at all: confirm framework + location with the
  developer first (a real checkpoint), scaffold the minimum (one unit-test project + an HTTP
  integration fixture only if warranted, no E2E/coverage tooling day one), wire into existing
  CI/build, order first tests risk-first (hazard areas → financial invariants → critical journeys
  → domain logic), and record the remainder as one honest `TECH_DEBT.md` entry instead of implying
  coverage. **D2** — each stack's Feature workflow rail (`workflow-bullets`) gained an identical
  one-line parenthetical pointing at `Conventions > Testing` / the Test shape heuristic for level
  selection and the suite-bootstrap escape hatch, kept tight given the rail's always-loaded token
  budget. **D3** — `/bootstrap` (all three stacks) makes suite state a first-class output: the
  testing pass (`A5`/dotnet+monorepo, `A6`/angular, both subsections in monorepo) states "no test
  projects" as its *primary finding* rather than folding it into "coverage gaps"; Phase 3a's
  Conventions synthesis now requires ending `Conventions > Testing` with a one-line target test
  shape; Phase 3b writes a Severity-High `TECH_DEBT.md` entry naming suite-bootstrap mode as the
  fix, surfaced in the Phase 4 top-3 quick wins. Monorepo's dual-stack structure was handled
  correctly throughout (not copy-pasted) — both A5/.NET and A6/Angular testing passes got the
  primary-finding treatment, and the Phase 3b/3a/Phase-4 wording was generalized to "per affected
  stack" rather than assuming a single stack. **D4** — one routing line in each stack's
  `defaults.md` Testing section pointing "no test suite yet?" at `add-tests`. **Verified:**
  build ×3 + freshness; `validate-dist` ×3 exit 0 (re-run independently, not just trusted); the
  composed `dist/monorepo` skill/rail/bootstrap text spot-checked directly (not just "compose
  succeeded"); grep-confirmed the D1-D4 strings landed in all three composed dists (codex caught
  its own tooling mistake mid-verification — a non-`--hidden` `rg` search missed the dot-directory
  `.claude`/`.github` skill mirrors, silently reporting 0 matches — corrected and re-verified);
  a real greenfield install-smoke confirming the installed `add-tests` SKILL.md carries the suite-
  bootstrap routing/checkpoint/risk-first text; context-footprint measured (+178 chars per
  `CLAUDE.md`, monorepo-to-largest-stack ratio *improved* slightly to 1.159×, well under the 1.5×
  ceiling) — the un-updated baseline correctly FAILed pre-release (expected; `-Update` is
  `release.ps1`'s job, deliberately not run here). No hook/script changes, so hook suites are
  unaffected (spec's own call). Shipped in the same release as B-39 phase 2 (below) — one version
  bump covering both. Released via `release.ps1`, all gates green, pushed.

- **B-39 (phase 2)** — shipped **v0.30.0** (2026-07-16, same release as B-36 above). Implemented
  via a codex (gpt-5.6-sol) implementer under principal-engineer review. The shipped
  `src/core/tests/hooks/Invoke-HookTests.ps1` runner (single-source, composes byte-identically
  into all three dists) now runs its `*.Tests.ps1` files through a bounded 4-slot `Start-Job`
  worker pool instead of serially — each test file still runs as its own fully isolated external
  `pwsh`/`powershell` process (an extra process layer versus the job-orchestration process itself,
  which safely satisfies the B-37-discovered constraint that `_HookHarness.ps1`'s `Invoke-Hook`
  mutates process-global console encoding and must never share a runspace). Output is buffered per
  file and replayed in fixed name-sorted order after all children finish, preserving the exact
  `=== Hook test suite: N failure(s) across M file(s) ===` summary contract and `exit $total`
  behavior every caller (including `release.ps1`) depends on. The separate hand-maintained
  meta-only fork (`.claude/hooks/tests/Invoke-HookTests.ps1`) was correctly left untouched — out of
  scope. **Measured (real dist tree, dotnet):** serial 136.611s → parallel 91.999s (32.7%
  reduction); also confirmed green under Windows PowerShell 5.1 (89.661s). **Red-tested for real:**
  planted a failing assertion in one test file, confirmed it stayed visible through the buffered
  output (`[FAIL] PLANTED runner propagation failure`), the aggregate count and exit code (1)
  reflected it, and every other file still ran and reported correctly — then removed the plant and
  hash-verified its complete removal from every dist copy. **Verified:** all three dists'
  `Invoke-HookTests.ps1` (using the new parallel code) ran green (0 failures across 10 files) with
  individual wall times noted; `validate-dist` ×3 exit 0; PS-AST parse + BOM independently spot-
  checked (not just trusted codex's report). Shipped in the same release as B-36 — one version
  bump covering both. Released via `release.ps1`, all gates green, pushed.

- **B-39 (phase 1)** — done **2026-07-16** (meta-only, no version/CHANGELOG — process-only change
  to a maintainer script, per invariant #7's scoping to *shipped* behavior). Implemented via a
  codex (gpt-5.6-sol) implementer under principal-engineer review. `.claude/scripts/release.ps1`'s
  step 4 now runs the three per-dist gate pairs (`validate-dist.ps1` then that dist's
  `Invoke-HookTests.ps1`) as three concurrent `Start-Job` child processes (true process-level
  parallelism — a runspace-based approach was rejected per the B-37-discovered constraint that
  `_HookHarness.ps1` mutates process-global `[Console]::OutputEncoding`, which is unsafe to share
  across in-process runspaces) instead of serially; each dist's combined output is buffered to a
  temp log and replayed in fixed `$dists` order (dotnet, angular, monorepo) after all three jobs
  finish, so the release log stays readable rather than interleaving three suites' output.
  Both exit codes (`validate-dist`, hook suite) are gated per dist exactly as before — the
  existing `Gate` helper, its `$fatal` accumulation, and the REFUSED-exit messaging are untouched.
  **Measured (maintainer box, real dist trees, not a fixture):** serial baseline 418.46s
  (dotnet 139.6s / angular 137.6s / monorepo 141.2s) → parallel 247.12s — a 41% wall-time
  reduction (less than the spec's ~2.5min ideal-case estimate, since real concurrent process
  contention on one box doesn't hit the theoretical best case; still a substantial, honestly
  reported win). **Red-tested for real:** first attempt (renaming `.template-repo`) was a false
  negative — `validate-dist` doesn't actually check that file — caught and corrected to a defect
  class the validator does gate (`dist/angular/scripts/template-checks.ps1` missing), confirmed
  `GATE FAIL: validate-dist angular` + `$fatal=$true` with the hook suite still running and
  passing independently (both statuses are recorded per-dist regardless of the other), file
  restored, worktree left clean. **Independently re-verified** (not just trusted codex's
  self-report): PS-AST parse clean, BOM intact, a live green single-dist run, and a from-scratch
  repeat of the red test executing the literal code extracted from the file (not a retyped copy) —
  same result. Phase 2 (parallelizing `Invoke-HookTests.ps1`'s internal test files, a shipped
  change) remains open — see B-39 (phase 2) above.

- **B-38** — done **2026-07-16** (meta-only, no version/CHANGELOG — process-only fix to a
  maintainer script, per invariant #7's scoping to *shipped* behavior). Implemented via a codex
  (gpt-5.6-sol) implementer under principal-engineer review. `.claude/scripts/release.ps1`'s
  README version-stamp logic now distinguishes "line missing/reworded" (still FATAL, `exit 2`)
  from "line already carries the target version" (the state a *refused* release leaves behind,
  since stamping happens in step 2 but gates run in step 4) — the latter now skips the write and
  prints `README already stamped $Version (retry after a refused release).` instead of dying with
  a misleading "no such line" error. All three `Release REFUSED` exit points gained a one-line
  "safe to re-run as-is" hint. **Review finding fixed before merging:** the codex diff left
  `Write-Host "Stamped src + root README -> $Version ($today)."` unconditional after the if/else,
  so the already-stamped branch would have printed both "README already stamped…" and
  "Stamped src + root README…" together — self-contradictory (claims a stamp that didn't happen).
  Moved that line inside the `else` so only one message prints per branch. Audited the other three
  stamp steps (CHANGELOG `Unreleased`, core `CLAUDE.md`, the three `framework-version.json`s) for
  the same idempotency class — confirmed already-idempotent, left unchanged as the plan specified.
  **Verified:** PS-AST parse clean, BOM intact; independently re-ran (not just trusted codex's
  self-report) a standalone harness against temp README copies driving all three states —
  already-stamped (exit 0, file unchanged, single correct message), older-version (exit 0,
  rewrites), line-missing (exit 2, FATAL, unchanged) — all green post-fix. Full-loop confirmation
  (a real refused release hitting this path) deferred to the next occurrence per the plan; note
  the result in `meta/LEARNINGS.md` then.

- **B-21 (implementation)** — shipped **v0.28.0** (2026-07-16). Implemented the LOCKED WSD-013
  design (`.claude/plans/2026-07-06-b21-reviewer-profile-design.md`) via a codex (gpt-5.6-sol)
  implementer under principal-engineer review. **D1** — `bootstrap.md` Phase 4 + `adopt.md` Phase 8
  emit a prioritized "Paste this into your PR (or commit message)" judgment checklist (INFERRED
  conventions / unsure-or-tooling-only hazards / adopt-4a defaulted contradictions / discovered
  skills); bootstrap suppresses under `/adopt` (Phase 8 sole emitter via the Phase-2b adopt signal),
  bootstrap gains a commit/PR nudge, adopt-4a writes a durable `<!-- DEFAULTED: … -->` marker that
  Phase 8 re-scans. **D2** — `session-start.{ps1,sh}` (core twins) resurface hazard rows whose ISO
  `Reviewed` date is >90 days old (interval math, GNU-`date` guard, inside `$body`/`emit_body` for
  the Copilot surface); `bootstrap.md` 3d-bis pins `Reviewed` + the not-a-hazard status to ISO
  `YYYY-MM-DD`. **D3** — rendered ladder legend + "merging the PR does not confirm these" above the
  hazard table (was inside a non-rendering HTML comment); ladder tokens kept as machine anchors.
  **Structural correction** (see LEARNINGS 2026-07-16): the pre-merge spec's "one `src/core` edit
  per artifact" was stale — bootstrap.md/adopt.md/FRAMEWORK-CONTEXT.md are stack whole-file overrides,
  so this was a ×3 edit (invariant #1), only session-start is core; cross-stack inserts confirmed
  byte-identical. **Verified:** new `SessionStartHazard.Tests.ps1` (19 cases, red-tested against the
  pre-D2 HEAD hook then green on both twins incl. confirmed-stale + Copilot dual-shape); build ×3 +
  freshness; validate-dist ×3; dotnet dist hook suite 0 failures across 10 files (TwinParity 40/40).
  Released via `release.ps1`. **B-22 (headless `/adopt`) is now unblocked** (its hard dependency
  B-21 D1 shipped).

- **B-35** — shipped **v0.29.1** (2026-07-16). Implemented the LOCKED WSD-020 design
  (`.claude/plans/2026-07-15-b35-derive-dont-assume-design.md`) via a codex (gpt-5.6-sol)
  implementer under principal-engineer review. **D1** — new Verification Rule 10 ("Derive, don't
  assume") added to `verif-rule9` snippets in all three stacks (dotnet/angular/monorepo — the
  principle generalizes beyond ORM to HTTP client/state management/test framework, so it applies
  to angular too, not just the two EF-affected stacks). **D2** — dotnet + monorepo
  `docs/defaults.md` Data Access restructured into evidence-keyed blocks (EF Core / Dapper /
  MongoDB.Driver / none-detected); "Test shape" line genericized. **D3** — `/bootstrap` A2 opens
  its persistence detection list (EF Core/Dapper/ADO.NET/MongoDB.Driver/Cosmos/Redis/other/none)
  and Phase 3a gains a no-unevidenced-technology synthesis guard, dotnet + monorepo. **D4** —
  `add-entity` (`.claude` + `.github` mirrors, dotnet + monorepo) gains a Step 0 EF-evidence gate;
  bootstrap 3a Common Tasks audit gains a persistence-check line. **D5** — `boy-scout-check`
  heuristic #3 (4 files: dotnet + monorepo × `.ps1`/`.sh`) now requires an EF marker
  (`Microsoft.EntityFrameworkCore`/`DbContext`/`DbSet<`) in the same file before flagging missing
  `AsNoTracking()` — MongoDB's identically-named `ToListAsync`-family methods no longer misfire.
  **D6** — `copilot-instructions.md` (dotnet + monorepo) genericized ("data-access layer" instead
  of "DbContext"). New shared test cases added to the existing core `TwinParity.Tests.ps1` (not a
  new file — reused invariant #1's single-source test surface, angular skips via a guard since it
  doesn't carry the hook): Mongo-shaped query → zero findings, EF query without AsNoTracking →
  still flags. **Review finding fixed before shipping:** the angular consumer CHANGELOG entry
  copy-pasted the dotnet wording ("no longer assumes EF Core") verbatim — meaningless to an
  Angular consumer who never had EF Core guidance; reworded to name the actually-relevant
  technologies (HTTP client, state management, test framework). **Verified:** build ×3 + dist
  freshness; `validate-dist` ×3 exit 0 (all three, incl. skills-mirror sync); all 3 dists' hook
  suites 0 failures (dotnet `TwinParity.Tests` 42/42, up from 40/40 — exactly the 2 new cases) +
  meta suite 0 failures (`InstallerContract` 12/12). Released via `release.ps1`, all gates green,
  pushed.

- **B-22 (implementation)** — shipped **v0.29.0** (2026-07-16). Implemented the LOCKED WSD-014
  (Path A) design (`.claude/plans/2026-07-06-b22-headless-adopt-design.md`). Headless `/adopt`
  **prepares** adoption autonomously (auto-branch, archive, provenance + adversarial screen,
  impact baseline) and **stages** every `CLAUDE.md`/`TECH_DEBT.md` merge for a human to apply at
  PR review — the prompt-injection boundary is held by stage-don't-apply + quarantine-exclusion +
  a restricted tool surface, not by `disable-model-invocation` (a prompt wrapper ignores that
  anyway, so the boundary holds on the Copilot leg too). `adopt.md` ×3 gained a normative
  `## Headless mode` section (per-gate override table, restricted tool surface, marker/guard
  lifecycle, embedded-bootstrap headless propagation); `bootstrap.md` ×3 Phase 3d-bis auto-takes
  "skip all — mark as unverified" under headless; `adopt.prompt.md` (core) documents the
  `--headless` directive; `install.{sh,ps1}` twins + marker `nextStep` offer the headless entry
  alongside the developer path. **Structural correction** (same class as B-21's): the pre-merge
  spec's "single `src/core` edit" assumption was stale — `adopt.md`/`bootstrap.md` are stack
  whole-file overrides (×3), only the prompt wrapper + installers are core.
  **Deviation** (see `meta/LEARNINGS.md` 2026-07-16, B-22): the plan was to drive codex
  (gpt-5.6-sol) with `--dangerously-bypass-approvals-and-sandbox` as in B-32/B-21, but a
  relayed/cross-session authorization doesn't clear the bypass gate for a nested codex — the
  reviewer implemented directly instead (same edits, same review + gate verification). **Verified:**
  compose ×3 + `git status dist/` self-consistent (15 expected files); `validate-dist` ×3 exit 0
  (markers, template-checks/AGENTS mirror, no-meta-leak, no-dead-instruction); meta suite 0
  failures incl. `InstallerContract` 12/12 (both modes × both twins × 3 dists) and generated
  consumer marker JSON valid on both twins; dotnet dist hook suite 0 failures. Released via
  `release.ps1`, all gates green, pushed.

- **B-37** — shipped **v0.27.1** (2026-07-16). Post-ship review of v0.27.0 (B-27 team wiki
  memory) against the locked WSD-010 spec found six defects, all fixed: GNU-only `date -d`
  failing every valid `last-verified` on macOS agents (F1); both wiki-check twins reading
  `$Root` from stdin, hanging interactive `docs-sync-check` runs (F2); locale-dependent index
  sort — bare `sort` vs culture `Sort-Object`, the B-02 skew class — pinned to byte/ordinal
  order in both twins (F3); the D4/D9 boundary-doc touchpoints that never shipped (F4); the
  `.sh` hook's Copilot-JSON wiki delivery untested (F5); and a pre-existing harness bug —
  `Invoke-Hook` decoded child stdout with the console code page, so v0.27.0's "hook suites
  green" held only on UTF-8 consoles (F6, reproduced red under ibm850, fixed by pinning UTF-8
  around the capture). Fix loop: Opus 4.8 (scripts + tests) and Sonnet 5 (docs) implementers
  under Fable 5 review; verified by red-testing the F1/F3 classes and re-running both wiki
  suites green (13 + 10) under a non-UTF-8 code page. Observation logged, NO action (locked
  design): the D6 injection-marker list hard-FAILs benign descriptions containing "instead
  of" — revisit only on consumer evidence.

- **B-32** — shipped **v0.26.5** (2026-07-15). Implemented from the LOCKED spec
  (`.claude/plans/2026-07-11-b32-context-footprint-gate-design.md`, WSD-017) via a codex
  (gpt-5.6-sol) implementer + principal-engineer review loop — five review rounds, three real
  defects found and fixed before shipping (see `meta/workspace-decisions.md` WSD-017 for the
  implementation-deltas log: baseline path retargeted to `meta/context-footprint.json`, a
  pre-existing `.ps1` hook Unicode-mangling bug the fixtures caught, and two PowerShell
  correctness bugs in the gate script itself — `Measure-Object -Property` silently returning
  zero on `[ordered]` hashtable items, and a double-array-wrap that corrupted derived totals).
  Twins `scripts/context-footprint.ps1/.sh` ship as genuinely independent implementations (not
  a delegating wrapper — the first implementer's initial cut had `.sh` shell out to `.ps1`,
  rejected on review since it defeats the CI cross-OS twin proof). **Forced an unplanned
  shipped-behavior fix**: the rendered-hook fixtures proved `dist/*/.claude/hooks/{session-start,
  route-prompt}.ps1` rendered ASCII-flattened rails (`WARNING:`/`--`) where the `.sh` twins emit
  the designed `⚠`/`—`/`→` text, **and** that redirected `.ps1` hook stdout on Windows was
  encoded with the OEM code page, silently turning `⚠/—/🔴` into `?` for every consumer who
  runs the PowerShell hooks — both fixed (UTF-8-on-redirect guard + byte-identical rendered
  text), which is why this shipped as v0.26.5 rather than landing with no version slot as the
  design anticipated. `B-34` filed for the same rendered-parity sweep on `guard`/`audit-trail`
  (out of scope here). Verified: 30-pair cross-twin render matrix, baseline generation +
  idempotent `-Update` + cross-twin byte-identical proof, full red-test matrix (freshness drift,
  twin-render-mismatch detection, WARN-ceiling reachability), all 4 hook suites + `validate-dist`
  ×3 green (the one expected pre-stamp `validate-dist` FAIL — CHANGELOG at 0.26.5 vs
  `framework-version.json` at 0.26.4 — resolved by `release.ps1`'s own stamp-then-validate
  order). Released via `release.ps1`, all gates green, pushed.
- **B-27** — shipped **v0.27.0** (2026-07-16). Implemented from the LOCKED spec
  (`.claude/plans/2026-07-04-b27-wiki-memory-design.md`, D1–D10, WSD-010 + its 2026-07-11
  monorepo-retargeting appendix) via a codex (gpt-5.6-sol) implementer + principal-engineer
  review loop — two implementation rounds, five real defects found on review and fixed before
  shipping:
  1. `wiki-check.sh`'s injection-signal character class matched the INDEX grammar's own
     mandatory em-dash under real UTF-8 collation, FAILing every syntactically valid entry —
     reproduced directly, rewritten as `LC_ALL=C` byte-exact UTF-8 matching mirroring the `.ps1`
     twin's codepoint ranges.
  2. `wiki-check.sh` didn't resolve a native Windows-style root path (exactly what the
     `Invoke-Hook` test harness passes) — fixed with separator normalization + `cygpath`.
  3. `install.ps1`'s D8 copy-if-absent fix had diverged structurally from the `.sh` twin (a full
     per-file rewrite of the whole copy loop vs. the twin's surgical `docs/`-only special case,
     an invariant #3 twin-parity violation and an oversized blast radius) — restored to match.
  4. Three separate wiki-related doc insertions (`CLAUDE.md` companion-preamble line, Common
     Tasks bullet, self-review bullet ×3 each; `ci-integration.md`'s wiki-check line ×2) had
     landed tripled/duplicated — none in the 5 verbatim-gated mirror sections, so
     `template-checks` passed clean despite it; caught only by direct file reading, deduped.
  5. The shipped `_template.md` carried a leading HTML comment not present in the locked D2
     template, breaking its own frontmatter contract (`first line must be ---`) the moment an
     entry was drafted from it literally — caught by an actual skill smoke test (draft-from-
     template, not a synthetic fixture), fixed by removing the line (principal-engineer fix,
     not round-tripped — trivial one-line deletion).
  Also confirmed and corrected: every other hook-suite failure the implementer reported
  (`AuditTrail`, `PostWriteRouting`, `RoutePrompt`, `SessionStartWiki`, `TwinParity`) was its
  sandbox's Git Bash failing to start (`CreateFileMapping ... Win32 error 5`), not a real defect
  — confirmed by rerunning every suite in a working shell, all green throughout both rounds.
  **Verified:** `build.ps1` fresh ×3 + `git status --porcelain dist/` stable; `validate-dist.ps1`
  ×3 clean (markers, JSON, `bash -n`, PS-AST, `template-checks`, `no-meta-leak`,
  `no-dead-instruction`); all 3 dists' `Invoke-HookTests.ps1` 0 failures across 9 files each
  (`WikiCheck.Tests` 11/11, `TwinParity.Tests` 40/40); meta suite (`DocTruth`,
  `InstallerContract`, `MetaHooks`, `WorkspaceBom`) green; install smoke greenfield + brownfield +
  update ×3 dists all `EXIT=0`; `docs-sync-check` ×3 clean; `wiki-check` run directly against the
  real committed `dist/*` wiki dirs (both twins agree); live guard-hook fixture (a fabricated AWS
  key in a `docs/wiki/*.md` write) blocked with exit 2, proving the generic secret-scan already
  covers wiki writes with no wiki-specific code needed; hands-on skill smoke (draft from the
  corrected template → passes wiki-check with only an expected body-level WARN → single
  entry/single INDEX line, proving the dedup-not-duplicate mechanics hold). Released via
  `release.ps1`, all gates green, pushed.
- **B-33** — done **2026-07-12**, then **REOPENED AND RE-FIXED THE SAME DAY** when tested on the
  second surface. The README fix below was **Claude-only**: given the archived repo's URL, **Copilot
  never opens the README** — it clones and runs `scripts/install.ps1` directly, and duly installed
  the frozen **v0.25.5** template straight past a STOP banner it never read. The first "verified
  red→green" claim was made on one surface of a two-surface product, which is to say it was not
  verified. **Final fix: a hard refuse-and-redirect at the top of all four frozen installer twins**
  (print the STOP, `exit 1`, copy nothing) — the one channel both surfaces demonstrably obey.
  Re-tested on Copilot against the archived URL: now redirects and installs **v0.26.4**, committed,
  correct handoff. Claude path provably unaffected (guard commit touched only `scripts/install.*`).
  Repos re-archived. Lesson in `meta/LEARNINGS.md`: *documentation is advisory; executable output is
  not.* Original README work below — still correct, just not sufficient on its own.

  Both archived
  pointer READMEs rewritten, verified, and re-archived. **The hypothesis was right and the mechanism
  was worse than filed.** Reproduced end-to-end: an agent given the old URL and *"install this
  framework into our repo"* on a clean machine read the archive banner, **rationalised past it, and
  installed the frozen v0.25.5 template** — citing the banner's own words as its warrant: *"its content
  (and the byte-for-byte-identical installer) still works, and the URL you gave me is exactly this
  repo, so I installed from it as asked."* Two causes: **(1)** the only *imperative, agent-addressed*
  text on the page was the preserved §1 (*"If you are an AI agent reading this repository, start
  here"*) telling it to run the installer **there**; the archive notice was human-voice prose the model
  felt free to weigh against it and discount. **(2)** The banner's reassurance — *"reproduces this
  template byte-for-byte … moving is an update, not a behavior change"* — was written to comfort a
  human and **armed the agent**: it reads as *the old one is equivalent, so installing it is fine.* It
  was also no longer true. Fix: banner now addresses agents first and humans second; §1 is a STOP that
  redirects; the equivalence claim is gone. Re-tested identically → installs **v0.26.3**, commits in
  the target, hands off correctly. Red→green: `0.25.5` → `0.26.3`. Repos re-archived.
  Lesson in `meta/LEARNINGS.md`.

- **B-22 (P0 design)** — done **2026-07-06** (meta-only; implementation stays open, post-merge).
  Design locked as **WSD-014**, spec at `.claude/plans/2026-07-06-b22-headless-adopt-design.md`
  (rev-2). Adversarial critique returned **RETHINK** — it proved the non-negotiable
  prompt-injection boundary forbids auto-merging untrusted content into `CLAUDE.md` (a keyword
  denylist was the only automated filter). Surfaced the constraint-1-vs-2 conflict to the
  maintainer, who chose **Path A** (prepare autonomously, human applies merges at PR review) over
  Path B (constrained auto-merge, residual risk). rev-2 folds both HIGH findings (auto-merge
  breach; embedded `/bootstrap` 3d-bis stall) + M3–M7/L8–L9: invocation via the read-and-execute
  prompt pattern (drops the spike; both surfaces), provenance-exemption for installer-archived
  originals, marker/branch lifecycle pinned, restricted tool surface for untrusted-content
  handling. Depends on B-21 D1; implementation ≥ v0.28.0 in the merged repo.
- **B-21 (P0 design)** — done **2026-07-06** (meta-only; implementation stays open, post-merge).
  Design locked as **WSD-013**, spec at `.claude/plans/2026-07-06-b21-reviewer-profile-design.md`.
  Re-scoped after finding two of the three original fixes already partly shipped; three deltas
  designed (D1 judgment checklist into PR/commit, D2 session-start hazard resurface, D3 rendered
  ladder legend). Adversarially critiqued (LOCK WITH AMENDMENTS): 2 HIGH + 4 MEDIUM + 4 LOW
  folded — notably D2's date mechanism rewritten to real interval math with an ISO-pin on
  3d-bis, D1 given a real landing site + durable `<!-- DEFAULTED -->` trace, and a corrected
  (false) B-27 dependency. Implementation is B-21's remaining open work, ≥ v0.28.0 in the merged
  repo. The B-21 entry above carries the pointer.
- **B-31** — shipped **v0.25.5** (2026-07-06). Angular's `.claude/settings.windows.json` was
  missing the `audit-trail.ps1` PostToolUse registration — a gap the B-14 port missed (it wired
  `settings.json` + `hooks.json` but not the PS-5.1 fallback), found by the B-25 adversarial
  review. PS-5.1-fallback Angular consumers silently had no audit log while the v0.25.3
  CHANGELOG claimed one. Fixed (registration line byte-matches dotnet), and `check-lockstep`
  gained a §5 `settings.json`/`settings.windows.json` registration-parity gate
  (`event|matcher|command` sets; `_comment` ignored) with a planted-drift self-test
  (`CheckLockstep.Tests.ps1` B-31 case, red-before-green: the new gate first failed the old
  synthetic fixture, then 5/5). Released via release.ps1, all gates green, both repos pushed.
- **B-25 (decision + refresh)** — done **2026-07-06** (meta + the B-31 release). D1–D7 signed
  off (**WSD-012**); `MERGE-MIGRATION-PLAN.md` refreshed against v0.25.5 (fresh §1 evidence:
  138 files/repo, 128 common, 51 EOL-normalized-identical, 10+10 stack-only; new §2.5
  machinery-disposition table; composer twin policy resolving the WSD-005 collision; honest D3;
  D7 meta-layer fate; freeze scope; archive/tag moved after Phase 6; abort rule; freeze-tag
  fidelity baseline). Adversarial review pass reproduced every measured number and surfaced
  B-31 (fixed) + the stale-execution-sections and phase-ordering hazards (folded in).
  Execution continues as **B-25-EXEC**. WSD-010 + the B-27 design doc carry retarget notes
  (v0.27.0, merged repo).
- **B-19 · B-24 · B-28 · B-30** — shipped **v0.25.4** (2026-07-05, the "small-items sweep"; all
  gates green via `release.ps1`, both repos pushed). Per item:
  - **B-28**: `build-architecture-html` twins now byte-identical — `.ps1` gained the missing head
    newline, writes LF-only BOM-less UTF-8 via .NET (the content cmdlets added BOM + host EOLs, a
    third divergence beyond the two the entry named), and both twins stamp the neutral `{sh,ps1}`
    generator name. New `tests/hooks/BuildArchitectureHtml.Tests.ps1` (byte-identical both repos;
    red-before-green: 4 failures pre-fix → 5/5 green; fixture byte-compare + join-symptom guard).
    Both repos' `architecture.html` regenerated **with the `.ps1`** — surgical diff (generator
    line + sha + content only), proving parity in real use.
  - **B-30**: `test-critic` row added to the §5 agents table in both repos + HTML regen (filed by
    the WSD-011 adversarial review; rode the release, so B-11's no-version question was moot).
  - **B-24**: **premise correction** — the entry's "installer fallback is also PowerShell" was
    stale: `install.sh:120-127` already rewires Claude Code hooks to the bash twins when the
    installing box lacks pwsh. The real residual gap is *team inheritance*: committed
    `settings.json` carries the installing machine's wiring, so a teammate without that shell
    gets no hooks silently (and the manual-copy Quick Start path never rewires). Documented as a
    README "Hook prerequisite" callout in both repos.
  - **B-19**: (a) `post-write` trigger breadth — dotnet accepts
    `.cs|.csproj|.sln|.props|.targets|.razor|.cshtml`; angular accepts `.ts` under `src/` plus
    `tsconfig*.json` anywhere (tsconfig bypasses the `src/` gate; `angular.json`/`package.json`
    excluded by design — `tsc` can't validate them, a trigger there is false comfort). All four
    twins + header comments; filter reach verified via `bash -x` trace matrix (12 inputs, all as
    designed — full build-failure path not exercisable on this box: no dotnet CLI, no
    node_modules fixture; hook suites 2×7 files, 0 failures). (b) README versioning section now
    points at the installer's real update mode instead of the `/framework-update` vaporware.
    (c) Boy Scout dedup semantics documented in `enforcement-surfaces.md` (hash of sorted finding
    set; silence = already flagged, not resolved). Bonus: fixed stale "audit trail — dotnet only
    (B-14)" row in both repos' `enforcement-surfaces.md` (missed by the B-14 release).

- **B-14** — shipped **v0.25.3** (2026-07-05). Ported the `audit-trail` PostToolUse hook to Angular
  in dual-repo lockstep. Angular now carries `.claude/hooks/audit-trail.ps1/.sh` (faithful mirror of
  dotnet — byte-identical except the artifact skip: `node_modules`/`dist`/`.angular`/`coverage`
  instead of `obj`/`bin`; UTF-8 BOM on the `.ps1`), a byte-identical seed `.claude/ai-audit.log`,
  the `PostToolUse` registration in `.claude/settings.json`, and the `postToolUse` entry
  (timeoutSec 10, no matcher) in `.github/hooks/hooks.json`. CLAUDE.md/AGENTS.md Registers lines
  gained the ai-audit sentence. Added `tests/hooks/AuditTrail.Tests.ps1` (byte-identical in both
  repos, stack-agnostic behavior + static skip/append guards, red-before-green verified);
  TwinParity auto-covers the new twin. **Removed all three `check-lockstep.ps1` audit-trail
  exceptions** (the two `$onlyInDotnet` entries + the §4 hooks.json `-notmatch 'audit-trail'`
  special-case) — the gate now enforces full parity and passes clean. Delivered by Sonnet against
  an Opus plan (`.claude/plans/2026-07-04-b14-port-audit-trail-angular.md`); adversarial review
  caught a missing trailing newline on the Angular `.ps1` (fixed → now differs from the dotnet twin
  only in the skip line). Verified: release.ps1 ran every gate green (template-checks ×2, hook
  suites ×2 with AuditTrail 10/10, check-lockstep, meta suite), both repos committed + pushed.
- **B-12** — **already resolved; no change needed** (verified **2026-07-04**, meta-only). The audit
  inspected only the *root* `.gitignore` and missed the tracked, colocated **`.claude/.gitignore`**
  (present in both repos since v0.4.0), whose `.state/` line already ignores
  `.claude/.state/last-build-ts`. Evidence: `git check-ignore -v .claude/.state/last-build-ts` →
  `.claude/.gitignore:2:.state/` in both repos; no `.state` file tracked in either. Greenfield
  `install.sh` smoke into a temp dir confirmed the installer **ships** `.claude/.gitignore` and,
  after simulating the `post-write` stamp, git ignores it. **Correction to the audit's suggested
  approach:** adding `.claude/.state/` to the *root* `.gitignore` would have been wrong — the
  installer excludes the root `.gitignore` from the consumer copy (`$metaFiles` in
  `scripts/install.ps1`/`.sh`), so the nested `.claude/.gitignore` is the *only* vehicle that
  reaches consumers, and it is already correct.

> **Post-hoc review 2026-07-04 (Fable):** the P1 (v0.25.1) and P2 (v0.25.2) bands were
> independently re-verified — all gates re-run green (template-checks ×2, check-lockstep, hook
> suites 0 failures, meta suite), both repos clean and pushed, every claimed fix reviewed at diff
> level and confirmed genuine (incl. the epoch fix's graceful handling of stale fractional stamps
> from the buggy version). Only finding: `CheckLockstep.Tests.ps1` was created without a UTF-8
> BOM — folded into B-10. Accepted; no re-release needed.

- **B-11** — done **2026-07-04** (docs accuracy, **no version/CHANGELOG** — user-approved: invariant
  #7 is scoped to shipped *behavior*). Corrected every human-facing bootstrap pass-count reference to
  match each repo's `bootstrap.md`. **Scope was larger than the audit stated** — the drift was in
  *both* repos (angular said A1–A6/"six" but runs A1–A7), and the adversarial review found two the
  audit + plan missed: both repos' `.github/prompts/rebootstrap.prompt.md`, and angular's
  `bootstrap.md:2` frontmatter description ("eight"→"seven"). Files: dotnet — `README.md`,
  `docs/ARCHITECTURE.md` (×2 rows), `.github/prompts/rebootstrap.prompt.md`, regenerated
  `docs/architecture.html`; angular — same four + `.claude/commands/bootstrap.md:2`. **HTML regenerated
  with the `.sh` twin, not `.ps1`** (see B-28 — the `.ps1` twin emits divergent bytes and would have
  injected a generator-comment flip + `<script>`-tag change into the diff). Verified: exhaustive grep
  sweep (zero stale counts, both repos), content-only HTML diffs, all gates green (template-checks ×2,
  check-lockstep, hook suites 0 failures, meta suite). Canonical `commands/bootstrap.md` bodies,
  `bootstrap.prompt.md`, and the `bootstrap-pass` agents were already correct and left untouched.
- **B-10** — done **2026-07-04** (meta-only, no version/CHANGELOG). Added UTF-8 BOMs to 3 offenders (`.claude/scripts/check-lockstep.ps1`, `release.ps1`, `.claude/hooks/tests/CheckLockstep.Tests.ps1`). New `.claude/hooks/tests/WorkspaceBom.Tests.ps1` recurrence gate: asserts all root `.claude/` `.ps1` files carry a BOM on every meta-suite run, vacuous-pass guard included. Meta suite wired into `release.ps1` so the gate runs at every future release.
- **B-13** — done **2026-07-04** (maintainer memory, no repo change). `hook-output-semantics.md`
  updated: "shipped docs stale" removed; now records the v0.25.1 live-canary results (CLI 1.0.68
  consumes `userPromptSubmitted` additionalContext, does NOT consume `postToolUse`; folder-trust
  prerequisite; VS Code consumption still unverified). `self-sufficiency-roadmap.md` and
  `fable-exit-backlog.md` refreshed in the same pass.
- **B-02** — shipped **v0.25.1**. `post-write.ps1` epoch switched to
  `[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()` (both repos), killing the PS 5.1 comma-decimal
  `OverflowException` and the UTC/local twin-skew. Added `tests/hooks/PostWrite.Tests.ps1`
  (host-independent, red-before-green; crash reproduced under de-DE during the fix).
- **B-01** (minimum doc-honesty fix) — shipped **v0.25.1**. `enforcement-surfaces.md` gained the
  shell-write caveat on the Write hard-blocks row; `CLAUDE.md`/`AGENTS.md` Verification-Rule-7
  parenthetical scoped to editor/file writes. *Optional guard hardening (register on the terminal
  tool + content-sniff) was **deferred** by decision — file as a follow-on; false-positive risk +
  needs its own fixtures and a workspace-decision record.*
- **B-03** — shipped **v0.25.1**. Live-verified via sentinel canary on **Copilot CLI 1.0.68**:
  `userPromptSubmitted` additionalContext **is** consumed; `postToolUse` additionalContext is
  **not** consumed by the model; repo hooks fire **only after folder trust** (no non-interactive
  trust flag). Updated `enforcement-surfaces.md` Status notes + corrected the false
  "consumes postToolUse feedback" comment in the `post-write` twins. **Follow-ons this surfaced:**
  the `post-write`/`audit-trail` Copilot postToolUse leg is dead → fold into the B-08 matrix rows
  and the B-09 post-write demotion; the folder-trust prerequisite → `framework-doctor` (B-16).
  VS Code agent-mode consumption still unverified (canary covered the CLI only).
- **B-09** — shipped **v0.25.2**. Fixed the `post-write.ps1` `$tn=$null` misrouting (pre-declared
  `$tn=''` so malformed/env-fallback build failures hit Claude's exit-2 branch, matching the `.sh`
  twin). Added `tests/hooks/PostWriteRouting.Tests.ps1` (static `$tn` guard + build-free twin
  agreement). Note: post-write's *build-failure* routing can't be exercised in the byte-identical
  `tests/hooks` dir (stack-specific `.cs`-vs-`.ts` build); boy-scout decision-output likewise — both
  covered only for robustness there. B-02's epoch bug (the other divergence B-09 named) shipped in 0.25.1.
- **B-04** — shipped **v0.25.2** (maintainer gate). `check-lockstep` enumerates the union of both
  repos for every IDENTICAL class (missing-in-dotnet now fails too), throw-safe on missing dirs.
  Self-test: `.claude/hooks/tests/CheckLockstep.Tests.ps1` (green control + planted angular-only file).
- **B-06** — shipped **v0.25.2** (maintainer gate). Replaced the static `$sharedSkills` list with a
  computed rule: any skill present in both repos is shared-and-required; only stack-specific skills are
  declared. `enforce-standards` now enforced. Self-tested.
- **B-05** — shipped **v0.25.2**. Unified `post-write` `timeoutSec` to 120 (angular was 60; WSD-009)
  and added a structured `hooks.json` registration-parity gate to `check-lockstep` (audit-trail the
  one dotnet-only exception). Self-tested (planted timeout drift).
- **B-07** — shipped **v0.25.2**. `template-checks.ps1/.sh` gained an EOL-normalized `.claude/skills`
  ↔ `.github/skills` mirror gate (runs in both repos' `template-ci.yml`). Trap recorded in LEARNINGS:
  the gate must EOL-normalize (core.autocrlf) and `[IO.File]::ReadAllText` needs absolute paths
  (process-CWD ≠ `Set-Location`).
- **B-08** — shipped **v0.25.2**. `enforcement-surfaces.md` gained three capability rows (build/
  type-check feedback, Boy Scout stop-nudge, audit trail) encoding the B-03 live findings — Copilot
  does not consume `postToolUse` additionalContext (post-write feedback not surfaced), while
  `audit-trail`'s file side-effect still fires.
