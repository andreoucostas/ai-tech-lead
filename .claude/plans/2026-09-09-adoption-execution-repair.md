# Adoption execution repair — design for adversarial review

Status: PRODUCT-ONLY PLAN after two Opus critiques (both REVISE). Root incorporated
the concrete corrections below; those final amendments have not had a third
review. A is the first proposed implementation; B is evidence-gated and not
co-delivery approval. Implementation requires user direction. No shipped files
change in this delivery. See the sibling review/adjudication record.
Filed against: v0.86.0; authoring baseline
`f589b901b40df0ac1beb8a5aa17aa6d59f8f0307`.

## 1. Decision and proportionality

Product delivery 1: correct the archive-plan document contract and test its exact
published example. Product delivery 2, held pending the stated evidence: improve
recovery from oversized workflow reads through the existing rules carrier.
No operator tooling, study runner or model-comparison campaign is in either scope.

Repair two demonstrated instruction/tool contracts, not the whole onboarding
architecture. Separate those repairs from maintainer execution mistakes. Preserve
the existing archive, provenance, headless approval and completion obligations.

Observed harm: an incorrect archive plan survived an intermediate agent checkpoint;
the real script rejected it when finally exercised. Oversized reads returned a
tool message rather than workflow content, followed by fragmented discovery.
Repeated paid sessions did not reach an application change. We cannot attribute
the total cost to one model or to the framework: prompts, caps, resume state,
permissions, interruption and model all varied.

Options considered:

- A — schema example/test only, with operator-led paged reading. Smallest certain
  defect fix; does not improve the shipped read-recovery instruction.
- B — A plus a short read-recovery clarification in the existing loaded rules
  carrier. Retained as a separately evidence-gated second product increment;
  behavioral usefulness of the added prose still needs observation.
- C — split/rebuild adoption into phase files, build a runner/state machine, or
  weaken full onboarding to enable the bug immediately. Rejected at this stage:
  higher surface/cost and lifecycle/security risks without evidence it is needed.

If Opus finds B's incremental prose unhelpful or its loading unobservable, ship A
first and keep B as an explicitly unvalidated proposal. Do not let a small defect
become a new orchestration platform.

## 2. Evidence and limitations

External replay packet: `C:/TEMP/abp-replay-20260909/evidence/` (never ships).
ABP pre-fix source: `280549ca794e9c3fa25aebd7500b426f7fd80ab3`; local exported
snapshot has no upstream history. Root observed 8 multilingual and 31 mapping
baseline tests pass; no bug regression or implementation has run.

- Native Copilot 1.0.83, Sonnet 5 medium, session
  `c71685d9-1e0b-457b-800f-9f3b2f2b8303`: `view` on adopt.md returned
  `File too large to read at once (39.4 KB)` instead of the file. Its tool event
  nevertheless had `success: true`; the console said `1 line read`. The 40,351-byte
  file and the exact selected tool event were inspected by root. The archive
  script similarly returned a 38.8 KB size message. This is a host-read limit,
  not proof that long Markdown is intrinsically unusable or that grep cannot help.
- After the first critique, root inspected the same session's initial
  system.message at 10:57:18.351 UTC, before the adopt.md view at 10:57:21.681 UTC.
  It already contained the framework-rules carrier path, shared Verification
  command discovery paragraph and the exact shared bug-scope sentence. Thus
  current carrier content reached this native surface before the failed read;
  this does NOT prove a future new paragraph will be followed or universal loading.
- All three authored adopt.md files describe a plan containing path pairs, without
  showing the required `{ "entries": [...] }` document shape. The actual helper
  `src/core/scripts/adoption-archive.ps1`, Invoke-AaFreeze, requires `entries`.
  Existing tests construct this correct wrapper themselves in New-ArchivePlanFile.
- The earlier GPT-authored checkpoint used a bare array. Sonnet's first run reached
  actual -Freeze exit 3; its next run repaired the shape and archived .cursorrules.
  Root reran -Verify on both native PS7 and PS5.1: all three frozen archives PASS.
- Final replay commit `989f1e800d9c7cdd8190d965e0c1ca3d944b30ec` preserves only
  the plan correction, marker extension and lossless .cursorrules archive. This
  proves inventoried-byte preservation, not complete discovery/provenance review.
