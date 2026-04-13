# [Project Name]

> This file is the single source of truth for AI-assisted development in this repository.
> It is automatically loaded by Claude Code on every session.
> Run `/bootstrap` to populate it from your actual codebase.

---

## Codebase Context

<!-- Populated by /bootstrap — do not fill manually -->

What this application does, who uses it, key domain concepts, and critical user journeys.

---

## File Structure

<!-- Populated by /bootstrap — replaces separate CODEMAP.md -->

Top-level folder layout, feature module boundaries, shared/core module contents, routing structure, and where to put new code.

Include a text or mermaid diagram showing the module dependency graph.

---

## Conventions

<!-- Populated by /bootstrap — replaces separate CONVENTIONS.md -->
<!-- Each convention: the rule, then 1-2 sentence rationale -->

> **DEFAULTS BELOW.** Everything in this section is a starting template targeting Angular 17+.
> When you run `/bootstrap`, these are replaced with conventions observed in your actual codebase.
> If you haven't run `/bootstrap` yet, do not treat these as authoritative.

### Angular Version & Tooling
<!-- Check angular.json, package.json, tsconfig.json. Reference strict mode, build optimisations, and any non-standard config. -->

### Build & Test Commands
<!-- Populated by /bootstrap — detect the test runner (Karma, Jest, Vitest) and record the exact commands here -->
- **Build**: `ng build`
- **Test**: `ng test --watch=false --browsers=ChromeHeadless`
- **Lint**: `ng lint`
<!-- If using Jest: "npx jest". If using Vitest: "npx vitest run". Bootstrap should detect and set these. -->

### Architecture
- Standalone components as default. NgModules only where the codebase hasn't migrated yet.
- Use `inject()` function for dependency injection in new code. Constructor injection is acceptable in existing code but don't mix both in the same file.
- Feature areas are lazy-loaded routes. Eagerly loaded modules should be justified.
- Barrel files (`index.ts`) only at feature boundaries — not inside feature folders (causes circular deps).

### Component Design
- Smart/container components handle state and orchestration. Dumb/presentational components receive data via `@Input` and emit via `@Output`.
- `ChangeDetectionStrategy.OnPush` on every component. No exceptions without a documented reason.
- Templates stay lean — no complex expressions, no business logic. Move logic to the component class or a pipe.
- Use new control flow syntax (`@if`, `@for`, `@switch`) in new code. Migrate from `*ngIf`/`*ngFor` when touching existing templates.
- Prefer signals over getter-based reactive state for new code.

### State Management
- Local component state: signals or simple properties.
- Shared state: signals-based service, NgRx, or NGXS — whichever the project uses. Don't mix approaches.
- No prop drilling through more than 2 component levels — use a service or store instead.
- Server state: handle loading, error, and success states explicitly. No optimistic assumptions.

### RxJS
- Prefer `async` pipe over manual `.subscribe()`. Manual subscribes require explicit cleanup.
- Subscription cleanup via `takeUntilDestroyed(this.destroyRef)` (Angular 16+) or `DestroyRef`. No manual `ngOnDestroy` subject patterns for new code.
- No nested subscribes. Use `switchMap`, `mergeMap`, `concatMap`, or `exhaustMap` — choose the right operator for the use case.
- Error handling in every stream. Use `catchError` to prevent stream death.

### API / HTTP
- One service per backend resource (e.g., `UserService`, `OrderService`).
- All HTTP return types are typed interfaces — no `any`.
- Interceptors handle cross-cutting concerns: auth tokens, error handling, retry logic, loading state.
- Environment config for API URLs. No hardcoded URLs.

### Typing
- `strict: true` in tsconfig. No overrides weakening strictness.
- No `any` — use `unknown` if the type is genuinely uncertain, then narrow.
- Interfaces for data shapes. Classes only when behavior is needed.
- No type assertions (`as`) without a comment explaining why.

### Styling
- Component styles are encapsulated by default (`ViewEncapsulation.Emulated`). Do not change to `None` without justification.
- Use `:host` for component-level styling. Avoid styling the component's own tag from the parent.
- Global styles go in `styles.scss` only. No global styles leaked through component files.
- Follow the project's CSS methodology (BEM, utility-first, etc.) — bootstrap will detect this.

### SSR / Hydration
<!-- If using @angular/ssr or Angular Universal, document the constraints here. -->
<!-- Common rules: no direct DOM access (use Renderer2/inject DOCUMENT), no window/localStorage without isPlatformBrowser check. -->

