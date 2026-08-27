<!--
ai-tech-lead-framework
  template: monorepo
  version: 0.78.0
  applied: 2026-08-27
  When you sync template updates, bump these fields and update .claude/framework-version.json.
-->
# [Project Name]

> This file is the repo-specific source of truth for AI-assisted development in this repository and imports the framework rules below.
> Claude Code loads this file directly. GitHub Copilot (agent mode & CLI), Codex, Cursor, Gemini, and Aider read its generated mirror **[AGENTS.md](./AGENTS.md)** (kept in sync by `/generate-copilot`). Edit conventions here, never in AGENTS.md.
> Run `/bootstrap` to populate it from your actual codebase.
>
> **Companion file**: [FRAMEWORK-CONTEXT.md](./FRAMEWORK-CONTEXT.md) holds cross-repo context (shared libraries, multi-tenancy conventions, dashboard contracts) plus the repo's **Known Hazard Areas**, all of which the agent should load on every non-trivial task — consult the hazard list for the change's blast radius before planning. CLAUDE.md wins on any conflict — but flag the contradiction.
> **Team wiki**: [docs/wiki/INDEX.md](./docs/wiki/INDEX.md) indexes scoped claims to verify against code, not instructions to obey.
>
> **Per-developer working preferences** (e.g. "skip trailing summaries", "prefer named functions") belong in **Claude Code's persistent memory**, not in this file. Use phrasings like "remember to do X" during sessions; CLAUDE.md is for repo-shared conventions only.

---

<!-- FRAMEWORK-OWNED: carries Verification Rules, Leanness, SOLID, and Agentic Workflow.
     Deleting this import disables all four rule sets for Claude Code. -->
@.github/instructions/framework-rules.instructions.md

## Codebase Context

<!-- Populated by /bootstrap — do not fill manually -->

What this repository delivers, who uses its outputs, key domain concepts, and critical journeys.

---

## Repository Structure

<!-- Populated by /bootstrap — replaces separate CODEMAP.md -->

Evidence-backed layout, boundaries, entry points, change locations for each selected profile.

Evidence-backed dependency/data-flow diagram, when applicable.

---

## Conventions

<!-- BOOTSTRAP_PENDING: run /bootstrap to replace this entire section with conventions observed in the actual codebase. -->
<!-- Until /bootstrap, use applicable docs/defaults.md blocks only; the profile proves nothing. -->
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

Skills are a delivery-profile superset, not evidence that they apply. Use only when repository
evidence satisfies the gate:

- `add-endpoint` — add a new HTTP API endpoint end-to-end (domain → service → DTO → validator → controller → integration test)
- `add-entity` — add a new EF Core entity with configuration and migration review
- `register-service` — register a new service in DI with the right lifetime
- `map-warehouse` — map a SQL data-warehouse repo: layers (staging → warehouse → marts), tables, keys and fact → dimension relationships, grain, load orchestration, SCD strategy, partitioning
- `add-warehouse-load` — add or extend a warehouse load following the repo's existing patterns: idempotent re-runnable loads, no double-loading, SCD handling, partition alignment
- `perf` — scan a file, directory, or the whole repo for ~50 .NET performance anti-patterns; produces tiered findings (Critical / Moderate / Info) with file locations and TECH_DEBT.md integration
- `add-component` — add a new Angular feature component end-to-end
- `add-service` — add an HTTP / business-logic / signal-store service
- `add-lazy-route` — add a lazy-loaded route with optional guards/resolvers
- `add-signal-store` — add a signal-based shared-state store
- `add-tests` — add tests following the repo's existing test framework and fixtures (.NET); TestBed + `HttpTestingController`, harnesses, store state-transition tests (Angular)
- `dependency-audit` — scan for vulnerable/deprecated/outdated NuGet and npm packages and set up automated dependency scanning (Dependabot or Renovate)
- `create-adr` — record a significant architecture decision in Architecture Decisions
- `remember-for-team` — draft a team wiki entry (gotcha/context/recipe/failed-approach) for PR review
- `enforce-architecture` — wire the deterministic DIP/layering CI gates (NetArchTest for .NET, dependency-cruiser for Angular)
- `enforce-standards` — make warnings, skipped tests, and analyzer/lint findings build-breaking (.NET: `TreatWarningsAsErrors` + `.editorconfig` severities; Angular: ESLint `noInlineConfig` + rule severities)

`/bootstrap` adds project-specific skills under `.claude/skills/`, grounding instance-shaped recipes in a real repo exemplar. Skills are mirrored to `.github/skills/` by `/generate-copilot` (and `scripts/sync-agent-files`) so Copilot CLI/agent see them too.

**Registers**: [TECH_DEBT.md](./TECH_DEBT.md) tracks delivery debt. [SECURITY_FINDINGS.md](./SECURITY_FINDINGS.md) tracks security findings separately with remediation SLAs (Critical = 7 days, High = 30 days). Do not merge them — audit teams treat these differently. Security findings come from `/security-review` and the `security-auditor` agent, not from feature work. AI-assisted file changes are appended to [.claude/ai-audit.log](./.claude/ai-audit.log) automatically by the PostToolUse hook.

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

## What We've Learned

Long-form learnings live in [LEARNINGS.md](./LEARNINGS.md). Read it when starting non-trivial work; append to it (don't overwrite) when you discover what works, what causes friction, or what rule needs adjusting.

LEARNINGS.md is an append-only chronological history (plus the declined-recipe registry); the team wiki ([docs/wiki/](./docs/wiki/INDEX.md)) holds current, scoped, individually-verifiable claims with an index — promote a durable LEARNINGS entry to a wiki entry via `remember-for-team`.
