# B-86 independent post-ship review — v0.44.0

Review surface: release commit `ae438a1`, documentation follow-up `e305f55`. Findings cite the
release-commit line where that differs from `HEAD`. I did not run the release script, alter a tag,
commit, push, or mutate `dist/`.

## Findings

### Check 8 can lose eleven of its 26 references and still satisfy its vacuous-pass guard

- **Severity: P2.** This is the B-59/B-74 failure class the release was intended to close: a partly
  inert extractor still reports success. The real extraction is 6 + 6 + 14 references, not the
  source comment's 6 + 6 + 8; a floor of 15 permits 42% of the advertised surface to disappear.
- **Exact file:line:** `scripts/validate-dist.ps1:287-290`; `scripts/validate-dist.sh:257-259`.
- **Failing scenario:** rename all six `command` keys in `.claude/settings.json` on a scratch dist.
  Claude Code has lost all six registrations in that file, but the other 20 textual references keep
  `$regCount` above 15 and the PowerShell validator prints `all 20 hook registrations resolve` and
  exits 0.
- **Proof command (Windows PowerShell, from repo root):**

  ```powershell
  $s = Join-Path ([IO.Path]::GetTempPath()) ('b86-floor-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory $s | Out-Null; Copy-Item -Recurse dist/dotnet $s
  $f = Join-Path $s 'dotnet/.claude/settings.json'
  $x = [IO.File]::ReadAllText($f) -replace '"command"\s*:', '"commande":'
  [IO.File]::WriteAllText($f, $x, [Text.UTF8Encoding]::new($false))
  $ps = (Get-Process -Id $PID).Path
  & $ps -NoProfile -ExecutionPolicy Bypass -File scripts/validate-dist.ps1 dotnet $s
  "EXIT=$LASTEXITCODE; SCRATCH=$s"
  ```
- **Verification:** verified by execution under Windows PowerShell 5.1: exit 0 and `all 20 hook
  registrations resolve`. The clean dist independently extracted 26 (6 + 6 + 14), so the
  quantitative claim in `CHANGELOG.md:45` and `DEVELOPING.md:74` is correct; the 6 + 6 + 8 comment
  in the gate is not.

### Check 8 silently exempts an absolute missing hook target while claiming to resolve every reference

- **Severity: P2.** A committed absolute target is a portability defect and a dead hook on every
  machine except the one named. Both twins deliberately return without checking it, so this is an
  identical false green rather than parity. It is also a documentation overclaim: `CHANGELOG.md:43-45`
  and `DEVELOPING.md:71-74` say every named script exists in the dist, with no absolute-path exception.
- **Exact file:line:** `scripts/validate-dist.ps1:59-60`; `scripts/validate-dist.sh:199-200`.
- **Failing scenario:** a settings registration names `C:/definitely-missing/session-start.ps1`.
  No such target or twin exists, yet both validators print `all 26 hook registrations resolve` and
  exit 0.
- **Proof command (Windows PowerShell, from repo root):**

  ```powershell
  $s = Join-Path ([IO.Path]::GetTempPath()) ('b86-abs-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory $s | Out-Null; Copy-Item -Recurse dist/dotnet $s
  $f = Join-Path $s 'dotnet/.claude/settings.json'
  $x = [IO.File]::ReadAllText($f).Replace('.claude/hooks/session-start.ps1','C:/definitely-missing/session-start.ps1')
  [IO.File]::WriteAllText($f, $x, [Text.UTF8Encoding]::new($false))
  $ps = (Get-Process -Id $PID).Path
  & $ps -NoProfile -ExecutionPolicy Bypass -File scripts/validate-dist.ps1 dotnet $s; "PS_EXIT=$LASTEXITCODE"
  $env:PATH = 'C:\Windows\System32\WindowsPowerShell\v1.0;' + $env:PATH
  $p = $s.Replace('\','/').Replace('C:','/c')
  & 'C:\Program Files\Git\usr\bin\bash.exe' scripts/validate-dist.sh dotnet $p; "SH_EXIT=$LASTEXITCODE; SCRATCH=$s"
  ```
- **Verification:** verified by execution on both twins: each exited 0 and claimed all 26 references
  resolved.

### A quoted relative `-File` value is truncated to a slash and then silently exempted

- **Severity: P2.** This is another false-green extraction path, not merely lack of support for a
  cosmetic spelling. JSON permits the escaped quotes and PowerShell requires them for a path with a
  space; the registration can name a nonexistent script and still pass.
