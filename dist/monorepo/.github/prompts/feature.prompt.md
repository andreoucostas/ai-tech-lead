---
agent: agent
description: Implement a new feature in this mixed .NET + Angular codebase end-to-end (.NET: domain → service → API → tests; Angular: models → state → component → tests).
---

Read `CLAUDE.md` and `.claude/commands/feature.md` in this repository, then execute the feature workflow defined there for the request below.

`.claude/commands/feature.md` is the single source of truth for this workflow. Follow it exactly: design check → ordered subtasks per stack touched (.NET: domain → service → API → integration test, gated by `dotnet build` and `dotnet test`; Angular: models/services → state → component → integration, gated by `ng build` and `ng test`) → Boy Scout on touched files → self-review against `CLAUDE.md` conventions → present.

## Request

${input:request:Describe the feature you want implemented}
