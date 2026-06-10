Analyse this Angular codebase and set up the AI Tech Lead framework. This is the one-time bootstrap that makes the repo AI-ready.

## Input
$ARGUMENTS

Execute all phases below in sequence. Do not skip any phase. Do not ask for confirmation between phases — run the full pipeline. **Exceptions:** Phase 2b and Phase 3d-bis pause for developer input before generating artifacts; this is intentional.

---

## Pre-flight checks

Before starting analysis:
1. **Locate the project root** — find `angular.json`. If not found, check for `nx.json` or `project.json` (Nx workspace). All paths are relative to this root. If it's a monorepo (e.g., `apps/` structure), note which apps/libs exist and adjust paths in generated output.
2. **Check Angular version** — read `package.json` for `@angular/core` version. Note whether it's 17+ (standalone default, signals, new control flow) or older. Adjust conventions accordingly.
3. **Check for existing configuration** — if `CLAUDE.md` already has populated content (not just template defaults), back up the existing conventions section and merge your findings with what's already there rather than overwriting. Never touch `LEARNINGS.md` — it is append-only.
4. **Large codebases** — if the project has more than 200 components, focus analysis on the most actively changed areas (check git log). Note which areas were analysed and which were skipped.
5. **Mixed-stack detection** — count `.cs` / `.csproj` / `.sln` files outside `node_modules/` and `dist/`. If a `.sln` exists or more than ~50 `.cs` source files exist, flag this as a mixed-stack repo. After Phase 3 generation, add a note in the final report recommending the user create `.github/instructions/<stack>.instructions.md` with `applyTo:` frontmatter (see README "Mixed-stack repos" section). Do not auto-generate the secondary-stack instructions file — the user picks the rules.

---

## Phase 1 — Analysis

Dispatch the seven analysis passes (A1–A7) **in parallel** via the `Task` tool, each invoking the `bootstrap-pass` subagent with the pass id as input. Example call shape:

```
Task(subagent_type="bootstrap-pass", description="Bootstrap pass A1", prompt="Run pass A1.")
```

Send all seven Task calls in a single message so they execute concurrently. Wait for all seven to return.

Each subagent returns structured findings; you do **not** redo the analysis. Just collect the seven results — they feed Phase 2.

The pass definitions below are the source of truth the subagents read. Do not duplicate the pass logic inline; the subagents read this file directly.

### A1: Module Architecture & Lazy Loading
- NgModules vs standalone — split, consistency
- Lazy vs eager routes — eager justifications
- Barrel files (`index.ts`) — usage, circular-dep risk
- Shared/core module boundaries — clarity
- Routing — flat/nested, guards, resolvers
- Module-level circular dependencies

### A2: State Management
- Approach — NgRx / NGXS / Akita / BehaviorSubjects / signals / mix
- Local vs shared state — boundary clarity
- Informal stores — services-with-BehaviorSubjects pattern
- Prop drilling — through how many levels
- Server state — caching, staleness, loading/error
- NgRx/similar — actions/reducers/effects/selectors structure or over-engineered

### A3: Component Design
- Smart vs dumb — applied, consistent
- OnPush coverage — gaps
- Template complexity — heavy logic, deep nesting, complex expressions
- God components
- `@Input`/`@Output` patterns — anti-patterns
- Lifecycle hook misuse
- Signals adoption (Angular 16+)

### A4: RxJS Hygiene
- Subscription cleanup pattern — takeUntil / takeUntilDestroyed / async pipe / DestroyRef
- Nested subscribes — locations
- Manual `.subscribe` vs async pipe — ratio
- Operator misuse — switchMap/mergeMap/concatMap/exhaustMap choice
- Stream error handling — caught vs silent death
- Subject usage — justified or crutch
- Leak risks

### A5: API Layer & Error Handling
- HTTP service organisation
- Interceptors — auth/error/loading/retry coverage
- Request/response typing — interfaces vs `any`
- Error handling — global/per-service/inconsistent
- Loading & error UI signalling
- Retry logic — present, appropriate
- Environment config — API URLs/keys

### A6: Build, Testing & Code Quality
- Angular version currency
- `angular.json` — unusual config, missing optimisation flags
- tsconfig — strict, permissive overrides
- `package.json` — outdated/deprecated/redundant
- Bundle size — obvious bloat
- Test framework (Karma/Jasmine, Jest, Vitest, Cypress, Playwright)
- Coverage gaps
- Test quality — behaviour vs implementation
- `any` usage; strict null checks
- Dead code, unused imports, `console.log`

