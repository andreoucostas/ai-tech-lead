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
- “Do not add a separate testing skill.” — `meta/workspace-decisions.md WSD-020`
- “Do not add a separate data-warehouse distribution.” — `meta/workspace-decisions.md WSD-021`
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
- “Independent review is evidence-bound, not rank-bound.” — `meta/workspace-decisions.md WSD-057` (WSD-092 amends who supplies red evidence and narrows the orthogonal vantage to the installer's destructive blocks)
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
- “Discover repository knowledge broadly; capture grounded drafts in existing carriers and measure ordinary Copilot outcomes before expanding machinery.” — `meta/workspace-decisions.md WSD-074` (WSD-091 pauses its expansion until B-253 reports)
- “Run eight native Windows execution contexts independently, then require one same-platform case-count parity decision.” — `meta/workspace-decisions.md WSD-075`
- “CP1 is a separate maintainer Copilot campaign; readiness precedes purchase.” — `meta/workspace-decisions.md WSD-076` (WSD-091 closes CP1 as scoped)
- “CP1 may assess a Hyper-V-isolated Windows container; offline feasibility does not establish paid-run readiness.” — `meta/workspace-decisions.md WSD-077` (prospectively amends WSD-076's guest requirement; WSD-091 closes CP1 as scoped)
- “CP2's paid comparison is retired on decision-value grounds; isolation and efficacy remain unknown, and any new attempt requires a fresh decision.” — `meta/workspace-decisions.md WSD-078`
- “RK1 compares the discovery increment above retained knowledge paths on a matched current foundation; policy execution must be demonstrated before study dispatch.” — `meta/workspace-decisions.md WSD-081` (WSD-091 closes RK1 as scoped)
- “Ordinary overwrite and ledger retirement are different contracts; a path can never be both.” — `meta/workspace-decisions.md WSD-088`
- “Root `AGENTS.md` is the canonical maintainer instruction file, imported by `CLAUDE.md`; both sit under recorded ceilings.” — `meta/workspace-decisions.md WSD-089`
- “Ceremony follows the change class decided from the changed paths; prose ships batched with a disclosed non-review cell.” — `meta/workspace-decisions.md WSD-089` (amends WSD-028/WSD-057 scope for records and prose)
- “Knowledge-increment expansion is paused until the with/without-framework eval first reports; CP1 and RK1 are closed as scoped, and any new attempt requires a fresh decision.” — `meta/workspace-decisions.md WSD-091`
- “Red evidence is mechanical (`assert-red-first.ps1`); the user's review counts only in the user's own words; mechanism changes run touched tests locally and CI runs every suite; an RCA is owed only for an escaped defect.” — `meta/workspace-decisions.md WSD-092` (amends WSD-057 and WSD-089)
- “Two path-keyed tiers, guarded and ordinary; review only on the destructive guarded subset; the backlog is capped at 40 compact entries and a decision entry at ten lines.” — `meta/workspace-decisions.md WSD-093` (supersedes WSD-089's classes and success measure and WSD-092 items 3–5)
- “The write guard's edit-scope gap is documented, not hardened: scanning the pre-edit file with the new text refuses the edit that removes a leaked key.” — `meta/workspace-decisions.md WSD-094` (applies WSD-047)
- “A project `.claude/commands/<name>.md` replaces the host's built-in of the same name; the shipped `/security-review` runs.” — `meta/workspace-decisions.md WSD-095`
- “The agent-eval self-test is a recipe (after a runner change, before a live run), not a release gate and not CI; the runner is kept for B-253.” — `meta/workspace-decisions.md WSD-096`
- “B-222 to B-224 are held after B-253's first report; one timeboxed Copilot executor spike runs inside the existing eval runner without the CP1/RK1 isolation, relay or candidate contract.” — `meta/workspace-decisions.md WSD-097` (answers WSD-091's resumption clause)
- “Shipped `AGENTS.md` is the one edited instruction file; `CLAUDE.md` is a two-import stub; update moves an older layout once, only over a generated mirror.” — `meta/workspace-decisions.md WSD-098` (supersedes WSD-002's mirror clause)
- “`.github/copilot-instructions.md` and `/generate-copilot` are retired; Visual Studio and github.com Copilot Chat lose framework-delivered conventions by choice.” — `meta/workspace-decisions.md WSD-099`
- “Keep `route-prompt`; commands already are skills on Claude Code; path-scoped rules are not used for the workflow rails; no non-inferiority trial is funded.” — `meta/workspace-decisions.md WSD-100`
- “Distribution stays file-copy; a plugin cannot replace the in-tree files Copilot reads; any installer rewrite keeps hash-gated retirement.” — `meta/workspace-decisions.md WSD-101` (withdraws WP7's ledger deletion)
- “No framework hook runs test suites or `Verification Commands` rows; the post-write build throttle is a stated limit, not fixed.” — `meta/workspace-decisions.md WSD-102` (closes B-261)
- “do not try to make this a deterministic gate” — `meta/BACKLOG-DONE.md B-83`
- “no always-on router or no-match hook” — `meta/BACKLOG-DONE.md B-98`
- “Reuse the B-41 harness; do not build a second one.” — `meta/BACKLOG-DONE.md B-98`
- “B-129/WSD-042 is out of scope for this item” — `meta/BACKLOG-DONE.md B-140`
- “Vendor-capability claims are maintainer-owned and gated meta-side, never in a consumer's build.” — `meta/BACKLOG-DONE.md B-55`
