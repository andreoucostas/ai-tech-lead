# B-222/B-223: bounded discovery, capture and refresh acceptance

**Date:** 2026-09-08. **Source baseline:** v0.86.0,
`c9e25953e2cdd04c1bc780a5a95ddab5c806b494`.
**Status:** reviewed execution proposal; source-checked final corrections recorded in the companion review. This document plans execution;
the present user request authorizes planning and the requested fresh-context and Opus reviews.
It does not start semantic trials, implement product changes, or reopen a Copilot study.
**Authority:** root `CLAUDE.md`, `DEVELOPING.md`, WSD-074, WSD-078 and WSD-079.
**Outcome:** establish exactly which named authoring-workflow cases work on this release, repair
only reproduced in-scope defects when execution is authorized, and retain every miss and limitation.

## 1. Why this scope

The retained PK-2 record reports a skill with no link to its created reference and a duplicate
operation in the wiki. Later source text explicitly requires the link and forbids the duplicate,
but the record contains no accepted follow-up demonstrating those corrections. The record also
leaves budget exhaustion, continuation and semantic refresh unobserved. These are concrete evidence
gaps; they are not proof that the current release still has those defects.

Three options were considered:

| Option | Decision and trade-off |
|---|---|
| Re-run only existing parser/ownership suites | Cheapest, but cannot answer whether a model discovers meaning or refreshes a quiet dependent claim. Reuse them for their existing mechanical coverage. |
| One small retained/reconstructed fixture family with bounded authoring observations | Selected. Exercises the named semantic obligations and yields a repair/no-repair decision without an enterprise application or new runtime. |
| Resume CP2, create a broad benchmark, or run Copilot outcome comparisons | Disproportionate to this acceptance question and outside this delivery. B-224/B-225/B-42 retain their separate questions and authority. |

The smaller first action is re-examination of current carriers and retained artifacts. Do not edit
prose merely because an old run failed. A corrected current carrier may need evidence only.
Do not add a registry, generic grader, workflow engine, new release gate or context-budget increase.

## 2. What was actually checked during planning

- The working tree was clean; all three distribution stamps read `0.86.0`.
- The current monorepo bootstrap Phase 3a-bis explicitly requires both operation files, a relative
  Markdown link to each focused reference, and no wiki duplicate of the same operation.
- Rebootstrap's Phase 3 permits automatic creation only for absent drafts. Existing wiki/skill/map
  changes remain confirmed diffs, including refresh after a dependency changes.
- Discovery is `A8` in .NET and monorepo, but **`A7` in Angular**. Do not send Angular an A8 request.
- The external archive below exists. Its `pk2-capture-4` Git HEAD is
  `f53c3564b22d534e15a6c09ca15547032c6b2c79`; its 15 tracked input paths are readable.
  `capture-output.md` matches recorded SHA-256
  `52762C9D9EFB2B545A52D06FB63B8A72597CB47FB2B392FFA27818738059135E`.
- The original PK-1 discovery input is documented as deleted. Do not describe its reconstruction
  as a rerun of that input. Existence of other archive directories does not recover that evidence.
- Native PS7, PS5.1 and Claude CLI resolve here. Claude reports `2.1.260`. Every recipe flag was
  found in its help: `--print`, `--model`, `--effort`, `--output-format`, `--verbose`, `--safe-mode`,
  `--restricted`, `--strict-mcp-config`, `--no-session-persistence`, `--disable-slash-commands`,
  `--permission-mode`, `--tools`, `--allowedTools`, `--max-budget-usd`, `--add-dir`. Help describes print as
  noninteractive/pipeline mode, restricted mode as confined file tools with execution tools removed,
  safe mode as customization-disabled, and the USD flag as a maximum for print calls. Retained full
  help and review startup metadata are identified in the companion review record. The Opus review
  actually used stdin redirection and this read-only flag combination, resolving `claude-opus-5`
  with only Glob/Grep/Read in init and usage in result. This does not calibrate the proposed Sonnet
  write route, outside-root denial, opaque startup content, or monetary-limit enforcement.
- A local PS7 7.6.5 / CP65001 supervisor probe captured native exits 7 and 0 correctly and retained
  both stdout and stderr after terminating a sleeping child. This is narrow process evidence;
  no semantic actor, fixture acceptance or PS5.1 supervisor run followed.

Archive hint, not a portable dependency:
`%TEMP%\ai-tech-lead-forward-eval-adf0b0e-20260906-c9fa636e3ce74aa3a4965160948c0d87\pk2-capture-4`.
Original observations: `meta/repository-knowledge-forward-evidence.md`. Preserve that historical
record unchanged; write a new dated result section or companion record for this series.

## 3. Roles, authority and bounded effort

The **delivery lead** prepares fixtures, freezes inputs, observes commands, scores evidence and
integrates changes. A **fresh actor** receives only its consumer fixture, the actual workflow
entrypoint and neutral request. An **independent reviewer** receives the frozen contract and raw
evidence, forms its own threat model and checks the lead's conclusions. An actor must not grade
itself; a reviewer must not implement the fix it later reviews. One writer at a time.

This is local fixture work plus model-driven authoring observations, **not literally offline model
execution**. Proposed execution uses the installed Claude CLI for its observable tool/result stream,
with `sonnet`, medium effort, no model fallback, and recorded resolved model identifiers. This is
Claude authoring evidence, never Copilot efficacy. The separate requested Opus design review is
authorized now; it does not authorize these future actor calls.

