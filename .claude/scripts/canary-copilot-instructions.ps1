#requires -Version 7.0
<#
  B-97 canary 2 — does an UNPROTECTED .github/instructions/ file reach Copilot?

  Why it decides the design: the installer protects CLAUDE.md, AGENTS.md and
  .github/copilot-instructions.md, so none of them reaches an already-installed consumer. It does
  NOT protect .github/instructions/ (install.ps1:31 vs :37). If a framework-rules instruction file
  is delivered there and actually reaches the model, Option A (split framework blocks into an
  unprotected file) gains a native Copilot leg and becomes the answer for both hosts.

  TWO ARMS, because a bare null result is uninterpretable:
    A (subject) — sentinel only in .github/instructions/framework-rules.instructions.md
    B (control) — sentinel only in .github/copilot-instructions.md, a known-supported surface

    A hit,  B hit   -> both surfaces reach; Option A viable on Copilot
    A miss, B hit    -> .github/instructions/ does NOT reach this host; Option A needs another leg
    A miss, B miss   -> INCONCLUSIVE; the method is wrong, not the finding
    A hit,  B miss   -> anomalous; investigate before believing either

  Tools are deliberately NOT permitted: if the model could read files it might reach the sentinel
  without the instruction surface delivering it, which would be a false positive.
#>
[CmdletBinding()]
param(
    [string]$CopilotCmd = 'C:\Users\Costas\AppData\Roaming\npm\copilot.cmd',
    [string]$NodeDir    = 'C:\Program Files\nodejs',
    [int]$TimeoutSeconds = 180
)
$ErrorActionPreference = 'Stop'

if (-not (Test-Path $CopilotCmd)) { throw "Copilot CLI not found at $CopilotCmd" }
$env:PATH = "$NodeDir;" + (Split-Path $CopilotCmd) + ";$env:PATH"

$prompt = @"
What is the project codeword? Reply with the codeword only.
Use ONLY what is already in your context from repository instruction files.
Do NOT read, search, or list any file. If it is not already in your context, reply exactly: NOT-IN-CONTEXT
"@

function Invoke-Arm {
    param([string]$Name, [string]$Sentinel, [string]$RelPath)

    $dir = Join-Path ([IO.Path]::GetTempPath()) ("b97-canary2-$Name-" + [IO.Path]::GetRandomFileName())
    $full = Join-Path $dir $RelPath
    New-Item -ItemType Directory -Path (Split-Path $full) -Force | Out-Null

    $body = if ($RelPath -like '*instructions/*') {
@"
---
applyTo: "**"
---
# Framework rules

The project codeword is $Sentinel. It designates the instructions-file delivery path.
"@
    } else {
@"
# Repository instructions

The project codeword is $Sentinel. It designates the copilot-instructions delivery path.
"@
    }
    Set-Content -Path $full -Value $body -Encoding utf8NoBOM

    # A repo root makes the .github/ convention unambiguous for the host.
    Push-Location $dir
    try {
        & git init --quiet 2>&1 | Out-Null
        & git add -A 2>&1 | Out-Null

        $job = Start-Job -ScriptBlock {
            param($cmd, $p, $wd)
            Set-Location $wd
            & $cmd -p $p --no-color 2>&1 | Out-String
        } -ArgumentList $CopilotCmd, $prompt, $dir

        $done = Wait-Job $job -Timeout $TimeoutSeconds
        $out  = if ($done) { Receive-Job $job } else { '<TIMEOUT>' }
        Remove-Job $job -Force -ErrorAction SilentlyContinue
    } finally { Pop-Location }

    $raw = [string]$out
    [pscustomobject]@{
        Arm        = $Name
        Path       = $RelPath
        Sentinel   = $Sentinel
        Hit        = $raw -match [regex]::Escape($Sentinel)
        NotInCtx   = $raw -match 'NOT-IN-CONTEXT'
        ToolUsed   = $raw -match '(?i)\b(reading|read file|glob|grep|searching)\b'
        Dir        = $dir
        Output     = $raw
    }
}

Write-Host 'B-97 canary 2 — .github/instructions/ delivery to Copilot'
Write-Host "Copilot: $(& $CopilotCmd --version 2>&1 | Select-Object -First 1)"
Write-Host ''

$armA = Invoke-Arm -Name 'subject' -Sentinel 'QUVIRAX-3T8P' -RelPath '.github/instructions/framework-rules.instructions.md'
Write-Host "  A (.github/instructions/)      hit=$($armA.Hit) notInCtx=$($armA.NotInCtx)"
$armB = Invoke-Arm -Name 'control' -Sentinel 'MELDOVAR-9K2R' -RelPath '.github/copilot-instructions.md'
Write-Host "  B (.github/copilot-instructions) hit=$($armB.Hit) notInCtx=$($armB.NotInCtx)"

Write-Host ''
Write-Host '=== VERDICT ==='
if     ($armA.Hit -and $armB.Hit)       { Write-Host 'BOTH REACH — .github/instructions/ delivers; Option A gains a native Copilot leg.'; $code = 0 }
elseif (-not $armA.Hit -and $armB.Hit)  { Write-Host 'SUBJECT MISS, CONTROL HIT — .github/instructions/ does NOT reach this host. Option A needs another Copilot leg.'; $code = 1 }
elseif (-not $armA.Hit -and -not $armB.Hit) { Write-Host 'INCONCLUSIVE — control also failed, so the method is wrong, not the finding. Do not record either way.'; $code = 2 }
else   { Write-Host 'ANOMALOUS — subject hit while the known-good control missed. Investigate before believing either.'; $code = 3 }

Write-Host ''
Write-Host "  A output: $($armA.Dir)"
Write-Host "  B output: $($armB.Dir)"
exit $code
