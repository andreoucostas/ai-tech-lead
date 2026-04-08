Read the CLAUDE.md file in the project root. Generate (or regenerate) `.github/copilot-instructions.md` as a full derivative.

## Input
$ARGUMENTS

## Rules

1. Read every section of CLAUDE.md — Codebase Context, File Structure, Conventions, Architecture Decisions, Common Tasks, Boy Scout Rule.

2. Convert each into imperative instructions that GitHub Copilot must follow on every interaction.

3. Start the file with:
   ```
   When generating code in this repo, always follow these rules:
   ```

4. Structure the output with these sections:
   - **Project Overview** — one paragraph from Codebase Context
   - **Architecture Rules** — from File Structure + Architecture Decisions
   - **Component Rules** — from Conventions > Component Design
   - **State Management Rules** — from Conventions > State Management
   - **RxJS Rules** — from Conventions > RxJS
   - **API / HTTP Rules** — from Conventions > API/HTTP
   - **Typing Rules** — from Conventions > Typing
   - **Testing Rules** — from Conventions > Testing
   - **Common Patterns** — from Common Tasks (abbreviated)
   - **Boy Scout Rule** — from Boy Scout Rule (exact priority list)
   - **Gotchas** — any non-obvious traps from Architecture Decisions
   - **Documentation Maintenance** — these exact rules:
     - New pattern introduced → flag that CLAUDE.md needs updating
     - Convention changed → flag that CLAUDE.md needs updating
     - Tech debt resolved → flag that TECH_DEBT.md entry should be removed
     - New tech debt found → flag that TECH_DEBT.md needs a new entry
     - If an implementation contradicts these instructions → ask whether to update the convention or change the implementation, never silently deviate

5. Every point must be scannable — one to two lines max. Imperative voice throughout.

6. Do NOT compress or summarise — this is a full derivative, not an abbreviation. Every rule in CLAUDE.md must appear in copilot-instructions.md.

7. Write the file to `.github/copilot-instructions.md`. Create the `.github/` directory if it doesn't exist.
