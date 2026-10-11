# Greenfield Conventions — Evidence-Matched Defaults

> Reference defaults for technologies this repository actually evidences, including an Angular application. These apply only when AGENTS.md > Conventions has not been populated by `/bootstrap`.
> Once `/bootstrap` runs, AGENTS.md > Conventions is the authoritative source — these defaults are for cold-start scaffolding only.

The distribution name is not technology evidence. Apply the Angular headings only when the
repository contains Angular application markers such as `angular.json`, an exact-case
`"@angular/core"` dependency-map key in `package.json`, or an exact-case Angular token in a
supported plugin, executor, generator, schematic, or target-default field of Nx/project
configuration. A string mention elsewhere in a manifest is not evidence.

### Verification Commands

For each durable category — **build**, **test**, **format**, **lint**, **migration/deploy**, and
**data-validation** — use an exact command only when committed repository evidence names it:
AGENTS.md conventions, CI definitions, scripts/task runners, manifests, or tool configuration.
Record that exact evidence path with the command. If a category has no applicable Angular profile or
evidenced command, report `not available (no evidenced command)`; never invent `ng build`, `ng test`,
a browser flag, or another command from this distribution's name.

## Angular application defaults (only when Angular application markers exist)

### Angular Version & Tooling
These defaults cover Angular v21 and v22, the current major and the one before it as of 2026-10 (support status:
angular.dev/reference/releases); a rule that differs between them names the major.
<!-- Check angular.json, package.json, tsconfig.json. Record the major; the change-detection provider
     (zoneless by default from v21, or `provideZoneChangeDetection` where the app keeps zone.js); the build
     builder (`:application` is current, the webpack `:browser` builder is deprecated); the test builder and
     runner (`@angular/build:unit-test` runs Vitest unless its `runner` names another, `@angular/build:karma`
     runs Karma/Jasmine) and whether the test build loads zone.js; `strict` and `strictTemplates`; and any
     non-standard config. -->

### Architecture
- New components, directives and pipes are standalone (the default since v19). Mirror NgModule declarations only where a file or feature already uses them.
- New code injects with `inject()`. Mirror constructor injection only in a file that already uses it; do not mix the two styles in one file.
- **DIP (see the framework rules (`.github/instructions/framework-rules.instructions.md` › SOLID))**: derive a service seam and registration from first-party project evidence and correctness needs. Do not introduce an abstraction, token, or DI container solely from this default; preserve an evidenced dependency boundary. Data carriers (models, DTOs, enums) are not services and get no abstraction.
- Follow the project’s evidenced route-loading mechanism. A genuinely new lazy/eager choice needs an explicit design decision; this default does not select one.
- Barrel files (`index.ts`) only at feature boundaries — not inside feature folders (causes circular deps).

### Component Design
- Smart/container components handle state and orchestration. Dumb/presentational components receive data through inputs and emit through outputs (`input()`, `output()` and `model()` in new code; `@Input`/`@Output` where the file already uses them) — except a component that is itself a form control, which must participate in the forms API instead (see Forms).
- OnPush change detection on every component: on v21 set `ChangeDetectionStrategy.OnPush`; on v22+, where OnPush is the default, leave `changeDetection` unset unless sibling components set it explicitly. `Eager` (21.2+) or the deprecated `Default` needs a documented reason; the `Eager` that `ng update` writes into existing components on v22 is upgrade debt to review, not a convention.
- Templates stay lean — no complex expressions, no business logic. Derive values with `computed()` (or a pipe) and keep other logic in the component class.
- Use `@if`/`@for`/`@switch`; `*ngIf`/`*ngFor`/`*ngSwitch` are deprecated since v20. Migrate a template when its file is the primary target, not in a bug fix.
- Prefer signals over getter-based reactive state for new code.

### Forms
<!-- Detect the approach before writing any: `ReactiveFormsModule` + `formControlName` in templates
     means reactive; `FormsModule` + `ngModel` means template-driven; `form()` imported from
     `@angular/forms/signals` means Signal Forms (experimental on v21, stable on v22). Mirror what the
     repo already uses and don't introduce a second approach alongside it. Record which one, and where
     validators live. -->
