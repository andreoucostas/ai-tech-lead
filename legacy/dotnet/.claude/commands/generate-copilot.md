Read the CLAUDE.md file in the project root. Generate (or regenerate) `.github/copilot-instructions.md` as a **terse rule digest for inline editor completions**.

## Input
$ARGUMENTS

## Why this is small (read this first)

GitHub Copilot's coding agent and CLI now read `CLAUDE.md` and `AGENTS.md` directly — they don't need a duplicate. This file is **only** for inline completions in the editor (Copilot suggestions as you type), where the model has limited context and needs short, scannable rules.

Do **not** copy Common Tasks, Architecture Decisions, or Codebase Context here. Those are full-context concerns that the agent reads from `CLAUDE.md` and `AGENTS.md` directly.

## Rules

1. Read CLAUDE.md, focusing on: **Conventions** (all subsections) and **Boy Scout Rule**.

2. Convert each rule into one imperative line. Inline completions only see a few hundred lines of context; brevity matters more than completeness.

3. Start the file with:
   ```
   When generating code in this repo, follow these rules. The full conventions, architecture, and common tasks are in CLAUDE.md (read it for non-trivial work).
   ```

4. Structure the output:
   - **Naming** — one line per rule
   - **Architecture** — dependency direction + layering rules only
   - **Dependency Injection** — lifetimes + registration pattern
   - **Data Access** — query placement, AsNoTracking, repository usage
   - **API Design** — controller thinness, DTO separation, validation
   - **Async** — CancellationToken, no async void / sync-over-async
   - **Null Handling** — nullable enabled, no unjustified `!`
   - **Logging** — structured only, no string interpolation
   - **Testing** — test name format, framework choice
   - **Boy Scout (always-apply items only)** — the numbered list from CLAUDE.md's "Always apply" subsection

5. Hard limits:
   - Each rule: one line, max 120 characters
   - Total file: under 80 lines
   - No code samples, no rationale, no prose paragraphs

6. Skip these (the agent reads them from CLAUDE.md):
   - Codebase Context
   - Solution Structure
   - Architecture Decisions
   - Common Tasks
   - Agentic Workflow
   - "Apply only when primary target" Boy Scout items
   - What We've Learned

7. Write the file to `.github/copilot-instructions.md`. Create the `.github/` directory if it doesn't exist.

## Verify after writing

Run `wc -l .github/copilot-instructions.md`. If the result is over 80 lines, condense further — every line costs context budget on every completion.
