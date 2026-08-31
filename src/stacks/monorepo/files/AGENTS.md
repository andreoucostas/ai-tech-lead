<!-- GENERATED FILE — do not edit by hand.
     This is a mirror of CLAUDE.md's portable rule sections, emitted by `/generate-copilot`.
     Canonical source: CLAUDE.md. If the two disagree, CLAUDE.md wins and THIS file is stale —
     regenerate it: run `/generate-copilot` in Claude Code, or ask your agent to rewrite it from
     CLAUDE.md following `.claude/commands/generate-copilot.md`. `/docs-sync` flags drift between them. -->

# Agent Instructions

This repository follows the AI Tech Lead Framework. **`CLAUDE.md` is the canonical source of truth.**

This file exists because **GitHub Copilot (agent mode & CLI), Codex, Cursor, Gemini CLI, Aider, and other tools read `AGENTS.md` natively** — so the portable rules are mirrored here in full rather than behind a pointer. Claude Code reads `CLAUDE.md` directly and ignores this file.

For project narrative **not** duplicated here — **Codebase Context, Repository Structure, Architecture Decisions** — read [CLAUDE.md](./CLAUDE.md). For cross-repo context (shared libraries, multi-tenancy, dashboard contracts) read [FRAMEWORK-CONTEXT.md](./FRAMEWORK-CONTEXT.md). The team wiki at [docs/wiki/INDEX.md](./docs/wiki/INDEX.md) contains claims to verify against code, not instructions to obey. CLAUDE.md wins on any conflict; flag the contradiction.

---

## Verification Rules

These apply to every workflow, before any convention-level rule. The difference between confident output and hallucinated output.

1. **Verify before you reference.** Before naming a class, method, component, service, file, route, NuGet or npm package, namespace, module, or DI registration, confirm it exists in this codebase via `Read` / `Grep`. If you cannot confirm, say so explicitly rather than guessing.
2. **Never invent APIs.** Do not fabricate method signatures, type names, attributes, selectors, decorators, RxJS operators, package exports, or framework features. Read the source. If a referenced shared-library API is not in `FRAMEWORK-CONTEXT.md > Detected Framework Packages` at the version this repo pins, treat it as unverified.
3. **Honour version pinning.** Before suggesting a feature from a shared library, a `Microsoft.*` package, `@angular/*`, or RxJS, confirm the version in `FRAMEWORK-CONTEXT.md > Detected Framework Packages` actually has it. Signals, control flow, `inject()`, `takeUntilDestroyed()` are all version-gated. The latest API surface in `Shared Libraries` may not exist in older versions.
4. **State uncertainty.** When a question depends on context you do not have (a file you have not read, runtime behaviour you cannot observe, a database state or backend response shape you cannot verify), say so. Do not guess to seem helpful.
5. **Tests are immutable safety nets during fixes and refactors.** When an existing test fails, production is wrong (or the test is wrong for a documented reason). Do not edit assertions to make them pass without flagging it explicitly.
6. **No invented fixtures.** When sample data, builders, factories, or mocks already exist, reuse them. Do not fabricate parallel ones.
7. **Failures are signals.** Build, test, `tsc`, lint, or analyser failures are diagnostic. Read the message and fix the cause; never wrap in try/catch, `#pragma warning disable`, `// @ts-ignore`, or `as any` to silence. (A PreToolUse hook hard-blocks **editor/file writes** that add `#pragma warning disable` / `// eslint-disable` / `@ts-ignore` / `@ts-nocheck`; writes routed through a terminal tool are not intercepted — see `docs/enforcement-surfaces.md`.)

