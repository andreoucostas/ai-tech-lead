# Repository-knowledge semantic acceptance

Date: 2026-09-08

This record executes the bounded B-222/B-223 plan in
`.claude/plans/2026-09-08-b222-b223-semantic-acceptance.md`. It is a monorepo-component,
Claude-authoring observation with a restricted tool menu. It is not Copilot or VS Code evidence,
an enterprise-repository sample, a full bootstrap run, or proof that the carrier caused the model's
behaviour.

## Frozen route and limits

- Product source baseline: `c9e25953e2cdd04c1bc780a5a95ddab5c806b494`; the working product source was unchanged from that
  reviewed baseline during actor execution.
- Installed actor: Claude Code `2.1.260`, resolved model `claude-sonnet-5`, medium effort,
  non-persistent restricted mode, `dontAsk`, strict empty MCP configuration and a USD1 configured
  limit per call.
- External evidence root:
  `%LOCALAPPDATA%\Temp\rk-accept-20260908-91934cfa2f50450fa0fc30e98ed5a109`.
- Six of eight permitted actor calls ran. Reported CLI list-price cost was USD2.4739664. The actor
  stage ran from `2026-09-08T19:34:31.8663371Z` through
  `2026-09-08T20:39:52.3711338Z`, within its 80-minute limit. Every supervised call after the
  first recorded native exit 0, no timeout and empty stderr.
- The first D supervisor crashed after launching the child because its progress formatter contained
  invalid PowerShell. The child still produced a terminal success event and complete typed stream;
  its native process exit is unknown. That gap remains attached only to the first attempt. The
  corrected supervisor recorded PID, native exit and timeout before later calls were accepted.

The committed portable packet is `meta/eval-fixtures/repository-knowledge-acceptance/`. It contains
the recovered-input manifest, raw fixture inputs, prompts and hidden grading key. Bulky JSONL streams,
dynamic Git roots and tool ledgers remain outside Git at the evidence root above. The hashes below
identify the exact observed streams and unmodified terminal reports.

| Attempt | Stream SHA-256 | Report SHA-256 | Cost USD |
|---|---|---|---:|
| D, rejected fixture | `D04B760E0A811FC519614E9DA2BC2F1249140CE85FEE9255D75B265CA1AEDE31` | `2CD87F38BF23C97A7639847DAFE612D49182F28EC6261FEDAEB6768CC7B17467` | 0.3284256 |
| D, corrected fixture | `93C683527DD7A21A349DF99C109EF1BB783B252042D824338E721E93C548CC3B` | `1E8F7132C7AC9106D3D25747089552402F3414D12707F42B57AAFA2A75F60D7C` | 0.3242310 |
| C | `DEA5D21EE03C68F6F58F298777FD2D30A1DB38835485E76C5A7DBD88825F4911` | `A13E8956F3D203ED6F2A8B731C9A1425B61EC8345B8A561DD62341ECEBEB0D0D` | 0.6977010 |
| R | `FADF886CFE929C462BDDB9684D26E2AB63550A85AC584E2AA89BD4DE02EB3EA0` | `7BC22CEC43D21C6243BFAAEC060EDFD601532B6FE19FBAE793F2D8B616444615` | 0.4753962 |
| B | `4847D4F31FC57F8F8354A227A2A1BC2CF8712EA2EEB395F73A2501993668539A` | `A75979BBC482D153A59155ACD24AAB156B68D60735D61EB35F728C4043076FB4` | 0.3541624 |
| B-continue | `22C97EB417625B296DF79521D09476AEE85DB173989F1956651AF2C2199792F4` | `E29EA62363FDE1FE0CB0B1EE529AB812F865191A6E187F67CC85C30BA134C5B1` | 0.2940502 |

## Fixture and observer controls

The content-read observer was calibrated against a successful Read, filename-only Glob, failed
Read, multi-file Grep content and explicitly delimited PowerShell output. It counted five expected
paths. A copied ownership file changed hash under mutation and returned byte-identically after
restoration. The outside-root sentinel was denied and the in-root control succeeded in both D calls.

Independent fixture review found and corrected four preparation defects before relying on their
subject results:

1. The first D retry source did not bind configuration to the helper. The original actor result was
   retained, the source alone was corrected, and one separately labelled optional D rerun followed.
2. The first supervisor failed after child launch. Later calls used a corrected formatter and
   recorded native outcomes.
