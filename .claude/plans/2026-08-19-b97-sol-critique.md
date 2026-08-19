# B-97 adversarial critique (Sol, gpt-5.6-sol) — 2026-08-19

## Verdict: REQUEST CHANGES — five blocking findings

Rev 1 proposed consuming `meta/block-manifest.json`. **The premise was rejected.** Findings 1-4
accepted into rev 2; finding 5 dissolved because no stamp comparison survives the rewrite.
Findings 2, 3 and 4 were re-verified directly by Claude before acceptance (manifest `B-97` string,
`No jq/python dependency by design`, absence of SHA-256 in shipped shell).

Raw critique follows verbatim.

---


The shell twin explicitly claims “No jq/python dependency by design” [src/core/scripts/framework-doctor.sh:2](C:\TEMP\AIdrivenDev\ai-tech-lead\src\core\scripts\framework-doctor.sh:2). It opportunistically uses `jq`, then a proven-working Python interpreter, then a narrow `sed` fallback only for the flat three-field stamp [src/core/scripts/framework-doctor.sh:56](C:\TEMP\AIdrivenDev\ai-tech-lead\src\core\scripts\framework-doctor.sh:56)–[src/core/scripts/framework-doctor.sh:71](C:\TEMP\AIdrivenDev\ai-tech-lead\src\core\scripts\framework-doctor.sh:71), [src/core/scripts/framework-doctor.sh:92](C:\TEMP\AIdrivenDev\ai-tech-lead\src\core\scripts\framework-doctor.sh:92)–[src/core/scripts/framework-doctor.sh:107](C:\TEMP\AIdrivenDev\ai-tech-lead\src\core\scripts\framework-doctor.sh:107). That `sed` fallback cannot robustly query the manifest’s nested per-stack arrays.

The doctor currently has no SHA-256 implementation. Existing shipped shell hashing code supports only optional `sha1sum`/`shasum` and falls back to no hash [src/core/scripts/build-architecture-html.sh:17](C:\TEMP\AIdrivenDev\ai-tech-lead\src\core\scripts\build-architecture-html.sh:17)–[src/core/scripts/build-architecture-html.sh:20](C:\TEMP\AIdrivenDev\ai-tech-lead\src\core\scripts\build-architecture-html.sh:20).

Do not add a mandatory `jq` dependency. If the manifest design survives proportionality review, specify:

- parse with `jq` or the already-probed working Python;
- when neither exists, emit an honest `MISSING`/`CANT-VERIFY` parser result, never parse nested JSON with regex;
- hash through an explicit portable cascade such as `sha256sum`, `shasum -a 256`, Python `hashlib`, or another verified SHA-256 provider;
- when none exists, emit `MISSING`/`CANT-VERIFY`;
- narrow “twin agreement” to environments where both legs possess the required capability, and separately test identical incapable-host behavior.

Without this, test 7’s unconditional claim that both twins return the same row for all fixtures is not implementable across the doctor’s supported environments [.claude/plans/2026-08-19-b97-protected-file-sync-design.md:107](C:\TEMP\AIdrivenDev\ai-tech-lead\.claude\plans\2026-08-19-b97-protected-file-sync-design.md:107).

### 5. The pre-coverage test names the wrong stamp

The installed machinery stamp is overwritten on update, while protected `CLAUDE.md` is restored [meta/BACKLOG.md:878](C:\TEMP\AIdrivenDev\ai-tech-lead\meta\BACKLOG.md:878)–[meta/BACKLOG.md:882](C:\TEMP\AIdrivenDev\ai-tech-lead\meta\BACKLOG.md:882). Consequently `.claude/framework-version.json` does not preserve the consumer’s original installation version.

