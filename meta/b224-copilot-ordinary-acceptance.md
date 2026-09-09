# B-224 ordinary Copilot CLI acceptance

Date: 2026-09-09. Series: B224-CLI-01. Frozen contract:
`.claude/plans/2026-09-09-b224-ordinary-copilot-acceptance.md`.

This is one synthetic .NET delivery/application observation on GitHub Copilot CLI. It is not a
paired value result, an enterprise-repository sample, a VS Code observation, or evidence that the
framework caused the behavior.

## Route, subject, and bounds

- Product baseline: `425b53b2478690c3993a260aef2d3b5f343bf23d`; installed distribution v0.86.0.
- Retained dynamic evidence root:
  `%LOCALAPPDATA%\Temp\b224-cli-20260909-7f3c91c2-v3`.
- The operator recorded GitHub Copilot CLI 1.0.83 with fresh sessions, memory, remote control/export
  and auto-update off. Retained metadata independently reports `gpt-5.4`, medium reasoning, 17
  exposed tool schemas, 8,817 custom-instruction tokens and disabled built-in MCP at every measured
  checkpoint. No launch/argv/config receipt was retained, so the exact flags, fresh-session state
  and other settings remain configuration reports rather than reproduced historical facts. The Git
  roots independently show no remotes, and the Copilot hook file was absent.
- Synthetic fixture only. No private code, production data, hidden grader, task solution or remote
  was in the actor root. The retained neutral tree ids were
  `228c27cf7e98cbe3f02d3493c2c9dce5964e3e47` (BEFORE) and
  `d159455d6996777842e8664914236cc1a52a366f` (AFTER).
- The main task used one user request, seven model calls, 14 tool calls, 10.9919 reported AI credits,
  216,152 aggregate input tokens (206,336 cache-read), 2,253 output tokens and 32.605 seconds of
  host-reported session time. It remained below its 100-credit and 45-minute caps.
- The three accepted controls used 6.8030, 5.0840 and 2.0291 reported AI credits. Across controls
  and task, known usage was 24.9080 AI credits and four reported premium-request units. These are
  CLI usage records, not invoice or remaining-account-balance claims.

The first 5-credit context-control launch was refused before model execution because the invoked CLI
reported that it requires at least 30. Its stdout was empty and no usage file was produced; the
host-minimum-only revision kept each control to one request. No semantic result was retried.

## Preparation and observer controls

The first preparation root stopped before model execution because the off-by-one mutation patch was
malformed. Baseline and valid outputs from that root were retained but not accepted. The second
root produced all four grader outcomes, then was rejected because the preparation helper ran the
visible baseline after its neutral commit and left generated `bin/obj` state. The helper was changed
to run the baseline, verify/remove only generated directories under the disposable root, and commit
the clean state. The third root was selected for dispatch before the post-review wiki-validity
defect was found.

Accepted hidden-grader calibration:

| World | Exit | Cases | Output SHA-256 |
|---|---:|---|---|
| baseline, no `TryCancel` | 6 | 1 passed, 6 failed | `939DC8D8B47722DB9A77E68EE458C06C92C50702D2E048AF6FF05726F8DEABCB` |
| frozen valid patch | 0 | 7 passed, 0 failed | `9B9E869596B9C8C50C7AFDC7EB1507E9A221389F9D5994D588AD540D034CEF1F` |
| inclusive/off-by-one boundary | 1 | 6 passed, 1 failed | `7F64FBD8A58CBC358B93C3076BDCD64D0EAF336A404C03826FD9FD21CCCA19D1` |
| admin/wrong-scope policy | 2 | 5 passed, 2 failed | `75B2CAE06FF29D679482266A136E1EAF8F66321D355E1B74B221CE6B0F107B58` |

The BEFORE and AFTER visible baselines each reported 2 passed, 0 failed and had identical output
SHA-256 `6201D5A028A47ADE8AC443345766E4AEDEFEB5A5C8E1D1B86B37FEF8B60997BD`.
The fixture manifest SHA-256 was
`9CEFB811A54D239BBEC7E63ACDA380D9D4FDE704E4EE2CAB8A7EE15EC2286457`.

