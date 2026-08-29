# B-193 — hazard-oracle same-class closure

**Date:** 2026-08-29  
**Filed against:** v0.78.3  
**Status:** VERIFIED 2026-08-29 — immutable candidate `fb35803` approved; native Linux/Bash 3.2 remains release evidence

## Premise and value decision

B-190's blind-first independent review met WSD-057's higher bar: distinct PowerShell and Bash
execution paths, release-specific mutations observed red, clean byte-identical restoration, and
explicit gaps. It then reproduced five findings covering six shipped false-green shapes, including
two that let the enclosing `docs-sync-check` print its exact completion line.

The pre-lock reviews then challenged inherited B-77 behavior instead of treating it as doctrine.
B-77's missing/pending/no-section skips and placeholder exemption were designed for an optional
referential-drift checker. Since v0.78.0, the same checker is a mandatory `/bootstrap` completion
dependency. In consumer-shaped fixtures, pending, absent-section, and placeholder states made both
wrappers exit zero and print the exact completion line even though `/bootstrap` requires each state
to be resolved first. The reviewers also reproduced two path-safety bypasses in both twins:
terminal punctuation removal turns `src/..` into `src/`, and turns a bare `C:` into ignorable prose
before the frozen safety grammar runs.

Fix B-193 now. Deferral knowingly preserves observed completion bypasses. Removing the deterministic
checker or replacing it with an LLM would discard portable CI evidence; a generic Markdown parser or
structured-format migration is much larger than the bounded grammar. The value-positive scope
remains the two native checkers and their existing suite, but the lifecycle rules are amended
prospectively rather than preserved merely because v0.58.0 once chose them.

## Frozen behavioral contract

1. `FRAMEWORK-CONTEXT.md` is required input for this completion oracle. A missing file is an
   incomplete artifact and exits nonzero with an actionable diagnostic; it is not a successful
   skip. The enclosing docs-sync gate independently checks the same required file, but the delegated
   oracle must also be honest when invoked directly.
2. The exact case-sensitive `KNOWN_HAZARD_AREAS_PENDING` token anywhere in the context is an
   incomplete state and exits nonzero before row validation. Once it is absent, count headings line
   by line. A heading starts at column zero, is case-sensitive, and equals
   `## Known Hazard Areas` after removing trailing ASCII space/tab only. Zero headings fails;
   exactly one is validated; more than one is malformed and fails before any completion claim. Do
   not use a multiline `\s*` match that can consume line breaks.
   PowerShell must use an ordinal/case-sensitive test rather than its default `-match` behavior.
3. The sole section has exactly two completed outcome modes: at least one ordinary hazard table row,
   or the exact case-sensitive `_No notable hazards detected — confirm with the team._` line after
   trimming ASCII horizontal whitespace. Header and separator rows are framing, not an outcome. A header-only,
   empty, arbitrary-prose-only, or mixed real-row-plus-no-notable section fails. Ordinary malformed
   rows still count as attempted rows and report their own diagnostics rather than being disguised
   as an empty section. PowerShell uses scalar `-ceq` for the exact no-notable comparison.
4. The exact bootstrap placeholder has exactly six trimmed split fields: empty outer fields and the
   four case-sensitive scalar values `_(drafted by /bootstrap)_`, `_`, `_`, `_`. It is a dedicated
   incomplete sentinel and fails once the pending marker is absent. Use scalar `-ceq` comparisons in
   PowerShell. A matching Area with different case, cells, or framing is an ordinary row and must
   satisfy the full contract.
5. Backticked tokens are data, never shell patterns. Both twins extract every closed backticked token
   and inspect the remaining prose without using captured content as replacement syntax.
6. Derive two forms with a terminating, lexical endpoint transform. Repeatedly remove terminal
   comma/semicolon, detach and preserve **at most one** terminal `.`/`:`, then remove one exactly
   matching endpoint pair (`()`, `""`, or `''`); repeat until unchanged. Reattach the detached suffix
   only to the safety form and omit it from the display/existence form. Unmatched wrappers remain
   literal data; do not infer Markdown balance. Filter URLs and ancillary wildcards using the display form. A
   `*`, `?`, or `[` followed later by `]` makes a token ancillary wildcard syntax; it never satisfies
   literal-path evidence, even when the filesystem contains those characters literally. An
   unmatched bracket remains literal; wildcard escaping is unsupported and out of scope.
7. A final line without a trailing newline is still a line. Both Bash context loops must process it;
   initialize their loop variables before `read ... || [ -n "$value" ]` under `set -u`.
