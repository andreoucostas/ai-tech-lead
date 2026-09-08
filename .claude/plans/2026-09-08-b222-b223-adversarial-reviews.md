# B-222/B-223 acceptance plan: adversarial review record

**Date:** 2026-09-08. **Product baseline:** v0.86.0,
`c9e25953e2cdd04c1bc780a5a95ddab5c806b494`.
**Subject:** `.claude/plans/2026-09-08-b222-b223-semantic-acceptance.md`.
**Scope:** the user requested a concrete plan, an adversarial review in a new context, and an
additional Opus adversarial review. These are design reviews; no semantic acceptance trial,
product implementation or release is being certified.

## First review: fresh Codex context

The nonimplementing reviewer `/root/semantic_plan_adversary` was spawned with `fork_turns=none`.
It received the root rules, standing decisions, B-222/B-223 and WSD-074/078/079 first, and was
instructed to form its own threat model before reading the proposed plan. No previous critique or
conversation was supplied. It used the inherited Codex model; the collaboration result does not
provide a separately resolved model identifier, so no more precise identity is claimed.

Initial immutable plan commit: `32aaf7e818b4aac6b76bded83051d0a096d47d03`.
Plan SHA-256: `A1BAF4644FD794884090BCA2B098675707071EA85CB0E71282BBF48E4C3EA402`.
The reviewer reported checking the hash and one-file range, relevant baseline source, and the
retained fixture's Git input listing. Root independently checked the cited source and fixture.

**Initial verdict: REVISE.** The reviewer accepted the premise and proportionality of a bounded
authoring acceptance pass while finding three execution defects and two clarifications:

| Finding | Root source check and correction |
|---|---|
| P1: fixture has no ownership inventory | The retained 15-file input listing contains none; monorepo rebootstrap Shared A8 requires it. Added a complete synthetic inventory with real schema/classifications, populated context/profile prerequisites, and explicit component/full-workflow boundaries. |
| P2: capture write scope and scorer disagree with the workflow | Bootstrap Phase 3a-bis permits a new discovery note and summary-marker replacement. Added one allowed-delta list shared by prompt and scorer, preserving existing entries and all bytes outside the named marker. |
| P2: inherited timeout capture can erase evidence | Root and reviewer read B-41's actual blank-on-timeout branch. Added a concrete restricted-tool supervisor recipe, a per-call deadline, separate native exit/timeout, and retained partial stdout/stderr; no generic harness change. |
| Startup context could escape the read count | Known injected first-party files must be counted; unknown startup content prevents a total-budget PASS. The deliberate budget calls expose Read/Glob only; other calls disclose opaque search/access gaps separately from semantic results. |
| Optional calls had two inconsistent descriptions | Unified the allowance: two total optional calls, for a justified correction or a separately labelled isolated capture case. Original integrated misses remain visible. |

Root supplied source facts during the review and later asked for a delta check; that exchange is
adjudication, not an additional blind reviewer. Revised immutable plan commit:
`071c87597d9d994853a8280200766dd515aa80c5`; SHA-256
`710A55D29CB18A3EBEAA1130021F763897B257259CA5C716769194802E964A5F`.
The reviewer returned **ACCEPT for disposition of its findings**, with no additional correction.
It explicitly did not execute the launcher, fixtures or models. Runtime capability, observer
calibration and semantic outcomes remain unobserved.

## Second review: independent Opus context

The revised plan and 27 supporting files were copied into an external frozen source
packet; root compared every copied file's SHA-256 with its authoring source. The packet includes
no first-review narrative. Its prompt requests an independent threat model from the original
authority before reading the proposal, permits rejection of the premise and asks for minimal
source-grounded corrections. Claude CLI was launched as a new nonpersistent read-only session,
requesting `opus` at xhigh effort, safe/restricted mode, Read/Glob/Grep only, strict MCP config,
no fallback and a USD6 configured limit. The review process has a 15-minute supervisory deadline.

Local raw packet/prompt/stream location:
`%TEMP%\b222-b223-plan-review-20260908-e0143a2811a04244a6360efd7f6891d1`.
Root observed Claude CLI 2.1.260 initialize as **`claude-opus-5`**, session
`5cafcb96-eb8d-4e6b-8907-8cecd755ad14`, with exactly Glob/Grep/Read and `dontAsk` permissions.
It completed with native exit 0, no timeout, terminal `success`, 37 turns and 602,499 ms reported
duration. CLI list-price accounting was USD3.2280665, including USD0.001691 of ancillary Haiku
usage; this is observed CLI accounting, not an invoice or Copilot credits.

