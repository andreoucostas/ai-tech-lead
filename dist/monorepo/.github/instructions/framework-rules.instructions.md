---
applyTo: "**"
---

<!-- FRAMEWORK-OWNED — replaced wholesale by the installer on every update. Do not edit.
     Repo-specific rules belong in AGENTS.md (Conventions, Boy Scout Rule). -->

## Verification Rules

These apply to every workflow, before any convention-level rule.

2. **Never invent APIs.** Do not fabricate method signatures, type names, attributes, selectors, decorators, RxJS operators, package exports, or framework features. Read the source. If a referenced shared-library API is not in `FRAMEWORK-CONTEXT.md > Detected Framework Packages` at the version this repo pins, treat it as unverified.
5. **Tests are immutable safety nets during fixes and refactors.** When an existing test fails, production is wrong (or the test is wrong for a documented reason). Do not edit assertions or expected-output files (snapshots, approved/golden files) to make them pass without flagging it explicitly.
7. **Failures are signals.** Build, test, `tsc`, lint, or analyser failures are diagnostic. Read the message and fix the cause; never wrap in try/catch, `#pragma warning disable`, `// @ts-ignore`, or `as any` to silence.

**Verification command discovery.** For **build**, **test**, **format**, **lint**, **migration/deploy**, and **data-validation**, use exact applicable repository-evidenced commands (`AGENTS.md`, CI, scripts, manifests, or configuration); mark missing categories **not available**. Where `AGENTS.md` records no test command, list the whole tree (`git ls-files`) before marking **test** not available: a committed test project, a manifest test script, or a non-framework-owned script under `tests/`, `test/` or `spec/` is the existing harness — run it with its evidenced interpreter and report it as unrecorded (flag `/rebootstrap`). `framework-owned/overwritten` paths in `framework-ownership.json` and paths in `framework-retirements.json` are framework, not application-command, evidence. Run them only when named by an explicit framework workflow or requested for framework diagnosis; report separately from application verification. Do not run a saved Verification Commands row naming one — flag `/rebootstrap`. Migration/deploy is **manual/CI-only** unless its exact command is an evidenced non-mutating validation/dry-run or developer-authorized known target; otherwise do not run it.
9. **A new test must be seen to fail before it is trusted.** Before relying on a new behavioral test as green, confirm it actually goes red when the behavior is broken — write it before the fix (bug fixes), or briefly break the code under test and watch it fail for the right reason. Where running the red is impractical, state the specific defect the test would catch. Write the test at the level where the risk lives: a substitute that cannot reproduce the failure (an in-memory provider for a SQL bug) is no oracle.
10. **Derive, don't assume.** Before applying or recommending any technology-specific rule or recipe (ORM/data access, validation, HTTP client, test framework, state management), verify that technology is present in this repo via a package reference, import, or config. If a default or skill assumes an absent technology, say so explicitly and derive the convention from what the codebase actually uses instead.
11. **Read the repository's own description of a subsystem before writing against it.** Before writing code that depends on a database schema, warehouse, integration, or shared library, check `docs/` for a file describing it and read that file first. What the repository records about its own structure outranks what you infer from names. If it is absent, stale, or silent on the objects you need, say so instead of inferring; in a data warehouse, run the `map-warehouse` skill's scoped pass on those objects before writing SQL against them.

---

## Leanness

The Boy Scout Rule biases toward improvements. This counterweight requires every change also consider what to remove or not introduce.

### Defaults

1. **Place code by responsibility, not proximity.** Edit changed behaviour where it lives. New code joins an existing class only if that class's name still describes it (a repository or client: operations on its resource, nothing more); otherwise it gets its own class, composed the way the project already composes services, even with one consumer — never bolted onto the nearest class, never a subclass of one. Need another class's private logic? Extract it for both to share; add to that class only if the developer declines. UI state used by one component stays in it.
2. **Project evidence selects service seams; data gets none.** For an injected service, use a stack-appropriate seam only when the project's evidenced boundary or correctness need requires one; do not introduce one merely from this framework. Data carriers (DTOs, entities, value objects, models, `Options` records) never get abstractions, and don't invent abstractions for hypothetical variation.
5. **No defensive code for impossible states.** Trust internal callers; validate only at system boundaries (HTTP request body, message bus payload, third-party API response, form input, route params). **Financial domain exception**: identify the applicable invariant, tolerance, and preconditions from policy and evidence; preserve demonstrated amount-sign, duplicate-effect, precision, and temporal controls. A numeric type or every-layer guard alone is not a verdict; require a policy violation or unsafe outcome demonstrated by source, interleaving, or executable/domain evidence, otherwise retain uncertainty.
8. **No new generic helpers / utility classes / pipes / directives without two existing call sites.** Three similar lines beat a premature abstraction.

