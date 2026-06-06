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

1. **Verify before you reference.** Before naming a class, method, file, route, NuGet package, namespace, or DI registration extension, confirm it exists in this codebase via `Read` / `Grep`. If you cannot confirm, say so explicitly rather than guessing.
2. **Never invent APIs.** Do not fabricate method signatures, type names, attributes, package exports, or framework features. Read the source. If a referenced shared-library API is not in `FRAMEWORK-CONTEXT.md > Detected Framework Packages` at the version this repo pins, treat it as unverified.
3. **Honour version pinning.** Before suggesting a feature from a shared library, framework, or `Microsoft.*` package, confirm the version in `FRAMEWORK-CONTEXT.md > Detected Framework Packages` actually has it. The latest API surface in `Shared Libraries` may not exist in older versions.
4. **State uncertainty.** When a question depends on context you do not have (a file you have not read, runtime behaviour you cannot observe, a database state you cannot query), say so. Do not guess to seem helpful.
5. **Tests are immutable safety nets during fixes and refactors.** When an existing test fails, production is wrong (or the test is wrong for a documented reason). Do not edit assertions to make them pass without flagging it explicitly.
6. **No invented fixtures.** When sample data, builders, factories, or mocks already exist, reuse them. Do not fabricate parallel ones.
7. **Failures are signals.** Build, test, or analyser failures are diagnostic. Read the message and fix the cause; never wrap in try/catch or `#pragma warning disable` to silence. (A PreToolUse hook hard-blocks writes that add `#pragma warning disable`.)
8. **No future-proofing.** Do not add code for hypothetical requirements. Three similar lines is better than a premature abstraction.

---

## Leanness

The Boy Scout Rule biases toward adding improvements. This section is the counterweight: every change should also consider what to remove or what not to introduce. Bloat is not a stylistic preference — it is the highest-cost long-term failure mode of AI-assisted development.

### Defaults

