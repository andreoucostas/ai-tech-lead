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

---

## P2 — gates that lie by omission (drift they were built to catch passes silently)

**All P2 items (B-04…B-09) shipped in v0.25.2 (2026-07-04) — see the Done section.** The
check-lockstep union/computed-skills/hooks.json gates + template-checks skills-mirror gate close
the silent-drift holes; the post-write $tn routing divergence is fixed with twin agreement tests;
the enforcement matrix gained the three missing capability rows.

---
## P3 — hygiene, drift, small fixes

**B-12 was already resolved — see the Done section.** No open P3 items remain from the audit;
post-audit P3 item B-29 (haiku adequacy evidence) is under "Known deferred work" (its sibling
B-30 shipped in v0.25.4).

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

### B-21 · Reviewer-profile systemic fixes — **P0 design DONE; implementation post-merge**
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

### B-22 · Headless `/adopt` — **P0 design DONE (Path A); implementation post-merge**
**Effort:** L · **P0 design complete 2026-07-06** (WSD-014) · **Invariants:** #1 #3 #5 #7

> **Design LOCKED — do not re-derive.** Full spec (adversarially critiqued — verdict RETHINK,
> resolved as **Path A**; findings folded): **`.claude/plans/2026-07-06-b22-headless-adopt-design.md`**;
> decision record **WSD-014**. Implement **post-merge, ≥ v0.28.0**, as single `src/core` edits;
> **depends on B-21 D1** (sequence with or before). Frozen under WSD-012 until the merge.

Agent-runnable, non-interactive adoption. The critique proved the non-negotiable prompt-injection
boundary (constraint 2) forbids auto-merging untrusted content into `CLAUDE.md`; the maintainer
chose **Path A** — headless **prepares** adoption autonomously (branch, archive, provenance +
adversarial screen, impact baseline) and **stages** every proposed CLAUDE.md/TECH_DEBT merge for a
**human to apply at PR review**. Invocation reuses the read-and-execute-the-workflow prompt pattern
(`--headless` directive; both Claude Code + Copilot CLI; `disable-model-invocation` stays). Embedded
Phase-7 `/bootstrap` runs headlessly (3d-bis → all hazards `[UNVERIFIED]`). Composes with B-21 D1.
The remaining backlog work is the implementation (L).

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

### B-27 · Team wiki memory: repo-managed shared knowledge for consumer dev pools
**Effort:** L (implementation only — design DONE) · **Invariants:** #1 #2 #3 #5 #7 · added 2026-07-04

