---
name: security-review
description: "Security gate on changed code: spawns the security-auditor subagent, cross-checks tenant isolation and shared-library auth patterns, and records only repository-safe critical/high findings in SECURITY_FINDINGS.md. Credential incidents require restricted human handling and never mutate Git automatically."
argument-hint: "[files (uncommitted filter) | whole-files: files | A..B | A...B; empty = uncommitted changes]"
---

Read `AGENTS.md`, `FRAMEWORK-CONTEXT.md`, and `.claude/commands/security-review.md`, then execute the security review workflow defined there for the scope below. Plain files restrict `Uncommitted`; reserve `whole-files:` for explicitly labelled whole-file review, using the one JSON-array `-PathFile` shape. Use its frozen `-ScopePath` bundle and manifest SHA-256 handoff; recompute `manifest.json` SHA-256 and reject mismatch as `CANNOT EXAMINE`. Do not recompute a Git diff or look up a PR. If `Task` is unavailable, invoke the security auditor sequentially; invalid or unreadable capture is `CANNOT EXAMINE`.

`.claude/commands/security-review.md` is the single source of truth. Follow it exactly: derive only repository-evidenced **build**, **test**, **format**, **lint**, **migration/deploy**, **data-validation**, and dependency-scan commands (report unsupported categories as **not available**) → dispatch the `security-auditor` subagent (or run its applicable checklist directly if subagents are unavailable) → cross-check applicable framework auth patterns → apply senior judgement only to the evidence-selected profiles → verify auditor findings → synthesise with verdict APPROVE / REQUEST CHANGES / BLOCK. Never echo protected credential-incident detail or mutate Git for such an incident; require restricted human handling.

For an active or suspected credential finding, do not echo protected incident detail in the response
or write it to Git. State only that restricted human handling is required and the minimum immediate
action class.

Be direct. Do not praise code for not being insecure — that is the baseline.

## Scope

The scope is the text after `/security-review`, or the change the developer asked to review: plain files restrict uncommitted changes; `whole-files:` files; an explicit `A..B` or `A...B`; none means the uncommitted changes. Use it wherever `.claude/commands/security-review.md` says `$ARGUMENTS`.