Initial Opus prompt SHA-256:
`D805AB4A4E3B4ABB171B0706A304DA7B506BDCC59BBB5521E32208582FFCD4B3`.
Unmodified stream SHA-256:
`982ECA4D354E2B8E01FC4A9594FFFAA771BF6163E1FF19621D4E03934E5172B9`.
Initial source-manifest SHA-256:
`6D57D9997B48307A6B7CDA33C4FD491451B7888988FDCC22F932EB9C6EA2DF06`.

**Initial verdict: REVISE; premise and proportionality accepted.** Root adjudicated its thirteen
findings against the actual source rather than adopting every suggested remedy:

| Opus finding | Verified disposition in the next plan revision |
|---|---|
| F1: fixture membership can leak a discovery answer | Accepted. Retry wiki is R-only; per-call memberships and hashes distinguish raw D inputs, actual C handoff and controlled refresh. The blanket suggestion that no input can state a graded fact is narrowed: raw first-party configuration and an old claim being refreshed are necessary inputs. |
| F2: a single promotion destination can reject defensible capture | Accepted with precision. Predeclare conditional skill/reference or scoped fact/abstention; the latter leaves skill-link acceptance NOT EXERCISED. Source permits unresolved steps, so missing signing evidence does not categorically forbid an operation draft. Duplicate procedures and missing links remain failures. |
| F3: report fidelity is ungraded | Accepted. Required worker fields, observed/reported read sets and counts, per-seed dependency hops and truthful coverage are explicitly compared. Missing report fields and unavailable traces have different dispositions. |
| F4: clean-only mechanical checks omit red/hostile evidence | Accepted obligation; changed the proposed remedy. Generic DocClaims `-RedTest` exercises a demo registry, not the repository-knowledge function. The plan mutates the actual required discovery sentence in a copied DistRoot, requires both native hosts and restored clean, and makes CP437 evidence unconditional. |
| F5: CLI readiness/cap wording is unobservable | Accepted clarification. All flags are now recorded; actual review init/usage/exit and stdin launch are observed. Future Sonnet/write/denial controls remain unrun. Configured monetary limit is not certified enforcement; call count and supervisor time are bounded. |
| F6: entrypoints and preflight boundaries are unclear | Accepted exact paths, parent/worker roles and unavailable-dispatch outcome. Full bootstrap preflight is deliberately outside this component trial; classifier/full-onboarding machinery is not added merely to simulate an excluded workflow. Required ownership/context prerequisites remain. |
| F7: reduced tool menu is an evidence limit | Accepted; explicitly recorded alongside monorepo-only/Claude-only scope. No observation claims to run the complete shipped worker menu or actual Copilot host. |
| F8/F9: ignored decoy can vanish; README names can leak rubric | Accepted. Store inactive ignore rules, verify the full tracked fixture inventory, and distinguish hidden grading/answer-key.md and maintainer README from the neutral actor README. |
| F10: preparation scope has no credible staged bounds | Accepted stage stops and a concrete 45-file recipe. Retained the 180-minute attempt ceiling with partial outcomes rather than claiming a guaranteed completion time or raising it because maxima were added together. Documentation delivery/CI is separately stated. |
| F11: passes do not attribute behavior to the carrier | Accepted explicit attribution limit. Declined the optional retired-carrier comparison: it changes the question and cannot guarantee a red model outcome. No spare-call efficacy comparison is added. |
| F12: required fields conflate wiki and skill schemas | Accepted typed artifact requirements and actual fixture wiki-check before/after calls. Existing deterministic invalid-date/index checks are acknowledged separately from semantics. |
| F13: map presence, old-date warnings and counting basis are unspecified | Accepted no-map fixture, advisory date warnings and conservative B1 count of all repository content reads, with first-party subset reported separately. Topology names alone do not imply warehouse semantics. |

Root corrected two review-record limits explicitly: the packet had **28** files, not the review's
stated 27; and the PK-2 15-input observation was independently obtained from its retained Git commit,
not borrowed from the deleted PK-1 fixture's count. Opus could not inspect that external archive,
several omitted runner/dist files, or CLI behavior; it disclosed those limits and performed no
execution. Root did not convert those unexamined claims into reviewer observations.

