#requires -Version 7.0
<#
  B-143 canary — does Copilot honour a BRACE (and a COMMA) `applyTo` glob?

  Why this is a separate script from canary-applyto-scope.ps1 rather than two more arms on it:
  that canary's prompt deliberately NAMES NO FILE, which is the right design for its own question
  ("is breadth load-bearing?") and the wrong one for this. A narrow glob that never attaches to a
  file cannot distinguish "braces are unsupported" from "this prompt didn't engage the scope at
  all" — the two failures look identical. So every arm here NAMES the matching file.

  The risk being measured: two shipped READMEs tell consumers to write
  `applyTo: "**/*.{ts,html}"`. Nothing has ever verified Copilot honours a brace glob, and canary 3
  established that a non-matching `applyTo` FAILS SILENTLY — the instructions simply never arrive
  and the developer sees a correctly installed file either way. If braces are unsupported we are
  walking consumers into a config that delivers nothing and looks fine.

  Arms (fresh repo each, distinct sentinel each, identical prompt naming app.ts):
    single — applyTo: "**/*.ts"            intended as the positive control -- SEE THE RESULT BELOW
    brace  — applyTo: "**/*.{ts,html}"     the form our READMEs actually recommend
    comma  — applyTo: "**/*.ts,**/*.html"  the plausible alternative if braces fail

  Reading:
    single MISS            -> INVALID run. Do not interpret the others; the control failed.
    single hit, brace hit  -> braces are honoured. Keep the README advice, record it verified.
    single hit, brace miss -> braces are NOT honoured. Correct both READMEs to a verified form
                              (use `comma` if it hit; otherwise separate files per extension).

  ============================================================================================
  RESULT, 2026-08-18, Copilot CLI 1.0.80 — RAN, VALID-INVALID, AND THE DESIGN IS CONFOUNDED.
  ============================================================================================
  All three arms MISSED (single=False brace=False comma=False), so this reported INVALID and
  refused to let the brace result be read. That refusal was correct and it is the useful part.

  The reason is a flaw in THIS script's control, not in Copilot: `single` is itself a NARROW
  glob, and `canary-applyto-scope.ps1` had already established that a narrow `applyTo` does not
  deliver. Re-run the same day on 1.0.80 to confirm it still holds: star `"**"` HIT, narrow
  `"**/*.cs"` MISS, no-frontmatter HIT. So the control here was the very thing already known to
  fail — a positive control has to be a form known to SUCCEED.

  What that jointly establishes, and it is stronger than the question asked: on Copilot CLI in
  `-p` mode, a narrow `applyTo` delivers nothing EVEN WHEN a matching file exists AND the prompt
  names it (this script's prompt names app.ts; canary 3's names no file; both miss). Therefore
  the brace-versus-comma question is MOOT ON THIS SURFACE — narrowness alone defeats delivery,
  whatever the punctuation. Braces are neither confirmed nor refuted, and no run on this surface
  can separate them.

  Do NOT "fix" this by swapping the control to `"**"`: that would make the run report VALID
  while measuring nothing, because the brace arm would still miss for the narrowness reason and
  the script would blame the braces. The confound is real and the honest move is to say so.
  The open question belongs to VS Code agent mode, where `applyTo` scoping is the documented
  mechanism and the file-context model differs — and which remains unverified (B-43).
#>
[CmdletBinding()]
param(
    [string]$CopilotCmd = '',
    [string]$NodeDir    = 'C:\Program Files\nodejs',
    [int]$TimeoutSeconds = 180
)
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($CopilotCmd)) {
    if ([string]::IsNullOrWhiteSpace($env:APPDATA)) { throw 'Copilot CLI not found; pass -CopilotCmd.' }
    $CopilotCmd = Join-Path $env:APPDATA 'npm\copilot.cmd'
}
if (-not (Test-Path -LiteralPath $CopilotCmd -PathType Leaf)) { throw 'Copilot CLI not found; pass -CopilotCmd.' }
$CopilotCmd = (Resolve-Path -LiteralPath $CopilotCmd).Path
$env:PATH = "$NodeDir;" + (Split-Path $CopilotCmd) + ";$env:PATH"

# Names the matching file, so a narrow glob has something to attach to, and forbids reading it so
# a hit can only come from instruction delivery rather than from the model opening the file.
$prompt = 'Considering app.ts in this repository, what is the project codeword? Reply with the ' +
          'codeword only. Use ONLY what is already in your context from repository instruction ' +
          'files. Do NOT read, search, or list any file. If it is not already in your context, ' +
          'reply exactly: NOT-IN-CONTEXT'

$base = Join-Path ([IO.Path]::GetTempPath()) ('b143-brace-' + [IO.Path]::GetRandomFileName())

