# Greenfield Conventions — .NET Defaults

> Reference defaults for a modern .NET solution. These apply only when CLAUDE.md > Conventions has not been populated by `/bootstrap`.
> Once `/bootstrap` runs, CLAUDE.md > Conventions is the authoritative source — these defaults are for cold-start scaffolding only.

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
- EF Core with repository pattern only where it adds value (not wrapping DbContext for the sake of it).
- Queries belong in the application/service layer, not in controllers.
- Always use `.AsNoTracking()` for read-only queries.

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
- Every public behavior has a test. Test behavior, not implementation details.
- Unit tests use xUnit + NSubstitute (or project's chosen stack).
- Integration tests use `WebApplicationFactory`.
- Test naming: `MethodName_Scenario_ExpectedResult`.

### Test shape
Choose the level by what the test actually exercises — *push each test to the lowest level that still runs real behavior; test at the boundary, not the mock.* A heuristic, not a fixed ratio; `/bootstrap` replaces it with the shape your codebase warrants.
- Domain / application logic (rules, calculations, branching, validation) → unit-dense.
- Cross-cutting paths (routing, model binding, EF Core, auth, serialization) → integration via `WebApplicationFactory`; exercise the real pipeline, don't mock it.
- Critical journeys → a sparse top layer of full-stack behavioral checks. Few, high-value.
- Boundary-heavy / gateway services → weight toward integration (honeycomb / risk-based), not unit.
- Anti-shape: the inverted suite (mostly slow end-to-end tests over a thin unit base). Slow + flaky = wrong shape.

### Test determinism
- Tests must be deterministic and hermetic: no real network, clock, randomness, filesystem, or inter-test order dependence. An intermittently-failing test is worse than none — it trains the team to ignore red.
- Pin time behind an abstraction (`TimeProvider` / injected clock); seed or stub randomness; isolate state between tests.
