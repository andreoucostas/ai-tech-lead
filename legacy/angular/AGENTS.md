<!-- GENERATED FILE — do not edit by hand.
     This is a mirror of CLAUDE.md's portable rule sections, emitted by `/generate-copilot`.
     Canonical source: CLAUDE.md. If the two disagree, CLAUDE.md wins and THIS file is stale —
     regenerate it: run `/generate-copilot` in Claude Code, or ask your agent to rewrite it from
     CLAUDE.md following `.claude/commands/generate-copilot.md`. `/docs-sync` flags drift between them. -->

# Agent Instructions

This repository follows the AI Tech Lead Framework. **`CLAUDE.md` is the canonical source of truth.**

This file exists because **GitHub Copilot (agent mode & CLI), Codex, Cursor, Gemini CLI, Aider, and other tools read `AGENTS.md` natively** — so the portable rules are mirrored here in full rather than behind a pointer. Claude Code reads `CLAUDE.md` directly and ignores this file.

For project narrative **not** duplicated here — **Codebase Context, Repository Structure, Architecture Decisions** — read [CLAUDE.md](./CLAUDE.md). For cross-repo context (shared libraries, multi-tenancy, dashboard contracts) read [FRAMEWORK-CONTEXT.md](./FRAMEWORK-CONTEXT.md). CLAUDE.md wins on any conflict; flag the contradiction.

---

## Verification Rules

These apply to every workflow, before any convention-level rule. The difference between confident output and hallucinated output.

1. **Verify before you reference.** Before naming a component, service, route, npm package, module, or signal/store, confirm it exists in this codebase via `Read` / `Grep`. If you cannot confirm, say so explicitly rather than guessing.
2. **Never invent APIs.** Do not fabricate selectors, decorators, RxJS operators, package exports, or framework features. Read the source. If a referenced shared-library API is not in `FRAMEWORK-CONTEXT.md > Detected Framework Packages` at the version this repo pins, treat it as unverified.
3. **Honour version pinning.** Before suggesting a feature from `@angular/*`, RxJS, or a shared library, confirm the version in `FRAMEWORK-CONTEXT.md > Detected Framework Packages` actually has it. Signals, control flow, `inject()`, `takeUntilDestroyed()` are all version-gated. The latest API surface in `Shared Libraries` may not exist in older versions.
4. **State uncertainty.** When a question depends on context you do not have (a file you have not read, runtime behaviour you cannot observe, a backend response shape you cannot verify), say so. Do not guess to seem helpful.
5. **Tests are immutable safety nets during fixes and refactors.** When an existing spec fails, production is wrong (or the test is wrong for a documented reason). Do not edit assertions to make them pass without flagging it explicitly.
6. **No invented fixtures.** When sample data, builders, factories, or HTTP mocks already exist, reuse them. Do not fabricate parallel ones.
7. **Failures are signals.** `tsc` errors, lint errors, and test failures are diagnostic. Read the message and fix the cause; never `// @ts-ignore`, `as any`, or comment-out to silence. (A PreToolUse hook hard-blocks writes that add `// eslint-disable` / `@ts-ignore` / `@ts-nocheck`.)
8. **No future-proofing.** Do not add code for hypothetical requirements. Three similar lines is better than a premature abstraction.

---

## Leanness

The Boy Scout Rule biases toward adding improvements. This section is the counterweight: every change should also consider what to remove or what not to introduce. Bloat is not a stylistic preference — it is the highest-cost long-term failure mode of AI-assisted development.

### Defaults