If the user approves execution of this plan, the proposed allowance is at most **180 minutes** for
fixture preparation, observation, adjudication and the acceptance report, and **eight actor calls**
with `--max-budget-usd 1` each (USD8 aggregate configured limit, enforcement unverified). Six primary calls are specified
below; at most two additional calls may rerun an affected case after one justified source correction
or perform the separately labelled isolated capture case defined in P1.
Calibration, aborted calls and launcher failures consume this allowance. This is a proposed cap,
not a predicted price or a claim that CLI accounting equals the invoice. Record observed usage and
unknown usage. No model upgrade, extra calls or substitute study follows exhaustion. Required
product-release verification is separate from this diagnostic allowance and cannot be waived to fit.

If the actor cannot expose matched tool-use/tool-result events, resolved identity and usage, or
rejects the configured limit, stop that observation as `CANNOT-EXAMINE`. Flag acceptance plus usage
reporting does not prove monetary enforcement. The supervisor deadline and attempted-call count
are the controlled bounds; unexpected reported overspend stops further calls. Do not build another general
harness to overcome the limitation. A changed route or budget needs a revised concrete proposal.
No external application, network isolation engineering, new installation, Copilot call, production
query, private source export or participant contact is part of this plan.

The 180 minutes is an attempt ceiling, not a delivery-time estimate. Use these staged maxima:
fixture construction and independent fixture/control critique 50 minutes; launch/calibration
preparation 15; actor work 80 (including optional calls and in-call calibration); adjudication and
the concise acceptance report 35. Each stage is also bounded by remaining global time. At a stage
timeout retain completed evidence, mark unreached rows NOT EXERCISED, and stop dependent work;
do not spend the next stage's allowance rescuing failed prerequisites. Normal documentation checks,
commit/push/CI and any required release verification follow outside the diagnostic clock and add no
actor calls. A partial attempt is a permitted outcome, not permission to relax controls or raise caps.

## 4. Required reading and exact source map

Read root `CLAUDE.md`, `DEVELOPING.md`, `meta/decisions-index.md`, backlog B-222/B-223, WSD-074,
and sections 3-5 of `.claude/plans/2026-09-05-repository-knowledge-strategy.md`.
The old implementation contract describes history; this document fixes the acceptance scope.

| Subject | Current authoring paths; inspect all named siblings before any product edit |
|---|---|
| Discovery instructions | `src/stacks/{dotnet,angular,monorepo}/files/.claude/commands/bootstrap.md` and `.claude/agents/bootstrap-pass.md` |
| Continuation, ownership and refresh | `src/stacks/{dotnet,angular,monorepo}/files/.claude/commands/rebootstrap.md` |
| Fact capture and dates | `src/core/.claude/skills/remember-for-team/SKILL.md`, `src/core/docs/wiki/_template.md`, `src/core/scripts/wiki-check.ps1` |
| Static carrier checks | `.claude/hooks/tests/DocClaims.Tests.ps1`, functions `Assert-RepositoryKnowledgeDiscoveryContracts` and `Assert-RepositoryKnowledgeCaptureContracts` |
| Existing wiki/ownership mechanics | `src/core/tests/hooks/WikiCheck.Tests.ps1`, `.claude/hooks/tests/UpdateDelivery.Tests.ps1`, `.claude/hooks/tests/InstallerConvergence.Tests.ps1` |
| Existing stream/observer patterns | `.claude/evals/run-agent-evals.ps1`, `.claude/evals/tests/AgentEvals.Tests.ps1`; do not invoke the live scenario matrix for this task |

Run semantic cases on **monorepo** first, since it holds the mixed-domain contract. Read the .NET
and Angular siblings and run existing three-dist static checks. No semantic parity is claimed for
an unrun stack. Full `/bootstrap` and `/rebootstrap` contain other phases and human checkpoints;
the calls below deliberately exercise named components, not full onboarding or host dispatch.

## 5. Package the fixture before exposing it to an actor

Create a small maintainer-only fixture family at
`meta/eval-fixtures/repository-knowledge-acceptance/` only during authorized execution. Its maintainer
`README.md` holds provenance and construction recipes; `grading/answer-key.md` holds the grading matrix.
Neither file reaches the actor. Keep `inputs/` and `grading/` separate. The distinct actor-visible
`inputs/base/README.md` is the neutral first-party fixture README; it contains no grading rubric.
Materialize only inputs plus actual composed workflow files into a new external scratch Git root.
Do not place the plan, answer key, prior outputs or reviewer narrative in the actor root or its Git
history. Preserve original fixture source bytes before adding new cases. All new `.ps1` files use
UTF-8 BOM. Fixture inputs are synthetic and must contain no secrets.

First recover the 15 **committed inputs** from the captured Git commit, not its generated working
tree. Record each path, Git blob ID, raw SHA-256 and byte length. Preserve raw bytes (no `git show |
Set-Content` text round trip). Reuse the repository's binary Git-read pattern or a binary-safe Git
archive export, then compare every extracted file to its Git blob. Retain a portable copy and
manifest in the new maintainer fixture so a later model does not need this user's temporary folder.
If recovery fails, record `CANNOT-EXAMINE` for the historical replay; the lead may reconstruct the
explicit contracts below as **new fixtures**, with new identities and no historical-equality claim.

Retain these original semantics rather than cleaning the subject up:

- `ops/promote-package.ps1`: check manifest, invoke unavailable external signing script, then copy
  the package. Steps and missing signing evidence are discoverable; successful real signing is not.
- `ops/complete-leased-item.ps1`: inspect the lease, exit 3 if it is not held, invoke an arbitrary
  ScriptBlock, inspect `$LASTEXITCODE`, then acknowledge. Do not describe the native-exit check as
  universal ScriptBlock success or certify external queue behavior. The oracle grades this exact
  source limitation; do not fix the synthetic application to make a generated claim true.
- `topology/storage.json`: write region `uk-south`, replica `uk-west`, manual promotion,
  `replicaAcceptsWrites: false`. These are declared configuration facts, not deployed guarantees.
