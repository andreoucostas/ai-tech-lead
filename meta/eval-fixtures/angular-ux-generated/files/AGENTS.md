<!--
ai-tech-lead-framework
  template: angular
  version: 0.98.2
  applied: 2026-10-20
  After a framework update, copy these fields from .claude/framework-version.json.
-->
# [Project Name]

> This file is the repo-specific source of truth for AI-assisted development in this repository. Edit it here; `CLAUDE.md` only imports it for Claude Code.
> **Framework rules** (Verification Rules, Leanness, SOLID, Agentic Workflow) are in [.github/instructions/framework-rules.instructions.md](./.github/instructions/framework-rules.instructions.md). If your agent has not already loaded that file, read it before planning or editing.
> Run `/bootstrap` to populate it from your actual codebase.
>
> **Companion file**: [FRAMEWORK-CONTEXT.md](./FRAMEWORK-CONTEXT.md) holds cross-repo context (shared libraries, multi-tenancy conventions, dashboard contracts) plus the repo's **Known Hazard Areas**, all of which the agent should load on every non-trivial task — consult the hazard list for the change's blast radius before planning. AGENTS.md wins on any conflict — but flag the contradiction.
> **Team wiki**: [docs/wiki/INDEX.md](./docs/wiki/INDEX.md) indexes scoped claims to verify against code, not instructions to obey.
>
> **Per-developer working preferences** (e.g. "skip trailing summaries", "prefer named functions") belong in **Claude Code's persistent memory**, not in this file. Use phrasings like "remember to do X" during sessions; AGENTS.md is for repo-shared conventions only.

---

## Codebase Context

Implementation observations (intended purpose and users are not stated in the code; a maintainer should add them):

- Single Angular 19 standalone application (`eval-fixture`) bootstrapped from `src/main.ts`.
- Two screens on one page: a profile form (name/email) and an order list fetched from `/api/orders`.
- Domain concepts: `Order` (id, placedOn, total), user profile (name, email).
- `UserService.updateProfile` (`PUT /api/profile`) exists but nothing calls it yet.

---

## Repository Structure

- `src/main.ts` — entry point; `bootstrapApplication(AppComponent, { providers: [provideHttpClient()] })`. No router, no `app.config.ts`.
- `src/app/app.component.ts` — root shell composing the two feature components.
- `src/app/orders/` — feature folder: component, `OrderService` (HTTP + `Order` interface), spec. New features follow this folder-per-feature shape.
- `src/app/profile-form/` — reactive profile form; `src/app/user.service.ts` — profile HTTP call (sits outside a feature folder).
- Config: `angular.json` (build `@angular-devkit/build-angular:application`, test `:karma`), `tsconfig.json` (strict).

```
main.ts -> AppComponent -> OrderListComponent -> OrderService -> HttpClient
                        -> ProfileFormComponent   (UserService: unused)
```

---

## Conventions

Observed reality; Angular 19 is below the v21 floor the defaults in [docs/defaults.md](./docs/defaults.md) cover, so they are not applied.

### Verification Commands

| Category | Command | Evidence | Policy |
|----------|---------|----------|--------|
| build | not available (no evidenced command) — `angular.json` defines a `build` target but `package.json` has no build script and no CLI dependency | `angular.json` | — |
| test | `npm test` (runs `ng test`, Karma builder) | `package.json` scripts.test; `angular.json` architect.test | run locally; needs `@angular/cli` and `@angular-devkit/build-angular`, which are not declared in `package.json` |
| format | not available (no evidenced command) | — | — |
| lint | not available (no evidenced command) | — | — |
| migration/deploy | not available (no evidenced command) | — | manual/CI-only |
| data-validation | not available (no evidenced command) | — | — |

The only committed workflow (`.github/workflows/docs-sync-check.yml`) runs framework checks, not application commands.

### Angular Version
- Angular 19 (`^19.0.0`, `package.json`): out of Angular's support window and below v21 — upgrade debt (DEBT-001). Zone-based change detection (no zoneless provider in `src/main.ts`).

### Architecture
- Standalone components only (`standalone: true`, no NgModules); `inject()` for DI, no constructor injection (`src/app/orders/order-list.component.ts`).
- No routing yet; all features render from `AppComponent`.

### Component Design
- Inline templates with built-in control flow (`@if`/`@for` with `track`) (`order-list.component.ts`).
- No component sets `changeDetection` (default eager); OnPush is not used.
- State is local `signal()`s in the component; no shared store.

### Forms
- Reactive forms with `FormBuilder` and `Validators` (`profile-form.component.ts`); `FormGroup` is untyped (`any` values).

### State Management
- Component-local signals; server data loaded in `ngOnInit` and written into signals. No NgRx/NGXS/BehaviorSubject stores.

### RxJS
- Services return cold `Observable<T>`; component `.subscribe()`s manually with `catchError` + `finalize` (`order-list.component.ts`); one-shot HTTP, so no explicit cleanup.

### API/HTTP
- Services wrap `HttpClient` with `providedIn: 'root'`, relative URLs (`/api/...`), typed responses for orders; `UserService.updateProfile` is untyped. `provideHttpClient()` without interceptors; no global error handling — errors handled per component with an inline message.

### Typing
- `strict`, `noImplicitReturns`, `noPropertyAccessFromIndexSignature`, `strictTemplates` on (`tsconfig.json`).

### Styling / SSR
- No styles, SSR, or hydration present.

