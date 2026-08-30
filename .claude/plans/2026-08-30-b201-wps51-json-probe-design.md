# B-201 — Windows PowerShell 5.1-safe Bash JSON capability probes

**Status:** IMPLEMENTED CANDIDATE · **Date:** 2026-08-30 · **Scope:** three existing session-start test probes only

## Value decision

Implement this item as P2/S for v0.79.0. It was filed for no earlier than v0.78.5, but that target
was revalidated after the bounded implementation: withholding a zero-growth test-truth correction
from the still-unreleased v0.79.0 tree would add branch/release complexity while making that
release's Windows evidence less trustworthy. It changes no product behavior and can use the same
pending Windows/Linux candidate CI, so earlier inclusion adds value without widening release risk.

Native Windows PowerShell 5.1
currently corrupts the nested quoting in each direct `$bash -c $probeCmd` invocation. Bash prints a
syntax error, but the test files reduce the empty captured stdout to the same value as genuine tool
absence and record invariant capability skips. Exact current runs reproduced this on all three
suites despite working jq: Hazard 18/0/1, Wiki 12/0/1, and FrameworkRules 9/0/1. Four existing Bash
Copilot JSON results therefore disappear behind three dishonest skips on a supported orchestrator.

Do not close or defer this as cosmetic test output. The skipped results exercise distinct shipped
hook behavior and already exist; restoring their execution improves test truth without adding a
suite, result, product branch, or recurring runtime. Conversely, do not expand the item into product
resolver changes, a generic process abstraction, or more JSON cases. PowerShell 7 already transports
the probe successfully, and the hook behavior itself is outside this defect.

## Locked implementation

Change only these authored files and compose their generated copies:

- `src/core/tests/hooks/SessionStartHazard.Tests.ps1`
- `src/core/tests/hooks/SessionStartWiki.Tests.ps1`
- `src/core/tests/hooks/SessionStartFrameworkRules.Tests.ps1`

At each existing capability site:

1. Preserve the current capability reach: jq is accepted when found; otherwise execute
   `python3`, `python`, then `py` against the same minimal JSON parse. Do not claim this is literal
   product-resolver identity: the older Python probe checks parse plus exit 0, while the hook has its
   own encoder-output contract. That pre-existing distinction is not B-201 scope because a broken
   encoder still makes the existing JSON result fail rather than falsely pass.
2. Make the probe emit exactly one terminal sentinel: normalized stdout `yes` when an encoder is
   available and `no` when none succeeds. Empty output is forbidden. An earlier draft retained empty
   as the unavailable state, but adversarial review blocked it because an omitted/unread stdin script
   has the same exit-0/empty/clean shape—the same ambiguity class this item exists to remove.
3. Invoke the existing `Invoke-RawProcess` helper with the resolved Bash executable, argument
   `@('-s')`, and the complete probe script as stdin. Nested Bash/Python quotes then remain BOM-less
   UTF-8 input rather than crossing Windows PowerShell 5.1's legacy native-argument marshaller.
   Bash executes the complete final `fi` at EOF, so no synthetic newline or file is needed.
4. Treat only these normalized raw outcomes as valid: exit 0, exact empty stderr, and case-sensitive
   stdout `yes` or `no`. Set `$shJson` true only for exact `yes`; exact `no` retains the existing
   invariant skip. Do not call `Trim()`, use case-insensitive comparison, or ignore extra output.
   Nonzero exit, any stderr, empty/unexpected stdout, or mixed-case sentinel throws a top-level setup
   error naming the Bash path, exit, stdout, and stderr. `Invoke-RawProcess` captures these channels
   rather than throwing, so explicit classification is load-bearing.
5. Keep the three small guards local. A new shared helper for three low-churn sites would broaden
   harness risk and require its own contract coverage. Do not change `Invoke-RawProcess`, `RunArg`,
   the existing JSON `It` bodies, skip wording, or result cardinality.

## Proportional evidence

- Preserve the current native Windows PowerShell 5.1 old-red evidence above, including the emitted
  Bash syntax error and false invariant skip despite working jq.
- After implementation, require native Windows PowerShell 5.1 to run all existing JSON arms with no
  invariant skip: Hazard 19/0/0, Wiki 14/0/0, FrameworkRules 10/0/0. Require the same counts under
  PowerShell 7; no new result may appear.
- In a disposable exact-test mutation, prepend a probe-local PATH with no jq/Python commands. The
  probe must return exact `no` with clean status/channels and each file must retain its one existing
  named invariant skip. Restore exact bytes afterward.
- In a second disposable mutation, make the probe emit an unexpected channel/result. Each affected
  file must exit nonzero through the setup diagnostic rather than record a skip. Wrap the expected
  child failures so the outer validation command succeeds only when all three actually fail, then
  restore exact bytes and rerun green.
- Parse all changed PowerShell under both hosts, preserve required UTF-8 BOMs, compose all three
  distributions with both composer twins, and run the focused composed suites plus record gates.
  Modified-test Windows/Linux CI remains required before completion; local Git Bash is not Linux.

## Adversarial review

Two independent read-only reviews approved IMPLEMENT/P2 and rejected both new test growth and a
shared helper. One review required fail-closed use of exit/stderr/stdout around `Invoke-RawProcess`;
the other blocked the initial empty-output design and required explicit case-sensitive `yes`/`no`
sentinels. The locked design incorporates both findings.

## Implementation evidence

All three authored probes now emit explicit `yes`/`no`, pass the script to the existing raw-process
helper through Bash `-s` stdin, and throw a diagnostic setup error for any nonzero exit, stderr,
empty/unexpected stdout, or non-exact sentinel. No hook, harness helper, suite, `It`, `Skip`, or
result count changed. Each source file is byte-identical to all three composed copies: Hazard
SHA-256 `d03ce9c7e12e4411eb25f424b9a5d55a892512cc8ba949917fd518d37d7cb8de`, Wiki
`beb31a3d07ad1fe2323f1fe3eb72ff8239d8761f7b1a009ef1882470dedf8336`, and FrameworkRules
`b496189839327a1c6549f380d59f50fd00988128785651593d2d2f09ff4f8141`.

The exact old Windows PowerShell 5.1 files emitted Bash's syntax error and falsely finished at
18/0/1, 12/0/1, and 9/0/1 despite working jq. The candidate ran the existing Bash JSON arms at
19/0/0, 14/0/0, and 10/0/0 under both native Windows PowerShell 5.1 and PowerShell 7, for authored
source and the composed dotnet distribution. A probe-local empty PATH produced exact `no` and the
same three honest named invariant skips without a syntax error. An unexpected-output mutation made
all three files exit 1 with the setup diagnostic; an outer oracle succeeded only after confirming
all three expected failures, then exact hashes were restored before green composition.

Both composers converged at 173/169/183 files, all twelve authored/generated files retained their
required BOMs and exact parity, both PowerShell parsers reported zero errors, and all three
distribution validators passed. Independent read-only implementation review found no defect and
confirmed exact scope. Native Linux and first exact-candidate Windows/Linux CI remain unobserved, so
this is an implemented candidate rather than completion or release approval.

No product behavior, push, tag, or release is authorized by this plan.
