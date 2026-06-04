Analyse this Angular codebase and set up the AI Tech Lead framework. This is the one-time bootstrap that makes the repo AI-ready.

## Input
$ARGUMENTS

Execute all phases below in sequence. Do not skip any phase. Do not ask for confirmation between phases — run the full pipeline.

---

## Pre-flight checks

Before starting analysis:
1. **Locate the project root** — find `angular.json`. If not found, check for `nx.json` or `project.json` (Nx workspace). All paths are relative to this root. If it's a monorepo (e.g., `apps/` structure), note which apps/libs exist and adjust paths in generated output.
2. **Check Angular version** — read `package.json` for `@angular/core` version. Note whether it's 17+ (standalone default, signals, new control flow) or older. Adjust conventions accordingly.
3. **Check for existing configuration** — if `CLAUDE.md` already has populated content (not just template defaults), back up the existing conventions section and merge your findings with what's already there rather than overwriting. Never touch `LEARNINGS.md` — it is append-only.
4. **Large codebases** — if the project has more than 200 components, focus analysis on the most actively changed areas (check git log). Note which areas were analysed and which were skipped.
5. **Mixed-stack detection** — count `.cs` / `.csproj` / `.sln` files outside `node_modules/` and `dist/`. If a `.sln` exists or more than ~50 `.cs` source files exist, flag this as a mixed-stack repo. After Phase 3 generation, add a note in the final report recommending the user create `.github/instructions/<stack>.instructions.md` with `applyTo:` frontmatter (see README "Mixed-stack repos" section). Do not auto-generate the secondary-stack instructions file — the user picks the rules.

---

## Phase 1 — Analysis

Dispatch the six analysis passes (A1–A6) **in parallel** via the `Task` tool, each invoking the `bootstrap-pass` subagent with the pass id as input. Example call shape:

```
Task(subagent_type="bootstrap-pass", description="Bootstrap pass A1", prompt="Run pass A1.")
```

Send all six Task calls in a single message so they execute concurrently. Wait for all six to return.

Each subagent returns structured findings; you do **not** redo the analysis. Just collect the six results — they feed Phase 2.

The pass definitions below are the source of truth the subagents read. Do not duplicate the pass logic inline; the subagents read this file directly.

### A1: Module Architecture & Lazy Loading
- NgModules vs standalone — split, consistency
- Lazy vs eager routes — eager justifications
- Barrel files (`index.ts`) — usage, circular-dep risk
- Shared/core module boundaries — clarity
- Routing — flat/nested, guards, resolvers
- Module-level circular dependencies

### A2: State Management
- Approach — NgRx / NGXS / Akita / BehaviorSubjects / signals / mix
- Local vs shared state — boundary clarity
- Informal stores — services-with-BehaviorSubjects pattern
- Prop drilling — through how many levels
- Server state — caching, staleness, loading/error
- NgRx/similar — actions/reducers/effects/selectors structure or over-engineered

### A3: Component Design
- Smart vs dumb — applied, consistent
- OnPush coverage — gaps
- Template complexity — heavy logic, deep nesting, complex expressions
- God components
- `@Input`/`@Output` patterns — anti-patterns
- Lifecycle hook misuse
- Signals adoption (Angular 16+)

### A4: RxJS Hygiene
- Subscription cleanup pattern — takeUntil / takeUntilDestroyed / async pipe / DestroyRef
- Nested subscribes — locations
- Manual `.subscribe` vs async pipe — ratio
- Operator misuse — switchMap/mergeMap/concatMap/exhaustMap choice
- Stream error handling — caught vs silent death
- Subject usage — justified or crutch
- Leak risks

### A5: API Layer & Error Handling
- HTTP service organisation
- Interceptors — auth/error/loading/retry coverage
- Request/response typing — interfaces vs `any`
- Error handling — global/per-service/inconsistent
- Loading & error UI signalling
- Retry logic — present, appropriate
- Environment config — API URLs/keys

### A6: Build, Testing & Code Quality
- Angular version currency
- `angular.json` — unusual config, missing optimisation flags
- tsconfig — strict, permissive overrides
- `package.json` — outdated/deprecated/redundant
- Bundle size — obvious bloat
- Test framework (Karma/Jasmine, Jest, Vitest, Cypress, Playwright)
- Coverage gaps
- Test quality — behaviour vs implementation
- `any` usage; strict null checks
- Dead code, unused imports, `console.log`

---

## Phase 2 — Synthesis

From the six analysis passes, synthesise findings into three priority tiers:

1. **Architectural risks** — affect scalability or correctness
2. **Technical debt** — slows delivery or causes bugs
3. **Quick wins** — improve quality with minimal effort

For each item: current pattern → target pattern → brief rationale.

---

## Phase 3 — Generate artifacts

### 3a: Populate CLAUDE.md

Read the existing CLAUDE.md template in the project root. Replace every placeholder section with real findings from this codebase:

