# Forensic evaluation of the AI Tech Lead framework + remediation plan

## Context

The user asked for a brutal, top-to-bottom forensic evaluation of the framework (both template
repos at v0.23.2 + the workspace meta layer), including things they should have asked but didn't,
followed by a remediation plan. Three parallel audits (dotnet repo, angular repo + cross-repo
parity, meta layer) were run and every load-bearing claim was re-verified by hand.

**User decisions taken during planning:** (1) remediate in the dual-repo world now — do not wait
for the monorepo merge; (2) `git init` the workspace root so the meta layer is versioned.

---

## Part 1 — Evaluation (ranked)

### A. Systemic — the framework does not practice what it preaches

**A1. Zero effective CI on the framework's own repos.** The only workflow in either repo is
`.github/workflows/docs-sync-check.yml`, and `scripts/docs-sync-check.ps1/.sh` **early-exits when
`.template-repo` is present** (docs-sync-check.ps1:10–13). So in the template repos, CI checks
nothing. The hook test suite (`tests/hooks/Invoke-HookTests.ps1`), PS-syntax parse, BOM check,
twin-parity check, and version-stamp sync are wired into **nothing** — they run only if someone
remembers the DEVELOPING.md recipes. Both repos are on GitHub (`github.com/andreoucostas/...`),
so Actions is available; this is an unforced error. The framework's whole thesis is
"deterministic backstops because instruction-following can't be trusted" — and its own repos have
none.

**A2. `docs-sync-check` is weaker than its billing.** Root CLAUDE.md calls it "the gate that
catches drift" (invariant #2). In reality its AGENTS.md check (docs-sync-check.ps1:43–54) only
asserts a banner and 4 headings *exist* — it never compares content. It catches **absence, not
drift**. It also never checks the CLAUDE.md version stamp against `framework-version.json`.

**A3. The drift the gates should have caught has already happened — in both repos:**
- `CLAUDE.md` header stamp says **0.23.0 / 2026-06-25**; `framework-version.json` says
  **0.23.2 / 2026-06-29** — in *both* repos, despite the json's own comment mandating sync.
  The DEVELOPING.md release recipe (step 1) bumps the json but never mentions the CLAUDE.md stamp.
