# Greenfield Conventions — Evidence-Matched Defaults

> Reference defaults for the technologies this repository actually evidences: .NET, Angular v21–v22, and/or SQL/warehouse sources. These apply only when AGENTS.md > Conventions has not been populated by `/bootstrap`.
> Once `/bootstrap` runs, AGENTS.md > Conventions is the authoritative source — these defaults are for cold-start scaffolding only.

The distribution name is not technology evidence. Apply only the sections whose application markers
exist; the raw-SQL and warehouse blocks under .NET Data Access also stand on their own for a
warehouse-only repository.

### Verification Commands

For each durable category — **build**, **test**, **format**, **lint**, **migration/deploy**, and
**data-validation** — use an exact command only when committed repository evidence names it:
AGENTS.md conventions, CI definitions, scripts/task runners, manifests, or tool configuration.
Record that exact evidence path with the command. For the .NET profile, a committed C# project
(`*.csproj`) evidences `dotnet build`, and a committed test project (a `*.csproj` that references
`Microsoft.NET.Test.Sdk`, or an xunit, NUnit or MSTest package) evidences `dotnet test`. The target is the
`.sln` that contains the project only when every project that `.sln` contains is an SDK-style C# project (a
`*.sqlproj` or legacy-style project in it makes the solution-level command fail); otherwise record one
command per `*.csproj` (each test `*.csproj` for `dotnet test`). Record that manifest path as the evidence.
A `.sln` with no C# project, or a `*.sqlproj`, evidences neither; format, lint, migration/deploy and
data-validation still need explicit evidence. If a category has no applicable selected profile
or evidenced command, report `not available (no evidenced command)`; never invent a .NET or Angular
command from this distribution's name.

---

## .NET application defaults (only when .NET application markers exist)

### .editorconfig & Analysers
<!-- Check for .editorconfig, Directory.Build.props, and Roslyn analyser rules. Reference them here so AI tools respect toolchain-enforced conventions. -->

### Architecture
- Dependency direction: inward only. API → Application → Domain. Never the reverse.
- Domain layer has zero external dependencies.

### Naming
- Classes: PascalCase. Interfaces: `I` prefix. Async methods: `Async` suffix.
- Files match class names exactly. One public class per file.

### Dependency Injection
- **DIP (see the framework rules (`.github/instructions/framework-rules.instructions.md` › SOLID))**: derive a .NET service seam, registration, and lifetime from first-party project evidence and correctness needs. Do not introduce an interface or DI container solely from this default; preserve an evidenced dependency boundary. Data carriers (DTOs, entities, value objects, `Options`) are not services and get no interface.
- **Mechanism**: when project evidence selects a .NET DI seam, follow the established composition root, lifetime, and interface shape; this framework selects none of those mechanisms.
- Where the project already evidences DI, follow its established lifetime and composition-root conventions; this default does not choose scoped, transient, or singleton.
- Follow the project’s evidenced composition-root location and registration mechanism; do not select extension methods or `Program.cs` from this default.
- Use an options/configuration mechanism only where the project evidences it; do not select `IOptions<T>`, `IOptionsMonitor<T>`, or `IOptionsSnapshot<T>` solely from this default.

## Evidence-matched data-access defaults

### Data Access
Data-access defaults are conditional on what the repo evidences in csproj package references or repo artifacts such as SQL project/source trees. Apply only the matching block; if none match, ask.

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

**If raw SQL / stored procedures (`.sql` source tree, SQL project such as SSDT `.sqlproj`, migration-script folders, Dapper over procs):**
- Parameterized statements only; never concatenate input into SQL.
- Prefer set-based statements over row-by-row loops (cursors/WHILE) unless the surrounding code deliberately does otherwise.
- Schema-qualify object names; follow the repo's existing naming for tables and procedures.
- Every schema change goes through the repo's one deployment vehicle (SQL project build or migration scripts) — never ad-hoc.

**If data-warehouse signals (staging/dim/fact schemas or `Dim*`/`Fact*` tables, load procs, batch/watermark control tables):**
- Follow the existing load pattern exactly — one warehouse, one loading style; never introduce a second.
- Loads are idempotent and re-runnable: use the repo's control mechanism (watermarks, batch/load ids, partition switch, versioned runs) — never load the same data twice, and a rerun after a failed run must be safe.
- Load dimensions before the facts that reference them; apply the slowly-changing-dimension type each dimension already uses.
- Use the `map-warehouse` skill to understand the warehouse before changing it, and `add-warehouse-load` to add or extend a load.
- The map lives in `docs/warehouse-map.md`, indexed by a one-line pointer in AGENTS.md > Conventions > Data Access — the same detail-on-demand split as Architecture Decisions. **Read the map before writing a warehouse query**, not only before changing a load: it carries the fact → dimension relationships, which key reaches which dimension, and the confidence in each. Reach an attribute by following a fact key to the dimension that owns it — never off a same-named column that happens to sit on a table already in the join, and never assume a relationship from a naming convention. If the map marks an edge `UNRESOLVED`, copy an existing reporting view's join path or ask; do not guess.
- T-SQL examples apply only where the repo evidences SQL Server (`.sqlproj`, `Microsoft.Data.SqlClient`, T-SQL syntax in `.sql` files).

**If none detected:**
- For greenfield work, ask the developer before introducing a data-access stack.

