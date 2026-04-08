Analyse this .NET codebase and set up the AI Tech Lead framework. This is the one-time bootstrap that makes the repo AI-ready.

## Input
$ARGUMENTS

Execute all phases below in sequence. Do not skip any phase. Do not ask for confirmation between phases — run the full pipeline.

---

## Pre-flight checks

Before starting analysis:
1. **Locate the solution root** — find the `.sln` file. All paths are relative to this root. If the `.sln` is in a subdirectory (e.g., `src/`), note this and adjust paths in generated output.
2. **Check .NET version** — read `<TargetFramework>` from csproj files and check for `global.json`. Note whether it's .NET 6/7/8/9. Adjust conventions accordingly (e.g., minimal APIs from .NET 6+, primary constructors from .NET 8+, `required` keyword from C# 11+). Also check for `Directory.Build.props` — it affects build and analyser behaviour across the entire solution.
3. **Check for existing configuration** — if `CLAUDE.md` already has populated content (not just template defaults), back up the existing conventions section and merge your findings with what's already there rather than overwriting. Preserve any entries in the "What We've Learned" section.
4. **Large codebases** — if the solution has more than 30 projects, focus analysis on the most actively changed projects (check git log). Note which projects were analysed and which were skipped.

---

## Phase 1 — Analysis

Perform six analysis passes. For each, observe and record findings internally. Do not output analysis results to the user — they feed Phase 2.

### A1: Solution Architecture
- Solution and project layout (how many projects, their types, responsibilities)
- Layering strategy (API, domain, application, infrastructure, shared)
- Dependency direction between projects (do dependencies flow inward correctly?)
- Entry points (API controllers, background services, middleware pipeline)
- Configuration approach (appsettings, options pattern, environment-specific config)

### A2: Domain & Data Access
- Domain entity structure (rich models or anaemic?)
- ORM in use (EF Core, Dapper, both) and DbContext organisation
- Repository pattern usage (adding value or wrapping EF Core unnecessarily?)
- Migration management
- Query patterns (queries in controllers vs properly separated?)
- N+1 risks, missing includes, untracked query opportunities

### A3: Dependency Injection & Services
- Service registration approach (individual, by convention, extension methods)
- Service lifetimes (scoped/transient/singleton used correctly? Lifetime mismatches?)
- Interface usage (meaningful or ceremony?)
- Cross-cutting concerns (logging, validation, exception handling)
- MediatR/CQRS if present — how consistently applied

### A4: API Design & Middleware
- Controller design (thin or fat?)
- Request/response models (separated from domain entities?)
- Validation approach (data annotations, FluentValidation, manual)
- Error handling strategy (middleware, exception filters, try-catch in controllers)
- Authentication and authorisation setup
- API versioning
- Middleware pipeline order

### A5: Testing
- Test projects, frameworks (xUnit, NUnit, MSTest), mocking framework
- What's tested vs not — biggest gaps
- Test quality — testing behaviour or implementation details?
- Integration tests — WebApplicationFactory usage?
- Test fixtures, builders, helpers

### A6: Code Quality & Dependencies
- Async/await hygiene (sync-over-async, async void, missing CancellationToken)
- Null handling (nullable reference types enabled? Consistent?)
- Exception handling patterns
- Logging (structured? Consistent levels? Sensitive data?)
- NuGet dependencies (outdated, deprecated, redundant?)
- .NET version currency

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
- **Solution Structure**: actual project layout with dependency diagram
- **Conventions**: the rules this codebase actually follows (or should follow), with rationale. Keep the subsection structure (Architecture, Naming, DI, Data Access, API, Async, Null Handling, Logging, Testing). Replace template defaults with observed reality.
- **Architecture Decisions**: every significant decision found — intentional or accidental. Include context, consequences, and honest review notes.
- **Common Tasks**: real patterns from this codebase for adding endpoints, entities, services
- **Boy Scout Rule**: priority improvements based on the actual debt found in Phase 2

Preserve the Agentic Workflow and What We've Learned sections as-is.

### 3b: Generate TECH_DEBT.md

Create TECH_DEBT.md in the project root with this structure:

```markdown
# Tech Debt Register

| ID | Category | Severity | Files Affected | Issue | Recommended Fix | Effort |
|----|----------|----------|----------------|-------|-----------------|--------|
```

Categories: Architecture, Data Access, DI/Lifetime, API Design, Async, Testing, Types/Nullability, Performance, Dependencies, Security
Severity: Critical / High / Medium / Low
Effort: S (< 1hr) / M (half day) / L (1-2 days) / XL (needs spike)

Sort by severity then effort.

Add a "Trojan Horse Opportunities" section grouping debt items by feature area, so developers can bundle cleanup into feature work.

### 3c: Generate copilot-instructions.md

Read the now-populated CLAUDE.md. Generate `.github/copilot-instructions.md` as a full derivative:

- Start with: "When generating code in this repo, always follow these rules:"
- Convert every convention, rule, and pattern from CLAUDE.md into imperative instructions
- Include all sections: architecture, naming, DI, data access, API, async, null handling, logging, testing, boy scout rule, documentation maintenance
- Imperative voice throughout
- Keep every point scannable — one to two lines max
- Include the documentation maintenance rules:
  - New pattern → flag CLAUDE.md needs updating
  - Convention changed → flag CLAUDE.md needs updating
  - Tech debt resolved → flag TECH_DEBT.md entry for removal
  - New tech debt found → flag TECH_DEBT.md needs new entry
  - Implementation contradicts instructions → ask whether to update convention or change implementation

---

## Phase 4 — Report

Run `git diff CLAUDE.md` and `git diff TECH_DEBT.md` to show the user exactly what changed. Present the diff summary before the rest of the report.

Then output:
- Number of findings per severity
- Top 3 architectural risks
- Top 3 quick wins
- Files generated/modified

**Important**: remind the user to review the generated `CLAUDE.md` before using any other commands. The conventions in that file drive everything else — if they're wrong, every command will follow wrong rules.
