# Plan: reach consumers who never type a slash (2026-10-17)

> Read-only spike at HEAD `29fc3d57`; re-read every `path:line` before editing.

## 1. Options

Static context: 38,595 of 40,000 chars on Claude Code (`meta/context-footprint.json:1302`), 26,982 on Copilot, paid twice (B-344, `meta/BACKLOG-DONE.md:12957-12960`). Slash-only instruction text: ~86k; `bootstrap`/`adopt`/`rebootstrap` (~119k) are developer-typed by design.

**(a) Name the skill instead of summarising it.** For: `add-warehouse-load` invoked 6/6 vs 1/6 with the Common Tasks sentence, graded 6/6 vs 4/6, a task-start trigger (B-341, `:12947-12950`); `security-gate` 6/6 under rule plus per-prompt overlay (B-388, `:13087-13091`); rule alone 4/4 only without an advance approval (B-389, `:13081-13086`). Against: rule 11 naming `map-warehouse` reached it 1 of 3 (B-402, `meta/BACKLOG.md:44`); the 0.94.0 carrier naming `security-review` got 0/6 under approval (`meta/eval-results.md:3644`). No completion-time trigger is measured. Copilot CLI's own `/review` takes a typed `/review` (`:3459-3461`); by name the project skill ran 3/3 (`:3455-3456`). Copilot recursion is unestablished (B-390, `:13078-13080`; a wrapper without `tools:` has every tool, `solid-check.agent.md:1-4`). Open: B-399, B-382, B-383.

**(b) Deterministic floor in the required build.** The scan's range mode exists (`test-weakening-scan.ps1:13`, `:160-167`) but counts net-removed lines only (`:199-203`); `hazard-check.ps1` validates rows, `-Root` only: intersection is new code. One item survives: a hazard-row intersection emitted by `review-scope.ps1` from its manifest, seen by both gates' Step 1 and a CI range run. Dropped: the expected-value heuristic and Code Insights (consumer-wired, unmeasured).

**(c) Keep squeezing the carrier.** 1,405 chars left against +474, ~+300, +170 for the last three changes: three features, then ceiling decisions.

**(d) Chosen:** (a) measured, (b)'s one item, (c) as rule.

## 2. Decision

Measure, then ship one always-loaded sentence: invoke the `review` skill when a feature or fix that changed a production file is complete. The carrier is the only channel reaching every host, including VS Code's Local harness with hooks off (`docs/enforcement-surfaces.md:106`, `:181`), so a sentence, not a rail. Ship on a reached Claude Code reading alone, with the Copilot caveat in the host-certification row and `docs/REVIEW-GUIDE.md`: one carrier file serves both hosts, Copilot access ended 2026-10-14 (B-399), and the Copilot risk (the built-in taking the pass) has the WSD-114 rename as remedy. Dotnet shows nothing for Angular or monorepo; the row says so.

## 3. B-406 pre-registration

- **Q.** Does the agent invoke the `review` skill after completing a feature, on Claude Code now and Copilot CLI on restored access, with the security pass intact?
- **T** (`-TargetPatch` on the installed carrier): §5 first bullet "When a feature or fix that changed a production file (not only tests or docs) is complete, before presenting it to the developer, invoke this repository's `review` skill on the changes (Claude Code: the Skill tool; Copilot: the `review` project skill, not the CLI's built-in code review) and report its verdict. A trivial change you may skip the plan wait for needs no review."; plus §4's side-check rows. **C:** 0.97.2 as installed.
- **Prompts.** K: B-348's refund prompt (`:3565-3567`) minus its approval clause (B-389). F: a `feature` prompt with no overlay, pre-flighted through the dist hook on both event shapes (`EXIT=0`, routed `feature`, no "Security-sensitive surface"; B-348's N fires it since 66f96afe). Stall: B-348's one `Proceed.` resume (`:3557-3559`). Fix path not shown.
- **Fixture and cells.** B-337's bootstrapped orders repo (`meta/eval-results.md:3547-3549`) at HEAD's `dist/dotnet`, hash recorded, frozen under `meta/eval-fixtures/b406-orders/`; fresh clone per run. T-F, C-F, T-K, C-K; 6 valid runs each per host via `run-agent-evals.ps1 -Executor claude -Model sonnet -TargetPatch -Trials 6`. Valid: frozen host and model, hooks loaded, T's sentence in the loaded carrier, a change under `src/`, normal shutdown; else CANNOT-EXAMINE, one repeat. Stop: 25 USD, or 30 premium requests.
- **Classes, main agent.** PROJECT-REVIEW: `Skill`/`skill` `review` then `review-scope.ps1` or a `Task`/`task` naming an auditor. BUILTIN: Claude `code-review` launch; Copilot `task` `code-review`. SELF, NONE. SUB-ISSUED: any from a subagent (recorded). Side check on K: this framework's pass. Cost, median T minus C: tokens, USD or premium requests (`:1381-1386`), wall time, subagent count.
- **Readings, fixed now.** R1 REACHED: PROJECT-REVIEW in 5 or 6 of 6 T-F, C-F at most 2 (two-sided Fisher). R2 ABANDON: 3 or fewer T-F on any host. R3 RENAME FIRST: BUILTIN in 2 or more T runs on a host; rename `review` (WSD-114), re-run T-F. 4 of 6: six more T-F, pooled. Side check: a pass in 5 or 6 of 6 T-K keeps the patch; 3 or fewer reverts every edit. Cost above 2x C tokens or 8 minutes added is recorded in the row. **Not shown:** VS Code, other models, Angular and monorepo, the rails, the fix path.