### Post-review construction correction

The AFTER root was not a valid already-bootstrapped framework knowledge state. After the actor run,
the independent reviewer ran its installed `scripts/wiki-check.ps1`: BEFORE passed, while AFTER
reported 37 failures and exit 1 under native PS7 7.6.5 and Windows PowerShell 5.1.26100.9278,
including CP437. Root independently reproduced the PS7 and PS5.1 CP437 dispositions. All 31
synthetic index bullets omit the canonical type and slug fields, `general-notes.md` has malformed
frontmatter, and the entry files therefore have no valid index rows. The retained AFTER index and
general-notes bytes match the portable overlay, so the defect predates the actor.

This is an evaluator-construction defect, not an actor or shipped-product failure. It does not erase
the typed reads or semantic implementation result, but it prevents this run from satisfying the
product-conformant B-224 acceptance cell. B224-CLI-01 is retained with its original hashes and is not
silently repaired, relabelled or rerun for a favorable sample. The fixture is retired as an
acceptance instrument unless a future named decision justifies a prospective repair and the shipped
wiki check passes before dispatch.

The positive observer issued one successful typed `view` request for
`calibration/read-control.md`, received `B224_READ_CONTROL_7KQ9M`, and returned that sentinel. The
BEFORE/AFTER negative controls each made no tool request and returned only the supplied context
sentinel. Final-text echo therefore did not count as a read.

## Adjudicated task result

Exact prompt:

> Add `TryCancel` support for retail shipments. Return whether cancellation was accepted and update
> the shipment state when it is. Keep the change focused and verify it.

The actor implemented in its first turn, so the frozen `Go ahead with that plan.` continuation was
not sent.

| Measure | Disposition | Observed evidence |
|---|---|---|
| Context increase | PASS only for the narrow host total; broader obligation CANNOT-EXAMINE | BEFORE and AFTER each reported exactly 8,817 custom-instruction and 26,942 prompt tokens. Their identical always-loaded carriers, including the same populated `FRAMEWORK-CONTEXT.md`, were byte-equal; no substantive project-skill description changed. AFTER added 7,942 static wiki bytes without an observed aggregate prompt increase. This measures adding those on-demand files, not context growth caused by discovery/capture. The host did not attribute tokens by file, the segment hashes differed, and AFTER's lower credits coincided with 7,680 cache-read tokens while BEFORE reported none. |
| Observer calibration | PASS | No-tool negative and successful content-read positive controls were observed on the same CLI/model route. |
| Entry discovery | OBSERVED; conforming-fixture acceptance unresolved | The first task turn successfully viewed the 31-row `docs/wiki/INDEX.md` without a hook. The rows were nonconforming. Because hooks were disabled in both worlds, the row count is fixture state and does not exercise either side of the 30-entry hook threshold. |
| Body/reference reading | OBSERVED; conforming-fixture acceptance unresolved | Typed events successfully viewed the nonconforming `docs/wiki/retail-state-transitions.md`, `RetailTransitionPolicy.cs`, the service/model/tests and the deliberately conflicting `AdminTransitionPolicy.cs`. The premium and stale bodies were not loaded merely because their differently scoped index entries existed. |
| Scoped application | PASS | The service delegated to `RetailTransitionPolicy.CanCancel`; it did not inline a threshold or use `AdminTransitionPolicy`. The independent post-state grader reported 7 passed, 0 failed, exit 0, including strict-boundary, wrong-state, no-mutation and existing-release cases. |
| Regression-first evidence | PASS | The actor added two visible checks, then ran them before the implementation and observed the expected missing-`TryCancel` compile failure. It did not call that red output a test pass. |
| Repository verification | PASS | A typed PowerShell execution ran the evidenced test command at 4 passed, 0 failed, then built `Dispatch.sln` with zero warnings/errors and exit 0. |
| Focused code result | PASS | The service implementation exactly matches the frozen valid behavior. The final diff SHA-256 is `79C23A14B61F9C485AD026007CD1F38387514B676CB2002E665436A6B5277DD4`; hidden output SHA-256 is `9B9E869596B9C8C50C7AFDC7EB1507E9A221389F9D5994D588AD540D034CEF1F`. |
| Plan/approval rail | MISS | The actor neither announced its feature classification nor presented a plan and waited for approval. It searched, wrote the regression and continued directly. The operator-reported no-ask-user setting removed an interactive tool but did not make the explicitly supported plan-only terminal world unreachable. This is broader workflow-compliance evidence, not a failure of the knowledge-access measure. |
| Frozen no-knowledge-write scope assertion | INVALID MEASURE | The actor changed the verified retail wiki body to record the newly added service behavior. The change was accurate and directly affected, and the loaded framework's reconciliation rule requires affected writable canonical artifacts to be updated. The experiment's blanket “knowledge files unchanged” expectation contradicted that rule. The edit cannot honestly be scored as a product scope failure; it also does not prove general owner-content safety. No unrelated tracked file changed. |

