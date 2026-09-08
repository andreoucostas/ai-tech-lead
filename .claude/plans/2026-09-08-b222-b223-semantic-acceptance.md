# B-222/B-223: bounded discovery, capture and refresh acceptance

**Date:** 2026-09-08. **Source baseline:** v0.86.0,
`c9e25953e2cdd04c1bc780a5a95ddab5c806b494`.
**Status:** revised after the fresh-context review; pending independent Opus review. This document plans execution;
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
- Native PS7, PS5.1 and Claude CLI resolve here. Claude reports `2.1.260`; its help exposes
  `--safe-mode`, `--tools`, `--strict-mcp-config`, `--no-session-persistence`, stream JSON and a USD cap.
  A future actor invocation/model/usage route has **not** been calibrated by these help checks.

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
with `--max-budget-usd 1` each (USD8 aggregate CLI accounting ceiling). Six primary calls are specified
below; at most two additional calls may rerun an affected case after one justified source correction
or perform the separately labelled isolated capture case defined in P1.
Calibration, aborted calls and launcher failures consume this allowance. This is a proposed cap,
not a predicted price or a claim that CLI accounting equals the invoice. Record observed usage and
unknown usage. No model upgrade, extra calls or substitute study follows exhaustion. Required
product-release verification is separate from this diagnostic allowance and cannot be waived to fit.

If the actor cannot expose matched tool-use/tool-result events, resolved identity, usage and a
working configured cap, stop that observation as `CANNOT-EXAMINE`. Do not build another general
harness to overcome the limitation. A changed route or budget needs a revised concrete proposal.
No external application, network isolation engineering, new installation, Copilot call, production
query, private source export or participant contact is part of this plan.

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
`meta/eval-fixtures/repository-knowledge-acceptance/` only during authorized execution. Its `README.md`
holds provenance, construction recipes and the grading matrix. Keep `inputs/` and `grading/` separate.
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
| `docs/wiki/retry-boundary.md` | Existing owner-authored claim, `status: verified`, `last-verified: 2026-09-01`, naming caller/helper/configuration dependencies and an exact source-predicate recheck. Freeze bytes before any refresh. |
| Existing `LEARNINGS.md`, discovery summary and INDEX | Add minimal valid consumer context, a pending summary marker and a scoped declined-recipe record unrelated to the required new promotion operation. Preserve existing owner text; sorted INDEX updates for genuinely new entries are allowed. |

The preparer must make the helper relationship explicit in actual source, not only comments or the
grading key. No package restore is needed to grade these source claims. If executable checks are
used, they execute the actual fixture predicates; a PowerShell reimplementation of C#/TypeScript
does not prove those languages' behavior. The lead and independent reviewer read the decisive source.

Create a **separate budget variant** containing exactly 45 distinct eligible first-party content
files, including consumer context and evidence files. Use five small, meaningful areas with nine
files each and local dependency chains, each no deeper than two added hops. Do not fill it with 45
copies of one fact. Keep generated/control/answer files outside that corpus and publish the counted
manifest to the scorer. This variant tests a deliberate boundary request, not natural task selection.

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
absent skill with its new absent linked reference; new absent `docs/discovery-notes.md` for incomplete
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
| C1 operation capture | Grounded promotion operation becomes one candidate skill plus a linked focused reference; evidence/uncertainty/refresh survive in those files. | Delete only the Markdown link while retaining the reference file; add a second wiki procedure with the same scope/steps; both must be detected. Distinct topology facts remain legitimate wiki material. |
| C2 ownership + truth | Exact allowed-delta list above holds, including INDEX insertion and only the pending summary marker; other owner bytes unchanged; draft status and `origin: discovered` retained; dates match actual verification. | Alter one owner byte outside allowed ranges; mark a never-checked claim `verified` with `never`; claim an external check ran. Each is separately detectable. |
| R1 quiet dependency | Change `maxAttempts` from 3 to 5 in a new Git commit without touching caller/wiki. Rebootstrap re-reads decisive evidence and proposes the exact affected claim diff. | A path-existence-only refresh or silently unchanged verified boundary is a miss. Mere mention of changed files is insufficient. |
| R2 confirmed ownership | Before confirmation owner hashes stay unchanged. After the fixture owner approves the exact reviewed diff, only that change applies, with truthful result/date. | Premature edit fails. A missing/deleted helper variant instead requires unresolved/downgrade proposal preserving the historic date, not a new verification date. |
| B1 finite pass | Observed content accesses stay within 40 distinct first-party files, report is partial, unread areas remain explicit. | A 41st distinct access or an exhaustive claim fails; if the boundary was not reached, exhaustion is `NOT EXERCISED`, not passed. |
| B2 continuation | Next bounded pass reads previously unread sources, retains earlier findings and distinguishes new reads from necessary rechecks. | Repeating only already-read areas with an invented progress claim fails. Changed counts without observed reads cannot prove progress. |