- Existing `docs/wiki/release-ownership.md` and `.claude/skills/team-release/SKILL.md` are owner
  content. The skill is announcements-only; promotion is not a duplicate of that skill.

Add only the following mixed-domain cases to the recovered base; these additions form a **new**
fixture commit, not the original PK-2 input:

| Fixture surface | Exact source fact and purpose |
|---|---|
| `src/intake/TombstonePolicy.cs` | A single quiet predicate rejects an incoming record when `incomingTimestamp <= tombstoneTimestamp`. Equality is consequential and unique; no claim that three examples are required. |
| `src/intake/RetryPolicy.cs` and `config/retry.json` | Caller reads a helper/configured maximum; at base it accepts `attempt < maxAttempts`, with maximum 3. The quiet caller's derived boundary depends on the named helper/configuration. |
| `ui/admin/can-submit.ts`, `ui/self-service/can-submit.ts` | Admin permits an explicitly privileged bypass; self-service requires completed verification with no bypass. Both are scoped behaviors; no evidence authorizes a repo-global policy. |
| `generated/retry-reference.cs` | Ignored generated decoy claiming the opposite threshold. Its generated status is established by `.gitignore` and fixture README, not its filename alone. |
| R-only `docs/wiki/retry-boundary.md` | Existing owner-authored claim, `status: verified`, `last-verified: 2026-09-01`, naming caller/helper/configuration dependencies and an exact source-predicate recheck. Absent from D/C; freeze bytes before refresh. This synthetic old claim is a refresh input, not newly observed historical verification. |
| Existing `LEARNINGS.md`, discovery summary and INDEX | Add minimal valid consumer context, a pending summary marker and a scoped declined-recipe record unrelated to the required new promotion operation. Preserve existing owner text; sorted INDEX updates for genuinely new entries are allowed. |

The preparer must make the helper relationship explicit in actual source, not only comments or the
grading key. No package restore is needed to grade these source claims. If executable checks are
used, they execute the actual fixture predicates; a PowerShell reimplementation of C#/TypeScript
does not prove those languages' behavior. The lead and independent reviewer read the decisive source.

Create a **separate budget variant** with exactly 45 eligible first-party content files: the five
root consumer prerequisites `CLAUDE.md`, `Consumer.csproj`, `LEARNINGS.md`, `TECH_DEBT.md`,
`FRAMEWORK-CONTEXT.md`, plus eight files in each of five areas. Use these fixed area/operator/limit
tuples: intake/`-le`/7 (record age); delivery/`-lt`/20 (batch size); lease/`-eq`/1 (held token count);
storage/`-ge`/2 (available replicas); ui/`-ne`/0 (verified flag). In each area create `README.md`
(scope and units), `policy.json` (operator and limit), `entry.ps1` (integer input forwarded to
`rules/decision.ps1`), `rules/decision.ps1` (reads `../policy.json` and evaluates that operator),
`state.json` (area-specific state names), `exceptions.json` (one explicitly excluded state),
`routing.json` (that area's consumer), and `sample.json` (one value and its source-derived expected
decision). The only required dependency chain is entry -> decision -> policy: two added hops,
not three. No runtime correctness is inferred from these invented demonstration policies.
Do not add root README/wiki/INDEX files to this variant. Framework inventory, workflow files,
control metadata and report handoffs are additional, separately inventoried files. They still count
when their contents are read under the conservative B1 rule below. This deliberate boundary corpus
does not measure natural selection or enterprise coverage.

**Portable ignore control.** Store each fixture's ignore rules as inactive `gitignore.fixture` in
the authoring fixture and rename to `.gitignore` only in external materialization. Retain original
path mapping and raw hash in the manifest. This keeps the ignored generated decoy itself committed.
Before delivery compare the complete expected file list to `git ls-files`; use `git check-ignore`
to explain omissions. The materialized consumer decoy must be ignored there, while its source
fixture is tracked here. Never include an archived `.git` tree or generated PK-2 outputs in D.

**Per-call input manifest.** At P0 freeze a row for every file with stored path, materialized path,
SHA-256, byte length, provenance/classification and membership in D, C, R-changed, R-missing,
R-confirm, B or B-continue. Hash the exact prompt, entrypoint and handoff documents separately.
The sets are fixed as follows; dynamic output hashes are filled only after the preceding call and
before its dependent dispatch, without rewriting the upstream result:

| Set | Included / excluded inputs |
|---|---|
| D | Recovered committed inputs plus new raw source cases and required neutral consumer/workflow context. No retry wiki, generated capture output, discovery report or answer key. Existing release-ownership and announcements-only team-release documents remain; they do not state D1/D2's answers. |
| C | Exact D state plus its unmodified discovery report as labelled control material. No pre-seeded retry answer. Deduplicate against existing release ownership and announcement scope; neither is a promotion procedure. |
| R-changed | Clean D base plus C's eligible outputs, a canonical synthetic retry wiki and its INDEX entry, and the new maxAttempts=5 commit. If C created any overlapping retry claim, retain it in the C record but replace it in this separately labelled R fixture with the frozen canonical old claim; never leave conflicting duplicate baselines. This is controlled refresh evidence, not fully integrated D->C->R evidence. |
| R-missing | Separate alternative copy of the same R pre-change baseline with the helper removed in its own commit, outside R-changed's Git history. During the R call the supervisor grants only this second synthetic directory via `--add-dir`, after checking it holds no key/prior verdict. Treat it as a separately labelled proposal case; apply no changes there. |
| R-confirm | Exact R-changed post-proposal state, its unmodified proposed diff and an explicit synthetic-owner approval for only the reviewed path/diff hash. No approval for R-missing. |
| B / B-continue | The fixed budget corpus plus workflow/control files. B-continue alone receives B's exact report. No D/C/R outputs or answer key. |

