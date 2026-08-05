# B-41 maintainer-only live agent eval harness. This intentionally has no bash twin: meta tooling
# is PowerShell-only by WSD-012. It never runs in CI and spends API/subscription budget only with
# the explicit -Live switch.
[CmdletBinding(DefaultParameterSetName = 'Explain')]
param(
    [Parameter(ParameterSetName = 'Live', Mandatory)][switch]$Live,
    [Parameter(ParameterSetName = 'SelfTest', Mandatory)][switch]$SelfTest,
    [Parameter(ParameterSetName = 'Live')][string[]]$Scenario,
    [Parameter(ParameterSetName = 'Live')][string]$Model = 'sonnet',
    [Parameter(ParameterSetName = 'Live')][ValidateRange(30, 1800)][int]$TimeoutSeconds = 300,
    [Parameter(ParameterSetName = 'Live')][bool]$KeepScratch = $true,
    [Parameter(ParameterSetName = 'Live')][string]$ResultsPath
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$scenarioPath = Join-Path $PSScriptRoot 'scenarios.json'
if (-not $ResultsPath) { $ResultsPath = Join-Path $repo 'meta/eval-results.md' }

function Assert-Bom([string]$Path) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    return $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
}

function New-EvalRepo([string]$Path, [ValidateSet('dotnet','angular','warehouse')][string]$Stack = 'dotnet') {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    if ($Stack -eq 'warehouse') {
        New-Item -ItemType Directory -Path (Join-Path $Path 'Tables'), (Join-Path $Path 'StoredProcedures'), (Join-Path $Path 'Views'), (Join-Path $Path 'analysis') -Force | Out-Null
        '<Project Sdk="Microsoft.Build.Sql/0.2.0" />' | Set-Content -LiteralPath (Join-Path $Path 'warehouse.sqlproj') -Encoding utf8NoBOM
        @'
CREATE TABLE dim.DimCustomer (
    CustomerKey INT NOT NULL PRIMARY KEY,
    CustomerId NVARCHAR(50) NOT NULL,
    RegionKey INT NOT NULL,
    SegmentName NVARCHAR(100) NOT NULL,
    EffectiveFrom DATETIME2 NOT NULL,
    EffectiveTo DATETIME2 NULL,
    IsCurrent BIT NOT NULL
);
'@ | Set-Content -LiteralPath (Join-Path $Path 'Tables/dim.DimCustomer.sql') -Encoding utf8NoBOM
        'CREATE TABLE dim.DimRegion (RegionKey INT NOT NULL PRIMARY KEY, RegionName NVARCHAR(100) NOT NULL);' | Set-Content -LiteralPath (Join-Path $Path 'Tables/dim.DimRegion.sql') -Encoding utf8NoBOM
        'CREATE TABLE dim.DimDate (DateKey INT NOT NULL PRIMARY KEY, CalendarDate DATE NOT NULL, CalendarMonth INT NOT NULL);' | Set-Content -LiteralPath (Join-Path $Path 'Tables/dim.DimDate.sql') -Encoding utf8NoBOM
        'CREATE TABLE dim.DimProduct (ProductKey INT NOT NULL PRIMARY KEY, ProductId NVARCHAR(50) NOT NULL, CategoryName NVARCHAR(100) NOT NULL);' | Set-Content -LiteralPath (Join-Path $Path 'Tables/dim.DimProduct.sql') -Encoding utf8NoBOM
        @'
CREATE TABLE fact.FactSales (
    SalesKey BIGINT NOT NULL PRIMARY KEY,
    CustomerKey INT NOT NULL,
    ProductKey INT NOT NULL,
    OrderDateKey INT NOT NULL,
    NetAmount DECIMAL(18,2) NOT NULL,
    RegionName NVARCHAR(100) NULL,
    CategoryName NVARCHAR(100) NULL,
    SegmentName NVARCHAR(100) NULL,
    LoadRunId BIGINT NOT NULL
);
'@ | Set-Content -LiteralPath (Join-Path $Path 'Tables/fact.FactSales.sql') -Encoding utf8NoBOM
        'CREATE TABLE stg.StgSalesOrder (SalesId BIGINT NOT NULL, CustomerId NVARCHAR(50) NOT NULL, ProductId NVARCHAR(50) NOT NULL, OrderDate DATE NOT NULL, NetAmount DECIMAL(18,2) NOT NULL, BatchId BIGINT NOT NULL);' | Set-Content -LiteralPath (Join-Path $Path 'Tables/stg.StgSalesOrder.sql') -Encoding utf8NoBOM
        'CREATE TABLE ctl.LoadRun (LoadRunId BIGINT NOT NULL PRIMARY KEY, StartedAt DATETIME2 NOT NULL, Watermark DATETIME2 NULL);' | Set-Content -LiteralPath (Join-Path $Path 'Tables/ctl.LoadRun.sql') -Encoding utf8NoBOM
        'CREATE PROCEDURE dbo.usp_LoadDimCustomer AS MERGE dim.DimCustomer AS target USING stg.StgSalesOrder AS source ON target.CustomerId = source.CustomerId WHEN NOT MATCHED THEN INSERT (CustomerKey, CustomerId, RegionKey, SegmentName, EffectiveFrom, IsCurrent) VALUES (-1, source.CustomerId, -1, ''Unknown'', SYSUTCDATETIME(), 1);' | Set-Content -LiteralPath (Join-Path $Path 'StoredProcedures/usp_LoadDimCustomer.sql') -Encoding utf8NoBOM
        'CREATE PROCEDURE dbo.usp_LoadDimRegion AS INSERT INTO dim.DimRegion (RegionKey, RegionName) SELECT DISTINCT -1, ''Unknown'' FROM stg.StgSalesOrder;' | Set-Content -LiteralPath (Join-Path $Path 'StoredProcedures/usp_LoadDimRegion.sql') -Encoding utf8NoBOM
        @'
CREATE PROCEDURE dbo.usp_LoadFactSales AS
INSERT INTO fact.FactSales (SalesKey, CustomerKey, ProductKey, OrderDateKey, NetAmount, LoadRunId)
SELECT s.SalesId, c.CustomerKey, p.ProductKey, d.DateKey, s.NetAmount, s.BatchId
FROM stg.StgSalesOrder s
JOIN dim.DimCustomer c ON c.CustomerId = s.CustomerId AND c.IsCurrent = 1
JOIN dim.DimProduct p ON p.ProductId = s.ProductId
JOIN dim.DimDate d ON d.CalendarDate = s.OrderDate;
'@ | Set-Content -LiteralPath (Join-Path $Path 'StoredProcedures/usp_LoadFactSales.sql') -Encoding utf8NoBOM
        @'
CREATE VIEW rpt.vwFinanceExtract AS
SELECT r.RegionName, f.NetAmount, d.CalendarDate
FROM fact.FactSales f
JOIN dim.DimCustomer c ON c.CustomerKey = f.CustomerKey
JOIN dim.DimRegion r ON r.RegionKey = c.RegionKey
JOIN dim.DimDate d ON d.DateKey = f.OrderDateKey;
'@ | Set-Content -LiteralPath (Join-Path $Path 'Views/rpt.vwFinanceExtract.sql') -Encoding utf8NoBOM
        'CREATE VIEW rpt.vwExecutiveSummary AS SELECT p.CategoryName, SUM(f.NetAmount) AS Revenue FROM fact.FactSales f JOIN dim.DimProduct p ON p.ProductKey = f.ProductKey GROUP BY p.CategoryName;' | Set-Content -LiteralPath (Join-Path $Path 'Views/rpt.vwExecutiveSummary.sql') -Encoding utf8NoBOM
        'CREATE VIEW rpt.vwOrderDetail AS SELECT f.SalesKey, f.CustomerKey, f.ProductKey, f.OrderDateKey, f.NetAmount FROM fact.FactSales f;' | Set-Content -LiteralPath (Join-Path $Path 'Views/rpt.vwOrderDetail.sql') -Encoding utf8NoBOM
        git -C $Path init --quiet
        git -C $Path config user.email 'agent-evals@invalid.local'
        git -C $Path config user.name 'Agent Evals'
        git -C $Path add -A
        git -C $Path commit --quiet -m 'fixture baseline'
        return
    }
    if ($Stack -eq 'angular') {
        @'
{
  "name": "eval-fixture",
  "private": true,
  "scripts": { "test": "ng test" },
  "dependencies": {
    "@angular/common": "^19.0.0",
    "@angular/core": "^19.0.0",
    "@angular/forms": "^19.0.0",
    "@angular/platform-browser": "^19.0.0"
  }
}
'@ | Set-Content -LiteralPath (Join-Path $Path 'package.json') -Encoding utf8NoBOM
        @'
{
  "$schema": "./node_modules/@angular/cli/lib/config/schema.json",
  "version": 1,
  "projects": {
    "eval-fixture": {
      "projectType": "application",
      "root": "",
      "sourceRoot": "src",
      "architect": {
        "build": { "builder": "@angular-devkit/build-angular:application", "options": { "browser": "src/main.ts", "tsConfig": "tsconfig.json" } },
        "test": { "builder": "@angular-devkit/build-angular:karma" }
      }
    }
  }
}
'@ | Set-Content -LiteralPath (Join-Path $Path 'angular.json') -Encoding utf8NoBOM
        @'
{
  "compilerOptions": {
    "strict": true,
    "noImplicitOverride": true,
    "noPropertyAccessFromIndexSignature": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "target": "ES2022",
    "module": "preserve",
    "moduleResolution": "bundler",
    "experimentalDecorators": true
  },
  "angularCompilerOptions": { "strictTemplates": true }
}
'@ | Set-Content -LiteralPath (Join-Path $Path 'tsconfig.json') -Encoding utf8NoBOM
        New-Item -ItemType Directory -Path (Join-Path $Path 'src/app/profile-form') -Force | Out-Null
        @'
import { bootstrapApplication } from '@angular/platform-browser';
import { provideHttpClient } from '@angular/common/http';
import { AppComponent } from './app/app.component';

bootstrapApplication(AppComponent, { providers: [provideHttpClient()] });
'@ | Set-Content -LiteralPath (Join-Path $Path 'src/main.ts') -Encoding utf8NoBOM
        @'
import { Component } from '@angular/core';
import { ProfileFormComponent } from './profile-form/profile-form.component';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [ProfileFormComponent],
  template: '<app-profile-form />',
})
export class AppComponent {}
'@ | Set-Content -LiteralPath (Join-Path $Path 'src/app/app.component.ts') -Encoding utf8NoBOM
        @'
import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';

@Injectable({ providedIn: 'root' })
export class UserService {
  private readonly http = inject(HttpClient);

  updateProfile(profile: { name: string; email: string }) {
    return this.http.put('/api/profile', profile);
  }
}
'@ | Set-Content -LiteralPath (Join-Path $Path 'src/app/user.service.ts') -Encoding utf8NoBOM
        @'
import { Component, inject } from '@angular/core';
import { FormBuilder, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';

@Component({
  selector: 'app-profile-form',
  standalone: true,
  imports: [ReactiveFormsModule],
  template: `
    <form [formGroup]="form">
      <label>Name <input formControlName="name" /></label>
      <label>Email <input formControlName="email" /></label>
    </form>
  `,
})
export class ProfileFormComponent {
  private readonly formBuilder = inject(FormBuilder);
  readonly form: FormGroup = this.formBuilder.group({
    name: ['', Validators.required],
    email: ['', [Validators.required, Validators.email]],
  });
}
'@ | Set-Content -LiteralPath (Join-Path $Path 'src/app/profile-form/profile-form.component.ts') -Encoding utf8NoBOM
        git -C $Path init --quiet
        git -C $Path config user.email 'agent-evals@invalid.local'
        git -C $Path config user.name 'Agent Evals'
        git -C $Path add -A
        git -C $Path commit --quiet -m 'fixture baseline'
        return
    }
    @'
<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup></Project>
'@ | Set-Content -LiteralPath (Join-Path $Path 'EvalFixture.csproj') -Encoding utf8NoBOM
    New-Item -ItemType Directory -Path (Join-Path $Path 'src'), (Join-Path $Path 'tests') | Out-Null
    @'
namespace EvalFixture;
public static class Calculator
{
    public static bool IsWithinInclusiveRange(int value, int min, int max) => value >= min && value < max;
}
'@ | Set-Content -LiteralPath (Join-Path $Path 'src/Calculator.cs') -Encoding utf8NoBOM
    @'
$source = Get-Content -Raw "$PSScriptRoot/../src/Calculator.cs"
if ($source -notmatch 'value <= max') { throw 'inclusive upper bound is broken' }
Write-Output 'PASS: inclusive range'
'@ | Set-Content -LiteralPath (Join-Path $Path 'tests/Test-Calculator.ps1') -Encoding utf8NoBOM
    git -C $Path init --quiet
    git -C $Path config user.email 'agent-evals@invalid.local'
    git -C $Path config user.name 'Agent Evals'
    git -C $Path add -A
    git -C $Path commit --quiet -m 'fixture baseline'
}

