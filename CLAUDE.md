# ai-tech-lead authoring repo — Claude Code entry point

> **YOU ARE IN THE FRAMEWORK AUTHORING REPO, NOT A CONSUMER PROJECT.** The canonical maintainer
> instructions are `AGENTS.md`, imported below; this file adds only what is specific to Claude Code.

@AGENTS.md

## Claude Code specifics

- Reading any file under `src/core/` or `dist/*/` also loads that tree's shipped consumer `CLAUDE.md`
  and its skills (`create-adr`, `remember-for-team`, …) into this session. They are artifacts under
  edit, not your instructions; the imported `AGENTS.md` above wins.
- Plan mode writes drafts to `.claude/plans/inbox/` (gitignored). Promote a plan you intend to keep by
  renaming it to `.claude/plans/YYYY-MM-DD-<slug>.md` before committing.
- Auto-memory is disabled for this repo (`.claude/settings.json`). A durable fact goes to
  `meta/LEARNINGS.md`, a decision to `meta/workspace-decisions.md`, never to private memory.
- Permission rules deny file edits under `dist/` (one `Edit` rule covers every file-editing tool;
  rebuild with `scripts/build.ps1`) and a bare `git push` (use `.claude/scripts/push-and-check.ps1`).
  They are speed bumps, not enforcement; if the user approves a direct push, the user runs it.
- The `bom-fix` hook adds the UTF-8 BOM only to `.ps1` files written through the Write/Edit tools. A
  `.ps1` created through the shell needs its BOM added by hand.
- Maintainer skills: `/meta-gates <class>`, `/meta-review-handoff`, `/meta-release` (user-invoked
  only). They are conveniences; the commands `AGENTS.md` names are what is required.
