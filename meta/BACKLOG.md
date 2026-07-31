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
> 6. Then interleave: **B-15** (CI recipe) from the deferred list — it is
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

### B-51 · Release tags stopped at v0.26.0 — restore the release artifact contract
**Effort:** S · **Priority:** P2 reproducibility · **Invariants:** #7

**Found by:** B-49 drill #0 D0, 2026-07-17. The latest release was v0.32.2 but `git tag
--sort=-version:refname` showed only `v0.26.0` and `pre-restructure`. The locked drill protocol
requires a clean checkout of the latest released tag; drill #0 had to use the known release commit
`29e57fea78adc1446426ad27b742a294bde3e3bb` instead. Extend `release.ps1` to create and push an
annotated `vX.Y.Z` tag only after every gate and the release commit succeed; add a safe retry/idempotency
test. Decide whether to backfill v0.26.1–v0.32.2 or tag only current/future releases, and record the
choice in a WSD.

**Reproduced 2026-07-31 by the v0.38.0 release:** the release committed and pushed successfully,
and `origin/master` was confirmed at the new SHA, but no `v0.38.0` tag was created. `git tag` still
ends at `v0.26.0`.

**DONE 2026-07-31.** Both halves closed.

*Code:* `release.ps1` now creates and pushes an annotated `vX.Y.Z` tag after every gate and the
release commit succeed, so a tag always means a green release. A re-run finding the tag already on
the release commit skips it; a tag pointing anywhere else is refused rather than moved; the push is
verified against `ls-remote`, because a local-only tag is precisely the failure this entry
describes. An isolation test caught a real bug before it shipped: `git rev-parse refs/tags/x` on an
**annotated** tag returns the tag *object* sha, not the commit sha, so without a `^{commit}` peel
every retry would have taken the "exists elsewhere" branch and refused a re-run outright.

*Backfill (maintainer decision — backfill all, verified):* **27 tags created** for v0.26.1 … v0.40.0
and pushed; with the pre-existing `v0.26.0` that is **29 version tags, every one verified on origin**
to point at the same commit locally and remotely. Tags were not trusted to commit subjects — each was
placed only where that commit's own `dist/angular/.claude/framework-version.json` stamp equals the
tag version, so the tag is backed by the artifact rather than by a message someone typed.
`git tag --sort=-version:refname` now returns `v0.40.0`, so the B-49 drill protocol's "clean checkout
of the latest released tag" works without a raw SHA.

*Deliberately not tagged:* the pre-merge legacy versions (0.13.x–0.19.x) appear **twice** in history —
once from each legacy repo merged in — and carry no `dist/` stamp, so a tag would be ambiguous and
unverifiable. The root `CHANGELOG.md` starts at v0.26.0 for the same reason.

**Anomaly surfaced by the backfill, root-caused and fixed the same day:** **v0.34.0 has no release
commit.** Its version stamp lands in `524842f`, a squashed PR merge whose subject reads
"B-52: persist two-hook Copilot canary durably + point BACKLOG at it **(meta-only)**". Reading the
squashed body shows why: the PR carried three commits and the third was a genuine release
(`v0.34.0: add technical architecture presentation and system map`, gates green, version stamps and
all three changelogs in the diff). `release.ps1` had been run **on the PR branch**, and the
squash-merge replaced the release commit's subject with the PR title.

So the label was never the problem — the root cause is that `release.ps1` had **no precondition that
HEAD is master**, which is **B-53(a)**, open as a P1 through four detached-HEAD occurrences. This is
the fifth occurrence and a second mechanism for it. Fixed in B-53 (see that entry): releasing off
master is now refused, with the squash hazard named in the error. The tag stays at `524842f` because
that is verifiably where the shipped version became 0.34.0.

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

**Not:** don't relax the `enforcement-surfaces.md` wording pre-emptively — it already keeps the VS
Code hedge; this item either upgrades the CLI row to verified or triggers the fallback. Cross-links:
B-43 (recert cadence — run this in the same quarterly slot), B-50 (the sibling `postToolUse`
capability-honesty item from drill #0), B-03 (original canary design).

### B-53 · `release.ps1` can print "Release complete" while shipping nothing
**Effort:** S · **Priority:** P1 release integrity · **Invariants:** #7

**Why:** the commit+push step runs `git -C $repo push origin master` — it pushes the branch **by
name**, not the commit it just created. During the v0.35.0 release the repo was on a **detached
HEAD** (and had been for three releases); the release commit landed on that detached HEAD,
`push origin master` pushed the *unchanged* local `master` ref, exited 0, and the script printed
`Release 0.35.0 complete.` Nothing reached `origin`. There is no precondition asserting HEAD is on
the expected branch, and no postcondition asserting `origin/master` actually advanced to the new
commit — so the one thing a release script exists to guarantee is unverified. This is not
hypothetical drift: the v0.34.3 root CHANGELOG entry is scar tissue from an earlier instance of the
same class ("replayed here as v0.34.3 to resolve the version collision … that shipped on `master`").

**Root cause of the recurrence, identified 2026-07-31 (4th occurrence, found pre-flight while
shipping B-57):** the repo does not drift into a detached HEAD by accident — **Claude Code scratchpad
worktrees claim the `master` branch**. An abandoned worktree under
`%TEMP%\claude\<project>\<session>\scratchpad\wt-*` still held `master` (at a commit two behind
`origin/master`, with 1126 uncommitted deletions and nothing else), which forces the main working
directory to a detached HEAD and leaves the `master` *ref* stale. That is the precondition for the
failure above, and it will keep recurring for as long as sessions create worktrees here. Note this
also means fix (a) below, added on its own, would **block every release** until the operator
understands the worktree interaction — so ship (a) with an error message that names the likely cause
and the remedy. Non-destructive remedy, verified: `git -C <worktree> checkout --detach` frees the
branch without discarding the worktree, then `git checkout master && git merge --ff-only <sha>`.
`git worktree list` is the diagnostic.

**Do:** (a) refuse to run when HEAD is detached or not on the expected branch, unless an explicit
override is passed — and when refusing, run `git worktree list` and point at any worktree holding the
target branch; (b) push the commit explicitly (`HEAD:master`) instead of by branch name;
(c) after pushing, re-read `origin/master` and fail loudly unless it equals the release commit;
(d) apply the same postcondition to the eval-results push. Consider also warning when the target
branch is checked out in another worktree — that is what let the divergence persist unnoticed.

**DONE 2026-07-31 — (a), (b), (c) and (d) all shipped.** Reached by asking for the *root cause* of
the v0.34.0 anomaly that the B-51 tag backfill surfaced, which turned out to be this entry's missing
precondition.

**A fifth occurrence, and a new mechanism.** The four known instances were all detached HEAD. v0.34.0
was different: `release.ps1` ran on a **PR branch**, and the branch was then **squash-merged**.
GitHub replaced the release commit's subject with the PR title — "B-52: persist two-hook Copilot
canary durably + point BACKLOG at it **(meta-only)** (#5)" — so a real release
(`v0.34.0: add technical architecture presentation and system map`, gates green, stamps and all three
changelogs in the diff) survives only as a bullet inside a squashed commit body, under a subject
asserting it shipped nothing. The precondition now covers both mechanisms, because both reduce to
"HEAD is not master's tip".

**Shipped:** (a) refuses unless HEAD is `master`, printing `git worktree list` and the
non-destructive `checkout --detach` remedy on the detached path, and naming the v0.34.0 squash hazard
on the branch path; escape hatch `-AllowNonMasterHead`, named for what it risks rather than what it
enables. (b) pushes `<commit>:refs/heads/master`. (c) re-reads `origin/master` via `ls-remote` and
exits 1 unless it equals the release commit, saying explicitly "do not treat this as shipped".
(d) the same explicit push + postcondition on the eval-results push.

**Red-tested, including the original failure reproduced end to end** in a throwaway repo with a bare
origin: on a detached HEAD, `git push origin master` printed **"Everything up-to-date"** and
**exited 0** while `origin/master` stayed at the old commit — B-53's exact claim, demonstrated rather
than argued. `push <commit>:refs/heads/master` then advanced origin to the release commit. Guard
tests: feature branch → refused exit 2; detached HEAD → refused exit 2 with the worktree list;
`master` → proceeds to the real gates. Meta suite 0 failures.

### B-54 · Shipped changelog dates are never stamped, and no gate rejects the placeholder
**Effort:** S · **Priority:** P2 gate lies by omission · **Invariants:** #7

**Why:** `release.ps1` rewrites `Unreleased` → today's date in the **root** `CHANGELOG.md` only. The
three shipped changelogs (`src/stacks/*/files/CHANGELOG.md`) are never touched, and the
`template-checks` version-stamp gate parses only the version *number* out of the head entry
(`^## (\d+\.\d+\.\d+)`), so `## 0.35.0 — Unreleased` satisfies it. v0.35.0 came within one manual
catch of shipping the literal word "Unreleased" to consumers as its release date.

**Do:** extend the release stamping to the shipped changelogs, **and** make `template-checks` fail
when a shipped changelog head entry carries a placeholder instead of a date — belt and braces, so
the gate still catches it when an entry is hand-authored outside the release script.

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

### B-56 · Host-dependent capability probes make gate outcomes machine-dependent
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

**Process evidence added 2026-07-31:** do not run gate suites concurrently with an implementer
round. During the v0.38.0 task, a hook suite raced a tree being modified by a concurrent Codex run
and produced a transient failure that cost a diagnosis cycle. The implementer's self-reported
before/after was also a false pass **twice**: both verifications ran inside a sandbox whose `PATH`
differed from the real environment, so the defect could not manifest there. The reviewer re-running
the red-test in the real environment caught both failures.

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

### B-63 · Audit every capability probe for vantage-point validity
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
`C:\Users\Costas\.claude\plans\let-s-go-ahead-and-sorted-quill.md` (including three precision traps:
qualify circular DI to the *self-referencing* `useExisting` provider; do **not** claim "Angular
warns" about `@Input() disabled` — it collides with `setDisabledState()`, which is a different
thing; signal inputs are read-only so a CVA's *value* cannot be an `input()`).

Scope note: `bootstrap.md`/`adopt.md` were taken deliberately even though B-66 deferred the
delivery-tier question to B-65. B-65 is about restoring the pointer `/bootstrap` *deletes*; this was
about what `/bootstrap` *writes*. Adjacent, not the same.

### B-67 · `no-dead-instruction` does not validate markdown link targets
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

### B-71 · Silently skipped tests make a green local suite weaker than it looks
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

### B-73 · `release.ps1` invoked from bash mangles any argument beginning with `/`, and its runtime now exceeds the tooling that calls it
**Effort:** S · **Priority:** P2 release integrity · **Invariants:** #7 · found 2026-07-31 shipping v0.40.0

**Why (defect 1 — a corrupted permanent record).** The v0.40.0 release was invoked from Git Bash as
`-Summary "/bootstrap and /adopt capture Angular forms conventions"`. MSYS argument conversion
rewrote the leading `/bootstrap` into a Windows path before `pwsh` ever saw it, so the release commit
subject is permanently:

```
v0.40.0: C:/Program Files/Git/bootstrap and /adopt capture Angular forms conventions
```

The release itself was correct — all 11 gates green, `origin/master` verified in sync — but the
commit subject is wrong in the one log that is supposed to be authoritative. Note the second
`/adopt` survived: MSYS converts only the *first* token when it looks like an absolute path, which
is exactly the kind of half-applied corruption that reads as a typo rather than a tooling bug. Every
slash-command name in this framework (`/bootstrap`, `/adopt`, `/review`, `/fix`, `/feature`,
`/design`, `/debt`, `/map-warehouse`) triggers it, so any release summary naming a command is
exposed. Same interop family as the `hooks.json` backslash-escape trap (B-52) and the corrupted
session `PATH`.

**Do:** either defend inside the script (reject or repair a `-Summary` containing the repo path /
`Program Files`, since neither can be intentional) or document `MSYS_NO_PATHCONV=1` as the required
invocation and add it to `DEVELOPING.md`'s release recipe. The script-side guard is preferable —
`DEVELOPING.md` already has a recipe and it did not prevent this.

**DONE 2026-07-31 (both halves).** The script-side guard shipped: `release.ps1` refuses a `-Summary`
containing the Git install path or the repo path and prints the `MSYS_NO_PATHCONV=1` remedy. The red
test **reproduced the bug live** — passing the *correct* string from Git Bash still tripped the
guard, because bash mangled it on the way in; the same string with `MSYS_NO_PATHCONV=1` passed
through and proceeded to the real gates. The v0.40.0 commit subject itself was corrected by rebuilding
the two commits on top of `790e42c` and force-pushing with `--force-with-lease`, after proving the
rebuilt history was content-identical (`git diff` against the originals empty in both directions).
The runtime notice also shipped: the script now states the ~30-minute estimate and "if interrupted
before complete, nothing was committed — re-run as-is" before the first gate.

**Residual, deliberately not done:** the `-ResumeFrom` / `-SkipGates` escape hatch. Skipping gates is
the one thing this script exists to prevent, and a flag that does it would be reached for under
exactly the time pressure that makes it dangerous. The re-run-as-is path is slow but honest. Revisit
only if release runtime grows further.

**Why (defect 2 — the release cannot fit in one tool call).** The gate sequence is
`compose ×3 → footprint → validate-dist ×3 → hook suites ×3 → meta suite → eval self-test`, and the
hook suites alone run ~10 minutes each. The first v0.40.0 attempt was **killed at the 10-minute
background-task cap, mid-gates** — after stamping, composing, and rewriting the footprint baseline,
but before committing. It had to be re-run under a persistent monitor. The failure presents as a
kill, which is indistinguishable at a glance from a gate failure, and it leaves a stamped and
rebuilt tree that looks like a botched release. The script's re-run-as-is design saved it, but
nothing tells the operator that.

**Do:** print an up-front runtime estimate and a "safe to re-run as-is if interrupted" line before
the first gate; consider a `-ResumeFrom` or a `-SkipGates` escape hatch for a re-run whose gates
already passed minutes earlier. Cross-links: B-53 (the other release-integrity entry — same script,
different failure), B-51 (tagging, still unfixed and reproduced by this release).

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
