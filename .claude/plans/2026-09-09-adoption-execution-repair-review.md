# Opus design review and root adjudication

Request: product-fix plan plus adversarial Opus review, 2026-09-09. No implementation.
Plan: `2026-09-09-adoption-execution-repair.md` in this directory.
Source baseline: `f589b901b40df0ac1beb8a5aa17aa6d59f8f0307` (v0.86.0).
Review packet: `C:/TEMP/adoption-plan-review-20260909/`, retained outside Git.

## Review identity and evidence

Two fresh Claude CLI 2.1.260 sessions, model claude-opus-5, medium effort, Read only,
restricted/safe mode, no implementation participation, no shell/network tools.
Each began with a frozen plan and then inspected source. This is adversarial
design review, NOT independent implementation/release verification.

- V1 hash: D618342B3966B041CC2469972D48F9C0A8C2342CE5FFB79FD3C445452A12045D.
  Verdict REVISE: A first; question B's reach, scope and evidence.
  Textual verdict was emitted, then CLI ended error_max_budget_usd, exit 1;
  reported cost USD0.6733525 exceeded the USD0.65 soft cap. The reviewer guessed
  source filenames because the packet lacked an exact inventory and could not
  read several supplied files. Treat that pass as coverage-limited, not clean.
- V2 hash: F6791C7580041027D4A369B226E6151A53C85920B2B58599B6DD8260012CD915.
  Supplied exact source filenames/ranges, narrowed scope to product A/B, and added
  root's observed initial-context evidence. Verdict REVISE: A after explicit
  fixture preconditions; B drafted-but-gated, not co-delivered. CLI result success,
  exit 0; reported cost USD0.2955885. Source schema and test-helper claims were
  inspected in this pass. Combined reported review cost USD0.968941.

Frozen snapshots included source-adopt.md, source-bootstrap.md, source-archive.ps1,
source-archive-tests.ps1 and source-rules.md. Neither reviewer executed code or
independently replayed the native session. Root observations remain attributed.
The final plan includes root's adjudicated amendments below; there was no third
review and no unconditional Opus ACCEPT.

## Findings and disposition

1. **Correct prose, not just an adjacent example — accepted.** Both critics
   confirmed Invoke-AaFreeze requires an entries wrapper. The first reviewer
   overstated that the original sentence necessarily caused the model's array:
   root accepts documented ambiguity, not proof of internal model causation.
   Update the sentence and add the exact example in all three stacks.
2. **Label-keyed extraction — clarified.** V1 already proposed a stable local
   label; root made explicit that unrelated fenced/JSON blocks are irrelevant.
   Missing/duplicate labelled example must fail; no generic Markdown parser.
3. **Realistic noncolliding fixture — accepted.** Specify valid unfrozen marker,
   verified prior entries, a real .cursorrules source, no same-path marker entry
   and no archive destination. Test must not repair the extracted example.
   Bare-array mutation must fail through missing-entries exit 3 with no mutation,
   not through a missing-source/invalid-marker/collision accident.
4. **Avoid phase-only reading — accepted.** Proposed B requires complete governing
   instructions, including mode overrides, precedence/early stops, marker lifecycle,
   failure recovery and completion conditions wherever they occur. No skipped
   later-phase safety obligations or bypass of complete-read skill instructions.
5. **Carrier presence — evidence added, claim bounded.** Root inspected initial
   system.message at 10:57:18.351 UTC before the 10:57:21.681 workflow read; it
   contained the carrier reference and unique existing shared rules. This supports
   presence on that native run only, not future paragraph compliance. Opus V2
   accepted this attribution, not a universal capability certification.
6. **Exact carrier placement — accepted.** Candidate B belongs after the shared
   Verification Rules introduction and before verif-rules expansion, outside the
   numbered list. No shipped change yet; compose/mirror checks remain required.
7. **Headless restriction gap — accepted; overbroad inference rejected.** Prior
   native execution did not establish the required denied egress/secret/git-config
   surface. No live headless continuation is licensed by this plan. However a
   read-only retrieval observation of public shipped instructions is not itself
   headless adoption; it need not perform that workflow. V2 already distinguished
   these scopes. Root retains an explicit feasibility/cost/tool-scope decision
   before any such probe, and holds B rather than claiming it validated today.
8. **Smallest delivery and user priority — accepted.** Product A first. B remains
   a separate evidence-gated product proposal. Removed the DEVELOPING.md/operator
   workstream entirely. No runner, relay, model-ranking campaign, new generic
   gate, permission relaxation or workflow bypass.

## Resulting plan