- **Codebase Context**: what this app does, users, domain concepts, critical journeys
- **Repository Structure**: actual folder layout with module dependency diagram
- **Conventions**: the rules this codebase actually follows (or should follow), with rationale. Use the subsection structure from `docs/defaults.md` (Angular Version, Architecture, Component Design, State Management, RxJS, API/HTTP, Typing, Testing) as a starting checklist; record observed reality, deviating from defaults where the codebase does. If Angular version is below 17, adjust conventions to match what's available. **Delete the `BOOTSTRAP_PENDING` HTML comment and the "_Not yet populated_" placeholder line** when this section is filled in.
- **Architecture Decisions**: index every significant decision found (intentional or accidental) as a one-line entry here; write the full Decision → Context → Consequences → Review notes to `docs/architecture-decisions.md` (create it if missing). Keeping detail out of CLAUDE.md holds it within the token budget — it loads on nearly every turn.
- **Common Tasks**: do NOT write recipes inline in CLAUDE.md. Instead, audit `.claude/skills/` against this codebase: keep a default skill if its recipe matches reality (adjust steps where they don't); add new skills under `.claude/skills/<name>/SKILL.md` for project-specific recipes (each with `name` + `description` frontmatter); delete defaults that don't apply. Update the Common Tasks bullet list in CLAUDE.md to match the final skill set.
- **Boy Scout Rule**: priority improvements based on the actual debt found in Phase 2

Preserve the Agentic Workflow section as-is. Never touch `LEARNINGS.md` — it is append-only.

**Token budget**: `CLAUDE.md` loads on nearly every agent turn and anchors the prompt cache — keep it ≤ ~400 lines. Put verbose detail (long ADRs, exhaustive structure dumps) in on-demand files (`docs/`, skills); keep CLAUDE.md to the high-frequency rules. `scripts/docs-sync-check.*` warns past the budget.

### 3b: Generate TECH_DEBT.md

Create TECH_DEBT.md in the project root with this structure:

```markdown
# Tech Debt Register

> One block per item. Sort by severity then effort. Reference items by ID in commit messages and PRs.

---

## DEBT-001: <Short title>

- **Category**: <see list below>
- **Severity**: Critical | High | Medium | Low
- **Effort**: S (<1hr) | M (half day) | L (1-2 days) | XL (needs spike)
- **Files**: `path/to/foo.component.ts:42`, `path/to/bar.service.ts`

### Issue
<1-3 sentences on what's wrong and why it matters>

### Recommended fix
<1-3 sentences on the change and any risks>

---

## Trojan Horse Opportunities

Group DEBT IDs by feature area so developers can bundle cleanup into feature work:

- **Auth**: DEBT-003, DEBT-007
- **Reporting**: DEBT-002, DEBT-011
```

Categories: Architecture, State Management, RxJS, Component Design, Testing, Types, Performance, Dependencies, Security
Severity: Critical / High / Medium / Low
Effort: S (< 1hr) / M (half day) / L (1-2 days) / XL (needs spike)

Sort by severity then effort. One `## DEBT-NNN` block per item.

### 3c: AGENTS.md (generated full mirror)

`AGENTS.md` is a **generated mirror** of CLAUDE.md's portable rules (Verification, Leanness, Conventions, Boy Scout, Agentic Workflow, Common Tasks). It exists so AGENTS.md-native tools — GitHub Copilot agent mode & CLI, Codex, Cursor, Gemini CLI, Aider — get the actual ruleset, not a pointer. **Do not hand-write a pointer file.**

AGENTS.md is produced by the `/generate-copilot` workflow (Part B), which Phase 3e runs **after** Phase 3a has populated `CLAUDE.md > Conventions`. So there is nothing to do here except ensure 3e runs. If a stale or pointer-style `AGENTS.md` already exists, it will be **regenerated** (overwritten) by 3e — do not preserve hand edits to it.

### 3d: Populate FRAMEWORK-CONTEXT.md > Detected Framework Packages

Read `package.json` (and `package-lock.json` if present for resolved versions). For each entry in `dependencies` and `peerDependencies`, check whether the package is part of the team's shared framework.

**How to identify framework packages**: read the existing `FRAMEWORK-CONTEXT.md > Shared Libraries` section. Any package whose name matches an entry there is a framework package. If `Shared Libraries` is empty or template, fall back to a heuristic: packages whose name starts with the org/team scope (look at the most common scope among `dependencies` — e.g. `@acme/*`, `@myorg/*`).

Replace the `## Detected Framework Packages` section with a populated table:

```markdown
## Detected Framework Packages

<!-- Auto-populated by /bootstrap. -->

| Package | Version | Source |
|---------|---------|--------|
| @acme/ui-kit | 3.1.0 | package.json (dependencies) |
| @acme/auth-client | 2.4.7 | package.json (dependencies) |
```

**Delete the `DETECTED_FRAMEWORK_PACKAGES_PENDING` HTML comment** when this section is populated. If no framework packages were found, replace the table with a single line: `_No framework packages detected in this repo._` and still delete the marker.

Do **not** edit any other section of FRAMEWORK-CONTEXT.md — those are maintainer-curated.

### 3e: Generate the agent-facing derived files

Run the `/generate-copilot` workflow. It regenerates **both** derived files from the now-populated CLAUDE.md:

- **`.github/copilot-instructions.md`** — slim (≤80 lines), terse imperative one-liners, Conventions + always-apply Boy Scout only. For **inline editor completions**.
- **`AGENTS.md`** — full mirror of CLAUDE.md's portable rules (Verification, Leanness, Conventions, Boy Scout, Agentic Workflow, Common Tasks), preserving the `GENERATED FILE` banner. For **AGENTS.md-native tools** (Copilot agent mode & CLI, Codex, Cursor, Gemini, Aider) — they get the real ruleset, not a pointer.

See `.claude/commands/generate-copilot.md` for the exact rules for each file.

---

## Phase 4 — Report

Run `git diff CLAUDE.md` and `git diff TECH_DEBT.md` to show the user exactly what changed. Present the diff summary before the rest of the report.

Then output:
- Number of findings per severity
- Top 3 architectural risks
- Top 3 quick wins
- Files generated/modified

**Important**: remind the user to review the generated `CLAUDE.md` before using any other commands. The conventions in that file drive everything else — if they're wrong, every command will follow wrong rules.
