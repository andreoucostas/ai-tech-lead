Analyse this .NET codebase and set up the AI Tech Lead framework. This is the one-time bootstrap that makes the repo AI-ready.

## Input
$ARGUMENTS

Execute all phases below in sequence. Do not skip any phase. Do not ask for confirmation between phases — run the full pipeline. **Exceptions:** Phase 2b and Phase 3d-bis pause for developer input before generating artifacts; this is intentional.

---

## Pre-flight checks

Before starting analysis:
1. **Locate the solution root** — find the `.sln` file. All paths are relative to this root. If the `.sln` is in a subdirectory (e.g., `src/`), note this and adjust paths in generated output.
2. **Check .NET version** — read `<TargetFramework>` from csproj files and check for `global.json`. Note whether it's .NET 6/7/8/9. Adjust conventions accordingly (e.g., minimal APIs from .NET 6+, primary constructors from .NET 8+, `required` keyword from C# 11+). Also check for `Directory.Build.props` — it affects build and analyser behaviour across the entire solution.
3. **Check for existing configuration** — if `CLAUDE.md` already has populated content (not just template defaults), back up the existing conventions section and merge your findings with what's already there rather than overwriting. Never touch `LEARNINGS.md` — it is append-only.
4. **Large codebases** — if the solution has more than 30 projects, focus analysis on the most actively changed projects (check git log). Note which projects were analysed and which were skipped.
5. **Mixed-stack detection** — count `.ts` / `.html` / `.scss` files outside `obj/`, `bin/`, `wwwroot/lib/`, and `node_modules/`. If more than ~50 source files of another stack exist, flag this as a mixed-stack repo. After Phase 3 generation, add a note in the final report recommending the user create `.github/instructions/<stack>.instructions.md` with `applyTo:` frontmatter (see README "Mixed-stack repos" section). Do not auto-generate the secondary-stack instructions file — the user picks the rules.

---

## Phase 1 — Analysis

Dispatch the eight analysis passes (A1–A8) **in parallel** via the `Task` tool, each invoking the `bootstrap-pass` subagent with the pass id as input. Example call shape:

```
Task(subagent_type="bootstrap-pass", description="Bootstrap pass A1", prompt="Run pass A1.")
```

Send all eight Task calls in a single message so they execute concurrently. Wait for all eight to return.

Each subagent returns structured findings; you do **not** redo the analysis. Just collect the eight results — they feed Phase 2.

The pass definitions below are the source of truth the subagents read. Do not duplicate the pass logic inline; the subagents read this file directly.

### A1: Solution Architecture
- Project layout — count, types, responsibilities
- Layering — API/domain/application/infrastructure/shared
- Dependency direction — inward-only correctness
- Entry points — controllers, hosted services, middleware pipeline
- Configuration — appsettings, options pattern, environment splits

### A2: Domain & Data Access
- Entity structure — rich vs anaemic
- ORM — EF Core / Dapper / both; DbContext organisation
- Repository pattern — value-add vs ceremony
- Migration management
- Query placement — service layer vs controllers
- N+1, missing includes, untracked-query opportunities

### A3: Dependency Injection & Services
- Registration — individual / by convention / extension methods
- Lifetimes — scoped/transient/singleton correctness; lifetime mismatches
- Interface usage — meaningful or ceremony
- Cross-cutting — logging/validation/exception handling
- MediatR/CQRS — present, consistency

### A4: API Design & Middleware
- Controller thinness
- Request/response DTOs — separated from domain
- Validation — DataAnnotations / FluentValidation / manual
- Error handling — middleware / filters / try-catch
- Auth setup
- API versioning
- Middleware pipeline order

### A5: Testing
- Test projects, framework (xUnit/NUnit/MSTest), mocking framework
- Coverage gaps
- Test quality — behaviour vs implementation
- Integration tests — `WebApplicationFactory` usage
- Fixtures, builders, helpers

### A6: Code Quality & Dependencies
- Async hygiene — sync-over-async, `async void`, missing `CancellationToken`
- Null handling — NRT enabled, consistency
- Exception handling patterns
- Logging — structured, levels, sensitive data
- NuGet — outdated/deprecated/redundant
- .NET version currency