### Testing
- Every public behavior has a test. Test behavior, not implementation details.
- Component tests use `TestBed` with component harnesses where available.
- Service tests mock HTTP via `provideHttpClientTesting` (preferred) or `HttpClientTestingModule` (legacy).
- Test naming: `should [expected behavior] when [condition]`.
- No `fdescribe`, `fit`, or `xdescribe`, `xit` committed to main.

---

## Architecture Decisions

<!-- Populated by /bootstrap — replaces separate ADR files -->
<!-- Format: Decision → Context → Consequences → Review notes -->

Record significant decisions here. Include accidental decisions that became convention.

---

## Common Tasks

### Add a new feature component
1. Create component with `ng generate component` (standalone by default)
2. Add route in the feature's routing config (lazy-loaded)
3. Create interfaces/models for the feature's data shapes
4. Create or extend service for backend communication
5. Wire up state (signals, store, or service — match existing pattern)
6. Write component test + service test

### Add a new service
1. `ng generate service` in the appropriate feature or core directory
2. `providedIn: 'root'` for app-wide singletons, feature-level for scoped services
3. Type all method signatures — no `any` in or out
4. Write service test with `HttpClientTestingModule`

### Add a new route with lazy loading
1. Create feature directory with routing config
2. Add lazy route in parent: `loadComponent` (standalone) or `loadChildren` (module)
3. Add guards if auth/role-gating needed
4. Add resolvers only if data must load before render

### Add a new signal-based store
1. Create service with `signal()` for state and `computed()` for derived values
2. Expose read-only signals publicly (`asReadonly()`)
3. Mutations via explicit methods — no external `.set()` calls
4. Write tests verifying signal state transitions

---

## Boy Scout Rule

When touching any file, apply these improvements if they exist.

### Always apply (low-effort, low-risk — do these on every touched file):

1. Replace manual `ngOnDestroy` subscription cleanup with `takeUntilDestroyed()`
2. Add `ChangeDetectionStrategy.OnPush` if missing
3. Replace nested `.subscribe()` with appropriate RxJS operator
4. Replace `any` with proper types

### Apply only when the file is the primary target of the change:

5. Replace manual `.subscribe()` with `async` pipe where possible
6. Extract complex template expressions into component methods or pipes

Items 5–6 can significantly expand a diff. Only apply them when the file is what the task is specifically about, not when it's incidentally touched. This keeps PRs focused and reviewable.

**When to skip**: hotfixes, time-sensitive production incidents, and proof-of-concept branches. If skipping, add a comment `// TODO: Boy Scout skipped — [reason]` so it's picked up on the next pass. Use `/debt` to clean up later.

---

## Agentic Workflow

When given any task, follow this execution model:

### 1. Classify the intent
Determine what the developer is asking for:
- **Feature**: new functionality across one or more layers → follow the feature workflow
- **Bug fix**: something is broken → follow the fix workflow
- **Refactor**: restructure without changing behavior → follow the refactor workflow
- **Investigation/design**: need to think before coding → follow the design workflow
- **Test**: add or improve test coverage → follow the test workflow
- **Debt cleanup**: address known tech debt → follow the debt workflow

If the intent is ambiguous, ask before proceeding.

### 2. Plan before coding
For any non-trivial task:
- List the files you'll create or modify
- State the order of operations
- Identify what tests will verify success
- State the plan, then execute

### 3. Execute in verified subtasks
For features and complex changes, decompose into ordered subtasks:
1. Models/interfaces and service layer + tests
2. State management changes (store/signals/service) + tests
3. Component implementation + tests
4. E2E or integration verification

Each subtask must leave the codebase compilable and test-passing.
Run `ng build` and `ng test --watch=false --browsers=ChromeHeadless` after each subtask. Fix failures before moving on.

### 4. Boy Scout every touched file
Check the Boy Scout Rule list above. Apply relevant improvements to every file you modify.

### 5. Self-review before presenting
Before presenting work as complete:
- Review your changes against the Conventions section above
- Verify all tests pass
- Check if the change introduces a new pattern → flag that this file needs updating
- Check if the change resolves a TECH_DEBT.md item → flag for removal
- Check if the change contradicts any convention → ask whether to update the convention or change the implementation

### 6. Flag documentation drift
At the end of your response, note if:
- A new pattern was introduced that should be documented here
- A TECH_DEBT.md entry was resolved or a new one discovered
- copilot-instructions.md needs regeneration (run `/generate-copilot`)

---

## What We've Learned

<!-- This section evolves over time. Add entries when you discover what works and what doesn't. -->
<!-- Format: [date] observation -->

_No entries yet. As the team uses this framework, record what works, what causes friction, and what rules need adjusting._
