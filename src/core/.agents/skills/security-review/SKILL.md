---
name: security-review
<!-- @stack:desc -->
argument-hint: "[files (uncommitted filter) | whole-files: files | A..B | A...B; empty = uncommitted changes]"
---

Read `AGENTS.md`, `FRAMEWORK-CONTEXT.md`, and `.claude/commands/security-review.md`, then execute the security review workflow defined there for the scope below. Plain files restrict `Uncommitted`; reserve `whole-files:` for explicitly labelled whole-file review, using the one JSON-array `-PathFile` shape. Use its frozen `-ScopePath` bundle and manifest SHA-256 handoff; recompute `manifest.json` SHA-256 and reject mismatch as `CANNOT EXAMINE`. Do not recompute a Git diff or look up a PR. If `Task` is unavailable, invoke the security auditor sequentially; invalid or unreadable capture is `CANNOT EXAMINE`.

<!-- @stack:summary -->

For an active or suspected credential finding, do not echo protected incident detail in the response
or write it to Git. State only that restricted human handling is required and the minimum immediate
action class.

Be direct. Do not praise code for not being insecure — that is the baseline.

## Scope

The scope is the text after `/security-review`, or the change the developer asked to review: plain files restrict uncommitted changes; `whole-files:` files; an explicit `A..B` or `A...B`; none means the uncommitted changes. Use it wherever `.claude/commands/security-review.md` says `$ARGUMENTS`.
