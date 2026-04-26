# Agent Instructions

This repository follows the [AI Tech Lead Framework](./README.md). The single source of truth for conventions, architecture, common tasks, and the agentic workflow lives in **[CLAUDE.md](./CLAUDE.md)** at the repository root.

All AI coding agents (Claude Code, GitHub Copilot coding agent, Codex, Cursor, Aider, etc.) should read `CLAUDE.md` before making changes and treat it as authoritative.

## Quick reference

- **Conventions, architecture, common tasks, boy-scout rules**: see [CLAUDE.md](./CLAUDE.md)
- **Tech debt register**: see [TECH_DEBT.md](./TECH_DEBT.md)
- **Inline-completion ruleset (terse, for editor autocomplete)**: see [.github/copilot-instructions.md](./.github/copilot-instructions.md)
- **Reusable workflows for Copilot Chat**: see [.github/prompts/](./.github/prompts/)
- **Reusable workflows for Claude Code**: see [.claude/commands/](./.claude/commands/)

## Precedence

If anything in this file or in derived files (`copilot-instructions.md`, prompt files) conflicts with `CLAUDE.md`, `CLAUDE.md` wins. The derived files are generated and may lag.

When the agentic workflow in `CLAUDE.md` references slash commands (e.g. `/feature`, `/fix`), the Copilot equivalents are in `.github/prompts/` with the same names.
