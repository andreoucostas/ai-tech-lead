<!--
ai-tech-lead-framework
  template: angular
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

1. **Verify before you reference.** Before naming a component, service, route, npm package, module, or signal/store, confirm it exists in this codebase via `Read` / `Grep`. If you cannot confirm, say so explicitly rather than guessing.
2. **Never invent APIs.** Do not fabricate selectors, decorators, RxJS operators, package exports, or framework features. Read the source. If a referenced shared-library API is not in `FRAMEWORK-CONTEXT.md > Detected Framework Packages` at the version this repo pins, treat it as unverified.
3. **Honour version pinning.** Before suggesting a feature from `@angular/*`, RxJS, or a shared library, confirm the version in `FRAMEWORK-CONTEXT.md > Detected Framework Packages` actually has it. Signals, control flow, `inject()`, `takeUntilDestroyed()` are all version-gated. The latest API surface in `Shared Libraries` may not exist in older versions.
4. **State uncertainty.** When a question depends on context you do not have (a file you have not read, runtime behaviour you cannot observe, a backend response shape you cannot verify), say so. Do not guess to seem helpful.
5. **Tests are immutable safety nets during fixes and refactors.** When an existing spec fails, production is wrong (or the test is wrong for a documented reason). Do not edit assertions to make them pass without flagging it explicitly.
6. **No invented fixtures.** When sample data, builders, factories, or HTTP mocks already exist, reuse them. Do not fabricate parallel ones.
7. **Failures are signals.** `tsc` errors, lint errors, and test failures are diagnostic. Read the message and fix the cause; never `// @ts-ignore`, `as any`, or comment-out to silence.
8. **No future-proofing.** Do not add code for hypothetical requirements. Three similar lines is better than a premature abstraction.

---

## Leanness

The Boy Scout Rule biases toward adding improvements. This section is the counterweight: every change should also consider what to remove or what not to introduce. Bloat is not a stylistic preference — it is the highest-cost long-term failure mode of AI-assisted development.

### Defaults

1. **Edit existing files; do not create new ones unless required.** A new file is a long-term commitment. If a method fits an existing service or component, put it there.
2. **No interface unless there will be a second implementation.** "I might mock it" is not a second implementation — Angular's testing utilities work on concrete classes via DI overrides.
3. **No abstract base class with one subclass.** Inline it.
4. **Wrappers must add behavior.** A service whose method just calls `httpClient.get(...)` and returns the observable is a layer that costs reading time and adds no value. Inline or remove.
5. **No defensive code for impossible states.** Trust internal callers; validate only at system boundaries (form input, HTTP response, route params).
6. **No `catchError` to silence; only to recover.** If you cannot say what the recovery returns to the stream, do not write it. Letting an error reach the global error handler is a valid choice.
7. **No comments that restate code.** A comment earns its place only when it captures a non-obvious *why* (constraint, invariant, workaround).
8. **No new utility helpers / pipes / directives without two existing call sites.** Three similar template expressions beat a premature pipe.
9. **Deletion is a contribution.** If a change makes existing code obsolete, delete it in the same PR. Comment-out is never the answer; that is what version control is for.
10. **No re-exports through `index.ts` barrels unless the barrel already exports adjacent symbols.** Do not grow the public surface for free. Internal-only files do not need exports at all.

### Test leanness

11. **Do not test getters, setters, or trivial signals.** Test behavior, not assignment.
12. **Do not test the framework.** No tests that `@Input` decorators bind, that `Router.navigate` works, that change detection runs.
13. **Reuse existing test fixtures and HTTP mocks.** Do not introduce parallel test data unless existing fixtures cannot represent the case.

### When you must add structure

If a change genuinely requires a new abstraction, component, service, or pipe, state the second consumer (existing or imminent) in the design or PR description. "Imminent" means within the same change-set. Otherwise: defer the abstraction until the second case appears.

---

## Codebase Context

<!-- Populated by /bootstrap — do not fill manually -->

What this application does, who uses it, key domain concepts, and critical user journeys.

---

## Repository Structure

<!-- Populated by /bootstrap — replaces separate CODEMAP.md -->

Top-level folder layout, feature module boundaries, shared/core module contents, routing structure, and where to put new code.

Include a text or mermaid diagram showing the module dependency graph.

---

## Conventions

<!-- BOOTSTRAP_PENDING: run /bootstrap to replace this entire section with conventions observed in the actual codebase. -->
<!-- Until /bootstrap runs, defer to docs/defaults.md for greenfield Angular 17+ conventions. -->
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

- `add-component` — add a new Angular feature component end-to-end
- `add-service` — add an HTTP / business-logic / signal-store service
- `add-lazy-route` — add a lazy-loaded route with optional guards/resolvers
- `add-signal-store` — add a signal-based shared-state store

`/bootstrap` adds project-specific skills under `.claude/skills/` rather than appending recipes here.

---

## Boy Scout Rule

When touching any file, leave it cleaner than you found it. The rule is symmetric: improvements *add* missing pieces and *remove* dead weight. Deletion is a contribution.

### Always apply (low-effort, low-risk — do these on every touched file):

**Add:**
1. Replace manual `ngOnDestroy` subscription cleanup with `takeUntilDestroyed()`
2. `ChangeDetectionStrategy.OnPush` if missing
3. Replace nested `.subscribe()` with the appropriate RxJS operator
4. Replace `any` with proper types

**Subtract:**
5. Unused TypeScript imports and unused RxJS operator imports
6. Commented-out code or template blocks (more than 1 line — version control preserves them)
7. Unreferenced private fields, methods, or local variables that `tsc`/lint flags
8. Unused `@Input` / `@Output` properties

### Apply only when the file is the primary target of the change:

**Add:**
9. Replace manual `.subscribe()` with `async` pipe where possible
10. Extract complex template expressions into component methods or pipes

**Subtract:**
11. Inline single-consumer interfaces or abstract bases (per Leanness)
12. Collapse shallow service methods that just delegate to `HttpClient` with no transformation
13. Single-use pipes or directives — inline at the call site, or convert to a component method
14. Unused barrel re-exports in `index.ts`

Items 9–14 can significantly expand or reshape a diff. Only apply them when the file is what the task is specifically about, not when it's incidentally touched. This keeps PRs focused and reviewable.

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
1. Models/interfaces and service layer + tests
2. State management changes (store/signals/service) + tests
3. Component implementation + tests
4. E2E or integration verification

Each subtask must leave the codebase compilable and test-passing.
Run `ng build` and `ng test --watch=false --browsers=ChromeHeadless` after each subtask. Fix failures before moving on.

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

Long-form learnings live in [LEARNINGS.md](./LEARNINGS.md). Read it when starting non-trivial work; append to it (don't overwrite) when you discover what works, what causes friction, or what rule needs adjusting.