Calibrate each used observer against its valid and targeted-invalid sample before accepting actor
results. For hashes, mutate a copied owner file then restore exact bytes; for semantic grading,
the reviewer must explain why the altered claim is wrong. For the content-read observer, exercise
a known read, a filename-only inventory, an unsuccessful read, and a command returning several
files' contents. Match tool requests to successful results, inspect truncation/errors, and deduplicate
canonical in-root paths. Missing trace, unknown shell expansion or truncated decisive evidence is
`CANNOT-EXAMINE`, never zero reads or success. Count content returned by Grep and PowerShell too.
Record workflow/control-file accesses separately; do not hide first-party docs/config reads there.
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
$actorExe = 'C:\Users\Costas\.local\bin\claude.exe'
$actorRoot = '<absolute external synthetic case root>'
$actorPrompt = '<absolute UTF-8 prompt file>'
$actorOut = '<new external attempt directory>/stdout.jsonl'
$actorErr = '<new external attempt directory>/stderr.txt'
$actorTools = 'Read,Glob,Grep' # replace only from the case table above
$actorRemainingSeconds = 600 # min(600, remaining 180-minute diagnostic allowance)
$actorArgs = @('--print','--model','sonnet','--effort','medium',
  '--output-format','stream-json','--verbose','--safe-mode','--restricted',
  '--strict-mcp-config','--no-session-persistence','--disable-slash-commands',
  '--permission-mode','dontAsk','--tools',$actorTools,'--allowedTools',$actorTools,
  '--max-budget-usd','1')
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
| D | New base fixture + shipped monorepo worker and bootstrap entrypoint. Request: `Run shared A8 for this repository. Discover grounded repository knowledge across its areas and return the pass report.` Read-only; result remains in captured stdout. | Score D1-D3 and actual source access. Do not inject missed answers into the report. |
| C | Fresh context, identical base inputs, actual D report, shipped bootstrap Phase 3a-bis and remember-for-team. Request: `Capture eligible findings from this discovery report using the repository-knowledge capture phase. Preserve existing owner content and report unresolved work.` Supply section 5's exact allowed-delta list, including a new absent discovery note and only the pending summary marker. | Score C1-C2 from actual bytes. If D omitted an operation/fact needed for these cases, mark the corresponding integrated case NOT EXERCISED; do not substitute a scorer-authored finding. |
| R | Fresh context on the changed-helper fixture with pre-existing grounded retry wiki and C outputs. Request: `Refresh repository knowledge against the changes since the recorded baseline using shared A8 and rebootstrap's discovery/merge phases. Present changes requiring owner confirmation.` No existing owner-file changes authorized yet. | Score R1 and R2 pre-confirmation; retain exact diff. Missing-helper branch is supplied as a second clearly identified snapshot for an unresolved proposal only. |
| R-confirm | Fresh context on an exact copy of R's output state plus its reviewed diff. The fixture owner explicitly approves only the supported retry-claim diff by path and SHA-256. Request: `Apply only this approved change and report the semantic recheck and any unresolved evidence.` | Compare every owner file; verify approved diff, actual source read and truthful date. Do not approve an unsupported or absent proposal to obtain a passing run. |
| B | Fresh budget fixture + actual discovery entrypoint. Request: `Inventory the repository, then inspect each eligible first-party content file in any order until the discovery pass content-file limit is reached. Report partial coverage and stop at that limit.` Read-only. | Score B1 from stream; natural discovery efficacy is not being tested by this deliberately explicit boundary request. |
| B-continue | Fresh context with unchanged budget fixture and B's exact report. Request: `Continue the previous discovery in one further pass under the same limit. Prioritize the areas previously left unread and retain prior findings.` Read-only. | Score B2; independently reconstruct old/new read sets. |

