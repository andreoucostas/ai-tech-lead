---
mode: agent
description: Implement a new feature in this .NET codebase end-to-end (domain → service → API → tests).
---

Read `CLAUDE.md` and `.claude/commands/feature.md` in this repository, then execute the feature workflow defined there for the request below.

`.claude/commands/feature.md` is the single source of truth for this workflow. Follow it exactly: design check → ordered subtasks (domain → service → API → integration test) with `dotnet build` and `dotnet test` between each → Boy Scout on touched files → self-review against `CLAUDE.md` conventions → present.

## Request

${input:request:Describe the feature you want implemented}
