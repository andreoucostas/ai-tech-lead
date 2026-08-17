# B-46 + B-65 implementation report

Date: 2026-08-17. Target: v0.56.0. No files were staged or committed.

## Red evidence on the unfixed composed installers

The test file was changed first, while `dist/` still contained the unfixed v0.55.0 installers, then:

```powershell
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File '.claude/hooks/tests/UpdateDelivery.Tests.ps1'; exit $LASTEXITCODE
```

Observed exit 4. Relevant literal output:

```text
[FAIL] update disclosure precedes the first target mutation (ps1) -- update preflight disclosure was absent.
[FAIL] settings backup is named and round-trips the consumer edit before refresh (ps1) -- rolling settings backup was not created
[FAIL] update disclosure precedes the first target mutation (sh) -- update preflight disclosure was absent.
[FAIL] settings backup is named and round-trips the consumer edit before refresh (sh) -- rolling settings backup was not created
UpdateDelivery.Tests: 23 passed, 4 failed, 0 skipped
```

This instrument can register success when the disclosure precedes the first observable target
mutation (the settings backup), the named backup contains the planted consumer edit, and the live
settings file has been refreshed. The green run below demonstrates that reachable state.

## Syntax and BOM

```powershell
$errors=$null; [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path 'src/core/scripts/install.ps1'),[ref]$null,[ref]$errors)|Out-Null; if($errors){$errors|ForEach-Object ToString; exit 1}; bash -n src/core/scripts/install.sh; $bytes=[IO.File]::ReadAllBytes((Resolve-Path 'src/core/scripts/install.ps1')); if(-not ($bytes[0]-eq 0xEF -and $bytes[1]-eq 0xBB -and $bytes[2]-eq 0xBF)){Write-Error 'install.ps1 BOM missing'; exit 1}; 'syntax and BOM: OK'
```

Observed exit 0:

```text
syntax and BOM: OK
```

## Composition and sibling evidence

```powershell
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File scripts/build.ps1 dotnet
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File scripts/build.ps1 angular
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File scripts/build.ps1 monorepo
```

Observed exit 0 for each:

```text
composed dist/dotnet (166 files)
composed dist/angular (162 files)
composed dist/monorepo (176 files)
```

```powershell
git status --porcelain dist/
```

Observed exit 0; the output named `CHANGELOG.md`, `README.md`,
`docs/enforcement-surfaces.md`, and both installer twins under each of `dist/angular`,
`dist/dotnet`, and `dist/monorepo`. In particular, all three README siblings were present.

## Green targeted suite

```powershell
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File '.claude/hooks/tests/UpdateDelivery.Tests.ps1'; exit $LASTEXITCODE
```

Observed exit 0:

```text
[ok] update disclosure precedes the first target mutation (ps1)
[ok] settings backup is named and round-trips the consumer edit before refresh (ps1)
[ok] update disclosure precedes the first target mutation (sh)
[ok] settings backup is named and round-trips the consumer edit before refresh (sh)
[ok] an update completes and reports success on both twins, for every dist
[ok] legal-file refusal remains exit 3 without an update completion banner (ps1, LICENSES/ai-tech-lead-MIT.txt)
[ok] legal-file refusal remains exit 3 without an update completion banner (ps1, NOTICE-ai-tech-lead.md)
[ok] legal-file refusal remains exit 3 without an update completion banner (sh, LICENSES/ai-tech-lead-MIT.txt)
[ok] legal-file refusal remains exit 3 without an update completion banner (sh, NOTICE-ai-tech-lead.md)
UpdateDelivery.Tests: 27 passed, 0 failed, 0 skipped
```

The omitted `[ok]` lines cover the existing protected-file, carrier, skills, routing, doctor, and
brownfield assertions; the summary is the literal complete count.

## Separate greenfield and update smoke

The temporary `.claude/plans/b46-smoke.ps1` harness was created for this run and deleted afterward.
It installed `dist/dotnet` into a fresh temporary directory with each twin, asserted that greenfield
created no backup, planted `CONSUMER-SMOKE-EDIT` in settings, updated, and asserted disclosure,
named path, recoverability, completion text, and exit codes.

```powershell
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File '.claude/plans/b46-smoke.ps1'; exit $LASTEXITCODE
```

Observed exit 0:

```text
ps1 greenfield exit=0 backup=absent; update exit=0 preflight=present backup-path=present edit=recoverable completion=present
sh greenfield exit=0 backup=absent; update exit=0 preflight=present backup-path=present edit=recoverable completion=present
```

## Checks not shown failing

- The existing legal-file exit-3 messages could not honestly be shown failing on the unfixed tree:
  v0.55.0 already implements that policy. They were retained as regression checks and passed for
  both collision types and both twins.
- The success-only completion assertion could not be shown failing on the unfixed tree: the existing
  legal preflight already exits before the completion banner. Its value here is preventing the new
  update output from being mistaken for success on an exit-3 refusal.
- Greenfield absence of `settings.json.pre-update` could not be shown failing before the change
  because the old installer created no such backup anywhere. It guards the newly introduced feature's
  update-only scope.
- B-65 is a documentation correction, not a behavioral routing claim. No pointer was added and no
  model-behavior test was run; the single 2026-07-31 observation cannot establish improvement.
- Per instruction, the full hook and validation suites were not run; the reviewer owns them.