3. The first R-changed construction wrote literal `$15` and invalid JSON. It was rejected before
   dispatch; its manifest and bytes remain outside actor roots under
   `manifests/R-changed-rejected-invalid-v1.*`.
4. The next R pair had semantically equal worktrees but 16 unequal base Git blobs because the two
   histories used different line-ending normalization. Both histories were rebuilt with
   `core.autocrlf=false`; their complete semantic-base trees compared equal before dispatch.

These are evaluation-construction defects, not product defects. The independent reviewer accepted
each corrected dynamic fixture before its dependent call.

## Adjudicated results

| Row | Disposition | Observed evidence |
|---|---|---|
| D launch controls | PASS | Corrected D had only Glob/Read in its init menu, 31 matched calls, an allowed in-root Read, expected outside-root denial, terminal success and native exit 0. |
| D1 tombstone equality | PASS | The report stated the `<=` equality rejection with the exact source and limited scope. |
| D2 helper and scoped policies | PASS for the required target; report-truth MISS | The corrected report read caller, helper and config and kept admin/self-service separate. It unsupportedly added “three retries past the initial attempt”; no caller defines that lifecycle numbering. |
| D3 unavailable evidence | MISS | Signing remained unresolved and generated output was excluded correctly, but the report described `$LASTEXITCODE` after an arbitrary ScriptBlock as the work's general exit code. |
| D report fidelity | MISS | The typed trace had 29 successful Reads; the report called only 26 “actual” and therefore misstated the remaining budget. It also invented `complete-leased-item.ps1 -> config/lease-policy.json`; the script's direct dependency is external `queue-cli`. |
| C1/C2 | CANNOT-EXAMINE | Ordinary and `docs/` writes worked, but both Writes to the required `.claude/skills/.../SKILL.md` calibration path were denied in `dontAsk` mode. The actor then requested unavailable Bash and retried, contrary to the stop rule. |
| C partial bytes | Retained, not accepted | Only allowed output paths changed and both post-state wiki checks passed. The partial retry and lease drafts nevertheless repeated D's unsupported lifecycle and ScriptBlock claims. |
| R1 changed dependency | PASS | With owner bytes unchanged, the actor reread caller, helper and valid max 5 config and proposed an exact existing-wiki refresh. |
| R2 preapproval integrity | PASS | The trace contained no Write/Edit and both roots remained clean. |
| R2 missing helper | MISS | It proposed the right downgrade shape and preserved `2026-09-01`, but falsely said `RetryPolicy.cs` was absent. The caller file remained; only `RetryBoundary` was removed. |
| R report fidelity | MISS | It omitted required actual-read and hop accounting and made an unsupported repository-wide no-caller claim from filename Globs. |
| R-confirm | CANNOT-EXAMINE without dispatch | The same required skill-path write route was already known unavailable. The plan required stopping dependent write work rather than paying for a predictable denial or widening permission. The valid R-changed proposal remains unapplied. |
| B1 finite boundary | PASS; report-fidelity MISS | The trace contained exactly 40 distinct successful Reads, no 41st and no `.git/**` Read. The report miscounted the 51-file/45-eligible corpus as 52/48, counted two workflow controls as eligible and called a two-edge dependency chain `<=1` hop. |
| B2 continuation | PASS; carry-forward/hop MISS | The second trace read the exact eleven previously unread eligible files plus the prior report, and separately identified two necessary workflow rechecks. The union was all 52 continuation-root files. It repeated B's false eligibility totals and one-hop label. |

No row is converted to success merely because the terminal event succeeded. C/R-confirm route
unavailability is distinct from a semantic failure. The independent reviewer read raw typed events,
source bytes and dynamic manifests rather than accepting actor self-reports.

## Product decision and remaining scope

No product source was changed. The current worker already requires actual read paths, per-seed hop
counts, scoped evidence, unresolved dependencies and bounded continuation. Capture already requires
factual source grounding, and rebootstrap already requires meaningful source rechecks, downgrade on
unavailable evidence and owner confirmation. The observed contradictions are model-compliance or
route-availability misses under this restricted authoring configuration. Rephrasing those same
obligations more loudly would add instruction weight without evidence that it changes behaviour.

B-222 and B-223 remain partially done. This run supplies synthetic monorepo evidence for quiet facts,
the 40-read boundary, continuation, one dependency-triggered refresh and owner preservation. It does
not supply a successful skill/reference capture route, confirmed refresh application, correct
missing-helper report, other-stack model behaviour, full shipped tool-menu behaviour, Copilot/VS Code
acceptance, enterprise coverage or value evidence.

