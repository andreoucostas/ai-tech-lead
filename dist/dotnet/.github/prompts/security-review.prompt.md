---
agent: agent
description: Security review of changed code in this repository. Apply profile-specific OWASP checks only where repository evidence and changed files support them; use senior judgement for auth, data flow, and error envelopes.
---

Read `CLAUDE.md`, `FRAMEWORK-CONTEXT.md`, and `.claude/commands/security-review.md`, then execute the security review workflow defined there for the scope below. Plain files restrict `Uncommitted`; reserve `whole-files:` for explicitly labelled whole-file review, using the one JSON-array `-PathFile` shape. Use its frozen `-ScopePath` bundle and manifest SHA-256 handoff; recompute `manifest.json` SHA-256 and reject mismatch as `CANNOT EXAMINE`. Do not recompute a Git diff or look up a PR. If `Task` is unavailable, invoke the security auditor sequentially; invalid or unreadable capture is `CANNOT EXAMINE`.

`.claude/commands/security-review.md` is the single source of truth. Follow it exactly: derive only repository-evidenced **build**, **test**, **format**, **lint**, **migration/deploy**, **data-validation**, and dependency-scan commands (report unsupported categories as **not available**) → dispatch the `security-auditor` subagent (or run its applicable checklist directly if subagents are unavailable) → cross-check applicable framework auth patterns → apply senior judgement on applicable auth, data flow, and concurrency concerns → verify auditor findings → synthesise with verdict APPROVE / REQUEST CHANGES / BLOCK. Never echo protected credential-incident detail or mutate Git for such an incident; require restricted human handling.

For an active or suspected credential finding, do not echo protected incident detail in the response
or write it to Git. State only that restricted human handling is required and the minimum immediate
action class.

Be direct. Do not praise code for not being insecure — that is the baseline.

## Scope

${input:scope:Files restrict uncommitted; whole-files: files; explicit A..B or A...B; or leave blank}
