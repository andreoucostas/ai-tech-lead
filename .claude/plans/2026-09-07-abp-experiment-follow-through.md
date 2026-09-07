# ABP experiment — adversarial review and final implementation plan

**Status:** Final proposal for the user's implementation decision. This task prepares and records
the plan; it does not implement shipped changes or authorize another paid experiment.
**Source baseline:** `d6625bef4d45168a71a2f16855b442149e59a49d` (v0.84.0).
**Authority:** root CLAUDE.md, DEVELOPING.md, WSD-074 and WSD-078; B-230 and B-224 remain open.

## Review disposition

**REVISE the seven-part recommendation.** Deliver the observed archive defect first; make the
scope-policy repair separately; fold compatibility into that existing workflow; keep operator
lessons in maintainer guidance; defer both paid observation and context removal pending a named
decision and adequate evidence. Unused credits are not a reason to reopen CP2.

This review inspected the source and retained authoring records. The ABP worktree and raw task
files were deleted during the user-authorized cleanup; the user reports deleting the remote fork.
Earlier hashes and observations remain historical records, not newly inspectable raw evidence.
Fresh miniature fixtures must be labelled reconstructions, not a replay of deleted material.

| Finding against the earlier plan | Consequence and final disposition |
|---|---|
| A hash computed from an already-normalized archive certifies the damaged copy. | Capture actual working-file bytes before any move or synthesis. Freeze the expected digest; a rerun must never rebaseline an existing archive to make it pass. |
| Correct original path alone is insufficient for provenance after installation replaced that path. | Retain the pre-install Git revision and original path. Query that revision, not the later framework-install author at HEAD. Metadata and trust judgement remain separate. |
| The pending marker currently disappears before bootstrap, whose completion check examines documentation shape, not archive identity. | Preserve explicit integrity evidence through Phase 7 and require an additional final identity result before adoption completion/commit. Documentation-check PASS alone is insufficient. |
| Git blob identity is not raw working-file identity under line-ending conversion or filters. | Use raw SHA-256 for preservation and Git revision/path for historical attribution; never substitute one for the other. |
| Limiting cleanup to already-changed lines can exclude necessary callers, dependency setup and compatibility fixes. | Bound edits by the requested behaviour, existing compatibility obligations and verification. File/hunk membership alone is neither permission nor prohibition. |
| The Boy Scout conflict exists beyond `/fix`. | Reconcile the canonical rule, workflow section 4, review/convention-check expectations, hook output and generated carriers; preserve the user's explicit project policy. |
| No explicit skill/read event does not establish that relevant information was absent from injected context or that a needed fact was missed. | Keep B-224 open. Do not claim retrieval failure caused the patch defects, or that another compulsory read would have prevented them. |
| The proposed 30–60-credit trial and context deduplication have no current decision contract or measured carrier attribution. | Remove both from the implementation commitment. Require a fresh decision before spend; retain the current static ceilings and carrier architecture. |
| Publishing and launcher mistakes do not by themselves justify consumer policy or a new runner. | Amend existing maintainer operating guidance. Headless `/adopt` already forbids opening a PR. |

## Alternatives and proportionality

1. **Prose-only archive reminder:** cheapest, but the current workflow already forbids deletion and
   overwriting. Repeating that promise does not address the observed false completion. Reject.
2. **Bounded archive evidence plus final verification:** closes byte loss and misattribution with
   one adoption-specific helper and the existing installer/workflow/completion path. Select.
3. **General transactional adoption service, persistent audit registry, new hook or eval platform:**
   would enlarge the product and testing burden beyond the observed harm. Reject for this delivery.

The recorded archival loss is sufficient to prioritize B-230 without repeating a paid ABP run.
Parser gates established well-formed output while no completion assertion compared all original
and archived bytes. The same gap covers every approved archive candidate and quarantine move,
not only `.cursorrules` and Copilot instructions. This is the B-230 RCA to verify during delivery.

## Delivery 1 — B-230 archive preservation and provenance

**Frozen outcome:** every candidate the installer or adoption workflow moves retains its exact
pre-move bytes, original path and examinable provenance evidence. A changed, absent or unexaminable
required archive cannot produce adoption completion. Clean screen-in-place content stays untouched;
quarantine never grants trust or permission to merge. Apply the mechanism to interactive and
headless paths so they cannot disagree about preservation.

**Implementation boundaries and sequence:**

1. Add versioned integrity entries to the existing adoption evidence, preserving the legacy
   `archivedOriginals` string array for existing readers. An entry records original path, actual
   destination, raw pre-move SHA-256 and byte length, archive owner (installer/workflow), and the
   explicit pre-move Git revision plus provenance availability and any local-modification status.
   Tracked history does not vouch for uncommitted bytes. Unknown history is a named state,
   not a fabricated author or an automatic trust finding. An empty candidate set is valid only
   after successful inventory; failed inventory is not an empty set.
