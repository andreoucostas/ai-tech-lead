# B-222–B-224 implementation contract

**Frozen:** 2026-09-05 against v0.83.0 / `341f586b63815eb17730fd4b2e57f8ab92c9cf64`.
**Authority:** WSD-074 and `.claude/plans/2026-09-05-repository-knowledge-strategy.md`.
**Status:** PK-1 accepted with conditions for implementation; PK-2 and PK-3 remain sequential
packages under this one coherent product increment. No intermediate package establishes Copilot
application or product value.

## Delivery sequence and ownership

Terra implements one package at a time: PK-1 discovery, then PK-2 capture/refresh, then PK-3
ordinary-task use. Sol owns contract coordination, source/dist/changelog/backlog/RCA surfaces and
candidate integration. Root owns adversarial critique, independent review and push authorization.
No simultaneous writer may edit bootstrap, rebootstrap or skill files. B-225's offline protocol may
run independently; its live arms, B-42 and B-49 require their stated external prerequisites.
B-216, B-226, B-227 and B-220 are separate repairs and do not block this increment.

## PK-1 — bounded semantic repository discovery

The only planned authored product surfaces are the three stack copies of
`.claude/commands/bootstrap.md`, `.claude/commands/rebootstrap.md`, and
`.claude/agents/bootstrap-pass.md`, plus the .NET one-sided `map-warehouse/SKILL.md` amendment that
flows to monorepo. Tests may add only directly required contract/fixture surfaces.

1. Inventory accessible first-party tracked source, configuration, migrations, orchestration,
   tests and authoritative project documentation across the repository. Consider relevant local
   untracked source only with explicit uncommitted provenance. Classify generated, vendored,
   framework-owned, inaccessible and external material. A profile label is neither an inventory
   boundary nor permission to cross an access boundary. Do not capture secrets.
2. Select semantic slices through entrypoints, dependencies, callers/callees, tests,
   configuration, producers/consumers and exceptions. Include quiet, atypical, unique,
   helper-derived and conflicting-scope evidence; recurrence and naming are leads, not gates.
3. Read at most 40 distinct content files and follow at most two additional dependency hops per
   selected seed. Inventory does not consume that content-read budget. Track visited sources, stop
   cycles, report actual reads and keep unresolved dependencies with the next useful source.
4. Return scoped facts and evidenced operations with applicability/non-applicability, repository-
   relative source paths and symbols, revision when available, counterevidence and exceptions,
   dependency sources, observed/declared/inferred/unresolved status, meaningful recheck, and area
   coverage as inventory-only, semantically inspected, excluded or inaccessible. The worker remains
   read-only; PK-2 gives the parent write authority.
5. Three-to-five is only a presentation batch, never an eligibility or completeness cap. Budget
   exhaustion is a partial result with a bounded continuation, never “nothing found”, exhaustive
   coverage or a recall claim. Rebootstrap continues from previously uncovered areas and changed
   explicit evidence/dependencies, including quiet callers, rather than selecting only recent work.
6. Preserve declined-recipe intent; reconsider one only when changed evidence is named. During a
   requested bootstrap/rebootstrap discovery pass, indirect warehouse tracing may share this
   bounded budget. Standalone map behavior and unresolved outcomes remain unchanged. Use native
   worker delegation only when the host exposes it; otherwise perform the same finite passes
   sequentially, without assuming Claude `Task` support in Copilot.

Acceptance separates three kinds of evidence. Deterministic tests verify required and forbidden
carrier contracts across all three composed distributions; they do not certify semantic discovery.
An independent fresh-context forward test receives only the concrete workflow entrypoint, a
realistic request and a raw mixed-domain repository fixture in an isolated scratch root; it does
not receive this conversation, plan, grading key, expected findings or prior conclusions. Its
read/write scope stays inside that root. The produced candidate and coverage artifacts—not the
evaluator's self-report—are inspected for the actual scoped claims or ordered operation steps, plus
a quiet unique fact, helper-derived fact, conflicting scoped patterns,
cross-component operation, generated decoy and inaccessible dependency. The evaluator must retain
the inaccessible dependency as unresolved and may use quiet non-recurring evidence. Later Copilot
CLI/VS Code and value observations remain PK-3/B-225 evidence, not substitutes for this test.
Any unavoidable authoring-workspace context is recorded as a limitation and never presented as
target-host isolation or product efficacy.

Non-goals: a registry, parser, graph or hosted service; a background miner; a new distribution;
new access or write authority; production queries; provider spending; a no-match hook/router; a
domain keyword taxonomy; a footprint-ceiling increase; or changing map-warehouse's unsupported
correctness sentence, which belongs to B-227.

## PK-2 — grounded draft capture and dependency refresh

PK-2 consumes PK-1 output and reuses wiki, project skills, maps and existing triage. A scoped fact,
gotcha, constraint or failed approach goes to an existing wiki/authoritative document; an evidenced
repeatable operation becomes a consumer-owned candidate project skill with focused references; a
warehouse fact links the existing map; conventions, ADRs, hazards, security and debt retain their
existing owners; incomplete exploration gets at most 12 summary lines in `FRAMEWORK-CONTEXT.md`
plus an on-demand existing document or consumer-owned `docs/discovery-notes.md`.

Automatic writes are limited to new, non-overwriting drafts during requested discovery. Existing
provenance/adversarial screens and confirmation for owner content, policy/ADRs, deletion and
authority remain. Source, comments and generated documents are evidence, not executable
instructions or authorization. A draft skill's loaded body states candidate status, scope,
evidence and unresolved steps because it is immediately discoverable. It cannot self-corroborate,
approve itself through indexing/invocation, or authorize broader reads/writes.