- `AGENTS.md` Agentic Workflow §1 is **paraphrased, not verbatim** (examples dropped, "Honour
  Leanness:" removed, rails blockquote condensed, security paragraph reworded). The framework's
  own `/docs-sync` (docs-sync.md:31) calls this "a hard drift finding, not a cosmetic one" —
  §1 is the *only* routing surface Copilot has.
- `.github/copilot-instructions.md` is **missing in both repos** while AGENTS.md's Quick
  Reference links to it (dead link in a shipped artifact) and consumer docs-sync-check #3
  requires it.
- Only a deterministic gate would have caught these; the verbatim mandate is enforced solely by a
  model reading an instruction — the exact failure mode the framework exists to prevent.

**A4. `guard.sh` overclaims fail-closed.** Header (guard.sh:12–13) says high-confidence secret
patterns "FAIL CLOSED", but when neither `jq` nor `python3` is available it exits 0 at line 52
("degrade safe") — **everything passes, secrets included, silently**. On a minimal Linux box the
security write-floor is a no-op and nobody is told. The claim and the behavior contradict.

**A5. The eval suite is dormant.** `tests/evals/` (run_evals.py + cases.yaml) is well-designed —
deterministic regex + Haiku rubric per rule — and its README says "run quarterly, after framework
version bumps." There is **no evidence it has ever gated a release**: no results recorded
anywhere, no CI wiring, not mentioned in README.md. The only instrument that measures whether the
rules actually change model behavior is switched off.

**A6. The meta layer violates its own invariants.**
- `bom-fix.ps1` has **no `.sh` twin** — direct violation of invariant #3, in the layer that
  defines it.
- `.claude/plans/` is referenced (root CLAUDE.md Conventions, DEVELOPING.md:15) but **does not
  exist**; no plan has ever been persisted there despite "persist the plan to .claude/plans/".
- `docs/workspace-decisions.md` and root `LEARNINGS.md` were never created — multiple versions
  of decisions (v0.21–v0.23) have shipped since those conventions were written, so "create on
  first entry" has demonstrably been skipped, not merely not-yet-triggered.
- Root `settings.local.json` is a 9.2K accreted 87-entry permission transcript, not curated config.

### B. Defects (concrete, shippable fixes)

- **B1.** `docs/architecture-decisions.md` referenced by CLAUDE.md:114 but missing (dead link
  until first `/create-adr` run). Both repos.
- **B2.** AGENTS.md:143 says "The **seven** workflows" while CLAUDE.md §1 lists **six** bullets
  (Security pass is a cross-cutting rule, not a listed workflow; `route-prompt` classifies 7).
  Internal contradiction in the canonical routing text.
- **B3.** No LICENSE file in either repo that "ships to consumers."
- **B4.** `audit-trail` hook is dotnet-only, rationalized as ".NET-specific" — an AI-audit log is
  stack-agnostic. Angular consumers get no audit trail; dotnet CLAUDE.md promises one. Merge-plan
  D3 already concedes it should be unified. In the dual-repo world this is a standing invariant-#1
  violation tolerated by documentation.
- **B5.** MERGE-MIGRATION-PLAN.md is stale (D2 recommends first merged version "v0.19.0"; repos
  at 0.23.2; Phase 0 checkboxes all unchecked). `project_framework_architecture.md` (root) is
  orphaned — referenced nowhere, describes v0.8.0-era state.

### C. Things you didn't ask but should have (design-level)

- **C1. Release integrity is pure manual discipline.** A 7-step human checklist (DEVELOPING.md
  Release process) with no automation, for a framework whose premise is that manual discipline
  fails. The stamp drift in A3 is the proof.
- **C2. Non-Windows Claude Code consumers get dead hooks.** `settings.json` wires every hook via
  `pwsh`; the installer's fallback (`settings.windows.json`) is *also* PowerShell. The `.sh`
  twins are wired only for Copilot (`.github/hooks/hooks.json`). A macOS/Linux Claude Code user
  without pwsh gets silently failing hooks. Acceptable for a Windows/Bitbucket-DC audience, but
  undocumented.
- **C3. §1 is loaded up to three times per prompt** on Claude Code: CLAUDE.md (every turn) +
  session-start preload + route-prompt rails injection. Deliberate ("bound salience copy") but
  the token cost is unmeasured and unbudgeted (the 400-line CLAUDE.md budget is advisory-only).
- **C4. Consumer update path is aspirational.** framework-version.json's comment references a
  "future /framework-update command"; consumers must re-clone the template and re-run the
  installer, and nothing in consumer CI detects that they're N versions behind.
- **C5. route-prompt classification is keyword-grep.** Misclassification silently applies the
  wrong rails; there's no confidence fallback. Low priority, but it's the front door of the
  routing story.
- **C6. Whether `tests/` ships to consumers is unverified.** If the installer copies
  `tests/evals/` (needs ANTHROPIC_API_KEY) into consumer repos, that's wrong; if it copies
  nothing, consumers get hooks with no tests. Needs a look at install.ps1's copy list.

### D. What is genuinely solid (for calibration)

Shipped-hook twin parity is real and tested (TwinParity.Tests.ps1 caught the historic guard.sh
gap); dual-repo lockstep held across ~10 recent commit pairs with zero copy-paste residue;
guard.sh's multi-surface JSON superset is correct and was verified end-to-end; the dependency-free
hook harness is a good corporate-constraints call; `docs/enforcement-surfaces.md` is honest about
guaranteed-vs-instructed. The failures above are concentrated in **self-application**, not in the
shipped artifact's core design.

---

## Part 2 — Remediation plan

All shared changes land in **both repos in lockstep** (invariant #1); every `.ps1` change has its
`.sh` twin (#3); AGENTS.md regenerated after CLAUDE.md edits (#2); CHANGELOG + version bump per
release (#7). Version numbers: Phase 0 ships as **0.23.3**; Phases 1–2 ship as the next minor
(0.24.0 is soft-reserved for the testing-diagnostics workstream — if kept reserved, use 0.25.0;
maintainer's call at implementation).

### Phase 0 — Correctness fixes (both repos, one release: 0.23.3)

1. **Version stamps**: set CLAUDE.md header to current version/date in both repos. Add the
   CLAUDE.md stamp to DEVELOPING.md release step 1 (until Phase 1 automates it).
2. **AGENTS.md §1 verbatim**: regenerate per `.claude/commands/generate-copilot.md` so §1 is a
   true verbatim copy of CLAUDE.md §1. Fix "seven workflows" → match reality (six + the
   cross-cutting security pass), in whichever file is wrong after reconciling with
   `route-prompt`'s 7-way classification.
3. **Generate `.github/copilot-instructions.md`** (≤80 lines) in both repos — kills the dead link
   and satisfies consumer check #3.
4. **Seed `docs/architecture-decisions.md`** (empty ADR log with header) in both repos.
5. **`guard.sh` honesty fix**: on the no-parser path, emit a one-line stderr warning
   ("guard inactive: no jq/python3 — secret/test-defeat floor is OFF") before exit 0, and correct
   the header comment (fails closed *only when a parser is present*). Mirror the doc fix into
   `docs/enforcement-surfaces.md`. (Blocking outright would brick boxes without jq — warn, don't
   block.)
6. CHANGELOG entries in both repos; run the full DEVELOPING.md verification battery; commit +
   push both.

### Phase 1 — Deterministic self-enforcement (the core fix)

1. **Template-repo CI** — new `.github/workflows/template-ci.yml` in both repos running on
   push/PR: `Invoke-HookTests.ps1` (pwsh is preinstalled on GitHub runners; ubuntu leg exercises
   the `.sh` twins), PS-syntax parse, BOM check, twin-existence check.
2. **New deterministic checks** added to a `scripts/template-checks.ps1/.sh` pair (run by the CI
   above and locally):
   - version-stamp triple-sync: CLAUDE.md header == framework-version.json == newest CHANGELOG
     heading;
   - **§1 verbatim diff**: extract Agentic-Workflow §1 from CLAUDE.md and AGENTS.md, normalize
     whitespace, byte-compare — fail on mismatch (turns the /docs-sync "hard drift finding" into
     a machine check);
   - copilot-instructions.md exists and ≤80 lines.
3. **Consumer-side hardening**: add the version-stamp sync check to `docs-sync-check.ps1/.sh`
   (runs for consumers; keep the `.template-repo` skip for the *consumer-state* checks only —
   restructure so template-relevant checks run everywhere).
4. **Cross-repo lockstep check** (meta layer): `\.claude\scripts\check-lockstep.ps1` — hash-compare
   the shared files between the two repos (shared hooks, commands, agents, scripts,
   docs-sync-check), compare CHANGELOG head versions; list intentional divergences
   (stack-specific skills, audit-trail until B4 lands) in a small manifest so the check is exact.
5. **Release automation** (meta layer): `.claude\scripts\release.ps1 <version> <summary>` — bumps
   json + CLAUDE.md stamp in both repos, verifies CHANGELOG entries exist, runs
   template-checks + hook suites + lockstep check, refuses to complete on any failure, then
   commits + pushes both repos. Replaces the manual 7-step list; DEVELOPING.md updated to point
   at it.

### Phase 2 — Meta-layer compliance (workspace root)

1. `git init` the root; `.gitignore` excludes `ai-tech-lead-dotnet/`, `ai-tech-lead-angular/`,
   `presentation/`, `.claude/settings.local.json`, `.claude/scheduled_tasks.lock`. First commit =
   current governance files. (User-approved.)
2. Write `bom-fix.sh` twin (+ add it to the root hook test suite `MetaHooks.Tests.ps1`), closing
   the invariant-#3 breach.
3. Create `.claude/plans/` and persist this plan there; create `docs/workspace-decisions.md` with
   first entries (dual-repo-now vs merge; root git init; guard warn-don't-block); create root
   `LEARNINGS.md` with the meta-lesson ("a gate that skips the template repo protects nothing").
4. Housekeeping: prune `settings.local.json` to a curated allowlist; add a STALE/status banner to
   `MERGE-MIGRATION-PLAN.md` (and correct D2's version reference); either delete
   `project_framework_architecture.md` or fold its still-true content into
   workspace-decisions.md and delete the rest.

### Phase 3 — Follow-on workstream (tracked, not executed in this task)

- **B4**: port `audit-trail.ps1/.sh` to the Angular repo (+ settings wiring + tests) — pulls
  merge-plan D3 forward; removes the standing lockstep exception.
- **A5**: make evals a release gate — `release.ps1` prompts to run `run_evals.py` (API cost →
  keep human-triggered), results appended to `docs/eval-results.md` per version.
- **B3**: LICENSE decision (recommend adding one, even a proprietary/internal notice) — user call.
- **C2**: document the pwsh requirement for non-Windows Claude Code consumers in both READMEs.
- **C6**: verify whether `install.ps1/.sh` copies `tests/`; exclude `tests/evals/` from consumer
  installs if it does.
- **C5** (route-prompt keyword brittleness) and **C3** (token triple-load measurement): log to
  root LEARNINGS/TECH-DEBT as accepted-for-now.

### Critical files

- Both repos: `CLAUDE.md`, `AGENTS.md`, `.github/copilot-instructions.md` (new),
  `docs/architecture-decisions.md` (new), `.claude/hooks/guard.sh`,
  `scripts/docs-sync-check.ps1/.sh`, `scripts/template-checks.ps1/.sh` (new),
  `.github/workflows/template-ci.yml` (new), `CHANGELOG.md`, `.claude/framework-version.json`,
  `docs/enforcement-surfaces.md`.
- Meta layer: `.claude/hooks/bom-fix.sh` (new), `.claude/hooks/tests/MetaHooks.Tests.ps1`,
  `.claude/scripts/check-lockstep.ps1` + `release.ps1` (new), `DEVELOPING.md`, root `CLAUDE.md`/
  `AGENTS.md`, `docs/workspace-decisions.md` (new), `LEARNINGS.md` (new), `.gitignore` (new).
- Reuse: the existing `_HookHarness.ps1` pattern for new hook tests; docs-sync-check's existing
  SHA1 skills-mirror comparison (docs-sync-check.ps1:80–91) as the model for the §1 diff and
  lockstep hash checks.

### Verification (evidence-based, per DEVELOPING.md)

1. Run both repos' `tests/hooks/Invoke-HookTests.ps1` + root meta suite → exit 0.
2. Run new `template-checks.ps1` in both repos → all green, including §1 verbatim diff and stamp
   triple-sync (deliberately break a stamp → confirm it fails, then fix — "seen to fail").
3. `check-lockstep.ps1` → green with only manifest-listed divergences.
4. PS-syntax parse + BOM sweep + twin-existence sweep → clean.
5. Greenfield + brownfield install smoke into temp dirs → expected layout, no maintainer files
   leaked (don't-ship boundary #6).
6. Push both repos → confirm `template-ci.yml` runs green on GitHub Actions (the first time the
   framework's invariants are machine-enforced).
7. Root repo: `git log` shows the meta layer's first tracked history.
