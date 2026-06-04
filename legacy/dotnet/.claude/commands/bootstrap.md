Analyse this .NET codebase and set up the AI Tech Lead framework. This is the one-time bootstrap that makes the repo AI-ready.

## Input
$ARGUMENTS

Execute all phases below in sequence. Do not skip any phase. Do not ask for confirmation between phases — run the full pipeline.

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

Dispatch the seven analysis passes (A1–A7) **in parallel** via the `Task` tool, each invoking the `bootstrap-pass` subagent with the pass id as input. Example call shape:

```
Task(subagent_type="bootstrap-pass", description="Bootstrap pass A1", prompt="Run pass A1.")
```

Send all seven Task calls in a single message so they execute concurrently. Wait for all seven to return.

Each subagent returns structured findings; you do **not** redo the analysis. Just collect the seven results — they feed Phase 2.

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

---

## Phase 2 — Synthesis

From the seven analysis passes (A7 may report no financial signals and self-skip), synthesise findings into three priority tiers:

1. **Architectural risks** — affect scalability or correctness
2. **Technical debt** — slows delivery or causes bugs
3. **Quick wins** — improve quality with minimal effort

For each item: current pattern → target pattern → brief rationale.

---

## Phase 3 — Generate artifacts

### 3a: Populate CLAUDE.md

Read the existing CLAUDE.md template in the project root. Replace every placeholder section with real findings from this codebase:

- **Codebase Context**: what this app does, users, domain concepts, critical journeys
- **Repository Structure**: actual project layout with dependency diagram
- **Conventions**: the rules this codebase actually follows (or should follow), with rationale. Use the subsection structure from `docs/defaults.md` (Architecture, Naming, DI, Data Access, API, Async, Null Handling, Logging, Testing) as a starting checklist; record observed reality, deviating from defaults where the codebase does. **Delete the `BOOTSTRAP_PENDING` HTML comment and the "_Not yet populated_" placeholder line** when this section is filled in.
- **Architecture Decisions**: index every significant decision found (intentional or accidental) as a one-line entry here; write the full Decision → Context → Consequences → Review notes to `docs/architecture-decisions.md` (create it if missing). Keeping detail out of CLAUDE.md holds it within the token budget — it loads on nearly every turn.
- **Common Tasks**: do NOT write recipes inline in CLAUDE.md. Instead, audit `.claude/skills/` against this codebase: keep a default skill if its recipe matches reality (adjust steps where they don't); add new skills under `.claude/skills/<name>/SKILL.md` for project-specific recipes (each with `name` + `description` frontmatter); delete defaults that don't apply. Update the Common Tasks bullet list in CLAUDE.md to match the final skill set.
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

Do **not** edit any other section of FRAMEWORK-CONTEXT.md — those are maintainer-curated.

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

**Important**: remind the user to review the generated `CLAUDE.md` before using any other commands. The conventions in that file drive everything else — if they're wrong, every command will follow wrong rules.