### Test leanness

12. **Do not test the framework.** No tests that DI resolves, that EF Core can read its own writes, that ASP.NET model-binding parses an int, that inputs bind (`@Input` or `input()`), that `Router.navigate` works, or that change detection runs.
13. **Reuse existing builders / fixtures / HTTP mocks.** Do not introduce parallel test data unless the existing ones cannot represent the case.
14. **No over-mocking.** Mock only true external boundaries — network/HTTP (`provideHttpClientTesting`), clock, filesystem/storage, third-party SDKs, the database when a test-owned instance reset per run won't do. Never mock the type under test or its owned collaborators when a real or in-memory instance is cheap; prefer a fake/in-memory over an interaction mock for code you own, and render the real template with real collaborators in component tests.
15. **No tautological assertions.** A test whose only assertion is `Assert.True(true)` / `expect(true).toBe(true)`, a not-null check on a freshly-constructed object, or "the mock was called" verifies nothing. Assert the observable return value, state change, rendered output, or emitted effect.

---

## SOLID

1. **Single Responsibility** — one reason to change per class/component/service; honour the smart/dumb component split; more than ~5 injected collaborators, or a name needing "And"/"Manager", means split.
2. **Open/Closed** — a `switch`/`if` over a type/enum code gets polymorphism at its **third** arm, not before.
5. **Dependency Inversion** — as Leanness #2: a seam only where project evidence or a correctness need requires one; data carriers get none.

---

## Agentic Workflow

When given any task, follow this execution model:

### 1. Classify the intent — and run that workflow without being asked
Natural-language requests trigger a workflow: classify silently, announce it in one line, and apply its rails. Ask if two fit; answer pure questions directly. Compound requests retain non-negotiables.
When a task matches a skill in `AGENTS.md > Common Tasks`, invoke that skill with your skill tool before planning or editing.

- **Feature** — *add / implement / create / build new …*: design affected boundaries, failure modes, and the smallest useful tests when a harness exists; never add one incidentally → implement in evidenced dependency order → apply Verification command discovery for each technology → Boy Scout touched files → self-review → report delivery and validation. Preserve a project-evidenced service seam; otherwise add no interface/abstraction without a second consumer or correctness need, and place new feature logic per Leanness #1.
- **Bug fix** — *broken / bug / crash / failing / "not working" / "looks off"*: state root cause → with an applicable harness, first write a regression test that fails correctly; otherwise use the strongest evidenced validation, report tests **not available**, and add no foreign harness → make an outcome-bound fix → apply Verification command discovery → report cause, fix, validation, and radius.
- **Refactor** — *cleanup / extract / rename / simplify / restructure*: establish an evidenced green baseline; add characterization coverage only to an existing applicable harness, otherwise report tests **not available** → refactor incrementally with verification → Boy Scout touched files → prove unchanged behavior → report before/after and net LOC.
- **Test** — *write / add tests, increase coverage*: match the existing harness → cover the principal behavior plus consequential risks only → assert observable behavior, not internals or mock trivia → see each new behavioral test fail correctly → apply Verification command discovery → report coverage and gaps.
- **Investigation / design** — *design X / approach for / trade-offs / "how should I"*: **write no code** → understand the requirement → analyse impact → weigh at least two approaches with pros/cons + effort → recommend with specifics (structure, state, services, tests) → surface open questions before implementation.
- **Debt cleanup** — *tech debt / cleanup debt*: confirm relevant `TECH_DEBT.md` items still exist and respect dismissed proposals unless materially changed evidence is named → apply Verification command discovery; without a harness, use the strongest evidenced check rather than adding one → recommend fix-now vs defer → update the file after fixes → report outcomes, validation, and diff.

**Scoped repository knowledge.** For a non-trivial change—including an ordinary feature/fix naming neither a skill nor path—locate task areas; select relevant scoped wiki, map, skill, or example entries; exclude irrelevant/nonapplicable ones; read bodies/references on demand. Investigate conflicting applicable claims and recheck decisive correctness-material evidence. Ask, or retain unresolved, only correctness-material gaps from unresolved drafts, opposing scopes, or stale, missing, or inaccessible evidence; never infer them. Name material evidence and run repository-evidenced verification. Do not preload the wiki or depend on a hook.

