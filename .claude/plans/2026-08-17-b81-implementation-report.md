# B-81 implementation report

Date: 2026-08-17

Scope: B-81 only. B-17 was not implemented or edited.

## Build and generated output

Commands (run from the repository root):

```powershell
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File scripts/build.ps1 dotnet
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File scripts/build.ps1 angular
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File scripts/build.ps1 monorepo
git status --porcelain dist/
```

Observed build output:

```text
composed dist/dotnet (166 files)
BUILD_EXIT=0
composed dist/angular (162 files)
BUILD_EXIT=0
composed dist/monorepo (176 files)
BUILD_EXIT=0
```

Observed dist status contained only the three generated changelogs, six generated installer twins,
and the two new generated legal artifacts in each dist:

```text
 M dist/angular/CHANGELOG.md
 M dist/angular/scripts/install.ps1
 M dist/angular/scripts/install.sh
 M dist/dotnet/CHANGELOG.md
 M dist/dotnet/scripts/install.ps1
 M dist/dotnet/scripts/install.sh
 M dist/monorepo/CHANGELOG.md
 M dist/monorepo/scripts/install.ps1
 M dist/monorepo/scripts/install.sh
?? dist/angular/LICENSES/
?? dist/angular/NOTICE-ai-tech-lead.md
?? dist/dotnet/LICENSES/
?? dist/dotnet/NOTICE-ai-tech-lead.md
?? dist/monorepo/LICENSES/
?? dist/monorepo/NOTICE-ai-tech-lead.md
```

## Installer behavior: initial RED

Command:

```powershell
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File .claude/hooks/tests/Invoke-HookTests.ps1 -File LicenseDelivery.Tests.ps1 -Sequential
```

Observed against the unmodified shipped installers:

```text
[FAIL] greenfield creates the licence and notice with the shipped content (ps1) -- LICENSES/ai-tech-lead-MIT.txt was not installed
[FAIL] brownfield refuses a conflicting LICENSES/ai-tech-lead-MIT.txt without changing it (ps1) -- conflicting LICENSES/ai-tech-lead-MIT.txt was accepted
[FAIL] brownfield refuses a conflicting NOTICE-ai-tech-lead.md without changing it (ps1) -- conflicting NOTICE-ai-tech-lead.md was accepted
[FAIL] update replaces a stale framework-owned notice (ps1) -- Could not find ... dist\dotnet\NOTICE-ai-tech-lead.md
[FAIL] update refuses a notice whose ownership marker was removed (ps1) -- consumer-modified notice was accepted
[FAIL] greenfield creates the licence and notice with the shipped content (sh) -- LICENSES/ai-tech-lead-MIT.txt was not installed
[FAIL] brownfield refuses a conflicting LICENSES/ai-tech-lead-MIT.txt without changing it (sh) -- conflicting LICENSES/ai-tech-lead-MIT.txt was accepted
[FAIL] brownfield refuses a conflicting NOTICE-ai-tech-lead.md without changing it (sh) -- conflicting NOTICE-ai-tech-lead.md was accepted
[FAIL] update replaces a stale framework-owned notice (sh) -- Could not find ... dist\dotnet\NOTICE-ai-tech-lead.md
[FAIL] update refuses a notice whose ownership marker was removed (sh) -- consumer-modified notice was accepted
LicenseDelivery.Tests: 0 passed, 10 failed, 0 skipped
RESULT LicenseDelivery.Tests.ps1 10
OBSERVED_EXIT=10
```

## Every refusal observed on both twins

Command:

```powershell
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File .claude/hooks/tests/Invoke-HookTests.ps1 -File LicenseDelivery.Tests.ps1 -Sequential
```

The real-temp-dir cases hash the consumer file before and after and fail unless it is untouched.
Observed refusal lines (the two notice lines per twin are brownfield collision, then marker-removed
update):

```text
[observed refusal] twin=ps1 exit=3 path=LICENSES/ai-tech-lead-MIT.txt message=ERROR: Refusing to overwrite 'LICENSES/ai-tech-lead-MIT.txt': the existing file is not identical to the framework licence.
[observed refusal] twin=ps1 exit=3 path=NOTICE-ai-tech-lead.md message=ERROR: Refusing to overwrite 'NOTICE-ai-tech-lead.md': the existing file is not marked FRAMEWORK-OWNED.
[observed refusal] twin=ps1 exit=3 path=NOTICE-ai-tech-lead.md message=ERROR: Refusing to overwrite 'NOTICE-ai-tech-lead.md': the existing file is not marked FRAMEWORK-OWNED.
[observed refusal] twin=sh exit=3 path=LICENSES/ai-tech-lead-MIT.txt message=ERROR: Refusing to overwrite 'LICENSES/ai-tech-lead-MIT.txt': the existing file is not identical to the framework licence.
[observed refusal] twin=sh exit=3 path=NOTICE-ai-tech-lead.md message=ERROR: Refusing to overwrite 'NOTICE-ai-tech-lead.md': the existing file is not marked FRAMEWORK-OWNED.
[observed refusal] twin=sh exit=3 path=NOTICE-ai-tech-lead.md message=ERROR: Refusing to overwrite 'NOTICE-ai-tech-lead.md': the existing file is not marked FRAMEWORK-OWNED.
```

## Additional assertion REDs

The LF-normalised-identical case was red-tested by temporarily planting the old unconditional-copy
behavior in both generated dotnet installers, running the same command above, then restoring with:

```powershell
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File scripts/build.ps1 dotnet
```

Observed:

