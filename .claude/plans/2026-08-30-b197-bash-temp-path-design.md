# B-197 — Bash installer path-safe temporary lifecycle

**Status:** DESIGN LOCKED · **Date:** 2026-08-30 · **Scope:** Bash installer only

## Value decision

Implement this item as P1/S for v0.78.4. This is no longer merely a hypothetical path-style defect.
An exact controlled replay of the current composed dotnet installer used an owned `TMPDIR` named
`prefix dir`, an owned unrelated sibling file named `prefix`, and an empty target. The installer
reported greenfield success and exited 0, but deleted the sibling and leaked all 17 temporary files.
The scalar registry split every generated pathname at the embedded space; its unquoted cleanup also
permits pathname expansion. Successful deletion of unrelated bytes is a product data-loss boundary,
so closing or deferring the item would be disproportionate even though no consumer incident is
known.

The second current failure is less severe but has the same lifecycle cause: a `TMPDIR` physically
inside an otherwise clean Git target makes the installer's own pre-status files untracked and
produces a false dirty-tree refusal. The installer should not hide those files from Git or silently
override the caller's temp policy. It should identify that unsupported placement before relying on
status, remove the exact file it just allocated, and leave no persistent target mutation: the
whole-target fingerprint must be restored before exit. A cleanup failure is a separately reported
nonzero result and may retain the owned temp rather than falsely claiming restoration.

## Locked behavior and implementation

Change product behavior only in `src/core/scripts/install.sh`; composition remains the sole route to
the three distribution copies.

1. Resolve a separate physical target root with `pwd -P` for temporary-location containment. Do not
   change the existing logical `tgt` used by installer behavior.
2. Replace the space-delimited scalar with a Bash-3.2 indexed array plus an explicit integer count.
   Do not expand an empty array or derive its length: Bash 3.2 treats an elementless declared array
   as unbound under this script's `set -u`. Clear the shared result before each attempt. Append each
   successful non-empty `mktemp` result at the current count and increment the count before physical
   containment inspection, so the EXIT trap already owns a path that inspection rejects. Expose the
   allocated index to the caller and support explicit release by replacing an owned slot with a set
   empty value; cleanup skips released slots without expanding an unset array element. Use only
   assignment-form increments (`count=$((count + 1))`): post-increment arithmetic returns status 1
   at zero under `set -e` and could abort the allocator or EXIT trap.
3. Cleanup captures the incoming body status before any other command and clears the EXIT trap to
   prevent recursion. It walks only the populated numeric indices, passes each element as one
   quoted argument to `rm -f --`, guards every removal so one failure cannot suppress later cleanup,
   and reports every failed exact path. Guard diagnostic writes too, so broken stderr cannot abort
   later attempts or replace the body status. If the body succeeded but cleanup failed, state that
   target work completed, temp cleanup failed, and target changes were not rolled back, then exit 3.
   If both failed, retain the original body status while surfacing cleanup diagnostics. No `eval`,
   delimiter encoding, glob suppression, temp-name reconstruction, recursive deletion, or Bash-4-
   only syntax is allowed.
4. Immediately after registration, resolve the generated file's existing parent with `pwd -P`.
   Derive parent and leaf without losing the `/` parent for a root-level result. Construct the
   physical file path from that parent and returned leaf, prove it is `-ef` the generated entry, and
   replace both the registry slot and caller-facing `new_temp` with that one absolute physical path
   before the containment decision. Walk the physical parent's ancestors and compare filesystem
   identity with the physical target (`-ef`), so relative `TMPDIR`, links into the target, Windows
   case aliases, later working-directory changes, and retargeting of the caller-supplied logical
   temp link cannot split caller/cleanup authority. If identity, containment, or physical resolution
   cannot be established, emit a specific error and return failure while the EXIT trap still owns
   the best established exact pathname.
5. Lock allocator disposition rather than relying on `set -e`. Validator-internal allocations use
   `new_temp_file || return 2`; ordinary content validation failures remain 1. Incoming validator
   callers map either nonzero to their existing fatal exit 3. The previous-manifest caller captures
   the real validator status without `if !` erasing `$?`: status 2 surfaces the temp-host diagnostic
   and exits 3, status 1 alone enters existing additive compatibility, and 0 continues parsing.
   Every top-level allocation—including incoming/retirement inventory, both previous-manifest
   outputs, operation planning, legal comparison, and late settings replacement—uses an explicit
   exit-3 path before further work. Make `new_git_preflight_temp` delegate to the same allocator,
   then retain its existing exit-4 CANT-VERIFY mapping for a genuinely later preflight allocation
   failure.
6. Route the two short-lived legal-comparison files and the late settings replacement through the
   same allocator as well. A second legal allocation failure can otherwise leak the first file, and
   a failed late transform/move can leak its replacement file. Remove the legal pair's early `rm`
   and let EXIT retain ownership until it removes them. After a successful settings `mv`, release
   that exact registered slot immediately because ownership of the vanished source pathname has
   ended. Express the settings operation as `if sed ... && mv ...; then release; else ... exit 3; fi`:
   the failure branch must diagnose and leave the still-owned temp for EXIT, and the success message
   belongs only to the true branch. A released-path recreation must survive EXIT. This covers all
   five current `mktemp` call sites without introducing another abstraction or leaving stale
   deletion authority.