The revised plan was frozen at `2ec41616aad17410f4cf2e4743ce70f049672085`, SHA-256
`D131DBE5A6C1AF0FA2E42C6EA0612F20319F84A7AE655FB35AC469BEA07FD274`.
A separate nonpersistent Opus session at high effort checked this delta with a USD3 configured
limit and ten-minute supervisor deadline. It received the earlier findings and root's source
corrections, so it is adjudication, not another independent blind review. Root observed init model
`claude-opus-5`, session `c4bc5a3f-9ba6-4001-b44e-b611056b2913`, the same three read-only tools,
native exit 0, no timeout, terminal success, 18 turns and 203,508 ms reported duration. CLI
list-price accounting was USD1.0948705, including USD0.002212 ancillary Haiku usage. The two
requested Opus review calls total USD4.322937 in observed CLI list-price accounting.
Delta prompt SHA-256: `A872DEF233EAD941FCF2255D4294AED4F25543F2C434ADC1431D38588119758D`.
Delta stream SHA-256: `DD554A9F2751062E880353CD6D73D078D1333F1F72D2CEAFA856284F1042652D`.

**Delta verdict: REVISE two local blockers; acceptable after correction without another independent
review round.** The fresh Codex reviewer independently found the same gate-target blocker and one
report-scope clarification. Root checked the actual harness and CLI help before correcting them:

- `DocClaims -DistRoot` takes one distribution root and hard-labels it `dotnet`, not the parent of
  three dists. The former recipe would fail for a missing file, then never reach clean. The final
  recipe copies **one actual .NET dist**, names `.claude/commands/bootstrap.md` unambiguously,
  observes baseline clean before removal and restored clean after, and does not combine `-RedTest`.
  Opus suggested a monorepo copy plus a label warning; the actual .NET copy removes that avoidable
  attribution mismatch while the normal all-dist checks remain. This proves a mechanical .NET
  carrier boundary, not monorepo semantic behavior.
- Restricted CLI mode may reserve tool-configuration writes even when an ordinary Markdown write
  works. Both C and R-confirm now calibrate an ordinary path **and a `.claude/skills/.../SKILL.md`
  path**, with explicit control-delta authority. A denial is CANNOT-EXAMINE for dependent write
  acceptance, not a product MISS; it does not license permission escalation or more calls.
- The full shipped worker report skeleton applies to actual shared-A8 outputs, including the
  discovery portion of R, not the parent C/R-confirm summaries. Those still require truthful
  evidence and recheck reports; the clarification prevents a false shape failure.

**Final design revision before CI portability correction:** `892c641dbc342cac36c6351d72b5eae60dcb90da`.
SHA-256: `9B1022C19C48397FC419F489DF1B52AB1127BE57C40DD614DB4B502FE6251943`.
The fresh Codex reviewer verified this exact delta and hash and returned **ACCEPT**, explicitly
without runtime acceptance. Root considers Opus's conditional acceptance satisfied by the
source-checked corrections; Opus did not inspect this last revision. No third Opus round or final
exact-byte Opus approval is claimed. The actual corrected gate recipe was then executed as a local
planning control, below. No unresolved design blocker is knowingly handed to the execution model.

## Local planning verification

Root directly checked the retained PK-2 input commit and exact output hash, source ownership schema,
capture/refresh boundaries and both PowerShell examples' syntax. A free local native-process probe
under PS7 7.6.5 / CP65001 observed child exits 7 and 0, then killed a sleeping child after its writes
and observed both `partial-out` and `partial-err` in retained files (termination exit -1). This checks
the supervisor primitives, not a semantic actor or monetary enforcement. No semantic actor fixture was run.
Full CLI help is retained externally as `claude-help.txt`, SHA-256
`95A31820DC2A7B1ADBD197346BAA89A62CDDD14B984079E1FC2AD56D11A97B20`.
On native Windows, root directly invoked PS7 `7.6.5` at
`C:\Program Files\PowerShell\7\pwsh.exe` and PS5.1 `5.1.26100.9278` at
`C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`; neither relaunched the other.
The corrected scratch-.NET DocClaims baseline was 11 passed / 0 failed on each host at CP65001.
At CP437 on each host, deleting the exact budget sentence from the copied command produced
10 passed / 1 failed, exit 1, naming the repository-knowledge carrier omission. Restoring its exact
bytes produced 11 passed / 0 failed, exit 0. The source and restored copy hash was
`8DA293BD21886907E287D2268754B6E61102760C4FF31BBC589C33110C711A14`.
This is an observed red/clean instrument check, not a semantic model trial.