The R-only old claim is necessary to test refresh; the no-answer-leak rule prohibits generated or
scorer-authored target answers in D, not ordinary raw source/configuration truth or the old claim in R.
There is **no `docs/warehouse-map.md`** in these fixtures. Storage configuration remains general
topology evidence; its name alone does not make it a warehouse fact. Future execution may trigger
the wiki check's historic-date advisory; a WARN is reported, not silently converted to a semantic MISS.

**Component prerequisites must exist before dispatch.** Add a populated synthetic `CLAUDE.md`
(no `BOOTSTRAP_PENDING`), a minimal first-party `.csproj` marker for the selected .NET profile,
and `TECH_DEBT.md` with an empty `## Dismissed proposals` section. Supply a root
`framework-ownership.json` with `"schema-version": 1` and an ordinally sorted `paths` array of
`{ "path": "relative/path", "ownership": "classification" }` rows for every materialized path.
Actual workflow/agent/remember-for-team files and the inventory itself are
`framework-owned/overwritten`; first-party application/configuration/evidence and owner documents
are `consumer-owned/protected`. The copied wiki template is framework content. Treat this as a
synthetic component inventory, not a real installer result. Include synthetic
`framework-retirements.json` as `{ "schema-version": 1, "retirements": [] }`, classified as framework
content. Freeze and review the complete inventory with the fixture. No fixture inference may use
framework-owned text as first-party evidence. Count first-party prerequisites within the 45-file
budget corpus; workflow/control files remain separately enumerated.

The lead supplies an observed base/head revision and path-level change report in an explicitly
labelled control document, without grading answers. It is a prepared Git observation, not model
execution evidence. Full profile selection, command inventory, onboarding, hazard/intent interviews,
installer/adopt and unrelated bootstrap phases are excluded from this component observation.
The scoped worker and capture/merge ownership prerequisites above are **not** waived.

**One allowed-delta list governs both the C prompt and scorer:** new eligible wiki drafts; a new
absent `.claude/skills/<slug>/SKILL.md` with exactly one new absent linked reference at
`.claude/skills/<slug>/references/project-pattern.md`, linked from the skill as
`[Project pattern](./references/project-pattern.md)`; new absent `docs/discovery-notes.md` for incomplete
exploration; correctly sorted new INDEX entries without rewriting existing entries; and replacement
of only `<!-- REPOSITORY_KNOWLEDGE_DISCOVERY_PENDING -->` in the named FRAMEWORK-CONTEXT section
with at most 12 summary lines. Freeze the marker's exact range and compare all surrounding bytes.
Every other pre-existing file must be byte-identical. Missing markers or existing discovery notes
are owner content, not implicit overwrite permission. New-file authority is distinct from existing
content confirmation; R-confirm has only its individually approved diff.

## 6. Freeze valid, invalid and unavailable worlds before model work

Keep the following grading key outside the actor root. Grade semantic content with cited source
and output locations; do not use keyword presence or an exact preferred prose answer as the oracle.
Several scoped facts may share one document. An index link to an operation is not a duplicate recipe.

| ID | Constructible passing observation | Targeted failing control / unavailable distinction |
|---|---|---|
| D1 quiet fact | Discovery states the tombstone equality boundary with exact source and limited scope. | Change a copy of its report to strict `<`; reviewer must reject that claim against the unchanged predicate. A fact omitted from a valid bounded report is a coverage miss, not fabricated knowledge. |
| D2 helper + scopes | Read caller and decisive helper/config; state configured retry boundary; keep the two UI policies separate. | Replace helper evidence with filename-only citation or globalize the admin bypass. An unread helper cannot support a settled derived claim. |
| D3 unavailable + decoy | External signing remains unavailable; generated decoy supplies no authority; lease native-exit limitation is explicit. | Claim signing was verified or universal ScriptBlock success. Missing external source is not an invalid configuration or an observed access-denied error. |
| C1 operation capture | When an operation draft is justified and created, it is one candidate skill plus a linked focused reference; evidence/uncertainty/refresh survive in those files. Apply the predeclared destination alternatives below. | Delete only the Markdown link while retaining the reference file; add a second wiki procedure with the same scope/steps; both must be detected. Distinct topology facts remain legitimate wiki material. |
| C2 ownership + truth | Exact allowed-delta list holds; other owner bytes unchanged. Grade required metadata only for artifact types actually created under the predeclared alternative. A created wiki has `name`, `description`, `type`, `scope`, `status`, `last-verified`, provenance/refresh/draft-status body fields and matching sorted INDEX entry. A created skill has `name`, `description`, `origin: discovered`, the exact linked reference and scope/uncertainty/refresh/draft-status body. Absence of an artifact type the alternative did not create is neither C2 PASS nor MISS. | Alter one owner byte outside allowed ranges; mark a never-checked wiki claim `verified` with `never`; claim an external check ran. Do not demand skill-only `origin` on a wiki or skill metadata when the defensible alternative created no skill. |
| R1 quiet dependency | Change `maxAttempts` from 3 to 5 in a new Git commit without touching caller/wiki. Rebootstrap re-reads decisive evidence and proposes the exact affected claim diff. | A path-existence-only refresh or silently unchanged verified boundary is a miss. Mere mention of changed files is insufficient. |
| R2 confirmed ownership | Before confirmation owner hashes stay unchanged. After the fixture owner approves the exact reviewed diff, only that change applies, with truthful result/date. | Premature edit fails. A missing/deleted helper variant instead requires unresolved/downgrade proposal preserving the historic date, not a new verification date. |
| B1 finite pass | Conservatively count all materialized repository files whose contents were accessed, including workflow/control/report files but excluding `.git/**` internals and the external sentinel; stay within 40, report partial coverage and unread areas. Also report the first-party subset separately. Any `.git/**` access is separately reported and excluded from semantic scoring. | A 41st distinct counted content access or an exhaustive claim fails under this frozen counting interpretation; report any source ambiguity rather than claiming a universal rule. If the boundary was not reached, exhaustion is NOT EXERCISED. |
| B2 continuation | Next bounded pass reads previously unread sources, retains earlier findings and distinguishes new reads from necessary rechecks. | Repeating only already-read areas with an invented progress claim fails. Changed counts without observed reads cannot prove progress. |

