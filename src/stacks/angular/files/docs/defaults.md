# Greenfield Conventions — Angular Defaults

> Reference defaults targeting Angular 17+. These apply only when CLAUDE.md > Conventions has not been populated by `/bootstrap`.
> Once `/bootstrap` runs, CLAUDE.md > Conventions is the authoritative source — these defaults are for cold-start scaffolding only.

### Angular Version & Tooling
<!-- Check angular.json, package.json, tsconfig.json. Reference strict mode, build optimisations, and any non-standard config. -->

### Build & Test Commands
- **Build**: `ng build`
- **Test**: `ng test --watch=false --browsers=ChromeHeadless`
- **Lint**: `ng lint`
<!-- If using Jest: "npx jest". If using Vitest: "npx vitest run". Bootstrap should detect and set these. -->

### Architecture
- Standalone components as default. NgModules only where the codebase hasn't migrated yet.
- Use `inject()` function for dependency injection in new code. Constructor injection is acceptable in existing code but don't mix both in the same file.
- **DIP (mandatory — see CLAUDE.md > SOLID)**: every injected service is provided through an abstraction — an `abstract class` used as the DI token (`{ provide: Foo, useClass: FooImpl }`), or `interface` + `InjectionToken<T>`. Inject the abstraction, never a concrete service. Data carriers (models, DTOs, enums) are not services and get no abstraction.
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

### Test shape
Choose the level by what the test actually exercises — *push each test to the lowest level that still runs real behavior; test at the boundary, not the mock.* A heuristic, not a fixed ratio; `/bootstrap` replaces it with the shape your codebase warrants. Frontend testing is **trophy-shaped**, not a pyramid:
- Static analysis (strict TypeScript + lint) is the wide base — it catches a whole class of bugs before a test runs.
- Component / integration tests (`TestBed` with the real template + DI, harnesses) are the **centre of gravity** — they exercise rendering, inputs/outputs, and interaction the way a user hits them.
- A thin layer of E2E (Cypress/Playwright) for critical journeys.
- Fewest isolated unit tests — reserve them for pure pipes, pure functions, and signal/store state transitions.
- Anti-shape: the inverted suite (mostly slow E2E over a thin base). Slow + flaky = wrong shape.

### Test determinism
- Tests must be deterministic and hermetic: no real network, real timers, randomness, or inter-test order dependence. An intermittently-failing test is worse than none — it trains the team to ignore red.
- Use fake async (`fakeAsync`/`tick`) or marble tests for time; mock HTTP via `provideHttpClientTesting`; seed or stub randomness; reset state between tests.