The design says “Consumer stamp predates `coverage.earliest-release`” [.claude/plans/2026-08-19-b97-protected-file-sync-design.md:70](C:\TEMP\AIdrivenDev\ai-tech-lead\.claude\plans\2026-08-19-b97-protected-file-sync-design.md:70), but must explicitly mean the embedded protected-file version parsed from `CLAUDE.md`, not `$stamp.version`. The current code exposes both distinct values at [dist/dotnet/scripts/framework-doctor.ps1:48](C:\TEMP\AIdrivenDev\ai-tech-lead\dist\dotnet\scripts\framework-doctor.ps1:48)–[dist/dotnet/scripts/framework-doctor.ps1:55](C:\TEMP\AIdrivenDev\ai-tech-lead\dist\dotnet\scripts\framework-doctor.ps1:55) and [dist/dotnet/scripts/framework-doctor.ps1:72](C:\TEMP\AIdrivenDev\ai-tech-lead\dist\dotnet\scripts\framework-doctor.ps1:72)–[dist/dotnet/scripts/framework-doctor.ps1:77](C:\TEMP\AIdrivenDev\ai-tech-lead\dist\dotnet\scripts\framework-doctor.ps1:77). Lock this down in the design and tests.

## Verified requested points

- The current universal claim is overstated. The row does not inspect migration at all; it returns `OK` whenever the two version strings match and `DIVERGED` otherwise [dist/dotnet/scripts/framework-doctor.ps1:72](C:\TEMP\AIdrivenDev\ai-tech-lead\dist\dotnet\scripts\framework-doctor.ps1:72)–[dist/dotnet/scripts/framework-doctor.ps1:77](C:\TEMP\AIdrivenDev\ai-tech-lead\dist\dotnet\scripts\framework-doctor.ps1:77). A normal existing consumer that adds only the migration import will indeed remain `DIVERGED` after updates, but not literally “every migrated consumer forever”: a fresh v0.45+ install or a consumer whose protected-file version is manually synchronized returns `OK`. The design should state the narrower, verified population.

- The manifest’s current `latest-release: v0.44.0` is genuinely stale metadata because the repository now has tags through v0.60.0, while the generator enumerates every `vX.Y.Z` tag and derives `latest-release` from the final tag [.claude/scripts/build-block-manifest.ps1:162](C:\TEMP\AIdrivenDev\ai-tech-lead\.claude\scripts\build-block-manifest.ps1:162)–[.claude/scripts/build-block-manifest.ps1:169](C:\TEMP\AIdrivenDev\ai-tech-lead\.claude\scripts\build-block-manifest.ps1:169), [.claude/scripts/build-block-manifest.ps1:213](C:\TEMP\AIdrivenDev\ai-tech-lead\.claude\scripts\build-block-manifest.ps1:213)–[.claude/scripts/build-block-manifest.ps1:217](C:\TEMP\AIdrivenDev\ai-tech-lead\.claude\scripts\build-block-manifest.ps1:217). However, fingerprint ranges ending at v0.44.0 are correct by construction because the blocks moved out of those files at v0.45.0. The current builder records every post-migration absent block as `unavailable` [.claude/scripts/build-block-manifest.ps1:181](C:\TEMP\AIdrivenDev\ai-tech-lead\.claude\scripts\build-block-manifest.ps1:181)–[.claude/scripts/build-block-manifest.ps1:200](C:\TEMP\AIdrivenDev\ai-tech-lead\.claude\scripts\build-block-manifest.ps1:200); the design is correct that this needs a distinct migrated-absence representation.

- The stack dimension is not blocking. `.claude/framework-version.json` already carries `template`, the doctor parses it, and later uses it for stack-specific toolchain checks [dist/dotnet/scripts/framework-doctor.ps1:48](C:\TEMP\AIdrivenDev\ai-tech-lead\dist\dotnet\scripts\framework-doctor.ps1:48)–[dist/dotnet/scripts/framework-doctor.ps1:55](C:\TEMP\AIdrivenDev\ai-tech-lead\dist\dotnet\scripts\framework-doctor.ps1:55), [dist/dotnet/scripts/framework-doctor.ps1:180](C:\TEMP\AIdrivenDev\ai-tech-lead\dist\dotnet\scripts\framework-doctor.ps1:180)–[dist/dotnet/scripts/framework-doctor.ps1:185). The design should explicitly require exact `dotnet|angular|monorepo` validation and fail closed on any other value before indexing the manifest.