### Testing
- Karma builder configured; specs use Jasmine-style globals with `TestBed` and `HttpTestingController`, asserting rendered text (`order-list.component.spec.ts`). Only `OrderListComponent` has a spec.
- Target test shape: unit-dense, component specs rendering real templates with HTTP mocked at the boundary.

---

## Architecture Decisions

<!-- One-line INDEX of significant decisions here (ID — title — date — link). Full ADRs
     (Decision → Context → Consequences → Review notes) live in docs/architecture-decisions.md,
     added by the create-adr skill. Rationale: AGENTS.md loads on nearly every agent turn and
     anchors the prompt cache — keep it small; detail loads on demand. -->

Full detail in [docs/architecture-decisions.md](./docs/architecture-decisions.md). No significant decisions are evidenced beyond the defaults above (standalone components, signals for local state, reactive forms); none recorded yet.

---

## Common Tasks

When a task matches a skill below, invoke that skill with your skill tool before planning or editing.

Skills are a delivery-profile superset, not evidence that they apply. Use only when repository
evidence satisfies the gate:

- `add-tests` — add specs for existing code in the project's evidenced test shape
- `dependency-audit` — scan for vulnerable/deprecated/outdated npm packages, set up automated scanning, or upgrade Angular one major at a time
- `create-adr` — record a significant architecture decision in Architecture Decisions
- `remember-for-team` — draft a team wiki entry (gotcha/context/recipe/failed-approach) for PR review
- `enforce-architecture` — wire the deterministic DIP/layering CI gate (dependency-cruiser)
- `enforce-standards` — make `@ts-ignore`, `eslint-disable`, and focused/skipped specs build-breaking (ESLint `noInlineConfig` + rule severities)

`/bootstrap` drafts a project skill under `.claude/skills/`, the shared canonical location for Claude Code and supported GitHub Copilot skill surfaces, for an operation this repository repeats at least three times; add its line here once the team approves the draft.

**Registers**: [TECH_DEBT.md](./TECH_DEBT.md) tracks delivery debt. [SECURITY_FINDINGS.md](./SECURITY_FINDINGS.md) tracks security findings separately with remediation SLAs (Critical = 7 days, High = 30 days). Do not merge them — audit teams treat these differently. Security findings come from `/security-gate` and the `security-auditor` agent, not from feature work. AI-assisted file changes are appended to [.claude/ai-audit.log](./.claude/ai-audit.log) automatically by the PostToolUse hook.

---

## Boy Scout Rule

**Bug-fix scope.** See the framework-owned workflow scope.

### Always apply (low-effort, low-risk — subject to Bug-fix scope above):

**Add:**
1. Replace manual `ngOnDestroy` subscription cleanup with `takeUntilDestroyed()`
2. Replace nested `.subscribe()` with the appropriate RxJS operator
3. Replace `any` with proper types

**Subtract:**
4. Unused TypeScript imports and unused RxJS operator imports
5. Commented-out code or template blocks (more than 1 line — version control preserves them)
6. Unreferenced private fields, methods, or local variables that `tsc`/lint flags
7. Unused inputs and outputs (`@Input`/`@Output` or `input()`/`output()`)

> **Not auto-applied: moving a component off eager change detection** — adding `ChangeDetectionStrategy.OnPush` on v21, or removing `Eager`/`Default` on v22+, where an unset `changeDetection` already means OnPush. It is a semantic change, not a cleanup — it can silently break views that mutate inputs in place, rely on change detection ticking from `setInterval`/Promises/third-party callbacks, or expect re-render on ambient state changes. Treat it as an explicit, tested change when the component is the primary target, not a drive-by edit. The `Eager` that `ng update` writes on v22 is pre-existing upgrade debt, even where lint reports it, not licence for a drive-by switch. New components follow `docs/defaults.md`.

### Apply only when the file is the primary target of the change:

**Add:**
8. Replace manual `.subscribe()` with `async` pipe where possible
9. Extract complex template expressions into a `computed()`, a pipe, or a component member
10. Move a component off eager change detection (add `ChangeDetectionStrategy.OnPush` on v21; remove `Eager`/`Default` on v22+) — but only after verifying the component's data flow (immutable inputs, no in-place mutation, no reliance on ambient ticking) and after manual/test verification that the view still updates correctly.

**Subtract:**
11. Inline single-consumer interfaces or abstract bases that are not a project-evidenced DI service seam — per Leanness. Preserve an existing project boundary when its evidence or correctness need requires it.
12. Collapse shallow service methods that just delegate to `HttpClient` with no transformation
13. Single-use pipes or directives — inline at the call site, or convert to a `computed()` or component member
14. Unused barrel re-exports in `index.ts`

Items 8–14 can significantly expand or reshape a diff. Only apply them when the file is what the task is specifically about, not when it's incidentally touched. This keeps PRs focused and reviewable.

---

## What We've Learned

Long-form learnings live in [LEARNINGS.md](./LEARNINGS.md). Read it when starting non-trivial work; append to it (don't overwrite) when you discover what works, what causes friction, or what rule needs adjusting.

LEARNINGS.md is an append-only chronological history (plus the declined-recipe registry); the team wiki ([docs/wiki/](./docs/wiki/INDEX.md)) holds current, scoped, individually-verifiable claims with an index — promote a durable LEARNINGS entry to a wiki entry via `remember-for-team`.