1. **Edit existing files; do not create new ones unless required.** A new file is a long-term commitment. If a method fits an existing service or component, put it there.
2. **Abstractions are for injected services (SOLID/DIP) and for genuine second implementations — not for data.** Every injected service is provided through an `abstract class`/token (see [SOLID](#solid)). *Outside* that rule, no interface or abstraction without a real need — models/DTOs never get abstractions, and don't invent abstractions for hypothetical variation.
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

## SOLID

SOLID is **mandatory** in this codebase. It governs structure; [Leanness](#leanness) governs ceremony *beyond* that structure — reconciled here and in Leanness #2.

1. **Single Responsibility** — one reason to change. No god components/services; honour the smart/dumb split; split a component that mixes data access and presentation. Heuristic: more than ~5 injected collaborators, or a name needing "And"/"Manager", means split.
2. **Open/Closed** — extend by adding a type/strategy, not editing a stable one. When a `switch`/`if` over a type code reaches its **third** arm, replace it with polymorphism. (Don't build the seam speculatively before then — that is future-proofing.)
3. **Liskov Substitution** — every implementation fulfils its abstraction's contract: no `throw new Error('not implemented')`, no strengthened preconditions, no weakened postconditions.
4. **Interface Segregation** — small, role-based interfaces over one fat service contract; no implementation forced to stub members it doesn't use.
5. **Dependency Inversion** — **every injected service is depended on through an abstraction**: declare an `abstract class` (a runtime-capable DI token) — or an `interface` + `InjectionToken<T>` — and `provide` the concrete implementation; components/services inject the abstraction, never `new` a concrete service. Data carriers (models, DTOs, enums) are not services — they get no abstraction.

**Mechanism**: prefer `abstract class Foo` as the token with `{ provide: Foo, useClass: FooImpl }` (TypeScript `interface`s don't exist at runtime); use `interface` + `InjectionToken<T>` where an abstract class is awkward.

**Deterministic backstop**: module/layer dependency direction is enforced in CI by **dependency-cruiser** (or `eslint-plugin-boundaries`). The `solid-check` agent covers the semantic principles per diff and is run by `/review`. Scaffold it with the `enforce-architecture` skill.

---

## Conventions

<!-- Mirrored from CLAUDE.md > Conventions by /bootstrap. Until /bootstrap runs, the greenfield
     defaults in docs/defaults.md apply, and CLAUDE.md > Conventions remains authoritative. -->

_Project conventions are populated by `/bootstrap` into `CLAUDE.md > Conventions` and mirrored here. Until then, follow the greenfield defaults in [docs/defaults.md](./docs/defaults.md). `CLAUDE.md > Conventions` is authoritative if this section lags._

---

## Common Tasks

Recipes live as auto-discovered **skills**, available to both Claude Code (`.claude/skills/`) and GitHub Copilot (`.github/skills/`). The model triggers the relevant one when you describe that kind of task. Current skills:

- `add-component` — add a new Angular feature component end-to-end
- `add-service` — add an HTTP / business-logic / signal-store service
- `add-lazy-route` — add a lazy-loaded route with optional guards/resolvers
- `add-signal-store` — add a signal-based shared-state store
- `add-tests` — add tests following project patterns (Jasmine/Karma or Jest spec + HTTP mocks)
- `dependency-audit` — scan for vulnerable/outdated npm packages and wire up automated dependency scanning
- `create-adr` — record an architecture decision
- `enforce-architecture` — wire the deterministic DIP/layering CI gate (dependency-cruiser)

**Registers**: [TECH_DEBT.md](./TECH_DEBT.md) tracks delivery debt. AI-assisted file changes are appended to `.claude/ai-audit.log` automatically by the PostToolUse hook.

---

## Boy Scout Rule

When touching any file, leave it cleaner than you found it. The rule is symmetric: improvements *add* missing pieces and *remove* dead weight. Deletion is a contribution.

### Always apply (low-effort, low-risk — do these on every touched file):

**Add:**
1. Replace manual `ngOnDestroy` subscription cleanup with `takeUntilDestroyed()`
2. Replace nested `.subscribe()` with the appropriate RxJS operator
3. Replace `any` with proper types

**Subtract:**
4. Unused TypeScript imports and unused RxJS operator imports
5. Commented-out code or template blocks (more than 1 line — version control preserves them)
6. Unreferenced private fields, methods, or local variables that `tsc`/lint flags
7. Unused `@Input` / `@Output` properties

> **Not auto-applied: `ChangeDetectionStrategy.OnPush`.** Switching a component to `OnPush` is a semantic change, not a cleanup — treat it as an explicit, tested change when the component is the primary target, not a drive-by edit. New components scaffolded from skills still default to `OnPush`.

### Apply only when the file is the primary target of the change:

**Add:**
8. Replace manual `.subscribe()` with `async` pipe where possible
9. Extract complex template expressions into component methods or pipes
10. Add `ChangeDetectionStrategy.OnPush` — but only after verifying the component's data flow (immutable inputs, no in-place mutation, no reliance on ambient ticking) and after manual/test verification that the view still updates correctly.

**Subtract:**
11. Inline single-consumer interfaces or abstract bases (per Leanness)
12. Collapse shallow service methods that just delegate to `HttpClient` with no transformation
13. Single-use pipes or directives — inline at the call site, or convert to a component method
14. Unused barrel re-exports in `index.ts`

Items 8–14 can significantly expand or reshape a diff. Only apply them when the file is what the task is specifically about, not when it's incidentally touched.

**When to skip**: hotfixes, time-sensitive production incidents, and proof-of-concept branches. If skipping, add a comment `// TODO: Boy Scout skipped — [reason]` so it's picked up on the next pass. Use `/debt` to clean up later.

---

## Agentic Workflow

When given any task, follow this execution model. The seven workflows are also invokable explicitly as slash commands — in Claude Code from `.claude/commands/`, in Copilot Chat from `.github/prompts/` (same names).

1. **Classify the intent** — feature / fix / refactor / design / test / debt / review. If ambiguous, ask before proceeding.
2. **Plan before coding** — for any non-trivial task, list files to create/modify, the order of operations, and what tests verify success. State the plan, then execute. For larger features, persist a spec to `specs/<slug>.md` (see `/design`) and implement against it.
3. **Execute in verified subtasks** — decompose into ordered layers (models/services → state → component → integration). Run `ng build` and `ng test --watch=false --browsers=ChromeHeadless` after each; fix failures before moving on.
4. **Boy Scout every touched file** — apply the always-apply list above to every file you modify.
5. **Self-review before presenting** — review against `CLAUDE.md > Conventions`; verify build + tests pass; flag new patterns, resolved TECH_DEBT items, and any convention contradictions.
6. **Flag documentation drift** — note new patterns to document, TECH_DEBT changes, and whether `copilot-instructions.md` / this file need regeneration (`/generate-copilot`).

---

## Quick reference

- **Conventions, architecture, common tasks, boy-scout rules** (canonical): [CLAUDE.md](./CLAUDE.md)
- **Cross-repo context**: [FRAMEWORK-CONTEXT.md](./FRAMEWORK-CONTEXT.md)
- **Tech debt register**: [TECH_DEBT.md](./TECH_DEBT.md)
- **Inline-completion ruleset** (terse, editor autocomplete): [.github/copilot-instructions.md](./.github/copilot-instructions.md)
- **Skills** (Common Tasks recipes): [.github/skills/](./.github/skills/) (Copilot) · [.claude/skills/](./.claude/skills/) (Claude Code)
- **Custom agents / subagents**: [.github/agents/](./.github/agents/) (Copilot) · [.claude/agents/](./.claude/agents/) (Claude Code)
- **Reusable workflows**: [.github/prompts/](./.github/prompts/) (Copilot Chat) · [.claude/commands/](./.claude/commands/) (Claude Code)

## Precedence

If anything in this file or any derived file (`copilot-instructions.md`, prompt files) conflicts with `CLAUDE.md`, **`CLAUDE.md` wins** — it is canonical and this file is generated, so it may lag. Slash commands (`/feature`, `/fix`, …) have Copilot equivalents in `.github/prompts/` with the same names.
