# B-41 remainder locked-design adversarial review (2026-08-13)

Scope reviewed: section 2 of `.claude/plans/2026-08-09-b41-eval-harness-remainder-design.md`, including the validation addendum's new step 2b. This pass did not re-litigate observations the addendum says it directly re-executed. It tested the addendum's new claims and the portions of locked scope they affect. No implementation was performed.

## Findings

1. **BLOCKING — step 2b names a generator path that does not exist in the authoring repo.**

   The locked command is `pwsh -NoProfile -File scripts/build-architecture-html.ps1 ...`, but root `scripts/` contains no `build-architecture-html` twin. The actual authoring sources are `src/core/scripts/build-architecture-html.ps1` and `.sh`; composed distributions receive them at `dist/<stack>/scripts/`. An implementer following step 2b literally cannot regenerate the source-owned `src/stacks/*/files/docs/architecture.html` files.

   Verification/read used:

   ```text
   Get-Content -Raw -LiteralPath 'scripts/build-architecture-html.ps1'
   -> Cannot find path 'scripts/build-architecture-html.ps1' because it does not exist.

   rg -n "build-architecture-html" scripts src
   -> src/core/scripts/build-architecture-html.ps1
   -> src/core/scripts/build-architecture-html.sh
   ```

   I also read both source generators. They accept `[src] [out] [title]`, resolve relative arguments from the Git root, and therefore can generate each stack-owned source HTML when invoked from `src/core/scripts/`. Correct the locked command path before implementation (and name the `.sh` source twin consistently).

2. **NON-BLOCKING — step 2b's verification does not prove the stated freshness property.**

   The addendum requires grepping the regenerated HTML for absence of `executable spec` / old prose. That catches this particular stale phrase, but it does not prove that HTML matches the complete Markdown source or even that the generator ran. The generator deliberately stamps `<!-- src-sha1: ... -->`, and the shipped `docs-sync-check` computes the same CR-stripped SHA-1. Comparing that marker against each edited `ARCHITECTURE.md` is the direct, cheap verification of the claim "committed HTML is fresh"; phrase absence should remain a semantic assertion, not the freshness assertion.

   Verification/read used:

   ```text
   Get-Content -Raw src/core/scripts/build-architecture-html.ps1
   Get-Content -Raw src/core/scripts/build-architecture-html.sh
   Get-Content src/core/scripts/docs-sync-check.ps1 (lines 142-148)
   ```

   Those reads show the generators hash the full CR-stripped Markdown and stamp `src-sha1`, while `docs-sync-check` compares that full-source hash. I independently computed the hashes for all three current source pairs and found all three markers currently fresh (`MARKER=True`), demonstrating a concrete success state for this measure. Amend step 2b to verify the marker for all three pairs after regeneration. This is non-blocking because the mandated regeneration and direct phrase grep still address the observed B-23 text if executed correctly.

3. **NON-BLOCKING — the addendum overstates what stale `architecture.html` currently tells a reviewer.**

   The addendum says stale HTML would remain "telling a human reviewer to run the deleted evals runner." It does not contain `run_evals.py`, `requirements.txt`, or a run command. It embeds the weaker but still false post-deletion claims that `cases.yaml` is an "executable spec" and uses a "model-graded rubric." Step 2b remains necessary, but the evidence record should describe the observed defect accurately.

   Verification/read used:

   ```text
   Get-ChildItem src/stacks -Recurse -File |
     Select-String -Pattern 'evals|executable spec|run_evals|requirements.txt'
   ```

   Result: each `architecture.html` contains the `executable spec` / `model-graded rubric` sentence and no `run_evals.py` or `requirements.txt`; the actual run commands occur in `tests/evals/README.md`.

4. **NON-BLOCKING — the newly asserted maintainer-gate blind spot is real and was constructively verified.**

   This supports rather than rejects step 2b. I copied `dist/dotnet` to a scratch dist, appended `B41_STALE_PROBE` only to `docs/ARCHITECTURE.md`, and ran check 6-8 through the validator's supported scratch-root interface:

   ```text
   .\scripts\validate-dist.ps1 dotnet <scratch-root> --content-only
   -> All dist validation checks passed
   -> VALIDATE_EXIT=0 HTML_CONTAINS_PROBE=False
   ```

   Thus the current maintainer content gates accept a provably stale Markdown/HTML pair. This is recorded as non-blocking confirmation because the addendum already added the proportional manual regeneration step; it does not justify expanding this S item into a new permanent gate.

## Verdict

**Proceed only after correcting blocking finding 1 in the locked design.** The overall B-41 remainder is still necessary and proportionate:

- The `no-dead-instruction` Python grammar repair is the smallest change that makes deletion of the live `python run_evals.py` instructions gateable; extending the existing twin gate is proportionate to the observed false-green risk.
- Deleting the stale response-only runner and requirements while retaining `cases.yaml` as documentary cases remains proportionate. The current source and all three dists still contain the runner instructions, and the current B-41 backlog entry still requires resolving B-23.
- Audit-only Copilot coverage remains the right boundary: no new conformance layer absent a drift-discovered gap.
- S1 remains a bounded, zero-credit schema freshness check and does not gate the useful work.
- Regenerating the three already-versioned `architecture.html` derivatives is necessary once their Markdown sources change, but it is a normal derivative update, not grounds for a new authoring gate.

Nothing since the design's `4a7757a` base undercuts that premise. I verified current `HEAD` is `afabd90`, inspected the intervening log, and read the live B-41/B-43/B-49 backlog entries. B-41 is still open with its old DONE bar, B-43/B-49 remain the existing recurring host-evidence vehicle, and the intervening commits concern other work. The only material design change required by this review is to use the actual source generator path and strengthen step 2b's freshness assertion to its existing full-source SHA marker.
