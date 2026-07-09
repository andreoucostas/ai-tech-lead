---
description: "Regenerate the derived files from CLAUDE.md: .github/copilot-instructions.md and the AGENTS.md full mirror, plus the .github/skills mirror via scripts/sync-agent-files. Invoke after any change to CLAUDE.md rules or the skill set."
---

Read the CLAUDE.md file in the project root. Regenerate the two **agent-facing derived files** from it:

1. `.github/copilot-instructions.md` — a terse rule digest for **inline editor completions**.
2. `AGENTS.md` — a **full mirror of CLAUDE.md's portable rules** for tools that read AGENTS.md natively (GitHub Copilot agent mode & CLI, Codex, Cursor, Gemini CLI, Aider).

## Input
$ARGUMENTS

## Why two files (read this first)

- **`copilot-instructions.md` is tiny** because it is loaded on every inline completion, where the model has a few hundred lines of context. Brevity beats completeness.
- **`AGENTS.md` is a full mirror** because AGENTS.md-native agents do **not** read `CLAUDE.md`; if AGENTS.md only pointed at CLAUDE.md, those agents would get a pointer instead of the rules. So AGENTS.md carries the actual Verification / Leanness / Boy Scout / Agentic Workflow / Conventions content.
- **`CLAUDE.md` stays canonical.** Both derived files are generated from it and may lag; `CLAUDE.md` wins on any conflict. `/docs-sync` flags drift.

---

## Part A — `.github/copilot-instructions.md` (slim, inline-completions only)

1. Read CLAUDE.md, focusing on: **Conventions** (all subsections) and **Boy Scout Rule**.

2. Convert each rule into one imperative line. Inline completions only see a few hundred lines of context; brevity matters more than completeness.

3. Start the file with:
   ```
   When generating code in this repo, follow these rules. The full conventions, architecture, and common tasks are in CLAUDE.md (read it for non-trivial work).
   ```

4. Structure the output:
   - **Architecture** — standalone components, inject(), lazy loading, barrel-file rules
   - **SOLID** — abstraction/token per injected service (DIP); one line each for SRP/OCP/LSP/ISP
   - **Component Design** — OnPush, smart/dumb split, control flow syntax, signals preference
   - **State Management** — local vs shared, no prop drilling, server state
   - **RxJS** — async pipe preference, takeUntilDestroyed, no nested subscribes, error handling
   - **API / HTTP** — typed services, interceptors, environment URLs
   - **Typing** — strict, no `any`, interfaces over classes
   - **Styling** — encapsulation, scoping, global rules
   - **Testing** — test name format, framework choice
   - **Boy Scout (always-apply items only)** — the numbered list from CLAUDE.md's "Always apply" subsection

5. Hard limits:
   - Each rule: one line, max 120 characters
   - Total file: under 80 lines
   - No code samples, no rationale, no prose paragraphs

6. Skip these (the agent reads them from CLAUDE.md / AGENTS.md):
   - Codebase Context, Repository Structure, Architecture Decisions, Common Tasks, Agentic Workflow
   - "Apply only when primary target" Boy Scout items
   - LEARNINGS.md (separate root file)

7. Write the file to `.github/copilot-instructions.md`. Create the `.github/` directory if it doesn't exist.

8. **Verify**: run `wc -l .github/copilot-instructions.md`. If over 80 lines, condense further.

---

## Part B — `AGENTS.md` (full mirror of portable rules)

Regenerate `AGENTS.md` at the repo root so AGENTS.md-native tools get the full ruleset. Keep the generation banner at the very top (it tells humans not to hand-edit, and tells agents that CLAUDE.md is canonical).

Copy these sections **verbatim** from CLAUDE.md (they are the portable rules):

- **Verification Rules** — full
- **Leanness** — full (Defaults, Test leanness, When you must add structure)
- **SOLID** — full
- **Conventions** — copy `CLAUDE.md > Conventions` once bootstrapped. Until then, keep the placeholder that points to `docs/defaults.md` and marks CLAUDE.md authoritative.
- **Boy Scout Rule** — full (Always apply + the OnPush caveat + Apply-only-when-primary + When to skip)
- **Agentic Workflow** — copy **section 1 ("Classify the intent — and run that workflow without being asked") VERBATIM**: every workflow's inline non-negotiables, the canonical-definition note, the answer-only carve-out, and the security-pass paragraph. This is the canonical routing definition and the *only* routing surface Copilot has (no hook injects routing context there), so it must never be condensed or paraphrased. Sections 2–5 (plan-gate, verified subtasks, Boy Scout, self-review/flag-drift) may be condensed to one line each. `/docs-sync` asserts this mirror's section-1 block still matches `CLAUDE.md` §1.
- **Common Tasks** — the skills list, noting they live in both `.github/skills/` and `.claude/skills/`

Then keep:
- **Quick reference** — links to CLAUDE.md, FRAMEWORK-CONTEXT.md, TECH_DEBT.md, skills, agents, prompts/commands
- **Precedence** — CLAUDE.md wins; this file is generated and may lag

Do **not** copy into AGENTS.md the project-narrative sections (Codebase Context, Repository Structure, Architecture Decisions) — those stay only in CLAUDE.md, and AGENTS.md points agents there. This keeps AGENTS.md bounded while still carrying every rule an agent must follow.

**Verify**: AGENTS.md begins with the `GENERATED FILE — do not edit by hand` banner and contains the `## Verification Rules`, `## Leanness`, `## Boy Scout Rule`, and `## Agentic Workflow` headers.

---

## Part C — sync the skills mirror

Skills are authored in `.claude/skills/` and mirrored to `.github/skills/` so GitHub Copilot CLI and the cloud agent discover them (VS Code Copilot already reads `.claude/skills/`). After any skill change, regenerate the mirror:

```bash
bash scripts/sync-agent-files.sh        # macOS / Linux / Windows git-bash
```
```powershell
pwsh scripts/sync-agent-files.ps1       # Windows PowerShell
```

This makes `.github/skills/` a byte-identical copy of `.claude/skills/`. The docs-sync CI check fails if they diverge. Do not hand-edit `.github/skills/` — edit the skill under `.claude/skills/` and re-run the sync.
