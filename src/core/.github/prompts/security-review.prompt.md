---
agent: agent
<!-- @stack:desc -->
---

Read `CLAUDE.md`, `FRAMEWORK-CONTEXT.md`, and `.claude/commands/security-review.md`, then execute the security review workflow defined there for the scope below.

<!-- @stack:summary -->

For an active or suspected credential finding, do not echo protected incident detail in the response
or write it to Git. State only that restricted human handling is required and the minimum immediate
action class.

Be direct. Do not praise code for not being insecure — that is the baseline.

## Scope

${input:scope:Files, PR number, or leave blank to review uncommitted changes}
