# B-36 design — Testing strategy: suite bootstrap + per-item strategy rail (LOCKED 2026-07-15, WSD-020)

> **Status: DESIGN LOCKED.** Implement as specified; deviations need a new WSD entry.
> Trigger: maintainer question (2026-07-15) — does the framework guide the agent to choose the
> right testing strategy per dev item, extend the suite, and *build* a suite when none exists?
> Implementer: read root `CLAUDE.md` (meta-invariants #1–#7) and `DEVELOPING.md` first.
> Ship via `.claude/scripts/release.ps1` [#7].

---

## 1. Audit — what already exists (verified 2026-07-15, v0.26.4; do NOT rebuild these)

The framework's per-item testing coverage is **substantially present**:

- **Per-workflow rails** (`src/stacks/*/snippets/CLAUDE.md/workflow-bullets`, all three stacks):
  Feature = "design check first (… test strategy)"; Bug fix = failing regression test *before*
  production code, red-for-the-right-reason; Refactor = characterization tests first if
  untested; Test workflow = behavior-first, red-before-green, no over-mocking.
- **Test shape heuristic** (`docs/defaults.md` all stacks): level-selection doctrine ("lowest
  level that still runs real behavior"), anti-inverted-pyramid, determinism/hermeticity rules.
- **`add-tests` skill** (dotnet/angular/monorepo): level decision (unit vs WebApplicationFactory
  integration), behavior-not-implementation, red-check, plus a full **Characterization mode**.
- **Test leanness #11–16** (CLAUDE.md, always loaded) + **`test-critic` agent** (review-time).
- **Bootstrap A5/A6**: detects test projects, framework, coverage gaps, fixture patterns.
- **Meta-framework side: no gap.** The authoring repo's "Definition of done per artifact type"
  (root CLAUDE.md) already defines evidence-based verification per artifact class (fixture-driven
  hook proof, install smokes, red-testing gates) — that *is* its testing strategy; hooks have a
  dedicated dependency-free harness. Nothing to do there.

## 2. The gaps (what this item actually adds)

- **G1 — Zero-test repos have no path.** `add-tests` Step 1 is "find the existing pattern
  first" (Grep a sibling test to mirror). In a repo with **no test project/specs at all** —
  precisely the brownfield adoption audience — there is nothing to mirror and no recipe covers:
  choosing the framework, creating the first test project(s) and shared fixtures, wiring them
  into build/CI, and deciding *what to test first*. Bootstrap A5 will report the absence as
  debt, but nothing converts that report into a suite. The Refactor rail's "write
  characterization tests first" is silently unexecutable without infrastructure to write them in.
- **G2 — The Feature rail says "test strategy" without pointing at the decision procedure.**
  The decision logic exists (Test shape heuristic + add-tests Step 2) but the rail doesn't
  reference it, so per-item strategy is left to agent improvisation exactly where the rail is
  the only thing loaded.
- **G3 — Suite-level strategy isn't a first-class bootstrap output.** 3a populates
  `Conventions > Testing` with observed reality, but never requires (a) a stated *target test
  shape* for this repo, or (b) an explicit plan when observed = "no tests".

## 3. Approaches weighed

- **A. Extend existing artifacts (CHOSEN):** a "Suite bootstrap mode" inside `add-tests`
  (mirroring its existing Characterization mode), one-line rail pointer, one bootstrap output
  requirement. Zero new skills/commands; minimal always-loaded token delta (B-32 discipline).
- **B. New `bootstrap-tests` skill/command.** Rejected: duplicates add-tests' doctrine
  (leanness #13, parallel-infrastructure rule would be violated by our own framework); another
  trigger surface to route correctly; more shipped tokens.
- **C. Push it all into `/bootstrap`.** Rejected: bootstrap is a one-time analysis pipeline,
  already long; suite creation is a *dev task* the team schedules, needs the interactive
  framework-choice checkpoint, and must be re-runnable later. Bootstrap should *detect and
  route*, not build.

## 4. Locked design

### D1 — `add-tests` gains **Suite bootstrap mode** (all three stacks [#1])
New section after Characterization mode, symmetric with it. Entry condition in Step 1: "If
Grep finds **no test project / no spec files at all**, switch to Suite bootstrap mode." Mode
content (stack-appropriate wording per dist):

1. **Confirm the stack with the developer before scaffolding** (one message): test framework
   (default: repo's `Conventions > Testing`; unbootstrapped default: xUnit + NSubstitute /
   the Angular workspace's configured builder — Jasmine/Karma or Jest, detect from
   `angular.json`), and where test projects live. This is a real checkpoint — a wrong framework
   choice is expensive to unwind.
2. **Scaffold the minimum, not a taxonomy**: one unit-test project referencing the primary
   domain/application project (+ `dotnet sln add`; Angular: specs colocate, ensure `ng test`
   runs) and — only if the repo exposes an HTTP surface — one integration fixture
   (`WebApplicationFactory<Program>` subclass; note the `public partial class Program` or
   `InternalsVisibleTo` requirement for minimal APIs). No E2E project, no coverage tooling,
   no extra layers on day one (Leanness #1).
3. **Wire it so it cannot rot**: ensure `dotnet test` / `ng test --watch=false` runs the new
   project(s) in the repo's CI (point at `docs/ci-integration.md`; if the repo has no CI, flag
   it and reference the `enforce-standards` skill rather than building CI here).
4. **First tests are risk-first, not coverage-first** — order: (1) `FRAMEWORK-CONTEXT.md >
   Known Hazard Areas` rows, (2) financial-domain invariants if present (reuse the skill's
   existing step 4), (3) the critical journeys named in `CLAUDE.md > Codebase Context`, (4)
   pure domain logic with branching. Write a handful that prove the harness works end-to-end;
   every test still obeys the red-check (existing step 6).
5. **Record the remainder honestly**: one `TECH_DEBT.md` entry ("Test suite bootstrapped
   <date>; backfill areas: …") instead of pretending coverage. Update `CLAUDE.md >
   Conventions > Testing` with the now-real conventions (framework, naming, fixture location)
   and flag the doc-drift per Agentic Workflow §6.

### D2 — Feature rail points at the decision procedure (all three stacks [#1])
In `workflow-bullets` Feature line, expand "(… failure modes, test strategy)" to
"(… failure modes, test strategy — pick levels per `Conventions > Testing` / the Test shape
heuristic, and say which levels this change needs and why; if the needed level has no
infrastructure yet, flag it — `add-tests` suite-bootstrap mode)". Keep it a parenthetical —
rails are the always-loaded surface, budget applies (B-32). Mirror wording across the three
stacks; monorepo = same line.

### D3 — Bootstrap makes suite state a first-class output (dotnet + angular + monorepo)
- **A5 (dotnet/monorepo) / A6 (angular)**: add "If no test projects/specs exist, state that as
  the pass's primary finding — do not silently return 'coverage gaps'."
- **Phase 3a Conventions bullet**: `Conventions > Testing` must end with a one-line **target
  test shape** for this repo (unit-dense / honeycomb / etc., per the defaults.md heuristic
  adapted to what A1–A6 found), so per-item decisions (D2) have a repo-specific anchor.
- **Phase 3b**: when no tests exist, write a single Severity-High `TECH_DEBT.md` entry that
  names `add-tests` suite-bootstrap mode as the fix, and surface it in the Phase 4 report's
  top-3 quick wins.

### D4 — defaults.md Testing section: one routing line (all stacks)
Add to `### Testing`: "No test suite yet? Use the `add-tests` skill — its suite-bootstrap mode
scaffolds the harness and first risk-first tests." (One line; defaults.md is cold-start-only.)

## 5. Out of scope (explicit)

- Coverage thresholds / coverage-as-diagnostic and mutation testing — deferred by earlier
  decision (see memory: v0.22.0 lean test-integrity core; do not resurrect here).
- E2E tooling selection (Playwright etc.) — suite-bootstrap stops at unit + integration; E2E
  is a per-repo decision the developer schedules.
- No new agents/commands; `test-critic` unchanged.
- No changes to the meta-framework's own testing (§1 — already adequate).

## 6. Acceptance criteria

1. Install-smoke a dist into a temp dir; in a zero-test fixture repo, `add-tests` text routes
   to Suite bootstrap mode (read the rendered SKILL.md in all three dists — `dist/monorepo`
   must carry the union wording [#1]).
2. Feature rail in all three dists carries the D2 pointer; `validate-dist` ×3 green (mirror
   parity [#2] covers AGENTS.md propagation).
3. Bootstrap.md in all three dists carries D3; grep the composed dists for the new strings.
4. Standard gates: `build.ps1` ×3 + freshness, `validate-dist` ×3, hook suites unaffected.
   Version bump + changelogs (shipped changelog in consumer voice: "the framework now covers
   repos with no test suite: add-tests gains a suite-bootstrap mode; /bootstrap reports suite
   absence and your target test shape") [#7].

## 7. Effort / invariants

**M** (one session; mostly Markdown across 3 stacks × siblings). Invariants: #1 (siblings for
every snippet/skill touched), #2 (rebuild regenerates mirrors), #6 (consumer-voice text only),
#7 (release.ps1). Independent of B-35 — can ship in the same release or separately; both are
pre-B-27 candidates. No hook/script changes → #3/#5 untouched.