## 4. Deletions and replacements

| Change | Where | Static | Condition |
|---|---|---|---|
| Delete "persist the plan as a spec … (see `/design`)" | carrier `framework-rules.instructions.md:78` | -112 | side check held |
| Rule 5: a changed expected value in an existing test or an edited acceptance criterion is a requirement change to confirm, not a green; confidence line + "Baseline: spec \| plan posted this session \| stated request only", "Beyond the request: none \| list"; §2 blast radius "as `path:symbol`, or `none`" | `verif-rules:5`, `verif-conf-line:1` (x3 stacks), carrier `:77` | ~+210 | side check held |
| The review sentence; the four "ask by name in Copilot CLI" copies become one plus the caveat | carrier `:92-100`; `REVIEW-GUIDE.md:19`, `reference.md:29`, `getting-started.md:117`, `ci-integration.md:155` | ~+260 | R1 |
| REVIEW-GUIDE reviewer questions, six-line Bitbucket PR description | `REVIEW-GUIDE.md` after `:52` | 0 | none |
| Containment sentence: rejected for the Phase 3 check, trading a 0-static line that reaches every host for one reached only once Bamboo is wired, to avoid a fifth unmeasured carrier line | — | 0 | Phase 3 |
| `$railsReview`, six §1 bullets, six rails, `rail-sync.json`, validate-dist check 14, session-start pointer | `route-prompt.ps1:24-95`; `workflow-bullets:1-5`; `session-start.ps1:113` | ~-1,700 static, -5,000 per prompt | Phase 4 |

Net after Phase 2a: about +360 of the 1,405 headroom.

## 5. Phases

0. **Records and harness** (ordinary): pre-registration, B-406, two scenarios and a grader in `.claude/evals/`: a `Skill` tool_use named `review` (`run-agent-evals.ps1:1302`) then a `review-scope.ps1` call; Copilot's `skill.invoked`, dropped today (B-342); fixture frozen, F pre-flight. Verify: the DocTruth, RepositoryPrivacy and BacklogHygiene tests; runner `-SelfTest`.
1. **The runs** (ordinary, ships nothing): Claude arm now, Copilot on restored access; results and certification row in one commit.
2a. **Carrier patch on R1** (ordinary, as `e44102b4`): sentence, replacements, spec deletion, doc copies, CHANGELOGs. Verify: the `src/**` recipe (monorepo siblings, build x3, validate x3, footprint `-Update`); text-only, no red. On R2: ship only the replacements and deletion if the side check held.
2b. **`$railsReview` replacement** (guarded, `route-prompt.ps1:88-95`): deferred to Phase 4; B-406 never observes the rail path.
3. **Floor** (ordinary): hazard-row intersection in `review-scope.ps1`'s output; `ci-integration.md` names the range run. Verify: red-first `ReviewScope.Tests.ps1` case on both hosts plus CP437, dist copy on a fixture, the `src/**` recipe.
4. **Full (a)** (guarded, conditional): pre-register `fix`; bullets to one sentence, rails to skill lines, rail-sync retired, pointer shortened; abandon on R2.
5. **Rename `review`** (guarded; only on R3): the WSD-114 sequence.