<!-- Record how this repo's custom form controls participate in the forms API — providing
     `NG_VALUE_ACCESSOR`, or injecting `NgControl` and assigning `valueAccessor`; under Signal Forms,
     implementing `FormValueControl` or `FormCheckboxControl` — and follow the pattern already
     established. A component bindable with `formControlName` must participate one of those ways;
     inputs and outputs alone cannot carry a form binding. -->

**If a forms approach already exists:** mirror it; do not introduce a second approach.

**If no forms approach exists (greenfield only):**
- Use reactive forms with typed controls (`FormControl<T>` or `NonNullableFormBuilder`).
- Declare field validators with their control and cross-field validators on the `FormGroup`.
- Never use `ngModel` and `formControlName` on the same control.

For a custom reactive or template-driven form control, neither integration option is an
anti-pattern. Choose by what the component needs to render:

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
- Subscription cleanup via `takeUntilDestroyed(this.destroyRef)` or `DestroyRef`. No manual `ngOnDestroy` subject patterns for new code.
- No nested subscribes. Use `switchMap`, `mergeMap`, `concatMap`, or `exhaustMap` — choose the right operator for the use case.
- Error handling in every stream. Use `catchError` to prevent stream death.

### API / HTTP
- One HTTP client service per backend resource (e.g., `UserService`, `OrderService`).
- All HTTP return types are typed interfaces — no `any`.
- Interceptors handle cross-cutting concerns: auth tokens, error handling, retry logic, loading state.
- Environment config for API URLs. No hardcoded URLs.

### Typing
- `strict` and `strictTemplates` on in tsconfig. No overrides weakening strictness; the `strictTemplates: false` that `ng update` writes when moving to v22 is upgrade debt, not a convention.
- No `any` — use `unknown` if the type is genuinely uncertain, then narrow.
- Interfaces for data shapes. Classes only when behavior is needed.
- No type assertions (`as`) without a comment explaining why.

### Styling
- Component styles are encapsulated by default (`ViewEncapsulation.Emulated`). Do not change to `None` without justification.
- Use `:host` for component-level styling. Avoid styling the component's own tag from the parent.
- Global styles go in `styles.scss` only. No global styles leaked through component files.
- Follow the project's CSS methodology (BEM, utility-first, etc.) — bootstrap will detect this.

### SSR / Hydration
<!-- If using @angular/ssr, document the constraints here. -->
<!-- Common rules: no direct DOM access (use Renderer2/inject DOCUMENT); run browser-only code (window, localStorage) in `afterNextRender`/`afterEveryRender` rather than behind an `isPlatformBrowser` check. Incremental hydration is on by default from v22. -->

### Testing
- Detect the spec runner (Karma/Jasmine, Jest, or Vitest) and assertion style from workspace config and existing specs; mirror them, never replace them.
- No test suite yet? Do not create one as an incidental side effect of feature, fix, refactor, or
  debt work. When establishing tests is explicitly in scope, use the `add-tests` skill to propose
  the smallest harness and first risk-first tests; get agreement before adding a runner.
- Prefer a few tests for consequential branching, boundaries, and regressions over one test per
  public member. Test observable behavior, not implementation details.
- Component tests mirror the repository's established component integration boundary (for example
  `TestBed` with harnesses where already evidenced).
- Service tests mock HTTP with `provideHttpClientTesting()`, after `provideHttpClient(…)` only when the test needs an HTTP feature. `HttpClientTestingModule` is deprecated: mirror it only in a spec that already uses it.
- Test naming: `should [expected behavior] when [condition]`.
- No focused or skipped tests committed to main: Jasmine's `fit`/`fdescribe`/`xit`/`xdescribe`, or `.only`/`.skip` on `it`, `test`, `describe` or `suite` (Vitest, Jest).

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
- Control time with the runner's fake timers (Vitest, Jest, or `jasmine.clock()` with `mockDate()` when a spec reads `Date`) or marble tests, and `fakeAsync`/`tick` only where the runner is zone-patched; mock HTTP via `provideHttpClientTesting`; seed or stub randomness; reset state between tests.
