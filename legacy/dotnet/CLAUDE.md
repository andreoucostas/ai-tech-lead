<!--
ai-tech-lead-framework
  template: dotnet
  version: 0.7.0
  applied: 2026-04-29
  When you sync template updates, bump these fields and update .claude/framework-version.json.
-->
# [Project Name]

> This file is the single source of truth for AI-assisted development in this repository.
> It is automatically loaded by Claude Code, by GitHub Copilot's coding agent and CLI, and by any AGENTS.md-aware tool (Codex, Cursor, Aider).
> Run `/bootstrap` to populate it from your actual codebase.
>
> **Companion file**: [FRAMEWORK-CONTEXT.md](./FRAMEWORK-CONTEXT.md) holds cross-repo context (shared libraries, multi-tenancy conventions, dashboard contracts) that the agent should also load on every non-trivial task. CLAUDE.md wins on any conflict — but flag the contradiction.
>
> **Per-developer working preferences** (e.g. "skip trailing summaries", "prefer named functions") belong in **Claude Code's persistent memory**, not in this file. Use phrasings like "remember to do X" during sessions; CLAUDE.md is for repo-shared conventions only.

---

## Verification Rules

These apply to every workflow, before any convention-level rule. The difference between confident output and hallucinated output.

1. **Verify before you reference.** Before naming a class, method, file, route, NuGet package, namespace, or DI registration extension, confirm it exists in this codebase via `Read` / `Grep`. If you cannot confirm, say so explicitly rather than guessing.
2. **Never invent APIs.** Do not fabricate method signatures, type names, attributes, package exports, or framework features. Read the source. If a referenced shared-library API is not in `FRAMEWORK-CONTEXT.md > Detected Framework Packages` at the version this repo pins, treat it as unverified.
3. **Honour version pinning.** Before suggesting a feature from a shared library, framework, or `Microsoft.*` package, confirm the version in `FRAMEWORK-CONTEXT.md > Detected Framework Packages` actually has it. The latest API surface in `Shared Libraries` may not exist in older versions.
4. **State uncertainty.** When a question depends on context you do not have (a file you have not read, runtime behaviour you cannot observe, a database state you cannot query), say so. Do not guess to seem helpful.
5. **Tests are immutable safety nets during fixes and refactors.** When an existing test fails, production is wrong (or the test is wrong for a documented reason). Do not edit assertions to make them pass without flagging it explicitly.
6. **No invented fixtures.** When sample data, builders, factories, or mocks already exist, reuse them. Do not fabricate parallel ones.
7. **Failures are signals.** Build, test, or analyser failures are diagnostic. Read the message and fix the cause; never wrap in try/catch or `#pragma warning disable` to silence.
8. **No future-proofing.** Do not add code for hypothetical requirements. Three similar lines is better than a premature abstraction.

---

## Leanness

The Boy Scout Rule biases toward adding improvements. This section is the counterweight: every change should also consider what to remove or what not to introduce. Bloat is not a stylistic preference — it is the highest-cost long-term failure mode of AI-assisted development.

### Defaults

1. **Edit existing files; do not create new ones unless required.** A new file is a long-term commitment. If a method fits an existing file, put it there.
2. **No interface unless there will be a second implementation.** Sealed classes are fine. "I might mock it" is not a second implementation — `NSubstitute` and equivalents work on virtual methods of concrete classes.
3. **No abstract base class with one subclass.** Inline it.
4. **Wrappers must add behavior.** A method that just delegates is a layer that costs reading time and adds no value. Inline or remove.
5. **No defensive code for impossible states.** Trust internal callers; validate only at system boundaries (HTTP request body, message bus payload, third-party API response). **Financial domain exception**: for monetary amounts, ledger entries, account balances, regulatory figures, and idempotency keys — treat every state as possible regardless of caller. Use `decimal` (never `double`) for money; guard against negative amounts, duplicate transaction IDs, decimal precision loss, and timestamp ordering violations at every layer even in internal code.
6. **No `try/catch` to silence; only to handle.** If you cannot say what the catch block does for the user, do not write it.
7. **No comments that restate code.** A comment earns its place only when it captures a non-obvious *why* (constraint, invariant, workaround). XML doc comments on public APIs are an exception when the project ships them.
8. **No new generic helpers / utility classes without two existing call sites.** Three similar lines beat a premature abstraction.
9. **Deletion is a contribution.** If a change makes existing code obsolete, delete it in the same PR. Comment-out is never the answer; that is what version control is for.
10. **No re-exports through barrel files unless the barrel already exports adjacent symbols.** Do not grow the public surface for free.

