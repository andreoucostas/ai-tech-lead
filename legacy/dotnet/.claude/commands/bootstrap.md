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

Perform six analysis passes. For each, observe and record findings internally. Do not output analysis results to the user — they feed Phase 2.

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

---

## Phase 2 — Synthesis

From the six analysis passes, synthesise findings into three priority tiers:

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
- **Architecture Decisions**: every significant decision found — intentional or accidental. Include context, consequences, and honest review notes.
- **Common Tasks**: do NOT write recipes inline in CLAUDE.md. Instead, audit `.claude/skills/` against this codebase: keep a default skill if its recipe matches reality (adjust steps where they don't); add new skills under `.claude/skills/<name>/SKILL.md` for project-specific recipes (each with `name` + `description` frontmatter); delete defaults that don't apply. Update the Common Tasks bullet list in CLAUDE.md to match the final skill set.
- **Boy Scout Rule**: priority improvements based on the actual debt found in Phase 2

Preserve the Agentic Workflow section as-is. Never touch `LEARNINGS.md` — it is append-only.

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

### 3c: Ensure AGENTS.md exists

If `AGENTS.md` is missing from the repo root, write it. Use this exact content (it points all agent-style tools — Copilot coding agent, Codex, Cursor, Aider — at CLAUDE.md):

```markdown
# Agent Instructions

This repository follows the AI Tech Lead Framework. The single source of truth for conventions, architecture, common tasks, and the agentic workflow lives in **[CLAUDE.md](./CLAUDE.md)** at the repository root.

All AI coding agents (Claude Code, GitHub Copilot coding agent, Codex, Cursor, Aider, etc.) should read `CLAUDE.md` before making changes and treat it as authoritative.

## Quick reference

- **Conventions, architecture, common tasks, boy-scout rules**: see [CLAUDE.md](./CLAUDE.md)
- **Tech debt register**: see [TECH_DEBT.md](./TECH_DEBT.md)
- **Inline-completion ruleset**: see [.github/copilot-instructions.md](./.github/copilot-instructions.md)
- **Reusable workflows for Copilot Chat**: see [.github/prompts/](./.github/prompts/)
- **Reusable workflows for Claude Code**: see [.claude/commands/](./.claude/commands/)

## Precedence

If anything in this file or in derived files conflicts with `CLAUDE.md`, `CLAUDE.md` wins. Slash commands (`/feature`, `/fix`, etc.) have Copilot equivalents in `.github/prompts/` with the same names.
```

If `AGENTS.md` already exists, leave it alone.

### 3d: Generate copilot-instructions.md (slim, inline-completions only)

Run the `/generate-copilot` workflow. **Do not** produce a full derivative of CLAUDE.md — Copilot's coding agent reads CLAUDE.md and AGENTS.md directly. The copilot-instructions.md file is now scoped to inline editor completions only:

- Terse imperative one-liners
- Conventions and Boy Scout (always-apply only)
- Total under 80 lines
- No Common Tasks, no Architecture Decisions, no Codebase Context

See `.claude/commands/generate-copilot.md` for the exact rules.

---

## Phase 4 — Report

Run `git diff CLAUDE.md` and `git diff TECH_DEBT.md` to show the user exactly what changed. Present the diff summary before the rest of the report.

Then output:
- Number of findings per severity
- Top 3 architectural risks
- Top 3 quick wins
- Files generated/modified

**Important**: remind the user to review the generated `CLAUDE.md` before using any other commands. The conventions in that file drive everything else — if they're wrong, every command will follow wrong rules.
