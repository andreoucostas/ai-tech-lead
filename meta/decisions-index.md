# Standing decisions index

This is a curated index of standing constraints decided elsewhere, not an exhaustive inventory: a
constraint written only inside a shipped artifact can be absent. Before locking a design that
changes a shipped artifact, read its current authoring source under `src/` as well as this index.
Follow the cited source; do not treat this file as a second statement of the decision or its
reasoning.

Citations use stable WSD or backlog entry ids, never line numbers: line numbers move on every edit
to the backlog, and a citation that rots is worse than none. The hygiene gate verifies that each
cited source and stable id resolves. For backlog-entry citations it also verifies that the displayed
phrase occurs inside the cited entry; WSD labels are curated summaries, and the cited WSD remains
authoritative.

- “Single-source composition; generated distributions are not authored.” — `meta/workspace-decisions.md WSD-012`
- “A stack-specific source change requires reviewing its monorepo sibling.” — `meta/workspace-decisions.md WSD-015`
- “Evals are not a release gate.” — `meta/workspace-decisions.md WSD-016`
- “The meta/product boundary is sealed and machine-checked.” — `meta/workspace-decisions.md WSD-019`
- “Do not add a separate testing skill or data-warehouse distribution.” — `meta/workspace-decisions.md WSD-020`
- “The Copilot Boy Scout nudge remains advisory; never block.” — `meta/workspace-decisions.md WSD-024`
- “Capability probes use the consumer’s vantage point.” — `meta/workspace-decisions.md WSD-026`
- “Automation never sets or upgrades warehouse-map status.” — `meta/workspace-decisions.md WSD-027`
- “A gate can expose evidence or absence without certifying independence or quality” — `meta/workspace-decisions.md WSD-028`
- “A release tag follows CI-verified green.” — `meta/workspace-decisions.md WSD-029`
- “Framework-owned rules have one unprotected carrier.” — `meta/workspace-decisions.md WSD-031`
- “Read-side guidance travels on the measured channel.” — `meta/workspace-decisions.md WSD-032`
- “Proportionality belongs inside pre-lock critique.” — `meta/workspace-decisions.md WSD-034`
- “Updates disclose ownership classes and back up settings.” — `meta/workspace-decisions.md WSD-043`
- “The stale quarterly-drill protocol is historical; re-lock it before any live spend.” — `meta/workspace-decisions.md WSD-062` (supersedes WSD-022/WSD-044 for execution)
- “Template-check findings use a fixed status, never their count.” — `meta/workspace-decisions.md WSD-063`
- “Scoped test-file instructions buy locality, not coverage — B-17 is rejected.” — `meta/workspace-decisions.md WSD-045`
- “Guard regex errors split by confidence; content case is exact and routing folds.” — `meta/workspace-decisions.md WSD-046`
- “Bypasses are answered by kind — harden, advise, or document — never uniformly.” — `meta/workspace-decisions.md WSD-047`
- “Recover consumer state and evidence integrity before structural redesign.” — `meta/workspace-decisions.md WSD-048`
- “issue intake is not sentiment evidence; balanced field outcomes use a replay plus diary” — `meta/workspace-decisions.md WSD-053`
- “Onboarding preserves evidence and project ownership; repeated samples describe stability, not truth.” — `meta/workspace-decisions.md WSD-054`
- “Reject permanent Codex integration unless repeated artifact-only work exposes concrete ad-hoc cost or defects and supplies an immutable final-state oracle that can be red-tested.” — `meta/workspace-decisions.md WSD-054`
- “Historic decisions are evidence-bearing defaults, not doctrine.” — `meta/workspace-decisions.md WSD-057`
- “Independent review is evidence-bound, not rank-bound.” — `meta/workspace-decisions.md WSD-057`
- “The next independent paired replay begins FS2 and is never aggregated with FS1.” — `meta/workspace-decisions.md WSD-058`
- “A unique supported-provider claim can justify one focused provider leg.” — `meta/workspace-decisions.md WSD-061` (WSD-073 supersedes its multi-platform topology)
- “Host evidence is capability-specific and recertification is evidence-triggered.” — `meta/workspace-decisions.md WSD-066`
- “Specification readiness remains adaptive; Draft status is not human authority.” — `meta/workspace-decisions.md WSD-067`
- “B-136 re-locks one size-negative reconciliation rule and nothing else” — `meta/workspace-decisions.md WSD-068`
- “The standing-decisions index is curated meta guidance, not an exhaustive inventory of constraints embedded in shipped artifacts.” — `meta/workspace-decisions.md WSD-069`
- “Unavailable team intent is not a gradable agent outcome; a direction-of-travel probe must grade asking or unresolved separately from canonizing legacy.” — `meta/workspace-decisions.md WSD-070`
- “Framework-maintainer tests stay in distributions but do not install into consumers or evidence application verification.” — `meta/workspace-decisions.md WSD-071`
- “Project skills ship once under `.claude/skills`; retire only content-qualified GitHub mirrors.” — `meta/workspace-decisions.md WSD-072` (WSD-073 supersedes its Bash-adapter retention)
- “Supported framework execution is native Windows and PowerShell only.” — `meta/workspace-decisions.md WSD-073`
- “do not try to make this a deterministic gate” — `meta/BACKLOG-DONE.md B-83`
- “no always-on router or no-match hook” — `meta/BACKLOG-DONE.md B-98`
- “Reuse the B-41 harness; do not build a second one.” — `meta/BACKLOG-DONE.md B-98`
- “B-129/WSD-042 is out of scope for this item” — `meta/BACKLOG-DONE.md B-140`
- “Vendor-capability claims are maintainer-owned and gated meta-side, never in a consumer's build.” — `meta/BACKLOG-DONE.md B-55`