No files were modified.
tokens used
157,356
REQUEST CHANGES

Commands run:

```powershell
$p='.claude/plans/2026-08-19-b97-protected-file-sync-design.md'; $i=0; Get-Content -LiteralPath $p | ForEach-Object { $i++; '{0,5}: {1}' -f $i, $_ }
$p='CLAUDE.md'; $i=0; Get-Content -LiteralPath $p | ForEach-Object { $i++; '{0,5}: {1}' -f $i, $_ }
rg -n -C 8 "B-97( ANSWER \(rev 3\)| DESIGN COMPLETE|\b)" meta/BACKLOG.md
rg -n "python|jq|json|sha256|shasum|openssl|template|framework-version|Protected-file" dist/dotnet/scripts/framework-doctor.sh src/core/scripts/framework-doctor.sh .claude/scripts/build-block-manifest.ps1
rg -n "sha256sum|shasum|openssl dgst|certutil|Get-FileHash|SHA256" src dist scripts .claude/scripts -g '*.sh' -g '*.ps1'
git tag --list 'v*' --sort=v:refname | Select-Object -Last 12
git status --short
```

## Blocking findings

### 1. The proposed state table does not fix the stated harm for migrated existing consumers

The design calls only “blocks absent + import present” `OK`; any retained known block becomes `BEHIND`, even though the same message says the carrier supersedes it [.claude/plans/2026-08-19-b97-protected-file-sync-design.md:64](C:\TEMP\AIdrivenDev\ai-tech-lead\.claude\plans\2026-08-19-b97-protected-file-sync-design.md:64), [.claude/plans/2026-08-19-b97-protected-file-sync-design.md:66](C:\TEMP\AIdrivenDev\ai-tech-lead\.claude\plans\2026-08-19-b97-protected-file-sync-design.md:66), [.claude/plans/2026-08-19-b97-protected-file-sync-design.md:67](C:\TEMP\AIdrivenDev\ai-tech-lead\.claude\plans\2026-08-19-b97-protected-file-sync-design.md:67).

But the settled migration is one added `@import` line; it does not remove the stale inline blocks [meta/BACKLOG.md:909](C:\TEMP\AIdrivenDev\ai-tech-lead\meta\BACKLOG.md:909), [meta/BACKLOG.md:911](C:\TEMP\AIdrivenDev\ai-tech-lead\meta\BACKLOG.md:911). WSD-031 likewise says existing consumers retain the stale inline copy and receive a pointer [meta/workspace-decisions.md:1278](C:\TEMP\AIdrivenDev\ai-tech-lead\meta\workspace-decisions.md:1278), [meta/workspace-decisions.md:1279](C:\TEMP\AIdrivenDev\ai-tech-lead\meta\workspace-decisions.md:1279).

Therefore the normal successfully migrated existing consumer has both:

- the import; and
- all four historical inline blocks.

The proposed replacement will continue warning on exactly that population, merely changing `DIVERGED` to one or more `BEHIND` findings. This contradicts the proportionality premise that the change removes the permanent false alarm [.claude/plans/2026-08-19-b97-protected-file-sync-design.md:89](C:\TEMP\AIdrivenDev\ai-tech-lead\.claude\plans\2026-08-19-b97-protected-file-sync-design.md:89).

The state model must be redesigned. At minimum, import present + carrier present must be the primary successful migration state. Historical inline blocks may be reported separately as cleanup information, but cannot make `Protected-file sync` unhealthy merely because the settled migration deliberately leaves them in place.

### 2. The 8 KB manifest is not proportionate to the observed false alarm

The existing preceding row already makes the actionable carrier/import check:

