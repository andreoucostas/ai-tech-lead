<!--
ai-tech-lead-framework
  template: angular
  version: 0.25.5
  applied: 2026-07-06
  When you sync template updates, bump these fields and update .claude/framework-version.json.
-->
# [Project Name]

> This file is the single source of truth for AI-assisted development in this repository.
> Claude Code loads this file directly. GitHub Copilot (agent mode & CLI), Codex, Cursor, Gemini, and Aider read its generated mirror **[AGENTS.md](./AGENTS.md)** (kept in sync by `/generate-copilot`). Edit conventions here, never in AGENTS.md.
> Run `/bootstrap` to populate it from your actual codebase.
>
> **Companion file**: [FRAMEWORK-CONTEXT.md](./FRAMEWORK-CONTEXT.md) holds cross-repo context (shared libraries, multi-tenancy conventions, dashboard contracts) plus the repo's **Known Hazard Areas**, all of which the agent should load on every non-trivial task — consult the hazard list for the change's blast radius before planning. CLAUDE.md wins on any conflict — but flag the contradiction.
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
7. **Failures are signals.** `tsc` errors, lint errors, and test failures are diagnostic. Read the message and fix the cause; never `// @ts-ignore`, `as any`, or comment-out to silence. (A PreToolUse hook hard-blocks **editor/file writes** that add `// eslint-disable` / `@ts-ignore` / `@ts-nocheck`; writes routed through a terminal tool are not intercepted — see [docs/enforcement-surfaces.md](./docs/enforcement-surfaces.md).)
8. **No future-proofing.** Do not add code for hypothetical requirements. Three similar lines is better than a premature abstraction.
9. **A new spec must be seen to fail before it is trusted.** Before relying on a new behavioral spec as green, confirm it actually goes red when the behavior is broken — write it before the fix (bug fixes), or briefly break the code under test and watch it fail for the right reason. Where running the red is impractical, state the specific defect the spec would catch. *Why: AI-generated specs are the highest-risk for tautological or over-mocked assertions that pass even against broken code; a spec you have watched fail cannot be vacuous.*

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
14. **No over-mocking.** Mock only true external boundaries — HTTP (`provideHttpClientTesting`), time, storage, third-party SDKs. Never mock the component/service under test or its owned collaborators when the real (or a lightweight fake) instance is cheap; render the real template and inject real collaborators. *Why: AI assistants frequently produce tests that assert on mock interactions and would still pass if the real code were broken — see [Verification Rules](#verification-rules) #9.*
15. **No tautological assertions.** A test whose only assertion is `expect(true).toBe(true)`, a lone `expect(x).toBeDefined()` on a freshly-created object, or "the spy was called" verifies nothing. Assert the rendered output, emitted value, or state change. *Why: a large share of LLM-generated assertions are weak or vacuous — they bank coverage without catching regressions.*
16. **Assert behavior, not implementation.** Do not assert private fields, internal method-call order that isn't part of the contract, or DOM structure that isn't user-visible. A refactor that preserves behavior must not break the test.

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

<!-- One-line INDEX of significant decisions here (ID — title — date — link). Full ADRs
     (Decision → Context → Consequences → Review notes) live in docs/architecture-decisions.md,
     added by the create-adr skill. Rationale: CLAUDE.md loads on nearly every agent turn and
     anchors the prompt cache — keep it small; detail loads on demand. -->

A one-line index of significant decisions (including accidental ones that became convention). Full detail in [docs/architecture-decisions.md](./docs/architecture-decisions.md).

---

## Common Tasks

Recipes live as **skills**, auto-discovered by both Claude Code (`.claude/skills/`) and GitHub Copilot (`.github/skills/`) — the model triggers the relevant one when you describe that kind of task. Current skills:

- `add-component` — add a new Angular feature component end-to-end
- `add-service` — add an HTTP / business-logic / signal-store service
- `add-lazy-route` — add a lazy-loaded route with optional guards/resolvers
- `add-signal-store` — add a signal-based shared-state store
- `add-tests` — add specs following project patterns (TestBed + `HttpTestingController`, harnesses, store state-transition tests)
- `dependency-audit` — scan for vulnerable/deprecated/outdated npm packages and set up automated dependency scanning (Dependabot or Renovate)
- `create-adr` — record a significant architecture decision in Architecture Decisions
- `enforce-architecture` — wire the deterministic DIP/layering CI gate (dependency-cruiser)
- `enforce-standards` — make `@ts-ignore`, `eslint-disable`, and focused/skipped specs build-breaking (ESLint `noInlineConfig` + rule severities)

`/bootstrap` adds project-specific skills under `.claude/skills/`, grounding instance-shaped recipes in a real repo exemplar. Skills are mirrored to `.github/skills/` by `/generate-copilot` (and `scripts/sync-agent-files`) so Copilot CLI/agent see them too.

**Registers**: [TECH_DEBT.md](./TECH_DEBT.md) tracks delivery debt. [SECURITY_FINDINGS.md](./SECURITY_FINDINGS.md) tracks security findings separately with remediation SLAs (Critical = 7 days, High = 30 days). Do not merge them — audit teams treat these differently. Security findings come from `/security-review` and the `security-auditor` agent, not from feature work. AI-assisted file changes are appended to [.claude/ai-audit.log](./.claude/ai-audit.log) automatically by the PostToolUse hook.

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

> **Not auto-applied: `ChangeDetectionStrategy.OnPush`.** Switching a component to `OnPush` is a semantic change, not a cleanup — it can silently break views that mutate inputs in place, rely on default change detection ticking from `setInterval`/Promises/third-party callbacks, or expect re-render on ambient state changes. Treat it as an explicit, tested change when the component is the primary target, not a drive-by edit. New components scaffolded from skills still default to `OnPush` (see `docs/defaults.md`).

### Apply only when the file is the primary target of the change:

**Add:**
8. Replace manual `.subscribe()` with `async` pipe where possible
9. Extract complex template expressions into component methods or pipes
10. Add `ChangeDetectionStrategy.OnPush` — but only after verifying the component's data flow (immutable inputs, no in-place mutation, no reliance on ambient ticking) and after manual/test verification that the view still updates correctly.

**Subtract:**
11. Inline single-consumer interfaces or abstract bases **that are not DI service seams** (data/internal abstractions only) — per Leanness. Service abstractions/tokens are required by SOLID/DIP even with one implementation; never inline those.
12. Collapse shallow service methods that just delegate to `HttpClient` with no transformation
13. Single-use pipes or directives — inline at the call site, or convert to a component method
14. Unused barrel re-exports in `index.ts`

Items 8–14 can significantly expand or reshape a diff. Only apply them when the file is what the task is specifically about, not when it's incidentally touched. This keeps PRs focused and reviewable.

**When to skip**: hotfixes, time-sensitive production incidents, and proof-of-concept branches. If skipping, add a comment `// TODO: Boy Scout skipped — [reason]` so it's picked up on the next pass. Use `/debt` to clean up later.

---

## Agentic Workflow

When given any task, follow this execution model:

### 1. Classify the intent — and run that workflow without being asked
Developers will rarely type a slash command. Treat any natural-language request as the trigger: silently classify it, **announce in one line which workflow you concluded** ("Reading this as a *fix*…"), and apply that workflow's rails below. If two workflows genuinely fit, ask one clarifying question first. If it's a pure question ("why does this throw?", "what does `X` do?"), just answer it — no workflow ceremony. You may combine workflows for a compound request ("fix this and add a test"), but **never silently drop a workflow's non-negotiables** to do so.

> These rails are the **canonical definition** of each workflow. `commands/*.md` and the `route-prompt` hook elaborate them but must not contradict them; `/docs-sync` checks they stay aligned. Where hooks are off (Copilot VS Code without Preview agent-hooks, Copilot CLI < v1.0.65) this text is the *only* thing that reaches the model — treat it as binding, not advisory.

- **Feature** — *add / implement / create / build new …*: design check first (affected layers, files to create/modify, failure modes, test strategy) → decompose into ordered subtasks, running `ng build` + `ng test --watch=false --browsers=ChromeHeadless` after each → Boy Scout every touched file → self-review against Conventions → present what was built and tested. Honour Leanness: no new service/abstraction without a second consumer in this change-set.
- **Bug fix** — *broken / bug / crash / failing / "not working" / "looks off"*: **state the root cause before writing any code** → write a failing regression test (spec) that fails for the *right reason* **before** touching production code → apply the *minimal* fix (no unrelated refactor) → verify the regression test + related suite + build + lint all pass → apply Boy Scout to the **blast radius only** → report root cause, fix, regression coverage, blast radius.
- **Refactor** — *cleanup / extract / rename / simplify / restructure*: **build + tests must pass before you touch anything**; if the target has no tests, write baseline (characterization) specs first → refactor incrementally, building + testing after each step → Boy Scout touched files → verify behaviour is unchanged → present a before/after summary **including net LOC delta**.
- **Test** — *write / add tests, increase coverage*: match existing spec structure, naming, framework, mocking → cover happy path, edge cases, error paths, boundaries → **assert observable behaviour (rendered output, emitted events, store state), not framework internals or implementation detail; no over-mocking, no tautological assertions** → a new behavioural spec must be *seen to fail* before it is trusted (red before green) → verify new specs pass → report what's tested and what's still uncovered.
- **Investigation / design** — *design X / approach for / trade-offs / "how should I"*: **write no code** → understand the requirement → analyse impact → weigh at least two approaches with pros/cons + effort → recommend with specifics (component structure, state, services, tests) → surface open questions before implementation.
- **Debt cleanup** — *tech debt / cleanup debt*: read `TECH_DEBT.md` and find items in the area → confirm each still exists in the code (may already be fixed) → recommend fix-now vs defer with reasons → after fixes, update `TECH_DEBT.md` → Boy Scout touched files → report fixed/deferred plus the `TECH_DEBT.md` diff.

What is *guaranteed* vs merely *instructed* here depends on the surface — see `docs/enforcement-surfaces.md`. On Claude Code — and on Copilot where hooks are enabled (CLI ≥ v1.0.65, VS Code Preview agent-hooks) — these rails are reinforced by a per-prompt hook and a write-time guard; where hooks are off, only this text reaches the model.

**Security-sensitive surfaces always get a security pass.** If the work touches authentication/authorization, tokens, sessions, PII, or output sanitization (XSS/CSRF), run `/security-review` on the diff (or the `security-auditor` agent) before presenting it as complete — regardless of which workflow above applies. On Claude Code — and on Copilot where hooks are enabled — a `UserPromptSubmit` hook flags these automatically; elsewhere it does not — the rule holds regardless.

### 2. Plan before coding — present, clarify, then get the go-ahead
For any non-trivial task, STOP before writing code and post a short plan:
- The files you'll create or modify, and the order of operations
- What tests will verify success
- Your assumptions, plus **clarifying questions** for anything underspecified (ambiguous scope, unclear acceptance criteria, competing approaches). Do not guess past a material ambiguity to seem helpful — ask.
- For larger features, persist the plan as a spec to `specs/<slug>.md` (see `/design`) and implement against it

Then **wait for the developer's explicit go-ahead before editing code.** This checkpoint is where a wrong assumption gets caught before it becomes a wrong diff — and where the developer stays engaged with the change instead of rubber-stamping output. Skip the wait only for a trivial, unambiguous change (typo, one-liner), and say that you're skipping it and why.

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
- **Close with a Verification & confidence line**: separate what you actually verified by running it (build / tests / lint — name which you ran) from what you assert without having run it, and flag anything you could not verify. Show the evidence — the command you ran and its observed result (e.g. `ng test --watch=false` → 87 passed, 0 failed), not the bare claim "tests pass." This calibration is deliberate — it counters the well-documented tendency to feel more done than the work is.

### 6. Flag documentation drift
At the end of your response, note if:
- A new pattern was introduced that should be documented here
- A TECH_DEBT.md entry was resolved or a new one discovered
- A SECURITY_FINDINGS.md entry was resolved or a new finding discovered
- `copilot-instructions.md` / `AGENTS.md` need regeneration (run `/generate-copilot` in Claude Code, or ask your agent to rewrite them from this file following the rules in `.claude/commands/generate-copilot.md`)

---

## What We've Learned

Long-form learnings live in [LEARNINGS.md](./LEARNINGS.md). Read it when starting non-trivial work; append to it (don't overwrite) when you discover what works, what causes friction, or what rule needs adjusting.