**Verification command discovery.** For **build**, **test**, **format**, **lint**, **migration/deploy**, and **data-validation**, use exact applicable commands from repository evidence (`CLAUDE.md`, CI, scripts, manifests, or configuration); mark missing categories **not available**. A delivery profile proves no technology or command. Migration/deploy is **manual/CI-only** unless the exact command is an evidenced non-mutating validation/dry-run or the developer authorizes a known target; otherwise do not run it.
8. **No future-proofing.** Do not add code for hypothetical requirements. Three similar lines is better than a premature abstraction.
9. **A new test must be seen to fail before it is trusted.** Before relying on a new behavioral test as green, confirm it actually goes red when the behavior is broken — write it before the fix (bug fixes), or briefly break the code under test and watch it fail for the right reason. Where running the red is impractical, state the specific defect the test would catch. *Why: AI-generated tests are the highest-risk for tautological or over-mocked assertions that pass even against broken code; a test you have watched fail cannot be vacuous.*
10. **Derive, don't assume.** Before applying or recommending any technology-specific rule or recipe (ORM/data access, validation, HTTP client, test framework, state management), verify that technology is present in this repo via a package reference, import, or config. If a default or skill assumes an absent technology, say so explicitly and derive the convention from what the codebase actually uses instead.
11. **Read the repository's own description of a subsystem before writing against it.** Before writing code that depends on a database schema, warehouse, integration, or shared library, check `docs/` for a file describing it and read that file first. What the repository records about its own structure outranks what you infer from names. If it is absent, stale, or silent on what you need, say so instead of inferring.

---

## Leanness

The Boy Scout Rule biases toward adding improvements. This section is the counterweight: every change should also consider what to remove or what not to introduce. Bloat is not a stylistic preference — it is the highest-cost long-term failure mode of AI-assisted development.

### Defaults