```text
[FAIL] update leaves an LF-normalised-identical licence byte-untouched (ps1) -- LF-normalised-identical licence was rewritten instead of left untouched
[FAIL] update leaves an LF-normalised-identical licence byte-untouched (sh) -- LF-normalised-identical licence was rewritten instead of left untouched
LicenseDelivery.Tests: 12 passed, 2 failed, 0 skipped
RESULT LicenseDelivery.Tests.ps1 2
OBSERVED_EXIT=2
composed dist/dotnet (166 files)
RESTORE_BUILD_EXIT=0
```

The brownfield smoke's fixture guard was red-tested by temporarily removing its `TECH_DEBT.md`
adoption signal, running the same command, then restoring the signal. Observed:

```text
[FAIL] brownfield without a legal collision creates both files (ps1) -- fixture did not exercise brownfield mode
[FAIL] brownfield without a legal collision creates both files (sh) -- fixture did not exercise brownfield mode
LicenseDelivery.Tests: 12 passed, 2 failed, 0 skipped
RESULT LicenseDelivery.Tests.ps1 2
OBSERVED_EXIT=2
```

## Installer behavior and smoke: final GREEN

Command:

```powershell
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File .claude/hooks/tests/Invoke-HookTests.ps1 -File LicenseDelivery.Tests.ps1 -Sequential
```

Observed after every planted defect was restored:

```text
[ok] greenfield creates the licence and notice with the shipped content (dotnet/ps1)
[ok] brownfield without a legal collision creates both files (dotnet/ps1)
[ok] greenfield creates the licence and notice with the shipped content (angular/ps1)
[ok] brownfield without a legal collision creates both files (angular/ps1)
[ok] greenfield creates the licence and notice with the shipped content (monorepo/ps1)
[ok] brownfield without a legal collision creates both files (monorepo/ps1)
[ok] brownfield refuses a conflicting LICENSES/ai-tech-lead-MIT.txt without changing it (ps1)
[ok] brownfield refuses a conflicting NOTICE-ai-tech-lead.md without changing it (ps1)
[ok] update replaces a stale framework-owned notice (ps1)
[ok] update leaves an LF-normalised-identical licence byte-untouched (ps1)
[ok] update refuses a notice whose ownership marker was removed (ps1)
[ok] greenfield creates the licence and notice with the shipped content (dotnet/sh)
[ok] brownfield without a legal collision creates both files (dotnet/sh)
[ok] greenfield creates the licence and notice with the shipped content (angular/sh)
[ok] brownfield without a legal collision creates both files (angular/sh)
[ok] greenfield creates the licence and notice with the shipped content (monorepo/sh)
[ok] brownfield without a legal collision creates both files (monorepo/sh)
[ok] brownfield refuses a conflicting LICENSES/ai-tech-lead-MIT.txt without changing it (sh)
[ok] brownfield refuses a conflicting NOTICE-ai-tech-lead.md without changing it (sh)
[ok] update replaces a stale framework-owned notice (sh)
[ok] update leaves an LF-normalised-identical licence byte-untouched (sh)
[ok] update refuses a notice whose ownership marker was removed (sh)
LicenseDelivery.Tests: 22 passed, 0 failed, 0 skipped
RESULT LicenseDelivery.Tests.ps1 0
OBSERVED_EXIT=0
```

The first six cases per twin are the requested greenfield and successful brownfield smoke installs;
they run every shipped dist installer in real temporary directories and verify both legal files.

## Licence drift gate: RED then GREEN

Initial missing-copy RED command:

```powershell
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File .claude/hooks/tests/Invoke-HookTests.ps1 -File LicenseDrift.Tests.ps1 -Sequential
```

Observed:

```text
[FAIL] src/core licence is LF-normalised byte-identical to root LICENSE -- Could not find ... src\core\LICENSES\ai-tech-lead-MIT.txt
RESULT LicenseDrift.Tests.ps1 1
OBSERVED_EXIT=1
```

After creation, one byte was deliberately perturbed (`Costas` → `Costa`) and the same literal
command was run. Observed:

```text
[FAIL] src/core licence is LF-normalised byte-identical to root LICENSE -- src/core/LICENSES/ai-tech-lead-MIT.txt differs from root LICENSE after LF normalisation
LicenseDrift.Tests: 0 passed, 1 failed, 0 skipped
RESULT LicenseDrift.Tests.ps1 1
OBSERVED_EXIT=1
```

The byte was restored and the same command was run again. Observed:

```text
[ok] src/core licence is LF-normalised byte-identical to root LICENSE
LicenseDrift.Tests: 1 passed, 0 failed, 0 skipped
RESULT LicenseDrift.Tests.ps1 0
OBSERVED_EXIT=0
```

## Syntax, encoding, and equality

Commands:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' -n src/core/scripts/install.sh
$tokens=$null; $errors=$null
[Management.Automation.Language.Parser]::ParseFile((Resolve-Path 'src/core/scripts/install.ps1'),[ref]$tokens,[ref]$errors) | Out-Null
$errors.Count
```

Observed:

```text
BASH_PARSE_EXIT=0
PS_PARSE_ERRORS=0
src/core/scripts/install.ps1 BOM=True
.claude/hooks/tests/LicenseDelivery.Tests.ps1 BOM=True
.claude/hooks/tests/LicenseDrift.Tests.ps1 BOM=True
LICENSE_EQUAL=True
```

## Assertions not shown failing

None. The original tree supplied the artifact/collision/update REDs; one-byte licence drift supplied
the equality RED; deliberately planted unconditional-copy and missing-adoption-signal states supplied
the two assertions added after the first red run. Every planted change was restored before the final
green runs.

Per instruction, the full `validate-dist` sweep and full hook suites were not run.