### A7: Project-Specific Skill Discovery

Mine this codebase for **tribal-knowledge recipes** — multi-step operations that recur but carry non-obvious, repo-specific steps that a competent agent would not infer from a single instance or from the framework alone.

**Qualifying criterion (both must hold):**
1. **Recurs** — the same multi-step operation appears 3+ times (naming cluster + structural pattern).
2. **Carries tribal knowledge** — at least one step in the sequence is non-obvious and repo-specific (e.g., "every new feature module also requires a route registration, a NavBar entry, and a permission check"). Pure structural repetition dictated by the framework does **not** qualify.

**Exclusions — never propose these (framework-mandated shapes, not tribal knowledge):**
- Generated code: `node_modules/`, `dist/`, `.angular/`
- Every `*.component.ts` scaffolded shell (the framework shapes its structure)
- Every `*.service.ts` that only wraps `HttpClient` with no repo-specific behaviour
- Every NgModule / standalone bootstrap boilerplate
- Every `*.spec.ts` test class

**Return candidates only** (the parent `/bootstrap` writes the skills). For each candidate:
- Proposed `name` (kebab-case)
- Terse `description` (one line — what operation it scaffolds, in plain engineering language)
- Recurring **constellation** — what files and steps always travel together
- Single cleanest **existing instance** (file path)
- One-line **confidence/why-tribal** note — the non-obvious repo-specific step that disqualifies it as a pure-framework pattern

**Low count by design.** Propose ≤3–5 candidates; fewer is better — precision beats recall, since reviewers approve at a glance. Return an empty findings block if no candidate meets the criterion.

**Check `LEARNINGS.md` for declined recipes** before proposing. If a candidate's name or constellation matches a `## Declined recipe:` entry, skip it — the team removed it deliberately.

---

## Phase 2 — Synthesis

From the seven analysis passes, synthesise findings into three priority tiers:

1. **Architectural risks** — affect scalability or correctness
2. **Technical debt** — slows delivery or causes bugs
3. **Quick wins** — improve quality with minimal effort

For each item: current pattern → target pattern → brief rationale.

---

## Phase 2b — Clarify before writing

**If this `/bootstrap` is being invoked from within `/adopt`:** skip this phase entirely — the developer already provided codebase context in `/adopt` phases 1–6.

Before generating any artifact, ask the developer a small number of targeted questions — **only where human judgment materially changes the output and the code alone cannot resolve it.** Collect all questions into a **single message** (never drip one at a time). Limit to ≤5 questions.

**Ask about:**
1. **Convention contradictions** — if two conflicting patterns exist for the same area (e.g. NgRx store in some features, BehaviorSubject services in others): *"Your codebase uses both [A] (e.g. NgRx in `feature-a/`) and [B] (e.g. BehaviorSubject services in `feature-b/`) for state management. Which is the intended approach — or are these genuinely different contexts?"* Frame as a plain engineering question about the codebase, never about which CLAUDE.md section to use.
2. **Pattern intent** — if a pattern recurs but is applied inconsistently: *"I see [X] in [N] places but not all. Is this intentional (applied selectively) or drift (should be consistent)?"*

**Do not ask** about things determinable from code (naming patterns, Angular version, file structure), matters of taste with no right answer, or hazard areas (those get their own confirmation in Phase 3d-bis).

**Skip signal:** if the developer says "skip", "proceed", or "accept defaults", continue without adding any markers. Use `<!-- INFERRED -->` only when the code gives genuinely contradictory signals and the agent still cannot determine intent after reading multiple files — not as a default fallback when the developer skips.

---

## Phase 3 — Generate artifacts

### 3a: Populate CLAUDE.md

Read the existing CLAUDE.md template in the project root. Replace every placeholder section with real findings from this codebase:

