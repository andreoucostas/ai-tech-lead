---
agent: agent
description: Refresh the AI Tech Lead framework config for this repository — derive applicable profiles from repository evidence, then make a diff-aware merge into existing AGENTS.md and TECH_DEBT.md after months of evolution.
---

Read `AGENTS.md` and `.claude/commands/rebootstrap.md` in this repository, then execute the rebootstrap workflow defined there.

`.claude/commands/rebootstrap.md` is the single source of truth for this workflow. Follow it exactly: pre-flight check → baseline pre-step (stop when nothing changed) → re-analysis (A1–A8 .NET / A1–A7 Angular; each profile full or incremental) → delta synthesis → diff-aware merge with user confirmation per chunk → re-record the baseline → final report.

## Request

${input:request:Describe what has changed or what areas you want to re-align (leave blank for a full drift check)}
