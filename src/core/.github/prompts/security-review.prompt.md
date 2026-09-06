---
agent: agent
<!-- @stack:desc -->
---

Read `CLAUDE.md`, `FRAMEWORK-CONTEXT.md`, and `.claude/commands/security-review.md`, then execute the security review workflow defined there for the scope below. Plain files restrict `Uncommitted`; reserve `whole-files:` for explicitly labelled whole-file review, using the one JSON-array `-PathFile` shape. Use its frozen `-ScopePath` bundle and manifest SHA-256 handoff; recompute `manifest.json` SHA-256 and reject mismatch as `CANNOT EXAMINE`. Do not recompute a Git diff or look up a PR. If `Task` is unavailable, invoke the security auditor sequentially; invalid or unreadable capture is `CANNOT EXAMINE`.

<!-- @stack:summary -->

For an active or suspected credential finding, do not echo protected incident detail in the response
or write it to Git. State only that restricted human handling is required and the minimum immediate
action class.

Be direct. Do not praise code for not being insecure — that is the baseline.

## Scope

${input:scope:Files restrict uncommitted; whole-files: files; explicit A..B or A...B; or leave blank}