- carrier and import present → `OK`;
- carrier present but import absent → `MISSING` with the exact fix;
- carrier absent → `MISSING` with reinstall guidance.

That is implemented at [dist/dotnet/scripts/framework-doctor.ps1:64](C:\TEMP\AIdrivenDev\ai-tech-lead\dist\dotnet\scripts\framework-doctor.ps1:64)–[dist/dotnet/scripts/framework-doctor.ps1:69](C:\TEMP\AIdrivenDev\ai-tech-lead\dist\dotnet\scripts\framework-doctor.ps1:69) and [src/core/scripts/framework-doctor.sh:118](C:\TEMP\AIdrivenDev\ai-tech-lead\src\core\scripts\framework-doctor.sh:118)–[src/core/scripts/framework-doctor.sh:124](C:\TEMP\AIdrivenDev\ai-tech-lead\src\core\scripts\framework-doctor.sh:124).

A materially smaller remedy therefore removes most of the observed harm: delete the version-proxy `Protected-file sync` row, or redefine it around the already-computed carrier/import migration state. That stops the false alarm and preserves the actionable diagnostic without shipping historical fingerprints, JSON parsing, SHA-256 portability logic, or six-way classification.

The design rejects only a different small fix—comparing against `coverage.latest-release` [.claude/plans/2026-08-19-b97-protected-file-sync-design.md:92](C:\TEMP\AIdrivenDev\ai-tech-lead\.claude\plans\2026-08-19-b97-protected-file-sync-design.md:92)–[.claude/plans/2026-08-19-b97-protected-file-sync-design.md:94](C:\TEMP\AIdrivenDev\ai-tech-lead\.claude\plans\2026-08-19-b97-protected-file-sync-design.md:94). It does not evaluate the smaller fix already present immediately above the defective row. That fails Maintenance model #6’s requirement to test whether a materially smaller change removes most of the observed harm [CLAUDE.md:163](C:\TEMP\AIdrivenDev\ai-tech-lead\CLAUDE.md:163)–[CLAUDE.md:176](C:\TEMP\AIdrivenDev\ai-tech-lead\CLAUDE.md:176).

Reject the manifest-consuming premise unless a separate, observed harm establishes why distinguishing historical inline text from local edits materially helps after the carrier/import state is healthy.

### 3. Shipping the manifest verbatim violates the machine-enforced don’t-ship boundary

The proposed move ships `meta/block-manifest.json` verbatim from `src/core/.claude/` [.claude/plans/2026-08-19-b97-protected-file-sync-design.md:56](C:\TEMP\AIdrivenDev\ai-tech-lead\.claude\plans\2026-08-19-b97-protected-file-sync-design.md:56).

Its `purpose` contains the internal identifier `B-97` [meta/block-manifest.json:4](C:\TEMP\AIdrivenDev\ai-tech-lead\meta\block-manifest.json:4). The composed-dist gate explicitly denies that identifier form [scripts/meta-denylist.txt:19](C:\TEMP\AIdrivenDev\ai-tech-lead\scripts\meta-denylist.txt:19)–[scripts/meta-denylist.txt:24](C:\TEMP\AIdrivenDev\ai-tech-lead\scripts\meta-denylist.txt:24). Invariant #6 requires scanning the composed dist and forbids internal tracking vocabulary [CLAUDE.md:81](C:\TEMP\AIdrivenDev\ai-tech-lead\CLAUDE.md:81)–[CLAUDE.md:90](C:\TEMP\AIdrivenDev\ai-tech-lead\CLAUDE.md:90).

The manifest also advertises a maintainer-only generator path that will not exist in a consumer repo [meta/block-manifest.json:3](C:\TEMP\AIdrivenDev\ai-tech-lead\meta\block-manifest.json:3); the generator itself explicitly says it is meta-only and never ships [.claude/scripts/build-block-manifest.ps1:22](C:\TEMP\AIdrivenDev\ai-tech-lead\.claude\scripts\build-block-manifest.ps1:22).

