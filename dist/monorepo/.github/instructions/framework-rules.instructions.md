---
applyTo: "**"
---

<!-- FRAMEWORK-OWNED — replaced wholesale by the installer on every update. Do not edit.
     Repo-specific rules belong in CLAUDE.md (Conventions, Boy Scout Rule). -->

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

### 2. Plan before coding — present, clarify, then get the go-ahead
For any non-trivial task, STOP before writing code and post a short plan:
- The files you'll create or modify, and the order of operations
- Evidenced validation; include tests only when a harness exists
- Your assumptions, plus **clarifying questions** for anything underspecified (ambiguous scope, unclear acceptance criteria, competing approaches). Do not guess past a material ambiguity to seem helpful — ask.
- For larger features, persist the plan as a spec to `specs/<slug>.md` (see `/design`) and implement against it

Then **wait for the developer's explicit go-ahead before editing code.** This checkpoint is where a wrong assumption gets caught before it becomes a wrong diff — and where the developer stays engaged with the change instead of rubber-stamping output. Skip the wait only for a trivial, unambiguous change (typo, one-liner), and say that you're skipping it and why.

### 3. Execute in verified subtasks
For features and complex changes, decompose into ordered subtasks:
Choose only evidenced technologies and order work by their dependency flow. Application examples are
model → service → API or state → component → integration; a warehouse may flow schema → migration
→ procedure/query → validation. Omit absent stacks, layers, and tests.

Each subtask leaves applicable evidenced verification green; never add a foreign harness to manufacture a check.
Apply Verification command discovery after each subtask. Delivery-profile membership proves no command;
run only exact recorded invocations for changed technologies and fix failures before continuing.

### 4. Boy Scout every touched file
Check the Boy Scout Rule list above. Apply relevant improvements to every file you modify.

### 5. Self-review before presenting
Before presenting work as complete:
- Review your changes against the Conventions section above
- Apply Verification command discovery; report what ran, was unavailable, or stayed manual/CI-only
- Check if the change introduces a new pattern → flag that this file needs updating
- Check if the change resolves a TECH_DEBT.md item → flag for removal
- Check if the change contradicts any convention → ask whether to update the convention or change the implementation
- If the session surfaced a team-worthy gotcha, recipe, or failed approach, offer `remember-for-team`
- **Close with a Verification & confidence line**: separate what you actually verified by running it (build / tests / lint — name which you ran) from what you assert without having run it, and flag anything you could not verify. Show the evidence — the command you ran and its observed result (e.g. `dotnet test` → 142 passed, 0 failed; `ng test --watch=false` → 87 passed, 0 failed), not the bare claim "tests pass." This calibration is deliberate — it counters the well-documented tendency to feel more done than the work is.

### 6. Flag documentation drift
At the end of your response, note if:
- A new pattern was introduced that should be documented here
- A TECH_DEBT.md entry was resolved or a new one discovered
- A SECURITY_FINDINGS.md entry was resolved or a new finding discovered
- `copilot-instructions.md` / `AGENTS.md` need regeneration (run `/generate-copilot` in Claude Code, or ask your agent to rewrite them from this file following the rules in `.claude/commands/generate-copilot.md`)

---
