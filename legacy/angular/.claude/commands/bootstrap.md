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
5. **Mixed-stack detection** — count `.cs` / `.csproj` / `.sln` files outside `node_modules/` and `dist/`. If a `.sln` exists or more than ~50 `.cs` source files exist, flag this as a mixed-stack repo. After Phase 3 generation, add a note in the final report recommending the user create `.github/instructions/<stack>.instructions.md` with `applyTo:` frontmatter (see README "Mixed-stack repos" section). Do not auto-generate the secondary-stack instructions file — the user picks the rules.

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
- **Repository Structure**: actual folder layout with module dependency diagram
- **Conventions**: the rules this codebase actually follows (or should follow), with rationale. Keep the subsection structure (Angular Version, Architecture, Component Design, State Management, RxJS, API/HTTP, Typing, Testing). Replace template defaults with observed reality. If Angular version is below 17, adjust conventions to match what's available.
- **Architecture Decisions**: every significant decision found — intentional or accidental. Include context, consequences, and honest review notes.
- **Common Tasks**: real patterns from this codebase for adding components, services, routes, stores
- **Boy Scout Rule**: priority improvements based on the actual debt found in Phase 2

Preserve the Agentic Workflow and What We've Learned sections as-is.

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

### 3c: Ensure AGENTS.md exists

If `AGENTS.md` is missing from the repo root, write it. Use this exact content (it points all agent-style tools — Copilot coding agent, Codex, Cursor, Aider — at CLAUDE.md):

```markdown
# Agent Instructions

This repository follows the AI Tech Lead Framework. The single source of truth for conventions, architecture, common tasks, and the agentic workflow lives in **[CLAUDE.md](./CLAUDE.md)** at the repository root.

All AI coding agents (Claude Code, GitHub Copilot coding agent, Codex, Cursor, Aider, etc.) should read `CLAUDE.md` before making changes and treat it as authoritative.

## Quick reference

- **Conventions, architecture, common tasks, boy-scout rules**: see [CLAUDE.md](./CLAUDE.md)
- **Tech debt register**: see [TECH_DEBT.md](./TECH_DEBT.md)
- **Inline-completion ruleset**: see [.github/copilot-instructions.md](./.github/copilot-instructions.md)
- **Reusable workflows for Copilot Chat**: see [.github/prompts/](./.github/prompts/)
- **Reusable workflows for Claude Code**: see [.claude/commands/](./.claude/commands/)

## Precedence

If anything in this file or in derived files conflicts with `CLAUDE.md`, `CLAUDE.md` wins. Slash commands (`/feature`, `/fix`, etc.) have Copilot equivalents in `.github/prompts/` with the same names.
```

If `AGENTS.md` already exists, leave it alone.

### 3d: Generate copilot-instructions.md (slim, inline-completions only)

Run the `/generate-copilot` workflow. **Do not** produce a full derivative of CLAUDE.md — Copilot's coding agent reads CLAUDE.md and AGENTS.md directly. The copilot-instructions.md file is now scoped to inline editor completions only:

- Terse imperative one-liners
- Conventions and Boy Scout (always-apply only)
- Total under 80 lines
- No Common Tasks, no Architecture Decisions, no Codebase Context

See `.claude/commands/generate-copilot.md` for the exact rules.

---

## Phase 4 — Report

Run `git diff CLAUDE.md` and `git diff TECH_DEBT.md` to show the user exactly what changed. Present the diff summary before the rest of the report.

Then output:
- Number of findings per severity
- Top 3 architectural risks
- Top 3 quick wins
- Files generated/modified

**Important**: remind the user to review the generated `CLAUDE.md` before using any other commands. The conventions in that file drive everything else — if they're wrong, every command will follow wrong rules.