First delivery: schema sentence + labelled runnable JSON example in the three
adopt sources; one bounded doc-example case in the existing archive suite; observed
RED/GREEN and bare-array RED/restore on native PS7/PS5.1; normal compose/install/
release verification and an independent implementation review when code exists.

Second delivery is held: complete-read recovery in the already-used rules carrier,
with exact placement and actual native retrieval evidence before any efficacy or
completion claim. Parser presence does not establish comprehension.

RCA: tests constructed the correct wrapper themselves and did not exercise the
published instructions. A tool error labelled success and an intermediate commit
were over-read as useful evidence. The archive helper's preservation check worked;
it should not be loosened to accept an ambiguous alternative format.

## Delivery A implementation review — 2026-09-09

User subsequently authorized implementation and an Opus handoff. A alone is
implemented for v0.86.1; B remains deferred. Frozen contract SHA-256:
`0D3ADD75A5E66295F33B9B494FDDDB30023C02645FB1CA2B707942ADAF855F2B`.
Immutable range: `f29cc39f70c9a719d46020211d8bc702db570732..afd34867f7c2728af1286d923a7eb39e46492f2e`.
Authored review diff SHA-256: `A9D2783BC6B9598E1B0A8BD8DEBA7EDCEB0C36B9D3CEA89A9ADE3030A87E60F1`.

Fresh Claude CLI 2.1.260 / `claude-opus-5`, Read-only session
`1a0fbd6a-01cb-44d9-bed6-d443219e8b10`, no implementation participation.
Reviewer stated a blind-first threat model before reading the diff and receipts.
Its final text returned **ACCEPT**, no source correctness/contract blockers.
It confirmed raw example execution, scoped extraction, specific bare-array
rejection with unchanged inputs, byte comparisons, unchanged helper and lifecycle,
and proportionality (two new functions in the existing suite, no new runner).

**Do not overstate that result.** The CLI subsequently ended with
`error_max_budget_usd`, exit 1, reported cost USD 0.680585; ACCEPT is the emitted
review text, not a successful CLI result. Its receipt summary incorrectly claimed
both `final-ps*.log` runs were green. Root rejected that claim: the PS5.1 launch
wrapper had injected Stop preference into tests which inspect native stderr.
An earlier installer-only background launch also could not resolve Get-FileHash.
These failed receipts remain retained, not overwritten or counted green.

Root corrected only the external invocation: explicit native PS5.1 module path
and normal direct-file error preference. No frozen source changed. Root then
observed `verified-ps7.log` and `verified-ps51.log`: native PS7 7.6.5 and PS5.1
5.1.26100.9278 respectively, code page 437, **34 archive cases and 8 installer
cases per host, zero final failures, both process exits 0**. Installer cases
exercise greenfield/brownfield across all three distributions. Nested intentional
mutation failures are not final suite failures. Log SHA-256 identities:

- PS7: `B0B647ABD301F8BB9C2B11256FB1E6803C72618289B52DA950E1B7F8AD2ACC85`.
- PS5.1: `C45DBEFFAF8E3E62B3F2DE4C93A3AFDB34C42113C5B4350BE47BBF089C7E7BD9`.

Earlier direct runs observed 27 PASS / 6 missing-example FAIL on both unfixed
hosts, then 33 PASS / 0 FAIL after the documentation repair. The frozen version
adds the unavailable-helper classification case (34 total). Every final run
executes all three bare-array mutations through actual Freeze exit 3 with the
missing-entries diagnostic, asserts unchanged marker/source and no destination,
and then reruns the original document successfully. The existing digest-corruption
mutation also remains observed red and restored. No ABP files were mutated.

Root adjudication of optional points: retain the lean fixture; its empty prior
inventory is valid and the existing nonempty-installer extension case remains.
Missing `verified` cannot make the full case green: actual MoveFrozen/Verify
still validate the inventory. The unavailable-helper case observes the real
failure classification; it was added after the initial missing-example red run,
which is not claimed as its before-state. Root confirmed the matching root
Unreleased changelog in the frozen commit; it was omitted from the initial review
packet, not from implementation. All three source changelogs also match.

Evidence packet: `C:/TEMP/b232-implementation-20260909/`, including exact prompt,
frozen source export, failed and corrected receipts, and selected readable Opus
output (SHA-256 `D83867875293B0CE803523D3A243F458167198D37ACD2B98B0B9242B78F1047E`).
Opus did not execute tests; the corrected host results are root-observed, not
reviewer-executed. Independent source review plus direct native host execution
are the supplied evidence; neither model rank nor CLI exit certifies quality.
Release stamping/composition, normal gates and CI are subsequent promotion steps,
not covered by the frozen source review. No comprehension/adoption-completion or
deferred B claim follows.