2. In `src/core/scripts/install.ps1`, capture evidence in the existing preflight before any archive
   mutation. Check each move immediately. Stop on mismatch or examination failure while preserving
   originals/evidence and reporting any completed moves. Do not add broad automatic rollback or
   silently continue to overwrite a failed candidate. `-WhatIf` must remain non-mutating.
3. Add one narrow PowerShell helper under `src/core/scripts/` for candidate capture, byte-preserving
   archive and verification. Workflow-selected candidates are fixed before synthesis. Reuse the
   same byte/path checks for installer and workflow moves; do not write a second generic installer.
   Retain path containment, literal-path handling, collision refusal and reparse-point safeguards.
   Prefer exact original-relative destinations for new archives; old renamed archives remain
   supported through explicit mappings rather than guessed filenames. No automatic archive migration.
4. Use the existing clean committed-install HEAD as the immutable headless baseline anchor.
   Installer entries carry the earlier pre-install revision; still-live candidates use their
   recorded pre-move revision. Keep the raw digest captured from the actual filesystem even when
   Git uses different line endings. Freeze the candidate inventory and expected evidence identity
   before transformation; final verification must reject altered, missing or omitted entries rather
   than accepting a regenerated manifest. Preserve the saved evidence until completion. This is
   protection against accidental loss/rebaselining, not tamper resistance against an unrestricted
   writer replacing the checker and every reference.
5. Update all three stack `adopt.md` sources and the shared Copilot adapter. Keep originals separate
   from normalized proposals. Screen archived content using its original path at its captured
   revision; an available author/history is evidence to review, not a machine-verifiable team-trust
   verdict. Preserve headless non-application and human review of discovered instructions.
6. Carry the saved evidence explicitly across Phase 7's existing marker removal/restoration path.
   Require archive verification before entering bootstrap and again after its documentation gate,
   immediately before the adoption report/commit. PASS requires both results against the frozen
   complete inventory. On either failure or inability to examine, restore the saved pending marker,
   retain evidence, report the reason and stop. The final report names both commands/results. Do
   not implement an always-on archive-integrity obligation after completed adoption; existing human
   archive-retention/removal policy remains a separate lifecycle decision.
7. Legacy pending installs lacking pre-move digests must not silently hash today's archive and
   declare original preservation proved. Use independently available original-byte evidence when
   demonstrable; otherwise report `CANT-VERIFY` and request a human recovery/disposition. Git history
   may establish attribution without establishing exact pre-move worktree bytes. A human disposition
   does not become a fabricated verified-integrity result. Greenfield installs remain applicable
   without inventing adoption evidence.

**Acceptance on both direct native PS7 and PS5.1:**

| Constructible case | Required result |
|---|---|
| Ordinary exact-copy candidate, zero-byte candidate and validated empty inventory | PASS; every selected byte preserved; empty is explicit. |
| Non-ASCII/BOM/CRLF content with Git line-ending conversion enabled | Exact raw bytes survive; no decoded or Git-blob comparison masquerades as byte equality. |
| The 30-to-8-line normalization shape, one-byte corruption, deleted archive or removed evidence entry | Verified failure naming the candidate; no adoption completion. |
| Candidate/evidence recapture after corruption; interrupted run resumed | No silent rebaseline; preserve the original reference and distinguish already-verified work from incomplete work. |
| Installer archive followed by a framework replacement commit | Attribute the original file at the pre-install revision; do not call it freshly untracked or attribute it to the installer. |
| Real untracked input, shallow/unavailable history, unreadable file and malformed evidence | Distinct factual diagnostics; unavailable examination is not a trust finding, corruption finding or PASS. |
| Flagged candidate quarantined; clean architecture/wiki retained | Bytes preserved; flagged content stays unmerged; clean content's paths and bytes remain unchanged. |
| Existing destination, case collision, escaped path or reparse ancestor | Refuse before affected-path mutation; inspect no out-of-repository candidate. |
| Bootstrap changes an archive after the pre-bootstrap check | Final check fails; pending marker restored; no completion report/commit. |
| Legacy marker without reconstructible evidence; ordinary greenfield/update | Legacy uncertainty disclosed without rebaselining; unrelated installation modes retain their documented behaviour. |

Extend existing installer/update and documentation contract suites; add only a focused executable
suite/helper where the real lifecycle cannot otherwise be exercised. Observe a normalized-archive
false acceptance on the unfixed completion path with all unrelated checks valid, then reject it
with the new completion sequence. This reconstructs the missing mechanical guard; it does not
prove a live model will invoke it. Observe a release-specific verifier mutation red, valid/clean
reruns, exact host executables and nonzero case counts, including one hostile code-page run.

Before release obtain separate nonimplementer review of the frozen contract and immutable diff,
plus an orthogonal byte-comparison execution vantage for this data-loss change. Compose all three
distributions, update all four changelogs, run the existing release gates and CI, then tag through
`release.ps1`. Record the actual results, invocation/compliance gap and RCA; do not infer live
Copilot compliance from deterministic tests. Delivery 2 does not hold this repair's release.