**Predeclared destination alternatives.** Bootstrap 3a-bis permits an operation with "grounded
steps, integration points, and verification" while requiring "unresolved steps" in its draft.
Promotion may therefore be a skill/reference describing observed manifest/sign/copy order with
external signing unresolved; it is not an instance of the eight named application-operation skills.
A narrowly scoped wiki fact about that sequence's boundary, with explicit abstention from a usable
operation because verification is unavailable, is defensible but leaves the skill-link C1 case
NOT EXERCISED; it is not a C1 PASS or automatic routing MISS. A wiki promotion *procedure* and a
skill duplicating it fail. Lease may be a precisely scoped native-exit gotcha in the wiki or a
conditional operation skill/reference, without universal ScriptBlock-success or queue claims.
Freeze this alternative set before output; never demand a preferred artifact to manufacture failure.

**Full report-shape checking applies to actual shared-A8 worker outputs:** D, B, B-continue and
the discovery portion of R. C and R-confirm are parent capture/application summaries; check their
evidence truth and promised rechecks, but do not require the worker skeleton from those summaries.
Copy the actual shipped
worker output skeleton into the hidden grading key: Inventory with per-area classification;
Knowledge findings with Kind, Claim/operation, Selection reason, Scope, Evidence, Status,
Counterevidence/exceptions, Dependencies and Meaningful recheck; Coverage and continuation with
Actual content reads (count and paths), Dependency hops, Unresolved/inaccessible, and Next bounded
continuation. Compare reported read sets/counts to matched successful content results, including
known startup delivery. Derive dependency hops from the frozen source graph and the actor's named
seeds; any settled dependency outside two added hops, invented read, incorrect count or unsupported
coverage assertion is an explicit report-fidelity MISS. A missing required report field is a
report-fidelity MISS when the trace is available; a missing/ambiguous trace is CANNOT-EXAMINE for
the affected measurement, not a confident product diagnosis. The conservative total-file basis is stated in B/B-continue prompts so the
actor and scorer do not silently use different interpretations of the unqualified shipped limit.

Calibrate each used observer against its valid and targeted-invalid sample before accepting actor
results. For hashes, mutate a copied owner file then restore exact bytes; for semantic grading,
the reviewer must explain why the altered claim is wrong. For the content-read observer, exercise
a known read, a filename-only inventory, an unsuccessful read, and a command returning several
files' contents. Match tool requests to successful results, inspect truncation/errors, and deduplicate
canonical in-root paths. Missing trace, unknown shell expansion or truncated decisive evidence is
`CANNOT-EXAMINE`, never zero reads or success. Count content returned by Grep and PowerShell too.
Record workflow/control-file accesses separately and include them in the B1 total; do not hide
first-party docs/config reads there.
Git internals under `.git/**` and the external sentinel are outside the counted repository-content
corpus. Prohibit deliberate `.git/**` reads in B/B-continue; if one still occurs, report it
separately and exclude it from semantic scoring rather than silently changing the 40-file basis.
Startup-delivered first-party content must also be attributed and counted. Safe mode is intended
to disable automatic project context, but an observed tool menu alone does not prove its absence.
Record the startup configuration and any known injected files. Unknown eligible startup content
precludes a total-content-budget PASS; report only the explicit-tool-read result and the gap.
For B/B-continue expose only Read and Glob: this removes opaque shell/Grep enumeration from the
specific count experiment. In D/C/R, where Grep is available, unobservable scan inputs prevent a
total-budget claim but do not erase independently evidenced semantic results.

Synthetic bad-output controls validate the scorer, **not** model behavior and not red evidence of
a current product defect. A product correction requires a retained current-carrier miss or direct
contradiction, then a separately reported corrected-carrier observation. Source-test green cannot
turn a missing semantic rerun into a behavioral pass.

## 7. Execution sequence for the delivery model

### P0 — freeze and preflight (no semantic claim yet)

1. Confirm HEAD/source hashes, no overlapping edits, supported native host paths, and current
   scope. Read the source map. If the source baseline changed, list only relevant deltas and have
   the lead decide whether the unchanged contract still applies before freezing new hashes.
2. Package fixtures and the outside-the-root answer key. Record base/changed/deleted-helper Git
   commits, owner hashes and intended writes. Independently critique the actual fixtures and
   scorer controls before actor dispatch; this plan review is not fixture acceptance.
3. Check the installed Claude version/help and auth readiness without printing credentials.
   Use the concrete recipe below. Actor cwd is its synthetic external root. Do not supply the
   authoring checkout or answer-key directory via `--add-dir`. The actor has no shell tool in
   this source-semantics observation; prepared Git metadata comes from the lead. This is a
   deliberately limited tool surface, not full-host or command-execution acceptance.
4. Freeze the six requests below and the exact resolved model/configuration. Fold the read-stream
   calibration into the first capped call using a separate harmless calibration file; its content
   is not grading evidence. If configuration/cap/trace readiness fails, stop without paid retries.

