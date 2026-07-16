# ai-tech-lead — Changelog

> **This is the *maintainer's* changelog — the engineering log for the authoring repo.** It may
> reference tracking ids, decisions (`WSD-nnn`), and internal tooling. The **consumer-facing**
> release notes are the ones that ship inside each dist (`dist/*/CHANGELOG.md`, authored at
> `src/stacks/*/files/CHANGELOG.md`); those are written in the consumer's voice and are gated by
> `no-meta-leak` [#6]. Do not blur the two.
>
> This file starts at the merge (v0.26.0). Earlier framework history — everything before
> `ai-tech-lead-dotnet` and `ai-tech-lead-angular` combined into this repo — lives in the two
> preserved legacy changelogs: [`meta/changelogs/legacy-dotnet.md`](meta/changelogs/legacy-dotnet.md)
> and [`meta/changelogs/legacy-angular.md`](meta/changelogs/legacy-angular.md).

## 0.29.0 (2026-07-16)

### Added — B-22: headless `/adopt` (Path A — prepare autonomously, human applies the merge)

Implements the LOCKED design `.claude/plans/2026-07-06-b22-headless-adopt-design.md` (WSD-014,
**Path A**), unblocked now that its hard dependency B-21 D1 (the PR judgment checklist) has shipped.
Closes the last manual step of adoption without breaking the prompt-injection trust boundary that
made `/adopt` developer-initiated. Authored as **three-stack whole-file edits** of `adopt.md` and
`bootstrap.md` (invariant #1 — they are stack whole-file overrides, only the prompt wrapper +
installers are core), plus the two core installer twins (invariant #3). Implemented this session by
principal-engineer direct edit after the intended codex (gpt-5.6-sol) implementer was blocked by the
bypass-authorization boundary (see `meta/LEARNINGS.md`).

- **`adopt.md` gains a normative `## Headless mode` section** (byte-identical across all three
  stacks). When `$ARGUMENTS` carries a `--headless` directive, the workflow **prepares** adoption
  autonomously — auto-branch `adopt-ai-framework`, archive, provenance + adversarial screen, impact
  baseline, PR structuring — and **stages** every proposed `CLAUDE.md`/`TECH_DEBT.md` merge as a
  clearly-marked, attributed, normalized block for a human to apply at PR review. A per-gate
  override table makes each interactive gate's headless behavior normative (skip ambiguous, exclude
  quarantine with no auto-upgrade, record-not-apply the plan, stage-don't-apply merges with the
  `<!-- DEFAULTED -->` marker on 4a contradictions, unset TECH_DEBT severity/effort, never auto-add
  custom commands, commit to the branch only). Everything deferred lands in the Phase-8 report +
  B-21 checklist.
- **The trust boundary is preserved by construction (constraint 2), not by the flag.** Nothing
  derived from an untrusted discovered file is ever *applied* to canonical guidance without a
  person; `disable-model-invocation: true` stays on `adopt.md`/`bootstrap.md`. Works on both Claude
  Code (`claude -p`) and Copilot CLI (its `-p` equivalent), reusing the read-and-execute prompt
  pattern — so the boundary holds even where the flag is irrelevant (Copilot). A restricted tool
  surface (deny network egress / secret access / git-config changes) bounds mid-run exposure.
- **Marker/guard lifecycle:** the install is committed to the **default branch** (precondition);
  headless deletes `.claude/adoption-pending.json` only on the adoption branch, so SessionStart +
  `docs-sync-check` keep firing on the default branch until a human merges the reviewed PR — guards
  release on human merge, not on the headless run.
- **Embedded Phase-7 `/bootstrap` runs headless too (HIGH-2 fix):** the `--headless` directive
  propagates in; `bootstrap.md` Phase 3d-bis no longer stalls — it takes the "skip all — mark as
  unverified" path automatically, writing every candidate hazard `[UNVERIFIED]` onto the checklist,
  never auto-confirming a hazard unattended.
- **Installer twins + marker `nextStep`** now offer the headless entry alongside the developer path
  (`src/core/scripts/install.{sh,ps1}`): the brownfield agent-handoff block tells an installing
  agent it may EITHER hand off to a developer OR run headless adoption (which prepares a PR branch
  for human review and does not auto-merge or open the PR). The `InstallerContract` gate confirms
  the full agent contract still prints in both modes × both twins × all three dists.

## 0.28.0 (2026-07-16)

### Added — B-21: reviewer-profile systemic fixes (judgment items stop scattering and expiring silently)

Implements the LOCKED design `.claude/plans/2026-07-06-b21-reviewer-profile-design.md` (WSD-013).
The reviewer profile (competent engineers, limited AI understanding): the pipeline makes every
AI-architecture call itself; reviewers only answer plain questions about their own code. The
residual gap the design named — judgment-needed items are created with good UX but then scatter
and expire silently — is closed by three deltas. Implemented via a codex (gpt-5.6-sol) implementer
under principal-engineer review (this session); shipped as **three-stack whole-file edits**, not
the single `src/core` edit the pre-merge spec assumed (`bootstrap.md`/`adopt.md`/`FRAMEWORK-CONTEXT.md`
are stack whole-file overrides — the spec's "one src/core edit per artifact" was stale; only the
`session-start` twins are core).

- **D1 — one "Needs a human decision" checklist emitted for the PR/commit.** `bootstrap.md`
  Phase 4 and `adopt.md` Phase 8 now emit a prioritized (~10-cap) fenced block titled
  *"Paste this into your PR (or commit message)"*, each item a plain yes/no question with a file
  pointer. Sources: `<!-- INFERRED -->` conventions, `(c) unsure`/tooling-only hazards,
  adopt-4a contradictions resolved by default, and `origin: discovered` skills. bootstrap
  **suppresses** its block under `/adopt` (Phase 8 is the sole emitter, reusing the existing
  Phase-2b adopt-context signal, M1); bootstrap gains a commit/PR nudge since it has no branch
  step of its own (H2a). adopt Phase 4a writes a durable `<!-- DEFAULTED: … -->` marker at
  resolution time so the choice survives the full `/bootstrap` pipeline that runs between 4a and
  8 (H2b); Phase 8 re-scans it. Empty categories are omitted; all-empty prints one line.
- **D2 — hazard staleness becomes a mechanism.** `session-start.{ps1,sh}` (core twins) parse
  `FRAMEWORK-CONTEXT.md > Known Hazard Areas` and resurface areas whose `Reviewed` date is >90
  days old — real interval math (`cutoff = today − 90d`, ISO-pinned, GNU-`date` guard on the sh
  side per H1; no `date -j`/epoch, avoiding the B-02 skew class). Open items (`[UNVERIFIED]`/
  `[SUSPECTED]`) get an open-question line; `[VERIFIED]` a lighter re-confirm nudge. Excludes
  `[REVIEWED: not a hazard]`, the `_` placeholder row, and files still carrying
  `KNOWN_HAZARD_AREAS_PENDING` (M4). Block lives inside `$body`/`emit_body` so the Copilot
  surface gets it via JSON `additionalContext` (M5). `bootstrap.md` 3d-bis now pins `Reviewed`
  and the not-a-hazard status to ISO `YYYY-MM-DD` (the parser keys on it). Header "keep fast"
  comment updated to include FRAMEWORK-CONTEXT.md + the ~12-row cap (L2).
- **D3 — rendered legend + "merge ≠ verified".** `FRAMEWORK-CONTEXT.md` gains a visible
  (non-comment) one-line ladder legend and the sentence *"Merging the PR does not confirm these
  …"* directly above the hazard table — the prior explanation lived inside an HTML comment that
  never renders in GitHub file view (M3). The `[VERIFIED]/[SUSPECTED]/[UNVERIFIED]` tokens stay
  (machine anchors for D2's parser and 3d-bis's writer).

**Verification:** new `src/core/tests/hooks/SessionStartHazard.Tests.ps1` (19 cases: resurface /
fresh-silent / unparseable-skip / REVIEWED-excluded / placeholder-skip / PENDING-silent /
confirmed-stale lighter nudge / suspected-resurface / twin-agreement / Copilot dual-shape on both
twins) — red-tested against the pre-D2 HEAD hook (no resurface line), green after. Cross-stack
sibling parity confirmed byte-identical (D1/D3 inserts). Gates green: build ×3 + dist freshness;
validate-dist ×3 (markers, template-checks/AGENTS mirror, no-meta-leak, no-dead-instruction);
dotnet dist hook suite 0 failures across 10 files (TwinParity 40/40). Full gate battery via
`release.ps1`.

## 0.27.1 (2026-07-16)

### Fixed — B-37: post-ship review findings on v0.27.0 (team wiki memory)

Post-ship review of `60dd04c` against the locked B-27 spec (WSD-010) found six defects, all
fixed here. Review/verification: Fable 5; implementers: Opus 4.8 (scripts + tests), Sonnet 5
(docs). Full evidence in `meta/BACKLOG.md` B-37.

- **F1 (P1)** `wiki-check.sh` used GNU-only `date -d` — the only occurrence in any shipped
  script — so on BSD/macOS every *valid* `last-verified` FAILed as "invalid last-verified",
  turning macOS consumer CI red via the `docs-sync-check` chain on the first wiki entry.
  Replaced with pure-shell calendar validation (rejects 2026-02-30 deterministically on every
  platform) + a feature-detected 90-day cutoff (GNU `date -d` → BSD `date -v` → skip the
  staleness WARN); the per-entry staleness check is a lexical YYYY-MM-DD compare.
- **F2** Both `wiki-check` twins read `$Root` from **stdin** when no argument was given, so an
  interactive `docs-sync-check` run blocked waiting for a keyboard line (CI survived only via
  /dev/null stdin). The stdin path is removed: root comes from the argument — `docs-sync-check`
  now passes it explicitly — or self-anchors to `scripts/..` like `template-checks`.
- **F3** The sorted-index check was locale-dependent (bare `sort` in .sh vs culture-sensitive
  `Sort-Object` in .ps1 — glibc UTF-8 locales collate hyphens differently, the B-02 skew
  class). Pinned to byte/ordinal order in both twins (`LC_ALL=C sort`;
  `[StringComparer]::Ordinal`); `remember-for-team` step 4 documents the order.
- **F4** Locked-spec omissions (D4/D9) shipped: the "What We've Learned" boundary sentence in
  `CLAUDE.md` and the LEARNINGS-vs-wiki boundary table in `docs/wiki/INDEX.md`.
- **F5** `SessionStartWiki.Tests` now cover the `.sh` hook's Copilot-JSON `additionalContext`
  delivery (jq/python3-gated, skip otherwise); red tests added for the F1 (non-calendar date)
  and F3 (hyphen adjacency) defect classes — both run both twins and assert verdict agreement.
- **F6 (pre-existing, found while verifying)** `_HookHarness.ps1` `Invoke-Hook` decoded child
  stdout with `[Console]::OutputEncoding`, so the em-dash summary-line assertions failed on any
  non-UTF-8 console (reproduced under ibm850) — v0.27.0's "hook suites green" was
  environment-dependent. The capture now pins UTF-8 and restores the prior encoding in
  `finally` — the harness-side leg of the v0.26.5 rendering fix.

Logged-not-fixed (locked design, revisit only on consumer evidence): the D6 injection-marker
list hard-FAILs benign prose descriptions containing `instead of` (observation in B-37).

## 0.27.0 (2026-07-16)

### Added — B-27 team wiki memory (WSD-010)
- New `docs/wiki/` per dist: `INDEX.md` (normative grammar, sorted by slug) + `_template.md`,
  a flat one-fact-per-file team wiki (gotcha/context/recipe/failed-approach) with frontmatter
  (`name`, `description`, `type`, `scope`, `status`, `last-verified`).
- `remember-for-team` skill (human-gated write path: triage/redirect, dedup-before-create, draft
  from template, sorted-insert into `INDEX.md`, honest "draft until PR review" close). Mirrored
  to `.github/skills/` for Copilot parity.
- `wiki-check.ps1/.sh` twins: structural validation (index↔file bijection, frontmatter schema,
  enum values, sort order) plus an injection screen — FAIL on INDEX-line/description-level
  matches, WARN (advisory only) on body-level matches. Wired into `docs-sync-check` (both twins).
- `session-start.ps1/.sh` preload the wiki index (inline when small, summarized above a size
  threshold, silent when absent), on both Claude Code and Copilot surfaces.
- `CLAUDE.md`/`AGENTS.md` companion-preamble line + Common Tasks/self-review pointers to the wiki.
- `install.ps1/.sh`: `docs/wiki/INDEX.md` is copy-if-absent (joins `$adoptionSignals`), everything
  else under `docs/wiki/` copies normally — a consumer's own wiki survives a framework update.
- `adopt.md` D7: `docs/wiki/**` is a **screen-in-place** candidate class — clean entries stay
  where they are (never archived/merged); flagged entries quarantine to
  `docs/pre-adoption/quarantine/` with their INDEX line intact, keeping `wiki-check` red until a
  human resolves them.

### Fixed (found during B-27 implementation review)
- `wiki-check.sh`'s injection-signal character class matched the INDEX grammar's own mandatory
  em-dash under real UTF-8 collation, failing every syntactically valid entry. Rewritten as
  `LC_ALL=C` byte-exact UTF-8 matching, mirroring the `.ps1` twin's codepoint ranges.
- `wiki-check.sh` failed to resolve a native Windows-style root path; now normalizes separators
  (and uses `cygpath` when available) before building `docs/wiki` paths.
- `install.ps1`'s D8 fix had diverged structurally from the `.sh` twin (a full per-file rewrite of
  the copy loop vs. the twin's surgical `docs/`-only special case) — restored to the same shape.
- The shipped `_template.md` carried a leading HTML comment that broke its own frontmatter
  contract the moment it was used literally; removed to match the locked design's D2 template.

## 0.26.5 (2026-07-15)

### Added — B-32 context-footprint gate (WSD-017)
- Added deterministic context measurement and a reviewed-baseline CI gate with advisory ceilings.
- Release automation re-measures the baseline after version stamping.

### Fixed
- Aligned PowerShell session-start and prompt-routing guidance with canonical bash rendering
  byte-for-byte. The new rendered-hook check exposed Unicode, blank-line, and whitespace drift.
- PowerShell hooks now emit UTF-8 whenever their output is captured, preventing Windows OEM
  output encoding from garbling the Unicode guidance.

## 0.26.4 — 2026-07-12

> **The gates that should have caught v0.26.3's defects.** Every gate this repo had was a *parser*
> gate — markers resolve, JSON parses, `bash -n`, PS-AST, twins agree, no meta vocabulary leaks. The
> product is prose aimed at a model, and **nothing tested whether the prose works.** Three defects
> walked straight through. Two of them were mechanically catchable and now are.
>
> Written before the cleanup, red-tested first, per `DEVELOPING.md`: *a gate you have never seen fail
> is not a gate.* Each one found a live defect on its first run.

### Added — `no-dead-instruction` (`validate-dist` check 7, both twins)
Every script a shipped doc tells someone to **run** must exist, resolved from the dist root.
Check 6 (`no-meta-leak`) proves shipped docs don't say the wrong *words*; nothing proved they don't
give the wrong *commands*.
**Found on first run:** a **second, un-noticed instance of the v0.26.3 defect** —
`dist/monorepo/README.md:137` (the update-mode section) still told consumers to run
`bash install.sh` / `pwsh install.ps1`, which do not exist in that dist. I fixed the §1 occurrence
this morning by hand and missed this one. The gate did not.

### Added — `InstallerContract.Tests.ps1` (meta suite)
Runs the **shipped installer for real** — 3 dists × greenfield/brownfield × `.ps1`/`.sh` = 12 installs
into temp targets — and asserts its **stdout** states the whole agent contract: commit the files;
your task is NOT complete until you hand off; do not hand-replicate `/bootstrap`|`/adopt`;
`docs-sync-check` is red **by design**. Asserted as *behavior*, not as prose in a source file — the
only way to catch a mode branch that quietly stops printing it, which is exactly what greenfield did.
Red-tested by regressing greenfield to its pre-v0.26.3 wording: fails on both twins, other dists stay
green.

### Added — `DocTruth.Tests.ps1` (meta suite)
The authoring docs must describe the repo that exists: one version stamp everywhere, README's claimed
version == what's shipped, no phantom marker syntax, every `scripts/…` path in a root doc resolves,
every script `ci.yml` invokes exists. Docs that lie to the *maintainer* are how the next defect gets
authored.
**Found on first run:** `CLAUDE.md:63` pointed at `scripts/template-checks.*` as if it were a root
script. It is per-dist (`dist/<stack>/scripts/`); no root one has ever existed. Flagged by the
adversarial review earlier today and still not fixed until a machine insisted.

### Fixed
- **`dist/monorepo/README.md:137`** — update-mode install command (see above). Shipped.
- **`CLAUDE.md:63`** — `template-checks` path now unambiguous.
- **Both new test files initially swallowed their own failures.** They ended with
  `Write-TestSummary`, not `exit (Write-TestSummary …)`, so the meta runner (which sums
  `$LASTEXITCODE`) saw 0 regardless. `DocTruth` reported *2 failed* while the suite reported *0
  failures* — a gate lying about itself, caught only because the numbers disagreed on screen. The
  established files had it right; the new ones didn't. Fixed and regression-tested: a planted failure
  now propagates to the suite exit code.

### Known blind spot (stated, not solved)
Whether the prose actually **steers a model** is still untested. That needs a real agent driven
end-to-end, which needs standing permission to spawn one non-interactively — a deliberate trade not
taken. The other two v0.26.3 defects (an installing agent mistaking this repo for its target; the
archived repos sending agents to install the frozen v0.25.5 template) were found *only* by driving
agents by hand, and no gate here would catch their like. Recorded in `DEVELOPING.md` so the next
maintainer doesn't mistake green gates for coverage.

## 0.26.3 — 2026-07-12

> Started as "did the merge drop the README's *For AI agents (LLMs)* section?" It did not — §1 is
> intact in all three dists and `git log -S` shows only additions. But the merge **moved the front
> door** (the legacy template repos → this authoring repo), and chasing that turned up a dead install
> command in `dist/monorepo` and an installer branch that under-instructs installing agents.
>
> **The diagnosis was baselined before anything was fixed**, and the baseline killed the original
> hypothesis — see `meta/LEARNINGS.md`.

### Fixed (shipped)
- **`dist/monorepo/README.md` §1 told installing agents to run a command that does not exist.** It
  said `pwsh install.ps1 <target>`; that dist contains only `scripts/install.ps1` (`dist/{dotnet,
  angular}` correctly said `scripts/install.ps1`). Root-installer wording had been copied into a dist
  README during Phase 4 monorepo authoring. Since the root README's blockquote routes readers straight
  into `dist/<stack>`, an agent following that trail hit `No such file or directory` — on the mixed
  .NET + Angular path, i.e. exactly the audience `dist/monorepo` exists for. Fixed in
  `src/stacks/monorepo/files/README.md`.
- **The greenfield branch of the shipped installer under-instructed AI agents relative to brownfield.**
  Brownfield printed a standalone *"IF YOU ARE AN AI AGENT … your task is NOT complete until you have
  done step 1 [commit] and then told the developer … Do not attempt /adopt yourself or replicate it by
  hand"* block. Greenfield printed only a weaker parenthetical: no "or replicate it by hand", and no
  warning that `docs-sync-check` fails **by design** until `/bootstrap` runs — so an agent would see
  red CI and try to fix it. Greenfield now prints the same contract, naming `/bootstrap`.
  Single-sourced in `src/core/scripts/install.{sh,ps1}` [#1], twins in lockstep [#3].
  **Observed, not theorised:** a baseline run (Opus 4.8, cwd = this repo, prompt *"install this
  framework into `<target>`"*) chose the right installer, detected greenfield, was **not** captured by
  this repo's maintainer `CLAUDE.md`, and correctly refused to run `/bootstrap` — but explicitly
  declined to **commit** the copied files in the target. Step 1 of the contract, silently dropped.

### Docs (authoring repo — not shipped)
- **`@@INCLUDE` was phantom syntax.** Documented in `README.md`, `CLAUDE.md`, `AGENTS.md` and
  `DEVELOPING.md`; implemented nowhere. The composer's marker is `<!-- @stack:NAME -->`
  (`scripts/build.ps1:6-7`). Corrected in all four. (The historical v0.26.0 entry below is left as
  written — it is a dated record, not live guidance.)
- **Root `README.md` had no acquisition step.** Every install instruction presumed a local clone the
  reader was never told to make (`grep -i clone README.md` → zero hits). `## Quick start` now opens
  with `git clone`.
- **`fidelity-check` was still described as a live CI gate** in `README.md` and `DEVELOPING.md`. It was
  retired from CI at v0.26.0 (`ci.yml:11-15`); it remains a manual re-audit tool. Corrected.
- Root `README.md` claimed shipped v0.26.1 against an actual stamp of v0.26.2.

### Not done (deliberately)
- **No rewrite of this repo's root `CLAUDE.md`/`AGENTS.md` banner.** The pre-fix hypothesis was that
  the always-loaded maintainer governance captures an installing agent and its unqualified *"commit to
  `master` and push"* would make it push to **this** repo. The baseline did not reproduce either. One
  sample (Opus 4.8, plan mode, .NET target) is not proof — but it is evidence against, and a prose
  change with no observed failure behind it is exactly what this repo's own record warns off.

## 0.26.2 — 2026-07-12

> Hotfix for a defect v0.26.1 introduced, plus the machine check that would have caught it.
> v0.26.1's CI went **red on the linux leg** — the two composers disagreed on
> `dist/{dotnet,angular}/.claude/hooks/post-write.sh`.

### Fixed
- **A lone `0xE2` byte in two `src/stacks/*/files/.claude/hooks/post-write.sh` files.** Introduced by
  a v0.26.1 `sed` whose character class contained an em-dash (`[-—]`). `sed` matches **bytewise**, so
  it stripped the em-dash's two continuation bytes (`80 94`) and left the lead byte stranded —
  invalid UTF-8. The two composers then disagreed by construction: `build.sh` copies the raw byte
  through, while `build.ps1` decodes and re-encodes it into `U+FFFD`. The committed dist matched
  whichever composer produced it, so the *other* CI leg failed the freshness diff. Comment text only;
  the hook's behavior was never affected.

### Added
- **A repo-wide valid-UTF-8 sweep in the meta test suite** (`WorkspaceBom.Tests.ps1`, alongside the
  BOM gate [#4]). Every file must decode under a **strict** UTF-8 decoder — one that throws rather
  than silently substituting `U+FFFD`, since a lenient decode would make the test vacuous. It carries
  a positive control that plants the exact byte sequence this release fixes. This closes a real hole:
  every local gate passed on v0.26.1, and **only** CI's cross-leg rebuild caught the divergence — a
  failure that surfaces far from its cause. It is now caught at the source, locally, before a push.

## 0.26.1 — 2026-07-12

> Seals the meta/product boundary. A sweep of the composed dists found **192 lines of maintainer
> vocabulary in shipped content** (81 dotnet / 83 angular / 28 monorepo), in two tiers. **22 lines
> genuinely installed into a consumer's repo:** tracking ids baked into live shipped hooks, scripts,
> and tests — including a pointer to the maintainer-only `release.ps1`, a script that does not exist
> in a consumer repo. **~170 lines product-visible but not installed:** almost all in the shipped
> changelogs, which were maintainer engineering logs (backlog ids, `WSD-nnn`, the "Fable-exit"
> codename, "lockstep with the .NET twin", links to the archived legacy repos, and a literal
> `_Maintainer-only (does not ship)_` note). The installer excludes `CHANGELOG.md` from the copy, so
> that tier never reached a working tree — but it is the surface a team reads when evaluating the
> framework. **The merge inherited this rather than causing it:** the legacy
> `ai-tech-lead-dotnet/CHANGELOG.md` carries the identical markers, and the v0.25.5 fidelity freeze
> copied them byte-for-byte. Full decision record: WSD-019.
>
> No behavior change — shipped *content* and repo layout only.

### Added
- **`no-meta-leak` — `validate-dist` check 6.** Scans each composed dist against the new
  `scripts/meta-denylist.txt` and fails if the framework's own development vocabulary appears in a
  shipped file. One denylist file, read by **both** the `.ps1` and `.sh` twins, so it cannot drift.
  It denies the *ID* forms (`B-nn`, `WSD-nnn`) rather than the words — `BACKLOG` and `twin` stay
  legal, because the product legitimately reads the consumer's own `BACKLOG.md` and the shipped
  `.ps1`/`.sh` twins are a real feature. The `ALLOW` list is consequently empty. CI already runs
  `validate-dist` per dist on both legs, so no workflow change was needed.

### Changed
- **The shipped changelogs are now written in the consumer's voice** — what changed in *their* repo
  and what they must do. Every version heading is preserved (37 / 38 / 2, unchanged); only the
  framing changed. Safe because the full engineering history is preserved verbatim in
  `meta/changelogs/legacy-*.md`.
- **Tracking ids stripped from shipped code comments** — `post-write.{ps1,sh}` (all three stacks),
  `template-checks.{ps1,sh}` (which also referenced the maintainer-only `release.ps1`),
  `build-architecture-html.ps1`, and four `tests/hooks/*.Tests.ps1`. Each comment now states the
  invariant the code holds rather than the ticket that produced it.
- **Stale pointers to the archived legacy repos removed** from the shipped `README.md`s and the
  monorepo changelog; the cross-stack advice now points at the monorepo distribution instead.
- **The maintainer layer moved to `meta/`** (`BACKLOG.md`, `workspace-decisions.md`, `LEARNINGS.md`,
  `ci-handover.md`, `changelogs/`), and **root `docs/` is gone** — that name belongs to the consumer
  (`dist/*/docs/`). `CLAUDE.md`/`AGENTS.md`/`.claude/` stay at the root because Claude Code loads
  them from there; their "you are in the authoring repo" banner remains the tie-breaker.

### Fixed
- **`validate-dist.ps1` resolved paths against the wrong root after check 5.** The dist's own
  `template-checks.ps1` does a `Set-Location` into the dist and never restores it, so any relative
  path used afterwards broke — on the PowerShell leg only, since the bash twin runs it in a subshell.
  Found by building the new gate before the cleanup. Paths are now resolved up front.

## 0.26.0 — 2026-07-12

> The single biggest structural change in the framework's history: two independently-versioned
> template repos (`ai-tech-lead-dotnet`, `ai-tech-lead-angular`) become one authoring repo,
> `ai-tech-lead`, that composes three installable distributions. The decision, rationale, and
> execution record live in `meta/workspace-decisions.md` (WSD-012 and its Phase 0–6 execution
> deltas, plus WSD-015, WSD-016, and WSD-018). Phase 6
> validation is green (real-toolchain install + `docs-sync-check` across all three dists, the
> monorepo security-overlay smoke, and the composer/validate/hook/meta gates — WSD-018); the two
> legacy repos are archived at this release with pointer READMEs, frozen at their last independent
> release, v0.25.5.

### Added
- **One authoring repo, three installable distributions.** Shared framework content — skills,
  commands, agents, hooks, `CLAUDE.md`/`AGENTS.md` templates, scripts — is now authored **once**
  under `src/`, and a deterministic composer emits `dist/dotnet`, `dist/angular`, and
  `dist/monorepo`, each a complete, installable, single-stack (or mixed-stack) copy of the
  framework. Composition is concat-by-default with authored overrides where stacks genuinely
  diverge (`@@INCLUDE` markers in `src/core`, per-stack snippets/whole-file overrides under
  `src/stacks/<stack>/`) and an explicit-collision-is-an-error rule for the monorepo dist — no
  silent last-wins when the same path exists in more than one stack (WSD-015).
- **`dist/monorepo` — a new distribution for mixed .NET + Angular repos.** Previously a consumer
  with both a .NET backend and an Angular frontend in one repo had no first-class option; this
  dist carries the union of both stacks' content, with 111 authored merged/sectioned snippets and
  38 authored whole-file overrides where union-by-default wasn't safe (WSD-015). 148 files total.
- **Root installers with stack auto-detection.** `install.ps1` / `install.sh` at the repo root
  are thin wrappers: they resolve the target's stack (explicit flag → an existing update stamp →
  auto-detection from `*.csproj`/`*.sln` vs `angular.json`, checked at the root and two levels
  down → both found routes to `dist/monorepo` → neither found exits with a clear ask for the
  flag) and then delegate to the chosen dist's own byte-frozen installer. No install logic is
  duplicated outside `dist/`.
- **Full git history preserved from both legacy repos.** The merge used `git filter-repo` to
  relocate each legacy repo's history under `legacy/{dotnet,angular}/` before merging with
  `--allow-unrelated-histories` (zero conflicts — the trees were disjoint at merge time); `git log
  --follow` on any long-lived file (e.g. `CLAUDE.md`) traces back through the merge to its
  original v4.0 commit in whichever legacy repo it came from.

### Changed
- **Zero shipped-behaviour change, proven by a strict fidelity gate.** Every one of the 138
  tracked files in each legacy repo (dotnet, Angular) reproduces byte-for-byte (EOL-normalized)
  from the new `src/` composition — `scripts/fidelity-check.ps1/.sh` diffs the rebuilt
  `dist/dotnet` and `dist/angular` against the `freeze-v0.25.5` tags taken on both legacy repos
  before any restructuring began, with an **empty allowlist** (no version-stamp or
  stack-flavoured exclusions needed). This is the migration's central acceptance criterion: a
  consumer already running v0.25.5 of either template gets an update, not a behavior change, when
  they eventually move to a dist built from this repo.
- **The workspace meta-development layer moved into this repo (D7, WSD-016).** The maintainer
  workflow for developing the framework itself — previously governed by a separate, untracked
  workspace root one level up — now lives here: root `CLAUDE.md`/`AGENTS.md`/`DEVELOPING.md`
  (rewritten for single-repo composition instead of dual-repo lockstep), the `bom-fix` hook +
  its meta test suite, `meta/BACKLOG.md` and `meta/workspace-decisions.md` (this repo's ADR
  log), and the maintainer's `.claude/plans/`. The two-repo-specific `check-lockstep.ps1` gate is
  retired — its job is now structural (one source, three composed dists) rather than a
  cross-repo diff.
- **Shipped CI workflows use `actions/checkout@v5`.** The `template-ci.yml` and
  `docs-sync-check.yml` workflows that install into consumer repos were bumped from
  `actions/checkout@v4` to `@v5` (GitHub's Node 20 runtime deprecation). This is the first
  release to deliberately change shipped content since the freeze, so it also retires the
  authoring repo's strict fidelity-check CI legs (dist == `freeze-v0.25.5`) — the freeze tags
  are no longer the baseline; `src/ → dist/` freshness (rebuild + diff) plus per-dist
  `validate-dist` and hook suites remain the CI guardrails.

### Notes
- Phase 6 (`MERGE-MIGRATION-PLAN.md`) validation completed green (WSD-018); the two legacy repos
  — `ai-tech-lead-dotnet` and `ai-tech-lead-angular` — are archived at this release with pointer
  READMEs directing consumers here. They remain readable, frozen at v0.25.5.
- Legacy framework history predating the merge: [`meta/changelogs/legacy-dotnet.md`](meta/changelogs/legacy-dotnet.md),
  [`meta/changelogs/legacy-angular.md`](meta/changelogs/legacy-angular.md).

---

## How to update this changelog

- One section per release (or per "Unreleased" working window). Date the heading once released.
- Group entries by **Added / Changed / Fixed / Removed / Decided**.
- One line per change. Reference the file or workflow touched, not the implementation detail.
- Framework-level decisions (the merge, composition rules, hook semantics) go in
  `meta/workspace-decisions.md`; this file is the consumer-facing summary of what shipped.