- **Exact file:line:** `scripts/validate-dist.ps1:267,274-276`; `scripts/validate-dist.sh:242,232-239`.
- **Failing scenario:** `-File \".claude/hooks/definitely missing.ps1\"`. The outer textual JSON
  regex stops at the escaped quote; the inner extraction sees the escape backslash, normalization
  turns it into `/`, and the absolute-path early return suppresses the missing-target finding.
- **Proof command (Windows PowerShell, from repo root):**

  ```powershell
  $s = Join-Path ([IO.Path]::GetTempPath()) ('b86-space-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory $s | Out-Null; Copy-Item -Recurse dist/dotnet $s
  $f = Join-Path $s 'dotnet/.claude/settings.json'
  $x = [IO.File]::ReadAllText($f).Replace('-File .claude/hooks/session-start.ps1','-File \".claude/hooks/definitely missing.ps1\"')
  [IO.File]::WriteAllText($f, $x, [Text.UTF8Encoding]::new($false))
  $ps = (Get-Process -Id $PID).Path
  & $ps -NoProfile -ExecutionPolicy Bypass -File scripts/validate-dist.ps1 dotnet $s
  "EXIT=$LASTEXITCODE; SCRATCH=$s"
  ```
- **Verification:** verified by execution under Windows PowerShell 5.1: the nonexistent quoted
  target produced exit 0 and `all 26 hook registrations resolve`. I also ran both twins with the
  quoted target and real twin files present; both exited 0, confirming that the syntax reaches this
  extraction path.

### The staged-set guard accepts scratch, backup, or temp files anywhere under six broad directories

- **Severity: P2.** This rejects the instrument's premise. B-80's general hazard was `git add -A`
  sweeping scratch/editor/temp output into a release. The guard catches that class only at an
  unfamiliar top-level path; `src/notes.tmp`, `meta/review.txt`, or `.claude/debug.log` are classified
  as expected and committed silently. `CHANGELOG.md:63` therefore overclaims that release.ps1 “no
  longer commits whatever is in the tree.”
- **Exact file:line:** `ae438a1:.claude/scripts/release.ps1:351-365,374`; the green fixture at
  `ae438a1:.claude/hooks/tests/ReleaseStagingGuard.Tests.ps1:84-90` tests only the directory, not
  whether a file belongs to the release.
- **Failing scenario:** an untracked `src/release-notes.tmp` exists when step 5 runs. `git add -A`
  stages it, the allowlist matches `src/`, `$unexpected` remains empty, and the release commits it
  without warning.
