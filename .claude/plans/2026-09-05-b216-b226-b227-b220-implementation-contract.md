# B-216 / B-226 / B-227 / B-220 implementation contract

Date: 2026-09-05  
Status: proposed for adversarial critique; no implementation is authorised by this document alone.  
Authority: the detailed acceptance and non-goals remain in `meta/BACKLOG.md`; this file freezes the
smaller delivery mechanisms, ownership boundaries, order, and hostile/valid worlds.

## Programme boundary and order

These are independent repairs, not prerequisites for the B-222--B-224 discovery increment. Deliver
them in this order where files overlap: **B-216 authority -> B-220 installer cleanup -> B-226 review
scope -> B-227 financial verdicts**. B-216 waits for PK-3's rules-carrier checkpoint; B-226 finishes
before B-227 changes review/security carriers. Terra owns prose/product implementation. Luna may own
mechanical tests or read-only fixture preparation in non-overlapping files. Sol coordinates plans,
backlog, changelogs, composition, and candidate commits. Root supplies adversarial critique and
independent immutable-range review. No worker commits or pushes.

One stable-tree build and aggregate verification boundary follows the accepted packets. Focused
red/green checks are per packet. Do not add provider legs, invoke a paid model, raise context/runtime
budgets, contact participants, or treat an authoring fixture as installed-host efficacy.

## R1 -- B-216 project-derived operation authority

**Small mechanism.** The only new consumer surface is an optional consumer-owned
`.claude/skills/<operation>/references/project-pattern.md` beside each of the eight existing .NET and
Angular operation skills. Ship no placeholder at that path and add no registry/parser/mirror. Each
skill derives the applicable pattern from first-party implementation, configuration, tests, and
owner documentation; reads the scoped sidecar on demand when present; treats generated recipes as
leads only; excludes irrelevant scope; investigates conflicting applicable evidence; and asks or
retains correctness-material uncertainty. Generic examples are conditional fallbacks, never
authority to introduce a container, library, layer, interface, or token.

**Owned source.** The eight existing `add-endpoint`, `add-entity`, `register-service`,
`add-warehouse-load`, `add-component`, `add-service`, `add-lazy-route`, and `add-signal-store` bodies;
their dotnet/angular/monorepo siblings; and only active carriers that can override the choice:
framework-rules `lean-1-2`, `solid-1-5`, and `solid-mechanism`; Claude `solid-check`
principles/counterweight; Copilot `solid-check` DIP note; `/review`'s SOLID description; protected
AGENTS templates and Copilot summaries; `docs/defaults.md`, `docs/REVIEW-GUIDE.md`,
`docs/ARCHITECTURE.md`, active eval cases, and bootstrap/rebootstrap capture/re-pin instructions.
Capture reuses PK-2's scoped evidence, counterevidence, draft, ownership, and semantic-refresh
envelope. An operation matching an existing framework skill never becomes a competing new skill:
only its absent consumer-owned `references/project-pattern.md` may be created automatically. A new
absent reference is distinct from changing an existing reference, framework `SKILL.md`, or other
owner content; those retain their existing confirmation/ownership path. Historical changelogs are
evidence, not edit targets. No production function is added.

**Acceptance.** A raw Unity-style fixture selects only its evidenced composition root and lifetime
and creates no MS.DI artifact. Alternative scoped .NET and Angular fixtures do not acquire an
unsupported interface/token/library. Missing sidecar reaches derive-first fallback; irrelevant
evidence is excluded; two applicable conflicts and unreadable/cannot-examine remain visibly
unresolved rather than becoming policy. Existing InstallerConvergence/UpdateDelivery fixtures prove
ordinary update, adopt, disable, and re-enable preserve a representative sidecar byte-for-byte,
including an `origin: discovered` skill body and protected wiki content. First observe whether a gap
exists; change installer policy only if these existing lifecycle semantics fail. A fresh
skill-creator forward check receives raw inputs and no expected answer; its artifacts are inspected
independently and are not target-host proof.

## R2 -- B-220 retired installer argument

**Small mechanism and ownership.** After inventorying all current callers, remove only the
`GitHooks` parameter, usage text, and compatibility refusal from root `install.ps1`, delegated
`src/core/scripts/install.ps1`, current installer documentation, and their existing tests. Preserve
framework-doctor legacy hook/helper detection, retirement manifests, migration evidence, and
historical changelogs. Add no replacement switch or cleanup behavior; no production function is
added.

**Acceptance.** Before the edit, a direct hostile invocation proves the compatibility refusal runs
before mutation. After the edit, native PS7 and PS5.1 reject `-GitHooks` through their native
parameter-binding error and nonzero exit before the script body, rather than the framework's exit-2
compatibility refusal, and leave the target byte-identical. Reconcile the entrypoint's current
“every error exits 2” comment/help without retaining a compatibility parser or changing unrelated
wrapper error domains. Normal install/update/adopt/disable behavior remains reachable and legacy
doctor diagnostics still identify owned historical helpers without deleting consumer files.

## R3 -- B-226 one immutable review scope

**Bounded snapshot.** `/review` invokes one new narrow `scripts/review-scope.ps1` before dispatch.
It writes only to a caller-supplied fresh temporary directory outside the repository. Its exact
PowerShell parameter contract is `-Mode Uncommitted|Range|WholeFile`, mandatory `-OutputPath`,
`-Base` and `-Head` only for `Range`, and optional `-PathFile` pointing to a UTF-8 JSON array of
repository-relative path filters. This avoids the invalid repeated-named-parameter shape and is run
directly under both native hosts. No repository/index/config file is written. Bundle inputs and
manifest paths are literal, contained beneath the selected repository/bundle, reject traversal and
reparse escapes, and never execute captured source or patch text. No ambient PR lookup or base
guessing is permitted.

