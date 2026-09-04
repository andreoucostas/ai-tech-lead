---
description: "Regenerate the two derived rule files from CLAUDE.md: .github/copilot-instructions.md and the AGENTS.md full portable mirror."
---

Read `CLAUDE.md` and the framework-generated `.github/instructions/framework-rules.instructions.md` carrier. Regenerate the two **agent-facing derived files** from those sources:

1. `.github/copilot-instructions.md` — a terse rule digest for **inline editor completions**.
2. `AGENTS.md` — a **full mirror of CLAUDE.md's portable rules** for Codex and GitHub code review; Cursor also reads it.

## Input
$ARGUMENTS

## Why two files (read this first)

- **`copilot-instructions.md` is tiny** because it is loaded on every inline completion, where the model has a few hundred lines of context. Brevity beats completeness.
- **`AGENTS.md` is a full mirror** because Codex and GitHub code review have no documented automatic import of this repository's `CLAUDE.md`; a pointer is not injected rules. Cursor reads both files. Gemini defaults to `GEMINI.md`, and Aider needs explicit read configuration, so neither is claimed as an automatic consumer here.
- **The carrier is framework-generated; never hand-edit it.** It is canonical for Verification Rules, Leanness, SOLID, and Agentic Workflow. `CLAUDE.md` stays canonical for repo-specific content and imports that carrier. `/docs-sync` flags mirror drift.

---

## Part A — `.github/copilot-instructions.md` (slim, inline-completions only)

1. Read CLAUDE.md, focusing on: **Conventions** (all populated subsections), its `Verification Commands` inventory, and **Boy Scout Rule**. Derive applicable profiles and constructs from those populated sections and repository evidence; never infer an application profile from this framework distribution.

2. Convert each rule into one imperative line. Inline completions only see a few hundred lines of context; brevity matters more than completeness.

3. Start the file with:
   ```
   When generating code in this repo, follow these rules. The full conventions, architecture, and common tasks are in CLAUDE.md (read it for non-trivial work).
   ```

4. Structure the output. Select only headings whose source convention is populated in `CLAUDE.md` or whose profile/construct is established by repository evidence. Omit absent application-profile headings rather than emitting a template default. Include warehouse schema, migration/deploy, and data-validation rules when the warehouse profile is evidenced. For Testing, name the evidenced harness; if no harness or command is evidenced, state **not available** rather than inventing one:
   - **Angular Architecture / SOLID / Component Design / State Management / RxJS / API / HTTP / Typing / Styling** — only when the Angular profile and each source convention are evidenced/populated
   - **Testing** — name the framework evidenced in `CLAUDE.md > Conventions`; if absent, require mirroring the existing suite
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

Copy these sections **verbatim** from `.github/instructions/framework-rules.instructions.md` (they are framework-owned portable rules):

- **Verification Rules** — full
- **Leanness** — full (Defaults, Test leanness, When you must add structure)
- **SOLID** — full
- **Conventions** — copy `CLAUDE.md > Conventions` once bootstrapped. Until then, keep the placeholder that points to `docs/defaults.md` and marks CLAUDE.md authoritative.
- **Boy Scout Rule** — full (Always apply + the OnPush caveat + Apply-only-when-primary + When to skip)
- **Agentic Workflow** — copy **section 1 ("Classify the intent — and run that workflow without being asked") VERBATIM**: every workflow's inline non-negotiables, the canonical-definition note, the answer-only carve-out, and the security-pass paragraph. This is the canonical file-based routing definition, so it must never be condensed or paraphrased. A registered prompt hook is an independent, capability-specific salience path; its registration and output do not prove host firing or consumption. Sections 2–5 (plan-gate, verified subtasks, Boy Scout, self-review/flag-drift) may be condensed to one line each. `/docs-sync` asserts this mirror's section-1 block still matches `CLAUDE.md` §1.
- **Common Tasks** — the skills list, noting that `.claude/skills/` is the shared canonical location for Claude Code and supported GitHub Copilot skill surfaces

Then keep:
- **Quick reference** — links to CLAUDE.md, FRAMEWORK-CONTEXT.md, TECH_DEBT.md, skills, agents, prompts/commands
- **Precedence** — the framework-rules carrier wins for its four headings; CLAUDE.md wins for repo-specific content; this file is generated and may lag

Do **not** copy into AGENTS.md the project-narrative sections (Codebase Context, Repository Structure, Architecture Decisions) — those stay only in CLAUDE.md, and AGENTS.md points agents there. This keeps AGENTS.md bounded while still carrying every rule an agent must follow.

**Verify**: AGENTS.md begins with the `GENERATED FILE — do not edit by hand` banner and contains the `## Verification Rules`, `## Leanness`, `## Boy Scout Rule`, and `## Agentic Workflow` headers.

---

## Deterministic completion gate

After Parts A–B, run exactly one host-native framework check from the repository root:

PowerShell 7 (`pwsh`, primary):

```powershell
pwsh -NoProfile -File scripts/docs-sync-check.ps1
```

Windows PowerShell 5.1 fallback (Windows without `pwsh`):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/docs-sync-check.ps1
```

PASS requires exit code 0 and the final line `All AI Tech Lead framework checks passed.`. If it
fails, repair only `.github/copilot-instructions.md` or `AGENTS.md`, the files generated by this
workflow, then rerun. If a remaining failure is outside this workflow's scope,
report it with the failing check and **do not claim completion**. If neither checker can execute or
its result cannot be examined, report `CANT-VERIFY` with the reason and **do not claim completion**.
Report the command and PASS, failure, or CANT-VERIFY result.