1. **Edit existing files; do not create new ones unless required.** A new file is a long-term commitment. If a method fits an existing file, service, or component, put it there.
2. **Abstractions are for injected services (SOLID/DIP) and for genuine second implementations — not for data.** Every injected service is depended on through an abstraction — in .NET an interface (the implementation may be `sealed`), in Angular an `abstract class`/token (see [SOLID](#solid)). *Outside* that rule, no interface or abstraction without a real need — data carriers (DTOs, entities, value objects, models, `Options` records) never get abstractions, and don't invent abstractions for hypothetical variation.
3. **No abstract base class with one subclass.** Inline it.
4. **Wrappers must add behavior.** A method that just delegates — or a service method that just calls `httpClient.get(...)` and returns the observable — is a layer that costs reading time and adds no value. Inline or remove.
5. **No defensive code for impossible states.** Trust internal callers; validate only at system boundaries (HTTP request body, message bus payload, third-party API response, form input, route params). **Financial domain exception**: for monetary amounts, ledger entries, account balances, regulatory figures, and idempotency keys — treat every state as possible regardless of caller. Use `decimal` (never `double`) for money; guard against negative amounts, duplicate transaction IDs, decimal precision loss, and timestamp ordering violations at every layer even in internal code.
6. **No `try/catch` or `catchError` to silence; only to handle.** If you cannot say what the catch block does for the user — or what the recovery returns to the stream — do not write it. Letting an error reach the global error handler is a valid choice in Angular.
7. **No comments that restate code.** A comment earns its place only when it captures a non-obvious *why* (constraint, invariant, workaround). XML doc comments on public APIs are an exception when the project ships them. Bad: `// loop over orders` above the loop it sits on. Good: `// vendor API caps batches at 50` above a chunk-size constant.
8. **No new generic helpers / utility classes / pipes / directives without two existing call sites.** Three similar lines beat a premature abstraction.
9. **Deletion is a contribution.** If a change makes existing code obsolete, delete it in the same PR. Comment-out is never the answer; that is what version control is for.
10. **No re-exports through barrel files (`index.ts`) unless the barrel already exports adjacent symbols.** Do not grow the public surface for free. Internal-only files do not need exports at all.

### Test leanness

11. **Do not test getters, setters, or trivial constructors/signals.** Test behavior, not assignment.
12. **Do not test the framework.** No tests that DI resolves, that EF Core can read its own writes, that ASP.NET model-binding parses an int, that `@Input` decorators bind, or that `Router.navigate` works.
13. **Reuse existing builders / fixtures / HTTP mocks.** Do not introduce parallel test data unless the existing ones cannot represent the case.
14. **No over-mocking.** Mock only true external boundaries — network/HTTP (`provideHttpClientTesting`), clock, filesystem/storage, third-party SDKs, the database when an in-memory substitute won't do. Never mock the type under test or its owned collaborators when a real or in-memory instance is cheap; prefer a fake/in-memory over an interaction mock for code you own, and render the real template with real collaborators in component tests. *Why: AI assistants frequently produce tests that assert on mock interactions and would still pass if the real code were broken — see [Verification Rules](#verification-rules) #9.*
15. **No tautological assertions.** A test whose only assertion is `Assert.True(true)` / `expect(true).toBe(true)`, a not-null check on a freshly-constructed object, or "the mock was called" verifies nothing. Assert the observable return value, state change, rendered output, or emitted effect. *Why: a large share of LLM-generated assertions are weak or vacuous — they bank coverage without catching regressions.*
16. **Assert behavior, not implementation.** Do not assert private state, internal call order that isn't part of the contract, exact log strings, or DOM structure that isn't user-visible. A refactor that preserves behavior must not break the test.

### When you must add structure

If a change genuinely requires a new abstraction, file, component, service, or pipe, state the second consumer (existing or imminent) in the design or PR description. "Imminent" means within the same change-set. Otherwise: defer the abstraction until the second case appears.

---

## SOLID

SOLID is **mandatory** in this codebase. It governs structure; [Leanness](#leanness) governs ceremony *beyond* that structure — the two are reconciled here and in Leanness #2.

1. **Single Responsibility** — one reason to change per class/component/service. No god classes or god services; controllers stay thin (delegate to a service immediately); honour the smart/dumb component split. Split anything that mixes orchestration, data access, and presentation. Heuristic: more than ~5 injected collaborators, or a name needing "And"/"Manager", means split.
2. **Open/Closed** — extend by adding a type/strategy, not editing a stable one. When a `switch`/`if` over a type/enum code reaches its **third** arm, replace it with polymorphism. (Do not build the seam speculatively before then — that is future-proofing.)
3. **Liskov Substitution** — every implementation fulfils its abstraction's contract completely: no `NotImplementedException`/`NotSupportedException` or `throw new Error('not implemented')`, no strengthened preconditions, no weakened postconditions. If a type can't honour the contract, it must not implement it.
4. **Interface Segregation** — small, role-based interfaces over one fat `I*Service` / service contract. No implementation is forced to implement or stub members it does not use.
5. **Dependency Inversion** — **every injected service/behaviour is depended on through an abstraction**: in .NET an interface registered in DI; in Angular an `abstract class` (a runtime-capable DI token) — or an `interface` + `InjectionToken<T>` — with a `provide` mapping. Higher layers never `new` a concrete service or depend on a concrete lower layer. Data carriers (DTOs, entities, value objects, models, `Options` records, enums) are **not** services — they get no abstraction.

**Mechanism** — .NET: define `IFoo` beside `Foo`; register `services.AddScoped<IFoo, Foo>()` via the project's DI extension; inject `IFoo`; implementations may be `sealed`. Angular: prefer `abstract class Foo` as the token with `{ provide: Foo, useClass: FooImpl }` (TypeScript `interface`s don't exist at runtime); use `interface` + `InjectionToken<T>` where an abstract class is awkward.

**Deterministic backstops**: `solid-check` is advisory. NetArchTest and `dependency-cruiser` are scaffoldable and enforce direction only after the consumer wires them into CI with `enforce-architecture`.

---

## Conventions

<!-- Mirrored from CLAUDE.md > Conventions by /bootstrap. Until /bootstrap runs, apply only the
     docs/defaults.md blocks selected by Git-root evidence; CLAUDE.md > Conventions remains authoritative. -->

_Project conventions are populated by `/bootstrap` into `CLAUDE.md > Conventions` and mirrored here. Until then, follow only the [docs/defaults.md](./docs/defaults.md) blocks supported by Git-root evidence. `CLAUDE.md > Conventions` is authoritative if this section lags._

---

## Common Tasks

Skills are a delivery-profile superset, not evidence that they apply. Use only when repository evidence satisfies the gate:

- `add-endpoint` — add a new HTTP API endpoint end-to-end (domain → service → DTO → validator → controller → integration test)
- `add-entity` — add a new EF Core entity with configuration and migration review
- `register-service` — register a new service in DI with the right lifetime
- `map-warehouse` — map a SQL data-warehouse repo: layers (staging → warehouse → marts), tables, keys and fact → dimension relationships, grain, load orchestration, SCD strategy, partitioning
- `add-warehouse-load` — add or extend a warehouse load following the repo's existing patterns: idempotent re-runnable loads, no double-loading, SCD handling, partition alignment
- `perf` — scan for .NET performance anti-patterns; tiered findings with TECH_DEBT.md integration
- `add-component` — add a new Angular feature component end-to-end
- `add-service` — add an HTTP / business-logic / signal-store service
- `add-lazy-route` — add a lazy-loaded route with optional guards/resolvers
- `add-signal-store` — add a signal-based shared-state store
- `add-tests` — add tests following the repo's existing test framework and fixtures (.NET); TestBed + `HttpTestingController`, harnesses, store state-transition tests (Angular)
- `dependency-audit` — scan for vulnerable/outdated NuGet and npm packages and wire up automated dependency scanning
- `create-adr` — record an architecture decision
- `remember-for-team` — draft a team wiki entry (gotcha/context/recipe/failed-approach) for PR review
- `enforce-architecture` — wire the deterministic DIP/layering CI gates (NetArchTest for .NET, dependency-cruiser for Angular)
- `enforce-standards` — make warnings, skipped tests, and analyzer/lint findings build-breaking (.NET: `TreatWarningsAsErrors` + `.editorconfig` severities; Angular: ESLint `noInlineConfig` + rule severities)

**Registers**: [TECH_DEBT.md](./TECH_DEBT.md) tracks delivery debt. [SECURITY_FINDINGS.md](./SECURITY_FINDINGS.md) tracks security findings separately with remediation SLAs (Critical = 7 days, High = 30 days). Supported hooked editor/file-write events append mutable local telemetry to `.claude/ai-audit.log`; shell/external writes and unavailable hooks are blind spots.

---

## Boy Scout Rule

When touching any file, leave it cleaner than you found it. The rule is symmetric: improvements *add* missing pieces and *remove* dead weight. Deletion is a contribution.

### Always apply (low-effort, low-risk — do these on every touched file):

Apply only entries whose technology exists here; the profile proves none.

**Add:**
1. Missing `CancellationToken` propagation (.NET)
2. Replace string-interpolated log messages with structured logging (.NET)
3. Missing null checks at public boundaries (.NET)
4. Missing `.AsNoTracking()` on read-only queries (.NET)
5. Replace manual `ngOnDestroy` subscription cleanup with `takeUntilDestroyed()` (Angular)
6. Replace nested `.subscribe()` with the appropriate RxJS operator (Angular)
7. Replace `any` with proper types (Angular)

**Subtract:**
8. Unused `using` directives (.NET), unused TypeScript imports and unused RxJS operator imports (Angular)
9. Commented-out code or template blocks (more than 1 line — version control preserves them)
10. Unreferenced private fields, methods, or local variables that the IDE/compiler/`tsc`/lint flags
11. Unused `@Input` / `@Output` properties (Angular)

> **Not auto-applied: `ChangeDetectionStrategy.OnPush`.** Switching a component to `OnPush` is a semantic change, not a cleanup — it can silently break views that mutate inputs in place, rely on default change detection ticking from `setInterval`/Promises/third-party callbacks, or expect re-render on ambient state changes. Treat it as an explicit, tested change when the component is the primary target, not a drive-by edit. New components scaffolded from skills still default to `OnPush` (see `docs/defaults.md`).

### Apply only when the file is the primary target of the change:

**Add:**
12. Split mixed-responsibility methods; never use a line-count threshold
13. Add risk-relevant tests only, and only with a harness
14. Replace manual `.subscribe()` with `async` pipe where possible (Angular)
15. Extract complex template expressions into component methods or pipes (Angular)
16. Add `ChangeDetectionStrategy.OnPush` — but only after verifying the component's data flow (immutable inputs, no in-place mutation, no reliance on ambient ticking) and after manual/test verification that the view still updates correctly. (Angular)

**Subtract:**
17. Inline single-consumer interfaces or abstract bases **that are not DI service seams** (data/internal abstractions only) — per Leanness. Service interfaces/abstractions are required by SOLID/DIP even with one implementation; never inline those.
18. Collapse shallow delegate methods that add no behavior — including service methods that just call `HttpClient` with no transformation
19. Single-use private helpers, pipes, or directives — inline at the call site
20. Unused barrel re-exports in `index.ts` (Angular)

Items 12–20 can significantly expand or reshape a diff. Only apply them when the file is what the task is specifically about, not when it's incidentally touched. This keeps PRs focused and reviewable.

**When to skip**: hotfixes, time-sensitive production incidents, and proof-of-concept branches. If skipping, add a comment `// TODO: Boy Scout skipped — [reason]` so it's picked up on the next pass. Use `/debt` to clean up later.

---

## Agentic Workflow

When given any task, follow this execution model:

### 1. Classify the intent — and run that workflow without being asked
Developers will rarely type a slash command. Treat any natural-language request as the trigger: silently classify it, **announce in one line which workflow you concluded** ("Reading this as a *fix*…"), and apply that workflow's rails below. If two workflows genuinely fit, ask one clarifying question first. If it's a pure question ("why does this throw?", "what does `X` do?"), just answer it — no workflow ceremony. You may combine workflows for a compound request ("fix this and add a test"), but **never silently drop a workflow's non-negotiables** to do so.

> These rails are the **canonical definition** of each workflow. `commands/*.md` and the `route-prompt` hook elaborate them but must not contradict them; `/docs-sync` checks they stay aligned. The native instruction carrier and hook lifecycle are independent; delivery of one proves no event in the other. Treat these rails as binding, not advisory.

- **Feature** — *add / implement / create / build new …*: design affected boundaries, failure modes, and the smallest useful tests when a harness exists; never add one incidentally → implement in evidenced dependency order → apply Verification command discovery for each technology → Boy Scout touched files → self-review → report delivery and validation. No new interface/service/abstraction without a second consumer.
- **Bug fix** — *broken / bug / crash / failing / "not working" / "looks off"*: state root cause → with an applicable harness, first write a regression test that fails correctly; otherwise use the strongest evidenced validation, report tests **not available**, and add no foreign harness → make the minimal fix → apply Verification command discovery → Boy Scout the blast radius → report cause, fix, validation, and radius.
- **Refactor** — *cleanup / extract / rename / simplify / restructure*: establish an evidenced green baseline; add characterization coverage only to an existing applicable harness, otherwise report tests **not available** → refactor incrementally with verification → Boy Scout touched files → prove unchanged behavior → report before/after and net LOC.
- **Test** — *write / add tests, increase coverage*: match the existing harness → cover the principal behavior plus consequential risks only → assert observable behavior, not internals or mock trivia → see each new behavioral test fail correctly → apply Verification command discovery → report coverage and gaps.
- **Investigation / design** — *design X / approach for / trade-offs / "how should I"*: **write no code** → understand the requirement → analyse impact → weigh at least two approaches with pros/cons + effort → recommend with specifics (structure, state, services, tests) → surface open questions before implementation.
- **Debt cleanup** — *tech debt / cleanup debt*: confirm relevant `TECH_DEBT.md` items still exist and respect dismissed proposals unless materially changed evidence is named → apply Verification command discovery; without a harness, use the strongest evidenced check rather than adding one → recommend fix-now vs defer → update the file after fixes → Boy Scout touched files → report outcomes, validation, and diff.

What is *registered*, *observed*, or merely *instructed* depends on the surface — see `docs/enforcement-surfaces.md`. Hook registration proves neither client firing nor output consumption; these rails remain binding independently.

**Security-sensitive surfaces always get a security pass.** If the work touches authentication/authorization, payments, balances, ledgers, transactions, idempotency, secrets, tokens, sessions, PII, or output sanitization (XSS/CSRF), run `/security-review` on the diff (or the `security-auditor` agent) before presenting it as complete — regardless of which workflow above applies. For prompts matching its bounded security vocabulary, the registered prompt hook emits this reminder when invoked; host firing and output consumption require separate, capability-specific evidence. The rule holds whether or not the hook runs.

### Steps 2–6 (condensed — full text in [.github/instructions/framework-rules.instructions.md](./.github/instructions/framework-rules.instructions.md) › Agentic Workflow)

2. **Plan before coding** — for any non-trivial task, present a plan (files to create/modify, order of operations, repository-evidenced validation including tests only where a harness exists) **plus clarifying questions for anything underspecified, then wait for the developer's go-ahead before writing code** (skip the wait only for trivial, unambiguous changes, and say so). For larger features, persist a spec to `specs/<slug>.md` (see `/design`) and implement against it.
3. **Execute in verified subtasks** — identify only the repository-evidenced profiles and layers the change touches; run applicable commands after each subtask and report unsupported categories as **not available**.
4. **Boy Scout every touched file** — apply the always-apply list above to every file you modify.
5. **Self-review before presenting** — review against `CLAUDE.md > Conventions`; verify every applicable repository-evidenced check; flag new patterns, resolved TECH_DEBT items, and any convention contradictions. **Close with a Verification & confidence line**: separate what you verified by running it from what is **not available** or otherwise unverified. Show the command and observed result, not the bare claim "tests pass."
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