The resulting small bundle contains `manifest.json` plus the actual immutable bytes being reviewed:
separate full-index binary `staged.patch` and `unstaged.patch`, nonignored untracked file copies, or
one range patch / explicitly labelled whole-file copies as applicable. The manifest records resolved
base/head object IDs, selected paths, staged/unstaged/untracked/rename/deletion layers, and SHA-256
for every patch/file. Default uncommitted scope retains both tracked layers even when they cancel in
the net worktree. Manifests and hashes exclude temp paths and timestamps, so the same unchanged
selection is byte-comparable. Copied untracked/whole-file content is limited to 16 MiB per file and
64 MiB total; unsupported/over-budget content is named and exits 3 rather than being omitted from an
approval. Git stderr/nonzero, unborn HEAD where required, bad refs, inaccessible content, an occupied
output path, or inability to hash/copy is CANNOT EXAMINE (exit 3), never an empty bundle. Invalid
arguments exit 2. A valid empty bundle is constructible and exit 0.

The parent gives the same bundle path/hash to all applicable Claude auditors (including conditional
security), the Copilot adapter, and the advisory scanner. Use `Task` when supported; otherwise run
every participant sequentially against that bundle. Participants inspect the captured patches/files,
not a recomputed `git diff`. Before synthesis, the parent creates a second snapshot from the same
selection and requires identical manifest/content hashes; drift is CANNOT EXAMINE and restarts or
stops review. This is a one-workflow temporary evidence packet, not a persistent manifest or generic
resolver framework. The parent disposes only bundles it created after review; scanner-created private
compatibility bundles are disposed on every exit. Caller-supplied bundles are never deleted.

**Advisory arguments and exit domains.** The primary scanner contract becomes
`test-weakening-scan.ps1 -ScopePath <bundle>`; it validates hashes and reads those exact patch bytes.
Findings and valid no-signal remain advisory exit 0; malformed, missing, or hash-mismatched bundle
content exits 2 as an invalid artifact; inability to read or hash emits `CANNOT EXAMINE` and exits 3.
Preserve the existing sole positional
`<git-ref-range>` call shape and useful no-argument behavior by creating one private Range or
Uncommitted snapshot and scanning it; reject mixed legacy/new shapes. For `A..B`, resolve and compare
the two endpoints. For `A...B`, resolve both endpoints, use their Git merge-base as the effective
base, and record supplied and effective object IDs; never guess a missing endpoint. Allowed new
production functions are limited to snapshot
`Invoke-GitBytes`, `Get-SelectedPaths`, and `Write-ReviewScopeBundle`, plus scanner
`Read-ReviewScopeBundle`; existing recomputing `Get-DiffNames`/`Get-FileDiff` are removed. Do not
redesign the assertion heuristic.

**Owned source and acceptance.** Change `src/core/.claude/commands/review.md`, every active auditor
scope snippet/whole-file sibling, `src/core/.github/prompts/review.prompt.md`, the test-weakening
script, `TestWeakeningScan.Tests.ps1`, and focused review contract assertions only. Hostile fixtures
cover cancelling staged/unstaged edits, untracked nonignored versus ignored, rename/delete, spaces,
path filtering, valid/invalid immutable ranges, unborn HEAD, Git stderr/nonzero, inaccessible input,
tampered bundle bytes, between-dispatch drift, and missing Task capability. All participants receive
the identical bytes; valid empty and valid
no-signal worlds pass distinctly; inability can never yield APPROVE or “nothing qualifies.” Both
native hosts must execute the real parent/builder/scanner command shape, including `-PathFile`.
Native binding failures and malformed/missing/tampered bundles are invalid input; actual read/hash
inability is CANNOT EXAMINE.

## R4 -- B-227 evidence-based financial/security verdicts

**Small mechanism.** Change only .NET/monorepo security-auditor carriers, related active financial
rule/bootstrap text, canonical `map-warehouse`, and focused security contract/eval expectations.
Review applicable atomicity/concurrency, precision/rounding, and temporal invariants against actual
mechanisms, policy, and executable/domain evidence. A type name, property name, absent lock, or
particular isolation level cannot establish severity by itself. Preserve hard auth, injection,
secret, and demonstrated financial controls. Map usage/provenance is not correctness. B-216 retains
interface/layer authority. No domain engine, score, new security skill, or production function.

**Acceptance.** Raw paired cases include a valid optimistic/atomic strategy versus an actual lost
update, justified numeric representation versus reproduced precision/rounding loss, an idempotent
operation versus duplicate effect, and an existing reporting implementation with a wrong result.
Before any model review, each pair freezes the applicable invariant, tolerances, and preconditions;
its executable/domain oracle runs independently of property/type names and of the model response.
Applicable policy violations and reproduced unsafe outcomes remain findings with evidence/severity;
unavailable proof remains uncertainty. Static carrier tests first go red on the old categorical
language. A bounded fresh semantic check gets raw sources and withheld expected outcomes; reviewers
inspect its artifacts and executable/domain oracles rather than accepting caveat words or a model's
self-report. It is not financial-safety certification or Copilot efficacy.

## Common completion and deferrals

Each packet needs exact changed-function accounting, focused hostile red plus clean evidence on
native PS7/PS5.1 where executable, immutable independent review, cross-stack composition/parity,
consumer-voice changelogs, backlog RCA, and the stable-tree aggregate/release boundary. B-42 remains
open until a real independent participant exists. B-49 remains invalid/deferred. B-224/B-225 remain
partial until separately authorised host/application/value observations; fixtures and documentation
do not close them. B-227 owns certainty in warehouse/financial verdicts; no earlier packet expands
into it.