## Proportional behavioral evidence

Add exactly one Bash-only `It` to the existing update-delivery suite, with a named invariant Skip
when Bash is unavailable; add no suite, matrix, helper framework, source-text assertion, or
PowerShell twin case. Execute only the composed dotnet Bash installer because all three Bash
installers are generated from the same authored file and the composer/validator gates already
enforce parity.

The one result owns a unique disposable root and runs two worlds before asserting either:

- **Spaced external temp root:** change the child to an owned working directory and pass literal
  relative `TMPDIR='prefix dir'`. Require exit 0 and completion, byte-identical unrelated `prefix`
  sentinel, no generated files under `TMPDIR`, and no split-fragment residue under the owned working
  directory. This exercises relative resolution as well as whitespace while keeping the old
  split-word deletion inside the unique owned root.
- **Target-confined temp root:** create and commit a clean update target whose tracked temp directory
  is physically inside the target, then set `TMPDIR` to it. Require exact exit 3, the specific
  temp-containment refusal, absence of dirty-tree/completion text, an unchanged whole-target
  fingerprint, the tracked sentinel unchanged, and no generated temp residue. Before the installer,
  capture `git status --porcelain=v1 --untracked-files=all` and require exit 0 plus exact empty
  output so the false-dirty premise cannot be vacuous.

The wrapper changes the child working directory only to keep the known old split-relative deletion
inside the unique owned root. It passes paths and environment as arguments rather than interpolated
shell text. The result exercises shipped behavior; it does not reimplement cleanup or containment.

One temporary mutation removes quoting from the indexed cleanup element. The existing result must
then fail through the spaced-temp sentinel/residue assertions. Restore the exact bytes and rerun
green. Preserve the controlled current-version replay as old-red evidence; do not retain a second
historical test.

## Adversarial design review

Two independent reviews approved IMPLEMENT/P1 only after correcting the initial draft. The locked
design now covers every `mktemp` site, preserves body status across cleanup, distinguishes temp-host
failure from malformed previous-manifest compatibility, canonicalizes caller and cleanup to one
filesystem identity, and relinquishes deletion authority when a moved pathname is no longer owned.
The reviews also required clean-Git calibration, exact exit/diagnostic absence, root-path and
`set -e` arithmetic guards, previous-validator failure injection, link/case identity probes, and a
released-path recreation probe. These hostile checks remain disposable because adding permanent
cases for each mechanism would repeat the same lifecycle contract without commensurate value.

Both reviewers rejected CLOSE/DEFER after independently reproducing current exit-0 unrelated-file
deletion plus 17 leaked temps. They approved one new result because it observes the product harm and
the distinct target-confined refusal, while rejecting a new suite, PowerShell twin case, and
three-distribution runtime matrix as duplicate evidence.

## Acceptance boundary

- Bash syntax passes for source and all three generated installers; source/dist hashes are exact.
- The focused result passes under PowerShell 7 and native Windows PowerShell 5.1/CP437 with Git Bash.
  The whole modified suite passes on both hosts with unchanged results apart from this one justified
  Bash-only addition.
- Before product editing, run the exact new two-world result once against current composed bytes.
  Its one outer result must report both the relative-path sentinel/leak failure and the confined
  world's dirty-tree-versus-containment failure. This is preserved old-red evidence, not a second
  historical result.
- A calibrated disposable `mktemp` shim fails the first internal allocation during previous-manifest
  validation after all earlier allocations succeed. Require exact exit 3, allocator plus named
  temp-host diagnostics, absence of the malformed-prior/additive-compatibility message, removal of
  every earlier temp, no stale `new_temp` continuation, and restored target fingerprint. A separate
  missing/unusable temp-root probe covers call-1 failure. Neither becomes a permanent result.
- Disposable actual-candidate probes route a relative link/junction temp parent into the target and
  use a Windows case alias of the same target. Both must exit 3, restore the target fingerprint, and
  prove that identity-based containment—not a textual prefix—made the decision. Do not add an `It`.
- Disposable cleanup-failure probes show that every registered path is attempted, successful-body
  cleanup failure exits 3, and simultaneous body/cleanup failure retains the body's original
  nonzero status while emitting both diagnostics. These are hostile review evidence, not permanent
  fixture machinery.
- A disposable settings-`mv` wrapper recreates the released source pathname before EXIT. Its unique
  bytes must survive, proving that cleanup does not retain stale deletion authority after ownership
  transfer.
- PowerShell and Bash composition converge; both validator twins and the focused maintainer record
  gates pass.
- Freeze an immutable candidate and obtain an independent hostile review. Native Linux and the
  focused stock macOS Bash 3.2 provider remain required before completion/release; Git Bash and
  syntax checks are not substitutes.

No push, tag, or release is authorized by this plan.