`last-verified: never` is valid only for never-checked `suspected` or `unverified` claims;
`verified` requires a real ISO date and meaningful recheck. Failed, unavailable or path-existence-
only checks do not refresh truth or dates, and downgrading preserves a historic verification date.
Rebootstrap compares changed explicit evidence and dependency sources, including quiet callers;
renames, deletions, unavailable history and external state remain visible. Installer/adopt behavior
changes only if a focused preservation fixture first exposes an actual gap.

Hostile/valid worlds cover invalid `never` status, semantic versus path-only refresh, quiet-helper
invalidation, deduplication, opposing scopes, generated self-confirmation, owner-byte preservation
and an unresolved draft consulted as if unconditional. Run relevant tests directly under native
PowerShell 7 and 5.1 with equal nonzero case counts. Measure installed summary/index/skill-
description size separately from on-demand bodies.

## PK-3 — selective ordinary-task use

Add or replace one concise rule in the existing update-owned framework-rules carrier: for a
nontrivial change, locate likely task areas even from a feature-only request; select relevant scoped
claim/map/skill/example sections; recheck correctness-material underlying evidence; preserve
conflicts, staleness and inaccessible facts as unresolved or ask; then name material evidence and
run repository-evidenced verification. Keep bodies on demand. Do not add a duplicate always-loaded
carrier, skills tree, hook dependency, keyword catalog, GitHub PR dependency or full-wiki preload.
Repository-local persistence is not a promise that model processing stays local.

Acceptance observes entry discovery, body/reference reading, scoped application and task
verification separately. Hostile cases include irrelevant and opposing scopes, unresolved drafts,
stale/missing evidence, feature-only prompts, absent hooks and an index above the existing inline
threshold. A loaded-context measure must be negative or unchanged while remaining inside existing
ceilings. Offline carrier checks and vendor documentation are not efficacy evidence. Exact Copilot
CLI and VS Code host/model/seat observations remain named gaps when unavailable; an unexercised
required host leaves B-224 partially done. B-225 alone owns the outcome comparison.

## Accepted critique and threat model

Root independently challenged the contract before implementation and returned **ACCEPT WITH
CONDITIONS**. The binding threats are: latent behavior promoted to unsupported global policy;
self-corroborating drafts or overwritten owner content; missed quiet/unique/helper/conflict cases;
the finite budget misreported as complete; active draft skills losing unresolved status; feature-
only tasks failing without Claude delegation/hooks; refresh dates changing without semantic
recheck; installed catalog cost escaping the dist ceiling; overlapping carriers reimposing
framework-specific implementation assumptions; and scope checks converting failed examination to
clean. The conditions above incorporate root's required raw-fixture forward test, access and
provenance boundaries, negative-or-equal loaded context, and separation of artifact, host and value
evidence. This critique authorizes PK-1 implementation only; future immutable code ranges still
require independent adversarial review.

## B-228 — test-oracle correctness and bounded runtime repair

**Frozen:** 2026-09-05 against the same baseline. **Status:** accepted with conditions for
implementation alongside PK-1 because its three meta-test files do not overlap the product source.
This is a new responsiveness/correctness objective, not a reopened claim that the retired runtime
architecture breached its old budget. Luna owns implementation; Sol integrates; root independently
reviews the immutable candidate, including an orthogonal execution vantage for false-green release
behavior.

1. **ValidateDist process result.** Change only the driver's result classification and its directly
   required regression mechanism. A child `Process.ExitCode` other than zero fails that case even
   when stdout claims `1 passed, 0 failed`; it replaces the claimed pass rather than adding a second
   verdict. Retain the 43 existing case registrations and current-host assertion. Missing, zero,
   malformed or ambiguous summaries remain honest failures. Drive the actual parent/child process
   boundary for valid exit zero and planted success-summary plus exit seven; copied decision logic
   is not evidence.
2. **Release budget enforcement oracle.** Preserve the first nine executable waiver-decision
   cases. Replace the regex/name-presence claim with a bounded test of the actual source function,
   actual source caller and the downstream release-refusal boundary. A known within-budget world
   reaches allow; a known over-budget world prevents downstream release. A source mutation that
   removes the single caller, and one that conditionally bypasses it, must make the oracle red.
   Do not invoke external release actions, mutate the working release, create a generic checker, or
   refactor production solely to ease the test. Every new function must be required by this contract.
3. **B-215 raw Git reader.** Change only `Invoke-GitBytes` mechanics to use
   `Diagnostics.Process`, binary stdout `BaseStream` copying and concurrent/asynchronous stderr
   draining. Preserve exit/error/raw bytes, tag selection through v0.82, all history/path/stack
   observations, OID caching, SHA comparison and the missing-digest hostile control. A focused
   fixture must preserve NUL/high bytes and nonzero Git stderr/exit. Do not normalize bytes, remove
   versions, or alter caching/history without separate evidence.

Each focused suite must run directly under
`C:\Program Files\PowerShell\7\pwsh.exe` and
`C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`, printing the actual executable and
version and retaining equal nonzero case counts. Preserve UTF-8 BOM. Do not run aggregate suites
while a writer is active. Any performance claim requires the same stable-tree aggregate before and
after; the already-observed CI baseline may be used instead of spending another baseline run. No
budget ceiling increase, coverage deletion, provider leg or live evaluation is authorized.

The separately lockable CI critical-path package is not part of this implementation range. If
approved later, all eight native Windows host contexts start independently and publish nonempty
per-file manifests; one required downstream Windows parity job safely downloads and compares all
four PS7/PS5.1 pairs. The watcher and topology tests must explicitly require the aggregator, and
missing, skipped or bypassed parity must be hostile red worlds. Removing serial `needs` without
that downstream decision is forbidden.