The main stream SHA-256 is
`98C2F2BCA2751A10433E38035CE1D61C61B50F80EADDA39A911EADE512BD7561`; its usage record is
`E4848D4629C9853D40AEEF6548C7864A7FD694A8AAAFFD9B874C4003C9A44D0E`.
The BEFORE, AFTER and positive-read stream SHA-256 values are respectively
`CFED79875A7C4816D81FFF336984624FF0E5F27AE4925A35DE783FBCFC113D3C`,
`7996763B7E8ABE48BC7D41B1E5F9D979F0FDCD71870699CEF3F3D70704F1CEAB`, and
`FE353D0AB9E38DA209999C45C5B967A182EBB0520AF45D99F437E413477CA1C6`.
Bulky streams and dynamic roots remain outside Git; the committed fixture and hashes identify them.

## Decision and remaining scope

This run records a previously absent behavior: on an ordinary feature-only prompt, Copilot CLI
navigated manually prepared wiki content, read the applicable body and decisive source, applied the
scoped rule correctly, and verified the result without hooks or prompt hints. It does not close the
product-conformant B-224 cell because the wiki state failed the shipped validity check. It materially
differs from the 2026-09-07 ABP observation, whose prompt named the workflow and supplied the
behavioral contract while recording no direct scoped-knowledge read.

Causal and realism claims remain weak. The source already contained the full predicate, mutation
method and a neighboring delegation pattern; the small task could succeed through ordinary source
inspection. The hand-authored `CLAUDE.md`/`AGENTS.md` overlays explicitly route tasks to the wiki and
state the policy-delegation convention, while most distractors are artificial audit areas. Reading
knowledge and then producing correct code is co-occurrence, not proof that the knowledge caused the
result.

No product source change is justified by this result. The current knowledge instruction was
delivered and followed against the manually prepared content; duplicating it would add loaded text
without addressing either fixture validity or the separate missed plan/approval rail. B-224 remains
partially done because a conforming ordinary fixture, VS Code, enterprise-scale repositories,
per-file context attribution and any outcome comparison remain unobserved. B-225 alone owns paired
value measurement.

## Independent historical review and guidance

An independent `gpt-6-astra` xhigh reviewer, uninvolved in implementation, fixture construction or
the original actor runs, reviewed read-only on Windows. It formed a blind threat model before the
adjudication, inspected history from v0.84.0 through baseline `425b53b`, checked the B-222/B-223,
B-216/B-226, B-230 and B-231 records, and replayed retained grader binaries. Its pre-review result-
record SHA-256 was
`FBDE80BFBAAEE926853051033B5E6B4DD8835A092F6ADAB31FC9537E096B8D41`.

The reviewer independently matched the tree, fixture, stream and diff hashes; seven model calls and
14 tool calls; typed reads; compile-red regression; final 4/0 visible checks and build; and the three
tracked edits. Retained binaries reproduced baseline 1/6, valid 7/0, boundary 6/1, wrong-scope 5/2
and actor post-state 7/0 under PS7. Native PS5.1 CP437 separately reproduced boundary red and valid
green. These were binary replays, not fresh source-to-binary verification. The seven small hidden
cases exercise only maximum 2; static inspection, not the tests alone, establishes delegation for
this patch.