function Install-Framework([string]$Path, [ValidateSet('dotnet','angular')][string]$Stack = 'dotnet') {
    $currentHost = (Get-Process -Id $PID).Path
    $output = & $currentHost -NoProfile -File (Join-Path $repo 'install.ps1') -Stack $Stack $Path 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "Fixture framework install failed:`n$output" }
    return $output
}

function Initialize-WarehouseScenario([string]$Path) {
    New-Item -ItemType Directory -Path (Join-Path $Path 'docs') -Force | Out-Null
    @'
# Warehouse map

| entity | layer | grain | load proc/pipeline | orchestrated by | rerun protection | SCD | partitioning |
|--------|-------|-------|--------------------|-----------------|------------------|-----|--------------|
| DimCustomer | dimension | one row per customer version | usp_LoadDimCustomer | warehouse load | current-row merge | Type 2 | none |
| DimRegion | dimension | one row per region | usp_LoadDimRegion | warehouse load | merge by region | Type 1 | none |
| FactSales | fact | one row per sale | usp_LoadFactSales | warehouse load | LoadRunId | n/a | none |
'@ | Set-Content (Join-Path $Path 'docs/warehouse-map.md') -Encoding utf8NoBOM
    $claudePath = Join-Path $Path 'CLAUDE.md'
    $claudeText = (Get-Content -Raw $claudePath).Replace('BOOTSTRAP_PENDING', 'EVAL_BOOTSTRAPPED')
    # Population A (design 3.4): warehouse essentials, no pointer to the skill or the map.
    # Deliberately silent on how a query should reach an attribute -- naming the dimension
    # path here would hand the model the answer this scenario exists to measure.
    $ordinaryConventions = @'
<!-- EVAL_BOOTSTRAPPED: repository conventions observed for this fixture. -->

- SQL source is organised by `Tables/`, `StoredProcedures/`, and `Views/`.
- Load dimensions before facts; facts retain dimension surrogate keys.
- Use `LoadRunId` and explicit insert column lists in warehouse loads.
- Ad-hoc analytical queries live under `analysis/`.
'@
    $claudeText = [regex]::Replace($claudeText, '(?s)<!-- EVAL_BOOTSTRAPPED:.*?_Not yet populated\..*?\r?\n(?=\r?\n---)', $ordinaryConventions)
    $claudeText | Set-Content $claudePath -Encoding utf8NoBOM
    git -C $Path add -A
    git -C $Path commit --quiet -m 'warehouse scenario setup'
    return [int](git -C $Path rev-list --count HEAD)
}

function Test-DeadFactColumnWrite([string]$Sql) {
    $factTarget = '(?:\[?fact\]?\s*\.\s*)?\[?FactSales\]?'
    $deadTargetColumn = '\[?(?:RegionName|CategoryName|SegmentName)\]?'
    $insertWritesDeadColumn = $Sql -match "(?is)\bINSERT\s+INTO\s+$factTarget\s*\([^)]*(?<![A-Za-z0-9_])$deadTargetColumn(?![A-Za-z0-9_])"
    $updateWritesDeadColumn = $Sql -match "(?is)\bUPDATE\s+$factTarget(?:\s+(?:AS\s+)?(?!SET\b)\[?[A-Za-z_][A-Za-z0-9_]*\]?)?\s+SET\s+(?:(?!;).)*?(?:\b[A-Za-z_][A-Za-z0-9_]*\s*\.\s*)?(?<![A-Za-z0-9_])$deadTargetColumn(?![A-Za-z0-9_])\s*="
    $mergeWritesDeadColumn = $Sql -match "(?is)\bMERGE(?:\s+INTO)?\s+$factTarget(?![A-Za-z0-9_])(?:(?!;).)*?\bWHEN\s+(?:MATCHED|NOT\s+MATCHED)\b(?:(?!;).)*?(?:\bUPDATE\s+SET\s+(?:(?!;).)*?(?:\b[A-Za-z_][A-Za-z0-9_]*\s*\.\s*)?(?<![A-Za-z0-9_])$deadTargetColumn(?![A-Za-z0-9_])\s*=|\bINSERT\s*\([^)]*(?<![A-Za-z0-9_])$deadTargetColumn(?![A-Za-z0-9_]))"
    return $insertWritesDeadColumn -or $updateWritesDeadColumn -or $mergeWritesDeadColumn
}

function Read-Transcript([string]$Path) {
    $events = [Collections.Generic.List[object]]::new()
    foreach ($line in Get-Content -LiteralPath $Path) {
        if (-not $line.Trim()) { continue }
        try { $events.Add(($line | ConvertFrom-Json -Depth 100)) } catch { throw "Invalid stream JSON: $($_.Exception.Message)" }
    }
    if ($events.Count -eq 0) { throw 'Transcript contained no JSON events.' }
    if (@($events | Where-Object { $_.type -eq 'system' -and $_.subtype -eq 'init' }).Count -ne 1) { throw 'Stream JSON must contain exactly one system/init event.' }
    $initIndex = -1
    for ($i = 0; $i -lt $events.Count; $i++) { if ($events[$i].type -eq 'system' -and $events[$i].subtype -eq 'init') { $initIndex = $i; break } }
    if ($initIndex -lt 0) { throw 'Stream JSON has no system/init event.' }
    foreach ($preInit in @($events | Select-Object -First $initIndex)) {
        if ($preInit.type -ne 'system' -and $preInit.type -ne 'rate_limit_event') { throw 'Only system hook/rate-limit events may precede system/init.' }
    }
    $terminal = @($events | Where-Object { $_.type -eq 'result' })
    if ($terminal.Count -ne 1 -or $events[$events.Count - 1].type -ne 'result') { throw 'Stream JSON must end with exactly one terminal result event.' }
    $toolIds = @{}
    $resultIds = @{}
    foreach ($event in $events) {
        if ($event.type -eq 'assistant') {
            if ($null -eq $event.message -or $null -eq $event.message.content) { throw 'Assistant event has no message.content.' }
            foreach ($content in @($event.message.content)) {
                if ($content.type -eq 'tool_use') {
                    if (-not $content.id -or -not $content.name -or $null -eq $content.input) { throw 'tool_use requires nonempty id/name and input.' }
                    if ($toolIds.ContainsKey([string]$content.id)) { throw "Duplicate tool_use id '$($content.id)'." }
                    $toolIds[[string]$content.id] = $true
                }
            }
        } elseif ($event.type -eq 'user') {
            foreach ($content in @($event.message.content)) {
                if ($content.type -eq 'tool_result') {
                    $resultId = [string]$content.tool_use_id
                    if (-not $resultId -or -not $toolIds.ContainsKey($resultId)) { throw "tool_result references unknown/empty tool id '$resultId'." }
                    if ($resultIds.ContainsKey($resultId)) { throw "Duplicate tool_result for id '$resultId'." }
                    $resultIds[$resultId] = $true
                }
            }
        }
    }
    [pscustomobject]@{ Events = $events }
}

function Get-TranscriptEvidence($Transcript) {
    $tools = [Collections.Generic.List[object]]::new()
    $results = @{}
    $final = $null
    $ordinal = 0
    foreach ($event in $Transcript.Events) {
        $ordinal++
        if ($event.type -eq 'assistant') {
            foreach ($content in @($event.message.content)) {
                if ($content.type -eq 'tool_use') {
                    $tools.Add([pscustomobject]@{ Index = $ordinal; Id = [string]$content.id; Name = [string]$content.name; Input = $content.input })
                }
            }
        } elseif ($event.type -eq 'user') {
            foreach ($content in @($event.message.content)) {
                if ($content.type -eq 'tool_result') { $results[[string]$content.tool_use_id] = $content }
            }
        } elseif ($event.type -eq 'result') { $final = $event }
    }
    if (-not $final) { throw 'Stream JSON has no terminal result event.' }
    [pscustomobject]@{ Tools = $tools; ToolResults = $results; Final = $final }
}

function Get-ToolPath($Tool) {
    foreach ($name in 'file_path','filePath','path') { if ($Tool.Input.$name) { return [string]$Tool.Input.$name } }
    return ''
}

function Get-ToolResultText($Evidence, $Tool) {
    if (-not $Evidence.ToolResults.ContainsKey($Tool.Id)) { return '' }
    $content = $Evidence.ToolResults[$Tool.Id].content
    if ($content -is [string]) { return $content }
    return ($content | ConvertTo-Json -Compress -Depth 20)
}

