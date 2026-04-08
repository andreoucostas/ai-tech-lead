Analyse this Angular codebase and set up the AI Tech Lead framework. This is the one-time bootstrap that makes the repo AI-ready.

## Input
$ARGUMENTS

Execute all phases below in sequence. Do not skip any phase. Do not ask for confirmation between phases — run the full pipeline.

---

## Pre-flight checks

Before starting analysis:
1. **Locate the project root** — find `angular.json`. If not found, check for `nx.json` or `project.json` (Nx workspace). All paths are relative to this root. If it's a monorepo (e.g., `apps/` structure), note which apps/libs exist and adjust paths in generated output.
2. **Check Angular version** — read `package.json` for `@angular/core` version. Note whether it's 17+ (standalone default, signals, new control flow) or older. Adjust conventions accordingly.
3. **Check for existing configuration** — if `CLAUDE.md` already has populated content (not just template defaults), back up the existing conventions section and merge your findings with what's already there rather than overwriting. Preserve any entries in the "What We've Learned" section.
4. **Large codebases** — if the project has more than 200 components, focus analysis on the most actively changed areas (check git log). Note which areas were analysed and which were skipped.

---

## Phase 1 — Analysis

Perform six analysis passes. For each, observe and record findings internally. Do not output analysis results to the user — they feed Phase 2.

### A1: Module Architecture & Lazy Loading
- Module layout (NgModules vs standalone components — which approach, how consistently applied?)
- Lazy loading strategy (which routes are lazy loaded, which are eagerly loaded and shouldn't be?)
- Barrel files (`index.ts`) — are they used? Are they causing circular dependencies or bloated imports?
- Shared/core module contents — what's in each and is the boundary clear?
- Routing structure (flat vs nested, guard usage, resolver patterns)
- Any circular dependencies between modules

### A2: State Management
- What approach is used (NgRx, NGXS, Akita, service-based with BehaviorSubjects, signals, or a mix)?
- Is there a clear distinction between local component state and shared application state?
- Are there services acting as informal stores with BehaviorSubjects? How consistently?
- Is there prop drilling (passing data through multiple component layers via @Input)?
- How is server state handled (caching, stale data, loading states)?
- If NgRx or similar: are actions, reducers, effects, and selectors well-structured or over-engineered?

### A3: Component Design
- Smart vs dumb component separation — is it applied? Consistently?
- Change detection strategy — which components use OnPush? Which should but don't?
- Template complexity — are there templates with heavy logic, nested conditions, or complex expressions?
- Component size — are there god components doing too many things?
- Input/Output patterns — correct use, or are there anti-patterns?
- Lifecycle hook usage — any misuse of ngOnInit, ngOnChanges, ngOnDestroy?
- Signal usage — if Angular 16+, are signals adopted? How consistently?

### A4: RxJS Hygiene
- Subscription management — are subscriptions properly cleaned up? What pattern is used (takeUntil, takeUntilDestroyed, async pipe, DestroyRef)?
- Nested subscribes (subscribe inside subscribe) — where do they occur?
- Manual subscribe vs async pipe — what's the ratio?
- Operator usage — any misuse of switchMap/mergeMap/concatMap/exhaustMap?
- Error handling in streams — are errors caught or do they silently kill streams?
- Subject usage — appropriate or a crutch?
- Memory leaks — any observable streams that could leak?

### A5: API Layer & Error Handling
- Service structure — how are HTTP services organised?
- HTTP interceptors — what's intercepted (auth tokens, error handling, loading state, retry)?
- Request/response models — typed with interfaces, or liberal use of `any`?
- Error handling strategy — global error handler? Per-service? Inconsistent?
- Loading and error states — how are they communicated to the UI?
- Retry logic — does it exist? Is it appropriate?
- Environment configuration — how are API URLs and keys managed?

### A6: Build, Testing & Code Quality
- Angular version — current or behind?
- angular.json — unusual config, missing optimisation flags?
- tsconfig — strict mode enabled? Overly permissive overrides?
- package.json — outdated, deprecated, or redundant dependencies?
- Bundle size — any obvious bloat?
- Test framework (Karma/Jasmine, Jest, Vitest, Cypress, Playwright)
- What's tested vs what's not — biggest gaps
- Test quality — testing behaviour or implementation details?
- Type safety — how much `any` is used? Strict null checks on?
- Dead code, unused imports, console.log in production code

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
- **File Structure**: actual folder layout with module dependency diagram
- **Conventions**: the rules this codebase actually follows (or should follow), with rationale. Keep the subsection structure (Angular Version, Architecture, Component Design, State Management, RxJS, API/HTTP, Typing, Testing). Replace template defaults with observed reality. If Angular version is below 17, adjust conventions to match what's available.
- **Architecture Decisions**: every significant decision found — intentional or accidental. Include context, consequences, and honest review notes.
- **Common Tasks**: real patterns from this codebase for adding components, services, routes, stores
- **Boy Scout Rule**: priority improvements based on the actual debt found in Phase 2

Preserve the Agentic Workflow and What We've Learned sections as-is.

### 3b: Generate TECH_DEBT.md

Create TECH_DEBT.md in the project root with this structure:

```markdown
# Tech Debt Register

| ID | Category | Severity | Files Affected | Issue | Recommended Fix | Effort |
|----|----------|----------|----------------|-------|-----------------|--------|
```

Categories: Architecture, State Management, RxJS, Component Design, Testing, Types, Performance, Dependencies, Security
Severity: Critical / High / Medium / Low
Effort: S (< 1hr) / M (half day) / L (1-2 days) / XL (needs spike)

Sort by severity then effort.

Add a "Trojan Horse Opportunities" section grouping debt items by feature area, so developers can bundle cleanup into feature work.

### 3c: Generate copilot-instructions.md

Read the now-populated CLAUDE.md. Generate `.github/copilot-instructions.md` as a full derivative:

- Start with: "When generating code in this repo, always follow these rules:"
- Convert every convention, rule, and pattern from CLAUDE.md into imperative instructions
- Include all sections: architecture, component design, state management, RxJS, API/HTTP, typing, testing, boy scout rule, documentation maintenance
- Imperative voice throughout
- Keep every point scannable — one to two lines max
- Include the documentation maintenance rules:
  - New pattern → flag CLAUDE.md needs updating
  - Convention changed → flag CLAUDE.md needs updating
  - Tech debt resolved → flag TECH_DEBT.md entry for removal
  - New tech debt found → flag TECH_DEBT.md needs new entry
  - Implementation contradicts instructions → ask whether to update convention or change implementation

---

## Phase 4 — Report

Run `git diff CLAUDE.md` and `git diff TECH_DEBT.md` to show the user exactly what changed. Present the diff summary before the rest of the report.

Then output:
- Number of findings per severity
- Top 3 architectural risks
- Top 3 quick wins
- Files generated/modified

**Important**: remind the user to review the generated `CLAUDE.md` before using any other commands. The conventions in that file drive everything else — if they're wrong, every command will follow wrong rules.