# Folder trust. Copilot does not load repository-scoped configuration from an untrusted folder, and
# there is no flag to grant trust non-interactively -- but `trustedFolders` in the CLI's own config
# is a plain array of absolute paths and writing to it is honoured exactly as if the interactive
# prompt had been accepted (established 2026-08-13, re-confirmed by the B-52 canary 2026-08-18).
# Without this, EVERY arm reports NOT-IN-CONTEXT and the run is INVALID -- which is what happened on
# the first attempt at this canary, and is indistinguishable from "braces are unsupported" if you
# are not looking for it. The control arm exists to catch exactly that, and did.
$copilotConfig = Join-Path $env:USERPROFILE '.copilot\config.json'
$configBackup  = $null
function Grant-Trust([string[]]$Paths) {
    if (-not (Test-Path -LiteralPath $copilotConfig)) { throw "no Copilot config at the expected path; cannot grant trust" }
    $script:configBackup = [IO.File]::ReadAllText($copilotConfig)
    $cfg = $script:configBackup | ConvertFrom-Json
    $cfg.trustedFolders = @($Paths)
    [IO.File]::WriteAllText($copilotConfig, ($cfg | ConvertTo-Json -Depth 10))
}
function Restore-Trust {
    if ($null -ne $script:configBackup) {
        [IO.File]::WriteAllText($copilotConfig, $script:configBackup)
        $script:configBackup = $null
    }
}

$arms = @(
    @{ Name = 'single'; Sentinel = 'MORVELLI-3K8P'; ApplyTo = '"**/*.ts"' }
    @{ Name = 'brace';  Sentinel = 'TALVEDRA-9Q4Z'; ApplyTo = '"**/*.{ts,html}"' }
    @{ Name = 'comma';  Sentinel = 'HESPERIN-6L2Y'; ApplyTo = '"**/*.ts,**/*.html"' }
)

Grant-Trust @($arms | ForEach-Object { Join-Path $base $_.Name })
try {

$results = foreach ($a in $arms) {
    $dir = Join-Path $base $a.Name
    New-Item -ItemType Directory -Path (Join-Path $dir '.github/instructions') -Force | Out-Null

    # Real files for BOTH extensions the brace/comma forms name, so neither half is vacuous.
    Set-Content -Path (Join-Path $dir 'app.ts')    -Value 'export const x = 1;'      -Encoding utf8NoBOM
    Set-Content -Path (Join-Path $dir 'page.html') -Value '<p>hello</p>'             -Encoding utf8NoBOM

    Set-Content -Path (Join-Path $dir '.github/instructions/framework-rules.instructions.md') `
                -Value "---`napplyTo: $($a.ApplyTo)`n---`n# Framework rules`n`nThe project codeword is $($a.Sentinel).`n" `
                -Encoding utf8NoBOM

    Push-Location $dir
    try {
        & git init --quiet 2>&1 | Out-Null
        $job = Start-Job -ScriptBlock {
            param($cmd, $p, $wd) Set-Location $wd; & $cmd -p $p --no-color 2>&1 | Out-String
        } -ArgumentList $CopilotCmd, $prompt, $dir
        $done = Wait-Job $job -Timeout $TimeoutSeconds
        $out  = if ($done) { [string](Receive-Job $job) } else { '<TIMEOUT>' }
        Remove-Job $job -Force -ErrorAction SilentlyContinue
    } finally { Pop-Location }

    Set-Content -Path (Join-Path $base "$($a.Name).txt") -Value $out -Encoding utf8NoBOM
    [pscustomobject]@{
        Arm      = $a.Name
        ApplyTo  = $a.ApplyTo
        Hit      = $out -match [regex]::Escape($a.Sentinel)
        NotInCtx = $out -match 'NOT-IN-CONTEXT'
    }
}

} finally { Restore-Trust }

$results | Format-Table -AutoSize | Out-String | Write-Host

$single = ($results | Where-Object Arm -eq 'single').Hit
$brace  = ($results | Where-Object Arm -eq 'brace').Hit
$comma  = ($results | Where-Object Arm -eq 'comma').Hit

Write-Host '=== VERDICT ==='
if (-not $single) {
    Write-Host 'INVALID -- the single-glob control did not deliver; do not interpret the other arms.'
    $code = 3
} elseif ($brace) {
    Write-Host 'BRACES ARE HONOURED -- the shipped README advice is correct. Record it verified.'
    $code = 0
} else {
    Write-Host 'BRACES ARE NOT HONOURED -- two shipped READMEs walk consumers into a config that'
    Write-Host '  delivers nothing and looks correctly installed. Correct them.'
    Write-Host "  comma form delivered: $comma  (use it only if true; otherwise one file per extension)"
    $code = 1
}
Write-Host "  single=$single brace=$brace comma=$comma"
Write-Host "  outputs: $base"
exit $code
