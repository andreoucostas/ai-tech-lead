<!--
ai-tech-lead-framework
<!-- @stack:stamp -->
  version: 0.65.0
  applied: 2026-08-21
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
- `remember-for-team` — draft a team wiki entry (gotcha/context/recipe/failed-approach) for PR review
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

## What We've Learned

Long-form learnings live in [LEARNINGS.md](./LEARNINGS.md). Read it when starting non-trivial work; append to it (don't overwrite) when you discover what works, what causes friction, or what rule needs adjusting.

LEARNINGS.md is an append-only chronological history (plus the declined-recipe registry); the team wiki ([docs/wiki/](./docs/wiki/INDEX.md)) holds current, scoped, individually-verifiable claims with an index — promote a durable LEARNINGS entry to a wiki entry via `remember-for-team`.
