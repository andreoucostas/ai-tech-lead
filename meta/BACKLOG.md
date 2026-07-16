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
B-30 shipped in v0.25.4). **B-38, B-39 (both phases), and B-36 all shipped 2026-07-16 — see the
Done section. B-34 (added 2026-07-15) is the only open P3 item.**

### B-34 · Rendered-output twin parity: guard + audit-trail (the hooks B-32's fixtures don't cover)
**Effort:** S–M · **Invariants:** #1 #3 #5 #7 · added 2026-07-15 (found during B-32 implementation)

**Problem.** The B-32 fixture work proved the `.ps1` hook twins render *different model-visible
text* than their `.sh` twins — the `.ps1` side was written ASCII-safe (`WARNING:`/`--`) while the
`.sh` side uses the house style (`⚠`/`—`/`→`). Invariant #3 promises identical behavior; the hook
suites test decisions/robustness, never rendered content (exactly the M5 gap named in the B-32
spec). session-start + route-prompt were aligned and gated in v0.26.5 (B-32's twin-render fixtures
now FAIL on drift there). **guard and audit-trail remain unswept**: grep evidence 2026-07-15 —
`guard.sh` 16 unicode-bearing lines vs `guard.ps1` 11; `audit-trail.sh` 4 vs `.ps1` 0 (some are
comments; nobody has diffed the *rendered* output).

**Do:** render-diff each remaining twin pair (`guard`, `audit-trail`, and the per-stack
`post-write` files under `src/stacks/*/files/`) across their existing test fixtures
(`tests/hooks/_fixtures/` patterns), byte-compare stdout/stderr per surface shape [#5]. Align
divergent rendered strings to the `.sh` canonical, sweep stack snippets/siblings [#1], update any
tests pinning old strings, rebuild dists. Ship via release.ps1 [#7]. Consider extending the B-32
fixture set to these hooks in the same pass (they're cheap once fixtures exist — but note guard's
output is *stderr + JSON deny shapes*, not plain rails, so the fixture capture differs).

**Not:** wording changes; the `.sh` content is canonical, this is formatting-parity only.

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

### B-23 · Evals as a release gate
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

### B-29 · Haiku-tier agent adequacy evidence (P3)
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
