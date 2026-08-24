# Greenfield Conventions — Evidence-Matched Defaults

> Reference defaults for technologies this repository actually evidences, including an Angular application. These apply only when CLAUDE.md > Conventions has not been populated by `/bootstrap`.
> Once `/bootstrap` runs, CLAUDE.md > Conventions is the authoritative source — these defaults are for cold-start scaffolding only.

The distribution name is not technology evidence. Apply the Angular headings only when the
repository contains Angular application markers such as `angular.json`, an exact-case
`"@angular/core"` dependency-map key in `package.json`, or an exact-case Angular token in a
supported plugin, executor, generator, schematic, or target-default field of Nx/project
configuration. A string mention elsewhere in a manifest is not evidence.

### Verification Commands

For each durable category — **build**, **test**, **format**, **lint**, **migration/deploy**, and
**data-validation** — use an exact command only when committed repository evidence names it:
CLAUDE.md conventions, CI definitions, scripts/task runners, manifests, or tool configuration.
Record that exact evidence path with the command. If a category has no applicable Angular profile or
evidenced command, report `not available (no evidenced command)`; never invent `ng build`, `ng test`,
a browser flag, or another command from this distribution's name.

## Angular application defaults (only when Angular application markers exist)

### Angular Version & Tooling
<!-- Check angular.json, package.json, tsconfig.json. Reference strict mode, build optimisations, and any non-standard config. -->

### Architecture
- Standalone components as default. NgModules only where the codebase hasn't migrated yet.
- Use `inject()` function for dependency injection in new code. Constructor injection is acceptable in existing code but don't mix both in the same file.
- **DIP (mandatory — see the framework rules (`.github/instructions/framework-rules.instructions.md` › SOLID; `AGENTS.md` › SOLID on AGENTS.md-native tools))**: every injected service is provided through an abstraction — an `abstract class` used as the DI token (`{ provide: Foo, useClass: FooImpl }`), or `interface` + `InjectionToken<T>`. Inject the abstraction, never a concrete service. Data carriers (models, DTOs, enums) are not services and get no abstraction.
- Feature areas are lazy-loaded routes. Eagerly loaded modules should be justified.
- Barrel files (`index.ts`) only at feature boundaries — not inside feature folders (causes circular deps).

### Component Design
- Smart/container components handle state and orchestration. Dumb/presentational components receive data via `@Input` and emit via `@Output` — except a component that is itself a form control, which must participate in the forms API instead (see Forms).
- `ChangeDetectionStrategy.OnPush` on every component. No exceptions without a documented reason.
- Templates stay lean — no complex expressions, no business logic. Move logic to the component class or a pipe.
- Use new control flow syntax (`@if`, `@for`, `@switch`) in new code. Migrate from `*ngIf`/`*ngFor` when touching existing templates.
- Prefer signals over getter-based reactive state for new code.

### Forms
<!-- Detect the approach before writing any: `ReactiveFormsModule` + `formControlName` in templates
     means reactive; `FormsModule` + `ngModel` means template-driven. Mirror what the repo already
     uses and don't introduce a second approach alongside it. Record which one, and where validators
     live. -->
<!-- Record how this repo's custom form controls participate in the forms API — providing
     `NG_VALUE_ACCESSOR`, or injecting `NgControl` and assigning `valueAccessor` — and follow the
     pattern already established. A component bindable with `formControlName` must participate one of
     those ways; `@Input`/`@Output` alone cannot carry a form binding. -->

**If a forms approach already exists:** mirror it; do not introduce a second approach.

**If no forms approach exists (greenfield only):**
- Use reactive forms with typed controls (`FormControl<T>` or `NonNullableFormBuilder`).
- Declare field validators with their control and cross-field validators on the `FormGroup`.
- Never use `ngModel` and `formControlName` on the same control.

For a custom form control, neither integration option is an anti-pattern. Choose by what the
component needs to render:

| | `NG_VALUE_ACCESSOR` provider | inject `NgControl` (`{ self: true }`) |
|---|---|---|
| gives you | value + disabled plumbing | plumbing plus the control (`touched`, `errors`, `status`) |
| choose when | renders no validation state of its own | renders its own error/required state |
| cost | needs a separate route to validity | must set `ngControl.valueAccessor = this` by hand |

Do not combine injected `NgControl` with a self-referencing `NG_VALUE_ACCESSOR` provider using
`useExisting: forwardRef(() => Self)`: that dependency path cycles from `NgControl` through the
provider and component back to `NgControl`. A separate accessor class does not create that cycle.

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
- Detect the spec runner (Karma/Jasmine, Jest, or Vitest) and assertion style from workspace config and existing specs; mirror them, never replace them.
- No test suite yet? Do not create one as an incidental side effect of feature, fix, refactor, or
  debt work. When establishing tests is explicitly in scope, use the `add-tests` skill to propose
  the smallest harness and first risk-first tests; get agreement before adding a runner.
- Prefer a few tests for consequential branching, boundaries, and regressions over one test per
  public member. Test observable behavior, not implementation details.
- Component tests mirror the repository's established component integration boundary (for example
  `TestBed` with harnesses where already evidenced).
- Service tests mock HTTP via `provideHttpClientTesting` (preferred) or `HttpClientTestingModule` (legacy).
- Test naming: `should [expected behavior] when [condition]`.
- No `fdescribe`, `fit`, or `xdescribe`, `xit` committed to main.

### Test shape
Choose the level by what the test actually exercises — *push each test to the lowest level that still runs real behavior; test at the boundary, not the mock.* A heuristic, not a fixed ratio; `/bootstrap` replaces it with the shape your codebase warrants. Frontend testing is **trophy-shaped**, not a pyramid:
- Static analysis (strict TypeScript + lint) is the wide base — it catches a whole class of bugs before a test runs.
- Component / integration tests using the repository's real template + DI approach are the **centre
  of gravity** — they exercise rendering, inputs/outputs, and interaction the way a user hits them.
- A thin layer of E2E (Cypress/Playwright) for critical journeys.
- Fewest isolated unit tests — reserve them for pure pipes, pure functions, and signal/store state transitions.
- Anti-shape: the inverted suite (mostly slow E2E over a thin base). Slow + flaky = wrong shape.

### Test determinism
- Tests must be deterministic and hermetic: no real network, real timers, randomness, or inter-test order dependence. An intermittently-failing test is worse than none — it trains the team to ignore red.
- Use fake async (`fakeAsync`/`tick`) or marble tests for time; mock HTTP via `provideHttpClientTesting`; seed or stub randomness; reset state between tests.
