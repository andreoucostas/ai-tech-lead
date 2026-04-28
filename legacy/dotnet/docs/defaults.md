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
