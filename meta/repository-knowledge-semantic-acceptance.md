# Repository-knowledge semantic acceptance

Date: 2026-09-08

This record executes the bounded B-222/B-223 plan in
`.claude/plans/2026-09-08-b222-b223-semantic-acceptance.md`. It is a monorepo-component,
Claude-authoring observation with a restricted tool menu. It is not Copilot or VS Code evidence,
an enterprise-repository sample, a full bootstrap run, or proof that the carrier caused the model's
behaviour.

## Frozen route and limits

- Product source baseline: `c9e259deac55d2c5dcf06291df1504d84eb19e46`; the working product source was unchanged from that
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