- **Proof command (Windows PowerShell, from repo root):**

  ```powershell
  $text = git show 'ae438a1:.claude/scripts/release.ps1' | Out-String
  $line = @($text -split "`n" | Where-Object { $_ -match '^\$expectedPathPattern\s*=' })
  $pattern = [regex]::Match($line[0], "'(.+)'").Groups[1].Value
  "src/release-notes.tmp MATCHES_ALLOWLIST=$('src/release-notes.tmp' -match $pattern)"
  ```
- **Verification:** verified against the verbatim release-commit pattern; it returns `True`. The
  control `scratch-notes.txt` returns `False`. I did not run the release script, as prohibited.

### Git-quoted non-ASCII paths are misclassified as unexpected and refuse a legitimate release

- **Severity: P2.** This is a deterministic false-positive refusal on a normal Git configuration.
  It blocks releases containing valid non-ASCII filenames under sanctioned directories and pushes
  maintainers toward the bypass. Content is not lost, so this is not P1.
- **Exact file:line:** `ae438a1:.claude/scripts/release.ps1:348,366-374`.
- **Failing scenario:** with `core.quotepath=true`, staging `meta/café.txt` makes
  `git diff --cached --raw` emit `"meta/caf\303\251.txt"`. The code takes the quoted field verbatim;
  its leading quote prevents the `^meta/` allowlist match, so step 5a refuses a legitimate path.
- **Proof command (Windows PowerShell, from repo root):**

  ```powershell
  $d = Join-Path ([IO.Path]::GetTempPath()) ('b86-quoted-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory $d | Out-Null; git -C $d init -q
  git -C $d config core.quotepath true; New-Item -ItemType Directory (Join-Path $d meta) | Out-Null
  [IO.File]::WriteAllText((Join-Path $d 'meta/café.txt'),'x',[Text.UTF8Encoding]::new($false)); git -C $d add -A
  $raw = @(git -C $d diff --cached --raw)[0]; $path = ($raw -split "`t")[-1]
  $text = git show 'ae438a1:.claude/scripts/release.ps1' | Out-String
  $line = @($text -split "`n" | Where-Object { $_ -match '^\$expectedPathPattern\s*=' })
  $pattern = [regex]::Match($line[0], "'(.+)'").Groups[1].Value
  "RAW=$raw"; "EXTRACTED=$path"; "MATCH=$($path -match $pattern); SCRATCH=$d"
  ```
- **Verification:** verified by execution with Git 2.51.0: raw output was
  `"meta/caf\303\251.txt"` and `MATCH=False`.

### Refusal resets the whole index; it does not leave pre-existing staged state “exactly as found”

- **Severity: P3.** No worktree content is deleted, but a maintainer's intentional partial staging
  is discarded. This contradicts both the source comment and the root record. It is lower severity
  than the release-integrity false greens because the state is reconstructable.
- **Exact file:line:** `ae438a1:.claude/scripts/release.ps1:342-343,387,403`; the test codifies the
  wrong postcondition at `ae438a1:.claude/hooks/tests/ReleaseStagingGuard.Tests.ps1:92-100` by
  asserting that the index is empty, not restored. The same false claim is in `CHANGELOG.md:69` and
  `meta/BACKLOG.md:1444-1446`.
- **Failing scenario:** `src/a.txt` was staged before release invocation; an unexpected top-level
  scratch file causes refusal. The unconditional `git reset --quiet` removes both the release-added
  entry and the user's pre-existing staged entry.
- **Proof command (Windows PowerShell, from repo root):**

  ```powershell
  $d = Join-Path ([IO.Path]::GetTempPath()) ('b86-index-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory $d | Out-Null; git -C $d init -q
  git -C $d config user.email test@example.invalid; git -C $d config user.name test
  New-Item -ItemType Directory (Join-Path $d src) | Out-Null
  Set-Content (Join-Path $d 'src/a.txt') baseline; git -C $d add -A; git -C $d commit -qm init
  Set-Content (Join-Path $d 'src/a.txt') prestaged; git -C $d add src/a.txt
  "BEFORE=$(@(git -C $d diff --cached --name-only) -join ',')"
  Set-Content (Join-Path $d 'scratch-notes.txt') unexpected; git -C $d add -A; git -C $d reset --quiet
  "AFTER=$(@(git -C $d diff --cached --name-only) -join ','); SCRATCH=$d"
  ```
- **Verification:** verified by execution: `BEFORE=src/a.txt`; `AFTER=`. Both worktree changes
  remained present.

## Claims and seed hypotheses checked without a finding

- `HarnessIntegrity.Tests.ps1` genuinely detects the historical single-failure scoreboard defect
  under Windows PowerShell 5.1. I copied the shipped harness, runner, and integrity test to scratch,
  removed `@()` only from the harness failure count, and observed the integrity test exit 2; the
  unmodified shipped test then passed 4/4 and exited 0. This is a real red-to-green observation.
- The check-8 twins implement the same floor, backslash-run normalization, absolute-path exemption,
  and twin rule. On a missing `audit-trail.sh`, both exited 1 and emitted the same four
  `[hook-registration]` findings. Their surrounding full gate output is not byte-identical (host
  names and Windows/POSIX scratch paths differ), so I interpret the changelog's “byte-identical
  findings” as the finding records, not the complete output.
- The “26 registrations per dist” claim is correct when a PowerShell and bash registration in
  `hooks.json` are counted separately: 6 + 6 + 14 = 26 in each dist.
- The historical replay numbers are reproducible. For the eight tags preceding v0.44.0
  (`v0.43.0` through `v0.37.0`), 266 path occurrences were classified. The reconstructed first-cut
  scope (`src/`, `dist/`, `meta/`, `CHANGELOG.md`) produces exactly 10 false positives: eight
  `README.md` occurrences and two `.claude/hooks/tests/` files in v0.41.0.
- An empty `(Get-Process -Id $PID).Path` would prevent child launch and make the integrity assertions
  fail; I found no false-green route from reading. Host availability remains unverified below.

## COULD NOT VERIFY FROM THE SANDBOX

- PowerShell 7 (`pwsh`) was not resolvable on this sandbox's PATH, so I could not independently run
  the harness integrity test under pwsh 7. This is an environment limitation, not a finding.
- I could not create a hosted runspace or ISE process where `(Get-Process -Id $PID).Path` is empty,
  so seed hypothesis 5's host-availability premise was not executed.
- I did not run `.claude/scripts/release.ps1` end to end because the review constraints expressly
  prohibit it. Release-guard findings above were exercised using scratch Git repositories and the
  verbatim release-commit classifier/reset operations.
- I did not reproduce all three original check-8 red fixtures and compare their bytes. I verified
  the twin-missing fixture's four finding records, plus the absolute-target false green on both
  twins; the renamed-hook and missing-`hooks.json`-target byte comparisons remain unexecuted.