Every call starts a new context, without prior implementation/review narrative or the grading key.
Intentional report handoffs D->C and B->B-continue remain disclosed. R-confirm receives only the
specific approved output, not blanket edit authority. Do not run complete bootstrap/adopt as an
unannounced substitute for these components. Record inherited host/system context and its limits.

A primary miss is retained even if later corrected. Two optional corrective calls are the total
allowance, not two per case. One may be used for an isolated capture observation with a separately
labelled source-grounded input if D prevented C from being exercised; it must not be called an
integrated pass or overwrite D/C's original disposition. Stop after the available calls/time.

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
nonzero comparable case counts and actual executable/version. For a changed check, observe its
release-specific targeted red and restored green directly in both hosts and at least one hostile
code page. The existing `DEVELOPING.md` recipe clears PSModulePath when crossing cmd->PS5.1; use it
instead of treating a launcher failure as product evidence. Do not pipe gate commands into filters.
Run UpdateDelivery/InstallerConvergence only if preservation surfaces or corresponding assertions
changed or a new concern warrants them; existing ownership evidence need not be repeated wholesale.
The release wrapper owns full gates, rebuilds, footprint and CI; never hand-edit `dist/`.

The resulting report must include baseline and final hashes; fixture origin and changes; exact
prompt/entrypoint/model/host identities; per-call outcome, elapsed time and usage including aborts;
unmodified outputs and relevant matched events; per-case semantic source/output citations; owner
before/after hashes; observer valid/invalid evidence; every unrun case; and a repair/no-repair
decision. Retain a portable synthetic input/concise-output packet; keep bulky raw streams outside
Git with stable manifest/hash/location, and explicitly record any unavailable raw evidence.

Update backlog pointers and append the delivery RCA: why existing gates did not catch the class,
which sibling carriers were checked, and what remains exposed. Commit to master and push through
`.claude/scripts/push-and-check.ps1`; wait for the watched CI result. No uncommitted handoff.

## 8. Delivery-model checklist

- [ ] Execution authorization includes the proposed actor route, eight-call/USD8 and time limits.
- [ ] Baseline, source map and actual fixture/observer controls are frozen and independently read.
- [ ] Original/reconstructed inputs are correctly labelled; hidden scoring material stays outside actor context.
- [ ] D, C, R, R-confirm, B and B-continue each have an honest disposition; no success-only selection.
- [ ] Refresh confirmation is exercised without granting blanket authority; exact owner bytes are compared.
- [ ] Any fix has a retained product failure, minimal reviewed scope, sibling reconciliation and proportionate verification.
- [ ] Results distinguish authoring behavior from static mechanics and unrun Copilot/value/stack coverage.
- [ ] Report, reusable synthetic evidence, backlog/RCA and required review/release records are committed and CI is observed.

## 9. Design review disposition

Pending fresh-context adversarial review, then a separate fresh Opus review. Freeze each reviewed
revision by Git commit and SHA-256; record rejected premises and source-checked corrections in the
companion review record. A final delta check is adjudication, not an additional independent review.
Plan acceptance does not mean the fixtures, observers, actor route or product have passed execution.