- The 100-cap Sonnet run ended at 76.78158 receipted credits, while its final prose
  said it ran out. No limit-reached event was observed for that run. A GPT resume
  had retained a 30-credit limit despite the launch flag; interrupted receipt
  capture leaves one run's cost unknown. Do not equate exit 0, plan commits,
  model self-reports or configured launch flags with task completion/effective cap.
- IMPORTANT HOST GAP: adopt.md's Headless mode requires denying network egress,
  secret access and git-config changes. Prior runs used ordinary native permission
  approvals, disabled built-in MCP, restricted paths on a best-effort basis, and
  denied git push/gh. Those facts do NOT establish the required three denials.
  The replay was not a certified conforming headless execution. No leak is alleged.

These are standalone maintainer observations, not RK1 arms, FS2 or causal model
comparisons. The frozen repository-knowledge study remains NOT RUN.

## 3. Proposed implementation contract (after approval)

### A. Make the archive-plan example executable documentation

In `src/stacks/{dotnet,angular,monorepo}/files/.claude/commands/adopt.md`, immediately
before Phase 3's -Freeze command, correct the existing prose to explicitly require
a JSON object with an `entries` array, and show one exact JSON example whose
`entries` array contains the .cursorrules original/destination pair. Explain that
the array contains every selected candidate and is frozen once before any move.
Keep the existing lifecycle and refusal behavior. Do not alter the helper to
accept a second ambiguous schema or silently repair malformed plans.

Use a stable local example label so the existing
`.claude/hooks/tests/AdoptionArchiveIntegrity.Tests.ps1` can extract exactly one
block identified by that label from each composed dist. Other JSON/fenced blocks
elsewhere are irrelevant and must not fail the test. Missing/duplicate labelled
block or invalid
JSON is a documentation defect; unreadable document/failed command is an explicit
examination failure, not an empty or passing example. This is one bounded example
extractor, not a generic Markdown parser. Do not add a new test runner/suite.

Use the existing fixture machinery with structurally valid integrity metadata,
all existing entries verified, and no `frozenAt`. Require a real root .cursorrules
file, no existing marker entry for that original/destination, and no existing
docs/pre-adoption/.cursorrules destination. Thus neither a missing source nor an
inventory/destination collision can masquerade as the example result. Do not
confuse fixture lifecycle failure with an example defect. The example contains only originalPath and
destination, never invented digests/verified flags. In those fixtures, serialize
neither a replacement wrapper nor a
test-only corrected example: write the extracted bytes as the plan, invoke the
real dist helper -Freeze, inspect the frozen entry, execute -MoveFrozen, and
verify exact preserved bytes. Test all three dist examples with the same case
count on PS7 and PS5.1. Retain the helper's existing negative/hostile tests.

### B. Recover unreadable/oversized instructions on an already-loaded carrier

This increment is NOT approved for co-delivery with A. Before implementation,
confirm its named native observation is executable without violating its scope.
Proposed exact placement: in the shared
`src/core/.github/instructions/framework-rules.instructions.md`, after the
introductory sentence beginning `These apply to every workflow` and BEFORE
`<!-- @stack:verif-rules -->`. Add at most one short paragraph there, outside the
composed numbered list and marker fragments. Check all three generated outputs
and mirror handling. Proposed obligation:

> A size limit, error, or truncated response is not a completed read. Before
> executing a workflow, obtain its complete governing instructions through bounded
> contiguous ranges, including mode overrides, precedence/early stops, marker
> lifecycle, failure recovery and completion conditions wherever they appear.
> Headings and search hits locate instructions but do not replace reading them.
> If required instructions remain unreadable, report cannot-examine and do not
> execute a guessed procedure.

Place this in the existing framework-owned carrier, not solely inside the
oversized adopt.md that the first read failed to return. No new carrier, router,
size-threshold gate, script or universal claim about current provider limits.
This deliberately does not permit reading only an isolated phase. No permission
to omit later-phase constraints needed by an earlier operation.
No relaxation of skill-mandated complete reads or other higher-priority rules.

This is a hypothesis about better instruction-following, not a deterministic
guarantee. Existing parser checks can show composition/presence, not comprehension.
Review all three composed carriers and mirror generation as usual. Do not invent
a regex assertion whose green result purports to prove the model read the text.

### Explicitly excluded operator work

No DEVELOPING.md change, budget runner, resume tool or checkpoint registry in this
product repair. Operator failures remain evidence limitations, not a third product
workstream. ABP continuation/recovery is separate: its discovery coverage has not
been certified and its frozen inventory must not be silently refreshed. Neither
an intermediate commit nor archive-byte PASS certifies adoption completion.

