# B-185 — preserve the consumer ADR log

**Status:** LOCKED 2026-08-27 after premise validation and adversarial review  
**Release intent:** narrow patch release before lower-priority work

## Premise

The defect still reproduces against v0.78.0. Both installer twins replace a consumer sentinel at
`docs/architecture-decisions.md` during update, and brownfield installation archives the live file.
That path is not merely documentation shipped by the framework: `create-adr`, bootstrap, adoption,
the consumer changelog, and WSD-054 all define it as the repository's append-only decision history.
The incoming ownership manifest nevertheless says `framework-owned/overwritten`.

A semantic sweep of other framework-owned Markdown/JSON scaffolds found no sibling with the same
clear lifecycle collision. Generated impact files and feature specs are created at new paths;
`specs/README.md` and `docs/wiki/_template.md` remain framework instructions; the wiki index and
the established root consumer documents already have protection. This hotfix stays exact-path.

## Options challenged

1. **Protect the canonical path and seed it only when absent — chosen.** Add the exact path to both
   installers' protected and copy-if-absent sets. Existing writers and links remain valid;
   greenfield still receives the seed; update and brownfield retain consumer bytes in place.
2. **Move future ADRs to a new consumer-only path — rejected.** This changes every producer and
   link, creates a migration problem, and does not recover ADRs already lost. It is unnecessary to
   stop the overwrite.
3. **Merge or archive-and-restore during update — rejected.** Automatic Markdown merging cannot
   distinguish framework seed text from consumer history safely. Archive-and-restore retains the
   wrong ownership classification and adds a transient data-movement failure mode.

## Adversarial design review

- **Update:** an existing canonical ADR file must be byte-identical after both installer twins run,
  regardless of whether its content resembles the shipped seed.
- **Brownfield:** the same file must stay at its live path, must not appear under
  `docs/pre-adoption/`, and must not be listed in `adoption-pending.json.archivedOriginals`.
- **Greenfield or missing file:** the framework seed must still be created so existing links resolve.
- **Manifest/composer:** all three generated manifests must classify the exact path
  `consumer-owned/protected`; the composer twins must continue to derive equal ownership policy.
- **Convergence and dry-run:** the path remains present in the incoming distribution, so it is not a
  retirement candidate. Operation plans must say preserve for an existing file and create for an
  absent one without an unplanned side write.
- **Case and containment:** protect only the canonical lower-case repository-relative path. Do not
  introduce wildcard or case-insensitive ownership rules.
- **Recovery:** v0.78.0 cannot reconstruct overwritten decisions. Consumer release notes must say
  to restore them from version control or another backup before relying on the repaired updater.
- **Proportionality:** fold the exact-path assertions into the two existing installer lifecycle
  fixtures; do not add another full-install case or a new suite.

## Implementation and proof

1. Extend the existing update and brownfield lifecycle cases with exact-path sentinel bytes; run
   `UpdateDelivery.Tests.ps1` against the unfixed dist and observe both lifecycle assertions red on
   both twins.
2. Add `docs/architecture-decisions.md` to `protected` and `copy-if-absent` in both source installer
   twins. Update all three authored README ownership disclosures.
3. Add v0.78.1 consumer-facing changelog heads with the preservation and recovery action, plus the
   maintainer RCA entry. Recompose all distributions; never edit `dist/` directly.
4. Re-run the focused suite green, inspect all generated manifest classifications and operation
   plans, then run the proportional root gates. The planted sentinel is the red instrument.
5. Adversarially review the final diff for unintended ownership widening, stale recovery claims,
   and source/dist drift before invoking the automated release path.

## Non-goals

- No automatic recovery of decisions already overwritten by v0.78.0.
- No redirect of ADR producers or consolidation of arbitrary mature-document corpora.
- No B-186/B-187 changes in this patch; those receive separate premise/design/release decisions.
