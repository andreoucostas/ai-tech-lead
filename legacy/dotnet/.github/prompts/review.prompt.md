---
mode: agent
description: Review code as a senior tech lead. This is a quality gate, not a rubber stamp.
---

Read `CLAUDE.md` and `.claude/commands/review.md`, then execute the review workflow defined there for the scope below.

`.claude/commands/review.md` is the single source of truth. Follow it exactly: correctness & convention compliance → test quality & coverage → verify by running `dotnet build` and `dotnet test` yourself → architecture & debt trajectory → report in the structured format with verdict APPROVE or REQUEST CHANGES.

Be direct. Do not praise code for meeting baseline expectations.

## Scope

${input:scope:Files, PR number, or leave blank to review uncommitted changes}
