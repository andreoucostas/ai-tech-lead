---
mode: agent
description: Security review of changed .NET code. OWASP-style scan plus senior judgement (auth, data flow, error envelopes).
---

Read `CLAUDE.md`, `FRAMEWORK-CONTEXT.md`, and `.claude/commands/security-review.md`, then execute the security review workflow defined there for the scope below.

`.claude/commands/security-review.md` is the single source of truth. Follow it exactly: dispatch the `security-auditor` subagent (or run its checklist directly if subagents are unavailable) → cross-check against framework auth patterns → apply senior judgement on auth, data flow, concurrency → verify auditor findings → synthesise with verdict APPROVE / REQUEST CHANGES / BLOCK.

Be direct. Do not praise code for not being insecure — that is the baseline.

## Scope

${input:scope:Files, PR number, or leave blank to review uncommitted changes}