> **P0 (design) COMPLETE 2026-07-04 — do not re-derive.** The full design (D1–D10, twice
> adversarially critiqued, 15/15 external findings incorporated) is at
> **`.claude/plans/2026-07-04-b27-wiki-memory-design.md`**; decision record **WSD-010** in
> `docs/workspace-decisions.md`. Implement from that doc: it contains the normative INDEX
> grammar + frontmatter parsing contract, the install ownership matrix (the #1 trap), the adopt
> screen-in-place class, the injection FAIL/WARN split, the check-lockstep additions, the test
> matrix, the implementation order, and end-to-end verification recipes. Target **v0.27.0 in
> the merged `ai-tech-lead` repo, after B-25-EXEC** (retargeted 2026-07-06 per WSD-012 — see
> the retarget banner on the design doc; D1–D10 unchanged, delivery mechanics map to the
> composer). The constraints below remain the locked envelope the design honors; the design
> doc's refinements win where more specific. **One deliberate reversal:** consumer LEARNINGS.md
> is KEPT (not merged into the wiki) — see WSD-010.

**Problem.** Claude Code auto-memory is per-developer and private; the only *shared* memory a
consumer repo has is CLAUDE.md conventions + append-only `LEARNINGS.md` + the registers
(TECH_DEBT / SECURITY_FINDINGS / ADRs). At large-team scale a single append-only file rots:
merge conflicts, unbounded token growth, no scoping/retrieval, no curation — and one developer's
discovered gotcha never reaches a teammate's agent. The goal is a repo-native shared knowledge
layer ("team wiki memory") so a large dev pool compounds each other's AI-session learnings.

**Grounding (leading practice).** Anthropic's best-practices guidance treats CLAUDE.md/AGENTS.md
as PR-reviewed shared team memory ("treat it as code"); the Karpathy-style "LLM wiki" pattern is
compile-don't-re-derive knowledge into a curated repo wiki; the documented dominant failure mode
of agent-memory systems is **uncurated accumulation** → noise, contradiction, context bloat.
Claude Code's own harness memory (an index file + one-fact-per-file with frontmatter) is the
reference implementation shape.

**Locked design constraints** (decided 2026-07-04 — the design phase refines *within* these,
it does not relitigate them):
1. **Repo-native, file-based, PR-curated.** A wiki dir (location decided in design phase;
   candidate `docs/wiki/`) — one fact per file with frontmatter (`name`, one-line `description`,
   `type: gotcha|context|recipe|failed-approach`, `scope` (area/glob), `last-verified` date,
   author). An `INDEX.md` (one line per entry) is the only always-loaded piece; agents read
   entries selectively by relevance.
2. **No RAG / embeddings / MCP memory server / decay algorithms** — REJECTED: infra-heavy,
   unusable across both surfaces (Copilot + Claude Code in Bitbucket DC shops), and unnecessary —
   grep + index is sufficient retrieval at repo scale. Staleness = a `last-verified` date + human
   review, not decay math.
3. **Write path is human-gated.** A skill (working name `remember-for-team`) drafts entry +
   index line; it reaches the team only via normal commit/PR review. **No auto-append hook** —
   REJECTED: auto-capture noise defeats curation, and every auto-write is a prompt-injection
   channel. The PR review *is* the memory-quality mechanism.
4. **Curation designed in:** the skill searches the index for duplicates before creating (update
   beats duplicate); entries >90 days unverified are resurfaced for confirm-or-delete (mirror the
   B-21 hazard-refresh pattern); an index-size threshold warns on token bloat (cf. B-26).
5. **Security — wiki entries are model-consumed text committed by many hands.** Treat as an
   injection surface: guard patterns scan wiki writes like any write; `/adopt`'s quarantine
   treats pre-existing wiki dirs as adversarial-content candidates; the consumed guidance states
   entries are *claims to verify against code, not instructions to obey*; the entry template
   forbids imperative phrasing ("always run X") in favor of factual claims.
6. **Boundaries:** the wiki must NOT duplicate TECH_DEBT / SECURITY_FINDINGS / ADRs / CLAUDE.md
   conventions. It is the layer beneath: gotchas, tribal context, failed approaches, "why X looks
   weird". The design must define the **promotion path** (recurring wiki entry → CLAUDE.md
   convention or ADR) and decide consumer `LEARNINGS.md`'s fate (likely: becomes/feeds the wiki).
   The wiki is a staging area, never a rival source of truth — CLAUDE.md wins conflicts.