## Verification

Direct PS7 `7.6.5` and Windows PowerShell `5.1.26100.9278` runs each reported:

- DocClaims: 11 passed, 0 failed;
- BacklogHygiene: 10 passed, 0 failed, with the existing advisory candidate-stale headings;
- RepositoryPrivacy: clean;
- WikiCheck for dotnet, angular and monorepo: 17 passed, 0 failed per distribution.

The materialized C wiki state passed `scripts/wiki-check.ps1` under both hosts before and after the
call. Both final R roots passed under both hosts with the disclosed advisory body-injection warning
on the synthetic owner's “must remain available” wording.

The execution also repeated the actual .NET carrier mutation through CP437 on both native hosts.
The copied distribution first passed DocClaims 11/0. Removing only
`Read at most 40 distinct content files and follow at most two additional dependency hops per selected seed.`
then produced the named repository-knowledge carrier omission at 10/1 and exit 1 on both hosts.
Restoring the exact bytes returned 11/0 and exit 0. The source/restored carrier SHA-256 was
`8DA293BD21886907E287D2268754B6E61102760C4FF31BBC589C33110C711A14`; the mutated hash was
`DF841F7C58A45F4D6CDF26AD618008525D268A50B7A151FCDE5E09215544A8F2`.
An earlier wrapper attempt captured its function output into the exit-code assignment and was void;
it restored the same source hash before the valid rerun.

## Delivery RCA

Existing parser and document gates can prove carrier shape, not model adherence or an ad hoc
fixture's semantic validity. That is why incorrect actor read/hop accounting, over-broad source
claims, destination-specific write denial, invalid prepared JSON and line-ending-divergent Git
histories were all possible while the shipped distributions remained well formed. Independent
fixture review and typed-event/byte observers caught the concrete cases. The same exposure applies
to every prose-directed workflow evaluated through a restricted model route: a terminal success is
not semantic success, and hash agreement is not proof that the hashed input represents the intended
world. The bounded response is to retain these observations and route limits; no generic gate or
new evaluation harness is justified by this single synthetic series.

## Targeted safe-write follow-up

The original C and R-confirm dispositions depended on a write route that could not exercise
`.claude/skills`. The authorized follow-up tested only that route and the two affected cases. Its
external evidence root is
`%LOCALAPPDATA%\Temp\rk-accept-followup-0fac767d5abf42129bea5def81431182`.
During this audit, `git cat-file` also exposed a one-character typo in the original result record's
product baseline. The corrected value above is the existing plan baseline commit
`c9e25953e2cdd04c1bc780a5a95ddab5c806b494`; no execution input or product source changed.

### Route development and retained evidence

The first calibration tried to use an MCP permission handler while retaining direct CLI
`--safe-mode --restricted`. Safe mode exposed no MCP server, so the first Write failed before any
terminal result. A second calibration and initial C/R-confirm observations proved that the handler
worked only after safe mode was removed. Independent review rejected those observations for
acceptance because they violated the frozen route. They remain route-development evidence only.

The accepted route used `@anthropic-ai/claude-agent-sdk` 0.3.265 with a host `canUseTool` callback.
The frozen runner supplied `--safe-mode`, `--restricted`, strict MCP configuration, disabled slash
commands and session persistence, empty setting sources, and the installed Claude executable. Init
events reported Claude Code 2.1.260, `claude-sonnet-5`, the requested tools, and no MCP servers,
skills, plugins or slash commands. The SDK init event does not echo the accepted safe/restricted
flags, so their presence is configuration-source evidence from the retained runner rather than an
argv receipt. Runner SHA-256 is
`8AE3E31EBA9DCD9EF2D1F8FD6841098DA1C4141C0DF5530F0A6165D704B8E4C6`; write-policy SHA-256 is
`94DA205F35169CCEFA2F0AB19312AD508F69CC19FFF15876189BB71F657DD091`.

The policy self-test observed both calibration paths allowed, an unauthorized in-root path denied,
an outside-root path denied, C skill/reference paths allowed, `CLAUDE.md` denied, the exact R target
allowed and another wiki path denied. Its source SHA-256 is
`D00E1140B1A891E6D22C080B0158EF3226BCF25DD8EC90EBBF376E461CA0D64A`.
The SDK warned in C/R-confirm that bare Read/Glob/Grep allowances bypass `canUseTool`; this did not
weaken the measured write boundary because Write/Edit were deliberately omitted from that list and
continued through the callback. Restricted mode remained the read boundary.