If the manifest remains in scope, define a consumer-safe schema/output: remove the tracking ID and do not publish a dead maintainer path.

### 4. The Bash implementation contract is underspecified and cannot promise unconditional twin agreement

The shell twin explicitly claims “No jq/python dependency by design” [src/core/scripts/framework-doctor.sh:2](C:\TEMP\AIdrivenDev\ai-tech-lead\src\core\scripts\framework-doctor.sh:2). It opportunistically uses `jq`, then a proven-working Python interpreter, then a narrow `sed` fallback only for the flat three-field stamp [src/core/scripts/framework-doctor.sh:56](C:\TEMP\AIdrivenDev\ai-tech-lead\src\core\scripts\framework-doctor.sh:56)–[src/core/scripts/framework-doctor.sh:71](C:\TEMP\AIdrivenDev\ai-tech-lead\src\core\scripts\framework-doctor.sh:71), [src/core/scripts/framework-doctor.sh:92](C:\TEMP\AIdrivenDev\ai-tech-lead\src\core\scripts\framework-doctor.sh:92)–[src/core/scripts/framework-doctor.sh:107](C:\TEMP\AIdrivenDev\ai-tech-lead\src\core\scripts\framework-doctor.sh:107). That `sed` fallback cannot robustly query the manifest’s nested per-stack arrays.

The doctor currently has no SHA-256 implementation. Existing shipped shell hashing code supports only optional `sha1sum`/`shasum` and falls back to no hash [src/core/scripts/build-architecture-html.sh:17](C:\TEMP\AIdrivenDev\ai-tech-lead\src\core\scripts\build-architecture-html.sh:17)–[src/core/scripts/build-architecture-html.sh:20](C:\TEMP\AIdrivenDev\ai-tech-lead\src\core\scripts\build-architecture-html.sh:20).

Do not add a mandatory `jq` dependency. If the manifest design survives proportionality review, specify:

- parse with `jq` or the already-probed working Python;
- when neither exists, emit an honest `MISSING`/`CANT-VERIFY` parser result, never parse nested JSON with regex;
- hash through an explicit portable cascade such as `sha256sum`, `shasum -a 256`, Python `hashlib`, or another verified SHA-256 provider;
- when none exists, emit `MISSING`/`CANT-VERIFY`;
- narrow “twin agreement” to environments where both legs possess the required capability, and separately test identical incapable-host behavior.

Without this, test 7’s unconditional claim that both twins return the same row for all fixtures is not implementable across the doctor’s supported environments [.claude/plans/2026-08-19-b97-protected-file-sync-design.md:107](C:\TEMP\AIdrivenDev\ai-tech-lead\.claude\plans\2026-08-19-b97-protected-file-sync-design.md:107).

### 5. The pre-coverage test names the wrong stamp

The installed machinery stamp is overwritten on update, while protected `CLAUDE.md` is restored [meta/BACKLOG.md:878](C:\TEMP\AIdrivenDev\ai-tech-lead\meta\BACKLOG.md:878)–[meta/BACKLOG.md:882](C:\TEMP\AIdrivenDev\ai-tech-lead\meta\BACKLOG.md:882). Consequently `.claude/framework-version.json` does not preserve the consumer’s original installation version.