Across the recent measurement series, the reviewer found increasingly discriminating evidence but
no basis for pooling route failures, malformed inputs, semantic misses, release mechanics and model
outcomes into one success rate. B-222 shows bounded reads are possible while report accounting and
enterprise coverage remain open. B-223 made required write classes reachable but retained grounded-
capture and authority-handling misses. B-216 and B-226 primarily establish narrow authority and
mechanics, not implemented integration or live dispatch benefit. B-230 and B-231 repaired concrete
preservation, scope and generated-derivative defects with stronger instruments, but do not prove
live-model compliance. In particular, C's strongest failure is its actual unsupported captured
content and exceeded summary bound; a missing parent reread alone should not become a universal
redundant-reread rule.

The recommended course is:

1. Keep the current shipped knowledge machinery and existing review boundaries; this evidence does
   not justify a rewrite, registry, automatic promotion or duplicate instruction blocks.
2. Stop this synthetic campaign and retire this fixture unless a named future decision requires a
   prospective conforming repair. Do not purchase another tiny pass merely to replace this result.
3. Let the next eligible, preselected independent field task under FS2 or B-225 dominate the next
   strategic decision. Keep their questions separate and record alternatives, human review/rework,
   setup/refresh effort, delays, usage, nulls and regressions.
4. Reopen a focused evaluation only for a repeated field failure, a conflicting or missing product
   instruction, a materially changed relevant host route, a pending destructive workflow or another
   specific uncertainty that would change adoption. Freeze one hypothesis, valid/invalid worlds,
   caps and a stop condition. Wait when the needed participant or host is unavailable.

Review environment/gaps: native PS7 7.6.5 and Windows PowerShell 5.1.26100.9278, including CP437;
read-only artifacts and retained-binary replay. No paid actor call, fresh build, original-run
observation, remote CI-log verification, VS Code execution, private consumer inspection or
independent field participant was part of the review.

## Delivery verification

Root executed the committed preparation helper afresh under native Windows PowerShell 5.1 at CP437.
It reproduced both retained tree ids, zero remotes, 31 rows and the four grader dispositions at
1/6, 7/0, 6/1 and 5/2. The helper carries the mandatory UTF-8 BOM and parses with zero errors under
both native PowerShell hosts. On the fresh roots, root also reproduced BEFORE wiki-check exit 0 and
AFTER's 37 failures/exit 1 under PS5.1 CP437. All 27 committed fixture files match the retained raw
manifest in path, length and SHA-256; the historical input was not repaired during review.

The complete maintainer meta suite passed all 36 files with zero failures under direct PS7 7.6.5
and Windows PowerShell 5.1.26100.9278 at CP437. Final hygiene checks found no source/distribution
change, so this meta-only evidence record requires no product changelog or version increment.

## RCA

Static carrier and release gates could not show whether an ordinary Copilot task would find or use
scoped knowledge. Typed read events plus an independently red/green hidden grader made that behavior
observable here. The preparation failures show the symmetrical risk: a malformed mutation or dirty
neutral root can make a semantic result unreadable even when the model is blameless. The accepted
controls separated those failures before dispatch.

The result exposed two evaluation defects. First, the preparation helper calibrated the hidden
grader and visible application tests but never ran the installed product's wiki validity check, so
stable hashes preserved a nonconforming knowledge state. A prospective fixture must pass the
existing checker before dispatch; this does not justify another generic gate. Second, treating every
knowledge-file edit as scope expansion conflicts with the framework's affected-artifact
reconciliation rule. That class applies to any evaluator that freezes file names without first
classifying their ownership and task effect.
The bounded correction is to adjudicate affected canonical artifacts semantically and preserve the
invalid expectation in this record, not retrofit the oracle after seeing this actor's diff.

Finally, a task can follow the scoped-knowledge and regression-first rules while ignoring the plan
gate from the same delivered instruction payload. Aggregate “framework followed” scoring would hide
that difference. Future observations should score each load-bearing rail separately; one synthetic
miss does not justify louder duplicate instructions or a new general gate.