| Attempt | Acceptance use | Stream SHA-256 | Terminal-report SHA-256 | Cost USD |
|---|---|---|---|---:|
| 01 direct safe calibration | Rejected: safe mode exposed no MCP permission tool; exit 1, no terminal result | `173552B08DD14415CC91C245A5FE9AED374CD3B5F8D05711F4C1FFCE2C9DB257` | unavailable | unknown |
| 02 direct calibration without safe mode | Route development only | `1FBDC95E93D5DA170AC8599FB58ED6316DCFB7007873E09017D50570AB6A32B2` | `283E4301988C0F22D3E6C2C7D0C66568821489AD0B9303C8069B4F4243B520FA` | 0.0095914 |
| 03 C without safe mode | Rejected by review | `59A7C1F6F70881705FE804F4CB31DD20A6081590E193037D8F95CADAEB60F133` | `CBDF0C295B403FC36C4202B9B100AFA1E21090F235C73ED639FE3FC4205B647E` | 0.6074244 |
| 04 R-confirm without safe mode | Rejected by review | `EFB7EE11498311B158B335F06CDA451748932FC4CFF2C8C9B47C322EB56F14A4` | `6B76ED175B3480E972FEB1C5C515A9E3ABD8BB9E1CD7E9CFB59C5326D5675A1A` | 0.1727254 |
| 05 SDK safe calibration | Accepted route control | `F4EF98AD4B782CFC84764430B2A67522AE7222F47F24239DD96D0257CCFA6947` | `B79F9EACA70A7EFA247B31C7B322AD9AE737ABF81E9F153F3AF680F8F9A30C34` | 0.0146650 |
| 06 SDK safe C | Accepted semantic attempt | `2F222152583BDA7DFC8F08A93C5210C3B615B9C33D88A2F096984AECE406D48E` | `9DA1C48B6FD8BE727E2BE1DFF6DA720F981FB895F98F267D3C4AAD56CB57586A` | 0.5779914 |
| 07 SDK safe R-confirm | Accepted semantic attempt | `50415C361E59848CA3E11BE01D2CB25893A4CD654DB45F26AFCC8B9C1D6CCB53` | `AF66080313E81C27855044830B79869DC38BC1C29C92BB54091ED6896DAE05E7` | 0.1554104 |

Attempts 02-07 ended without timeout, with native exit 0 and terminal success. Attempts 06 and 07
each emitted only the disclosed 485-byte SDK warning on stderr. Known follow-up list-price
accounting is USD1.5378080: USD0.7897412 for rejected no-safe development attempts and USD0.7480668
for the accepted safe route. Including the original series, known accounting is USD4.0117744 plus
attempt 01's unavailable usage. These are observed tool reports, not invoice claims.

One R-confirm approval record was rejected before actor dispatch because its PowerShell
construction left literal hash variable names. Root retained that invalid control externally,
rebuilt the approval, verified `git apply --check`, applied it to a copy, observed the exact approved
postimage, restored the target and then dispatched only the corrected fixture. The corrected
approval, patch, preimage and postimage SHA-256 values are respectively
`FC0B7BF114A11E38635EC3109D111EDEA091341FF2A0E7B9815629AF1F3083B7`,
`878D972CF0FA5D67F665170BFDFAACC27B70E2A13739E56C893E29F25BF54DF5`,
`BF61D5436480D7595A4B2C0818B255EBDCE2673F85ED3D25C2F0AECC9F20DB59` and
`4323A85DC3A4CD590794FF345774EDCBA73B315691F5E0C4D67BA103BA2F928D`.

### Follow-up adjudication

The safe calibration created exactly the ordinary and skill-path sentinels. Attempt 06 then
recorded eight Writes and three Edits, all allowed by the path callback; its permission ledger
SHA-256 is `21000D1CF016251A92E65B82FEB43ADD4F94949D6D38B0986E44B60DC6A7AA61`.
Against the 33-file premanifest, 31 pre-existing files remained byte-identical, `docs/wiki/INDEX.md`
and `FRAMEWORK-CONTEXT.md` changed, and exactly eight permitted files were added.

