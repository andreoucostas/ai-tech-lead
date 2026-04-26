---
mode: agent
description: Refresh the AI Tech Lead framework config for this .NET codebase — diff-aware merge into existing CLAUDE.md and TECH_DEBT.md after months of evolution.
---

Read `CLAUDE.md` and `.claude/commands/rebootstrap.md` in this repository, then execute the rebootstrap workflow defined there.

`.claude/commands/rebootstrap.md` is the single source of truth for this workflow. Follow it exactly: pre-flight check → git log pre-step → re-analysis (A1–A6 scoped to changed areas) → delta synthesis → diff-aware merge with user confirmation per chunk → final report.

## Request

${input:request:Describe what has changed or what areas you want to re-align (leave blank for a full drift check)}