### A7: Financial Domain Invariants
Run only if the codebase shows financial domain signals (look for: currency/money/amount/balance/ledger/payment/trade/account in class names, method names, or comments; `decimal` fields named `Amount`/`Balance`/`Price`; presence of packages like `NodaMoney`, `Money.Net`, or regulatory report namespaces).

If no financial signals found, return: `A7: No financial domain signals detected — skipping.`

If signals found, identify and report:
- **Monetary precision**: are `decimal` types used for money fields? Any `double` or `float` on financial amounts? (flag as Critical)
- **Negative amount guards**: do deposit/credit/debit operations validate that amounts are positive before writing?
- **Idempotency**: do payment or transaction-creating operations have idempotency keys? Are they enforced at the DB layer (unique index) or only in application code?
- **Check-then-act races**: are balance reads and subsequent debits/credits within the same database transaction with appropriate isolation level? Flag any pattern that reads a balance then writes without a transaction or with `IsolationLevel.ReadUncommitted`.
- **Regulatory calculation isolation**: which methods or classes produce figures for regulatory reporting? Are they unit-tested with known inputs/outputs to verify calculation accuracy?
- **Decimal rounding strategy**: is `MidpointRounding` specified on `Math.Round` calls involving money? Inconsistent rounding is a regulatory audit finding.
- **Audit trail for financial mutations**: do write operations on financial entities log who made the change, when, and the before/after values?

### A8: Project-Specific Skill Discovery

Mine this codebase for **tribal-knowledge recipes** — multi-step operations that recur but carry non-obvious, repo-specific steps that a competent agent would not infer from a single instance or from the framework alone.

**Qualifying criterion (both must hold):**
1. **Recurs** — the same multi-step operation appears 3+ times (naming cluster + structural pattern).
2. **Carries tribal knowledge** — at least one step in the sequence is non-obvious and repo-specific (e.g., "every new tenant also requires a `SeedData` row, a feature-flag entry, and a migration"). Pure structural repetition dictated by the framework does **not** qualify.

**Exclusions — never propose these (framework-mandated shapes, not tribal knowledge):**
- `Migrations/` files and EF Core scaffolded output
- `obj/` / `bin/` contents
- Every `*Controller` class
- Every `IEntityTypeConfiguration<T>` implementation
- Every xUnit/NUnit/MSTest test class

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

From the eight analysis passes (A7 may report no financial signals and self-skip), synthesise findings into three priority tiers:

1. **Architectural risks** — affect scalability or correctness
2. **Technical debt** — slows delivery or causes bugs
3. **Quick wins** — improve quality with minimal effort

For each item: current pattern → target pattern → brief rationale.

---

## Phase 2b — Clarify before writing

**If this `/bootstrap` is being invoked from within `/adopt`:** skip this phase entirely — the developer already provided codebase context in `/adopt` phases 1–6.

Before generating any artifact, ask the developer a small number of targeted questions — **only where human judgment materially changes the output and the code alone cannot resolve it.** Collect all questions into a **single message** (never drip one at a time). Limit to ≤5 questions.

**Ask about:**
1. **Convention contradictions** — if two conflicting patterns exist for the same area (e.g. manual DI registration in some files, convention scanning in others): *"Your codebase uses both [A] (e.g. `services.AddScoped<IFoo, Foo>()` in `file`) and [B] (e.g. `services.AddFromAssembly()` in `file`) for service registration. Which is the intended convention?"* Frame as a plain engineering question about the codebase, never about which CLAUDE.md section to use.
2. **Pattern intent** — if a pattern recurs but is applied inconsistently: *"I see [X] in [N] places but not all. Is this intentional (applied selectively) or drift (should be consistent)?"*
3. **.NET only — financial domain scope** — if A7 fired: *"I detected financial-domain signals in [area/file]. Should I apply strict decimal/idempotency rules across the entire [service/module] or only in the flagged files?"*

**Do not ask** about things determinable from code (naming patterns, framework version, file structure), matters of taste with no right answer, or hazard areas (those get their own confirmation in Phase 3d-bis).