The design says “Consumer stamp predates `coverage.earliest-release`” [.claude/plans/2026-08-19-b97-protected-file-sync-design.md:70](C:\TEMP\AIdrivenDev\ai-tech-lead\.claude\plans\2026-08-19-b97-protected-file-sync-design.md:70), but must explicitly mean the embedded protected-file version parsed from `CLAUDE.md`, not `$stamp.version`. The current code exposes both distinct values at [dist/dotnet/scripts/framework-doctor.ps1:48](C:\TEMP\AIdrivenDev\ai-tech-lead\dist\dotnet\scripts\framework-doctor.ps1:48)–[dist/dotnet/scripts/framework-doctor.ps1:55](C:\TEMP\AIdrivenDev\ai-tech-lead\dist\dotnet\scripts\framework-doctor.ps1:55) and [dist/dotnet/scripts/framework-doctor.ps1:72](C:\TEMP\AIdrivenDev\ai-tech-lead\dist\dotnet\scripts\framework-doctor.ps1:72)–[dist/dotnet/scripts/framework-doctor.ps1:77](C:\TEMP\AIdrivenDev\ai-tech-lead\dist\dotnet\scripts\framework-doctor.ps1:77). Lock this down in the design and tests.

## Verified requested points

- The current universal claim is overstated. The row does not inspect migration at all; it returns `OK` whenever the two version strings match and `DIVERGED` otherwise [dist/dotnet/scripts/framework-doctor.ps1:72](C:\TEMP\AIdrivenDev\ai-tech-lead\dist\dotnet\scripts\framework-doctor.ps1:72)–[dist/dotnet/scripts/framework-doctor.ps1:77](C:\TEMP\AIdrivenDev\ai-tech-lead\dist\dotnet\scripts\framework-doctor.ps1:77). A normal existing consumer that adds only the migration import will indeed remain `DIVERGED` after updates, but not literally “every migrated consumer forever”: a fresh v0.45+ install or a consumer whose protected-file version is manually synchronized returns `OK`. The design should state the narrower, verified population.

- The manifest’s current `latest-release: v0.44.0` is genuinely stale metadata because the repository now has tags through v0.60.0, while the generator enumerates every `vX.Y.Z` tag and derives `latest-release` from the final tag [.claude/scripts/build-block-manifest.ps1:162](C:\TEMP\AIdrivenDev\ai-tech-lead\.claude\scripts\build-block-manifest.ps1:162)–[.claude/scripts/build-block-manifest.ps1:169](C:\TEMP\AIdrivenDev\ai-tech-lead\.claude\scripts\build-block-manifest.ps1:169), [.claude/scripts/build-block-manifest.ps1:213](C:\TEMP\AIdrivenDev\ai-tech-lead\.claude\scripts\build-block-manifest.ps1:213)–[.claude/scripts/build-block-manifest.ps1:217](C:\TEMP\AIdrivenDev\ai-tech-lead\.claude\scripts\build-block-manifest.ps1:217). However, fingerprint ranges ending at v0.44.0 are correct by construction because the blocks moved out of those files at v0.45.0. The current builder records every post-migration absent block as `unavailable` [.claude/scripts/build-block-manifest.ps1:181](C:\TEMP\AIdrivenDev\ai-tech-lead\.claude\scripts\build-block-manifest.ps1:181)–[.claude/scripts/build-block-manifest.ps1:200](C:\TEMP\AIdrivenDev\ai-tech-lead\.claude\scripts\build-block-manifest.ps1:200); the design is correct that this needs a distinct migrated-absence representation.

- The stack dimension is not blocking. `.claude/framework-version.json` already carries `template`, the doctor parses it, and later uses it for stack-specific toolchain checks [dist/dotnet/scripts/framework-doctor.ps1:48](C:\TEMP\AIdrivenDev\ai-tech-lead\dist\dotnet\scripts\framework-doctor.ps1:48)–[dist/dotnet/scripts/framework-doctor.ps1:55](C:\TEMP\AIdrivenDev\ai-tech-lead\dist\dotnet\scripts\framework-doctor.ps1:55), [dist/dotnet/scripts/framework-doctor.ps1:180](C:\TEMP\AIdrivenDev\ai-tech-lead\dist\dotnet\scripts\framework-doctor.ps1:180)–[dist/dotnet/scripts/framework-doctor.ps1:185). The design should explicitly require exact `dotnet|angular|monorepo` validation and fail closed on any other value before indexing the manifest.

No files were modified.

[exited with code 0]

