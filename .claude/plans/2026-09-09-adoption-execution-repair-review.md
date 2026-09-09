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