1. **Edit existing files; do not create new ones unless required.** A new file is a long-term commitment. If a method fits an existing file, put it there.
2. **Interfaces are for injected services (SOLID/DIP) and for genuine second implementations — not for data.** Every injected service is depended on through an interface (see [SOLID](#solid)); the implementation may be `sealed`. *Outside* that rule, no interface or abstraction without a real need — data carriers (DTOs, entities, value objects, `Options` records) never get interfaces, and don't invent abstractions for hypothetical variation.
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

## SOLID

SOLID is **mandatory** in this codebase. It governs structure; [Leanness](#leanness) governs ceremony *beyond* that structure — the two are reconciled here and in Leanness #2.

1. **Single Responsibility** — one reason to change per class. No god classes; controllers stay thin (delegate to a service immediately). Split a class that mixes orchestration, data access, and presentation. Heuristic: more than ~5 injected collaborators, or a name needing "And"/"Manager", means split.
2. **Open/Closed** — extend by adding a type, not editing a stable one. When a `switch`/`if` over a type/enum code reaches its **third** arm, replace it with polymorphism. (Do not build the seam speculatively before then — that is future-proofing.)
3. **Liskov Substitution** — every implementation fulfils its interface's contract completely: no `NotImplementedException`/`NotSupportedException`, no strengthened preconditions, no weakened postconditions. If a type can't honour the contract, it must not implement it.
4. **Interface Segregation** — small, role-based interfaces over one fat `I*Service`. No implementation is forced to implement members it does not use.
5. **Dependency Inversion** — **every injected service/behaviour is depended on through an interface**, registered in DI; higher layers never `new` a concrete service or depend on a concrete lower layer. Data carriers (DTOs, entities, value objects, `Options` records, enums) are **not** services — they get no interface.

**Mechanism**: define `IFoo` beside `Foo`; register `services.AddScoped<IFoo, Foo>()` via the project's DI extension; inject `IFoo`. Implementations may be `sealed`.

**Deterministic backstop**: dependency *direction* is enforced in CI by architecture tests (**NetArchTest**). The `solid-check` agent covers the semantic principles per diff and is run by `/review`. Scaffold it with the `enforce-architecture` skill.

---

## Conventions

<!-- Mirrored from CLAUDE.md > Conventions by /bootstrap. Until /bootstrap runs, the greenfield
     defaults in docs/defaults.md apply, and CLAUDE.md > Conventions remains authoritative. -->

_Project conventions are populated by `/bootstrap` into `CLAUDE.md > Conventions` and mirrored here. Until then, follow the greenfield defaults in [docs/defaults.md](./docs/defaults.md). `CLAUDE.md > Conventions` is authoritative if this section lags._

---

## Common Tasks

Recipes live as auto-discovered **skills**, available to both Claude Code (`.claude/skills/`) and GitHub Copilot (`.github/skills/`). The model triggers the relevant one when you describe that kind of task. Current skills:

- `add-endpoint` — add a new HTTP API endpoint end-to-end (domain → service → DTO → validator → controller → integration test)
- `add-entity` — add a new EF Core entity with configuration and migration review
- `register-service` — register a new service in DI with the right lifetime
- `add-tests` — add tests following project patterns (xUnit + `WebApplicationFactory`)
- `perf` — scan for performance anti-patterns; tiered findings with TECH_DEBT.md integration
- `dependency-audit` — scan for vulnerable/outdated NuGet packages and wire up automated dependency scanning
- `create-adr` — record an architecture decision
- `enforce-architecture` — wire the deterministic DIP/layering CI gate (NetArchTest)

**Registers**: [TECH_DEBT.md](./TECH_DEBT.md) tracks delivery debt. [SECURITY_FINDINGS.md](./SECURITY_FINDINGS.md) tracks security findings separately with remediation SLAs (Critical = 7 days, High = 30 days). AI-assisted file changes are appended to `.claude/ai-audit.log` automatically by the PostToolUse hook.

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
10. Inline single-consumer interfaces or abstract bases **that are not DI service seams** (data/internal abstractions only) — per Leanness. Service interfaces are required by SOLID/DIP even with one implementation; never inline those.
11. Collapse shallow delegate methods that add no behavior beyond calling another component
12. Single-use private helpers — inline at the call site

Items 8–12 can significantly expand or reshape a diff. Only apply them when the file is what the task is specifically about, not when it's incidentally touched.

**When to skip**: hotfixes, time-sensitive production incidents, and proof-of-concept branches. If skipping, add a comment `// TODO: Boy Scout skipped — [reason]` so it's picked up on the next pass. Use `/debt` to clean up later.

---

## Agentic Workflow

When given any task, follow this execution model. The seven workflows are also invokable explicitly as slash commands — in Claude Code from `.claude/commands/`, in Copilot Chat from `.github/prompts/` (same names).

1. **Classify the intent** — feature / fix / refactor / design / test / debt / review. If ambiguous, ask before proceeding. **Security-sensitive work** (auth/authz, payments, balances, ledgers, idempotency, secrets) additionally runs `/security-review` (or the `security-auditor` agent) before being presented as complete.
2. **Plan before coding** — for any non-trivial task, present a plan (files to create/modify, order of operations, what tests verify success) **plus clarifying questions for anything underspecified, then wait for the developer's go-ahead before writing code** (skip the wait only for trivial, unambiguous changes, and say so). For larger features, persist a spec to `specs/<slug>.md` (see `/design`) and implement against it.
3. **Execute in verified subtasks** — decompose into ordered layers (domain → service → API → integration test). Run `dotnet build` and `dotnet test` after each; fix failures before moving on.
4. **Boy Scout every touched file** — apply the always-apply list above to every file you modify.
5. **Self-review before presenting** — review against `CLAUDE.md > Conventions`; verify build + tests pass; flag new patterns, resolved TECH_DEBT items, and any convention contradictions. **Close with a Verification & confidence line**: separate what you verified by running it (build/tests/lint) from what you assert without having run it, and flag anything unverified.
6. **Flag documentation drift** — note new patterns to document, TECH_DEBT/SECURITY_FINDINGS changes, and whether `copilot-instructions.md` / this file need regeneration (`/generate-copilot`).

---

## Quick reference

- **Conventions, architecture, common tasks, boy-scout rules** (canonical): [CLAUDE.md](./CLAUDE.md)
- **Cross-repo context**: [FRAMEWORK-CONTEXT.md](./FRAMEWORK-CONTEXT.md)
- **Tech debt register**: [TECH_DEBT.md](./TECH_DEBT.md)
- **Security findings register** (remediation SLAs): [SECURITY_FINDINGS.md](./SECURITY_FINDINGS.md)
- **Inline-completion ruleset** (terse, editor autocomplete): [.github/copilot-instructions.md](./.github/copilot-instructions.md)
- **Skills** (Common Tasks recipes): [.github/skills/](./.github/skills/) (Copilot) · [.claude/skills/](./.claude/skills/) (Claude Code)
- **Custom agents / subagents**: [.github/agents/](./.github/agents/) (Copilot) · [.claude/agents/](./.claude/agents/) (Claude Code)
- **Reusable workflows**: [.github/prompts/](./.github/prompts/) (Copilot Chat) · [.claude/commands/](./.claude/commands/) (Claude Code)

## Precedence

If anything in this file or any derived file (`copilot-instructions.md`, prompt files) conflicts with `CLAUDE.md`, **`CLAUDE.md` wins** — it is canonical and this file is generated, so it may lag. Slash commands (`/feature`, `/fix`, …) have Copilot equivalents in `.github/prompts/` with the same names.