### Test leanness

11. **Do not test getters, setters, or trivial constructors.** Test behavior, not assignment.
12. **Do not test the framework.** No tests that DI resolves, that EF Core can read its own writes, that ASP.NET model-binding parses an int.
13. **Reuse existing builders / fixtures.** Do not introduce parallel test data unless the existing builders cannot represent the case.

### When you must add structure

If a change genuinely requires a new abstraction, file, or wrapper, state the second consumer (existing or imminent) in the design or PR description. "Imminent" means within the same change-set. Otherwise: defer the abstraction until the second case appears.

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

<!-- BOOTSTRAP_PENDING: run /bootstrap to replace this entire section with conventions observed in the actual codebase. -->
<!-- Until /bootstrap runs, defer to docs/defaults.md for greenfield .NET conventions. -->
<!-- Each convention: the rule, then 1-2 sentence rationale. -->

_Not yet populated. Until you run `/bootstrap`, the greenfield defaults in [docs/defaults.md](./docs/defaults.md) apply. After bootstrap, this section becomes the authoritative source._

---

## Architecture Decisions

<!-- Populated by /bootstrap — replaces separate ADR files -->
<!-- Format: Decision → Context → Consequences → Review notes -->

Record significant decisions here. Include accidental decisions that became convention.

---

## Common Tasks

Recipes live in `.claude/skills/` — each is auto-discovered by Claude Code and triggered by the model when relevant. Current skills:

- `add-endpoint` — add a new HTTP API endpoint end-to-end (domain → service → DTO → validator → controller → integration test)
- `add-entity` — add a new EF Core entity with configuration and migration review
- `register-service` — register a new service in DI with the right lifetime
- `perf` — scan a file, directory, or the whole repo for ~50 performance anti-patterns; produces tiered findings (Critical / Moderate / Info) with file locations and TECH_DEBT.md integration

`/bootstrap` adds project-specific skills under `.claude/skills/` rather than appending recipes here.

**Registers**: [TECH_DEBT.md](./TECH_DEBT.md) tracks delivery debt. [SECURITY_FINDINGS.md](./SECURITY_FINDINGS.md) tracks security findings separately with remediation SLAs (Critical = 7 days, High = 30 days). Do not merge them — audit teams treat these differently. AI-assisted file changes are appended to [.claude/ai-audit.log](./.claude/ai-audit.log) automatically by the PostToolUse hook.

---

## Boy Scout Rule

When touching any file, leave it cleaner than you found it. The rule is symmetric: improvements *add* missing pieces and *remove* dead weight. Deletion is a contribution.

### Always apply (low-effort, low-risk — do these on every touched file):

**Add:**
1. Missing `CancellationToken` propagation
2. Replace string-interpolated log messages with structured logging
3. Missing null checks at public boundaries
4. Missing `.AsNoTracking()` on read-only queries

**Subtract:**
5. Unused `using` directives
6. Commented-out code blocks (more than 1 line — version control preserves them)
7. Unreferenced private fields, methods, or local variables that the IDE/compiler flags

### Apply only when the file is the primary target of the change:

**Add:**
8. Split fat methods (>30 lines) into focused private methods
9. Missing unit tests for public methods you're modifying

**Subtract:**
10. Inline single-consumer interfaces or abstract bases (per Leanness)
11. Collapse shallow delegate methods that add no behavior beyond calling another component
12. Single-use private helpers — inline at the call site

Items 8–12 can significantly expand or reshape a diff. Only apply them when the file is what the task is specifically about, not when it's incidentally touched. This keeps PRs focused and reviewable.

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
- A SECURITY_FINDINGS.md entry was resolved or a new finding discovered
- copilot-instructions.md needs regeneration (run `/generate-copilot` in Claude Code, or ask your agent to rewrite it from this file following the rules in `.claude/commands/generate-copilot.md`)

---

## What We've Learned

Long-form learnings live in [LEARNINGS.md](./LEARNINGS.md). Read it when starting non-trivial work; append to it (don't overwrite) when you discover what works, what causes friction, or what rule needs adjusting.
