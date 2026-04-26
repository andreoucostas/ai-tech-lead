# [Project Name]

> This file is the single source of truth for AI-assisted development in this repository.
> It is automatically loaded by Claude Code, by GitHub Copilot's coding agent and CLI, and by any AGENTS.md-aware tool (Codex, Cursor, Aider).
> Run `/bootstrap` to populate it from your actual codebase.
>
> **Per-developer working preferences** (e.g. "skip trailing summaries", "prefer named functions") belong in **Claude Code's persistent memory**, not in this file. Use phrasings like "remember to do X" during sessions; CLAUDE.md is for repo-shared conventions only.

---

## Codebase Context

<!-- Populated by /bootstrap — do not fill manually -->

What this application does, who uses it, key domain concepts, and critical user journeys.

---

## Repository Structure

<!-- Populated by /bootstrap — replaces separate CODEMAP.md -->

Project layout, layering strategy, dependency direction between projects, entry points, and where to put new code.

Include a text or mermaid diagram showing project dependencies.

---

## Conventions

<!-- Populated by /bootstrap — replaces separate CONVENTIONS.md -->
<!-- Each convention: the rule, then 1-2 sentence rationale -->

> **DEFAULTS BELOW.** Everything in this section is a starting template. When you run
> `/bootstrap`, these are replaced with conventions observed in your actual codebase.
> If you haven't run `/bootstrap` yet, do not treat these as authoritative.

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

---

## Architecture Decisions

<!-- Populated by /bootstrap — replaces separate ADR files -->
<!-- Format: Decision → Context → Consequences → Review notes -->

Record significant decisions here. Include accidental decisions that became convention.

---

## Common Tasks

### Add a new API endpoint end-to-end
1. Domain entity/value object (if new)
2. Application service method + interface
3. Request/response DTOs
4. FluentValidation validator for the request
5. Controller action (thin — delegates to service)
6. Unit tests for service logic
7. Integration test via WebApplicationFactory

### Add a new EF Core entity
1. Entity class in domain layer
2. Configuration class (`IEntityTypeConfiguration<T>`)
3. Add `DbSet<T>` to DbContext
4. Generate migration: `dotnet ef migrations add MigrationName`
5. Review generated migration SQL before applying

### Register a new service
1. Create interface + implementation
2. Add registration in the project's DI extension method
3. Inject via constructor — never resolve from `IServiceProvider` directly

---

## Boy Scout Rule

When touching any file, apply these improvements if they exist.

### Always apply (low-effort, low-risk — do these on every touched file):

1. Add missing `CancellationToken` propagation
2. Replace string-interpolated log messages with structured logging
3. Add missing null checks at public boundaries
4. Add missing `.AsNoTracking()` to read-only queries

### Apply only when the file is the primary target of the change:

5. Split fat methods (>30 lines) into focused private methods
6. Add missing unit tests for public methods you're modifying

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
1. Domain/model layer changes + tests
2. Service/application layer changes + tests
3. API/controller layer changes + tests
4. Integration test covering the full flow

Each subtask must leave the codebase compilable and test-passing.
Run `dotnet build` and `dotnet test` after each subtask. Fix failures before moving on.

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
- copilot-instructions.md needs regeneration (run `/generate-copilot` in Claude Code, or ask your agent to rewrite it from this file following the rules in `.claude/commands/generate-copilot.md`)

---

## What We've Learned

<!-- This section evolves over time. Add entries when you discover what works and what doesn't. -->
<!-- Format: [date] observation -->

_No entries yet. As the team uses this framework, record what works, what causes friction, and what rules need adjusting._
