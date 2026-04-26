# AI Tech Lead Framework — Angular

A working template that turns Claude Code and GitHub Copilot into a tech lead for your Angular codebase. Clone it, run one command, and get AI-driven development with built-in conventions, verification, and continuous improvement.

Targets **Angular 17+** (standalone components, signals, new control flow, `inject()`, `takeUntilDestroyed`). Bootstrap auto-detects your Angular version and adjusts conventions accordingly.

## Quick Start

### 1. Copy into your project
Copy the following into your existing Angular **project root** (where `angular.json` lives):
```
.claude/                            → Claude Code commands and hooks
.github/prompts/                    → GitHub Copilot Chat workflows (mirror of .claude/commands/)
.github/workflows/docs-sync-check.yml → CI guardrail for framework state
.github/PULL_REQUEST_TEMPLATE.md    → PR template with design rationale + Boy Scout checklist
AGENTS.md                           → pointer for any agent-style tool
CLAUDE.md                           → template, populated by /bootstrap
TECH_DEBT.md                        → template, populated by /bootstrap
```

**Do not copy** `.template-repo` — it's a marker that exists only in this template repository to disable the CI guardrail here.

All of these files should be committed to version control — they're shared team configuration, not local settings.

### 2. Bootstrap (greenfield) **or** Adopt (existing setup)

If the repo has **no AI tooling yet**, run:
```
/bootstrap
```

If the repo **already has AI artifacts** (CLAUDE.md from another template, `.cursorrules`, Cursor rules, Copilot instructions, Aider/Continue config, generic ARCHITECTURE/CONVENTIONS/ADR docs, an existing TECH_DEBT register, etc.), run:
```
/adopt
```
`/adopt` discovers everything, archives originals to `docs/pre-adoption/`, merges useful content into our canonical structure (CLAUDE.md + TECH_DEBT.md), then runs `/bootstrap` to fill gaps. Nothing is deleted.

Either command:

This single command:
- Analyses your codebase (modules, state management, components, RxJS, API layer, testing)
- Synthesises findings into priorities
- Populates `CLAUDE.md` with your actual conventions and patterns
- Generates `TECH_DEBT.md` with prioritised debt
- Writes `AGENTS.md` (a pointer at `CLAUDE.md` for Copilot agent / Codex / Cursor / Aider)
- Generates a slim `.github/copilot-instructions.md` for Copilot inline completions

### 3. Review
Read the generated `CLAUDE.md`. It should accurately describe your codebase. Fix anything that's wrong — this is the source of truth that all AI tools will follow.

### 4. Start working

Both Claude Code and Copilot Chat use the same slash-command names:

```
/feature [description]     — implement a feature across all layers
/fix [description]         — diagnose and fix a bug (regression test first)
/design [description]      — think through design before coding
/review                    — review changes as a tech lead
/refactor [target]         — refactor with safety net
/test [target]             — generate tests following project patterns
/debt [area]               — find and fix tech debt
/docs-sync                 — check documentation for drift
/adopt                     — ingest existing AI-framework artifacts into this layout
/generate-copilot          — regenerate the slim copilot-instructions.md (for inline completions)
```

In **Claude Code**, these are loaded from `.claude/commands/`. In **Copilot Chat**, the same names are loaded from `.github/prompts/` — those files are thin wrappers that delegate to the canonical `.claude/commands/*.md` files, so there's a single source of truth per workflow.

Or just describe what you want in natural language — `CLAUDE.md` teaches the agent to route to the right workflow automatically.

## What's in the box

| File | Purpose |
|------|---------|
| `CLAUDE.md` | **Single source of truth** — conventions, architecture, common tasks, agentic workflow. Read directly by Claude Code and by Copilot's coding agent / CLI. |
| `AGENTS.md` | Pointer to `CLAUDE.md` for any agent-style tool (Copilot agent, Codex, Cursor, Aider). |
| `.github/copilot-instructions.md` | **Generated** — slim imperative ruleset (≤80 lines) for Copilot **inline completions** only. The agent reads `CLAUDE.md` directly. |
| `.github/prompts/*.prompt.md` | Copilot Chat workflows. Thin wrappers that delegate to `.claude/commands/`. |
| `.claude/commands/*.md` | Canonical workflow definitions (used by Claude Code natively, and by the Copilot prompt files). |
| `.claude/settings.json` | Hooks — type-check (`tsc --noEmit`) after `.ts` file writes. Claude Code only — Copilot has no hook system. |
| `TECH_DEBT.md` | **Generated** by `/bootstrap` — prioritised debt register with Trojan Horse opportunities. |
| `docs/playbook.md` | Methodology guide (the "why" behind the framework). |

## How it works

Every command follows the same execution model:
1. **Read CLAUDE.md** for conventions
2. **Plan** before coding
3. **Execute in verified subtasks** (build + test after each)
4. **Boy Scout** every touched file
5. **Self-review** against conventions
6. **Flag drift** in documentation

Hooks in `.claude/settings.json` automatically run `tsc --noEmit` after every `.ts` file write — fast type-checking (1-2 seconds) that catches errors before they compound. Full `ng build` and `ng test` run inside command workflows.

## Mixed-stack repos (Angular + backend in one repository)

If your repo has significant code in another stack alongside Angular — e.g. a colocated .NET API, a Node/Express backend, or a Python service — use **path-scoped Copilot instructions** so each stack gets the right rules.

Create files under `.github/instructions/` with `applyTo:` frontmatter:

```markdown
---
applyTo: "**/*.cs"
---
# C# / .NET rules
- Propagate CancellationToken through every async call chain.
- Use `.AsNoTracking()` for read-only EF Core queries.
- ...
```

Copilot's coding agent and inline completions both honour `applyTo` — `.ts` files see the Angular rules from `copilot-instructions.md`, `.cs` files see the .NET rules from `.github/instructions/csharp.instructions.md`. The repo-wide rules apply on top of either.

If the secondary stack is .NET, the `ai-tech-lead-dotnet` template's `copilot-instructions.md` content is a sensible starting point — copy it into a `.github/instructions/csharp.instructions.md` file and add `applyTo: "**/*.cs"` at the top.

## Keeping it alive

- When conventions change: update `CLAUDE.md` and ask your agent (or `/generate-copilot`) to refresh `.github/copilot-instructions.md`
- Quarterly: run `/docs-sync` to find drift, or `/rebootstrap` for a deeper refresh
- Always: the Boy Scout Rule and Trojan Horse principle mean every change improves the codebase incrementally