**Skip signal:** if the developer says "skip", "proceed", or "accept defaults", continue without adding any markers. Use `<!-- INFERRED -->` only when the code gives genuinely contradictory signals and the agent still cannot determine intent after reading multiple files — not as a default fallback when the developer skips.

---

## Phase 3 — Generate artifacts

### 3a: Populate CLAUDE.md

Read the existing CLAUDE.md template in the project root. Replace every placeholder section with real findings from this codebase:

- **Codebase Context**: what this app does, users, domain concepts, critical journeys
- **Repository Structure**: actual project layout with dependency diagram
- **Conventions**: the rules this codebase actually follows (or should follow), with rationale. Use the subsection structure from `docs/defaults.md` (Architecture, Naming, DI, Data Access, API, Async, Null Handling, Logging, Testing) as a starting checklist; record observed reality, deviating from defaults where the codebase does. **Delete the `BOOTSTRAP_PENDING` HTML comment and the "_Not yet populated_" placeholder line** when this section is filled in.
- **Architecture Decisions**: index every significant decision found (intentional or accidental) as a one-line entry here; write the full Decision → Context → Consequences → Review notes to `docs/architecture-decisions.md` (create it if missing). Keeping detail out of CLAUDE.md holds it within the token budget — it loads on nearly every turn.
- **Common Tasks**: do NOT write recipes inline in CLAUDE.md. Instead, audit `.claude/skills/` against this codebase: keep a default skill if its recipe matches reality (adjust steps where they don't); add new skills under `.claude/skills/<name>/SKILL.md` for project-specific recipes (each with `name` + `description` frontmatter); delete defaults that don't apply. Update the Common Tasks bullet list in CLAUDE.md to match the final skill set — one terse line per skill, no USE-FOR/DO-NOT-USE-FOR trigger blocks.

  **Writing A8-discovered skills:** Before writing any A8 candidate as a skill, cross-check it against Phase-2 synthesis — if the pattern is flagged as an anti-pattern or Tier-1–2 debt, route it to `TECH_DEBT.md` instead (do NOT canonize a known problem). Each written mined skill gets `origin: discovered` in its frontmatter so the PR reviewer can focus scrutiny there. "No exemplar" is first-class: if no instance passes the quality cross-check or the path doesn't resolve, write the skill abstract.

  **Exemplar grounding (instance-shaped skills):** For `add-endpoint`, `add-entity`, `register-service`, and any mined `add-X` skill: confirm a real instance exists (Verification Rule #1 — Read/Grep confirms the path). If it passes the quality cross-check (not flagged as debt), append one prose line to the skill file, **below** any existing "Match CLAUDE.md > Conventions" instruction: *"For a concrete current instance in this repo, see `<path>` — reproduce its **conventions and structure**, not its contents; CLAUDE.md > Conventions wins on any conflict."* Exempt process skills (`add-tests`, `create-adr`, `dependency-audit`, `perf`, `enforce-architecture`) — they are not instance-shaped "add an X" recipes.
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
- **Files**: `path/to/Foo.cs:42`, `path/to/Bar.cs`

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

Categories: Architecture, Data Access, DI/Lifetime, API Design, Async, Testing, Types/Nullability, Performance, Dependencies, Security
Severity: Critical / High / Medium / Low
Effort: S (< 1hr) / M (half day) / L (1-2 days) / XL (needs spike)

Sort by severity then effort. One `## DEBT-NNN` block per item.

### 3c: AGENTS.md (generated full mirror)

`AGENTS.md` is a **generated mirror** of CLAUDE.md's portable rules (Verification, Leanness, Conventions, Boy Scout, Agentic Workflow, Common Tasks). It exists so AGENTS.md-native tools — GitHub Copilot agent mode & CLI, Codex, Cursor, Gemini CLI, Aider — get the actual ruleset, not a pointer. **Do not hand-write a pointer file.**

AGENTS.md is produced by the `/generate-copilot` workflow (Part B), which Phase 3f runs **after** Phase 3a has populated `CLAUDE.md > Conventions`. So there is nothing to do here except ensure 3f runs. If a stale or pointer-style `AGENTS.md` already exists, it will be **regenerated** (overwritten) by 3f — do not preserve hand edits to it.

### 3d: Populate FRAMEWORK-CONTEXT.md > Detected Framework Packages

Read every `*.csproj` and `Directory.Packages.props` file in the solution. For each `<PackageReference Include="..." Version="..." />` (or `<PackageVersion ...>` in central management), check whether the package is part of the team's shared framework.

**How to identify framework packages**: read the existing `FRAMEWORK-CONTEXT.md > Shared Libraries` section. Any package whose name matches an entry there is a framework package. If `Shared Libraries` is empty or template, fall back to a heuristic: packages whose name starts with the org/team prefix (look at the most common prefix among `PackageReference` entries — e.g. `Acme.*`, `MyOrg.*`).

Replace the `## Detected Framework Packages` section with a populated table:

```markdown
## Detected Framework Packages

<!-- Auto-populated by /bootstrap. -->

| Package | Version | Source |
|---------|---------|--------|
| Acme.Framework.Auth | 4.2.0 | src/MyApp.Api/MyApp.Api.csproj |
| Acme.Framework.Logging | 4.1.5 | Directory.Packages.props |
```

**Delete the `DETECTED_FRAMEWORK_PACKAGES_PENDING` HTML comment** when this section is populated. If no framework packages were found, replace the table with a single line: `_No framework packages detected in this repo._` and still delete the marker.

Do **not** edit any other section of FRAMEWORK-CONTEXT.md except `Known Hazard Areas` (next sub-step) — the rest are maintainer-curated.

### 3d-bis: Confirm and write FRAMEWORK-CONTEXT.md > Known Hazard Areas

From the Phase-2 **Tier-1 architectural risks** (and any domain-invariant / security findings — e.g. for .NET the A7 check-then-act / idempotency gaps), identify up to ~12 candidate hazard areas. **Before writing anything to FRAMEWORK-CONTEXT.md**, ask the developer to confirm each one — in a **single message** (not dripped):

For each candidate, ask a plain, answerable engineering question:
> "I found a potential hazard in [Area / file]: [one plain sentence describing the specific risk — e.g. 'balance reads and the subsequent debit write don't appear to be in the same transaction, which could allow double-spend under concurrent requests']. Is this (a) a confirmed risk to track, (b) not actually a risk in this codebase, or (c) you're not sure?"

Add a "skip all — mark as unverified" escape at the end of the message.

Map each answer to a row status:
- **(a) confirmed** → `Status = [VERIFIED]`
- **(b) not a risk** → `Status = [REVIEWED: not a hazard — <today's date>]` (write the row — kept for auditability, not dropped)
- **(c) unsure / skip all** → `Status = [UNVERIFIED]` (same as before this change — graceful degradation)

Then write the `## Known Hazard Areas` table to FRAMEWORK-CONTEXT.md with the answered statuses. One row per hazard: `Area / file(s)` · `Hazard` (the specific risk) · `Status` · `Reviewed` (today's date).

- **Delete the `KNOWN_HAZARD_AREAS_PENDING` marker** once written. If nothing notable surfaced, replace the table body with `_No notable hazards detected — confirm with the team._` and still delete the marker.
- Keep it tight (≤ ~12 rows); deeper items belong in TECH_DEBT.md.
- Do not upgrade `[UNVERIFIED]` rows yourself; only the developer can do that.

### 3e: Initialise SECURITY_FINDINGS.md

If `SECURITY_FINDINGS.md` does not exist at the repo root, create it using the template from `.claude/skills/` (or the framework template). Do not pre-populate findings — security findings come from `/security-review`, not from bootstrap analysis.

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
- **New project-specific skills discovered (A8) — review these in the PR diff**: for each skill written from the A8 discovery pass, list: skill name, one-line trigger phrase (what operation it scaffolds, in plain engineering language — e.g. "a recipe for adding a new tenant"), pinned exemplar file (or "(no exemplar — abstract only)"), and the why-tribal note. Omit this bullet entirely if A8 returned no candidates.

**Important**: the Conventions section was generated from code analysis and your Phase 2b answers. Verify it before relying on it — sections marked `<!-- INFERRED -->` flag specific areas where the code gave conflicting signals that couldn't be resolved automatically. All other sections reflect observed code patterns; review them for accuracy, not for AI-architecture decisions.
