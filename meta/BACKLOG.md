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
> 1. ~~**B-45**~~ and ~~**B-47**~~ — both **done 2026-08-01**, see the Done section. B-45 shipped in
>    a stronger form than written: enforced by `release.ps1`'s review ledger rather than by prose,
>    after an adversarial pass argued a prose-only version would not bind. B-47 landed MIT root-only;
>    the dist-travel half is deferred and filed separately.
> 2. **B-42** (field pilot) — start it early because its value is elapsed time; it runs in the
>    background while other items proceed, and its evidence should re-prioritize everything else.
> 3. **B-41** (agent-behavior harness) — the flagship; absorbs B-23 and B-29.
> 4. **B-49** (quarterly live-fire drill) — build the drill kit once B-41's first scenarios exist;
>    it becomes the recurring vehicle that *executes* B-43 (and reviews B-44) every quarter.
> 5. Then interleave: **B-15** (CI recipe) from the deferred list — it is
>    the consumer-lifecycle half of the same story — plus **B-44/B-46/B-48** as capacity allows.

### B-41 · Agent-behavior eval harness — close the "prose steers a model" blind spot
**Effort:** L · **Invariants:** #5 #6 #7 · absorbs B-23 and B-29

**Phase 1 in PR #2:** the maintainer-only Claude harness, typed stream-event graders, archived-
redirect fixture, release reminder, and Haiku planted-defect cases are implemented. The first live
results produced before the adversarial review used raw-transcript graders and are explicitly
invalidated in `meta/eval-results.md`; re-run the eight cases before claiming behavioral evidence
or closing B-29.

**Still required before DONE:** add the Copilot CLI leg where scriptable (including trusted-folder
setup and its different deny/additionalContext shapes); settle B-23's open question about why the
older response-only `tests/evals/` suite ships to consumers; then record threshold-based results
from both available hosts. Do not close the item from Claude-only evidence.

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

### B-50 · Copilot CLI 1.0.70 now consumes `postToolUse` context — update the shipped matrix
**Effort:** S · **Priority:** P2 documentation/capability honesty · **Invariants:** #3 #5 #7

**Found by:** B-49 drill #0 host recertification, 2026-07-17. The trusted-folder sentinel canary
performed a real write and the model returned the out-of-band `B49_POST_TOOL_4MV2` token injected
only by `postToolUse`. This reverses the live 1.0.68 observation on which
`docs/enforcement-surfaces.md` currently says the leg is dead. Re-run once in an isolated canary,
then update the shipped matrix/status note and any hook comments that demote Copilot post-write
feedback. Normal release path; do not fold the shipped change into the meta-only drill PR.

### B-52 · Verify Copilot CLI fires *both* `userPromptSubmitted` hooks and injects both payloads (v0.33.0 Boy Scout parity claim)
**Effort:** S · **Priority:** P2 capability honesty · **Invariants:** #5 · **execution vehicle: B-49's quarterly recert / B-43**

**Why:** v0.33.0 registered a **second** `userPromptSubmitted` hook (`boy-scout-check`, after
`route-prompt`) in `.github/hooks/hooks.json` to bring the Boy Scout nudge to Copilot, and updated
`docs/enforcement-surfaces.md` to claim "Guaranteed (soft), CLI ≥ 1.0.65" for the Copilot CLI Boy
Scout row. The prior live canary (2026-07-04, CLI 1.0.68) only ever verified a **single**
`userPromptSubmitted` hook (`route-prompt`) is consumed. Whether Copilot CLI runs **multiple**
`userPromptSubmitted` entries and merges **all** their `additionalContext` into the model-facing
prompt is **unverified** — if it honors only the first (or last), the shipped Boy Scout-on-Copilot
guarantee is false and the matrix row overclaims (the exact honesty failure the doc forbids at its
own line 34). VS Code agent-mode consumption remains unverified regardless (shared with B-43).

**Do:** a two-hook sentinel canary (reuse the B-03/B-43 canary design). In a trusted temp folder,
register two `userPromptSubmitted` hooks in `.github/hooks/hooks.json`, each emitting a **distinct**
out-of-band token (present in no file) via the dual JSON shape
(`additionalContext` + `hookSpecificOutput.additionalContext`); run
`copilot -C <dir> --allow-all-tools -p "echo any CANARY-XXXX tokens you were given"` and confirm the
model echoes **both** tokens. Both → re-date the matrix row as verified; one/neither → apply the
plan's documented fallback (fold Boy Scout into `route-prompt` without its early-exit) and correct
the `enforcement-surfaces.md` row. Prereq (verified 2026-07-20): the temp folder must be in
`~/.copilot/config.json` `trustedFolders` or repo hooks don't load in `-p` mode; and `hooks.json`
Windows paths must use forward slashes (backslashes are an invalid JSON escape — observed rejection).

**Blocked (2026-07-20, re-confirmed same day):** attempted live twice; the canary is built and
**committed at `meta/canaries/b52-copilot-two-hook/`** (two env-token hooks so the tokens are in no
file; run recipe + result-reading in its README), and folder-trust confirmed loading repo hooks in
`-p` mode, but the Copilot account hit its **monthly quota** (`402 Payment required`,
`AI Credits 0`) so no model turn could run — including a 2026-07-20 retry after the CLI drifted to
1.0.71. **Next action: re-run the committed canary once monthly Copilot credits reset (~Aug 2026)
or on another account** — no rebuild needed. Until then the v0.33.0 CLI Boy Scout row rests on
reasoning, not the live observation its wording implies.

**UNBLOCKED 2026-08-01.** The monthly quota has reset: a trivial probe
(`copilot --allow-all-tools -p "Reply with exactly: PROBE-OK"`, CLI 1.0.71) completed a real model
turn — `PROBE-OK` echoed, exit 0, `AI Credits 2.98` — where every 2026-07-20 attempt died at `402 /
AI Credits 0`. **What this observation does and does not establish:** it establishes that the
account can run a model turn. It does **not** run the canary — that still needs the interactive
folder-trust step (no non-interactive flag exists), which the probe deliberately skipped. So the
kit is ready and the blocker is gone; the two-hook result is still unobserved. Run it before the
next monthly cycle. Hazard for whoever runs it: on this box `copilot.cmd` fails with `'"node"' is
not recognized` because the session `PATH` is the corrupted one — prepend
`C:\Program Files\nodejs` (and invoke `copilot.cmd` by its absolute path,
`%APPDATA%\npm\copilot.cmd`, since it is not on `PATH` either).