| Follow-up row | Disposition | Observed evidence |
|---|---|---|
| C write route | PASS | Both required controls and every capture write succeeded through the safe/restricted SDK route; no path outside the frozen set changed. |
| C1 skill/reference | NOT EXERCISED | No substantive skill or linked reference was created. The promotion finding remained a scoped fact with external signing unresolved, which the frozen alternative permits without manufacturing an operation skill. |
| C path/owner-byte preservation | PASS | Owner bytes were preserved, five suspected wiki drafts were indexed, the security-sensitive bypass was routed to its owner, and no wiki/skill duplicate was made. This is a narrower subfinding, not a C2 pass. |
| C2 overall | MISS | The marker replacement occupied 13 lines despite the 12-line cap. The parent read no decisive first-party source, then repeated the report's unsupported “three retries past the initial attempt”, generalized `$LASTEXITCODE` after an arbitrary ScriptBlock, asserted external queue retry ownership, and cited generated/test material it had not read. |
| R-confirm source recheck | PASS in isolation | The actor reread the retained claim, caller/helper, changed configuration, exact approval and patch, correctly observing the unchanged binding and strict `<` predicate with maximum 5. |
| R-confirm application and controls | MISS | It made no Write/Edit request, created neither calibration file and refused the exact owner-approved patch, asking for the same approval again. The complete 40-file tree stayed byte-identical to premanifest SHA-256 `C5C6E0F81ED56CCA82EE1E0FA45BD4B2264D12CEE7857D3F0A8BABB7BF7D2AC7`. This is an authority/application miss, not CANNOT-EXAMINE: the safe route had already exercised both write classes and no write was denied. |

The independent Terra reviewer inspected the frozen contract, runner/policy, raw streams, write
ledgers, premanifests and post-state bytes. It found the 13-line C summary and confirmed the C and
R-confirm dispositions above. Attempt 07 created no permission ledger; the similarly named earlier
ledger belongs to rejected attempt 04 and cannot establish a per-call decision for attempt 07.

No product source changed. Grounded capture, the 12-line cap, scoped uncertainty and owner
confirmation are already explicit in the current carrier or actor request. These observations show
noncompliance with those obligations, not an absent instruction whose duplication would be a
proportionate correction. B-222/B-223 remain partially done: the safe write path is now observed,
but operation skill/reference capture was not exercised, factual capture missed grounding/truth,
and the confirmed refresh was semantically supported but not applied.

### Follow-up delivery verification

Direct PS7 7.6.5 and Windows PowerShell 5.1.26100.9278 runs each reported DocClaims 11/0,
BacklogHygiene 10/0 and RepositoryPrivacy 7/0. WikiCheck reported 17/0 for each of dotnet, angular
and monorepo under each host. The backlog suite retained its existing advisory candidate-stale
headings without closing them. The C and R-confirm materialized wiki states also passed their
before/after direct-host checks; R-confirm retained the disclosed body-injection advisory on the
synthetic owner's wording. The authoring diff changed no `src/` or `dist/` file and needs no product
version or changelog entry.

### Follow-up RCA

The original direct route coupled safe mode to an MCP permission handler that safe mode itself made
unavailable. The parser, wiki and document gates cannot detect launcher-capability conflicts,
whether a model reread decisive evidence, or whether it honored exact current owner authority.
Route calibration and independent raw-event/byte review separated those conditions: attempt 05
proved the two write classes, attempt 06 exposed semantic overclaims behind successful writes, and
attempt 07 exposed refusal behind terminal success. The same exposure applies to any prose-directed
workflow whose host permission channel differs from its model-visible evidence. The bounded response
is this retained route and semantic evidence; one synthetic follow-up does not justify a new generic
harness or another copy of requirements already present.

## Reporting overlay — Sonnet component observation (2026-09-10)

The user authorized Sonnet implementation, with Sol only if Sonnet exhausted its usage. Sonnet
implemented the optional reporting overlay and prompts under the existing fixture family. No
Sonnet quota failure occurred. Root applied the final mechanical corrections to evidence-removal
wording and unspecified SQL collation. The authoring baseline is
`497663e9f405ef4cf123e03ada71f656aec0b24f`, framework v0.86.4. All 79 historical fixture input files
were compared as raw Git blob bytes and remain identical; historical prompts and `src/`/`dist/`
are unchanged. The execution lock and Opus adjudication are in
`.claude/plans/2026-09-10-reporting-knowledge-coverage.md`.