- **Codebase Context**: what this app does, users, domain concepts, critical journeys
- **Repository Structure**: actual folder layout with module dependency diagram
- **Conventions**: the rules this codebase actually follows (or should follow), with rationale. Use the subsection structure from `docs/defaults.md` (Angular Version, Architecture, Component Design, State Management, RxJS, API/HTTP, Typing, Testing) as a starting checklist; record observed reality, deviating from defaults where the codebase does. If Angular version is below 17, adjust conventions to match what's available. **Delete the `BOOTSTRAP_PENDING` HTML comment and the "_Not yet populated_" placeholder line** when this section is filled in.
- **Architecture Decisions**: index every significant decision found (intentional or accidental) as a one-line entry here; write the full Decision → Context → Consequences → Review notes to `docs/architecture-decisions.md` (create it if missing). Keeping detail out of CLAUDE.md holds it within the token budget — it loads on nearly every turn.
- **Common Tasks**: do NOT write recipes inline in CLAUDE.md. Instead, audit `.claude/skills/` against this codebase: keep a default skill if its recipe matches reality (adjust steps where they don't); add new skills under `.claude/skills/<name>/SKILL.md` for project-specific recipes (each with `name` + `description` frontmatter); delete defaults that don't apply. Update the Common Tasks bullet list in CLAUDE.md to match the final skill set — one terse line per skill, no USE-FOR/DO-NOT-USE-FOR trigger blocks.

  **Writing A7-discovered skills:** Before writing any A7 candidate as a skill, cross-check it against Phase-2 synthesis — if the pattern is flagged as an anti-pattern or Tier-1–2 debt, route it to `TECH_DEBT.md` instead (do NOT canonize a known problem). Each written mined skill gets `origin: discovered` in its frontmatter so the PR reviewer can focus scrutiny there. "No exemplar" is first-class: if no instance passes the quality cross-check or the path doesn't resolve, write the skill abstract.

  **Exemplar grounding (instance-shaped skills):** For `add-component`, `add-service`, `add-lazy-route`, `add-signal-store`, and any mined `add-X` skill: confirm a real instance exists (Verification Rule #1 — Read/Grep confirms the path). If it passes the quality cross-check (not flagged as debt), append one prose line to the skill file, **below** any existing "Match CLAUDE.md > Conventions" instruction: *"For a concrete current instance in this repo, see `<path>` — reproduce its **conventions and structure**, not its contents; CLAUDE.md > Conventions wins on any conflict."* Exempt process skills (`add-tests`, `create-adr`, `dependency-audit`, `enforce-architecture`) — they are not instance-shaped "add an X" recipes.
- **Boy Scout Rule**: priority improvements based on the actual debt found in Phase 2

Preserve the Agentic Workflow section as-is. Never touch `LEARNINGS.md` — it is append-only.

**Token budget**: `CLAUDE.md` loads on nearly every agent turn and anchors the prompt cache — keep it ≤ ~400 lines. Put verbose detail (long ADRs, exhaustive structure dumps) in on-demand files (`docs/`, skills); keep CLAUDE.md to the high-frequency rules. `scripts/docs-sync-check.*` warns past the budget.

### 3b: Generate TECH_DEBT.md

Create TECH_DEBT.md in the project root with this structure:

```markdown
# Tech Debt Register

> One block per item. Sort by severity then effort. Reference items by ID in commit messages and PRs.

---

## DEBT-001: <Short title>

- **Category**: <see list below>
- **Severity**: Critical | High | Medium | Low
- **Effort**: S (<1hr) | M (half day) | L (1-2 days) | XL (needs spike)
- **Files**: `path/to/foo.component.ts:42`, `path/to/bar.service.ts`

### Issue
<1-3 sentences on what's wrong and why it matters>

### Recommended fix
<1-3 sentences on the change and any risks>

---

## Trojan Horse Opportunities

Group DEBT IDs by feature area so developers can bundle cleanup into feature work:

- **Auth**: DEBT-003, DEBT-007
- **Reporting**: DEBT-002, DEBT-011
```

Categories: Architecture, State Management, RxJS, Component Design, Testing, Types, Performance, Dependencies, Security
Severity: Critical / High / Medium / Low
Effort: S (< 1hr) / M (half day) / L (1-2 days) / XL (needs spike)

Sort by severity then effort. One `## DEBT-NNN` block per item.

### 3c: AGENTS.md (generated full mirror)

`AGENTS.md` is a **generated mirror** of CLAUDE.md's portable rules (Verification, Leanness, Conventions, Boy Scout, Agentic Workflow, Common Tasks). It exists so AGENTS.md-native tools — GitHub Copilot agent mode & CLI, Codex, Cursor, Gemini CLI, Aider — get the actual ruleset, not a pointer. **Do not hand-write a pointer file.**

AGENTS.md is produced by the `/generate-copilot` workflow (Part B), which Phase 3f runs **after** Phase 3a has populated `CLAUDE.md > Conventions`. So there is nothing to do here except ensure 3f runs. If a stale or pointer-style `AGENTS.md` already exists, it will be **regenerated** (overwritten) by 3f — do not preserve hand edits to it.

### 3d: Populate FRAMEWORK-CONTEXT.md > Detected Framework Packages

Read `package.json` (and `package-lock.json` if present for resolved versions). For each entry in `dependencies` and `peerDependencies`, check whether the package is part of the team's shared framework.

**How to identify framework packages**: read the existing `FRAMEWORK-CONTEXT.md > Shared Libraries` section. Any package whose name matches an entry there is a framework package. If `Shared Libraries` is empty or template, fall back to a heuristic: packages whose name starts with the org/team scope (look at the most common scope among `dependencies` — e.g. `@acme/*`, `@myorg/*`).

Replace the `## Detected Framework Packages` section with a populated table:

```markdown
## Detected Framework Packages

<!-- Auto-populated by /bootstrap. -->

| Package | Version | Source |
|---------|---------|--------|
| @acme/ui-kit | 3.1.0 | package.json (dependencies) |
| @acme/auth-client | 2.4.7 | package.json (dependencies) |
```

**Delete the `DETECTED_FRAMEWORK_PACKAGES_PENDING` HTML comment** when this section is populated. If no framework packages were found, replace the table with a single line: `_No framework packages detected in this repo._` and still delete the marker.

Do **not** edit any other section of FRAMEWORK-CONTEXT.md here — `Known Hazard Areas` is handled in 3d-bis, and the five context sections are drafted in 3d-ter.

### 3d-bis: Confirm and write FRAMEWORK-CONTEXT.md > Known Hazard Areas

From the Phase-2 **Tier-1 architectural risks** (and any domain-invariant / security findings — e.g. RxJS subscription leaks, missing sanitisation, auth interceptor gaps), identify up to ~12 candidate hazard areas. **Before writing anything to FRAMEWORK-CONTEXT.md**, ask the developer to confirm each one — in a **single message** (not dripped):

For each candidate, ask a plain, answerable engineering question:
> "I found a potential hazard in [Area / file]: [one plain sentence describing the specific risk — e.g. 'the auth interceptor does not retry after a 401 token refresh, so a race condition could leave the user with a broken session']. Is this (a) a confirmed risk to track, (b) not actually a risk in this codebase, or (c) you're not sure?"

Add a "skip all — mark as unverified" escape at the end of the message.

Map each answer to a row status:
- **(a) confirmed** → `Status = [VERIFIED]`
- **(b) not a risk** → `Status = [REVIEWED: not a hazard — <today's date>]` (write the row — kept for auditability, not dropped)
- **(c) unsure / skip all** → `Status = [UNVERIFIED]` (same as before this change — graceful degradation)

Then write the `## Known Hazard Areas` table to FRAMEWORK-CONTEXT.md with the answered statuses. One row per hazard: `Area / file(s)` · `Hazard` (the specific risk) · `Status` · `Reviewed` (today's date).

- **Delete the `KNOWN_HAZARD_AREAS_PENDING` marker** once written. If nothing notable surfaced, replace the table body with `_No notable hazards detected — confirm with the team._` and still delete the marker.
- Keep it tight (≤ ~12 rows); deeper items belong in TECH_DEBT.md.
- Do not upgrade `[UNVERIFIED]` rows yourself; only the developer can do that.

### 3d-ter: Draft the remaining FRAMEWORK-CONTEXT.md context sections

The five context sections — Production Architecture, Shared Libraries, Multi-Tenancy Conventions, Dashboard Integration Contracts, Cross-Service Communication — describe cross-repo facts, but each leaves an observable footprint in this repo. Draft them from that footprint instead of leaving template placeholders. **Draft what the code shows; hand what it cannot show to the maintainer — explicitly.**

**Ground rules:**
1. **Only fill a section that still carries its `*_PENDING` marker** (or the original template placeholder text). If a maintainer has written anything there, leave that section untouched.
2. **Single-repo evidence only** (Verification Rule #1). Every statement must trace to something you Read/Grep'd: a config file, a package reference, an interceptor or provider. Never assert facts this repo cannot show — what the backend does with a header, why an org-wide convention exists, a shared library's full public surface.
3. **Open each drafted section** with: `<!-- Auto-drafted by /bootstrap on <date> from this repo's code. Describes what THIS repo shows; a maintainer should add the cross-repo context the code cannot prove. -->` — and delete that section's `*_PENDING` marker.
4. **Verified negatives beat placeholders.** If a section has no signals, replace the placeholder with one line stating what was checked, e.g. `_No multi-tenancy signals found in this repo (no tenant resolution, tenant headers, or tenant-scoped config as of <date>). If the system is multi-tenant at another layer, a maintainer should document it here._` — and still delete the marker.
5. **Keep it scannable** — a short paragraph or a few bullets per section. These are context anchors, not documentation dumps.

**Per-section evidence to gather:**

- **Production Architecture** — classify the repo: application vs publishable library (`ng-packagr` targets in `angular.json` / Nx project config). Consumes: API base URLs and auth provider config in `environment*.ts` (or a runtime config fetch), backend(s) it talks to. Exposes: the route surface / app shell, published entry points for libraries. One paragraph.
- **Shared Libraries** — one entry per package detected in 3d, built from this repo's usage: pinned version, the components / directives / providers / services actually imported (Grep the import sites), where it is configured (e.g. `provideX(...)` in the app config). **Heading honesty**: title the API list `Consumed API surface (observed in this repo)` — never `Public API surface (latest)` — and end each entry with: `Purpose, pitfalls, and the full surface need the library's source repo or owner.` If 3d found no framework packages, apply ground rule 4.
- **Multi-Tenancy Conventions** — Grep for tenant signals: subdomain/path tenant resolution, a tenant header set in an interceptor, tenant-scoped theming or feature flags, tenant guards/resolvers, `Tenant*` types. Document the observed resolution and scoping pattern, with file references.
- **Dashboard Integration Contracts** — control-plane registration calls, embedded-shell or `postMessage` contracts, heartbeat/health pings, required metadata in configuration.
- **Cross-Service Communication** — the interceptor chain (auth token, error mapping, correlation-ID headers), API base URL and versioning conventions, typed error/response envelopes, WebSocket/SSE usage.

No interactive confirmation here — the drafts land in the PR diff where reviewers correct wrong *content* (the same review path as mined skills), and every cross-repo blank is explicitly handed to the maintainer by the drafted comment.

### 3e: Initialise SECURITY_FINDINGS.md

If `SECURITY_FINDINGS.md` does not exist at the repo root, create it using the framework template. Do not pre-populate findings — security findings come from `/security-review`, not from bootstrap analysis.

If `SECURITY_FINDINGS.md` already exists, leave it entirely alone.

### 3f: Generate the agent-facing derived files

Run the `/generate-copilot` workflow. It regenerates **both** derived files from the now-populated CLAUDE.md:

- **`.github/copilot-instructions.md`** — slim (≤80 lines), terse imperative one-liners, Conventions + always-apply Boy Scout only. For **inline editor completions**.
- **`AGENTS.md`** — full mirror of CLAUDE.md's portable rules (Verification, Leanness, Conventions, Boy Scout, Agentic Workflow, Common Tasks), preserving the `GENERATED FILE` banner. For **AGENTS.md-native tools** (Copilot agent mode & CLI, Codex, Cursor, Gemini, Aider) — they get the real ruleset, not a pointer.

See `.claude/commands/generate-copilot.md` for the exact rules for each file.

---

## Phase 4 — Report

Run `git diff CLAUDE.md` and `git diff TECH_DEBT.md` to show the user exactly what changed. Present the diff summary before the rest of the report.

Then output:
- Number of findings per severity
- Top 3 architectural risks
- Top 3 quick wins
- Files generated/modified
- **New project-specific skills discovered (A7) — review these in the PR diff**: for each skill written from the A7 discovery pass, list: skill name, one-line trigger phrase (what operation it scaffolds, in plain engineering language — e.g. "a recipe for adding a new feature module with routing and a permission guard"), pinned exemplar file (or "(no exemplar — abstract only)"), and the why-tribal note. Omit this bullet entirely if A7 returned no candidates.
- **FRAMEWORK-CONTEXT.md sections drafted from code (3d-ter)**: one line per section — what was found (e.g. "Cross-Service Communication: auth + correlation-ID interceptors, typed error envelope in `core/api/`") or the verified negative. Remind the user: these describe what the code shows; anything about *other* repos and services still needs a maintainer to fill in (the drafted comment in each section says exactly that).

**Important**: the Conventions section was generated from code analysis and your Phase 2b answers. Verify it before relying on it — sections marked `<!-- INFERRED -->` flag specific areas where the code gave conflicting signals that couldn't be resolved automatically. All other sections reflect observed code patterns; review them for accuracy, not for AI-architecture decisions.
