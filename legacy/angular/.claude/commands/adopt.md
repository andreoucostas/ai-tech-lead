Adopt this repository into the AI Tech Lead Framework, ingesting any existing AI-framework artifacts (Cursor, Copilot, Aider, Continue, Claude, Gemini, generic docs) without losing work.

Use this command when the repo already has *some* AI tooling or documentation (CLAUDE.md, .cursorrules, AGENTS.md, ARCHITECTURE.md, ADRs, etc.) and you want to consolidate it into our canonical structure. If the repo has nothing AI-related yet, run `/bootstrap` directly instead.

## Input
$ARGUMENTS

## CRITICAL: Do not delete or overwrite existing content. This command PRESERVES everything by archiving originals.

---

## Phase 0 — Pre-flight

1. **Check for uncommitted changes** — run `git status`. If there are uncommitted changes, STOP and tell the user to commit or stash. Adoption touches many files and must be reversible.
2. **Recommend a branch** — tell the user: "I recommend running this on a new branch: `git checkout -b adopt-ai-framework`. Review everything and merge when satisfied." Wait for confirmation.
3. **Locate the project root** — find `angular.json` (or `nx.json`/`project.json` for Nx). All paths are relative to this root.
4. **Capture the impact baseline (before any changes).** This freezes the "before" for the impact report — do it now or it's lost:
   - `git tag -f pre-adoption HEAD` and write the resolved SHA to `.claude/impact-baseline.ref`.
   - `mkdir -p docs/impact && bash scripts/metrics.sh > docs/impact/baseline.json` (the original codebase scorecard).
   The `pre-adoption` tag becomes the "old framework" arm of the behavioral A/B in Phase 9. (Requires the framework's `scripts/` — copied in before `/adopt`.)

---

## Phase 1 — Discovery

Scan the repo for AI-framework and AI-adjacent artifacts. Build an inventory. Do not modify anything in this phase.

### 1a. Other AI agent instruction files
Look for these at the repo root and in standard locations:
- `CLAUDE.md` (Claude Code) — likely main candidate to merge into
- `AGENTS.md` (generic agent pointer)
- `GEMINI.md` (Gemini)
- `.clinerules` (Cline)
- `.windsurfrules` or `.windsurf/rules/*` (Windsurf)
- `.roomodes` (Roo)

### 1b. Cursor
- `.cursorrules` (legacy single-file)
- `.cursor/rules/*.mdc` (current, with frontmatter)

### 1c. GitHub Copilot
- `.github/copilot-instructions.md`
- `.github/instructions/*.instructions.md` (path-scoped)
- `.github/prompts/*.prompt.md` (already-existing prompt files)
- `.github/chatmodes/*.chatmode.md`
- `.github/agents/*.agent.md`

### 1d. Aider / Continue
- `.aider.conf.yml`, plus any `CONVENTIONS.md` referenced by it
- `.continue/config.json`, `.continue/rules/*`

### 1e. Existing Claude Code config
- `.claude/commands/*.md` (custom commands not in our template set)
- `.claude/settings.json` (existing hooks — preserve unless they conflict)
- `.claude/skills/`, `.claude/agents/`

### 1f. Generic project documentation
- `CONTRIBUTING.md`, `ARCHITECTURE.md`, `CODEMAP.md`
- `docs/CONVENTIONS.md`, `docs/ARCHITECTURE.md`, `docs/CODEMAP.md`
- `docs/architecture/*`, `docs/adr/*`, `docs/decisions/*`
- `docs/TESTING.md`, `TESTING.md`

### 1g. Tech debt / backlog
- `TECH_DEBT.md`, `TODO.md`, `BACKLOG.md`, `ISSUES.md`
- `docs/tech-debt/*`

### 1h. Toolchain config (referenced, not merged)
- `angular.json`, `tsconfig.json`, `eslint.config.js` / `.eslintrc*`, `.prettierrc`, `stylelint.config.js`

Note their existence so the generated `CLAUDE.md` can reference them under the `Angular Version & Tooling` subsection. Do not merge their content.

### Discovery report
Present the inventory to the user as a table:

```
| Category | File | Size | Disposition (proposed) |
|----------|------|------|------------------------|
| Cursor   | .cursorrules | 2.4KB | Merge → CLAUDE.md > Conventions |
| ADR      | docs/adr/0001-state-mgmt.md | 1.8KB | Merge → CLAUDE.md > Architecture Decisions |
| Codemap  | CODEMAP.md | 5.1KB | Merge → CLAUDE.md > Repository Structure |
| Tech debt| TODO.md | 0.9KB | Merge → TECH_DEBT.md |
| Toolchain| eslint.config.js | — | Reference, don't merge |
| Unknown  | docs/notes.md | 12KB | Skip (ask user) |
```

For anything ambiguous (>200 lines, unclear category, custom commands), ask the user explicitly before proceeding.

---

## Phase 2 — Plan

Based on the inventory, propose a merge plan grouped by canonical target:

```
CLAUDE.md will receive:
  > Conventions ← .cursorrules (12 rules), docs/CONVENTIONS.md (8 rules), .windsurfrules (3 rules)
                  Estimated: 18 unique rules after dedup
  > Repository Structure ← CODEMAP.md (full content)
  > Architecture Decisions ← docs/adr/*.md (6 ADRs)
  > Conventions > Testing ← docs/TESTING.md (summary)

TECH_DEBT.md will receive:
  ← TODO.md (4 items), docs/tech-debt/*.md (12 items)

.claude/commands/ will receive:
  ← (any existing custom commands not in our template, listed for user review)

Originals will be archived to: docs/pre-adoption/
```

Wait for the user to confirm or amend the plan.

---

## Phase 3 — Archive originals

Move every file in the discovery inventory (except toolchain config) to `docs/pre-adoption/<original-relative-path>`. **Do not delete anything.** Use `git mv` where possible to preserve history.

Examples:
- `.cursorrules` → `docs/pre-adoption/cursorrules.md` (rename to .md so it renders)
- `.cursor/rules/api.mdc` → `docs/pre-adoption/cursor/rules/api.mdc`
- `CODEMAP.md` → `docs/pre-adoption/CODEMAP.md`
- `docs/adr/0001-...md` → `docs/pre-adoption/adr/0001-...md`
- `TODO.md` → `docs/pre-adoption/TODO.md`

After archive, run `git status` and present the moves to the user.

---

## Phase 4 — Merge content into CLAUDE.md (interactive)

For each archived source file, read it and merge into the appropriate CLAUDE.md section. **Show each merge to the user before applying.**

Merge principles:
- **Deduplicate** — if a rule already exists in CLAUDE.md, don't add it again
- **Normalise voice** — convert do/don't lists, bullet points, or arbitrary prose into our convention format: rule + 1-2 sentence rationale
- **Preserve attribution** — at the end of each merged section, add a comment: `<!-- Merged from: docs/pre-adoption/cursorrules.md, docs/pre-adoption/CONVENTIONS.md -->`
- **Summarise large content** — if a source file is over 200 lines, summarise key points and add a reference: `See \`docs/pre-adoption/[file]\` for full detail.`
- **Keep CLAUDE.md scannable** — target under 400 lines total

### 4a — Merge into Conventions
Read `.cursorrules`, `.cursor/rules/*.mdc`, `docs/CONVENTIONS.md`, `.windsurfrules`, `.clinerules`, Aider's `CONVENTIONS.md`, and any other instruction file. For each rule:
1. Categorise into a CLAUDE.md Conventions subsection (Architecture, Component Design, State Management, RxJS, API/HTTP, Typing, Styling, SSR/Hydration, Testing).
2. Skip rules that duplicate existing CLAUDE.md content.
3. For rules that contradict existing CLAUDE.md content, surface them to the user and ask: keep existing, replace with adopted, or merge.

Present to the user:
> "From your existing files I extracted [N] convention rules. [M] are duplicates of what's already in CLAUDE.md. [K] contradict existing rules — please resolve those. The remaining [N-M-K] can be added directly. Here's the proposed Conventions section:
>
> [show diff]
>
> Apply?"

### 4b — Merge into Repository Structure
If `CODEMAP.md`, `ARCHITECTURE.md`, or `docs/architecture/*` exist, extract:
- Folder layout / module dependency diagram (preserve mermaid)
- Feature module boundaries
- Where to put new code

Merge into CLAUDE.md > Repository Structure. Preserve diagrams.

### 4c — Merge into Architecture Decisions
For each ADR found in `docs/adr/*` or `docs/decisions/*`:
- Append the full ADR (title, decision, context, consequences) to `docs/architecture-decisions.md` (create it with an `# Architecture Decisions` heading if missing), then add a **one-line index entry** to `CLAUDE.md > Architecture Decisions` (`ADR-NNN — title — date — link`). Do not paste full ADRs into CLAUDE.md — it loads on nearly every turn (same split as the `create-adr` skill and `/bootstrap` Phase 3a).
- For lengthy ADRs: summarise to decision + one-line consequence in `docs/architecture-decisions.md` and reference the archived original under `docs/pre-adoption/`.

### 4d — Merge into Codebase Context
If `CONTRIBUTING.md` or top-of-`README.md` describes what the app does and who uses it, extract that into CLAUDE.md > Codebase Context. Don't duplicate the README — extract only the "what / who / domain" framing.

### 4e — Merge into Testing conventions
If `docs/TESTING.md` or `TESTING.md` exists, merge testing strategy and patterns into CLAUDE.md > Conventions > Testing.

---

## Phase 5 — Merge into TECH_DEBT.md

For each item in `TODO.md`, `BACKLOG.md`, `ISSUES.md`, `docs/tech-debt/*`:
- Categorise (Architecture, State Management, RxJS, Component Design, Testing, Types, Performance, Dependencies, Security)
- Estimate severity (Critical / High / Medium / Low) — ask user when unclear
- Estimate effort (S / M / L / XL) — ask user when unclear
- Add to TECH_DEBT.md

Skip items that are clearly product backlog (feature requests) rather than tech debt.

Present the proposed additions to the user before applying.

---

## Phase 6 — Handle Copilot/Cursor command-style assets

For any `.github/prompts/*.prompt.md`, `.github/chatmodes/*.chatmode.md`, `.cursor/rules/*.mdc` with prompt-like content, or custom `.claude/commands/*.md` that aren't in our template:

- If the workflow is genuinely useful and project-specific, copy it into `.claude/commands/<name>.md` (creating a new slash command) and generate a `.github/prompts/<name>.prompt.md` wrapper. **Ask the user first** — this expands the command surface area.
- Otherwise, leave them in `docs/pre-adoption/` as reference.

---

## Phase 7 — Fill gaps via /bootstrap

Now that adopted content has been merged, run the `/bootstrap` workflow against the codebase to:
- Fill any CLAUDE.md sections still empty (use the bootstrap analysis passes)
- Add any tech debt the bootstrap discovers that wasn't in the adopted backlog
- Generate AGENTS.md (if not already present)
- Generate the slim `.github/copilot-instructions.md`

`/bootstrap` will detect the existing populated content and merge with it rather than overwrite — that behaviour is built into bootstrap's pre-flight check.

---

## Phase 8 — Final report

Show the user:
- What was discovered (inventory)
- What was archived to `docs/pre-adoption/` (with paths)
- What was merged into CLAUDE.md (section by section, with rule counts)
- What was merged into TECH_DEBT.md (item count)
- What new commands (if any) were added to `.claude/commands/` and `.github/prompts/`
- What `/bootstrap` filled in
- Final CLAUDE.md line count
- `git diff --stat`

Remind the user to:
1. Review the updated CLAUDE.md — especially merged Conventions and Architecture Decisions
2. Review TECH_DEBT.md — verify severity and effort estimates
3. Try `/feature` or `/fix` on a small task to verify the workflow
4. Commit: `git add -A && git commit -m "Adopt AI Tech Lead Framework"`
5. Optionally delete `docs/pre-adoption/` once they're confident nothing was lost (keep it for at least one release cycle)

---

## Phase 9 — Impact report

After the adoption is committed (step 4 above — so `HEAD` reflects this framework), run `/impact`. It contrasts the old setup (archived in `docs/pre-adoption/`) with this framework and writes `docs/impact/IMPACT.md` (+ `docs/impact/impact.html`): the **capability diff**, the **deterministic scorecard** vs the Phase-0 baseline, and — if Copilot CLI is available — a **behavioral A/B** (the same tasks run against the `pre-adoption` tag vs `HEAD`, several trials each). No input needed. This report is what you show the tech leads.
