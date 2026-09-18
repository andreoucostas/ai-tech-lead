# Framework review, 2026-09-18 — findings record

**Class:** records. **Filed against:** v0.86.7 (`0.87.0 — Unreleased` on master `ac10c538`).
**Decision record:** WSD-090. **Backlog:** stubs B-247 to B-266; existing B-237, B-240, B-244,
B-245, B-246 and B-42 are referenced, not duplicated.
**Method:** nine read-only area reviews delegated to cheaper models (seven Sonnet, two Haiku), then
synthesis in the main session. **[V]** marks a claim the synthesising session re-checked at the
source; unmarked claims are sub-agent findings judged credible but not re-checked (maintenance
model #3: attribute, do not promote). The Haiku changelog classification was discarded as unreliable
(it filed a retirement and a docs page as new capabilities); only its checkable facts are used.
Nothing in the tree was changed by the review. No gate suite was run.

## 1. The central finding

The maintainer process is much larger than the shipped product, and the rigor is aimed at gate
correctness rather than product efficacy.

| Product (ships) | Process (maintainer layer) |
|---|---|
| ~256 always-loaded lines (`CLAUDE.md` + imported rules carrier) | 44 meta-test files, 10,417 lines [V]; about a third test process or records |
| 14 commands, 7 agents, 12 .NET skills, 6 hooks | `release.ps1` 956 lines, six escape-hatch switches |
| | `.claude/evals/run-agent-evals.ps1` 3,556 lines [V], never run automatically |
| | 121 changelog releases since 2026-04-28; 41 of the last 60 commits touch no `src/` [V] |

- **Value evidence.** The only valid with/without-framework replay reads "direction no detectable
  difference … `+1/10` rubric delta is below the frozen `2/10` threshold"
  (`meta/field-study-results.md`, run `FS-20260826-RERUN-02`, maintainer) [V]; the earlier
  `FS-20260826-DRY-01` is recorded void. Zero independent pairs exist (B-42, filed v0.31.0).
- **Host certification.** `meta/host-certification.md`: every Claude Code hook capability row is
  "not certified — quota"; every Copilot VS Code row is "not certified — no seat" [V].
- **One properly powered positive result exists:** B-98 step 2, 6/6 vs 0/6 (Fisher p≈0.002) for a
  rule that made the agent read `docs/warehouse-map.md`. It fixed reach, not the downstream outcome.
- **The ceremony did not prevent its own target defect.** `release.ps1` captures `$releaseCommit`
  for the CI watch, then re-reads `HEAD` into `$releaseSha` and tags that; its closing message still
  says the tag is on the CI-verified commit [V]. This is B-237; it occurred at v0.86.5.

## 2. Needs improvement

1. **B-237** — tag the watched commit, not a re-read `HEAD`. Small change, critical class.
2. **Guard credential check (B-247).** `src/core/.claude/hooks/guard.ps1`: the generic
   credential-literal / connection-string check is skipped when the file path merely *contains*
   `test|spec|Development|example|sample|mock|fixture` [V] — `LatestRatesClient.cs`,
   `Specification.cs`, `Inspector.cs` are exempt. Vendor-token patterns (AWS, GitHub, Slack, `sk-`,
   Google, PEM) apply to all paths but include no Azure shapes (`AccountKey=`, SAS `sig=`) [V]. The
   guard sees only the current edit's new text, never the resulting file. Read WSD-046/WSD-047 first:
   bypasses are answered by kind; the substring exemption is a false negative, not a bypass.
3. **Unbounded build on write (B-248).** `post-write.ps1` runs a synchronous
   `dotnet build $target --no-restore` with no timeout [V]; the shipped `settings.windows.json` has
   no `timeout` field [V]. Per-hook `timeout` and `shell` keys exist on the host (B-241 plan, vendor
   docs fetched 2026-09-16).
4. **Hook process overhead.** Every registration spawns a PowerShell process: a five-write turn is
   roughly 17 cold starts (sub-agent estimate, not measured). `route-prompt.ps1` spawns on every
   prompt, including pure questions.
5. **Instruction text reads as disclaimers (B-255).** Examples in the always-loaded carrier: "Hook
   registration alone proves neither firing nor consumption", "Registered, observed, and instructed
   differ by surface", "A delivery profile proves no technology or command" [V] — true, not
   actionable by a consumer's agent. The frozen-bundle "CANNOT EXAMINE" paragraph appears 15 times
   across all six reviewer agents and both review commands [V]; "derive, don't assume .NET" repeats in
   five commands although Verification Rule #10 states it; the financial-domain hedge repeats in four
   files. Workflow rails are hand-mirrored in `CLAUDE.md`, `AGENTS.md` and `route-prompt.ps1`, policed
   by `/docs-sync`.
6. **Installer (B-259; B-244; B-240).** Updates overwrite consumer edits to framework-owned files
   behind a printed warning; `-WhatIf` skips the dirty-tree guard (`docs/upgrade-checklist.md`);
   conflict output is unstructured text; the Quick Start installs `master`. The happy-path copy is a
   small fraction of the ~1,200-line installer; the rest is accreted reconciliation (retired twins,
   legacy hook hashes, licence migration on one hardcoded SHA-256).
7. **Consumer README (B-262).** Section 1 is addressed to LLMs; the human value proposition starts
   at section 2 [V]. Host caveats repeat three to four times. No installed-file tree, no uninstall
   guide; the FAQ sits in an unlinked `docs/presentation/TALKING-POINTS.md`. No single "which register
   does this go in" table (TECH_DEBT / SECURITY_FINDINGS / ADR / wiki / hazards / LEARNINGS).
8. **`meta/BACKLOG.md` (B-264).** Open entries are dominated by hour-by-hour CP1/RK1 campaign
   accounting that `meta/field-study-results.md` and the plans already hold.
9. **Monorepo sibling drift (WSD-015).** Caught late by `validate-dist` `marker-expansion`, not at
   composition; missed by three adversarial reviews in B-239. No stub filed: observe under B-264.

## 3. Remove

- **`/impact` (B-250)** — a retired experiment's shell under a name that suggests blast-radius
  analysis [V].
- **Orphaned `.sh` snippet directories (B-249)** — 19 files in five directories under
  `src/stacks/*/snippets/.claude/hooks/{audit-trail,route-prompt}.sh/`; `scripts/build.ps1` never
  references `.sh` [V]. Left from the v0.83 Bash retirement (WSD-073).
- **`scripts/fidelity-check.ps1` + `FidelityCheck.Tests.ps1` (B-251)** — audit tool for a finished
  migration.
- **Presentation deck copied into every consumer repo (B-252)** — 97 KB across four files in
  `docs/presentation/` [V]. Link instead.
- **Warehouse skills as default-listed (B-256)** — `map-warehouse` (305 lines) and
  `add-warehouse-load` (172) are the two largest .NET skills and appear in every .NET `CLAUDE.md`.
  WSD-021 forbids a separate warehouse distribution; an evidence-selected listing inside the dist
  does not.
- **Copilot VS Code "supported" claim (B-263)** — never observed; every hook carries shape-detection
  branching for it.
- **Process candidates (B-264)** — `GateBudgetConsistency.Tests.ps1` (a test of a config that exists
  to police a gate); the eval scenario marked "SATURATED" in its own file (`scenarios.json`).

## 4. Missing

- A **scheduled, non-gating with/without-framework behavioural eval** on the existing harness
  (B-253). WSD-016 stands (evals are not a release gate); B-98 stands (reuse the B-41 harness).
- **Stop-time verification** (B-261): nothing runs build or tests before the agent presents work as
  done; the product's verification promise rests on self-report. WSD-024 keeps the Copilot Boy Scout
  nudge advisory; this is a separate Claude Code control.
- **Lifecycle basics** (B-259): uninstall/rollback, a real update check (today: a weekly offline
  nudge linking to the releases page [V]; the version stamp's `_comment` still promises a "future
  /framework-update command" [V]), structured installer output.
- **Workflows** (B-265): PR description, read-only explain-this-codebase, major-version upgrade,
  Angular perf/accessibility parity with .NET `perf`.
- **Independent users** — B-42. Needs a demo repo, a ten-minute start and an uninstall path first.
- **Static analysis** (B-266): no PSScriptAnalyzer leg; the only lint is the AST parse check.

## 5. High-impact changes, with the approaches weighed

1. **Aim the rigor at efficacy (B-253, B-254).** Three to five existing typed-event scenarios, with
   and without the framework, n≥6, budget-capped, reported per release candidate. First use: ablate
   always-loaded rules; a component with no measurable effect is a removal candidate.
2. **Distribution re-audit (B-258).**
   - *A — plugin first.* Claude surface (skills, agents, hooks, commands) as a Claude Code plugin via
     a team marketplace. Gains: native versioning, update, uninstall; no settings merge; most
     retirement logic goes. Costs: files leave the consumer's tree (today's README argues they must
     be committed); Copilot files still need the installer; locked-down shops need an internal
     marketplace; re-audits WSD-012/WSD-043.
   - *B — keep file-copy, make it boring.* Manifest-only copy/delete, no special cases, `-Uninstall`,
     JSON output, tag-pinned install. Gains: both surfaces, offline, corporate-friendly. Costs: the
     brownfield and settings merge stay owned here.
   - Recommendation: do B's cheap parts regardless (B-244, B-259); spike A for one to two days before
     deciding.
3. **Commands → skills; retire regex routing; path-scoped rules (B-257).** B-98 already records "no
   always-on router or no-match hook" as the direction. Removes a per-prompt spawn and the
   three-way rails mirror. `.claude/rules/*.md` with `paths:` could load C#-specific rules only when
   `.cs` files are touched — but WSD-045 already judged scoped instructions to buy locality, not
   coverage, and WSD-089 rejected them for the root layer; the investigation must answer that.
4. **Process diet (B-264, B-245).** Weekly release batches; CI as the only full-suite run; the
   "adding a clause means retiring one" rule extended to meta test files.

Platform facts behind items 2–3 come from the docs-research sub-agent (vendor docs, not re-checked
here): plugin contents and `enabledPlugins`/`extraKnownMarketplaces`; hook `"shell":"powershell"`,
600 s default command-hook timeout, events `SubagentStop`/`PostToolUseFailure`/`PreCompact`/
`InstructionsLoaded`; `claude plugin eval`; Copilot reading `AGENTS.md` and `.claude/skills`
natively; the Copilot cloud agent ignoring `powershell` hook entries. Unconfirmed: whether the
built-in `/security-review` shadows the shipped command of the same name (B-260).

## 6. Recommended order

1. Known defects: B-237, B-247, B-248, B-244; deletions B-249, B-250, B-251.
2. Evidence loop: B-254 (user decision), then B-253; publish the first result whatever it shows.
3. Instruction text: B-255, measured by step 2.
4. B-260 observation, B-257 and B-258 investigations → WSDs.
5. Adoption: B-262, B-259, then B-42.

Recommended pause until step 2 reports (not yet decided by the user — B-254): B-222 to B-225
expansion, Copilot VS Code investment, new meta gates.