**Not:** don't relax the `enforcement-surfaces.md` wording pre-emptively — it already keeps the VS
Code hedge; this item either upgrades the CLI row to verified or triggers the fallback. Cross-links:
B-43 (recert cadence — run this in the same quarterly slot), B-50 (the sibling `postToolUse`
capability-honesty item from drill #0), B-03 (original canary design).

### B-55 · Vendor-behavior facts are restated across ~6 shipped surfaces with no single source
**Effort:** M · **Priority:** P2 doc truth · **Invariants:** #5, #6

**Why:** claims about what Copilot/Claude actually do are duplicated in
`docs/enforcement-surfaces.md`, the `hooks.json` `_comment`, the three stack `README.md` hook tables,
all six `boy-scout-check` headers, and `docs/presentation/framework-technical.html`. When Copilot
shipped `agentStop`, **five** of those surfaces still asserted "Copilot has no equivalent event", and
a README asserted "Copilot does not consume hook stdout for this event" while
`enforcement-surfaces.md` said the opposite **in the same commit**. Separately, a factually wrong
claim (a Stop hook's `decision:"block"` `reason` "is shown only to the user" — it is shown to Claude;
the confusion was with `stopReason`) survived in six hook headers for months. `DocTruth` covers
internal repo facts (paths, version stamps); nothing tests prose about *external* behavior.

**Do:** pick one canonical home for vendor-capability claims (`enforcement-surfaces.md` is the
natural one) and have the other surfaces point at it rather than restate it. Where a restatement is
genuinely load-bearing, back it with a small machine-checkable registry (event name → minimum
version → date verified) that a gate can diff against the shipped surfaces. Cheap first step: a gate
that greps shipped files for a denylist of *superseded* claims, so the next vendor change fails a
gate instead of quietly making six files wrong.

### B-56 · Host-dependent capability probes make gate outcomes machine-dependent — **DONE 2026-08-08, see Done**
**Effort:** S · **Priority:** P2 · **Invariants:** #3

**Why:** `framework-doctor`'s "Guard JSON parser" row asked PowerShell's `Get-Command jq` (Windows
PATH + PATHEXT) while *reporting on* `guard.sh`, which runs under bash. On a machine where `jq` is an
extensionless binary, the twins disagreed (PS `[MISSING]`, bash `[OK]`), the twin-parity test failed,
and — because `release.ps1` gates on the hook suites — **every release was blocked** until it was
diagnosed. Fixed for that row in v0.35.0 by probing from bash's vantage point, but the class is open:
a check that asks the wrong shell about another surface's capability yields a different verdict per
machine, and the fixtures exercise the real host rather than a pinned environment.

**Do:** audit the doctor's remaining probes for the same shape — where a check is about surface X's
capability, ask X. Pin the probe environment in the twin-parity fixtures so a maintainer's local tool
layout cannot decide whether a gate passes.

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

### B-59 · The guard's test harness cannot detect an **inert** check — twins can silently disagree
**Effort:** M · **Priority:** P2 · **Invariants:** #3 #5 · needs a WSD record

**Why:** `TwinParity.Tests.ps1` compares the *decisions* the two twins reach on fixture inputs. It
cannot see a check that has stopped working, because an inert check and a check that legitimately
didn't match are indistinguishable from the outside. Three independent mechanisms can make a check
inert, all found while shipping B-57 (v0.37.0), all verified by execution:

1. **`grep -Eq … && reasons+=(…)` fails OPEN — 20 sites in `guard.sh`.** `grep` exits 2 on a bad
   regex, an unsupported construct, or an unreadable input. The `&&` treats that identically to
   "no match", so the reason is never appended and the write is allowed. A first-draft B-57 pattern
   did exactly this — `[\](,]` is invalid POSIX ERE — which would have shipped a check that blocks
   on `.ps1` and does nothing on `.sh`. Nothing in CI would have failed, because no fixture case
   exercised it on the erroring twin.

2. **`-match` is case-insensitive; `grep -E` is not.** Verified across **every existing pattern**,
   not just the new one — `#PRAGMA WARNING DISABLE`, `[FACT(Skip="x")]`, `ASSERT.True(true)`,
   `// ESLINT-DISABLE-next-line`, `// @TS-IGNORE` all block on `guard.ps1` and pass on `guard.sh`.
   **No live exploit today**: C#, ESLint directives, and TS pragmas are all case-sensitive, so every
   divergent input above is invalid code the `.ps1` side merely over-blocks. The danger is the *next*
   pattern — B-57's `Ignore` was the first to collide with a legitimate lowercase identifier
   (`Handle(evt, ignore, ctx)`), and it needed `-cmatch`. There is no stated policy, so the trap is
   re-armed for whoever adds pattern #21.

3. **Fixture content does not resemble the input.** Every `guard-cases.ps1` entry is a one-line
   snippet; the hook receives whole file contents. A failure mode that only manifests across lines
   is untestable by construction. B-57's patterns happened to be correct under `(?m)`/line-oriented
   `grep`, but that was confirmed by an ad-hoc check, not by the suite.

**Do:** (a) make grep errors loud — check the exit code explicitly (0 match / 1 no-match / 2 error →
fail the hook or emit a diagnostic) rather than `&&`-chaining, or wrap the idiom in one helper used
by all 20 sites; (b) decide and document a case-sensitivity policy for guard patterns, sweep the
existing ones to `-cmatch` where the pattern contains a bare identifier, and add adversarially-cased
fixture cases so `TwinParity` can actually see the divergence; (c) convert several fixtures to
realistic multi-line file bodies; (d) add a self-test that plants a deliberately invalid regex in each
twin and asserts the suite goes red — the harness must be shown to catch an inert check. Same
portability class, worth sweeping together: the NUnit CI grep shipped in `enforce-standards` step 2
uses GNU-only `\s`/`\b`, which are literal on BSD/macOS grep — it works on typical Linux CI but is
the exact trap this entry is about, and a POSIX-safe form
(`'^[[:space:]]*\[.*[^A-Za-z]Ignore[^A-Za-z]'`) is verified equivalent.

### B-60 · Skill step cross-references rot silently when a numbered list changes
**Effort:** S · **Priority:** P3 hygiene

**Why:** skills cross-reference their own steps in prose — `add-tests` alone has "financial-domain
invariants from **step 4** above" and "apply **step 6**'s red-check to every test". Markdown
auto-renumbers ordered lists, so changing the first item's number silently repoints every such
reference. This was caught by hand during B-57 (an implementer renamed step 1 to 0, leaving
`0,2,3,4,5,6,7`, which renders as `0,1,2,3,4,5,6` and shifts both cross-references onto the wrong
steps) in all three stacks. Nothing gates it, and the failure is invisible in the diff — each line
looks locally correct.

**Do:** a small check in `validate-dist` (or `template-checks`): for each shipped skill/command, parse
the ordered-list labels, confirm they are contiguous from 1, and confirm every `step N` reference in
the prose resolves to an existing item. Red-test by planting a gap. Cheap, and it protects a
correctness property no human reliably re-verifies.

### B-58 · `CLAUDE.md` ↔ `AGENTS.md` skills list is ungated and has already drifted

`template-checks.{ps1,sh}` mirrors exactly four sections — `## Verification Rules`, `## Leanness`,
`## SOLID`, `## Boy Scout Rule` (plus `### 1. Classify the intent`). The skills list under
`## Common Tasks` is **never compared**, and it had already drifted in all three dists while every
gate was green. Found while shipping B-57, which edits exactly those lines:

```
dist/dotnet/CLAUDE.md:134   - `add-tests` — add unit/integration tests following project patterns (xUnit + `WebApplicationFactory`)
dist/dotnet/AGENTS.md:100   - `add-tests` — add tests following project patterns (xUnit + `WebApplicationFactory`)
dist/angular/CLAUDE.md:133  - `add-tests` — add specs following project patterns (TestBed + `HttpTestingController`, harnesses, …)
dist/angular/AGENTS.md:99   - `add-tests` — add tests following project patterns (Jasmine/Karma or Jest spec + HTTP mocks)
```

Angular's pair had drifted far enough to name a *different technology* on each side. B-57 fixed the
lines by hand and hand-diffed them; nothing stops them drifting again.

**Do not add `## Common Tasks` to the verbatim mirror list** — that was the first idea and it is
wrong. A section diff shows `AGENTS.md`'s Common Tasks is *deliberately* condensed: shorter
descriptions throughout and the `/bootstrap` paragraph dropped. A verbatim gate goes red in all three
dists and would force rewriting a section that is intentionally different.

The right gate compares the **set of backtick-quoted skill slugs** in each file, ignoring the prose
around them: catches "a skill was added/removed on one side only" without fighting the intentional
condensation. It does *not* catch description drift (the actual B-57 defect), so consider whether a
second, looser check is worth it — e.g. flag when one side names a technology token the other does
not. Red-test per `DEVELOPING.md`: plant a slug on one side only, show non-zero exit, then the clean
pass. Both twins.

### B-61 · Twin behavioural parity does not cover shipped `scripts/`, only `.claude/hooks/`
**Effort:** M · **Priority:** P1

**Why:** `tests/hooks/TwinParity.Tests.ps1` genuinely runs both twins against fixtures and diffs
stdout/stderr, but its coverage is scoped to hooks: guard, boy-scout-check, and the empty/malformed-
stdin cases. `framework-doctor.ps1` and `framework-doctor.sh` returned **opposite verdicts on the
same machine at the same moment**: OK vs MISSING, exit 0 vs exit 1. No gate noticed. That divergence
was the only reason the bug was found; running either twin alone showed a clean bill of health. The
doctor is the diagnostic every other honesty claim rests on.

**Do:** extend the behavioural twin comparison to the shipped `scripts/` twins, framework-doctor
first.

### B-62 · No gate validates the hook registrations we ship
**Effort:** S · **Priority:** P1

**Why:** a bare interpreter name shipped in `dist/*/.claude/settings.json` for many versions with no
check. `validate-dist` has `no-meta-leak` and `no-dead-instruction`, but nothing inspects whether a
hook registration can actually start. `settings.windows.json` ships a bare `powershell` and carries
the same exposure.

**Do:** add a `validate-dist` check that fails on a bare interpreter name in a shipped settings
file; red-test it by planting one.

### B-63 · Audit every capability probe for vantage-point validity — **DONE 2026-08-08, see Done**
**Effort:** M · **Priority:** P2

**Why:** this is the **second** instance of the class; the first was a jq probe checking from
PowerShell's vantage point instead of bash's. The remaining `Invoke-BashProbe` use for the Guard JSON
parser row still has it: it spawns bash as a child of the doctor, so that bash inherits the doctor's
`PATH`, not the host's. Measured: from the host's shell `pwsh` was not found; from a doctor-spawned
bash it **was** found. It does not bite today only because jq's location does not vary the way
pwsh's does. A comment now warns against reuse, but the flaw is unfixed.

**Do:** enumerate every capability probe across hooks, scripts and gates; for each, state which
environment it observes and which one actually matters. Where the relevant environment is
unobservable, report CANT-VERIFY rather than guessing, or remove the dependency.

### B-64 · Deterministic diagnostics have no planted-defect tests
**Effort:** M · **Priority:** P2

**Why:** framework-doctor shipped three independent defects that all reported success, and its
existing suite passed throughout because it tested happy paths. The root `CLAUDE.md` Definition of
done already requires red-testing for composer/gate scripts, but the diagnostics themselves were
never held to it.

**Do:** for each gate and diagnostic, add at least one test that plants the defect class it exists
to catch and asserts the non-zero exit or the honest row — the discipline B-41 applies to agent
behaviour, applied to the deterministic layer.

### B-65 · Restore reliable post-bootstrap discovery of `docs/defaults.md`
**Effort:** S · **Priority:** P2

**Why:** every inbound pointer is conditional on being un-bootstrapped: the `CLAUDE.md`
`BOOTSTRAP_PENDING` comment and `add-tests/SKILL.md`. `bootstrap.md` instructs the model to delete the
`BOOTSTRAP_PENDING` marker and the placeholder line, severing the only pointer. `session-start` and
`route-prompt` reference the file nowhere. Every bootstrapped consumer repo therefore carries a
greenfield-conventions document that nothing can route a model to. This also means on-demand `docs/`
files are a weaker delivery tier than Instructed, and `enforcement-surfaces.md` has no row for it.

**Do:** decide whether `defaults.md` should be reachable post-bootstrap or explicitly retired at
bootstrap, and add the missing tier to `enforcement-surfaces.md`.

**Amended 2026-07-31 after the Phase A experiment:** the unreachability framing above is too strong
and is superseded by measurement. Agents do reach on-demand `docs/` files in bootstrapped repos; in
one valid no-pointer run, the agent opened the file unaided. Removing the pointer therefore
plausibly reduces the *reliability* with which guidance is found rather than making the file
unreachable. Keep this item open: restoring the pointer that `/bootstrap` deletes is cheap and
still worth doing. The causal question—whether the pointer increases load probability—needs more
runs before the framework asserts anything about pointers in shipped documentation. For the Angular
work, a pattern catalogue in `docs/` is a viable delivery location on this evidence.

### B-66 · The Angular stack ships no forms guidance at all
**Effort:** M · **Priority:** P2

**Why:** case-sensitive grep across `src/stacks/angular/` for `ControlValueAccessor`, `NgControl`,
`FormControl`, `FormGroup`, `FormBuilder`, `Validators`, `ngModel`, `NG_VALUE_ACCESSOR`,
`formControlName`, and `ReactiveFormsModule` returns no matches; likewise `ng-content`,
`ngTemplateOutlet`, `hostDirectives`, `defer`, `viewChild`, `contentChild`, and `toSignal`. Forms are
the largest surface of a line-of-business Angular app. This is the standing defect behind the first
field report the framework has ever received.

**Do:** the immediate transcript-independent piece is a Forms section in the Angular conventions:
reactive over template-driven for new code, typed forms, where validators live, and when a component
becomes a `ControlValueAccessor`. State the `NG_VALUE_ACCESSOR`-provider vs `NgControl`-injection
trade-off honestly rather than naming either an anti-pattern, and name the double-registration hazard
(providing both causes a circular-DI runtime error).

**Not:** do not ship a broad pattern catalogue before the delivery-tier question in B-65 is
answered.

**PARTIALLY DONE — delivery half shipped as v0.40.0 (2026-07-31); the guidance half is deliberately
still open.** What shipped: `/bootstrap` and `/adopt` now author a `Forms` subsection (both stacks,
monorepo siblings included), `/bootstrap`'s A3 pass probes for it, `docs/defaults.md` gained a
**detect-only** `### Forms` section in the `### SSR / Hydration` house style, and the two surfaces
asserting `@Input`/`@Output` **only** (`copilot-instructions.md`, `defaults.md` § Component Design)
were carved out. That closes the delivery-tier problem: the reason the guidance could not reach a
bootstrapped repo was that nothing wrote `Conventions > Forms`, and the `add-component` skill
subordinates itself to `CLAUDE.md > Conventions` at its first line — so routing around the tier was
never going to work.

What did **not** ship, and why: the prescriptive greenfield block (reactive-over-template-driven,
typed forms, the `NG_VALUE_ACCESSOR`-vs-`NgControl` trade-off table, the double-registration hazard)
and an `add-component` form-control branch. The `angular-form-control` baseline **passed with no
forms guidance shipped at all** — the agent self-injected `NgControl`, set `valueAccessor = this`,
used `setDisabledState` rather than an `@Input() disabled`, and commented that this avoids the
circular-DI `forwardRef`. Writing prescriptive guidance whose only instrument is green before the
fix would be shipping on faith. **Resume this half once B-72 re-specifies the probe** so it states
the business need without naming the mechanism, and shows where the model actually fails. The
technical content is drafted and reviewed in
`<home>\.claude\plans\let-s-go-ahead-and-sorted-quill.md` (including three precision traps:
qualify circular DI to the *self-referencing* `useExisting` provider; do **not** claim "Angular
warns" about `@Input() disabled` — it collides with `setDisabledState()`, which is a different
thing; signal inputs are read-only so a CVA's *value* cannot be an `input()`).

Scope note: `bootstrap.md`/`adopt.md` were taken deliberately even though B-66 deferred the
delivery-tier question to B-65. B-65 is about restoring the pointer `/bootstrap` *deletes*; this was
about what `/bootstrap` *writes*. Adjacent, not the same.

### B-67 · `no-dead-instruction` does not validate markdown link targets — **DONE 2026-08-08, see Done**
**Effort:** S · **Priority:** P3

**Why:** the check greps for script invocations and asserts the script resolves; it has no notion of
markdown links, so a doc-to-doc reference can dangle in all three dists with no gate firing.

**Do:** extend it to markdown link targets; red-test with a planted dangling link.

### B-68 · `context-footprint` hard-codes the Instructed file list
**Effort:** S · **Priority:** P3

**Why:** the instructed group iterates a literal list (`FRAMEWORK-CONTEXT.md`, `docs/defaults.md`,
`docs/wiki/INDEX.md`), so any newly added `docs/*.md` is measured by nothing and silently escapes the
budget gate.

**Do:** derive the list, or require new files be added deliberately. Twin edit, both `.ps1` and
`.sh`.

### B-69 · `tests/evals/` scoping limitation is not written down
**Effort:** S · **Priority:** P3

**Why:** `run_evals.py` builds its system context from exactly `CLAUDE.md` and
`FRAMEWORK-CONTEXT.md` and calls `messages.create` with no `tools` parameter. It can therefore never
see `docs/`, follow a pointer, or observe tool use. During the v0.38.0 session this was briefly
mistaken for a viable way to measure whether a `docs/` file changes model behaviour. It is not, and
a null result would have been misread as the wording being wrong rather than the instrument being
blind.

**Do:** state the limitation at the top of `tests/evals/README.md` and point anything needing
tool-use or file-read evidence at `.claude/evals/`.

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

### B-71 · Silently skipped tests make a green local suite weaker than it looks — **DONE 2026-08-08, see Done**
**Effort:** S · **Priority:** P2

**Why:** the FrameworkDoctor suite prints `[skip] Windows PowerShell 5.1 compatibility --
powershell.exe unavailable on this host` and still summarises as green. On the maintainer machine
`powershell.exe` cannot be resolved because the session `PATH` is missing System32, so the one test
that guards meta-invariant #4's entire rationale — Windows PowerShell 5.1 mis-parses BOM-less UTF-8
— never runs locally. A `[skip]` line scrolls past inside an otherwise-green summary and reads as
benign. The same machine condition is what made the v0.38.0 hook defect possible in the first
place, so this is not hypothetical: local coverage silently shrank exactly where the invariant
needed it.

**Do:** distinguish an ordinary skip from a skip of an invariant-guarding test. Surface the latter
prominently in the suite summary — a count and a named list, not just an inline line — and consider
making the summary state which invariants went unexercised on this host. Cross-reference
framework-doctor's CANT-VERIFY tier: the honest-reporting pattern already exists in this repo and
should apply to the test harness too.

**Not:** do not make the skip a hard failure; a host genuinely without Windows PowerShell should
still be able to run the suite.

**Live evidence, 2026-08-01 (shipping B-61) — this entry is no longer hypothetical.** The
FrameworkDoctor suite reported `15 passed, 0 failed, 1 skipped` on the maintainer box all through the
v0.41.0 work; the skip was the Windows PowerShell 5.1 case, because `Get-Command powershell.exe
-CommandType Application` cannot resolve it when the session `PATH` lacks System32. In the *same
session* a **5.1-only** harness defect was found (see the v0.41.0 RCA) — the exact host whose coverage
had silently lapsed. `powershell.exe` was in fact present and usable at
`$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe`; only PATH resolution failed. So
besides surfacing invariant-guarding skips prominently, the probe should fall back to the well-known
absolute path before declaring the host incapable — a skip caused by a broken PATH is not the same
fact as a host without 5.1, and reporting them identically is what let the gap persist.

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

### B-76 · Nothing checks that a shipped doc's description of a command matches that command
**Effort:** M · **Priority:** P2 doc truth · **Invariants:** #6 · found 2026-08-01 shipping v0.42.0

**Why:** three false claims were shipping simultaneously, each asserting a command does maintenance
it does not do:

- `FRAMEWORK-CONTEXT.md` and all three `README.md`s: *"'Detected Framework Packages' and 'Known
  Hazard Areas' are also refreshed by `/docs-sync`"*. `grep -i hazard` over `docs-sync.md` returned
  **nothing**. The packages half was true, which is what made the sentence survive reading.
- `rebootstrap.md`'s own frontmatter `description`: *"refresh conventions, **hazards**, and mined
  skills"*. `grep -i hazard` over its body returned **only that line**. This is the highest-salience
  of the three — the description drives model routing and is what the developer sees in the command
  picker.
- `.github/prompts/docs-sync.prompt.md` enumerated the docs-sync workflow as four steps, omitting
  Step 4 (FRAMEWORK-CONTEXT) and the AGENTS.md/rails half of Step 2 — and it is a `src/core` file,
  so it ships to all three dists as the only workflow summary Copilot gets.

The first two survived from introduction to v0.41.0. `no-dead-instruction` matches script
invocations only (`pwsh|bash|powershell <path>.{ps1,sh}`) and asserts the file resolves; `DocTruth`
covers authoring-repo facts (paths, version stamps). Neither has any notion of *"this prose
describes that command"*.

**Do:** add a gate covering **all three shapes** — a check aimed only at the first would have caught
one of three:

1. **Third-party attribution** — `refreshed by /X`, `checked by /X`, `asserted by /X`: assert the
   named command's body mentions the subject noun.
2. **Frontmatter self-description** — assert each `description:` verb-phrase subject appears in its
   own body.
3. **Step enumeration** — where a doc lists another doc's steps, assert count and order match.

Red-test each shape with a planted false claim.

**Cross-links:** B-55 (same family, but scoped to *external vendor* behavior claims rather than our
own commands), B-67 (`no-dead-instruction` blind to markdown link targets — the third blind spot in
the same check). Consider closing all three as one hardening pass on that check.

**Not swept:** other `checked by /X` / `asserted by /X` phrasings across `dist/*` were not audited
when the three above were fixed — only the exact `refreshed by /docs-sync` string was.

---

### B-77 · Hazard-row references have no machine check — only their age is measured
**Effort:** S · **Priority:** P2 · found 2026-08-01 shipping v0.42.0

**Why:** `session-start.{ps1,sh}` warns when a `Known Hazard Areas` row's `Reviewed` date passes 90
days. It reads the `Area / file(s)` cell only to skip the placeholder row; the logic is purely
`$reviewed -ge $cutoff` — **age, never content**. So a `[VERIFIED]` row pointing at a file deleted,
renamed, or extracted months ago stays fresh-looking indefinitely, while `CLAUDE.md` instructs the
agent to consult that list for blast radius on every non-trivial task. A row pointing at nothing is
false confidence, which is exactly what the table's own warning says a stale hazard map causes.

v0.42.0 gave `/rebootstrap` Phase 3c a referential-drift pass, but that is model-executed and
developer-initiated — there is no deterministic equivalent, and no gate fails when a row dangles.

**Do:** add `hazard-check.{ps1,sh}` modelled on the existing `wiki-check.{ps1,sh}` — same problem
shape (an optional artifact carrying epistemic status), same wiring (invoked from
`docs-sync-check`), same test shape (`WikiCheck.Tests.ps1`). Validate row shape, a required status
token, an ISO `Reviewed` date, and that each path named in `Area / file(s)` resolves. **It must
never set or upgrade a status** — that is the human's, per WSD-027. Twin edit; red-test with a
planted dangling path.

---

### B-78 · Warehouse-map staleness has four populations no signal reaches
**Effort:** S · **Priority:** P3 · found 2026-08-01 shipping v0.42.0

> **DONE in v0.51.0.** `warehouse-map-check` reaches current/missing/stale/declined/not-applicable
> states directly and through advisory docs-sync output; the load recipe requires current map or
> equivalent live evidence. Pure-SQL adoption is covered with B-115.

**Why:** v0.42.0 added a freshness caveat inside `add-warehouse-load` (fires when the map is read)
and a `/docs-sync` bullet gated on `docs/warehouse-map.md` existing. Both are structurally blind to
repos that have **no** map but should:

- bootstrapped on v0.31.0–v0.34.1, before the Phase-4 nudge existed — and `/bootstrap` is
  `disable-model-invocation: true`, so it is not re-run;
- the developer declined the offer — `map-warehouse` says "offer, don't force";
- the repo **grew** a warehouse after bootstrap, where `/bootstrap` Phase 3a's three-way rule
  already deleted both warehouse skills, so nothing warehouse-shaped remains to fire at all;
- `/adopt` — the brownfield path an existing warehouse actually takes — never mentions warehouses,
  and declares its own Phase 8 the sole emitter during adoption.

Compounding it: the Phase-4 nudge is a bullet in a chat report. It leaves no artifact, so it is a
one-shot mention, not a durable pointer.

**Do:** decide which of these deserve a signal — this is a scoping question, not an obvious fix.
Cheapest candidate is a durable pointer written into `CLAUDE.md > Conventions > Data Access` when A2
finds warehouse signals, which survives where a report bullet does not; second is a warehouse row in
`/adopt`'s Phase-8 checklist.

**Stakes raised 2026-08-07.** `add-warehouse-load`'s new dimension-binding step tells the reader to
search `docs/warehouse-map.md`'s table inventory for the business key before creating a dimension. A
missing or stale map now costs a *wrong write* — a duplicate dimension — where before it cost a wrong
read. Every population listed above inherits that. B-115 closes the `/adopt` one as a side effect of
making a warehouse-only repo adoptable at all; the other three are still unreached.

---

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

### B-80 · `release.ps1`'s `git add -A` commits whatever is sitting in the working tree
**Effort:** S · **Priority:** P2 release integrity · **Invariants:** #7 · found 2026-08-01 after v0.43.0

**Why:** the release stages with a blanket `git add -A` (step 5). That is deliberate — the release
commit must carry the stamps, the rebuilt `dist/`, and the footprint baseline together — but it also
sweeps in anything else present. A git worktree created under `.claude/worktrees/` (where the
tooling puts them by default) is recorded as a **gitlink**, mode 160000, so v0.42.0 and v0.43.0 each
shipped a stray pointer to a directory that ceased to exist the moment the worktree was removed.
Caught only because removing the worktrees showed two tracked deletions.

`.gitignore` now covers `.claude/worktrees/`, which closes this instance. The general hazard is not
closed: `git add -A` will do the same for any untracked scratch file, editor backup, or temp output
that happens to be in the tree when a release runs, and the release prints no manifest of what it
staged, so nothing surfaces it.

**Do:** before committing, diff the staged set against what a release is *expected* to touch
(`src/**`, `dist/**`, `CHANGELOG.md`, `meta/context-footprint.json`, the version stamps) and refuse
— or at minimum print a prominent warning and require confirmation — when anything else appears.
A stray gitlink (mode 160000) anywhere in the index should be a hard refusal: this repo has no
submodules, so it is always a mistake. Red-test by planting an untracked file and a worktree.

**Cross-links:** B-53 and B-73 (same script, other release-integrity failures -- both now closed). Consider closing all
three as one pass over `release.ps1`.

---
### B-74 · Nothing proves a test harness can report failure — **DONE in v0.44.0; stale heading corrected 2026-08-08, see Done**
**Effort:** S · **Priority:** P2 · **Invariants:** #3 · found 2026-08-01 shipping B-61

**Why:** B-64 covers gates and diagnostics. It does not cover `_HookHarness.ps1` / `Invoke-HookTests.ps1`,
which decide whether *any* gate's verdict is heard. A defect there is maximally silent: every suite
still prints, and every exit code lies. The v0.41.0 finding above is the existence proof, and it
survived on a supported host for an unknown number of releases.

**Do:** add a self-test that plants a deliberately failing test in a throwaway fixture and asserts the
harness returns non-zero — run under **both** PowerShell hosts, since this defect existed only on 5.1.
Extend the same idea to the runner: a file that exits 1 must make `Invoke-HookTests.ps1` exit non-zero.

**Not:** do not fold this into B-64. B-64's subject is the checks; this one's subject is the scoreboard.

---

### B-75 · The parity fixture was inert for two of seven checks, and looked green
**Effort:** S · **Priority:** P3 · found 2026-08-01 shipping B-61

**Why:** the first cut of `ScriptTwinParity`'s `template-checks` fixture omitted `.claude/hooks/` and
`.claude/skills/`, so checks 5 and 7 never emitted. A planted defect in check 5 **failed to go red**
and the suite reported 4/4 passing. The fixture now asserts which checks it *reached*, so a check that
stops being exercised fails instead of agreeing vacuously. The general hazard: a twin-parity fixture
that does not trigger a branch makes both twins agree about nothing, and that is indistinguishable
from agreement.

**Do:** apply the reached-set assertion to the other parity suites (`WikiCheck`, `FrameworkDoctor`,
`BuildArchitectureHtml`) — each should assert the branches its fixtures are supposed to exercise. This
is B-59's inert-check class one level up: not an inert *check*, an inert *fixture*.

---

### B-83 · A backlog entry's *Do* can be contradicted by a later shipped decision, and nothing notices
**Effort:** M · **Priority:** P2 · filed 2026-08-02 (RCA of v0.44.0)

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

### B-84 · Red-testing a gate is a manual ritual with no record and no shared kit
**Effort:** M · **Priority:** P3 · filed 2026-08-02 (RCA of v0.44.0)

**Why:** three of the four instrument defects in this release were found the same way — mutate the
subject, re-run the check, confirm it goes red — and every one of those mutations was hand-rolled in
an ad-hoc shell command, then thrown away. The maintenance model requires the red observation (#4)
but the repo provides nothing to *perform* it with, so each red-test is re-invented, its exact
mutation is unrecorded, and only the assertion survives. Two of this release's own red-tests were
themselves defective on the first attempt (an over-broad extraction; a vacuously empty pattern), and
nothing but a second look caught either.

**Do:** provide a small mutation helper for meta tests — take a file, a find/replace, run a command,
assert non-zero, restore unconditionally — and use it to record the *specific* mutation next to each
gate as executable text rather than as a comment claiming a red-test happened. Then the claim "seen
to go red" is re-verifiable by running it, which is the only version of that claim worth having.

**Not:** don't run mutations against the working tree in a release path — this must operate on
scratch copies, as this release's red-tests did (`validate-dist` already accepts a dist-root
argument for exactly that).

**Cross-links:** B-64 (planted-defect tests for diagnostics — this is the missing tooling under it),
B-59, B-75.

---

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

### B-88 · Nothing tells you a release broke CI — four red runs went unnoticed until asked — **DONE 2026-08-02, see Done section**
**Effort:** M · **Priority:** **P1** · filed 2026-08-02, observed the same day

**Why:** v0.44.0 was released, tagged, pushed and reported green. **CI went red on both legs, and so
did the three commits after it.** Nobody noticed for over an hour, and only because the maintainer
asked. `release.ps1` runs every local gate and refuses to commit on failure — but it exits **before**
CI has an opinion, so "Release complete" is a statement about the maintainer's box, not about the
repo. Four consecutive red runs is exactly the state the whole gate apparatus exists to make
impossible, and the release path is blind to it.

The specific break was B-70's class (a new test never exercised on a CI leg before shipping) with a
**vantage-point** cause (B-63's class): `ReleaseStagingGuard.Tests` replays release tags, and
`actions/checkout` defaults to `--depth=1 --no-tags`. The test observed a full clone; CI observed a
shallow one. Both legs failed identically, which is the good case — a test that failed on only one
leg would have been read as flakiness.

**Do:** after the tag push succeeds, have `release.ps1` **watch the CI run for the release commit**
and report its conclusion — poll `gh run list --commit <sha>` (or the API) to a terminal state, print
success/failure, and exit non-zero on failure so the release is not reported as complete when it is
not. The release is already a 5–7 minute operation; adding the wait is cheap next to shipping a red
master. If `gh` is absent, say so explicitly and print the run URL — an unverifiable CI result must
read as CANT-VERIFY, never as success (the doctor's tier already models this).

**Not:** don't make the release *depend* on CI passing before committing — the freshness gate needs
the commit to exist. This is a post-condition, like the `origin/master` advance check (B-53), not a
precondition.

**Cross-links:** B-70 (the shipped-untested-on-a-leg gap this instance is), B-63 (vantage point),
B-53 (the precedent: a release that exits 0 without verifying its own postcondition).

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

### B-81 · The licence does not travel with what consumers actually copy
**Effort:** S · **Priority:** P3 · filed 2026-08-01 alongside B-47

**Why:** B-47 put MIT at the repo root, which makes the repository legally consumable. But the unit
of consumption is `dist/<stack>/` — the installers copy those contents into the consumer's own repo
— and those copied files carry no licence text. A consumer whose compliance process inspects *their*
tree (not ours) still finds unlicensed files. Root-only was the deliberate decision at B-47; this is
the deferred half, not a reversal.

**Do:** decide whether each dist ships a `LICENSE` copy. If yes it is authored once in
`src/core/` and reaches all three dists, and it is new **shipped** content, so it needs a
`no-meta-leak` pass and a line in the shipped changelogs. If no, say so explicitly in the README
licence section so the answer is recorded rather than re-litigated.

---

### B-82 · Root `CLAUDE.md` ↔ `AGENTS.md` mirror parity is ungated
**Effort:** S · **Priority:** P3 · filed 2026-08-01 while shipping B-45

**Why:** meta-invariant #2 has two halves. The **shipped** half is gated per dist by
`template-checks` (verbatim section diff + version stamps). The **root** half — this repo's own
hand-maintained `AGENTS.md` mirror — is gated by nothing at all. `DocTruth` treats the four root
docs as a set but never compares them to each other. Adding the Maintenance model section required
editing both files by hand with no check that the second edit happened; the next such section may not
be so lucky.

**Do:** add a `DocTruth` assertion driven by a table of expected `CLAUDE.md` heading →
`AGENTS.md` heading mappings, asserted **both** directions, and encoding the deliberate merges
(Workflows / Definition of done / Verification / Inherited disciplines all collapse into one mirror
section; Commit & push folds into Conventions). Verbatim diffing is the wrong instrument for a
deliberately condensed mirror — that is B-58's lesson. Red-test by adding a section to one file only.
Guard against the vacuous pass: assert the mapping table is non-empty, and count with `@(...).Count`
(a bare pipeline `.Count` returns `$null` for a single match under 5.1 — the v0.41.0 RCA).

---
### B-86 · Post-ship review owed for v0.44.0 — **DONE 2026-08-03, see Done section** (findings: B-92, B-93, B-94)
**Effort:** S · **Priority:** P2 · filed automatically by `release.ps1` on 2026-08-02

**Why:** v0.44.0 shipped with `-NoIndependentReview`, so no second session re-ran a gate or a
red-test against it. Maintenance model #2 requires the review to be filed rather than assumed when
it did not happen. Summary of what shipped: instruments that could not fail now can - harness red-test, hook-registration gate, release staging guard

**Do:** review the v0.44.0 diff as an independent session -- re-run at least one gate and one
red-test yourself, do not read the release output as evidence -- and file whatever it finds. Then
close this entry, recording what was re-run.

---
### B-89 · Windows PowerShell 5.1 turns a native command's stderr into a terminating error — one *shipped* script remains exposed — **DONE 2026-08-08, see Done**
**Effort:** S · **Priority:** P2 · filed 2026-08-02 (RCA of B-88) · **Invariants:** #3 #5

**Why:** under 5.1, a native command that writes to stderr raises a `NativeCommandError` record, and
with `$ErrorActionPreference = 'Stop'` that record is **terminating**. `2>$null` redirects the *text*
but does not stop the record. pwsh 7 does not do this (`$PSNativeCommandUseErrorActionPreference`
defaults to `False` — measured on 7.6.4). So the idiom `$root = (git rev-parse --show-toplevel
2>$null)`, written to degrade gracefully, degrades gracefully on one host and dies on the other.

Found in new code while shipping B-88, then swept. Two shipped scripts originally matched both
conditions. B-90's now-honest 5.1 architecture test reproduced and fixed
`src/core/scripts/build-architecture-html.ps1`; **`src/core/scripts/sync-agent-files.ps1:12`
remains exposed**, and it is not theoretical. Run from a non-git directory,
`dist/dotnet/scripts/sync-agent-files.ps1`:

```
5.1: git : fatal: not a git repository ... + FullyQualifiedErrorId : NativeCommandError   (no exit code at all)
7  : No .claude/skills directory -- nothing to sync.                                       EXIT=0
```

The remaining script intends the fallback that pwsh 7 gives it. Consumers on Windows may use either host,
and the 5.1 outcome is a raw .NET error dump instead of the message the author wrote. This is also a
**twin divergence** the `.sh` side does not have (`2>/dev/null` in bash is just a redirect), so it is
invariant #3 territory as well as #5.

**Do:** wrap the remaining native call so the exit code is inspected rather than the error record —
set `$ErrorActionPreference = 'Continue'` around the call and test `$LASTEXITCODE`, as
`.claude/scripts/watch-ci.ps1`'s `Invoke-GitQuiet` now does. Red-test it from a non-git directory
**under 5.1**. B-90 supplies the completed architecture-generator red/green evidence. Then sweep the remaining `2>$null` sites listed by
`grep -rn '2>\$null' --include=*.ps1 src/ scripts/` and decide each; most do not set `Stop`, which is
the only reason this has not bitten more widely.

---

### B-123b · `build-block-manifest.ps1:183` has the same `Stop` + native-stderr idiom B-89 swept for
**Effort:** XS · **Priority:** P3 · found 2026-08-08 re-running B-89's own closing sweep

**Why:** `.claude/scripts/build-block-manifest.ps1` sets `$ErrorActionPreference = 'Stop'` (line 45)
and calls `& git show "${tag}:${path}" 2>$null` unwrapped (line 183) — the exact idiom B-89 fixed in
`sync-agent-files.ps1` and `fidelity-check.ps1`. Under Windows PowerShell 5.1, a missing tag or path
would raise a terminating `NativeCommandError` instead of the graceful fallback the `2>$null` was
written to produce. Lower urgency than B-89's sites: this is `.claude/scripts/`, maintainer-only,
run only on this box, and this session runs pwsh 7 in practice — but B-89's own RCA said the sweep
"should be re-run again before assuming no third site remains," and re-running it here is what
found this one.

**Do:** wrap the `git show` call the same way B-89 did (temporary
`$ErrorActionPreference = 'Continue'`, check `$LASTEXITCODE`), red-test from a non-existent
tag/path under real Windows PowerShell 5.1, then re-run the same grep once more before closing.

---

### B-90 · A suite can spawn its subject under a host the defect cannot exist on — **DONE 2026-08-08, see Done**
**Effort:** M · **Priority:** P2 · filed 2026-08-02 (RCA of B-88) · **Invariants:** #3

**Why:** `_HookHarness.ps1`'s `Get-PsExe` prefers `pwsh` whenever it resolves. Any suite that uses it
to spawn the code under test therefore exercises that code under **pwsh 7 even when the suite itself
is running under 5.1** — so running the suite under 5.1 proves nothing about 5.1. B-74's RCA recorded
exactly this (fixtures were switched to `(Get-Process -Id $PID).Path`), and it **recurred immediately
in new code**: `ReleaseCiWatch.Tests.ps1`'s first cut used `Get-PsExe`, reported 18/18 green under
5.1, and was hiding two 5.1-only defects — a terminating `NativeCommandError` (B-89) and 5.1's
`ConvertFrom-Json` not enumerating a top-level array. Both appeared the moment the child was bound to
the suite's own host, and one of them would have mis-decided a release.

A fix applied to one file is not a fix applied to a class. Nothing stops the next suite reaching for
`Get-PsExe`, because `Get-PsExe` is the obvious thing to reach for and its name does not warn.

**Do:** audit every `*.Tests.ps1` in `.claude/hooks/tests/` and `src/core/tests/hooks/` that spawns
the subject. Where the subject must be exercised on the host under test, bind it to
`(Get-Process -Id $PID).Path`; where `Get-PsExe` is genuinely right (the subject is *always* invoked
by pwsh in production, as hooks registered with an explicit interpreter are), say so in a comment so
the choice is visible. Consider renaming or documenting `Get-PsExe` at its definition — "resolves a
host, NOT necessarily this one" — since the trap is that the name reads as "the PowerShell I am".
Cross-links: B-74 (first instance), B-71 (the sibling: a skipped 5.1 test inside a green summary).

---

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

### B-93 · The staged-set guard's 5.1 hardening is tested only under pwsh 7 — **ABSORBED by B-90 2026-08-08, see Done**
**Effort:** S · **Priority:** P2 · filed 2026-08-03 by the B-86 post-ship review · **Invariants:** #3

**Why:** `.claude/hooks/tests/ReleaseStagingGuard.Tests.ps1:83` spawns the extracted guard region via
`Get-PsExe`. Measured on this box: under a **Windows PowerShell 5.1** suite run, `Get-PsExe` returns
`pwsh`, resolving to `pwsh 7.6.4`. So running the suite under 5.1 exercises the guard under 7, and
the `@()` wrappers the guard carries *explicitly and only* for a 5.1 defect (`release.ps1:398-401`,
citing the v0.41.0 RCA) are never executed on the host they defend against.

This is B-90 verbatim, and the timing is the point: B-90 was filed 2026-08-02 as the *class* behind
B-74's recurrence, and the file that repeats it was added by v0.44.0 — the release whose theme was
instruments that cannot fail. The trap is that `Get-PsExe` reads at the call site as "the PowerShell
I am" when it means "the best PowerShell on this box".

**Do:** bind the fixture to `(Get-Process -Id $PID).Path`, as `HarnessIntegrity.Tests.ps1:57` and
`ReleaseCiWatch.Tests.ps1` already do, and run the suite under both hosts. Fold this file into
B-90's audit rather than treating it as separate work — it is one more row in that sweep, filed
separately only because it landed after B-90 was written.

**Cross-links:** B-90 (the class), B-74 (first instance), B-71 (the sibling: a 5.1 test skipped
inside a green summary).

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

### B-101 · Gate runtime is measured by nothing, and one gate shipped that could not finish at all
**Effort:** M · **Priority:** P2 · found 2026-08-05 while verifying B-97 · **Invariants:** #3

**Why:** the repo gates correctness rigorously and cost not at all. B-97's new `validate-dist` check
shipped with a bash twin that **never completed** — its section-path check ran a `sed` plus a `grep`
for every *(line × cited file × heading)* triple, up to 66 subprocesses per line across ~160 shipped
files, which exhausted the Git-for-Windows process table (`dofork: ... Resource temporarily
unavailable`) after 10+ minutes. The PowerShell twin did the same work in 10s. **Every correctness
gate was green throughout**, and the implementer reported the hang as an environment quirk rather
than a defect. It was found only because the meta suite ran for hours and the maintainer asked why.

That is the finding: **twin parity is asserted on decisions, never on feasibility.** A twin that
cannot finish is as broken as one that returns the wrong answer — and CI's linux leg runs the `.sh`
twin, so this would have hung CI, which B-88 would then have reported as a failure of unknown cause.

Fixed for that check (batched to one `grep` pass per cited file: 77s, exit 0). The *class* is open,
and so is the cost problem underneath it. Measured on this box against B-79's profiled spawn costs
(pwsh MSIX 265 ms, bash fork 55 ms), for one `validate-dist.sh dotnet` run at 77s:

| Cost | Count | Est. |
|---|---:|---:|
| marker check — outer loop greps **every** file in `src/core` | 218 forks | ~12s |
| marker check — `sed`/`grep` per marker (117 × ~3), re-reading the whole dist file per marker | 351 forks | ~19s |
| PS-AST check — one pwsh process **per `.ps1` file** | 32 spawns | ~8.5s |

Only **40 of 109** files in `src/core` contain a marker, so ~138 forks (~7.6s) scan files that have
none. The PS-AST loop is pre-existing (since the merge commit), not new.

**Do:** (a) add a runtime budget signal — have the meta suite and `validate-dist` print elapsed time
per check, and fail (or warn loudly) past a per-check ceiling, so a 20× regression is visible in the
run that causes it rather than hours later; (b) the three speedups above — hoist the marker loop to
`grep -rl` so only marker-bearing files are scanned, cache the dist-file read per file instead of per
marker, and batch the 32 PS parses into one process (~77s → ~35-40s); (c) the structural one, worth
more than (b) combined: **`ValidateDist.Tests.ps1` copies the real 161-file dist into temp for each of
its 20 cases and runs full validation on both twins**, when it is testing gate *logic* that a small
synthetic fixture would exercise just as well — it also re-proves what a single `validate-dist` run
already proves. That file dominates the meta suite's runtime.

**Not — and this is the trap:** do **not** optimise a gate without red-testing it afterwards. If the
marker loop's file list is subtly wrong after hoisting, the gate silently checks fewer markers and
still prints `OK`. That is B-59's inert-check class, and B-97 shipped **two** live instances of it in
one session (the `.ps1` marker check was blind to the 15 hash-form markers in `route-prompt` /
`audit-trail` / `.gitignore` / CI; the `.sh` twin matched unanchored, so a prose mention of the syntax
would have counted as a marker). Every speedup here needs the planted-defect test re-run, both twins.

**LARGELY DONE 2026-08-06 — measured, fixed, re-red-tested. What the measurement overturned:**

Every estimate in the table below was derived from spawn-cost arithmetic, and the profile disagreed
with most of it. Recorded because the *method* is the lesson, not the numbers:

| claim | measured |
|---|---|
| marker outer loop ~12s | real, but the actual hotspot inside 1a was a `printf \| grep -q` blank-test **per marker** (117 × 2 forks) — 14.7s |
| PS-AST 32 spawns ~8.5s | **confirmed** — batching to one process took it to **0.6s** |
| `ValidateDist.Tests` dominates because it copies the dist per case | **wrong** — `Copy-Item` of the 161-file dist is **0.25s**, ~9s across all 37 cases. Not worth touching. |
| — (not in the table at all) | `case_exact_path` forked `ls \| grep` **per path segment**: ~312 forks, and it made `--content-only` *slower than a full run* |
| — (not in the table at all) | check 7 forked a `grep` **per doc** (~90) plus a `basename` per doc |

**Fixed (bash twin):** file-index built once for case-exact lookups; one batched `grep` for check 7
with the per-file loop retained *only* as the error path (so "which doc was unreadable" is still
answerable); `basename`/`sed`/`tr` replaced with parameter expansion; the blank-test made a bash
pattern match; PS-AST batched into one process; marker scan hoisted to `grep -rlE` sharing **one**
regex variable with the extractor so the selecting and extracting patterns cannot drift apart.

| | before | after |
|---|---:|---:|
| `validate-dist.sh` FULL | 66s | **29s** |
| `validate-dist.sh --content-only` | 23s | **11s** |
| `ValidateDist.Tests.ps1` | ~850s | **391s**, then **187s** parallel |
| **the whole meta suite** | **1,027s** | **270s** |

**Then parallelised (2026-08-06).** `ValidateDist.Tests.ps1` now dispatches one child process per
case, `min(8, cores)` at a time; the cases already built their own temp dists, so they were
independent before they were run that way. Measured 4/8/12 lanes = 218/183/179s against 391s
sequential — the floor is the longest single case, so the default is capped at 8 and scaled to the
host (a 2-core runner must not be over-subscribed into being slower than sequential). Three
consecutive green runs (208/200/187s) before it was trusted, because parallelism turns a real race
into an intermittent failure and a flaky gate is worse than a slow one.

**Two things this did NOT need, discovered by looking rather than assuming:** `release.ps1` already
ran the three dists' gates concurrently via `Start-Job`, and the shipped hook suites already
throttle internally over their test files (`HOOKTESTS_THROTTLE`). The meta suite's
`ValidateDist.Tests` was the only serial block left in the system.

**The dispatcher shipped a silent-zero-coverage bug for one run, and it is worth recording because
it is this file's own subject matter.** `Start-Process -ArgumentList` joins without quoting, so case
names containing spaces arrived as many arguments, `-Only` bound to the first word, no case matched,
and the suite reported **0 passed / 0 failed in 8 seconds** — indistinguishable from a 50× speedup if
you only read the clock. The guard added in response now fails any child that reports no result for
the case it was handed; a total of zero is never a pass.

**Red-tested after every step, both twins** — 20/20 planted-defect cases still red, and the counts
the checks report (117 markers, 30 script refs, 89 docs, 26 registrations) are byte-identical to
before, which is the anti-inert evidence. The backslash-collapse rewrite was proven equivalent to the
`sed` it replaced across 7 inputs including the `//` edge case.

**(a) shipped as well:** both twins now print `TIMING <s>  <check>` to stderr and warn past a
per-check ceiling (`VALIDATE_DIST_CHECK_CEILING_S`, default 25s). stdout is untouched, so every
existing caller parses the same `OK:`/`FAIL:` stream.

**Still open:** the `.ps1` twin's section-path check (4.6s of its ~7s) is now *its* hotspot and was
left alone. And the structural question stands — the suite makes ~16 bash validator runs against a
real dist, so ~300s is inherent at current per-run cost. Going below that means running fewer legs,
which is a **coverage** decision (B-92 chose both legs deliberately), not a performance one. Do not
take it without a written decision.

**MEASURED 2026-08-05 (the number this entry has never had).** The meta suite, run end-to-end on the
maintainer box with a warm tree: **1,027s — 17.1 minutes**, of which `ValidateDist.Tests` is the
overwhelming majority (the other eight files together finish in well under a minute). The shipped
hook suites cost a further **174s / 217s / 182s** for dotnet / angular / monorepo, so a full local
gate pass before a release is **~27 minutes** before `release.ps1` re-runs all of it and then waits
on CI. Two consequences worth stating plainly: the maintainer asked "what's going on, it's been
running for years" during this very run — the same question that originally produced this entry — and
a 20× regression inside that 17 minutes would still be invisible, because nothing measures it. Fix
(c) is therefore the one with real leverage: `ValidateDist.Tests` copies the whole 161-file dist per
case and re-runs full validation on both twins, to test gate *logic* a small synthetic fixture would
exercise just as well.

**Also this class, added 2026-08-05 by B-103's review (F7): the parser resolution is re-derived on
every hook invocation, uncached.** `guard.sh` runs on **every** `Write`/`Edit`; on the no-`jq` path it
now spawns up to three `command -v` probes plus up to two real interpreter startups — the Store stub
*executes* before being rejected — per write. `route-prompt` pays the same on every prompt once B-104
lands. It is small per call and invisible on the maintainer box (which has `jq`), which is exactly the
shape of cost this entry exists to make visible. Caching the resolved interpreter in `.claude/.state/`
is the obvious fix and carries its own hazard (a cached path that later breaks), so measure before
building it.

**Cross-links:** B-79 (MSIX pwsh spawn cost — the measured baseline this uses, and the reason
parallelism cannot rescue it), B-59 (inert checks), B-61 (twin parity does not cover feasibility),
B-64 (planted-defect tests for diagnostics), B-70 (a change is not done until CI is green — this
would have taken the linux leg down), B-88 (CI-red reporting), B-104/B-108 (the hooks whose
resolution this measures).

### B-102 · The documented JSON-parser fallback cannot exist on Windows — `python3` is not the name Windows installs

> **DONE — shipped v0.45.0 (2026-08-05).** Probe now resolves by execution over
> `python3 → python → py` in ~~all ten shipped `.sh` hooks and the doctor~~ **five shipped `.sh`
> hooks** (`guard`, `session-start`, `audit-trail`, `boy-scout-check`, `post-write`);
> `enforcement-surfaces.md` corrected. Measured before/after, same box, Python 3.14.5 present:
> `exit 0` (INACTIVE, write allowed) → `exit 2` (blocked), verified against the composed dist.
>
> **CORRECTION, 2026-08-05 (B-103's review).** The struck claim above is false and is left visible
> rather than rewritten. `git show --stat 6eb7752` contains no `route-prompt.sh`, no
> `framework-doctor.{ps1,sh}`, and not a single test file. So: the doctor was **not** fixed (B-105);
> `route-prompt.sh` was **not** fixed and still selects the Store stub (B-104, **P1** — a *silent*
> fail-open, the exact outcome this entry exists to prevent); the false skip below was **not** fixed
> (B-106). The record asserted three fixes that did not ship. That is why Maintenance model #2 does
> not accept a self-review, and why the RCA below is itself incomplete.
>
> **RCA — why did no gate catch it?** Two reasons, both structural. (1) `jq` is present on the
> maintainer box, so the fallback branch never executed here — the gates only ever exercised the
> path that worked. (2) The one test that would have covered it was **permanently skipped** with the
> message "python3 is unavailable on this host", which was false; the suite summarised green around
> it. A skip that misreports its cause is indistinguishable from coverage.
> **What else is exposed?** Any capability probe that (a) tests a name rather than the capability, or
> (b) has a fallback branch no test forces. B-63 owns the general audit; this entry is its third
> confirmed instance and the first with live consumer impact. Specifically worth checking: every
> `command -v` in the shipped hooks, and every `[skip]` message in the suites that asserts a host
> lacks something.
**Effort:** S–M · **Priority:** **P1** (the write-guard fails open on the primary target platform while a doc
promises otherwise) · found 2026-08-05 · **Invariants:** #3 #5 #6

**Why:** every shipped `.sh` hook resolves its JSON parser with `command -v python3`, and
`docs/enforcement-surfaces.md:48` promises consumers *"(`jq`, with `python3` as fallback)"*. **A
standard python.org install on Windows provides `python.exe` only — there is no `python3.exe`.**
Verified on the maintainer box: `C:\Python314\` (registered in the registry `PATH`) contains
`python.exe`, `pythonw.exe`, `python3.dll` — and no `python3.exe`; `C:\Python314\python.exe --version`
returns **Python 3.14.5** and parses JSON from stdin correctly.

So on Windows the documented fallback **can never engage**, no matter how healthy the `PATH` is. The
consequence is the one that matters: with `jq` absent, `guard.sh` prints
*"no jq or python3 on PATH — write-guard INACTIVE (secret/test-defeat floor is OFF)"* and **allows
every write**, on a box that has a perfectly good JSON parser installed. The framework's deterministic
write floor is the product's central enforcement claim, and its only fallback is spelled in a way that
excludes the primary target platform (Bitbucket DC shops on Windows).

Why nobody noticed: `jq` is present on the maintainer box (`<home>/bin/jq`), so the fallback
branch is never taken here. It fails only for a consumer without jq — i.e. exactly the person the
fallback exists for.

**Blast radius — 14 shipped/meta files carry the `command -v python3` probe:** `guard.sh`,
`route-prompt.sh`, `session-start.sh`, `audit-trail.sh` (core); `boy-scout-check.sh` and
`post-write.sh` (all three stacks); `framework-doctor.{ps1,sh}`; three `SessionStart*.Tests.ps1`.
The doctor's `Guard JSON parser` row reports *"jq or python3 is available"* on the same naming, so it
reports the floor's health on a basis that is wrong on Windows — a second defect in a row B-56 and
B-63 have already had to correct once for vantage-point reasons.

**The trap in the obvious fix, which must not be skipped:** do **not** simply add `python` to the
`command -v` list. `<home>\AppData\Local\Microsoft\WindowsApps\python.exe` **exists and
resolves**, but it is the Microsoft Store *app-execution-alias stub*: running it prints *"Python was
not found; run without arguments to install from the Microsoft Store"* and exits non-zero. A
name-resolution probe would therefore report a parser as available and then fail at the moment the
guard needs it — converting a loud INACTIVE warning into a silent malfunction, which is strictly
worse. **The probe must validate by execution** (run the candidate and confirm it parses), which is
the same lesson as B-63: ask the capability, not the name.

**Do:** one shared resolution helper used by both twins and the doctor: try `jq`, then `python3`,
then `python`, then `py -3`, and accept a candidate only after it successfully round-trips a trivial
JSON document. Correct `enforcement-surfaces.md`'s parenthetical to name what is actually probed.
Red-test it by hiding `jq` and asserting the fallback engages and the guard still blocks a planted
secret — on Windows, which is where the current code fails.

**Also fixes a false skip (B-71's class).** — **it did not; see the correction above. The file is
untouched by `6eb7752` and the skip is still live. Now B-106.** `ValidateDist.Tests.ps1` prints
*"python3 is unavailable on this host; CI linux must exercise this branch"* and the suite still
summarises green. That statement is **false** — python is installed and working. The skipped
assertion is a *twin-parity* one (the jq and python normalized record streams must be byte-identical),
so it has been permanently unexercised on every Windows box while reading as covered. A skip caused by
a POSIX-only name is not the same fact as a host without python, and reporting them identically is
precisely what B-71 says lets a gap persist.

**Cross-links:** B-63 (probe vantage-point validity — third instance), B-56 (host-dependent probes
make gate outcomes machine-dependent), B-71 (skips that misreport why), B-48 (enforcement-bypass
audit — an inactive guard belongs on that list), B-101 (filed the same day from the same verification
pass).

---

### B-103 · Post-ship review owed for B-102 — implementer and reviewer were the same session

> **DONE — review performed 2026-08-05** by an independent session (Opus 5; B-102's implementer was
> a different session), with an adversarial second pass by codex `gpt-5.6-sol` over the review's own
> findings. **It did not come back clean: 9 findings, 5 of them defects in shipped code or in the
> record.** Filed as B-104 (P1), B-105, B-106, B-107, B-108; F7 appended to B-101.
>
> | # | finding | disposition |
> |---|---|---|
> | F1 | `route-prompt.sh` never fixed; its `python` branch selects the Store stub and the `elif` chain makes the regex fallback unreachable — routing dies **silently** on Windows | **B-104, P1** |
> | F2 | `framework-doctor.{ps1,sh}` never fixed; post-B-102 it now reports the write floor **backwards** (`MISSING` while the guard is active) | **B-105** |
> | F3 | the false skip B-102 claims to have fixed is untouched, plus four more of the same shape in shipped suites | **B-106** |
> | F4 | `enforcement-surfaces.md:48` overclaims for `route-prompt.sh` and omits three hooks that gained the dependency | folded into B-104 |
> | F5 | `_pybin` reachability across all six sites — **no defect** (checked by ordering, not by counting; confirmed independently) | closed |
> | F6 | comments in `audit-trail.sh` and `guard.sh` now contradict the code beneath them | **B-107** |
> | F7 | resolution re-runs per invocation, uncached, on a per-tool-call hook | appended to **B-101** |
> | F8 | one resolver, two grammars, fifteen copies — which is *how* F1 was missed | **B-108** |
> | F9 | the no-`jq` fallback branch has no regression test in any suite | folded into B-106 |
>
> The three answers B-103 explicitly asked for: `_pybin` is safe on every reachable path (F5); the
> per-invocation latency cost is real but small and belongs to B-101 (F7); and yes, the
> `enforcement-surfaces.md` wording **does** now overclaim in the other direction (F4) — it promises
> execution-probing for a hook that does not do it.
>
> **Method note, worth keeping:** the review's own adversarial pass returned 5 blocking findings, of
> which **4 were accepted and 1 was refuted by execution** (it claimed a test file did not exist; the
> file is tracked and unignored, and the reviewer had searched a tree that skipped `.claude/` — this
> repo's own documented search hazard, at the top of this file). Maintenance model #1's "a reviewer's
> corrections are input, not verdict" earned its keep again.

**Effort:** S · **Priority:** P2 · filed 2026-08-05 at release time, per Maintenance model #2

**Why:** B-97 followed the intended pipeline — an adversarial reviewer returned 7 blocking findings
on the plan, an external implementer built it, and a different session re-ran the gates and
red-tests independently, catching four defects the implementer's report did not contain. **B-102 did
not.** It was found, designed, implemented and verified in one session by one model. Maintenance
model #2 is explicit that this does not count as reviewed, and the honest response is to file the
review rather than to pretend it happened.

That matters more than usual here because B-102 changes the **write guard's** parser resolution in
ten shipped hooks — the framework's central enforcement claim — and because the same session
inflicted two defects on itself while doing it (a failed `sed` that left eight hooks calling an
unassigned variable and still passed `bash -n`; a compound `elif` whose invocation was rewritten
while its assignment landed in another branch). Both were caught, but by the author, which is the
condition this rule exists to distrust.

**Do:** an independent session reviews commit `6eb7752` specifically for: the resolver's behaviour
when a candidate exists but is broken in a way other than the Store stub (e.g. a Python whose
`json` import fails, a `py` launcher with no installed runtime); whether `_pybin` can be unset on any
reachable path in any of the ten hooks (assert ordering, do not count occurrences); whether probing
by execution introduces a meaningful latency cost on the no-`jq` path for hooks that run per tool
call; and whether the `enforcement-surfaces.md` wording now overclaims in the other direction.
Re-run the jq-hidden red-test independently rather than trusting the recorded before/after.

**Cross-links:** B-102 (the change under review), B-63 (probe vantage-point audit — B-102 is its
third instance), B-45 (the review ledger that made this fileable at release time).

---

### B-104 · `route-prompt.sh` selects the Windows Store stub and then silently routes nothing
**Effort:** S · **Priority:** **P1** · found 2026-08-05 by B-103's review · **Invariants:** #3 #5 #6

**Why:** `src/core/.claude/hooks/route-prompt.sh` extracts the prompt through an `elif` chain:
`jq` → `command -v python3` → `command -v python` → last-resort regex. On Windows, `python3` never
resolves (python.org ships `python.exe` only), so the chain reaches `command -v python` — which
resolves `%LOCALAPPDATA%\Microsoft\WindowsApps\python.exe`, the Store *alias stub*: it prints
"Python was not found" and exits 49. Because this is an `elif` chain, **selecting the stub commits
to that branch** — the regex `else` is never re-entered — so `prompt` comes back empty and the hook
exits without routing anything. The output-encode site (~line 210) name-probes `python3` the same way
and falls through to plain stdout, which Copilot drops.

The consequence is the whole natural-language routing and discipline-injection delivery on the bash
leg, failing **silently**, on the primary target platform. B-102 fixed exactly this class in five
other hooks and its commit message names `route-prompt.sh` as the one hook with a bare-`python`
fallback — but `git show --stat 6eb7752` does not contain the file. A *loud* degradation was
converted into a silent one, which is what B-102 existed to prevent.

**Do:** resolve a **working** interpreter by execution over `python3 → python → py`, using the exact
grammar already in `guard.sh:46-52` (do not author a third dialect — see B-108). Resolve **lazily**,
inside the `else` of the `jq` test only: this hook runs on every prompt and must not pay interpreter
startups on the common path. Resolve **once** and memoise for both sites; initialise the variable for
`set -u`. When no interpreter resolves, the regex path and the plain-stdout path must be genuinely
reachable — *that reachability is the bug, not the name*. `route-prompt.ps1` needs no change
(PowerShell parses JSON natively); state that explicitly rather than silently skipping the twin [#3].
Also correct `docs/enforcement-surfaces.md:48` (F4): it promises execution-probing for
`route-prompt.sh`, which is currently false, and omits `audit-trail.sh`, `post-write.sh` and
`boy-scout-check.sh`, which gained the same dependency in the same commit.

**Red-test (B-106 owns the permanent one):** sandbox `PATH` with no `jq`/`python3`/`py` and a fake
`python` that exits 49; the hook must still route via the regex path.

**Cross-links:** B-102 (the change that missed it), B-103 (the review that found it), B-108 (the
two-grammar duplication that *caused* the miss), B-63.

### B-105 · The doctor reports the write floor backwards — `MISSING` while the guard is active
**Effort:** S · **Priority:** P2 · found 2026-08-05 by B-103's review · **Invariants:** #3 #5

**Why:** `framework-doctor.sh` still name-probes `python3` at `:43` (version-stamp read), `:134`
(the `Guard JSON parser` row) and `:153`/`:162` (Copilot `hooks.json` validity); `framework-doctor.ps1`
`:172-173` asks the same question through `Invoke-BashProbe` and, when that observation is
unavailable, **guesses from PowerShell's own PATH** — the wrong-vantage-point shape B-63 has already
had to correct twice.

Since B-102, this inverts. On a Windows box with a working python.org install and no `jq`, `guard.sh`
is now **active**, and the doctor tells the consumer *"the bash write guard is INACTIVE"*. The
diagnostic that every other honesty claim rests on (B-61) now produces a false alarm about the write
floor — a defect **created by the fix**, because the doctor was out of that change's scope while its
record claimed otherwise.

**Do:** implement both twins to one verdict table, and test every row: `jq` present → OK; no `jq` but
a working `python`/`py` → **OK** (today: wrongly MISSING); only the Store stub → MISSING; no parser →
MISSING; parser present but `hooks.json` malformed → **invalid**, not CANT-VERIFY; bash unobservable
(`.ps1` twin) → CANT-VERIFY. **Delete the `.ps1` PATH-guess fallback** — the row reports on
`guard.sh`, which runs under bash, so when bash cannot be observed the honest answer is CANT-VERIFY.
Keep "no parser" distinguishable from "invalid JSON".

**Not yet observed live:** the inversion follows from the code by inspection. Constructing the host
condition (no `jq`, working non-`python3` python) and recording the row before and after is required
before this closes — do not close it on inference.

### B-106 · The no-`jq` fallback has no test, and five skips lapse exactly where it matters — **DONE in v0.46.0; bookkeeping corrected 2026-08-08, see Done**
**Effort:** M · **Priority:** P2 · found 2026-08-05 by B-103's review · **Invariants:** #3

**Why:** B-102's red-test was run by hand and recorded in a commit message. **Nothing in any suite
forces the no-`jq` branch**, so B-104 could regress tomorrow with every gate green — B-64's class, on
the change that most needed it. Meanwhile five test cases silently stop covering it:

- `.claude/hooks/tests/ValidateDist.Tests.ps1:158-161` — `Get-Command python3`, then
  *"python3 is unavailable on this host"*, and the suite summarises green. B-102's entry claims to
  have fixed this; the file is not in the commit.
- `src/core/tests/hooks/SessionStart{FrameworkRules,Hazard,Wiki}.Tests.ps1` (`:22`, `:27`, `:15`) —
  each probes `command -v jq || command -v python3` and skips its Copilot-JSON case as *"no
  jq/python3 in bash"*; the Wiki file has two cases behind one skip.
- `src/core/tests/hooks/FrameworkDoctor.Tests.ps1:73` asserts the **pre-fix** contract by name.

**Do:** add a `route-prompt` no-`jq` case and a doctor inverted-row case, both driven from a sandbox
`PATH`. Reuse the utility-sandbox already at `FrameworkDoctor.Tests.ps1:73-95` — do not invent a new
one: a naive PATH scrub breaks the hook before the branch under test is reached (`route-prompt.sh`
needs `cat`/`tr`/`grep`/`sed`), while an inherited PATH may expose a real `jq` so the stub is never
selected. That fixture already carries the Git-Bash/POSIX split both CI legs need. Convert the five
skips to execution probes, and when a host genuinely lacks every parser surface it as an
**invariant-guarding** skip per B-71, not an inline `[skip]` inside a green summary. Both legs [B-70].

### B-107 · Comments left contradicting the code beneath them
**Effort:** S · **Priority:** P3 · found 2026-08-05 by B-103's adversarial pass

`audit-trail.sh:73` still says *"fall back to python3"* directly above the new three-candidate
resolver; `guard.sh:13` still describes absence as *"no jq, no python3"*, which is no longer the
capability condition. The header of the change's own flagship file misdescribes it. Sweep the other
parser-dependent hooks for the same wording while there.

### B-108 · One resolver, two grammars, fifteen copies — and that is how B-104 was missed — **CLOSED 2026-08-08, premise rejected; see Done**
**Effort:** S–M · **Priority:** P2 · found 2026-08-05 by B-103's review · **Invariants:** #3 #6

**Why:** `guard.sh` spells the parser probe as a multi-line `for` loop; `audit-trail`, `post-write`,
`boy-scout-check` and `session-start` spell the same contract as a ~200-char one-liner inside an
`elif` condition; `route-prompt` spells it a third way. Hooks are standalone by design (nothing is
sourced), so *duplication* is structural and acceptable — **two different grammars for one contract
is not.** It is B-55's class, and it is the direct cause of B-104: the change was scoped by grepping
`command -v python3`, and the sites that survived are the ones spelled differently.

**Do:** normalise every site to one grammar, then add a `validate-dist` check that fails any shipped
`.sh` naming `python3` outside the sanctioned probe form. Red-test it by planting a bare
`command -v python3` and showing the non-zero exit before the clean pass — per the trap in B-101, an
optimised or narrowed gate that silently checks fewer sites is worse than no gate.

### B-109 · `no-meta-leak` denies our vocabulary but not the maintainer's filesystem — **DONE 2026-08-08, see Done section**
**Effort:** S · **Priority:** **P2** · found 2026-08-05 while reviewing B-106's implementation ·
**Invariants:** #6

**Why:** `scripts/meta-denylist.txt` catches tracking ids, "lockstep", the two-repo past — our
*development vocabulary*. It has **no pattern for a machine-specific absolute path**. Caught live:
an implementer added host-resolution helpers to `src/core/tests/hooks/_HookHarness.ps1`, which
composes into all three dists, containing

```powershell
$fallback = 'C:\Python314\python.exe'
$fallback = '<home>\bin\jq.exe'
```

Both would have reached every consumer. `no-meta-leak` caught the `B-nn` ids in the same commit and
**passed the paths** — so the gate that exists to hold the don't-ship boundary reported a clean scan
over a file naming the maintainer's home directory. A consumer's test harness reaching into a
username on a machine that is not theirs is a worse leak than a tracking id: the id is embarrassing,
the path is a broken artifact plus an information disclosure.

This is also the shape B-97's `$protected` work already knows about — *shipped* content is the only
thing a consumer sees, and prose alone has never held this line (~190 leaking lines shipped once
before, per the invariant's own note).

**Do:** add DENY patterns for machine-local absolute paths in shipped content — at minimum
`[A-Za-z]:\\Users\\`, `/home/[^/]+/`, `/Users/[^/]+/`, and the maintainer's own username as a
belt-and-braces literal. Red-test by planting one and showing the non-zero exit. Consider whether
any *legitimate* shipped file needs an absolute example path (documentation placeholders like
`C:\path\to\repo` are the plausible case) and carve those out with a narrow `ALLOW` rather than
weakening the DENY, per the invariant's standing rule.

**Cross-links:** invariant #6, B-103 (the review during which this surfaced), B-62/B-92 (the other
"nothing validates what we ship" entries).

---

### RCA — v0.45.0 (B-102), filed 2026-08-05 with B-103's review

**Why did no gate catch it?** The change was scoped by a grep for `command -v python3`, and the sites
that survived are precisely the ones spelling the probe differently (B-108) — plus a diagnostic and
five test files nobody re-ran the grep against. **No gate knows which files are parser-dependent**, so
"fixed everywhere" was an unfalsifiable claim: there is no inventory for a gate to re-derive and diff.
`bash -n` passed on every hook, because a syntax check is not a coverage check, and the correctness
gates only ever exercised the `jq` path that works on this box.

**What else is exposed?** Every claim of the form "fixed everywhere / in all N files" made without an
inventory a gate can re-derive. The sweep is worth doing on the standing ones: the `.sh`/`.ps1` twin
sets, the six `boy-scout-check` headers (B-55), and the `enforcement-surfaces.md` capability rows.

**And the pattern above the defect.** This is the **third consecutive release whose record
overclaimed what it shipped** — B-94 (the staged-set guard's record overclaimed in three places),
B-102 (three fixes asserted that are not in the commit), and the v0.45.0 commit message itself, which
reports a "14 files × 3 dists" verification for files the commit does not contain. Each was caught by
the next independent review, never by the authoring session and never by a gate. That is the argument
for Maintenance model #2 being enforced rather than encouraged: **the failing component is not the
implementation, it is the self-report.** Worth considering whether `release.ps1` should require the
claimed blast radius to be stated as a file list it can diff against the commit.

### B-110 · The context-footprint ceiling is advisory — the budget gate cannot fail on a breach

> **DONE 2026-08-06 (meta-only; the twins do not ship — they are authoring gates, absent from
> `dist/*/scripts/`, so no version bump).** **Decision: the ceilings are LIMITS, not guidance.**
> A breach now prints `FAIL:` per breached metric with the measured value and the overage, then
> exits 1 — in **both** `-Check` and `-Update`, and **before** the `-Update` write, so a breach can
> never leave a rewritten baseline behind. The escape hatch is `-AllowCeilingBreach` /
> `--allow-ceiling-breach`, named for what it risks per this repo's convention: it prints
> `WARN (CEILING WAIVED):` and continues. Raising a ceiling stays a two-twin edit, deliberately.
>
> **Red-tested — the instrument was seen to go red before its green counted (Maintenance model #4).**
> Planted +1,180 chars into `dist/dotnet/CLAUDE.md` (38,997 → 40,201, over by 201), restored
> unconditionally via `git checkout` in a `finally` (B-84's rule). Observed:
>
> | run | observed |
> |---|---|
> | `.ps1 -Check` | `FAIL: dotnet static.claude is 40201 chars, ceiling 40000 (over by 201).` · **exit 1** |
> | `.ps1 -Update` | same FAIL · **exit 1** · `baseline_untouched=True` — **this is the defect, closed** |
> | `.sh -Check` | byte-identical verdict · **exit 1** |
> | `.sh -Check -AllowCeilingBreach` | `WARN (CEILING WAIVED)` then fell through to the drift check · exit 1 (drift, correct — the waiver waives the ceiling, not drift) |
> | `.ps1 -Update -AllowCeilingBreach` | `WARN (CEILING WAIVED)` + `UPDATED` · **exit 0** |
> | both twins, restored tree | `OK: context footprint matches…` · **exit 0** |
>
> Both CI legs already invoke their own twin with `-Check` (`ci.yml:45-46`, `:81-82`) and
> `release.ps1:232` gates on `-Update` exiting 0, so the new failure mode is enforced everywhere
> without wiring changes. Current values are all under ceiling (dotnet 38,997 / angular 37,835 /
> monorepo 47,354 / ratio 1,214), so nothing is blocked today.
>
> **Also closed from this entry's "worth checking":** the twins previously had *no* fixture
> exercising the ceiling branch on either side (B-75's inert-fixture class — both agreed about
> nothing). The red-test above is the first execution of that branch in either twin, and they were
> shown to agree on it.
>
> **NOT done, deliberately, and it is the honest residual:** no *permanent* test was added. The
> red-test was performed and is recorded here as observed output, not as executable text — which is
> exactly the gap **B-84** exists to close, and this is now a second worked example for it. The
> reason is cost, not oversight: a single `context-footprint` run takes minutes (it renders both hook
> twins across three dists), so a suite case would add multi-minute runtime to a meta suite B-101
> just cut from 1,027s to 270s. That trade should be made deliberately with B-84's mutation helper,
> which could plant the breach against a scratch dist rather than the real one. Filed as the reason,
> not as a claim that testing happened.
**Effort:** S · **Priority:** P2 · found 2026-08-06 while shipping v0.47.0 · **Invariants:** #3

**Why:** `scripts/context-footprint.ps1:323-331` checks the ceilings and emits
`WARN: <dist> static.claude exceeds 40000 chars.` / `WARN: monorepo static.claude exceeds 48000
chars.` / the 1.5× ratio warning — and **never sets a non-zero exit**. The script's only failing
condition is *baseline drift* (`FAIL: context footprint differs from meta/context-footprint.json`),
which the documented remedy `-Update` resolves by accepting whatever the new numbers are. So the
sequence "make a change, run `-Update`, commit" absorbs a ceiling breach silently, and a `WARN:` line
scrolls past inside an otherwise-clean run — B-71's shape as well as B-64's.

This matters more than a normal advisory: the footprint gate is the instrument **every** static-context
decision is weighed against. B-97 cited it to argue "whatever the answer is, it is not add more to
`CLAUDE.md`"; B-99's placement decision was costed against it and its headroom figure was already
wrong once (characters read as tokens, a 4× error, corrected in that entry). A budget whose enforcement
is a print statement invites exactly that.

Live relevance: v0.47.0 took monorepo `static.claude` to **47,354 / 48,000 — 646 characters (~162
tokens) of headroom**. The next static-context addition can breach the ceiling, and on current code
nothing would stop it.

**Do:** decide whether the ceilings are limits or guidance, and make the code say so. If limits: exit
non-zero on breach (with an explicit opt-out switch for a deliberate, recorded raise, since the
ceilings are a judgment call and not physics). If guidance: rename them and say so, so no future entry
cites them as a gate. Either way, **red-test it** — plant a file that breaches the ceiling and show the
non-zero exit (or the documented WARN-only behaviour) before the clean pass. Twin edit: the `.sh` twin
carries the same logic and must reach the same verdict [#3].

**Also worth checking in the same pass:** whether `.sh` and `.ps1` agree on the ceiling branch at all.
It is un-exercised code on both sides, which is B-75's inert-fixture class — a branch no fixture
triggers makes both twins agree about nothing.

**Cross-links:** B-64 (planted-defect tests for diagnostics — this is one), B-71 (a warning inside a
green summary), B-75 (inert fixtures), B-32/WSD-017 (the gate's origin), B-97/B-99 (entries whose
reasoning rests on these numbers).

---

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
### B-113 · CI is being cancelled at exactly 15 minutes, and the windows leg already runs 12–14.5
**Effort:** S to diagnose · **Priority:** **P1** — it blocks every release · found 2026-08-06 shipping v0.48.0

**Why:** the v0.48.0 release commit (`beface1`) could not be tagged, because `release.ps1`'s CI watch
(B-88) correctly refused to tag against a red run. But the run did not *fail* — **both jobs were
`cancelled`, simultaneously, at exactly 15m01s, with no failing step in either.** Reproduced by an
explicit `gh run rerun`: identical outcome, same 15-minute boundary
(`16:49:45Z → 17:04:46Z` linux, `→ 17:04:47Z` windows). Two independent jobs, so this is not
`fail-fast`.

**What it is not, checked rather than assumed:**
- **Not the code.** Every local gate passed twice: compose ×3, `validate-dist` ×3, hook suites ×3,
  meta suite, eval self-test. The change under test is a 420-character markdown rule.
- **Not a configured timeout.** `grep -rn timeout .github/workflows/` returns nothing; GitHub's
  default job timeout is 6 hours.
- **Not an Actions quota.** The repository is **public** (`private=false`), so Actions minutes are
  not metered.
- **Not `fail-fast`/concurrency.** `ci.yml` declares two independent jobs, no matrix, no
  `concurrency:` block.

**The part that makes this P1 rather than a curiosity — we were already at the edge and nobody
measured it.** Recent green runs, wall clock:

| commit | duration |
|---|---|
| `b1e24b5` | 12m27s (windows leg 12m24s, linux 5m24s) |
| `5eeda5d` | **14m33s** |
| `e88f8eb` | 12m36s |
| `ef38832` | 11m12s |
| `7ff3e2b` | 12m10s |

Every green run fits under 15 minutes; the longest cleared it by 27 seconds. **The windows leg is the
long pole and it has been running at 80–97% of a ceiling nobody knew existed.** So this is not "one
unlucky run" — the repo has been one small slowdown away from being unable to release, and B-88 will
correctly refuse to tag every time it happens. B-101 measured and optimised the *local* gates
(1,027s → 270s); nothing has ever measured CI duration, and no signal exists for approaching a limit.

> **CAUSE FOUND 2026-08-06: GitHub Actions was in a `major_outage`.**
> `curl https://www.githubstatus.com/api/v2/components.json` → the `Actions` component reports
> `"status":"major_outage"`. Repo-side Actions config is healthy
> (`repos/.../actions/permissions` → `enabled:true, allowed_actions:"all"`), so nothing here caused
> it and nothing here can fix it.
>
> **The evidence that settles it, and it arrived in the order that made it obvious:**
>
> | commit | what it changed | outcome |
> |---|---|---|
> | `beface1` | the v0.48.0 release | both legs cancelled at exactly 15m01s |
> | `e90adac` | **`meta/BACKLOG.md` only — one markdown file** | both legs cancelled at exactly 15m01s |
> | `68cf0aa` | the CI split below | **no workflow run was created at all** |
>
> A commit touching one markdown file cannot produce a 15-minute build, let alone a cancelled one.
> That row alone rules out repo content; the third rules out "slow build hits a ceiling" entirely,
> because the platform stopped scheduling runs.
>
> **Correction to this entry as first written.** It framed the 15-minute boundary as a *ceiling the
> windows leg was creeping toward* and made that the P1. The duration data was real — recent green
> runs at 11–14.5 minutes, the longest clearing by 27 seconds — but the causal story was **wrong**,
> and it was wrong in the direction of blaming the thing I had just changed. The 15m00s figure is an
> outage artifact, not a configured limit. Left visible rather than rewritten: this is the same
> failure shape the entries above it are about — a confident explanation that fit the data and was
> not the cause.
>
> **What survives the correction, and is still worth doing:** the margin genuinely was thin. A
> 12–14.5 minute windows leg with a 27-second worst-case margin is fragile regardless of what
> cancelled it, and the split below stands on its own merits. But it must be re-verified once
> Actions recovers — **it has never had a green run**, so it is currently an unvalidated change to
> the one system that validates everything else.
>
> **Do first, when Actions recovers:** re-run CI on `68cf0aa` and confirm (a) all eight jobs appear,
> (b) the matrix legs actually execute, (c) `watch-ci.ps1`'s extended `ExpectedJobs` matches the real
> job names — GitHub's `<job> (<value>)` naming is assumed, not observed. Then re-run the release to
> tag v0.48.0.

**Do:** (1) ~~establish what is doing the cancelling~~ — **answered: a GitHub Actions outage.** Retained
so the reasoning that led there is not lost. (1) establish what is doing the cancelling — a GitHub-side incident, an account/org runner
policy, or something in this environment; the 15m00s boundary is too exact to be coincidence, and it
is the one fact that would identify the mechanism. (2) Independently of the cause, get the windows leg
well clear of 15 minutes — it duplicates work the linux leg already does, and B-101's parallelisation
of `ValidateDist.Tests` was applied to the meta suite but the shipped hook suites (~174–217s per dist)
still run serially per dist in CI. (3) Add a duration signal: print each leg's elapsed time and warn
past a threshold, the same treatment B-101 gave `validate-dist` per-check timings.

**Not:** do not tag v0.48.0 with `-AllowUnverifiedCi` to get past this. That switch exists and is
honest — it records the waiver in the tag annotation — but using it to paper over an unexplained,
*reproducible* cancellation would put a "CI-verified" tag on a build nobody has seen pass. That is
precisely the claim the tag is supposed to carry.

**Status:** v0.48.0 is **on `master` and pushed (`beface1`) but UNTAGGED** — the documented safe state
(`release.ps1` prints it explicitly). Re-running the identical release command re-watches and tags if
CI comes back green; nothing needs unwinding.

> **NEW, 2026-08-07 — `68cf0aa` also broke the meta suite, and that now blocks every release.**
> Found while shipping B-96, which cannot reach its own ship gates because of it. `ReleaseCiWatch.Tests`
> reports **5 failures**; `release.ps1` gates on the meta suite (`:271`), so **no release can be cut
> until this is fixed** — including v0.49.0.
>
> **Cause, confirmed rather than inferred.** `68cf0aa` extended `watch-ci.ps1`'s default
> `ExpectedJobs` (`:47`) to the six split legs — `windows-hooks (dotnet|angular|monorepo)`,
> `linux-hooks (…)`. Five test fixtures still register only the old two jobs, so the watcher correctly
> returns `EXIT=3 CI CANT-VERIFY: expected CI leg(s) not present … Jobs observed: linux, windows`.
> `git log -- .claude/scripts/watch-ci.ps1` shows `68cf0aa` as the last change to that file; B-96's
> diff touches no file under `scripts/` at all.
>
> **The five are not about job naming.** They test *watcher logic* — a `pull_request` run must not
> decide the release, a re-run supersedes an earlier failure, polling reaches a terminal state, query
> scoping. Each broke incidentally because its stub job list no longer covers the widened default.
> Updating those stubs restores them to testing what they exist for.
>
> **What updating them must NOT be mistaken for.** It does not verify the real job names. This entry
> already records that GitHub's `<job> (<value>)` naming is *assumed, not observed*, and Actions being
> down is exactly why it still cannot be observed. That assumption lives in `watch-ci.ps1`'s default
> and is equally unverified before and after. Do not let a green meta suite be read as confirmation
> of the naming — the "Do first, when Actions recovers" checklist above stays owed in full.
>
> **Effort:** S. **Priority: P1** — it is now on the critical path of every release, not just this one.
>
> **FIXED 2026-08-07 (v0.49.0). And the naming question above is now ANSWERED BY OBSERVATION.**
> CI run `31168445026` produced exactly eight jobs — `windows`, `linux`,
> `windows-hooks (dotnet|angular|monorepo)`, `linux-hooks (dotnet|angular|monorepo)` — matching
> `watch-ci.ps1`'s widened default. The six split legs each ran in **1:21–3:16**, nowhere near the
> 15-minute ceiling. So all three items on the "Do first, when Actions recovers" checklist are
> discharged: eight jobs appear, the matrix legs execute, and `ExpectedJobs` matches the real names.
> The `<job> (<value>)` shape is no longer an assumption. **The 15-minute cancellation is gone —
> `68cf0aa`'s split worked, and the outage that masked it has passed.**
>
> **The fix is structural, not a patch.** `New-Jobs` in `ReleaseCiWatch.Tests.ps1` no longer restates
> the leg list; it **derives it from `watch-ci.ps1`'s own `-ExpectedJobs` default** by AST. Restating
> it is precisely what drifted. Red-tested both directions: widening `ExpectedJobs` with a brand-new
> leg — the exact `68cf0aa` scenario — leaves the suite **18/18 green** because the stubs follow
> automatically, and removing the parameter fails **loudly** (14 failures), never silently.
> **This breakage class cannot recur by omission.**
>
> **What this cost while it was open, worth remembering:** five stubs that had nothing to do with job
> naming — they test that a `pull_request` run does not decide a release, that a re-run supersedes an
> earlier failure, that the watcher polls to a terminal state, and that queries are scoped — blocked
> *every* release for a day, including a documentation-only one. That asymmetry is the argument for
> `-AllowFailingGate`, added in the same release.

**Cross-links:** B-88 (the watch that caught it and is working correctly), B-101 (gate runtime — the
local half of this, and its "nothing measures cost" thesis now has a CI-side instance), B-70 (a change
is not done until CI is green — which is now unachievable through no fault of the change).

---
### B-114 · Two entries both claim the id `B-113` — **DONE 2026-08-08, see Done section**
**Effort:** XS · **Priority:** P3 · found 2026-08-07 while filing B-115..B-118

**Why:** `### B-113 · Post-ship review owed for v0.48.0` and `### B-113 · CI is being cancelled at
exactly 15 minutes` are both live entries with the same id. Every cross-link written as "B-113" is
now ambiguous, including the one in v0.49.0's CHANGELOG ("B-113 records that `68cf0aa` extended the
watcher's `ExpectedJobs`"), which meant the CI entry — a reader following it to the post-ship-review
entry learns nothing about `ExpectedJobs`.

**Why no gate caught it:** nothing parses this file. Ids are allocated by reading the tail and adding
one, which fails exactly when two items are filed from different sessions on the same day.

**Do:** renumber the *post-ship review* one (it has fewer inbound references) and add a duplicate-id
check to the meta suite — a five-line scan over `^### B-\d+`, in the file that already sweeps this
repo's documentation for truth.

---
### B-115 · Pure SQL / SSDT / dbt repos cannot be installed, and `/adopt` cannot run in one
**Effort:** S · **Priority:** P3 · found 2026-08-07 (dimension-binding work)

> **DONE in v0.51.0.** Root fallback uses the shared category signal table after application-stack
> detection misses; PowerShell/Bash behavior tests install a pure-SQL fixture without a solution.

**Why:** three independent blocks, none of which the installer reports as a stack problem:
1. auto-detect covers only `*.csproj`/`*.sln`/`angular.json`, so a bare `.sqlproj`, a dbt project, or
   a plain `Tables/`+`StoredProcedures/` tree hard-errors with "Could not determine the stack"
   (`install.ps1:57,63,65`; `install.sh:62,67,69`). `-Stack dotnet` works and is named nowhere the
   consumer will look.
2. `/adopt` Phase 0 step 3 is "**Locate the solution root** — find the `.sln` file. All paths are
   relative to this root" (`adopt.md:53`). `/adopt` is the brownfield path an existing warehouse
   actually takes, so this stops the very repo the warehouse skills exist for.
3. pre-bootstrap, the shipped `CLAUDE.md` says "defer to `docs/defaults.md` for greenfield **.NET**
   conventions" (`src/stacks/dotnet/snippets/CLAUDE.md/defaults-comment`) — a technology claim about
   a repo that evidences no .NET, i.e. exactly the class Verification Rule 10 exists to prevent.

**Not urgent for the current consumer set** — the reporting maintainer's repos all carry a `.sln`
alongside the SQL warehouse, so all three blocks are bypassed. Filed because the guidance is aimed at
warehouses and a warehouse-only repo is the shape most likely to want it.

**Do:** add a SQL fallback to detection, evaluated **only after** dotnet and angular both miss so a
mixed repo still resolves to `dotnet`, and gate it on the **≥2 warehouse signals `map-warehouse`
step 0 already defines** — reuse that list rather than inventing a second one, or the two will drift.
Generalise `/adopt`'s root-finding. Make the pre-bootstrap pointer technology-neutral (it costs
static budget — measure it).

**Rejected in advance:** a `sql`/`warehouse` dist. WSD-020 and WSD-021 both call that the wrong
altitude, and nothing here changes that.

---
### B-116 · `route-prompt` has no data or warehouse vocabulary
**Effort:** S · **Priority:** P3 · found 2026-08-07 · **Cross-link:** B-98 (the general routing question)

> **DONE (no code) in v0.51.0.** The write-side baseline routed correctly, so warehouse regexes
> were not added without evidence of a failure.

**Why:** "implement a new import into the data warehouse" classifies as a generic `feature` on
`\bimplement\b` (`route-prompt.ps1:140`), and `$railsFeature` never mentions skills, `docs/`, or the
warehouse map. The prompt most characteristic of a warehouse consumer therefore gets rails written
for application features. This is not a claim that adding keywords would fix it — B-98 step 2 found
that broadening a `description` is the mechanism the `r=0` observation *weakens*. It is a claim that
the router is currently silent on an entire delivery surface, and nobody had written that down.

**Do:** nothing standalone. Fold into B-98's general question, and settle it with the write-side
baseline (`meta/eval-results.md`, dimension-binding Stage A) rather than by adding regexes on
intuition.

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
### B-118 · RCA: a recipe listed what to build without ever asking whether it should exist
**Effort:** S (the sweep) · **Priority:** P2 · filed 2026-08-07 · **Cross-link:** B-112 (sibling class)

> **DONE in v0.51.0.** The warehouse, endpoint, entity, DI service, Angular component/service,
> lazy-route, and signal-store recipes now search for an existing owner before scaffolding.

**Why:** `add-warehouse-load` shipped in v0.31.0 and was revised through v0.49.0 without anyone
noticing that it goes from "find a load pattern to copy" straight to "design the entity" — it never
asks *whether the dimension already exists*. The commonest real warehouse task is a new fact against
dimensions that all already exist, and the recipe's structure quietly assumes the opposite.

**Why no gate caught it.** None could, and that is the point. `validate-dist` proves the file is
present, parses, mirrors to `.github/skills`, and leaks no meta vocabulary. `no-dead-instruction`
proves every script it names exists. **Every gate we have checks that the guidance is well-formed;
none checks that it is complete.** The B-96 field report is the same shape one layer over: the map
was a valid document that omitted the thing a reader needed.

**What else is exposed to the same class — sweep, the answer is not "nothing".** Any instance-shaped
`add-X` skill that enumerates construction steps without a preceding *should this exist / does it
already exist* decision. First-pass candidates, to be confirmed by reading rather than assumed:
`add-endpoint` (does this route already exist under another name?), `register-service` (is there
already a service doing this?), `add-entity` (is this a new table or a column on an existing one?),
`add-component`/`add-service` on the Angular side. `add-tests` is likely exempt — it is process-
shaped, not instance-shaped, and its subject already exists by definition.

**Do:** read each candidate for a missing reuse gate; add one only where a real duplicate is
plausible in that stack. Do not mass-apply a template — that would be the "recipe lists what to
build" failure repeated at the meta level.

---
### B-119 · The dimension-binding post-change arm is owed — v0.50.0 shipped an unproven fix

> **DONE 2026-08-08.** Re-ran `warehouse-bind-mixed` ×2 against v0.50.0 (`2915412`), both completed
> cleanly (no spend-cap error this time): `regionOnFact` **0/2**, `Pass` **2/2** — the floor of the
> pre-registered range, not the ambiguous middle. **The dimension-binding step works on the defect it
> was written for.** Full write-up in `meta/eval-results.md` under "POST-CHANGE ARM — COMPLETE".

**Effort:** S (one arm, ~$5) · **Priority:** **P2** · filed 2026-08-07 shipping v0.50.0

**Why:** the Stage A baseline established the defect — on the `warehouse-mixed` fixture the model put
`RegionKey` directly on the new fact **2/2 counted (3/3 including the uncounted batch)**, while the
pure-SQL fixture bound correctly 2/2. v0.50.0 ships the dimension-binding step that targets exactly
that. **Whether the step changes the behaviour is unmeasured.**

The post-change arm ran against the released dist and got **one of two** scenarios: `bind-sql`
**PASS** (no regression, under the stricter resolution criterion). `bind-mixed` — the only fixture
that ever exhibited the defect — terminated on `api_error_status: 429`, *"You've hit your monthly
spend limit"*, having produced no SQL at all. Environment stop, not a result.

**The trap this leaves in the record, stated so nobody walks into it:** that run's `Detail` reads
`regionOnFact=False newDimTables= naturalKeyOnFact=False` — every value the *desired* one. All three
are artifacts of `factWritten=False`. Anyone skimming `meta/eval-results.md` for a post-change number
will find a row that looks like a clean pass and is nothing of the kind. The row is annotated in
place; this entry exists because annotations get skimmed too.

**Do:** re-run `warehouse-bind-mixed` ×2 against v0.50.0 (`2915412`), `sonnet`, `-TimeoutSeconds 900`,
once budget allows. Thresholds are **already pre-registered** in `meta/eval-results.md` (post-change
arm) — do not re-derive them after seeing the output: `regionOnFact` 0/2 = works, 1/2 = partial ship
with a stated ceiling, 2/2 = **it does not work**, record that plainly.

**Cross-links:** B-118 (the RCA that produced the step), B-117 (the disambiguation class this arm's
`reachedAddEntity=0/6` did *not* discharge).

---
### B-120 · A produce-nothing run scores every per-signal field as its desirable value
**Effort:** XS · **Priority:** P3 · filed 2026-08-07 · **Cross-link:** B-112 (instrument class)

> **DONE in v0.51.0.** No-fact runs are INCONCLUSIVE and emit `n/a` for artifact-derived fields;
> the self-test includes an engaged successful-tool transcript that produces no output.

**Why:** in `warehouseDimensionBinding`, every absence-shaped signal (`regionOnFact`,
`naturalKeyOnFact`, `newDimTables`) is computed from a fact body that is the empty string when no
fact was written. A run that produces nothing therefore reports the same values as a perfect run.
`Pass` is safe — it requires `factWritten` — and `Status` is `INCONCLUSIVE` when nothing was produced
*and* no warehouse-tree tool call was made. But a run that made tool calls and then died mid-flight
falls through both, as the B-119 run did; it graded `ERROR` only because the harness separately
checks `agentExit`. Had the CLI exited 0 after an early stop, the row would have looked clean.

**Why no gate catches it:** the self-test's non-engagement case has no tool calls, so it exercises the
`INCONCLUSIVE` path and never the "engaged, then produced nothing" one.

**Do:** emit `n/a` rather than `False` for every field derived from `$factBody` when `factWritten` is
false, and add the missing self-test case — a transcript with successful tool calls and an empty
target tree. Sweep the other graders for the same shape: **an absence-shaped signal is
indistinguishable from a missing artifact unless the artifact's existence is reported alongside it.**

---

### B-121 · Post-ship review owed for v0.51.0

> **DONE (discharged) 2026-08-08.** Independent review by Claude Sonnet 5, separate session from
> the implementer. Re-ran validate-dist ×3 fresh (all 8 checks, all three dists), rebuilt all three
> dists and confirmed freshness, red-tested `no-meta-leak` (seen RED on a planted `WSD-999`, then
> GREEN restored), ran the dotnet hook suite and the meta suite (0 failures, 26 files total). No
> defects found in the v0.51.0 diff. Full evidence in `meta/review-ledger.md`.

---
### B-122 · Remove personal machine details from the public authoring repository — **DONE 2026-08-08, see Done section**
**Effort:** S–M · **Priority:** P3 · filed 2026-08-08 following B-109 · **Scope:** maintainer layer,
not shipped distributions

**Why:** B-109 established a generic gate preventing account-qualified home paths from reaching a
composed distribution, but the public authoring repository still contains personal machine details.
Observed on 2026-08-08: 30 tracked case-insensitive occurrences of the maintainer's name or GitHub
handle, including unnecessary `C:\Users\<account>\...` and `/c/Users/<account>/...` paths in
maintainer scripts, operational documentation, backlog evidence, decision records, and eval output.
The three `dist/` trees contained zero occurrences of the maintainer's name. Some authoring-repo
identity is intentional and public — the MIT copyright attribution and GitHub repository URLs — so
this is a classification and sanitisation task, not a blind text replacement.

**Do:** inventory every tracked account-qualified home path and personal-name occurrence, classify
each as required public identity or incidental machine detail, then:
1. replace incidental paths in prose/evidence with stable placeholders such as `<home>`,
   `<username>`, or `<repo>` without falsifying the recorded technical result;
2. replace hard-coded maintainer paths in executable scripts with parameters, environment variables,
   or existing host-resolution helpers, with behavioural tests for any changed executable;
3. preserve `LICENSE` attribution and repository-owner URLs unless the maintainer explicitly chooses
   otherwise;
4. add a repository-level gate for account-qualified home paths outside fixtures, distinct from
   B-109's distribution boundary, with narrow allow rules for deliberate test fixtures and an
   executable red test on Windows, Linux, and macOS forms;
5. record an explicit decision on Git history. Working-tree cleanup does not erase already-pushed
   commits; history rewriting requires a separate, maintainer-approved migration because it changes
   every descendant commit and affects collaborators, tags, and forks. Do not rewrite history as
   part of this item without that approval.

**Done when:** the tracked-tree sweep reports no incidental personal machine paths; every remaining
name/handle occurrence is enumerated and justified; affected scripts still pass their behavioural
tests; the new prevention gate has been observed red on planted generic fixtures and green on the
clean tree; and the history-retention/rewrite decision is recorded.

---
### B-124 · Decide whether a warehouse change belongs in an existing fact or a new fact — **CLOSED 2026-08-09, premise rejected; see Done**
**Effort:** M · **Priority:** P2 · filed 2026-08-08 · **Capability:** warehouse technical leadership

**Final status (2026-08-09): premise rejected.** Design/eval instrument:
`.claude/plans/2026-08-09-b124-fact-binding-design.md`. Opus rev 1 rejected the first design; rev 2
required a non-telegraphing `n>=2` ambiguous-pair baseline before premise lock. The corrected
instrument is red/green self-tested. After invalid spend-limit runs were excluded, the unchanged
skill chose the intended existing/new fact in 2/2 runs each. The registered stopping rule therefore
rejects the shipped matrix as unproportionate; no distribution change was made.

**Why:** `add-warehouse-load` now asks whether a dimension already exists, but it has no equally
explicit decision for facts. A new measure or business event can therefore be placed in a new fact
unnecessarily, or added to an existing fact whose grain, lifecycle, dimensionality, sparsity, or
loading semantics are incompatible. Either failure fragments a business process or creates a
mixed-grain fact whose numbers are easy to misinterpret.

**Do:** design a fact-binding decision that inspects the warehouse map and live repository evidence
before DDL is proposed. Compare business process, declared atomic grain, dimensionality, event
frequency and lifecycle, measure additivity, source authority, update/load semantics, and existing
consumer contracts. The outcome must distinguish: extend an existing fact, create a new fact,
model a separate snapshot/accumulating snapshot, or abstain pending a named missing fact. Explain
the evidence and trade-off; do not infer compatibility from similar table names.

**Framework fit:** integrate with B-125's modelling findings, B-126's change-impact contract,
B-127's scoped lineage, and B-128's physical review. Reuse `map-warehouse` and
`add-warehouse-load`; do not create a competing warehouse inventory or a second generic workflow.
Preserve evidence/confidence labels, bounded tracing, and explicit abstention.

**Design/review gate:** write and lock a design before implementation, including the proportionality
case and at least two approaches. Then obtain an independent adversarial review with **Claude Opus**;
the review may reject the premise. If Opus is rate- or spend-limited, mark the review **WAITING —
OPUS LIMIT** and continue only work that is independent of this item's implementation. Do not
substitute a lower tier and call the review complete.

**Done when:** ambiguous existing-vs-new fact fixtures have a pre-registered red baseline and a
constructible success case; post-change evals demonstrate the intended choice without mixed grain;
all applicable dists carry the guidance; and B-41 records whether the behavior is reliable enough
to ship.

---
### B-125 · Produce an evidence-ranked warehouse modelling health review — **DONE 2026-08-10**
**Effort:** M–L · **Priority:** P2 · filed 2026-08-08 · **Capability:** warehouse technical leadership ·
**Design:** `.claude/plans/2026-08-09-b125-warehouse-modelling-health-review-design.md` (rev 14;
Opus reviews plus user-authorized fresh Sol review; final verdict `ACCEPT — ship: YES`)

**Why:** the warehouse map reports several local findings, but it is not yet a systematic modelling
review. The framework can describe a model without consistently challenging mixed or unstated
grain, the wrong fact type, missing many-to-many bridges or allocations, duplicated/non-conformed
dimensions, inappropriate snowflaking, natural keys on facts, ambiguous special members, incorrect
measure additivity, or unsafe fan/chasm paths. The framework's premise requires it to surface these
issues and propose proportionate improvements, not merely catalogue tables.

**Do:** design a bounded review mode or extension to `map-warehouse` that checks dimensional
semantics and produces findings with evidence, confidence, severity, consequence, and a suggested
remediation. It must separate an observed defect from a convention preference, show uncertainty,
and avoid proposing a remodel without considering migration cost and downstream consumers. Include
the common fact, dimension, bridge, role-playing, conformance, SCD, special-member, and additivity
failure classes, while allowing repository-specific conventions to override generic advice when
they are explicit and coherent.

**Framework fit:** this is the shared modelling-analysis layer consumed by B-126, B-127, and B-128.
B-124 closed without a shipped dependency; its retained regression scenarios are evidence only.
Extend the existing map/finding vocabulary rather than creating a parallel architecture
document. Keep the default pass cheap; deeper tracing must remain scoped and on demand.

**Design/review gate:** locked design plus proportionality case, followed by an independent
adversarial **Claude Opus** review before implementation. If Opus is unavailable because of limits,
record **WAITING — OPUS LIMIT** and proceed only with independent design/backlog work.

**Done when:** planted-model fixtures make each claimed detector visibly fail before the change and
pass after it; clean and intentionally unconventional fixtures do not receive false defect claims;
recommendations cite repository evidence; and behavioural evals show the model uses the findings
rather than merely reproducing them.

**Done:** `map-warehouse` now emits structured evidence/confidence/severity/consequence/remediation
findings, applies evidence-gated modelling-health checks, and offers bounded allocation/fan-chasm
deepening. Rev-14 fixtures cover each supported detector plus clean, explicit-convention,
no-trigger, and existing-correct-bridge controls. The downstream scenario is finding-led and
requires direct load/consumer reads plus a safe one-as-of-date decision. Claude live reruns were
unavailable after HTTP 429 monthly-limit errors; the user authorized fresh Sol high-reasoning
substitution, whose final verdict was `ACCEPT — ship: YES` after independently rerunning the suite.

**RCA:** the first evaluator encoded expected words and confidence tiers before proving that the
fixture supported those conclusions. Reachability self-tests showed the matcher could turn green
and red, but could not establish that its answer key was true; correlated inherited defects hid the
problem. The corrected gate binds claims to direct artifacts/tool events, uses counterfixtures for
absent triggers, conventions, and already-correct structures, validates the full Findings contract,
and mutates plausible contradictory outputs rather than only missing keywords.

---
### B-126 · Make dimension and fact enhancement safe across downstream warehouse consumers
**Effort:** M–L · **Priority:** P2 · filed 2026-08-08 · **Capability:** warehouse technical leadership

**Why:** deciding to reuse an existing dimension or fact is only the first decision. The current
recipe does not require a complete change-impact argument for attribute ownership, per-attribute
SCD behavior, source-authority conflicts, historical backfill, null/default semantics, grain or type
changes, or affected views, marts, procedures, semantic models, reports, exports, and external
contracts. A locally correct ALTER can still break the warehouse's overall design.

**Do:** design a warehouse schema-evolution preflight used before enhancing an existing fact or
dimension. It must identify upstream authority and downstream consumers, classify compatible versus
breaking changes, define history/backfill and deployment sequencing, preserve old consumers during
migration where required, and state rollback/deprecation obligations. It must establish the named
target fact/dimension from live evidence (B-124 shipped no separate decision artifact), consume
modelling findings from B-125 and scoped lineage from B-127; physical
consequences route to B-128 rather than being reinvented here.

**Framework fit:** add a composable preflight to the existing warehouse change workflow. Do not turn
`add-warehouse-load` into an exhaustive global scan: request deeper evidence only for the entities
and consumers touched by the proposed change, and abstain when the dependency graph is incomplete.

**What established practice says (checked 2026-08-11):** Kimball's dimensional guidance makes
fact grain uniformity and per-attribute SCD treatment semantic contracts, not incidental table
details; a Type 2 change creates a new surrogate-keyed row and changes which version future facts
reference. Fowler/Sadalage's evolutionary-database practice requires versioned migrations,
automated data movement, consumer-contract testing, and collaboration with people who can see
dependencies beyond the immediate application. Parallel Change supplies the compatible
expand → migrate → contract sequence for interfaces with multiple consumers. Microsoft's current
Power BI guidance says to inspect lineage and impact before changing a shared semantic model, test
dependent reports, and interpret the result as *potential* impact rather than proof of failure; its
architecture guidance likewise recommends compatibility with at least the preceding schema and
sequencing destructive changes across releases. Sources:
[Kimball SCD overview](https://www.kimballgroup.com/2008/08/slowly-changing-dimensions/),
[Kimball Type 2](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/type-2/),
[Kimball fact-table grain](https://www.kimballgroup.com/2003/01/fact-tables-and-dimension-tables/),
[Fowler/Sadalage evolutionary database design](https://www.martinfowler.com/articles/evodb.html),
[Fowler Parallel Change](https://martinfowler.com/bliki/ParallelChange.html),
[Power BI semantic-model impact analysis](https://learn.microsoft.com/en-us/power-bi/collaborate-share/service-dataset-impact-analysis),
and [Azure schema-update guidance](https://learn.microsoft.com/en-gb/azure/architecture/guide/multitenant/approaches/storage-data).

**Fresh-context adversarial review (Codex, 2026-08-11; does not satisfy the Opus gate):** verdict
**REJECT pending redesign and unchanged-skill baseline**. The first candidate assumed a behavioral
gap from missing prose, made `compatible in-place` unreachable by asking static repository evidence
to prove every runtime consumer, misstated the whole-file composition layout, conflated relationship
and finding vocabularies, depended on unimplemented B-127/B-128 work, and specified fixture topics
rather than discriminating graders. It also treated compatibility as one property when schema,
semantics, history, deployment, privacy, and rollback can disagree. The revised plan below folds
those findings. It remains unlocked and must receive a fresh Opus review after the redesign.

**Implementation plan — revised design candidate:**

1. **Test the premise before authorising shipped edits.** Freeze at least two non-telegraphing paired
   fixtures, expected artifacts, three-or-more repeated runs per available agent surface, direct-read
   observations, truncation/inconclusive rules, and grader mutations. Include (a) a repository-closed,
   genuinely compatible existing-dimension change and (b) identical additive DDL made incompatible
   by a visible consumer; add grain/SCD and incomplete-external-consumer cases. Run the unchanged
   `add-warehouse-load`. Stop with no shipped change if it reliably inventories the right evidence,
   distinguishes the pair, preserves uncertainty, and produces an executable migration decision.
2. Define evidence closure before grading safety. **Repository-visible compatibility** enumerates
   what the scan actually found and never implies completeness. **Deployment approval** additionally
   requires a stated closed-world premise or named owner/catalog/runtime attestation for external
   consumers, operational constraints, and authority. Name the constructible evidence world for
   every outcome; unavailable or access-limited evidence is `Unknown`, not a pass or an affected
   consumer. `Potential consumer` and `confirmed dependency` remain distinct.
3. Only if the baseline proves a material gap, add a bounded **Evolution preflight** section to
   `add-warehouse-load` after the skill has proved the target entity and before it writes DDL/load
   logic. Trigger it only for an existing fact/dimension change; a new entity continues through the
   existing path. The actual sources are the dotnet whole-file mirrors at
   `src/stacks/dotnet/files/{.claude,.github}/skills/add-warehouse-load/SKILL.md`; composition carries
   them into dotnet and monorepo. There is no monorepo source sibling and no new skill or
   always-loaded instruction.
4. Build an evidence packet for only the named entity and proposed fields: current declared and
   effective grain; keys and dependent facts; each field's source authority, type/null/default and
   SCD/history policy; load and backfill code; repository-visible views, procedures, marts, exports,
   semantic/report artifacts, tests, and deployment references. Reuse the fresh warehouse map and
   B-125 Findings. Until B-127 exists, permit only a minimal direct trace through already-open SQL
   and named repository references; mark the boundary and request deeper lineage instead of claiming
   B-127 was consumed or implementing a general lineage graph.
5. Emit a compact change matrix with one row per proposed semantic change: `Change`, `Current
   contract`, `Proposed contract`, `Evidence`, `Upstream authority`, `Affected consumers`,
   `Compatibility dimensions`, `History/backfill`, `Deploy sequence`, `Verification`, and `Open
   owner`. Define claim status separately (`Observed`, `Reported/attested`, `Inferred`, `Unknown`)
   rather than pretending it is the map's relationship or B-125 finding vocabulary. Grade schema,
   semantic, historical, privacy/security, deployment, and rollback compatibility independently per
   consumer before deriving a recommendation. Classify compatibility per consumer, not from DDL
   shape: additive nullable data can still change row
   counts, SCD interpretation, measures, wildcard extracts, or security exposure. Separate
   potential from confirmed impact.
6. Require an explicit invariants check before recommending reuse: no silent grain change; no
   attribute moved between authorities without conflict resolution; SCD behavior stated per changed
   attribute; unknown/null/default-member semantics preserved or migrated; fact/dimension key and
   effective-date resolution intact; historical recomputation policy named; reconciliation totals
   and privacy/security exposure considered. A grain change, key reinterpretation, destructive type
   change, or changed historical meaning defaults to breaking for the relevant dimension unless the
   explicitly bounded evidence proves otherwise.
7. Produce one of three decisions: **repository-compatible candidate** (with enumerated coverage,
   migration/backfill and consumer tests; deployment approval still separately gated),
   **parallel evolution** (expand with a new field/view/version, dual-write or backfill,
   migrate named consumers, observe, then contract after an owner/date/deprecation gate), or
   **stop/abstain** (authority, lineage, runtime consumer, or rollback evidence is missing). Never
   describe rollback as simply reversing DDL after consumers or history have changed; name restore,
   replay, or forward-fix mechanics and the last safe point. For parallel evolution name the
   authoritative pre-cutover write path, dual-write/backfill reconciliation, cutover and abort
   criteria, backup/restore assumptions, replay boundary, post-cutover writes, and the point where
   rollback becomes compensating forward migration.
8. Keep minimum operational feasibility here: backfill volume/window, locks, log growth, partition
   mechanics, deploy ordering, and last-safe-point evidence determine whether the migration is
   executable. Route optimisation and broader physical-design judgment to B-128. Likewise do not
   duplicate B-129's reporting-interface design; here a report/semantic model is a contract to
   preserve, test, migrate, and deprecate, while B-129 owns choosing/designing a new publication
   surface.
9. Expand the pre-registered fixtures only if the unchanged baseline fails. Cover: a truly compatible
   nullable descriptive Type-1 attribute; the same DDL with a `SELECT *` extract or sensitive-field
   exposure (not automatically safe); a Type-1→Type-2 policy change; a fact-grain change; a widening
   and a narrowing/type-semantic change; historical backfill with late-arriving facts; an external
   or access-limited semantic consumer; and incomplete lineage. Plant mutations that omit a
   consumer, call every `ADD COLUMN` safe, fabricate rollback, or confuse potential with confirmed
   impact. Bind grader assertions to the correct entity/consumer and direct artifact reads; include
   clean/convention counterfixtures, contradictory prose, empty/truncated output, and independent
   mutations for lineage, compatibility, sequencing, and rollback. The abstention cases alone cannot
   prove discrimination. Show every grader red and green.
10. After implementation, run the repeated behavioral matrix, then greenfield, brownfield, and update
   delivery through both installer twins and applicable root stack-detection paths. Verify both skill
   mirrors refresh as intended without overwriting protected consumer material. Success requires the
   correct evidence boundary, dimension-level compatibility result, and usable migration sequence,
   not checklist words. Then compose/freshness and `validate-dist` ×3; Angular behavior stays
   unchanged, while release-wide version/changelog stamping remains expected.

**Proportionality:** the current evidence proves a prose omission, not behavioral harm. The unchanged
baseline is therefore the smallest response and can close the item without a shipped change. Only a
reproduced decision defect authorises one demand-triggered section in an existing skill. A persistent
lineage service, warehouse-wide graph, schema registry, or new routed skill remains out of scope
until B-127/B-42 supplies observed evidence that the bounded repository scan is insufficient.

**Status: AWAITING OPUS REVIEW.** The plan above is not locked and authorises no implementation.
The fresh-context review must be licensed to reject the premise, challenge whether the evidence
packet is reachable from static repositories, test the proportionality claim, and require a second
pass after any material redesign. If Opus is unavailable, retain `WAITING — OPUS LIMIT` rather than
substituting a lower-tier verdict.

**Design/review gate:** locked design plus proportionality case, followed by an independent
adversarial **Claude Opus** review before implementation. If Opus is limited, record **WAITING —
OPUS LIMIT**; design of another independent item may continue, but implementation may not.

**Done when:** fixtures cover safe additive evolution, SCD-policy change, historical backfill, grain
or type breakage, and a downstream semantic/report consumer; the framework names affected artifacts
and a compatible migration path; and evals prove it does not treat every additive column as safe.

---
### B-127 · Trace a warehouse attribute or metric from source to consumption on demand
**Effort:** M–L · **Priority:** P2 · filed 2026-08-08 · **Capability:** warehouse technical leadership

**Why:** the map records entity-level flow, relationships, and consumption surfaces, but it cannot
yet explain a named attribute or metric end to end. Without scoped lineage the framework can miss
filters, derivations, defaulting, deduplication, effective-date resolution, currency/unit/time-zone
conversion, and semantic redefinition between source, staging, core facts/dimensions, marts, and
reports. Whole-warehouse column lineage would be costly and brittle; the need is a bounded trace
for the change or question at hand.

**Do:** design an on-demand trace that starts from a named source field, warehouse attribute,
measure, or reported metric and follows repository evidence in either direction. Record each
transformation, filter, join/key resolution, unit/currency/time-zone rule, aggregation, owning
definition, and consumer, with gaps and conflicts explicitly marked. Capture canonical metric
semantics where the repository defines them, but do not invent business definitions or claim
runtime lineage from static evidence alone.

**Framework fit:** enrich the existing warehouse map or a linked scoped artifact using its evidence
and confidence vocabulary. B-125 uses the trace for modelling findings, B-126 for impact, and B-128
for workload evidence; B-124's retained evals may use it in future regression fixtures, but there is
no shipped B-124 consumer. The trace must be demand-driven and
budgeted, not an always-on whole-repository graph.

**What established practice says (checked 2026-08-11):** OpenLineage's current column-lineage
facet distinguishes a value-producing `DIRECT` dependency from `INDIRECT` influences such as
joins, filters, grouping, sorting, windows, and conditions, then records transformation subtype,
description, and masking. That distinction prevents a trace from claiming that a metric depends
only on the columns in its final expression. OpenMetadata supports column-level impact tracing but
also allows manual lineage where automation cannot surface it. Microsoft Purview's current docs are
more important for their limits than their happy path: stored procedures with create/drop patterns,
dynamic M parameters, non-Azure-SQL Power BI sources, process-mediated manual column links, and
several Fabric/Synapse paths can leave lineage incomplete. Kimball grounds a metric in the fact's
declared grain and distinguishes additive, semi-additive, and non-additive measures; for ratios the
additive components should be aggregated before division. A catalog edge or same-named field is
therefore evidence of a candidate path, not proof of semantic equivalence or runtime execution.
Sources: [OpenLineage column-lineage facet](https://openlineage.io/docs/spec/facets/dataset-facets/column_lineage_facet/),
[OpenMetadata column lineage](https://docs.open-metadata.org/latest/how-to-guides/data-lineage/column),
[Microsoft Purview lineage guide](https://learn.microsoft.com/en-us/azure/purview/catalog-lineage-user-guide),
[Power BI lineage limitations](https://learn.microsoft.com/en-us/purview/how-to-lineage-powerbi),
[Fabric lineage limitations](https://learn.microsoft.com/en-us/purview/data-map-lineage-fabric),
[Kimball facts and grain](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/facts-for-measurement/),
and [Kimball measure additivity](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/additive-semi-additive-non-additive-fact/).

**Fresh-context adversarial review (Codex, 2026-08-11; does not satisfy the Opus gate):** verdict
**REJECT pending baseline-first redesign**. The reviewer found that the first candidate conflated
connector-extracted lineage, captured execution, and runtime values; forced a branching lineage DAG
into a false ordered path; could manufacture metric authority from an implementation owner; gave no
executable search limits; overclaimed effective grain from static SQL; and made unimplemented
B-126/B-128/B-129 work acceptance dependencies. Persistence also conflicted with the map's fixed
seven-heading contract. The investigation-first plan below incorporates those findings and remains
unlocked.

**Implementation plan — revised investigation and conditional design:**

1. **Authorise only the unchanged-skill baseline now.** Freeze non-telegraphing forward and reverse
   questions, normalized edge answers, exact decisive-artifact reads, three-or-more runs per
   available agent surface, hard budgets, truncation/inconclusive rules, and grader mutations. Ask
   unchanged `map-warehouse` explicitly to perform the scoped second semantic pass it already offers
   (not an ordinary map refresh). Include one key-resolution trace it should solve today, one
   attribute trace, one branching metric, one conflict, and one budget-exhaustion case. Close or
   narrow B-127 without shipped changes if that behavior is already reliable and decision-useful.
2. Define the trace as one named **subject** and one named **question/direction**, not a
   whole-repository graph: source field → published attribute/metric, warehouse field/measure → sources and consumers,
   or reported metric → definition and inputs. Resolve ambiguous names before tracing; record exact
   fully-qualified identifiers, requested scope, start/end, and the warehouse-map freshness/boundary.
3. **Only if the baseline reproduces a material decision defect**, design an on-request **Trace one
   attribute or metric** mode in the existing `map-warehouse` skill. The sources are the dotnet
   whole-file mirrors at
   `src/stacks/dotnet/files/{.claude,.github}/skills/map-warehouse/SKILL.md`, composed into dotnet
   and monorepo. Do not add an always-routed skill, change Angular behavior, or run this semantic
   second pass during an ordinary map refresh.
4. Pre-register an executable search contract, then calibrate it from baseline cost without moving
   the thresholds after seeing correctness. Initial ceiling: one repository-wide indexed text
   reference search (report total hits, inspect at most the first 100 under deterministic
   path/identifier ranking), 16 files opened, graph depth 8, 12 candidate edges per frontier,
   4 semantic/publication artifacts, and 20k trace-task tokens. Maintain a visited node+artifact set
   to stop cycles. Terminate as `question answered`, `budget exhausted`, `ambiguous frontier`,
   `unsupported artifact`, or `external boundary`; list skipped candidates and the exact bounded
   continuation. Binary/remote semantic models are unsupported unless a directly readable export or
   connector record exists.
5. Emit a bounded trace **edge table**, not a linear path:

   | edge id | from node(s) | to node(s) | influence | operation | declared semantics | evidence coordinates | evidence dimensions |
   |---------|--------------|------------|-----------|-----------|--------------------|----------------------|---------------------|

   Stable node IDs permit branches, merges, multiple inputs/outputs, and cycles. `influence` is value,
   row selection, grouping/partition/order, key/version resolution, or conditional control;
   `operation` records identity, transform, aggregation, filter, join, group, window,
   conditional/default, deduplication, conversion, union, or semantic alias. Declared input/output
   grain, grouping, temporal rule, cardinality, and additivity are independently `Unknown` when the
   artifact cannot establish them. An optional narrative may summarize the graph but never replace it.
6. Keep evidence on four independent axes: **origin** (repository, catalog, execution event, human),
   **acquisition** (direct read, connector-extracted, run-captured, attested), **assertion** (declared
   transform, possible path, observed execution, observed value behavior), and **scope/time**
   (branch/version, environment, run/job ID, timestamp). Add completeness only as `none`, `bounded`
   with its enumerated frontier, or `externally attested`. Use map provenance only for its existing
   fact→dimension assertion. Static SQL never proves execution or effective cardinality; a captured
   run proves only that run; connector output inherits the connector's documented limits.
7. For a metric, add a **candidate semantic contract**, not a canonical one: implementation
   definition, publication definition, accountable business authority, authority evidence, event or
   declared grain, numerator/denominator or base measures, aggregation/additivity, dimensions,
   filters/exclusions, calendar/as-of rule, units/currency/time zone, null/default behavior, and
   publication consumers. Authority requires an explicit governance/convention artifact or named
   accountable attestation for that metric and scope; a developer, catalog owner, or model owner is
   not interchangeable with business authority. Preserve conflicting definitions separately and
   abstain. Include a fixture where a real governance artifact makes authority reachable.
8. Default to an ephemeral response. Persist only with explicit user approval to a separate
   `docs/warehouse-traces/<stable-subject-id>.md`, linked from the existing map Coverage or
   Dimensional-semantics section without adding an eighth required heading. Do not auto-retain or
   auto-delete traces. Record subject/question, verifier, verified date, source-map fingerprint, the
   normalized sorted list of decisive artifact paths+content hashes, coverage/frontier, and refresh
   triggers. A changed decisive hash or missing path marks it stale; replacement/retirement remains
   an explicit reviewed edit.
9. Design fixtures that discriminate rather than reward abstention: direct rename; derived measure
   with filter-only and join-key influences; deduplication/window; currency and time-zone conversion;
   ratio whose components must aggregate before division; SCD effective-date resolution; reverse
   trace from a semantic/report measure; conflicting definitions; dynamic SQL/external catalog gap;
   and a same-named decoy. Include clean controls and paired fixtures where one predicate changes the
   correct answer. Mutate missing indirect edges, wrong direction, wrong grain, fabricated authority,
   false completeness, and plausible-but-wrong field binding; show every deterministic grader red
   and green and require direct reads of the decisive artifacts.
10. Measure utility, not document production. Use a self-contained decision such as whether report X
    must migrate before attribute Y changes, or whether metric Z aggregates its components before
    division; construct paired worlds whose correct outcome differs only at a decisive trace edge.
    Success requires the trace to change that decision correctly while staying within the budget;
    a complete-looking path that does not affect a decision, or a correct abstention on every case,
    is insufficient. B-125/B-126/B-128/B-129 may later consume the contract, but are not acceptance
    dependencies. B-128 receives only candidate query/physical paths; workload frequency, volume,
    latency, skew, and runtime use require separate telemetry or captured execution evidence.
11. After implementation, repeat behavioral trials on each available supported host and verify
    greenfield, brownfield, and update delivery through both installer twins and relevant root stack
    detection. Confirm delivery and update of both skill mirrors plus dotnet/monorepo composition.
    Separately use behavioral fixtures for trace/staleness
    semantics and a brownfield document fixture to prove an existing user-authored map/trace is not
    silently overwritten. Then compose/freshness and `validate-dist` ×3; Angular receives only
    release-wide stamps/changelog truth, not warehouse behavior.

**Proportionality:** the existing map already identifies edges, consumption surfaces, and offers an
on-request semantic second pass; no behavioral harm is yet observed. Only the unchanged-skill
baseline is presently proportionate and authorised. If it demonstrates a repeatable decision defect,
the smallest candidate is one demand-triggered bounded edge response, ephemeral by default. A
persistent service/graph, parser, catalog integration, whole-warehouse scan, automatic retention, or
new skill is not authorised.

**Status: AWAITING OPUS REVIEW.** This candidate is not locked and authorises no implementation.
The independent Codex critique above improved the candidate but does not clear the gate. Give this
revised investigation-first plan to Claude Opus, licensed to reject the baseline, evidence axes,
numeric budget, graph contract, persistence choice, and premise. If Opus is genuinely unavailable
due to limits, record `WAITING — OPUS LIMIT` rather than substituting a lower-tier review.

**Design/review gate:** locked design plus proportionality case, followed by an independent
adversarial **Claude Opus** review before implementation. If Opus is unavailable due to limits,
record **WAITING — OPUS LIMIT** and leave implementation blocked while independent work continues.

**Done when:** multi-stage fixtures prove forward and reverse tracing through SQL transformations
and a consuming semantic/report artifact; conflicting and absent evidence produce abstention rather
than a fabricated line; cost/coverage is reported; and evals show the trace changes a downstream
design or review decision.

---
### B-128 · Review warehouse physical design against its actual load and query workload
**Effort:** M–L · **Priority:** P2 · filed 2026-08-08 · **Capability:** warehouse technical leadership

**Why:** the framework records partitioning, columnstore, retention, and load ordering, but does not
systematically test whether physical design supports the warehouse's observed loading and access
patterns. Sound logical modelling can still fail through unsuitable partition keys, indexes,
columnstore layout, distribution/sharding, compression, statistics, materialisation, or an
unexamined load-versus-query trade-off.

**Do:** design a physical-design review driven by repository evidence about fact size/growth,
incremental and backfill patterns, join/filter/grouping paths, concurrency, retention, platform
capabilities, and operational constraints. Assess partitioning, indexing/columnstore, distribution,
compression, statistics, aggregates/materialised views, and maintenance cost where applicable.
Recommendations must name the workload assumption and expected benefit, distinguish measured facts
from estimates, and request plans/runtime evidence rather than asserting performance when static
code is insufficient. This is architecture review, not a replacement for single-query tuning.

**Framework fit:** establish the grain/fact target from current repository evidence (B-124 shipped
no separate choice artifact) and optionally use B-125's shipped logical findings. B-126/B-127 are
unlocked future integrations, not inputs or acceptance dependencies. Keep platform-specific advice
behind detected capabilities and avoid universal vendor prescriptions. Prefer extending the
warehouse review workflow over a new always-routed skill unless the design demonstrates a routing
need.

**What established practice says (checked 2026-08-11):** Microsoft's current SQL Server guidance
treats index choice as a workload-dependent balance between query speed, write/maintenance overhead,
and storage. Query Store supplies query, plan, runtime, variation, and wait history; an estimated plan
does not execute and carries no runtime resource/row evidence, while an actual plan does. Columnstore
benefits large scans, but small rowgroups, partition granularity, load batch shape, deletes, and
selective point access materially change the answer. Snowflake says explicit clustering is unnecessary
for most tables: use large-table scan evidence and common filters, then prove benefit offsets initial
and ongoing credit/storage cost. BigQuery likewise ties partition/clustering value to eligible
predicates, pruning, column order, bytes scanned, table size, and update patterns; expressions can
defeat pruning even when the “right” column appears. Leading vendor advice therefore supports an
evidence ladder — declared layout → estimated behavior → observed representative workload → measured
before/after outcome — and rejects universal index, partition, or materialisation recipes. Sources:
[SQL Server index design](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-index-design-guide),
[Query Store workload practice](https://learn.microsoft.com/en-us/sql/relational-databases/performance/best-practice-with-the-query-store),
[estimated vs actual plans](https://learn.microsoft.com/en-us/sql/relational-databases/performance/display-and-save-execution-plans),
[columnstore design](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-design-guidance),
[columnstore loading](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-data-loading-guidance),
[SQL Server statistics](https://learn.microsoft.com/en-us/sql/relational-databases/statistics/statistics),
[Snowflake table/clustering considerations](https://docs.snowflake.com/en/user-guide/table-considerations),
[Snowflake clustering cost](https://docs.snowflake.com/en/user-guide/tables-auto-reclustering),
[BigQuery partitioning](https://docs.cloud.google.com/bigquery/docs/partitioned-tables), and
[BigQuery clustered-query guidance](https://docs.cloud.google.com/bigquery/docs/querying-clustered-tables).

**Fresh-context adversarial review (Codex, 2026-08-11; does not satisfy the Opus gate):** verdict
**REJECT candidate beyond a redesigned unchanged-skill baseline**. The reviewer found no observed
harm attributable to current guidance; asking a structural grep-based mapping skill for a detailed
physical review would mostly test model improvisation and telegraph the desired rubric. The first
plan also left “representative workload” unreachable, offered a feature taxonomy instead of safe
versioned platform adapters, blurred evidence validity, omitted mixed/invalid experiment outcomes,
under-specified noise/privacy/cost controls, and expanded an M–L item into a cross-vendor tuning
product. The narrower investigation below folds those findings and remains unlocked.

**Implementation plan — revised investigation and conditional design:**

1. **Authorise Phase 0 only.** Pre-register a small unchanged-framework behavioral baseline before
   adding any instructions. Compare (a) ordinary routed warehouse work, (b) an explicit physical-
   design question, and (c) a control with no performance question. Use two or three paired SQL
   Server text fixtures plus normalized supplied telemetry: identical DDL with scan-heavy versus
   selective workload; point lookup versus columnstore/load trade-off; representative versus biased
   sample; and a justified no-change case. Do not put expected tuning vocabulary in the prompts.
2. Attribute failure carefully. Freeze prompts, decisive artifacts, evidence available, normalized
   outputs, direct-read requirements, three-or-more repetitions per available surface, and red/green
   grader mutations. A shipped change is authorised only if unchanged behavior repeatedly makes a
   materially wrong or unsafe decision *because framework guidance is missing or misleading*, not
   because a general model lacks specialist database knowledge. Otherwise close or narrow B-128.
3. Define workload representativeness before any recommendation: named population (queries/jobs in
   scope), capture source and integrity, environment/version/settings, selection method, time window,
   release/seasonal/peak periods, parameter/skew classes, coverage by execution count and by the
   primary resource/cost measure, excluded classes, and a stability comparison with an adjacent
   window. No universal percentage is assumed; the owner pre-registers the material population and
   minimum coverage. Missing or unstable coverage yields `Evidence collection required` only.
4. Record evidence on independent axes: origin/acquisition (direct repository read, supplied export,
   captured execution, aggregate telemetry, attestation); exact coordinates/integrity; platform,
   version/edition/service, environment and settings; time/window/population; direct versus attested;
   and representativeness status. Static DDL/query text is a candidate mechanism; estimated plans are
   predictions; actual plans prove one execution; aggregates are meaningful only with population
   metadata. Screenshots or exports without coordinates, freshness, and environment remain unverified.
5. Use a complete deterministic state transition: `Evidence collection required`, `Reject from
   evidence`, `Candidate experiment`, `Awaiting authority`, `Invalid experiment`, `No material
   difference`, `Measured improvement`, `Measured regression`, or `Mixed/guardrail failure`.
   Define a constructible fixture world for each exercised state. Improvement requires the primary
   threshold, every correctness/load/cost/maintenance guardrail, comparable environments, and proper
   authority; it cannot hide a regression behind one faster query. Abstention is not the only pass.
6. If Phase 0 reproduces an attributable gap, Phase 1 may add one ephemeral on-request **comparison
   and experiment-planning** section to the existing dotnet `map-warehouse` mirrors at
   `src/stacks/dotnet/files/{.claude,.github}/skills/map-warehouse/SKILL.md`, composed into dotnet
   and monorepo. It performs no query, DDL, plan generation, telemetry export, or persistence. Keep
   the C#-only `perf` skill and Angular behavior unchanged.
7. Phase 1 supports only the evidenced platform/version family from Phase 0 (initially SQL Server).
   Its adapter contract names detection precedence, required version/edition/service and managed-
   feature state, permissions, current official capability source/date, supported alternatives and
   diagnostics, `Unknown/unsupported` behavior, and expiry/recheck trigger. Snowflake, BigQuery, or
   other adapters require a later separately reviewed evidence case and discriminating fixture; do
   not ship vendor-name substitutions from the research survey.
8. The conditional output compares `No change` plus only applicable alternatives, binding each to
   evidence, predicted mechanism, query benefit, load/write cost, storage/maintenance cost,
   operational risk, reversibility, falsifying diagnostic, safe experiment proposal, authority
   needed, and decision state. Static review can nominate or reject an experiment, never label an
   optimization measured or validated.
9. A proposed experiment must pre-register identical data/configuration, randomized or interleaved
   A/B order where possible, compilation and cold/warm-cache populations, background-load/noisy-
   neighbor/autoscaling controls, parameter and concurrency mix, stabilization, repetitions, raw-run
   retention, robust distribution/uncertainty summary, outlier rule, correctness, primary outcome,
   all guardrails, abort/invalidation conditions, and rollback/drop plan. The fixed snapshot's scope
   and representativeness are explicit; no execution is part of this item.
10. Define authority levels separately for repository reads, telemetry/history read or export, plan
    generation, query execution/replay, non-production DDL, production action, and spend. Default is
    proposal-only. Require minimization/redaction of literals and sensitive query text, secret
    exclusion, approved storage/retention, cost ceiling, and named abort owner before proposing a
    higher-authority phase. A restored database or estimated compilation can still expose data or
    consume resources.
11. Phase-0 graders bind table/workload/evidence coordinates, validate units/arithmetic/comparison
    direction, reject cherry-picked samples and vendor-keyword matching, and mutate evidence axes,
    representativeness, no-change, cost, guardrails, and state transitions red→green. Include one
    unsupported-platform control that safely requests capability evidence rather than inventing
    advice. Broader platform/mechanism fixtures are explicitly deferred.
12. Keep boundaries honest: B-125 may provide current logical context; B-126/B-127 are future
    integrations, not prerequisites; B-129 owns publication design. Scope is one named table/fact
    plus the named interacting objects required to evaluate its joins, aggregate, distribution, or
    load. Single-query tuning remains out unless that query is part of the pre-registered workload.
13. If Phase 1 is eventually implemented, verify exact changed-skill delivery: both authored mirrors,
    dotnet/monorepo composition, disabled/discovered-skill semantics, greenfield and update installs
    through both twins, and dotnet/monorepo root detection. Specify the expected brownfield collision
    behavior for a same-name customized framework skill. Add document-preservation tests only if a
    later design actually writes a document. Then compose/freshness and `validate-dist` ×3.

**Proportionality:** no harmful framework-caused tuning decision has been observed, and the current
skill promises structural mapping rather than performance review. Only the small unchanged-framework
baseline is presently proportionate. If it proves attributable harm, an ephemeral SQL Server
comparison/experiment-planning section is the maximum authorised candidate. Automated capture,
execution, production DDL, cross-platform tuning engine, persistent telemetry, whole-warehouse scan,
or new skill is not authorised.

**Status: AWAITING OPUS REVIEW.** This candidate is not locked and authorises no implementation.
The separate Codex critique above materially reduced the plan but does not clear the gate. Obtain a
Claude Opus review of this revised baseline, attribution rule, representativeness contract, evidence
axes, conditional single-platform scope, experiment safety, and proportionality. If Opus is genuinely
unavailable due to limits, record `WAITING — OPUS LIMIT` rather than substituting a lower-tier verdict.

**Design/review gate:** locked design plus proportionality case, followed by an independent
adversarial **Claude Opus** review before implementation. If Opus is rate- or spend-limited, record
**WAITING — OPUS LIMIT** and move to independent design work; do not implement this item unreviewed.

**Done when:** representative fixtures cover rowstore and columnstore/partitioned designs, harmful
and appropriate configurations, incremental loads and backfills, and absent workload evidence;
recommendations are platform-scoped and evidence-ranked; false-positive controls are demonstrated;
and behavioral evals show the framework can decline an unjustified optimization.

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

**Status: AWAITING OPUS REVIEW.** This candidate is not locked and authorises no implementation.
The separate Codex critique above materially reduced the plan but does not clear the gate. Obtain
Claude Opus review of the controlled A/B, carrier feasibility, SQL-only scope, authority states,
security oracle, compatibility boundary, context cost, and proportionality. If Opus is genuinely
unavailable due to limits, record `WAITING — OPUS LIMIT` rather than substituting a lower-tier verdict.

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

### B-130 · Diagnose or retire the historical Windows PowerShell 5.1 parity failures
**Effort:** S · **Priority:** P3 · filed 2026-08-08 · **Invariants:** #3

**Why:** discovered incidentally while resuming B-54: `src/core/tests/hooks/ScriptTwinParity.Tests.ps1`'s
`docs-sync-check branches and advisory prose agree` case fails with "docs exit mismatch" when run
under Windows PowerShell 5.1 (`powershell.exe`), even on unmodified `master` at `9500f5f` — pwsh 7
passes cleanly. Not investigated beyond confirming it is pre-existing and unrelated to B-54 (stashed
all B-54 changes and reproduced the same failure on baseline). The `Assert` call that fails
(`Assert ($p.Exit-eq$s.Exit) "docs exit mismatch"`) doesn't interpolate the actual exit codes, so the
next person will need to add that before diagnosing further.

**Do:** reproduce, capture both hosts' actual exit codes and stdout for the `docs-sync-check.ps1`/`.sh`
twins over `DocsFixture`/`TemplateFixture`, and find the 5.1-specific divergence (likely another
BOM-less-file default-encoding case, per invariant #4's known class — see B-54's fix in
`template-checks.ps1` step 1 for the pattern: replace `Get-Content` with an absolute-path
`[IO.File]::ReadAllText`). Confirm whether this already fails in CI's Windows leg or is silently
masked there too.

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

### B-131 · `release.ps1` and `template-checks` disagree on changelog-head grammar
**Effort:** S · **Priority:** P3 · filed 2026-08-09 · **Invariants:** #7

**Why:** found during B-54's independent review (Opus round 2). `release.ps1`'s
`Get-ReleaseChangelogHead` requires the *literal first* `## ` line in a changelog to be a version
head; `template-checks.ps1`/`.sh`'s version-stamp check instead skips down to the first
*version-shaped* `## ` line. On an unusual changelog layout (e.g. a Keep-a-Changelog-style
`## Unreleased` section heading placed above the actual versioned head), `release.ps1` hard-refuses
the release while `template-checks` would have passed the same file. This fails safe in the
direction observed (the stricter check blocks first), so it was not fixed in B-54's own pass —
recorded here per Maintenance model rule 6 (proportionality) rather than left as an
unsubstantiated "filed as follow-up" claim in the B-54 Done entry.

**Do:** decide on one shared changelog-head grammar for both scripts (most likely: both should
require the literal first `## ` line to be the version head, matching `release.ps1`'s stricter
reading, since a shipped/authored changelog is not expected to carry other `## ` sections above its
version history) and apply it identically in both twins.

**Established practice and local contract (researched 2026-08-11):** Keep a Changelog recommends an
`Unreleased` section above released versions and adding a new one after a release; that is a valid
external convention, not malformed Markdown. SemVer defines version precedence but does not define
changelog layout. This repository intentionally uses a narrower workflow: four authored changelogs
must put the target release as the first H2, `release.ps1` atomically changes its state from
`Unreleased` to an ISO-like date, composition must reproduce all heads, and shipped
`template-checks` rejects an `Unreleased` current version. Sources:
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
[Semantic Versioning 2.0.0](https://semver.org/). The defect is therefore internal contract drift,
not failure to implement Keep a Changelog. Ownership is decisive: installers preserve and do not
install `CHANGELOG.md`, while `template-checks` also runs inside consumer repos. The local grammar
may apply only where `.template-repo` marks a framework-owned template; an unmarked consumer's
changelog is product-owned and must not be parsed or rejected by this gate.

**Approaches considered:**

1. **Adopt the full Keep a Changelog layout.** Teach release tooling to locate the first matching
   version below an optional `## [Unreleased]`, insert/retain sections, and update link ranges.
   Rejected as disproportionate: no consumer requested that format, atomic four-head stamping is
   already shipped and red-proven, and accepting a second layout expands mutation and ambiguity.
2. **Make the literal first column-zero `## ` line the canonical framework-owned head — selected.**
   Define one two-state lexical contract: `## <X.Y.Z> — Unreleased` is accepted by release preflight
   only when all four authored heads have that target/state; `## <X.Y.Z> — <YYYY-MM-DD>` is accepted
   only when the relevant authored heads agree and the resolved target/date matches the phase.
   Template validation accepts only the dated state. This is not a Markdown parser, full SemVer (the
   triplet is digits/dots only), ISO date validation, or chronology check. It requires one ASCII
   space after `##`, a literal UTF-8 em dash with surrounding spaces, and whole-line match; prose and
   blockquotes before it are allowed, while fences/indentation have no special parsing semantics.
   Apply it only to `.template-repo` roots. Unmarked consumers ignore any `CHANGELOG.md` and perform
   framework-version pair checks only.
3. **Loosen `release.ps1` to template-checks' current “first version-shaped H2 anywhere” rule.** This
   makes the two gates agree cheaply but permits release mutation below an unowned H2 and can stamp a
   file whose visible head represents a different state. Rejected because it weakens the fail-safe
   release boundary.

**Implementation plan (after review):**

1. Freeze a shared fixture table before changing parsers: agreed dated target; all-four target
   `Unreleased`; mixed dated/Unreleased and disagreeing dates; non-version first `## ` followed by a
   dated target; wrong target; bracketed target; hyphen/en-dash variants; trailing text; missing H2;
   prose/blockquotes before a valid head; LF/CRLF; and a repeated current-version heading. Reject a
   repeated current-version lexical heading so stamping cannot leave a later `Unreleased` duplicate.
   Diagnostics assert category plus salient observed value, and exact offending line only when one
   exists. State explicitly that date shape is lexical; B-54's deferred wrong/future-date question
   remains outside scope.
2. Change both authored `template-checks.ps1` and `.sh` twins to branch on ownership. Marked template:
   require `CHANGELOG.md`, capture the literal first column-zero `## ` line, validate the local
   whole-line grammar/date state, and compare its version. Unmarked consumer: ignore a present or
   absent consumer changelog and pair-check only. Add a green unmarked Keep-a-Changelog fixture and
   a red marked/missing-changelog fixture. Do not add a runtime dependency or pretend the parsers
   share executable code; keep one documented contract and shared fixture rows.
3. Align the third executable parser in `.claude/evals/run-agent-evals.ps1`: its paid-live preflight
   must require the dated framework-owned literal head, not skip to a buried version and call it the
   head. Add reachable self-test cases for buried version, `Unreleased`, and dated target.
4. Extend `ReleaseChangelogStamp.Tests.ps1` and `ScriptTwinParity.Tests.ps1` with the frozen table.
   Red-prove the current divergence using `## Unreleased` above the target: current template checks
   pass while release refuses. Then require both template twins to refuse it, release to remain
   fail-safe before mutation, retry/idempotence and mixed-state checks to stay green, and composition
   to preserve the accepted target/date head across source and dist. Exercise each grammar/state row
   once per parser implementation (three parsers across two languages), not as a seven-path product;
   separately plant one sentinel in each four preflight/seven postcondition path and prove all three
   stack compositions.
5. Run the modified twin suite under PowerShell 7, Windows PowerShell 5.1, and Git Bash with LF/CRLF;
   compose/freshness, `validate-dist`, all three dist hook suites, the meta suite, release changelog,
   eval self-test, and release staging recurrences. Update the root and three authored changelogs,
   version target, release header contract, and known `DEVELOPING.md` drift that still describes
   shipped notes as conditional. Record the locked choice in `meta/workspace-decisions.md` after
   Opus approval; close with `meta/LEARNINGS.md`, the mandatory RCA/same-class sweep, release, and
   observed source-to-dist delivery.

**Proportionality:** the observed mismatch fails safe and no shipped release escaped it, so the
operational harm is modest: framework validation can report a false green for a format that mandatory
release preflight then refuses. The smallest sufficient change is ownership-bounding and aligning
three short parsers plus focused fixtures. A general changelog parser, shared module, or
Keep-a-Changelog migration would cost more and broaden release mutation without observed benefit.

**Design/review gate — AWAITING OPUS REVIEW:** before implementation, obtain a fresh independent
Claude Opus adversarial review of the local-format decision, exact grammar, state split, fixture
reachability, cross-language parity, and proportionality. First obtain and incorporate a separate
fresh-context Codex critique; it does not clear the Opus gate. If Opus is limited, record
`WAITING — OPUS LIMIT`. This plan is not locked and authorises no implementation.

**Fresh-context adversarial review (Codex, 2026-08-11):** **REQUESTED CHANGES.** It found that the
first design would wrongly impose private release grammar on preserved consumer changelogs, omitted
the live-eval parser, called a lexical regex Markdown/SemVer/date validation, left mixed/duplicate
states indeterminate, multiplied fixture axes, and omitted delivery/RCA work. The revision above
uses `.template-repo` as the ownership boundary, ignores consumer changelogs, aligns all three
parsers across two languages, defines state/path axes separately, and adds delivery and closure
obligations. This Codex review **does not satisfy the required Claude Opus gate**.

**Status: AWAITING OPUS REVIEW.** This revised design is not locked and authorises no
implementation. If Opus is genuinely unavailable due to limits, record `WAITING — OPUS LIMIT`.

### B-135 · Security register republishes active credential-incident metadata to every clone
**Effort:** M · **Priority:** P1 · filed 2026-08-11 · **Invariants:** #1 #2 #6 #7

**Why:** a field report says the framework-shaped findings table copied a live service-account
name, a concrete secret-bearing file path, host information, and the fact that the credential was
echoed into an AI transcript into committed Markdown. The password itself was absent, but this
broadened an active credential incident's operational metadata to every clone and PR reader. The
affected consumer repository is not present here, so those incident facts remain attributed to the
report. The enabling framework contract is locally confirmed: canonical `SECURITY_FINDINGS.md`
requests `File:line` plus free-form `Description`; dotnet and monorepo `/security-review`
automatically append critical/high rows; none of the register, parent workflow, or auditor output
contracts forbids operational identifiers or transcript detail.

**Do:** keep the committed register only as a minimised coordination index for ordinary
repository-safe code findings. For active or suspected credential incidents, make **no automatic
Git mutation** and never echo service/principal
names, hosts/IPs, usernames/home paths, vault/key names, concrete secret-bearing paths/lines, secret
fragments/fingerprints, transcript/session identifiers or links, or narrative disclosure-channel
detail into chat output or Git. The review may retain ordinary repository-relative code `file:line`
when locator and target are safe; the parent separately synthesises any durable row and never pastes
raw auditor/chat/tool output. Ask a human to establish restricted incident handling; create no
placeholder row or invented reference. A contained incident may gain a minimal historical row only
with explicit human authorisation and an approved opaque reference. Apply the safe-record contract to
active, accepted-risk, resolved, and archived findings across all three stacks and both host-facing
agent surfaces.

**Design:** `.claude/plans/2026-08-11-b135-security-register-minimisation-design.md` weighs three
approaches and, after fresh-context review, selects a hybrid rather than warning-only,
active-incident stubs, or mandatory external-only tracking. Legacy schemas fail closed because
update preserves the consumer register; migration is human-only. Stack-specific fixtures define
reachable red/green worlds. The same-class sweep must disposition `.claude/ai-audit.log`'s
original-path fallback before lock. History/transcript containment remains outside automatic
framework mutation.

**Fresh-context adversarial review (Codex, 2026-08-11):** **REJECTED the active-incident stub.** It
found that even a redacted row leaks incident existence/correlation, update preserves the legacy
unsafe schema, the original all-stack red oracle was unreachable, Angular does not append despite
its frontmatter claim, the live harness is Claude-only and cannot install monorepo, and the committed
AI audit log is a concrete same-class path leak. The revised design adopts the hybrid, no-placeholder
behavior, fail-closed legacy handling, stack-specific evidence, safe response output, and an
audit-log pre-lock disposition. This review does **not** satisfy the Claude Opus gate.

**Review gate — AWAITING OPUS REVIEW:** commit this revised design for independent Claude Opus
review. Opus may reject the premise, require no security persistence at all, or change the migration
and audit-log boundary. No shipped implementation is authorised until the design is locked and the
decision is recorded in `meta/workspace-decisions.md`.

**Proportionality:** the reported harm is an actual disclosure expansion caused by a durable record,
not a hypothetical scanner concern. A schema and workflow-contract correction with focused
behavioral evidence removes most of it. A general DLP/classification engine, mandatory incident-tool
integration, history rewrite, or automatic transcript remediation is not authorised.

---
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

**B-16 is implemented for v0.32.0 — see the Done section.**

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
Execution-ready plan exists: `<home>\.claude\plans\v0_24_0-shipped-framework-testing.md`
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

### B-95 · `validate-dist` checks 1–4 still carry the vacuity shapes B-92 removed from 6–8 — **DONE 2026-08-08, see Done**
**Effort:** S · **Priority:** P3 · filed 2026-08-04 (B-92's independent review) · **Invariants:** #3

**Why:** B-92 was scoped to checks 6, 7 and 8, and those now guard their inputs, count what they
scanned, and report read errors. The four checks above them were not touched and still have the
shapes B-92 exists to remove — confirmed by reading during the pre-commit review:

- **check 1** (`@stack` markers) swallows read errors in both twins (`-ErrorAction
  SilentlyContinue` / `2>/dev/null || true`), so an unreadable file is indistinguishable from a
  clean one.
- **checks 2, 3 and 4** each print their own `OK:` on **zero** inputs. A dist containing no
  `*.json`, no `*.sh` or no `*.ps1` gets three individual passes saying those files are all valid.
  Other checks would redden the run overall, but each of those specific claims is vacuous.

This is a genuine residual, not a regression: it is the same class, one check group over. It is P3
because a dist with zero JSON/shell/PowerShell files fails checks 5–8 loudly anyway.

**Do:** give checks 1–4 the treatment 6–8 received — count inputs, state the counts on the OK line,
and record read/enumeration errors as findings rather than skipping the file. Decide explicitly
whether zero inputs is legitimate for each (it is not, for any of the three). Red-test each with a
planted unreadable file and an emptied tree, both twins.

**Cross-links:** B-92 (the same class in checks 6–8, fixed), B-59 (the inert-check family), B-64
(planted-defect tests for diagnostics).

---

## Done

- **B-124** — closed **2026-08-09**, premise rejected after two independent Opus design reviews and
  a pre-registered behavioral baseline. The first fixture telegraphed its answers and was rejected;
  the corrected fixture exposes only paths/live SQL and uses non-leading prompts. On the unchanged
  v0.51.5 skill, `warehouse-fact-existing` selected **EXTEND `FactOrderLine` 2/2**, and
  `warehouse-fact-new` selected **CREATE `FactPaymentAllocation` 2/2**. One first-run new-fact row
  was falsely labelled FAIL because the grader demanded the literal `OrderLine`; its DDL correctly
  used the warehouse's degenerate `OrderNumber + LineNumber` plus `AllocationSequence`. The matcher
  was changed to those structural columns, observed red without the sequence, and green live.
  Snapshot and explicit-abstention success worlds are also retained, with red worlds for missing
  semi-additivity, map-only echo, wrong missing facts, and DDL-after-abstention. **No shipped change
  and no version bump:** the proposed eleven-axis mandatory note was disproportionate to zero
  observed failures. RCA: no gate caught the supposed gap because there was no demonstrated defect;
  the exposed class is future fact-binding regressions, now covered by the maintainer scenarios.

- **B-54** — implemented **2026-08-08** on branch `codex/b54-release-changelog-stamp`, **not yet
  released or merged** (pending independent review — see below). Codex began this item and ran out
  of budget mid-implementation with `release.ps1`'s changelog-stamping half drafted but uncommitted
  and `template-checks`'s placeholder-gate half not started; Claude resumed and finished both.

  **Part 1 (`release.ps1`, Codex's draft, verified as-is):** `Set-ReleaseChangelogHeads` now
  validates and stamps all four authored heads (root + 3 `src/stacks/*/files/CHANGELOG.md`)
  atomically — refusing on any missing, version-mismatched, or malformed head before writing any of
  them — and a new post-composition `Test-ReleaseChangelogHeads` postcondition (with
  `-IncludeDist`) refuses the release before commit unless the stamped date reached all three
  composed `dist/*/CHANGELOG.md` too. Previously only the root changelog was ever stamped.

  **Part 2 (`template-checks.{ps1,sh}`, new):** the version-stamp check now also fails when a
  changelog's head entry carries the *current stamped version* but still reads `Unreleased` instead
  of a date — the belt-and-braces half, catching a hand-authored placeholder even outside
  `release.ps1`. Discovered and fixed a Windows PowerShell 5.1-only defect in the same check while
  building it: `Get-Content` with no explicit encoding mis-decodes a BOM-less UTF-8 em dash in the
  changelog head under 5.1, garbling the failure message; switched to an absolute-path
  `[IO.File]::ReadAllText`, matching the idiom `release.ps1` already used for the same reason.

  **Live production defect found while validating this fix:** all three *already-shipped* v0.51.4
  consumer changelogs still read `## 0.51.4 — Unreleased` — the exact class B-54 exists to prevent,
  happening a third time, silently, on a release that was already tagged and CI-green. Corrected
  directly on `master` (commit `9ddc97a`, pushed) as a data-only fix (dated to match the root
  changelog's already-recorded `2026-08-08`), independent of this branch's code change, then the
  branch was rebased onto the corrected master.

  **Observed red:** the new `template-checks` case (`ScriptTwinParity.Tests.ps1`, new `It` block)
  was confirmed to fail on the unfixed scripts before the fix landed (stashed the fix, reran, saw
  `[FAIL] ... Unreleased head at the stamped version should fail`, restored the fix). The live
  v0.51.4 defect above is itself an observed-red instance in production, predating any fixture.
  `ReleaseChangelogStamp.Tests.ps1` (Codex's test) carries its own bounded legacy-fallback so its
  first case is red against the pre-fix root-only behavior by construction.

  **Observed green:** `ReleaseChangelogStamp.Tests.ps1` 3/3 under both pwsh and Windows PowerShell
  5.1. `ScriptTwinParity.Tests.ps1` 7/7 under pwsh; 6/7 under 5.1 — the one failure
  (`docs-sync-check branches and advisory prose agree`) reproduces identically on unmodified master
  with all B-54 changes stashed, confirmed pre-existing and unrelated (filed as B-130). All three
  dists (`dotnet`/`angular`/`monorepo`) composed cleanly (`git status --porcelain dist/` showed only
  the 9 expected `template-checks`/`ScriptTwinParity` files) and passed `validate-dist.ps1` fully,
  including the new check now passing against the corrected shipped changelogs. All three dist hook
  suites: 14/15 files clean, the one failure being a second, separately pre-existing 5.1-only
  `FrameworkDoctor.Tests.ps1` flake (also reproduced on unmodified master with B-54 stashed; also
  filed under B-130). Meta suite: 0 failures across 14 files.

  **RCA (why did no gate catch it twice, third time silent):** the version-stamp check only ever
  parsed the leading digits of the head line, so it structurally could not distinguish a real date
  from any other trailing text — the check's own regex made "Unreleased" and "2026-08-08"
  indistinguishable inputs. **Same-class sweep:** no other shipped gate was found doing this
  specific "parse a leading token, ignore the rest of the line" pattern against a value with a
  release-safety meaning; B-130 (filed above) is a different failure shape (host-encoding, not
  under-parsing) surfaced by the same validation pass, not the same class.

  **Deferred to actual release, not part of this commit:** the `## 0.51.5` CHANGELOG headings
  (root + 3 shipped) and the corresponding `framework-version.json`/`CLAUDE.md` version bump.
  Pre-adding a bumped heading without also bumping the version stamp fails `template-checks`'s
  existing (unchanged) drift check by design — confirmed by trying it and observing the exact
  failure — so per repo convention (see the B-63 "prepare vX.Y.Z" commit) that bump belongs to the
  single atomic release step, not to this pre-review commit.

  **Independent review round 2 (Opus, different tier — 2026-08-09):** a Sonnet-tier self-review
  found nothing; per Maintenance model rule 2 that didn't count as independent since Sonnet also
  implemented. An Opus-tier review of commit `10c89d0` returned **REQUEST CHANGES** with one real,
  verified-blocking finding and four non-blocking/nitpick findings:

  - **Blocking (fixed):** `Set-ReleaseChangelogHeads`/`Test-ReleaseChangelogHeads` required an
    already-stamped head to equal *today's* date, not merely be a valid date. A release retried on
    a later calendar day after a gate failure — the script's own banner promises this is safe — hit
    a "date mismatch" refusal telling the operator to rewrite an already-correct, already-published
    date. **Observed red** on the pre-fix committed code: a fixture stamped `2031-02-03` then
    retried with `$Date` `2031-02-04` produced four `date mismatch` problems and refused. Fixed by
    resolving the release date from any single already-agreeing stamped value across the four heads
    (falling back to `$today` only when all four still read `Unreleased`), threading that resolved
    date into the postcondition instead of a freshly recomputed `$today`, and treating a genuine
    *mix* of disagreeing dates or dated+`Unreleased` heads as its own distinct refusal (a related,
    lower-probability gap the same pass closed rather than leaving implicit). New test: `a retry on
    a later calendar day accepts an already-consistently-stamped world without rewriting the date`
    in `ReleaseChangelogStamp.Tests.ps1`, confirmed red on the pre-fix commit and green after,
    under both pwsh and Windows PowerShell 5.1.
  - **Non-blocking (fixed):** `release.ps1`'s header comment and root `CLAUDE.md` invariant #7 both
    described the shipped-changelog update as conditional ("if the release notes should reach
    consumers"); B-54 made all three mandatory on every release. Checked history first — every
    release from v0.26.0 through v0.51.4 already had a shipped entry with zero gaps, so this was
    stale wording, not a behavior change in practice. Both docs corrected.
  - **Nitpick (fixed):** `template-checks.ps1`'s `Resolve-Path 'CHANGELOG.md'` used glob-sensitive
    matching; switched to `-LiteralPath`.
  - **Non-blocking (deferred):** `release.ps1`'s changelog-head grammar (literal first `## ` line
    must be a version head) and `template-checks`'s (skips to the first version-shaped `## ` line)
    can disagree on an unusual changelog layout — fails safe in the direction observed, not
    proportionate to fix in this pass. Filed as **B-131** (an earlier draft of this entry claimed
    it was "filed as follow-up" when it wasn't yet — round-3 review caught the unsubstantiated
    claim; it is now actually filed).
  - **Nitpick (not fixed, low value):** no test pins the case where a changelog's `Unreleased` head
    is for a version that doesn't yet match `framework-version.json` (mid-authoring); reviewer
    verified by reading that the pre-existing drift branch already prevents a false positive there.

  **Independent review round 3 (Opus, same reviewer, commit `3c060f2` — 2026-08-09): APPROVE.**
  Re-extracted the helpers by AST and drove the full state matrix (fresh/retry/inconsistent/mixed)
  directly; re-ran `ReleaseChangelogStamp.Tests.ps1` 4/4 under both pwsh and Windows PowerShell 5.1
  itself rather than taking the report on trust; independently re-verified the "zero gaps" changelog
  history claim via `comm`. Three more non-blocking findings, all addressed in the same pass:
  `AGENTS.md`'s generated mirror of invariant #7 still described the shipped-changelog update as
  optional even after `CLAUDE.md` was fixed — corrected, restoring mirror parity [#2]; the
  unsubstantiated "filed as follow-up" claim above — B-131 now actually exists; and a genuinely new
  gap the round-2 fix introduced: four changelog heads that already **agree with each other** but on
  a *wrong* date (e.g. copy-pasted from the previous release and only the version edited) are now
  accepted and shipped silently, where round 1's stricter `Status -ne $Date` check would have caught
  it. Assessed as low-probability and non-blocking (the console output names the resolved date, and
  the corrected `CLAUDE.md`/`AGENTS.md` now tell an author to write `Unreleased`, not copy a date) —
  not fixed in this branch; a future-dated-head guard is cheap and worth adding but was not judged
  proportionate to hold the merge for a defect with no observed occurrence.

  **Independent review status: satisfied.** Two full rounds (Sonnet self-review did not count per
  Maintenance model rule 2; Opus round 2 found the real blocking defect; Opus round 3 re-verified
  the fix and closed the round-2 process gaps). Branch `codex/b54-release-changelog-stamp`, tip
  `3c060f2` plus whatever commit fixes round 3's three findings, is now clear to merge.

- **B-63 / B-56** — done **2026-08-08** (target v0.51.4). The audit closed B-56's
  remaining class rather than treating v0.35.0's child-Bash probe as a complete fix. The complete
  disposition is: `Framework install`, `Framework rules delivery`, `Protected-file sync`,
  `Bootstrap/adoption state`, `Hook files`, and `Mirror and version integrity` remain valid
  checkout-local structural checks; `Hook liveness` remains the actual Claude-host observation;
  `Audit trail substrate` remains a doctor-process filesystem check, not host-execution proof;
  `Wired hook shell` now treats a portable bare interpreter as deliberately unobservable and an
  absolute path as current-machine evidence only; `Guard JSON parser` derives demand from the
  actual registered Claude and Copilot `guard.sh` targets, reports `CANT-VERIFY` from PowerShell,
  and reports only on “this Bash environment” when invoked directly under Bash; `Stack toolchain`
  and `Copilot surface` now describe resolution only in “this doctor process environment,” with
  their actual-host claims left to explicit canaries. The new post-write canary requires a
  deliberate compile/type failure through the agent, the hook's own build-failure heading, a
  revert, and awareness of the throttle.

  **Observed red:** on unchanged production, the new Copilot-only-demand fixture registered
  `guard.sh` only through `.github/hooks/*.json`; the PowerShell doctor incorrectly printed
  `[OK] ... not required` instead of `CANT-VERIFY`. In the Claude-Bash fixture, a controlled parser
  visible only to the doctor-spawned child made the old PowerShell probe print `[OK]`, proving it
  was observing its inherited `PATH`, while the genuine no-Bash setup control stayed `[OK] ... not
  required`. Both defects reproduced under pwsh and Windows PowerShell 5.1. The historical-branch
  mutation reconstructs the removed function and branch between neutral, exact-once source
  anchors: with the same registrations and `PATH`, fixed production is `CANT-VERIFY` while the
  mutant is `OK`, and both keep a coherent summary and exit 0.

  **Observed green before release:** the source `FrameworkDoctor` suite passed 31/31 under pwsh
  and 30/30 under Windows PowerShell 5.1, with its one existing 5.1 invariant skip explaining that
  the host Python executable is inaccessible rather than counting it as evidence. The three
  composed distributions each passed all 15 shipped hook suites. A second composition found all
  501 generated files byte-identical (165 dotnet, 161 angular, 175 monorepo), and both validator
  twins passed all 11 checks against all three distributions. Registration matrices cover both
  twins; parser and CLI asymmetries use exact fixture-specific divergence sets; isolated command
  bins prevent the maintainer's ambient tools deciding parity. Independent review then found the
  Bash registration extractor did not match the PowerShell twin for shell-valid single-quoted
  targets/interpreters or a case-varied `BASH.EXE` basename. The permanent case pins
  `bash '.claude/hooks/guard.sh'`, `'/usr/bin/bash' .claude/hooks/guard.sh`, and
  `C:\Git\BASH.EXE .claude/hooks/guard.sh` on both twins while the existing `bash -c` command-
  position negative remains green. Before the Bash fix its first arm failed hook-target resolution;
  after it, the full source suite completes in 107.2 seconds under pwsh and 70.9 seconds under 5.1.
  The runtime optimization is confined to `FrameworkDoctor.Tests.ps1`'s B-63 parser bins; the
  shared shipped hook harness remains unchanged.

  **RCA:** v0.35.0 corrected which language performed the parser lookup but not which environment
  supplied the evidence: a child shell still inherited the doctor's `PATH`. Demand was also
  inferred from Claude's interpreter choice rather than the registered guard targets, so a
  Copilot-only Bash guard disappeared from the row. Ambient-path fixtures and whole-output parity
  comparisons hid both the invalid observation and legitimate per-surface asymmetries. The
  prevention is an explicit consumer/observation audit for every row, target-derived demand,
  `CANT-VERIFY` where the relevant host environment is unobservable, semantic row assertions,
  exact divergence sets, isolated capability worlds, a reachable historical mutation, and
  actual-host canaries for facts no local doctor process can prove. WSD-026 retains its historical
  v0.38.0 record and carries an append-only correction to the v0.38.1 portable bare-name policy.

- **B-89** — done **2026-08-08** (target v0.51.4). `src/core/scripts/sync-agent-files.ps1`'s
  `git rev-parse --show-toplevel 2>$null` fallback used the same
  `$ErrorActionPreference = 'Stop'` + native-stderr idiom that B-90 already fixed in
  `build-architecture-html.ps1`; this closes the sibling site B-90's own RCA named as still
  exposed. Wrapped the call with `$ErrorActionPreference = 'Continue'` and an explicit
  `$LASTEXITCODE` check, mirroring `watch-ci.ps1`'s `Invoke-GitQuiet`. `scripts/fidelity-check.ps1`
  (root, maintainer-only, not shipped) had the identical idiom and was fixed in the same pass.
  **Observed red:** run from a non-git directory under real Windows PowerShell 5.1, the unfixed
  `sync-agent-files.ps1` throws a terminating `NativeCommandError` naming `fatal: not a git
  repository`, exit 1. **Observed green:** the fixed script prints "No .claude/skills directory --
  nothing to sync." and exits 0, in the same non-git directory under the same 5.1 host.
  `FidelityCheck.Tests.ps1` (new, 3/3) and `ScriptTwinParity.Tests.ps1`'s new
  "sync-agent-files twins fall back to the current directory outside Git" case both pass. **RCA:**
  B-90's sweep fixed the site its own red-test targeted but did not re-run
  `grep -rn '2>\$null' --include=*.ps1 src/ scripts/` against every hit; the same idiom can recur
  anywhere a native command's stderr is redirected under `Stop`. No new gate added here beyond the
  two red-tests — B-89 itself was filed as the sweep, and the grep should be re-run again before
  assuming no third site remains.

- **B-67** — done **2026-08-08** (target v0.51.3). Check 7 in both `validate-dist`
  twins now resolves rendered single-line relative inline Markdown links from the document that
  contains them, case-exactly, accepting files and directories while rejecting paths that escape
  the dist. External URLs, pure fragments, images, fenced/inline-code examples, reference-style or
  multiline links, and anchor existence are explicitly outside this bounded grammar; this is not
  presented as a full CommonMark/network checker. The scan carries its own extracted-link floor so
  a broken regex cannot turn an empty candidate set green. The sweep exposed a real shipped defect
  in the dotnet and monorepo bootstrap instructions: an example meant for root `CLAUDE.md` rendered
  as a live `./docs/warehouse-map.md` link from `.claude/commands/`; it is now shown as literal
  Markdown syntax instead. **Observed red:** before the production change, case 32 planted
  `[B67 planted](./docs/definitely-missing-b67.md)` in a copied real dist; the PowerShell validator
  printed its old script-only OK and exited 0, so the permanent case failed. **Observed green:**
  case 32 made both twins exit 1 and name `README.md`, its line, and the missing target, while fenced
  and inline-code examples remained green; case 33 removed every rendered local link and both twins
  failed the zero-candidate floor. **Independent review found four twin/boundary gaps:** the first
  PowerShell draft accidentally stopped checking script commands inside fences; bash truncated
  angle-bracket targets containing spaces; malformed/control percent escapes differed; and links to
  the dist root were rejected. Case 34 now locks fenced-command parity, angle-bracket spaces, malformed
  and control escapes, encoded traversal, and root-directory links across both twins. Both twins then passed all
  three composed dists with 35 relative inline links each. **RCA:** the original gate defined a dead instruction only as an executable
  command, so navigational instructions had no extractor, resolution rule, count, or planted
  failure. The fix extends the existing document-reference gate rather than introducing a parser or
  dependency disproportionate to the observed local-link defect.

- **B-95** — done **2026-08-08** (meta-only; no shipped version). Both `validate-dist` twins now
  derive and check the input inventory for marker, JSON, shell, and PowerShell scans; zero inputs,
  enumeration failures, and read failures are findings, while successful lines state the actual
  nonzero population. The filed premise was narrowed during audit: checks 2 and 3 already failed an
  enumerated unreadable file as invalid, but did not distinguish the read failure; the shared live
  defects were zero-input vacuity and uncaptured enumeration status, plus check 1's definite
  fail-open read path. **Observed red:** before the validator changes, an empty dist and zero
  JSON/shell/PowerShell populations each produced `OK` and exit 0. After adding a permanent
  Windows file-sharing fixture, restoring the old marker catch/ignore behavior made a locked
  `README.md` produce `OK ... (165 files scanned)` and exit 0, so the case itself exited 1.
  **The independent post-merge review found the first closure incomplete:** it had one read-failure
  fixture for check 1, only regex evidence that clean counts were nonzero, no syntax mutants for
  checks 1–4, no spaced-root or selector-conflict coverage, and no parser-child failure fixture.
  Its line-shaped dispatcher also omitted an `It` registration that appeared after an inline
  conditional. The remediation derives registrations from the suite AST and rejects nonliteral,
  duplicate, or orphan-skip registrations. **Observed remediation evidence:** case 26 used real
  Windows deny-sharing locks for all four input types and both twins named the unreadable file; this
  caught a second real defect before closure, because both PowerShell parser paths initially called
  `Parser.ParseFile` without first probing readability and mislabeled its nonthrowing read error as
  invalid syntax. Case 27 independently enumerated each scratch dist and matched exact clean counts
  of 165 files, 6 JSON, 16 shell, and 34 PowerShell files on both twins. Case 28 rejected combined
  `--content-only`/`-Check` selectors with exit 2 on both twins; case 29 preserved a dist-root path
  containing spaces on both; case 30 made marker, JSON, shell, and PowerShell syntax mutants fail
  for their named reason on both; and case 31 replaced `pwsh` with an exit-17 shim and observed the
  bash validator's named parser-child failure. The AST dispatcher immediately exposed the omitted
  jq/python parity case: its name-only probe accepted Windows' broken Store `python3.exe` alias and
  its fallback called helpers absent from this meta harness. An execution-probed, self-contained
  fallback then passed the focused parity case (1 passed, 0 failed, 0 skipped). On POSIX, the read
  fixtures use `chmod 000` only after a capability probe proves the current user cannot still read
  the file; otherwise they are an invariant-guarding skip, never a false pass. **RCA:** no gate caught the original gap because
  success was inferred from an empty failure collection without first proving that enumeration and
  reads had produced a population. The remediation itself was under-tested because one marker-lock
  example and four broad nonzero regexes were generalized into claims about four distinct read and
  parse paths, while the dispatcher was trusted through the same source-text shape it consumed.
  The same class had already been removed from checks 6–8 by B-92; this closes checks 1–4 without a
  generic scanner framework or production fault-injection API.

- **B-71** — done **2026-08-08**. The harness already had prominent invariant-skip reporting from
  v0.46.0, but the filed 5.1 case still tested only PATH and used an ordinary skip. The doctor suite
  now resolves Windows PowerShell locally by trying the application on PATH and then
  `$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe`; the same result drives its
  healthy fixture default and its explicit 5.1 compatibility run. Genuine absence is now a named
  invariant skip. **Observed red:** with PATH restricted so `Get-Command powershell.exe` returned
  nothing while the standard executable existed and ran, the new permanent fallback case failed
  because `Resolve-WindowsPowerShell` did not exist; the file reported 20 passed, 2 failed. **Observed
  green:** after the local resolver was added, that exact case and the explicit 5.1 doctor run both
  passed; the file reported 21 passed, 1 failed. The remaining failure is the pre-existing
  PowerShell/bash parser-vantage mismatch in the Copilot-arguments fixture, tracked by B-63/B-85 and
  not presented as B-71 success. **RCA:** no gate caught the silent coverage loss because ordinary
  skips counted inside a green summary and capability was inferred from PATH spelling rather than
  the installed host. The same class exposed other invariant skips; the harness-level prominence
  fix already shipped, while this change closes the concrete false-absence probe without adding a
  shared resolver framework.

- **B-106** — done in **v0.46.0** (`d329c7c`); its still-open strategic heading was stale and is
  corrected here without another product release. That release added permanent sandboxed
  `route-prompt.sh` cases for no `jq`, a working interpreter available only as `python`, and the
  Windows Store alias stub; changed the five spelling-dependent skips to execution probes; and
  added doctor fixtures proving both the working-interpreter and Store-stub outcomes. Fresh direct
  evidence on 2026-08-08: `RoutePrompt.Tests.ps1` passed 13/13, including all three fallback
  controls. `FrameworkDoctor.Tests.ps1` executed and passed the B-106 cases (working `python`, Store
  stub, no interpreter, and the load-bearing mutation); its file-level result was 20 passed, 1
  failed because the PowerShell twin could not observe `bash` on this maintainer host while the
  shell twin could, an unrelated host-vantage mismatch tracked by B-63/B-85 rather than hidden as a
  B-106 success. **RCA:** implementation and release evidence were appended elsewhere in this
  ledger by the v0.46.0 change, but the original strategic heading was not closed. Keeping live and
  completed state in two sections allowed the contradiction; B-114's heading-integrity gate catches
  duplicate ids, not stale status, so closure still requires explicit release bookkeeping review.
- **B-90 / B-93** — done **2026-08-08**; B-93 was one call site in B-90's class and was absorbed.
  Both the maintainer and shipped test harnesses now bind PowerShell child subjects to the suite's
  current executable instead of preferring `pwsh`. The call-site audit found no current consumer
  that needs a 5.1 parent to upgrade its child: hooks can be registered with `powershell`, and the
  installers, doctor, generator, and release fixtures support both hosts. The aggregate runners may
  still choose `pwsh`; a suite invoked directly under 5.1 now remains honest. **Observed red:** in
  fresh child processes, both unchanged real harnesses were launched by
  `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe` but selected PowerShell 7, and the
  identity probe exited 23; the reachable PowerShell 7 control selected itself and exited 0.
  **Observed green:** after the central change, both real harnesses selected their identical parent
  executable under both 5.1 and 7, with all four fresh probes exiting 0. **RCA:** no gate caught the
  false evidence because the harness helper encoded availability preference while its name implied
  current-host identity, and aggregate runs normally start under `pwsh`, hiding the distinction.
  Once the harness became honest, the architecture fixture went red under 5.1: an expected failed
  `git rev-parse` probe became a terminating `NativeCommandError` outside a worktree. The generator
  now lowers error preference only around that native probe and checks its exit explicitly.
  The same class exposed every child subject using that helper, so the fix was made at both helper
  definitions rather than at B-93 alone; aggregate-runner host choice remains a separately stated
  boundary, not evidence that every suite was exercised under 5.1.

- **B-108** — closed **2026-08-08** with no product change after design and adversarial review
  rejected the remedy as disproportionate. The filed inventory was itself inaccurate: the current
  composed distributions contain seven affected shell files and ten probe sites, not fifteen
  copies, and every observed site now implements the same execution-verified candidate order
  (`python3`, `python`, `py`) despite differing shell syntax. No current behavioural failure was
  reproduced. Normalising six stack overrides plus core hooks/doctor, shipping a canonical fragment,
  and adding twinned lexical validators would police formatting rather than runtime behaviour and
  introduce quoting/comment false-positive risk. The actual residual safety gap is behavioural:
  B-106 already owns permanent no-`jq` fallback tests across the affected surfaces and is the right
  next work. **RCA:** B-104 was missed because the change and review used a spelling-dependent grep,
  not because multiple correct spellings are intrinsically defective. The same class is exposed
  wherever an audit infers behavioural coverage from one textual spelling; future sweeps must derive
  their population from composed artifacts and prove behavior with executable fixtures.

- **B-122** — done **2026-08-08** (meta-only; no shipped version). Sanitized 16 incidental
  maintainer paths while preserving 14 intentional identity/URL lines, made three canary defaults
  relative to `APPDATA`/`USERPROFILE` with explicit overrides, and added an auto-discovered privacy
  test over tracked plus non-ignored untracked files. B-109's three concrete fixtures are assembled
  dynamically, so no fixture exemption weakens the gate. Red-before-green against the real
  pre-change tree: 20 concrete paths found (16 machine details plus four fixture/evidence lines),
  `EXIT=1`; focused post-change suite: 6/6, `EXIT=0`. WSD-035 records that HEAD is clean while old
  published commits retain the metadata. **RCA:** the prior privacy boundary scanned only composed
  distributions, so maintainer scripts, transcripts, plans, and records were outside its population.
  The same class exposes any non-ignored authoring-tree text file; the new gate derives that complete
  working-tree population from Git rather than maintaining a directory list.

- **B-109** — done **2026-08-08** (meta-only; no shipped version). Extended the shared
  `no-meta-leak` denylist to reject Windows user profiles and Linux/macOS home directories while
  retaining generic documentation placeholders. Added a real-dist regression covering all three
  forms on both validator twins. Red-before-green: a planted Windows user-profile path passed both
  validators (`EXIT=0`) before the change and
  failed both afterward (`EXIT=1`); the focused four-form test passed on both legs, full
  `validate-dist.ps1` passed all three dists, and the meta suite passed 11 files with zero failures.
  **RCA:** no gate caught the original leak because check 6 encoded only development vocabulary,
  not host identity or filesystem provenance. The same class exposes any shipped textual artifact
  containing an account-qualified home path; the new cross-platform patterns sweep the entire
  composed distribution without recording a maintainer's identity in the denylist itself.

- **B-114** — done **2026-08-08** (meta-only; no shipped version). Renumbered the lower-reference
  v0.48.0 post-ship review entry from B-113 to B-123; the CI-cancellation entry retains B-113 and
  its existing CHANGELOG references. `DocTruth.Tests.ps1` now extracts live item headings using
  their full `### B-nnn ·` grammar, fails on duplicate ids, and refuses a vacuous zero-id scan.
  Red-before-green: the unchanged backlog passed the old six-case suite despite its duplicate;
  the new check first reported `duplicate live backlog item ids: B-113`, then passed after the
  renumber. **RCA:** no gate caught it because no test parsed backlog identities. Concurrent filing
  exposes every identifier allocated by reading the current tail; the recurrence gate scans the
  complete live-item population rather than special-casing B-113.

- **CI watch, 2026-08-04:** one linux run failed `route-prompt twins agree: security (Copilot)` with
  `ps1=139 sh=0`. Exit 139 is SIGSEGV — the pwsh child crashed on the ubuntu runner; the harness
  recorded the crash faithfully rather than a behavioural divergence. It did **not** reproduce on a
  re-run of the same commit and did not appear on the two earlier runs of the same tree, and the
  commits in question touch no `dist/`, `src/`, or `route-prompt` file. Recorded as an observation,
  not a defect: if it recurs, it is a real bug in a shipped hook on Linux and deserves its own entry,
  and this note is the second data point.

- **B-92** — done 2026-08-04 (meta-only; no version; commits `61257f6`, `c247797`, `97bea4a`, CI
  green on both legs). Three false greens in check 8 reproduced first, then closed; the RCA sweep
  extended the fix to checks 7 and 6. **What CI caught after three local runs said green** — a
  Linux-only `Permission denied` and a Linux-only `-Force` enumeration hole that would have made
  `no-meta-leak` inspect zero hooks and zero skills there. Both are filed as B-70's third and fourth
  instances. Verified: 16 passed / 0 failed / 1 skipped under pwsh 7 **and** Windows PowerShell 5.1;
  both twins exit 0 on all three dists with identical counts; meta suite 0 failures across 8 files.
  The `python3` parser branch cannot run on the maintainer's box at all — CI is its only instrument,
  and it is green there.

- **B-92 (original entry)** — done 2026-08-03 (meta-only; no version). `validate-dist` checks 6–8 now have
  structural anti-vacuity guards in both twins, hook registrations are parsed as JSON, and the new
  real-dist regression suite exercises the PowerShell and bash legs. Check 7 remains limited to its
  inline-command grammar; B-67 owns broader markdown-link coverage. The maintainer selected B-92
  before the unordered P2/P3 items on 2026-08-03; **B-89** is the recommended next item because its
  Windows PowerShell 5.1 defect is consumer-visible. Check 7's rewrite also removed the predictable
  `/tmp/_dead_$$` path it used to write (no temporary file is created now), so the entry filed for
  that during this change was withdrawn rather than shipped.

- **B-86** — the post-ship review v0.44.0 owed, done 2026-08-03 (meta-only; no version). Three
  findings filed: **B-92** (P2), **B-93** (P2), **B-94** (P3). The adversarial pass was run by
  **codex CLI `gpt-5.6-sol`** in a separate session — a different model, which is what Maintenance
  model #2 asks for and what a second Claude session cannot supply; its report is kept as the
  evidence trail at `.claude/plans/2026-08-03-b86-codex-review.md`.

  **Every finding was re-run here before it was filed**, per Maintenance model #3 and the standing
  rule that an implementer's self-report can be a false pass. Re-run, with the observed result:

  | # | re-run | observed |
  |---|--------|----------|
  | 1 | check 8, six `"command"` keys renamed in a scratch `settings.json` | `OK: all 20 hook registrations resolve`, EXIT 0 → **B-92.1** |
  | 2 | check 8, `session-start.ps1` repointed at `C:/definitely-missing/` | `all 26 … resolve`, EXIT 0 on **both twins** → **B-92.2** |
  | 3 | check 8, quoted `-File \"… definitely missing.ps1\"` (valid JSON) | `all 26 … resolve`, EXIT 0 → **B-92.3** |
  | 4 | live `$expectedPathPattern` vs `src/*.tmp`, `meta/*.txt`, `.claude/*.log` | all `allowed=True` → **B-94.1** |
  | 5 | scratch repo: pre-staged `src/a.txt`, then guard refusal | `BEFORE=src/a.txt` → `AFTER=` → **B-94.2** |
  | 6 | scratch repo, `core.quotepath` **unset** (default), non-ASCII path | `"meta/caf\303\251.txt"`, `MATCH=False` → **B-94.3** |
  | 7 | `Get-PsExe` probed from a 5.1 host | returns `pwsh` → 7.6.4 → **B-93** |
  | 8 | **`HarnessIntegrity` red-test under Windows PowerShell 5.1** | control EXIT 0; `@()` stripped from the harness → EXIT 1 → **no finding** |

  **The flagship instrument is sound.** (8) is the one that mattered most and it holds: with the
  v0.41.0 defect re-planted, the mutant printed `3 passed,  failed, 0 skipped` — the `$null` visible
  in the summary — and still exited 1, because the file scores itself independently of the harness.
  That is the design working exactly as its header claims. Run with `powershell.exe` by **absolute
  path** (`$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe`); it is present as
  5.1.26100.8875 and **not resolvable from `PATH`**, re-confirming B-71's live evidence.

  Two corrections the re-run made to the findings as first written, both left visible: the
  git-quotepath case needs **no** unusual configuration (quoting is the default, so the review's
  "with `core.quotepath=true`" understated it), and the in-directory stray of B-94.1 **is** surfaced
  by the unconditional staged manifest, which drops it from a premise-rejection to a record
  overclaim. A finding weakened by evidence is still evidence.

  Also observed: v0.44.0's own CI run **failed** (run 30740988544), as did the three commits after
  it, and `master` is green again only from `8265daf` — the record B-88 was filed on, confirmed
  first-hand rather than read from its entry. Nothing was fixed in this pass, by design: the review's
  product is findings, and fixing them here would collapse reviewer into implementer.

- **B-88** — landed 2026-08-02 (meta-only; `.claude/` never ships, so no version). `release.ps1`
  step 5c watches the CI run for the release commit between the verified `origin/master` push and the
  tag, via a new `.claude/scripts/watch-ci.ps1` (0 green / 1 red / **3 CANT-VERIFY**) and a callable
  `Get-CiPublishDecision` in `.claude/scripts/_ci-decision.ps1`. **WSD-029**; `DEVELOPING.md` has the
  recipe.

  **Shipped stronger than the entry asked, and deliberately.** The entry said "after the tag push
  succeeds"; step 5b's own comment already claimed *"a tag always means a green release"*, so
  watching after the tag would have made that sentence false while the drill protocol checks out the
  latest tag. The watch went **before** the tag instead and the tag became the promotion step: red or
  unverifiable leaves the commit on master **untagged**, and the release exits 1 or 3. The entry's
  real constraint (don't gate the commit on CI) is untouched. This is B-83's class caught in the act
  — the *Do* was written before the reading that contradicts it.

  **Verified, not asserted.** Live against real history: `-Sha a41ab8d` → EXIT 0 on the genuinely
  green run, `-Sha fc3a140` → EXIT 1 on one of the four red ones — real `gh`, real auth, real JSON,
  under **both** PowerShell hosts. `ReleaseCiWatch.Tests.ps1` is 21 cases (18 + 4 self-test), 0
  skipped, green on pwsh 7 and Windows PowerShell 5.1. Its `-SelfTest` plants four recorded
  mutations and asserts the named case goes red for each, with a control run against the unmutated
  watcher first. Both `release.ps1` wiring assertions were red-tested by mutating the real file
  (watch relocated after the tag; the old `exit 0` restored) and observing each fail alone.

  **Four defects found in this work's own instruments, all by red-testing them:**
  1. **A unary comma over-wrapped the parsed rows**, so `$_.event` returned *every* row's event and
     `-eq 'push'` matched a non-empty result — truthy. A failed `pull_request` run for the same sha
     would have decided the release.
  2. **Windows PowerShell 5.1 does not enumerate a top-level JSON array**: `@('[{a},{b}]' |
     ConvertFrom-Json).Count` is **1** under 5.1 and **2** under pwsh 7 (measured). Same consequence
     as (1). `-NoEnumerate` does not exist in 5.1, so the flatten is explicit.
  3. **5.1 raises a terminating `NativeCommandError` for a native command's stderr** under
     `$ErrorActionPreference='Stop'` — `2>$null` redirects the text but not the record. `git rev-parse`
     against a non-repo killed the script with *no output at all* under 5.1 and worked under 7.
  4. **The test fixture was one string, not three.** In PowerShell `,` binds tighter than `+`, so
     `'[' + (New-Row) + ']', '[' + (New-Row) + ']'` is one 656-char concatenation. The polling case
     was exercising a payload that could never parse.

  (2) and (3) were invisible until the suite was made to run the watcher under **its own host**
  rather than `Get-PsExe`'s — which prefers pwsh 7 whenever it resolves. That is verbatim B-74's
  finding, one release later, in new code. Single-row payloads survive (1) and (2) *by accident*, so
  only the multi-row cases could ever see them.

  **Scope limits, recorded rather than glossed:** this notifies and withholds a tag; it does **not
  prevent** a red commit reaching `master` (direct-to-master is B-53's decision). It does **not close
  B-70** — the per-leg job check narrows that exposure, it does not replace it. And no end-to-end
  release was run: ordering and the decision mapping are covered, real parameter binding is not, so
  the next release is part of this change.

- **B-74** — shipped as **v0.44.0**, 2026-08-02. `src/core/tests/hooks/HarnessIntegrity.Tests.ps1`
  plants a fixture with **exactly one** failing test (one, not two: two or more returned a real
  integer and were always caught; one is the shape that hid) and asserts non-zero at both levels —
  the suite file's own exit code and `Invoke-HookTests.ps1`'s sum — with passing controls at each so
  a harness hard-wired to fail would not satisfy it.

  **Two defects in the test itself, both found by red-testing it and both the class it exists to
  close.** (1) The first cut ran its fixtures through the harness's `Get-PsExe`, which prefers pwsh 7
  whenever it resolves — so every fixture ran under pwsh 7 even when the suite ran under 5.1, and the
  one host where the defect exists was never the host under test. With `@()` reverted, the file
  passed. Fixtures now run under `(Get-Process -Id $PID).Path`. (2) It was **scored by the component
  it tests**: with the defect planted it correctly printed `[FAIL]` and then exited **0**, because
  the summary scoring it was the broken one. It now computes its own exit code from `$script:Tests`.
  Every other suite file may trust `Write-TestSummary`; this one provably may not.

  **Evidence:** defect planted → 5.1 `EXIT=1`; restored → `EXIT=0`. Under pwsh 7 green either way —
  recorded as a documented blind spot, not a pass. Dist suites 13 files × 3, 0 failures.

- **B-62** — shipped as **v0.44.0**, 2026-08-02, **with its premise corrected rather than executed.**
  The entry's *Do* ("fail on a bare interpreter name in a shipped settings file") contradicts
  **v0.38.1**, which deliberately reverted absolute-path interpreter pinning because
  `.claude/settings.json` is committed team configuration and a machine-specific path breaks every
  teammate on another OS or profile. A bare name is the *intended* shipped value; the check as
  written would have failed every settings file on purpose. Whether a bare name *resolves* is a
  runtime property no build-time check can observe — v0.39.0's `Hook liveness` doctor row already
  reports that from the consumer's own machine.

  The real gap was that **nothing read the registration files at all**: check 2 proved they parse as
  JSON, check 7 scanned only `*.md`. `validate-dist` check 8 (`hook-registration`, both twins) now
  resolves every reference in `.claude/settings.json`, `.claude/settings.windows.json` and
  `.github/hooks/hooks.json`, requires the opposite-language twin [#3], and rejects an unsanctioned
  interpreter. 26 registrations per dist. Extraction is textual and identical in both twins by
  decision: the bash leg's JSON parser is python3-or-jq depending on the box, so parsing there would
  leave whichever branch a machine lacks untested — B-59's inert-check class.

  > **Superseded 2026-08-04 by WSD-030 (B-92).** The textual-extraction decision recorded in the
  > paragraph above was *reversed*: registrations are now parsed as JSON, because that decision was
  > the direct cause of two of B-92's three false greens (a vacuity floor that was a second regex
  > over the same bytes, and a quoted `-File` value the regex could not read). The concern it names
  > was real and is now handled by coverage rather than by avoidance — `VALIDATE_DIST_JSON_TOOL`
  > pins the branch so both can be exercised and diffed, and the two CI legs run different ones.
  > The paragraph is left standing rather than rewritten, because the reasoning is why the reversal
  > needed its own decision record.

  **Band:** the delivered check is **P2-shaped, not P1**. The P1 severity came from silent dead
  hooks, which v0.39.0 covers consumer-side; this is build-time consistency. Recorded rather than
  silently re-banded — reopen if that reading is wrong.

  **Evidence:** red-tested on both twins against a scratch dist across three defect classes (renamed
  hook in `settings.json`, missing target in `hooks.json`, a hook stripped of its `.sh` twin); both
  legs produced byte-identical findings, and both exit 0 on all three real dists. A normalization
  bug surfaced during the red-test and was fixed: translating each backslash separately turned
  `.claude\\hooks\\x.ps1` into `.claude//hooks//x.ps1`, which resolves on Windows *and* POSIX and so
  hid the sloppiness instead of failing on it; runs of backslashes now collapse to one separator.

- **B-80** — done **2026-08-02** (meta-only, no version/CHANGELOG). `release.ps1` classifies the
  staged set before committing: a mode-`160000` gitlink is a **hard refusal with no escape hatch**
  (this repo has no submodules, so it is always a mistake), and a path outside where the repo keeps
  files refuses unless `-AllowExtraStagedPaths` is passed. The manifest prints either way, and a
  refusal `git reset`s so the index is left as found. Classification happens *after* staging because
  that is the only point at which mode `160000` exists — an unadded worktree is merely untracked
  (verified against `90f331d`, where both strays present as `:160000 000000 … D`).

  **A confirmation prompt was considered and rejected**: `release.ps1` runs non-interactively, where
  `Read-Host` reads EOF as empty — a guard treating that as "proceed" is worse than none, and one
  treating it as "refuse" is a refusal with extra steps. Hence a named escape hatch, per
  `-AllowNonMasterHead`.

  **The allowlist's first cut would have refused every release from v0.39.0 to v0.43.0.** Written
  from this entry's own wording (`src/`, `dist/`, `CHANGELOG.md`, `meta/context-footprint.json`, the
  stamps), it produced **10 false positives** replayed over the last 8 tags: every release touches
  `README.md`, and v0.41.0 touched `.claude/hooks/tests/`. A release commit carries the whole
  session's work, not the stamped set. The question it asks is now "is this file somewhere this repo
  keeps files at all?" — the actual scratch-file hazard.

  **Evidence:** `.claude/hooks/tests/ReleaseStagingGuard.Tests.ps1` (6 tests, auto-discovered by the
  meta suite, so the guard is re-verified at every release). It extracts the guard **verbatim** from
  `release.ps1` rather than re-typing it, is bounded at both ends, and replays the last 8 tags so the
  allowlist cannot silently narrow again. Red-tested by mutation: narrowing the allowlist → 1 failed;
  making the gitlink check inert → 1 failed; restored → 6/6. Meta suite 6 files, 0 failures.

  **The test's own first cut was inert twice**, both caught before landing: the extraction ran to the
  `# ---- 6.` marker and swept in the commit+push (green cases really committed, then failed to push
  to a nonexistent origin) while the marker sanity-check passed, because a too-*large* region still
  contains every marker; and the allowlist replay used a bare `[0]` on a single-match `[string]`,
  yielding its first *character*, so the pattern extracted empty and `-notmatch ''` classified 266
  paths as clean. Both now have assertions that fail rather than agree vacuously.

- **B-45** — done **2026-08-01** (meta-only, no version/CHANGELOG). Root `CLAUDE.md` gained a
  **Maintenance model** section: five rules (locked design + adversarial critique that may reject the
  premise, with a reviewer's corrections treated as input not verdict; implementer ≠ reviewer with an
  auto-filed post-ship review when tiers are equal; nothing enters the record as observed unless you
  observed it *in the environment that matters*; a green result counts only from an instrument seen to
  go red; close every delivery with an RCA). The original entry listed six rules — four of them were
  one rule in four costumes and were consolidated, and the RCA rule was added because it was practised
  but written down nowhere in the repo, which made root `CLAUDE.md`'s "nothing resolves to private
  `~/.claude` memory" claim false. **Crucially the rules are not prose-only:** an adversarial pass
  argued that a prose section plus a "the heading exists" check is theatre in a repo whose whole
  history is *prose did not hold the line*, so rules 2–4 are enforced by `release.ps1`, which now
  refuses to start without `-ReviewEvidence` or an explicit `-NoIndependentReview`, records the
  outcome in `meta/review-ledger.md`, and auto-files the post-ship review item when there was none.
  Mirrored to root `AGENTS.md`; recipes and the concurrency hazard to `DEVELOPING.md`. WSD-028.
- **B-47** — done **2026-08-01** (meta-only, no version/CHANGELOG). MIT `LICENSE` at repo root,
  copyright Costas Andreou, plus a README **Licence** section. The repo was public with no licence
  file since the 2026-07-01 audit, so default copyright made every documented install legally void.
  Posture decided by the maintainer: MIT, **root only**. The dist-travel half was deliberately
  deferred — consumers copy `dist/<stack>/` contents into their own repos and those copies still
  carry no licence text — and is filed separately.
- **B-51** — done **2026-08-01** (meta-only, no version/CHANGELOG). `release.ps1` creates, verifies
  and pushes an annotated tag after the gates and the commit succeed, so a tag always means a green
  release; the historic gap was backfilled. Verified 2026-08-01: 33 tags present, v0.42.0 and v0.43.0
  both tagged by the script during this session.
- **B-53** — done **2026-08-01** (meta-only, no version/CHANGELOG). `release.ps1` refuses to release
  when HEAD is not `master` (escape hatch `-AllowNonMasterHead`, named for what it risks), pushes the
  **commit** rather than the branch name, and asserts afterwards that `origin/master` actually
  advanced to it. Verified 2026-08-01: the branch guard refused a release attempted from a worktree
  branch, and both v0.42.0 and v0.43.0 printed the confirmed-at-origin postcondition.
- **B-73** — done **2026-08-01** (meta-only, no version/CHANGELOG). Two defects, both fixed:
  `release.ps1` now refuses a `-Summary` mangled by MSYS path conversion (the v0.40.0 commit subject
  is permanently corrupted by it), and it states its runtime up front. The runtime notice was itself
  wrong — it claimed "roughly 30 minutes" and had never been measured — and was corrected to a
  measured 5–7 minutes in v0.43.0, which also cut the gate phase 385s → 285s.

- **B-61** — shipped as **v0.41.0**, 2026-08-01. Behavioural twin parity extended from
  `.claude/hooks/` to the shipped `scripts/` twins. New shipped `tests/hooks/ScriptTwinParity.Tests.ps1`
  runs both twins of `template-checks`, `docs-sync-check`, `sync-agent-files` and `metrics` against one
  fixture; `framework-doctor` gained two **non-pending** cases so `Stack toolchain`, `Mirror and version
  integrity` and `Audit trail substrate` are twin-compared for the first time; a maintainer-only
  `.claude/hooks/tests/ScriptTwinCoverage.Tests.ps1` fails on any twin pair that is neither exercised
  nor given a written reason. `RunArg` was promoted into `_HookHarness.ps1` (array args) and
  `WikiCheck.Tests.ps1`'s shadowing local copy deleted.

  **The harness immediately found three divergences that were already shipping** — which is the item
  working, not a surprise:
  1. `metrics.sh` was missing test-integrity counters, by a **different amount per stack** (dotnet +2,
     angular +2, monorepo +4). Two adversarial review passes were needed to get this inventory right;
     the first revision of the plan asserted three keys common to all three stacks and was wrong.
  2. `docs-sync-check` twins printed different prose — four punctuation sites and two whole sentences.
  3. **The test harness itself could not go red** (see the RCA below).

  **Contract decisions, recorded so they are not re-litigated:** comparison is of the **ordered**
  `OK:`/`FAIL:` sequence, never a set (a set hides ordering and duplication defects); exactly two
  normalizations exist, both by name and both commented — `template-checks`' by-design check-6
  asymmetry and a script naming its own sibling twin — with a static assertion that fails if the
  check-6 exemption ever widens. `impact-run` is deliberately **not** behaviourally tested: it needs an
  external agent CLI, git worktrees and paid API calls, and `tests/impact/config.json` *ships*, so a
  naive "missing config" case would fall through the guard and start a real agent run in a consumer
  repo. Case-sensitivity parity is deliberately not asserted (belongs to **B-59(b)**), and the
  `Stack toolchain` regex-vs-glob branch stays unexercised; both are stated in the test rather than
  implied as coverage.

### RCA of v0.41.0 — filed 2026-08-01

**Finding 1 (fixed in this release): the shipped test harness scored a failing suite as green.**
Under Windows PowerShell 5.1, `(… | Where-Object …).Count` on a pipeline yielding **exactly one**
object returns `$null`. `Write-TestSummary` therefore returned `$null`, `exit (Write-TestSummary …)`
became **exit 0**, and `Invoke-HookTests.ps1` — which sums child exit codes — scored the file green
while printing `[FAIL]`. Two or more failures in one file returned an int and were caught, so this hid
precisely the **lone regression**, the most common shape of a fresh break. pwsh 7 returns 1 for the
same expression, which is why CI and the maintainer box never saw it. Reproduced under 5.1 (exit 0
before, exit 1 after) rather than argued. Consumers on 5.1-only boxes — the configuration
`settings.windows.json` exists to serve — were exposed; the shipped changelogs tell them to re-run.

*Why did no gate catch it:* nothing tests the harness that reports test results. B-64 asks that gates
and diagnostics be red-tested; the **reporting layer beneath them** was not in anyone's scope.

*What else is exposed to the same class:* swept every `.ps1` under `src/`, `scripts/` and `.claude/`.
Contained — `framework-doctor.ps1` already used `@()`, and the `metrics.ps1` counters go through
`Measure-Object`, which always returns a real object with a real `Count`. The harness was the only site.

- **B-57** — shipped as **v0.36.0** (guidance) and **v0.37.0** (enforcement), 2026-07-31, WSD-025.
  Field report from a brownfield .NET install on NUnit: the reviewer's complaint was that the
  framework kept pushing xUnit instead of following the suite already in place. Six surfaces stated
  xUnit as fact while Verification Rule #10 and `bootstrap.md`'s Phase 3a synthesis guard both already
  forbade exactly that. Fixed by reusing B-35's evidence-keyed block pattern in `docs/defaults.md`
  § Testing, neutralising `copilot-instructions.md` and the skills-list one-liners, adding a Step-1
  evidence gate to `add-tests` (the .NET branch had hardcoded while Angular already derived from
  `angular.json`), branching `enforce-standards` across xUnit/MSTest/NUnit, and teaching
  `ArchitectureTests.sample.cs` to translate off xUnit. v0.37.0 then closed the enforcement half: the
  guard blocked only `[Fact(Skip=…)]`, so NUnit and MSTest repos got a weaker floor than xUnit ones.

  **Split into two releases deliberately.** The guard regex is the only part that can regress working
  behaviour — an unanchored pattern hard-blocks `public enum Mode { None, Ignore, All }` — so it did
  not ride along with prose changes. That judgement was vindicated: an adversarial review of the plan
  found five blocking defects, four of them in the regex (invalid POSIX bracket syntax that makes
  `grep` exit 2 and silently disables the `.sh` twin; `\s` unsupported by BSD grep; `-match` vs
  `grep -E` case divergence; and a missed `[TestCase(…, Ignore = …)]`, the direct analogue of
  `[Fact(Skip=)]`). All four were confirmed by execution before any code was written.

  Deliberate non-changes, recorded so they are not re-litigated: `tests/impact/tasks.json` keeps
  naming xUnit (the prompt is a direct instruction, the harness runs greenfield, and a held-constant
  prompt is what makes A/B scoring meaningful); `[Explicit]` is not blocked (legitimate NUnit idiom,
  and blocking it would make the framework stricter on NUnit than xUnit). Spun out: **B-58**.

- **B-16** — implemented for **v0.32.0** (2026-07-17). Added the locked WSD-023
  `framework-doctor.{ps1,sh}` design: nine ordered machine checks with verified/pending/missing
  states, explicit human canaries for agent-only facts, parserless bash fallback, PowerShell 5.1
  compatibility, installer/docs handoff, and fixture tests including the fresh-install and
  missing-shell failure modes. The doctor diagnoses only; `docs-sync-check` remains the CI gate.
  **Review finding fixed before merging (PR #1):** the Claude-hooks canary quoted a session-start
  banner that no shipped hook emits ("## AI Tech Lead - Session Context"; the real first line is
  "## Session preload") — exactly the WSD-023 F9 pinned-string hazard, and the F6 failure mode in
  reverse: a developer with *working* hooks would have concluded they were broken. Fixed in both
  twins (canary now also observable via asking the model, since SessionStart stdout is context,
  not chrome), and a new anti-rot test case pins every doctor-quoted string to the hook sources
  it cites (red-tested against the unfixed doctor: caught it). Accepted deviation from the spec:
  row 6 keys off the installed `template` stamp instead of `@stack` markers — one byte-identical
  core file, less drift surface; and the `.sh`-only Copilot CANT-VERIFY branch is a documented
  twin divergence (PowerShell always has a JSON parser).

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
