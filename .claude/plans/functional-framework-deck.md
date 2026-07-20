# Functional framework deck revision

## Problem

The v0.34.0 technical deck accurately classifies the architecture and enforcement strengths, but it
remains too abstract to teach a team member what literally happens during installation and daily
use. It names components without exposing their inputs, outputs, ordering, developer interactions,
or failure paths.

## Narrative

Use one running example: **"Add CSV export to the dashboard."** Follow it through the real system:

1. Installer detects the stack, archives collisions, and copies the selected distribution.
2. Bootstrap replaces template placeholders with repository-specific facts.
3. Opening an agent session triggers `SessionStart` and injects bounded current state.
4. A natural-language prompt triggers `UserPromptSubmit`; `route-prompt` classifies it and emits the
   Feature workflow rails and plan gate.
5. The agent reads the canonical rules, project context, and `/feature` contract; the developer
   reviews the proposed files, order, failure modes, and tests.
6. Each editor write passes through `PreToolUse`; `guard` allows or denies defined patterns.
7. Successful editor writes trigger `PostToolUse`; `post-write` runs fast feedback and
   `audit-trail` records the changed path.
8. The workflow explicitly runs build and relevant tests after coherent subtasks.
9. Self-review, focused agents, and the Boy Scout hook inspect the result.
10. CI re-runs deterministic checks independently of the assistant.
11. Architecture, decisions, debt, security findings, learnings, and derived instruction files are
    updated when the change makes them stale.

## Slide standard

Every functional slide must show:

- the triggering person or event;
- the exact shipped file or command involved;
- representative input and output;
- whether the action instructs, nudges, blocks, validates, records, or requires human judgement;
- what the developer sees and must decide;
- the relevant failure/degradation path.

## Team coverage

Include explicit daily responsibilities for developers, reviewers, tech leads, and platform/tooling
owners, plus hotfix/incident behaviour and the procedure for changing a team standard.

## Verification

- Render the opening, request-routing, write-lifecycle, role-responsibility, and summary slides.
- Confirm no slide overflows at 1600x900.
- Rebuild and validate all three distributions through the release workflow.

