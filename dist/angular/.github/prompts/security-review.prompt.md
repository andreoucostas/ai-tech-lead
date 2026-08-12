---
agent: agent
description: Security review of changed Angular code. OWASP-style frontend scan plus senior judgement (auth, token handling, trust boundaries).
---

Read `CLAUDE.md`, `FRAMEWORK-CONTEXT.md`, and `.claude/commands/security-review.md`, then execute the security review workflow defined there for the scope below.

`.claude/commands/security-review.md` is the single source of truth. Follow it exactly: dispatch the `security-auditor` subagent (or run its checklist directly if subagents are unavailable) → cross-check against framework auth patterns → apply senior judgement on auth, trust boundaries, token lifecycle → verify auditor findings → synthesise with verdict APPROVE / REQUEST CHANGES / BLOCK. Never echo protected credential-incident detail or mutate Git for such an incident; require restricted human handling.

For an active or suspected credential finding, do not echo protected incident detail in the response
or write it to Git. State only that restricted human handling is required and the minimum immediate
action class.

Be direct. Do not praise code for not being insecure — that is the baseline.

## Scope

${input:scope:Files, PR number, or leave blank to review uncommitted changes}