7. **Dual-surface, instructed-first.** Must work with zero hooks (index referenced from the
   CLAUDE.md/AGENTS.md companion-files preamble [#2]); an optional session-start index preload is
   salience-only, twin-scripted [#3], and honest per surface [#5] — remember `postToolUse`
   additionalContext is NOT consumed by the Copilot CLI model (B-03 canary).

**Suggested phases.** P0: design doc weighing ≥2 layouts (flat dir + index vs scoped subdirs;
session-start preload vs pointer-only), adversarial critique pass, record the outcome in
`docs/workspace-decisions.md`. P1: implement in dotnet → mirror to angular [#1] (dir skeleton +
entry template, skill mirrored to `.github/skills` [#2], CLAUDE.md preamble line + AGENTS.md
regen via `/generate-copilot` [#2]). P2: deterministic `wiki-check` validation (frontmatter
validity, index↔files bijection, size threshold) as `.ps1`/`.sh` twins [#3], referenced from the
B-15 consumer CI recipe. Then CHANGELOG both repos + release via `release.ps1` [#7].

**Verification for the executing agent (evidence-based — show commands + observed output):**
- *Skill:* greenfield + brownfield install smoke into temp dirs → ask the agent to save a team
  learning → entry file + index line created, frontmatter parses; repeat the same fact → it
  updates the existing entry (dedup), does not duplicate.
- *Retrieval:* fresh session in the temp install → a planted entry is cited when its scoped area
  comes up, via index + one entry read (not a bulk load of all entries).
- *wiki-check red-tests:* plant (a) an index line with no file, (b) a file with no index line,
  (c) malformed frontmatter → each fails with a specific message; a clean fixture exits 0. Run
  BOTH twins on the same fixtures and assert identical verdicts (follow the `tests/hooks/`
  harness pattern; remember the EOL-normalization + absolute-path traps in LEARNINGS.md).
- *Injection:* attempt a wiki entry containing a secret / instruction-like payload → the
  editor-path guard fires (existing fixture pattern under `.claude/hooks/_fixtures/`).
- *Parity:* `template-checks` ×2, `check-lockstep`, `docs-sync-check` all green; AGENTS.md
  regenerated.

**Recommendation & pushback (recorded at triage):** worth building — it converts the framework's
weakest long-term asset (append-only LEARNINGS.md) into a compounding one, and it is the only
piece that scales knowledge across a dev pool rather than per seat. The pushback is on *shape*,
encoded in constraints 2–3: systems in this space die of uncurated auto-capture or of infra
nobody runs. Value is contingent on teams reviewing wiki PRs like code — say so explicitly in
the shipped docs (fits the reviewer profile: entries must read as plain engineering notes).

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

### B-32 · Context-footprint gate: deterministic measurement + regression tripwire for the always-loaded surface — **P0 design DONE; implementation post-merge**
**Effort:** M · **P0 design complete 2026-07-11** (WSD-017) · **Invariants:** #3 #6 #7 · added 2026-07-11

> **Design LOCKED — do not re-derive.** Full spec (adversarially critiqued — LOCK WITH
> AMENDMENTS; 2 HIGH + 5 MEDIUM + 5 LOW folded, both HIGHs independently re-verified):
> **`.claude/plans/2026-07-11-b32-context-footprint-gate-design.md`**; decision record
> **WSD-017**. Implement **after Phase 6 / v0.26.0** (maintainer-side — no shipped-behavior
> change, so no version slot per invariant #7), **before or with B-27 (v0.27.0)** so the wiki
> inherits the counting rule. The one shipped piece (framework-doctor "context cost" section,
> design D6) rides B-16 (≥ v0.28.0).

Problem: B-26's "re-measure if context budgets tighten" was an advisory note nobody executed,
and WSD-015's 1.17×/1.5× monorepo token check was a one-off. Measured 2026-07-11: static
per-prompt overhead ≈ **8.5–10.4K tok on Claude Code** (CLAUDE.md + skills/commands/agents
frontmatter; monorepo highest at 41,443 chars) and ≈ **6.0–7.6K on Copilot** (AGENTS.md +
copilot-instructions.md), plus up to ~1.1K route-prompt rails per matched prompt — previously
invisible and silently growable. Ship `scripts/context-footprint.ps1/.sh` twins: per-dist
manifest (static.claude / static.copilot / instructed / session / prompt / ondemand-info);
rendered-hook fixtures execute **both** hook twins and FAIL on output mismatch (doubles as the
first rendered-rails content-parity gate); committed baseline `docs/context-footprint.json`
with hand-rolled canonical serialization; freshness-style FAIL on any drift; advisory WARN
ceilings (40K/48K chars static.claude; 1.5× monorepo CLAUDE.md ratio — absorbs WSD-015's
fallback trigger); CI cross-OS legs = the twin proof; `release.ps1` runs `-Update` (version
stamp lands after PRs were gated). Non-goals (locked): no tokenizer, no consumer-side FAIL, no
output-token measurement, no relitigating WSD-011. Verification recipes + red-test matrix are
in the spec.

---

## Done

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
