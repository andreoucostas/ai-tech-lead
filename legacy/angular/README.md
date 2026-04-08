# AI Tech Lead Framework — Angular

A working template that turns Claude Code and GitHub Copilot into a tech lead for your Angular codebase. Clone it, run one command, and get AI-driven development with built-in conventions, verification, and continuous improvement.

Targets **Angular 17+** (standalone components, signals, new control flow, `inject()`, `takeUntilDestroyed`). Bootstrap auto-detects your Angular version and adjusts conventions accordingly.

## Quick Start

### 1. Copy into your project
Copy the following into your existing Angular **project root** (where `angular.json` lives):
```
.claude/          → commands and hooks configuration
CLAUDE.md         → template, populated by /bootstrap
TECH_DEBT.md      → template, populated by /bootstrap
```

All of these files should be committed to version control — they're shared team configuration, not local settings.

### 2. Bootstrap
Open Claude Code in your project and run:
```
/bootstrap
```

This single command:
- Analyses your codebase (modules, state management, components, RxJS, API layer, testing)
- Synthesises findings into priorities
- Populates `CLAUDE.md` with your actual conventions and patterns
- Generates `TECH_DEBT.md` with prioritised debt
- Generates `.github/copilot-instructions.md` from `CLAUDE.md`

### 3. Review
Read the generated `CLAUDE.md`. It should accurately describe your codebase. Fix anything that's wrong — this is the source of truth that all AI tools will follow.

### 4. Start working
```
/feature [description]     — implement a feature across all layers
/fix [description]         — diagnose and fix a bug (regression test first)
/design [description]      — think through design before coding
/review                    — review changes as a tech lead
/refactor [target]         — refactor with safety net
/test [target]             — generate tests following project patterns
/debt [area]               — find and fix tech debt
/docs-sync                 — check documentation for drift
/generate-copilot          — regenerate copilot-instructions.md from CLAUDE.md
```

Or just describe what you want in natural language — `CLAUDE.md` teaches Claude Code to route to the right workflow automatically.

## What's in the box

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Single source of truth — conventions, architecture, agentic workflow |
| `.github/copilot-instructions.md` | **Generated** by `/bootstrap` or `/generate-copilot` — full derivative of CLAUDE.md for GitHub Copilot |
| `TECH_DEBT.md` | **Generated** by `/bootstrap` — prioritised debt register with Trojan Horse opportunities |
| `.claude/commands/*.md` | 10 workflow commands |
| `.claude/settings.json` | Hooks — type-check (`tsc --noEmit`) after `.ts` file writes |
| `docs/playbook.md` | Methodology guide (the "why" behind the framework) |

## How it works

Every command follows the same execution model:
1. **Read CLAUDE.md** for conventions
2. **Plan** before coding
3. **Execute in verified subtasks** (build + test after each)
4. **Boy Scout** every touched file
5. **Self-review** against conventions
6. **Flag drift** in documentation

Hooks in `.claude/settings.json` automatically run `tsc --noEmit` after every `.ts` file write — fast type-checking (1-2 seconds) that catches errors before they compound. Full `ng build` and `ng test` run inside command workflows.

## Migrating from v3

If your team already set up the v3 framework (the HTML playbook), you have populated documents (CLAUDE.md, CODEMAP.md, CONVENTIONS.md, ADRs, TESTING.md, TECH_DEBT.md, etc.) that contain real work. **Don't lose it.**

### Steps

1. **Copy the v4 `.claude/` directory** into your project (overwriting any v3 skills/commands)
2. **Copy `docs/playbook.md`** into your project
3. Open Claude Code and run:
   ```
   /migrate
   ```

The migrate command will:
- Archive your v3 documents to `docs/v3-archive/` (nothing deleted)
- Fold CODEMAP, CONVENTIONS, ADRs, and TESTING into your existing CLAUDE.md
- Add the v4 Agentic Workflow section to CLAUDE.md
- Install correct hooks in `.claude/settings.json`
- Regenerate copilot-instructions.md from the enriched CLAUDE.md

Your TECH_DEBT.md, pre-commit hooks, and any project-specific customisations are preserved.

---

## Keeping it alive

- When conventions change: update `CLAUDE.md`, then run `/generate-copilot`
- Quarterly: run `/docs-sync` to find drift
- Always: the Boy Scout Rule and Trojan Horse principle mean every change improves the codebase incrementally
