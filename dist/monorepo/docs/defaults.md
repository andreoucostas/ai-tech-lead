# Greenfield Conventions — Defaults

> Reference defaults for a modern .NET solution and an Angular 17+ frontend in this mixed .NET + Angular codebase. These apply only when CLAUDE.md > Conventions has not been populated by `/bootstrap`.
> Once `/bootstrap` runs, CLAUDE.md > Conventions is the authoritative source — these defaults are for cold-start scaffolding only.

This repo carries both stacks. Apply the `.NET defaults` to backend C# code and the `Angular defaults` to the frontend; each section stands on its own.

---

## .NET defaults

### .editorconfig & Analysers
<!-- Check for .editorconfig, Directory.Build.props, and Roslyn analyser rules. Reference them here so AI tools respect toolchain-enforced conventions. -->

### Architecture
- Dependency direction: inward only. API → Application → Domain. Never the reverse.
- Domain layer has zero external dependencies.

### Naming
- Classes: PascalCase. Interfaces: `I` prefix. Async methods: `Async` suffix.
- Files match class names exactly. One public class per file.

### Dependency Injection
- **DIP (mandatory — see CLAUDE.md > SOLID)**: every injected service is depended on through an interface (`IFoo` + `Foo`, impl may be `sealed`), registered in DI; never inject or `new` a concrete service. Data carriers (DTOs, entities, value objects, `Options`) are not services and get no interface.
- Services: scoped. Factories and stateless helpers: transient. Caches and config: singleton.
- Register via extension methods per project, not in Program.cs directly.
- Use `IOptions<T>` for static config, `IOptionsMonitor<T>` for config that can change at runtime, `IOptionsSnapshot<T>` for scoped config refresh.

### Data Access
Data-access defaults are conditional on what the repo evidences in csproj package references. Apply only the matching block; if none match, ask.

**If EF Core (`Microsoft.EntityFrameworkCore*`):**
- EF Core with repository pattern only where it adds value (not wrapping DbContext for the sake of it).
- Queries belong in the application/service layer, not in controllers.
- Always use `.AsNoTracking()` for read-only queries.

**If Dapper:**
- Use parameterized queries only; keep SQL in the application layer; never concatenate dynamic SQL.

**If MongoDB.Driver:**
- Use typed collections via a small registry; no magic strings.
- Review indexes when adding a new query shape, and use projections for read-heavy queries.
- Use multi-document transactions only where the deployment supports them (replica set); otherwise design idempotent single-document writes.

**If none detected:**
- For greenfield work, ask the developer before introducing a data-access stack.

### API Design
- Controllers are thin — delegate to services immediately. Minimal APIs are acceptable for simple endpoints if the project uses them.
- Request/response DTOs are separate from domain entities. Never expose domain models in API contracts.
- Use FluentValidation for request validation. No validation logic in controllers.
- Background work uses `BackgroundService` or `IHostedService`. No `Task.Run` fire-and-forget in request handlers.

### Async
- Propagate `CancellationToken` through every async call chain.
- No `async void`. No sync-over-async. No fire-and-forget without explicit justification.

### Null Handling
- Nullable reference types enabled project-wide. No suppression (`!`) without a comment explaining why.
- Guard clauses at public API boundaries. Trust internal code.

### Logging
- Structured logging only (no string interpolation in log messages).
- Use `LoggerMessage` source generators for hot paths.

### Testing
- No test suite yet? Use the `add-tests` skill — its suite-bootstrap mode scaffolds the harness and first risk-first tests.
- Every public behavior has a test. Test behavior, not implementation details.
- Unit tests use xUnit + NSubstitute (or project's chosen stack).
- Integration tests use `WebApplicationFactory`.
- Test naming: `MethodName_Scenario_ExpectedResult`.

### Test shape
Choose the level by what the test actually exercises — *push each test to the lowest level that still runs real behavior; test at the boundary, not the mock.* A heuristic, not a fixed ratio; `/bootstrap` replaces it with the shape your codebase warrants.
- Domain / application logic (rules, calculations, branching, validation) → unit-dense.
- Cross-cutting paths (routing, model binding, data access, auth, serialization) → integration via `WebApplicationFactory`; exercise the real pipeline, don't mock it.
- Critical journeys → a sparse top layer of full-stack behavioral checks. Few, high-value.
- Boundary-heavy / gateway services → weight toward integration (honeycomb / risk-based), not unit.
- Anti-shape: the inverted suite (mostly slow end-to-end tests over a thin unit base). Slow + flaky = wrong shape.

### Test determinism
- Tests must be deterministic and hermetic: no real network, clock, randomness, filesystem, or inter-test order dependence. An intermittently-failing test is worse than none — it trains the team to ignore red.
- Pin time behind an abstraction (`TimeProvider` / injected clock); seed or stub randomness; isolate state between tests.

---

## Angular defaults

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
- No test suite yet? Use the `add-tests` skill — its suite-bootstrap mode scaffolds the harness and first risk-first tests.
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