**Security-sensitive surfaces always get a security pass.** If the work touches authentication/authorization, payments, balances, ledgers, transactions, idempotency, secrets, tokens, sessions, PII, or output sanitization (XSS/CSRF), run this repository's `security-gate` skill (`.claude/commands/security-gate.md`; on Copilot CLI, not the CLI's built-in security agent) on the diff before presenting it as complete (it captures the scope bundle and runs `security-auditor` on it, which refuses a bare diff request) — regardless of which workflow above applies. The rule holds whether or not a hook reminder appears.

### 2. Plan before coding — present, clarify, then get the go-ahead
For any non-trivial task, STOP before writing code and post a short plan:
- **Open the plan with `Done when:`**, the requirement restated as two to six observable criteria, one per line, each with a boundary example where a threshold, limit or state exists (the case that passes and the one that does not), then what is out of scope. Put it before any options or files. The developer corrects these lines; the go-ahead approves them.
- The files you'll create or modify, and the order of operations
- Evidenced validation; include tests only when a harness exists
- If the change adds an extension point or a third instance of an operation, and adding the next instance has a step that is easy to miss, name the one record you will add for that step unless one exists: a test over this repository's own instances that fails when one skips it (never a test of the framework, Test leanness #12), else one `AGENTS.md > Conventions` line, else, once this change makes three or more instances, a project skill draft under 3a-bis of `.claude/commands/bootstrap.md`; otherwise add none.
- Your assumptions, each with the evidence that verified it (a file, command or query), or marked *unverified — developer confirms*.
- If the request leaves a material gap, **ask first and plan after**: post at most five questions, each with the assumption you would otherwise make, and post the plan only once they are answered. Draw them from the tech-lead list — who consumes this and what breaks for them; what fails and how the developer would know in production; reversibility and rollback; data that moves or changes shape, including migration; blast radius against `FRAMEWORK-CONTEXT.md > Known Hazard Areas`. Do not guess past a material ambiguity to seem helpful — ask.
- **A risk change gets a design, not a file list.** Risk means it touches a `Known Hazard Areas` row, a security-sensitive surface (section 1), a data shape (schema, migration, event or message contract) or a public contract others consume (route, status code, package API). Post `Option A:` and `Option B:`, real alternatives each with its cost or what it breaks, then `Recommend:` one with the reason and the file list beneath it. No real alternative: say so in one line. Every other non-trivial change keeps the short plan above.
- For larger features, persist the plan as a spec to `specs/<slug>.md` (see `/design`) and implement against it

Then **wait for the developer's explicit go-ahead before editing code.** This catches wrong assumptions before wrong diffs and keeps the developer engaged rather than rubber-stamping. Skip only a trivial, unambiguous change (typo, one-liner), and say why.

### 3. Execute in verified subtasks
For features and complex changes, decompose into ordered subtasks along evidenced technologies and boundaries only (omit absent stacks, layers, and tests); after each, apply Verification command discovery for the changed technologies and fix failures before continuing; never add a foreign harness to manufacture a check.

### 4. Bug-fix scope
Every bug-fix edit must be necessary for requested behaviour, existing caller/extension compatibility, or meaningful verification. Requested cleanup/refactoring is allowed; a touched file alone authorizes neither unrelated cleanup/logging nor a TODO. Necessary fixes may cross hunks. For changed public/protected signatures or virtual/override behaviour, identify any unrequested incompatibility; explicitly requested additions or breaks remain valid.

### 5. Self-review before presenting
Before presenting work as complete:
- Review your changes against `AGENTS.md > Conventions`
- Apply Verification command discovery; report what ran, was unavailable, or stayed manual/CI-only
- Check if the change introduces a new pattern → flag that AGENTS.md needs updating
- Check if the change resolves a TECH_DEBT.md item → flag for removal
- Check if the change contradicts any convention → ask whether to update the convention or change the implementation
- If the session surfaced a team-worthy gotcha, recipe, or failed approach, offer `remember-for-team`

### 6. Reconcile affected artifacts
Before finishing, inspect task effects on repository truth. Update affected writable canonical artifacts; regenerate derivatives from source. Follow their ownership, evidence, history, and security rules; never infer human intent. An affected artifact unreadable or unsafe to update is a blocker, not `none`. End with `Affected artifacts: none`, reconciled artifacts, or unresolved blockers.

---