## .NET application defaults (continued)

### API Design
- Controllers are thin — delegate at an evidenced project boundary. Minimal APIs are acceptable for simple endpoints if the project uses them.
- Request/response DTOs are separate from domain entities. Never expose domain models in API contracts.
- Use FluentValidation for request validation. No validation logic in controllers.
- Background work uses `BackgroundService` or `IHostedService`. No `Task.Run` fire-and-forget in request handlers.

### Async
- Preserve extension compatibility; propagate `CancellationToken` only when outcome or compatibility requires it.
- No `async void`. No sync-over-async. No fire-and-forget without explicit justification.

### Null Handling
- Nullable reference types enabled project-wide. No suppression (`!`) without a comment explaining why.
- Guard clauses at public API boundaries. Trust internal code.

### Logging
- Structured logging only (no string interpolation in log messages).
- Use `LoggerMessage` source generators for hot paths.

### Testing
Test-framework defaults are conditional on what the repo already evidences. Detect first, then apply
the matching block.

**Detect** — read the test projects' `.csproj` package references:
`xunit*` → xUnit · `NUnit` / `NUnit3TestAdapter` → NUnit · `MSTest.TestFramework` → MSTest.
Mocking: `NSubstitute` · `Moq` · `FakeItEasy`. Assertions: `FluentAssertions` · `Shouldly` · built-in.

**If a test suite already exists (any framework):**
- Mirror it — the runner, mocking library, assertion library, naming convention, and base
  fixtures/builders already in use.
- Do not introduce a second test framework alongside it. If the existing one is genuinely wrong for
  the job, raise it in `TECH_DEBT.md` and get a human decision rather than migrating as a side effect
  of adding tests.

**If no test suite exists anywhere in the repository (greenfield only):**
- Do not create a harness as an incidental side effect of feature, fix, refactor, or debt work.
- When establishing tests is explicitly in scope, use the `add-tests` skill to propose the smallest
  harness and first risk-first tests; get agreement before adding a framework.
- Prefer a few tests for consequential branching, boundaries, and regressions over one test per
  public member. Test observable behavior, not implementation details.

### Test shape
Choose the level by what the test actually exercises — *push each test to the lowest level that still runs real behavior; test at the boundary, not the mock.* A heuristic, not a fixed ratio; `/bootstrap` replaces it with the shape your codebase warrants.
- Domain / application logic (rules, calculations, branching, validation) → unit-dense.
- Cross-cutting paths (routing, model binding, data access, auth, serialization) → use the
  repository's established integration boundary (for example `WebApplicationFactory`, or a
  test-owned database for data access, where already evidenced); exercise the real pipeline, don't
  invent or over-mock it.
- Structured outputs (reports, exports, generated files, mapped rows) → a checked-in expected-output
  file built from a small curated input, scrubbed and small enough to read in review; re-accepting
  it is an assertion edit.
- Critical journeys → a sparse top layer of full-stack behavioral checks. Few, high-value.
- Boundary-heavy / gateway services → weight toward integration (honeycomb / risk-based), not unit.
- Anti-shape: the inverted suite (mostly slow end-to-end tests over a thin unit base). Slow + flaky = wrong shape.

### Test determinism
- Tests must be deterministic and hermetic: no real network, clock, randomness, shared database or environment, filesystem beyond checked-in fixture files, or inter-test order dependence. A database the test owns and resets per run is hermetic, but slower: keep it for risks that live in the engine. An intermittently-failing test is worse than none — it trains the team to ignore red.
- Pin time behind an abstraction (`TimeProvider` / injected clock); seed or stub randomness; isolate state between tests.

---

## Angular defaults (only when Angular application markers exist)

### Angular Version & Tooling
These defaults cover Angular v21 and v22, the current major and the one before it as of 2026-10 (support status:
angular.dev/reference/releases); a rule that differs between them names the major.
<!-- Check angular.json, package.json, tsconfig.json. Record the major; the change-detection provider
     (zoneless by default from v21, or `provideZoneChangeDetection` where the app keeps zone.js); the build
     builder (`:application` is current, the webpack `:browser` builder is deprecated); the test builder and
     runner (`@angular/build:unit-test` runs Vitest unless its `runner` names another, `@angular/build:karma`
     runs Karma/Jasmine) and whether the test build loads zone.js; `strict` and `strictTemplates`; and any
     non-standard config. -->

### Build & Test Commands
Record the exact Angular build, test, and lint commands only when the repository evidences them in
CI, scripts, `package.json`, workspace targets, or configuration. Angular presence does not prove a
particular runner, browser, lint target, or flag set; unavailable categories remain `not available`.

### Architecture
- New components, directives and pipes are standalone (the default since v19). Mirror NgModule declarations only where a file or feature already uses them.
- New code injects with `inject()`. Mirror constructor injection only in a file that already uses it; do not mix the two styles in one file.
- **DIP (see the framework rules (`.github/instructions/framework-rules.instructions.md` › SOLID))**: derive an Angular service seam and registration from first-party project evidence and correctness needs. Do not introduce an abstraction, token, or DI container solely from this default; preserve an evidenced dependency boundary. Data carriers (models, DTOs, enums) are not services and get no abstraction.
- **Mechanism**: when project evidence selects an Angular DI seam, follow the established token/registration mechanism and shape; this framework selects none of those mechanisms.
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