The first capped D request begins with a labelled launcher calibration: read one harmless in-root
control file, list its name without contents, and attempt to read a specifically named harmless
sentinel in a sibling scratch directory outside every granted root. Observe matching successes and
outside-root denial, not the actor's description. Assert the init tool set is exactly the intended
set and no tool event uses another tool; require recorded model identity and terminal usage. If
any control is unavailable or contradicts the restriction, D's semantic rows are CANNOT-EXAMINE for
this route, even if the actor continued; stop C and later calls. Save the entire failed attempt.
Known injected calibration text is control material; any actual file content returned still counts
in total reads. Each write-enabled call (C and R-confirm) additionally creates two harmless new
control files at predeclared absent paths: `calibration/write-route.md` and
`.claude/skills/calibration-write-route/SKILL.md`. The latter must exercise the same path class as
the intended skill output: restricted mode can reserve tool-configuration writes for a person or
permission handler even when ordinary Markdown writes work. Explicitly allow these two control
deltas and compare their hashes separately from product output; neither is a capture finding.
Require both observed write successes before grading product changes. A denied/unavailable control
makes that call's write-route-dependent rows CANNOT-EXAMINE (C1/C2 for C), not a capture/application
MISS. Retain any partial output, stop dependent write work, and do not widen permissions or retry
outside the existing authority/call allowance. The R additional root is
the sole `--add-dir` exception and must be in the frozen manifest; the outside sentinel is never in it.

**Concrete invocation/capture recipe (PS7 supervisor, future execution only).** The lead creates
the prompt with `apply_patch`, using a distinct external run directory for each attempt. Use
`Read,Glob,Grep` for D/R, `Read,Glob,Grep,Write,Edit` for C/R-confirm, and `Read,Glob` for B/B-continue.
The prompt names the allowed-delta list; before/after byte comparison enforces its scoring boundary.
The tool menu and restricted cwd do not make that narrower per-path permission transactional.
`--restricted` confines file tools to the fixture; safe mode disables project customization. Record
these limitations. No shell, network tool, Agent tool, permission bypass or permission prompt is
exposed. If installed flags conflict or required permitted writes are denied, classify the launch
as unavailable and revise its recipe; do not widen tools while the experiment is running.

```powershell
# Assign these from the frozen case manifest; never use an authoring or home root as actor cwd.
$actorExe = Join-Path $env:USERPROFILE '.local/bin/claude.exe'
if (-not (Test-Path -LiteralPath $actorExe -PathType Leaf)) { throw 'Claude executable is unavailable; stop and resolve the actor route in P0.' }
# Record the resolved executable/version in local evidence; do not commit an account-qualified home path.
$actorRoot = '<absolute external synthetic case root>'
$actorPrompt = '<absolute UTF-8 prompt file>'
$actorOut = '<new external attempt directory>/stdout.jsonl'
$actorErr = '<new external attempt directory>/stderr.txt'
$actorTools = 'Read,Glob,Grep' # replace only from the case table above
$actorDiagnosticDeadline = [DateTime]::Parse('<recorded diagnostic-start UTC>').ToUniversalTime().AddMinutes(180)
$actorStageDeadline = [DateTime]::Parse('<recorded actor-stage-start UTC>').ToUniversalTime().AddMinutes(80)
$actorRemainingSeconds = [int][math]::Floor([math]::Min(600, [math]::Min(
  ($actorDiagnosticDeadline - [DateTime]::UtcNow).TotalSeconds,
  ($actorStageDeadline - [DateTime]::UtcNow).TotalSeconds)))
if ($actorRemainingSeconds -le 0) { throw 'No observation allowance remains.' }
$actorArgs = @('--print','--model','sonnet','--effort','medium',
  '--output-format','stream-json','--verbose','--safe-mode','--restricted',
  '--strict-mcp-config','--no-session-persistence','--disable-slash-commands',
  '--permission-mode','dontAsk','--tools',$actorTools,'--allowedTools',$actorTools,
  '--max-budget-usd','1')
$actorAdditionalRoot = '' # R only: exact frozen R-missing root; empty for every other case
if ($actorAdditionalRoot) {
    if ($actorAdditionalRoot.Contains('"')) { throw 'Unsupported quote in fixture path.' }
    $actorArgs += @('--add-dir', ('"' + $actorAdditionalRoot + '"'))
}
if ((Test-Path -LiteralPath $actorOut) -or (Test-Path -LiteralPath $actorErr)) {
    throw 'Use new log paths; do not overwrite an earlier attempt.'
}
$actorProcess = Start-Process -FilePath $actorExe -ArgumentList $actorArgs -WorkingDirectory $actorRoot `
  -RedirectStandardInput $actorPrompt -RedirectStandardOutput $actorOut -RedirectStandardError $actorErr `
  -WindowStyle Hidden -PassThru
$actorDeadline = [DateTime]::UtcNow.AddSeconds($actorRemainingSeconds)
while (-not $actorProcess.HasExited -and [DateTime]::UtcNow -lt $actorDeadline) {
    [void]$actorProcess.WaitForExit(1000)
    $actorProcess.Refresh()
    # Supervisor returns control/progress at least every 60 seconds while this loop runs.
}
$actorTimedOut = -not $actorProcess.HasExited
if ($actorTimedOut) { $actorProcess.Kill($true); [void]$actorProcess.WaitForExit(10000) }
$actorProcess.Refresh()
$actorExit = if ($actorProcess.HasExited) { $actorProcess.ExitCode } else { $null }
[pscustomobject]@{ Exit=$actorExit; TimedOut=$actorTimedOut; Stdout=$actorOut; Stderr=$actorErr }
```

Use a supervised asynchronous terminal session for the loop, continuing user updates while it runs.
Log native exit and timeout separately. Retain both files even when partial, malformed, empty or
missing a terminal result. The B-41 timeout branch currently empties its transcript: **do not copy
that branch**. Parse the actual init/result events for identity and usage after the process ends;
missing result/usage is UNKNOWN and consumes the attempted-call allowance. The CLI's configured USD
limit is not an invoice guarantee. Do not assert enforcement solely because the flag was accepted.

### P1 — six primary calls, in this order