## 4. Verification and falsifiability

1. Before changing prose, add the narrow doc-example test and observe RED against
   the current missing example on direct PS7 and PS5.1. The same instrument must
   be able to succeed once the valid example is present and works with the helper.
2. Observe GREEN after the doc fix on both hosts. Then mutate only the example to
   a bare array: the case must go RED through the actual -Freeze rejection before
   any move, specifically exit 3 with the missing-entries diagnostic class, not
   merely any nonzero result; verify unchanged source/marker and restore/rerun
   clean. Avoid matching the entire path-bearing error string. Also exercise a missing/unreadable example
   and preserve the artifact-vs-cannot-examine distinction. Do not mutate live ABP.
3. For B, deterministic checks establish shipped placement/format only. A later,
   separately authorized READ-ONLY native instruction-retrieval observation, NOT
   a headless /adopt execution, must show the modified carrier present in the
   initial model context and the complete governing workflow fetched through
   successful contiguous ranges after a real oversized-read response. Ask for
   source-grounded mode/early-stop/marker-recovery/completion obligations; compare
   with source. Tool results, not a self-reported claim of having read, are the
   retrieval evidence. No writes, archive commands, shell, secrets or adoption
   transition is authorized by this observation. If it cannot be separated from
   live headless execution, §5's restricted-surface prerequisite blocks it.
   Do not conflate these two workflows: a read-only check of public shipped docs
   need not perform headless adoption or access legacy consumer instructions.
   Before dispatch, freeze the tiny read-only task, available tools, non-sensitive
   workspace, expected red/green observations and explicit cost authority. This
   plan has not executed or certified that probe. No new generic harness follows.
   Success is concrete and constructible; failure is also retained. Do not claim
   improved completion or lower cost without measuring those separate outcomes.
4. Rebuild all three distributions from source; validate all three; run affected
   suites direct on PS7/PS5.1 with equal nonzero case counts, install smoke in both
   modes, and the normal release verification. Do not run gates against an editing
   tree. .ps1 files retain UTF-8 BOM. No hand edits in dist.
5. Before shipping behavior changes, matching Unreleased entries in root and all
   three stack changelogs, independent implementation review on a frozen diff,
   and release.ps1's normal gates/CI. This design review is not that code review.

## 5. Constraints and stop rules

- No application fix, further paid Copilot run, release or upstream ABP write is
  authorized by the current request for a plan/review. Implementation awaits the
  reviewed decision and user direction.
- No guard/ownership/provenance weakening; no shell/permission bypass; no SDK,
  provider, auth, relay or sandbox engineering. Neither model rank nor budget
  increase is a substitute for satisfying the declared execution contract.
- Before later paid headless execution, establish the existing workflow's required
  restricted surface with observed capability evidence. If unavailable, stop that
  live execution and request a supported human-driven path or explicit new design;
  do not silently downgrade it to ordinary unrestricted agent work.
- Timebox implementation of A/B to a small repair; if it requires new helper
  APIs, a phase runner or instruction-file restructuring, return to scope review.
- Preserve the former evidence, including the operator mistakes. No model ranking,
  efficacy verdict, study closure or new universal compatibility claim follows.

## 6. Adversarial questions / lock criteria

Opus should form a blind-first threat model from this contract, then inspect the
named evidence/source rather than trust this narrative. It may reject the premise.

Does A test the actual instructions rather than a fixture it secretly repairs?
Does B reach the model before the failed read, and merely add more prose without
solving comprehension? Root now has narrow initial-context evidence, not universal
loading or compliance proof. Is A alone the proportionate first delivery? Does the
proposal confuse read limits with total context or token cost? Could phase-scoped
reading omit a safety obligation? Does the current headless host gap preclude
the proposed live validation? Are we proposing a safety/control bypass, inventing
human approval, or treating checkpoint/byte preservation as completion? Is any
claimed evidence actually an unverified self-report?

Require an explicit ACCEPT / REVISE / REJECT with blockers, a smaller alternative
if appropriate, and unverified gaps. Root adjudicates each finding against source.
Record the review, exact frozen plan hash, and resulting decision before design
lock. Record RCA in the existing backlog record: missing schema example and tests
that supplied their own wrapper; no model-consumption proof; operator launch and
receipt errors. Sweep only directly analogous archive instruction examples, not
all Markdown or all host tooling.
