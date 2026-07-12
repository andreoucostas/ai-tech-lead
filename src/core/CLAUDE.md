<!--
ai-tech-lead-framework
<!-- @stack:stamp -->
  version: 0.26.0
  applied: 2026-07-12
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

<!-- @stack:verif-rules -->
8. **No future-proofing.** Do not add code for hypothetical requirements. Three similar lines is better than a premature abstraction.
<!-- @stack:verif-rule9 -->

---

## Leanness

The Boy Scout Rule biases toward adding improvements. This section is the counterweight: every change should also consider what to remove or what not to introduce. Bloat is not a stylistic preference — it is the highest-cost long-term failure mode of AI-assisted development.

### Defaults

<!-- @stack:lean-1-2 -->
3. **No abstract base class with one subclass.** Inline it.
<!-- @stack:lean-4-8 -->
9. **Deletion is a contribution.** If a change makes existing code obsolete, delete it in the same PR. Comment-out is never the answer; that is what version control is for.
<!-- @stack:lean-10 -->

### Test leanness

<!-- @stack:lean-test -->

### When you must add structure

<!-- @stack:lean-structure -->

---

## SOLID

<!-- @stack:solid-intro -->

<!-- @stack:solid-1-5 -->

<!-- @stack:solid-mechanism -->

<!-- @stack:solid-backstop -->

---

## Codebase Context

<!-- Populated by /bootstrap — do not fill manually -->

What this application does, who uses it, key domain concepts, and critical user journeys.

---

## Repository Structure

<!-- Populated by /bootstrap — replaces separate CODEMAP.md -->

<!-- @stack:repo-structure -->

<!-- @stack:repo-diagram -->

---

## Conventions

<!-- BOOTSTRAP_PENDING: run /bootstrap to replace this entire section with conventions observed in the actual codebase. -->
<!-- @stack:defaults-comment -->
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

<!-- @stack:skills-list -->
- `create-adr` — record a significant architecture decision in Architecture Decisions
<!-- @stack:enforce-skills -->

`/bootstrap` adds project-specific skills under `.claude/skills/`, grounding instance-shaped recipes in a real repo exemplar. Skills are mirrored to `.github/skills/` by `/generate-copilot` (and `scripts/sync-agent-files`) so Copilot CLI/agent see them too.

<!-- @stack:registers -->

---

## Boy Scout Rule

When touching any file, leave it cleaner than you found it. The rule is symmetric: improvements *add* missing pieces and *remove* dead weight. Deletion is a contribution.

### Always apply (low-effort, low-risk — do these on every touched file):

**Add:**
<!-- @stack:bs-add -->

**Subtract:**
<!-- @stack:bs-subtract -->

### Apply only when the file is the primary target of the change:

**Add:**
<!-- @stack:bs-primary-add -->

**Subtract:**
<!-- @stack:bs-primary-subtract -->

<!-- @stack:bs-items-note -->

**When to skip**: hotfixes, time-sensitive production incidents, and proof-of-concept branches. If skipping, add a comment `// TODO: Boy Scout skipped — [reason]` so it's picked up on the next pass. Use `/debt` to clean up later.

---

## Agentic Workflow

When given any task, follow this execution model:

### 1. Classify the intent — and run that workflow without being asked
Developers will rarely type a slash command. Treat any natural-language request as the trigger: silently classify it, **announce in one line which workflow you concluded** ("Reading this as a *fix*…"), and apply that workflow's rails below. If two workflows genuinely fit, ask one clarifying question first. If it's a pure question ("why does this throw?", "what does `X` do?"), just answer it — no workflow ceremony. You may combine workflows for a compound request ("fix this and add a test"), but **never silently drop a workflow's non-negotiables** to do so.

> These rails are the **canonical definition** of each workflow. `commands/*.md` and the `route-prompt` hook elaborate them but must not contradict them; `/docs-sync` checks they stay aligned. Where hooks are off (Copilot VS Code without Preview agent-hooks, Copilot CLI < v1.0.65) this text is the *only* thing that reaches the model — treat it as binding, not advisory.

<!-- @stack:workflow-bullets -->
- **Debt cleanup** — *tech debt / cleanup debt*: read `TECH_DEBT.md` and find items in the area → confirm each still exists in the code (may already be fixed) → recommend fix-now vs defer with reasons → after fixes, update `TECH_DEBT.md` → Boy Scout touched files → report fixed/deferred plus the `TECH_DEBT.md` diff.

What is *guaranteed* vs merely *instructed* here depends on the surface — see `docs/enforcement-surfaces.md`. On Claude Code — and on Copilot where hooks are enabled (CLI ≥ v1.0.65, VS Code Preview agent-hooks) — these rails are reinforced by a per-prompt hook and a write-time guard; where hooks are off, only this text reaches the model.

<!-- @stack:security-pass -->

### 2. Plan before coding — present, clarify, then get the go-ahead
For any non-trivial task, STOP before writing code and post a short plan:
- The files you'll create or modify, and the order of operations
- What tests will verify success
- Your assumptions, plus **clarifying questions** for anything underspecified (ambiguous scope, unclear acceptance criteria, competing approaches). Do not guess past a material ambiguity to seem helpful — ask.
- For larger features, persist the plan as a spec to `specs/<slug>.md` (see `/design`) and implement against it

Then **wait for the developer's explicit go-ahead before editing code.** This checkpoint is where a wrong assumption gets caught before it becomes a wrong diff — and where the developer stays engaged with the change instead of rubber-stamping output. Skip the wait only for a trivial, unambiguous change (typo, one-liner), and say that you're skipping it and why.

### 3. Execute in verified subtasks
For features and complex changes, decompose into ordered subtasks:
<!-- @stack:exec-subtasks -->

Each subtask must leave the codebase compilable and test-passing.
<!-- @stack:exec-buildtest -->

### 4. Boy Scout every touched file
Check the Boy Scout Rule list above. Apply relevant improvements to every file you modify.

### 5. Self-review before presenting
Before presenting work as complete:
- Review your changes against the Conventions section above
- Verify all tests pass
- Check if the change introduces a new pattern → flag that this file needs updating
- Check if the change resolves a TECH_DEBT.md item → flag for removal
- Check if the change contradicts any convention → ask whether to update the convention or change the implementation
<!-- @stack:verif-conf-line -->

### 6. Flag documentation drift
At the end of your response, note if:
- A new pattern was introduced that should be documented here
- A TECH_DEBT.md entry was resolved or a new one discovered
- A SECURITY_FINDINGS.md entry was resolved or a new finding discovered
- `copilot-instructions.md` / `AGENTS.md` need regeneration (run `/generate-copilot` in Claude Code, or ask your agent to rewrite them from this file following the rules in `.claude/commands/generate-copilot.md`)

---

## What We've Learned

Long-form learnings live in [LEARNINGS.md](./LEARNINGS.md). Read it when starting non-trivial work; append to it (don't overwrite) when you discover what works, what causes friction, or what rule needs adjusting.