## Delivery 2 — B-231 focused bug-fix scope and compatibility

Replace contradictory defaults with one outcome-based rule: every bug-fix edit must be necessary
for requested behaviour, compatibility with existing callers/extension points, or meaningful
verification. Explicitly requested cleanup remains allowed. Being in a touched file does not
authorize logging conversions or other independent cleanup. Do not require a TODO comment merely
because unrelated Boy Scout work was deferred. Permit necessary fixes outside the original hunk.

Use the existing canonical framework rules and `/fix`/review path; add a short conditional check
for changed public/protected extension contracts (signatures and virtual/override behaviour).
This is relevant to libraries/frameworks such as ABP, not a requirement to build a new API analyzer
or compatibility skill. Additions or breaking changes explicitly requested by the user remain valid.

Sweep only active reintroductions: `src/core/CLAUDE.md`, framework-rules workflow text, `/fix`,
`/review`, `convention-check`, the three `boy-scout-check.ps1` messages, generation snippets and
shipped mirrors; inspect corresponding monorepo siblings. Qualify default cancellation propagation
so it cannot demand an unrequested extension-contract change. Keep one canonical scope rule and
short references elsewhere. The hook remains advisory under WSD-024; change conflicting wording,
not its detection algorithm or permission semantics. Ensure reviewers
receive the task's scope so they do not re-demand excluded cleanup. Keep static context ceilings.
Protected consumer policy cannot be bulk-overwritten on update: use the update-owned framework
carrier for framework defaults and expose any required protected-text migration through existing
reconciliation. Preserve explicit consumer mandates; do not promise updates silently repair them.

Acceptance examples: unrelated old logging stays unchanged; necessary test DI/caller edits are
allowed; an unrequested virtual-signature break is identified; a compatible override remains
valid; explicitly requested refactoring is allowed. Check conflicting generated instructions in
fresh installs and protected-text update cases. Static consistency checks certify carrier agreement,
not that a model follows the rule. Keep any live semantic observation separately labelled.
Review/release this bounded source change separately, with its own changelogs, normal gates and RCA.

## Maintainer corrections and deferred decisions

Amend existing operating guidance, not a new runner or consumer approval system:

- Before paid work, verify prompt round-trip, actual resolved launcher/model/effort, working scope,
  usage capture, and any available enforceable cap; never describe prompt-only limits as hard caps.
  Establish the required SDK and a real build/test baseline before purchase. Separate dependency
  setup permissions from the task's required network restrictions; do not weaken headless adoption
  restrictions to accommodate a task toolchain. Reuse existing tools/packets.
- Treat external publication as its own stated objective. Existing authorization carries forward;
  do not ask twice. An evaluation result alone is not an upstream-PR instruction. If authorized,
  use a clean upstream branch and preflight contribution identity/CLA requirements before pushing.
- Before temporary cleanup, retain only approved sanitized findings, cost records and compact
  reproductions in the maintainer record, then delete task artifacts as requested. Never retain raw
  content against a deletion request. Mark missing evidence honestly; hashes cannot restore files.

**B-224/context follow-up is deferred.** The 17,801-token final-request aggregate does not establish
carrier duplication, per-request repetition, or total billable cost. A source inventory can suggest
measurement targets but cannot reproduce the deleted installed consumer. A later proposal must name
the decision its result changes, a relevant task fact absent from the ordinary prompt, observer
positive/negative controls (including auto-delivered context), toolchain readiness, a measured host,
and total attempted-call cost/time limits including calibration and aborts. Separate descriptive
access evidence from B-225 paired value evidence. No guaranteed success or reuse of the arbitrary
30–60-credit suggestion; WSD-078's fresh-decision requirement applies.

## Cost, completion and review record

This review/plan uses the current agent session and one independent read-only review session; it
launches no paid Copilot/Claude CLI calls. That is not a claim of zero agent tokens. The first
implementation delivery uses local fixtures and installed PowerShell hosts; no ABP re-download,
container rebuild or paid efficacy trial is required to establish its mechanical contract. Exact
implementation tokens and credits cannot be predicted from this plan. If the named helper requires
general lifecycle infrastructure, stop and re-scope instead of silently expanding B-230.

The requested planning task is complete when this proposal, critique disposition and backlog
pointers are recorded and normal meta-document checks pass. Product implementation, runtime
acceptance and release remain future work. Design critique is not independent implementation review.

Root performed direct source checks; a separate read-only agent `adversarial_plan_review` received
the immutable source baseline and proposed seven changes, was asked to form its own threat model
before reading prior rationale, and supplied critique. Root supplied source counterchecks during
review, so follow-up findings are collaborative adjudication rather than a second blind review.
The reviewer did not implement any product change. Its accepted corrections are represented above;
the final document's review result is recorded in WSD-079 after delta review.
