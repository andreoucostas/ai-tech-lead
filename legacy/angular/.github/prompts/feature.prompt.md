---
agent: agent
description: Implement a new feature in this Angular codebase end-to-end (models → state → component → tests).
---

Read `CLAUDE.md` and `.claude/commands/feature.md` in this repository, then execute the feature workflow defined there for the request below.

`.claude/commands/feature.md` is the single source of truth for this workflow. Follow it exactly: design check → ordered subtasks (models/services → state → component → integration) with `ng build` and `ng test` between each → Boy Scout on touched files → self-review against `CLAUDE.md` conventions → present.

## Request

${input:request:Describe the feature you want implemented}