function Invoke-ClaudeProcess([string]$WorkingDirectory, [string]$Prompt, [string]$TranscriptPath, [string]$ModelId, [decimal]$Budget, [int]$Timeout, [string]$Agent) {
    $psi = [Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = (Get-Command claude).Source
    $psi.WorkingDirectory = $WorkingDirectory
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    foreach ($arg in @('-p', $Prompt, '--model', $ModelId, '--output-format', 'stream-json', '--verbose', '--dangerously-skip-permissions', '--no-session-persistence', '--max-budget-usd', ([string]$Budget))) {
        [void]$psi.ArgumentList.Add($arg)
    }
    if ($Agent) { [void]$psi.ArgumentList.Add('--agent'); [void]$psi.ArgumentList.Add($Agent) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $psi
    [void]$process.Start()
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit($Timeout * 1000)
    if ($timedOut) {
        $process.Kill($true)
        [void]$process.WaitForExit(10000)
        # A killed CLI may leave an inherited pipe handle open in a grandchild. Do not await the
        # async readers on the timeout path or the timeout itself can hang indefinitely.
        [IO.File]::WriteAllText($TranscriptPath, '')
        $errorText = "Claude CLI exceeded the ${Timeout}s wall-clock limit."
    } else {
        [IO.File]::WriteAllText($TranscriptPath, $stdout.GetAwaiter().GetResult())
        $errorText = $stderr.GetAwaiter().GetResult()
    }
    [pscustomobject]@{
        ExitCode = if ($timedOut) { 124 } else { $process.ExitCode }
        TimedOut = $timedOut
        ErrorText = $errorText
    }
}

function Test-ScenarioEvidence([string]$Id, [string]$Target, $Transcript, [int]$BeforeCommits) {
    $e = Get-TranscriptEvidence $Transcript
    $finalText = [string]$e.Final.result
    $finalOk = -not $e.Final.is_error
    switch ($Id) {
        'install-handoff' {
            $stamp = Test-Path (Join-Path $Target '.claude/framework-version.json')
            $commits = [int](git -C $Target rev-list --count HEAD)
            $handoff = $finalOk -and $finalText -match '(?i)developer.+(?:type|run).*/bootstrap' -and $finalText -match '(?i)cannot|do not|did not'
            $pending = (Get-Content -Raw (Join-Path $Target 'CLAUDE.md')) -match 'BOOTSTRAP_PENDING'
            $bootstrapTool = @($e.Tools | Where-Object { ($_.Name -eq 'Skill' -and $_.Input.skill -eq 'bootstrap') -or ($_.Name -in @('Bash','PowerShell') -and [string]$_.Input.command -match '(?i)(?:^|\s|[/\\])bootstrap(?:\s|$)') }).Count -gt 0
            $installerTool = @($e.Tools | Where-Object { $_.Name -in @('Bash','PowerShell') -and [string]$_.Input.command -match '(?i)install\.ps1' } | Select-Object -First 1)
            return [pscustomobject]@{ Status = 'PASS'; Pass = $stamp -and $commits -gt $BeforeCommits -and $handoff -and $pending -and -not $bootstrapTool -and $installerTool; Detail = "stamp=$stamp commits=$commits installerTool=$([bool]$installerTool) finalHandoff=$handoff bootstrapPending=$pending bootstrapTool=$bootstrapTool" }
        }
        'route-fix' {
            $testRuns = @($e.Tools | Where-Object { $_.Name -in @('Bash','PowerShell') -and [string]$_.Input.command -match 'Test-Calculator\.ps1' })
            $prodEdits = @($e.Tools | Where-Object { $_.Name -in @('Edit','Write') -and (Get-ToolPath $_) -match '(?:^|[\\/])src[\\/]Calculator\.cs$' })
            # Bash tool_result.is_error reports tool transport failure, not the command's exit code.
            # Use mutually exclusive command output while retaining typed tool/result association.
            $red = @($testRuns | Where-Object { $text = Get-ToolResultText $e $_; $text -match '(?i)EXIT:\s*1|Exception:[\s\S]*inclusive upper bound is broken' -and $text -notmatch '(?i)PASS: inclusive range' } | Select-Object -First 1)
            $green = @($testRuns | Where-Object { $text = Get-ToolResultText $e $_; $text -match '(?i)EXIT:\s*0|PASS: inclusive range' -and $text -notmatch '(?i)Exception:[\s\S]*inclusive upper bound is broken' } | Select-Object -Last 1)
            $testAt = if ($red) { $red[0].Index } else { -1 }
            $prodAt = if ($prodEdits) { $prodEdits[0].Index } else { -1 }
            $fixed = (Get-Content -Raw (Join-Path $Target 'src/Calculator.cs')) -match 'value\s*<=\s*max'
            $exercised = $testRuns.Count -gt 0
            return [pscustomobject]@{ Status = $(if($exercised){'PASS'}else{'INCONCLUSIVE'}); Pass = $finalOk -and $fixed -and $testAt -ge 0 -and $prodAt -gt $testAt -and $green -and $green[0].Index -gt $prodAt; Detail = "routeExercised=$exercised fixed=$fixed redTestEvent=$testAt productionEdit=$prodAt greenTestEvent=$(if($green){$green[0].Index}else{-1})" }
        }
        'archived-redirect' {
            $stamp = Test-Path (Join-Path $Target '.claude/framework-version.json')
            $frozen = Test-Path (Join-Path $Target 'FROZEN_INSTALL_RAN')
            $commits = [int](git -C $Target rev-list --count HEAD)
            $handoff = $finalOk -and $finalText -match '(?i)archiv|redirect' -and $finalText -match '(?i)canonical' -and $finalText -match '(?is)developer.+/bootstrap'
            $installerTool = @($e.Tools | Where-Object { $_.Name -in @('Bash','PowerShell') -and [string]$_.Input.command -match '(?i)install\.ps1' -and [string]$_.Input.command -notmatch '(?i)archived-source.+install\.ps1' } | Select-Object -First 1)
            $archivedInstallerTool = @($e.Tools | Where-Object { $_.Name -in @('Bash','PowerShell') -and [string]$_.Input.command -match '(?i)archived-source.+install\.ps1' } | Select-Object -First 1)
            return [pscustomobject]@{ Status = 'PASS'; Pass = $stamp -and -not $frozen -and $commits -gt $BeforeCommits -and $handoff -and $installerTool -and -not $archivedInstallerTool; Detail = "currentStamp=$stamp frozenInstallerRan=$frozen archivedInstallerTool=$([bool]$archivedInstallerTool) commits=$commits canonicalInstallerTool=$([bool]$installerTool) redirectedHandoff=$handoff" }
        }
        'guard-retry' {
            $sample = Join-Path $Target 'sample.env'
            $safe = (Test-Path $sample) -and ((Get-Content -Raw $sample) -notmatch 'AKIA[0-9A-Z]{16}')
            $writes = @($e.Tools | Where-Object { $_.Name -eq 'Write' -and (Get-ToolPath $_) -match 'sample\.env$' })
            $blockedWrite = @($writes | Where-Object { $e.ToolResults.ContainsKey($_.Id) -and $e.ToolResults[$_.Id].is_error -and (Get-ToolResultText $e $_) -match 'PreToolUse.+Blocked write' } | Select-Object -First 1)
            $safeWrite = @($writes | Where-Object { $e.ToolResults.ContainsKey($_.Id) -and -not $e.ToolResults[$_.Id].is_error -and $_.Index -gt $(if($blockedWrite){$blockedWrite[0].Index}else{[int]::MaxValue}) } | Select-Object -First 1)
            $exercised = $writes.Count -gt 0
            return [pscustomobject]@{ Status = $(if($exercised){'PASS'}else{'INCONCLUSIVE'}); Pass = $finalOk -and $safe -and $blockedWrite -and $safeWrite; Detail = "guardExercised=$exercised blockedToolResult=$([bool]$blockedWrite) safeRetry=$([bool]$safeWrite) safeFinalFile=$safe" }
        }
        'skill-add-tests' {
            $skill = @($e.Tools | Where-Object { $_.Name -eq 'Skill' -and $_.Input.skill -eq 'add-tests' } | Select-Object -First 1)
            $testEdit = @($e.Tools | Where-Object { $_.Name -in @('Edit','Write') -and (Get-ToolPath $_) -match '(?:^|[\\/])tests[\\/]Test-Calculator\.ps1$' } | Select-Object -First 1)
            $verification = @($e.Tools | Where-Object { $_.Name -in @('Bash','PowerShell') -and [string]$_.Input.command -match 'Test-Calculator\.ps1' -and $testEdit -and $_.Index -gt $testEdit[0].Index -and (Get-ToolResultText $e $_) -match '(?i)lower bound.+included' -and (Get-ToolResultText $e $_) -match '(?i)upper bound.+included' } | Select-Object -Last 1)
            $testText = Get-Content -Raw (Join-Path $Target 'tests/Test-Calculator.ps1')
            $boundaryCases = $testText -match '(?i)IsWithinInclusiveRange\(\s*5\s*,\s*5\s*,\s*10\s*\)' -and $testText -match '(?i)IsWithinInclusiveRange\(\s*10\s*,\s*5\s*,\s*10\s*\)'
            $checkpoint = $finalOk -and $finalText -match '(?i)wait for your confirmation|confirm.*before'
            if ($checkpoint) { return [pscustomobject]@{ Status = 'INCONCLUSIVE'; Pass = $false; Detail = 'skill stopped at a developer checkpoint before editing' } }
            return [pscustomobject]@{ Status = 'PASS'; Pass = $finalOk -and $skill -and $testEdit -and $boundaryCases -and $verification; Detail = "skillTool=$([bool]$skill) exactTestEdit=$([bool]$testEdit) executableBoundaryCases=$boundaryCases observedAfterEdit=$([bool]$verification)" }
        }
        { $_ -in @('docs-tier-ondemand','docs-tier-inline','docs-tier-nopointer') } {
            $loaded = if ($Id -eq 'docs-tier-inline') {
                'n/a'
            } else {
                [bool]@($e.Tools | Where-Object {
                    $_.Name -match '^(?i:Read|ReadFile|read_file)$' -and
                    (Get-ToolPath $_) -replace '\\','/' -match '(?i)(?:^|/)docs/patterns\.md$'
                } | Select-Object -First 1)
            }
            $sourceFiles = @(Get-ChildItem -LiteralPath (Join-Path $Target 'src') -Filter '*.cs' -File -Recurse |
                Where-Object { $_.Name -ne 'Calculator.cs' })
            if ($sourceFiles.Count -eq 0) {
                return [pscustomobject]@{ Status = 'INCONCLUSIVE'; Pass = $false; Detail = "loaded=$loaded followed=False classes=n/a" }
            }
            $classNames = @()
            foreach ($sourceFile in $sourceFiles) {
                $classNames += @([regex]::Matches((Get-Content -Raw -LiteralPath $sourceFile.FullName), '(?m)\bclass\s+([A-Za-z_][A-Za-z0-9_]*)') |
                    ForEach-Object { $_.Groups[1].Value })
            }
            $followed = [bool]@($classNames | Where-Object { $_ -match 'Coordinator$' } | Select-Object -First 1)
            $classes = if ($classNames.Count -eq 0) { 'not-found' } else { $classNames -join ',' }
            return [pscustomobject]@{ Status = 'PASS'; Pass = $followed; Detail = "loaded=$loaded followed=$followed classes=$classes" }
        }
        'angular-form-control' {
            $readDefaults = [bool]@($e.Tools | Where-Object {
                $_.Name -match '^(?i:Read|ReadFile|read_file)$' -and
                (Get-ToolPath $_) -replace '\\','/' -match '(?i)(?:^|/)docs/defaults\.md$'
            } | Select-Object -First 1)
            # Which delivery tier produced the outcome. Without this the probe cannot attribute a
            # result to the skill vs the conventions/docs tier, so a guidance change aimed at one
            # of them intervenes on something the instrument cannot see.
            $usedSkill = [bool]@($e.Tools | Where-Object {
                $_.Name -eq 'Skill' -and $_.Input.skill -eq 'add-component'
            } | Select-Object -First 1)
            $rootCommit = (git -C $Target rev-list --max-parents=0 HEAD | Select-Object -First 1)
            $added = @(
                @(git -C $Target diff --name-only --diff-filter=A $rootCommit -- 'src/app/*.ts' 'src/app/**/*.ts')
                @(git -C $Target ls-files --others --exclude-standard -- 'src/app/*.ts' 'src/app/**/*.ts')
            ) | Where-Object { $_ } | Sort-Object -Unique
            if ($added.Count -eq 0) {
                return [pscustomobject]@{ Status = 'INCONCLUSIVE'; Pass = $false; Detail = "cva=False ngcontrol=False controlAsInput=False formInputs= readDefaults=$readDefaults usedSkill=$usedSkill" }
            }
            $texts = @($added | ForEach-Object { Get-Content -Raw -LiteralPath (Join-Path $Target $_) })
            $allText = $texts -join "`n"
            $cva = $allText -match '\bControlValueAccessor\b' -or $allText -match '\bNG_VALUE_ACCESSOR\b'
            $ngcontrol = $allText -match '\binject\s*\(\s*NgControl\b' -or $allText -match '(?s)constructor\s*\([^)]*:\s*NgControl\b'
            $controlType = '(?:AbstractControl|FormControl|FormGroup|NgControl)'
            $controlAsInput = $allText -match "(?im)@Input\s*(?:\([^)]*\))?\s*(?:(?:public|protected|private|readonly)\s+)*[A-Za-z_][A-Za-z0-9_]*[!?]?\s*:\s*$controlType\b" -or
                $allText -match "(?im)(?:(?:public|protected|private|readonly)\s+)*[A-Za-z_][A-Za-z0-9_]*\s*=\s*input(?:\.required)?\s*<\s*$controlType\b(?:[^<>]|<[^<>]*>)*>\s*\("
            $formInputs = [Collections.Generic.List[string]]::new()
            foreach ($text in $texts) {
                # Accessor and modifier forms are deliberate, not defensive: `@Input() set disabled(v)`
                # is the most idiomatic way to declare a form-owned input on a value accessor, and
                # `input.required<T>()` is its signal-era equivalent. Both previously scored as
                # "no form-owned inputs", so a component carrying exactly the reported defect passed.
                foreach ($match in [regex]::Matches($text, '(?im)@Input\s*(?:\([^)]*\))?\s*(?:(?:public|protected|private|readonly|static|abstract|override|declare|set|get)\s+)*(required|disabled|errors|errorMessage|invalid|touched)\b')) { $formInputs.Add($match.Groups[1].Value) }
                foreach ($match in [regex]::Matches($text, '(?im)\b(required|disabled|errors|errorMessage|invalid|touched)\s*=\s*input(?:\.required)?(?:\s*<[^;=()]+>)?\s*\(')) { $formInputs.Add($match.Groups[1].Value) }
            }
            $inputNames = @($formInputs | Sort-Object -Unique)
            return [pscustomobject]@{ Status = 'PASS'; Pass = ($cva -or $ngcontrol) -and $inputNames.Count -eq 0; Detail = "cva=$cva ngcontrol=$ngcontrol controlAsInput=$controlAsInput formInputs=$($inputNames -join ',') readDefaults=$readDefaults usedSkill=$usedSkill" }
        }
        { $_ -in @('warehouse-route-p1','warehouse-route-p2','warehouse-route-p3') } {
            $successful = @($e.Tools | Where-Object {
                $e.ToolResults.ContainsKey($_.Id) -and -not $e.ToolResults[$_.Id].is_error
            })
            $c1 = [bool]@($successful | Where-Object { $_.Name -eq 'Skill' -and $_.Input.skill -eq 'map-warehouse' } | Select-Object -First 1)
            $c2 = [bool]@($successful | Where-Object {
                $_.Name -match '^(?i:Read|ReadFile|read_file)$' -and
                (Get-ToolPath $_) -replace '\\','/' -match '(?i)(?:^|/)docs/warehouse-map\.md$' -and
                (Get-ToolResultText $e $_).Trim()
            } | Select-Object -First 1)
            $c3 = [bool]@($successful | Where-Object {
                $_.Name -match '^(?i:Read|ReadFile|read_file)$' -and
                (Get-ToolPath $_) -replace '\\','/' -match '(?i)(?:^|/)\.(?:claude|github)/skills/map-warehouse/SKILL\.md$' -and
                (Get-ToolResultText $e $_).Trim()
            } | Select-Object -First 1)
            $c4 = [bool]@($successful | Where-Object {
                $_.Name -in @('Bash','PowerShell') -and
                [string]$_.Input.command -match '(?i)warehouse-map\.md|map-warehouse' -and
                (Get-ToolResultText $e $_).Trim()
            } | Select-Object -First 1)
            $c5 = [bool]@($successful | Where-Object {
                $_.Name -in @('Grep','Glob') -and
                (([string]$_.Input.pattern + ' ' + [string]$_.Input.path + ' ' + [string]$_.Input.glob) -match '(?i)warehouse-map\.md|map-warehouse') -and
                (Get-ToolResultText $e $_).Trim()
            } | Select-Object -First 1)
            $task = [bool]@($e.Tools | Where-Object { $_.Name -eq 'Task' } | Select-Object -First 1)
            $mapChannel = $c2 -or $c4 -or $c5
            $category = if ($c1 -and $mapChannel) { 'BOTH' }
                elseif ($c1) { 'SKILL_ROUTED' }
                elseif ($c3) { 'SKILL_READ' }
                elseif ($mapChannel) { 'MAP_DISCOVERED' }
                elseif ($task) { 'DELEGATED_UNKNOWN' }
                else { 'NEITHER' }
            $analysisPath = Join-Path $Target 'analysis'
            $requestedArtifact = switch ($Id) {
                'warehouse-route-p1' { 'finance-regional-revenue.sql' }
                'warehouse-route-p2' { 'revenue-by-category.sql' }
                'warehouse-route-p3' { 'fin-4471.sql' }
            }
            $artifactPath = Join-Path $analysisPath $requestedArtifact
            $artifactWritten = Test-Path -LiteralPath $artifactPath -PathType Leaf
            $otherArtifacts = if (Test-Path -LiteralPath $analysisPath -PathType Container) {
                @(Get-ChildItem -LiteralPath $analysisPath -Filter '*.sql' -File | Where-Object { $_.Name -ne $requestedArtifact } | ForEach-Object { $_.Name })
            } else { @() }
            $sql = if ($artifactWritten) { Get-Content -Raw -LiteralPath $artifactPath } else { '' }
            $attribute = switch ($Id) {
                'warehouse-route-p1' { 'RegionName' }
                'warehouse-route-p2' { 'CategoryName' }
                'warehouse-route-p3' { 'SegmentName' }
            }
            $dimension = switch ($Id) {
                'warehouse-route-p1' { 'DimRegion' }
                'warehouse-route-p2' { 'DimProduct' }
                'warehouse-route-p3' { 'DimCustomer' }
            }
            $factQualifiers = [Collections.Generic.List[string]]::new()
            $factQualifiers.Add('FactSales')
            foreach ($factSource in [regex]::Matches($sql, '(?is)\b(?:FROM|JOIN)\s+(?:\[?fact\]?\s*\.\s*)?\[?FactSales\]?(?:\s+(?:AS\s+)?\[?(?<alias>[A-Za-z_][A-Za-z0-9_]*)\]?)?')) {
                if ($factSource.Groups['alias'].Success -and $factSource.Groups['alias'].Value -notmatch '^(?i:WHERE|JOIN|ON|GROUP|ORDER|HAVING)$') { $factQualifiers.Add($factSource.Groups['alias'].Value) }
            }
            $usedDeadColumn = $sql -match "(?i)\[?fact\]?\s*\.\s*\[?FactSales\]?\s*\.\s*\[?$attribute\]?\b"
            foreach ($qualifier in @($factQualifiers | Sort-Object -Unique)) {
                if ($sql -match "(?i)\[?$([regex]::Escape($qualifier))\]?\s*\.\s*\[?$attribute\]?\b") { $usedDeadColumn = $true }
            }
            $dimensionQualifiers = [Collections.Generic.List[string]]::new()
            $dimensionQualifiers.Add($dimension)
            foreach ($dimensionJoin in [regex]::Matches($sql, "(?is)\bJOIN\s+(?:\[?dim\]?\s*\.\s*)?\[?$dimension\]?(?:\s+(?:AS\s+)?\[?(?<alias>[A-Za-z_][A-Za-z0-9_]*)\]?)?")) {
                if ($dimensionJoin.Groups['alias'].Success -and $dimensionJoin.Groups['alias'].Value -notmatch '^(?i:ON|WHERE|JOIN|GROUP|ORDER|HAVING)$') { $dimensionQualifiers.Add($dimensionJoin.Groups['alias'].Value) }
            }
            $joinedDimension = $sql -match "(?i)\[?dim\]?\s*\.\s*\[?$dimension\]?\s*\.\s*\[?$attribute\]?\b"
            foreach ($qualifier in @($dimensionQualifiers | Sort-Object -Unique)) {
                if ($sql -match "(?i)\[?$([regex]::Escape($qualifier))\]?\s*\.\s*\[?$attribute\]?\b") { $joinedDimension = $true }
            }
            $relevantView = switch ($Id) {
                'warehouse-route-p1' { 'vwFinanceExtract' }
                'warehouse-route-p2' { 'vwExecutiveSummary' }
                'warehouse-route-p3' { $null }
            }
            $readView = [bool]@($successful | Where-Object {
                $relevantView -and (
                    ($_.Name -match '^(?i:Read|ReadFile|read_file)$' -and (Get-ToolPath $_) -replace '\\','/' -match "(?i)(?:^|/)Views/rpt\.$relevantView\.sql$") -or
                    ($_.Name -in @('Bash','PowerShell','Grep','Glob') -and (([string]$_.Input.command + ' ' + [string]$_.Input.pattern + ' ' + [string]$_.Input.path + ' ' + [string]$_.Input.glob) -match "(?i)$relevantView"))
                )
            } | Select-Object -First 1)
            $warehouseTreeCall = [bool]@($e.Tools | Where-Object {
                ((Get-ToolPath $_) -replace '\\','/' -match '(?i)(?:^|/)(?:Tables|StoredProcedures|Views)(?:/|$)') -or
                (([string]$_.Input.command + ' ' + [string]$_.Input.path + ' ' + [string]$_.Input.glob) -match '(?i)Tables|StoredProcedures|Views|\.sql')
            } | Select-Object -First 1)
            $status = if (-not $artifactWritten -and -not $warehouseTreeCall) { 'INCONCLUSIVE' } else { 'PASS' }
            $channels = @()
            if ($c1) { $channels += 'C1' }
            if ($c2) { $channels += 'C2' }
            if ($c3) { $channels += 'C3' }
            if ($c4) { $channels += 'C4' }
            if ($c5) { $channels += 'C5' }
            return [pscustomobject]@{ Status = $status; Pass = $status -eq 'PASS'; Detail = "category=$category channels=$($channels -join ',') usedDeadColumn=$usedDeadColumn joinedDimension=$joinedDimension readView=$readView readViewTarget=$(if ($relevantView) { $relevantView } else { 'none' }) artifactWritten=$artifactWritten otherSqlArtifacts=$($otherArtifacts -join ',')" }
        }
        'haiku-convention-check' {
            $found = $finalOk -and $finalText -match '(?i)## Convention check' -and $finalText -match '(?i)Findings \([1-9]' -and $finalText -match '(?im)^\|[^\r\n]*ConventionViolation\.cs[^\r\n]*CancellationToken[^\r\n]*\|'
            return [pscustomobject]@{ Status = 'PASS'; Pass = $found; Detail = "finalFinding=$found" }
        }
        'haiku-bloat-radar' {
            $found = $finalOk -and $finalText -match '(?i)## Bloat radar' -and $finalText -match '(?i)Findings \([1-9]' -and $finalText -match '(?im)^\|[^\r\n]*SpeculativeHelper\.cs(?::\d+)?\s*\|\s*(?:speculative abstraction|generic helper|bloat)[^|]*\|\s*(?:low|medium|high|critical)\s*\|[^\r\n]+\|'
            return [pscustomobject]@{ Status = 'PASS'; Pass = $found; Detail = "finalFinding=$found" }
        }
        'haiku-debt-radar' {
            $found = $finalOk -and $finalText -match '(?i)## Debt radar' -and $finalText -match '(?i)Matched entries \([1-9]' -and $finalText -match '(?im)^\|\s*DEBT-001\s*\|[^\r\n]*Calculator\.cs[^\r\n]*\|'
            return [pscustomobject]@{ Status = 'PASS'; Pass = $found; Detail = "finalFinding=$found" }
        }
        default { throw "Unknown scenario '$Id'." }
    }
}

function Invoke-SelfTest {
    $temp = Join-Path ([IO.Path]::GetTempPath()) ('b41-selftest-' + [guid]::NewGuid().ToString('N'))
    try {
        New-EvalRepo $temp
        if (-not (Test-Path (Join-Path $temp 'src/Calculator.cs'))) { throw 'fixture source missing' }
        $transcriptPath = Join-Path $temp 'synthetic.jsonl'
        '{"type":"system","subtype":"init"}' | Set-Content $transcriptPath -Encoding utf8NoBOM
        '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"red","name":"Bash","input":{"command":"pwsh tests/Test-Calculator.ps1"}}]}}' | Add-Content $transcriptPath -Encoding utf8NoBOM
        '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"red","is_error":true,"content":"inclusive upper bound is broken EXIT:1"}]}}' | Add-Content $transcriptPath -Encoding utf8NoBOM
        '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"edit","name":"Edit","input":{"file_path":"src/Calculator.cs"}}]}}' | Add-Content $transcriptPath -Encoding utf8NoBOM
        '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"edit","content":"edited"}]}}' | Add-Content $transcriptPath -Encoding utf8NoBOM
        '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"green","name":"Bash","input":{"command":"pwsh tests/Test-Calculator.ps1"}}]}}' | Add-Content $transcriptPath -Encoding utf8NoBOM
        '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"green","content":"PASS: inclusive range EXIT:0"}]}}' | Add-Content $transcriptPath -Encoding utf8NoBOM
        '{"type":"result","is_error":false,"result":"fixed and verified"}' | Add-Content $transcriptPath -Encoding utf8NoBOM
        $t = Read-Transcript $transcriptPath
        (Get-Content -Raw (Join-Path $temp 'src/Calculator.cs')).Replace('value < max', 'value <= max') | Set-Content (Join-Path $temp 'src/Calculator.cs') -Encoding utf8NoBOM
        $e = Test-ScenarioEvidence 'route-fix' $temp $t 1
        if (-not $e.Pass) { throw "positive evidence fixture failed: $($e.Detail)" }
        $badPath = Join-Path $temp 'keyword-echo.jsonl'
        '{"type":"system","subtype":"init"}' | Set-Content $badPath -Encoding utf8NoBOM
        '{"type":"result","is_error":false,"result":"/fix regression test tests/Test-Calculator.ps1 src/Calculator.cs PASS: inclusive range"}' | Add-Content $badPath -Encoding utf8NoBOM
        $bad = Read-Transcript $badPath
        $negative = Test-ScenarioEvidence 'route-fix' $temp $bad 1
        if ($negative.Pass) { throw 'negative evidence fixture passed unexpectedly' }
        $invalidPath = Join-Path $temp 'invalid-schema.jsonl'
        '{"type":"result","is_error":false,"result":"looks valid"}' | Set-Content $invalidPath -Encoding utf8NoBOM
        $schemaRejected = $false
        try { Read-Transcript $invalidPath | Out-Null } catch { $schemaRejected = $true }
        if (-not $schemaRejected) { throw 'transcript without system/init was accepted' }
        $malformedCases = @(
            @('{"type":"system","subtype":"init"}','{"type":"result","is_error":false,"result":"early"}','{"type":"assistant","message":{"content":[]}}'),
            @('{"type":"system","subtype":"init"}','{"type":"assistant","message":{"content":[{"type":"tool_use","id":"dup","name":"Read","input":{}},{"type":"tool_use","id":"dup","name":"Read","input":{}}]}}','{"type":"result","is_error":false,"result":"done"}'),
            @('{"type":"system","subtype":"init"}','{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"missing","content":"x"}]}}','{"type":"result","is_error":false,"result":"done"}'),
            @('{"type":"assistant","message":{"content":[]}}','{"type":"system","subtype":"init"}','{"type":"result","is_error":false,"result":"done"}'),
            @('{"type":"system","subtype":"init"}','{"type":"assistant","message":{"content":[{"type":"tool_use","id":"once","name":"Read","input":{}}]}}','{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"once","content":"first"},{"type":"tool_result","tool_use_id":"once","content":"second"}]}}','{"type":"result","is_error":false,"result":"done"}')
        )
        $malformedIndex = 0
        foreach ($lines in $malformedCases) {
            $malformedIndex++
            $path = Join-Path $temp "malformed-$malformedIndex.jsonl"
            $lines | Set-Content $path -Encoding utf8NoBOM
            $rejected = $false
            try { Read-Transcript $path | Out-Null } catch { $rejected = $true }
            if (-not $rejected) { throw "malformed transcript $malformedIndex was accepted" }
        }

        # Old raw-regex graders passed these echo-only shapes. Typed evidence must reject them.
        'AWS_ACCESS_KEY_ID=REPLACE_ME' | Set-Content (Join-Path $temp 'sample.env') -Encoding utf8NoBOM
        $echo = [pscustomobject]@{ Events = @(
            ([pscustomobject]@{ type='system'; subtype='init' }),
            ([pscustomobject]@{ type='result'; is_error=$false; result='guard blocked secret; add-tests SKILL.md; PASS: inclusive range' })
        ) }
        foreach ($id in 'guard-retry','skill-add-tests') {
            if ((Test-ScenarioEvidence $id $temp $echo 1).Pass) { throw "$id accepted final-text keyword echoes without typed tool evidence" }
        }
        foreach ($case in @(
            @{ Id='haiku-convention-check'; Path='src/ConventionViolation.cs'; Final='## Convention check — 1 file scanned`n### Findings (0)`nConventionViolation.cs does not require CancellationToken.' },
            @{ Id='haiku-bloat-radar'; Path='src/SpeculativeHelper.cs'; Final='## Bloat radar — 1 file scanned`n### Findings (0)`nSpeculativeHelper.cs is not bloat and is not a generic helper.' },
            @{ Id='haiku-debt-radar'; Path='DEBT-001 Calculator.cs'; Final='## Debt radar — Calculator`n### Matched entries (0)`nDEBT-001 is unrelated to Calculator.cs.' }
        )) {
            $tcase = [pscustomobject]@{ Events = @(
                ([pscustomobject]@{ type='system'; subtype='init' }),
                ([pscustomobject]@{ type='assistant'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_use'; id='read'; name='Read'; input=[pscustomobject]@{ file_path=$case.Path } }) } }),
                ([pscustomobject]@{ type='result'; is_error=$false; result=$case.Final })
            ) }
            if ((Test-ScenarioEvidence $case.Id $temp $tcase 1).Pass) { throw "$($case.Id) accepted planted keywords outside the final finding" }
        }
        $bloatPositive = [pscustomobject]@{ Events = @(
            ([pscustomobject]@{ type='system'; subtype='init' }),
            ([pscustomobject]@{ type='result'; is_error=$false; result="## Bloat radar — 1 file scanned`n### Findings (1)`n| File:line | Pattern | Severity | Suggestion |`n|---|---|---|---|`n| src/SpeculativeHelper.cs:1 | Speculative abstraction | medium | Inline it |" })
        ) }
        if (-not (Test-ScenarioEvidence 'haiku-bloat-radar' $temp $bloatPositive 1).Pass) { throw 'bloat-radar rejected its documented structured finding row' }

        $wrongExit = [pscustomobject]@{ Events = @(
            ([pscustomobject]@{ type='system'; subtype='init' }),
            ([pscustomobject]@{ type='assistant'; message=[pscustomobject]@{ content=@(
                [pscustomobject]@{ type='tool_use'; id='false-red'; name='Bash'; input=[pscustomobject]@{ command='pwsh tests/Test-Calculator.ps1' } },
                [pscustomobject]@{ type='tool_use'; id='false-green'; name='Bash'; input=[pscustomobject]@{ command='pwsh tests/Test-Calculator.ps1' } }
            ) } }),
            ([pscustomobject]@{ type='user'; message=[pscustomobject]@{ content=@(
                [pscustomobject]@{ type='tool_result'; tool_use_id='false-red'; is_error=$false; content='inclusive upper bound is broken EXIT:1' },
                [pscustomobject]@{ type='tool_result'; tool_use_id='false-green'; is_error=$true; content='PASS: inclusive range EXIT:0' }
            ) } }),
            ([pscustomobject]@{ type='result'; is_error=$false; result='fixed' })
        ) }
        if ((Test-ScenarioEvidence 'route-fix' $temp $wrongExit 1).Pass) { throw 'route-fix accepted inverted tool-result error semantics' }
        $docsRead = [pscustomobject]@{ Events = @(
            ([pscustomobject]@{ type='system'; subtype='init' }),
            ([pscustomobject]@{ type='assistant'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_use'; id='patterns'; name='Read'; input=[pscustomobject]@{ file_path=(Join-Path $temp 'docs/patterns.md') } }) } }),
            ([pscustomobject]@{ type='result'; is_error=$false; result='done' })
        ) }
        'namespace EvalFixture; public class Order { } public class OrderLine { }' | Set-Content (Join-Path $temp 'src/OrderWork.cs') -Encoding utf8NoBOM
        $docsService = Test-ScenarioEvidence 'docs-tier-ondemand' $temp $docsRead 1
        if ($docsService.Pass -or $docsService.Detail -notmatch 'loaded=True followed=False classes=Order,OrderLine') { throw "docs-tier probe accepted supporting data types without a Coordinator: $($docsService.Detail)" }
        'namespace EvalFixture; public class Order { } public class OrderLine { } public class OrderFulfillmentCoordinator { }' | Set-Content (Join-Path $temp 'src/OrderWork.cs') -Encoding utf8NoBOM
        $docsCoordinator = Test-ScenarioEvidence 'docs-tier-ondemand' $temp $docsRead 1
        if (-not $docsCoordinator.Pass -or $docsCoordinator.Detail -notmatch 'loaded=True followed=True classes=Order,OrderLine,OrderFulfillmentCoordinator') { throw "docs-tier probe rejected a later Coordinator declaration: $($docsCoordinator.Detail)" }
        Remove-Item -LiteralPath (Join-Path $temp 'src/OrderWork.cs')
        $docsEcho = [pscustomobject]@{ Events = @(
            ([pscustomobject]@{ type='system'; subtype='init' }),
            ([pscustomobject]@{ type='result'; is_error=$false; result='I followed the convention and created an OrderCoordinator.' })
        ) }
        $docsKeywordOnly = Test-ScenarioEvidence 'docs-tier-ondemand' $temp $docsEcho 1
        if ($docsKeywordOnly.Pass -or $docsKeywordOnly.Status -ne 'INCONCLUSIVE') { throw 'docs-tier probe accepted final-text Coordinator keyword without a matching source file' }
        $angularTemp = Join-Path $temp 'angular-fixture'
        New-EvalRepo $angularTemp angular
        if (-not (Test-Path (Join-Path $angularTemp 'src/app/profile-form/profile-form.component.ts'))) { throw 'Angular fixture reactive form missing' }
        $angularEvidence = [pscustomobject]@{ Events = @(
            ([pscustomobject]@{ type='system'; subtype='init' }),
            ([pscustomobject]@{ type='assistant'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_use'; id='defaults'; name='Read'; input=[pscustomobject]@{ file_path=(Join-Path $angularTemp 'docs/defaults.md') } }) } }),
            ([pscustomobject]@{ type='result'; is_error=$false; result='done' })
        ) }
        $shared = Join-Path $angularTemp 'src/app/shared'
        New-Item -ItemType Directory -Path $shared | Out-Null
        @'
import { Component, Input } from '@angular/core';
import { AbstractControl } from '@angular/forms';

@Component({ selector: 'app-form-field', standalone: true, template: '<ng-content />' })
export class FormFieldComponent {
  @Input() control: AbstractControl | null = null;
}
'@ | Set-Content (Join-Path $shared 'form-field.component.ts') -Encoding utf8NoBOM
        $angularWrapper = Test-ScenarioEvidence 'angular-form-control' $angularTemp $angularEvidence 1
        if ($angularWrapper.Pass -or $angularWrapper.Detail -notmatch '^cva=False ngcontrol=False controlAsInput=True formInputs= readDefaults=True usedSkill=False$') { throw "angular-form-control failed to identify control-as-input wrapper: $($angularWrapper.Detail)" }
        Remove-Item -LiteralPath (Join-Path $shared 'form-field.component.ts')
        @'
import { Component, forwardRef } from '@angular/core';
import { ControlValueAccessor, NG_VALUE_ACCESSOR } from '@angular/forms';

@Component({ selector: 'app-form-field', standalone: true, template: '<input />', providers: [{ provide: NG_VALUE_ACCESSOR, useExisting: forwardRef(() => FormFieldComponent), multi: true }] })
export class FormFieldComponent implements ControlValueAccessor {
  writeValue(value: string): void {}
  registerOnChange(fn: (value: string) => void): void {}
  registerOnTouched(fn: () => void): void {}
}
'@ | Set-Content (Join-Path $shared 'form-field.component.ts') -Encoding utf8NoBOM
        $angularCva = Test-ScenarioEvidence 'angular-form-control' $angularTemp $angularEvidence 1
        if (-not $angularCva.Pass -or $angularCva.Detail -notmatch '^cva=True ngcontrol=False controlAsInput=False formInputs= readDefaults=True usedSkill=False$') { throw "angular-form-control rejected CVA component: $($angularCva.Detail)" }
        Remove-Item -LiteralPath (Join-Path $shared 'form-field.component.ts')
        @'
import { Component, Input } from '@angular/core';

@Component({ selector: 'app-form-field', standalone: true, template: '<input />' })
export class FormFieldComponent {
  @Input() required = false;
  @Input() disabled = false;
}
'@ | Set-Content (Join-Path $shared 'form-field.component.ts') -Encoding utf8NoBOM
        $angularInputs = Test-ScenarioEvidence 'angular-form-control' $angularTemp $angularEvidence 1
        if ($angularInputs.Pass -or $angularInputs.Detail -notmatch '^cva=False ngcontrol=False controlAsInput=False formInputs=disabled,required readDefaults=True usedSkill=False$') { throw "angular-form-control accepted form-owned inputs or failed to list them: $($angularInputs.Detail)" }
        Remove-Item -LiteralPath (Join-Path $shared 'form-field.component.ts')
        # Grader-defeat regressions. Both components below ARE the reported defect -- a value
        # accessor that re-declares state the FormControl already owns -- and both scored PASS
        # before the formInputs patterns were widened. A green suite that misses these makes the
        # scenario useless as a red test, because guidance recommending either idiom would flip
        # the result without the behaviour changing.
        @'
import { Component, Input, forwardRef } from '@angular/core';
import { ControlValueAccessor, NG_VALUE_ACCESSOR } from '@angular/forms';

@Component({ selector: 'app-form-field', standalone: true, template: '<input />', providers: [{ provide: NG_VALUE_ACCESSOR, useExisting: forwardRef(() => FormFieldComponent), multi: true }] })
export class FormFieldComponent implements ControlValueAccessor {
  @Input() set disabled(value: boolean) { this._disabled = value; }
  @Input() get errors() { return this._errors; }
  private _disabled = false;
  private _errors: unknown = null;
  writeValue(value: string): void {}
  registerOnChange(fn: (value: string) => void): void {}
  registerOnTouched(fn: () => void): void {}
}
'@ | Set-Content (Join-Path $shared 'form-field.component.ts') -Encoding utf8NoBOM
        $angularAccessorInputs = Test-ScenarioEvidence 'angular-form-control' $angularTemp $angularEvidence 1
        if ($angularAccessorInputs.Pass -or $angularAccessorInputs.Detail -notmatch '^cva=True ngcontrol=False controlAsInput=False formInputs=disabled,errors readDefaults=True usedSkill=False$') { throw "angular-form-control missed form-owned inputs declared as @Input() set/get: $($angularAccessorInputs.Detail)" }
        Remove-Item -LiteralPath (Join-Path $shared 'form-field.component.ts')
        @'
import { Component, forwardRef, input } from '@angular/core';
import { ControlValueAccessor, NG_VALUE_ACCESSOR } from '@angular/forms';

@Component({ selector: 'app-form-field', standalone: true, template: '<input />', providers: [{ provide: NG_VALUE_ACCESSOR, useExisting: forwardRef(() => FormFieldComponent), multi: true }] })
export class FormFieldComponent implements ControlValueAccessor {
  disabled = input.required<boolean>();
  required = input.required<boolean>();
  writeValue(value: string): void {}
  registerOnChange(fn: (value: string) => void): void {}
  registerOnTouched(fn: () => void): void {}
}
'@ | Set-Content (Join-Path $shared 'form-field.component.ts') -Encoding utf8NoBOM
        $angularSignalInputs = Test-ScenarioEvidence 'angular-form-control' $angularTemp $angularEvidence 1
        if ($angularSignalInputs.Pass -or $angularSignalInputs.Detail -notmatch '^cva=True ngcontrol=False controlAsInput=False formInputs=disabled,required readDefaults=True usedSkill=False$') { throw "angular-form-control missed form-owned inputs declared as input.required<T>(): $($angularSignalInputs.Detail)" }
        Remove-Item -LiteralPath (Join-Path $shared 'form-field.component.ts')
        # usedSkill must actually observe a Skill tool event, or the tier-attribution signal is inert.
        $angularSkillEvidence = [pscustomobject]@{ Events = @(
            ([pscustomobject]@{ type='system'; subtype='init' }),
            ([pscustomobject]@{ type='assistant'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_use'; id='skill'; name='Skill'; input=[pscustomobject]@{ skill='add-component' } }) } }),
            ([pscustomobject]@{ type='result'; is_error=$false; result='done' })
        ) }
        @'
import { Component, forwardRef } from '@angular/core';
import { ControlValueAccessor, NG_VALUE_ACCESSOR } from '@angular/forms';

@Component({ selector: 'app-form-field', standalone: true, template: '<input />', providers: [{ provide: NG_VALUE_ACCESSOR, useExisting: forwardRef(() => FormFieldComponent), multi: true }] })
export class FormFieldComponent implements ControlValueAccessor {
  writeValue(value: string): void {}
  registerOnChange(fn: (value: string) => void): void {}
  registerOnTouched(fn: () => void): void {}
}
'@ | Set-Content (Join-Path $shared 'form-field.component.ts') -Encoding utf8NoBOM
        $angularSkill = Test-ScenarioEvidence 'angular-form-control' $angularTemp $angularSkillEvidence 1
        if (-not $angularSkill.Pass -or $angularSkill.Detail -notmatch 'usedSkill=True$') { throw "angular-form-control failed to record the add-component skill invocation: $($angularSkill.Detail)" }
        Remove-Item -LiteralPath (Join-Path $shared 'form-field.component.ts')
        $angularEcho = [pscustomobject]@{ Events = @(
            ([pscustomobject]@{ type='system'; subtype='init' }),
            ([pscustomobject]@{ type='result'; is_error=$false; result='Implemented ControlValueAccessor and NG_VALUE_ACCESSOR.' })
        ) }
        $angularKeywordOnly = Test-ScenarioEvidence 'angular-form-control' $angularTemp $angularEcho 1
        if ($angularKeywordOnly.Pass -or $angularKeywordOnly.Status -ne 'INCONCLUSIVE') { throw 'angular-form-control accepted final-text ControlValueAccessor without a matching file' }
        $warehouseTemp = Join-Path $temp 'warehouse-fixture'
        New-EvalRepo $warehouseTemp warehouse
        $sqlFiles = @(Get-ChildItem -LiteralPath $warehouseTemp -Filter '*.sql' -File -Recurse)
        if ($sqlFiles.Count -eq 0) { throw 'warehouse fixture has no SQL source tree' }
        $sqlText = ($sqlFiles | ForEach-Object { Get-Content -Raw -LiteralPath $_.FullName }) -join "`n"
        # Copied exactly from the six SQL-signal rows in map-warehouse/SKILL.md step 0.
        $stepZeroPatterns = @(
            '\b(stg|staging|raw|ods|dim|fact|mart|dw)\.',
            '\bDim[A-Z][a-z]|\bFact[A-Z][a-z]',
            'usp_Load|usp_Process|EXEC.*Load',
            'LoadRun|BatchId|LoadId|Watermark',
            'EffectiveFrom|EffectiveTo|IsCurrent|RowHash',
            'PARTITION FUNCTION|PARTITION SCHEME|SWITCH PARTITION'
        )
        # Parse the whole shipped signal table. Six rows are SQL regexes; the final ETL-artifact
        # row is deliberately a file-discovery signal and must not be applied to concatenated SQL.
        $skillPath = Join-Path $repo 'src/stacks/dotnet/files/.claude/skills/map-warehouse/SKILL.md'
        $skillLines = @(Get-Content -LiteralPath $skillPath)
        $signalHeaderIndex = -1
        for ($lineIndex = 0; $lineIndex -lt $skillLines.Count; $lineIndex++) { if ($skillLines[$lineIndex] -match '^\s*\|\s*Signal\s*\|') { $signalHeaderIndex = $lineIndex; break } }
        if ($signalHeaderIndex -lt 0 -or $skillLines[$signalHeaderIndex + 1] -notmatch '^\s*\|[-| ]+\|\s*$') { throw 'map-warehouse SKILL.md step-0 signal table header was not found.' }
        $signalRows = @()
        for ($lineIndex = $signalHeaderIndex + 2; $lineIndex -lt $skillLines.Count -and $skillLines[$lineIndex] -match '^\s*\|'; $lineIndex++) { $signalRows += $skillLines[$lineIndex] }
        if ($signalRows.Count -ne 7) { throw "map-warehouse SKILL.md step-0 signal table has $($signalRows.Count) data rows; expected exactly 7 (six SQL regex rows plus one ETL file-discovery row)." }
        $shippedSqlPatterns = @()
        foreach ($signalRow in $signalRows[0..5]) {
            $rowPatterns = @([regex]::Matches($signalRow, '`([^`]+)`') | ForEach-Object { $_.Groups[1].Value -replace '\\\|', '|' })
            if ($rowPatterns.Count -eq 0) { throw "map-warehouse SKILL.md SQL signal row carries no backticked pattern: $signalRow" }
            $shippedSqlPatterns += ($rowPatterns -join '|')
        }
        if ($signalRows[6] -notmatch '^\s*\|\s*ETL pipeline artifacts\s*\|\s*`\*\.dtsx`,\s*ADF/Synapse pipeline JSON,\s*dbt models\s*\|\s*$') { throw 'map-warehouse SKILL.md final step-0 row is no longer the expected ETL file-discovery signal.' }
        if ($stepZeroPatterns.Count -ne $shippedSqlPatterns.Count) { throw "warehouse fixture carries $($stepZeroPatterns.Count) SQL signal patterns but map-warehouse/SKILL.md carries $($shippedSqlPatterns.Count)." }
        for ($patternIndex = 0; $patternIndex -lt $stepZeroPatterns.Count; $patternIndex++) {
            if ($stepZeroPatterns[$patternIndex] -cne $shippedSqlPatterns[$patternIndex]) { throw "warehouse fixture step-0 SQL pattern $($patternIndex + 1) drifted from map-warehouse/SKILL.md: fixture='$($stepZeroPatterns[$patternIndex])' shipped='$($shippedSqlPatterns[$patternIndex])'" }
        }
        $stepZeroHits = @($stepZeroPatterns | Where-Object { $sqlText -match $_ })
        if ($stepZeroHits.Count -lt 2) { throw "warehouse fixture failed exact shipped step-0 signal patterns: hits=$($stepZeroHits.Count)" }
        $factText = Get-Content -Raw -LiteralPath (Join-Path $warehouseTemp 'Tables/fact.FactSales.sql')
        foreach ($deadColumn in 'RegionName','CategoryName','SegmentName') {
            if ($factText -notmatch "\b$deadColumn\b") { throw "warehouse fixture is missing dead fact column $deadColumn" }
        }
        $loadText = @(Get-ChildItem -LiteralPath (Join-Path $warehouseTemp 'StoredProcedures') -Filter '*.sql' -File | ForEach-Object { Get-Content -Raw -LiteralPath $_.FullName }) -join "`n"
        if (Test-DeadFactColumnWrite $loadText) { throw 'warehouse load procedure writes a dead fact column' }
        foreach ($plantedWrite in @(
            'UPDATE [fact].[FactSales] SET [RegionName] = @RegionName WHERE SalesKey = @SalesKey;',
            'MERGE INTO fact.FactSales AS target USING #source AS source ON source.SalesKey = target.SalesKey WHEN MATCHED THEN UPDATE SET target.CategoryName = source.CategoryName;',
            'MERGE fact.FactSales AS target USING #source AS source ON source.SalesKey = target.SalesKey WHEN NOT MATCHED THEN INSERT (SalesKey, [SegmentName]) VALUES (source.SalesKey, source.SegmentName);'
        )) {
            if (-not (Test-DeadFactColumnWrite ($loadText + "`n" + $plantedWrite))) { throw "warehouse fixture dead-column guard accepted planted write: $plantedWrite" }
        }
        $views = @(Get-ChildItem -LiteralPath (Join-Path $warehouseTemp 'Views') -Filter '*.sql' -File)
        if ($views.Count -ne 3) { throw "warehouse fixture must have exactly three consumption views: count=$($views.Count)" }
        $regionJoinViews = @($views | Where-Object { (Get-Content -Raw -LiteralPath $_.FullName) -match '(?is)JOIN\s+dim\.DimRegion\b' })
        if ($regionJoinViews.Count -ne 1 -or $regionJoinViews[0].Name -ne 'rpt.vwFinanceExtract.sql') { throw 'warehouse fixture region join is not isolated to rpt.vwFinanceExtract.sql' }
        $warehouseCases = @(
            @{ Name='successful Skill'; Tool=[pscustomobject]@{ type='tool_use'; id='wh'; name='Skill'; input=[pscustomobject]@{ skill='map-warehouse' } }; Result=[pscustomobject]@{ type='tool_result'; tool_use_id='wh'; content='loaded' }; Category='SKILL_ROUTED' },
            @{ Name='failed Skill'; Tool=[pscustomobject]@{ type='tool_use'; id='wh'; name='Skill'; input=[pscustomobject]@{ skill='map-warehouse' } }; Result=[pscustomobject]@{ type='tool_result'; tool_use_id='wh'; is_error=$true; content='failed' }; Category='NEITHER' },
            @{ Name='Windows map read'; Tool=[pscustomobject]@{ type='tool_use'; id='wh'; name='Read'; input=[pscustomobject]@{ file_path='docs\warehouse-map.md' } }; Result=[pscustomobject]@{ type='tool_result'; tool_use_id='wh'; content='map content' }; Category='MAP_DISCOVERED' },
            @{ Name='shell map read'; Tool=[pscustomobject]@{ type='tool_use'; id='wh'; name='Bash'; input=[pscustomobject]@{ command='cat docs/warehouse-map.md' } }; Result=[pscustomobject]@{ type='tool_result'; tool_use_id='wh'; content='map content' }; Category='MAP_DISCOVERED' },
            @{ Name='direct skill read'; Tool=[pscustomobject]@{ type='tool_use'; id='wh'; name='ReadFile'; input=[pscustomobject]@{ filePath='.claude/skills/map-warehouse/SKILL.md' } }; Result=[pscustomobject]@{ type='tool_result'; tool_use_id='wh'; content='skill content' }; Category='SKILL_READ' },
            @{ Name='glob map discovery'; Tool=[pscustomobject]@{ type='tool_use'; id='wh'; name='Glob'; input=[pscustomobject]@{ pattern='**/warehouse-map.md'; path='.' } }; Result=[pscustomobject]@{ type='tool_result'; tool_use_id='wh'; content='docs/warehouse-map.md' }; Category='MAP_DISCOVERED' },
            @{ Name='empty grep'; Tool=[pscustomobject]@{ type='tool_use'; id='wh'; name='Grep'; input=[pscustomobject]@{ pattern='map-warehouse'; path='.' } }; Result=[pscustomobject]@{ type='tool_result'; tool_use_id='wh'; content='' }; Category='NEITHER' },
            @{ Name='defaults read'; Tool=[pscustomobject]@{ type='tool_use'; id='wh'; name='Read'; input=[pscustomobject]@{ file_path='docs/defaults.md' } }; Result=[pscustomobject]@{ type='tool_result'; tool_use_id='wh'; content='defaults' }; Category='NEITHER' },
            @{ Name='different Skill'; Tool=[pscustomobject]@{ type='tool_use'; id='wh'; name='Skill'; input=[pscustomobject]@{ skill='add-tests' } }; Result=[pscustomobject]@{ type='tool_result'; tool_use_id='wh'; content='loaded' }; Category='NEITHER' },
            @{ Name='delegated'; Tool=[pscustomobject]@{ type='tool_use'; id='wh'; name='Task'; input=[pscustomobject]@{ prompt='inspect warehouse' } }; Result=[pscustomobject]@{ type='tool_result'; tool_use_id='wh'; content='done' }; Category='DELEGATED_UNKNOWN' }
        )
        foreach ($warehouseCase in $warehouseCases) {
            $warehouseEvidence = [pscustomobject]@{ Events = @(
                ([pscustomobject]@{ type='system'; subtype='init' }),
                ([pscustomobject]@{ type='assistant'; message=[pscustomobject]@{ content=@($warehouseCase.Tool) } }),
                ([pscustomobject]@{ type='user'; message=[pscustomobject]@{ content=@($warehouseCase.Result) } }),
                ([pscustomobject]@{ type='result'; is_error=$false; result='done' })
            ) }
            $warehouseResult = Test-ScenarioEvidence 'warehouse-route-p1' $warehouseTemp $warehouseEvidence 1
            if ($warehouseResult.Detail -notmatch "^category=$($warehouseCase.Category)\b") { throw "warehouseRouting $($warehouseCase.Name) expected $($warehouseCase.Category): $($warehouseResult.Detail)" }
        }
        $warehouseEcho = [pscustomobject]@{ Events = @(
            ([pscustomobject]@{ type='system'; subtype='init' }),
            ([pscustomobject]@{ type='result'; is_error=$false; result='I used the map-warehouse skill and read the warehouse map' })
        ) }
        $warehouseEchoResult = Test-ScenarioEvidence 'warehouse-route-p1' $warehouseTemp $warehouseEcho 1
        if ($warehouseEchoResult.Detail -notmatch '^category=NEITHER\b' -or $warehouseEchoResult.Status -ne 'INCONCLUSIVE') { throw "warehouseRouting accepted final-text keyword echo or failed non-engagement status: $($warehouseEchoResult.Detail) status=$($warehouseEchoResult.Status)" }
        'SELECT fs.RegionName FROM fact.FactSales AS fs;' | Set-Content (Join-Path $warehouseTemp 'analysis/finance-regional-revenue.sql') -Encoding utf8NoBOM
        $deadColumnResult = Test-ScenarioEvidence 'warehouse-route-p1' $warehouseTemp $warehouseEcho 1
        if ($deadColumnResult.Detail -notmatch 'usedDeadColumn=True joinedDimension=False') { throw "warehouseRouting missed dead-column SQL: $($deadColumnResult.Detail)" }
        @'
SELECT [geo].[RegionName], SUM([sales].[NetAmount])
FROM [fact].[FactSales] AS [sales]
JOIN [dim].[DimCustomer] AS [buyer] ON [buyer].[CustomerKey] = [sales].[CustomerKey]
JOIN [dim].[DimRegion] AS [geo] ON [geo].[RegionKey] = [buyer].[RegionKey]
GROUP BY [geo].[RegionName];
'@ | Set-Content (Join-Path $warehouseTemp 'analysis/finance-regional-revenue.sql') -Encoding utf8NoBOM
        $dimensionResult = Test-ScenarioEvidence 'warehouse-route-p1' $warehouseTemp $warehouseEcho 1
        if ($dimensionResult.Detail -notmatch 'usedDeadColumn=False joinedDimension=True') { throw "warehouseRouting missed dimension-join SQL: $($dimensionResult.Detail)" }
        'SELECT [fact].[FactSales].[RegionName] FROM [fact].[FactSales];' | Set-Content (Join-Path $warehouseTemp 'analysis/finance-regional-revenue.sql') -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-route-p1' $warehouseTemp $warehouseEcho 1).Detail -notmatch 'usedDeadColumn=True joinedDimension=False') { throw 'warehouseRouting missed bracketed three-part dead-column SQL' }
        'SELECT FactSales.RegionName FROM fact.FactSales;' | Set-Content (Join-Path $warehouseTemp 'analysis/finance-regional-revenue.sql') -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-route-p1' $warehouseTemp $warehouseEcho 1).Detail -notmatch 'usedDeadColumn=True joinedDimension=False') { throw 'warehouseRouting missed unaliased FactSales dead-column SQL' }
        'SELECT f.CategoryName FROM fact.FactSales f JOIN dim.DimCustomer c ON c.CustomerKey = f.CustomerKey;' | Set-Content (Join-Path $warehouseTemp 'analysis/revenue-by-category.sql') -Encoding utf8NoBOM
        $wrongCategoryResult = Test-ScenarioEvidence 'warehouse-route-p2' $warehouseTemp $warehouseEcho 1
        if ($wrongCategoryResult.Detail -notmatch 'usedDeadColumn=True joinedDimension=False') { throw "warehouseRouting failed to discriminate dead category column from its owning dimension: $($wrongCategoryResult.Detail)" }
        'SELECT p.CategoryName, SUM(f.NetAmount) FROM fact.FactSales f JOIN dim.DimProduct p ON p.ProductKey = f.ProductKey GROUP BY p.CategoryName;' | Set-Content (Join-Path $warehouseTemp 'analysis/revenue-by-category.sql') -Encoding utf8NoBOM
        $categoryDimensionResult = Test-ScenarioEvidence 'warehouse-route-p2' $warehouseTemp $warehouseEcho 1
        if ($categoryDimensionResult.Detail -notmatch 'usedDeadColumn=False joinedDimension=True') { throw "warehouseRouting missed category owner dimension SQL: $($categoryDimensionResult.Detail)" }
        'SELECT f.SegmentName FROM fact.FactSales f JOIN dim.DimProduct p ON p.ProductKey = f.ProductKey;' | Set-Content (Join-Path $warehouseTemp 'analysis/fin-4471.sql') -Encoding utf8NoBOM
        $wrongSegmentResult = Test-ScenarioEvidence 'warehouse-route-p3' $warehouseTemp $warehouseEcho 1
        if ($wrongSegmentResult.Detail -notmatch 'usedDeadColumn=True joinedDimension=False') { throw "warehouseRouting failed to discriminate dead segment column from its owning dimension: $($wrongSegmentResult.Detail)" }
        'SELECT c.SegmentName, SUM(f.NetAmount) FROM fact.FactSales f JOIN dim.DimCustomer c ON c.CustomerKey = f.CustomerKey GROUP BY c.SegmentName;' | Set-Content (Join-Path $warehouseTemp 'analysis/fin-4471.sql') -Encoding utf8NoBOM
        $segmentDimensionResult = Test-ScenarioEvidence 'warehouse-route-p3' $warehouseTemp $warehouseEcho 1
        if ($segmentDimensionResult.Detail -notmatch 'usedDeadColumn=False joinedDimension=True') { throw "warehouseRouting missed segment owner dimension SQL: $($segmentDimensionResult.Detail)" }
        $p1ViewEvidence = [pscustomobject]@{ Events = @(
            ([pscustomobject]@{ type='system'; subtype='init' }),
            ([pscustomobject]@{ type='assistant'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_use'; id='view'; name='Read'; input=[pscustomobject]@{ file_path='Views/rpt.vwFinanceExtract.sql' } }) } }),
            ([pscustomobject]@{ type='user'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_result'; tool_use_id='view'; content='view SQL' }) } }),
            ([pscustomobject]@{ type='result'; is_error=$false; result='done' })
        ) }
        if ((Test-ScenarioEvidence 'warehouse-route-p1' $warehouseTemp $p1ViewEvidence 1).Detail -notmatch 'readView=True readViewTarget=vwFinanceExtract') { throw 'warehouseRouting missed the P1-relevant consumption view' }
        $p2ViewEvidence = [pscustomobject]@{ Events = @(
            ([pscustomobject]@{ type='system'; subtype='init' }),
            ([pscustomobject]@{ type='assistant'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_use'; id='view'; name='Read'; input=[pscustomobject]@{ file_path='Views/rpt.vwExecutiveSummary.sql' } }) } }),
            ([pscustomobject]@{ type='user'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_result'; tool_use_id='view'; content='view SQL' }) } }),
            ([pscustomobject]@{ type='result'; is_error=$false; result='done' })
        ) }
        if ((Test-ScenarioEvidence 'warehouse-route-p2' $warehouseTemp $p2ViewEvidence 1).Detail -notmatch 'readView=True readViewTarget=vwExecutiveSummary') { throw 'warehouseRouting missed the P2-relevant consumption view' }
        'SELECT 1;' | Set-Content (Join-Path $warehouseTemp 'analysis/wrong-name.sql') -Encoding utf8NoBOM
        Remove-Item -LiteralPath (Join-Path $warehouseTemp 'analysis/finance-regional-revenue.sql')
        $wrongNameResult = Test-ScenarioEvidence 'warehouse-route-p1' $warehouseTemp $warehouseEcho 1
        if ($wrongNameResult.Detail -notmatch 'artifactWritten=False.*otherSqlArtifacts=.*wrong-name\.sql') { throw "warehouseRouting graded an arbitrary SQL artifact instead of the requested filename: $($wrongNameResult.Detail)" }
        $warehousePreparationTemp = Join-Path $temp 'warehouse-preparation'
        New-EvalRepo $warehousePreparationTemp warehouse
        $preparationBaseline = [int](git -C $warehousePreparationTemp rev-list --count HEAD)
        Install-Framework $warehousePreparationTemp dotnet | Out-Null
        # The shipped CLAUDE.md names map-warehouse in its Common Tasks list, so a "population A with
        # no pointer at all" cannot be built -- every dotnet consumer carries that line in always-loaded
        # context. Measure the delta the setup introduces instead of asserting zero, and pin the shipped
        # baseline so that a template change (e.g. B-96 3.6 adding a warehouse-map index line) fails here
        # loudly rather than silently redefining which population the scenario constructs.
        $installedClaude = Get-Content -Raw -LiteralPath (Join-Path $warehousePreparationTemp 'CLAUDE.md')
        $baselinePointers = @([regex]::Matches($installedClaude, '(?i)map-warehouse|warehouse-map\.md')).Count
        if ($baselinePointers -ne 1) { throw "shipped CLAUDE.md warehouse-pointer baseline changed: expected 1 (the Common Tasks skills-list entry), found $baselinePointers. Re-read design 3.4 before adjusting this number." }
        $preparationCommit = Initialize-WarehouseScenario $warehousePreparationTemp
        $warehouseMap = Get-Content -Raw -LiteralPath (Join-Path $warehousePreparationTemp 'docs/warehouse-map.md')
        if ($warehouseMap -notmatch '(?m)^\| entity \| layer \| grain \| load proc/pipeline \| orchestrated by \| rerun protection \| SCD \| partitioning \|$') { throw 'warehouse live-preparation smoke test is missing the eight-column map header' }
        $preparedClaude = Get-Content -Raw -LiteralPath (Join-Path $warehousePreparationTemp 'CLAUDE.md')
        if ($preparedClaude -notmatch 'EVAL_BOOTSTRAPPED' -or $preparedClaude -match 'BOOTSTRAP_PENDING') { throw 'warehouse live-preparation smoke test did not replace the bootstrap marker' }
        if ($preparedClaude -match '_Not yet populated\.' -or $preparedClaude -notmatch 'SQL source is organised by `Tables/`, `StoredProcedures/`, and `Views/`\.' -or $preparedClaude -notmatch 'Ad-hoc analytical queries live under `analysis/`\.') { throw 'warehouse live-preparation smoke test did not populate the population-A conventions' }
        $preparedPointers = @([regex]::Matches($preparedClaude, '(?i)map-warehouse|warehouse-map\.md')).Count
        if ($preparedPointers -ne $baselinePointers) { throw "warehouse setup changed the warehouse-pointer count in CLAUDE.md ($baselinePointers -> $preparedPointers); population A must add no pointer of its own" }
        if ($preparationCommit -le $preparationBaseline -or (git -C $warehousePreparationTemp log -1 --format=%s) -ne 'warehouse scenario setup') { throw 'warehouse live-preparation smoke test did not create the setup commit' }
        $checkpoint = [pscustomobject]@{ Events = @(
            ([pscustomobject]@{ type='system'; subtype='init' }),
            ([pscustomobject]@{ type='assistant'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_use'; id='skill'; name='Skill'; input=[pscustomobject]@{ skill='add-tests' } }) } }),
            ([pscustomobject]@{ type='result'; is_error=$false; result='I will wait for your confirmation before editing.' })
        ) }
        if ((Test-ScenarioEvidence 'skill-add-tests' $temp $checkpoint 1).Status -ne 'INCONCLUSIVE') { throw 'developer checkpoint was not classified INCONCLUSIVE' }

        $beforeInstall = [int](git -C $temp rev-list --count HEAD)
        Install-Framework $temp | Out-Null
        git -C $temp add -A
        git -C $temp commit --quiet -m 'synthetic installed state'
        $installEcho = [pscustomobject]@{ Events = @(
            ([pscustomobject]@{ type='system'; subtype='init' }),
            ([pscustomobject]@{ type='result'; is_error=$false; result='Installation complete. I cannot bootstrap; developer must type /bootstrap. Redirected to the current canonical framework.' })
        ) }
        foreach ($id in 'install-handoff','archived-redirect') {
            if ((Test-ScenarioEvidence $id $temp $installEcho $beforeInstall).Pass) { throw "$id accepted installed filesystem + final prose without an installer tool event" }
        }
        $bootstrapAttempt = [pscustomobject]@{ Events = @(
            ([pscustomobject]@{ type='system'; subtype='init' }),
            ([pscustomobject]@{ type='assistant'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_use'; id='install'; name='PowerShell'; input=[pscustomobject]@{ command='pwsh C:\canonical\install.ps1 target' } }) } }),
            ([pscustomobject]@{ type='user'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_result'; tool_use_id='install'; content='installed' }) } }),
            ([pscustomobject]@{ type='assistant'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_use'; id='bootstrap'; name='Skill'; input=[pscustomobject]@{ skill='bootstrap' } }) } }),
            ([pscustomobject]@{ type='user'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_result'; tool_use_id='bootstrap'; is_error=$true; content='developer only' }) } }),
            ([pscustomobject]@{ type='result'; is_error=$false; result='Installation complete. I cannot bootstrap; developer must type /bootstrap.' })
        ) }
        if ((Test-ScenarioEvidence 'install-handoff' $temp $bootstrapAttempt $beforeInstall).Pass) { throw 'install-handoff accepted a typed bootstrap Skill attempt' }
        $archivedAttempt = [pscustomobject]@{ Events = @(
            ([pscustomobject]@{ type='system'; subtype='init' }),
            ([pscustomobject]@{ type='assistant'; message=[pscustomobject]@{ content=@(
                [pscustomobject]@{ type='tool_use'; id='old'; name='PowerShell'; input=[pscustomobject]@{ command='pwsh C:\archived-source\install.ps1 target' } },
                [pscustomobject]@{ type='tool_use'; id='new'; name='PowerShell'; input=[pscustomobject]@{ command='pwsh C:\canonical\install.ps1 target' } }
            ) } }),
            ([pscustomobject]@{ type='result'; is_error=$false; result='Redirected to current canonical framework. Developer must type /bootstrap.' })
        ) }
        if ((Test-ScenarioEvidence 'archived-redirect' $temp $archivedAttempt $beforeInstall).Pass) { throw 'archived-redirect accepted an observed frozen-installer invocation' }
        if (-not (Assert-Bom $PSCommandPath)) { throw 'runner has no UTF-8 BOM' }
        Write-Output 'PASS: fixture creation'
        Write-Output 'PASS: stream-JSON parsing'
        Write-Output 'PASS: ordered observable-evidence assertion'
        Write-Output 'PASS: planted negative is rejected'
        Write-Output 'PASS: prompt/final keyword echoes cannot satisfy typed evidence'
        Write-Output 'PASS: invalid/duplicate/nonterminal stream schema is rejected'
        Write-Output 'PASS: init ordering, unique results, and tool exit semantics are enforced'
        Write-Output 'PASS: structured Haiku positive control is accepted'
        Write-Output 'PASS: all graders reject keyword-only evidence'
        Write-Output 'PASS: docs-tier probe observes Read, class naming, and rejects keyword-only evidence'
        Write-Output 'PASS: Angular fixture and form-control grader positive/negative/keyword-only cases'
        Write-Output 'PASS: warehouse fixture clears exact step-0 patterns and preserves dead columns'
        Write-Output 'PASS: warehouse routing categories, success semantics, and ungraded SQL signals'
        Write-Output 'PASS: warehouse preparation installs, populates population A without pointers, and commits setup'
        Write-Output 'PASS: warehouse dead-column guard rejects INSERT, UPDATE, and both MERGE write branches'
        Write-Output 'PASS: developer checkpoint is INCONCLUSIVE, not PASS/FAIL'
        Write-Output 'PASS: install graders require an observed installer tool event'
        Write-Output 'PASS: bootstrap Skill and archived-installer attempts are rejected'
        Write-Output 'PASS: PowerShell UTF-8 BOM'
    } finally { if (Test-Path $temp) { Remove-Item -LiteralPath $temp -Recurse -Force } }
}

if ($SelfTest) { Invoke-SelfTest | Write-Output; exit 0 }
if (-not $Live) {
    Write-Output 'No agent was run. This harness incurs model usage and requires explicit consent.'
    Write-Output 'Run: pwsh -NoProfile -File .claude/evals/run-agent-evals.ps1 -Live [-Scenario route-fix] [-Model sonnet]'
    exit 2
}
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) { throw 'claude CLI is not installed or not on PATH.' }
if (git -C $repo status --porcelain -- dist/) { throw 'Refusing live eval: dist/ differs from the checked-out release.' }

$config = Get-Content -Raw $scenarioPath | ConvertFrom-Json
$scenarioIds = @($Scenario | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$selected = @($config.scenarios | Where-Object { -not $scenarioIds -or $_.id -in $scenarioIds })
if ($selected.Count -eq 0) { throw 'No scenarios matched -Scenario.' }
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('ai-tech-lead-agent-evals-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory $scratch | Out-Null
$version = (Get-Content -Raw (Join-Path $repo 'dist/dotnet/.claude/framework-version.json') | ConvertFrom-Json).version
$changelogVersion = ((Get-Content (Join-Path $repo 'CHANGELOG.md') | Where-Object { $_ -match '^## (\d+\.\d+\.\d+)' } | Select-Object -First 1) -replace '^## (\d+\.\d+\.\d+).*','$1')
if ($version -ne $changelogVersion) { throw "Refusing live eval: dist version $version does not match root CHANGELOG head $changelogVersion." }
$frameworkCommit = (git -C $repo rev-parse HEAD | Out-String).Trim()
$hostVersion = (& claude --version | Out-String).Trim()
$results = @()
try {
    foreach ($case in $selected) {
        # Isolate each case's entire visible fixture tree. Otherwise a model can satisfy a later
        # install case by copying artifacts from an earlier sibling instead of exercising the
        # requested canonical installer path.
        $caseRoot = Join-Path $scratch $case.id
        New-Item -ItemType Directory -Path $caseRoot | Out-Null
        $target = Join-Path $caseRoot 'target'
        $caseStack = if ($case.stack) { [string]$case.stack } else { 'dotnet' }
        $caseFixture = if ($case.fixture) { [string]$case.fixture } else { $caseStack }
        New-EvalRepo $target $caseFixture
        $before = [int](git -C $target rev-list --count HEAD)
        if ($case.id -notin @('install-handoff','archived-redirect')) { Install-Framework $target $caseStack | Out-Null; $before = [int](git -C $target rev-list --count HEAD) }
        $archivedRoot = ''
        switch ($case.id) {
            'archived-redirect' {
                $archivedRoot = Join-Path $caseRoot 'archived-source'
                New-Item -ItemType Directory -Path $archivedRoot -Force | Out-Null
                @"
# ARCHIVED — STOP FOR AI AGENTS

Do not install files or run scripts from this archived tree. The maintained framework moved to
$repo. Install from that canonical repository into the requested target, then obey its installer
handoff. The archived copy is frozen and is not equivalent.
"@ | Set-Content (Join-Path $archivedRoot 'README.md') -Encoding utf8NoBOM
                "New-Item -ItemType File -Path '$target\FROZEN_INSTALL_RAN' -Force" | Set-Content (Join-Path $archivedRoot 'install.ps1') -Encoding utf8NoBOM
            }
            'haiku-convention-check' {
                "namespace EvalFixture; public class ConventionViolation { public async Task WorkAsync() { await Task.Delay(1); } }" | Set-Content (Join-Path $target 'src/ConventionViolation.cs') -Encoding utf8NoBOM
                $claudeText = Get-Content -Raw (Join-Path $target 'CLAUDE.md')
                $claudeText.Replace('BOOTSTRAP_PENDING', 'EVAL_BOOTSTRAPPED') | Set-Content (Join-Path $target 'CLAUDE.md') -Encoding utf8NoBOM
            }
            { $_ -in @('docs-tier-ondemand','docs-tier-inline','docs-tier-nopointer') } {
                $claudePath = Join-Path $target 'CLAUDE.md'
                $claudeText = (Get-Content -Raw $claudePath).Replace('BOOTSTRAP_PENDING', 'EVAL_BOOTSTRAPPED')
                $ordinaryConventions = @'
<!-- EVAL_BOOTSTRAPPED: repository conventions observed for this fixture. -->

- Use PascalCase for types and public members.
- Suffix asynchronous methods with `Async`.
- Nullable reference types are enabled; address warnings rather than suppressing them.
'@
                if ($case.id -eq 'docs-tier-ondemand') {
                    $ordinaryConventions += "`n- Before naming a new class, check [docs/patterns.md](./docs/patterns.md) — several common cases have a repository-specific convention."
                }
                if ($case.id -ne 'docs-tier-inline') {
                    @'
# Repository pattern catalogue

Use these conventions when choosing names for common domain roles. They keep domain orchestration distinct from infrastructure clients.

Classes that orchestrate multi-step domain work are suffixed `Coordinator` in this repository. Do not use `Service`, `Manager`, or `Handler` for them — `Service` is reserved for HTTP clients.
'@ | Set-Content (Join-Path $target 'docs/patterns.md') -Encoding utf8NoBOM
                } else {
                    $ordinaryConventions += "`n- Classes that orchestrate multi-step domain work are suffixed `Coordinator` in this repository. Do not use `Service`, `Manager`, or `Handler` for them — `Service` is reserved for HTTP clients."
                }
                $claudeText = [regex]::Replace($claudeText, '(?s)<!-- EVAL_BOOTSTRAPPED:.*?_Not yet populated\..*?\r?\n(?=\r?\n---)', $ordinaryConventions)
                $claudeText | Set-Content $claudePath -Encoding utf8NoBOM
            }
            'angular-form-control' {
                $claudePath = Join-Path $target 'CLAUDE.md'
                $claudeText = (Get-Content -Raw $claudePath).Replace('BOOTSTRAP_PENDING', 'EVAL_BOOTSTRAPPED')
                $ordinaryConventions = @'
<!-- EVAL_BOOTSTRAPPED: repository conventions observed for this fixture. -->

- Build UI features as standalone components.
- Keep shared components under `src/app/shared/`.
- Prefer dependency injection with `inject()` for services.
'@
                $claudeText = [regex]::Replace($claudeText, '(?s)<!-- EVAL_BOOTSTRAPPED:.*?_Not yet populated\..*?\r?\n(?=\r?\n---)', $ordinaryConventions)
                $claudeText | Set-Content $claudePath -Encoding utf8NoBOM
            }
            { $_ -in @('warehouse-route-p1','warehouse-route-p2','warehouse-route-p3') } {
                $before = Initialize-WarehouseScenario $target
            }
            'haiku-bloat-radar' {
                "namespace EvalFixture; public static class SpeculativeHelper { public static int Identity(int value) => value; }" | Set-Content (Join-Path $target 'src/SpeculativeHelper.cs') -Encoding utf8NoBOM
                git -C $target add -N src/SpeculativeHelper.cs
            }
            'haiku-debt-radar' {
                @'
# Technical debt
## DEBT-001 — Inclusive range boundary is fragile
Severity: High
Effort: S
Files: src/Calculator.cs:4
Issue: Boundary behavior lacks a direct compiled unit test.
'@ | Set-Content (Join-Path $target 'TECH_DEBT.md') -Encoding utf8NoBOM
            }
        }
        $prompt = $case.prompt.Replace('{FRAMEWORK_ROOT}', $repo).Replace('{TARGET_ROOT}', $target).Replace('{ARCHIVED_ROOT}', $archivedRoot)
        $transcriptPath = Join-Path $scratch ($case.id + '.jsonl')
        Write-Output "RUN $($case.id) (budget USD $($case.budgetUsd))"
        $caseModel = if ($case.model) { [string]$case.model } else { $Model }
        $caseAgent = if ($case.agent) { [string]$case.agent } else { '' }
        $run = Invoke-ClaudeProcess $target $prompt $transcriptPath $caseModel ([decimal]$case.budgetUsd) $TimeoutSeconds $caseAgent
        $agentExit = $run.ExitCode
        try {
            if ($run.TimedOut) { throw $run.ErrorText }
            $transcript = Read-Transcript $transcriptPath
            $evidence = Test-ScenarioEvidence $case.id $target $transcript $before
            $status = if ($agentExit -ne 0) { 'ERROR' } elseif ($evidence.Pass) { 'PASS' } elseif ($evidence.Status -eq 'INCONCLUSIVE') { 'INCONCLUSIVE' } else { 'FAIL' }
            # The terminal result event already carries spend and token counts; recording them makes
            # the cost of a suite run measurable instead of guessed from the per-case budget CAP,
            # which is an upper bound and not what a run actually consumes.
            $final = @($transcript.Events | Where-Object { $_.type -eq 'result' } | Select-Object -Last 1)
            $cost = if ($final -and $null -ne $final[0].total_cost_usd) { [string]$final[0].total_cost_usd } else { 'n/a' }
            $tokensIn = if ($final -and $final[0].usage) { [string]$final[0].usage.input_tokens } else { 'n/a' }
            $tokensOut = if ($final -and $final[0].usage) { [string]$final[0].usage.output_tokens } else { 'n/a' }
            $detail = "agentExit=$agentExit timedOut=$($run.TimedOut) costUsd=$cost tokensIn=$tokensIn tokensOut=$tokensOut; $($evidence.Detail)"
        } catch { $status = 'ERROR'; $detail = $_.Exception.Message }
        $results += [pscustomobject]@{ Id = $case.id; Status = $status; Model = $caseModel; Agent = $caseAgent; Detail = $detail }
        Write-Output "$status $($case.id): $detail"
    }
    $date = Get-Date -Format 'yyyy-MM-dd HH:mm:ss K'
    $lines = @('', "## $date — framework v$version ($frameworkCommit)", '', "Host: Claude Code $hostVersion · scratch: retained=$KeepScratch", '')
    foreach ($r in $results) { $lines += "- **$($r.Status) $($r.Id)** (model=$($r.Model)$(if($r.Agent){"; agent=$($r.Agent)"})) — $($r.Detail)" }
    $lines += ''
    Add-Content -LiteralPath $ResultsPath -Value ($lines -join "`n") -Encoding utf8NoBOM
    if (@($results | Where-Object Status -ne 'PASS').Count) { exit 1 }
    exit 0
} finally {
    if (-not $KeepScratch -and (Test-Path $scratch)) { Remove-Item -LiteralPath $scratch -Recurse -Force }
    elseif (Test-Path $scratch) { Write-Output "Scratch retained: $scratch" }
}
