# B-186 — hazard-oracle completion-contract design

**Date:** 2026-08-27  
**Filed against:** v0.78.0  
**Status:** LOCKED after premise audit and adversarial self-review

## Premise and decision

The defect is live in v0.78.2. Bootstrap requires every real `Known Hazard Areas` row to contain at
least one exact resolving repository-root-relative path and one complete status token. Both shipped
hazard-check twins instead accept a row with no path candidate, recursively resolve a bare filename,
accept any status with the reviewed prefix, and never compare its embedded date with `Reviewed`.
`docs-sync-check` treats that oracle as a blocking completion result, so malformed generated output
can satisfy the mandatory onboarding gate.

Fix B-186 now. It is a deterministic integrity correction at the existing oracle, not a new
workflow, status model, or AI judgment layer. WSD-027's boundary remains intact: tooling verifies
reference and token shape; only a person may change epistemic status.

## Contract

For each non-header, non-separator, non-placeholder table row:

1. Require exactly four cells under the existing Markdown table framing.
2. Accept case-sensitively only `[VERIFIED]`, `[SUSPECTED]`, `[UNVERIFIED]`, or the complete form
   `[REVIEWED: not a hazard — YYYY-MM-DD]`.
3. Require both the `Reviewed` value and any embedded reviewed-status date to be calendar-valid ISO
   dates. The embedded date must equal the `Reviewed` cell.
4. Extract path-shaped tokens from backticks and remaining comma/whitespace-separated prose as the
   current checker does, but classify URLs, symbols, and wildcard expressions as ancillary. They do
   not satisfy the path requirement and are not wildcard-expanded or prefix-resolved.
5. Require at least one literal path-shaped candidate. A candidate is repository-root-relative,
   contains no absolute prefix or `.`/`..` traversal segment, contains no wildcard, and either has a
   slash or looks like a filename with an extension.
6. Resolve every literal candidate exactly beneath the supplied repository root. A bare filename is
   therefore checked only at the repository root; no recursive filename index exists. Any named
   literal candidate that does not resolve still fails, preserving the existing stronger
   referential-drift behavior.

The exact placeholder row, pending marker, missing context, missing section, header/separator rows,
and non-table `_No notable hazards detected ..._` outcome retain their existing skip/pass semantics.

## Adversarial review findings folded

- **Presence without pairing is not enough.** A reviewed-status prefix plus any date would recreate
  the current false pass. Anchor the whole token, calendar-check the captured date, and compare it to
  the column.
- **PowerShell equality is case-insensitive by default.** Use a case-sensitive simple-token
  membership test so `[verified]` cannot pass one twin and fail the other.
- **A glob prefix is not an exact path.** Do not truncate or expand globs. A glob may accompany a
  literal path as explanatory scope but cannot be the row's evidence.
- **A repository-wide filename search changes identity.** `PaymentService.cs` means the root file,
  not whichever nested file happens to share the name. Remove both twins' recursive index.
- **Joining an untrusted relative string is not containment.** Reject drive/UNC/rooted paths,
  repeated separators, and interior `.`/`..` segments before `Test-Path`/`-e`; otherwise a resolving
  sibling outside the fixture could satisfy the contract.
- **Path enforcement can mask status tests.** Status/date fixtures will create a valid exact path so
  each red proves its intended branch. Failure-count fixtures likewise isolate one defect per row.
- **Leaf parity does not prove the completion gate.** One consumer-shaped composed fixture will show
  malformed hazards make both docs-sync twins fail and a corrected row reaches the exact final
  success line.
- **Do not broaden the semantic oracle.** Hazard prose quality, truth, freshness policy, session
  rendering, and Markdown table escaping are outside this correction.

## Red-first evidence matrix

Before changing either checker, update the existing finite `HazardCheck.Tests.ps1` matrix and
observe failures for:

- pure prose, symbol-only, URL-only, and wildcard-only rows;
- a root-level filename that exists only in a nested directory;
- a traversal path resolving outside the repository fixture;
- lower-case, truncated, trailing-garbage, and invalid-calendar reviewed statuses;
- a valid reviewed-status date conflicting with the `Reviewed` column;
- the enclosing docs-sync check accepting the malformed row.

Retain positive controls for exact nested paths, a real root-level filename, mixed literal path plus
ancillary label/symbol/URL/glob text, all three simple statuses, a valid reviewed token, BOM/CRLF,
placeholder/no-section/pending states, read-only failure, and both script twins.

## Implementation and verification

1. Change only `src/core/scripts/hazard-check.ps1`, `hazard-check.sh`, and their existing behavioral
   suite. Do not add a new script or suite.
2. Preserve the PowerShell files' UTF-8 BOM and Windows PowerShell 5.1 parseability; retain portable
   Bash calendar validation and align year-zero behavior with .NET.
3. Compose dotnet, angular, and monorepo. Run the focused suite against authored code and every
   composed distribution, including both twins and the docs-sync wrapper fixture.
4. Run a hostile-code-page leg under PowerShell 7 and Windows PowerShell 5.1, `bash -n`, all three
   dist validators, and the normal documentation/backlog gates.
5. Plant at least one post-green mutation in each checker that weakens status/path enforcement;
   require the suite to go red and restore both files byte-identically.
6. Record the RCA and exposed defect class in root/consumer changelogs, `meta/LEARNINGS.md`, and the
   Done archive. Release separately as v0.78.3 only if the guarded release pipeline remains green.