| Call | Inputs, neutral task and permitted writes | Inspect before advancing |
|---|---|---|
| D | D manifest + shipped worker. Request: `You are the parent-dispatched worker. Read .claude/agents/bootstrap-pass.md and .claude/commands/bootstrap.md. Execute only shared A8's discovery component against this repository and return its report; do not start full bootstrap.` Prepend only the launcher controls above. Read-only result in stdout. | Score D1-D3 and source access. Never inject missed answers into its report. |
| C | C manifest + actual D report. Request: `Read .claude/commands/bootstrap.md Phase 3a-bis and .claude/skills/remember-for-team/SKILL.md. As the parent, capture eligible findings from this discovery report using only that capture component. Preserve owner content and report unresolved work.` Supply exact allowed-delta list. | Score C1-C2 from bytes. Missing D prerequisites yield NOT EXERCISED, not a scorer-authored replacement finding. |
| R | R-changed and separately named R-missing manifests. Request: `Read .claude/commands/rebootstrap.md Shared A8 and Phase 3/3a-discovery, and the referenced shared A8 in .claude/commands/bootstrap.md. For each labelled snapshot, refresh knowledge against its supplied base/head change record. Present existing-content diffs for owner confirmation; apply none. Execute only these components.` | Score R1/R2 per snapshot; retain exact proposals. No content from one snapshot may corroborate the other's missing source. |
| R-confirm | R-confirm manifest + exact approved diff. Request: `Read .claude/commands/rebootstrap.md Phase 3 and .claude/skills/remember-for-team/SKILL.md. Apply only this approved change and report the semantic source recheck and unresolved evidence.` | Compare every owner file and approved diff; never approve an unsupported or absent proposal to manufacture a pass. |
| B | Budget manifest. Request: `As parent-dispatched worker, read .claude/agents/bootstrap-pass.md and shared A8 in .claude/commands/bootstrap.md. Execute only this component. Inventory the repository, then inspect eligible first-party contents in any order until 40 distinct repository content files have been read, counting these workflow/control files too but excluding and not deliberately reading .git/** internals. Report partial coverage and stop.` | Score total and first-party reads, report fidelity and B1. This is deliberate boundary acceptance. |
| B-continue | Budget manifest + exact B report. Request: `Read .claude/agents/bootstrap-pass.md and shared A8 in .claude/commands/bootstrap.md. Continue only that component in one further pass; count all repository content files including workflow/report files toward 40. Prioritize previously unread areas and retain prior findings.` | Score B2; independently reconstruct old/new read sets and declared seeds/hops. |

Every call starts a new context, without prior implementation/review narrative or the grading key.
Intentional report handoffs D->C and B->B-continue remain disclosed. R-confirm receives only the
specific approved output, not blanket edit authority. Do not run complete bootstrap/adopt as an
unannounced substitute for these components. Record inherited host/system context and its limits.

A primary miss is retained even if later corrected. Two optional corrective calls are the total
allowance, not two per case. One may be used for an isolated capture observation with a separately
labelled source-grounded input if D prevented C from being exercised; it must not be called an
integrated pass or overwrite D/C's original disposition. Stop after the available calls/time.
Failure to locate/read the explicitly named entrypoint is CANNOT-EXAMINE for dispatch, scoring no
semantic row. Component requests deliberately do not invoke slash commands or full preflight.
The lead verifies no adoption-pending marker or foreign AI carriers exist in the synthetic roots;
the full bootstrap's classifier/command-inventory/owner-interview prerequisites are not exercised
or claimed. No actor runs the worker with its complete shipped PowerShell tool menu; record that
restricted-tool limitation alongside monorepo-only and Claude-only scope.

### P2 — classify findings and make the smallest supported correction

For each row, record `PASS`, `MISS/FAIL`, `NOT EXERCISED` or `CANNOT-EXAMINE`, with actual evidence.
Separate source fact, source-test mechanics, authoring-model behavior and unrun target-host/value
evidence. A stopped or absent call is not failure of its subject.

If a defect reproduces, freeze its failed input/output and name the exact contradictory or
insufficient carrier. Propose one minimal correction within section 4 and obtain nonimplementer
critique before editing. Edit only `src/` and directly relevant existing tests, review all siblings,
compose dists, then use any remaining corrective calls on the affected cases. Do not edit fixture
facts, delete difficult cases, relax the rubric, tune prompts or repeat until success. If a fix
requires a new mechanism, a different task or more observations, stop and file the concrete debt.
An installer/ownership defect must be isolated to its real script with a focused before/after case;
these model observations alone do not authorize a lifecycle rewrite.

### P3 — verification and delivery

Evidence-only work runs focused meta/document checks and commits its report/fixture/provenance.
No product version bump follows merely from observations. For any shipped correction, write all
four changelog heads and use the existing release process with independent implementation review,
release-specific red/clean evidence and normal CI. Planning reviewers do not substitute for that
later implementation review. Keep B-222/B-223 PARTIALLY DONE wherever their full acceptance remains
unmet; never close B-224/B-225/B-42 or claim stack/host parity from this monorepo observation.

Use existing checks, with cwd at the authoring root and no concurrent writer:

```powershell
$repoForAcceptance = (Get-Location).Path
$ps7ForAcceptance = 'C:\Program Files\PowerShell\7\pwsh.exe'
$ps51ForAcceptance = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
$env:PATH = 'C:\Windows\System32;C:\Windows;C:\Windows\System32\WindowsPowerShell\v1.0;' + $env:PATH
foreach ($acceptanceHost in @($ps7ForAcceptance, $ps51ForAcceptance)) {
    & $acceptanceHost -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoForAcceptance '.claude/hooks/tests/DocClaims.Tests.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'DocClaims did not pass; inspect its actual output.' }
    foreach ($acceptanceStack in @('dotnet','angular','monorepo')) {
        & $acceptanceHost -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoForAcceptance "dist/$acceptanceStack/tests/hooks/WikiCheck.Tests.ps1")
        if ($LASTEXITCODE -ne 0) { throw "WikiCheck did not pass for $acceptanceStack." }
    }
}
```