BacklogHygiene was 10 passed / 0 failed on each native host at CP65001. A temporary decision-index
citation to absent `WSD-999` then produced 9 passed / 1 failed, exit 1, on each host at CP437,
specifically naming the unresolved decision id. Removing that control restored 10 passed / 0
failed, exit 0, at CP437 on each host. The original index bytes were restored exactly (SHA-256
`4927AC3D5CC6BBB78963FA12AAC58A9592ACDC08764E73EC7C0E6D6525D749CD`); no index edit remains.
The existing candidate-stale-heading advisories were disclosed, not used to close partial entries.
CP437 invocations used the documented `cmd` boundary with `PSModulePath` cleared and printed
each actual executable, version and output code page. Gate output was inspected unfiltered.
These controls validate their named mechanical/documentation boundaries, not the plan's judgment.
Both PowerShell examples in the final immutable plan parsed with zero errors under each native
host (two examples per host). `git diff --check` passed. No source, generated dist, product version
or release record was changed by this documentation delivery.

## Delivery CI correction and final plan identity

The first documentation push at `f66f1a6bb8db2aa3e118ba31e3911eb71ee263d2` was **red**, not green:
[CI run 34196083936](https://github.com/andreoucostas/ai-tech-lead/actions/runs/34196083936).
All six stack hook jobs passed. Each native meta job failed only RepositoryPrivacy.Tests, which
found one literal account-qualified home path in the plan's launcher example. The parity job then
failed because the two failed meta jobs did not supply their required case manifests. Expected
mutation-failure output from passing suites is not counted as another actual suite failure.

Root had omitted the existing privacy scan from local planning checks. The outgoing check calls
the shipped guard and did not reject this path; it is not the authoring RepositoryPrivacy scan.
The privacy gate did catch the defect in CI. The minimal correction resolves the executable from
`USERPROFILE`, verifies that it is a file, stops if unavailable, and keeps account-qualified runtime
identity in local evidence. No gate, exclusion, allowlist or product behavior was changed.

Root observed the actual unfixed tree's `RepositoryPrivacy.Tests.ps1 -ScanRoot .` fail with the
named plan location on both native hosts at CP437; after correction the same scan exited 0 and
reported clean on each. Both hosts' actual executable/version/code page were recorded. Earlier
immutable review commits still retain the literal account path; this follow-up does **not** rewrite
published Git history or claim history-wide removal. The original failed CI remains in the record.

**Final delivered plan:** `03cec478235f1b248ef8d49dc0d24d80e1e93974`.
SHA-256: `2CCF7B78EAE2120E99B67E0AD01F4710569633440FD13AC8C96FA7F7AFB20C12`.
The fresh Codex reviewer verified the exact portability-only delta and hash and returned ACCEPT;
it did not rerun the root-observed privacy checks. Opus's reviewed design and conditional verdict
remain as described above, not a claimed review of these last bytes. The task contract, actor tool
menu, scoring rules and execution authority did not change.

## Evidence limits

The retained PK-2 output hash and committed input listing were directly inspected during planning.
They do not prove that current carriers correct the historic misses. The original PK-1 input is
documented as deleted. Newly constructed inputs will form a new fixture series, and proposed
scorer controls are not observed red/green worlds until execution. No Copilot observation, CP2
retry, product efficacy claim or product version bump follows from either design verdict.

## Execution-time fixture and evidence review

The authorized execution used one independent Terra reviewer that did not construct or run the
fixtures. It inspected the frozen contract, actual materialized bytes, Git histories, raw typed
events and owner state before each dependent dispatch and again during grading. Its corrections were
re-verified by root rather than accepted as verdict alone.

The reviewer rejected the initial D2 fixture because the caller did not actually bind the config to
the helper; root retained that actor output, corrected only the source edge and ran the separately
labelled optional D case. It later rejected an R-changed fixture whose matching hash covered invalid
literal `$15` JSON, and a second R pair whose semantic bases had 16 unequal Git blobs from different
line-ending normalization. Neither rejected R fixture reached an actor. The final R pair had equal
complete base trees and isolated one-path semantic changes before dispatch.

The same reviewer confirmed the C route's `.claude/skills` write denial made C1/C2 unavailable and
required stopping R-confirm, then independently graded D, R, B and B-continue from matched events
rather than terminal summaries. The final dispositions and exact evidence hashes are retained in
`meta/repository-knowledge-semantic-acceptance.md`. This review establishes evidence integrity for
the bounded series; it does not turn model misses into product defects or supply the unrun host,
stack, Copilot or value outcomes.