### Identities, route and frozen evidence

| Work | Separate CLI session | Model-reported USD |
|---|---|---:|
| Source diagnosis, Sonnet | `da85fe3f-e09e-4269-a3a4-74e647a1ecfa` | 0.9514248 |
| Fixture implementation, Sonnet | `ec309aa8-eb22-41ec-9623-acf7148af52c` | 1.0163302 |
| Adversarial fixture review, Opus | `31c01e0a-4796-4909-9358-2fe91063764e` | 0.7303325 |
| Fixture corrections, Sonnet | `4ce5d2a1-27cd-4055-adfa-946dd3d416bf` | 0.6768962 |
| Capture actor, Sonnet | `4e30845a-6c6d-4629-821b-755dfe1aa491` | 0.5684634 |

All five terminal results reported `is_error: false` and native exit 0. The capture init identifies
`claude-sonnet-5`, Claude Code 2.1.260, `dontAsk`, and exactly Read/Glob/Grep/Write/Edit. It used
safe/restricted mode, no session persistence, no execution tools, unchanged composed framework
rules supplied as system guidance, a USD3 CLI ceiling and a 600-second process deadline. It
finished in 251026 ms without timeout. This was direct CLI, not the earlier SDK route, a full
bootstrap, automatic host instruction discovery, Copilot or VS Code. No SQL engine ran.

The actor root contained 39 files: historical base plus the four-file reporting overlay, seven
current composed monorepo carriers and updated ownership rows. The neutral synthetic input commit
was `a20bc65b47ce99cce2bd614d6a8d1685e139798a`. The actor received tracked-path metadata but no
grader, review, prior transcript or precomputed reporting wiki. Raw outputs and construction
records are outside Git at `$env:TEMP/ai-tech-lead-report-implementation-20260910`.

| Evidence | SHA-256 |
|---|---|
| Frozen grader | `EEC53A8BC8AA896EE2A64F50B6A7368E25DE84F1A557CB78D82DD92922F06911` |
| Contract manifest | `812544FF99AD237F65C3AEEFAD52CE9A9F0FCE5B320C9407F281D8BBF066A345` |
| Materialization manifest | `15D3308604A2BA42AA756D9583AB6EA8864469B9D147A6DCEDC0FA3AE5A1B221` |
| Before manifest | `8567DE0CC71FF753D9200324FE2695FD8D27F904BC23F884A736F0652B166B76` |
| Raw capture stream | `DF7EAE33A35097C197A3132EDB78CE091C47545967A3E67C5027B04E04870A06` |
| After manifest | `D8F38B768C91379BFFFF55E7296F993C480A1F45520A79D9104EB9B27E631363` |
| Valid stream with wrapper read pair removed | `0D08CC47E9F03B0D4D7B5BB43434152881ED98F7F33E281486B597C29F1BFF96` |

### Direct observations

The existing `Read-Transcript` / `Get-TranscriptEvidence` functions, copied unchanged into the
external supervisor, accepted the completed stream. Root inspected matched returned content:
14 successful distinct-file Reads (including each of the three SQL bodies once), one expected
outside-root Read denial, one Glob, four Writes and one Edit. There were **no Grep calls**.
The in-root read/write calibration succeeded. The only denial was the harmless outside-root
control; it was not retried. This is usable access with observable content, not cannot-examine.

The actor added three wiki drafts and the calibration file and edited INDEX. Of 39 pre-existing
files, 38 remained byte-identical; INDEX retained its original owner entry. No file was deleted.
The drafts described the net figure, the caller's temporary table and the external adjustment
dependency, and marked themselves pending PR review. The post-state format passed the shipped
wiki checker on both native hosts. These observations establish successful file routing and
preservation; they do not by themselves establish semantic capture correctness.

The independent Codex reviewer inspected the corrected fixture before dispatch and returned no
remaining blocker at the frozen grader hash above. Its post-run semantic adjudication and root's
delivery checks follow below.

### Semantic adjudication and stop decision

Root and the independent Codex reviewer inspected actual SQL bodies, returned tool content,
post-state bytes and the frozen grader. The reviewer confirmed all 43 post-state file hashes
against disk and the permitted changes above.