These existing suites prove their named mechanical boundaries, not the semantic matrix. Record
nonzero comparable case counts and actual executable/version. For the relevant DocClaims mutation,
copy the complete `dist/dotnet/` tree into one external scratch distribution root. `-DistRoot`
takes that single distribution root, not a parent containing three dists; the harness labels it
`dotnet`, so using the actual .NET copy also keeps evidence attribution correct. First observe a
clean baseline with `-DistRoot <copied-dotnet-root>` under each native host. Then remove only the
exact required sentence
`Read at most 40 distinct content files and follow at most two additional dependency hops per selected seed.`
from `<copied-dotnet-root>/.claude/commands/bootstrap.md` (not the agent with a similar name).
Run DocClaims with the same `-DistRoot <copied-dotnet-root>` under both native hosts and observe
the named repository-knowledge carrier omission, not a missing-file/setup failure; restore exact
bytes and observe clean. This mutation is .NET carrier evidence only; the ordinary commands above
still check all three dists. Do not combine `-DistRoot` and `-RedTest`: the generic registry red
mode exits before inspecting a distribution and is not discovery-carrier evidence.
Run at least one focused suite through CP437 under both hosts, including the relevant red/clean
case; this obligation applies even when no check changed. The existing `DEVELOPING.md` recipe
clears PSModulePath when crossing cmd->PS5.1; use it
instead of treating a launcher failure as product evidence. Do not pipe gate commands into filters.
Run UpdateDelivery/InstallerConvergence only if preservation surfaces or corresponding assertions
changed or a new concern warrants them; existing ownership evidence need not be repeated wholesale.
The release wrapper owns full gates, rebuilds, footprint and CI; never hand-edit `dist/`.

Before dispatch and after C/R-confirm, invoke the shipped monorepo `scripts/wiki-check.ps1 -Root
<materialized-fixture>` from each native host and capture exit/output. Existing WikiCheck fixtures
already exercise invalid `verified`+`never` and sorting. Do not relabel a failing schema/index check
as a semantic miss: retain separate mechanical and semantic dispositions. Old-date/body warnings
remain disclosed advisories. The budget-only fixture has no wiki and is not a subject of this check.

The resulting report must include baseline and final hashes; fixture origin and changes; exact
prompt/entrypoint/model/host identities; per-call outcome, elapsed time and usage including aborts;
unmodified outputs and relevant matched events; per-case semantic source/output citations; owner
before/after hashes; observer valid/invalid evidence; every unrun case; and a repair/no-repair
decision. Retain a portable synthetic input/concise-output packet; keep bulky raw streams outside
Git with stable manifest/hash/location, and explicitly record any unavailable raw evidence.
A PASS means no reproduced defect for this specific case, fixture size and restricted authoring
tool menu. It does not establish that the carrier caused the behavior or improves a bare model.
Do not use spare calls for an unplanned comparison with retired instructions; that would change
the question and still would not guarantee a failing model outcome. Record this attribution limit
in the backlog alongside unrun stack and target-host coverage.

Update backlog pointers and append the delivery RCA: why existing gates did not catch the class,
which sibling carriers were checked, and what remains exposed. Commit to master and push through
`.claude/scripts/push-and-check.ps1`; wait for the watched CI result. No uncommitted handoff.

## 8. Delivery-model checklist

- [x] Execution authorization includes the proposed actor route, eight-call/USD8 and time limits.
- [x] Baseline, source map and actual fixture/observer controls are frozen and independently read.
- [x] Original/reconstructed inputs are correctly labelled; hidden scoring material stays outside actor context.
- [x] D, C, R, R-confirm, B and B-continue each have an honest disposition; no success-only selection.
- [ ] Refresh confirmation is exercised without granting blanket authority; exact owner bytes are compared. The owner bytes were compared and stayed unchanged, but R-confirm is CANNOT-EXAMINE because the required skill-path write control was denied.
- [x] No product fix was made: the retained misses contradict obligations already explicit in the current carrier, so there is no supported corrective delta to review or reconcile.
- [x] Results distinguish authoring behavior from static mechanics and unrun Copilot/value/stack coverage.
- [ ] Report, reusable synthetic evidence, backlog/RCA and required review/release records are committed and CI is observed.

## 9. Design review disposition

Fresh-context Codex and separate blind-first Opus reviews accepted the bounded premise and
requested corrections. Their initial findings, corrective delta checks, root source adjudication,
immutable plan revisions and hashes are retained in
`2026-09-08-b222-b223-adversarial-reviews.md`. A final delta check is adjudication, not an additional
independent review. No requested blocker is intentionally deferred into implementation.
Plan acceptance does not mean the fixtures, observers, actor route or product have passed execution.

## 10. Execution disposition

Execution completed on 2026-09-08 with six Sonnet calls, USD2.4739664 reported cost and no call past
the shared 80-minute actor-stage deadline. The complete scored result and exact stream/report hashes
are in `meta/repository-knowledge-semantic-acceptance.md`.

Core observations: D1 and the required D2 target passed while D3 and report fidelity missed; the C
skill-path control was unavailable, making C1/C2 and unrun R-confirm CANNOT-EXAMINE; R1 and owner
preapproval integrity passed while the missing-helper report and report fidelity missed; B1 and B2
passed their read-boundary/continuation targets while retaining eligibility and hop-count errors.
Independent review rejected and corrected invalid D/R fixture states before relying on their
subjects. No product correction followed because the current carrier already states the missed
requirements. B-222/B-223 remain partial under the scope limits named in the result record.