8. Freeze path-classification order after URL/wildcard filtering. Normalize `\` to `/` in both token
   forms; run the unsafe grammar on **both** forms and reject `^/`, `^[A-Za-z]:` (rooted, drive-
   relative, and bare drive prefixes), repeated separators, and every exact `.`/`..` segment. This
   catches both an unsafe raw token and one exposed by the single punctuation removal. Only then
   apply path-shape filtering to the display form and join it beneath the root. Never strip leading `./`,
   use host-dependent rootedness, or reject valid dot-named segments such as `.github` or `.cache`.
   POSIX names with a drive-like leading `[A-Za-z]:` prefix remain deliberately excluded so that
   identity cannot diverge across hosts; internal colon names are not claimed to be excluded.
9. Preserve the other v0.78.3 accepted states: exact literal paths, ancillary URLs/symbols/globs
   beside a literal, exact status/date grammar, header/separator handling, the exact no-notable
   outcome, BOM/CRLF, and read-only behavior. Missing input, pending, zero/multiple headings,
   placeholder, and incomplete/mixed outcomes are intentionally no longer accepted.

## Bounded implementation

Change only the two existing authored checkers and `HazardCheck.Tests.ps1`, then compose their three
generated dist copies. Track heading cardinality and the two completed outcome modes explicitly. In
PowerShell, retain a safety-preserving candidate before sentence punctuation removal, tighten
wildcard and path-prefix classification, and make placeholder comparison scalar/case-exact. In
Bash:

- store the anchored prefix/token/suffix regex in a single-quoted variable, copy all `BASH_REMATCH`
  captures before changing the remainder, and reconstruct through quoted concatenation; never feed
  captured content into `${value/pattern/replacement}`;
- initialize each loop variable and add portable `read ... || [ -n "$value" ]` guards to both
  context loops;
- mirror the lifecycle, outcome-cardinality, raw-safety, placeholder, heading, wildcard, and unsafe-
  prefix rules.

Change `Check` and `CheckDocs` so both available subjects execute before either result is asserted;
a PowerShell failure must not make Bash unobserved. For every expected wrapper failure, assert the
exact final success line is absent from each output as well as asserting nonzero exit.
The grouped lifecycle case must capture all eight states against both wrappers—all 16 results—before
asserting any result, so an early pre-fix false success cannot hide later states. Refactor the existing
manual read-only case to use separate twin fixtures and capture both executions, before/after hashes,
and outputs before any assertion.

Do not add dependencies, a new script, a generic Markdown parser, recursive lookup, path expansion,
hazard-truth judgment, freshness policy, or Markdown table-escaping semantics. Do not change
`docs-sync-check`; its existing delegation is the integration surface to prove. Code-fence
awareness, wildcard escaping, and physical symlink/reparse-target canonicalization remain outside
this bounded lexical parser.

## Red-first matrix

Retain the existing 38 `It` results, but reverse four stale expectations: missing context, pending
marker, absent exact section, and the exact placeholder now fail with their intended diagnostics.
Before changing either checker, add 29 `It` cases—26 leaf, two single-state wrapper cases, and one
grouped lifecycle-wrapper case—and observe current v0.78.3 fail the discriminating fixtures:

1. a backticked wildcard followed by a missing literal and an existing literal; both twins name the
   missing literal;
2. a balanced bracket-class glob whose bracket-named filesystem path literally exists; both twins
   report no literal evidence;
3. an unmatched-bracket literal path that exists remains a positive literal control;
4. a balanced bracket glob beside a valid literal stays ancillary while the row passes;
5. an unterminated final missing-path row is rejected, and the fixture asserts its final byte is not
   CR/LF;
6. an unterminated final valid row passes with the same last-byte assertion;
7. an unterminated final pending marker exercises the preliminary scan loop and fails as incomplete;
8. an exact placeholder Area with non-placeholder cells is validated and rejected;
9. a case-variant placeholder token with otherwise exact cells is not treated as the sentinel;
10. an exact four-value placeholder with non-empty trailing framing is not treated as the sentinel;
11. an existing path prefixed by `./` reports the unsafe-path diagnostic;
12. a rooted drive path reports that diagnostic;
13. a drive-relative path reports that diagnostic before path-shape filtering;
14. two exact hazard headings separated by another H2 are rejected as duplicate;
15. a case-variant hazard heading fails as a missing exact section;
16. the exact heading with trailing horizontal whitespace remains accepted;
17. the exact non-table no-notable outcome remains accepted in the presence of a case-variant
    pending-token decoy, proving pending detection is case-sensitive; require the exact
    `hazard-check passed.` output;
18. a consumer-shaped backtick-divergence world makes both docs-sync twins fail and omit the exact
    final success line;
19. the shared bracket-glob bypass does the same;
20. twelve safety-preserving exact-dot candidates cover bare, simple, single-/double-quoted,
    parenthesized, nested, sentence-punctuated, and repeated comma/semicolon frames beside a valid
    literal. Create every known wrong-normalized path, then capture both leaves and both wrappers
    before asserting exactly twelve unsafe diagnostics per output, no missing-path diagnostic,
    nonzero exits, and no leaf or wrapper completion line;
21. a bare `C:` beside a valid literal still reports an unsafe drive prefix;
22. a header/separator-only section fails for having no completed outcome;
23. an arbitrary-non-table-prose-only section fails for the same reason;
24. an exact no-notable line mixed with a valid real row fails as contradictory completion modes;
25. ten consumer-shaped rows independently prove each matching-frame transform and each
    Windows-valid unmatched-wrapper spelling beneath `src/.cache/`; stripped unmatched-wrapper
    controls are absent, all four leaf/wrapper subjects are captured before assertions, and every
    row must independently supply exact literal evidence;
26. existing literal paths followed by sentence-final `.` and `:` still pass after display-form
    trimming, proving the raw-safety fix did not disable ordinary prose punctuation;
27. a case-variant no-notable line fails rather than exploiting PowerShell's default case-insensitive
    comparison;
28. the exact no-notable text with trailing non-whitespace garbage fails rather than exploiting an
    unanchored match; and
29. one reused consumer-shaped fixture captures missing-context, pending, absent-section, exact-
    placeholder, header-only, arbitrary-prose-only, and mixed-outcome failure states, then the exact
    no-notable success state against both wrappers before making any assertion. Each failure omits
    the exact final success line.

The final suite has exactly 67 `It` results. Per twin it invokes 63 leaf states and 14 wrapper states
(77 subjects, 154 across both twins). Every new test identifies its intended diagnostic or output so
a generic earlier error cannot counterfeit coverage. Counts describe the frozen coverage; they did
not constrain which cases the reviews were allowed to add.

## Adversarial review disposition

Two independent pre-lock reviewers returned BLOCK rather than rubber-stamping the inherited design.
Accepted P1 findings replaced the B-77 lifecycle skips with mandatory completion semantics, added
completed-outcome cardinality, and moved path safety ahead of destructive punctuation trimming. An
accepted P2 added a valid dot-named-segment control. One reviewer recommended retaining the missing-
context leaf skip because `docs-sync-check` already fails it; the stricter recommendation was chosen
because this delegated script is itself a required-artifact oracle and a direct zero exit would be
ambiguous. The outer check remains an independent integration control, not the sole source of truth.
Both reviewers and the nested portability reviewer re-read the amended contract and returned
APPROVE with no residual blocker; this is the locked implementation boundary.

Post-implementation review did not rubber-stamp that boundary. Two fresh reviewers independently
blocked the first candidate: bare `.` was still skipped after normalization, and wrapper removal
before punctuation removal made `(src/..);` false-green while rejecting `(src/.cache/config.json);`.
The first amendment fixed ordering but a second review found exterior sentence punctuation such as
`(src/..).` still masked the traversal. The detached-suffix transform above replaces that amendment.
A later oracle review then blocked a grouped positive row because one resolving spelling could hide
nine ignored spellings. One-row-per-spelling coverage and a planted single-token skip mutation closed
that gap; independent code and oracle reviewers approved the amended source blobs.

## Verification and adversarial closure

1. Capture the pre-fix focused-suite RED count against the new fixtures and prove all 75 subjects per
   twin executed even though multiple assertions are expected to fail.
2. Implement only from this locked contract; any material deviation returns the design to
   adversarial review before code proceeds.
3. Run the authored focused suite to exactly 67/0 under PowerShell 7 and native Windows PowerShell
   5.1 with an isolated WindowsPowerShell module path and hostile code page 437; require Git Bash
   execution and prove the 77-per-twin subject count from instrumented output or an equivalent
   inspectable oracle.
4. Compose dotnet, Angular, and monorepo; run the focused suite against all three dists, `bash -n`,
   all validators, and the relevant doc/backlog/meta gates. Preserve the PowerShell BOM.
5. After green, independently weaken PowerShell wildcard/section/outcome enforcement and Bash
   extraction/EOF/raw-safety enforcement in scratch copies. Each mutation must make its
   discriminating case red while the other execution surface remains observable; restore byte-
   identically and rerun clean.
6. After implementation, a new non-implementing reviewer session starts from this locked contract
   and the immutable candidate range before reading the implementer narrative, forms an independent
   threat model, records agent/model/environment, independently observes the old tree or an applied
   release-specific mutation go red, restores and reruns clean, and records gaps. Implementer
   mutations do not substitute for that review.
7. Because this is a false-green release/enforcement change, add a second orthogonal reviewer or
   execution vantage before release. Same-host PowerShell/Bash diversity counts only when a surface-
   specific mutation and observed divergence prove material independence; otherwise retain review
   debt. The first Windows and Linux three-dist CI matrix for the immutable candidate must be green.
   Git Bash is not Linux/macOS evidence; if Bash 3.2/macOS is unavailable, record that compatibility
   gap rather than claiming it was run.

## RCA boundary

The v0.78.3 fix tested the invalid worlds named in its first design but treated that list as if it
closed the grammar. Parameter substitution reused untrusted captured text as syntax; wildcard
classification named only two of three standard forms; Bash's EOF behavior, exact placeholder
shape, section cardinality, completed-outcome cardinality, lifecycle role, and raw-versus-display
candidate order were not threat-modeled. The same-class sweep is the finite parser boundary above,
not every possible Markdown construct. Record this in `meta/LEARNINGS.md`, B-193's Done entry, and
root/consumer changelogs without claiming semantic truth enforcement.