| Row | Disposition | Evidence and limit |
|---|---|---|
| RPT-D1 | PASS | Actual caller `1` and callee default `0` both stated, supported by complete source Reads. |
| RPT-D2 | MISS | Scope ownership and all three predicates were found, but the figure draft says only literal `Draft` is excluded and every other status contributes. The fixture specifies no collation; that literal-only inference is unjustified. |
| RPT-D3 | PASS | The invoked helper subtracts tax from gross inside the per-category base aggregate; all decisive code was returned. This says nothing about the complete external-adjusted report. |
| RPT-D4 | MISS | The call and unknown external behavior were recognized, but the description/INDEX say the entry point “always emits external adjustments”. Invocation is not evidence of emitted adjustments. Global absence/caller/test claims also exceed the inspected content. |
| RPT-C1 routing/envelope/preservation | PASS as subchecks | Three indexed drafts, required metadata/body fields, pending-review labels and permitted changes; native wiki format checks passed. |
| Capture overall | MISS | Durable overclaims remain in the wiki and INDEX. Format validity is insufficient for a conforming retained-knowledge fixture. |
| RPT-R1 / wiki reuse | NOT DISPATCHED | The frozen stop rule applies after invalid capture. No silent repair, supplied-wiki substitution, semantic retry or reuse-control result is claimed. |

SQL string comparisons depend on collation; a compatible case-insensitive deployment can compare
`Draft` and `draft` equally. The frozen D2 key already retained this uncertainty. This conclusion
is source/documentation reasoning, not an executed database case. See Microsoft's
[collation precedence](https://learn.microsoft.com/en-us/sql/t-sql/statements/collation-precedence-transact-sql?view=sql-server-ver17)
and [case sensitivity documentation](https://learn.microsoft.com/en-us/ef/core/miscellaneous/collations-and-case-sensitivity).
The nested temporary-table interpretation follows Microsoft's
[CREATE TABLE documentation](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-table-transact-sql?view=sql-server-ver17).

The only Glob returned 100 of 125 matches, explicitly including Git internals and a truncation
notice. The user prompt supplied a complete tracked-path inventory, so filenames were available;
neither inventory constitutes a semantic search of the unread caller/test trees. Nevertheless the
final report states that a grep of first-party trees found no callers. No Grep event exists.
Its repeated-read narration is also not an observed repeated tool access: each SQL file was Read
once. Absence of a second Read alone does not prove no internal semantic recheck occurred and was
not used to invalidate every verified source claim. The decisive misses are the durable overclaims
and invented search, not an unobservable model thought process.

### Controls and delivery verification

The independent reviewer checked the evidence-removal copy: original 21 tool uses/results,
mutant 20/20, no orphans. Raw wrapper Read pair at JSONL lines 39–40 was removed; no equivalent
Grep existed. The final 10395-character answer remained identical. Required wrapper-content
evidence went 1 → 0 → 1 on original, mutant and restored original; its grade became observed
not-read / unsupported, not cannot-examine. D1's separate actual-caller paragraph mutation changed
the explicit `1` into reliance on default `0`: independent semantic grading was
PASS → INVALID → PASS. These controls validate the narrow D1/evidence distinctions; they do not
turn the overall capture miss green or establish a retrieval result.

Native PS7 7.6.5 and PS5.1 5.1.26100.9444, both at output code page 65001, each observed wiki
baseline 0, copied verified/never defect 1 with the specific invalid-date diagnosis, restoration 0,
and actual capture post-state 0. The processes reported their own executable paths and versions;
neither host relaunched the other. Direct authoring checks on both native hosts then reported
DocClaims 11/0, BacklogHygiene 10/0 and RepositoryPrivacy 7/0, each exit 0. The existing backlog
dangling-pointer control identified missing B-999 with exit 1 on each host, followed by a clean
10/0 rerun. `git diff --check` passed and HEAD stayed at the baseline throughout verification.
Normal push/CI is observed separately after the delivery commit; these local checks do not
override the semantic miss.

### Reporting RCA

The authoring gates verify structure and bytes; they cannot establish that an agent performed a
narrated search, preserved a SQL comparison's environment dependence, or kept a title as narrow
as its body. Raw event review and scoped source counterexamples exposed these failures despite
successful writes and green wiki checks. Adjacent exposure includes generated map summaries,
INDEX descriptions, source-absence claims and project references. Existing verification,
grounding and unresolved-evidence rules already prohibit these overclaims, so this observation
supports no additional product instruction, catalogue or migration contract. The bounded fixture
and failed result are delivered; B-222/B-223/B-224 retain the unresolved behavioral work.
