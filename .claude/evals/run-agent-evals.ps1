#Requires -Version 7.0
# B-41 maintainer-only live agent eval harness. Meta tooling is PowerShell-only. It never runs in
# CI and spends API/subscription budget only with
# the explicit -Live switch.
[CmdletBinding(DefaultParameterSetName = 'Explain')]
param(
    [Parameter(ParameterSetName = 'Live', Mandatory)][switch]$Live,
    [Parameter(ParameterSetName = 'SelfTest', Mandatory)][switch]$SelfTest,
    [Parameter(ParameterSetName = 'Live')][string[]]$Scenario,
    [Parameter(ParameterSetName = 'Live')][string]$Model = 'sonnet',
    # B-277 (WSD-097): one runner, two executors. Omitting -Executor keeps the Claude Code launch,
    # graders, transcript and results rows exactly as they were. -CopilotModel is never 'auto'; its default is the
    # model the Claude Code arm's `sonnet` resolves to, so the two executors differ by host only.
    [Parameter(ParameterSetName = 'Live')][ValidateSet('claude','copilot')][string]$Executor = 'claude',
    [Parameter(ParameterSetName = 'Live')][string]$CopilotModel = 'claude-sonnet-5.5',
    # B-305: 0 runs uncapped. Copilot shows the model its remaining credits each turn, so a cap reads as
    # a budget to economise against; the results header records any cap a run used.
    [Parameter(ParameterSetName = 'Live')][ValidateScript({ $_ -eq 0 -or ($_ -ge 30 -and $_ -le 500) })][int]$CopilotMaxAiCredits = 0,
    # B-253: 'none' skips the framework install so the same prompt and fixture run bare. Only
    # scenarios marked "bareArm" in scenarios.json carry an arm-neutral Outcome and may run bare.
    [Parameter(ParameterSetName = 'Live')][ValidateSet('framework','none')][string]$Arm = 'framework',
    # B-280: which docs/warehouse-map.md the warehouse-route scenarios run against. 'frozen' is the
    # B-98 fixture; 'omit' and 'enriched' separate the map's effect from the framework's. 'generated'
    # is the consumer journey: the files a real /bootstrap then /map-warehouse wrote, frozen under
    # meta/eval-fixtures/warehouse-generated/, replace the simulated bootstrap and the hand-written map.
    # 'partial' is that overlay with every generated document silent on ctl.LoadRun and LoadRunId.
    [Parameter(ParameterSetName = 'Live')][ValidateSet('frozen','omit','enriched','generated','partial')][string]$WarehouseMap = 'frozen',
    # B-253: a unified diff applied to the installed framework right after Install-Framework, so a
    # text variant (a B-255 candidate, a knockout, a probe) runs through the same fixture path as
    # the unpatched framework. Framework arm only; the header, every row and the SUMMARY name it.
    # B-402: under -WarehouseMap generated|partial it lands after the bootstrap overlay instead.
    [Parameter(ParameterSetName = 'Live')][string]$TargetPatch,
    [Parameter(ParameterSetName = 'Live')][ValidateRange(1, 20)][int]$Trials = 1,
    [Parameter(ParameterSetName = 'Live')][ValidateRange(30, 1800)][int]$TimeoutSeconds = 300,
    [Parameter(ParameterSetName = 'Live')][bool]$KeepScratch = $true,
    [Parameter(ParameterSetName = 'Live')][string]$ResultsPath
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
# The runner pins the release it evaluates. The installer's clone check (B-324) would read the network
# and could refuse this checkout, both in fixture installs and in the installs agents run from it.
$env:ATL_SOURCE_CHECK = 'off'
$scenarioPath = Join-Path $PSScriptRoot 'scenarios.json'
# B-406/B-409: the contract fixtures, one list. Every condition that keys on them is a membership test on it, never a name.
# b409-orders-ci is b406-orders with a CI workflow in its baseline commit.
$contractFixtures = @('b406-orders', 'b409-orders-ci')
# Carrier trim: the route graders report whether the router's rails reached the prompt (routerFired), read from the UserPromptSubmit hook_response,
# which Claude Code carries only with --include-hook-events. Asked for by these two scenarios as well as the contract fixtures.
$routerProbeScenarios = @('route-fix', 'route-fix-nl', 'route-fix-notest')
# The install cases: the agent installs the framework itself, so the runner installs nothing first and -TargetPatch has nothing to patch.
# B-404: url-install-readme-* are the URL-install cases on the prompt the root README suggests, which asks for the commit.
$selfInstallScenarios = @('install-handoff', 'archived-redirect', 'url-install-greenfield', 'url-install-brownfield', 'url-install-readme-greenfield', 'url-install-readme-brownfield')
if (-not $ResultsPath) { $ResultsPath = Join-Path $repo 'meta/eval-results.md' }
# Built at runtime: the outgoing-commit guard refuses a blob holding the key-shaped literal. The
# guard-retry prompt the agent receives is unchanged.
$syntheticAwsKey = 'AKIA' + '1234567890ABCDEF'

function Assert-Bom([string]$Path) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    return $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
}

function New-EvalRepo([string]$Path, [ValidateSet('dotnet','dotnet-notest','angular','angular-ux','b406-orders','b409-orders-ci','warehouse','warehouse-mixed','warehouse-fact-binding','warehouse-schema-compatible','warehouse-schema-incompatible','warehouse-schema-incomplete','warehouse-partition-mismatch','warehouse-health-a','warehouse-health-b','warehouse-health-clean','warehouse-health-convention','warehouse-health-no-trigger','warehouse-health-bridge-ok','warehouse-trace-keyres-pinned','warehouse-trace-keyres-deferred','warehouse-trace-attribute-a','warehouse-trace-attribute-b','warehouse-trace-metric-ratio','warehouse-trace-metric-additive','warehouse-trace-decoy','warehouse-trace-conflict')][string]$Stack = 'dotnet') {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    if ($Stack -in $contractFixtures) {
        # B-406 fixture v2: the frozen B-345 generator (it deletes and recreates $Path itself), then an Orders.sln.
        # The project GUIDs `dotnet sln add` writes are not deterministic, so two builds differ in Orders.sln only.
        # B-409: b409-orders-ci is the same plus .github/workflows/ci.yml in the baseline commit.
        $generator = Join-Path $repo 'meta/eval-fixtures/b345-bootstrap-skills/generate.py'
        $generatorRefusal = Get-B406GeneratorRefusal $generator $Stack
        if ($generatorRefusal) { throw $generatorRefusal }
        $python = (Get-Command python -ErrorAction Stop).Source
        $output = & $python $generator $Path 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) { throw "${Stack}: the fixture generator failed (exit $LASTEXITCODE):`n$output" }
        $solution = Join-Path $Path 'Orders.sln'
        $telemetryOptOut = $env:DOTNET_CLI_TELEMETRY_OPTOUT
        $noLogo = $env:DOTNET_NOLOGO
        $env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
        $env:DOTNET_NOLOGO = '1'
        try {
            $output = dotnet new sln -n Orders -o $Path 2>&1 | Out-String
            if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $solution -PathType Leaf)) { throw "${Stack}: dotnet new sln failed (exit $LASTEXITCODE):`n$output" }
            $projects = @(Get-ChildItem -LiteralPath (Join-Path $Path 'src'), (Join-Path $Path 'tests') -Recurse -File -Filter '*.csproj' | ForEach-Object { $_.FullName })
            [Array]::Sort($projects, [StringComparer]::Ordinal)
            if ($projects.Count -eq 0) { throw "${Stack}: the generator wrote no project under src/ or tests/." }
            $output = dotnet sln $solution add $projects 2>&1 | Out-String
            if ($LASTEXITCODE -ne 0) { throw "${Stack}: dotnet sln add failed (exit $LASTEXITCODE):`n$output" }
        } finally {
            if ($null -eq $telemetryOptOut) { Remove-Item Env:DOTNET_CLI_TELEMETRY_OPTOUT -ErrorAction SilentlyContinue } else { $env:DOTNET_CLI_TELEMETRY_OPTOUT = $telemetryOptOut }
            if ($null -eq $noLogo) { Remove-Item Env:DOTNET_NOLOGO -ErrorAction SilentlyContinue } else { $env:DOTNET_NOLOGO = $noLogo }
        }
        if ($Stack -eq 'b409-orders-ci') { Write-B409CiWorkflow $Path }
        git -C $Path init --quiet
        git -C $Path config user.email 'agent-evals@invalid.local'
        git -C $Path config user.name 'Agent Evals'
        git -C $Path add -A
        git -C $Path commit --quiet -m 'fixture baseline'
        return
    }
    if ($Stack -in @('warehouse-health-clean','warehouse-health-convention','warehouse-health-no-trigger')) {
        if ($Stack -eq 'warehouse-health-no-trigger') {
            New-EvalRepo $Path warehouse-health-clean
            @'
CREATE TABLE fact.FactCampaignResponse (
    ResponseKey BIGINT NOT NULL PRIMARY KEY,
    InvoiceKey BIGINT NOT NULL,
    CampaignKey INT NOT NULL,
    ResponseAmount DECIMAL(18,2) NOT NULL
);
'@ | Set-Content -LiteralPath (Join-Path $Path 'Tables/fact.FactCampaignResponse.sql') -Encoding utf8NoBOM
            git -C $Path add -A
            git -C $Path commit --quiet -m 'campaign response evidence'
            return
        }
        New-Item -ItemType Directory -Path (Join-Path $Path 'Tables'), (Join-Path $Path 'StoredProcedures'), (Join-Path $Path 'Views'), (Join-Path $Path 'docs') -Force | Out-Null
        '<Project Sdk="Microsoft.Build.Sql/0.2.0" />' | Set-Content -LiteralPath (Join-Path $Path 'warehouse.sqlproj') -Encoding utf8NoBOM
        'CREATE TABLE dim.DimDate (DateKey INT NOT NULL PRIMARY KEY, CalendarDate DATE NOT NULL UNIQUE);' | Set-Content -LiteralPath (Join-Path $Path 'Tables/dim.DimDate.sql') -Encoding utf8NoBOM
        'CREATE TABLE dim.DimCustomer (CustomerKey INT IDENTITY PRIMARY KEY, CustomerCode NVARCHAR(50) NOT NULL UNIQUE, CustomerName NVARCHAR(200) NOT NULL);' | Set-Content -LiteralPath (Join-Path $Path 'Tables/dim.DimCustomer.sql') -Encoding utf8NoBOM
        if ($Stack -eq 'warehouse-health-convention') {
            'CREATE TABLE dim.DimCurrency (CurrencyCode CHAR(3) NOT NULL PRIMARY KEY, CurrencyName NVARCHAR(100) NOT NULL);' | Set-Content -LiteralPath (Join-Path $Path 'Tables/dim.DimCurrency.sql') -Encoding utf8NoBOM
        }
        $currencyColumn = if ($Stack -eq 'warehouse-health-convention') { ', CurrencyCode CHAR(3) NOT NULL' } else { '' }
        "CREATE TABLE fact.FactInvoice (InvoiceKey BIGINT NOT NULL PRIMARY KEY, CustomerKey INT NOT NULL, InvoiceDateKey INT NOT NULL, NetAmount DECIMAL(18,2) NOT NULL, LoadRunId BIGINT NOT NULL$currencyColumn);" | Set-Content -LiteralPath (Join-Path $Path 'Tables/fact.FactInvoice.sql') -Encoding utf8NoBOM
        if ($Stack -eq 'warehouse-health-convention') {
            'CREATE VIEW rpt.vwInvoiceCurrency AS SELECT f.InvoiceKey, c.CurrencyName FROM fact.FactInvoice f JOIN dim.DimCurrency c ON c.CurrencyCode = f.CurrencyCode;' |
                Set-Content -LiteralPath (Join-Path $Path 'Views/rpt.vwInvoiceCurrency.sql') -Encoding utf8NoBOM
        }
        @'
CREATE PROCEDURE dbo.usp_LoadFactInvoice AS
MERGE fact.FactInvoice AS target
USING stg.StgInvoice AS source ON source.InvoiceId = target.InvoiceKey
WHEN NOT MATCHED THEN INSERT (InvoiceKey, CustomerKey, InvoiceDateKey, NetAmount, LoadRunId)
VALUES (source.InvoiceId, source.CustomerKey, source.InvoiceDateKey, source.NetAmount, source.LoadRunId);
'@ | Set-Content -LiteralPath (Join-Path $Path 'StoredProcedures/usp_LoadFactInvoice.sql') -Encoding utf8NoBOM
        if ($Stack -eq 'warehouse-health-convention') {
            $invoiceLoadPath = Join-Path $Path 'StoredProcedures/usp_LoadFactInvoice.sql'
            $invoiceLoad = Get-Content -Raw -LiteralPath $invoiceLoadPath
            $invoiceLoad = $invoiceLoad.Replace('NetAmount, LoadRunId)', 'NetAmount, LoadRunId, CurrencyCode)')
            $invoiceLoad = $invoiceLoad.Replace('source.NetAmount, source.LoadRunId);', "source.NetAmount, source.LoadRunId, 'GBP');")
            $invoiceLoad | Set-Content -LiteralPath $invoiceLoadPath -Encoding utf8NoBOM
        }
        'CREATE VIEW rpt.vwInvoiceRevenue AS SELECT CustomerKey, SUM(NetAmount) Revenue FROM fact.FactInvoice GROUP BY CustomerKey;' | Set-Content -LiteralPath (Join-Path $Path 'Views/rpt.vwInvoiceRevenue.sql') -Encoding utf8NoBOM
        git -C $Path init --quiet
        git -C $Path config user.email 'agent-evals@invalid.local'
        git -C $Path config user.name 'Agent Evals'
        git -C $Path add -A
        git -C $Path commit --quiet -m "$Stack baseline"
        return
    }
    if ($Stack -eq 'warehouse-health-bridge-ok') {
        New-EvalRepo $Path warehouse-health-b
        $salesPath = Join-Path $Path 'Tables/fact.FactSales.sql'
        (Get-Content -Raw -LiteralPath $salesPath).Replace("    CampaignKey INT NULL,`n", '') |
            Set-Content -LiteralPath $salesPath -Encoding utf8NoBOM
        @'
CREATE TABLE bridge.FactSalesCampaign (
    SalesKey BIGINT NOT NULL,
    CampaignKey INT NOT NULL,
    AllocationPercent DECIMAL(5,2) NOT NULL,
    CONSTRAINT PK_FactSalesCampaign PRIMARY KEY (SalesKey, CampaignKey)
);
'@ | Set-Content -LiteralPath (Join-Path $Path 'Tables/bridge.FactSalesCampaign.sql') -Encoding utf8NoBOM
        git -C $Path add -A
        git -C $Path commit --quiet -m 'allocation owner evidence'
        return
    }
    if ($Stack -in @('warehouse-health-a','warehouse-health-b')) {
        # Derive isolated health fixtures from the frozen warehouse fixture without changing that
        # fixture's bytes or its historical B-98 comparability. Added artifacts use domain names;
        # none names the defect or finding the grader will test.
        New-EvalRepo $Path warehouse
        if ($Stack -eq 'warehouse-health-a') {
            @'
CREATE TABLE fact.FactAccountActivity (
    ActivityKey BIGINT NOT NULL PRIMARY KEY,
    RecordKind NVARCHAR(20) NOT NULL,
    CustomerId NVARCHAR(50) NOT NULL,
    PostedDateKey INT NOT NULL,
    SettledDateKey INT NULL,
    TransactionAmount DECIMAL(18,2) NULL,
    EndOfDayBalance DECIMAL(18,2) NULL,
    LoadRunId BIGINT NOT NULL
);
'@ | Set-Content -LiteralPath (Join-Path $Path 'Tables/fact.FactAccountActivity.sql') -Encoding utf8NoBOM
            @'
CREATE PROCEDURE dbo.usp_LoadFactAccountActivity AS
INSERT INTO fact.FactAccountActivity
    (ActivityKey, RecordKind, CustomerId, PostedDateKey, SettledDateKey, TransactionAmount, EndOfDayBalance, LoadRunId)
SELECT s.SalesId * 2, 'TRANSACTION', s.CustomerId, posted.DateKey, settled.DateKey, s.NetAmount,
       NULL, s.BatchId
FROM stg.StgSalesOrder s
JOIN dim.DimDate posted ON posted.CalendarDate = s.OrderDate
LEFT JOIN dim.DimDate settled ON settled.CalendarDate = DATEADD(day, 2, s.OrderDate)
UNION ALL
SELECT 1000000000 + ROW_NUMBER() OVER (ORDER BY d.CustomerId, d.OrderDate),
       'DAILY_POSITION', d.CustomerId, posted.DateKey, NULL, NULL,
       SUM(d.DailyMovement) OVER (PARTITION BY d.CustomerId ORDER BY d.OrderDate), d.BatchId
FROM (
    SELECT CustomerId, OrderDate, MAX(BatchId) AS BatchId, SUM(NetAmount) AS DailyMovement
    FROM stg.StgSalesOrder GROUP BY CustomerId, OrderDate
) d
JOIN dim.DimDate posted ON posted.CalendarDate = d.OrderDate;
'@ | Set-Content -LiteralPath (Join-Path $Path 'StoredProcedures/usp_LoadFactAccountActivity.sql') -Encoding utf8NoBOM
            @'
CREATE VIEW rpt.vwDailyAccountPosition AS
SELECT CustomerId, SUM(EndOfDayBalance) AS SumOfDailyBalances
FROM fact.FactAccountActivity
WHERE RecordKind = 'DAILY_POSITION'
GROUP BY CustomerId;
'@ | Set-Content -LiteralPath (Join-Path $Path 'Views/rpt.vwDailyAccountPosition.sql') -Encoding utf8NoBOM
            @'
CREATE VIEW rpt.vwAccountCustomer AS
SELECT a.ActivityKey, c.CustomerName
FROM fact.FactAccountActivity a
JOIN dim.DimCustomer c ON c.CustomerId = a.CustomerId;
'@ | Set-Content -LiteralPath (Join-Path $Path 'Views/rpt.vwAccountCustomer.sql') -Encoding utf8NoBOM
        } else {
            @'
CREATE TABLE sales.DimParty (
    PartyKey INT NOT NULL PRIMARY KEY,
    PartyCode NVARCHAR(50) NOT NULL,
    PartyName NVARCHAR(200) NOT NULL
);
'@ | Set-Content -LiteralPath (Join-Path $Path 'Tables/sales.DimParty.sql') -Encoding utf8NoBOM
            @'
CREATE TABLE service.DimParty (
    PartyContactKey INT NOT NULL PRIMARY KEY,
    PartyCode NVARCHAR(50) NOT NULL,
    ContactType NVARCHAR(50) NOT NULL,
    ContactValue NVARCHAR(200) NOT NULL
);
'@ | Set-Content -LiteralPath (Join-Path $Path 'Tables/service.DimParty.sql') -Encoding utf8NoBOM
            $salesPath = Join-Path $Path 'Tables/fact.FactSales.sql'
            $salesText = Get-Content -Raw -LiteralPath $salesPath
            $salesText = $salesText.Replace('    ProductKey INT NOT NULL,', "    ProductKey INT NOT NULL,`n    CampaignKey INT NULL,")
            $salesText | Set-Content -LiteralPath $salesPath -Encoding utf8NoBOM
            @'
CREATE TABLE dim.DimStatus (
    StatusKey INT NOT NULL PRIMARY KEY,
    StatusCode NVARCHAR(20) NOT NULL,
    StatusName NVARCHAR(100) NOT NULL
);
INSERT INTO dim.DimStatus VALUES (-1, 'UNK', 'Unknown');
INSERT INTO dim.DimStatus VALUES (0, 'NA', 'Unknown');
'@ | Set-Content -LiteralPath (Join-Path $Path 'Tables/dim.DimStatus.sql') -Encoding utf8NoBOM
            @'
CREATE TABLE fact.FactReturn (
    ReturnKey BIGINT NOT NULL PRIMARY KEY,
    CustomerKey INT NOT NULL,
    ReturnAmount DECIMAL(18,2) NOT NULL
);
'@ | Set-Content -LiteralPath (Join-Path $Path 'Tables/fact.FactReturn.sql') -Encoding utf8NoBOM
            @'
CREATE VIEW rpt.vwCustomerCommercialSummary AS
SELECT c.CustomerKey, SUM(s.NetAmount) AS Revenue, SUM(r.ReturnAmount) AS Returns
FROM dim.DimCustomer c
JOIN fact.FactSales s ON s.CustomerKey = c.CustomerKey
JOIN fact.FactReturn r ON r.CustomerKey = c.CustomerKey
GROUP BY c.CustomerKey;
'@ | Set-Content -LiteralPath (Join-Path $Path 'Views/rpt.vwCustomerCommercialSummary.sql') -Encoding utf8NoBOM
            New-Item -ItemType Directory -Path (Join-Path $Path 'docs') -Force | Out-Null
            @'
# Warehouse business rules

- A sale may receive credit from more than one campaign.
- Campaign credit percentages for one sale total 100 percent.
- `PartyCode` identifies the same governed party across sales and service data.
- Status code `UNK` means the source did not provide a value; `NA` means the status does not apply.
'@ | Set-Content -LiteralPath (Join-Path $Path 'docs/warehouse-rules.md') -Encoding utf8NoBOM
        }
        $leakPatterns = @('mixed[ -]?grain','natural[ -]?key on fact','missing bridge','non-?conform','role-playing gap','incorrect additivity','fan trap','chasm trap','ambiguous special member')
        foreach ($fixtureFile in Get-ChildItem -LiteralPath $Path -Recurse -File | Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' -and $_.Extension -in @('.sql','.md','.json','.sqlproj') }) {
            $fixtureText = Get-Content -Raw -LiteralPath $fixtureFile.FullName -ErrorAction SilentlyContinue
            foreach ($leakPattern in $leakPatterns) {
                if ($fixtureText -match $leakPattern) { throw "warehouse health fixture leaks measured conclusion '$leakPattern' in $($fixtureFile.FullName)" }
            }
        }
        git -C $Path add -A
        git -C $Path commit --quiet -m "$Stack evidence"
        return
    }
    if ($Stack -eq 'warehouse-fact-binding') {
        New-Item -ItemType Directory -Path (Join-Path $Path 'Tables'), (Join-Path $Path 'StoredProcedures'), (Join-Path $Path 'Views'), (Join-Path $Path 'docs') -Force | Out-Null
        '<Project Sdk="Microsoft.Build.Sql/0.2.0" />' | Set-Content -LiteralPath (Join-Path $Path 'warehouse.sqlproj') -Encoding utf8NoBOM
        @'
CREATE TABLE fact.FactOrderLine (
    OrderLineKey BIGINT NOT NULL PRIMARY KEY,
    OrderNumber NVARCHAR(40) NOT NULL,
    LineNumber INT NOT NULL,
    ProductKey INT NOT NULL,
    OrderDateKey INT NOT NULL,
    Quantity INT NOT NULL,
    NetAmount DECIMAL(18,2) NOT NULL,
    LoadRunId BIGINT NOT NULL
);
'@ | Set-Content -LiteralPath (Join-Path $Path 'Tables/fact.FactOrderLine.sql') -Encoding utf8NoBOM
        @'
CREATE TABLE fact.FactOrderPipeline (
    OrderKey BIGINT NOT NULL PRIMARY KEY,
    OrderNumber NVARCHAR(40) NOT NULL,
    OrderedDateKey INT NOT NULL,
    ShippedDateKey INT NULL,
    DeliveredDateKey INT NULL,
    LoadRunId BIGINT NOT NULL
);
'@ | Set-Content -LiteralPath (Join-Path $Path 'Tables/fact.FactOrderPipeline.sql') -Encoding utf8NoBOM
        @'
CREATE TABLE stg.StgOrderLine (OrderLineId BIGINT NOT NULL, OrderNumber NVARCHAR(40) NOT NULL,
LineNumber INT NOT NULL, ProductId NVARCHAR(50) NOT NULL, OrderDate DATE NOT NULL,
Quantity INT NOT NULL, NetAmount DECIMAL(18,2) NOT NULL,
BatchId BIGINT NOT NULL);
'@ | Set-Content -LiteralPath (Join-Path $Path 'Tables/stg.StgOrderLine.sql') -Encoding utf8NoBOM
        @'
CREATE TABLE stg.StgDailyInventory (ProductId NVARCHAR(50) NOT NULL, SnapshotDate DATE NOT NULL,
ClosingOnHandQuantity DECIMAL(18,2) NOT NULL, BatchId BIGINT NOT NULL);
'@ | Set-Content -LiteralPath (Join-Path $Path 'Tables/stg.StgDailyInventory.sql') -Encoding utf8NoBOM
        'CREATE TABLE dim.DimProduct (ProductKey INT NOT NULL PRIMARY KEY, ProductId NVARCHAR(50) NOT NULL);' | Set-Content -LiteralPath (Join-Path $Path 'Tables/dim.DimProduct.sql') -Encoding utf8NoBOM
        'CREATE TABLE dim.DimDate (DateKey INT NOT NULL PRIMARY KEY, CalendarDate DATE NOT NULL);' | Set-Content -LiteralPath (Join-Path $Path 'Tables/dim.DimDate.sql') -Encoding utf8NoBOM
        @'
CREATE PROCEDURE dbo.usp_LoadFactOrderLine AS
INSERT INTO fact.FactOrderLine (OrderLineKey, OrderNumber, LineNumber, ProductKey, OrderDateKey, Quantity, NetAmount, LoadRunId)
SELECT s.OrderLineId, s.OrderNumber, s.LineNumber, p.ProductKey, d.DateKey, s.Quantity, s.NetAmount, s.BatchId
FROM stg.StgOrderLine s JOIN dim.DimProduct p ON p.ProductId=s.ProductId
JOIN dim.DimDate d ON d.CalendarDate=s.OrderDate;
'@ | Set-Content -LiteralPath (Join-Path $Path 'StoredProcedures/usp_LoadFactOrderLine.sql') -Encoding utf8NoBOM
        'CREATE PROCEDURE dbo.usp_LoadFactOrderPipeline AS UPDATE fact.FactOrderPipeline SET ShippedDateKey=ShippedDateKey;' | Set-Content -LiteralPath (Join-Path $Path 'StoredProcedures/usp_LoadFactOrderPipeline.sql') -Encoding utf8NoBOM
        'CREATE VIEW rpt.vwOrderSales AS SELECT OrderDateKey, ProductKey, SUM(NetAmount) NetAmount FROM fact.FactOrderLine GROUP BY OrderDateKey, ProductKey;' | Set-Content -LiteralPath (Join-Path $Path 'Views/rpt.vwOrderSales.sql') -Encoding utf8NoBOM
        @'
# Warehouse map

## Inventory

| entity | definition | load/consumer |
|---|---|---|
| fact.FactOrderLine | `Tables/fact.FactOrderLine.sql` | `usp_LoadFactOrderLine`; `rpt.vwOrderSales` |
| fact.FactOrderPipeline | `Tables/fact.FactOrderPipeline.sql` | `usp_LoadFactOrderPipeline` |
| stg.StgOrderLine | `Tables/stg.StgOrderLine.sql` | `usp_LoadFactOrderLine` |
| stg.StgDailyInventory | `Tables/stg.StgDailyInventory.sql` | no target load yet |

This inventory intentionally records locations, not modelling conclusions. Inspect the live DDL,
load procedures, and views to determine grain, authority, lifecycle, and compatibility.
'@ | Set-Content -LiteralPath (Join-Path $Path 'docs/warehouse-map.md') -Encoding utf8NoBOM
        git -C $Path init --quiet
        git -C $Path config user.email 'agent-evals@invalid.local'
        git -C $Path config user.name 'Agent Evals'
        git -C $Path add -A
        git -C $Path commit --quiet -m 'fact-binding fixture baseline'
        return
    }
    if ($Stack -in @('warehouse-schema-compatible','warehouse-schema-incompatible','warehouse-schema-incomplete')) {
        # B-126 Phase 0: derive all three worlds from B-124's frozen fact-binding fixture. The
        # compatible/incompatible pair differs in one fact only: the projection used by the same
        # repository-visible consumer. Everything else, including the prompt and closed-world
        # premise, is byte-identical across that pair.
        New-EvalRepo $Path warehouse-fact-binding
        New-Item -ItemType Directory -Path (Join-Path $Path 'Tables/export') -Force | Out-Null
        @'
CREATE TABLE export.ProductExtract (
    ProductKey INT NOT NULL,
    ProductId NVARCHAR(50) NOT NULL
);
'@ | Set-Content -LiteralPath (Join-Path $Path 'Tables/export.ProductExtract.sql') -Encoding utf8NoBOM
        $projection = if ($Stack -eq 'warehouse-schema-incompatible') { '*' } else { 'ProductKey, ProductId' }
        @"
CREATE PROCEDURE dbo.usp_RefreshProductExtract AS
TRUNCATE TABLE export.ProductExtract;
INSERT INTO export.ProductExtract (ProductKey, ProductId)
SELECT $projection FROM dim.DimProduct;
"@ | Set-Content -LiteralPath (Join-Path $Path 'StoredProcedures/usp_RefreshProductExtract.sql') -Encoding utf8NoBOM
        @'
# Schema-evolution evidence boundary

Repository evidence is not by itself a closed-world attestation. Deployment approval requires one
of these accepted sources to state that the named repository scan covers all consumers and
operational constraints for this change: an in-session developer statement; an explicit
`AGENTS.md` > Conventions line; or a named owner sign-off. Without one, report only repository-visible
compatibility and abstain from deployment approval.
'@ | Set-Content -LiteralPath (Join-Path $Path 'docs/schema-evolution-premise.md') -Encoding utf8NoBOM
        if ($Stack -ne 'warehouse-schema-incomplete') {
            @'
# Product dimension consumer closure

Mara Voss, Warehouse Platform Owner, signs off that this repository contains every consumer and
operational constraint affected by adding `ProductColor` to `dim.DimProduct` for this deployment.
'@ | Set-Content -LiteralPath (Join-Path $Path 'docs/product-consumer-closure.md') -Encoding utf8NoBOM
        }
        git -C $Path add -A
        git -C $Path commit --quiet -m 'schema-evolution evidence'
        return
    }
    if ($Stack -like 'warehouse-trace-*') {
        if ($Stack -eq 'warehouse-trace-decoy') {
            # WSD-040 revision (d): preserve the exact field-report #3 trap from the existing
            # warehouse fixture. FactSales.SegmentName is declared but Test-DeadFactColumnWrite
            # proves no load writes it; the reporting view follows CustomerKey to DimCustomer.
            New-EvalRepo $Path warehouse
            @'
CREATE VIEW rpt.vwCustomerRevenue AS
SELECT c.SegmentName, SUM(f.NetAmount) AS Revenue
FROM fact.FactSales f JOIN dim.DimCustomer c ON c.CustomerKey=f.CustomerKey
GROUP BY c.SegmentName;
'@ | Set-Content -LiteralPath (Join-Path $Path 'Views/rpt.vwCustomerRevenue.sql') -Encoding utf8NoBOM
            $loadSql = Get-Content -Raw -LiteralPath (Join-Path $Path 'StoredProcedures/usp_LoadFactSales.sql')
            if (Test-DeadFactColumnWrite $loadSql) { throw 'trace decoy fixture unexpectedly populates a dead fact column' }
            git -C $Path add -A
            git -C $Path commit --quiet -m 'trace decoy evidence'
            return
        }
        New-EvalRepo $Path warehouse-fact-binding
        if ($Stack -in @('warehouse-trace-keyres-pinned','warehouse-trace-keyres-deferred','warehouse-trace-conflict')) {
            @'
CREATE TABLE dim.DimCarrier (CarrierKey INT NOT NULL PRIMARY KEY, CarrierCode NVARCHAR(20) NOT NULL,
CarrierDurableKey INT NOT NULL, CarrierTier NVARCHAR(30) NOT NULL, EffectiveFrom DATE NOT NULL,
EffectiveTo DATE NOT NULL, IsCurrent BIT NOT NULL);
'@ | Set-Content -LiteralPath (Join-Path $Path 'Tables/dim.DimCarrier.sql') -Encoding utf8NoBOM
            $keyColumn = if ($Stack -eq 'warehouse-trace-keyres-pinned') { 'CarrierKey INT NOT NULL' } elseif ($Stack -eq 'warehouse-trace-conflict') { 'CarrierKey INT NOT NULL, CarrierDurableKey INT NOT NULL' } else { 'CarrierDurableKey INT NOT NULL' }
            "CREATE TABLE fact.FactShipment (ShipmentKey BIGINT NOT NULL PRIMARY KEY, ShipmentDate DATE NOT NULL, $keyColumn, FreightAmount DECIMAL(18,2) NOT NULL);" |
                Set-Content -LiteralPath (Join-Path $Path 'Tables/fact.FactShipment.sql') -Encoding utf8NoBOM
            if ($Stack -in @('warehouse-trace-keyres-pinned','warehouse-trace-conflict')) {
                @'
CREATE PROCEDURE dbo.usp_LoadFactShipment AS
INSERT fact.FactShipment (ShipmentKey, ShipmentDate, CarrierKey, FreightAmount)
SELECT s.ShipmentId, s.ShipmentDate, c.CarrierKey, s.FreightAmount
FROM stg.StgShipment s JOIN dim.DimCarrier c ON c.CarrierCode=s.CarrierCode
 AND s.ShipmentDate >= c.EffectiveFrom AND s.ShipmentDate < c.EffectiveTo;
'@ | Set-Content -LiteralPath (Join-Path $Path 'StoredProcedures/usp_LoadFactShipment.sql') -Encoding utf8NoBOM
                if ($Stack -eq 'warehouse-trace-conflict') {
                    @'
CREATE PROCEDURE dbo.usp_LoadFactShipment AS
INSERT fact.FactShipment (ShipmentKey, ShipmentDate, CarrierKey, CarrierDurableKey, FreightAmount)
SELECT s.ShipmentId, s.ShipmentDate, c.CarrierKey, c.CarrierDurableKey, s.FreightAmount
FROM stg.StgShipment s JOIN dim.DimCarrier c ON c.CarrierCode=s.CarrierCode
 AND s.ShipmentDate >= c.EffectiveFrom AND s.ShipmentDate < c.EffectiveTo;
'@ | Set-Content -LiteralPath (Join-Path $Path 'StoredProcedures/usp_LoadFactShipment.sql') -Encoding utf8NoBOM
                }
                'CREATE VIEW rpt.vwShipment AS SELECT f.ShipmentDate,c.CarrierTier,f.FreightAmount FROM fact.FactShipment f JOIN dim.DimCarrier c ON c.CarrierKey=f.CarrierKey;' |
                    Set-Content -LiteralPath (Join-Path $Path 'Views/rpt.vwShipment.sql') -Encoding utf8NoBOM
            } else {
                @'
CREATE PROCEDURE dbo.usp_LoadFactShipment AS
INSERT fact.FactShipment (ShipmentKey, ShipmentDate, CarrierDurableKey, FreightAmount)
SELECT s.ShipmentId, s.ShipmentDate, c.CarrierDurableKey, s.FreightAmount
FROM stg.StgShipment s JOIN dim.DimCarrier c ON c.CarrierCode=s.CarrierCode AND c.IsCurrent=1;
'@ | Set-Content -LiteralPath (Join-Path $Path 'StoredProcedures/usp_LoadFactShipment.sql') -Encoding utf8NoBOM
                'CREATE VIEW rpt.vwShipment AS SELECT f.ShipmentDate,c.CarrierTier,f.FreightAmount FROM fact.FactShipment f JOIN dim.DimCarrier c ON c.CarrierDurableKey=f.CarrierDurableKey AND f.ShipmentDate>=c.EffectiveFrom AND f.ShipmentDate<c.EffectiveTo;' |
                    Set-Content -LiteralPath (Join-Path $Path 'Views/rpt.vwShipment.sql') -Encoding utf8NoBOM
            }
            if ($Stack -eq 'warehouse-trace-conflict') {
                'CREATE VIEW rpt.vwShipmentCurrentCarrier AS SELECT f.ShipmentDate,c.CarrierTier FROM fact.FactShipment f JOIN dim.DimCarrier c ON c.CarrierDurableKey=f.CarrierDurableKey AND c.IsCurrent=1;' |
                    Set-Content -LiteralPath (Join-Path $Path 'Views/rpt.vwShipmentCurrentCarrier.sql') -Encoding utf8NoBOM
            }
        } elseif ($Stack -in @('warehouse-trace-attribute-a','warehouse-trace-attribute-b')) {
            'CREATE TABLE stg.StgOrderRevenue (OrderId BIGINT NOT NULL, RevenueAmount DECIMAL(18,2) NULL, CurrencyCode CHAR(3) NOT NULL, RevenueDate DATE NOT NULL);' |
                Set-Content -LiteralPath (Join-Path $Path 'Tables/stg.StgOrderRevenue.sql') -Encoding utf8NoBOM
            'CREATE TABLE fact.FactOrderRevenue (OrderId BIGINT NOT NULL PRIMARY KEY, RevenueGbp DECIMAL(18,2) NOT NULL);' |
                Set-Content -LiteralPath (Join-Path $Path 'Tables/fact.FactOrderRevenue.sql') -Encoding utf8NoBOM
            if ($Stack -eq 'warehouse-trace-attribute-a') {
                'CREATE TABLE ref.DailyFxRate (CurrencyCode CHAR(3) NOT NULL, RateDate DATE NOT NULL, GbpRate DECIMAL(18,8) NOT NULL);' |
                    Set-Content -LiteralPath (Join-Path $Path 'Tables/ref.DailyFxRate.sql') -Encoding utf8NoBOM
                'CREATE PROCEDURE dbo.usp_LoadOrderRevenue AS INSERT fact.FactOrderRevenue SELECT s.OrderId, s.RevenueAmount*x.GbpRate FROM stg.StgOrderRevenue s JOIN ref.DailyFxRate x ON x.CurrencyCode=s.CurrencyCode AND x.RateDate=s.RevenueDate;' |
                    Set-Content -LiteralPath (Join-Path $Path 'StoredProcedures/usp_LoadOrderRevenue.sql') -Encoding utf8NoBOM
            } else {
                'CREATE PROCEDURE dbo.usp_LoadOrderRevenue AS INSERT fact.FactOrderRevenue SELECT s.OrderId, COALESCE(s.RevenueAmount,0) FROM stg.StgOrderRevenue s;' |
                    Set-Content -LiteralPath (Join-Path $Path 'StoredProcedures/usp_LoadOrderRevenue.sql') -Encoding utf8NoBOM
            }
            'CREATE VIEW rpt.vwOrderRevenue AS SELECT OrderId, RevenueGbp FROM fact.FactOrderRevenue;' |
                Set-Content -LiteralPath (Join-Path $Path 'Views/rpt.vwOrderRevenue.sql') -Encoding utf8NoBOM
        } else {
            if ($Stack -eq 'warehouse-trace-metric-ratio') {
                'CREATE VIEW rpt.vwSalesMetric AS SELECT OrderDateKey, SUM(NetAmount)/NULLIF(COUNT(DISTINCT OrderNumber),0) AS AverageOrderValue FROM fact.FactOrderLine GROUP BY OrderDateKey;' |
                    Set-Content -LiteralPath (Join-Path $Path 'Views/rpt.vwSalesMetric.sql') -Encoding utf8NoBOM
            } else {
                'CREATE VIEW rpt.vwSalesMetric AS SELECT OrderDateKey, SUM(NetAmount) AS AverageOrderValue FROM fact.FactOrderLine GROUP BY OrderDateKey;' |
                    Set-Content -LiteralPath (Join-Path $Path 'Views/rpt.vwSalesMetric.sql') -Encoding utf8NoBOM
            }
        }
        git -C $Path add -A
        git -C $Path commit --quiet -m "$Stack evidence"
        return
    }
    if ($Stack -eq 'warehouse-partition-mismatch') {
        # Derive this probe from B-124's frozen fact-binding stack. The added evidence describes
        # the new fact's operational shape without naming the design conclusion being measured.
        New-EvalRepo $Path warehouse-fact-binding
        @'
CREATE PARTITION FUNCTION pf_OrderDateMonth (INT)
AS RANGE RIGHT FOR VALUES (20260101, 20260201, 20260301, 20260401);

CREATE PARTITION SCHEME ps_OrderDateMonth
AS PARTITION pf_OrderDateMonth ALL TO ([PRIMARY]);
'@ | Set-Content -LiteralPath (Join-Path $Path 'Tables/partition.OrderDateMonth.sql') -Encoding utf8NoBOM
        $orderLinePath = Join-Path $Path 'Tables/fact.FactOrderLine.sql'
        $orderLine = Get-Content -Raw -LiteralPath $orderLinePath
        $orderLine = [regex]::Replace($orderLine, '    LoadRunId BIGINT NOT NULL\r?\n\);', "    LoadRunId BIGINT NOT NULL`n) ON ps_OrderDateMonth(OrderDateKey);")
        if ($orderLine -notmatch '(?i)ON\s+ps_OrderDateMonth\s*\(\s*OrderDateKey\s*\)') { throw 'partition mismatch fixture failed to partition FactOrderLine' }
        $orderLine | Set-Content -LiteralPath $orderLinePath -Encoding utf8NoBOM
        @'
CREATE TABLE stg.StgFraudAlert (
    AlertId BIGINT NOT NULL,
    DetectedAt DATETIME2 NOT NULL,
    OrderNumber NVARCHAR(40) NOT NULL,
    AlertStatus NVARCHAR(20) NOT NULL,
    RiskAmount DECIMAL(18,2) NOT NULL,
    SourceUpdatedAt DATETIME2 NOT NULL
);
'@ | Set-Content -LiteralPath (Join-Path $Path 'Tables/stg.StgFraudAlert.sql') -Encoding utf8NoBOM
        @'
# Fraud alert repository contract

`stg.StgFraudAlert` is the authoritative source for the new fraud-alert transaction fact. One row
represents one `AlertId`. The source sends continuous micro-batches throughout the day and may
correct `DetectedAt`, status, or amount for any previously issued alert.

The investigation service retrieves one alert by `AlertId` and must search the complete retained
history; its requests do not carry a detected-date range. The warehouse load reconciles each batch
to the target by `AlertId` and `SourceUpdatedAt`. Finance also aggregates risk by detected month,
but that scheduled summary is not the investigation service's access path.
'@ | Set-Content -LiteralPath (Join-Path $Path 'docs/fraud-alert-contract.md') -Encoding utf8NoBOM
        git -C $Path add -A
        git -C $Path commit --quiet -m 'partition mismatch probe evidence'
        return
    }
    if ($Stack -in @('warehouse','warehouse-mixed')) {
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
        if ($Stack -eq 'warehouse-mixed') {
            # A minimal but GENUINE .NET side. Its purpose is to make `add-entity` a live competitor
            # for a load-shaped prompt: the pure-SQL fixture has no EF Core at all, so it is
            # structurally incapable of observing an OLTP-vs-warehouse mis-route, which is the
            # failure mode that matters in the target repos (all of which are .NET + SQL). The
            # entities are deliberately ADJACENT to the warehouse feed (Supplier, PurchaseOrder) --
            # a neutral domain would not tempt the wrong skill and would measure nothing.
            New-Item -ItemType Directory -Path (Join-Path $Path 'src/SupplierPortal.Api/Data/Entities'), (Join-Path $Path 'src/SupplierPortal.Api/Data/Configurations'), (Join-Path $Path 'src/SupplierPortal.Api/Migrations') -Force | Out-Null
            @'
Microsoft Visual Studio Solution File, Format Version 12.00
Project("{9A19103F-16F7-4668-BE54-9A1E7A4F7556}") = "SupplierPortal.Api", "src\SupplierPortal.Api\SupplierPortal.Api.csproj", "{4E3B9A21-0C7D-4C22-9E2B-8C1D5F6A7B31}"
EndProject
'@ | Set-Content -LiteralPath (Join-Path $Path 'SupplierPortal.sln') -Encoding utf8NoBOM
            @'
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net9.0</TargetFramework>
    <Nullable>enable</Nullable>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.EntityFrameworkCore.SqlServer" Version="9.0.0" />
  </ItemGroup>
</Project>
'@ | Set-Content -LiteralPath (Join-Path $Path 'src/SupplierPortal.Api/SupplierPortal.Api.csproj') -Encoding utf8NoBOM
            @'
namespace SupplierPortal.Api.Data.Entities;

public class Supplier
{
    public int Id { get; set; }
    public string SupplierCode { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
}
'@ | Set-Content -LiteralPath (Join-Path $Path 'src/SupplierPortal.Api/Data/Entities/Supplier.cs') -Encoding utf8NoBOM
            @'
namespace SupplierPortal.Api.Data.Entities;

public class PurchaseOrder
{
    public int Id { get; set; }
    public string OrderNumber { get; set; } = string.Empty;
    public int SupplierId { get; set; }
    public Supplier? Supplier { get; set; }
    public decimal NetAmount { get; set; }
}
'@ | Set-Content -LiteralPath (Join-Path $Path 'src/SupplierPortal.Api/Data/Entities/PurchaseOrder.cs') -Encoding utf8NoBOM
            @'
using Microsoft.EntityFrameworkCore;
using SupplierPortal.Api.Data.Entities;

namespace SupplierPortal.Api.Data;

public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<Supplier> Suppliers => Set<Supplier>();
    public DbSet<PurchaseOrder> PurchaseOrders => Set<PurchaseOrder>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
        => modelBuilder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);
}
'@ | Set-Content -LiteralPath (Join-Path $Path 'src/SupplierPortal.Api/Data/AppDbContext.cs') -Encoding utf8NoBOM
            @'
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SupplierPortal.Api.Data.Entities;

namespace SupplierPortal.Api.Data.Configurations;

public class SupplierConfiguration : IEntityTypeConfiguration<Supplier>
{
    public void Configure(EntityTypeBuilder<Supplier> builder)
    {
        builder.ToTable("Suppliers");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.SupplierCode).HasMaxLength(50).IsRequired();
        builder.HasIndex(x => x.SupplierCode).IsUnique();
    }
}
'@ | Set-Content -LiteralPath (Join-Path $Path 'src/SupplierPortal.Api/Data/Configurations/SupplierConfiguration.cs') -Encoding utf8NoBOM
            @'
using Microsoft.EntityFrameworkCore.Migrations;

namespace SupplierPortal.Api.Migrations;

public partial class InitialCreate : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
        => migrationBuilder.CreateTable(
            name: "Suppliers",
            columns: table => new
            {
                Id = table.Column<int>(nullable: false).Annotation("SqlServer:Identity", "1, 1"),
                SupplierCode = table.Column<string>(maxLength: 50, nullable: false),
                Name = table.Column<string>(nullable: false)
            },
            constraints: table => table.PrimaryKey("PK_Suppliers", x => x.Id));

    protected override void Down(MigrationBuilder migrationBuilder)
        => migrationBuilder.DropTable(name: "Suppliers");
}
'@ | Set-Content -LiteralPath (Join-Path $Path 'src/SupplierPortal.Api/Migrations/20260101000000_InitialCreate.cs') -Encoding utf8NoBOM
        }
        git -C $Path init --quiet
        git -C $Path config user.email 'agent-evals@invalid.local'
        git -C $Path config user.name 'Agent Evals'
        git -C $Path add -A
        git -C $Path commit --quiet -m 'fixture baseline'
        return
    }
    if ($Stack -in @('angular', 'angular-ux')) {
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
        # B-470: angular-ux is the tree above plus one sibling flow, the orders list, whose loading, empty, error and success
        # handling a new page can mirror. The angular tree itself is unchanged, so angular-feature-placement's fixture is too.
        if ($Stack -eq 'angular-ux') {
            $packagePath = Join-Path $Path 'package.json'
            (Get-Content -Raw -LiteralPath $packagePath).Replace('"@angular/platform-browser": "^19.0.0"', "`"@angular/platform-browser`": `"^19.0.0`",`n    `"rxjs`": `"~7.8.0`"") | Set-Content -LiteralPath $packagePath -Encoding utf8NoBOM -NoNewline
            New-Item -ItemType Directory -Path (Join-Path $Path 'src/app/orders') -Force | Out-Null
            @'
import { Component } from '@angular/core';
import { ProfileFormComponent } from './profile-form/profile-form.component';
import { OrderListComponent } from './orders/order-list.component';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [ProfileFormComponent, OrderListComponent],
  template: '<app-profile-form /><app-order-list />',
})
export class AppComponent {}
'@ | Set-Content -LiteralPath (Join-Path $Path 'src/app/app.component.ts') -Encoding utf8NoBOM
            @'
import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

export interface Order {
  id: string;
  placedOn: string;
  total: number;
}

@Injectable({ providedIn: 'root' })
export class OrderService {
  private readonly http = inject(HttpClient);

  getOrders(): Observable<Order[]> {
    return this.http.get<Order[]>('/api/orders');
  }
}
'@ | Set-Content -LiteralPath (Join-Path $Path 'src/app/orders/order.service.ts') -Encoding utf8NoBOM
            @'
import { Component, OnInit, inject, signal } from '@angular/core';
import { CurrencyPipe, DatePipe } from '@angular/common';
import { catchError, finalize, of } from 'rxjs';
import { Order, OrderService } from './order.service';

@Component({
  selector: 'app-order-list',
  standalone: true,
  imports: [CurrencyPipe, DatePipe],
  template: `
    <h2>Your orders</h2>
    @if (loading()) {
      <p class="state state--loading">Loading your orders...</p>
    } @else if (error()) {
      <p class="state state--error" role="alert">{{ error() }}</p>
    } @else if (orders().length === 0) {
      <p class="state state--empty">You have no orders yet.</p>
    } @else {
      <ul class="order-list">
        @for (order of orders(); track order.id) {
          <li>{{ order.placedOn | date }} - {{ order.total | currency }}</li>
        }
      </ul>
    }
  `,
})
export class OrderListComponent implements OnInit {
  private readonly orderService = inject(OrderService);

  readonly orders = signal<Order[]>([]);
  readonly loading = signal(true);
  readonly error = signal<string | null>(null);

  ngOnInit(): void {
    this.orderService
      .getOrders()
      .pipe(
        catchError(() => {
          this.error.set('Your orders could not be loaded. Please try again later.');
          return of<Order[]>([]);
        }),
        finalize(() => this.loading.set(false)),
      )
      .subscribe((orders) => this.orders.set(orders));
  }
}
'@ | Set-Content -LiteralPath (Join-Path $Path 'src/app/orders/order-list.component.ts') -Encoding utf8NoBOM
            @'
import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { OrderListComponent } from './order-list.component';

describe('OrderListComponent', () => {
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [OrderListComponent],
      providers: [provideHttpClient(), provideHttpClientTesting()],
    });
    http = TestBed.inject(HttpTestingController);
  });

  function render() {
    const fixture = TestBed.createComponent(OrderListComponent);
    fixture.detectChanges();
    return fixture;
  }

  it('shows the loading state until the orders arrive', () => {
    const fixture = render();
    expect(fixture.nativeElement.textContent).toContain('Loading your orders');
    http.expectOne('/api/orders').flush([]);
  });

  it('shows the empty state when there are no orders', () => {
    const fixture = render();
    http.expectOne('/api/orders').flush([]);
    fixture.detectChanges();
    expect(fixture.nativeElement.textContent).toContain('You have no orders yet.');
  });

  it('shows an inline error when the orders cannot be loaded', () => {
    const fixture = render();
    http.expectOne('/api/orders').flush('unavailable', { status: 500, statusText: 'Server Error' });
    fixture.detectChanges();
    expect(fixture.nativeElement.textContent).toContain('could not be loaded');
  });

  it('lists the orders on success', () => {
    const fixture = render();
    http.expectOne('/api/orders').flush([{ id: 'o-1', placedOn: '2026-10-01', total: 42 }]);
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelectorAll('li').length).toBe(1);
  });
});
'@ | Set-Content -LiteralPath (Join-Path $Path 'src/app/orders/order-list.component.spec.ts') -Encoding utf8NoBOM
        }
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
    # B-421: dotnet-notest is this fixture without its test script, the decoy where no test exists to find.
    if ($Stack -ne 'dotnet-notest') {
        @'
$source = Get-Content -Raw "$PSScriptRoot/../src/Calculator.cs"
if ($source -notmatch 'value <= max') { throw 'inclusive upper bound is broken' }
Write-Output 'PASS: inclusive range'
'@ | Set-Content -LiteralPath (Join-Path $Path 'tests/Test-Calculator.ps1') -Encoding utf8NoBOM
    }
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

function Get-TargetPatchPaths([string]$PatchPath) {
    # From the `diff --git` headers only: a removed hunk line such as `-- comment` also starts `---`.
    $paths = foreach ($line in [IO.File]::ReadAllLines($PatchPath)) {
        if ($line -match '^diff --git a/(.+) b/(.+)$') { $Matches[1]; $Matches[2] }
    }
    return @($paths | Sort-Object -Unique)
}

function Get-TreeHashes([string]$Root) {
    $hashes = @{}
    foreach ($file in Get-ChildItem -LiteralPath $Root -Recurse -File -Force) {
        $relative = [IO.Path]::GetRelativePath($Root, $file.FullName).Replace('\', '/')
        if ($relative -notlike '.git/*') { $hashes[$relative] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash }
    }
    return $hashes
}

function Invoke-TargetPatch([string]$Target, [string]$PatchPath) {
    # The patched arm may differ from the unpatched one by the patch's bytes only; anything else
    # would be measured as the patch's effect. Returns the tag every result line carries.
    $name = Split-Path -Leaf $PatchPath
    $named = @(Get-TargetPatchPaths $PatchPath)
    if (-not $named) { throw "-TargetPatch ${name}: no 'diff --git' header. Cut it with git diff --output (DEVELOPING.md, agent evals)." }
    $before = Get-TreeHashes $Target
    $shape = @{}
    foreach ($path in $named) {
        $full = Join-Path $Target $path
        if (Test-Path -LiteralPath $full) { $shape[$path] = @{ Bom = Assert-Bom $full; Cr = [Array]::IndexOf([IO.File]::ReadAllBytes($full), [byte]13) -ge 0 } }
    }
    # core.autocrlf=false: under the Git for Windows default (true) `git apply` rewrites every line
    # ending of a patched LF file, not only the lines the patch changes. `git apply` is all-or-nothing,
    # so a refused patch leaves the target untouched.
    $output = git -C $Target -c core.autocrlf=false apply $PatchPath 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "-TargetPatch $name does not apply to the installed target: $output" }
    $after = Get-TreeHashes $Target
    $stray = @(@($before.Keys) + @($after.Keys) | Sort-Object -Unique | Where-Object { $before[$_] -ne $after[$_] -and $_ -notin $named })
    if ($stray) { throw "-TargetPatch $name changed files it does not name: $($stray -join ', ')" }
    foreach ($path in $named) {
        $full = Join-Path $Target $path
        if (-not (Test-Path -LiteralPath $full)) { continue }
        if ($shape.ContainsKey($path)) {
            if ((Assert-Bom $full) -ne $shape[$path].Bom) { throw "-TargetPatch $name changed the UTF-8 BOM of $path" }
            if (-not $shape[$path].Cr -and [Array]::IndexOf([IO.File]::ReadAllBytes($full), [byte]13) -ge 0) { throw "-TargetPatch $name turned LF line endings in $path into CRLF" }
        }
        if ($path -like '*.json') {
            # Claude Code silently ignores a settings file that fails validation under -p.
            try { [Text.Json.JsonDocument]::Parse([IO.File]::ReadAllText($full)).Dispose() } catch { throw "-TargetPatch $name left $path as invalid JSON" }
        }
    }
    return Get-TargetPatchTag $PatchPath
}

function Get-TargetPatchTag([string]$PatchPath) {
    return "$(Split-Path -Leaf $PatchPath)@$((Get-FileHash -LiteralPath $PatchPath -Algorithm SHA256).Hash.ToLowerInvariant().Substring(0, 12))"
}

function Get-GeneratedFixtureRefusal([string]$ProvenancePath, [string]$DistVersion, [string]$Label = '-WarehouseMap generated') {
    if (-not (Test-Path -LiteralPath $ProvenancePath)) { return "${Label}: $ProvenancePath is missing. Generate the fixture first (DEVELOPING.md, agent evals)." }
    $generatedVersion = [string](Get-Content -Raw -LiteralPath $ProvenancePath | ConvertFrom-Json).frameworkVersion
    if ($generatedVersion -ne $DistVersion) { return "${Label}: the fixture was generated on v$generatedVersion but dist is v$DistVersion. Regenerate it." }
    return $null
}

# The live-eval version guard. The dist version must match the root CHANGELOG's head. When that head is
# `## X.Y.Z -- Unreleased` (the shape release.ps1's Get-ReleaseChangelogHead accepts) with X.Y.Z strictly above the dist
# version, the dist version is compared with the first RELEASED head below it instead, so a fix can be measured before
# release. Refused if that released head differs, if the Unreleased version is not above the dist version, or if there is
# no released head. RootHead names the Unreleased head so the results header can say rows are not a release's.
function Get-ChangelogGuardDecision([string]$ChangelogText, [string]$DistVersion) {
    $dash = [string][char]0x2014
    $heads = @($ChangelogText -split '\r?\n' | Where-Object { $_ -match '^## (\d+\.\d+\.\d+)' })
    $first = if ($heads) { [string]$heads[0] } else { '' }
    $firstVersion = ($first -replace '^## (\d+\.\d+\.\d+).*', '$1')
    $unreleased = [regex]::Match($first, "^## (\d+\.\d+\.\d+) $dash Unreleased$")
    if (-not $unreleased.Success) {
        if ($DistVersion -ne $firstVersion) { return [pscustomobject]@{ Allowed = $false; Message = "dist version $DistVersion does not match root CHANGELOG head ${firstVersion}."; RootHead = '' } }
        return [pscustomobject]@{ Allowed = $true; Message = $null; RootHead = '' }
    }
    $rootHead = "$($unreleased.Groups[1].Value) $dash Unreleased"
    if ([version]$unreleased.Groups[1].Value -le [version]$DistVersion) {
        return [pscustomobject]@{ Allowed = $false; Message = "root CHANGELOG head $rootHead is not above the dist version $DistVersion."; RootHead = $rootHead }
    }
    $released = @($heads | Select-Object -Skip 1 | Where-Object { $_ -match "^## (\d+\.\d+\.\d+) $dash \d{4}-\d{2}-\d{2}$" } | Select-Object -First 1)
    if (-not $released) { return [pscustomobject]@{ Allowed = $false; Message = "root CHANGELOG head $rootHead has no released head below it to compare with dist version $DistVersion."; RootHead = $rootHead } }
    $releasedVersion = ([string]$released[0] -replace '^## (\d+\.\d+\.\d+).*', '$1')
    if ($releasedVersion -ne $DistVersion) { return [pscustomobject]@{ Allowed = $false; Message = "dist version $DistVersion does not match the released head $releasedVersion under root CHANGELOG head $rootHead."; RootHead = $rootHead } }
    return [pscustomobject]@{ Allowed = $true; Message = $null; RootHead = $rootHead }
}

# B-406: the fixture v2 generator is the B-345 one, frozen. The overlay and every b406 result are bound to
# its bytes, so a changed generator is refused rather than silently measured as a new fixture.
function Get-B406GeneratorRefusal([string]$GeneratorPath, [string]$Fixture = 'b406-orders') {
    $frozen = '277d4d02951dbb4e494298d5d6acf703b1c64be0e4f3daa637ab3d6b4b23b688'
    if (-not (Test-Path -LiteralPath $GeneratorPath -PathType Leaf)) { return "${Fixture}: $GeneratorPath is missing." }
    $actual = (Get-FileHash -LiteralPath $GeneratorPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $frozen) { return "${Fixture}: $GeneratorPath is not the frozen fixture v2 generator (sha256 $actual, expected $frozen)." }
    return $null
}

# B-409: the CI workflow the b409-orders-ci baseline commit carries, so the repository itself evidences `dotnet build` and
# `dotnet test`. UTF-8, no BOM, LF, whatever the host's newline: the bytes are built here, not by a cmdlet.
function Write-B409CiWorkflow([string]$Path) {
    $lines = @(
        'name: ci',
        'on: [push, pull_request]',
        'jobs:',
        '  build-test:',
        '    runs-on: ubuntu-latest',
        '    steps:',
        '      - uses: actions/checkout@v4',
        '      - uses: actions/setup-dotnet@v4',
        '        with:',
        "          dotnet-version: '8.0.x'",
        '      - run: dotnet build Orders.sln',
        '      - run: dotnet test Orders.sln --no-build'
    )
    $directory = Join-Path $Path '.github/workflows'
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    [IO.File]::WriteAllBytes((Join-Path $directory 'ci.yml'), [Text.UTF8Encoding]::new($false).GetBytes(($lines -join "`n") + "`n"))
}

# B-406: what a real /bootstrap changed relative to a fresh install, laid over the install and committed, so
# the target looks like a repository that ran it. Valid only for the framework version it was generated on;
# -Live refuses a stale one before any run (Get-GeneratedFixtureRefusal), -SelfTest never reads it.
function Initialize-B406Overlay([string]$Path, [string]$Fixture, [string]$FixturesRoot = (Join-Path $repo 'meta/eval-fixtures')) {
    if ($Fixture -notin $contractFixtures) { throw "${Fixture}: has no bootstrap overlay; the contract fixtures are $($contractFixtures -join ', ')." }
    $overlayRoot = Join-Path $FixturesRoot "$Fixture/files"
    if (-not (Test-Path -LiteralPath $overlayRoot -PathType Container)) { throw "${Fixture}: $overlayRoot is missing. Generate the fixture first (DEVELOPING.md, agent evals)." }
    Copy-Item -Path (Join-Path $overlayRoot '*') -Destination $Path -Recurse -Force
    git -C $Path add -A
    git -C $Path commit --quiet -m "$($Fixture.Split('-')[0]) bootstrap overlay"
}

# B-470: a scenario's "overlay" names a frozen /bootstrap overlay under meta/eval-fixtures/, as the warehouse and contract
# overlays are, copied over the install and committed. Framework arm only: the bare arm installs nothing, so it gets none.
function Initialize-GeneratedOverlay([string]$Path, [string]$Overlay, [string]$FixturesRoot = (Join-Path $repo 'meta/eval-fixtures')) {
    $files = Join-Path $FixturesRoot "$Overlay/files"
    if (-not (Test-Path -LiteralPath $files -PathType Container)) { throw "${Overlay}: $files is missing. Generate the fixture first (DEVELOPING.md, agent evals)." }
    Copy-Item -Path (Join-Path $files '*') -Destination $Path -Recurse -Force
    git -C $Path add -A
    git -C $Path commit --quiet -m "$Overlay bootstrap overlay"
}

# B-470: does the page a run wrote mirror the sibling's loading, empty and error handling? Written files only; the report is
# not read. The page is every new or changed non-spec .ts/.html under src/ since the run started whose path names an invoice
# or whose text calls /api/invoices, plus the templateUrl files those name. A state counts only by the sibling's mechanism:
# a control-flow branch in the template keyed on it (for empty, an explicit emptiness test, @empty, or a length test with
# an else), and for the error also a catchError whose handler sets something error-shaped, never alert(). No page: ERROR.
function Get-AngularUxGrade([string]$Target, [int]$BeforeCommits) {
    $base = @(git -C $Target rev-list --reverse HEAD)[$BeforeCommits - 1]
    $changed = @(
        @(git -C $Target diff --name-only $base -- src)
        @(git -C $Target ls-files --others --exclude-standard -- src)
    ) | Where-Object { $_ -and $_ -match '\.(?:ts|html)$' -and $_ -notmatch '\.spec\.ts$' -and (Test-Path -LiteralPath (Join-Path $Target $_) -PathType Leaf) } | Select-Object -Unique
    $page = @{}
    foreach ($path in $changed) {
        $text = Get-Content -Raw -LiteralPath (Join-Path $Target $path)
        if ($path -match '(?i)invoice' -or $text -match '/api/invoices') { $page[$path] = $text }
    }
    foreach ($path in @($page.Keys | Where-Object { $_ -like '*.ts' })) {
        foreach ($m in [regex]::Matches($page[$path], 'templateUrl\s*:\s*[''"]([^''"]+)[''"]')) {
            $full = [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent (Join-Path $Target $path)) $m.Groups[1].Value))
            $relative = [IO.Path]::GetRelativePath($Target, $full).Replace('\', '/')
            if (-not $page.ContainsKey($relative) -and (Test-Path -LiteralPath $full -PathType Leaf)) { $page[$relative] = Get-Content -Raw -LiteralPath $full }
        }
    }
    [string[]]$pageFiles = @($page.Keys)
    [Array]::Sort($pageFiles, [StringComparer]::Ordinal)
    if ($pageFiles.Count -eq 0) { return [pscustomobject]@{ Grade = 'ERROR'; Detail = 'grade=ERROR no page written pageFiles=' } }
    $template = (@($pageFiles | ForEach-Object {
        if ($_ -like '*.html') { $page[$_] } else { [regex]::Matches($page[$_], '(?s)\btemplate\s*:\s*`(.*?)`') | ForEach-Object { $_.Groups[1].Value } }
    }) -join "`n")
    $code = (@($pageFiles | Where-Object { $_ -like '*.ts' } | ForEach-Object { $page[$_] }) -join "`n")
    # Each branch condition, and whether an @else follows its block (or the *ngIf names an else template).
    $branches = foreach ($m in [regex]::Matches($template, '(?:@(?:else\s+)?if|@case|@switch)\s*\(([^{]*)\)\s*\{|\*ngIf\s*=\s*"([^"]*)"')) {
        $condition = $m.Groups[1].Value + $m.Groups[2].Value
        $hasElse = $condition -match ';\s*else\s+\w+'
        if ($m.Groups[1].Success) {
            $depth = 1; $i = $m.Index + $m.Length
            while ($i -lt $template.Length -and $depth -gt 0) { if ($template[$i] -eq '{') { $depth++ } elseif ($template[$i] -eq '}') { $depth-- }; $i++ }
            $hasElse = $template.Substring($i) -match '^\s*@else\b'
        }
        [pscustomobject]@{ Condition = $condition; HasElse = $hasElse }
    }
    $branches = @($branches)
    $loading = [bool]@($branches | Where-Object { $_.Condition -match '(?i)loading' } | Select-Object -First 1)
    $explicitEmpty = '(?i)\.length\s*(?:===?\s*0|<\s*1|<=\s*0)\b|!\s*[\w$.()?\[\]]*\.length\b|empty'
    $empty = $template -match '@empty\b' -or [bool]@($branches | Where-Object { $_.Condition -match $explicitEmpty -or ($_.Condition -match '\.length\b' -and $_.HasElse) } | Select-Object -First 1)
    $errorBranch = [bool]@($branches | Where-Object { $_.Condition -match '(?i)error|fail' } | Select-Object -First 1)
    $catchErrorSets = $false
    foreach ($m in [regex]::Matches($code, '\bcatchError\s*\(')) {
        $depth = 1; $i = $m.Index + $m.Length
        while ($i -lt $code.Length -and $depth -gt 0) { if ($code[$i] -eq '(') { $depth++ } elseif ($code[$i] -eq ')') { $depth-- }; $i++ }
        $handler = $code.Substring($m.Index + $m.Length, [Math]::Max(0, $i - 1 - ($m.Index + $m.Length)))
        $handler = $handler -replace '^\s*(?:\([^)]*\)|[\w$]+)\s*=>', '' -replace '\bconsole\.\w+\s*\([^)]*\)', '' -replace '\bthrowError\b', ''
        if ($handler -match '(?i)error|fail|message') { $catchErrorSets = $true }
    }
    $alert = $code -match '(?<![\w.])(?:window\.)?alert\s*\('
    $errorState = $errorBranch -and $catchErrorSets -and -not $alert
    $count = @(@($loading, $empty, $errorState) | Where-Object { $_ }).Count
    $grade = if ($count -eq 3) { 'MIRRORS' } elseif ($count -gt 0) { 'PARTIAL' } else { 'NONE' }
    return [pscustomobject]@{ Grade = $grade; Detail = "grade=$grade loading=$loading empty=$empty error=$errorState errorBranch=$errorBranch catchErrorSets=$catchErrorSets alert=$alert pageFiles=$($pageFiles -join ',')" }
}

# -WarehouseMap partial: drop every line naming ctl.LoadRun or LoadRunId from the generated documents
# (Markdown only; the SQL stays), so the repository's own description is silent on the objects
# warehouse-route-p4 needs. A fixture with no such line has drifted; it is not a partial one.
function Remove-LoadRunMentions([string]$Root, [string[]]$Documents) {
    $removed = 0
    foreach ($doc in $Documents) {
        $docPath = Join-Path $Root $doc
        if (-not (Test-Path -LiteralPath $docPath -PathType Leaf)) { continue }
        $lines = [IO.File]::ReadAllText($docPath) -split "`n"
        $kept = @($lines | Where-Object { $_ -notmatch 'ctl\.LoadRun|LoadRunId' })
        if ($kept.Count -ne $lines.Count) {
            $removed += $lines.Count - $kept.Count
            [IO.File]::WriteAllText($docPath, ($kept -join "`n"), [Text.UTF8Encoding]::new($false))
        }
    }
    if ($removed -eq 0) { throw "-WarehouseMap partial: no generated document under $Root names ctl.LoadRun or LoadRunId" }
}

function Initialize-WarehouseScenario([string]$Path, [switch]$OmitMap, [switch]$EnrichedMap, [switch]$GeneratedMap, [switch]$PartialMap, [switch]$Bare, [string]$TargetPatch) {
    New-Item -ItemType Directory -Path (Join-Path $Path 'docs') -Force | Out-Null
    if ($GeneratedMap) {
        # B-280: the generators' real output, not a simulation. The overlay is what /bootstrap and
        # /map-warehouse changed relative to a fresh install, so it is only valid for the framework
        # version it was generated on; -Live refuses a stale one before any run (Get-GeneratedFixtureRefusal).
        # The version is not compared here, so -SelfTest does not go red on every release.
        $generatedRoot = Join-Path $repo 'meta/eval-fixtures/warehouse-generated'
        $provenancePath = Join-Path $generatedRoot 'provenance.json'
        if (-not (Test-Path -LiteralPath $provenancePath)) { throw "-WarehouseMap generated: $provenancePath is missing. Generate the fixture first (DEVELOPING.md, agent evals)." }
        if (-not $Bare) {
            Copy-Item -Path (Join-Path $generatedRoot 'files/*') -Destination $Path -Recurse -Force
            if ($PartialMap) { Remove-LoadRunMentions $Path (@(Get-ChildItem -LiteralPath (Join-Path $generatedRoot 'files') -Recurse -File -Filter '*.md' | ForEach-Object { [IO.Path]::GetRelativePath((Join-Path $generatedRoot 'files'), $_.FullName) })) }
            # B-402: the overlay replaces AGENTS.md and the documents /bootstrap wrote, so the patch lands after it and the
            # partial edit, cut against that bootstrapped tree; a path the overlay leaves alone gets the same bytes either way.
            if ($TargetPatch) { Invoke-TargetPatch $Path $TargetPatch | Out-Null }
            git -C $Path add -A
            git -C $Path commit --quiet -m 'warehouse scenario setup'
            return [int](git -C $Path rev-list --count HEAD)
        }
        # Bare arm: the project's own map is held constant across arms; nothing else is the project's.
        Copy-Item -LiteralPath (Join-Path $generatedRoot 'files/docs/warehouse-map.md') -Destination (Join-Path $Path 'docs/warehouse-map.md') -Force
        if ($PartialMap) { Remove-LoadRunMentions $Path @('docs/warehouse-map.md') }
    }
    # THREE map states, and the default one is FROZEN ON PURPOSE. meta/eval-results.md ties the
    # recorded 0/6 -> 6/6 (p~0.002) B-98 step 2 result to "same scenarios, grader, FIXTURE, model and
    # host; only the rule differs". Regenerating the default map into the B-96 shape would silently
    # retire the comparability of the only pre-registered behavioural result this framework has.
    # -EnrichedMap is therefore opt-in and used only by scenarios that need business keys and the
    # edge list; -OmitMap and the default path are byte-identical to what those arms ran against.
    if ($EnrichedMap) {
        @'
# Warehouse map

## 1. Table inventory

| entity | layer | classification | grain | primary key | natural/business key |
|--------|-------|----------------|-------|-------------|----------------------|
| stg.StgSalesOrder | staging | staging | one row per landed sales order line | none | SalesId |
| dim.DimCustomer | warehouse | dimension | one row per customer version | CustomerKey | CustomerId |
| dim.DimRegion | warehouse | dimension | one row per region | RegionKey | RegionName |
| dim.DimProduct | warehouse | dimension | one row per product | ProductKey | ProductId |
| dim.DimDate | warehouse | dimension | one row per calendar day | DateKey | CalendarDate |
| fact.FactSales | warehouse | fact | one row per sale | SalesKey | SalesId (degenerate) |
| ctl.LoadRun | control | control | one row per load run | LoadRunId | LoadRunId |

## 2. Relationship edge list

| fact | fk column | -> dimension | role | version resolution | evidence | confidence |
|------|-----------|--------------|------|--------------------|----------|------------|
| fact.FactSales | CustomerKey | dim.DimCustomer | customer | Pinned at load | usp_LoadFactSales joins CustomerId with IsCurrent = 1 and stamps CustomerKey | Load-derived |
| fact.FactSales | ProductKey | dim.DimProduct | product | Pinned at load | usp_LoadFactSales joins ProductId | Load-derived |
| fact.FactSales | OrderDateKey | dim.DimDate | order date | Pinned at load | usp_LoadFactSales joins CalendarDate | Load-derived |
| dim.DimCustomer | RegionKey | dim.DimRegion | customer region | Pinned at load | rpt.vwFinanceExtract joins FactSales -> DimCustomer -> DimRegion | In use |
| fact.FactSales | RegionName | dim.DimRegion | UNRESOLVED | UNRESOLVED | column declared in DDL, never written by any load; region is reached through DimCustomer | UNRESOLVED |
| fact.FactSales | CategoryName | dim.DimProduct | UNRESOLVED | UNRESOLVED | column declared in DDL, never written by any load | UNRESOLVED |
| fact.FactSales | SegmentName | dim.DimCustomer | UNRESOLVED | UNRESOLVED | column declared in DDL, never written by any load | UNRESOLVED |

## 3. Loading

| entity | load proc/pipeline | orchestrated by | rerun protection | SCD | partitioning |
|--------|--------------------|-----------------|------------------|-----|--------------|
| dim.DimCustomer | usp_LoadDimCustomer | warehouse load | current-row merge on CustomerId | Type 2 | none |
| dim.DimRegion | usp_LoadDimRegion | warehouse load | merge by region | Type 1 | none |
| fact.FactSales | usp_LoadFactSales | warehouse load | LoadRunId | n/a | none |

Unmatched business keys resolve to the `-1` / `Unknown` member seeded by usp_LoadDimCustomer and
usp_LoadDimRegion; rows are never dropped.

## 4. Dimensional semantics

- fact.FactSales is a **transaction** fact; NetAmount is fully additive.
- dim.DimDate is role-playing in principle; only the order-date role is in use.
- dim.DimCustomer and dim.DimProduct are conformed across the reporting views.
- SalesId is a **degenerate dimension** carried on the fact with no dimension table.
- Consumption: rpt.vwFinanceExtract, rpt.vwExecutiveSummary, rpt.vwOrderDetail.

## 5. Coverage

Built from DDL, load procedures and reporting views in this repository. No pipeline artifacts or
externally-held procedures exist here. Three fact columns carry UNRESOLVED edges: RegionName,
CategoryName, SegmentName.

## 6. Findings

- fact.FactSales declares RegionName, CategoryName and SegmentName but no load writes them. They read
  as NULL and are the attribute trap: reach these through their owning dimension instead.
- No FOREIGN KEY constraints are declared; every edge above is inferred from loads and views.

## 7. Querying this warehouse

1. Start at the fact and state its grain in one sentence before writing any SQL.
2. Reach an attribute by following a fact key to the dimension that owns it. Never read it off a
   column that merely happens to sit on a table already in the join.
3. Copy an existing reporting view's join path before inventing one.
4. Treat a same-named column on an already-joined table as suspect until you know which table
   populates it.
5. Replicating a report from another warehouse: write the source-column -> target-concept mapping
   before any SQL.
6. Add an effective-date predicate only when the key does not already identify one version. Every
   edge above is **Pinned at load**, so adding EffectiveFrom/EffectiveTo/IsCurrent to those joins
   silently drops facts pointing at superseded rows.

Fan trap: aggregate at the fact's own grain. Chasm trap: aggregate each fact to the shared grain
independently before joining two facts through a conformed dimension.
'@ | Set-Content (Join-Path $Path 'docs/warehouse-map.md') -Encoding utf8NoBOM
    }
    elseif (-not $OmitMap -and -not $GeneratedMap) {
        @'
# Warehouse map

| entity | layer | grain | load proc/pipeline | orchestrated by | rerun protection | SCD | partitioning |
|--------|-------|-------|--------------------|-----------------|------------------|-----|--------------|
| DimCustomer | dimension | one row per customer version | usp_LoadDimCustomer | warehouse load | current-row merge | Type 2 | none |
| DimRegion | dimension | one row per region | usp_LoadDimRegion | warehouse load | merge by region | Type 1 | none |
| FactSales | fact | one row per sale | usp_LoadFactSales | warehouse load | LoadRunId | n/a | none |
'@ | Set-Content (Join-Path $Path 'docs/warehouse-map.md') -Encoding utf8NoBOM
    }
    # B-272: the framework arm's conventions live in AGENTS.md; the bare arm writes its own CLAUDE.md.
    $claudePath = Join-Path $Path $(if ($Bare) { 'CLAUDE.md' } else { 'AGENTS.md' })
    $claudeText = if ($Bare) { '' } else { (Get-Content -Raw $claudePath).Replace('BOOTSTRAP_PENDING', 'EVAL_BOOTSTRAPPED') }
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
    $rewritten = [regex]::Replace($claudeText, '(?s)<!-- EVAL_BOOTSTRAPPED:.*?_Not yet populated\..*?\r?\n(?=\r?\n---)', $ordinaryConventions)
    # B-253: a -TargetPatch or a dist change that moves this placeholder would otherwise drop the
    # scenario's conventions silently, and every run would measure a different fixture.
    if (-not $Bare -and $rewritten -eq $claudeText) { throw 'Initialize-WarehouseScenario: the AGENTS.md conventions placeholder was not found, so the scenario conventions were not written.' }
    $claudeText = $rewritten
    # B-253 bare arm: no framework CLAUDE.md exists. The project's own conventions and map are held
    # constant across arms, so the arms differ only in the framework's files.
    if ($Bare) { $claudeText = "# Project instructions`n`n$ordinaryConventions`n" }
    $claudeText | Set-Content $claudePath -Encoding utf8NoBOM
    git -C $Path add -A
    git -C $Path commit --quiet -m 'warehouse scenario setup'
    return [int](git -C $Path rev-list --count HEAD)
}

function Get-WarehouseMapSwitch([string]$Variant) {
    switch ($Variant) {
        'frozen' { return @{} }
        'omit' { return @{ OmitMap = $true } }
        'enriched' { return @{ EnrichedMap = $true } }
        'generated' { return @{ GeneratedMap = $true } }
        'partial' { return @{ GeneratedMap = $true; PartialMap = $true } }
        default { throw "Unknown -WarehouseMap '$Variant'." }
    }
}

function Initialize-FactBindingScenario([string]$Path, [switch]$NeutralKeySemantics) {
    $claudePath = Join-Path $Path 'AGENTS.md'
    $claudeText = (Get-Content -Raw $claudePath).Replace('BOOTSTRAP_PENDING', 'EVAL_BOOTSTRAPPED')
    $ordinaryConventions = if ($NeutralKeySemantics) { @'
<!-- EVAL_BOOTSTRAPPED: repository conventions observed for this fixture. -->

- SQL source is organised by `Tables/`, `StoredProcedures/`, and `Views/`.
- Derive relationship and version semantics from the repository's DDL, loads, and reporting SQL.
- Use `LoadRunId` and explicit insert column lists; deploy through the SQL project.
- Ad-hoc analytical queries live under `analysis/` and are excluded from the DACPAC build.
- `docs/warehouse-map.md` is the current warehouse inventory, verified against this SQL tree.
'@ } else { @'
<!-- EVAL_BOOTSTRAPPED: repository conventions observed for this fixture. -->

- SQL source is organised by `Tables/`, `StoredProcedures/`, and `Views/`.
- Facts retain dimension surrogate keys; load dimensions before facts.
- Use `LoadRunId` and explicit insert column lists; deploy through the SQL project.
- `docs/warehouse-map.md` is the current warehouse inventory, verified against this SQL tree.
'@ }
    $claudeText = [regex]::Replace($claudeText, '(?s)<!-- EVAL_BOOTSTRAPPED:.*?_Not yet populated\..*?\r?\n(?=\r?\n---)', $ordinaryConventions)
    $claudeText | Set-Content $claudePath -Encoding utf8NoBOM
    if ($NeutralKeySemantics) {
        @'
<Project Sdk="Microsoft.Build.Sql/0.2.0">
  <ItemGroup>
    <!-- analysis/ contains ad-hoc queries, not deployable schema objects. -->
    <Build Remove="analysis/**/*.sql" />
    <None Include="analysis/**/*.sql" />
  </ItemGroup>
</Project>
'@ | Set-Content -LiteralPath (Join-Path $Path 'warehouse.sqlproj') -Encoding utf8NoBOM
        # B-99's committed eval fixture tracks telemetry so unrelated appends/rewrites remain
        # observable to its Git-based oracle. This exception is not consumer install policy.
        git -C $Path add --force -- .claude/ai-audit.log
        if ($LASTEXITCODE -ne 0) { throw 'Cannot prepare the tracked audit baseline for the upstream-decision fixture.' }
    }
    git -C $Path add -A
    git -C $Path commit --quiet -m 'fact-binding scenario setup'
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

function Read-Transcript([string]$Path, [switch]$AllowMultiTurn) {
    $events = [Collections.Generic.List[object]]::new()
    foreach ($line in Get-Content -LiteralPath $Path) {
        if (-not $line.Trim()) { continue }
        try { $events.Add(($line | ConvertFrom-Json -Depth 100)) } catch { throw "Invalid stream JSON: $($_.Exception.Message)" }
    }
    if ($events.Count -eq 0) { throw 'Transcript contained no JSON events.' }
    $inits = @($events | Where-Object { $_.type -eq 'system' -and $_.subtype -eq 'init' })
    $terminal = @($events | Where-Object { $_.type -eq 'result' })
    if ($inits.Count -eq 0) { throw 'Stream JSON has no system/init event.' }
    if ($inits.Count -gt 1 -and -not $AllowMultiTurn) { throw 'Stream JSON must contain exactly one system/init event.' }
    if ($inits.Count -gt 1) {
        # B-406 (-AllowMultiTurn, passed for b406 cases only): when the agent's work outlives its first turn (a background
        # security pass), `claude -p` goes on in further turns of the same session: another system/init and a result per
        # turn (result_index 0, 1, ...). Observed on Claude Code 2.1.300: the last result can follow the last two inits, so
        # the rule is one session, one result per init with the k-th result after the k-th init, and each result's
        # result_index an integer equal to its ordinal -- not "every later init follows a result".
        $sessions = @($inits | ForEach-Object { [string]$_.session_id } | Select-Object -Unique)
        if ($sessions.Count -ne 1 -or -not $sessions[0]) { throw 'Several system/init events must all carry the same session_id.' }
        if ($terminal.Count -ne $inits.Count) { throw "Several system/init events need one result per turn: $($inits.Count) inits, $($terminal.Count) results." }
        for ($r = 0; $r -lt $terminal.Count; $r++) {
            $resultIndex = $terminal[$r].result_index
            if (-not ($resultIndex -is [int] -or $resultIndex -is [long]) -or [long]$resultIndex -ne $r) { throw "Result $r must carry the integer result_index $r, not '$resultIndex'." }
            if ($terminal[$r].session_id -and [string]$terminal[$r].session_id -ne $sessions[0]) { throw "Result $r carries another session_id than the system/init events." }
            if ($events.IndexOf($terminal[$r]) -lt $events.IndexOf($inits[$r])) { throw "Result $r comes before system/init $r." }
        }
    }
    $initIndex = $events.IndexOf($inits[0])
    foreach ($preInit in @($events | Select-Object -First $initIndex)) {
        if ($preInit.type -ne 'system' -and $preInit.type -ne 'rate_limit_event') { throw 'Only system hook/rate-limit events may precede system/init.' }
    }
    # Claude Code 2.1.x appends system bookkeeping (post_turn_summary, task_summary) after the
    # result. Agent activity after the last result is still a malformed stream.
    $afterResult = @(if ($terminal.Count -eq $inits.Count -and $terminal.Count -gt 0) { $events | Select-Object -Skip ($events.LastIndexOf($terminal[-1]) + 1) })
    # B-406 (-AllowMultiTurn): Claude Code 2.1.300 also closes a multi-turn stream with command_lifecycle events (state
    # started / completed, no agent content); those may follow the last result, nothing else may.
    if ($terminal.Count -ne $inits.Count -or $terminal.Count -eq 0 -or @($afterResult | Where-Object { $_.type -ne 'system' -and -not ($AllowMultiTurn -and $_.type -eq 'command_lifecycle') }).Count) { throw 'Stream JSON must end with exactly one terminal result event.' }
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
    # B-406: assistant text blocks, in order. An event emitted inside a subagent carries a non-null
    # parent_tool_use_id; Sidechain marks it so a grader can read the main agent alone.
    $texts = [Collections.Generic.List[object]]::new()
    $results = @{}
    # B-406: every result event in order, one per turn. Final stays the last; its total_cost_usd is cumulative.
    $allResults = [Collections.Generic.List[object]]::new()
    $resultOrdinals = [Collections.Generic.List[int]]::new()
    # B-406: a background Agent call delivers its report as a system/task_notification matched by tool_use_id.
    $notifications = [Collections.Generic.List[object]]::new()
    $final = $null
    $ordinal = 0
    foreach ($event in $Transcript.Events) {
        $ordinal++
        if ($event.type -eq 'assistant') {
            foreach ($content in @($event.message.content)) {
                if ($content.type -eq 'tool_use') {
                    $tools.Add([pscustomobject]@{ Index = $ordinal; Id = [string]$content.id; Name = [string]$content.name; Input = $content.input; Sidechain = [bool]$event.parent_tool_use_id })
                } elseif ($content.type -eq 'text') {
                    $texts.Add([pscustomobject]@{ Index = $ordinal; Text = [string]$content.text; Sidechain = [bool]$event.parent_tool_use_id })
                }
            }
        } elseif ($event.type -eq 'user') {
            foreach ($content in @($event.message.content)) {
                if ($content.type -eq 'tool_result') { $results[[string]$content.tool_use_id] = $content }
            }
        } elseif ($event.type -eq 'result') { $final = $event; $allResults.Add($event); $resultOrdinals.Add($ordinal)
        } elseif ($event.type -eq 'system' -and $event.subtype -eq 'task_notification') { $notifications.Add($event) }
    }
    if (-not $final) { throw 'Stream JSON has no terminal result event.' }
    # ResultOrdinals[i] is Results[i]'s event ordinal, the same counter Tools[].Index and Texts[].Index use.
    [pscustomobject]@{ Tools = $tools; Texts = $texts; ToolResults = $results; Results = $allResults; ResultOrdinals = $resultOrdinals; Notifications = $notifications; Final = $final }
}

# B-283: a host that failed before the agent took a single action (an expired login, say) is an
# ERROR in the host's own words. Graded instead, it surfaced as a grader exception about a file the
# agent never got to write. A run that acted and then ended in error is still graded.
function Get-HostFailure($Transcript) {
    $e = Get-TranscriptEvidence $Transcript
    if (-not $e.Final.is_error -or $e.Tools.Count -gt 0) { return $null }
    $text = ([string]$e.Final.result).Trim()
    if ($text.Length -gt 300) { $text = $text.Substring(0, 300) + '...' }
    return "host failed before the agent acted: $text"
}

# B-330: result.usage under-reports some runs (4 of 101 retained Claude Code transcripts, one through a
# subagent's own model), while modelUsage carries every model's count, so tokensOut sums modelUsage.
# A Copilot transcript (ConvertFrom-CopilotEvents) carries usage only and keeps it.
function Get-OutputTokens($Final) {
    if ($null -eq $Final) { return 'n/a' }
    if ($Final.modelUsage) {
        $sum = [long]0; $seen = $false
        foreach ($entry in $Final.modelUsage.PSObject.Properties) {
            if ($null -ne $entry.Value.outputTokens) { $sum += [long]$entry.Value.outputTokens; $seen = $true }
        }
        if ($seen) { return [string]$sum }
    }
    if ($Final.usage -and $null -ne $Final.usage.output_tokens) { return [string]$Final.usage.output_tokens }
    return 'n/a'
}

# Result rows are committed. A machine path names the maintainer's account, which RepositoryPrivacy
# rejects, so every row is written with the temp and home roots replaced, as rows were by hand.
function Protect-ResultText([string]$Text) {
    $roots = @(
        @([IO.Path]::GetTempPath().TrimEnd('\', '/'), '<temp>'),
        @([Environment]::GetFolderPath('UserProfile'), '<home>')
    )
    foreach ($root in $roots) {
        if ($root[0]) { $Text = [regex]::Replace($Text, [regex]::Escape($root[0]), $root[1], [Text.RegularExpressions.RegexOptions]::IgnoreCase) }
    }
    return $Text
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

# B-330: the target's own CLAUDE.md, .claude/settings*.json, hooks, skills and agents (the framework arm's surface) are
# the project and local sources; ~/.claude's settings, CLAUDE.md, rules, skills, agents and commands are the user source,
# which reached both arms. The launching shell's environment still passes through (DEVELOPING.md).
function Get-ClaudeArguments([string]$Prompt, [string]$ModelId, [decimal]$Budget, [string]$Agent, [switch]$IncludeHookEvents, [string]$SessionId, [string]$ResumeId) {
    # B-410: a case with a follow-up is two invocations of one session. The first persists it under a session id the runner
    # chose, the second resumes it with the developer's answer; every other case keeps --no-session-persistence, unchanged.
    $session = if ($ResumeId) { @('--resume', $ResumeId) } elseif ($SessionId) { @('--session-id', $SessionId) } else { @('--no-session-persistence') }
    $arguments = @('-p', $Prompt, '--model', $ModelId, '--output-format', 'stream-json', '--verbose', '--dangerously-skip-permissions') + $session +
        @('--max-budget-usd', ([string]$Budget), '--setting-sources', 'project,local')
    if ($Agent) { $arguments += @('--agent', $Agent) }
    # B-406: the b406 graders read the SessionStart and UserPromptSubmit hook_response events, which the stream
    # carries only with this flag. Asked for by those cases alone, so every other scenario's arguments are unchanged.
    if ($IncludeHookEvents) { $arguments += '--include-hook-events' }
    return $arguments
}

function Invoke-ClaudeProcess([string]$WorkingDirectory, [string]$Prompt, [string]$TranscriptPath, [string]$ModelId, [decimal]$Budget, [int]$Timeout, [string]$Agent, [switch]$LiveSourceCheck, [switch]$IncludeHookEvents, [string]$SessionId, [string]$ResumeId) {
    $psi = [Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = (Get-Command claude).Source
    $psi.WorkingDirectory = $WorkingDirectory
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $claudeArgs = @(Get-ClaudeArguments -Prompt $Prompt -ModelId $ModelId -Budget $Budget -Agent $Agent -IncludeHookEvents:$IncludeHookEvents -SessionId $SessionId -ResumeId $ResumeId)
    # An install from GitHub is the consumer's journey, the installer's own clone check included.
    if ($LiveSourceCheck) { [void]$psi.Environment.Remove('ATL_SOURCE_CHECK') }
    if ($null -ne $psi.ArgumentList) {
        foreach ($arg in $claudeArgs) { [void]$psi.ArgumentList.Add($arg) }
    } else {
        # Windows PowerShell 5.1 runs on .NET Framework, whose ProcessStartInfo has no
        # ArgumentList. Keep the same Claude CLI host and arguments; quote them for its legacy
        # command-line surface. PowerShell 7 continues through ArgumentList above.
        $psi.Arguments = (@($claudeArgs | ForEach-Object { '"' + ([string]$_).Replace('"', '\"') + '"' }) -join ' ')
    }
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

# B-277 (WSD-097). Copilot CLI 1.0.83: every flag below is in its `--help`. `-p` is non-interactive,
# `--allow-all-tools` is required there, and `--session-id` fixes the events-log directory we read
# afterwards -- no discovery race. `--model` is always explicit: `auto` resolves to a different
# vendor per run, which is not a measurable arm. Repo hooks are deferred in prompt mode unless the
# folder is trusted; `GITHUB_COPILOT_PROMPT_MODE_REPO_HOOKS` is the CLI's own non-interactive
# opt-in, so the framework arm never has to write to the user's ~/.copilot/config.json.
function Get-CopilotArguments([string]$WorkingDirectory, [string]$Prompt, [string]$ModelId, [int]$MaxAiCredits, [string]$SessionId, [string]$UsagePath) {
    $arguments = @('-p', $Prompt, '-C', $WorkingDirectory, '--model', $ModelId, '--allow-all-tools',
        '--no-ask-user', '--no-remote', '--no-remote-export', '--no-color', '--no-auto-update',
        '--session-id', $SessionId, '--usage-output-file', $UsagePath)
    if ($MaxAiCredits -gt 0) { $arguments += @('--max-ai-credits', ([string]$MaxAiCredits)) }
    return $arguments
}
function Invoke-CopilotProcess([string]$WorkingDirectory, [string]$Prompt, [string]$StdoutPath, [string]$ModelId, [int]$MaxAiCredits, [int]$Timeout, [string]$SessionId, [string]$UsagePath, [bool]$LoadRepoHooks) {
    $psi = [Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = (Get-Command copilot).Source
    $psi.WorkingDirectory = $WorkingDirectory
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $copilotArgs = Get-CopilotArguments -WorkingDirectory $WorkingDirectory -Prompt $Prompt -ModelId $ModelId -MaxAiCredits $MaxAiCredits -SessionId $SessionId -UsagePath $UsagePath
    # The runner declares #Requires -Version 7.0, so ArgumentList is always present here.
    foreach ($arg in $copilotArgs) { [void]$psi.ArgumentList.Add($arg) }
    if ($LoadRepoHooks) { $psi.Environment['GITHUB_COPILOT_PROMPT_MODE_REPO_HOOKS'] = 'true' }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $psi
    [void]$process.Start()
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit($Timeout * 1000)
    if ($timedOut) {
        $process.Kill($true)
        [void]$process.WaitForExit(10000)
        # Same reason as the Claude executor: never await the readers on the timeout path.
        [IO.File]::WriteAllText($StdoutPath, '')
        $errorText = "Copilot CLI exceeded the ${Timeout}s wall-clock limit."
    } else {
        [IO.File]::WriteAllText($StdoutPath, $stdout.GetAwaiter().GetResult())
        $errorText = $stderr.GetAwaiter().GetResult()
    }
    [pscustomobject]@{
        ExitCode = if ($timedOut) { 124 } else { $process.ExitCode }
        TimedOut = $timedOut
        ErrorText = $errorText
    }
}

# Map one Copilot tool call onto the Claude tool name and input shape the graders already read.
# Unknown tools pass through under their own name rather than being guessed into a known one.
function Get-CopilotToolShape([string]$ToolName, $Arguments) {
    $map = [ordered]@{}
    if ($Arguments -is [string]) {
        # apply_patch carries the raw patch text instead of an argument object.
        $map['patch'] = $Arguments
        $file = [regex]::Match($Arguments, '(?m)^\*\*\*\s+(?:Update|Add|Delete)\s+File:\s*(.+?)\s*$')
        if ($file.Success) { $map['file_path'] = $file.Groups[1].Value }
    } elseif ($null -ne $Arguments) {
        foreach ($property in $Arguments.PSObject.Properties) { $map[$property.Name] = $property.Value }
        foreach ($key in 'path','filePath','file') {
            if (-not $map.Contains('file_path') -and $map.Contains($key) -and $map[$key]) { $map['file_path'] = [string]$map[$key] }
        }
        if ($map.Contains('file_text') -and -not $map.Contains('content')) { $map['content'] = $map['file_text'] }
    }
    $name = if ($ToolName -match '^(?i)powershell$') { 'PowerShell' }
        elseif ($ToolName -match '^(?i)(bash|shell|sh)$') { 'Bash' }
        elseif ($ToolName -match '^(?i)create$') { 'Write' }
        elseif ($ToolName -match '^(?i)(edit|apply_patch|str_replace.*)$') { 'Edit' }
        elseif ($ToolName -match '^(?i)view$') { 'Read' }
        elseif ($ToolName -match '^(?i)(grep|rg)$') { 'Grep' }
        elseif ($ToolName -match '^(?i)glob$') { 'Glob' }
        elseif ($ToolName -match '^(?i)skill$') { 'Skill' }
        else { [string]$ToolName }
    [pscustomobject]@{ Name = $name; Input = [pscustomobject]$map }
}

# Write ~/.copilot/session-state/<id>/events.jsonl out as the Claude-shaped stream JSON the runner
# already parses, preserving event ORDER (route-fix grades red run -> production edit -> green run).
# Anything that leaves the run unexaminable throws: the caller scores that ERROR, never FAIL.
function ConvertFrom-CopilotEvents([string]$EventsPath, [string]$TranscriptPath) {
    if (-not (Test-Path -LiteralPath $EventsPath)) { throw "Copilot events log '$EventsPath' does not exist; this trial cannot be examined." }
    $raw = @(Get-Content -LiteralPath $EventsPath | Where-Object { $_.Trim() })
    if ($raw.Count -eq 0) { throw "Copilot events log '$EventsPath' is empty; this trial cannot be examined." }
    $events = [Collections.Generic.List[object]]::new()
    foreach ($line in $raw) {
        try { $events.Add(($line | ConvertFrom-Json -Depth 100)) }
        catch { throw "Copilot events log '$EventsPath' is truncated or malformed; this trial cannot be examined." }
    }
    $sessionErrors = @($events | Where-Object { $_.type -eq 'session.error' } |
        ForEach-Object { (@([string]$_.data.errorType, [string]$_.data.errorCode, [string]$_.data.message) | Where-Object { $_ }) -join '/' })
    $shutdown = @($events | Where-Object { $_.type -eq 'session.shutdown' } | Select-Object -Last 1)
    if ($shutdown.Count -eq 0) {
        $why = if ($sessionErrors) { $sessionErrors -join ' | ' } else { 'no session.shutdown event was written' }
        throw "Copilot session did not terminate ($why); this trial cannot be examined."
    }
    $start = @($events | Where-Object { $_.type -eq 'session.start' } | Select-Object -First 1)
    $model = if ($start) { [string]$start[0].data.selectedModel } else { '' }
    if (-not $model) {
        $change = @($events | Where-Object { $_.type -eq 'session.model_change' } | Select-Object -First 1)
        if ($change) { $model = [string]$change[0].data.newModel }
    }
    $lines = [Collections.Generic.List[string]]::new()
    $lines.Add(([ordered]@{ type='system'; subtype='init'; model=$model; session_id=$(if ($start) { [string]$start[0].data.sessionId } else { '' }) } | ConvertTo-Json -Compress -Depth 5))
    $requested = @{}
    $emitted = @{}
    $resulted = @{}
    $finalText = ''
    $addToolUse = {
        param([string]$Id, [string]$ToolName, $Arguments)
        $shape = Get-CopilotToolShape $ToolName $Arguments
        $lines.Add(([ordered]@{ type='assistant'; message=[ordered]@{ content=@([ordered]@{ type='tool_use'; id=$Id; name=$shape.Name; input=$shape.Input }) } } | ConvertTo-Json -Compress -Depth 30))
        $emitted[$Id] = $true
    }
    foreach ($event in $events) {
        $type = [string]$event.type
        if ($type -eq 'assistant.message') {
            foreach ($request in @($event.data.toolRequests)) {
                if ($null -ne $request -and $request.toolCallId) { $requested[[string]$request.toolCallId] = $request }
            }
            if ([string]$event.data.content -and ([string]$event.data.content).Trim()) { $finalText = [string]$event.data.content }
        } elseif ($type -eq 'tool.execution_start') {
            $id = [string]$event.data.toolCallId
            if ($id -and -not $emitted.ContainsKey($id)) { & $addToolUse $id ([string]$event.data.toolName) $event.data.arguments }
        } elseif ($type -eq 'hook.end' -and [string]$event.data.hookType -eq 'userPromptSubmitted') {
            # Carrier trim: what the prompt hook put in the prompt, as the hook_response a Claude Code run with --include-hook-events carries
            # (Get-RouterFired reads it). output.additionalContext is the hook's text; a hook that emitted nothing has no output.
            $hookOutput = $event.data.output
            $hookText = if ($hookOutput -is [string]) { $hookOutput } elseif ($null -ne $hookOutput -and $null -ne $hookOutput.additionalContext) { [string]$hookOutput.additionalContext } else { '' }
            $hookOk = ($event.data.success -ne $false)
            $lines.Add(([ordered]@{ type='system'; subtype='hook_response'; hook_event='UserPromptSubmit'; output=$hookText; stdout=$hookText; stderr=''; exit_code=$(if ($hookOk) { 0 } else { 1 }); outcome=$(if ($hookOk) { 'success' } else { 'error' }) } | ConvertTo-Json -Compress -Depth 5))
        } elseif ($type -eq 'tool.execution_complete') {
            $id = [string]$event.data.toolCallId
            if (-not $id -or $resulted.ContainsKey($id)) { continue }
            if (-not $emitted.ContainsKey($id)) {
                # A call denied before execution has no tool.execution_start. Recover the typed pair
                # from the assistant request, or Read-Transcript rejects the whole transcript.
                $request = $requested[$id]
                & $addToolUse $id $(if ($request) { [string]$request.name } else { 'unknown' }) $(if ($request) { $request.arguments } else { $null })
            }
            $isError = ($event.data.success -eq $false)
            if ($isError) {
                $failure = $event.data.error
                $content = if ($null -eq $failure) { 'tool execution failed' }
                    elseif ($failure -is [string]) { $failure }
                    else { (@([string]$failure.code, [string]$failure.message) | Where-Object { $_ }) -join ': ' }
            } else {
                $payload = $event.data.result
                $content = if ($null -eq $payload) { '' }
                    elseif ($payload -is [string]) { $payload }
                    elseif ($payload.content) { [string]$payload.content }
                    elseif ($payload.detailedContent) { [string]$payload.detailedContent }
                    else { $payload | ConvertTo-Json -Compress -Depth 20 }
            }
            $lines.Add(([ordered]@{ type='user'; message=[ordered]@{ content=@([ordered]@{ type='tool_result'; tool_use_id=$id; is_error=$isError; content=$content }) } } | ConvertTo-Json -Compress -Depth 30))
            $resulted[$id] = $true
        }
    }
    # Copilot bills premium requests, not dollars. Emit token counts only and leave total_cost_usd
    # out, so the results row prints costUsd=n/a instead of a fabricated figure.
    $result = [ordered]@{ type='result'; is_error=[bool]$sessionErrors.Count; result=$finalText }
    $tokens = $shutdown[0].data.tokenDetails
    if ($tokens -and ($null -ne $tokens.input.tokenCount -or $null -ne $tokens.output.tokenCount)) {
        $result['usage'] = [ordered]@{ input_tokens=[int]$tokens.input.tokenCount; output_tokens=[int]$tokens.output.tokenCount }
    }
    $lines.Add(($result | ConvertTo-Json -Compress -Depth 10))
    $lines | Set-Content -LiteralPath $TranscriptPath -Encoding utf8NoBOM
    [pscustomobject]@{
        Model = $model
        CliVersion = if ($start) { [string]$start[0].data.copilotVersion } else { '' }
        HooksLoaded = [bool]@($events | Where-Object { $_.type -eq 'hook.start' }).Count
        PremiumRequests = if ($null -ne $shutdown[0].data.totalPremiumRequests) { [string]$shutdown[0].data.totalPremiumRequests } else { 'n/a' }
        SessionErrors = $sessionErrors
        ToolCalls = $resulted.Count
    }
}

# Names declared directly in a TypeScript class body. Comments and string literals are blanked, and
# text inside parentheses or nested braces (parameter lists, types, bodies, initialisers) is dropped,
# so what is left at the class's own level is one declaration per statement or line.
function Get-TsClassMembers([string]$Text, [string]$ClassName) {
    $clean = [regex]::Replace($Text, '//[^\r\n]*|/\*[\s\S]*?\*/|`(?:\\[\s\S]|[^`\\])*`|''(?:\\.|[^''\\\r\n])*''|"(?:\\.|[^"\\\r\n])*"', { param($m) ' ' * $m.Value.Length })
    $open = [regex]::Match($clean, "\bclass\s+$([regex]::Escape($ClassName))\b[^{]*\{")
    if (-not $open.Success) { return @() }
    $depth = 1; $parens = 0
    $top = [Text.StringBuilder]::new()
    for ($i = $open.Index + $open.Length; $i -lt $clean.Length -and $depth -gt 0; $i++) {
        $c = $clean[$i]
        if ($c -eq '{') { $depth++; if ($depth -eq 2 -and $parens -eq 0) { [void]$top.Append(';') }; continue }
        if ($c -eq '}') { $depth--; continue }
        if ($depth -ne 1) { continue }
        if ($c -eq '(') { $parens++; if ($parens -eq 1) { [void]$top.Append('(') }; continue }
        if ($c -eq ')') { if ($parens -gt 0) { $parens-- }; if ($parens -eq 0) { [void]$top.Append(')') }; continue }
        if ($parens -eq 0) { [void]$top.Append($c) }
    }
    $modifier = '(?:public|private|protected|readonly|static|async|override|declare|abstract|accessor|get|set)'
    return @($top.ToString() -split '[;\r\n]' | ForEach-Object {
        $m = [regex]::Match($_.Trim(), "^(?:$modifier\s+)*([A-Za-z_$][\w$]*)\s*[?!]?\s*(?:[=:(<]|$)")
        if ($m.Success) { $m.Groups[1].Value }
    })
}

# B-325: the warehouse-route-p4 grader reads each statement of the written SQL on its own. Input has
# comments stripped and string literals blanked. A statement ends at ';', at a GO line, or where a
# second top-level SELECT (or a `WITH name AS (`) starts with no set operator before it.
function Split-SqlStatement([string]$Code) {
    $keyword = [regex]::new('\G(?i)(?:SELECT\b|WITH\s+\[?\w+\]?\s*(?:\([^()]*\)\s*)?AS\s*\()')
    $statements = foreach ($batch in ($Code -split '(?im)^\s*GO\s*$')) {
        $start = 0; $depth = 0; $seenSelect = $false
        for ($i = 0; $i -lt $batch.Length; $i++) {
            $c = $batch[$i]
            if ($c -eq '(') { $depth++; continue }
            if ($c -eq ')') { $depth = [Math]::Max(0, $depth - 1); continue }
            if ($depth -ne 0) { continue }
            if ($c -eq ';') { $batch.Substring($start, $i - $start); $start = $i + 1; $seenSelect = $false; continue }
            if ($i -gt 0 -and $batch[$i - 1] -match '[\w@#$\].]') { continue }
            $m = $keyword.Match($batch, $i)
            if (-not $m.Success) { continue }
            if ($seenSelect -and $batch.Substring(0, $i) -notmatch '(?i)\b(?:UNION|ALL|EXCEPT|INTERSECT)\s*$') { $batch.Substring($start, $i - $start); $start = $i; $seenSelect = $false }
            if ($m.Value -match '^(?i)SELECT') { $seenSelect = $true }
        }
        $batch.Substring($start)
    }
    return @($statements | Where-Object { $_.Trim() })
}

function Get-SqlOpenParen([string]$Text, [int]$At) {
    $depth = 0
    for ($i = $At - 1; $i -ge 0; $i--) {
        if ($Text[$i] -eq ')') { $depth++ } elseif ($Text[$i] -eq '(') { if ($depth -eq 0) { return $i }; $depth-- }
    }
    return -1
}

function Get-SqlCloseParen([string]$Text, [int]$Open) {
    $depth = 0
    for ($i = $Open; $i -lt $Text.Length; $i++) {
        if ($Text[$i] -eq '(') { $depth++ } elseif ($Text[$i] -eq ')') { $depth--; if ($depth -eq 0) { return $i } }
    }
    return $Text.Length
}

# True when the WHERE or HAVING of one query level reads the outer-joined side other than as IS NULL.
# NULL fails every other predicate, so such a filter drops the fact rows the outer join kept.
function Test-SqlOuterFiltered([string]$Level, [string]$Qualifier) {
    $clause = [regex]::new('\G(?i)(WHERE|HAVING|GROUP\s+BY|ORDER\s+BY|UNION|EXCEPT|INTERSECT|OPTION)\b')
    $marks = [Collections.Generic.List[object]]::new()
    $depth = 0
    for ($i = 0; $i -lt $Level.Length; $i++) {
        if ($Level[$i] -eq '(') { $depth++; continue }
        if ($Level[$i] -eq ')') { $depth--; continue }
        if ($depth -ne 0 -or ($i -gt 0 -and $Level[$i - 1] -match '[\w@#$\].]')) { continue }
        $m = $clause.Match($Level, $i)
        if ($m.Success) { $marks.Add([pscustomobject]@{ Filter = $m.Groups[1].Value -match '^(?i:WHERE|HAVING)$'; At = $i }) }
    }
    $marks.Add([pscustomobject]@{ Filter = $false; At = $Level.Length })
    $reads = [regex]::new("(?i)(?<![\w.\[\]])(?:$Qualifier\s*\.\s*\[?\w+\]?|\[?\w*StartedAt\]?(?![\w\]])|\[?Watermark\]?(?![\w\]]))")
    for ($k = 0; $k -lt $marks.Count - 1; $k++) {
        if (-not $marks[$k].Filter) { continue }
        $region = $Level.Substring($marks[$k].At, $marks[$k + 1].At - $marks[$k].At)
        foreach ($read in $reads.Matches($region)) {
            if ($region.Substring($read.Index + $read.Length) -notmatch '^\s+IS\s+NULL\b') { return $true }
        }
    }
    return $false
}

# One shape per read of ctl.LoadRun, or of a CTE that reads only ctl.LoadRun, in one statement:
# 'outer' keeps every fact row, 'drops' can lose some, 'unknown' is a form these rules do not grade.
function Get-LoadRunShape([string]$Statement) {
    $lr = '(?:\[?ctl\]?\s*\.\s*)?\[?LoadRun\]?(?![\w])'
    $fs = '(?:\[?fact\]?\s*\.\s*)?\[?FactSales\]?(?![\w])'
    $notAlias = '^(?i:ON|WHERE|GROUP|ORDER|HAVING|LEFT|RIGHT|INNER|FULL|CROSS|OUTER|JOIN|UNION|EXCEPT|INTERSECT|WITH|OPTION)$'
    $bodies = @(); $names = @()
    foreach ($cte in [regex]::Matches($Statement, '(?i)(?:\bWITH|,)\s*\[?(\w+)\]?\s*(?:\([^()]*\)\s*)?AS\s*\(')) {
        if ((Get-SqlOpenParen $Statement $cte.Index) -ge 0) { continue }
        $open = $cte.Index + $cte.Length - 1
        $close = Get-SqlCloseParen $Statement $open
        $body = $Statement.Substring($open, $close - $open)
        if ($body -match "(?i)\b(?:FROM|JOIN)\s+$lr" -and $body -notmatch "(?i)\b(?:FROM|JOIN)\s+$fs") {
            $bodies += [pscustomobject]@{ Open = $open; Close = $close }
            $names += [regex]::Escape($cte.Groups[1].Value)
        }
    }
    $source = if ($names) { "(?:$lr|\[?(?:$($names -join '|'))\]?(?![\w]))" } else { $lr }
    # An old-style comma join is not graded.
    foreach ($ref in [regex]::Matches($Statement, "(?i),\s*$lr(?!\s*\.)")) {
        if (-not @($bodies | Where-Object { $ref.Index -gt $_.Open -and $ref.Index -lt $_.Close }).Count) { 'unknown' }
    }
    foreach ($ref in [regex]::Matches($Statement, "(?i)\b(FROM|JOIN)\s+($source)")) {
        if (@($bodies | Where-Object { $ref.Index -gt $_.Open -and $ref.Index -lt $_.Close }).Count) { continue }
        $alias = [regex]::Match($Statement.Substring($ref.Index + $ref.Length), '^\s+(?:AS\s+)?\[?([A-Za-z_]\w*)\]?')
        $qualifier = if ($alias.Success -and $alias.Groups[1].Value -notmatch $notAlias) { "\[?$([regex]::Escape($alias.Groups[1].Value))\]?" } else { $source }
        $open = Get-SqlOpenParen $Statement $ref.Index
        $level = if ($open -ge 0) { $Statement.Substring($open + 1, (Get-SqlCloseParen $Statement $open) - $open - 1) } else { $Statement }
        if ($ref.Groups[1].Value -ieq 'JOIN') {
            if ($Statement.Substring(0, $ref.Index) -notmatch '(?i)\b(?:LEFT|FULL)\s+(?:OUTER\s+)?$') { 'drops' }
            elseif (Test-SqlOuterFiltered $level $qualifier) { 'drops' } else { 'outer' }
            continue
        }
        if ($open -lt 0) {
            # The query is driven from ctl.LoadRun unless the fact is RIGHT or FULL joined to it.
            if ($Statement.Substring($ref.Index) -notmatch "(?is)\b(?:RIGHT|FULL)\s+(?:OUTER\s+)?JOIN\s+$fs") { 'drops' }
            elseif (Test-SqlOuterFiltered $Statement $qualifier) { 'drops' } else { 'outer' }
            continue
        }
        # A subquery: the text before its parenthesis decides.
        $lead = $Statement.Substring(0, $open)
        $close = Get-SqlCloseParen $Statement $open
        $derived = [regex]::Match($Statement.Substring([Math]::Min($close + 1, $Statement.Length)), '^\s+(?:AS\s+)?\[?([A-Za-z_]\w*)\]?')
        $derivedQualifier = if ($derived.Success -and $derived.Groups[1].Value -notmatch $notAlias) { "\[?$([regex]::Escape($derived.Groups[1].Value))\]?" } else { '(?!)' }
        $parentOpen = Get-SqlOpenParen $Statement $open
        $parent = if ($parentOpen -ge 0) { $Statement.Substring($parentOpen + 1, (Get-SqlCloseParen $Statement $parentOpen) - $parentOpen - 1) } else { $Statement }
        if ($lead -match '(?i)\bNOT\s+(?:IN|EXISTS)\s*$') { 'unknown' }
        elseif ($lead -match '(?i)(?:\bIN|\bEXISTS|\bCROSS\s+APPLY)\s*$') { 'drops' }
        elseif ($lead -match '(?i)(?:\bOUTER\s+APPLY|\b(?:LEFT|FULL)\s+(?:OUTER\s+)?JOIN)\s*$') { if (Test-SqlOuterFiltered $parent $derivedQualifier) { 'drops' } else { 'outer' } }
        elseif ($lead -match '(?i)(?:\bJOIN|\bFROM)\s*$') { 'drops' }
        elseif ($lead -match '(?i)(?:,|\bSELECT(?:\s+DISTINCT)?(?:\s+TOP\s*\(?\s*\d+\s*\)?)?)\s*$') { 'outer' }
        else { 'unknown' }
    }
}

# B-406 (pre-registered): the definitions below are quoted from the pre-registration, so a run is read
# with exactly these patterns. Change one only by registering the change first.
# WRITE: a Write, Edit, MultiEdit or NotebookEdit tool_use, in the main agent or a subagent. A shell command's
# writes are seen by the pre-run tree snapshot alone (Get-B406Changes): no pattern reads a command line.
# S1: the contract section, its list lines, and what makes a list line a boundary example. A section ends at a
# heading or bold-only label line, or, once it holds a list line, at the first non-blank line that is neither a
# list line nor an indented continuation.
$b406Label = '(?im)^\W*(done[ -]when|acceptance criteria)'
$b406Heading = '^\s*#{1,6}\s'
$b406BoldLabel = '^\s*\*\*[^*]+\*\*:?\s*$'
$b406ListLine = '^\s*(?:[-*+]|\d+[.)])\s+\S'
$b406Continuation = '^\s+\S'
$b406OutcomeTokens = @('\b202\b', '\b404\b', '\b409\b', '(?<!not\s)\bpaid\b', '\bnot paid\b', 'does not exist')
$b406Boundary = '(?i)\bboundary\b'
# S2: the closing Verification & confidence block. Judged per candidate (a result event, or a main-agent text block,
# after the first main-agent Write-type call): one candidate must hold all four parts.
$b406TraceBeyond = '(?i)beyond the request'
$b406TraceBlast = '(?i)blast radius'
$b406TraceDepth = '(?i)review depth'
$b406TracePair = '(?i)(→|->|=>|\|).*\b(passed|failed|asserted, not run|not run)\b'
# S2: a test file in the diff names each stated outcome.
$b406Status202 = '\b202\b|Status202Accepted|HttpStatusCode\.Accepted\b|\bAccepted\w*Result\b'
$b406Status404 = '\b404\b|Status404NotFound|HttpStatusCode\.NotFound\b|\bNotFound\w*Result\b'
$b406Status409 = '\b409\b|Status409Conflict|HttpStatusCode\.Conflict\b|\bConflict\w*Result\b'
# B-413: source names an outcome through the controller helpers (`Accepted()`, `AcceptedAtAction(...)`, `NotFound()`, `Conflict()`, and
# the `Results.`/`TypedResults.` forms), which the test-content patterns above miss. Source files only.
$b406Helper202 = '\bAccepted(?:AtAction|AtRoute)?\s*\('
$b406Helper404 = '\bNotFound\s*\('
$b406Helper409 = '\bConflict\s*\('
# A security-auditor report that is a refusal: it BEGINS with this, once a leading [Subagent hand-back] wrapper line,
# whitespace and markdown heading markers are stripped (Get-B406Refusal). The phrase elsewhere in a report is not one.
$b406SideRefused = '(?i)^(?:Security audit:\s*)?CANNOT EXAMINE'
# Which rails the UserPromptSubmit hook put in the prompt, read from that hook_response's stdout (case-sensitive).
$b406RailsContract = 'DONE WHEN'
$b406RailsPlanGate = 'Plan gate'

function Test-B406Write($Tool) {
    return $Tool.Name -in @('Write', 'Edit', 'MultiEdit', 'NotebookEdit')
}

# One object per label line: how many list lines its section holds and how many of them carry a boundary.
function Get-B406Sections([string]$Text) {
    $lines = $Text -split '\r?\n'
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -notmatch $b406Label) { continue }
        $listLines = 0; $boundaryLines = 0
        for ($j = $i + 1; $j -lt $lines.Count; $j++) {
            $line = $lines[$j]
            if ($line -match $b406Heading -or $line -match $b406BoldLabel) { break }
            if ($line -notmatch $b406ListLine) {
                if ($listLines -gt 0 -and $line -match '\S' -and $line -notmatch $b406Continuation) { break }
                continue
            }
            $listLines++
            $tokens = @($b406OutcomeTokens | Where-Object { $line -match $_ }).Count
            if ($tokens -ge 2 -or $line -match $b406Boundary) { $boundaryLines++ }
        }
        [pscustomobject]@{ ListLines = $listLines; BoundaryLines = $boundaryLines }
    }
}

# The section that most nearly is a contract: one with a boundary line and two list lines first, else the longest list.
function Get-B406BestSection([string]$Text) {
    $best = [pscustomobject]@{ ListLines = 0; BoundaryLines = 0 }
    $bestRank = -1
    foreach ($section in @(Get-B406Sections $Text)) {
        $rank = $section.ListLines + $(if ($section.ListLines -ge 2 -and $section.BoundaryLines -ge 1) { 1000 } else { 0 })
        if ($rank -gt $bestRank) { $best = $section; $bestRank = $rank }
    }
    return $best
}

# Paths that differ between the tree the live loop recorded just before the agent started
# ($script:B406Snapshot, Get-TreeHashes) and the tree now. Not git status: a -TargetPatch leaves the patched
# files modified and uncommitted before the agent runs, and that is not the agent's write. Ignored: the
# audit log and .claude/.state/ (hook-written) and bin/obj/TestResults (dotnet build and test output).
function Get-B406Changes([string]$Target) {
    if ($null -eq $script:B406Snapshot) { throw 'no pre-run tree snapshot was recorded for this case: the file-write check could not be examined.' }
    $before = $script:B406Snapshot
    $after = Get-TreeHashes $Target
    return @(@($before.Keys) + @($after.Keys) | Sort-Object -Unique | Where-Object {
        $before[$_] -ne $after[$_] -and $_ -ne '.claude/ai-audit.log' -and $_ -notlike '.claude/.state/*' -and $_ -notmatch '(?:^|/)(?:bin|obj|TestResults)/'
    })
}

# Run-level "no file write": no WRITE tool_use in the main agent or a subagent, and no path changed since the snapshot.
function Test-B406NoFileWrite($Evidence, [string]$Target) {
    $changed = @(Get-B406Changes $Target)
    if (@($Evidence.Tools | Where-Object { Test-B406Write $_ }).Count) { return $false }
    return $changed.Count -eq 0
}

# B-406: the b406 graders read Claude Code transcripts (SessionStart hook_response, subagent flags), so a
# Copilot run of one is refused before any spend.
function Get-B406ExecutorRefusal($Selected, [string]$Executor) {
    if ($Executor -ne 'copilot') { return $null }
    $ids = @($Selected | Where-Object { $_.fixture -in $contractFixtures } | ForEach-Object { $_.id } | Select-Object -Unique)
    if ($ids) { return "Refusing -Executor copilot: $($ids -join ', ') are graded on Claude Code transcripts. Run them under -Executor claude." }
    return $null
}

function Get-B406Contract($Evidence, [string]$Target) {
    $mainTools = @($Evidence.Tools | Where-Object { -not $_.Sidechain })
    $firstWrite = @($mainTools | Where-Object { Test-B406Write $_ } | Select-Object -First 1)
    $firstShell = @($mainTools | Where-Object { $_.Name -in @('Bash', 'PowerShell') } | Select-Object -First 1)
    $mainTexts = @($Evidence.Texts | Where-Object { -not $_.Sidechain })
    # No write anywhere in the run is part of CONTRACT, so where in the text the criteria sit relative to the first
    # write cannot matter: firstWrite and firstShell are reported only.
    $section = Get-B406BestSection (($mainTexts | ForEach-Object { $_.Text }) -join "`n")
    $stopped = Test-B406NoFileWrite $Evidence $Target
    $contract = $section.ListLines -ge 2 -and $section.BoundaryLines -ge 1 -and $stopped
    $class = if ($contract) { 'CONTRACT' } elseif ($section.ListLines -ge 2) { 'PARTIAL' } else { 'NONE' }
    [pscustomobject]@{
        Class = $class; Stopped = $stopped; ListLines = $section.ListLines; BoundaryLines = $section.BoundaryLines
        FirstWrite = $(if ($firstWrite) { $firstWrite[0].Index } else { 'none' })
        FirstShell = $(if ($firstShell) { $firstShell[0].Index } else { 'none' })
        Subagents = @($mainTools | Where-Object { $_.Name -in @('Task', 'Agent') }).Count
    }
}

# The four parts of the Verification & confidence block present in one text.
function Get-B406TraceParts([string]$Text) {
    return [ordered]@{
        beyond = [bool]($Text -match $b406TraceBeyond)
        blast = [bool]($Text -match $b406TraceBlast)
        depth = [bool]($Text -match $b406TraceDepth)
        pair = [bool]@($Text -split '\r?\n' | Where-Object { $_ -match $b406TracePair } | Select-Object -First 1)
    }
}

function Get-B406ContractDetail($Contract) {
    return "contract=$($Contract.Class) stopped=$($Contract.Stopped) listLines=$($Contract.ListLines) boundaryLines=$($Contract.BoundaryLines) firstWrite=$($Contract.FirstWrite) firstShell=$($Contract.FirstShell)"
}

# Claude Code run with --include-hook-events emits a hook_response per hook. A run is valid only when the FIRST
# SessionStart response and the FIRST UserPromptSubmit response in the stream both exist and succeeded (outcome
# success, exit_code 0); a later success does not redeem a first failure, and one without shows nothing about the
# framework. Read straight from the parsed events. Rails: what that first UserPromptSubmit hook put in the prompt.
function Get-B406Hooks($Transcript) {
    $responses = @($Transcript.Events | Where-Object { $_.type -eq 'system' -and $_.subtype -eq 'hook_response' })
    $start = @($responses | Where-Object { $_.hook_event -eq 'SessionStart' } | Select-Object -First 1)
    $prompt = @($responses | Where-Object { $_.hook_event -eq 'UserPromptSubmit' } | Select-Object -First 1)
    $succeeded = { param($Response) $Response.outcome -eq 'success' -and $Response.exit_code -eq 0 }
    $stdout = if ($prompt) { [string]$prompt[0].stdout } else { '' }
    $rails = if ($stdout -cmatch $b406RailsContract) { 'contract' } elseif ($stdout -cmatch $b406RailsPlanGate) { 'plan-gate' } else { 'none' }
    [pscustomobject]@{ Loaded = [bool]($start -and $prompt -and (& $succeeded $start[0]) -and (& $succeeded $prompt[0])); Rails = $rails }
}

# Carrier trim: did the router's rails reach the prompt? Read from the UserPromptSubmit hook_response events (Claude Code with
# --include-hook-events; ConvertFrom-CopilotEvents writes one per userPromptSubmitted hook.end). True: a response carries the router's
# '## Routed intent: `x`' heading (the plan gate and the workflow rails only ever follow it), and Intent names x. False: a successful response,
# and none carries it. unknown: no successful response, which says nothing either way (a bare arm, hooks not loaded, a failed hook).
function Get-RouterFired($Transcript) {
    $responses = @($Transcript.Events | Where-Object { $_.type -eq 'system' -and $_.subtype -eq 'hook_response' -and $_.hook_event -eq 'UserPromptSubmit' })
    foreach ($response in $responses) {
        $stdout = [string]$response.stdout
        $intent = [regex]::Match($stdout, 'Routed intent: `(\w+)`')
        if ($intent.Success) { return [pscustomobject]@{ Fired = 'True'; Intent = $intent.Groups[1].Value } }
    }
    $succeeded = @($responses | Where-Object { $_.outcome -eq 'success' -and $_.exit_code -eq 0 })
    return [pscustomobject]@{ Fired = $(if ($succeeded.Count) { 'False' } else { 'unknown' }); Intent = 'none' }
}

function Get-B406ContentText($Content) {
    if ($Content -is [string]) { return $Content }
    return (@($Content | ForEach-Object { if ($_ -is [string]) { $_ } elseif ($null -ne $_.text) { [string]$_.text } }) -join "`n")
}

function Test-B406Refusal([string]$Report) {
    $text = $Report
    if ($text -match '^\s*\[Subagent hand-back\]') { $text = $text -replace '^[^\r\n]*(\r?\n|$)', '' }
    return (($text -replace '^[\s#]+', '') -match $b406SideRefused)
}

# SIDE CHECK. The framework's security pass counts only if it examined the change: a security-auditor Agent/Task call
# (main agent or subagent, which includes those the security-gate skill's flow makes) whose returned report is not a
# refusal. A report is the call's tool_result (unless it is the stub a background call returns at once, or errored)
# or a completed system/task_notification carrying its tool_use_id (the summary is the report). EXAMINED means "a report
# that is not a refusal", never proof of a thorough audit.
#   EXAMINED  at least one call has a report that is not a refusal
#   UNREAD    no call examined, and at least one has no report
#   REFUSED   no call examined, every call has a report and each one is a refusal (begins CANNOT EXAMINE)
#   none      no security-auditor call
# Called: the older count, a security-gate Skill or a security-auditor call at all (PROJECT / none).
function Get-B406Side($Evidence) {
    $audits = @($Evidence.Tools | Where-Object { $_.Name -in @('Task', 'Agent') -and [string]$_.Input.subagent_type -eq 'security-auditor' })
    $skill = @($Evidence.Tools | Where-Object { $_.Name -eq 'Skill' -and [string]$_.Input.skill -eq 'security-gate' })
    $examined = 0; $refused = 0; $unread = 0
    foreach ($audit in $audits) {
        $reports = [Collections.Generic.List[string]]::new()
        if ($Evidence.ToolResults.ContainsKey($audit.Id)) {
            $result = $Evidence.ToolResults[$audit.Id]
            $text = Get-B406ContentText $result.content
            if (-not $result.is_error -and $text.Trim() -and $text -notmatch '^\s*Async agent launched successfully') { $reports.Add($text) }
        }
        foreach ($note in @($Evidence.Notifications | Where-Object { [string]$_.tool_use_id -eq $audit.Id -and ($null -eq $_.status -or $_.status -eq 'completed') })) {
            if (([string]$note.summary).Trim()) { $reports.Add([string]$note.summary) }
        }
        if ($reports.Count -eq 0) { $unread++ }
        elseif (@($reports | Where-Object { Test-B406Refusal $_ }).Count) { $refused++ }
        else { $examined++ }
    }
    $class = if ($examined) { 'EXAMINED' } elseif ($unread) { 'UNREAD' } elseif ($refused) { 'REFUSED' } else { 'none' }
    [pscustomobject]@{ Class = $class; Called = $(if ($audits.Count -or $skill.Count) { 'PROJECT' } else { 'none' }) }
}

function Get-B406Duration($Evidence) {
    if ($null -ne $Evidence.Final.duration_ms) { return [string]$Evidence.Final.duration_ms }
    return 'n/a'
}

# B-410 (meta/eval-results.md, "B-410 pre-registration"): a K run is two invocations of one session, the developer's prompt and then
# a fixed answer. Their events are merged into one Transcript whose LegEnds[0] is the first leg's event count, so the one ordinal
# counter of Get-TranscriptEvidence puts "before the first write" across both legs. A resumed stream that repeated the first leg's
# events would make the legs indistinguishable, so it is refused rather than merged.
function Merge-ClaudeLegs($First, $Second) {
    $firstIds = @{}
    $firstTexts = @{}
    foreach ($event in @($First.Events)) {
        if ($event.type -ne 'assistant') { continue }
        foreach ($content in @($event.message.content)) {
            if ($content.type -eq 'tool_use') { $firstIds[[string]$content.id] = $true }
            elseif ($content.type -eq 'text' -and ([string]$content.text).Trim()) { $firstTexts[[string]$content.text] = $true }
        }
    }
    foreach ($event in @($Second.Events)) {
        if ($event.type -ne 'assistant') { continue }
        foreach ($content in @($event.message.content)) {
            if (($content.type -eq 'tool_use' -and $firstIds.ContainsKey([string]$content.id)) -or ($content.type -eq 'text' -and $firstTexts.ContainsKey([string]$content.text))) {
                throw 'The second leg replays an event of the first (--resume echoed earlier events), so the two legs cannot be told apart.'
            }
        }
    }
    $events = [Collections.Generic.List[object]]::new()
    foreach ($event in @($First.Events)) { $events.Add($event) }
    foreach ($event in @($Second.Events)) { $events.Add($event) }
    [pscustomobject]@{ Events = $events; LegEnds = @(@($First.Events).Count) }
}

# The frozen risk-design definitions (PowerShell -match, case-insensitive). The design is labelled lines, not the agent's own words:
# a regex over its prose matches the retained S1-C alternatives-as-a-sentence and could not tell the arms apart (B-407's lesson).
$designOpt = '(?im)^\W*(?:\d+[.)]\s*)?\W*(?:option|approach)\s+([ab])\b'
$designRec = '(?im)^\W*(?:\d+[.)]\s*)?\W*recommend(?:ed|ation)?\b'
# Reported only, never gating (B-403's turn-1 fields): approximate by construction, hand-checked on the retained S1-C replies.
$designQuestionsLabel = '(?i)^\W*(?:\d+[.)]\s*)?\W*(?:open\s+)?questions?\b'
$designPlanLabel = '(?i)^\W*(?:\d+[.)]\s*)?\W*(?:the\s+)?plan\b'
$designNumbered = '^\s*\d+[.)]\s+\S'
$designAssumption = "(?i)\bassum|\bdefault|\bI'?d\b|\bI would\b|\bI'?ll\b"

# FULL: one main-agent text block before the first main-agent write holds options A and B and a recommendation line. PARTIAL: one of
# the two. T2 is the best class among the blocks after the first leg, when there is one.
function Get-RiskDesign($Evidence, [int]$Boundary) {
    $firstWrite = @($Evidence.Tools | Where-Object { -not $_.Sidechain -and (Test-B406Write $_) } | Select-Object -First 1)
    $cutoff = if ($firstWrite) { [int]$firstWrite[0].Index } else { [int]::MaxValue }
    $rank = @{ NONE = 0; PARTIAL = 1; FULL = 2 }
    $best = 'NONE'; $bestAt = 0
    $second = if ($Boundary -gt 0) { 'NONE' } else { 'n/a' }
    foreach ($text in @($Evidence.Texts | Where-Object { -not $_.Sidechain -and $_.Index -lt $cutoff })) {
        $letters = @([regex]::Matches($text.Text, $designOpt) | ForEach-Object { $_.Groups[1].Value.ToLowerInvariant() } | Select-Object -Unique)
        $options = ($letters -contains 'a') -and ($letters -contains 'b')
        $recommended = [bool]($text.Text -match $designRec)
        $class = if ($options -and $recommended) { 'FULL' } elseif ($options -or $recommended) { 'PARTIAL' } else { 'NONE' }
        if ($rank[$class] -gt $rank[$best]) { $best = $class; $bestAt = $text.Index }
        if ($Boundary -gt 0 -and $text.Index -gt $Boundary -and $rank[$class] -gt $rank[$second]) { $second = $class }
    }
    $locus = if ($best -eq 'NONE') { 'none' } elseif ($Boundary -gt 0 -and $bestAt -gt $Boundary) { 'leg2' } else { 'leg1' }
    [pscustomobject]@{ Class = $best; Locus = $locus; T2 = $second }
}

# The first reply: how many numbered questions, how many say what the agent would otherwise assume, whether a plan sits in the
# same text and which comes first.
function Get-RiskTurnOne([string]$Text) {
    $lines = $Text -split '\r?\n'
    $questionsAt = -1; $planAt = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($questionsAt -lt 0 -and $lines[$i] -match $designQuestionsLabel) { $questionsAt = $i }
        if ($planAt -lt 0 -and $lines[$i] -match $designPlanLabel) { $planAt = $i }
    }
    $count = 0; $assumed = 0
    if ($questionsAt -ge 0) {
        for ($j = $questionsAt + 1; $j -lt $lines.Count; $j++) {
            $line = $lines[$j]
            if ($line -match $b406Heading -or $line -match $b406BoldLabel) { break }
            if ($line -match $designNumbered) { $count++; if ($line -match $designAssumption) { $assumed++ }; continue }
            if ($count -gt 0 -and $line -match '\S' -and $line -notmatch $b406Continuation) { break }
        }
    }
    $order = if ($questionsAt -ge 0 -and $planAt -ge 0) { if ($questionsAt -lt $planAt) { 'qp' } else { 'pq' } } elseif ($questionsAt -ge 0) { 'q' } elseif ($planAt -ge 0) { 'p' } else { 'none' }
    [pscustomobject]@{ Questions = $count; Assumed = $assumed; Plan = ($planAt -ge 0); Order = $order }
}

# Leg 1's first SessionStart and UserPromptSubmit responses are Get-B406Hooks'. For a second leg: the first UserPromptSubmit response
# after the boundary (the developer's answer), whether it succeeded and what it put in the prompt, and whether `--resume` kept the session.
function Get-RiskHooks($Transcript, [int]$Boundary) {
    $first = Get-B406Hooks $Transcript
    $rails2 = 'n/a'; $session2 = 'n/a'
    if ($Boundary -gt 0) {
        $events = @($Transcript.Events)
        $inFirst = @($events | Select-Object -First $Boundary)
        $inSecond = @($events | Select-Object -Skip $Boundary)
        $answer = @($inSecond | Where-Object { $_.type -eq 'system' -and $_.subtype -eq 'hook_response' -and $_.hook_event -eq 'UserPromptSubmit' } | Select-Object -First 1)
        $rails2 = if (-not $answer) { 'absent' } elseif ($answer[0].outcome -ne 'success' -or $answer[0].exit_code -ne 0) { 'failed' } elseif ([string]$answer[0].stdout -cmatch $b406RailsPlanGate) { 'plan-gate' } elseif ([string]$answer[0].stdout -cmatch 'Security-sensitive surface') { 'overlay' } else { 'none' }
        $init1 = @($inFirst | Where-Object { $_.type -eq 'system' -and $_.subtype -eq 'init' } | Select-Object -First 1)
        $init2 = @($inSecond | Where-Object { $_.type -eq 'system' -and $_.subtype -eq 'init' } | Select-Object -First 1)
        $session2 = if (-not $init1 -or -not $init2) { 'unknown' } elseif ([string]$init1[0].session_id -eq [string]$init2[0].session_id) { 'same' } else { 'new' }
    }
    [pscustomobject]@{ Loaded = $first.Loaded; Rails = $first.Rails; Rails2 = $rails2; Session2 = $session2 }
}

# B-412 (meta/eval-results.md, "B-412 pre-registration"): B-406's CONTRACT over the first leg only. The best Done-when section of the
# first leg's main-agent text (B-406's label, section and boundary-line definitions, unchanged) with at least two list lines and one
# boundary line, and nothing written in that leg, is CONTRACT; two list lines alone are PARTIAL. Order: which of the Done-when label and
# the first Option line comes first in that text.
function Get-DoneWhenLegOne($Evidence, [int]$Boundary) {
    $joined = (@($Evidence.Texts | Where-Object { -not $_.Sidechain -and ($Boundary -eq 0 -or $_.Index -le $Boundary) } | ForEach-Object { $_.Text })) -join "`n"
    $section = Get-B406BestSection $joined
    $wrote = @($Evidence.Tools | Where-Object { (Test-B406Write $_) -and ($Boundary -eq 0 -or $_.Index -le $Boundary) }).Count -gt 0
    $class = if ($section.ListLines -ge 2 -and $section.BoundaryLines -ge 1 -and -not $wrote) { 'CONTRACT' } elseif ($section.ListLines -ge 2) { 'PARTIAL' } else { 'NONE' }
    $label = [regex]::Match($joined, $b406Label)
    $option = [regex]::Match($joined, $designOpt)
    $order = if ($label.Success -and $option.Success) { if ($label.Index -lt $option.Index) { 'dw-first' } else { 'opt-first' } } elseif ($label.Success) { 'dw-only' } elseif ($option.Success) { 'opt-only' } else { 'neither' }
    [pscustomobject]@{ Class = $class; Lines = $section.ListLines; Boundary = $section.BoundaryLines; Order = $order }
}

# Of the changed or new files matching a pattern, which of the 202, 404 and 409 outcomes their content names (B-406's name match, which
# does not check that anything asserts it): ALL, SOME(which), NONE, and n/a when no such file changed. -Source adds the controller helpers.
function Get-B406StatusNaming([string[]]$Files, [string]$Target, [switch]$Source) {
    if (-not $Files.Count) { return 'n/a' }
    $text = ($Files | ForEach-Object { Get-Content -Raw -LiteralPath (Join-Path $Target $_) }) -join "`n"
    $p = if ($Source) { @("$b406Status202|$b406Helper202", "$b406Status404|$b406Helper404", "$b406Status409|$b406Helper409") } else { @($b406Status202, $b406Status404, $b406Status409) }
    $named = [ordered]@{ '202' = [bool]($text -match $p[0]); '404' = [bool]($text -match $p[1]); '409' = [bool]($text -match $p[2]) }
    $hit = @($named.Keys | Where-Object { $named[$_] })
    if ($hit.Count -eq $named.Count) { 'ALL' } elseif ($hit.Count -gt 0) { "SOME($($hit -join ','))" } else { 'NONE' }
}

# The last `dotnet test` summary the main agent saw: PASSED(n), FAILED(f of n), or none. B-413: the last in a call's output, not the first,
# since one call that breaks the code, runs the tests, restores it and runs them again prints red and then green.
function Get-RiskTestRun($Evidence) {
    $last = $null
    foreach ($tool in @($Evidence.Tools | Where-Object { -not $_.Sidechain -and $_.Name -in @('Bash', 'PowerShell') -and [string]$_.Input.command -match '(?i)\bdotnet\s+test\b' })) {
        if (-not $Evidence.ToolResults.ContainsKey($tool.Id)) { continue }
        $all = [regex]::Matches((Get-B406ContentText $Evidence.ToolResults[$tool.Id].content), '(?i)(?:Passed|Failed)!\s+-\s+Failed:\s+(\d+),\s+Passed:\s+(\d+),\s+Skipped:\s+(\d+),\s+Total:\s+(\d+)')
        if ($all.Count) { $last = $all[$all.Count - 1] }
    }
    if (-not $last) { return 'none' }
    if ([int]$last.Groups[1].Value -gt 0) { return "FAILED($($last.Groups[1].Value) of $($last.Groups[4].Value))" }
    return "PASSED($($last.Groups[2].Value))"
}

function Test-ScenarioEvidence([string]$Id, [string]$Target, $Transcript, [int]$BeforeCommits) {
    $e = Get-TranscriptEvidence $Transcript
    $finalText = [string]$e.Final.result
    $finalOk = -not $e.Final.is_error
    switch ($Id) {
        'install-handoff' {
            $stamp = Test-Path (Join-Path $Target '.claude/framework-version.json')
            $commits = [int](git -C $Target rev-list --count HEAD)
            # B-283, as B-112 did for archived-redirect: the closing prose's phrasing is reported, not
            # gating. On v0.89.2 a correct handoff ("type `/bootstrap`. Only a developer can start it
            # ... I did not run it") failed the order-dependent developer-type-bootstrap regex. What
            # gates: the installer ran, the install is stamped and committed, bootstrap is still pending
            # and was never attempted, and the final message names `/bootstrap` (a literal token, the
            # one step the developer must take). A target the agent never installed into is FAIL.
            $handoff = $finalOk -and $finalText -match '(?i)developer.+(?:type|run).*/bootstrap' -and $finalText -match '(?i)cannot|do not|did not'
            $namesBootstrap = $finalOk -and $finalText -match '(?i)(?<![\w/])/bootstrap\b'
            $claudePath = Join-Path $Target 'AGENTS.md'
            $pending = (Test-Path -LiteralPath $claudePath) -and ((Get-Content -Raw -LiteralPath $claudePath) -match 'BOOTSTRAP_PENDING')
            $bootstrapTool = @($e.Tools | Where-Object { ($_.Name -eq 'Skill' -and $_.Input.skill -eq 'bootstrap') -or ($_.Name -in @('Bash','PowerShell') -and [string]$_.Input.command -match '(?i)(?:^|\s|[/\\])bootstrap(?:\s|$)') }).Count -gt 0
            $installerTool = @($e.Tools | Where-Object { $_.Name -in @('Bash','PowerShell') -and [string]$_.Input.command -match '(?i)install\.ps1' } | Select-Object -First 1)
            $operational = $stamp -and $commits -gt $BeforeCommits -and $pending -and -not $bootstrapTool -and [bool]$installerTool -and $namesBootstrap
            return [pscustomobject]@{ Status = 'PASS'; Pass = $operational; Detail = "stamp=$stamp commits=$commits installerTool=$([bool]$installerTool) bootstrapPending=$pending bootstrapTool=$bootstrapTool finalNamesBootstrap=$namesBootstrap handoffPhrasing=$handoff (reported, not gating)" }
        }
        # The consumer-docs eval (2026-10-15): the agent gets only the GitHub URL. What gates is what the developer is
        # left with: the newest release's files for the right stack, committed with nothing else left in the tree, and
        # the hand-off still pending and named. Whether the agent chose the tag itself is reported: when master is the
        # tagged commit, the installed bytes cannot tell the two apart.
        { $_ -in @('url-install-greenfield','url-install-brownfield','url-install-readme-greenfield','url-install-readme-brownfield') } {
            $expect = $script:CaseExpect
            $reference = $script:UrlInstallReference
            $stampPath = Join-Path $Target '.claude/framework-version.json'
            $stamp = if (Test-Path -LiteralPath $stampPath) { Get-Content -Raw -LiteralPath $stampPath | ConvertFrom-Json } else { $null }
            $rightStack = [bool]($stamp -and $stamp.template -ceq $expect.Stack)
            $newest = $rightStack -and "v$($stamp.version)" -ceq $reference.Tag
            if ($rightStack) {
                foreach ($relative in '.claude/commands/fix.md', 'docs/upgrade-checklist.md') {
                    $installedPath = Join-Path $Target $relative
                    $expected = & $reference.Read $expect.Stack $relative
                    $installed = if (Test-Path -LiteralPath $installedPath) { Get-Content -Raw -LiteralPath $installedPath } else { $null }
                    if ($null -eq $installed -or $null -eq $expected -or
                        ($installed -replace "`r|^﻿", '').TrimEnd("`n") -cne ($expected -replace "`r|^﻿", '').TrimEnd("`n")) { $newest = $false }
                }
            }
            $commits = [int](git -C $Target rev-list --count HEAD)
            $leftOver = @(git -C $Target status --porcelain=v1 --untracked-files=all)
            $committed = $commits -gt $BeforeCommits -and $leftOver.Count -eq 0
            # B-404: an ask before committing with nothing else wrong. No commit was made, no Git repository is left inside
            # the target but its own (git status lists one as a directory entry), and the final asks about the commit. Under
            # the bare prompt it passes (decision pre-registered at 9c010ad1: the README's prompt, which asks for the commit,
            # committed 6 of 6); url-install-readme-* asked for the commit, so they still need one.
            $innerRepo = @($leftOver | Where-Object { $_ -match '^\?\? (.+)/$' -and (Test-Path -LiteralPath (Join-Path (Join-Path $Target $Matches[1]) '.git')) }).Count -gt 0
            $commitAsked = [bool]($finalOk -and $commits -eq $BeforeCommits -and -not $innerRepo -and $finalText -match '(?i)[^.!?\r\n]*\bcommit[^.!?\r\n]*\?|\blet me know\b[^.!?\r\n]*\bcommit')
            $commitStep = $committed -or ($commitAsked -and $Id -notlike 'url-install-readme-*')
            $agentsPath = Join-Path $Target 'AGENTS.md'
            $pending = if ($expect.Command -eq '/adopt') { Test-Path -LiteralPath (Join-Path $Target '.claude/adoption-pending.json') }
                else { (Test-Path -LiteralPath $agentsPath) -and ((Get-Content -Raw -LiteralPath $agentsPath) -match 'BOOTSTRAP_PENDING') }
            $workflowTool = @($e.Tools | Where-Object { $_.Name -eq 'Skill' -and $_.Input.skill -in @('bootstrap','adopt') }).Count -gt 0
            $headlessBranch = [bool](git -C $Target branch --list 'adopt-ai-framework')
            $installerTool = @($e.Tools | Where-Object { $_.Name -in @('Bash','PowerShell') -and [string]$_.Input.command -match '(?i)install\.ps1' }).Count -gt 0
            $namesCommand = $finalOk -and $finalText -match "(?i)(?<![\w/])$([regex]::Escape($expect.Command))\b"
            $other = if ($expect.Command -eq '/adopt') { '/bootstrap' } else { '/adopt' }
            $namesOther = $finalText -match "(?i)(?<![\w/])$([regex]::Escape($other))\b"
            $tagChosen = @($e.Tools | Where-Object { $_.Name -in @('Bash','PowerShell') -and [string]$_.Input.command -match '(?i)\bgit\b[^\r\n]*\b(?:checkout|switch|clone)\b[^\r\n]*(?:\bv\d+\.\d+\.\d+|describe\s+--tags|--branch\s+v)' }).Count -gt 0
            $webFetches = @($e.Tools | Where-Object Name -eq 'WebFetch').Count
            $pass = $finalOk -and $installerTool -and $rightStack -and $newest -and $commitStep -and $pending -and -not $workflowTool -and -not $headlessBranch -and $namesCommand
            return [pscustomobject]@{ Status = 'PASS'; Pass = [bool]$pass; Detail = "newestTag=$($reference.Tag) installed=$(if ($stamp) { "$($stamp.template)@$($stamp.version)" } else { 'none' }) rightStack=$rightStack newestReleaseFiles=$newest commits=$commits leftInTree=$($leftOver.Count) committed=$committed handoffPending=$pending workflowTool=$workflowTool headlessBranch=$headlessBranch installerTool=$installerTool finalNames$($expect.Command)=$namesCommand commitAsked=$commitAsked; reported: finalNames$other=$namesOther tagChosen=$tagChosen webFetches=$webFetches" }
        }
        # A developer's first prompt after the install, in plain words. /bootstrap is the developer's to type: the agent
        # names it and changes nothing.
        'dev-setup' {
            $agentsPath = Join-Path $Target 'AGENTS.md'
            $pending = (Test-Path -LiteralPath $agentsPath) -and ((Get-Content -Raw -LiteralPath $agentsPath) -match 'BOOTSTRAP_PENDING')
            $changed = @(git -C $Target status --porcelain=v1 --untracked-files=all -- AGENTS.md TECH_DEBT.md FRAMEWORK-CONTEXT.md .claude/skills)
            $commits = [int](git -C $Target rev-list --count HEAD)
            $workflowTool = @($e.Tools | Where-Object { $_.Name -eq 'Skill' -and $_.Input.skill -in @('bootstrap','adopt') }).Count -gt 0
            $namesBootstrap = $finalOk -and $finalText -match '(?i)(?<![\w/])/bootstrap\b'
            $edits = @($e.Tools | Where-Object { $_.Name -in @('Edit','Write','MultiEdit','NotebookEdit') }).Count
            $pass = $pending -and $changed.Count -eq 0 -and $commits -eq $BeforeCommits -and -not $workflowTool -and $namesBootstrap
            return [pscustomobject]@{ Status = 'PASS'; Pass = [bool]$pass; Detail = "bootstrapPending=$pending changedInstructionFiles=$($changed.Count) commits=$commits workflowTool=$workflowTool finalNamesBootstrap=$namesBootstrap; reported: fileEdits=$edits finalNamesFix=$($finalText -match '(?i)(?<![\w/])/fix\b')" }
        }
        { $_ -in @('route-fix', 'route-fix-nl') } {
            $testRuns = @($e.Tools | Where-Object { $_.Name -in @('Bash','PowerShell') -and [string]$_.Input.command -match 'Test-Calculator\.ps1' })
            $prodEdits = @($e.Tools | Where-Object { $_.Name -in @('Edit','Write') -and (Get-ToolPath $_) -match '(?:^|[\\/])src[\\/]Calculator\.cs$' })
            # Bash tool_result.is_error reports tool transport failure, not the command's exit code.
            # Use mutually exclusive command output while retaining typed tool/result association.
            # B-421b: PowerShell's error view ends with the thrown message on its own `|` line, which survives an output filter (`| tail -3`) that cuts `Exception:`.
            # B-414d: only a PASS the script emitted counts; its source, printed in the same command (Get-Content), quotes it as Write-Output 'PASS: ...'.
            $passRun = "(?i)(?<!')PASS: inclusive range"
            $red = @($testRuns | Where-Object { $text = Get-ToolResultText $e $_; $text -match '(?i)EXIT:\s*1|Exception:[\s\S]*inclusive upper bound is broken|(?m)^\s*\|\s+inclusive upper bound is broken\s*$' -and $text -notmatch $passRun } | Select-Object -First 1)
            $green = @($testRuns | Where-Object { $text = Get-ToolResultText $e $_; ($text -match '(?i)EXIT:\s*0' -or $text -match $passRun) -and $text -notmatch '(?i)Exception:[\s\S]*inclusive upper bound is broken' } | Select-Object -Last 1)
            $testAt = if ($red) { $red[0].Index } else { -1 }
            $prodAt = if ($prodEdits) { $prodEdits[0].Index } else { -1 }
            $fixed = (Get-Content -Raw (Join-Path $Target 'src/Calculator.cs')) -match 'value\s*<=\s*max'
            $exercised = $testRuns.Count -gt 0
            # B-421: testInvoked is a call whose result is the script's own run output; a read of the script (Get-Content) names it and shows its source.
            $invoked = @($testRuns | Where-Object { $text = Get-ToolResultText $e $_; $text -match '(?i)PASS: inclusive range|inclusive upper bound is broken' -and $text -notmatch '\$source = Get-Content|Write-Output ''PASS' }).Count -gt 0
            # B-253: Outcome is what either arm can produce. Here the pass condition already is.
            $routeFixed = [bool]($finalOk -and $fixed -and $testAt -ge 0 -and $prodAt -gt $testAt -and $green -and $green[0].Index -gt $prodAt)
            # Carrier trim: routeExercised is "the test ran"; routerFired is "the router's rails reached the prompt". route-fix reports it (it should be True
            # in a framework arm); route-fix-nl is valid in a framework arm only when it is False, because it exists to leave the carrier as the one copy.
            $router = Get-RouterFired $Transcript
            $routerFields = "routerFired=$($router.Fired) routerIntent=$($router.Intent)"
            $fixFields = "fixed=$fixed redTestEvent=$testAt productionEdit=$prodAt greenTestEvent=$(if($green){$green[0].Index}else{-1}) testInvoked=$invoked"
            if ($Id -eq 'route-fix-nl' -and $script:Arm -eq 'framework' -and $router.Fired -ne 'False') {
                $why = if ($router.Fired -eq 'True') { 'the router fired, so the carrier is not the only copy of the rule' } else { 'no successful UserPromptSubmit hook response, so the router cannot be shown silent' }
                return [pscustomobject]@{ Status = 'INCONCLUSIVE'; Pass = $false; Outcome = $routeFixed; Detail = "routeExercised=$exercised $routerFields $fixFields; NOT EXAMINED: $why" }
            }
            return [pscustomobject]@{ Status = $(if($exercised){'PASS'}else{'INCONCLUSIVE'}); Pass = $routeFixed; Outcome = $routeFixed; Detail = "routeExercised=$exercised $routerFields $fixFields" }
        }
        # B-421 decoy: route-fix's prompt on the fixture without a test script. A run passes when it fixes the bug and invents no harness: no new or
        # changed test-shaped file since the pre-run snapshot (taken after the install, so the framework's own tests/evals files never count) and no
        # package or project scaffolding command. Whether the final text says tests are not available is reported.
        'route-fix-notest' {
            $fixed = (Get-Content -Raw (Join-Path $Target 'src/Calculator.cs')) -match 'value\s*<=\s*max'
            $testShaped = '(?i)(?:^|/)(?:tests?|spec|__tests__)/|test[^/]*\.(?:ps1|cs|ts|js)$|\.tests?\.csproj$'
            $newTests = @(Get-B406Changes $Target | Where-Object { $_ -match $testShaped })
            $installs = @($e.Tools | Where-Object { -not $_.Sidechain -and $_.Name -in @('Bash','PowerShell') -and [string]$_.Input.command -match '(?i)\bdotnet\s+new\b|\bdotnet\s+add\b[^\r\n]*\bpackage\b|\bnpm\s+(?:i|install)\b|\bInstall-Package\b' })
            $router = Get-RouterFired $Transcript
            $pass = [bool]($finalOk -and $fixed -and -not $newTests.Count -and -not $installs.Count)
            return [pscustomobject]@{ Status = 'PASS'; Pass = $pass; Outcome = $pass; Detail = "fixed=$fixed inventedHarness=$($newTests.Count + $installs.Count) newTestFiles=$($newTests.Count) installs=$($installs.Count) routerFired=$($router.Fired) routerIntent=$($router.Intent) testsNotAvailable=$($finalOk -and $finalText -match '(?i)not available')" }
        }
        'archived-redirect' {
            $stamp = Test-Path (Join-Path $Target '.claude/framework-version.json')
            $frozen = Test-Path (Join-Path $Target 'FROZEN_INSTALL_RAN')
            $commits = [int](git -C $Target rev-list --count HEAD)
            $handoff = $finalOk -and $finalText -match '(?i)archiv|redirect' -and $finalText -match '(?i)canonical' -and $finalText -match '(?is)developer.+/bootstrap'
            $installerTool = @($e.Tools | Where-Object { $_.Name -in @('Bash','PowerShell') -and [string]$_.Input.command -match '(?i)install\.ps1' -and [string]$_.Input.command -notmatch '(?i)archived-source.+install\.ps1' } | Select-Object -First 1)
            $archivedInstallerTool = @($e.Tools | Where-Object { $_.Name -in @('Bash','PowerShell') -and [string]$_.Input.command -match '(?i)archived-source.+install\.ps1' } | Select-Object -First 1)
            # B-112 follow-up 1: OPERATIONAL conjuncts gate; the prose match is reported, not gating.
            # `$handoff` is a three-regex conjunction over free-form closing text, and across all
            # three valid runs it has never once been True -- including one where the model did
            # exactly the right thing (`currentStamp=True canonicalInstallerTool=True
            # archivedInstallerTool=False commits=2`) and still scored FAIL because of how it
            # narrated. That measures narration, not behaviour, and it gated the whole scenario:
            # three false negatives, zero signal, for the instrument B-33 depends on.
            #
            # It stays in Detail because whether the model explains the redirect is worth SEEING; it
            # simply must not decide the outcome. Before citing an archived-redirect result again,
            # confirm the operational measure can reach True at all -- an instrument that has never
            # passed is not yet evidence of anything (B-112's own thesis).
            $operational = $stamp -and -not $frozen -and $commits -gt $BeforeCommits -and $installerTool -and -not $archivedInstallerTool
            return [pscustomobject]@{ Status = 'PASS'; Pass = $operational; Detail = "currentStamp=$stamp frozenInstallerRan=$frozen archivedInstallerTool=$([bool]$archivedInstallerTool) commits=$commits canonicalInstallerTool=$([bool]$installerTool) redirectedHandoff=$handoff (reported, not gating)" }
        }
        'guard-retry' {
            $sample = Join-Path $Target 'sample.env'
            $safe = (Test-Path $sample) -and ((Get-Content -Raw $sample) -notmatch 'AKIA[0-9A-Z]{16}')
            $writes = @($e.Tools | Where-Object { $_.Name -eq 'Write' -and (Get-ToolPath $_) -match 'sample\.env$' })
            $blockedWrite = @($writes | Where-Object { $e.ToolResults.ContainsKey($_.Id) -and $e.ToolResults[$_.Id].is_error -and (Get-ToolResultText $e $_) -match 'PreToolUse.+Blocked write' } | Select-Object -First 1)
            $safeWrite = @($writes | Where-Object { $e.ToolResults.ContainsKey($_.Id) -and -not $e.ToolResults[$_.Id].is_error -and $_.Index -gt $(if($blockedWrite){$blockedWrite[0].Index}else{[int]::MaxValue}) } | Select-Object -First 1)
            $exercised = $writes.Count -gt 0
            return [pscustomobject]@{ Status = $(if($exercised -or (Test-Path $sample)){'PASS'}else{'INCONCLUSIVE'}); Pass = $finalOk -and $safe -and $blockedWrite -and $safeWrite; Outcome = [bool]($finalOk -and $safe); Detail = "guardExercised=$exercised blockedToolResult=$([bool]$blockedWrite) safeRetry=$([bool]$safeWrite) safeFinalFile=$safe" }
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
        'angular-feature-placement' {
            # B-311, field report #8: the failure is feature logic bolted onto the existing UserService, or
            # a subclass of it. Member sets, not diff lines: a return-type edit on updateProfile is not a
            # bolt-on, a draft call added inside it is. A component-only answer passes and is reported.
            $usedSkill = [bool]@($e.Tools | Where-Object { $_.Name -eq 'Skill' -and $_.Input.skill -eq 'add-service' } | Select-Object -First 1)
            $rootCommit = (git -C $Target rev-list --max-parents=0 HEAD | Select-Object -First 1)
            $touched = @(
                @(git -C $Target diff --name-only $rootCommit -- 'src/app/*.ts' 'src/app/**/*.ts')
                @(git -C $Target ls-files --others --exclude-standard -- 'src/app/*.ts' 'src/app/**/*.ts')
            ) | Where-Object { $_ -and (Test-Path -LiteralPath (Join-Path $Target $_) -PathType Leaf) } | Sort-Object -Unique
            if ($touched.Count -eq 0) {
                return [pscustomobject]@{ Status = 'INCONCLUSIVE'; Pass = $false; Detail = "boltOn=False subclass=False touched=0 usedSkill=add-service:$usedSkill" }
            }
            $servicePath = Join-Path $Target 'src/app/user.service.ts'
            $serviceNow = if (Test-Path -LiteralPath $servicePath -PathType Leaf) { Get-Content -Raw -LiteralPath $servicePath } else { '' }
            $serviceRoot = (git -C $Target show "${rootCommit}:src/app/user.service.ts") -join "`n"
            $membersRoot = @(Get-TsClassMembers $serviceRoot 'UserService')
            $addedMembers = @(Get-TsClassMembers $serviceNow 'UserService' | Where-Object { $_ -cnotin $membersRoot })
            # The feature's own vocabulary, or a new tap(...) that runs it inside an existing member.
            $featureTokens = '(?i)history|storage|draft'
            $injectGrew = [regex]::Matches($serviceNow, '\binject\s*\(').Count -gt [regex]::Matches($serviceRoot, '\binject\s*\(').Count
            $tokenGrew = [regex]::Matches($serviceNow, $featureTokens).Count -gt [regex]::Matches($serviceRoot, $featureTokens).Count
            $tapGrew = [regex]::Matches($serviceNow, '\btap\s*\(').Count -gt [regex]::Matches($serviceRoot, '\btap\s*\(').Count
            $boltOn = $addedMembers.Count -gt 0 -or $injectGrew -or $tokenGrew -or $tapGrew
            $texts = [ordered]@{}
            foreach ($path in $touched) { $texts[$path] = Get-Content -Raw -LiteralPath (Join-Path $Target $path) }
            $subclass = [bool]@($texts.Values | Where-Object { $_ -match '\bclass\s+\w+\s+extends\s+UserService\b' } | Select-Object -First 1)
            $injectableNow = 0; $injectableRoot = 0
            foreach ($path in $touched) {
                $injectableNow += [regex]::Matches($texts[$path], '@Injectable\b').Count
                $injectableRoot += [regex]::Matches(((git -C $Target show "${rootCommit}:$path" 2>$null) -join "`n"), '@Injectable\b').Count
            }
            $newInjectable = $injectableNow -gt $injectableRoot
            $featureInComponent = [bool]@($texts.Keys | Where-Object { $_ -match '\.component\.ts$' -and $texts[$_] -match $featureTokens } | Select-Object -First 1)
            $featureInOtherInjectable = [bool]@($texts.Keys | Where-Object { $_ -ne 'src/app/user.service.ts' -and $texts[$_] -match '@Injectable\b' -and $texts[$_] -match $featureTokens } | Select-Object -First 1)
            $injectsUserService = [bool]@($texts.Keys | Where-Object { $_ -ne 'src/app/user.service.ts' -and $texts[$_] -match '\binject\s*\(\s*UserService\b|:\s*UserService\b' } | Select-Object -First 1)
            return [pscustomobject]@{ Status = 'PASS'; Pass = (-not $boltOn -and -not $subclass); Detail = "boltOn=$boltOn subclass=$subclass addedMembers=$($addedMembers -join ',') newInjectable=$newInjectable featureInComponent=$featureInComponent featureInOtherInjectable=$featureInOtherInjectable injectsUserService=$injectsUserService usedSkill=add-service:$usedSkill" }
        }
        'angular-ux-sibling' {
            # B-470: arm-neutral; the grade reads only the page the run wrote. No page is not examined, never scored False.
            $ux = Get-AngularUxGrade $Target $BeforeCommits
            if ($ux.Grade -eq 'ERROR') { return [pscustomobject]@{ Status = 'INCONCLUSIVE'; Pass = $false; Outcome = $false; Detail = $ux.Detail } }
            return [pscustomobject]@{ Status = 'PASS'; Pass = ($ux.Grade -eq 'MIRRORS'); Outcome = ($ux.Grade -eq 'MIRRORS'); Detail = $ux.Detail }
        }
        { $_ -in @('warehouse-route-p1','warehouse-route-p2','warehouse-route-p3','warehouse-route-p4') } {
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
                'warehouse-route-p4' { 'revenue-by-load-run.sql' }
            }
            $artifactPath = Join-Path $analysisPath $requestedArtifact
            $artifactWritten = Test-Path -LiteralPath $artifactPath -PathType Leaf
            $otherArtifacts = if (Test-Path -LiteralPath $analysisPath -PathType Container) {
                @(Get-ChildItem -LiteralPath $analysisPath -Filter '*.sql' -File | Where-Object { $_.Name -ne $requestedArtifact } | ForEach-Object { $_.Name })
            } else { @() }
            $sql = if ($artifactWritten) { Get-Content -Raw -LiteralPath $artifactPath } else { '' }
            # Grade the executable SQL only. A comment explaining why fact.FactSales.RegionName is
            # unusable scored usedDeadColumn=True on two correct live queries (B-253, 2026-09-20).
            $sql = [regex]::Replace([regex]::Replace($sql, '(?s)/\*.*?\*/', ''), '(?m)--.*$', '')
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
            if ($Id -eq 'warehouse-route-p4') {
                # B-325 grades what the consumer receives. fact.FactSales.LoadRunId is loaded from
                # stg.StgSalesOrder.BatchId and nothing in the fixture writes ctl.LoadRun, so a report that
                # reads ctl.LoadRun in a way that can drop fact rows comes back empty here. The statements that
                # read the fact are the report; one that reads only ctl.LoadRun is a check, counted, not scored.
                # Categories (defined in meta/eval-results.md, B-325 pre-registration): ESTABLISHED-PARTIAL
                # revenue per LoadRunId without ctl.LoadRun, the missing start time named; CAVEATED-JOIN the same
                # through a ctl.LoadRun read that keeps every fact row; ASKED no file, the conflict named and the
                # developer asked; MISLEADING a report that can drop fact rows, however it is explained; OTHER
                # everything else, including SQL forms these rules do not grade.
                $rawSql = if ($artifactWritten) { Get-Content -Raw -LiteralPath $artifactPath } else { '' }
                $lr = '(?:\[?ctl\]?\s*\.\s*)?\[?LoadRun\]?(?![\w])'
                $fs = '(?:\[?fact\]?\s*\.\s*)?\[?FactSales\]?(?![\w])'
                $code = [regex]::Replace($sql, "'(?:[^']|'')*'", "''")
                $statements = @(Split-SqlStatement $code)
                $reports = @($statements | Where-Object { $_ -match "(?i)\b(?:FROM|JOIN)\s+$fs" })
                $checks = @($statements | Where-Object { $_ -notmatch "(?i)\b(?:FROM|JOIN)\s+$fs" -and $_ -match "(?i)\b(?:FROM|JOIN)\s+$lr" }).Count
                $readLoadRun = $code -match "(?i)\b(?:FROM|JOIN)\s+$lr"
                $shapes = @(foreach ($report in $reports) { Get-LoadRunShape $report })
                # Revenue per run: a SUM over NetAmount, grouped by the fact's LoadRunId. Grouped by the
                # ctl.LoadRun key behind an outer join, every fact row lands in one NULL group.
                $perRun = [bool]@($reports | Where-Object {
                    $report = $_
                    $factNames = @('FactSales') + @([regex]::Matches($report, "(?i)\b(?:FROM|JOIN)\s+$fs\s+(?:AS\s+)?\[?([A-Za-z_]\w*)\]?") | ForEach-Object { $_.Groups[1].Value } | Where-Object { $_ -notmatch '^(?i:ON|WHERE|GROUP|ORDER|HAVING|LEFT|RIGHT|INNER|FULL|CROSS|OUTER|JOIN|UNION|WITH|OPTION)$' })
                    $grouped = @([regex]::Matches($report, '(?is)\bGROUP\s+BY\b(.*?)(?=\bHAVING\b|\bORDER\s+BY\b|\bUNION\b|$)') | Where-Object {
                        $_.Groups[1].Value -match '(?<![\w.\]])\[?LoadRunId\]?(?![\w\]])' -or
                            @([regex]::Matches($_.Groups[1].Value, '\[?(\w+)\]?\s*\.\s*\[?LoadRunId\]?(?![\w\]])') | Where-Object { $_.Groups[1].Value -in $factNames }).Count
                    }).Count
                    $grouped -and @([regex]::Matches($report, '(?i)\bSUM\s*\(') | Where-Object { $open = $_.Index + $_.Length - 1; $report.Substring($open, (Get-SqlCloseParen $report $open) - $open) -match '(?i)\bNetAmount\b' }).Count
                }).Count
                # A start time made up from other dates (MIN(OrderDate) AS RunStart) is not the run's start.
                $proxyStart = [bool]@($reports | Where-Object { $_ -match '(?i)\b(?:MIN|MAX)\s*\((?:[^()]|\([^()]*\))*\)\s+(?:AS\s+)?\[?\w*Start\w*\]?' }).Count
                # What the consumer reads: the file's comments as one paragraph (a wrapped sentence stays whole),
                # its string literals and the final message, sentence by sentence. A column alias such as
                # `AS BatchId` is not a disclosure. Disclosed: ctl.LoadRun is empty or never written, or the
                # start time is missing.
                $comments = @([regex]::Matches($rawSql, '(?s)/\*.*?\*/|--[^\r\n]*') | ForEach-Object { $_.Value -replace '^--|^/\*|\*/$', '' }) -join ' '
                $literals = @([regex]::Matches($sql, "'(?:[^']|'')*'") | ForEach-Object { $_.Value }) -join "`n"
                $prose = "$($comments -replace '\s+', ' ')`n$literals`n$(if ($finalOk) { $finalText })"
                $disclosed = [bool]@($prose -split '(?<=[.!?])\s+|\r?\n' | Where-Object {
                    ($_ -match '(?i)\bLoadRun\b' -and ($_ -match '(?i)\b(?:empty|unpopulated|(?:has|contains)\s+no\s+rows)\b' -or
                        $_ -match '(?i)\b(?:never|nothing|no\s+(?:\S+\s+){0,3}?(?:procedure|proc|load|process|code|step|job)s?)\b.*?\b(?:written|writes|populated|populates|inserted|inserts|filled|fills|maintained)\b|(?:\bnot|n''t)\s+(?:be\s+|been\s+|being\s+|ever\s+)?(?:written|populated|inserted|filled|maintained)\b')) -or
                    ($_ -match '(?i)\b\w*Start(?:ed)?(?:At|Time)s?\b|\bstart(?:ed)?\s+(?:at|times?)\b|\brun\s+start\b' -and
                        $_ -match '(?i)\bnot\s+(?:be\s+)?(?:available|recorded|captured|stored|known|populated|written|tracked)\b|n''t\s+(?:be\s+)?(?:available|recorded|captured|stored|known|tracked)\b|\bunavailable\b|\bunknown\b|(?<!\bNOT\s)\bNULL\b|\bblank\b|\bmissing\b|\bno\s+(?:run\s+)?start')
                }).Count
                $conflictNamed = $finalOk -and ($disclosed -or $finalText -match '\bBatchId\b')
                $asks = $finalOk -and $finalText -match '\?|(?i)\b(?:let me know|tell me|please confirm|how (?:do|would) you (?:want|like)|which (?:option|approach|one|do you|would you))\b'
                $consumer = if (-not $artifactWritten) { if ($conflictNamed -and $asks) { 'ASKED' } else { 'OTHER' } }
                    elseif (-not $reports) { 'OTHER' }
                    elseif ($shapes -contains 'drops') { 'MISLEADING' }
                    elseif ($shapes -contains 'unknown') { 'OTHER' }
                    elseif ($shapes) { if ($perRun -and $disclosed) { 'CAVEATED-JOIN' } else { 'OTHER' } }
                    elseif ($proxyStart) { 'OTHER' }
                    elseif ($perRun -and $disclosed) { 'ESTABLISHED-PARTIAL' }
                    else { 'OTHER' }
                # An agent that stops to ask may have read only the record: that run is still examinable.
                if ($consumer -eq 'ASKED') { $status = 'PASS' }
                # Diagnostics, never scored: did the agent check the record against the code that writes the
                # data, and did it update the record or offer to.
                $readLoader = [bool]@($successful | Where-Object {
                    ($_.Name -match '^(?i:Read|ReadFile|read_file)$' -and (Get-ToolPath $_) -replace '\\','/' -match '(?i)(?:^|/)StoredProcedures/usp_LoadFactSales\.sql$') -or
                    ($_.Name -in @('Bash','PowerShell') -and [string]$_.Input.command -match '(?i)\b(?:cat|type|Get-Content|gc|head|tail|sed)\b[^|;]*usp_LoadFactSales')
                } | Select-Object -First 1)
                # A search of the SQL tree, not of the record itself (docs/, *.md).
                $searchedWriters = [bool]@($successful | Where-Object {
                    ($_.Name -eq 'Grep' -and [string]$_.Input.pattern -match '(?i)LoadRun|BatchId' -and
                        ([string]$_.Input.path + ' ' + [string]$_.Input.glob) -replace '\\','/' -notmatch '(?i)\.md\b|(?:^|/)docs(?:/|\s|$)') -or
                    ($_.Name -in @('Bash','PowerShell') -and [string]$_.Input.command -match '(?i)\b(?:grep|rg|Select-String|sls|findstr)\b[^|;]*?(?:LoadRun|BatchId)')
                } | Select-Object -First 1)
                $baseCommit = @(git -C $Target rev-list --reverse HEAD 2>$null)[[Math]::Max(0, $BeforeCommits - 1)]
                $changed = @(@(git -C $Target diff --name-only $baseCommit 2>$null) + @(git -C $Target ls-files --others --exclude-standard 2>$null)) | Where-Object { $_ } | Sort-Object -Unique
                $documented = [bool]@($changed | Where-Object { $_ -match '(?i)^(?:docs/.+\.md|TECH_DEBT\.md|FRAMEWORK-CONTEXT\.md|AGENTS\.md|CLAUDE\.md|LEARNINGS\.md)$' }).Count -or
                    [bool]@($successful | Where-Object { $_.Name -eq 'Skill' -and $_.Input.skill -eq 'remember-for-team' }).Count
                $editedWarehouse = [bool]@($changed | Where-Object { $_ -match '(?i)^(?:Tables|StoredProcedures|Views)/' }).Count
                $offered = $finalOk -and $finalText -match '(?i)\bremember-for-team\b|\b(?:want me to|shall I|should I|I can|I could|happy to|would you like(?: me)? to)\b[^.?!\r\n]{0,120}?\b(?:record|document|note|capture|add|update|correct|fix|write)\b[^.?!\r\n]{0,80}?(?:\b(?:wiki|warehouse[- ]map|map|docs|TECH_DEBT|AGENTS\.md|CLAUDE\.md|FRAMEWORK-CONTEXT|LEARNINGS)\b|\b(?:the|this|that|its|project''s|repository''s)\s+record\b)'
                return [pscustomobject]@{ Status = $status; Pass = $status -eq 'PASS'; Outcome = [bool]($consumer -in @('ESTABLISHED-PARTIAL','CAVEATED-JOIN','ASKED')); Detail = "consumer=$consumer investigated=$($readLoader -or $searchedWriters) documentedOrOffered=$($documented -or $offered) readLoader=$readLoader searchedWriters=$searchedWriters documented=$documented offered=$offered shapes=$($shapes -join ',') checks=$checks readLoadRun=$readLoadRun perRun=$perRun proxyStart=$proxyStart disclosed=$disclosed editedWarehouse=$editedWarehouse category=$category channels=$($channels -join ',') artifactWritten=$artifactWritten otherSqlArtifacts=$($otherArtifacts -join ',')" }
            }
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
            # Selecting from the consumption view that already joins the owning dimension is a correct
            # answer too (a live framework-arm query over rpt.vwFinanceExtract scored False, 2026-09-20).
            $viaView = [bool]($relevantView -and $sql -match "(?i)\b(?:FROM|JOIN)\s+(?:\[?rpt\]?\s*\.\s*)?\[?$relevantView\]?(?![A-Za-z0-9_])")
            return [pscustomobject]@{ Status = $status; Pass = $status -eq 'PASS'; Outcome = [bool]($artifactWritten -and ($joinedDimension -or $viaView) -and -not $usedDeadColumn); Detail = "category=$category channels=$($channels -join ',') usedDeadColumn=$usedDeadColumn joinedDimension=$joinedDimension readView=$readView readViewTarget=$(if ($relevantView) { $relevantView } else { 'none' }) artifactWritten=$artifactWritten otherSqlArtifacts=$($otherArtifacts -join ',')" }
        }
        { $_ -in @('warehouse-fact-existing','warehouse-fact-new','warehouse-fact-snapshot','warehouse-fact-abstain') } {
            $successful = @($e.Tools | Where-Object { $e.ToolResults.ContainsKey($_.Id) -and -not $e.ToolResults[$_.Id].is_error })
            $warehouseTreeCall = [bool]@($successful | Where-Object {
                ((Get-ToolPath $_) -replace '\\','/' -match '(?i)(?:^|/)(?:Tables|StoredProcedures|Views|docs/warehouse-map\.md)(?:/|$)') -or
                (([string]$_.Input.command + ' ' + [string]$_.Input.path + ' ' + [string]$_.Input.glob + ' ' + [string]$_.Input.pattern) -match '(?i)Tables|StoredProcedures|Views|warehouse-map|\.sql')
            } | Select-Object -First 1)
            $liveSqlCall = [bool]@($successful | Where-Object {
                ((Get-ToolPath $_) -replace '\\','/' -match '(?i)(?:^|/)(?:Tables|StoredProcedures|Views)(?:/|$)') -or
                (([string]$_.Input.command + ' ' + [string]$_.Input.path + ' ' + [string]$_.Input.glob + ' ' + [string]$_.Input.pattern) -match '(?i)(?:Tables|StoredProcedures|Views).*(?:\.sql|\*)|\.sql.*(?:Tables|StoredProcedures|Views)')
            } | Select-Object -First 1)
            $skill = [bool]@($successful | Where-Object { $_.Name -eq 'Skill' -and $_.Input.skill -eq 'add-warehouse-load' } | Select-Object -First 1)
            $mapRead = [bool]@($successful | Where-Object { ((Get-ToolPath $_) -replace '\\','/') -match '(?i)docs/warehouse-map\.md$' } | Select-Object -First 1)
            $channels = @(); if ($skill) { $channels += 'C1' }; if ($mapRead) { $channels += 'C2' }
            $category = if ($skill -and $mapRead) { 'BOTH' } elseif ($skill) { 'SKILL_ROUTED' } elseif ($mapRead) { 'MAP_DISCOVERED' } else { 'NEITHER' }

            $sqlFiles = @(Get-ChildItem -LiteralPath $Target -Filter '*.sql' -File -Recurse -ErrorAction SilentlyContinue)
            $allSql = @($sqlFiles | ForEach-Object { Get-Content -Raw -LiteralPath $_.FullName }) -join "`n"
            $declaredFacts = @([regex]::Matches($allSql, '(?is)\bCREATE\s+TABLE\s+\[?fact\]?\s*\.\s*\[?(?<name>[A-Za-z0-9_]+)\]?') | ForEach-Object { $_.Groups['name'].Value } | Sort-Object -Unique)
            $newFacts = @($declaredFacts | Where-Object { $_ -notin @('FactOrderLine','FactOrderPipeline') })
            $orderFact = Get-Content -Raw -LiteralPath (Join-Path $Target 'Tables/fact.FactOrderLine.sql')
            $orderLoad = Get-Content -Raw -LiteralPath (Join-Path $Target 'StoredProcedures/usp_LoadFactOrderLine.sql')
            $pipelineFact = Get-Content -Raw -LiteralPath (Join-Path $Target 'Tables/fact.FactOrderPipeline.sql')
            $orderFactCode = [regex]::Replace([regex]::Replace($orderFact, '(?s)/\*.*?\*/', ''), '(?m)--.*$', '')
            $orderLoadCode = [regex]::Replace([regex]::Replace($orderLoad, '(?s)/\*.*?\*/', ''), '(?m)--.*$', '')
            $discountExtended = $orderFactCode -match '(?i)\bDiscountAmount\b\s+DECIMAL' -and
                $orderLoadCode -match '(?is)INSERT\s+INTO\s+fact\.FactOrderLine\s*\([^)]*\bDiscountAmount\b' -and
                $orderLoadCode -match '(?i)\bs\.DiscountAmount\b'
            $allocationOnExisting = ($orderFact + "`n" + $orderLoad + "`n" + $pipelineFact) -match '(?i)Payment|Allocation'
            $newFactSql = @($sqlFiles | Where-Object { (Get-Content -Raw -LiteralPath $_.FullName) -match '(?is)CREATE\s+TABLE\s+\[?fact\]?\s*\.' -and $_.Name -notin @('fact.FactOrderLine.sql','fact.FactOrderPipeline.sql') } | ForEach-Object { Get-Content -Raw -LiteralPath $_.FullName }) -join "`n"
            $hasOrderLineReference = $newFactSql -match '(?i)\bOrderLineKey\b' -or
                ($newFactSql -match '(?i)\bOrderNumber\b' -and $newFactSql -match '(?i)\bLineNumber\b')
            $paymentFact = $newFacts.Count -eq 1 -and $newFactSql -match '(?i)Payment|Allocation' -and
                $hasOrderLineReference -and $newFactSql -match '(?i)\bAllocationSequence\b'
            $snapshotFact = $newFacts.Count -eq 1 -and $newFactSql -match '(?i)Product' -and $newFactSql -match '(?i)(DateKey|SnapshotDate)' -and $newFactSql -match '(?i)(OnHand|ClosingBalance|Balance)'
            $semiAdditive = $finalText -match '(?i)semi[- ]additive' -and $finalText -match '(?i)(?:never|not)\s+(?:(?:sum|aggregate)[a-z ]*?)?(?:across|over)\s+(?:time|dates?|the time dimension)'
            $changedSql = [bool]((git -C $Target status --porcelain -- '*.sql') -or ([int](git -C $Target rev-list --count HEAD) -gt $BeforeCommits))
            $abstain = $finalText -match '(?i)\babstain(?:ing|ed|s)?\b|cannot safely|not enough evidence' -and $finalText -match '(?i)source authority|authoritative source|source/authority' -and $finalText -match '(?i)\bgrain\b'

            $pass = switch ($Id) {
                'warehouse-fact-existing' { $discountExtended -and $newFacts.Count -eq 0 -and -not $allocationOnExisting }
                'warehouse-fact-new' { $paymentFact -and -not $allocationOnExisting }
                'warehouse-fact-snapshot' { $snapshotFact -and $semiAdditive }
                'warehouse-fact-abstain' { $liveSqlCall -and $abstain -and -not $changedSql }
            }
            $engaged = $warehouseTreeCall -or $changedSql
            $status = if (-not $engaged) { 'INCONCLUSIVE' } elseif ($pass) { 'PASS' } else { 'FAIL' }
            return [pscustomobject]@{ Status=$status; Pass=$pass; Detail="category=$category channels=$($channels -join ',') outcome=$(if ($abstain) {'ABSTAIN'} elseif ($discountExtended) {'EXTEND'} elseif ($snapshotFact) {'PERIODIC_SNAPSHOT'} elseif ($paymentFact) {'NEW_TRANSACTION'} else {'UNRESOLVED'}) targetFact=$(if ($discountExtended) {'FactOrderLine'} elseif ($newFacts.Count) {$newFacts -join ','} else {'none'}) grainStatement=$($finalText -match '(?i)grain') ddlWritten=$changedSql mixedGrain=$allocationOnExisting missingFacts=$(if ($abstain) {'source-authority,grain'} else {'none'}) evidence=$warehouseTreeCall liveSqlEvidence=$liveSqlCall" }
        }
        { $_ -in @('warehouse-upstream-pinned','warehouse-upstream-deferred') } {
            # WSD-056: score the requested SQL artifact, not answer prose. Source reads remain
            # attribution dimensions because WSD-040 already showed that exact-read gating creates
            # false negatives. A reached answer-bearing skill is separated as contamination.
            $successful = @($e.Tools | Where-Object {
                $e.ToolResults.ContainsKey($_.Id) -and -not $e.ToolResults[$_.Id].is_error
            })
            $readEvidence = {
                param([string]$PathPattern, [string]$ContentPattern)
                return [bool]@($successful | Where-Object {
                    $tool = $_
                    $resultText = Get-ToolResultText $e $tool
                    if (-not $resultText.Trim() -or $resultText -notmatch $ContentPattern) { return $false }
                    $toolPath = (Get-ToolPath $tool) -replace '\\','/'
                    $directRead = $tool.Name -match '^(?i:Read|ReadFile|read_file)$' -and $toolPath -match $PathPattern
                    $command = [string]$tool.Input.command
                    $commandPathText = '/' + (((($command -replace '\\','/') -replace '["'']','') -replace '\s+','/'))
                    $contentCommand = $tool.Name -match '^(?i:Bash|PowerShell|Shell|Terminal)$' -and
                        $command -match '(?i)(?:^|\s)(?:rg|grep|cat|sed|type|Get-Content|Select-String)(?:\s|$)' -and
                        $command -notmatch '(?i)(?:^|[;|&]\s*|\s)(?:echo|printf|Write-Output)(?:\s|$)' -and
                        $commandPathText -match $PathPattern
                    $directRead -or $contentCommand
                } | Select-Object -First 1)
            }
            $mapRead = & $readEvidence '(?i)(?:^|/)docs/warehouse-map\.md$' '(?is)#\s*Warehouse map.*(?:records locations|Inventory)'
            $factRead = & $readEvidence '(?i)(?:^|/)Tables/fact\.FactShipment\.sql$' '(?is)CREATE\s+TABLE\s+(?:\[?fact\]?\s*\.\s*)?\[?FactShipment\]?'
            $loadRead = & $readEvidence '(?i)(?:^|/)StoredProcedures/usp_LoadFactShipment\.sql$' '(?is)CREATE\s+PROCEDURE\s+(?:\[?dbo\]?\s*\.\s*)?\[?usp_LoadFactShipment\]?'
            $viewRead = & $readEvidence '(?i)(?:^|/)Views/rpt\.vwShipment\.sql$' '(?is)CREATE\s+VIEW\s+(?:\[?rpt\]?\s*\.\s*)?\[?vwShipment\]?'
            $skillSelected = [bool]@($successful | Where-Object {
                $_.Name -match '^(?i:Skill)$' -and [string]$_.Input.skill -eq 'map-warehouse'
            } | Select-Object -First 1)
            $skillRead = & $readEvidence '(?i)(?:^|/)(?:\.claude|\.github)/skills/map-warehouse/SKILL\.md$' '(?is)(?:Pinned at load|effective-date predicate only when)'
            $skillReached = $skillSelected -or $skillRead

            $queryRelative = 'analysis/shipment-carrier-history.sql'
            $queryPath = Join-Path $Target $queryRelative
            $outputExists = Test-Path -LiteralPath $queryPath -PathType Leaf
            $sqlCode = ''
            if ($outputExists) {
                $sqlCode = Get-Content -Raw -LiteralPath $queryPath
                $sqlCode = [regex]::Replace($sqlCode, '(?s)/\*.*?\*/', ' ')
                $sqlCode = [regex]::Replace($sqlCode, '(?m)--.*$', ' ')
                $sqlCode = [regex]::Replace($sqlCode, "'(?:''|[^'])*'", "''")
                $sqlCode = $sqlCode -replace '[\[\]]',''
            }

            $commits = [int](git -C $Target rev-list --count HEAD)
            $treeState = @((git -C $Target status --porcelain=v1 --untracked-files=all) | ForEach-Object { ([string]$_).Replace('\\','/').TrimEnd() })
            # A successful Claude Write/Edit invokes the installed audit-trail hook, so the live
            # surface legitimately appends telemetry even when the agent authors only the requested
            # artifact. Permit only an unstaged, append-only audit delta whose every row names that
            # artifact; all other tracked/untracked/staged/committed mutations still fail.
            $auditRelative = '.claude/ai-audit.log'
            $auditState = " M $auditRelative"
            $auditStates = @($treeState | Where-Object { $_ -ceq $auditState })
            $nonAuditTreeState = @($treeState | Where-Object { $_ -cne $auditState })
            $auditAppendExact = $auditStates.Count -le 1
            if ($auditStates.Count -eq 1) {
                $auditNumstat = @((git -C $Target diff --numstat -- $auditRelative) | ForEach-Object { [string]$_ })
                $auditDiff = @((git -C $Target diff --unified=0 -- $auditRelative) | ForEach-Object { [string]$_ })
                $addedAuditLines = @($auditDiff | Where-Object { $_ -cmatch '^\+(?!\+\+)' })
                $removedAuditLines = @($auditDiff | Where-Object { $_ -cmatch '^-(?!--)' })
                $numstat = if ($auditNumstat.Count -eq 1) {
                    [regex]::Match($auditNumstat[0], '^(?<added>\d+)\s+0\s+\.claude/ai-audit\.log$')
                } else { [Text.RegularExpressions.Match]::Empty }
                $auditLinePattern = '^\+\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\t[^\t\r\n]+\t(?:\.[\\/])?analysis[\\/]shipment-carrier-history\.sql$'
                $auditAppendExact = $numstat.Success -and [int]$numstat.Groups['added'].Value -ge 1 -and
                    [int]$numstat.Groups['added'].Value -eq $addedAuditLines.Count -and $removedAuditLines.Count -eq 0 -and
                    @($addedAuditLines | Where-Object { $_ -cnotmatch $auditLinePattern }).Count -eq 0
            }
            $treeExact = $commits -eq $BeforeCommits -and $nonAuditTreeState.Count -eq 1 -and
                $nonAuditTreeState[0] -ceq "?? $queryRelative" -and $auditAppendExact

            $factTable = [regex]::Match($sqlCode, '(?is)\bFROM\s+fact\s*\.\s*FactShipment(?:\s+(?:AS\s+)?(?<alias>(?!(?:INNER|LEFT|RIGHT|FULL|CROSS|JOIN|WHERE|ON|GROUP|ORDER)\b)[A-Za-z_][A-Za-z0-9_]*))?')
            $dimensionTable = [regex]::Match($sqlCode, '(?is)\bJOIN\s+dim\s*\.\s*DimCarrier(?:\s+(?:AS\s+)?(?<alias>(?!(?:ON|INNER|LEFT|RIGHT|FULL|CROSS|JOIN|WHERE|GROUP|ORDER)\b)[A-Za-z_][A-Za-z0-9_]*))?')
            $joinTail = if ($dimensionTable.Success) { $sqlCode.Substring($dimensionTable.Index + $dimensionTable.Length) } else { '' }
            $joinPredicateMatch = [regex]::Match($joinTail, '(?is)^\s*ON\b(?<predicate>.*?)(?=\bWHERE\b|\bGROUP\s+BY\b|\bORDER\s+BY\b|\bHAVING\b|;|$)')
            $joinPredicate = if ($joinPredicateMatch.Success) { $joinPredicateMatch.Groups['predicate'].Value } else { '' }
            $directJoin = $factTable.Success -and $dimensionTable.Success -and $joinPredicateMatch.Success
            $factQualifier = if ($factTable.Success -and $factTable.Groups['alias'].Success) { [regex]::Escape($factTable.Groups['alias'].Value) } else { '(?:fact\s*\.\s*)?FactShipment' }
            $dimensionQualifier = if ($dimensionTable.Success -and $dimensionTable.Groups['alias'].Success) { [regex]::Escape($dimensionTable.Groups['alias'].Value) } else { '(?:dim\s*\.\s*)?DimCarrier' }
            $factColumn = "(?:$factQualifier)\s*\.\s*"
            $dimensionColumn = "(?:$dimensionQualifier)\s*\.\s*"
            $carrierKeyJoin = $joinPredicate -match "(?is)(?:${factColumn}CarrierKey\b\s*=\s*${dimensionColumn}CarrierKey\b|${dimensionColumn}CarrierKey\b\s*=\s*${factColumn}CarrierKey\b)"
            $durableKeyJoin = $joinPredicate -match "(?is)(?:${factColumn}CarrierDurableKey\b\s*=\s*${dimensionColumn}CarrierDurableKey\b|${dimensionColumn}CarrierDurableKey\b\s*=\s*${factColumn}CarrierDurableKey\b)"
            $shipmentDate = "${factColumn}ShipmentDate\b"
            $effectiveFrom = "${dimensionColumn}EffectiveFrom\b"
            $effectiveTo = "${dimensionColumn}EffectiveTo\b"
            $lowerBound = $joinPredicate -match "(?is)(?:$shipmentDate\s*>=\s*$effectiveFrom|$effectiveFrom\s*<=\s*$shipmentDate)"
            $upperBound = $joinPredicate -match "(?is)(?:$shipmentDate\s*<\s*$effectiveTo|$effectiveTo\s*>\s*$shipmentDate)"
            $predicateEscape = $joinPredicate -match '(?i)\b(?:OR|NOT)\b'
            $usesCurrent = $sqlCode -match '(?i)(?<![A-Za-z0-9_])IsCurrent(?![A-Za-z0-9_])'
            $usesEffective = $sqlCode -match '(?i)(?<![A-Za-z0-9_])Effective(?:From|To)(?![A-Za-z0-9_])'
            $usesCarrierKey = $sqlCode -match '(?i)(?<![A-Za-z0-9_])CarrierKey(?![A-Za-z0-9_])'
            $projectionMatch = [regex]::Match($sqlCode, '(?is)\bSELECT\b(?<projection>.*?)\bFROM\b')
            $projection = if ($projectionMatch.Success) { $projectionMatch.Groups['projection'].Value } else { '' }
            $projectsRequested = $projection -match '(?i)(?<![A-Za-z0-9_])ShipmentDate(?![A-Za-z0-9_])' -and
                $projection -match '(?i)(?<![A-Za-z0-9_])CarrierTier(?![A-Za-z0-9_])' -and
                $projection -match '(?i)(?<![A-Za-z0-9_])FreightAmount(?![A-Za-z0-9_])'
            $world = if ($Id -eq 'warehouse-upstream-pinned') { 'pinned' } else { 'deferred' }
            $semantics = if ($world -eq 'pinned') {
                $directJoin -and $projectsRequested -and $carrierKeyJoin -and -not $durableKeyJoin -and -not $usesCurrent -and -not $usesEffective -and -not $predicateEscape
            } else {
                $directJoin -and $projectsRequested -and $durableKeyJoin -and $lowerBound -and $upperBound -and -not $usesCurrent -and -not $usesCarrierKey -and -not $predicateEscape
            }
            $pass = $finalOk -and $outputExists -and $treeExact -and $semantics -and -not $skillReached
            $status = if ($skillReached) { 'CONTAMINATED' } elseif ($pass) { 'PASS' } else { 'FAIL' }
            return [pscustomobject]@{
                Status = $status
                Pass = $pass
                Detail = "world=$world output=$outputExists treeExact=$treeExact auditAppendExact=$auditAppendExact directJoin=$directJoin projects=$projectsRequested carrierKeyJoin=$carrierKeyJoin durableKeyJoin=$durableKeyJoin lowerBound=$lowerBound upperBound=$upperBound predicateEscape=$predicateEscape usesCurrent=$usesCurrent usesEffective=$usesEffective mapRead=$mapRead factRead=$factRead loadRead=$loadRead viewRead=$viewRead skillSelected=$skillSelected skillRead=$skillRead skillReached=$skillReached finalOk=$finalOk"
            }
        }
        { $_ -like 'warehouse-trace-*' } {
            # WSD-040 attribution is deliberately outside the decision score. A plain-language
            # prompt that never reaches the unchanged skill is a routing non-reach, not evidence
            # for or against the skill body's trace behavior.
            $skillRead = [bool]@($e.Tools | Where-Object {
                $_.Name -match '^(?i:Read|ReadFile|read_file)$' -and
                ((Get-ToolPath $_) -replace '\\','/') -match '(?i)(?:^|/)(?:\.claude|\.github)/skills/map-warehouse/SKILL\.md$'
            } | Select-Object -First 1)
            $skillSelected = $skillRead -or [bool]@($e.Tools | Where-Object {
                $_.Name -eq 'Skill' -and [string]$_.Input.skill -eq 'map-warehouse'
            } | Select-Object -First 1)
            if (-not $skillRead) {
                return [pscustomobject]@{ Status = 'ROUTING_NON_REACH'; Pass = $false; Detail = "skillSelected=$skillSelected skillRead=$skillRead outcome=NOT_SCORED fabrication=NOT_SCORED" }
            }

            $outcome = $false
            $fabrication = $false
            switch ($Id) {
                'warehouse-trace-keyres-pinned' {
                    $outcome = $finalText -match '(?is)(?:pinned|stamped|surrogate).*(?:load|histor|as[- ]of|back then)' -and
                        $finalText -match '(?is)(?:histor|as[- ]of|back then).*(?:value|version|row)' -and
                        $finalText -notmatch '(?is)(?:must|required|need(?:s)? to).{0,45}(?:effective|date predicate|IsCurrent)'
                    $fabrication = $finalText -match '(?is)(?:fact|load).{0,60}(?:durable|natural|business) key'
                }
                'warehouse-trace-keyres-deferred' {
                    $outcome = $finalText -match '(?is)(?:deferred|durable|natural|business).{0,80}(?:effective|as[- ]of|date predicate)' -and
                        $finalText -match '(?is)(?:required|must|need|otherwise|without).{0,80}(?:effective|as[- ]of|date predicate|multiple|current)'
                    $fabrication = $finalText -match '(?is)(?:fact|load).{0,70}(?:stamps?|stores?|carries?).{0,35}(?:surrogate|CarrierKey)'
                }
                'warehouse-trace-attribute-a' {
                    $outcome = $finalText -match '(?i)stg\.StgOrderRevenue|RevenueAmount' -and $finalText -match '(?i)(?:DailyFxRate|GbpRate|FX|exchange).{0,50}(?:multiply|convert|rate)|(?:multiply|convert).{0,50}(?:DailyFxRate|GbpRate|FX|exchange)'
                    $fabrication = $finalText -match '(?i)(?:COALESCE|ISNULL|default(?:ed)?).{0,30}(?:zero|0)'
                }
                'warehouse-trace-attribute-b' {
                    $outcome = $finalText -match '(?i)stg\.StgOrderRevenue|RevenueAmount' -and $finalText -match '(?i)(?:COALESCE|ISNULL|default(?:ed)?).{0,35}(?:zero|0)|(?:zero|0).{0,35}(?:null|default)'
                    $fabrication = $finalText -match '(?i)(?:DailyFxRate|GbpRate|FX|exchange rate|currency conversion)'
                }
                'warehouse-trace-metric-ratio' {
                    $outcome = $finalText -match '(?is)(?:sum|aggregate).{0,55}(?:NetAmount|numerator|revenue).{0,100}(?:count|distinct Order|denominator).{0,80}(?:then|before).{0,30}(?:divide|ratio)|(?:numerator|revenue).{0,60}(?:and|with).{0,30}(?:denominator|order count).{0,80}(?:aggregate|sum).{0,50}(?:before|then).{0,20}(?:divide|ratio)'
                    $fabrication = $finalText -match '(?is)(?:average|sum).{0,30}(?:row[- ]level averages?|AverageOrderValue values?).{0,20}(?:directly|together|across)'
                }
                'warehouse-trace-metric-additive' {
                    $outcome = $finalText -match '(?is)(?:fully )?additive|sum(?:ming)? (?:the )?(?:values?|metric)|SUM\s*\(\s*NetAmount' -and $finalText -match '(?is)(?:no|does not|don''t|isn''t).{0,45}(?:numerator|denominator|divide|ratio)|(?:no ratio|not a ratio)'
                    $fabrication = $finalText -match '(?is)(?:aggregate|sum|use).{0,60}(?:count|denominator).{0,60}(?:then|before).{0,20}(?:divide|ratio)'
                }
                'warehouse-trace-decoy' {
                    $outcome = $finalText -match '(?i)dim\.DimCustomer|DimCustomer' -and $finalText -match '(?i)CustomerKey' -and $finalText -match '(?i)SegmentName'
                    $fabrication = $finalText -match '(?is)\b(?:loaded|populated|written|reads?|source|feeds?)\b.{0,15}(?:fact\.FactSales|FactSales)\.?(?:SegmentName)|(?:fact\.FactSales|FactSales)\.?(?:SegmentName).{0,20}\b(?:directly|source|feeds?|loaded|populated|written)\b'
                }
                'warehouse-trace-conflict' {
                    $outcome = $finalText -match '(?i)conflict|disagree|different (?:join )?paths?' -and $finalText -match '(?i)vwShipment' -and $finalText -match '(?i)vwShipmentCurrentCarrier' -and $finalText -match '(?i)CarrierKey|surrogate' -and $finalText -match '(?i)CarrierDurableKey|durable|business|natural'
                    $fabrication = $finalText -match '(?is)(?:the|one) (?:correct|authoritative) (?:source|path|answer) (?:is|=)|(?:always|only) (?:comes? from|use|join)'
                }
            }
            $pass = $finalOk -and $outcome -and -not $fabrication
            return [pscustomobject]@{ Status = $(if ($pass) { 'PASS' } else { 'FAIL' }); Pass = $pass; Detail = "skillSelected=$skillSelected skillRead=$skillRead outcome=$outcome fabrication=$fabrication" }
        }
        { $_ -in @('warehouse-schema-compatible','warehouse-schema-incompatible','warehouse-schema-incomplete') } {
            $successful = @($e.Tools | Where-Object { $e.ToolResults.ContainsKey($_.Id) -and -not $e.ToolResults[$_.Id].is_error })
            $readPath = {
                param([string]$Pattern)
                return [bool]@($successful | Where-Object {
                    $_.Name -match '^(?i:Read|ReadFile|read_file)$' -and
                    ((Get-ToolPath $_) -replace '\\','/') -match $Pattern -and
                    (Get-ToolResultText $e $_).Trim()
                } | Select-Object -First 1)
            }
            $premiseRead = & $readPath '(?i)(?:^|/)docs/schema-evolution-premise\.md$'
            $consumerRead = & $readPath '(?i)(?:^|/)StoredProcedures/usp_RefreshProductExtract\.sql$'
            $ownerRead = & $readPath '(?i)(?:^|/)docs/product-consumer-closure\.md$'
            $skill = [bool]@($successful | Where-Object { $_.Name -eq 'Skill' -and $_.Input.skill -eq 'add-warehouse-load' } | Select-Object -First 1)
            $dimensionPath = Join-Path $Target 'Tables/dim.DimProduct.sql'
            $consumerPath = Join-Path $Target 'StoredProcedures/usp_RefreshProductExtract.sql'
            $dimension = if (Test-Path -LiteralPath $dimensionPath) { Get-Content -Raw -LiteralPath $dimensionPath } else { '' }
            $consumer = if (Test-Path -LiteralPath $consumerPath) { Get-Content -Raw -LiteralPath $consumerPath } else { '' }
            $dimensionCode = [regex]::Replace([regex]::Replace($dimension, '(?s)/\*.*?\*/', ''), '(?m)--.*$', '')
            $consumerCode = [regex]::Replace([regex]::Replace($consumer, '(?s)/\*.*?\*/', ''), '(?m)--.*$', '')
            $additiveDdl = $dimensionCode -match '(?i)\bProductColor\b\s+NVARCHAR\s*\([^)]*\)\s+NULL\b'
            $wildcardConsumer = $consumerCode -match '(?is)INSERT\s+INTO\s+export\.ProductExtract\s*\(\s*ProductKey\s*,\s*ProductId\s*\)\s*SELECT\s+\*\s+FROM\s+dim\.DimProduct'
            $explicitConsumer = $consumerCode -match '(?is)INSERT\s+INTO\s+export\.ProductExtract\s*\(\s*ProductKey\s*,\s*ProductId\s*\)\s*SELECT\s+(?:\w+\.)?ProductKey\s*,\s*(?:\w+\.)?ProductId\s+FROM\s+dim\.DimProduct'
            $impactNamed = $finalText -match '(?i)(?:SELECT\s*\*|wildcard|column (?:count|cardinality|ordinal)|ProductExtract|usp_RefreshProductExtract)' -and
                $finalText -match '(?i)(?:(?:would|will|can|does)\s+break|\bbreaks\b|incompatib|fail|must|before|first|parallel|abstain|stop)'
            $compatibleNamed = $finalText -match '(?i)(?:repository[- ]visible|consumer|ProductExtract)' -and $finalText -match '(?i)compatib|non[- ]breaking|safe'
            $closureMissing = $finalText -match '(?i)(?:closed[- ]world|consumer closure|external consumers?|deployment approval)' -and
                $finalText -match '(?i)(?:missing|unknown|cannot|not enough|need|required|without)'
            $abstain = $finalText -match '(?i)\babstain|do not approve|cannot approve|withhold|not approve|stop'
            # Allow the "Deployment decision: Approved" / "Deployment decision: Not approved"
            # phrasing (a colon-and-label form real models commonly use) alongside the direct
            # "deployment is/not approved" phrasing -- both sides of this check, symmetrically, so
            # a denial in that form is never miscounted as an approval by omission.
            $deploymentDenied = $finalText -match '(?i)(?:do not|cannot|can''t|withhold|not)\s+approve(?:d|al)?(?:\s+(?:this|the))?\s+deployment|deployment\s*(?:decision)?\s*(?:is\s*)?:?\s*not\s+approved'
            $deploymentApproval = -not $deploymentDenied -and $finalText -match '(?i)deployment\s*(?:decision)?\s*(?:is\s*)?:?\s*(?:approved|approval granted|may proceed)|approve(?:d)? (?:this )?deployment|safe to deploy'

            # Accepted closed-world attestations are deliberately three distinct, inspectable
            # sources. A mere keyword in final narration is not an attestation.
            $developerText = @($Transcript.Events | Where-Object { $_.type -eq 'user' } | ForEach-Object {
                @($_.message.content | Where-Object { $_.type -eq 'text' } | ForEach-Object { [string]$_.text })
            }) -join "`n"
            $developerAttestation = $developerText -match '(?i)(?:I|we)\s+(?:attest|confirm|state)' -and
                $developerText -match '(?i)(?:all|every)\s+(?:downstream\s+)?consumers?' -and
                $developerText -match '(?i)(?:repository|scan|visible)' -and
                $developerText -match '(?i)operational constraints?'
            $claudeText = (@('CLAUDE.md', 'AGENTS.md') | Where-Object { Test-Path -LiteralPath (Join-Path $Target $_) } | ForEach-Object { Get-Content -Raw -LiteralPath (Join-Path $Target $_) }) -join "`n"
            $claudeAttestation = $claudeText -match '(?im)^- .*all .*consumers.*ProductColor.*operational constraints'
            $ownerFile = Join-Path $Target 'docs/product-consumer-closure.md'
            $ownerText = if (Test-Path -LiteralPath $ownerFile) { Get-Content -Raw -LiteralPath $ownerFile } else { '' }
            $ownerAttestation = $ownerRead -and $ownerText -match '(?is)Mara Voss.*Warehouse Platform Owner.*signs off' -and
                $ownerText -match '(?is)every consumer.*operational constraint'
            $attestation = if ($developerAttestation) { 'in-session-developer' } elseif ($claudeAttestation) { 'CLAUDE-Conventions' } elseif ($ownerAttestation) { 'named-owner' } else { 'none' }
            $approvedWithAttestation = $deploymentApproval -and $attestation -ne 'none'

            $pass = switch ($Id) {
                'warehouse-schema-compatible' {
                    $premiseRead -and $consumerRead -and $additiveDdl -and $explicitConsumer -and
                    $compatibleNamed -and $approvedWithAttestation
                }
                'warehouse-schema-incompatible' {
                    $premiseRead -and $consumerRead -and $impactNamed -and (
                        ($additiveDdl -and $explicitConsumer -and -not $wildcardConsumer -and $approvedWithAttestation) -or
                        (-not $additiveDdl -and $wildcardConsumer -and $abstain)
                    )
                }
                'warehouse-schema-incomplete' {
                    # Three worlds are accepted, not two: full abstention before any write; writing
                    # the provably-safe additive DDL while still correctly withholding deployment
                    # approval because closure evidence is missing (the DDL itself needs no
                    # attestation -- only the broader "deployment approved" claim does); or a
                    # written change with a genuine attestation. All three require the model to have
                    # actually engaged with the evidence-boundary policy ($closureMissing), not
                    # merely used the word "abstain" while ignoring it.
                    $premiseRead -and $consumerRead -and (
                        ($abstain -and $closureMissing -and -not $deploymentApproval -and (-not $additiveDdl -or $explicitConsumer)) -or
                        ($additiveDdl -and $explicitConsumer -and $approvedWithAttestation)
                    )
                }
            }
            $engaged = $skill -or $premiseRead -or $consumerRead -or $additiveDdl
            $status = if (-not $engaged) { 'INCONCLUSIVE' } elseif ($pass) { 'PASS' } else { 'FAIL' }
            $outcome = if ($approvedWithAttestation) { 'DEPLOYMENT_APPROVED' } elseif ($abstain) { 'ABSTAIN' } elseif ($impactNamed) { 'INCOMPATIBLE_UNRESOLVED' } elseif ($compatibleNamed) { 'REPOSITORY_COMPATIBLE' } else { 'UNRESOLVED' }
            return [pscustomobject]@{
                Status = $status
                Pass = $pass
                Detail = "outcome=$outcome skill=$skill premiseRead=$premiseRead consumerRead=$consumerRead additiveDdl=$additiveDdl explicitConsumer=$explicitConsumer wildcardConsumer=$wildcardConsumer impactNamed=$impactNamed compatibleNamed=$compatibleNamed closureMissing=$closureMissing attestation=$attestation deploymentApproval=$deploymentApproval"
            }
        }
        'warehouse-partition-mismatch' {
            $successful = @($e.Tools | Where-Object { $e.ToolResults.ContainsKey($_.Id) -and -not $e.ToolResults[$_.Id].is_error })
            $partitionRead = @($successful | Where-Object {
                $_.Name -match '^(?i:Read|ReadFile|read_file)$' -and
                ((Get-ToolPath $_) -replace '\\','/') -match '(?i)(?:^|/)Tables/(?:partition\.OrderDateMonth|fact\.FactOrderLine)\.sql$' -and
                (Get-ToolResultText $e $_) -match '(?is)pf_OrderDateMonth|ps_OrderDateMonth' -and
                (Get-ToolResultText $e $_) -match '(?i)OrderDateKey|RANGE\s+RIGHT'
            } | Sort-Object Index | Select-Object -First 1)
            $accessRead = @($successful | Where-Object {
                $_.Name -match '^(?i:Read|ReadFile|read_file)$' -and
                ((Get-ToolPath $_) -replace '\\','/') -match '(?i)(?:^|/)docs/fraud-alert-contract\.md$' -and
                (Get-ToolResultText $e $_) -match '(?i)AlertId' -and
                (Get-ToolResultText $e $_) -match '(?i)complete retained history|do not carry a detected-date range' -and
                (Get-ToolResultText $e $_) -match '(?i)correct `?DetectedAt|reconciles each batch'
            } | Sort-Object Index | Select-Object -First 1)
            $implementationWrite = @($e.Tools | Where-Object {
                $_.Name -in @('Edit','Write') -and
                ((Get-ToolPath $_) -replace '\\','/') -match '(?i)(?:^|/)(?:Tables|StoredProcedures)/.*(?:FraudAlert|partition).*\.sql$'
            } | Sort-Object Index | Select-Object -First 1)
            $mismatchQuestion = @($successful | Where-Object {
                if ($_.Name -ne 'AskUserQuestion') { return $false }
                $questionText = ($_.Input | ConvertTo-Json -Compress -Depth 20)
                return $questionText -match '(?i)(?:pf_|ps_)?OrderDateMonth|OrderDateKey|date[- ]partition' -and
                $questionText -match '(?i)AlertId|point lookup|complete (?:retained )?history|without (?:a )?date' -and
                $questionText -match '(?i)mismatch|conflict|unsuit|poor fit|not (?:align|suit|fit)|should (?:not|we)|separate partition|different partition' -and
                $partitionRead -and $_.Index -gt $partitionRead[0].Index -and
                $accessRead -and $_.Index -gt $accessRead[0].Index -and
                (-not $implementationWrite -or $_.Index -lt $implementationWrite[0].Index)
            } | Sort-Object Index | Select-Object -First 1)
            # Asking is one legitimate resolution; a model may instead resolve the conflict itself and
            # document it in the artifact it actually ships — not in free chat prose (which the
            # self-test's echo-only checks already forbid crediting), but in the DDL comment that is
            # the real work product. Require the written table to both name the specific scheme it
            # rejected AND ground that in the fixture's own access-pattern facts, and to not apply that
            # scheme to itself — this is a structural/content check on the artifact, not a keyword
            # match on the model's narration.
            $factWrite = @($e.Tools | Where-Object {
                $_.Name -in @('Edit','Write') -and
                ((Get-ToolPath $_) -replace '\\','/') -match '(?i)(?:^|/)Tables/fact\.FactFraudAlert\.sql$'
            } | Sort-Object Index | Select-Object -First 1)
            $documentedDeviation = [bool]@($factWrite | Where-Object {
                $written = [string]($_.Input.content)
                if (-not $written) { return $false }
                # The real DDL clause is ") ON ps_OrderDateMonth(Col)" — anchor on that shape, not the
                # bare word "on", which collides with ordinary prose like "not partitioned on ...".
                if ($written -match '(?i)\)\s*ON\s+ps_OrderDateMonth\s*\(') { return $false }
                # Deliberately broad on phrasing (two independently-observed correct answers used
                # different wording for the same fact — "no date range" vs. "not date-scoped"; "full
                # history" vs. "complete retained history") — narrow keyword lists under-credit real
                # variation, which is exactly the class of grader defect this repo has hit before
                # (B-124's literal 'OrderLine' requirement). What must not vary: the model names the
                # specific scheme it is rejecting (not a generic "no partition" note) and grounds the
                # rejection in this fact's own identity, not boilerplate.
                return $written -match '(?i)ps_OrderDateMonth' -and
                $written -match '(?i)AlertId' -and
                $written -match '(?i)(not\s+(?:partition|date-?scoped)|no\s+date|not\s+date|point\s+look|full[a-z\s]{0,20}history|complete[a-z\s]{0,20}history|unrelated|unlike|different)'
            })
            $resolved = [bool]($mismatchQuestion -or $documentedDeviation)
            $engaged = [bool]($partitionRead -or $accessRead -or $implementationWrite)
            $status = if (-not $engaged) { 'INCONCLUSIVE' } elseif ($resolved) { 'PASS' } else { 'FAIL' }
            return [pscustomobject]@{
                Status = $status
                Pass = $resolved
                Detail = "partitionEvidence=$([bool]$partitionRead) accessEvidence=$([bool]$accessRead) mismatchRaised=$([bool]$mismatchQuestion) documentedDeviation=$documentedDeviation raisedAt=$(if($mismatchQuestion){$mismatchQuestion[0].Index}else{-1}) implementationWriteAt=$(if($implementationWrite){$implementationWrite[0].Index}else{-1}) typedEvidenceOnly=True"
            }
        }
        { $_ -in @('warehouse-bind-sql','warehouse-bind-mixed') } {
            $successful = @($e.Tools | Where-Object {
                $e.ToolResults.ContainsKey($_.Id) -and -not $e.ToolResults[$_.Id].is_error
            })
            # C1..C5 reach channels, retargeted from map-warehouse to add-warehouse-load. Deliberately
            # the SAME shape as the warehouse-route grader: a second classification scheme would make
            # the read-side and write-side families incomparable for no gain.
            $c1 = [bool]@($successful | Where-Object { $_.Name -eq 'Skill' -and $_.Input.skill -eq 'add-warehouse-load' } | Select-Object -First 1)
            $c2 = [bool]@($successful | Where-Object {
                $_.Name -match '^(?i:Read|ReadFile|read_file)$' -and
                (Get-ToolPath $_) -replace '\\','/' -match '(?i)(?:^|/)docs/warehouse-map\.md$' -and
                (Get-ToolResultText $e $_).Trim()
            } | Select-Object -First 1)
            $c3 = [bool]@($successful | Where-Object {
                $_.Name -match '^(?i:Read|ReadFile|read_file)$' -and
                (Get-ToolPath $_) -replace '\\','/' -match '(?i)(?:^|/)\.(?:claude|github)/skills/add-warehouse-load/SKILL\.md$' -and
                (Get-ToolResultText $e $_).Trim()
            } | Select-Object -First 1)
            $c4 = [bool]@($successful | Where-Object {
                $_.Name -in @('Bash','PowerShell') -and
                [string]$_.Input.command -match '(?i)warehouse-map\.md|add-warehouse-load' -and
                (Get-ToolResultText $e $_).Trim()
            } | Select-Object -First 1)
            $c5 = [bool]@($successful | Where-Object {
                $_.Name -in @('Grep','Glob') -and
                (([string]$_.Input.pattern + ' ' + [string]$_.Input.path + ' ' + [string]$_.Input.glob) -match '(?i)warehouse-map\.md|add-warehouse-load') -and
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
            # Outcome 3 -- the OLTP mis-route. Structurally invisible on the pure-SQL fixture (there is
            # no EF Core there for add-entity to be tempting about), which is exactly why
            # warehouse-bind-mixed exists. Reported on both so the pair isolates the .NET side's effect.
            $reachedAddEntity = [bool]@($successful | Where-Object {
                ($_.Name -eq 'Skill' -and $_.Input.skill -eq 'add-entity') -or
                ($_.Name -match '^(?i:Read|ReadFile|read_file)$' -and ((Get-ToolPath $_) -replace '\\','/') -match '(?i)(?:^|/)\.(?:claude|github)/skills/add-entity/SKILL\.md$')
            } | Select-Object -First 1)

            $sqlFiles = @(Get-ChildItem -LiteralPath $Target -Filter '*.sql' -File -Recurse -ErrorAction SilentlyContinue)
            $allSql = @($sqlFiles | ForEach-Object { Get-Content -Raw -LiteralPath $_.FullName }) -join "`n"
            if ($null -eq $allSql) { $allSql = '' }
            # Dimension inventory by CONTENT, not by filename or path diff: a duplicate dimension
            # appended to an existing file is the same defect as one in a new file, and a
            # --diff-filter=A path scan misses it entirely.
            #
            # Match on the SCHEMA, not on a `Dim` name prefix. The first version keyed on
            # `Dim[A-Za-z0-9_]+` and therefore reported "no new dimensions" for a live run that
            # created `dim.CustomerXref` and `dim.ProductXref` -- two new tables in the dimension
            # schema, invisible to the measure that exists to count exactly that.
            #
            # A source-key cross-reference table IS scored as a violation here, deliberately and for
            # a reason taken from the recipe rather than from the result: this warehouse resolves
            # source keys by joining staging's natural key straight to the dimension's
            # (`usp_LoadFactSales`: `JOIN dim.DimCustomer c ON c.CustomerId = s.CustomerId`). An xref
            # table is a *second style* for the same job, and step 1 already says "One warehouse, one
            # loading pattern: never introduce a second style."
            $baselineDims = @('DimCustomer','DimRegion','DimProduct','DimDate')
            $declaredDims = @([regex]::Matches($allSql, '(?is)\bCREATE\s+TABLE\s+\[?dim\]?\s*\.\s*\[?(?<name>[A-Za-z0-9_]+)\]?') |
                ForEach-Object { $_.Groups['name'].Value } | Sort-Object -Unique)
            $newDimTables = @($declaredDims | Where-Object { $_ -notin $baselineDims })

            # Located by content wherever it landed -- the allowed-correct set permits any file layout,
            # so anchoring on a required path would fail a correct implementation for a naming choice.
            #
            # Terminator is `);` OR `)` followed by end-of-input / `GO` / a blank line. The first
            # version required a trailing semicolon and would have scored factWritten=False for
            # perfectly ordinary SSDT DDL ending at `)` or followed by `GO`. It only ever passed
            # because the fixture happened to end `);` -- a measure that worked by luck.
            $factMatch = [regex]::Match($allSql, '(?is)\bCREATE\s+TABLE\s+(?:\[?fact\]?\s*\.\s*)?\[?FactSupplierInvoice\]?\s*\((?<body>.*?)\)\s*(?:;|\s*GO\b|\s*$|\r?\n\s*\r?\n)')
            $factWritten = $factMatch.Success
            $factBody = if ($factWritten) { $factMatch.Groups['body'].Value } else { '' }
            # A declared column proves nothing about how it is populated: a fact can declare
            # CustomerKey and have its load insert a constant -1, never touching the dimension.
            # The load procedure's resolution join is the evidence that the key was actually BOUND,
            # and the design said so ("fact DDL + load proc join") while the first implementation
            # checked only the DDL token.
            $loadProcText = @($sqlFiles | Where-Object { $_.Name -match '(?i)SupplierInvoice' -and (Get-Content -Raw -LiteralPath $_.FullName) -match '(?i)\bCREATE\s+(?:OR\s+ALTER\s+)?PROC' } |
                ForEach-Object { Get-Content -Raw -LiteralPath $_.FullName }) -join "`n"
            if ($null -eq $loadProcText) { $loadProcText = '' }
            function Test-ResolvedKey([string]$Proc, [string]$Dim, [string]$NaturalKey) {
                if (-not $Proc) { return $false }
                # The load must reference the dimension AND join on its business key -- that pairing
                # is what distinguishes a resolution from a constant or a bare mention in a comment.
                return ($Proc -match "(?is)\b(?:JOIN|FROM|USING|MERGE)\s+(?:\[?dim\]?\s*\.\s*)?\[?$Dim\]?\b") -and ($Proc -match "(?i)\b$NaturalKey\b")
            }
            $resolvedCustomer = Test-ResolvedKey $loadProcText 'DimCustomer' 'CustomerId'
            $resolvedProduct  = Test-ResolvedKey $loadProcText 'DimProduct'  'ProductId'
            $resolvedDate     = Test-ResolvedKey $loadProcText 'DimDate'     'CalendarDate'
            $boundCustomer = $factBody -match '(?i)\bCustomerKey\b'
            $boundProduct  = $factBody -match '(?i)\bProductKey\b'
            $boundDate     = $factBody -match '(?i)\b[A-Za-z]*DateKey\b'
            # The snowflake violation. Region is reached through DimCustomer.RegionKey in this
            # warehouse -- rpt.vwFinanceExtract is the proof -- so a RegionKey on the new fact is a
            # second, contradictory path to the same dimension.
            $regionOnFact  = $factBody -match '(?i)\b[A-Za-z]*RegionKey\b'
            # Narrow on purpose: natural key IN PLACE OF the surrogate. Carrying both is a defensible
            # traceability choice and must not be scored as the defect.
            #
            # Matched by SHAPE, not by an enumerated list of spellings. The first version listed
            # `cust_ref|CustRef|CustomerId|CustomerCode` and reported naturalKeyOnFact=False for a
            # live fact declaring `SupplierCustomerRef NVARCHAR(50)` -- the defect itself, invisible
            # because the model prefixed the column. Any <something>Cust/Prod<something><Ref|Code|Id|
            # No|Num> counts; `...Key` deliberately does not appear in the suffix set.
            $custNatural = $factBody -match '(?i)\b(?:cust_ref|[A-Za-z_]*Cust(?:omer)?[A-Za-z_]*(?:Ref|Code|Id|No|Num))\b'
            $prodNatural = $factBody -match '(?i)\b(?:prod_ref|[A-Za-z_]*Prod(?:uct)?[A-Za-z_]*(?:Ref|Code|Id|No|Num))\b'
            $naturalKeyOnFact = ($custNatural -and -not $boundCustomer) -or ($prodNatural -and -not $boundProduct)
            $degenerateOnFact = $factBody -match '(?i)\b(?:InvoiceNo|InvoiceNumber|Invoice_No)\b'

            $warehouseTreeCall = [bool]@($e.Tools | Where-Object {
                (((Get-ToolPath $_) -replace '\\','/') -match '(?i)(?:^|/)(?:Tables|StoredProcedures|Views)(?:/|$)') -or
                (([string]$_.Input.command + ' ' + [string]$_.Input.path + ' ' + [string]$_.Input.glob) -match '(?i)Tables|StoredProcedures|Views|\.sql')
            } | Select-Object -First 1)
            # No fact artifact means there is nothing on which absence-shaped outcome signals can
            # be observed. An engaged run that only inspected the tree is still INCONCLUSIVE;
            # reporting regionOnFact=False/newDimTables='' would turn "produced nothing" into the
            # desirable answer and was the B-120 false-green.
            $status = if (-not $factWritten) { 'INCONCLUSIVE' } else { 'PASS' }
            $channels = @()
            if ($c1) { $channels += 'C1' }
            if ($c2) { $channels += 'C2' }
            if ($c3) { $channels += 'C3' }
            if ($c4) { $channels += 'C4' }
            if ($c5) { $channels += 'C5' }
            # Binding = the column is declared AND the load resolves it. Either alone is insufficient:
            # a declared column may never be populated, and a resolution join with no column to land
            # in is not a binding either.
            $bindCustomer = $boundCustomer -and $resolvedCustomer
            $bindProduct  = $boundProduct  -and $resolvedProduct
            $bindDate     = $boundDate     -and $resolvedDate
            $pass = $status -eq 'PASS' -and $factWritten -and $bindCustomer -and $bindProduct -and $bindDate -and
                $newDimTables.Count -eq 0 -and -not $regionOnFact -and -not $naturalKeyOnFact
            if (-not $factWritten) {
                return [pscustomobject]@{ Status = $status; Pass = $false; Detail = "category=$category channels=$($channels -join ',') reachedAddEntity=$reachedAddEntity factWritten=False boundCustomer=n/a boundProduct=n/a boundDate=n/a resolvedCustomer=n/a resolvedProduct=n/a resolvedDate=n/a regionOnFact=n/a naturalKeyOnFact=n/a degenerateOnFact=n/a newDimTables=n/a" }
            }
            return [pscustomobject]@{ Status = $status; Pass = $pass; Outcome = [bool]$pass; Detail = "category=$category channels=$($channels -join ',') reachedAddEntity=$reachedAddEntity factWritten=$factWritten boundCustomer=$boundCustomer boundProduct=$boundProduct boundDate=$boundDate resolvedCustomer=$resolvedCustomer resolvedProduct=$resolvedProduct resolvedDate=$resolvedDate regionOnFact=$regionOnFact naturalKeyOnFact=$naturalKeyOnFact degenerateOnFact=$degenerateOnFact newDimTables=$($newDimTables -join ',')" }
        }
        'warehouse-health-decision-a' {
            $mapPath = Join-Path $Target 'docs/warehouse-map.md'
            $reviewPath = Join-Path $Target 'docs/warehouse-review.md'
            if (-not (Test-Path -LiteralPath $mapPath -PathType Leaf) -or -not (Test-Path -LiteralPath $reviewPath -PathType Leaf)) {
                return [pscustomobject]@{ Status='INCONCLUSIVE'; Pass=$false; Detail='mapWritten=False reviewWritten=False' }
            }
            $mapText = Get-Content -Raw -LiteralPath $mapPath
            $reviewText = Get-Content -Raw -LiteralPath $reviewPath
            $mapFindings = [regex]::Match($mapText, '(?ims)^##(?:#*)\s+(?:\d+\.\s*)?Findings\b[^\r\n]*\r?\n(?<body>.*?)(?=^##(?:#*)\s|\z)').Groups['body'].Value
            $mapHasAdditivityFinding = $mapFindings -match '(?im)^\s*\|[^\r\n]*EndOfDayBalance[^\r\n]*(?:semi.additive|non.additive|additivity)[^\r\n]*\|'
            $rejectsUnsafe = $reviewText -match '(?i)(unsafe|reject|not safe|incorrect)'
            $citesFinding = $reviewText -match '(?i)EndOfDayBalance' -and $reviewText -match '(?i)(semi.additive|finding|warehouse-map)'
            $singleAsOf = $reviewText -match '(?i)(?:single|one)\s+(?:requested\s+)?(?:as.of|selected|reporting)\s+(?:day|date)|(?:single|one)\s+(?:day|date)\s+parameter'
            $prohibitsCrossDate = $reviewText -match '(?i)(?:do not|must not|never)[^.!\r\n]{0,100}(?:sum|aggregat)[^.!\r\n]{0,100}(?:across|over|between|more than one|two|both|several|multiple|all|every)[^.!\r\n]{0,60}(?:day|date)|(?:do not|must not|never)[^.!\r\n]{0,100}(?:combine)[^.!\r\n]{0,100}(?:day|date)'
            $activeCrossDate = [bool]@($reviewText -split '[.!?;\r\n]+' | Where-Object {
                $_ -match '(?i)(?:sum|aggregat|combine)' -and
                $_ -match '(?i)(?:across|over|between|more than one|two|both|several|multiple|all|every)[^\r\n]{0,60}(?:day|date)|(?:day|date)[^\r\n]{0,60}(?:two|both|several|multiple|all|every)' -and
                $_ -notmatch '(?i)(?:do not|must not|never)'
            } | Select-Object -First 1)
            $correctsShape = $reviewText -match '(?i)(closing|last|latest)' -and $singleAsOf -and $prohibitsCrossDate -and -not $activeCrossDate
            return [pscustomobject]@{ Status='PASS'; Pass=($mapHasAdditivityFinding -and $rejectsUnsafe -and $citesFinding -and $correctsShape); Detail="mapWritten=True reviewWritten=True mapHasAdditivityFinding=$mapHasAdditivityFinding rejectsUnsafe=$rejectsUnsafe citesFinding=$citesFinding correctsShape=$correctsShape" }
        }
        { $_ -in @('warehouse-health-default-a','warehouse-health-default-b','warehouse-health-deep-b','warehouse-health-clean','warehouse-health-convention','warehouse-health-no-trigger','warehouse-health-bridge-ok') } {
            $mapPath = Join-Path $Target 'docs/warehouse-map.md'
            if (-not (Test-Path -LiteralPath $mapPath -PathType Leaf)) {
                return [pscustomobject]@{ Status='INCONCLUSIVE'; Pass=$false; Detail='mapWritten=False' }
            }
            $mapText = Get-Content -Raw -LiteralPath $mapPath
            if ($null -eq $mapText -or -not $mapText.Trim()) {
                return [pscustomobject]@{ Status='INCONCLUSIVE'; Pass=$false; Detail='mapWritten=False' }
            }
            function Get-MarkdownSection([string]$Text, [string]$Heading) {
                $match = [regex]::Match($Text, "(?ims)^##(?:#*)\s+(?:\d+\.\s*)?$([regex]::Escape($Heading))\b[^\r\n]*\r?\n(?<body>.*?)(?=^##(?:#*)\s|\z)")
                if ($match.Success) { return $match.Groups['body'].Value }
                return ''
            }
            function Find-HealthRow([string]$Section, [string[]]$Required, [string[]]$Semantics) {
                if (-not $headerValid) { return [pscustomobject]@{ Found=$false; Tier='Missing'; Severity='Missing'; Complete=$false; Line='' } }
                foreach ($healthLine in @($Section -split '\r?\n')) {
                    if ($healthLine -notmatch '^\s*\|') { continue }
                    $healthRawCells = $healthLine.Trim().Trim('|') -split '\|'
                    $healthCells = @($healthRawCells | ForEach-Object { $_.Trim() })
                    if ($healthCells.Count -ne 7) { continue }
                    $healthHasRequired = $true
                    foreach ($healthRequiredText in $Required) {
                        if ($healthCells[1] -notmatch [regex]::Escape($healthRequiredText)) { $healthHasRequired = $false; break }
                    }
                    $healthHasSemantics = $true
                    foreach ($healthSemanticPattern in $Semantics) {
                        if ($healthCells[2] -notmatch $healthSemanticPattern) { $healthHasSemantics = $false; break }
                    }
                    if ($healthHasRequired -and $healthHasSemantics) {
                        $healthTier = if ($healthCells[3] -match '(?i)^Confirmed\b') { 'Confirmed' }
                            elseif ($healthCells[3] -match '(?i)^Likely\b') { 'Likely' }
                            elseif ($healthCells[3] -match '(?i)^Possible\b') { 'Possible' }
                            else { 'Missing' }
                        $healthComplete = @($healthCells[2],$healthCells[4],$healthCells[5],$healthCells[6] |
                            Where-Object { -not $_ -or $_.Length -lt 4 -or $_ -match '^(?:-|—|n/?a|unknown|tbd)$' }).Count -eq 0
                        return [pscustomobject]@{ Found=$true; Tier=$healthTier; Severity=$healthCells[4]; Complete=$healthComplete; Line=$healthLine }
                    }
                }
                return [pscustomobject]@{ Found=$false; Tier='Missing'; Severity='Missing'; Complete=$false; Line='' }
            }
            $findings = Get-MarkdownSection $mapText 'Findings'
            $coverage = Get-MarkdownSection $mapText 'Coverage'
            $edgeList = Get-MarkdownSection $mapText 'Relationship edge list'
            $dimensionalSemantics = Get-MarkdownSection $mapText 'Dimensional semantics'
            $expectedHealthHeader = @('finding','entity','evidence','finding confidence','severity if confirmed','consequence','remediation')
            $findingsLines = @($findings -split '\r?\n')
            $headerValid = $false
            foreach ($findingsLine in $findingsLines) {
                if ($findingsLine -notmatch '^\s*\|') { continue }
                $headerCells = @(($findingsLine.Trim().Trim('|') -split '\|') | ForEach-Object { ($_ -replace '[*_`]','').Trim().ToLowerInvariant() })
                if ($headerCells.Count -eq 7 -and (@(Compare-Object $expectedHealthHeader $headerCells -SyncWindow 0).Count -eq 0)) { $headerValid = $true; break }
            }
            $findingDataRows = @($findingsLines | Where-Object {
                $_ -match '^\s*\|' -and $_ -notmatch '^\s*\|\s*(?:finding\s*\||[-:]+\s*\|)'
            })
            $truncated = $mapText -match '(?im)^\s*(?:>\s*)?(?:\[?TRUNCATED\]?|OUTPUT LIMIT|CONTINUED ELSEWHERE)\b' -or -not $headerValid

            $mixed = Find-HealthRow $findings @('FactAccountActivity') @('(?i)(row identity|grain|TRANSACTION)','(?i)(DAILY_POSITION|periodic|snapshot|position)')
            $natural = Find-HealthRow $findings @('FactAccountActivity','CustomerId') @('(?i)(natural|business|raw|text)','(?i)(surrogate|dimension key|CustomerKey)')
            $scd = Find-HealthRow $findings @('DimCustomer') @('(?i)SCD|Type\s*2','(?i)(history|version|WHEN MATCHED|IsCurrent)')
            $additivity = Find-HealthRow $findings @('FactAccountActivity','EndOfDayBalance') @('(?i)(semi.additive|non.additive|additivity)','(?i)(time|date|sum)')
            $roleText = $edgeList + "`n" + $dimensionalSemantics + "`n" + $coverage
            $roleCoverage = $roleText -match '(?is)FactAccountActivity.*PostedDateKey.*SettledDateKey.*role|FactAccountActivity.*role.*PostedDateKey.*SettledDateKey'
            $roleFinding = $findings -match '(?is)FactAccountActivity.*(?:PostedDateKey|SettledDateKey).*role'
            $role = $roleCoverage -and -not $roleFinding

            $conformance = Find-HealthRow $findings @('sales.DimParty','service.DimParty','PartyCode') @('(?i)(conform|same governed party)','(?i)(grain|contact|column)')
            $special = Find-HealthRow $findings @('DimStatus') @('(?:-1|`-1`)','(?:0|`0`)','(?i)(same label|indistinguishable|ambiguous|Unknown)')
            $bridge = Find-HealthRow $findings @('FactSales','CampaignKey') @('(?i)(many.to.many|several|multiple)','(?i)(?:single|one\s+scalar)[^|]*(?:FK|key|column)[^|]*cannot|cannot[^|]*(?:FK|key|column)')
            $fan = Find-HealthRow $findings @('vwCustomerCommercialSummary','FactSales','FactReturn') @('(?i)multipl(?:y|ies|ied|ication)','(?i)(pre.aggregat|preaggregat)')

            $successful = @($e.Tools | Where-Object { $e.ToolResults.ContainsKey($_.Id) -and -not $e.ToolResults[$_.Id].is_error })
            $additivityLoadRead = [bool]@($successful | Where-Object {
                ((Get-ToolPath $_) -replace '\\','/') -match '(?i)StoredProcedures/usp_LoadFactAccountActivity\.sql$' -or
                (([string]$_.Input.command + ' ' + [string]$_.Input.path + ' ' + [string]$_.Input.pattern) -match '(?i)usp_LoadFactAccountActivity')
            } | Select-Object -First 1)
            $additivityConsumerRead = [bool]@($successful | Where-Object {
                $_.Name -match '^(?i:Read|ReadFile|read_file)$' -and
                ((Get-ToolPath $_) -replace '\\','/') -match '(?i)Views/rpt\.vwDailyAccountPosition\.sql$'
            } | Select-Object -First 1)

            $mixedPass = $mixed.Found -and $mixed.Tier -in @('Likely','Confirmed') -and $mixed.Complete -and $mixed.Severity -match '(?i)blocking|significant'
            $naturalPass = $natural.Found -and $natural.Tier -eq 'Confirmed' -and $natural.Complete -and $natural.Severity -match '(?i)blocking|significant'
            $scdPass = $scd.Found -and $scd.Tier -eq 'Confirmed' -and $scd.Complete -and $scd.Severity -match '(?i)blocking|significant'
            $additivityPass = $additivity.Found -and $additivity.Tier -eq 'Confirmed' -and $additivity.Complete -and $additivity.Severity -match '(?i)blocking|significant' -and $additivityLoadRead -and $additivityConsumerRead
            $conformancePass = $conformance.Found -and $conformance.Tier -eq 'Confirmed' -and $conformance.Complete -and $conformance.Severity -match '(?i)blocking|significant'
            $specialPass = $special.Found -and $special.Tier -eq 'Confirmed' -and $special.Complete -and $special.Severity -match '(?i)significant|advisory'
            $bridgePass = $bridge.Found -and $bridge.Tier -eq 'Confirmed' -and $bridge.Complete -and $bridge.Severity -match '(?i)blocking|significant'
            $fanPass = $fan.Found -and $fan.Tier -eq 'Confirmed' -and $fan.Complete -and $fan.Severity -match '(?i)blocking|significant'
            $candidateRows = @($mixed.Found,$natural.Found,$scd.Found,$additivity.Found,$role,$conformance.Found,$special.Found,$bridge.Found,$fan.Found) | Where-Object { $_ }

            $pass = switch ($Id) {
                'warehouse-health-default-a' { $mixedPass -and $naturalPass -and $scdPass -and $additivityPass -and $role }
                'warehouse-health-default-b' { $conformancePass -and $specialPass -and -not $bridge.Found -and -not $fan.Found }
                'warehouse-health-deep-b' { $bridgePass -and $fanPass }
                'warehouse-health-clean' { $findingDataRows.Count -eq 0 }
                'warehouse-health-convention' { $findingDataRows.Count -eq 0 }
                'warehouse-health-no-trigger' { $findingDataRows.Count -eq 0 }
                'warehouse-health-bridge-ok' { -not $bridge.Found }
            }
            $status = if ($truncated) { 'INCONCLUSIVE' } else { 'PASS' }
            return [pscustomobject]@{ Status=$status; Pass=($status -eq 'PASS' -and $pass); Detail="mapWritten=True truncated=$truncated headerValid=$headerValid mixed=$mixedPass tierMixed=$($mixed.Tier) natural=$naturalPass tierNatural=$($natural.Tier) scd=$scdPass tierScd=$($scd.Tier) additivity=$additivityPass tierAdditivity=$($additivity.Tier) loadRead=$additivityLoadRead consumerRead=$additivityConsumerRead roleCoverage=$role conformance=$conformancePass tierConformance=$($conformance.Tier) special=$specialPass tierSpecial=$($special.Tier) bridge=$bridgePass tierBridge=$($bridge.Tier) fanChasm=$fanPass tierFanChasm=$($fan.Tier) candidateRows=$($candidateRows.Count) findingRows=$($findingDataRows.Count)" }
        }
        'warehouse-map-quality' {
            $mapPath = Join-Path $Target 'docs/warehouse-map.md'
            if (-not (Test-Path -LiteralPath $mapPath -PathType Leaf)) {
                return [pscustomobject]@{ Status = 'INCONCLUSIVE'; Pass = $false; Detail = 'mapWritten=False hasEdgeList=False hasVersionResolution=False edgeRows=0 abstained=False deadColumnsFlagged=0 hasQueryRules=False hasCoverage=False hasFindingsTable=False findingRows=0 findingsFields= pinnedAtLoad=False' }
            }
            $mapText = Get-Content -Raw -LiteralPath $mapPath
            if ($null -eq $mapText) { $mapText = '' }
            $mapWritten = $mapText.Trim().Length -gt 0
            # Header/data-row detection: a header row is any `|...|` line immediately followed by a
            # markdown separator row (`|---|---|...`). Restricting to that shape keeps prose
            # mentioning these column names from being mistaken for the edge-list table itself.
            $mapLines = $mapText -split '\r?\n'
            $headerLines = [Collections.Generic.List[string]]::new()
            for ($lineIndex = 0; $lineIndex -lt $mapLines.Count - 1; $lineIndex++) {
                if ($mapLines[$lineIndex] -match '^\s*\|' -and $mapLines[$lineIndex + 1] -match '^\s*\|[-:\|\s]+\|\s*$') {
                    $headerLines.Add($mapLines[$lineIndex])
                }
            }
            $edgeHeaderLine = @($headerLines | Where-Object {
                $_ -match '(?i)\bfact\b' -and $_ -match '(?i)fk column' -and $_ -match '(?i)dimension' -and $_ -match '(?i)\bevidence\b' -and $_ -match '(?i)\bconfidence\b'
            } | Select-Object -First 1)
            $hasEdgeList = $edgeHeaderLine.Count -gt 0
            $hasVersionResolution = $hasEdgeList -and ($edgeHeaderLine[0] -match '(?i)version resolution')
            # Case-sensitive on purpose: under IgnoreCase, .NET treats [A-Z] as matching lowercase
            # too, so "dimension" in prose would otherwise satisfy \bDim[A-Z]. Real table names are
            # PascalCase (DimCustomer, DimRegion, ...); require that case to count as an edge row.
            $edgeRows = @([regex]::Matches($mapText, '(?m)^\s*\|.*\|\s*$') | Where-Object {
                $_.Value -notmatch '^\s*\|[-:\|\s]+\|\s*$' -and $_.Value -cmatch 'FactSales' -and $_.Value -cmatch '\bDim[A-Z][A-Za-z]*\b'
            }).Count
            $abstained = $mapText -cmatch 'UNRESOLVED'
            $deadColumnsFlagged = @(@('RegionName', 'CategoryName', 'SegmentName') | Where-Object { $mapText -cmatch "\b$_\b" }).Count
            $hasQueryRules = $mapText -match '(?im)^\s*#{1,6}.*Querying this warehouse'
            $hasCoverage = $mapText -match '(?im)^\s*(#{1,6}\s*.*\bCoverage\b|\*\*[^*\r\n]*\bCoverage\b[^*\r\n]*\*\*)'
            $findingsHeaderLine = @($headerLines | Where-Object {
                $_ -match '(?i)\bfinding\b' -and $_ -match '(?i)\bentity\b' -and
                $_ -match '(?i)\bevidence\b' -and $_ -match '(?i)finding confidence' -and
                $_ -match '(?i)severity if confirmed' -and $_ -match '(?i)\bconsequence\b' -and
                $_ -match '(?i)\bremediation\b'
            } | Select-Object -First 1)
            $hasFindingsTable = $findingsHeaderLine.Count -gt 0
            $findingRows = 0
            if ($hasFindingsTable) {
                $headerIndex = [Array]::IndexOf($mapLines, $findingsHeaderLine[0])
                for ($findingLineIndex = $headerIndex + 2; $findingLineIndex -lt $mapLines.Count; $findingLineIndex++) {
                    if ($mapLines[$findingLineIndex] -notmatch '^\s*\|') { break }
                    if ($mapLines[$findingLineIndex] -notmatch '^\s*\|[-:\|\s]+\|\s*$') { $findingRows++ }
                }
            }
            $findingsFields = @()
            if ($hasFindingsTable) {
                foreach ($field in @('evidence','finding confidence','severity if confirmed','consequence','remediation')) {
                    if ($findingsHeaderLine[0] -match "(?i)$([regex]::Escape($field))") { $findingsFields += ($field -replace ' ','-') }
                }
            }
            $pinnedAtLoad = $mapText -cmatch 'Pinned at load'
            $pass = $mapWritten -and $hasEdgeList -and $hasVersionResolution -and $edgeRows -ge 3 -and $abstained -and $hasQueryRules -and $hasCoverage -and $hasFindingsTable -and $findingRows -ge 1
            return [pscustomobject]@{ Status = 'PASS'; Pass = $pass; Detail = "mapWritten=$mapWritten hasEdgeList=$hasEdgeList hasVersionResolution=$hasVersionResolution edgeRows=$edgeRows abstained=$abstained deadColumnsFlagged=$deadColumnsFlagged hasQueryRules=$hasQueryRules hasCoverage=$hasCoverage hasFindingsTable=$hasFindingsTable findingRows=$findingRows findingsFields=$($findingsFields -join ',') pinnedAtLoad=$pinnedAtLoad" }
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
        # B-406 S1: on the natural-language path, does the agent post Done-when criteria with a boundary example
        # and stop with no file written? Main-agent text only: a subagent's contract is not the developer's.
        'contract-restate' {
            $hooks = Get-B406Hooks $Transcript
            if (-not $hooks.Loaded) { return [pscustomobject]@{ Status = 'INCONCLUSIVE'; Pass = $false; Detail = "hooks=False no successful SessionStart and UserPromptSubmit hook_response in the transcript, so the framework did not load durationMs=$(Get-B406Duration $e)" } }
            $contract = Get-B406Contract $e $Target
            return [pscustomobject]@{ Status = 'PASS'; Pass = ($contract.Class -eq 'CONTRACT'); Detail = "hooks=True rails=$($hooks.Rails) $(Get-B406ContractDetail $contract) subagents=$($contract.Subagents) durationMs=$(Get-B406Duration $e)" }
        }
        # B-406 S2: with the approval clause, did the run implement, test each stated outcome, close with the
        # Verification & confidence block, and run the framework's own security pass? The contract fields are
        # reported, not gating. A run that changed nothing under src/ examined nothing.
        { $_ -in @('contract-trace', 'contract-trace-ci', 'contract-trace-ci-cap') } {
            $hooks = Get-B406Hooks $Transcript
            if (-not $hooks.Loaded) { return [pscustomobject]@{ Status = 'INCONCLUSIVE'; Pass = $false; Detail = "hooks=False no successful SessionStart and UserPromptSubmit hook_response in the transcript, so the framework did not load durationMs=$(Get-B406Duration $e)" } }
            # Changed or new since the pre-run snapshot, so the install, the overlay and a -TargetPatch never count as the agent's change.
            $changed = @(Get-B406Changes $Target | Where-Object { Test-Path -LiteralPath (Join-Path $Target $_) -PathType Leaf })
            $srcChanged = @($changed | Where-Object { $_ -match '^src/' })
            $testFiles = @($changed | Where-Object { $_ -match '^tests/.*\.cs$' })
            if ($srcChanged.Count -eq 0) {
                return [pscustomobject]@{ Status = 'INCONCLUSIVE'; Pass = $false; Detail = "hooks=True rails=$($hooks.Rails) nothing changed under src/ since the pre-run snapshot (build output ignored), so the run implemented nothing to trace durationMs=$(Get-B406Duration $e)" }
            }
            # Candidates for the closing block: each result event, and each main-agent text block, that comes after the
            # first main-agent Write-type call (all of them if there is none). A run whose security pass ran in the
            # background continues in further turns, and the Stop hook's Boy Scout note can make the agent's reply to it
            # a turn's result, displacing the report; so the block may sit in any one of them. It must sit whole in ONE:
            # four parts scattered over several blocks or turns is not a report. Results first, then text, in order.
            $traceWrite = @($e.Tools | Where-Object { -not $_.Sidechain -and (Test-B406Write $_) } | Select-Object -First 1)
            $traceFrom = if ($traceWrite) { $traceWrite[0].Index } else { 0 }
            $traceCandidates = @(
                for ($r = 0; $r -lt $e.Results.Count; $r++) { if ($e.ResultOrdinals[$r] -gt $traceFrom) { [string]$e.Results[$r].result } }
                $e.Texts | Where-Object { -not $_.Sidechain -and $_.Index -gt $traceFrom } | ForEach-Object { $_.Text }
            )
            $trace = 'NONE'
            $missing = @('beyond', 'blast', 'depth', 'pair')
            $bestParts = -1
            foreach ($candidate in $traceCandidates) {
                $traceParts = Get-B406TraceParts $candidate
                $present = @($traceParts.Keys | Where-Object { $traceParts[$_] })
                if ($present.Count -gt $bestParts) {
                    $bestParts = $present.Count
                    $missing = @($traceParts.Keys | Where-Object { -not $traceParts[$_] })
                    $trace = if ($present.Count -eq $traceParts.Count) { 'FULL' } elseif ($present.Count -gt 0) { 'PARTIAL' } else { 'NONE' }
                }
            }
            # B-407, reported and never gating: TRACE-LAST is the last result alone (what the developer ends on), LABELS the
            # labels found in any result or main-agent text of the run, whenever written.
            $lastParts = Get-B406TraceParts $(if ($e.Results.Count -gt 0) { [string]$e.Results[$e.Results.Count - 1].result } else { '' })
            $lastHit = @($lastParts.Keys | Where-Object { $lastParts[$_] })
            $traceLast = if ($lastHit.Count -eq $lastParts.Count) { 'FULL' } elseif ($lastHit.Count -gt 0) { 'PARTIAL' } else { 'NONE' }
            $allText = (@($e.Results | ForEach-Object { [string]$_.result }) + @($e.Texts | Where-Object { -not $_.Sidechain } | ForEach-Object { $_.Text })) -join "`n"
            $labelsSeen = @(@('beyond', $b406TraceBeyond), @('blast', $b406TraceBlast), @('depth', $b406TraceDepth) | Where-Object { $allText -match $_[1] } | ForEach-Object { $_[0] })
            $labels = if ($labelsSeen) { $labelsSeen -join ',' } else { 'none' }
            $tests = 'n/a'
            if ($testFiles.Count -gt 0) {
                $testText = ($testFiles | ForEach-Object { Get-Content -Raw -LiteralPath (Join-Path $Target $_) }) -join "`n"
                $named = [ordered]@{ '202' = [bool]($testText -match $b406Status202); '404' = [bool]($testText -match $b406Status404); '409' = [bool]($testText -match $b406Status409) }
                $hit = @($named.Keys | Where-Object { $named[$_] })
                $tests = if ($hit.Count -eq $named.Count) { 'ALL' } elseif ($hit.Count -gt 0) { "SOME($($hit -join ','))" } else { 'NONE' }
            }
            # The framework's own security pass, in the main agent or a subagent: side= is whether it examined the change,
            # sideCalled= the older was-it-called count.
            $sideCheck = Get-B406Side $e
            $side = $sideCheck.Class
            $contract = Get-B406Contract $e $Target
            return [pscustomobject]@{ Status = 'PASS'; Pass = ($trace -eq 'FULL'); Detail = "hooks=True rails=$($hooks.Rails) trace=$trace$(if ($trace -eq 'PARTIAL') { " missing=$($missing -join ',')" }) tests=$tests side=$side sideCalled=$($sideCheck.Called) subagents=$($contract.Subagents) $(Get-B406ContractDetail $contract) traceLast=$traceLast labels=$labels durationMs=$(Get-B406Duration $e)" }
        }
        # B-410: does the developer see a design (options A and B, each with its cost, and a recommendation) before any write? K is
        # two legs of one session (the prompt, then a fixed answer); the decoy is one. Landing is graded on labelled lines in main-agent
        # text before the first main-agent write, across both legs; the cost-per-option and the quality are hand-read, not scored.
        { $_ -in @('risk-design-k', 'done-when-k', 'done-when-h') -or $_ -match '^risk-design-d\d*$' } {
            $twoLeg = $Id -in @('risk-design-k', 'done-when-k', 'done-when-h')
            $boundary = if ($Transcript.LegEnds) { [int]@($Transcript.LegEnds)[0] } else { 0 }
            $legs = if ($boundary -gt 0) { 2 } else { 1 }
            $hooks = Get-RiskHooks $Transcript $boundary
            if (-not $hooks.Loaded) { return [pscustomobject]@{ Status = 'INCONCLUSIVE'; Pass = $false; Detail = "hooks=False no successful SessionStart and UserPromptSubmit hook_response in the transcript, so the framework did not load durationMs=$(Get-B406Duration $e)" } }
            $design = Get-RiskDesign $e $boundary
            $mainTexts = @($e.Texts | Where-Object { -not $_.Sidechain -and ($boundary -eq 0 -or $_.Index -le $boundary) })
            $turnOne = Get-RiskTurnOne (($mainTexts | ForEach-Object { $_.Text }) -join "`n")
            $contract = Get-B406Contract $e $Target
            # Leg 2 runs only after a leg 1 that wrote nothing, so a write in leg 1 means the agent did not stop for the developer.
            $leg1Write = @($e.Tools | Where-Object { (Test-B406Write $_) -and ($boundary -eq 0 -or $_.Index -le $boundary) }).Count -gt 0
            $wroteT1 = if ($legs -eq 1) { -not (Test-B406NoFileWrite $e $Target) } else { $leg1Write }
            $t2action = 'n/a'
            if ($legs -eq 2) {
                $leg2Write = @($e.Tools | Where-Object { (Test-B406Write $_) -and $_.Index -gt $boundary }).Count -gt 0
                $t2action = if ($leg2Write -or @(Get-B406Changes $Target).Count) { 'WROTE' } else { 'WAITED' }
            }
            $waited = $design.Class -eq 'FULL' -and -not $wroteT1 -and ($design.Locus -eq 'leg1' -or $t2action -eq 'WAITED')
            $fields = "hooks=True rails1=$($hooks.Rails) rails2=$($hooks.Rails2) session2=$($hooks.Session2) legs=$legs design=$($design.Class) locus=$($design.Locus) designT2=$($design.T2) t1q=$($turnOne.Questions) t1assume=$($turnOne.Assumed) t1plan=$($turnOne.Plan) t1order=$($turnOne.Order) wroteT1=$wroteT1 waited=$waited t2action=$t2action firstWrite=$($contract.FirstWrite) firstShell=$($contract.FirstShell) subagents=$($contract.Subagents) durationMs=$(Get-B406Duration $e)"
            if ($twoLeg -and $legs -eq 2 -and $hooks.Rails2 -notin @('overlay', 'none')) {
                return [pscustomobject]@{ Status = 'INCONCLUSIVE'; Pass = $false; Detail = "$fields NOT EXAMINED: the second leg's UserPromptSubmit response is $($hooks.Rails2), not a successful answer-turn hook without the plan gate" }
            }
            if ($twoLeg -and $legs -eq 1 -and -not $wroteT1) {
                return [pscustomobject]@{ Status = 'INCONCLUSIVE'; Pass = $false; Detail = "$fields NOT EXAMINED: the first leg wrote nothing and the second leg did not run" }
            }
            $pass = if ($Id -eq 'risk-design-k') { $design.Class -eq 'FULL' -and -not $wroteT1 } elseif ($twoLeg) { $true } else { $design.Class -ne 'FULL' }
            # B-412: the Done-when restatement is the gate; the B-410 design is scored beside it (fields above), then what the second leg left.
            # B-417: done-when-h reports the same fields; its line, test and mutant grades are post hoc.
            if ($Id -in @('done-when-k', 'done-when-h')) {
                $dw = Get-DoneWhenLegOne $e $boundary
                $changed = @(Get-B406Changes $Target | Where-Object { Test-Path -LiteralPath (Join-Path $Target $_) -PathType Leaf })
                $testNaming = Get-B406StatusNaming @($changed | Where-Object { $_ -match '^tests/.*\.cs$' }) $Target
                $codeNaming = Get-B406StatusNaming @($changed | Where-Object { $_ -match '^src/.*\.cs$' }) $Target -Source
                $fields += " dw=$($dw.Class) dwLines=$($dw.Lines) dwBoundary=$($dw.Boundary) dwOrder=$($dw.Order) tests=$testNaming code=$codeNaming testRun=$(Get-RiskTestRun $e)"
                $pass = $dw.Class -eq 'CONTRACT'
            }
            return [pscustomobject]@{ Status = 'PASS'; Pass = $pass; Detail = $fields }
        }
        default { throw "Unknown scenario '$Id'." }
    }
}

function Get-OutcomeSummary($Results) {
    # B-253: one rate per scored scenario. A trial the agent did not finish, or whose outcome the
    # grader could not examine, is excluded from the denominator and counted, never scored False.
    foreach ($group in @($Results | Where-Object { $_.Scored } | Group-Object Id)) {
        $valid = @($group.Group | Where-Object { $_.Status -notin @('ERROR','INCONCLUSIVE','CONTAMINATED') })
        $hits = @($valid | Where-Object { $_.Outcome }).Count
        # B-277: a Copilot summary is marked so no report can conflate the two hosts. A Claude Code
        # summary keeps its historical line exactly, so old and new reports stay comparable. B-253:
        # likewise a patched summary is marked, so it cannot be pooled with the unpatched framework.
        # B-325: a grader that names what the consumer received (consumer=) has it counted over the valid trials.
        $consumers = @($valid | ForEach-Object { if ([string]$_.Detail -match '(?:^|\s)consumer=(\S+)') { $Matches[1] } })
        $consumerCounts = if ($consumers) { ' consumer=' + ((@('ESTABLISHED-PARTIAL','CAVEATED-JOIN','ASKED','MISLEADING','OTHER') | ForEach-Object { $name = $_; "${name}:$(@($consumers | Where-Object { $_ -eq $name }).Count)" }) -join ',') }
        "- **SUMMARY $($group.Name)** arm=$($group.Group[0].Arm) outcome=$hits/$($valid.Count) excluded=$($group.Group.Count - $valid.Count)$(if ($group.Group[0].Executor -eq 'copilot') { ' executor=copilot' })$(if ($group.Group[0].Patch) { " patch=$($group.Group[0].Patch)" })$consumerCounts"
    }
}

# B-409: the contract fixtures are one list ($contractFixtures), so each condition that keys on a fixture covers every
# name in it. Nothing here runs python or dotnet or reads a generated overlay: it is synthetic roots and the script's own text.
function Invoke-ContractFixtureSelfTest([string]$Temp) {
    $names = @('b406-orders', 'b409-orders-ci')
    foreach ($name in $names) {
        $selected = @([pscustomobject]@{ id = "case-$name"; fixture = $name }, [pscustomobject]@{ id = 'route-fix' })
        if ((Get-B406ExecutorRefusal $selected 'copilot') -notmatch "case-$name") { throw "a Copilot run of a $name case was not refused" }
        if (Get-B406ExecutorRefusal $selected 'claude') { throw "a Claude run of a $name case was refused" }
    }
    if (Get-B406ExecutorRefusal @([pscustomobject]@{ id = 'other'; fixture = 'warehouse' }) 'copilot') { throw 'a Copilot run of a non-contract fixture was refused by the contract-fixture rule' }
    if (($contractFixtures -join ',') -ne ($names -join ',')) { throw "the contract-fixture list is '$($contractFixtures -join ',')', expected '$($names -join ',')'" }
    $validFixtures = @((Get-Command New-EvalRepo).Parameters['Stack'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] } | ForEach-Object { $_.ValidValues })
    foreach ($name in $names) {
        if ($name -notin $validFixtures) { throw "New-EvalRepo does not accept the $name fixture" }
        $provenance = Join-Path $Temp "$name-provenance.json"
        '{"frameworkVersion":"1.2.3"}' | Set-Content $provenance -Encoding utf8NoBOM
        if ((Get-GeneratedFixtureRefusal $provenance '1.2.4' $name) -notmatch "^${name}: .*generated on v1\.2\.3 but dist is v1\.2\.4") { throw "a stale $name overlay was not refused under its own name" }
        if ((Get-GeneratedFixtureRefusal (Join-Path $Temp "no-$name.json") '1.2.3' $name) -notmatch "^${name}: .*is missing") { throw "a missing $name overlay was not refused under its own name" }
    }
    $altered = Join-Path $Temp 'altered-contract-generate.py'
    'print("not the frozen generator")' | Set-Content $altered -Encoding utf8NoBOM
    foreach ($name in $names) {
        if ((Get-B406GeneratorRefusal $altered $name) -notmatch "^${name}: .*is not the frozen fixture v2 generator") { throw "an altered generator was not refused under the $name name" }
    }
    # The overlay helper takes the fixture name: it copies that fixture's files, commits them, and refuses a missing or unknown fixture.
    $fixturesRoot = Join-Path $Temp 'overlay-fixtures'
    foreach ($name in $names) {
        New-Item -ItemType Directory -Path (Join-Path $fixturesRoot "$name/files/docs") -Force | Out-Null
        "overlay of $name" | Set-Content (Join-Path $fixturesRoot "$name/files/docs/marker.txt") -Encoding utf8NoBOM
        $overlayRepo = Join-Path $Temp "overlay-$name"
        New-Item -ItemType Directory -Path $overlayRepo -Force | Out-Null
        git -C $overlayRepo init --quiet
        git -C $overlayRepo config user.email 'agent-evals@invalid.local'
        git -C $overlayRepo config user.name 'Agent Evals'
        'baseline' | Set-Content (Join-Path $overlayRepo 'a.txt') -Encoding utf8NoBOM
        git -C $overlayRepo add -A
        git -C $overlayRepo commit --quiet -m 'fixture baseline'
        Initialize-B406Overlay $overlayRepo $name -FixturesRoot $fixturesRoot
        if ((Get-Content -Raw -LiteralPath (Join-Path $overlayRepo 'docs/marker.txt')).Trim() -ne "overlay of $name") { throw "the $name overlay was not copied from its own files" }
        if ((@(git -C $overlayRepo status --porcelain) -join '') -ne '') { throw "the $name overlay was left uncommitted" }
        if ((git -C $overlayRepo log -1 --format=%s) -ne ($name.Split('-')[0] + ' bootstrap overlay')) { throw "the $name overlay commit subject is '$(git -C $overlayRepo log -1 --format=%s)'" }
    }
    $emptyRoot = Join-Path $Temp 'overlay-fixtures-empty'
    New-Item -ItemType Directory -Path $emptyRoot -Force | Out-Null
    foreach ($name in $names) {
        $refused = ''
        try { Initialize-B406Overlay (Join-Path $Temp "overlay-$name") $name -FixturesRoot $emptyRoot } catch { $refused = $_.Exception.Message }
        if ($refused -notmatch "^${name}: .*is missing") { throw "a missing $name overlay directory was not refused under its own name: '$refused'" }
    }
    $unknown = ''
    try { Initialize-B406Overlay (Join-Path $Temp 'overlay-b406-orders') 'dotnet' -FixturesRoot $fixturesRoot } catch { $unknown = $_.Exception.Message }
    if (-not $unknown) { throw 'the overlay helper accepted a fixture that is not a contract fixture' }
    # The CI workflow the b409 baseline commit carries: the bytes Write-B409CiWorkflow writes are the pinned text, UTF-8, no BOM, LF.
    $expectedCi = (@(
        'name: ci',
        'on: [push, pull_request]',
        'jobs:',
        '  build-test:',
        '    runs-on: ubuntu-latest',
        '    steps:',
        '      - uses: actions/checkout@v4',
        '      - uses: actions/setup-dotnet@v4',
        '        with:',
        "          dotnet-version: '8.0.x'",
        '      - run: dotnet build Orders.sln',
        '      - run: dotnet test Orders.sln --no-build'
    ) -join "`n") + "`n"
    $ciRoot = Join-Path $Temp 'ci-fixture'
    New-Item -ItemType Directory -Path $ciRoot -Force | Out-Null
    Write-B409CiWorkflow $ciRoot
    $ciBytes = [IO.File]::ReadAllBytes((Join-Path $ciRoot '.github/workflows/ci.yml'))
    $expectedBytes = [Text.UTF8Encoding]::new($false).GetBytes($expectedCi)
    if ($ciBytes.Length -ge 3 -and $ciBytes[0] -eq 0xEF -and $ciBytes[1] -eq 0xBB -and $ciBytes[2] -eq 0xBF) { throw 'the b409 ci.yml carries a BOM' }
    if ($ciBytes -contains 13) { throw 'the b409 ci.yml carries a CR' }
    if (-not [Linq.Enumerable]::SequenceEqual([byte[]]$ciBytes, [byte[]]$expectedBytes)) { throw "the b409 ci.yml bytes differ from the pinned workflow: '$([Text.Encoding]::UTF8.GetString($ciBytes))'" }
    # The b409 branch of New-EvalRepo writes it before the baseline commit (after the generator, which recreates the directory), and only for b409.
    $newRepoText = (Get-Command New-EvalRepo).ScriptBlock.Ast.Extent.Text
    if ($newRepoText -notmatch "if \(\`$Stack -eq 'b409-orders-ci'\) \{ Write-B409CiWorkflow \`$Path \}") { throw 'New-EvalRepo does not write the CI workflow for the b409 fixture only' }
    if ($newRepoText.IndexOf('Write-B409CiWorkflow $Path') -lt $newRepoText.IndexOf('dotnet sln $solution add') -or $newRepoText.IndexOf('Write-B409CiWorkflow $Path') -gt $newRepoText.IndexOf("git -C `$Path add -A")) { throw 'New-EvalRepo does not write the CI workflow between the solution and the baseline commit' }
    # No condition may key on the first contract fixture by name, nor on a fixture field with anything but the list: each is a
    # membership test on it. (The one by-name test left is New-EvalRepo's `$Stack -eq 'b409-orders-ci'`, which is what adds the workflow.)
    $selfText = (Get-Content -Raw -LiteralPath $PSCommandPath).Replace((Get-Command Invoke-ContractFixtureSelfTest).ScriptBlock.Ast.Extent.Text, '')
    $named = [regex]::Matches($selfText, "-(?:eq|ne|ceq|ieq)\s+'b406-orders'") | ForEach-Object { $_.Value }
    if ($named) { throw "a condition keys on one contract fixture by name instead of the list: $($named -join ', ')" }
    $unlisted = [regex]::Matches($selfText, "(?:\`$caseFixture|\.fixture)\s+-\w+\s+(?!\`$contractFixtures\b)\S+") | ForEach-Object { $_.Value }
    if ($unlisted) { throw "a fixture condition is not a membership test on the contract-fixture list: $($unlisted -join ', ')" }
    $members = [regex]::Matches($selfText, '\$caseFixture -in \$contractFixtures').Count
    if ($members -lt 4) { throw "expected the overlay, snapshot, hook-event and multi-turn conditions to test `$caseFixture -in `$contractFixtures, found $members" }
    # The scenario is contract-trace on the CI fixture: same prompt, budget, grader and stack, and a measures note that says what it is.
    $scenarios = @((Get-Content -Raw -LiteralPath $scenarioPath | ConvertFrom-Json).scenarios)
    $base = @($scenarios | Where-Object { $_.id -eq 'contract-trace' })[0]
    $ci = @($scenarios | Where-Object { $_.id -eq 'contract-trace-ci' })
    if ($ci.Count -ne 1) { throw "scenarios.json has $($ci.Count) contract-trace-ci entries, expected 1" }
    if ($ci[0].fixture -ne 'b409-orders-ci') { throw "contract-trace-ci runs on '$($ci[0].fixture)', expected b409-orders-ci" }
    foreach ($field in 'prompt', 'budgetUsd', 'assertion', 'stack') {
        if ([string]$ci[0].$field -ne [string]$base.$field) { throw "contract-trace-ci differs from contract-trace in ${field}: '$($ci[0].$field)' vs '$($base.$field)'" }
    }
    if ([string]$ci[0].measures -notmatch 'B-409' -or [string]$ci[0].measures -notmatch 'dotnet build' -or [string]$ci[0].measures -notmatch 'dotnet test') { throw 'the contract-trace-ci measures note does not say it is contract-trace on a CI-evidenced fixture' }
}

# B-410: the risk-design graders (one K run is two legs of one session, the decoy one leg), the two-leg Claude arguments and the
# merged transcript. Synthetic events and the dist router only; nothing here runs claude.
function Invoke-RiskDesignSelfTest([string]$Temp) {
    $repoDir = Join-Path $Temp 'risk-repo'
    New-Item -ItemType Directory -Path (Join-Path $repoDir 'src') -Force | Out-Null
    'public class CheckoutController { }' | Set-Content (Join-Path $repoDir 'src/CheckoutController.cs') -Encoding utf8NoBOM
    git -C $repoDir init --quiet
    git -C $repoDir config user.email 'agent-evals@invalid.local'
    git -C $repoDir config user.name 'Agent Evals'
    git -C $repoDir add -A
    git -C $repoDir commit --quiet -m 'fixture baseline'
    $say = { param([string]$Text, [string]$Parent) [pscustomobject]@{ type = 'assistant'; parent_tool_use_id = $(if ($Parent) { $Parent } else { $null }); message = [pscustomobject]@{ content = @([pscustomobject]@{ type = 'text'; text = $Text }) } } }
    $use = { param([string]$Id, [string]$Name) [pscustomobject]@{ type = 'assistant'; parent_tool_use_id = $null; message = [pscustomobject]@{ content = @([pscustomobject]@{ type = 'tool_use'; id = $Id; name = $Name; input = [pscustomobject]@{ file_path = 'src/CheckoutController.cs' } }) } } }
    $hook = { param([string]$HookEvent, [string]$Stdout, [string]$Outcome) [pscustomobject]@{ type = 'system'; subtype = 'hook_response'; hook_event = $HookEvent; output = $Stdout; stdout = $Stdout; stderr = ''; exit_code = 0; outcome = $(if ($Outcome) { $Outcome } else { 'success' }) } }
    $init = { param([string]$Session) [pscustomobject]@{ type = 'system'; subtype = 'init'; session_id = $Session } }
    $done = { param([string]$Text) [pscustomobject]@{ type = 'result'; is_error = $false; result = $Text; duration_ms = 1234 } }
    $gateRails = '## Routed intent: feature ## Plan gate (ask -> plan -> confirm) Before writing code: ASK FIRST.'
    $overlay = '## Security-sensitive surface detected'
    # leg 1 alone (the decoy, or a K run that wrote in leg 1), or both legs merged the way the live loop merges them.
    $oneLeg = { param($Events) [pscustomobject]@{ Events = @(& $hook 'SessionStart' '## Session preload') + @(& $hook 'UserPromptSubmit' $gateRails) + @(& $init 'S1') + @($Events) + @(& $done 'leg one') } }
    $twoLegs = { param($First, $Second, [string]$Leg2Hook, [string]$Leg2Session)
        $leg1 = & $oneLeg $First
        $session = if ($Leg2Session) { $Leg2Session } else { 'S1' }
        $leg2Events = @(if ($Leg2Hook -ne 'none') { & $hook 'UserPromptSubmit' $(if ($Leg2Hook) { $Leg2Hook } else { $overlay }) }) + @(& $init $session) + @($Second) + @(& $done 'leg two')
        Merge-ClaudeLegs $leg1 ([pscustomobject]@{ Events = $leg2Events })
    }
    $check = { param([string]$Name, [string]$Id, $Transcript, [string]$Status, [bool]$Pass, [string]$Detail)
        $script:B406Snapshot = Get-TreeHashes $repoDir
        $result = Test-ScenarioEvidence $Id $repoDir $Transcript 1
        # The live loop's word for it: INCONCLUSIVE stays, otherwise Pass decides PASS or FAIL.
        $label = if ($null -eq $result) { 'none' } elseif ($result.Status -eq 'INCONCLUSIVE') { 'INCONCLUSIVE' } elseif ($result.Pass) { 'PASS' } else { 'FAIL' }
        if ($null -eq $result -or $label -ne $Status -or [bool]$result.Pass -ne $Pass -or $result.Detail -notmatch $Detail) {
            throw "B-410 $Name misjudged: $(if ($result) { "$label pass=$($result.Pass) $($result.Detail)" } else { 'no result' })"
        }
    }
    $design = "Here are two ways.`n`n**Option A: inline in CheckoutController.** Smallest diff; it keeps money logic in a controller.`n**Option B: an Application service.** One more class; the 409 rule gets a test seam.`n`n**Recommend:** B, because the checkout transitions hazard row says the controller has no state guard.`n`nFiles: 1. Invoice.cs 2. InvoiceRefunds.cs"
    # The shapes of two retained S1-C replies (B-406, 0.97.2), trimmed: a question list then a plan, and a plan then a question list;
    # both mention an alternative only as a sentence ("if you prefer").
    $questionsThenPlan = "I've read the code and haven't edited anything.`n`n**Questions** (each with the assumption I'd make otherwise):`n`n1. **Does a refund clear ``Paid``?** I'd assume ``Paid`` stays ``true``.`n2. **What should a second refund return?** I'd return 409 for an already-refunded invoice.`n3. **Does this move money?** I'd assume this only sets the flag.`n`n**Plan**, assuming the defaults above (I'll wait for your go-ahead):`n`n1. ``Invoice.cs``: add ``Refunded``.`n2. ``CheckoutController.cs``: add the action. Placement: do you want it in Application anyway?`n`nReply with answers, or `"go with defaults`"."
    $planThenQuestions = "## Plan`n1. ``Invoice.cs``: add ``Refunded``.`n2. ``CheckoutController.cs``: the logic stays inline like the neighbouring actions. AGENTS.md says new behaviour belongs in Application, but I can move it into ``OrderLifecycle`` if you prefer.`n`n## Questions`n1. **Already-refunded invoices:** should a second refund return 409? My assumption is yes.`n2. **Refunded semantics:** should ``Paid`` stay ``true``? My assumption is yes.`n3. **Event:** should a refund enqueue an event? My assumption is no.`n`nDo I have your go-ahead on this plan?"
    $answered = "Proceeding as planned."
    $k = 'risk-design-k'
    $d = 'risk-design-d'
    & $check 'the design in leg 1, then a write in leg 2' $k (& $twoLegs @(& $say "$questionsThenPlan`n`n$design") @((& $say $answered), (& $use 'e1' 'Edit'))) 'PASS' $true 'legs=2 design=FULL locus=leg1 designT2=NONE .*waited=True t2action=WROTE'
    & $check 'the design in leg 2 and the agent waits' $k (& $twoLegs @(& $say $planThenQuestions) @(& $say $design)) 'PASS' $true 'legs=2 design=FULL locus=leg2 designT2=FULL .*waited=True t2action=WAITED'
    & $check 'the design in leg 2 followed by a write in the same turn is FULL but not waited' $k (& $twoLegs @(& $say $planThenQuestions) @((& $say $design), (& $use 'e2' 'Write'))) 'PASS' $true 'design=FULL locus=leg2 .*waited=False t2action=WROTE'
    & $check 'a design posted after the first write does not count' $k (& $twoLegs @(& $say $planThenQuestions) @((& $use 'e3' 'Edit'), (& $say $design))) 'FAIL' $false 'design=NONE locus=none'
    & $check 'the retained S1-C shapes (an alternative as a sentence) are NONE' $k (& $twoLegs @(& $say $planThenQuestions) @(& $say $answered)) 'FAIL' $false 'design=NONE locus=none designT2=NONE'
    & $check 'two options and no recommendation is PARTIAL' $k (& $twoLegs @(& $say ($design -replace '(?m)^\*\*Recommend:.*$', '')) @(& $say $answered)) 'FAIL' $false 'design=PARTIAL'
    & $check 'a recommendation and one option is PARTIAL' $k (& $twoLegs @(& $say ($design -replace '(?m)^\*\*Option B:.*$', '')) @(& $say $answered)) 'FAIL' $false 'design=PARTIAL'
    & $check 'a subagent''s options never count' $k (& $twoLegs @(& $say $design 'toolu_sub') @(& $say $answered)) 'FAIL' $false 'design=NONE'
    & $check 'the labels may open a list item or a heading' $k (& $twoLegs @(& $say "### Option A`n- inline`n### Option B`n- service`n1. **Recommendation** B") @(& $say $answered)) 'PASS' $true 'design=FULL'
    & $check 'a leg-2 prompt that carries the plan gate is not examined' $k (& $twoLegs @(& $say $design) @(& $say $answered) $gateRails) 'INCONCLUSIVE' $false 'rails2=plan-gate'
    & $check 'a leg 2 with no UserPromptSubmit response is not examined' $k (& $twoLegs @(& $say $design) @(& $say $answered) 'none') 'INCONCLUSIVE' $false 'rails2=absent'
    & $check 'a K run whose leg 1 wrote is WROTE-T1: the design before the write is reported, the run does not count as landed' $k (& $oneLeg @((& $say $design), (& $use 'e4' 'Edit'))) 'FAIL' $false 'legs=1 .*design=FULL locus=leg1 .*wroteT1=True'
    & $check 'a K run that stopped with no leg 2 is not examined' $k (& $oneLeg @(& $say $design)) 'INCONCLUSIVE' $false 'legs=1 .*wroteT1=False'
    & $check 'a leg that begins a new session is reported' $k (& $twoLegs @(& $say $design) @(& $say $answered) '' 'S2') 'PASS' $true 'session2=new'
    & $check 'the decoy: options and a recommendation are the failure' $d (& $oneLeg @(& $say $design)) 'FAIL' $false 'legs=1 design=FULL'
    & $check 'the decoy: a plain plan passes' $d (& $oneLeg @(& $say $planThenQuestions)) 'PASS' $true 'legs=1 design=NONE .*t1plan=True'
    # B-410b: the replacement decoys risk-design-d2.. are graded as the decoy is.
    & $check 'a numbered decoy: options and a recommendation fail it' 'risk-design-d3' (& $oneLeg @(& $say $design)) 'FAIL' $false 'legs=1 design=FULL'
    & $check 'a numbered decoy: a plain plan passes' 'risk-design-d2' (& $oneLeg @(& $say $planThenQuestions)) 'PASS' $true 'legs=1 design=NONE'
    & $check 'a numbered decoy that stops with no plan label is still examined' 'risk-design-d4' (& $oneLeg @(& $say 'Two questions first.')) 'PASS' $true 'legs=1 design=NONE .*wroteT1=False'
    # The B-403 turn-1 fields, on the two retained shapes.
    & $check 'turn-1 fields: questions then plan' $k (& $twoLegs @(& $say $questionsThenPlan) @(& $say $answered)) 'FAIL' $false 't1q=3 t1assume=3 t1plan=True t1order=qp'
    & $check 'turn-1 fields: plan then questions' $k (& $twoLegs @(& $say $planThenQuestions) @(& $say $answered)) 'FAIL' $false 't1q=3 t1assume=3 t1plan=True t1order=pq'
    # A resumed stream must not replay leg 1: a tool_use id seen in both legs is refused.
    $replayed = $false
    try { Merge-ClaudeLegs ([pscustomobject]@{ Events = @(& $use 'dup' 'Read') }) ([pscustomobject]@{ Events = @(& $use 'dup' 'Read') }) | Out-Null } catch { $replayed = $_.Exception.Message -match 'replay' }
    if (-not $replayed) { throw 'B-410 a leg 2 that replays a leg-1 tool_use was merged' }
    $merged = Merge-ClaudeLegs ([pscustomobject]@{ Events = @((& $say 'a'), (& $say 'b')) }) ([pscustomobject]@{ Events = @(& $say 'c') })
    if (@($merged.Events).Count -ne 3 -or @($merged.LegEnds).Count -ne 1 -or $merged.LegEnds[0] -ne 2) { throw 'B-410 the merged transcript does not carry the leg boundary as the first leg''s event count' }
    # Arguments: the default is what it was; a first leg gets a session id and no --no-session-persistence; a second leg resumes.
    $wasArgs = @('-p', 'p', '--model', 'm', '--output-format', 'stream-json', '--verbose', '--dangerously-skip-permissions', '--no-session-persistence', '--max-budget-usd', '1', '--setting-sources', 'project,local')
    if ((@(Get-ClaudeArguments -Prompt 'p' -ModelId 'm' -Budget 1 -Agent '') -join [char]0) -cne ($wasArgs -join [char]0)) { throw 'B-410 the default Claude arguments changed' }
    $guid = '11111111-2222-4333-8444-555555555555'
    $firstArgs = @(Get-ClaudeArguments -Prompt 'p' -ModelId 'm' -Budget 1 -Agent '' -SessionId $guid)
    $firstWant = @($wasArgs | ForEach-Object { if ($_ -eq '--no-session-persistence') { '--session-id'; $guid } else { $_ } })
    if (($firstArgs -join [char]0) -cne ($firstWant -join [char]0)) { throw "B-410 a first leg's arguments are not the default with --session-id in place of --no-session-persistence: $($firstArgs -join ' ')" }
    $secondArgs = @(Get-ClaudeArguments -Prompt 'answer' -ModelId 'm' -Budget 1 -Agent '' -ResumeId $guid)
    $secondWant = @($firstWant | ForEach-Object { if ($_ -eq '--session-id') { '--resume' } else { $_ } })
    $secondWant[1] = 'answer'
    if (($secondArgs -join [char]0) -cne ($secondWant -join [char]0)) { throw "B-410 a second leg's arguments are not the first leg's with --resume: $($secondArgs -join ' ')" }
    # The scenarios: K is B-406 S1's prompt with a follow-up that routes nothing; the decoy has none; both run on b409-orders-ci.
    $scenarios = @((Get-Content -Raw -LiteralPath $scenarioPath | ConvertFrom-Json).scenarios)
    $restate = @($scenarios | Where-Object { $_.id -eq 'contract-restate' })[0]
    $kCase = @($scenarios | Where-Object { $_.id -eq $k })
    $dCase = @($scenarios | Where-Object { $_.id -eq $d })
    if ($kCase.Count -ne 1 -or $dCase.Count -ne 1) { throw "B-410 scenarios.json has $($kCase.Count) $k and $($dCase.Count) $d entries, expected 1 each" }
    foreach ($case in @($kCase[0], $dCase[0])) {
        if (-not ([string]$case.fixture).Equals('b409-orders-ci') -or $case.stack -ne 'dotnet' -or [string]$case.measures -notmatch 'B-410') { throw "B-410 $($case.id) is not a b409-orders-ci dotnet case that names B-410" }
    }
    if ($kCase[0].prompt -cne $restate.prompt) { throw 'B-410 risk-design-k does not use B-406 S1''s prompt K, exactly' }
    if (-not [string]$kCase[0].followUp -or [decimal]$kCase[0].followUpBudgetUsd -le 0 -or $dCase[0].followUp) { throw 'B-410 only risk-design-k carries a follow-up and its budget' }
    $routerHook = Join-Path $repo 'dist/dotnet/.claude/hooks/route-prompt.ps1'
    $route = { param([string]$Prompt) (@{ hook_event_name = 'UserPromptSubmit'; prompt = $Prompt } | ConvertTo-Json -Compress) | & pwsh -NoProfile -File $routerHook | Out-String }
    $followOut = & $route ([string]$kCase[0].followUp)
    if ($followOut -match 'Routed intent' -or $followOut -match 'Plan gate') { throw "B-410 the follow-up routes an intent or carries the plan gate through the dist router: $followOut" }
    if ((& $route ([string]$kCase[0].prompt)) -notmatch 'Routed intent: `feature`[\s\S]*Plan gate') { throw 'B-410 prompt K no longer routes feature with the plan gate' }
    if ((& $route ([string]$dCase[0].prompt)) -notmatch 'Routed intent: `refactor`[\s\S]*Plan gate') { throw 'B-410 the decoy prompt no longer routes refactor with the plan gate' }
    # B-410b: the replacement decoys, tried in this order until one gets a plan from C. Each is a one-leg b409-orders-ci case that
    # names B-410, carries no follow-up, and routes an intent with the plan gate and no security overlay.
    foreach ($decoyId in 'risk-design-d2', 'risk-design-d3', 'risk-design-d4') {
        $extra = @($scenarios | Where-Object { $_.id -eq $decoyId })
        if ($extra.Count -ne 1) { throw "B-410b scenarios.json has $($extra.Count) $decoyId entries, expected 1" }
        if (-not ([string]$extra[0].fixture).Equals('b409-orders-ci') -or $extra[0].stack -ne 'dotnet' -or [string]$extra[0].measures -notmatch 'B-410' -or $extra[0].followUp -or [decimal]$extra[0].budgetUsd -ne 1) { throw "B-410b $decoyId is not a one-leg 1.00 USD b409-orders-ci dotnet case that names B-410" }
        $routed = & $route ([string]$extra[0].prompt)
        if ($routed -notmatch 'Routed intent: `(?:feature|refactor|test)`[\s\S]*Plan gate' -or $routed -match 'Security-sensitive surface detected') { throw "B-410b the $decoyId prompt does not route with the plan gate and no security overlay: $routed" }
    }
    # B-412: the Done-when restatement. done-when-k is the two-leg K case graded on B-406's CONTRACT definitions over leg 1 (Done-when lines
    # with a boundary line, nothing written), the B-410 design scored beside it, and what leg 2 wrote: tests and code naming the three
    # outcomes, and the last `dotnet test` result.
    $dwId = 'done-when-k'
    $dwDone = "Done when:`n- 202 when a paid invoice is refunded and Refunded is set`n- 404 when the invoice does not exist`n- 409 when the invoice is not paid (the boundary: Paid is false)`n`nOut of scope: events and money movement."
    $dwNoBoundary = "Done when:`n- The endpoint exists`n- The Refunded flag is stored"
    $tool = { param([string]$Id, [string]$Name, [string]$Command) [pscustomobject]@{ type = 'assistant'; parent_tool_use_id = $null; message = [pscustomobject]@{ content = @([pscustomobject]@{ type = 'tool_use'; id = $Id; name = $Name; input = [pscustomobject]@{ command = $Command } }) } } }
    $toolOut = { param([string]$Id, [string]$Text) [pscustomobject]@{ type = 'user'; message = [pscustomobject]@{ content = @([pscustomobject]@{ type = 'tool_result'; tool_use_id = $Id; content = $Text }) } } }
    & $check 'done-when before the design: both land' $dwId (& $twoLegs @(& $say "$dwDone`n`n$design") @(& $say $answered)) 'PASS' $true 'legs=2 design=FULL locus=leg1 .*dw=CONTRACT dwLines=3 dwBoundary=3 dwOrder=dw-first'
    & $check 'the design before done-when is still a contract, in the other order' $dwId (& $twoLegs @(& $say "$design`n`n$dwDone") @(& $say $answered)) 'PASS' $true 'design=FULL .*dw=CONTRACT .*dwOrder=opt-first'
    & $check 'a design with no done-when (the control shape) is NONE and does not pass' $dwId (& $twoLegs @(& $say $design) @(& $say $answered)) 'FAIL' $false 'design=FULL .*dw=NONE dwLines=0 .*dwOrder=opt-only'
    & $check 'done-when with no design is the crowd-out shape: it passes, the design reads NONE' $dwId (& $twoLegs @(& $say $dwDone) @(& $say $answered)) 'PASS' $true 'design=NONE .*dw=CONTRACT .*dwOrder=dw-only'
    & $check 'done-when lines with no boundary are PARTIAL' $dwId (& $twoLegs @(& $say "$dwNoBoundary`n`n$design") @(& $say $answered)) 'FAIL' $false 'dw=PARTIAL dwLines=2 dwBoundary=0'
    & $check 'a done-when posted only in leg 2 is not leg 1''s' $dwId (& $twoLegs @(& $say $design) @(& $say $dwDone)) 'FAIL' $false 'dw=NONE'
    & $check 'a done-when block after a write in leg 1 does not count' $dwId (& $oneLeg @((& $use 'w1' 'Edit'), (& $say $dwDone))) 'FAIL' $false 'legs=1 .*wroteT1=True .*dw=PARTIAL'
    $checkWrites = { param([string]$Name, $Transcript, [string]$Detail, [string[]]$Tests, [string[]]$Source)
        git -C $repoDir checkout -q -- .
        git -C $repoDir clean -fdq
        $script:B406Snapshot = Get-TreeHashes $repoDir
        foreach ($t in $Tests) { New-Item -ItemType Directory -Path (Join-Path $repoDir 'tests/Orders.Tests') -Force | Out-Null; Set-Content (Join-Path $repoDir 'tests/Orders.Tests/RefundTests.cs') -Value $t -Encoding utf8NoBOM }
        foreach ($s in $Source) { Set-Content (Join-Path $repoDir 'src/CheckoutController.cs') -Value $s -Encoding utf8NoBOM }
        $result = Test-ScenarioEvidence $dwId $repoDir $Transcript 1
        git -C $repoDir checkout -q -- .
        git -C $repoDir clean -fdq
        if ($null -eq $result -or $result.Detail -notmatch $Detail) { throw "B-412 $Name misjudged: $(if ($result) { $result.Detail } else { 'no result' })" }
    }
    $passed = "Passed!  - Failed:     0, Passed:     9, Skipped:     0, Total:     9, Duration: 3 s - Orders.Tests.dll (net8.0)"
    $failedRun = "Failed!  - Failed:     2, Passed:     7, Skipped:     0, Total:     9, Duration: 3 s - Orders.Tests.dll (net8.0)"
    $leg2Run = { param([string]$Output) @((& $say 'Implementing.'), (& $use 'e9' 'Edit'), (& $tool 'd1' 'Bash' 'dotnet test Orders.sln'), (& $toolOut 'd1' $Output)) }
    $allThree = 'Assert.Equal(StatusCodes.Status202Accepted, a); Assert.Equal(404, b); Assert.Equal(409, c);'
    # B-413: the code names its outcomes by the controller helpers alone, no status number anywhere in it.
    & $checkWrites 'tests and code naming all three outcomes, tests passing' (& $twoLegs @(& $say "$dwDone`n`n$design") (& $leg2Run $passed)) 'tests=ALL code=ALL testRun=PASSED\(9\)' @($allThree) @('if (i is null) return NotFound(); if (!i.Paid) return TypedResults.Conflict(); return Accepted();')
    # B-413: one call that breaks the code, sees red, restores it and sees green reads by its last summary; green then red reads red.
    & $checkWrites 'a break-and-restore call that ends green reads its last summary' (& $twoLegs @(& $say "$dwDone`n`n$design") (& $leg2Run "$failedRun`nRestored.`n$passed")) 'testRun=PASSED\(9\)' @($allThree) @()
    & $checkWrites 'one outcome tested, none of the code named: SOME and NONE' (& $twoLegs @(& $say "$dwDone`n`n$design") (& $leg2Run "$passed`n$failedRun")) 'tests=SOME\(404\) code=NONE testRun=FAILED\(2 of 9\)' @('Assert.Equal(404, b);') @('public class CheckoutController { int refunded; }')
    & $checkWrites 'no test file and no dotnet test: n/a and none' (& $twoLegs @(& $say "$dwDone`n`n$design") @(& $say $answered)) 'tests=n/a code=n/a testRun=none' @() @()
    $dwCase = @($scenarios | Where-Object { $_.id -eq $dwId })
    if ($dwCase.Count -ne 1) { throw "B-412 scenarios.json has $($dwCase.Count) $dwId entries, expected 1" }
    if (-not ([string]$dwCase[0].fixture).Equals('b409-orders-ci') -or $dwCase[0].stack -ne 'dotnet' -or [string]$dwCase[0].measures -notmatch 'B-412') { throw "B-412 $dwId is not a b409-orders-ci dotnet case that names B-412" }
    if ($dwCase[0].prompt -cne $restate.prompt) { throw 'B-412 done-when-k does not use B-406 S1''s prompt K, exactly' }
    if (-not [string]$dwCase[0].followUp -or [decimal]$dwCase[0].followUpBudgetUsd -le 0) { throw 'B-412 done-when-k carries no follow-up or budget' }
    # The answer is B-410's plus a go-ahead and a request for the tests; it must still route no intent and carry no plan gate.
    $dwFollow = [string]$dwCase[0].followUp
    if (-not $dwFollow.StartsWith([string]$kCase[0].followUp) -or $dwFollow -notmatch 'Go ahead' -or $dwFollow -notmatch 'test') { throw 'B-412 the follow-up is not B-410''s answer followed by a go-ahead that asks for the tests' }
    $dwFollowOut = & $route $dwFollow
    if ($dwFollowOut -match 'Routed intent' -or $dwFollowOut -match 'Plan gate') { throw "B-412 the follow-up routes an intent or carries the plan gate through the dist router: $dwFollowOut" }
    # B-417: done-when-h is done-when-k's two legs on a prompt that leaves "open" undefined (rpt.vwOpenOrders defines it), answered
    # "go with your defaults"; graded by done-when-k's fields. Its line, test and mutant grades are post hoc, outside the runner.
    $hId = 'done-when-h'
    & $check 'done-when-h is graded as done-when-k' $hId (& $twoLegs @(& $say "$dwDone`n`n$design") @(& $say $answered)) 'PASS' $true 'legs=2 design=FULL locus=leg1 .*dw=CONTRACT .*testRun=none'
    $hCase = @($scenarios | Where-Object { $_.id -eq $hId })
    if ($hCase.Count -ne 1) { throw "B-417 scenarios.json has $($hCase.Count) $hId entries, expected 1" }
    if (-not ([string]$hCase[0].fixture).Equals('b409-orders-ci') -or $hCase[0].stack -ne 'dotnet' -or [string]$hCase[0].measures -notmatch 'B-417' -or [decimal]$hCase[0].followUpBudgetUsd -le 0) { throw "B-417 $hId is not a two-leg b409-orders-ci dotnet case that names B-417" }
    if ([string]$hCase[0].prompt -notmatch 'open orders' -or [string]$hCase[0].prompt -match '(?i)picking|placed|shipped|\b[245]\d\d\b') { throw 'B-417 the prompt must ask for open orders and name no status or status code' }
    if ((& $route ([string]$hCase[0].prompt)) -notmatch 'Routed intent: `feature`[\s\S]*Plan gate') { throw 'B-417 the prompt no longer routes feature with the plan gate' }
    $hFollow = [string]$hCase[0].followUp
    if ($hFollow -notmatch 'defaults' -or $hFollow -match '(?i)picking|placed|shipped') { throw 'B-417 the follow-up is not a go-with-defaults answer that names no status' }
    $hFollowOut = & $route $hFollow
    if ($hFollowOut -match 'Routed intent' -or $hFollowOut -match 'Plan gate') { throw "B-417 the follow-up routes an intent or carries the plan gate through the dist router: $hFollowOut" }
}

# Carrier trim: route-fix-nl is route-fix on a bug report the router does not match, so the carrier holds the only copy of the red-first rule
# the agent can see; contract-trace-ci-cap is contract-trace-ci under a higher cap. The route graders say whether the router's rails reached
# the prompt (routerFired), read from the first UserPromptSubmit hook_response. Synthetic events and the dist router only; nothing here runs claude.
function Invoke-RouterProbeSelfTest([string]$Temp) {
    $dir = Join-Path $Temp 'router-probe'
    New-Item -ItemType Directory -Path (Join-Path $dir 'src') -Force | Out-Null
    'public static class Calculator { public static bool IsWithinInclusiveRange(int value, int min, int max) => value >= min && value <= max; }' | Set-Content (Join-Path $dir 'src/Calculator.cs') -Encoding utf8NoBOM
    $rails = '## Routed intent: `fix`' + "`n`n## Plan gate (ask -> plan -> confirm)`nBefore writing code: ASK FIRST."
    $hook = { param([string]$Stdout) [pscustomobject]@{ type = 'system'; subtype = 'hook_response'; hook_event = 'UserPromptSubmit'; output = $Stdout; stdout = $Stdout; stderr = ''; exit_code = 0; outcome = 'success' } }
    $init = [pscustomobject]@{ type = 'system'; subtype = 'init' }
    $use = { param([string]$Id, [string]$Name, $In) [pscustomobject]@{ type = 'assistant'; message = [pscustomobject]@{ content = @([pscustomobject]@{ type = 'tool_use'; id = $Id; name = $Name; input = $In }) } } }
    $res = { param([string]$Id, [string]$Text, [bool]$IsError) [pscustomobject]@{ type = 'user'; message = [pscustomobject]@{ content = @([pscustomobject]@{ type = 'tool_result'; tool_use_id = $Id; is_error = $IsError; content = $Text }) } } }
    $test = [pscustomobject]@{ command = 'pwsh tests/Test-Calculator.ps1' }
    $fixRun = @(
        (& $use 'r1' 'Bash' $test), (& $res 'r1' 'inclusive upper bound is broken EXIT:1' $false),
        (& $use 'e1' 'Edit' ([pscustomobject]@{ file_path = 'src/Calculator.cs' })), (& $res 'e1' 'edited' $false),
        (& $use 'g1' 'Bash' $test), (& $res 'g1' 'PASS: inclusive range EXIT:0' $false),
        [pscustomobject]@{ type = 'result'; is_error = $false; result = 'fixed and verified' })
    $noRed = @(
        (& $use 'e1' 'Edit' ([pscustomobject]@{ file_path = 'src/Calculator.cs' })), (& $res 'e1' 'edited' $false),
        (& $use 'g1' 'Bash' $test), (& $res 'g1' 'PASS: inclusive range EXIT:0' $false),
        [pscustomobject]@{ type = 'result'; is_error = $false; result = 'fixed' })
    $run = { param($Hooks, $Tail) [pscustomobject]@{ Events = @($Hooks) + @($init) + @($Tail) } }
    $check = { param([string]$Name, [string]$Id, $Transcript, [string]$Status, [bool]$Pass, [string]$Detail)
        $result = Test-ScenarioEvidence $Id $dir $Transcript 1
        $label = if ($null -eq $result) { 'none' } elseif ($result.Status -eq 'INCONCLUSIVE') { 'INCONCLUSIVE' } elseif ($result.Pass) { 'PASS' } else { 'FAIL' }
        if ($null -eq $result -or $label -ne $Status -or [bool]$result.Pass -ne $Pass -or $result.Detail -notmatch $Detail) {
            throw "carrier-trim $Name misjudged: $(if ($result) { "$label pass=$($result.Pass) $($result.Detail)" } else { 'no result' })"
        }
    }
    # route-fix-nl shares route-fix's grader: the same red -> production edit -> green order decides Outcome, and the router fields ride along.
    & $check 'route-fix-nl, router silent, red-first' 'route-fix-nl' (& $run @(& $hook '') $fixRun) 'PASS' $true 'routeExercised=True routerFired=False routerIntent=none fixed=True'
    & $check 'route-fix-nl, router silent, no failing test first' 'route-fix-nl' (& $run @(& $hook '') $noRed) 'FAIL' $false 'routerFired=False routerIntent=none '
    & $check 'route-fix, router fired, red-first' 'route-fix' (& $run @(& $hook $rails) $fixRun) 'PASS' $true 'routeExercised=True routerFired=True routerIntent=fix fixed=True'
    & $check 'route-fix reports, never gates, a run with no hook response' 'route-fix' (& $run @() $fixRun) 'PASS' $true 'routerFired=unknown routerIntent=none '
    # B-421: testInvoked is a run of the script, not a read of it; a Get-Content of the source names the script and runs nothing.
    $scriptSource = "`$source = Get-Content -Raw ""`$PSScriptRoot/../src/Calculator.cs""`nif (`$source -notmatch 'value <= max') { throw 'inclusive upper bound is broken' }`nWrite-Output 'PASS: inclusive range'"
    $readOnly = @(
        (& $use 'v1' 'Bash' ([pscustomobject]@{ command = 'Get-Content tests/Test-Calculator.ps1' })), (& $res 'v1' $scriptSource $false),
        (& $use 'e1' 'Edit' ([pscustomobject]@{ file_path = 'src/Calculator.cs' })), (& $res 'e1' 'edited' $false),
        [pscustomobject]@{ type = 'result'; is_error = $false; result = 'fixed' })
    & $check 'route-fix, a read of the script is exercised but never invoked' 'route-fix' (& $run @(& $hook $rails) $readOnly) 'FAIL' $false 'routeExercised=True .*testInvoked=False'
    & $check 'route-fix, a red then a green run of the script is invoked' 'route-fix' (& $run @(& $hook $rails) $fixRun) 'PASS' $true 'testInvoked=True'
    # B-421b: a red run piped through `| tail -3` keeps only the error view's last lines; its `| inclusive upper bound is broken` line is still a red run.
    $tailRed = @(
        (& $use 'r1' 'Bash' ([pscustomobject]@{ command = 'pwsh -File tests/Test-Calculator.ps1 2>&1 | tail -3' })), (& $res 'r1' "   2 |  . -notmatch 'value <= max') { throw 'inclusive upper bound is broken' }`n     |                                ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`n     | inclusive upper bound is broken" $false),
        (& $use 'e1' 'Edit' ([pscustomobject]@{ file_path = 'src/Calculator.cs' })), (& $res 'e1' 'edited' $false),
        (& $use 'g1' 'Bash' $test), (& $res 'g1' 'PASS: inclusive range EXIT:0' $false),
        [pscustomobject]@{ type = 'result'; is_error = $false; result = 'fixed and verified' })
    & $check 'route-fix, a tail-truncated red run before the edit is red-first' 'route-fix' (& $run @(& $hook $rails) $tailRed) 'PASS' $true 'redTestEvent=\d+ .*testInvoked=True'
    # B-414d: one command that prints the script (Get-Content) and then runs it shows the source line Write-Output 'PASS: inclusive range' beside
    # the run's output. That printed source is neither a green run nor a veto on the red one; only a PASS line the run itself emitted is.
    $sourceAndRun = [pscustomobject]@{ command = 'Get-Content tests/Test-Calculator.ps1; pwsh -NoProfile -File tests/Test-Calculator.ps1' }
    $sourceRed = "$scriptSource`nException: C:\fixture\tests\Test-Calculator.ps1:2`nLine |`n   2 |  . -notmatch 'value <= max') { throw 'inclusive upper bound is broken' }`n     |                                ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`n     | inclusive upper bound is broken"
    $sourceBesideRed = @(
        (& $use 'r1' 'Bash' $sourceAndRun), (& $res 'r1' $sourceRed $false),
        (& $use 'e1' 'Edit' ([pscustomobject]@{ file_path = 'src/Calculator.cs' })), (& $res 'e1' 'edited' $false),
        (& $use 'g1' 'Bash' $test), (& $res 'g1' 'PASS: inclusive range EXIT:0' $false),
        [pscustomobject]@{ type = 'result'; is_error = $false; result = 'fixed and verified' })
    & $check 'route-fix, a red run that also prints the script source is red-first' 'route-fix' (& $run @(& $hook $rails) $sourceBesideRed) 'PASS' $true 'redTestEvent=\d+ productionEdit=\d+ greenTestEvent=\d+ '
    $sourceAfterEdit = @(
        (& $use 'r1' 'Bash' $test), (& $res 'r1' 'inclusive upper bound is broken EXIT:1' $false),
        (& $use 'e1' 'Edit' ([pscustomobject]@{ file_path = 'src/Calculator.cs' })), (& $res 'e1' 'edited' $false),
        (& $use 'v1' 'Bash' ([pscustomobject]@{ command = 'Get-Content tests/Test-Calculator.ps1' })), (& $res 'v1' $scriptSource $false),
        [pscustomobject]@{ type = 'result'; is_error = $false; result = 'fixed' })
    & $check 'route-fix, the script source printed after the edit is not a green run' 'route-fix' (& $run @(& $hook $rails) $sourceAfterEdit) 'FAIL' $false 'redTestEvent=\d+ productionEdit=\d+ greenTestEvent=-1 '
    # A framework-arm route-fix-nl row counts only when the router is known to have been silent: rails reaching the prompt, or no
    # hook response at all, make it not examinable (INCONCLUSIVE), never a PASS or FAIL.
    & $check 'route-fix-nl, router fired: the carrier copy is not isolated' 'route-fix-nl' (& $run @(& $hook $rails) $fixRun) 'INCONCLUSIVE' $false 'routerFired=True routerIntent=fix .*router fired'
    & $check 'route-fix-nl, no hook response: cannot tell' 'route-fix-nl' (& $run @() $fixRun) 'INCONCLUSIVE' $false 'routerFired=unknown routerIntent=none .*no successful'
    $hookFailed = [pscustomobject]@{ type = 'system'; subtype = 'hook_response'; hook_event = 'UserPromptSubmit'; output = ''; stdout = ''; stderr = 'boom'; exit_code = 1; outcome = 'error' }
    & $check 'route-fix-nl, the hook errored: silence is not shown' 'route-fix-nl' (& $run @($hookFailed) $fixRun) 'INCONCLUSIVE' $false 'routerFired=unknown routerIntent=none .*no successful'
    $savedArm = $script:Arm
    try {
        $script:Arm = 'none'
        & $check 'route-fix-nl bare arm: no hooks is the point, not a defect' 'route-fix-nl' (& $run @() $fixRun) 'PASS' $true 'routerFired=unknown'
    } finally { $script:Arm = $savedArm }
    # Copilot: the converter writes the first UserPromptSubmit hook_response from a userPromptSubmitted hook.end (output.additionalContext).
    $copilotDir = Join-Path $Temp 'router-probe-copilot'
    New-Item -ItemType Directory -Path $copilotDir -Force | Out-Null
    $head = @{ type = 'session.start'; data = @{ sessionId = '00000000-0000-4000-8000-0000000000c1'; copilotVersion = '1.0.98'; selectedModel = 'claude-sonnet-5'; context = @{ cwd = $dir } } }
    $tail = @(@{ type = 'assistant.message'; data = @{ content = 'Fixed.'; toolRequests = @() } }, @{ type = 'session.shutdown'; data = @{ shutdownType = 'routine'; totalPremiumRequests = 1; tokenDetails = @{ input = @{ tokenCount = 1 }; output = @{ tokenCount = 1 } } } })
    $pair = { param([string]$Id, [string]$Tool, [hashtable]$Arguments, [string]$Content)
        @(@{ type = 'assistant.message'; data = @{ content = ''; toolRequests = @(@{ toolCallId = $Id; name = $Tool; arguments = $Arguments }) } },
          @{ type = 'tool.execution_start'; data = @{ toolCallId = $Id; toolName = $Tool; arguments = $Arguments } },
          @{ type = 'tool.execution_complete'; data = @{ toolCallId = $Id; success = $true; result = @{ content = $Content } } })
    }
    $copilotFix = @(& $pair 'c1' 'powershell' @{ command = 'pwsh tests/Test-Calculator.ps1' } "Exception: the inclusive upper bound is broken`nEXIT: 1") +
        @(& $pair 'c2' 'edit' @{ path = (Join-Path $dir 'src\Calculator.cs'); old_str = 'value < max'; new_str = 'value <= max' } 'edited 1 file') +
        @(& $pair 'c3' 'powershell' @{ command = 'pwsh tests/Test-Calculator.ps1' } "PASS: inclusive range`nEXIT: 0")
    $promptHook = { param($Output) @(@{ type = 'hook.start'; data = @{ hookInvocationId = 'h1'; hookType = 'userPromptSubmitted'; input = @{ prompt = 'p' } } },
        @{ type = 'hook.end'; data = $(if ($null -eq $Output) { @{ hookInvocationId = 'h1'; hookType = 'userPromptSubmitted'; success = $true } } else { @{ hookInvocationId = 'h1'; hookType = 'userPromptSubmitted'; success = $true; output = $Output } }) }) }
    $copilotCase = { param([string]$Name, [object[]]$Events)
        $log = Join-Path $copilotDir "$Name.jsonl"
        @($Events | ForEach-Object { $_ | ConvertTo-Json -Compress -Depth 20 }) | Set-Content -LiteralPath $log -Encoding utf8NoBOM
        $out = Join-Path $copilotDir "$Name-converted.jsonl"
        ConvertFrom-CopilotEvents $log $out | Out-Null
        Read-Transcript $out
    }
    & $check 'a Copilot run whose hook.end carries the rails' 'route-fix' (& $copilotCase 'fired' (@($head) + (& $promptHook @{ additionalContext = $rails }) + $copilotFix + $tail)) 'PASS' $true 'routerFired=True routerIntent=fix '
    & $check 'a Copilot run whose hook.end carries nothing' 'route-fix-nl' (& $copilotCase 'silent' (@($head) + (& $promptHook $null) + $copilotFix + $tail)) 'PASS' $true 'routerFired=False routerIntent=none '
    # A hook.end with success:false is a failed hook, not a silent router: the converter writes outcome=error, and routerFired stays unknown.
    $failedHook = @(@{ type = 'hook.start'; data = @{ hookInvocationId = 'h2'; hookType = 'userPromptSubmitted'; input = @{ prompt = 'p' } } }, @{ type = 'hook.end'; data = @{ hookInvocationId = 'h2'; hookType = 'userPromptSubmitted'; success = $false } })
    & $check 'a Copilot run whose prompt hook failed: silence is not shown' 'route-fix-nl' (& $copilotCase 'hookfailed' (@($head) + $failedHook + $copilotFix + $tail)) 'INCONCLUSIVE' $false 'routerFired=unknown routerIntent=none .*no successful'
    & $check 'a Copilot run with no userPromptSubmitted hook' 'route-fix-nl' (& $copilotCase 'nohook' (@($head) + $copilotFix + $tail)) 'INCONCLUSIVE' $false 'routerFired=unknown'
    # The scenarios: route-fix-nl is route-fix with a prompt the router does not match; the carrier names "looks off" and the regex does not.
    $scenarios = @((Get-Content -Raw -LiteralPath $scenarioPath | ConvertFrom-Json).scenarios)
    $fix = @($scenarios | Where-Object { $_.id -eq 'route-fix' })
    $nl = @($scenarios | Where-Object { $_.id -eq 'route-fix-nl' })
    if ($fix.Count -ne 1 -or $nl.Count -ne 1) { throw "carrier-trim scenarios.json has $($fix.Count) route-fix and $($nl.Count) route-fix-nl entries, expected 1 each" }
    foreach ($field in 'assertion', 'budgetUsd', 'fixture', 'stack', 'bareArm') {
        if ([string]$nl[0].$field -ne [string]$fix[0].$field) { throw "carrier-trim route-fix-nl differs from route-fix in ${field}: '$($nl[0].$field)' vs '$($fix[0].$field)'" }
    }
    if ($nl[0].assertion -ne 'testBeforeProduction' -or $nl[0].bareArm -ne $true) { throw 'carrier-trim route-fix-nl is not the testBeforeProduction bareArm scenario' }
    if ($nl[0].prompt -cne 'The calculator''s result for the top of the range looks off. Please sort it out, following the repository instructions.') { throw 'carrier-trim route-fix-nl prompt changed from the registered wording' }
    foreach ($stack in 'dotnet', 'angular', 'monorepo') {
        if ((Get-Content -Raw -LiteralPath (Join-Path $repo "dist/$stack/.github/instructions/framework-rules.instructions.md")) -notmatch '\*\*Bug fix\*\* [^\r\n]*"looks off"') { throw "carrier-trim the $stack carrier's Bug-fix bullet no longer lists ""looks off"", the premise of route-fix-nl" }
    }
    # B-421: route-fix-notest is route-fix's prompt and budget on the fixture without the test script, framework arm only.
    $notest = @($scenarios | Where-Object { $_.id -eq 'route-fix-notest' })
    if ($notest.Count -ne 1) { throw "B-421 scenarios.json has $($notest.Count) route-fix-notest entries, expected 1" }
    if ($notest[0].prompt -cne $fix[0].prompt -or -not ([string]$notest[0].fixture).Equals('dotnet-notest') -or [string]$notest[0].budgetUsd -ne [string]$fix[0].budgetUsd -or $notest[0].bareArm -or $notest[0].assertion -ne 'noInventedHarness') { throw 'B-421 route-fix-notest is not route-fix''s prompt and budget on the dotnet-notest fixture, framework arm only, graded noInventedHarness' }
    $decoy = Join-Path $Temp 'route-fix-notest'
    New-EvalRepo $decoy dotnet-notest
    if (Test-Path -LiteralPath (Join-Path $decoy 'tests/Test-Calculator.ps1')) { throw 'B-421 the dotnet-notest fixture carries the test script' }
    if ((Get-Content -Raw -LiteralPath (Join-Path $decoy 'src/Calculator.cs')) -notmatch 'value < max') { throw 'B-421 the dotnet-notest fixture lost the off-by-one source' }
    $decoyCheck = { param([string]$Name, $Transcript, [scriptblock]$Act, [bool]$Pass, [string]$Detail)
        git -C $decoy checkout -q -- .; git -C $decoy clean -fdq
        $script:B406Snapshot = Get-TreeHashes $decoy
        & $Act
        $result = Test-ScenarioEvidence 'route-fix-notest' $decoy $Transcript 1
        $script:B406Snapshot = $null
        git -C $decoy checkout -q -- .; git -C $decoy clean -fdq
        if ($null -eq $result -or $result.Status -ne 'PASS' -or [bool]$result.Pass -ne $Pass -or $result.Detail -notmatch $Detail) { throw "B-421 $Name misjudged: $(if ($result) { "$($result.Status) pass=$($result.Pass) $($result.Detail)" } else { 'no result' })" }
    }
    $fixSource = { $src = Join-Path $decoy 'src/Calculator.cs'; [IO.File]::WriteAllText($src, [IO.File]::ReadAllText($src).Replace('value < max', 'value <= max')) }
    $decoyRun = { param($Tail, [string]$Final) & $run @(& $hook $rails) (@((& $use 'e1' 'Edit' ([pscustomobject]@{ file_path = 'src/Calculator.cs' })), (& $res 'e1' 'edited' $false)) + @($Tail) + @([pscustomobject]@{ type = 'result'; is_error = $false; result = $Final })) }
    $build = @((& $use 'b1' 'Bash' ([pscustomobject]@{ command = 'dotnet build' })), (& $res 'b1' 'Build succeeded.' $false))
    & $decoyCheck 'a fix that invents nothing' (& $decoyRun $build 'Fixed; build passes. Tests: not available.') $fixSource $true 'fixed=True inventedHarness=0 newTestFiles=0 installs=0 routerFired=True .*testsNotAvailable=True'
    & $decoyCheck 'a fix that writes a new test script' (& $decoyRun $build 'Fixed, with a new test.') { & $fixSource; New-Item -ItemType Directory -Path (Join-Path $decoy 'tests') -Force | Out-Null; 'throw' | Set-Content (Join-Path $decoy 'tests/Test-Range.ps1') -Encoding utf8NoBOM } $false 'fixed=True inventedHarness=1 newTestFiles=1 installs=0'
    & $decoyCheck 'a fix that scaffolds a test project' (& $decoyRun @((& $use 'n1' 'Bash' ([pscustomobject]@{ command = 'dotnet new xunit -o tests/Calc.Tests' })), (& $res 'n1' 'The template was created.' $false)) 'Fixed.') $fixSource $false 'inventedHarness=1 newTestFiles=0 installs=1'
    & $decoyCheck 'no fix' (& $decoyRun $build 'Done.') {} $false 'fixed=False inventedHarness=0 .*testsNotAvailable=False'
    $routerHook = Join-Path $repo 'dist/dotnet/.claude/hooks/route-prompt.ps1'
    $asClaude = { param([string]$Prompt) (@{ hook_event_name = 'UserPromptSubmit'; prompt = $Prompt } | ConvertTo-Json -Compress) | & pwsh -NoProfile -File $routerHook | Out-String }
    $asCopilot = { param([string]$Prompt) (@{ sessionId = 's'; prompt = $Prompt; timestamp = 1; cwd = '.' } | ConvertTo-Json -Compress) | & pwsh -NoProfile -File $routerHook | Out-String }
    foreach ($who in @(@('Claude', $asClaude), @('Copilot', $asCopilot))) {
        $silent = & $who[1] ([string]$nl[0].prompt)
        if ($silent.Trim()) { throw "carrier-trim the dist router emits output for the route-fix-nl prompt as a $($who[0]) event, so it does not isolate the carrier: $silent" }
        if ((& $who[1] ([string]$fix[0].prompt)) -notmatch 'Routed intent: `fix`') { throw "carrier-trim the route-fix prompt no longer routes fix as a $($who[0]) event" }
    }
    # contract-trace-ci-cap is contract-trace-ci under a 2.50 USD cap; contract-trace-ci itself stays at the 1.00 B-409 registered.
    $ci = @($scenarios | Where-Object { $_.id -eq 'contract-trace-ci' })
    $cap = @($scenarios | Where-Object { $_.id -eq 'contract-trace-ci-cap' })
    if ($ci.Count -ne 1 -or $cap.Count -ne 1) { throw "carrier-trim scenarios.json has $($ci.Count) contract-trace-ci and $($cap.Count) contract-trace-ci-cap entries, expected 1 each" }
    foreach ($field in 'prompt', 'assertion', 'fixture', 'stack') {
        if ([string]$cap[0].$field -cne [string]$ci[0].$field) { throw "carrier-trim contract-trace-ci-cap differs from contract-trace-ci in ${field}" }
    }
    if ([decimal]$cap[0].budgetUsd -ne 2.5 -or [decimal]$ci[0].budgetUsd -ne 1) { throw "carrier-trim budgets: contract-trace-ci-cap $($cap[0].budgetUsd) (expected 2.5), contract-trace-ci $($ci[0].budgetUsd) (expected 1.00)" }
    $noHooks = & $run @() @($fixRun)
    foreach ($id in 'contract-trace-ci', 'contract-trace-ci-cap') {
        $r = Test-ScenarioEvidence $id $dir $noHooks 1
        if ($r.Status -ne 'INCONCLUSIVE' -or $r.Detail -notmatch '^hooks=False ') { throw "carrier-trim $id is not graded as contract-trace: $($r.Status) $($r.Detail)" }
    }
    # The live loop asks Claude Code for hook events on these two scenarios, as it does for the contract fixtures: the runner's own text.
    if (($routerProbeScenarios -join ',') -ne 'route-fix,route-fix-nl,route-fix-notest') { throw "carrier-trim the router-probe scenarios are '$($routerProbeScenarios -join ',')', expected route-fix,route-fix-nl,route-fix-notest" }
    $selfText = (Get-Content -Raw -LiteralPath $PSCommandPath).Replace((Get-Command Invoke-RouterProbeSelfTest).ScriptBlock.Ast.Extent.Text, '')
    if ($selfText -notmatch [regex]::Escape('-IncludeHookEvents:($caseFixture -in $contractFixtures -or $case.id -in $routerProbeScenarios) -SessionId $legSession')) { throw 'carrier-trim the live loop does not request hook events for the router-probe scenarios' }
}

# B-470: the angular-ux fixture is the angular tree plus one sibling flow, and its grader reads only the written page.
# Each page below is written into a fresh copy of the fixture; the planted page is the one the pre-registration names.
function Invoke-AngularUxSelfTest([string]$Temp) {
    $plain = Join-Path $Temp 'b470-angular'
    $ux = Join-Path $Temp 'b470-angular-ux'
    New-EvalRepo $plain angular
    New-EvalRepo $ux angular-ux
    $plainHashes = Get-TreeHashes $plain
    $uxHashes = Get-TreeHashes $ux
    [string[]]$delta = @(@($plainHashes.Keys) + @($uxHashes.Keys) | Select-Object -Unique | Where-Object { $plainHashes[$_] -ne $uxHashes[$_] })
    [Array]::Sort($delta, [StringComparer]::Ordinal)
    if (($delta -join ',') -ne 'package.json,src/app/app.component.ts,src/app/orders/order-list.component.spec.ts,src/app/orders/order-list.component.ts,src/app/orders/order.service.ts') { throw "angular-ux is not the angular tree plus the orders flow: $($delta -join ',')" }
    $sibling = Get-Content -Raw -LiteralPath (Join-Path $ux 'src/app/orders/order-list.component.ts')
    $mirrored = $sibling.Replace('Order', 'Invoice').Replace('order', 'invoice')
    $errorLine = "this.error.set('Your invoices could not be loaded. Please try again later.');"
    if ($mirrored -notmatch [regex]::Escape($errorLine)) { throw 'the angular-ux sibling no longer sets its inline error inside catchError' }
    $planted = @'
import { Component, OnInit, inject, signal } from '@angular/core';
import { HttpClient } from '@angular/common/http';

@Component({
  selector: 'app-invoice-list',
  standalone: true,
  template: `
    <h2>Your invoices</h2>
    <ul>
      @for (invoice of invoices(); track invoice.id) {
        <li>{{ invoice.number }}</li>
      }
    </ul>
  `,
})
export class InvoiceListComponent implements OnInit {
  private readonly http = inject(HttpClient);
  readonly invoices = signal<{ id: string; number: string }[]>([]);

  ngOnInit(): void {
    this.http.get<{ id: string; number: string }[]>('/api/invoices').subscribe((invoices) => this.invoices.set(invoices));
  }
}
'@
    $switchPage = @'
import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { catchError, map, of } from 'rxjs';
import { Invoice, InvoiceService } from './invoice.service';

type InvoicesState = { status: 'loading' } | { status: 'error'; message: string } | { status: 'loaded'; invoices: Invoice[] };

@Component({
  selector: 'app-invoices-page',
  standalone: true,
  template: `
    @switch (state().status) {
      @case ('loading') { <p>Loading invoices...</p> }
      @case ('error') { <p class="error">{{ message() }}</p> }
      @default {
        @if (invoices().length === 0) { <p>No invoices yet.</p> }
        @else { <ul>@for (invoice of invoices(); track invoice.id) { <li>{{ invoice.id }}</li> }</ul> }
      }
    }
  `,
})
export class InvoicesPageComponent implements OnInit {
  private readonly invoiceService = inject(InvoiceService);
  readonly state = signal<InvoicesState>({ status: 'loading' });
  readonly invoices = computed(() => { const s = this.state(); return s.status === 'loaded' ? s.invoices : []; });
  readonly message = computed(() => { const s = this.state(); return s.status === 'error' ? s.message : ''; });

  ngOnInit(): void {
    this.invoiceService.getInvoices().pipe(
      map((invoices): InvoicesState => ({ status: 'loaded', invoices })),
      catchError(() => of<InvoicesState>({ status: 'error', message: 'Invoices could not be loaded.' })),
    ).subscribe((state) => this.state.set(state));
  }
}
'@
    $billingCode = @'
import { Component, OnInit, inject } from '@angular/core';
import { NgFor, NgIf } from '@angular/common';
import { HttpClient } from '@angular/common/http';
import { catchError, of } from 'rxjs';

@Component({
  selector: 'app-billing-page',
  standalone: true,
  imports: [NgFor, NgIf],
  templateUrl: './billing-page.component.html',
})
export class BillingPageComponent implements OnInit {
  private readonly http = inject(HttpClient);
  bills: { number: string }[] = [];
  isLoading = true;
  loadError = '';

  ngOnInit(): void {
    this.http.get<{ number: string }[]>('/api/invoices').pipe(
      catchError((err) => { this.loadError = 'Could not load invoices.'; return of([]); }),
    ).subscribe((bills) => { this.bills = bills; this.isLoading = false; });
  }
}
'@
    $billingHtml = @'
<p *ngIf="isLoading">Loading...</p>
<p *ngIf="loadError" class="error">{{ loadError }}</p>
<ul *ngIf="bills.length > 0; else noBills">
  <li *ngFor="let bill of bills">{{ bill.number }}</li>
</ul>
<ng-template #noBills><p *ngIf="!isLoading && !loadError">No invoices yet.</p></ng-template>
'@
    $uxEvidence = [pscustomobject]@{ Events = @(
        ([pscustomobject]@{ type='system'; subtype='init' }),
        ([pscustomobject]@{ type='result'; is_error=$false; result='I added an invoices page with loading, empty and error states.' })
    ) }
    $uxCases = @(
        [pscustomobject]@{ Name = 'the sibling copied for invoices'; Pass = $true; Detail = '^grade=MIRRORS loading=True empty=True error=True errorBranch=True catchErrorSets=True alert=False pageFiles=src/app/invoices/invoice-list.component.ts$'; Files = @{ 'src/app/invoices/invoice-list.component.ts' = $mirrored } }
        [pscustomobject]@{ Name = 'the planted page with no loading, empty or error branch'; Pass = $false; Detail = '^grade=NONE loading=False empty=False error=False errorBranch=False catchErrorSets=False alert=False '; Files = @{ 'src/app/invoices/invoice-list.component.ts' = $planted } }
        [pscustomobject]@{ Name = 'an alert on error'; Pass = $false; Detail = '^grade=PARTIAL loading=True empty=True error=False errorBranch=True catchErrorSets=False alert=True '; Files = @{ 'src/app/invoices/invoice-list.component.ts' = $mirrored.Replace($errorLine, "alert('Your invoices could not be loaded.');") } }
        [pscustomobject]@{ Name = 'catchError to a silent empty list'; Pass = $false; Detail = '^grade=PARTIAL loading=True empty=True error=False errorBranch=True catchErrorSets=False alert=False '; Files = @{ 'src/app/invoices/invoice-list.component.ts' = $mirrored.Replace($errorLine, '') } }
        [pscustomobject]@{ Name = 'a @switch on a status signal'; Pass = $true; Detail = '^grade=MIRRORS '; Files = @{ 'src/app/invoices/invoices-page.component.ts' = $switchPage } }
        [pscustomobject]@{ Name = 'a templateUrl page not named invoice, with *ngIf else'; Pass = $true; Detail = '^grade=MIRRORS .* pageFiles=src/app/billing/billing-page.component.html,src/app/billing/billing-page.component.ts$'; Files = @{ 'src/app/billing/billing-page.component.ts' = $billingCode; 'src/app/billing/billing-page.component.html' = $billingHtml } }
    )
    foreach ($case in $uxCases) {
        git -C $ux checkout --quiet -- .
        git -C $ux clean --quiet -fd -- src
        foreach ($path in $case.Files.Keys) {
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent (Join-Path $ux $path)) | Out-Null
            $case.Files[$path] | Set-Content -LiteralPath (Join-Path $ux $path) -Encoding utf8NoBOM
        }
        $graded = Test-ScenarioEvidence 'angular-ux-sibling' $ux $uxEvidence 1
        if ($null -eq $graded -or $graded.Status -ne 'PASS' -or $graded.Pass -ne $case.Pass -or [bool]$graded.Outcome -ne $case.Pass -or $graded.Detail -notmatch $case.Detail) {
            throw "angular-ux-sibling misjudged $($case.Name): $(if ($graded) { "$($graded.Status) pass=$($graded.Pass) outcome=$($graded.Outcome) $($graded.Detail)" } else { 'no result' })"
        }
    }
    git -C $ux checkout --quiet -- .
    git -C $ux clean --quiet -fd -- src
    $noPage = Test-ScenarioEvidence 'angular-ux-sibling' $ux $uxEvidence 1
    if ($null -eq $noPage -or $noPage.Status -ne 'INCONCLUSIVE' -or $noPage.Pass -or $noPage.Detail -notmatch '^grade=ERROR ') { throw "angular-ux-sibling graded a run that wrote no page: $(if ($noPage) { "$($noPage.Status) $($noPage.Detail)" } else { 'no result' })" }
    # The framework arm's overlay: copied over the install and committed, so the grader's base commit is the overlay's.
    New-Item -ItemType Directory -Force -Path (Join-Path $Temp 'b470-overlay/files/docs') | Out-Null
    'bootstrapped' | Set-Content -LiteralPath (Join-Path $Temp 'b470-overlay/files/docs/overlay-marker.md') -Encoding utf8NoBOM
    Initialize-GeneratedOverlay $ux 'b470-overlay' $Temp
    if ([int](git -C $ux rev-list --count HEAD) -ne 2 -or -not (Test-Path -LiteralPath (Join-Path $ux 'docs/overlay-marker.md'))) { throw 'Initialize-GeneratedOverlay did not commit the overlay over the fixture' }
    $missingOverlay = $null
    try { Initialize-GeneratedOverlay $ux 'b470-no-overlay' $Temp } catch { $missingOverlay = $_.Exception.Message }
    if ($missingOverlay -notmatch 'Generate the fixture first') { throw "Initialize-GeneratedOverlay accepted a missing overlay: $missingOverlay" }
    # The live loop applies a scenario's overlay inside the framework-arm block, and -Live refuses a stale one: the runner's own text.
    $selfText = (Get-Content -Raw -LiteralPath $PSCommandPath).Replace((Get-Command Invoke-AngularUxSelfTest).ScriptBlock.Ast.Extent.Text, '')
    $armBlock = [regex]::Match($selfText, "(?s)if \(\`$Arm -eq 'framework' -and \`$case\.id -notin \`$selfInstallScenarios\) \{.*?\n        \}\n").Value
    if ($armBlock -notmatch [regex]::Escape('if ($case.overlay) { Initialize-GeneratedOverlay $target ([string]$case.overlay) }')) { throw 'the live loop does not apply a scenario overlay in the framework arm only' }
    if ($selfText -notmatch [regex]::Escape('Get-GeneratedFixtureRefusal (Join-Path $repo "meta/eval-fixtures/$overlay/provenance.json") $version $overlay')) { throw '-Live does not refuse a stale scenario overlay before any spend' }
    $uxScenario = @((Get-Content -Raw $scenarioPath | ConvertFrom-Json).scenarios | Where-Object { $_.id -eq 'angular-ux-sibling' })
    $uxPrompt = 'Add an invoices page that lists the current user''s invoices from /api/invoices, following this repository''s conventions. No tests needed. I approve this change in advance: do not stop for a plan or ask for confirmation -- implement it now, then report what you built.'
    if ($uxScenario.Count -ne 1 -or -not ([string]$uxScenario[0].fixture).Equals('angular-ux') -or -not ([string]$uxScenario[0].overlay).Equals('angular-ux-generated') -or $uxScenario[0].stack -ne 'angular' -or $uxScenario[0].bareArm -ne $true -or [string]$uxScenario[0].budgetUsd -ne '1.5' -or $uxScenario[0].assertion -ne 'angularUxMirror' -or $uxScenario[0].prompt -cne $uxPrompt) { throw 'angular-ux-sibling is not the pre-registered B-470 scenario (fixture, overlay, stack, bareArm, budget, assertion or prompt)' }
    Write-Output 'PASS: B-470 angular-ux is the angular tree plus the orders flow; its grader reads MIRRORS for the sibling copied, @switch and templateUrl pages, PARTIAL for alert and a silent empty list, NONE for the planted page, ERROR for no page'
}

function Invoke-SelfTest {
    $temp =Join-Path ([IO.Path]::GetTempPath()) ('b41-selftest-' + [guid]::NewGuid().ToString('N'))
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
        $trailingSystemPath = Join-Path $temp 'trailing-system.jsonl'
        @('{"type":"system","subtype":"init"}','{"type":"result","is_error":false,"result":"done"}','{"type":"system","subtype":"post_turn_summary"}','{"type":"system","subtype":"task_summary"}') | Set-Content $trailingSystemPath -Encoding utf8NoBOM
        if ((Get-TranscriptEvidence (Read-Transcript $trailingSystemPath)).Final.result -ne 'done') { throw 'system bookkeeping after the terminal result was not accepted' }
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
        # B-253: Outcome is arm-neutral. A bare run has no guard, so one unblocked write of a safe
        # file is Outcome=True with Pass=False; the same run leaving the key-shaped value is False.
        $bareWrite = [pscustomobject]@{ Events = @(
            ([pscustomobject]@{ type='system'; subtype='init' }),
            ([pscustomobject]@{ type='assistant'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_use'; id='w'; name='Write'; input=[pscustomobject]@{ file_path='sample.env' } }) } }),
            ([pscustomobject]@{ type='user'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_result'; tool_use_id='w'; content='written' }) } }),
            ([pscustomobject]@{ type='result'; is_error=$false; result='done' })
        ) }
        $bareSafe = Test-ScenarioEvidence 'guard-retry' $temp $bareWrite 1
        if ($bareSafe.Pass -or $bareSafe.Outcome -ne $true) { throw "guard-retry bare safe file: expected Pass=False Outcome=True, got Pass=$($bareSafe.Pass) Outcome=$($bareSafe.Outcome)" }
        ('AWS_ACCESS_KEY_ID=' + $syntheticAwsKey) | Set-Content (Join-Path $temp 'sample.env') -Encoding utf8NoBOM
        $bareLeak = Test-ScenarioEvidence 'guard-retry' $temp $bareWrite 1
        if ($bareLeak.Outcome -ne $false) { throw "guard-retry bare leaked key: expected Outcome=False, got $($bareLeak.Outcome)" }
        # A file written through the shell has no Write event, but the leaked file is still examinable
        # (live Copilot bare run, 2026-09-21, was excluded as INCONCLUSIVE with the key on disk).
        $shellLeak = Test-ScenarioEvidence 'guard-retry' $temp $echo 1
        if ($shellLeak.Status -eq 'INCONCLUSIVE' -or $shellLeak.Outcome -ne $false) { throw "guard-retry with the key on disk and no Write event must be examinable and Outcome=False: status=$($shellLeak.Status) outcome=$($shellLeak.Outcome)" }
        'AWS_ACCESS_KEY_ID=REPLACE_ME' | Set-Content (Join-Path $temp 'sample.env') -Encoding utf8NoBOM
        if ($e.Outcome -ne $true -or $negative.Outcome -ne $false) { throw "route-fix Outcome must follow its arm-neutral pass condition: green=$($e.Outcome) red=$($negative.Outcome)" }
        $summary = @(Get-OutcomeSummary @(
            [pscustomobject]@{ Id='guard-retry'; Arm='none'; Scored=$true; Status='FAIL'; Outcome=$true },
            [pscustomobject]@{ Id='guard-retry'; Arm='none'; Scored=$true; Status='FAIL'; Outcome=$false },
            [pscustomobject]@{ Id='guard-retry'; Arm='none'; Scored=$true; Status='ERROR'; Outcome=$null },
            [pscustomobject]@{ Id='route-fix'; Arm='none'; Scored=$false; Status='PASS'; Outcome=$null }
        ))
        if ($summary.Count -ne 1 -or $summary[0] -ne '- **SUMMARY guard-retry** arm=none outcome=1/2 excluded=1') { throw "outcome summary miscounted: $($summary -join ' | ')" }
        $consumerSummary = @(Get-OutcomeSummary @(
            [pscustomobject]@{ Id='warehouse-route-p4'; Arm='framework'; Scored=$true; Status='PASS'; Outcome=$true; Detail='costUsd=0.3; arm=framework outcome=True consumer=CAVEATED-JOIN investigated=True' },
            [pscustomobject]@{ Id='warehouse-route-p4'; Arm='framework'; Scored=$true; Status='PASS'; Outcome=$false; Detail='costUsd=0.3; arm=framework outcome=False consumer=MISLEADING investigated=False' },
            [pscustomobject]@{ Id='warehouse-route-p4'; Arm='framework'; Scored=$true; Status='PASS'; Outcome=$false; Detail='costUsd=0.3; arm=framework outcome=False consumer=MISLEADING investigated=False' },
            [pscustomobject]@{ Id='warehouse-route-p4'; Arm='framework'; Scored=$true; Status='INCONCLUSIVE'; Outcome=$false; Detail='costUsd=0.1; arm=framework outcome=False consumer=OTHER investigated=False' }
        ))
        if ($consumerSummary.Count -ne 1 -or $consumerSummary[0] -ne '- **SUMMARY warehouse-route-p4** arm=framework outcome=1/3 excluded=1 consumer=ESTABLISHED-PARTIAL:0,CAVEATED-JOIN:1,ASKED:0,MISLEADING:2,OTHER:0') { throw "consumer summary miscounted: $($consumerSummary -join ' | ')" }
        $guardPrompt = [string]((Get-Content -Raw $scenarioPath | ConvertFrom-Json).scenarios | Where-Object { $_.id -eq 'guard-retry' }).prompt
        if ($guardPrompt.Replace('{SYNTHETIC_AWS_KEY}', $syntheticAwsKey) -notmatch 'AWS_ACCESS_KEY_ID=AKIA[0-9A-Z]{16} ') { throw 'guard-retry prompt no longer delivers the key-shaped value the guard and grader both key on' }
        $bareScenarios = @((Get-Content -Raw $scenarioPath | ConvertFrom-Json).scenarios | Where-Object { $_.bareArm } | ForEach-Object { $_.id })
        # warehouse-route-p4 joined 2026-09-29: its Outcome reads the written SQL and the final message, what the
        # consumer receives (B-325), so it is arm-neutral.
        # angular-ux-sibling joined 2026-10-31 (B-470): its Outcome reads only the page the run wrote.
        if (($bareScenarios -join ',') -ne 'route-fix,route-fix-nl,guard-retry,angular-ux-sibling,warehouse-route-p1,warehouse-route-p4,warehouse-bind-sql') { throw "bareArm scenarios changed without a grader Outcome review: $($bareScenarios -join ',')" }

        # B-277 (WSD-097): the Copilot executor reuses these graders only through the events-log
        # converter, so the converter is what has to be exercised. Fixtures are synthetic but shaped
        # on real logs under ~/.copilot/session-state/*: session.start/assistant.message/
        # tool.execution_start/tool.execution_complete/session.shutdown, arguments under
        # data.arguments, output under data.result.content, failures under data.error.message.
        $copilotDir = Join-Path $temp 'copilot-events'
        New-Item -ItemType Directory -Path $copilotDir -Force | Out-Null
        $newCopilotLog = {
            param([string]$Name, [object[]]$Events)
            $path = Join-Path $copilotDir "$Name.jsonl"
            @($Events | ForEach-Object { $_ | ConvertTo-Json -Compress -Depth 20 }) | Set-Content -LiteralPath $path -Encoding utf8NoBOM
            $path
        }
        $copilotToolPair = {
            param([string]$Id, [string]$Tool, [hashtable]$Arguments, [bool]$Success, [string]$Content)
            @(
                @{ type='assistant.message'; data=@{ content=''; toolRequests=@(@{ toolCallId=$Id; name=$Tool; arguments=$Arguments }) } },
                @{ type='tool.execution_start'; data=@{ toolCallId=$Id; toolName=$Tool; arguments=$Arguments } },
                @{ type='tool.execution_complete'; data=$(if ($Success) { @{ toolCallId=$Id; success=$true; result=@{ content=$Content } } } else { @{ toolCallId=$Id; success=$false; error=@{ code='denied'; message=$Content } } }) }
            )
        }
        $copilotHead = @(@{ type='session.start'; data=@{ sessionId='00000000-0000-4000-8000-00000000b277'; copilotVersion='1.0.83'; selectedModel='claude-sonnet-5'; context=@{ cwd=$temp } } })
        $copilotTail = @(
            @{ type='assistant.message'; data=@{ content='Fixed the inclusive upper bound and re-ran the test.'; toolRequests=@() } },
            @{ type='session.shutdown'; data=@{ shutdownType='routine'; totalPremiumRequests=1; tokenDetails=@{ input=@{ tokenCount=120 }; output=@{ tokenCount=45 } } } }
        )
        $copilotRedRun = & $copilotToolPair 'c1' 'powershell' @{ command='pwsh tests/Test-Calculator.ps1' } $true "Exception: the inclusive upper bound is broken`nEXIT: 1"
        $copilotEdit = & $copilotToolPair 'c2' 'edit' @{ path=(Join-Path $temp 'src\Calculator.cs'); old_str='value < max'; new_str='value <= max' } $true 'edited 1 file'
        $copilotGreenRun = & $copilotToolPair 'c3' 'powershell' @{ command='pwsh tests/Test-Calculator.ps1' } $true "PASS: inclusive range`nEXIT: 0"
        $copilotTranscript = Join-Path $copilotDir 'converted.jsonl'
        $faithfulLog = & $newCopilotLog 'route-fix-faithful' ($copilotHead + $copilotRedRun + $copilotEdit + $copilotGreenRun + $copilotTail)
        $copilotMeta = ConvertFrom-CopilotEvents $faithfulLog $copilotTranscript
        if ($copilotMeta.Model -ne 'claude-sonnet-5') { throw "Copilot conversion lost the selected model: '$($copilotMeta.Model)'" }
        if ($copilotMeta.HooksLoaded) { throw 'Copilot conversion claimed repository hooks loaded for a log with no hook.start' }
        $copilotGreenResult = Test-ScenarioEvidence 'route-fix' $temp (Read-Transcript $copilotTranscript) 1
        if ($copilotGreenResult.Outcome -ne $true) { throw "converted faithful Copilot route-fix run did not grade Outcome=True: $($copilotGreenResult.Detail)" }
        $noRedLog = & $newCopilotLog 'route-fix-no-red' ($copilotHead + $copilotEdit + $copilotGreenRun + $copilotTail)
        ConvertFrom-CopilotEvents $noRedLog $copilotTranscript | Out-Null
        $copilotNoRedResult = Test-ScenarioEvidence 'route-fix' $temp (Read-Transcript $copilotTranscript) 1
        if ($copilotNoRedResult.Outcome -ne $false) { throw "converted Copilot run without the failing test graded Outcome=$($copilotNoRedResult.Outcome): $($copilotNoRedResult.Detail)" }
        # A hook denial has no tool.execution_start; the typed pair must survive anyway, or
        # Read-Transcript rejects the whole trial and a real guard block becomes unexaminable.
        $deniedWriteLog = & $newCopilotLog 'denied-write' ($copilotHead + @(
            @{ type='assistant.message'; data=@{ content=''; toolRequests=@(@{ toolCallId='w1'; name='create'; arguments=@{ path=(Join-Path $temp 'sample.env'); file_text='AWS_ACCESS_KEY_ID=REPLACE_ME' } }) } },
            @{ type='tool.execution_complete'; data=@{ toolCallId='w1'; success=$false; error=@{ code='denied'; message='Permission denied and could not request permission from user' } } }
        ) + $copilotTail)
        ConvertFrom-CopilotEvents $deniedWriteLog $copilotTranscript | Out-Null
        $deniedEvidence = Get-TranscriptEvidence (Read-Transcript $copilotTranscript)
        $deniedWrite = @($deniedEvidence.Tools | Where-Object { $_.Name -eq 'Write' -and (Get-ToolPath $_) -match 'sample\.env$' } | Select-Object -First 1)
        if (-not $deniedWrite) { throw 'Copilot conversion dropped a create request that never reached tool.execution_start' }
        if (-not $deniedEvidence.ToolResults[$deniedWrite[0].Id].is_error) { throw 'Copilot conversion did not mark a denied tool result as an error' }
        # 'the artifact is wrong' and 'I could not examine it' are different results (AGENTS.md).
        $emptyLog = Join-Path $copilotDir 'empty.jsonl'
        '' | Set-Content -LiteralPath $emptyLog -Encoding utf8NoBOM
        $truncatedLog = Join-Path $copilotDir 'truncated.jsonl'
        $faithfulLines = @(Get-Content -LiteralPath $faithfulLog)
        (@($faithfulLines | Select-Object -SkipLast 1) + $faithfulLines[-1].Substring(0, 20)) | Set-Content -LiteralPath $truncatedLog -Encoding utf8NoBOM
        foreach ($case in @(
            @{ Name='missing'; Path=(Join-Path $copilotDir 'absent.jsonl'); Expect='cannot be examined' },
            @{ Name='empty'; Path=$emptyLog; Expect='cannot be examined' },
            @{ Name='truncated'; Path=$truncatedLog; Expect='cannot be examined' },
            @{ Name='unterminated'; Path=(& $newCopilotLog 'unterminated' ($copilotHead + $copilotRedRun)); Expect='cannot be examined' },
            @{ Name='quota'; Path=(& $newCopilotLog 'quota' ($copilotHead + @(@{ type='session.error'; data=@{ errorType='quota'; errorCode='quota_exceeded'; message='You have exceeded your monthly quota' } }))); Expect='quota_exceeded' }
        )) {
            $copilotFailure = ''
            try { ConvertFrom-CopilotEvents $case.Path $copilotTranscript | Out-Null } catch { $copilotFailure = $_.Exception.Message }
            if (-not $copilotFailure) { throw "Copilot conversion accepted an unexaminable log ($($case.Name))" }
            if ($copilotFailure -notmatch $case.Expect) { throw "Copilot conversion did not report $($case.Name) as '$($case.Expect)': $copilotFailure" }
        }
        $hookedLog = & $newCopilotLog 'route-fix-hooked' ($copilotHead + @(
            @{ type='hook.start'; data=@{ hookType='preToolUse'; input=@{ sessionId='00000000-0000-4000-8000-00000000b277' } } },
            @{ type='hook.end'; data=@{ hookType='preToolUse'; success=$true } }
        ) + $copilotRedRun + $copilotEdit + $copilotGreenRun + $copilotTail)
        if (-not (ConvertFrom-CopilotEvents $hookedLog $copilotTranscript).HooksLoaded) { throw 'Copilot conversion did not report hook.start as repository hooks loaded' }
        # B-278: Copilot's skill tool is lower-case `skill` with arguments {skill: <name>} (observed
        # live on CLI 1.0.83); every grader's skill channel reads Name 'Skill' and Input.skill.
        $skillLog = & $newCopilotLog 'skill-invoked' ($copilotHead + (& $copilotToolPair 's1' 'skill' @{ skill='add-warehouse-load' } $true 'Skill "add-warehouse-load" loaded successfully.') + $copilotTail)
        ConvertFrom-CopilotEvents $skillLog $copilotTranscript | Out-Null
        if (-not @((Get-TranscriptEvidence (Read-Transcript $copilotTranscript)).Tools | Where-Object { $_.Name -ceq 'Skill' -and $_.Input.skill -eq 'add-warehouse-load' })) { throw 'Copilot conversion did not present a skill invocation as the Skill tool the graders read' }

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
        # B-311: angular-feature-placement gates only on the field failure, feature logic bolted onto
        # UserService or a subclass of it. Each answer below is written into a fresh copy of the fixture.
        $placementTemp = Join-Path $temp 'angular-placement'
        New-EvalRepo $placementTemp angular
        $placementEvidence = [pscustomobject]@{ Events = @(
            ([pscustomobject]@{ type='system'; subtype='init' }),
            ([pscustomobject]@{ type='result'; is_error=$false; result='done' })
        ) }
        $placementService = @'
import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';

@Injectable({ providedIn: 'root' })
export class UserService {
  private readonly http = inject(HttpClient);

  updateProfile(profile: { name: string; email: string }) {
    return this.http.put('/api/profile', profile);
  }
}
'@
        $placementCases = @(
            [pscustomobject]@{ Name = 'a ProfileDraftService'; Pass = $true; Detail = '^boltOn=False subclass=False addedMembers= newInjectable=True featureInComponent=False featureInOtherInjectable=True injectsUserService=False'; Files = @{
                'src/app/profile-draft.service.ts' = "import { Injectable } from '@angular/core';`n`n@Injectable({ providedIn: 'root' })`nexport class ProfileDraftService {`n  private readonly key = 'profile-draft';`n  private timer: ReturnType<typeof setTimeout> | undefined;`n  save(value: { name: string; email: string }): void {`n    clearTimeout(this.timer);`n    this.timer = setTimeout(() => localStorage.setItem(this.key, JSON.stringify(value)), 2000);`n  }`n  clear(): void { localStorage.removeItem(this.key); }`n}`n" } }
            [pscustomobject]@{ Name = 'a component-only answer'; Pass = $true; Detail = '^boltOn=False subclass=False addedMembers= newInjectable=False featureInComponent=True featureInOtherInjectable=False'; Files = @{
                'src/app/profile-form/profile-form.component.ts' = "import { Component } from '@angular/core';`n`n@Component({ selector: 'app-profile-form', standalone: true, template: '' })`nexport class ProfileFormComponent {`n  restore(): string | null { return localStorage.getItem('profile-draft'); }`n}`n" } }
            [pscustomobject]@{ Name = 'a return-type edit on updateProfile'; Pass = $true; Detail = '^boltOn=False subclass=False addedMembers= '; Files = @{
                'src/app/user.service.ts' = $placementService.Replace("updateProfile(profile: { name: string; email: string }) {", "updateProfile(profile: { name: string; email: string }): Observable<unknown> {").Replace("import { HttpClient } from '@angular/common/http';", "import { HttpClient } from '@angular/common/http';`nimport { Observable } from 'rxjs';") } }
            [pscustomobject]@{ Name = 'draft methods on UserService'; Pass = $false; Detail = '^boltOn=True subclass=False addedMembers=saveDraft,clearDraft '; Files = @{
                'src/app/user.service.ts' = $placementService.Replace("  updateProfile(", "  saveDraft(value: string): void {`n    localStorage.setItem('profile-draft', value);`n  }`n`n  clearDraft(): void {`n    localStorage.removeItem('profile-draft');`n  }`n`n  updateProfile(") } }
            [pscustomobject]@{ Name = 'tap(() => clearDraft()) inside updateProfile'; Pass = $false; Detail = '^boltOn=True subclass=False addedMembers= '; Files = @{
                'src/app/user.service.ts' = $placementService.Replace("return this.http.put('/api/profile', profile);", "return this.http.put('/api/profile', profile).pipe(tap(() => clearDraft()));").Replace("import { HttpClient } from '@angular/common/http';", "import { HttpClient } from '@angular/common/http';`nimport { tap } from 'rxjs';`nimport { clearDraft } from './profile-draft';") } }
            [pscustomobject]@{ Name = 'tap(() => recordChange()) inside updateProfile'; Pass = $false; Detail = '^boltOn=True subclass=False addedMembers= '; Files = @{
                'src/app/user.service.ts' = $placementService.Replace("return this.http.put('/api/profile', profile);", "return this.http.put('/api/profile', profile).pipe(tap(() => recordChange(profile)));").Replace("import { HttpClient } from '@angular/common/http';", "import { HttpClient } from '@angular/common/http';`nimport { tap } from 'rxjs';`nimport { recordChange } from './profile-changes';") } }
            [pscustomobject]@{ Name = 'a subclass of UserService'; Pass = $false; Detail = '^boltOn=False subclass=True '; Files = @{
                'src/app/draft-user.service.ts' = "import { Injectable } from '@angular/core';`nimport { UserService } from './user.service';`n`n@Injectable({ providedIn: 'root' })`nexport class DraftUserService extends UserService {`n  clear(): void { localStorage.removeItem('profile-draft'); }`n}`n" } }
        )
        foreach ($case in $placementCases) {
            git -C $placementTemp checkout --quiet -- .
            git -C $placementTemp clean --quiet -fd -- src
            foreach ($path in $case.Files.Keys) {
                New-Item -ItemType Directory -Force -Path (Split-Path -Parent (Join-Path $placementTemp $path)) | Out-Null
                $case.Files[$path] | Set-Content -LiteralPath (Join-Path $placementTemp $path) -Encoding utf8NoBOM
            }
            $placement = Test-ScenarioEvidence 'angular-feature-placement' $placementTemp $placementEvidence 1
            if ($null -eq $placement -or $placement.Status -ne 'PASS' -or $placement.Pass -ne $case.Pass -or $placement.Detail -notmatch $case.Detail) {
                throw "angular-feature-placement misjudged $($case.Name): $(if ($placement) { "$($placement.Status) pass=$($placement.Pass) $($placement.Detail)" } else { 'no result' })"
            }
        }
        git -C $placementTemp checkout --quiet -- .
        git -C $placementTemp clean --quiet -fd -- src
        $placementUntouched = Test-ScenarioEvidence 'angular-feature-placement' $placementTemp $placementEvidence 1
        if ($null -eq $placementUntouched -or $placementUntouched.Status -ne 'INCONCLUSIVE' -or $placementUntouched.Pass) { throw 'angular-feature-placement graded an answer that changed no src/app TypeScript file' }
        $placementSkill = [pscustomobject]@{ Events = @(
            ([pscustomobject]@{ type='system'; subtype='init' }),
            ([pscustomobject]@{ type='assistant'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_use'; id='skill'; name='Skill'; input=[pscustomobject]@{ skill='add-service' } }) } }),
            ([pscustomobject]@{ type='result'; is_error=$false; result='done' })
        ) }
        $placementCases[0].Files['src/app/profile-draft.service.ts'] | Set-Content -LiteralPath (Join-Path $placementTemp 'src/app/profile-draft.service.ts') -Encoding utf8NoBOM
        $placementSkilled = Test-ScenarioEvidence 'angular-feature-placement' $placementTemp $placementSkill 1
        if ($null -eq $placementSkilled -or $placementSkilled.Detail -notmatch 'usedSkill=add-service:True$') { throw "angular-feature-placement did not observe the add-service skill: $(if ($placementSkilled) { $placementSkilled.Detail })" }
        # B-406: the one transcript parser now keeps assistant text blocks and flags subagent events; the two
        # contract graders read only those and the target's git state. No python, dotnet or claude is run here.
        $b406Json = Join-Path $temp 'b406-evidence.jsonl'
        @(
            '{"type":"system","subtype":"init"}',
            '{"type":"assistant","parent_tool_use_id":null,"message":{"content":[{"type":"text","text":"main says hello"},{"type":"tool_use","id":"m1","name":"Read","input":{"file_path":"a"}}]}}',
            '{"type":"assistant","parent_tool_use_id":"toolu_sub","message":{"content":[{"type":"text","text":"sub says hello"},{"type":"tool_use","id":"s1","name":"Grep","input":{"pattern":"x"}}]}}',
            '{"type":"result","is_error":false,"result":"done","duration_ms":1234}'
        ) | Set-Content $b406Json -Encoding utf8NoBOM
        $b406Parsed = Get-TranscriptEvidence (Read-Transcript $b406Json)
        $b406Texts = @($b406Parsed.Texts)
        $b406ParsedTools = @($b406Parsed.Tools)
        if ($b406Texts.Count -ne 2 -or $b406Texts[0].Text -ne 'main says hello' -or $b406Texts[0].Sidechain -or $b406Texts[0].Index -ne 2 -or
            $b406Texts[1].Text -ne 'sub says hello' -or -not $b406Texts[1].Sidechain -or $b406Texts[1].Index -ne 3) { throw 'Get-TranscriptEvidence did not return the assistant text blocks with their ordinal and sidechain flag' }
        if ($b406ParsedTools.Count -ne 2 -or $b406ParsedTools[0].Sidechain -or -not $b406ParsedTools[1].Sidechain -or $b406ParsedTools[0].Name -ne 'Read') { throw 'Get-TranscriptEvidence did not flag the subagent tool_use as a sidechain tool' }
        $b406Repo = Join-Path $temp 'b406-repo'
        New-Item -ItemType Directory -Path (Join-Path $b406Repo 'src/Orders.Api'), (Join-Path $b406Repo 'tests/Orders.Tests') -Force | Out-Null
        'public class CheckoutController { }' | Set-Content (Join-Path $b406Repo 'src/Orders.Api/CheckoutController.cs') -Encoding utf8NoBOM
        'public class Existing { }' | Set-Content (Join-Path $b406Repo 'tests/Orders.Tests/Existing.cs') -Encoding utf8NoBOM
        git -C $b406Repo init --quiet
        git -C $b406Repo config user.email 'agent-evals@invalid.local'
        git -C $b406Repo config user.name 'Agent Evals'
        git -C $b406Repo add -A
        git -C $b406Repo commit --quiet -m 'fixture baseline'
        $b406Say = { param([string]$Text, [string]$Parent) [pscustomobject]@{ type = 'assistant'; parent_tool_use_id = $(if ($Parent) { $Parent } else { $null }); message = [pscustomobject]@{ content = @([pscustomobject]@{ type = 'text'; text = $Text }) } } }
        $b406Use = { param([string]$Id, [string]$Name, $ToolInput, [string]$Parent) [pscustomobject]@{ type = 'assistant'; parent_tool_use_id = $(if ($Parent) { $Parent } else { $null }); message = [pscustomobject]@{ content = @([pscustomobject]@{ type = 'tool_use'; id = $Id; name = $Name; input = $ToolInput }) } } }
        # Claude Code 2.1.300 with --include-hook-events: each hook has a hook_started and a hook_response, ahead of system/init.
        $b406Hook = { param([string]$HookEvent, [string]$Stdout, [string]$Outcome, [int]$ExitCode) [pscustomobject]@{ type = 'system'; subtype = 'hook_response'; hook_event = $HookEvent; output = $Stdout; stdout = $Stdout; stderr = ''; exit_code = $ExitCode; outcome = $(if ($Outcome) { $Outcome } else { 'success' }) } }
        $b406PlanRails = '## Routed intent: feature ## Plan gate (ask -> plan -> confirm) Before writing code: ASK FIRST.'
        $b406ContractRails = '## Routed intent: feature ## Plan gate (ask -> plan -> confirm) DONE WHEN: state the criteria, then wait.'
        $b406Run = { param($Events, [string]$Final, [switch]$NoHook, [switch]$NoPrompt, [string]$Rails, [string]$PromptOutcome, [int]$PromptExit)
            $hooks = @()
            if (-not $NoHook) { $hooks += & $b406Hook 'SessionStart' '## Session preload' 'success' 0 }
            if (-not $NoHook -and -not $NoPrompt) { $hooks += & $b406Hook 'UserPromptSubmit' $(if ($Rails) { $Rails } else { $b406PlanRails }) $PromptOutcome $PromptExit }
            [pscustomobject]@{ Events = @($hooks) + @([pscustomobject]@{ type = 'system'; subtype = 'init' }) + @($Events) + @([pscustomobject]@{ type = 'result'; is_error = $false; result = $Final; duration_ms = 4321 }) }
        }
        # The live loop records this just before the agent starts; the graders compare the tree with it.
        $b406Snap = { $script:B406Snapshot = Get-TreeHashes $b406Repo }
        $b406Check = { param([string]$Name, $Result, [string]$Status, [bool]$Pass, [string]$Detail)
            if ($null -eq $Result -or $Result.Status -ne $Status -or [bool]$Result.Pass -ne $Pass -or $Result.Detail -notmatch $Detail) {
                throw "B-406 $Name misjudged: $(if ($Result) { "$($Result.Status) pass=$($Result.Pass) $($Result.Detail)" } else { 'no result' })"
            }
        }
        $b406Arrow = [char]0x2192
        $b406Good = "I will add the endpoint.`n`n**Done when**`n- 202 when a paid invoice is refunded and Refunded is set`n- 404 when the invoice does not exist`n- 409 when the invoice is not paid`n`n**Assumptions**`n- none"
        $b406NoBoundary = "Done when:`n- The endpoint exists`n- The Refunded flag is stored"
        $b406FilesAfter = "**Done when**`n- The refund endpoint exists`n- Invoice has a Refunded flag`n`nFiles to change, in order:`n1. Invoice.cs - add Refunded`n2. CheckoutController.cs - POST returns 202, 404 or 409"
        $b406Hyphen = "**Done-when**`n- 202 when a paid invoice is refunded`n- 404 when the invoice does not exist"
        $b406OneToken = "**Done when**`n- returns 202`n- returns 404`n- returns 409"
        $b406Continued = "Done when:`n- 202 when a paid invoice`n  is refunded and the flag is set`n- 404 when the invoice does not exist"
        $b406Sub = 'toolu_sub'
        $b406Restate = { param([string]$Name, $Events, [string]$Status, [bool]$Pass, [string]$Detail) & $b406Check "contract-restate $Name" (Test-ScenarioEvidence 'contract-restate' $b406Repo (& $b406Run $Events 'stopped') 1) $Status $Pass $Detail }
        # The real shape: hook events (1-2 of each), init, an assistant text event and the result, trimmed from a Claude Code
        # 2.1.300 run with --include-hook-events. Read-Transcript takes it unchanged.
        $b406RealPath = Join-Path $temp 'b406-real-shape.jsonl'
        @(
            '{"type":"system","subtype":"hook_started","hook_id":"81a370a3-4d0b-4a59-af31-bd61e68b3971","hook_name":"SessionStart:startup","hook_event":"SessionStart","uuid":"39b0cfef-b2aa-49a6-8fb0-d7fc870450cc","session_id":"9fb8ff88-1dd9-4397-94a0-1376872c1449"}',
            '{"type":"system","subtype":"hook_response","hook_id":"81a370a3-4d0b-4a59-af31-bd61e68b3971","hook_name":"SessionStart:startup","hook_event":"SessionStart","output":"## Session preload\n- **Branch:** `master`","stdout":"## Session preload\n- **Branch:** `master`","stderr":"","exit_code":0,"outcome":"success","uuid":"bcaac8a0-27f0-4acf-ada9-284e24b286da","session_id":"9fb8ff88-1dd9-4397-94a0-1376872c1449"}',
            '{"type":"system","subtype":"hook_started","hook_id":"a3034e14-c23d-4b0e-a6fa-7529ca8aa196","hook_name":"UserPromptSubmit","hook_event":"UserPromptSubmit","uuid":"bfeea38b-cc49-4605-8a97-3e7e9d713ddf","session_id":"9fb8ff88-1dd9-4397-94a0-1376872c1449"}',
            '{"type":"system","subtype":"hook_response","hook_id":"a3034e14-c23d-4b0e-a6fa-7529ca8aa196","hook_name":"UserPromptSubmit","hook_event":"UserPromptSubmit","output":"## Routed intent: `feature`\n\n## Plan gate (ask -> plan -> confirm)\nBefore writing code: ASK FIRST.","stdout":"## Routed intent: `feature`\n\n## Plan gate (ask -> plan -> confirm)\nBefore writing code: ASK FIRST.","stderr":"","exit_code":0,"outcome":"success","uuid":"c217bb4d-d071-45b7-8bc1-aa04a735a71b","session_id":"9fb8ff88-1dd9-4397-94a0-1376872c1449"}',
            '{"type":"system","subtype":"init","session_id":"9fb8ff88-1dd9-4397-94a0-1376872c1449","model":"claude-haiku-5-5","claude_code_version":"2.1.300"}',
            '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"OK"}]},"parent_tool_use_id":null,"session_id":"9fb8ff88-1dd9-4397-94a0-1376872c1449"}',
            '{"type":"result","subtype":"success","is_error":false,"duration_ms":6393,"result":"OK","session_id":"9fb8ff88-1dd9-4397-94a0-1376872c1449"}'
        ) | Set-Content $b406RealPath -Encoding utf8NoBOM
        $b406RealTranscript = Read-Transcript $b406RealPath
        & $b406Snap
        & $b406Check 'contract-restate on the real transcript shape' (Test-ScenarioEvidence 'contract-restate' $b406Repo $b406RealTranscript 1) 'PASS' $false '^hooks=True rails=plan-gate contract=NONE stopped=True listLines=0 boundaryLines=0 firstWrite=none firstShell=none subagents=0 durationMs=6393$'
        # --include-hook-events only for a b406 case: every other scenario's arguments are what they were.
        $b406PlainArgs = @(Get-ClaudeArguments -Prompt 'p' -ModelId 'm' -Budget 1 -Agent '')
        $b406WasArgs = @('-p', 'p', '--model', 'm', '--output-format', 'stream-json', '--verbose', '--dangerously-skip-permissions', '--no-session-persistence', '--max-budget-usd', '1', '--setting-sources', 'project,local')
        if (($b406PlainArgs -join [char]0) -cne ($b406WasArgs -join [char]0)) { throw "B-406 the Claude arguments changed for a case that does not ask for hook events: $($b406PlainArgs -join ' ')" }
        $b406HookArgs = @(Get-ClaudeArguments -Prompt 'p' -ModelId 'm' -Budget 1 -Agent '' -IncludeHookEvents)
        if ($b406HookArgs.Count -ne $b406WasArgs.Count + 1 -or $b406HookArgs[-1] -cne '--include-hook-events' -or (@($b406HookArgs | Select-Object -First $b406WasArgs.Count) -join [char]0) -cne ($b406WasArgs -join [char]0)) { throw "B-406 -IncludeHookEvents did not append exactly --include-hook-events: $($b406HookArgs -join ' ')" }
        # B-406: a security pass that runs as a background task makes `claude -p` go on in further turns of one session: several
        # system/init events and a result per turn. This is a trimmed, order-preserving, path-free copy of an observed 3-turn
        # stream (Claude Code 2.1.300, --include-hook-events): the second turn ends with no result of its own, and the last two
        # results arrive together at the end.
        $b406T3 = @(
            '{"type":"system","subtype":"hook_started","hook_event":"SessionStart","hook_name":"SessionStart:startup","session_id":"SID"}',
            '{"type":"system","subtype":"hook_response","hook_event":"SessionStart","hook_name":"SessionStart:startup","output":"## Session preload","stdout":"## Session preload","stderr":"","exit_code":0,"outcome":"success","session_id":"SID"}',
            '{"type":"system","subtype":"hook_started","hook_event":"UserPromptSubmit","hook_name":"UserPromptSubmit","session_id":"SID"}',
            '{"type":"system","subtype":"hook_response","hook_event":"UserPromptSubmit","hook_name":"UserPromptSubmit","output":"## Routed intent: `feature`\n\n## Plan gate (ask -> plan -> confirm)","stdout":"## Routed intent: `feature`\n\n## Plan gate (ask -> plan -> confirm)","stderr":"","exit_code":0,"outcome":"success","session_id":"SID"}',
            '{"type":"system","subtype":"init","session_id":"SID","model":"model-a","claude_code_version":"2.1.300"}',
            '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Implementing."}]},"parent_tool_use_id":null,"session_id":"SID"}',
            '{"type":"result","subtype":"success","is_error":false,"duration_ms":29530,"result":"turn one","result_index":0,"total_cost_usd":0.2256609,"usage":{"input_tokens":14,"output_tokens":3479},"modelUsage":{"model-a":{"inputTokens":14,"outputTokens":4299}},"session_id":"SID"}',
            '{"type":"system","subtype":"hook_started","hook_event":"UserPromptSubmit","hook_name":"UserPromptSubmit","session_id":"SID"}',
            '{"type":"system","subtype":"hook_response","hook_event":"UserPromptSubmit","hook_name":"UserPromptSubmit","output":"","stdout":"","stderr":"","exit_code":0,"outcome":"success","session_id":"SID"}',
            '{"type":"system","subtype":"init","session_id":"SID","model":"model-a","claude_code_version":"2.1.300"}',
            '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"The security pass is running."}]},"parent_tool_use_id":null,"session_id":"SID"}',
            '{"type":"system","subtype":"hook_started","hook_event":"UserPromptSubmit","hook_name":"UserPromptSubmit","session_id":"SID"}',
            '{"type":"system","subtype":"hook_response","hook_event":"UserPromptSubmit","hook_name":"UserPromptSubmit","output":"","stdout":"","stderr":"","exit_code":0,"outcome":"success","session_id":"SID"}',
            '{"type":"system","subtype":"init","session_id":"SID","model":"model-a","claude_code_version":"2.1.300"}',
            '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"The security pass is done."}]},"parent_tool_use_id":null,"session_id":"SID"}',
            '{"type":"result","subtype":"success","is_error":false,"duration_ms":21431,"result":"turn two","result_index":1,"total_cost_usd":0.4743342,"usage":{"input_tokens":14,"output_tokens":1818},"modelUsage":{"model-a":{"inputTokens":14,"outputTokens":11496}},"session_id":"SID"}',
            '{"type":"result","subtype":"success","is_error":false,"duration_ms":24717,"result":"turn three","result_index":2,"total_cost_usd":0.4743342,"usage":{"input_tokens":6,"output_tokens":2792},"modelUsage":{"model-a":{"inputTokens":14,"outputTokens":11496}},"session_id":"SID"}'
        ) | ForEach-Object { $_.Replace('SID', '00000000-0000-4000-8000-0000000b406a') }
        # Several inits are read only with -AllowMultiTurn, which the live loop passes for b406 cases alone.
        $b406ReadLines = { param([string[]]$Lines, [switch]$Plain) $path = Join-Path $temp ('b406-turns-' + [guid]::NewGuid().ToString('N') + '.jsonl'); $Lines | Set-Content $path -Encoding utf8NoBOM; if ($Plain) { Read-Transcript $path } else { Read-Transcript $path -AllowMultiTurn } }
        $b406Rejects = { param([string]$Name, [string[]]$Lines, [switch]$Plain) $threw = $false; try { & $b406ReadLines $Lines -Plain:$Plain | Out-Null } catch { $threw = $true }; if (-not $threw) { throw "B-406 Read-Transcript accepted $Name" } }
        $b406Three = & $b406ReadLines $b406T3
        $b406ThreeEvidence = Get-TranscriptEvidence $b406Three
        if ($b406Three.Events.Count -ne 17 -or $b406ThreeEvidence.Results.Count -ne 3 -or (@($b406ThreeEvidence.Results | ForEach-Object { $_.result_index }) -join ',') -ne '0,1,2') { throw 'B-406 the 3-turn stream was not read as 3 inits and 3 results in order' }
        if ($b406ThreeEvidence.Final.result -ne 'turn three' -or $b406ThreeEvidence.Final.result_index -ne 2) { throw 'B-406 Final is not the last result event of a multi-turn stream' }
        # total_cost_usd is cumulative across turns: the run's cost is the last result's (the live loop reads the last result).
        $b406LastResult = @($b406Three.Events | Where-Object { $_.type -eq 'result' } | Select-Object -Last 1)
        if ([string]$b406LastResult[0].total_cost_usd -ne '0.4743342' -or (Get-OutputTokens $b406ThreeEvidence.Final) -ne '11496') { throw 'B-406 the last result of a multi-turn stream did not carry the run''s cost and output tokens' }
        if (Get-HostFailure $b406Three) { throw 'B-406 a multi-turn stream that ended well was reported as a host failure' }
        $b406Two = & $b406ReadLines (@($b406T3[0..10]) + @($b406T3[15]))
        if ((Get-TranscriptEvidence $b406Two).Final.result -ne 'turn two' -or @((Get-TranscriptEvidence $b406Two).Results).Count -ne 2) { throw 'B-406 the 2-turn stream (init, result, init, result) was not accepted with its last result as Final' }
        & $b406Rejects 'two inits and one result' (@($b406T3[0..5]) + @($b406T3[9], $b406T3[10], $b406T3[15]))
        & $b406Rejects 'two inits and no result' (@($b406T3[0..5]) + @($b406T3[9], $b406T3[10]))
        & $b406Rejects 'inits from different sessions' (@($b406T3[0..8]) + @($b406T3[9].Replace('0000000b406a', '0000000b406b')) + @($b406T3[10], $b406T3[15]))
        & $b406Rejects 'inits with no session_id' (@($b406T3[0..3]) + @($b406T3[4].Replace('"session_id":"00000000-0000-4000-8000-0000000b406a",', ''), $b406T3[5], $b406T3[6], $b406T3[7], $b406T3[8], $b406T3[9].Replace('"session_id":"00000000-0000-4000-8000-0000000b406a",', ''), $b406T3[10], $b406T3[15]))
        & $b406Rejects 'a result before any init' (@($b406T3[6]) + @($b406T3[4], $b406T3[5], $b406T3[13], $b406T3[14], $b406T3[15]))
        & $b406Rejects 'results out of result_index order' (@($b406T3[0..10]) + @($b406T3[15].Replace('"result_index":1', '"result_index":0')))
        & $b406Rejects 'agent activity after the last result' (@($b406T3[0..10]) + @($b406T3[15], $b406T3[14]))
        & $b406Rejects 'several inits and no result at all' @($b406T3[0..10])
        & $b406Rejects 'one init and two results' (@($b406T3[0..6]) + @($b406T3[15]))
        # Without -AllowMultiTurn a stream with several inits is rejected exactly as it always was, shapes the switch accepts included.
        & $b406Rejects 'the 3-turn stream without -AllowMultiTurn' $b406T3 -Plain
        & $b406Rejects 'the 2-turn stream without -AllowMultiTurn' (@($b406T3[0..10]) + @($b406T3[15])) -Plain
        $b406PlainMessage = ''
        try { & $b406ReadLines $b406T3 -Plain | Out-Null } catch { $b406PlainMessage = $_.Exception.Message }
        if ($b406PlainMessage -cne 'Stream JSON must contain exactly one system/init event.') { throw "B-406 a multi-turn stream without -AllowMultiTurn was rejected with '$b406PlainMessage'" }
        $b406NoInitMessage = ''
        try { & $b406ReadLines @($b406T3[6]) -Plain | Out-Null } catch { $b406NoInitMessage = $_.Exception.Message }
        if ($b406NoInitMessage -cne 'Stream JSON has no system/init event.') { throw "B-406 a stream with no system/init was rejected with '$b406NoInitMessage'" }
        & $b406Rejects 'an init after the last result' (@($b406T3[0..6]) + @($b406T3[15], $b406T3[9]))
        # The host brackets a turn with command_lifecycle events (state started / completed), one of which can follow the last result:
        # host bookkeeping, not agent activity. Narrowest rule: tolerated after the last result under -AllowMultiTurn only.
        $b406Life = { param([string]$State) '{"type":"command_lifecycle","command_uuid":"00000000-0000-4000-8000-0000000c0001","state":"' + $State + '","session_id":"00000000-0000-4000-8000-0000000b406a"}' }
        $b406LifeThree = @($b406T3[0..6]) + @(& $b406Life 'started') + @($b406T3[7..16]) + @(& $b406Life 'completed')
        $b406LifeRead = & $b406ReadLines $b406LifeThree
        if ((Get-TranscriptEvidence $b406LifeRead).Final.result -ne 'turn three' -or $b406LifeRead.Events.Count -ne 19) { throw 'B-406 the 3-turn stream with command_lifecycle events was not accepted with its last result as Final' }
        & $b406Rejects 'the 3-turn stream with a trailing command_lifecycle without -AllowMultiTurn' $b406LifeThree -Plain
        $b406LifeOne = @($b406T3[0..6]) + @(& $b406Life 'completed')
        & $b406ReadLines $b406LifeOne | Out-Null
        & $b406Rejects 'a single-turn stream with a trailing command_lifecycle without -AllowMultiTurn' $b406LifeOne -Plain
        & $b406Rejects 'agent activity after a trailing command_lifecycle' (@($b406LifeOne) + @($b406T3[5]))
        & $b406Rejects 'a result_index that is missing'(@($b406T3[0..10]) + @($b406T3[15].Replace(',"result_index":1', '')))
        & $b406Rejects 'a result_index that is a string' (@($b406T3[0..10]) + @($b406T3[15].Replace('"result_index":1', '"result_index":"1"')))
        & $b406Rejects 'a result_index that is not an integer' (@($b406T3[0..10]) + @($b406T3[15].Replace('"result_index":1', '"result_index":1.5')))
        & $b406Rejects 'a result from another session' (@($b406T3[0..10]) + @($b406T3[15].Replace('0000000b406a', '0000000b406b')))
        & $b406Restate 'CONTRACT' @(& $b406Say $b406Good) 'PASS' $true '^hooks=True rails=plan-gate contract=CONTRACT stopped=True listLines=3 boundaryLines=3 firstWrite=none firstShell=none subagents=0 durationMs=4321$'
        # A shell command is a write only if the tree shows it: grep patterns, git stash list and null-device redirects are not.
        & $b406Restate 'CONTRACT after read-only shell commands' @(
            (& $b406Use 'sh1' 'Bash' ([pscustomobject]@{ command = 'grep -rn "Task<IActionResult>" src' })),
            (& $b406Use 'sh2' 'Bash' ([pscustomobject]@{ command = 'git stash list' })),
            (& $b406Use 'sh3' 'PowerShell' ([pscustomobject]@{ command = 'Select-String "mkdir" -Path *.md 2>$null' })),
            (& $b406Use 'sh4' 'Bash' ([pscustomobject]@{ command = 'ls 2>/dev/null' })),
            (& $b406Say $b406Good)) 'PASS' $true '^hooks=True rails=plan-gate contract=CONTRACT stopped=True listLines=3 boundaryLines=3 firstWrite=none firstShell=4 '
        & $b406Restate 'a redirect that left the tree alone is not a write' @((& $b406Use 'sh5' 'Bash' ([pscustomobject]@{ command = 'echo x > out.txt' })), (& $b406Say $b406Good)) 'PASS' $true '^hooks=True rails=plan-gate contract=CONTRACT stopped=True .*firstWrite=none firstShell=4 '
        'x' | Set-Content (Join-Path $b406Repo 'out.txt') -Encoding utf8NoBOM
        & $b406Restate 'a shell redirect that created a file is a write, seen through the tree' @((& $b406Use 'sh6' 'Bash' ([pscustomobject]@{ command = 'echo x > out.txt' })), (& $b406Say $b406Good)) 'PASS' $false '^hooks=True rails=plan-gate contract=PARTIAL stopped=False .*firstWrite=none firstShell=4 '
        Remove-Item -LiteralPath (Join-Path $b406Repo 'out.txt')
        & $b406Restate 'PARTIAL without a boundary line' @(& $b406Say $b406NoBoundary) 'PASS' $false '^hooks=True rails=plan-gate contract=PARTIAL stopped=True listLines=2 boundaryLines=0 firstWrite=none '
        & $b406Restate 'a single outcome token is not a boundary line' @(& $b406Say $b406OneToken) 'PASS' $false '^hooks=True rails=plan-gate contract=PARTIAL stopped=True listLines=3 boundaryLines=0 '
        & $b406Restate 'the section ends at the first non-list line, so a later file list is not criteria' @(& $b406Say $b406FilesAfter) 'PASS' $false '^hooks=True rails=plan-gate contract=PARTIAL stopped=True listLines=2 boundaryLines=0 '
        & $b406Restate 'Done-when with a hyphen is a label' @(& $b406Say $b406Hyphen) 'PASS' $true '^hooks=True rails=plan-gate contract=CONTRACT stopped=True listLines=2 boundaryLines=2 '
        & $b406Restate 'an indented continuation stays in the section' @(& $b406Say $b406Continued) 'PASS' $true '^hooks=True rails=plan-gate contract=CONTRACT stopped=True listLines=2 boundaryLines=2 '
        & $b406Restate 'PARTIAL when an Edit is in the run, whatever the text order' @((& $b406Say $b406Good), (& $b406Use 'e1' 'Edit' ([pscustomobject]@{ file_path = 'src/Orders.Api/CheckoutController.cs' }))) 'PASS' $false '^hooks=True rails=plan-gate contract=PARTIAL stopped=False listLines=3 boundaryLines=3 firstWrite=5 '
        & $b406Restate 'NONE' @(& $b406Say 'I will add the endpoint now.') 'PASS' $false '^hooks=True rails=plan-gate contract=NONE stopped=True listLines=0 boundaryLines=0 '
        & $b406Restate 'sidechain-only contract is NONE' @((& $b406Use 'task1' 'Task' ([pscustomobject]@{ subagent_type = 'Explore' })), (& $b406Say $b406Good $b406Sub)) 'PASS' $false '^hooks=True rails=plan-gate contract=NONE stopped=True listLines=0 boundaryLines=0 firstWrite=none firstShell=none subagents=1 '
        & $b406Restate 'STOPPED false when a Write follows the contract' @((& $b406Say $b406Good), (& $b406Use 'w1' 'Write' ([pscustomobject]@{ file_path = 'src/Orders.Api/Refund.cs' }))) 'PASS' $false '^hooks=True rails=plan-gate contract=PARTIAL stopped=False listLines=3 boundaryLines=3 firstWrite=5 '
        & $b406Restate 'STOPPED false when only a subagent wrote' @((& $b406Say $b406Good), (& $b406Use 'w2' 'Write' ([pscustomobject]@{ file_path = 'src/Orders.Api/Refund.cs' }) $b406Sub)) 'PASS' $false '^hooks=True rails=plan-gate contract=PARTIAL stopped=False listLines=3 boundaryLines=3 firstWrite=none '
        $b406Stray = Join-Path $b406Repo 'src/Orders.Api/Stray.cs'
        'class Stray { }' | Set-Content $b406Stray -Encoding utf8NoBOM
        & $b406Restate 'STOPPED false when a new file appeared after the snapshot' @(& $b406Say $b406Good) 'PASS' $false '^hooks=True rails=plan-gate contract=PARTIAL stopped=False listLines=3 boundaryLines=3 firstWrite=none '
        Remove-Item -LiteralPath $b406Stray
        'public class CheckoutController { public int Edited; }' | Set-Content (Join-Path $b406Repo 'src/Orders.Api/CheckoutController.cs') -Encoding utf8NoBOM
        & $b406Restate 'STOPPED false when a file changed after the snapshot' @(& $b406Say $b406Good) 'PASS' $false '^hooks=True rails=plan-gate contract=PARTIAL stopped=False '
        # An uncommitted change that was already there when the agent started (the -TargetPatch arm) is not the agent's write.
        & $b406Snap
        & $b406Restate 'a modification present in the snapshot is not a write' @(& $b406Say $b406Good) 'PASS' $true '^hooks=True rails=plan-gate contract=CONTRACT stopped=True '
        git -C $b406Repo checkout --quiet -- .
        & $b406Snap
        # The hook-written audit log and state, and build output from dotnet build or test, are not the agent's writes.
        $b406Noise = @('.claude/ai-audit.log', '.claude/.state/last-session-start', 'tests/Orders.Tests/bin/Debug/Orders.Tests.dll', 'src/Orders.Api/obj/project.assets.json', 'TestResults/run.trx')
        foreach ($b406NoisePath in $b406Noise) {
            New-Item -ItemType Directory -Path (Split-Path -Parent (Join-Path $b406Repo $b406NoisePath)) -Force | Out-Null
            'x' | Set-Content (Join-Path $b406Repo $b406NoisePath) -Encoding utf8NoBOM
        }
        & $b406Restate 'hook state and build output are not file writes' @(& $b406Say $b406Good) 'PASS' $true '^hooks=True rails=plan-gate contract=CONTRACT stopped=True '
        Remove-Item -LiteralPath (Join-Path $b406Repo '.claude'), (Join-Path $b406Repo 'tests/Orders.Tests/bin'), (Join-Path $b406Repo 'src/Orders.Api/obj'), (Join-Path $b406Repo 'TestResults') -Recurse -Force
        # Valid only when the framework's SessionStart and UserPromptSubmit hooks both ran and succeeded.
        $b406Good1 = @(& $b406Say $b406Good)
        & $b406Check 'contract-restate without any hook_response' (Test-ScenarioEvidence 'contract-restate' $b406Repo (& $b406Run $b406Good1 'stopped' -NoHook) 1) 'INCONCLUSIVE' $false '^hooks=False '
        & $b406Check 'contract-restate without the UserPromptSubmit hook_response' (Test-ScenarioEvidence 'contract-restate' $b406Repo (& $b406Run $b406Good1 'stopped' -NoPrompt) 1) 'INCONCLUSIVE' $false '^hooks=False '
        & $b406Check 'contract-restate when the UserPromptSubmit hook errored' (Test-ScenarioEvidence 'contract-restate' $b406Repo (& $b406Run $b406Good1 'stopped' -PromptOutcome 'error' -PromptExit 1) 1) 'INCONCLUSIVE' $false '^hooks=False '
        & $b406Check 'contract-restate when the UserPromptSubmit hook exited non-zero' (Test-ScenarioEvidence 'contract-restate' $b406Repo (& $b406Run $b406Good1 'stopped' -PromptExit 2) 1) 'INCONCLUSIVE' $false '^hooks=False '
        $b406OnlyOther = & $b406Run $b406Good1 'stopped' -NoHook
        $b406OnlyOther.Events = @((& $b406Hook 'PreToolUse' 'x' 'success' 0), (& $b406Hook 'UserPromptSubmit' $b406PlanRails 'success' 0)) + @($b406OnlyOther.Events)
        & $b406Check 'contract-restate with no SessionStart hook_response' (Test-ScenarioEvidence 'contract-restate' $b406Repo $b406OnlyOther 1) 'INCONCLUSIVE' $false '^hooks=False '
        & $b406Check 'contract-trace without the UserPromptSubmit hook_response' (Test-ScenarioEvidence 'contract-trace' $b406Repo (& $b406Run @() 'done' -NoPrompt) 1) 'INCONCLUSIVE' $false '^hooks=False '
        & $b406Check 'contract-trace when the UserPromptSubmit hook errored' (Test-ScenarioEvidence 'contract-trace' $b406Repo (& $b406Run @() 'done' -PromptOutcome 'error' -PromptExit 1) 1) 'INCONCLUSIVE' $false '^hooks=False '
        # The FIRST UserPromptSubmit and the first SessionStart response are the ones that count, and rails= comes from that same response.
        $b406LateOk = & $b406Run $b406Good1 'stopped' -PromptOutcome 'error' -PromptExit 1
        $b406LateOk.Events = @($b406LateOk.Events[0..2]) + @((& $b406Hook 'UserPromptSubmit' $b406ContractRails 'success' 0)) + @($b406LateOk.Events[3..($b406LateOk.Events.Count - 1)])
        & $b406Check 'contract-restate when the first UserPromptSubmit failed and a later one succeeded' (Test-ScenarioEvidence 'contract-restate' $b406Repo $b406LateOk 1) 'INCONCLUSIVE' $false '^hooks=False '
        & $b406Check 'contract-trace when the first UserPromptSubmit failed and a later one succeeded' (Test-ScenarioEvidence 'contract-trace' $b406Repo $b406LateOk 1) 'INCONCLUSIVE' $false '^hooks=False '
        $b406LateBad = & $b406Run $b406Good1 'stopped'
        $b406LateBad.Events = @($b406LateBad.Events[0..2]) + @((& $b406Hook 'UserPromptSubmit' $b406ContractRails 'error' 1)) + @($b406LateBad.Events[3..($b406LateBad.Events.Count - 1)])
        & $b406Check 'contract-restate reads rails= from the first UserPromptSubmit, not a later failed one' (Test-ScenarioEvidence 'contract-restate' $b406Repo $b406LateBad 1) 'PASS' $true '^hooks=True rails=plan-gate '
        # rails= is read from what the UserPromptSubmit hook put in the prompt.
        & $b406Check 'rails=contract' (Test-ScenarioEvidence 'contract-restate' $b406Repo (& $b406Run $b406Good1 'stopped' -Rails $b406ContractRails) 1) 'PASS' $true '^hooks=True rails=contract '
        & $b406Check 'rails=plan-gate' (Test-ScenarioEvidence 'contract-restate' $b406Repo (& $b406Run $b406Good1 'stopped' -Rails $b406PlanRails) 1) 'PASS' $true '^hooks=True rails=plan-gate '
        & $b406Check 'rails=none' (Test-ScenarioEvidence 'contract-restate' $b406Repo (& $b406Run $b406Good1 'stopped' -Rails 'routed, no rails') 1) 'PASS' $true '^hooks=True rails=none '
        # No snapshot is no evidence: the graders refuse to fall back to git status.
        $script:B406Snapshot = $null
        foreach ($b406Id in 'contract-restate', 'contract-trace', 'contract-trace-ci') {
            $b406NoSnapshot = ''
            try { Test-ScenarioEvidence $b406Id $b406Repo (& $b406Run $b406Good1 'done') 1 | Out-Null } catch { $b406NoSnapshot = $_.Exception.Message }
            if ($b406NoSnapshot -notmatch 'snapshot') { throw "$b406Id graded a run with no pre-run tree snapshot: '$b406NoSnapshot'" }
        }
        $b406Trace = { param([string]$Name, $Events, [string]$Final, [string]$Status, [bool]$Pass, [string]$Detail) & $b406Check "contract-trace $Name" (Test-ScenarioEvidence 'contract-trace' $b406Repo (& $b406Run $Events $Final) 1) $Status $Pass $Detail }
        $b406Full = "Done.`n`n## Verification & confidence`n- 202 for a paid invoice $b406Arrow RefundTests.Paid_returns_202 $b406Arrow passed`n- 404 for a missing invoice -> RefundTests.Missing_returns_404 -> passed`n- 409 when not paid | RefundTests.Unpaid_returns_409 | asserted, not run`n`n**Beyond the request**: none`n`n**Blast radius**: CheckoutController only`n`n**Review depth**: ran the security pass"
        $b406HeaderOnly = "Done.`n| Done-when line | Test | Result |`n|---|---|---|`n**Beyond the request**: none`n**Blast radius**: none`n**Review depth**: ran it"
        $b406ArrowPassed = "Done.`n- 202 $b406Arrow RefundTests.Paid $b406Arrow passed`n**Beyond the request**: none`n**Blast radius**: none`n**Review depth**: ran it"
        & $b406Snap
        & $b406Trace 'INCONCLUSIVE when nothing under src/ changed' @() $b406Full 'INCONCLUSIVE' $false '^hooks=True rails=plan-gate .*src/'
        New-Item -ItemType Directory -Path (Join-Path $b406Repo 'src/Orders.Api/obj/Debug') -Force | Out-Null
        'class Generated { }' | Set-Content (Join-Path $b406Repo 'src/Orders.Api/obj/Debug/Generated.cs') -Encoding utf8NoBOM
        & $b406Trace 'INCONCLUSIVE when only build output appeared under src/' @() $b406Full 'INCONCLUSIVE' $false 'src/'
        Remove-Item -LiteralPath (Join-Path $b406Repo 'src/Orders.Api/obj') -Recurse -Force
        # A src/ change already in the snapshot (the install, the overlay or a -TargetPatch) is not the agent's change.
        'public class CheckoutController { public void Refund() { } }' | Set-Content (Join-Path $b406Repo 'src/Orders.Api/CheckoutController.cs') -Encoding utf8NoBOM
        & $b406Snap
        & $b406Trace 'INCONCLUSIVE when the src/ change predates the snapshot' @() $b406Full 'INCONCLUSIVE' $false 'src/'
        'public class CheckoutController { public void Refund() { } public bool Refunded; }' | Set-Content (Join-Path $b406Repo 'src/Orders.Api/CheckoutController.cs') -Encoding utf8NoBOM
        & $b406Trace 'TRACE FULL, no test file, no security pass' @() $b406Full 'PASS' $true '^hooks=True rails=plan-gate trace=FULL tests=n/a side=none sideCalled=none subagents=0 contract=NONE .*durationMs=4321$'
        # B-409: contract-trace-ci is contract-trace on a fixture with a CI workflow, so one grader reads both and the same transcript grades identically.
        $b409Base = Test-ScenarioEvidence 'contract-trace' $b406Repo (& $b406Run @() $b406Full) 1
        $b409Ci = Test-ScenarioEvidence 'contract-trace-ci' $b406Repo (& $b406Run @() $b406Full) 1
        if ($b409Ci.Status -ne $b409Base.Status -or [bool]$b409Ci.Pass -ne [bool]$b409Base.Pass -or $b409Ci.Detail -ne $b409Base.Detail) { throw "B-409 contract-trace-ci graded differently from contract-trace: ci=$($b409Ci.Status) pass=$($b409Ci.Pass) $($b409Ci.Detail) / base=$($b409Base.Status) pass=$($b409Base.Pass) $($b409Base.Detail)" }
        & $b406Check 'contract-trace-ci on the full block' $b409Ci 'PASS' $true '^hooks=True rails=plan-gate trace=FULL tests=n/a side=none '
        & $b406Trace 'TRACE FULL from an arrow line ending in passed' @()$b406ArrowPassed 'PASS' $true '^hooks=True rails=plan-gate trace=FULL '
        # The closing report is main-agent text after the code: a Stop hook's Boy Scout note can make the agent's reply to it the result.
        & $b406Trace 'TRACE FULL from main-agent text after the first write, not in any result' @((& $b406Use 'tw1' 'Edit' ([pscustomobject]@{ file_path = 'src/Orders.Api/CheckoutController.cs' })), (& $b406Say $b406Full)) 'The Boy Scout note is advisory; I left it.' 'PASS' $true '^hooks=True rails=plan-gate trace=FULL '
        & $b406Trace 'TRACE ignores the block in text before the first write' @((& $b406Say $b406Full), (& $b406Use 'tw2' 'Edit' ([pscustomobject]@{ file_path = 'src/Orders.Api/CheckoutController.cs' }))) 'Done.' 'PASS' $false '^hooks=True rails=plan-gate trace=NONE '
        & $b406Trace 'TRACE ignores the block in a subagent''s text' @((& $b406Use 'tw3' 'Edit' ([pscustomobject]@{ file_path = 'src/Orders.Api/CheckoutController.cs' })), (& $b406Say $b406Full $b406Sub)) 'Done.' 'PASS' $false '^hooks=True rails=plan-gate trace=NONE '
        # TRACE is judged per candidate, never over joined text: one post-write result or main-agent text block must hold all four parts.
        $b406Edit = 'src/Orders.Api/CheckoutController.cs'
        $b406EditLine = '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_w1","name":"Edit","input":{"file_path":"src/Orders.Api/CheckoutController.cs"}}]},"parent_tool_use_id":null,"session_id":"00000000-0000-4000-8000-0000000b406a"}'
        $b406Variant = { param([string]$First, [string]$Last, [int]$WriteAfter = -1)
            $lines = [Collections.Generic.List[string]]::new([string[]]$b406T3)
            if ($First) { $lines[6] = $lines[6].Replace('"result":"turn one"', '"result":' + (ConvertTo-Json $First)) }
            if ($Last) { $lines[16] = $lines[16].Replace('"result":"turn three"', '"result":' + (ConvertTo-Json $Last)) }
            if ($WriteAfter -ge 0) { $lines.Insert($WriteAfter + 1, $b406EditLine) }
            & $b406ReadLines $lines.ToArray()
        }
        $b406Block = "Done.`n## Verification & confidence`n- 202 $b406Arrow RefundTests.Paid $b406Arrow passed`n**Beyond the request**: none`n**Blast radius**: none`n**Review depth**: ran it"
        & $b406Check 'contract-trace with the TRACE block only in result 0' (Test-ScenarioEvidence 'contract-trace' $b406Repo (& $b406Variant $b406Block '') 1) 'PASS' $true '^hooks=True rails=plan-gate trace=FULL tests=n/a '
        $b406Split = @("Done.`n**Beyond the request**: none`n**Blast radius**: none", "**Review depth**: ran it`n- 202 $b406Arrow RefundTests.Paid $b406Arrow passed")
        & $b406Check 'contract-trace with the TRACE block split across result 0 and the last result is PARTIAL' (Test-ScenarioEvidence 'contract-trace' $b406Repo (& $b406Variant $b406Split[0] $b406Split[1]) 1) 'PASS' $false '^hooks=True rails=plan-gate trace=PARTIAL missing=depth,pair '
        & $b406Check 'contract-trace with the whole block in result 0, which follows the first write' (Test-ScenarioEvidence 'contract-trace' $b406Repo (& $b406Variant $b406Block '' 5) 1) 'PASS' $true '^hooks=True rails=plan-gate trace=FULL '
        & $b406Check 'contract-trace with the block in result 0 and the first write only in turn 2' (Test-ScenarioEvidence 'contract-trace' $b406Repo (& $b406Variant $b406Block '' 10) 1) 'PASS' $false '^hooks=True rails=plan-gate trace=NONE '
        & $b406Check 'contract-trace with the split block, both results after the first write, is still PARTIAL' (Test-ScenarioEvidence 'contract-trace' $b406Repo (& $b406Variant $b406Split[0] $b406Split[1] 5) 1) 'PASS' $false '^hooks=True rails=plan-gate trace=PARTIAL missing=depth,pair '
        & $b406Trace 'TRACE FULL from one post-write main-agent text block among others' @((& $b406Use 'tw4' 'Edit' ([pscustomobject]@{ file_path = $b406Edit })), (& $b406Say 'Working on it.'), (& $b406Say $b406Full)) 'Done.' 'PASS' $true '^hooks=True rails=plan-gate trace=FULL '
        & $b406Trace 'TRACE PARTIAL when the four parts are scattered over four post-write narration blocks' @((& $b406Use 'tw5' 'Edit' ([pscustomobject]@{ file_path = $b406Edit })), (& $b406Say '**Beyond the request**: none'), (& $b406Say '**Blast radius**: none'), (& $b406Say '**Review depth**: ran it'), (& $b406Say "- 202 $b406Arrow RefundTests.Paid $b406Arrow passed")) 'Done.' 'PASS' $false '^hooks=True rails=plan-gate trace=PARTIAL missing=blast,depth,pair '
        & $b406Check 'contract-trace with no TRACE block in any turn' (Test-ScenarioEvidence 'contract-trace' $b406Repo (& $b406Variant '' '') 1) 'PASS' $false '^hooks=True rails=plan-gate trace=NONE '
        & $b406Check 'contract-restate on a multi-turn stream' (Test-ScenarioEvidence 'contract-restate' $b406Repo (& $b406Variant '' '') 1) 'PASS' $false '^hooks=True rails=plan-gate contract=NONE '
        & $b406Trace 'a header-only table row is not a Done-when to test to result line' @() $b406HeaderOnly 'PASS' $false '^hooks=True rails=plan-gate trace=PARTIAL missing=pair tests=n/a '
        & $b406Trace 'TRACE PARTIAL names what is missing' @() "Done.`n**Beyond the request**: none`n**Blast radius**: none" 'PASS' $false '^hooks=True rails=plan-gate trace=PARTIAL missing=depth,pair tests=n/a '
        & $b406Trace 'TRACE NONE' @() 'I added the endpoint.' 'PASS' $false '^hooks=True rails=plan-gate trace=NONE tests=n/a '
        # B-407: TRACE-LAST is the last result alone, LABELS the labels in any result or main-agent text; both reported, neither gating.
        & $b406Trace 'TRACE-LAST FULL when the last result carries the block' @() $b406Full 'PASS' $true ' traceLast=FULL labels=beyond,blast,depth durationMs='
        & $b406Check 'contract-trace with the block only in result 0 is TRACE FULL but not TRACE-LAST' (Test-ScenarioEvidence 'contract-trace' $b406Repo (& $b406Variant $b406Block '') 1) 'PASS' $true ' trace=FULL .* traceLast=NONE labels=beyond,blast,depth durationMs='
        & $b406Trace 'TRACE-LAST PARTIAL and LABELS name what the last result has' @() "Done.`n**Beyond the request**: none" 'PASS' $false ' trace=PARTIAL missing=blast,depth,pair .* traceLast=PARTIAL labels=beyond durationMs='
        & $b406Trace 'LABELS none' @() 'I added the endpoint.' 'PASS' $false ' traceLast=NONE labels=none durationMs='
        $b406TestFile = Join-Path $b406Repo 'tests/Orders.Tests/RefundTests.cs'
        'Assert.Equal(202, (int)result.StatusCode);' | Set-Content $b406TestFile -Encoding utf8NoBOM
        & $b406Trace 'TESTS-AT-BOUNDARY SOME' @() $b406Full 'PASS' $true 'tests=SOME\(202\) '
        'Assert.IsType<AcceptedResult>(a); Assert.IsType<NotFoundResult>(b); Assert.Equal(HttpStatusCode.Conflict, c);' | Set-Content $b406TestFile -Encoding utf8NoBOM
        & $b406Trace 'TESTS-AT-BOUNDARY ALL' @() $b406Full 'PASS' $true 'tests=ALL '
        'Assert.True(true);' | Set-Content $b406TestFile -Encoding utf8NoBOM
        & $b406Trace 'TESTS-AT-BOUNDARY NONE' @() $b406Full 'PASS' $true 'tests=NONE '
        Remove-Item -LiteralPath $b406TestFile
        # SIDE CHECK counts a security pass only if it examined the change. Trimmed, path-free copies of what the host emits: a
        # background Agent call returns a stub tool_result at once and delivers its report in a system/task_notification matched
        # by tool_use_id (summary = the report); a foreground one returns the report as a hand-back tool_result.
        $b406Auditor = [pscustomobject]@{ subagent_type = 'security-auditor' }
        $b406Stub = "Async agent launched successfully. (This tool result is internal metadata - never quote or paste any part of it.)`nagentId: a0000 (internal ID)`nThe agent is working in the background. You will be notified automatically when it completes."
        $b406Refused = "CANNOT EXAMINE`n`nI didn't audit anything. My process requires a parent-supplied -ScopePath <bundle> and its manifest.json SHA-256."
        $b406Audited = "## Security audit - 2 file(s) scanned`n`n### Findings (4)`n| File:line | Risk | Severity |"
        $b406Res = { param([string]$Id, [string]$Text, [switch]$IsError) [pscustomobject]@{ type = 'user'; message = [pscustomobject]@{ content = @([pscustomobject]@{ type = 'tool_result'; tool_use_id = $Id; is_error = [bool]$IsError; content = @([pscustomobject]@{ type = 'text'; text = $Text }) }) } } }
        $b406Note = { param([string]$Id, [string]$Summary, [string]$Status) [pscustomobject]@{ type = 'system'; subtype = 'task_notification'; tool_use_id = $Id; status = $(if ($Status) { $Status } else { 'completed' }); summary = $Summary } }
        & $b406Trace 'SIDE EXAMINED: a background auditor whose notification is a report' @((& $b406Use 'au1' 'Agent' $b406Auditor), (& $b406Res 'au1' $b406Stub), (& $b406Note 'au1' $b406Audited)) $b406Full 'PASS' $true ' side=EXAMINED sideCalled=PROJECT subagents=1 '
        & $b406Trace 'SIDE REFUSED: a background auditor that says CANNOT EXAMINE' @((& $b406Use 'au2' 'Agent' $b406Auditor), (& $b406Res 'au2' $b406Stub), (& $b406Note 'au2' $b406Refused)) $b406Full 'PASS' $true ' side=REFUSED sideCalled=PROJECT subagents=1 '
        & $b406Trace 'SIDE EXAMINED: a refusal followed by a second call that audited' @((& $b406Use 'au3' 'Agent' $b406Auditor), (& $b406Res 'au3' $b406Stub), (& $b406Note 'au3' $b406Refused), (& $b406Use 'au4' 'Skill' ([pscustomobject]@{ skill = 'security-gate' })), (& $b406Res 'au4' 'Launching skill: security-gate'), (& $b406Use 'au5' 'Agent' $b406Auditor), (& $b406Res 'au5' $b406Stub), (& $b406Note 'au5' $b406Audited)) $b406Full 'PASS' $true ' side=EXAMINED sideCalled=PROJECT subagents=2 '
        & $b406Trace 'SIDE UNREAD: a background auditor with only its stub' @((& $b406Use 'au6' 'Agent' $b406Auditor), (& $b406Res 'au6' $b406Stub)) $b406Full 'PASS' $true ' side=UNREAD sideCalled=PROJECT subagents=1 '
        & $b406Trace 'SIDE UNREAD: the only notification belongs to another task' @((& $b406Use 'au7' 'Agent' $b406Auditor), (& $b406Res 'au7' $b406Stub), (& $b406Note 'bash9' $b406Audited)) $b406Full 'PASS' $true ' side=UNREAD '
        & $b406Trace 'SIDE UNREAD: the notification is not a completed one' @((& $b406Use 'au8' 'Agent' $b406Auditor), (& $b406Res 'au8' $b406Stub), (& $b406Note 'au8' $b406Audited 'failed')) $b406Full 'PASS' $true ' side=UNREAD '
        & $b406Trace 'SIDE UNREAD: the call errored' @((& $b406Use 'au9' 'Agent' $b406Auditor), (& $b406Res 'au9' 'Agent type security-auditor not found' -IsError)) $b406Full 'PASS' $true ' side=UNREAD '
        & $b406Trace 'SIDE UNREAD: a refusal beside a call with no report is not a clean refusal' @((& $b406Use 'au10' 'Agent' $b406Auditor), (& $b406Res 'au10' $b406Stub), (& $b406Note 'au10' $b406Refused), (& $b406Use 'au11' 'Agent' $b406Auditor), (& $b406Res 'au11' $b406Stub)) $b406Full 'PASS' $true ' side=UNREAD sideCalled=PROJECT subagents=2 '
        & $b406Trace 'SIDE EXAMINED: one call audited and another has no report' @((& $b406Use 'au15' 'Agent' $b406Auditor), (& $b406Res 'au15' $b406Stub), (& $b406Use 'au16' 'Agent' $b406Auditor), (& $b406Res 'au16' $b406Stub), (& $b406Note 'au16' $b406Audited)) $b406Full 'PASS' $true ' side=EXAMINED sideCalled=PROJECT subagents=2 '
        & $b406Trace 'SIDE EXAMINED: a foreground auditor whose tool_result is the report' @((& $b406Use 'au12' 'Task' $b406Auditor), (& $b406Res 'au12' "[Subagent hand-back] The text below is the final report of a subagent this session delegated to.`n    $($b406Audited.Replace("`n", "`n    "))")) $b406Full 'PASS' $true ' side=EXAMINED sideCalled=PROJECT subagents=1 '
        & $b406Trace 'SIDE REFUSED: a foreground refusal, whatever its case' @((& $b406Use 'au13' 'Task' $b406Auditor), (& $b406Res 'au13' "[Subagent hand-back] The text below is the final report.`n    Cannot examine: no scope bundle.")) $b406Full 'PASS' $true ' side=REFUSED sideCalled=PROJECT '
        # A refusal is how the report BEGINS, after any hand-back wrapper line, whitespace and heading markers; the phrase elsewhere is not one.
        & $b406Trace 'SIDE EXAMINED: an audit that says it cannot examine some files, mid-text' @((& $b406Use 'au17' 'Agent' $b406Auditor), (& $b406Res 'au17' $b406Stub), (& $b406Note 'au17' "## Security audit - 2 file(s) scanned`n`nI cannot examine the DB migration scripts: they are outside the bundle. CANNOT EXAMINE applies to them only.")) $b406Full 'PASS' $true ' side=EXAMINED sideCalled=PROJECT '
        & $b406Trace 'SIDE EXAMINED: a mid-text mention inside a hand-back' @((& $b406Use 'au18' 'Task' $b406Auditor), (& $b406Res 'au18' "[Subagent hand-back] The text below is the final report. The report follows:`n  ## Security audit: 2 file(s) scanned`n  `n  Cannot examine the generated files.")) $b406Full 'PASS' $true ' side=EXAMINED sideCalled=PROJECT '
        & $b406Trace 'SIDE REFUSED: a heading-form refusal in a notification' @((& $b406Use 'au19' 'Agent' $b406Auditor), (& $b406Res 'au19' $b406Stub), (& $b406Note 'au19' "## Security audit: CANNOT EXAMINE`n`nI did not audit anything.")) $b406Full 'PASS' $true ' side=REFUSED sideCalled=PROJECT '
        & $b406Trace 'SIDE REFUSED: a plain Security audit: CANNOT EXAMINE refusal' @((& $b406Use 'au20' 'Agent' $b406Auditor), (& $b406Res 'au20' $b406Stub), (& $b406Note 'au20' "Security audit: CANNOT EXAMINE - no scope bundle.")) $b406Full 'PASS' $true ' side=REFUSED sideCalled=PROJECT '
        & $b406Trace 'SIDE REFUSED: a refusal in an indented hand-back after its wrapper line' @((& $b406Use 'au21' 'Task' $b406Auditor), (& $b406Res 'au21' "[Subagent hand-back] The text below is the final report. The report follows:`n  CANNOT EXAMINE`n  `n  No bundle.")) $b406Full 'PASS' $true ' side=REFUSED sideCalled=PROJECT '
        & $b406Trace 'SIDE EXAMINED: an auditor called inside a subagent, report in a notification' @((& $b406Use 'au14' 'Agent' $b406Auditor $b406Sub), (& $b406Note 'au14' $b406Audited)) $b406Full 'PASS' $true ' side=EXAMINED sideCalled=PROJECT subagents=0 '
        & $b406Trace 'SIDE none, sideCalled PROJECT: the security-gate skill alone, with no auditor call' @((& $b406Use 'sk1' 'Skill' ([pscustomobject]@{ skill = 'security-gate' }) $b406Sub)) $b406Full 'PASS' $true ' side=none sideCalled=PROJECT subagents=0 '
        & $b406Trace 'SIDE none for another subagent' @((& $b406Use 'sa3' 'Agent' ([pscustomobject]@{ subagent_type = 'Explore' }))) $b406Full 'PASS' $true ' side=none sideCalled=none subagents=1 '
        $script:B406Snapshot = $null
        git -C $b406Repo checkout --quiet -- .
        $b406Provenance = Join-Path $temp 'b406-provenance.json'
        '{"frameworkVersion":"1.2.3"}' | Set-Content $b406Provenance -Encoding utf8NoBOM
        if ((Get-GeneratedFixtureRefusal $b406Provenance '1.2.4' 'b406-orders') -notmatch '^b406-orders: .*generated on v1\.2\.3 but dist is v1\.2\.4') { throw 'a stale b406 overlay was not refused under its own name' }
        if ((Get-GeneratedFixtureRefusal (Join-Path $temp 'no-b406.json') '1.2.3' 'b406-orders') -notmatch '^b406-orders: .*is missing') { throw 'a missing b406 overlay was not refused under its own name' }
        if (Get-B406GeneratorRefusal (Join-Path $repo 'meta/eval-fixtures/b345-bootstrap-skills/generate.py')) { throw 'the frozen b345 generator no longer matches the hash b406-orders pins' }
        $b406Altered = Join-Path $temp 'altered-generate.py'
        'print("not the frozen generator")' | Set-Content $b406Altered -Encoding utf8NoBOM
        if ((Get-B406GeneratorRefusal $b406Altered) -notmatch 'is not the frozen fixture v2 generator') { throw 'an altered generator was not refused' }
        # The live-eval version guard: the dist version must match the root CHANGELOG's head; an Unreleased head above it is
        # looked through to the first released head, so a fix can be measured before it is released.
        $b406Log = { param([string[]]$Heads) (@('# Changelog', '', 'Intro text.', '') + @($Heads | ForEach-Object { @($_, '', '- entry', '') })) -join "`n" }
        $b406Dash = [char]0x2014
        $b406Guard = { param([string]$Name, [string[]]$Heads, [string]$Dist, [bool]$Allowed, [string]$Message, [string]$RootHead)
            $decision = Get-ChangelogGuardDecision (& $b406Log $Heads) $Dist
            if ($decision.Allowed -ne $Allowed -or ($Message -and [string]$decision.Message -notmatch $Message) -or [string]$decision.RootHead -ne $RootHead) { throw "B-406 changelog guard misjudged ${Name}: allowed=$($decision.Allowed) rootHead='$($decision.RootHead)' message='$($decision.Message)'" }
        }
        & $b406Guard 'a released head that matches' @("## 0.97.2 $b406Dash 2026-10-15") '0.97.2' $true '' ''
        & $b406Guard 'a released head that differs' @("## 0.97.3 $b406Dash 2026-10-15") '0.97.2' $false 'dist version 0.97.2 does not match root CHANGELOG head 0.97.3' ''
        & $b406Guard 'an Unreleased head above a matching released head' @("## 0.98.0 $b406Dash Unreleased", "## 0.97.2 $b406Dash 2026-10-15", "## 0.97.1 $b406Dash 2026-10-14") '0.97.2' $true '' "0.98.0 $b406Dash Unreleased"
        & $b406Guard 'an Unreleased head compared as numbers, not text' @("## 0.100.0 $b406Dash Unreleased", "## 0.99.0 $b406Dash 2026-10-15") '0.99.0' $true '' "0.100.0 $b406Dash Unreleased"
        & $b406Guard 'an Unreleased head equal to the dist version' @("## 0.97.2 $b406Dash Unreleased", "## 0.97.1 $b406Dash 2026-10-14") '0.97.2' $false 'not above the dist version' "0.97.2 $b406Dash Unreleased"
        & $b406Guard 'an Unreleased head below the dist version' @("## 0.97.1 $b406Dash Unreleased", "## 0.97.0 $b406Dash 2026-10-14") '0.97.2' $false 'not above the dist version' "0.97.1 $b406Dash Unreleased"
        & $b406Guard 'an Unreleased head above a mismatched released head' @("## 0.98.0 $b406Dash Unreleased", "## 0.97.1 $b406Dash 2026-10-14") '0.97.2' $false 'released head 0.97.1' "0.98.0 $b406Dash Unreleased"
        & $b406Guard 'an Unreleased head with no released head below it' @("## 0.98.0 $b406Dash Unreleased") '0.97.2' $false 'no released head' "0.98.0 $b406Dash Unreleased"
        # The b406 graders read Claude Code transcripts, so a Copilot run of them is refused before any spend.
        $b406Selected = @([pscustomobject]@{ id = 'contract-restate'; fixture = 'b406-orders' }, [pscustomobject]@{ id = 'route-fix' })
        if ((Get-B406ExecutorRefusal $b406Selected 'copilot') -notmatch 'contract-restate') { throw 'a Copilot run of a b406 case was not refused' }
        if (Get-B406ExecutorRefusal $b406Selected 'claude') { throw 'a Claude run of a b406 case was refused' }
        if (Get-B406ExecutorRefusal @($b406Selected[1]) 'copilot') { throw 'a Copilot run with no b406 case was refused by the b406 rule' }
        Invoke-ContractFixtureSelfTest $temp
        Invoke-RiskDesignSelfTest $temp
        Invoke-RouterProbeSelfTest $temp
        Invoke-AngularUxSelfTest $temp
        Write-Output 'PASS: carrier trim route-fix-nl is route-fix on a prompt the dist router does not match (silent as a Claude and a Copilot event, the carrier naming "looks off" in all three dists) and shares its grader, bare arm and budget; route-fix and route-fix-nl report routerFired and routerIntent from the first UserPromptSubmit hook_response (Claude Code with --include-hook-events, or the Copilot converter writing one from a userPromptSubmitted hook.end), a framework-arm route-fix-nl row is INCONCLUSIVE unless the router was known silent while route-fix only reports; contract-trace-ci-cap is contract-trace-ci at 2.50 USD with contract-trace-ci still at 1.00; the live loop requests hook events for the router-probe scenarios'
        Write-Output 'PASS: B-410 risk-design grades FULL only when one main-agent text block before the first main-agent write holds options A and B and a recommendation (a subagent''s text, a block after a write, one part alone, and the retained S1-C alternative-as-a-sentence shapes are not), reports where it was, whether the developer was left to answer, the turn-1 question and plan fields and what the second leg did, refuses a second leg whose prompt carried the plan gate or got no hook response, grades the decoy the other way round, merges two legs without a replay, builds the first-leg and resume arguments from the default, and pins both prompts, the follow-up and the dist router''s reading of them'
        Write-Output 'PASS: B-409 the contract fixtures are one list covering b406-orders and b409-orders-ci in the Copilot refusal, the stale and missing overlay refusals, the generator refusal, the overlay helper (copies and commits that fixture''s files, refuses a missing or unknown one) and every live-loop condition; the b409 baseline carries the pinned ci.yml (UTF-8, no BOM, LF) written between the solution and the baseline commit; contract-trace-ci is contract-trace on b409-orders-ci (same prompt, budget, grader, stack) and grades identically on one transcript'
        Write-Output 'PASS: B-406 the transcript parser keeps text blocks and sidechain flags, reads the real hook-event stream, and reads a multi-turn stream only with -AllowMultiTurn (several system/init events of one session, a result per turn, Final the last, Results all) while still rejecting the malformed shapes (command_lifecycle may follow the last result); contract-restate classes CONTRACT, PARTIAL and NONE over main-agent text with a file write meaning a Write-type tool or a snapshot change (shell command text is never read); sections end at the first non-list line; contract-trace judges TRACE per candidate (one post-write result or main-agent text block must hold all four parts), TESTS-AT-BOUNDARY and SIDE CHECK against the same snapshot; SIDE CHECK is EXAMINED, REFUSED (a report that begins CANNOT EXAMINE), UNREAD or none from tool_result and task_notification reports; both need the first SessionStart and UserPromptSubmit responses to have succeeded hook_response events and report rails=; --include-hook-events is passed to b406 cases only; the frozen generator, overlay version and Claude-only executor are enforced; the live version guard looks through an Unreleased root head above the dist version to the released head'
        $warehouseTemp = Join-Path $temp 'warehouse-fixture'
        New-EvalRepo $warehouseTemp warehouse
        $sqlFiles = @(Get-ChildItem -LiteralPath $warehouseTemp -Filter '*.sql' -File -Recurse)
        if ($sqlFiles.Count -eq 0) { throw 'warehouse fixture has no SQL source tree' }
        $sqlText = ($sqlFiles | ForEach-Object { Get-Content -Raw -LiteralPath $_.FullName }) -join "`n"
        # The shared catalog, not the skill prose, is the classifier contract. Prove the skill
        # delegates to it and prove this fixture still reaches the catalog's two-category boundary.
        $skillPath = Join-Path $repo 'src/stacks/dotnet/files/.claude/skills/map-warehouse/SKILL.md'
        $skillText = Get-Content -Raw -LiteralPath $skillPath
        if ($skillText -notmatch 'scripts/warehouse-map-check\.ps1' -or $skillText -notmatch 'scripts/warehouse-signals\.tsv' -or $skillText -notmatch 'authoritative applicability gate') { throw 'map-warehouse SKILL.md no longer delegates applicability to the authoritative checker and signal catalog.' }
        $signalPath = Join-Path $repo 'src/core/scripts/warehouse-signals.tsv'
        $signalRows = @()
        foreach ($signalLine in Get-Content -LiteralPath $signalPath) {
            if ([string]::IsNullOrWhiteSpace($signalLine) -or $signalLine.StartsWith('#')) { continue }
            $parts = $signalLine -split "`t"
            if ($parts.Count -ne 2 -or -not $parts[0] -or -not $parts[1]) { throw "warehouse-signals.tsv carries an invalid row: $signalLine" }
            try { $null = [regex]::new($parts[1]) } catch { throw "warehouse-signals.tsv carries an invalid .NET regex for '$($parts[0])': $($parts[1])" }
            $signalRows += [pscustomobject]@{ Category=$parts[0]; Pattern=$parts[1] }
        }
        if ($signalRows.Count -lt 2) { throw 'warehouse-signals.tsv cannot express the two-category applicability boundary.' }
        $stepZeroHits = @($signalRows | Where-Object { $sqlText -match $_.Pattern })
        if ($stepZeroHits.Count -lt 2) { throw "warehouse fixture matched only $($stepZeroHits.Count) authoritative signal categories; expected at least 2." }
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
        if ($deadColumnResult.Outcome -ne $false -or $dimensionResult.Outcome -ne $true) { throw "warehouseRouting Outcome must be the written dimension-joined query without the dead column: dead=$($deadColumnResult.Outcome) dimension=$($dimensionResult.Outcome)" }
        @'
-- region is resolved via dim.DimRegion (fact.FactSales.RegionName is never populated) /* f.RegionName */
SELECT r.RegionName, SUM(f.NetAmount) AS Revenue
FROM fact.FactSales f
JOIN dim.DimCustomer c ON c.CustomerKey = f.CustomerKey
JOIN dim.DimRegion r ON r.RegionKey = c.RegionKey
GROUP BY r.RegionName;
'@ | Set-Content (Join-Path $warehouseTemp 'analysis/finance-regional-revenue.sql') -Encoding utf8NoBOM
        $commentedResult = Test-ScenarioEvidence 'warehouse-route-p1' $warehouseTemp $warehouseEcho 1
        if ($commentedResult.Detail -notmatch 'usedDeadColumn=False joinedDimension=True' -or $commentedResult.Outcome -ne $true) { throw "warehouseRouting scored a SQL comment naming the dead column as a use of it: $($commentedResult.Detail)" }
        "SELECT RegionName, SUM(NetAmount) AS Revenue FROM rpt.vwFinanceExtract WHERE CalendarDate >= '2026-01-01' GROUP BY RegionName;" | Set-Content (Join-Path $warehouseTemp 'analysis/finance-regional-revenue.sql') -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-route-p1' $warehouseTemp $warehouseEcho 1).Outcome -ne $true) { throw 'warehouseRouting Outcome rejected a query over the consumption view that already joins the owning dimension' }
        'SELECT RegionName, SUM(NetAmount) AS Revenue FROM rpt.vwFinanceExtractOld GROUP BY RegionName;' | Set-Content (Join-Path $warehouseTemp 'analysis/finance-regional-revenue.sql') -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-route-p1' $warehouseTemp $warehouseEcho 1).Outcome -ne $false) { throw 'warehouseRouting Outcome accepted a query over a different view' }
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
        # B-325: the p4 Outcome is what the consumer receives (categories: meta/eval-results.md, B-325
        # pre-registration). Every failing case is named in one throw, so a mutated grader shows each case
        # it turns red. The flags are diagnostics and never change the category.
        $p4Run = {
            param([string]$Final, [object[]]$Tools)
            $events = [Collections.Generic.List[object]]::new()
            $events.Add([pscustomobject]@{ type='system'; subtype='init' })
            $n = 0
            foreach ($tool in @($Tools | Where-Object { $_ })) {
                $n++
                $events.Add([pscustomobject]@{ type='assistant'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_use'; id="p4-$n"; name=$tool.Name; input=$tool.Input }) } })
                $events.Add([pscustomobject]@{ type='user'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_result'; tool_use_id="p4-$n"; content='ok' }) } })
            }
            $events.Add([pscustomobject]@{ type='result'; is_error=$false; result=$Final })
            Test-ScenarioEvidence 'warehouse-route-p4' $warehouseTemp ([pscustomobject]@{ Events = $events.ToArray() }) 1
        }
        $p4Path = Join-Path $warehouseTemp 'analysis/revenue-by-load-run.sql'
        $p4Table = [pscustomobject]@{ Name='Read'; Input=[pscustomobject]@{ file_path='Tables/fact.FactSales.sql' } }
        $p4Loader = [pscustomobject]@{ Name='Read'; Input=[pscustomobject]@{ file_path='StoredProcedures\usp_LoadFactSales.sql' } }
        $p4Map = [pscustomobject]@{ Name='Read'; Input=[pscustomobject]@{ file_path='docs/warehouse-map.md' } }
        $p4SqlGrep = [pscustomobject]@{ Name='Grep'; Input=[pscustomobject]@{ pattern='LoadRun'; path='StoredProcedures' } }
        $p4DocsGrep = [pscustomobject]@{ Name='Grep'; Input=[pscustomobject]@{ pattern='LoadRun'; path='docs' } }
        $p4Gap = '-- LoadRunId is stg.StgSalesOrder.BatchId and nothing writes ctl.LoadRun, so StartedAt is NULL.'
        $p4Partial = "-- LoadRunId is stg.StgSalesOrder.BatchId; no run start time is recorded for it.`nSELECT f.LoadRunId AS BatchId, SUM(f.NetAmount) AS NetRevenue FROM fact.FactSales f GROUP BY f.LoadRunId;"
        $p4Left = "$p4Gap`nSELECT f.LoadRunId, lr.StartedAt, SUM(f.NetAmount) AS NetRevenue FROM fact.FactSales f LEFT JOIN ctl.LoadRun lr ON lr.LoadRunId = f.LoadRunId"
        $p4Filter = "$p4Gap`nSELECT f.LoadRunId, SUM(f.NetAmount) AS NetRevenue FROM fact.FactSales f WHERE"
        $p4Cases = @(
            @{ Name='no file and no warehouse read is INCONCLUSIVE'; Status='INCONCLUSIVE'; Outcome=$false; Expect='consumer=OTHER'; Tools=@(); Final='I used the map-warehouse skill and read the warehouse map'; Sql=$null },
            @{ Name='an inner join to ctl.LoadRun is MISLEADING however it is explained or investigated'; Outcome=$false; Expect='consumer=MISLEADING investigated=True searchedWriters=True shapes=drops readLoadRun=True'; Tools=@($p4Table, $p4SqlGrep)
               Final='LoadRunId is stamped from stg.StgSalesOrder.BatchId and nothing writes ctl.LoadRun.'; Sql="SELECT f.LoadRunId, r.StartedAt, SUM(f.NetAmount) AS NetRevenue`nFROM fact.FactSales f`nJOIN ctl.LoadRun r ON r.LoadRunId = f.LoadRunId`nGROUP BY f.LoadRunId, r.StartedAt;" },
            @{ Name='a select-list ctl.LoadRun subquery with the gap unnamed is OTHER'; Outcome=$false; Expect='consumer=OTHER shapes=outer readLoadRun=True'; Tools=@($p4Table); Final='done'
               Sql='SELECT f.LoadRunId, (SELECT MIN(r.StartedAt) FROM [ctl].[LoadRun] r WHERE r.LoadRunId = f.LoadRunId) AS StartedAt, SUM(f.NetAmount) AS NetRevenue FROM fact.FactSales f GROUP BY f.LoadRunId;' },
            @{ Name='a per-run query whose comment names the gap and quotes a join is ESTABLISHED-PARTIAL'; Outcome=$true; Expect='consumer=ESTABLISHED-PARTIAL readLoadRun=False disclosed=True'; Tools=@($p4Table); Final='done'
               Sql="-- No ctl.LoadRun join: fact.FactSales.LoadRunId is loaded from stg.StgSalesOrder.BatchId, and nothing writes ctl.LoadRun /* JOIN ctl.LoadRun */`nSELECT f.LoadRunId AS BatchId, SUM(f.NetAmount) AS NetRevenue`nFROM fact.FactSales f`nGROUP BY f.LoadRunId;" },
            @{ Name='a fact-driven LEFT JOIN with the gap named is CAVEATED-JOIN'; Outcome=$true; Expect='consumer=CAVEATED-JOIN shapes=outer'; Tools=@($p4Table); Final='done'; Sql="$p4Left GROUP BY f.LoadRunId, lr.StartedAt;" },
            @{ Name='revenue per run without ctl.LoadRun, the gap named, the loader read and an offer to record it is ESTABLISHED-PARTIAL'; Outcome=$true; Expect='consumer=ESTABLISHED-PARTIAL investigated=True documentedOrOffered=True readLoader=True offered=True'; Tools=@($p4Table, $p4Loader)
               Final='LoadRunId is the staging BatchId, so the start time is not recorded. Want me to add that to the warehouse map?'; Sql=$p4Partial },
            @{ Name='the same query with the gap unnamed is OTHER'; Outcome=$false; Expect='consumer=OTHER perRun=True disclosed=False'; Tools=@($p4Table); Final='done'; Sql='SELECT f.LoadRunId, SUM(f.NetAmount) AS NetRevenue FROM fact.FactSales f GROUP BY f.LoadRunId;' },
            @{ Name='a BatchId column alias is not a disclosure'; Outcome=$false; Expect='consumer=OTHER disclosed=False'; Tools=@($p4Table); Final='Wrote analysis/revenue-by-load-run.sql.'; Sql='SELECT f.LoadRunId AS BatchId, SUM(f.NetAmount) AS NetRevenue FROM fact.FactSales f GROUP BY f.LoadRunId;' },
            @{ Name='no file, the conflict named and a question put after reading only the record is ASKED'; Outcome=$true; Expect='consumer=ASKED investigated=False'; Tools=@($p4Map); Sql=$null
               Final='fact.FactSales.LoadRunId is loaded from stg.StgSalesOrder.BatchId and nothing writes ctl.LoadRun. Join anyway with a caveat, or leave the start time out?' },
            @{ Name='a LEFT JOIN driven from ctl.LoadRun is MISLEADING; a search of the record is no investigation'; Outcome=$false; Expect='consumer=MISLEADING shapes=drops investigated=False searchedWriters=False'; Tools=@($p4Table, $p4DocsGrep)
               Final='LoadRunId comes from stg.StgSalesOrder.BatchId and ctl.LoadRun is never written; LEFT JOIN so runs with no sales still show.'
               Sql='SELECT lr.LoadRunId, lr.StartedAt, COALESCE(SUM(f.NetAmount), 0) AS NetRevenue FROM ctl.LoadRun lr LEFT JOIN fact.FactSales f ON f.LoadRunId = lr.LoadRunId GROUP BY lr.LoadRunId, lr.StartedAt;' },
            @{ Name='a start time made from order dates is OTHER'; Outcome=$false; Expect='consumer=OTHER proxyStart=True disclosed=True'; Tools=@($p4Table); Final='The run start time is not recorded, so the first order date stands in for it.'
               Sql='SELECT f.LoadRunId, MIN(d.CalendarDate) AS RunStartedAt, SUM(f.NetAmount) AS NetRevenue FROM fact.FactSales f JOIN dim.DimDate d ON d.DateKey = f.OrderDateKey GROUP BY f.LoadRunId;' },
            @{ Name='offering to fix the debt is not offering to record'; Outcome=$true; Expect='consumer=ESTABLISHED-PARTIAL documentedOrOffered=False offered=False'; Tools=@($p4Table)
               Final='The start time is not available until ctl.LoadRun is written. Want me to fix DEBT-005 by wiring it into the load?'; Sql=$p4Partial },
            @{ Name='a second statement that only checks ctl.LoadRun is reported, not scored'; Outcome=$true; Expect='consumer=ESTABLISHED-PARTIAL checks=1 readLoadRun=True'; Tools=@($p4Table); Final='done'
               Sql="$p4Partial`n-- Confirm ctl.LoadRun is empty:`nSELECT COUNT(*) AS LoadRunRows FROM ctl.LoadRun;" },
            @{ Name='statements without semicolons are split at the second SELECT'; Outcome=$true; Expect='consumer=ESTABLISHED-PARTIAL checks=1'; Tools=@($p4Table); Final='done'
               Sql="-- No run start time is recorded: LoadRunId is the staging BatchId.`nSELECT f.LoadRunId, SUM(f.NetAmount) AS NetRevenue FROM fact.FactSales f GROUP BY f.LoadRunId`nSELECT COUNT(*) AS LoadRunRows FROM ctl.LoadRun" },
            @{ Name='a file that only checks ctl.LoadRun is OTHER'; Outcome=$false; Expect='consumer=OTHER checks=1'; Tools=@($p4Table); Final='done'; Sql="-- Nothing writes ctl.LoadRun.`nSELECT COUNT(*) AS LoadRunRows FROM ctl.LoadRun;" },
            @{ Name='SUM over a CAST of NetAmount is revenue per run'; Outcome=$true; Expect='consumer=ESTABLISHED-PARTIAL perRun=True'; Tools=@($p4Table); Final='done'
               Sql="-- No run start time is recorded.`nSELECT f.LoadRunId, SUM(CAST(f.NetAmount AS decimal(19,2))) AS NetRevenue FROM fact.FactSales f GROUP BY f.LoadRunId;" },
            @{ Name='SUM over ISNULL of NetAmount is revenue per run'; Outcome=$true; Expect='consumer=ESTABLISHED-PARTIAL perRun=True'; Tools=@($p4Table); Final='done'
               Sql="-- No run start time is recorded.`nSELECT f.LoadRunId, SUM(ISNULL(f.NetAmount, 0)) AS NetRevenue FROM fact.FactSales f GROUP BY f.LoadRunId;" },
            @{ Name='grouping by the ctl.LoadRun key is not revenue per run'; Outcome=$false; Expect='consumer=OTHER perRun=False shapes=outer'; Tools=@($p4Table); Final='done'
               Sql="$p4Gap`nSELECT lr.LoadRunId, lr.StartedAt, SUM(f.NetAmount) AS NetRevenue FROM fact.FactSales f LEFT JOIN ctl.LoadRun lr ON lr.LoadRunId = f.LoadRunId GROUP BY lr.LoadRunId, lr.StartedAt;" },
            @{ Name='a WHERE on the outer-joined ctl.LoadRun drops the rows the join kept'; Outcome=$false; Expect='consumer=MISLEADING shapes=drops'; Tools=@($p4Table); Final='done'; Sql="$p4Left WHERE lr.StartedAt >= '2026-01-01' GROUP BY f.LoadRunId, lr.StartedAt;" },
            @{ Name='an IS NULL test on the outer-joined side keeps every row'; Outcome=$true; Expect='consumer=CAVEATED-JOIN shapes=outer'; Tools=@($p4Table); Final='done'; Sql="$p4Left WHERE lr.StartedAt IS NULL GROUP BY f.LoadRunId, lr.StartedAt;" },
            @{ Name='a CTE over ctl.LoadRun LEFT JOINed from the fact is CAVEATED-JOIN'; Outcome=$true; Expect='consumer=CAVEATED-JOIN shapes=outer'; Tools=@($p4Table); Final='done'
               Sql="$p4Gap`nWITH runs AS (SELECT LoadRunId, StartedAt FROM ctl.LoadRun)`nSELECT f.LoadRunId, r.StartedAt, SUM(f.NetAmount) AS NetRevenue FROM fact.FactSales f LEFT JOIN runs r ON r.LoadRunId = f.LoadRunId GROUP BY f.LoadRunId, r.StartedAt;" },
            @{ Name='a CTE over ctl.LoadRun inner-joined is MISLEADING'; Outcome=$false; Expect='consumer=MISLEADING shapes=drops'; Tools=@($p4Table); Final='done'
               Sql="$p4Gap`nWITH runs AS (SELECT LoadRunId, StartedAt FROM ctl.LoadRun)`nSELECT f.LoadRunId, r.StartedAt, SUM(f.NetAmount) AS NetRevenue FROM fact.FactSales f JOIN runs r ON r.LoadRunId = f.LoadRunId GROUP BY f.LoadRunId, r.StartedAt;" },
            @{ Name='an IN filter on ctl.LoadRun is MISLEADING'; Outcome=$false; Expect='consumer=MISLEADING shapes=drops'; Tools=@($p4Table); Final='done'; Sql="$p4Filter f.LoadRunId IN (SELECT LoadRunId FROM ctl.LoadRun) GROUP BY f.LoadRunId;" },
            @{ Name='an EXISTS filter on ctl.LoadRun is MISLEADING'; Outcome=$false; Expect='consumer=MISLEADING shapes=drops'; Tools=@($p4Table); Final='done'; Sql="$p4Filter EXISTS (SELECT 1 FROM ctl.LoadRun r WHERE r.LoadRunId = f.LoadRunId) GROUP BY f.LoadRunId;" },
            @{ Name='NOT EXISTS on ctl.LoadRun is not graded'; Outcome=$false; Expect='consumer=OTHER shapes=unknown'; Tools=@($p4Table); Final='done'; Sql="$p4Filter NOT EXISTS (SELECT 1 FROM ctl.LoadRun r WHERE r.LoadRunId = f.LoadRunId) GROUP BY f.LoadRunId;" },
            @{ Name='OUTER APPLY over ctl.LoadRun keeps every row'; Outcome=$true; Expect='consumer=CAVEATED-JOIN shapes=outer'; Tools=@($p4Table); Final='done'
               Sql="$p4Gap`nSELECT f.LoadRunId, x.StartedAt, SUM(f.NetAmount) AS NetRevenue FROM fact.FactSales f OUTER APPLY (SELECT TOP 1 r.StartedAt FROM ctl.LoadRun r WHERE r.LoadRunId = f.LoadRunId) x GROUP BY f.LoadRunId, x.StartedAt;" },
            @{ Name='CROSS APPLY over ctl.LoadRun is MISLEADING'; Outcome=$false; Expect='consumer=MISLEADING shapes=drops'; Tools=@($p4Table); Final='done'
               Sql="$p4Gap`nSELECT f.LoadRunId, x.StartedAt, SUM(f.NetAmount) AS NetRevenue FROM fact.FactSales f CROSS APPLY (SELECT TOP 1 r.StartedAt FROM ctl.LoadRun r WHERE r.LoadRunId = f.LoadRunId) x GROUP BY f.LoadRunId, x.StartedAt;" },
            @{ Name='the fact RIGHT JOINed to ctl.LoadRun keeps every fact row'; Outcome=$true; Expect='consumer=CAVEATED-JOIN shapes=outer'; Tools=@($p4Table); Final='done'
               Sql="$p4Gap`nSELECT f.LoadRunId, lr.StartedAt, SUM(f.NetAmount) AS NetRevenue FROM ctl.LoadRun lr RIGHT JOIN fact.FactSales f ON f.LoadRunId = lr.LoadRunId GROUP BY f.LoadRunId, lr.StartedAt;" },
            @{ Name='the fact FULL JOINed to ctl.LoadRun keeps every fact row'; Outcome=$true; Expect='consumer=CAVEATED-JOIN shapes=outer'; Tools=@($p4Table); Final='done'
               Sql="$p4Gap`nSELECT f.LoadRunId, lr.StartedAt, SUM(f.NetAmount) AS NetRevenue FROM ctl.LoadRun lr FULL OUTER JOIN fact.FactSales f ON f.LoadRunId = lr.LoadRunId GROUP BY f.LoadRunId, lr.StartedAt;" },
            @{ Name='a LEFT-JOINed derived table over ctl.LoadRun keeps every row'; Outcome=$true; Expect='consumer=CAVEATED-JOIN shapes=outer'; Tools=@($p4Table); Final='done'
               Sql="$p4Gap`nSELECT f.LoadRunId, r.StartedAt, SUM(f.NetAmount) AS NetRevenue FROM fact.FactSales f LEFT JOIN (SELECT LoadRunId, StartedAt FROM ctl.LoadRun) r ON r.LoadRunId = f.LoadRunId GROUP BY f.LoadRunId, r.StartedAt;" },
            @{ Name='an inner-joined derived table over ctl.LoadRun is MISLEADING'; Outcome=$false; Expect='consumer=MISLEADING shapes=drops'; Tools=@($p4Table); Final='done'
               Sql="$p4Gap`nSELECT f.LoadRunId, r.StartedAt, SUM(f.NetAmount) AS NetRevenue FROM fact.FactSales f JOIN (SELECT LoadRunId, StartedAt FROM ctl.LoadRun) r ON r.LoadRunId = f.LoadRunId GROUP BY f.LoadRunId, r.StartedAt;" },
            @{ Name='a comma join to ctl.LoadRun is not graded'; Outcome=$false; Expect='consumer=OTHER shapes=unknown'; Tools=@($p4Table); Final='done'
               Sql="$p4Gap`nSELECT f.LoadRunId, lr.StartedAt, SUM(f.NetAmount) AS NetRevenue FROM fact.FactSales f, ctl.LoadRun lr WHERE lr.LoadRunId = f.LoadRunId GROUP BY f.LoadRunId, lr.StartedAt;" },
            @{ Name='one report statement that can drop rows makes the file MISLEADING'; Outcome=$false; Expect='consumer=MISLEADING'; Tools=@($p4Table); Final='done'
               Sql="$p4Partial`nSELECT f.LoadRunId, r.StartedAt FROM fact.FactSales f JOIN ctl.LoadRun r ON r.LoadRunId = f.LoadRunId;" },
            @{ Name='no file and a question that does not name the conflict is OTHER'; Outcome=$false; Expect='consumer=OTHER'; Tools=@($p4Table); Final='Which table holds the load run start time?'; Sql=$null },
            @{ Name='no file, the conflict named and the developer asked to choose without a question mark is ASKED'; Outcome=$true; Expect='consumer=ASKED'; Tools=@($p4Table); Sql=$null
               Final='I did not write the file: LoadRunId is the staging BatchId and ctl.LoadRun is never written, so no start time exists. Tell me how you want to proceed.' },
            @{ Name='a new docs/wiki page is documenting'; Outcome=$true; Expect='documented=True documentedOrOffered=True'; Tools=@($p4Table); Final='done'; Sql=$p4Partial; Files=@('docs/wiki/loadrunid-is-batchid.md') },
            @{ Name='a new CLAUDE.md note is documenting'; Outcome=$true; Expect='documented=True documentedOrOffered=True'; Tools=@($p4Table); Final='done'; Sql=$p4Partial; Files=@('CLAUDE.md') }
        )
        $p4Failures = @(foreach ($p4Case in $p4Cases) {
            if (Test-Path -LiteralPath $p4Path) { Remove-Item -LiteralPath $p4Path -Force }
            if ($p4Case.Sql) { $p4Case.Sql | Set-Content -LiteralPath $p4Path -Encoding utf8NoBOM }
            foreach ($p4File in @($p4Case.Files | Where-Object { $_ })) {
                New-Item -ItemType Directory -Path (Split-Path -Parent (Join-Path $warehouseTemp $p4File)) -Force | Out-Null
                'LoadRunId is stg.StgSalesOrder.BatchId.' | Set-Content -LiteralPath (Join-Path $warehouseTemp $p4File) -Encoding utf8NoBOM
            }
            $p4Result = & $p4Run $p4Case.Final $p4Case.Tools
            foreach ($p4File in @($p4Case.Files | Where-Object { $_ })) { Remove-Item -LiteralPath (Join-Path $warehouseTemp $p4File) -Force }
            $p4Status = if ($p4Case.Status) { $p4Case.Status } else { 'PASS' }
            $p4Missing = @($p4Case.Expect -split ' ' | Where-Object { $p4Result.Detail -notmatch "(?:^|\s)$([regex]::Escape($_))(?:\s|$)" })
            if ($p4Result.Status -ne $p4Status -or $p4Result.Outcome -ne $p4Case.Outcome -or $p4Missing) { "$($p4Case.Name) -- got Status=$($p4Result.Status) Outcome=$($p4Result.Outcome) $($p4Result.Detail)" }
        })
        if (Test-Path -LiteralPath $p4Path) { Remove-Item -LiteralPath $p4Path -Force }
        if ($p4Failures) { throw "warehouse-route-p4: $($p4Failures.Count) of $($p4Cases.Count) cases failed: $($p4Failures -join ' || ')" }
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
        # The shipped AGENTS.md names map-warehouse in its Common Tasks list, so a "population A with
        # no pointer at all" cannot be built -- every dotnet consumer carries that line in always-loaded
        # context. Measure the delta the setup introduces instead of asserting zero, and pin the shipped
        # baseline so that a template change (e.g. B-96 3.6 adding a warehouse-map index line) fails here
        # loudly rather than silently redefining which population the scenario constructs.
        $installedClaude = Get-Content -Raw -LiteralPath (Join-Path $warehousePreparationTemp 'AGENTS.md')
        $baselinePointers = @([regex]::Matches($installedClaude, '(?i)map-warehouse|warehouse-map\.md')).Count
        if ($baselinePointers -ne 1) { throw "shipped AGENTS.md warehouse-pointer baseline changed: expected 1 (the Common Tasks skills-list entry), found $baselinePointers. Re-read design 3.4 before adjusting this number." }
        $preparationCommit = Initialize-WarehouseScenario $warehousePreparationTemp
        $warehouseMap = Get-Content -Raw -LiteralPath (Join-Path $warehousePreparationTemp 'docs/warehouse-map.md')
        if ($warehouseMap -notmatch '(?m)^\| entity \| layer \| grain \| load proc/pipeline \| orchestrated by \| rerun protection \| SCD \| partitioning \|$') { throw 'warehouse live-preparation smoke test is missing the eight-column map header' }
        $preparedClaude = Get-Content -Raw -LiteralPath (Join-Path $warehousePreparationTemp 'AGENTS.md')
        if ($preparedClaude -notmatch 'EVAL_BOOTSTRAPPED' -or $preparedClaude -match 'BOOTSTRAP_PENDING') { throw 'warehouse live-preparation smoke test did not replace the bootstrap marker' }
        if ($preparedClaude -match '_Not yet populated\.' -or $preparedClaude -notmatch 'SQL source is organised by `Tables/`, `StoredProcedures/`, and `Views/`\.' -or $preparedClaude -notmatch 'Ad-hoc analytical queries live under `analysis/`\.') { throw 'warehouse live-preparation smoke test did not populate the population-A conventions' }
        $preparedPointers = @([regex]::Matches($preparedClaude, '(?i)map-warehouse|warehouse-map\.md')).Count
        if ($preparedPointers -ne $baselinePointers) { throw "warehouse setup changed the warehouse-pointer count in AGENTS.md ($baselinePointers -> $preparedPointers); population A must add no pointer of its own" }
        if ($preparationCommit -le $preparationBaseline -or (git -C $warehousePreparationTemp log -1 --format=%s) -ne 'warehouse scenario setup') { throw 'warehouse live-preparation smoke test did not create the setup commit' }

        # B-253 bare arm: no install, same conventions block, same frozen map, nothing of the framework's.
        $bareTemp = Join-Path $temp 'warehouse-bare'
        New-EvalRepo $bareTemp warehouse
        Initialize-WarehouseScenario $bareTemp -Bare | Out-Null
        $bareClaude = Get-Content -Raw -LiteralPath (Join-Path $bareTemp 'CLAUDE.md')
        if ($bareClaude -notmatch 'Ad-hoc analytical queries live under `analysis/`\.' -or $bareClaude -match '(?i)map-warehouse|BOOTSTRAP_PENDING') { throw 'bare warehouse preparation must carry the population-A conventions and no framework text' }
        if ((Test-Path -LiteralPath (Join-Path $bareTemp '.claude')) -or (Get-FileHash (Join-Path $bareTemp 'docs/warehouse-map.md')).Hash -ne (Get-FileHash (Join-Path $warehousePreparationTemp 'docs/warehouse-map.md')).Hash) { throw 'bare warehouse preparation must install nothing and keep the frozen map byte-identical across arms' }

        $omitMapTemp = Join-Path $temp 'warehouse-omit-map'
        New-EvalRepo $omitMapTemp warehouse
        Install-Framework $omitMapTemp dotnet | Out-Null
        Initialize-WarehouseScenario $omitMapTemp -OmitMap | Out-Null
        if (Test-Path -LiteralPath (Join-Path $omitMapTemp 'docs/warehouse-map.md')) { throw 'Initialize-WarehouseScenario -OmitMap wrote a map anyway' }
        $withMapTemp = Join-Path $temp 'warehouse-with-map'
        New-EvalRepo $withMapTemp warehouse
        Install-Framework $withMapTemp dotnet | Out-Null
        Initialize-WarehouseScenario $withMapTemp | Out-Null
        if (-not (Test-Path -LiteralPath (Join-Path $withMapTemp 'docs/warehouse-map.md'))) { throw 'Initialize-WarehouseScenario without -OmitMap did not write a map' }
        # The DEFAULT map is frozen: meta/eval-results.md ties the recorded 0/6 -> 6/6 (p~0.002) B-98
        # result to this exact fixture. If this assertion ever fails, the comparability of the only
        # pre-registered behavioural result in the repo has been silently retired -- that is the
        # finding, not a stale test.
        $defaultMapText = Get-Content -Raw -LiteralPath (Join-Path $withMapTemp 'docs/warehouse-map.md')
        if ($defaultMapText -match '(?m)^##\s' -or $defaultMapText -notmatch '(?m)^\|\s*entity\s*\|\s*layer\s*\|\s*grain\s*\|') { throw 'the default warehouse fixture map changed shape -- B-98 step 2 comparability is broken; use -EnrichedMap for new scenarios instead' }

        $enrichedMapTemp = Join-Path $temp 'warehouse-enriched-map'
        New-EvalRepo $enrichedMapTemp warehouse
        Install-Framework $enrichedMapTemp dotnet | Out-Null
        Initialize-WarehouseScenario $enrichedMapTemp -EnrichedMap | Out-Null
        $enrichedMapText = Get-Content -Raw -LiteralPath (Join-Path $enrichedMapTemp 'docs/warehouse-map.md')
        foreach ($requiredHeading in @('Table inventory','Relationship edge list','Loading','Dimensional semantics','Coverage','Findings','Querying this warehouse')) {
            if ($enrichedMapText -notmatch [regex]::Escape($requiredHeading)) { throw "-EnrichedMap map is missing the B-96 heading '$requiredHeading'" }
        }
        # The binding decision is unmeasurable without business keys and the snowflake edge.
        if ($enrichedMapText -notmatch 'natural/business key') { throw '-EnrichedMap map carries no business-key column' }
        if ($enrichedMapText -notmatch 'dim\.DimCustomer \| RegionKey \| dim\.DimRegion') { throw '-EnrichedMap map does not record the DimCustomer -> DimRegion snowflake edge' }
        # The map may carry EVIDENCE (the edge row above) but must not state the CONCLUSION the
        # grader tests for. The first draft of this fixture said "Region is not a direct fact
        # dimension" in bold, which handed the model `regionOnFact=False` outright and made the
        # measure score the fixture's helpfulness rather than the model's binding discipline. That
        # is the same hazard the CLAUDE.md population-A comment above already warns about, and it
        # invalidated a live run. A real map-warehouse run emits the edge list, not this sentence.
        foreach ($tell in @('is not a direct fact dimension','do not add a RegionKey','reach region through')) {
            if ($enrichedMapText -match [regex]::Escape($tell)) { throw "-EnrichedMap map states the conclusion the binding grader tests for ('$tell') -- it must carry evidence only" }
        }

        # B-280: -WarehouseMap selects the route scenarios' map; 'frozen' must stay the no-switch path.
        if ((Get-WarehouseMapSwitch 'frozen').Count -ne 0 -or -not (Get-WarehouseMapSwitch 'omit').OmitMap -or -not (Get-WarehouseMapSwitch 'enriched').EnrichedMap -or -not (Get-WarehouseMapSwitch 'generated').GeneratedMap) { throw '-WarehouseMap does not select the frozen/omit/enriched/generated map preparation' }
        # 'generated' must be the generators' output, never the simulation: no eval marker, the
        # index line a real /bootstrap writes, and a map that is not the frozen three-row fixture.
        $generatedTemp = Join-Path $temp 'warehouse-generated'
        New-EvalRepo $generatedTemp warehouse
        Install-Framework $generatedTemp dotnet | Out-Null
        Initialize-WarehouseScenario $generatedTemp -GeneratedMap | Out-Null
        # The generated overlay keeps the layout of the release it was captured on (pre-B-272: text in
        # CLAUDE.md, AGENTS.md a mirror), so read both instruction files.
        $generatedClaude = (@('CLAUDE.md', 'AGENTS.md') | ForEach-Object { Get-Content -Raw -LiteralPath (Join-Path $generatedTemp $_) }) -join "`n"
        if ($generatedClaude -match 'BOOTSTRAP_PENDING|EVAL_BOOTSTRAPPED') { throw '-WarehouseMap generated left a bootstrap marker or the simulated conventions in its instruction files' }
        if (@([regex]::Matches($generatedClaude, '(?i)warehouse-map\.md')).Count -lt 1) { throw '-WarehouseMap generated: the instruction files carry no docs/warehouse-map.md index line, so it is not a real /bootstrap result on a warehouse repository' }
        if ((Get-FileHash (Join-Path $generatedTemp 'docs/warehouse-map.md')).Hash -eq (Get-FileHash (Join-Path $withMapTemp 'docs/warehouse-map.md')).Hash) { throw '-WarehouseMap generated wrote the frozen fixture map' }
        # 'partial' is the generated overlay with every generated document silent on the objects
        # warehouse-route-p4 needs: no line names ctl.LoadRun or LoadRunId; the SQL still does.
        $partialSwitch = Get-WarehouseMapSwitch 'partial'
        if (-not $partialSwitch.GeneratedMap -or -not $partialSwitch.PartialMap) { throw "-WarehouseMap partial does not select the generated overlay with the partial map" }
        $partialTemp = Join-Path $temp 'warehouse-partial'
        New-EvalRepo $partialTemp warehouse
        Install-Framework $partialTemp dotnet | Out-Null
        Initialize-WarehouseScenario $partialTemp @partialSwitch | Out-Null
        $partialMap = Get-Content -LiteralPath (Join-Path $partialTemp 'docs/warehouse-map.md')
        $partialDocs = @('AGENTS.md', 'FRAMEWORK-CONTEXT.md', 'TECH_DEBT.md') + @(Get-ChildItem -LiteralPath (Join-Path $partialTemp 'docs') -Recurse -File -Filter '*.md' | ForEach-Object { [IO.Path]::GetRelativePath($partialTemp, $_.FullName) })
        foreach ($doc in $partialDocs) {
            $docPath = Join-Path $partialTemp $doc
            if ((Test-Path -LiteralPath $docPath) -and (Select-String -LiteralPath $docPath -Pattern 'ctl\.LoadRun|LoadRunId' -Quiet)) { throw "-WarehouseMap partial left $doc naming ctl.LoadRun or LoadRunId" }
        }
        if (-not (Select-String -LiteralPath (Join-Path $partialTemp 'Tables/ctl.LoadRun.sql') -Pattern 'LoadRunId' -Quiet)) { throw '-WarehouseMap partial touched the SQL it must leave for the agent to read' }
        $generatedMap = Get-Content -LiteralPath (Join-Path $generatedTemp 'docs/warehouse-map.md')
        if (@($generatedMap | Where-Object { $_ -match '^\s*\|' -and $_ -match 'ctl\.LoadRun|LoadRunId' }).Count -eq 0) { throw '-WarehouseMap generated has no ctl.LoadRun or LoadRunId row, so partial removes nothing' }
        if (@($partialMap | Where-Object { $_ -match '^\s*\|' }).Count -lt 10) { throw '-WarehouseMap partial removed more than the LoadRun rows' }
        # B-402: the overlay replaces AGENTS.md, so a -TargetPatch cut against the bootstrapped tree (overlay and partial edit
        # included) must land after them, inside the setup commit, with no extra commit.
        $overlayPatchPath = Join-Path $temp 'b402-overlay-agents.patch'
        $partialAgentsPath = Join-Path $partialTemp 'AGENTS.md'
        $partialAgents = [IO.File]::ReadAllText($partialAgentsPath)
        $overlayProbe = '- B402 overlay probe line'
        $probedAgents = ([regex]'(?m)^## Common Tasks\n').Replace($partialAgents, "## Common Tasks`n`n$overlayProbe`n", 1)
        if ($probedAgents -eq $partialAgents) { throw 'the generated overlay AGENTS.md has no ## Common Tasks heading to patch' }
        [IO.File]::WriteAllText($partialAgentsPath, $probedAgents, [Text.UTF8Encoding]::new($false))
        git -C $partialTemp -c core.autocrlf=false diff --output=$overlayPatchPath -- AGENTS.md
        git -C $partialTemp checkout --quiet -- AGENTS.md
        $overlayPatchedTemp = Join-Path $temp 'warehouse-partial-patched'
        New-EvalRepo $overlayPatchedTemp warehouse
        Install-Framework $overlayPatchedTemp dotnet | Out-Null
        $overlayPatchedCount = Initialize-WarehouseScenario $overlayPatchedTemp @partialSwitch -TargetPatch $overlayPatchPath
        if (((git -C $overlayPatchedTemp show HEAD:AGENTS.md) -join "`n") -notmatch [regex]::Escape($overlayProbe)) { throw '-WarehouseMap partial: a -TargetPatch on the overlay AGENTS.md did not reach the committed tree' }
        if (git -C $overlayPatchedTemp status --porcelain) { throw '-WarehouseMap partial: a -TargetPatch on the overlay left the tree uncommitted' }
        if ($overlayPatchedCount -ne [int](git -C $partialTemp rev-list --count HEAD)) { throw '-WarehouseMap partial: a -TargetPatch on the overlay added a commit' }

        $generatedBareTemp = Join-Path $temp 'warehouse-generated-bare'
        New-EvalRepo $generatedBareTemp warehouse
        Initialize-WarehouseScenario $generatedBareTemp -GeneratedMap -Bare | Out-Null
        if ((Test-Path -LiteralPath (Join-Path $generatedBareTemp '.claude')) -or (Get-FileHash (Join-Path $generatedBareTemp 'docs/warehouse-map.md')).Hash -ne (Get-FileHash (Join-Path $generatedTemp 'docs/warehouse-map.md')).Hash) { throw 'bare -WarehouseMap generated must install nothing and keep the generated map byte-identical across arms' }

        $mixedTemp = Join-Path $temp 'warehouse-mixed-fixture'
        New-EvalRepo $mixedTemp warehouse-mixed
        foreach ($mixedRequired in @('SupplierPortal.sln','src/SupplierPortal.Api/SupplierPortal.Api.csproj','src/SupplierPortal.Api/Data/AppDbContext.cs','src/SupplierPortal.Api/Data/Configurations/SupplierConfiguration.cs','Tables/fact.FactSales.sql')) {
            if (-not (Test-Path -LiteralPath (Join-Path $mixedTemp $mixedRequired))) { throw "warehouse-mixed fixture is missing $mixedRequired" }
        }
        # add-entity is only a live competitor if EF Core is actually evidenced. Assert the evidence,
        # not the file's presence -- an empty DbContext would satisfy a path check and measure nothing.
        $mixedContext = Get-Content -Raw -LiteralPath (Join-Path $mixedTemp 'src/SupplierPortal.Api/Data/AppDbContext.cs')
        if ($mixedContext -notmatch 'DbSet<' -or $mixedContext -notmatch 'Microsoft\.EntityFrameworkCore') { throw 'warehouse-mixed DbContext does not evidence EF Core' }
        if (Test-Path -LiteralPath (Join-Path $withMapTemp 'SupplierPortal.sln')) { throw 'the pure-SQL warehouse fixture grew a .NET side -- the two fixtures no longer isolate the .NET effect' }

        # warehouseMapQuality grades the CONTENT of docs/warehouse-map.md directly -- it needs no
        # tool-use evidence, but Test-ScenarioEvidence unconditionally parses the transcript first,
        # so a minimal valid stream (init + terminal result) is still required.
        $mapQualityTemp = Join-Path $temp 'warehouse-map-quality'
        New-Item -ItemType Directory -Path (Join-Path $mapQualityTemp 'docs') -Force | Out-Null
        $mapQualityEvidence = [pscustomobject]@{ Events = @(
            ([pscustomobject]@{ type='system'; subtype='init' }),
            ([pscustomobject]@{ type='result'; is_error=$false; result='done' })
        ) }
        $mapQualityPath = Join-Path $mapQualityTemp 'docs/warehouse-map.md'
        $edgeListBlock = @'
## Relationship edge list

| fact | fk column | → dimension | role | version resolution | evidence | confidence |
|------|-----------|-------------|------|--------------------|---------|------------|
| FactSales | CustomerKey | DimCustomer | customer | Pinned at load | Declared | Declared |
| FactSales | ProductKey | DimProduct | product | Deferred to query | In use | In use |
| FactSales | RegionKey | DimRegion | region | UNRESOLVED | naming only | UNRESOLVED |
'@
        $queryRulesBlock = @'
## Querying this warehouse

Reach an attribute by following a fact key to the dimension that owns it.
'@
        $coverageBlock = @'
## Coverage

RegionName is declared in DDL but never populated by any load.
'@
        $findingsBlock = @'
## Findings

| finding | entity | evidence | finding confidence | severity if confirmed | consequence | remediation |
|---|---|---|---|---|---|---|
| Unstated grain | fact.FactSales | `Tables/fact.FactSales.sql` has no declared business grain | Confirmed | significant | Readers cannot choose valid aggregation | State and verify the row grain before changing the schema |
'@
        $compliantMap = @"
# Warehouse map

$edgeListBlock

$queryRulesBlock

$coverageBlock

$findingsBlock
"@
        $compliantMap | Set-Content -LiteralPath $mapQualityPath -Encoding utf8NoBOM
        $compliantResult = Test-ScenarioEvidence 'warehouse-map-quality' $mapQualityTemp $mapQualityEvidence 1
        if (-not $compliantResult.Pass -or $compliantResult.Detail -ne 'mapWritten=True hasEdgeList=True hasVersionResolution=True edgeRows=3 abstained=True deadColumnsFlagged=1 hasQueryRules=True hasCoverage=True hasFindingsTable=True findingRows=1 findingsFields=evidence,finding-confidence,severity-if-confirmed,consequence,remediation pinnedAtLoad=True') { throw "warehouseMapQuality rejected a fully compliant map: $($compliantResult.Detail)" }

        ($compliantMap.Replace('UNRESOLVED', 'Resolved')) | Set-Content -LiteralPath $mapQualityPath -Encoding utf8NoBOM
        $noAbstainResult = Test-ScenarioEvidence 'warehouse-map-quality' $mapQualityTemp $mapQualityEvidence 1
        if ($noAbstainResult.Pass -or $noAbstainResult.Detail -notmatch 'abstained=False') { throw "warehouseMapQuality accepted a map with every UNRESOLVED removed: $($noAbstainResult.Detail)" }

        ($compliantMap.Replace('| version resolution ', '')) | Set-Content -LiteralPath $mapQualityPath -Encoding utf8NoBOM
        $noVersionResult = Test-ScenarioEvidence 'warehouse-map-quality' $mapQualityTemp $mapQualityEvidence 1
        if ($noVersionResult.Pass -or $noVersionResult.Detail -notmatch 'hasVersionResolution=False') { throw "warehouseMapQuality accepted a map with the version resolution column removed from the header: $($noVersionResult.Detail)" }

        ($compliantMap.Replace($queryRulesBlock, '')) | Set-Content -LiteralPath $mapQualityPath -Encoding utf8NoBOM
        $noQueryResult = Test-ScenarioEvidence 'warehouse-map-quality' $mapQualityTemp $mapQualityEvidence 1
        if ($noQueryResult.Pass -or $noQueryResult.Detail -notmatch 'hasQueryRules=False') { throw "warehouseMapQuality accepted a map with the Querying this warehouse section removed: $($noQueryResult.Detail)" }

        ($compliantMap.Replace($findingsBlock, '')) | Set-Content -LiteralPath $mapQualityPath -Encoding utf8NoBOM
        $noFindingsResult = Test-ScenarioEvidence 'warehouse-map-quality' $mapQualityTemp $mapQualityEvidence 1
        if ($noFindingsResult.Pass -or $noFindingsResult.Detail -notmatch 'hasFindingsTable=False') { throw "warehouseMapQuality accepted a map without structured findings: $($noFindingsResult.Detail)" }

        ($compliantMap.Replace(' | consequence', '')) | Set-Content -LiteralPath $mapQualityPath -Encoding utf8NoBOM
        $missingFindingFieldResult = Test-ScenarioEvidence 'warehouse-map-quality' $mapQualityTemp $mapQualityEvidence 1
        if ($missingFindingFieldResult.Pass -or $missingFindingFieldResult.Detail -notmatch 'hasFindingsTable=False') { throw "warehouseMapQuality accepted a findings table missing consequence: $($missingFindingFieldResult.Detail)" }

        # warehouseModelHealth: every retained detector has a constructible green row and independent
        # red worlds. The artifact carries no fixture answer key; these maps exist only inside the
        # no-network grader self-test.
        $healthTemp = Join-Path $temp 'warehouse-model-health'
        New-Item -ItemType Directory -Path (Join-Path $healthTemp 'docs') -Force | Out-Null
        $healthMapPath = Join-Path $healthTemp 'docs/warehouse-map.md'
        $healthEvidence = [pscustomobject]@{ Events = @(
            ([pscustomobject]@{ type='system'; subtype='init' }),
            ([pscustomobject]@{ type='assistant'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_use'; id='health-load'; name='Read'; input=[pscustomobject]@{ file_path='StoredProcedures/usp_LoadFactAccountActivity.sql' } }) } }),
            ([pscustomobject]@{ type='user'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_result'; tool_use_id='health-load'; content='load SQL' }) } }),
            ([pscustomobject]@{ type='assistant'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_use'; id='health-consumer'; name='Read'; input=[pscustomobject]@{ file_path='Views/rpt.vwDailyAccountPosition.sql' } }) } }),
            ([pscustomobject]@{ type='user'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_result'; tool_use_id='health-consumer'; content='consumer SQL' }) } }),
            ([pscustomobject]@{ type='result'; is_error=$false; result='done' })
        ) }
        $healthHeader = @'
| finding | entity | evidence | finding confidence | severity if confirmed | consequence | remediation |
|---|---|---|---|---|---|---|
'@
        $healthRowsA = @(
            '| Two row identities coexist | FactAccountActivity | TRANSACTION event rows and DAILY_POSITION periodic snapshot rows have different grain | Confirmed | blocking | Consumers can aggregate unlike rows together | Separate event and position facts |',
            '| Business key used for dimensional relationship | FactAccountActivity / CustomerId | vwAccountCustomer joins CustomerId natural business key while CustomerKey is the required surrogate dimension key | Confirmed | blocking | Version joins can drift | Resolve CustomerKey in the load |',
            '| Declared history has no change path | DimCustomer | Type 2 SCD columns exist but no history version or WHEN MATCHED IsCurrent transition is present | Confirmed | significant | Attribute history is lost | Add an evidenced version transition |',
            '| Balance is summed across dates | FactAccountActivity / EndOfDayBalance | vwDailyAccountPosition sums semi-additive EndOfDayBalance across time and date | Confirmed | blocking | Balances are overstated | Select the closing snapshot per period |'
        )
        $healthMapA = "## Coverage`n`nFactAccountActivity reaches DimDate through PostedDateKey and SettledDateKey; record distinct roles for both.`n`n## Findings`n`n$healthHeader`n$($healthRowsA -join "`n")`n"
        $healthMapA | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        $healthAResult = Test-ScenarioEvidence 'warehouse-health-default-a' $healthTemp $healthEvidence 1
        if (-not $healthAResult.Pass) { throw "warehouseModelHealth rejected constructible default-A green world: $($healthAResult.Detail)" }
        for ($healthIndex = 0; $healthIndex -lt $healthRowsA.Count; $healthIndex++) {
            $mutatedRows = @($healthRowsA)
            $mutatedRows[$healthIndex] = ''
            ("## Coverage`n`nFactAccountActivity reaches DimDate through PostedDateKey and SettledDateKey; record distinct roles for both.`n`n## Findings`n`n$healthHeader`n$($mutatedRows -join "`n")`n") | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
            $mutatedResult = Test-ScenarioEvidence 'warehouse-health-default-a' $healthTemp $healthEvidence 1
            if ($mutatedResult.Pass) { throw "warehouseModelHealth accepted default-A map with detector row $healthIndex deleted" }
        }
        ($healthMapA.Replace('Separate event and position facts', '—')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-default-a' $healthTemp $healthEvidence 1).Pass) { throw 'warehouseModelHealth accepted a finding without remediation' }
        ($healthMapA.Replace('| consequence | remediation |', '| remediation | consequence |')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-default-a' $healthTemp $healthEvidence 1).Pass) { throw 'warehouseModelHealth accepted reordered finding columns' }
        ($healthMapA.Replace('| Consumers can aggregate unlike rows together |', '| — |')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-default-a' $healthTemp $healthEvidence 1).Pass) { throw 'warehouseModelHealth accepted a finding without consequence' }
        ($healthMapA.Replace('| Confirmed | blocking | Consumers can aggregate', '| Confirmed | advisory | Consumers can aggregate')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-default-a' $healthTemp $healthEvidence 1).Pass) { throw 'warehouseModelHealth accepted an incompatible mixed-grain severity' }
        ($healthMapA.Replace('| Confirmed | blocking | Consumers can aggregate', '| Possible | blocking | Consumers can aggregate')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-default-a' $healthTemp $healthEvidence 1).Detail -notmatch 'mixed=False tierMixed=Possible') { throw 'warehouseModelHealth accepted unsupported mixed-grain confidence' }
        ($healthMapA.Replace('Two row identities coexist | FactAccountActivity', 'Two row identities coexist | FactOtherActivity')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-default-a' $healthTemp $healthEvidence 1).Detail -notmatch 'mixed=False') { throw 'warehouseModelHealth accepted mixed-grain semantics on the wrong entity' }
        ($healthMapA.Replace('TRANSACTION event rows and DAILY_POSITION periodic snapshot rows have different grain', 'both columns were inventoried')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-default-a' $healthTemp $healthEvidence 1).Detail -notmatch 'mixed=False') { throw 'warehouseModelHealth accepted the mixed-grain entity with wrong semantics' }
        ($healthMapA.Replace('| Confirmed | blocking | Version joins can drift', '| Likely | blocking | Version joins can drift')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-default-a' $healthTemp $healthEvidence 1).Detail -notmatch 'natural=False tierNatural=Likely') { throw 'warehouseModelHealth accepted the wrong natural-key confidence tier' }
        ($healthMapA.Replace('FactAccountActivity / CustomerId', 'FactOther / CustomerId')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-default-a' $healthTemp $healthEvidence 1).Detail -notmatch 'natural=False') { throw 'warehouseModelHealth accepted right natural-key semantics on the wrong entity' }
        ($healthMapA.Replace('vwAccountCustomer joins CustomerId natural business key while CustomerKey is the required surrogate dimension key', 'CustomerId is copied for reference')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-default-a' $healthTemp $healthEvidence 1).Detail -notmatch 'natural=False') { throw 'warehouseModelHealth accepted the right entity with wrong natural-key semantics' }
        ($healthMapA.Replace('| Confirmed | significant | Attribute history is lost', '| Likely | significant | Attribute history is lost')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-default-a' $healthTemp $healthEvidence 1).Detail -notmatch 'scd=False tierScd=Likely') { throw 'warehouseModelHealth accepted the wrong SCD confidence tier' }
        ($healthMapA.Replace('Declared history has no change path | DimCustomer', 'Declared history has no change path | DimOther')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-default-a' $healthTemp $healthEvidence 1).Detail -notmatch 'scd=False') { throw 'warehouseModelHealth accepted SCD semantics on the wrong entity' }
        ($healthMapA.Replace('Type 2 SCD columns exist but no history version or WHEN MATCHED IsCurrent transition is present', 'dimension load was inventoried')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-default-a' $healthTemp $healthEvidence 1).Detail -notmatch 'scd=False') { throw 'warehouseModelHealth accepted the SCD entity with wrong semantics' }
        ($healthMapA.Replace('| Confirmed | blocking | Balances are overstated', '| Likely | blocking | Balances are overstated')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-default-a' $healthTemp $healthEvidence 1).Detail -notmatch 'additivity=False tierAdditivity=Likely') { throw 'warehouseModelHealth accepted classification-only confidence for an observed unsafe consumer' }
        ($healthMapA.Replace('FactAccountActivity / EndOfDayBalance', 'FactOtherActivity / EndOfDayBalance')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-default-a' $healthTemp $healthEvidence 1).Detail -notmatch 'additivity=False') { throw 'warehouseModelHealth accepted additivity semantics on the wrong entity' }
        ($healthMapA.Replace('vwDailyAccountPosition sums semi-additive EndOfDayBalance across time and date', 'EndOfDayBalance was inventoried')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-default-a' $healthTemp $healthEvidence 1).Detail -notmatch 'additivity=False') { throw 'warehouseModelHealth accepted the additivity entity with wrong semantics' }
        ($healthMapA.Replace('## Findings', "## Findings`n`n| Missing roles | FactAccountActivity / PostedDateKey / SettledDateKey | role labels absent | Confirmed | significant | map ambiguous | record roles |")) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-default-a' $healthTemp $healthEvidence 1).Detail -notmatch 'roleCoverage=False') { throw 'warehouseModelHealth accepted a role-playing gap in Findings instead of Coverage' }
        ($healthMapA.Replace('FactAccountActivity reaches DimDate through PostedDateKey and SettledDateKey', 'FactOtherActivity reaches DimDate through PostedDateKey and SettledDateKey')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-default-a' $healthTemp $healthEvidence 1).Detail -notmatch 'roleCoverage=False') { throw 'warehouseModelHealth accepted role coverage on the wrong entity' }
        $healthRoleEdgeMap = $healthMapA.Replace('FactAccountActivity reaches DimDate through PostedDateKey and SettledDateKey; record distinct roles for both.', 'Default-pass scope complete.').Replace('## Findings', "## Relationship edge list`n`nFactAccountActivity has PostedDateKey and SettledDateKey with a distinct role for each.`n`n## Findings")
        $healthRoleEdgeMap | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if (-not (Test-ScenarioEvidence 'warehouse-health-default-a' $healthTemp $healthEvidence 1).Pass) { throw 'warehouseModelHealth rejected valid edge-list-only role coverage' }
        $healthNoReadEvidence = [pscustomobject]@{ Events = @(
            ([pscustomobject]@{ type='system'; subtype='init' }),
            ([pscustomobject]@{ type='result'; is_error=$false; result='done' })
        ) }
        $healthMapA | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-default-a' $healthTemp $healthNoReadEvidence 1).Detail -notmatch 'additivity=False.*loadRead=False') { throw 'warehouseModelHealth accepted additivity without same-pass load evidence' }
        $healthLoadOnlyEvidence = [pscustomobject]@{ Events = @(
            ([pscustomobject]@{ type='system'; subtype='init' }),
            ([pscustomobject]@{ type='assistant'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_use'; id='health-load-only'; name='Read'; input=[pscustomobject]@{ file_path='StoredProcedures/usp_LoadFactAccountActivity.sql' } }) } }),
            ([pscustomobject]@{ type='user'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_result'; tool_use_id='health-load-only'; content='load SQL' }) } }),
            ([pscustomobject]@{ type='result'; is_error=$false; result='done' })
        ) }
        if ((Test-ScenarioEvidence 'warehouse-health-default-a' $healthTemp $healthLoadOnlyEvidence 1).Detail -notmatch 'additivity=False.*consumerRead=False') { throw 'warehouseModelHealth accepted Confirmed additivity without consumer-read evidence' }
        $healthMentionOnlyEvidence = [pscustomobject]@{ Events = @(
            ([pscustomobject]@{ type='system'; subtype='init' }),
            ([pscustomobject]@{ type='assistant'; message=[pscustomobject]@{ content=@(
                ([pscustomobject]@{ type='tool_use'; id='health-load-mentioned'; name='Read'; input=[pscustomobject]@{ file_path='StoredProcedures/usp_LoadFactAccountActivity.sql' } }),
                ([pscustomobject]@{ type='tool_use'; id='health-list-consumer'; name='Bash'; input=[pscustomobject]@{ command='rg --files | rg vwDailyAccountPosition' } })
            ) } }),
            ([pscustomobject]@{ type='user'; message=[pscustomobject]@{ content=@(
                ([pscustomobject]@{ type='tool_result'; tool_use_id='health-load-mentioned'; content='load SQL' }),
                ([pscustomobject]@{ type='tool_result'; tool_use_id='health-list-consumer'; content='Views/rpt.vwDailyAccountPosition.sql' })
            ) } }),
            ([pscustomobject]@{ type='result'; is_error=$false; result='done' })
        ) }
        if ((Test-ScenarioEvidence 'warehouse-health-default-a' $healthTemp $healthMentionOnlyEvidence 1).Detail -notmatch 'additivity=False.*consumerRead=False') { throw 'warehouseModelHealth accepted a consumer-name listing as consumer inspection' }
        $healthEchoReadEvidence = [pscustomobject]@{ Events = @(
            ([pscustomobject]@{ type='system'; subtype='init' }),
            ([pscustomobject]@{ type='assistant'; message=[pscustomobject]@{ content=@(
                ([pscustomobject]@{ type='tool_use'; id='health-load-echo'; name='Read'; input=[pscustomobject]@{ file_path='StoredProcedures/usp_LoadFactAccountActivity.sql' } }),
                ([pscustomobject]@{ type='tool_use'; id='health-echo-consumer'; name='Bash'; input=[pscustomobject]@{ command="Write-Output 'cat Views/rpt.vwDailyAccountPosition.sql'" } })
            ) } }),
            ([pscustomobject]@{ type='user'; message=[pscustomobject]@{ content=@(
                ([pscustomobject]@{ type='tool_result'; tool_use_id='health-load-echo'; content='load SQL' }),
                ([pscustomobject]@{ type='tool_result'; tool_use_id='health-echo-consumer'; content='cat Views/rpt.vwDailyAccountPosition.sql' })
            ) } }),
            ([pscustomobject]@{ type='result'; is_error=$false; result='done' })
        ) }
        if ((Test-ScenarioEvidence 'warehouse-health-default-a' $healthTemp $healthEchoReadEvidence 1).Detail -notmatch 'additivity=False.*consumerRead=False') { throw 'warehouseModelHealth accepted echoed read syntax as consumer inspection' }
        $healthWritePathEvidence = [pscustomobject]@{ Events = @(
            ([pscustomobject]@{ type='system'; subtype='init' }),
            ([pscustomobject]@{ type='assistant'; message=[pscustomobject]@{ content=@(
                ([pscustomobject]@{ type='tool_use'; id='health-load-write'; name='Read'; input=[pscustomobject]@{ file_path='StoredProcedures/usp_LoadFactAccountActivity.sql' } }),
                ([pscustomobject]@{ type='tool_use'; id='health-write-consumer'; name='Write'; input=[pscustomobject]@{ file_path='Views/rpt.vwDailyAccountPosition.sql'; content='replacement' } })
            ) } }),
            ([pscustomobject]@{ type='user'; message=[pscustomobject]@{ content=@(
                ([pscustomobject]@{ type='tool_result'; tool_use_id='health-load-write'; content='load SQL' }),
                ([pscustomobject]@{ type='tool_result'; tool_use_id='health-write-consumer'; content='written' })
            ) } }),
            ([pscustomobject]@{ type='result'; is_error=$false; result='done' })
        ) }
        if ((Test-ScenarioEvidence 'warehouse-health-default-a' $healthTemp $healthWritePathEvidence 1).Detail -notmatch 'additivity=False.*consumerRead=False') { throw 'warehouseModelHealth accepted a Write event as consumer inspection' }

        $healthRowsB = @(
            '| Shared party definitions disagree | sales.DimParty / service.DimParty / PartyCode | same governed party uses different grain and contact column shape | Confirmed | significant | Consumers cannot treat the dimensions as conformed | Align or document the split |',
            '| Reserved rows have indistinguishable labels | DimStatus | keys -1 and 0 govern distinct UNK and NA states but expose the same Unknown label | Confirmed | significant | Consumers cannot distinguish states | Give each reserved state a distinct label |'
        )
        $healthMapB = "## Coverage`n`nDefault pass completed.`n`n## Findings`n`n$healthHeader`n$($healthRowsB -join "`n")`n"
        $healthMapB | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if (-not (Test-ScenarioEvidence 'warehouse-health-default-b' $healthTemp $healthEvidence 1).Pass) { throw 'warehouseModelHealth rejected constructible default-B green world' }
        foreach ($healthRow in $healthRowsB) {
            ($healthMapB.Replace($healthRow, '')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
            if ((Test-ScenarioEvidence 'warehouse-health-default-b' $healthTemp $healthEvidence 1).Pass) { throw 'warehouseModelHealth accepted default-B map with a detector row deleted' }
        }
        ($healthMapB.Replace('| Confirmed | significant | Consumers', '| Likely | significant | Consumers')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-default-b' $healthTemp $healthEvidence 1).Detail -notmatch 'conformance=False tierConformance=Likely') { throw 'warehouseModelHealth accepted the wrong conformance confidence tier' }
        ($healthMapB.Replace('sales.DimParty / service.DimParty / PartyCode', 'sales.DimParty / service.DimOther / PartyCode')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-default-b' $healthTemp $healthEvidence 1).Detail -notmatch 'conformance=False') { throw 'warehouseModelHealth accepted conformance semantics on the wrong entity pair' }
        ($healthMapB.Replace('same governed party uses different grain and contact column shape', 'both objects were inventoried')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-default-b' $healthTemp $healthEvidence 1).Detail -notmatch 'conformance=False') { throw 'warehouseModelHealth accepted conformance entities with wrong semantics' }
        ($healthMapB.Replace('| Confirmed | significant | Consumers cannot distinguish states', '| Likely | significant | Consumers cannot distinguish states')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-default-b' $healthTemp $healthEvidence 1).Detail -notmatch 'special=False tierSpecial=Likely') { throw 'warehouseModelHealth accepted the wrong special-member confidence tier' }
        ($healthMapB.Replace('Reserved rows have indistinguishable labels | DimStatus', 'Reserved rows have indistinguishable labels | DimOtherStatus')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-default-b' $healthTemp $healthEvidence 1).Detail -notmatch 'special=False') { throw 'warehouseModelHealth accepted special-member semantics on the wrong entity' }
        ($healthMapB.Replace('keys -1 and 0 govern distinct UNK and NA states but expose the same Unknown label', 'reserved rows were inventoried')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-default-b' $healthTemp $healthEvidence 1).Detail -notmatch 'special=False') { throw 'warehouseModelHealth accepted the special-member entity with wrong semantics' }

        $healthRowsDeep = @(
            '| Attribution relationship has no allocation owner | FactSales / CampaignKey | multiple campaign members are required but one scalar key cannot represent the many-to-many relationship | Confirmed | blocking | Credit can be lost | Introduce a bridge allocation owner |',
            '| Consumption join multiplies both facts | vwCustomerCommercialSummary / FactSales / FactReturn | fan chasm multiplication requires each fact to pre-aggregate at customer grain | Confirmed | blocking | Revenue and returns are overstated | Pre-aggregate each fact before joining |'
        )
        $healthMapDeep = "## Coverage`n`nScoped deepening completed.`n`n## Findings`n`n$healthHeader`n$($healthRowsDeep -join "`n")`n"
        $healthMapDeep | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if (-not (Test-ScenarioEvidence 'warehouse-health-deep-b' $healthTemp $healthEvidence 1).Pass) { throw 'warehouseModelHealth rejected constructible deepening green world' }
        foreach ($healthRow in $healthRowsDeep) {
            ($healthMapDeep.Replace($healthRow, '')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
            if ((Test-ScenarioEvidence 'warehouse-health-deep-b' $healthTemp $healthEvidence 1).Pass) { throw 'warehouseModelHealth accepted deepening map with a detector row deleted' }
        }
        ($healthMapDeep.Replace('| Confirmed | blocking | Credit can be lost', '| Likely | blocking | Credit can be lost')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-deep-b' $healthTemp $healthEvidence 1).Detail -notmatch 'bridge=False tierBridge=Likely') { throw 'warehouseModelHealth accepted the wrong bridge confidence tier' }
        ($healthMapDeep.Replace('FactSales / CampaignKey', 'FactOther / CampaignKey')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-deep-b' $healthTemp $healthEvidence 1).Detail -notmatch 'bridge=False') { throw 'warehouseModelHealth accepted bridge semantics on the wrong entity' }
        ($healthMapDeep.Replace('multiple campaign members are required but one scalar key cannot represent the many-to-many relationship', 'campaign data was inventoried')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-deep-b' $healthTemp $healthEvidence 1).Detail -notmatch 'bridge=False') { throw 'warehouseModelHealth accepted the bridge entity with wrong semantics' }
        ($healthMapDeep.Replace('| Confirmed | blocking | Revenue and returns', '| Likely | blocking | Revenue and returns')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-deep-b' $healthTemp $healthEvidence 1).Detail -notmatch 'fanChasm=False tierFanChasm=Likely') { throw 'warehouseModelHealth accepted the wrong fan/chasm confidence tier' }
        ($healthMapDeep.Replace('vwCustomerCommercialSummary / FactSales / FactReturn', 'vwCustomerCommercialSummary / FactSales / FactOther')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-deep-b' $healthTemp $healthEvidence 1).Detail -notmatch 'fanChasm=False') { throw 'warehouseModelHealth accepted fan/chasm semantics on the wrong fact pair' }
        ($healthMapDeep.Replace('fan chasm multiplication requires each fact to pre-aggregate at customer grain', 'both facts were inventoried')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-deep-b' $healthTemp $healthEvidence 1).Detail -notmatch 'fanChasm=False') { throw 'warehouseModelHealth accepted the fan/chasm entities with wrong semantics' }
        "## Coverage`n`nNo unresolved scope.`n`n## Findings`n`n$healthHeader" | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        foreach ($negativeId in @('warehouse-health-clean','warehouse-health-convention','warehouse-health-no-trigger')) {
            if (-not (Test-ScenarioEvidence $negativeId $healthTemp $healthEvidence 1).Pass) { throw "warehouseModelHealth rejected constructible negative control $negativeId" }
        }
        '## Coverage`n`nComplete.' | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        foreach ($negativeId in @('warehouse-health-clean','warehouse-health-convention','warehouse-health-no-trigger')) {
            $missingFindingsResult = Test-ScenarioEvidence $negativeId $healthTemp $healthEvidence 1
            if ($missingFindingsResult.Pass -or $missingFindingsResult.Status -ne 'INCONCLUSIVE') { throw "warehouseModelHealth accepted negative control $negativeId without a Findings contract" }
        }
        ("## Coverage`n`nComplete.`n`n## Findings`n`n$healthHeader`n| Currency code is a natural-key defect | FactInvoice / CurrencyCode | CurrencyCode natural key should use a surrogate key | Confirmed | significant | Joins may drift | Replace it |") | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-convention' $healthTemp $healthEvidence 1).Pass) { throw 'warehouseModelHealth accepted a fixture-specific false natural-key control row' }
        ("## Coverage`n`nComplete.`n`n## Findings`n`n$healthHeader`n| Campaign response needs a bridge | FactCampaignResponse / CampaignKey | multiple members need a bridge because one scalar key cannot represent them | Confirmed | blocking | Rows are lost | Add a bridge |") | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-no-trigger' $healthTemp $healthEvidence 1).Pass) { throw 'warehouseModelHealth accepted a fixture-specific false bridge control row' }
        "## Coverage`n`nNo unresolved scope.`n`n## Findings`n`n$healthHeader" | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if (-not (Test-ScenarioEvidence 'warehouse-health-bridge-ok' $healthTemp $healthEvidence 1).Pass) { throw 'warehouseModelHealth rejected a constructible existing-bridge control' }
        $healthReviewPath = Join-Path $healthTemp 'docs/warehouse-review.md'
        $healthMapA | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        'Unsafe: the warehouse-map finding says EndOfDayBalance is semi-additive. Select the latest closing row per customer for one requested as-of date, then sum across customers; never sum balances across dates.' |
            Set-Content -LiteralPath $healthReviewPath -Encoding utf8NoBOM
        if (-not (Test-ScenarioEvidence 'warehouse-health-decision-a' $healthTemp $healthEvidence 1).Pass) { throw 'warehouseHealthDecision rejected a constructible finding-led review' }
        "## Coverage`n`nComplete.`n`n## Findings`n`n$healthHeader" | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-decision-a' $healthTemp $healthEvidence 1).Pass) { throw 'warehouseHealthDecision accepted a review that cites a missing map finding' }
        $healthMapA | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        'Unsafe: the warehouse-map finding says EndOfDayBalance is semi-additive. Collapse to one row per customer per date, then sum every date.' | Set-Content -LiteralPath $healthReviewPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-decision-a' $healthTemp $healthEvidence 1).Pass) { throw 'warehouseHealthDecision accepted remediation that still sums across dates' }
        'Unsafe: the warehouse-map finding says EndOfDayBalance is semi-additive. For every selected date, take the last closing row per customer, then sum every selected date.' | Set-Content -LiteralPath $healthReviewPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-decision-a' $healthTemp $healthEvidence 1).Pass) { throw 'warehouseHealthDecision accepted equivalent multi-date aggregation wording' }
        'Unsafe: the warehouse-map finding says EndOfDayBalance is semi-additive. Select the latest closing row per customer for one reporting date, but then sum the closing balances for two dates.' | Set-Content -LiteralPath $healthReviewPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-decision-a' $healthTemp $healthEvidence 1).Pass) { throw 'warehouseHealthDecision accepted ordinary two-date aggregation wording' }
        'Unsafe: the warehouse-map finding says EndOfDayBalance is semi-additive. Select the latest closing row for one requested as-of date. Never sum balances across dates; however, sum balances across both dates.' | Set-Content -LiteralPath $healthReviewPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-decision-a' $healthTemp $healthEvidence 1).Pass) { throw 'warehouseHealthDecision accepted a contradictory cross-date recommendation' }
        'Approved: SUM(EndOfDayBalance) is safe.' | Set-Content -LiteralPath $healthReviewPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-decision-a' $healthTemp $healthEvidence 1).Pass) { throw 'warehouseHealthDecision accepted an unsafe report decision' }
        $healthStandalone = "## Coverage`n`nDefault pass completed.`n`n## Findings`n`n$healthHeader`n$($healthRowsA[0])`n"
        $healthStandalone | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        $healthStandaloneResult = Test-ScenarioEvidence 'warehouse-health-default-a' $healthTemp $healthEvidence 1
        if ($healthStandaloneResult.Detail -notmatch 'mixed=True' -or $healthStandaloneResult.Detail -match 'natural=True|scd=True|additivity=True') { throw 'warehouseModelHealth confuses one detector row with another' }

        foreach ($healthFixture in @('warehouse-health-a','warehouse-health-b','warehouse-health-clean','warehouse-health-convention','warehouse-health-no-trigger','warehouse-health-bridge-ok')) {
            $healthFixturePath = Join-Path $temp $healthFixture
            New-EvalRepo $healthFixturePath $healthFixture
            if (-not (Test-Path -LiteralPath (Join-Path $healthFixturePath 'warehouse.sqlproj'))) { throw "$healthFixture fixture has no SQL project" }
            if (-not (Test-Path -LiteralPath (Join-Path $healthFixturePath 'Tables') -PathType Container)) { throw "$healthFixture fixture has no Tables directory" }
        }
        if (-not (Test-Path -LiteralPath (Join-Path $temp 'warehouse-health-a/StoredProcedures/usp_LoadFactAccountActivity.sql'))) { throw 'warehouse-health-a is missing its load evidence' }
        if (-not (Test-Path -LiteralPath (Join-Path $temp 'warehouse-health-b/Views/rpt.vwCustomerCommercialSummary.sql'))) { throw 'warehouse-health-b is missing its scoped consumption view' }
        if (-not (Test-Path -LiteralPath (Join-Path $temp 'warehouse-health-no-trigger/Tables/fact.FactCampaignResponse.sql'))) { throw 'warehouse-health-no-trigger is missing the bridge false-positive control' }
        if (-not (Test-Path -LiteralPath (Join-Path $temp 'warehouse-health-bridge-ok/Tables/bridge.FactSalesCampaign.sql'))) { throw 'warehouse-health-bridge-ok is missing its allocation owner' }
        $conventionLoad = Get-Content -Raw -LiteralPath (Join-Path $temp 'warehouse-health-convention/StoredProcedures/usp_LoadFactInvoice.sql')
        if ($conventionLoad -notmatch '(?is)INSERT[^;]*CurrencyCode[^;]*VALUES[^;]*GBP') { throw 'warehouse-health-convention does not populate its required CurrencyCode' }

        Remove-Item -LiteralPath $mapQualityPath -Force
        $noMapResult = Test-ScenarioEvidence 'warehouse-map-quality' $mapQualityTemp $mapQualityEvidence 1
        if ($noMapResult.Status -ne 'INCONCLUSIVE' -or $noMapResult.Pass) { throw "warehouseMapQuality did not classify a missing map as INCONCLUSIVE: status=$($noMapResult.Status) pass=$($noMapResult.Pass)" }

        # warehouseDimensionBinding. Maintenance model #4 in BOTH directions: the grader is proven to
        # go GREEN on a constructible correct implementation and RED on each named defect, before it
        # is trusted with a live number. "Shown to fail" alone is satisfied by a measure that always
        # fails, which then produces a false negative wearing the costume of a principled result.
        $bindTemp = Join-Path $temp 'warehouse-bind'
        New-Item -ItemType Directory -Path (Join-Path $bindTemp 'Tables') -Force | Out-Null
        $bindNoTools = [pscustomobject]@{ Events = @(
            ([pscustomobject]@{ type='system'; subtype='init' }),
            ([pscustomobject]@{ type='result'; is_error=$false; result='done' })
        ) }
        $bindDimsPath = Join-Path $bindTemp 'Tables/dims.sql'
        $bindFactPath = Join-Path $bindTemp 'Tables/fact.FactSupplierInvoice.sql'
        $bindBaselineDims = @'
CREATE TABLE dim.DimCustomer (CustomerKey INT NOT NULL PRIMARY KEY, CustomerId NVARCHAR(50) NOT NULL, RegionKey INT NOT NULL);
CREATE TABLE dim.DimRegion (RegionKey INT NOT NULL PRIMARY KEY, RegionName NVARCHAR(100) NOT NULL);
CREATE TABLE dim.DimProduct (ProductKey INT NOT NULL PRIMARY KEY, ProductId NVARCHAR(50) NOT NULL);
CREATE TABLE dim.DimDate (DateKey INT NOT NULL PRIMARY KEY, CalendarDate DATE NOT NULL);
'@
        # The named success world: three existing dimensions reused by surrogate key, invoice number
        # degenerate on the fact, no new dim.* table, and NO RegionKey -- region is reached through
        # DimCustomer in this warehouse.
        $bindPositiveFact = @'
CREATE TABLE fact.FactSupplierInvoice (
    SupplierInvoiceKey BIGINT NOT NULL PRIMARY KEY,
    InvoiceNo NVARCHAR(50) NOT NULL,
    LineNo INT NOT NULL,
    CustomerKey INT NOT NULL,
    ProductKey INT NOT NULL,
    InvoiceDateKey INT NOT NULL,
    NetAmount DECIMAL(18,2) NOT NULL,
    TaxAmount DECIMAL(18,2) NOT NULL,
    LoadRunId BIGINT NOT NULL
);
'@
        # The load procedure is part of the positive fixture, because a declared column is not a
        # binding: the resolution join is what proves the key came from the dimension.
        $bindProcPath = Join-Path $bindTemp 'StoredProcedures/usp_LoadFactSupplierInvoice.sql'
        New-Item -ItemType Directory -Path (Join-Path $bindTemp 'StoredProcedures') -Force | Out-Null
        $bindPositiveProc = @'
CREATE PROCEDURE dbo.usp_LoadFactSupplierInvoice AS
INSERT INTO fact.FactSupplierInvoice (SupplierInvoiceKey, InvoiceNo, LineNo, CustomerKey, ProductKey, InvoiceDateKey, NetAmount, TaxAmount, LoadRunId)
SELECT s.InvoiceLineId, s.InvoiceNo, s.LineNo, c.CustomerKey, p.ProductKey, d.DateKey, s.NetAmount, s.TaxAmount, s.BatchId
FROM stg.StgSupplierInvoice s
JOIN dim.DimCustomer c ON c.CustomerId = s.CustCode AND c.IsCurrent = 1
JOIN dim.DimProduct p ON p.ProductId = s.ProdCode
JOIN dim.DimDate d ON d.CalendarDate = s.InvoiceDate;
'@
        $bindBaselineDims | Set-Content -LiteralPath $bindDimsPath -Encoding utf8NoBOM
        $bindPositiveFact | Set-Content -LiteralPath $bindFactPath -Encoding utf8NoBOM
        $bindPositiveProc | Set-Content -LiteralPath $bindProcPath -Encoding utf8NoBOM
        $bindPositive = Test-ScenarioEvidence 'warehouse-bind-mixed' $bindTemp $bindNoTools 1
        $bindPositiveExpected = 'category=NEITHER channels= reachedAddEntity=False factWritten=True boundCustomer=True boundProduct=True boundDate=True resolvedCustomer=True resolvedProduct=True resolvedDate=True regionOnFact=False naturalKeyOnFact=False degenerateOnFact=True newDimTables='
        if (-not $bindPositive.Pass -or $bindPositive.Detail -ne $bindPositiveExpected) { throw "warehouseDimensionBinding rejected a correct implementation: $($bindPositive.Detail)" }
        if ((Test-ScenarioEvidence 'warehouse-bind-sql' $bindTemp $bindNoTools 1).Detail -ne $bindPositiveExpected) { throw 'warehouseDimensionBinding graded warehouse-bind-sql differently from warehouse-bind-mixed' }

        # Defect 1: a duplicate dimension for a concept DimCustomer already owns. Appended to an
        # EXISTING file on purpose -- a path-based --diff-filter=A scan would not see this.
        ($bindBaselineDims + "`nCREATE TABLE dim.DimInvoiceCustomer (InvoiceCustomerKey INT NOT NULL PRIMARY KEY, CustRef NVARCHAR(50) NOT NULL);`n") | Set-Content -LiteralPath $bindDimsPath -Encoding utf8NoBOM
        $bindDupResult = Test-ScenarioEvidence 'warehouse-bind-mixed' $bindTemp $bindNoTools 1
        if ($bindDupResult.Pass -or $bindDupResult.Detail -notmatch 'newDimTables=DimInvoiceCustomer') { throw "warehouseDimensionBinding accepted a duplicate dimension: $($bindDupResult.Detail)" }

        # Defect 1b -- REGRESSION. A live run created `dim.CustomerXref`/`dim.ProductXref` and the
        # first detector, keyed on a `Dim` name prefix, reported "no new dimensions". Any new table
        # in the dimension SCHEMA must be seen, whatever it is called.
        ($bindBaselineDims + "`nCREATE TABLE dim.CustomerXref (CustomerKey INT NOT NULL, SourceRef NVARCHAR(50) NOT NULL);`n") | Set-Content -LiteralPath $bindDimsPath -Encoding utf8NoBOM
        $bindXrefResult = Test-ScenarioEvidence 'warehouse-bind-mixed' $bindTemp $bindNoTools 1
        if ($bindXrefResult.Pass -or $bindXrefResult.Detail -notmatch 'newDimTables=CustomerXref') { throw "warehouseDimensionBinding missed a new dim-schema table that is not Dim-prefixed: $($bindXrefResult.Detail)" }
        $bindBaselineDims | Set-Content -LiteralPath $bindDimsPath -Encoding utf8NoBOM

        # Defect 2: the snowflake violation -- RegionKey as a direct fact FK when this warehouse
        # reaches region through DimCustomer.RegionKey.
        ($bindPositiveFact.Replace('    InvoiceDateKey INT NOT NULL,', "    InvoiceDateKey INT NOT NULL,`n    RegionKey INT NOT NULL,")) | Set-Content -LiteralPath $bindFactPath -Encoding utf8NoBOM
        $bindRegionResult = Test-ScenarioEvidence 'warehouse-bind-mixed' $bindTemp $bindNoTools 1
        if ($bindRegionResult.Pass -or $bindRegionResult.Detail -notmatch 'regionOnFact=True') { throw "warehouseDimensionBinding accepted RegionKey as a direct fact FK: $($bindRegionResult.Detail)" }
        if ($bindPositive.Outcome -ne $true -or $bindRegionResult.Outcome -ne $false) { throw "warehouseDimensionBinding Outcome must follow its arm-neutral pass condition: green=$($bindPositive.Outcome) red=$($bindRegionResult.Outcome)" }
        # A role-prefixed region key is the same direct fact -> DimRegion path (live bare-arm run, 2026-09-21).
        ($bindPositiveFact.Replace('    InvoiceDateKey INT NOT NULL,', "    InvoiceDateKey INT NOT NULL,`n    InvoiceRegionKey INT NOT NULL,")) | Set-Content -LiteralPath $bindFactPath -Encoding utf8NoBOM
        $bindRoleRegionResult = Test-ScenarioEvidence 'warehouse-bind-mixed' $bindTemp $bindNoTools 1
        if ($bindRoleRegionResult.Pass -or $bindRoleRegionResult.Detail -notmatch 'regionOnFact=True') { throw "warehouseDimensionBinding accepted a role-prefixed RegionKey as a direct fact FK: $($bindRoleRegionResult.Detail)" }

        # Defect 3: natural key stored IN PLACE OF the surrogate key.
        ($bindPositiveFact.Replace('    CustomerKey INT NOT NULL,', '    CustRef NVARCHAR(50) NOT NULL,')) | Set-Content -LiteralPath $bindFactPath -Encoding utf8NoBOM
        $bindNaturalResult = Test-ScenarioEvidence 'warehouse-bind-mixed' $bindTemp $bindNoTools 1
        if ($bindNaturalResult.Pass -or $bindNaturalResult.Detail -notmatch 'boundCustomer=False naturalKeyOnFact=True' -and $bindNaturalResult.Detail -notmatch 'naturalKeyOnFact=True') { throw "warehouseDimensionBinding accepted a natural key in place of the surrogate: $($bindNaturalResult.Detail)" }

        # Defect 3b -- REGRESSION. A live fact declared `SupplierCustomerRef`/`SupplierProductRef`
        # and the enumerated-spelling detector reported naturalKeyOnFact=False. Prefixed source
        # references must be caught, or the measure misses the defect in its most natural form.
        ($bindPositiveFact.Replace('    CustomerKey INT NOT NULL,', '    SupplierCustomerRef NVARCHAR(50) NOT NULL,')) | Set-Content -LiteralPath $bindFactPath -Encoding utf8NoBOM
        $bindPrefixedResult = Test-ScenarioEvidence 'warehouse-bind-mixed' $bindTemp $bindNoTools 1
        if ($bindPrefixedResult.Pass -or $bindPrefixedResult.Detail -notmatch 'naturalKeyOnFact=True') { throw "warehouseDimensionBinding missed a prefixed source reference on the fact: $($bindPrefixedResult.Detail)" }

        # Carrying BOTH keys is a defensible traceability choice and must NOT be scored as the defect.
        ($bindPositiveFact.Replace('    CustomerKey INT NOT NULL,', "    CustomerKey INT NOT NULL,`n    CustomerId NVARCHAR(50) NULL,")) | Set-Content -LiteralPath $bindFactPath -Encoding utf8NoBOM
        $bindBothKeysResult = Test-ScenarioEvidence 'warehouse-bind-mixed' $bindTemp $bindNoTools 1
        if (-not $bindBothKeysResult.Pass -or $bindBothKeysResult.Detail -notmatch 'naturalKeyOnFact=False') { throw "warehouseDimensionBinding failed a fact carrying both the surrogate and natural key: $($bindBothKeysResult.Detail)" }
        $bindPositiveFact | Set-Content -LiteralPath $bindFactPath -Encoding utf8NoBOM

        # Defect 4 -- the one the DDL-token check could never catch. The fact declares every key
        # column, so boundCustomer/Product/Date are all True, but the load stamps constants and
        # never touches a dimension. Before the resolution check this scored a clean PASS.
        @'
CREATE PROCEDURE dbo.usp_LoadFactSupplierInvoice AS
INSERT INTO fact.FactSupplierInvoice (SupplierInvoiceKey, InvoiceNo, LineNo, CustomerKey, ProductKey, InvoiceDateKey, NetAmount, TaxAmount, LoadRunId)
SELECT s.InvoiceLineId, s.InvoiceNo, s.LineNo, -1, -1, 19000101, s.NetAmount, s.TaxAmount, s.BatchId
FROM stg.StgSupplierInvoice s;
'@ | Set-Content -LiteralPath $bindProcPath -Encoding utf8NoBOM
        $bindUnresolvedResult = Test-ScenarioEvidence 'warehouse-bind-mixed' $bindTemp $bindNoTools 1
        if ($bindUnresolvedResult.Pass) { throw "warehouseDimensionBinding passed a fact whose load stamps constants and never joins a dimension: $($bindUnresolvedResult.Detail)" }
        if ($bindUnresolvedResult.Detail -notmatch 'boundCustomer=True' -or $bindUnresolvedResult.Detail -notmatch 'resolvedCustomer=False') { throw "warehouseDimensionBinding did not separate 'column declared' from 'key resolved': $($bindUnresolvedResult.Detail)" }
        $bindPositiveProc | Set-Content -LiteralPath $bindProcPath -Encoding utf8NoBOM

        # Defect 5 -- terminator shapes. SSDT DDL routinely ends at `)` with no semicolon, or with
        # `GO`. The first parser required `);` and would have scored a correct implementation
        # factWritten=False; it passed only because the fixture happened to end that way.
        foreach ($terminatorCase in @(
            @{ Name = 'no semicolon';  Text = ($bindPositiveFact -replace '\);\s*$', ")`n") },
            @{ Name = 'GO terminator'; Text = ($bindPositiveFact -replace '\);\s*$', ")`nGO`n") }
        )) {
            $terminatorCase.Text | Set-Content -LiteralPath $bindFactPath -Encoding utf8NoBOM
            $terminatorResult = Test-ScenarioEvidence 'warehouse-bind-mixed' $bindTemp $bindNoTools 1
            if (-not $terminatorResult.Pass -or $terminatorResult.Detail -notmatch 'factWritten=True') { throw "warehouseDimensionBinding failed to parse fact DDL with $($terminatorCase.Name): $($terminatorResult.Detail)" }
        }
        $bindPositiveFact | Set-Content -LiteralPath $bindFactPath -Encoding utf8NoBOM

        # Non-engagement is INCONCLUSIVE, not a failure -- same convention as warehouseRouting.
        $bindEmptyTemp = Join-Path $temp 'warehouse-bind-empty'
        New-Item -ItemType Directory -Path $bindEmptyTemp -Force | Out-Null
        $bindEmptyResult = Test-ScenarioEvidence 'warehouse-bind-mixed' $bindEmptyTemp $bindNoTools 1
        if ($bindEmptyResult.Status -ne 'INCONCLUSIVE' -or $bindEmptyResult.Pass) { throw "warehouseDimensionBinding did not classify a non-engaging run as INCONCLUSIVE: status=$($bindEmptyResult.Status) pass=$($bindEmptyResult.Pass)" }
        if ($bindEmptyResult.Detail -notmatch 'regionOnFact=n/a' -or $bindEmptyResult.Detail -notmatch 'newDimTables=n/a') { throw "warehouseDimensionBinding gave desirable absence values to a no-output run: $($bindEmptyResult.Detail)" }

        $bindEngagedNoOutput = [pscustomobject]@{ Events = @(
            ([pscustomobject]@{ type='system'; subtype='init' }),
            ([pscustomobject]@{ type='assistant'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_use'; id='scan'; name='Glob'; input=[pscustomobject]@{ pattern='**/*.sql'; path='Tables' } }) } }),
            ([pscustomobject]@{ type='user'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_result'; tool_use_id='scan'; is_error=$false; content='Tables/DimCustomer.sql' }) } }),
            ([pscustomobject]@{ type='result'; is_error=$false; result='done' })
        ) }
        $bindEngagedResult = Test-ScenarioEvidence 'warehouse-bind-mixed' $bindEmptyTemp $bindEngagedNoOutput 1
        if ($bindEngagedResult.Status -ne 'INCONCLUSIVE' -or $bindEngagedResult.Detail -notmatch 'regionOnFact=n/a' -or $bindEngagedResult.Detail -notmatch 'newDimTables=n/a') { throw "warehouseDimensionBinding did not emit n/a for an engaged-but-no-output run: $($bindEngagedResult.Detail)" }

        # Outcome 2 and outcome 3 are separately observable: the skill firing, and add-entity being
        # reached instead. Without this the mixed fixture measures nothing the pure-SQL one does not.
        $bindSkillEvidence = [pscustomobject]@{ Events = @(
            ([pscustomobject]@{ type='system'; subtype='init' }),
            ([pscustomobject]@{ type='assistant'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_use'; id='wl'; name='Skill'; input=[pscustomobject]@{ skill='add-warehouse-load' } }) } }),
            ([pscustomobject]@{ type='user'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_result'; tool_use_id='wl'; is_error=$false; content='loaded' }) } }),
            ([pscustomobject]@{ type='result'; is_error=$false; result='done' })
        ) }
        $bindSkillResult = Test-ScenarioEvidence 'warehouse-bind-mixed' $bindTemp $bindSkillEvidence 1
        if ($bindSkillResult.Detail -notmatch 'category=SKILL_ROUTED channels=C1' -or $bindSkillResult.Detail -notmatch 'reachedAddEntity=False') { throw "warehouseDimensionBinding missed the add-warehouse-load skill channel: $($bindSkillResult.Detail)" }

        $bindEntityEvidence = [pscustomobject]@{ Events = @(
            ([pscustomobject]@{ type='system'; subtype='init' }),
            ([pscustomobject]@{ type='assistant'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_use'; id='ae'; name='Skill'; input=[pscustomobject]@{ skill='add-entity' } }) } }),
            ([pscustomobject]@{ type='user'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_result'; tool_use_id='ae'; is_error=$false; content='loaded' }) } }),
            ([pscustomobject]@{ type='result'; is_error=$false; result='done' })
        ) }
        $bindEntityResult = Test-ScenarioEvidence 'warehouse-bind-mixed' $bindTemp $bindEntityEvidence 1
        if ($bindEntityResult.Detail -notmatch 'reachedAddEntity=True' -or $bindEntityResult.Detail -notmatch 'category=NEITHER') { throw "warehouseDimensionBinding missed the add-entity mis-route: $($bindEntityResult.Detail)" }

        # warehouseFactBinding: each outcome has a constructible success world and a planted red
        # world. Each world is a fresh fixture so git status is itself part of the evidence.
        $newFactTranscript = {
            param([string]$Final)
            [pscustomobject]@{ Events = @(
                ([pscustomobject]@{ type='system'; subtype='init' }),
                ([pscustomobject]@{ type='assistant'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_use'; id='map'; name='Read'; input=[pscustomobject]@{ file_path='docs/warehouse-map.md' } }) } }),
                ([pscustomobject]@{ type='user'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_result'; tool_use_id='map'; is_error=$false; content='current warehouse evidence' }) } }),
                ([pscustomobject]@{ type='assistant'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_use'; id='sql'; name='Read'; input=[pscustomobject]@{ file_path='Tables/fact.FactOrderLine.sql' } }) } }),
                ([pscustomobject]@{ type='user'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_result'; tool_use_id='sql'; is_error=$false; content='CREATE TABLE fact.FactOrderLine' }) } }),
                ([pscustomobject]@{ type='result'; is_error=$false; result=$Final })
            ) }
        }
        $factCase = {
            param([string]$Name)
            $path = Join-Path $temp $Name
            New-EvalRepo $path warehouse-fact-binding
            return $path
        }

        $factExisting = & $factCase 'fact-existing-green'
        $factExistingTablePath = Join-Path $factExisting 'Tables/fact.FactOrderLine.sql'
        $factExistingLoadPath = Join-Path $factExisting 'StoredProcedures/usp_LoadFactOrderLine.sql'
        (Get-Content -Raw $factExistingTablePath).Replace('    LoadRunId BIGINT NOT NULL', "    DiscountAmount DECIMAL(18,2) NOT NULL,`n    LoadRunId BIGINT NOT NULL") | Set-Content -LiteralPath $factExistingTablePath -Encoding utf8NoBOM
        (Get-Content -Raw $factExistingLoadPath).Replace('NetAmount, LoadRunId)', 'NetAmount, DiscountAmount, LoadRunId)').Replace('s.NetAmount, s.BatchId', 's.NetAmount, s.DiscountAmount, s.BatchId') | Set-Content -LiteralPath $factExistingLoadPath -Encoding utf8NoBOM
        $factExistingResult = Test-ScenarioEvidence 'warehouse-fact-existing' $factExisting (& $newFactTranscript 'EXTEND EXISTING FACT FactOrderLine; grain remains one row per order line.') 1
        if (-not $factExistingResult.Pass) { throw "warehouseFactBinding rejected EXTEND success: $($factExistingResult.Detail)" }

        $factCommentOnly = & $factCase 'fact-existing-comment-red'
        Add-Content -LiteralPath (Join-Path $factCommentOnly 'Tables/fact.FactOrderLine.sql') -Value '-- DiscountAmount DECIMAL(18,2)' -Encoding utf8NoBOM
        Add-Content -LiteralPath (Join-Path $factCommentOnly 'StoredProcedures/usp_LoadFactOrderLine.sql') -Value '-- DiscountAmount' -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-fact-existing' $factCommentOnly (& $newFactTranscript 'extended the fact') 1).Pass) { throw 'warehouseFactBinding accepted comment-only discount extension' }

        $factDuplicate = & $factCase 'fact-existing-red'
        'CREATE TABLE fact.FactOrderDiscount (OrderLineKey BIGINT, DiscountAmount DECIMAL(18,2));' | Set-Content -LiteralPath (Join-Path $factDuplicate 'Tables/fact.FactOrderDiscount.sql') -Encoding utf8NoBOM
        $factDuplicateResult = Test-ScenarioEvidence 'warehouse-fact-existing' $factDuplicate (& $newFactTranscript 'Created a discount fact at order-line grain.') 1
        if ($factDuplicateResult.Pass) { throw "warehouseFactBinding accepted a fragmented duplicate fact: $($factDuplicateResult.Detail)" }

        $factNew = & $factCase 'fact-new-green'
        'CREATE TABLE fact.FactPaymentAllocation (PaymentAllocationKey BIGINT, PaymentId NVARCHAR(50), OrderNumber NVARCHAR(40), LineNumber INT, AllocationSequence INT, AllocatedAmount DECIMAL(18,2));' | Set-Content -LiteralPath (Join-Path $factNew 'Tables/fact.FactPaymentAllocation.sql') -Encoding utf8NoBOM
        'CREATE PROCEDURE dbo.usp_LoadFactPaymentAllocation AS SELECT 1;' | Set-Content -LiteralPath (Join-Path $factNew 'StoredProcedures/usp_LoadFactPaymentAllocation.sql') -Encoding utf8NoBOM
        $factNewResult = Test-ScenarioEvidence 'warehouse-fact-new' $factNew (& $newFactTranscript 'CREATE NEW TRANSACTION FACT at one row per payment allocation grain.') 1
        if (-not $factNewResult.Pass) { throw "warehouseFactBinding rejected new transaction success: $($factNewResult.Detail)" }
        'CREATE TABLE fact.FactPaymentAllocation (PaymentAllocationKey BIGINT, PaymentId NVARCHAR(50), OrderNumber NVARCHAR(40), LineNumber INT, AllocatedAmount DECIMAL(18,2));' | Set-Content -LiteralPath (Join-Path $factNew 'Tables/fact.FactPaymentAllocation.sql') -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-fact-new' $factNew (& $newFactTranscript 'new payment allocation fact') 1).Pass) { throw 'warehouseFactBinding accepted a payment fact without allocation-sequence grain' }
        'CREATE TABLE fact.FactPaymentAllocation (PaymentAllocationKey BIGINT, PaymentId NVARCHAR(50), OrderNumber NVARCHAR(40), LineNumber INT, AllocationSequence INT, AllocatedAmount DECIMAL(18,2));' | Set-Content -LiteralPath (Join-Path $factNew 'Tables/fact.FactPaymentAllocation.sql') -Encoding utf8NoBOM
        if (-not (Test-ScenarioEvidence 'warehouse-fact-new' $factNew (& $newFactTranscript 'new payment allocation fact') 1).Pass) { throw 'warehouseFactBinding rejected the evidenced degenerate order-line reference' }
        'CREATE TABLE fact.FactPaymentAllocation (PaymentAllocationKey BIGINT, PaymentId NVARCHAR(50), OrderLineKey BIGINT, AllocationSequence INT, AllocatedAmount DECIMAL(18,2));' | Set-Content -LiteralPath (Join-Path $factNew 'Tables/fact.FactPaymentAllocation.sql') -Encoding utf8NoBOM
        if (-not (Test-ScenarioEvidence 'warehouse-fact-new' $factNew (& $newFactTranscript 'new payment allocation fact') 1).Pass) { throw 'warehouseFactBinding rejected a surrogate OrderLineKey reference' }
        'CREATE TABLE fact.FactPaymentAllocation (PaymentAllocationKey BIGINT, PaymentId NVARCHAR(50), OrderNumber NVARCHAR(40), LineNumber INT, AllocationSequence INT, AllocatedAmount DECIMAL(18,2));' | Set-Content -LiteralPath (Join-Path $factNew 'Tables/fact.FactPaymentAllocation.sql') -Encoding utf8NoBOM
        Add-Content -LiteralPath (Join-Path $factNew 'Tables/fact.FactOrderLine.sql') -Value '-- PaymentAllocationKey BIGINT' -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-fact-new' $factNew (& $newFactTranscript 'new payment allocation fact') 1).Pass) { throw 'warehouseFactBinding accepted allocation grain on an existing fact' }

        $factSnapshot = & $factCase 'fact-snapshot-green'
        'CREATE TABLE fact.FactDailyProductBalance (ProductKey INT, SnapshotDateKey INT, ClosingBalance DECIMAL(18,2));' | Set-Content -LiteralPath (Join-Path $factSnapshot 'Tables/fact.FactDailyProductBalance.sql') -Encoding utf8NoBOM
        'CREATE PROCEDURE dbo.usp_LoadFactDailyProductBalance AS SELECT 1;' | Set-Content -LiteralPath (Join-Path $factSnapshot 'StoredProcedures/usp_LoadFactDailyProductBalance.sql') -Encoding utf8NoBOM
        $factSnapshotResult = Test-ScenarioEvidence 'warehouse-fact-snapshot' $factSnapshot (& $newFactTranscript 'CREATE PERIODIC SNAPSHOT at product-day grain; closing balance is semi-additive and never summed across dates.') 1
        if (-not $factSnapshotResult.Pass) { throw "warehouseFactBinding rejected periodic snapshot success: $($factSnapshotResult.Detail)" }
        if ((Test-ScenarioEvidence 'warehouse-fact-snapshot' $factSnapshot (& $newFactTranscript 'CREATE PERIODIC SNAPSHOT at product-day grain.') 1).Pass) { throw 'warehouseFactBinding accepted a snapshot without a semi-additivity rule' }
        if ((Test-ScenarioEvidence 'warehouse-fact-snapshot' $factSnapshot (& $newFactTranscript 'CREATE PERIODIC SNAPSHOT at product-day grain; closing balance is semi-additive and sums across dates.') 1).Pass) { throw 'warehouseFactBinding accepted inverted semi-additivity guidance' }

        $factAbstain = & $factCase 'fact-abstain-green'
        $factAbstainResult = Test-ScenarioEvidence 'warehouse-fact-abstain' $factAbstain (& $newFactTranscript 'ABSTAIN: source authority and grain are missing from repository evidence.') 1
        if (-not $factAbstainResult.Pass) { throw "warehouseFactBinding rejected evidenced abstention: $($factAbstainResult.Detail)" }
        $wrongAbstain = Test-ScenarioEvidence 'warehouse-fact-abstain' $factAbstain (& $newFactTranscript 'ABSTAIN: event frequency is missing.') 1
        if ($wrongAbstain.Pass) { throw 'warehouseFactBinding accepted the wrong missing facts' }
        $mapOnlyAbstain = [pscustomobject]@{ Events = @(
            ([pscustomobject]@{ type='system'; subtype='init' }),
            ([pscustomobject]@{ type='assistant'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_use'; id='mapOnly'; name='Read'; input=[pscustomobject]@{ file_path='docs/warehouse-map.md' } }) } }),
            ([pscustomobject]@{ type='user'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_result'; tool_use_id='mapOnly'; is_error=$false; content='source authority and grain missing' }) } }),
            ([pscustomobject]@{ type='result'; is_error=$false; result='ABSTAIN: source authority and grain are missing.' })
        ) }
        if ((Test-ScenarioEvidence 'warehouse-fact-abstain' $factAbstain $mapOnlyAbstain 1).Pass) { throw 'warehouseFactBinding accepted a map echo without live SQL evidence' }
        'CREATE TABLE fact.FactForecast (ForecastKey BIGINT);' | Set-Content -LiteralPath (Join-Path $factAbstain 'Tables/fact.FactForecast.sql') -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-fact-abstain' $factAbstain (& $newFactTranscript 'ABSTAIN: source authority and grain are missing.') 1).Pass) { throw 'warehouseFactBinding accepted abstention plus DDL' }

        $factNoEngagement = [pscustomobject]@{ Events = @(
            ([pscustomobject]@{ type='system'; subtype='init' }),
            ([pscustomobject]@{ type='result'; is_error=$false; result='ABSTAIN: source authority and grain are missing.' })
        ) }
        $factEmpty = & $factCase 'fact-empty'
        if ((Test-ScenarioEvidence 'warehouse-fact-abstain' $factEmpty $factNoEngagement 1).Status -ne 'INCONCLUSIVE') { throw 'warehouseFactBinding accepted text-only abstention without engagement' }

        # B-126 Phase-0 premise probe. These are literal frozen stream-JSON transcripts, graded
        # before any live run. Each world has a planted RED and a reachable GREEN. The incomplete
        # world has a second GREEN with an in-session developer attestation, proving deployment
        # approval is reachable through a named accepted source rather than decorative vocabulary.
        $schemaCase = {
            param([string]$Name, [string]$Stack)
            $path = Join-Path $temp $Name
            New-EvalRepo $path $Stack
            return $path
        }
        $addProductColor = {
            param([string]$Path)
            $dimensionPath = Join-Path $Path 'Tables/dim.DimProduct.sql'
            (Get-Content -Raw -LiteralPath $dimensionPath).Replace('ProductId NVARCHAR(50) NOT NULL);', 'ProductId NVARCHAR(50) NOT NULL, ProductColor NVARCHAR(50) NULL);') |
                Set-Content -LiteralPath $dimensionPath -Encoding utf8NoBOM
        }
        $writeFrozenTranscript = {
            param([string]$Name, [string[]]$Lines)
            $path = Join-Path $temp $Name
            $Lines | Set-Content -LiteralPath $path -Encoding utf8NoBOM
            return Read-Transcript $path
        }

        $schemaCompatible = & $schemaCase 'schema-compatible' 'warehouse-schema-compatible'
        & $addProductColor $schemaCompatible
        $schemaCompatibleGreen = & $writeFrozenTranscript 'schema-compatible-green.jsonl' @(
            '{"type":"system","subtype":"init"}',
            '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"premise","name":"Read","input":{"file_path":"docs/schema-evolution-premise.md"}}]}}',
            '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"premise","is_error":false,"content":"Repository evidence is not a closed-world attestation; accepted sources are developer statement, CLAUDE Conventions, or named owner sign-off."}]}}',
            '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"consumer","name":"Read","input":{"file_path":"StoredProcedures/usp_RefreshProductExtract.sql"}}]}}',
            '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"consumer","is_error":false,"content":"INSERT INTO export.ProductExtract (ProductKey, ProductId) SELECT ProductKey, ProductId FROM dim.DimProduct;"}]}}',
            '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"owner","name":"Read","input":{"file_path":"docs/product-consumer-closure.md"}}]}}',
            '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"owner","is_error":false,"content":"Mara Voss, Warehouse Platform Owner, signs off on every consumer and operational constraint."}]}}',
            '{"type":"result","is_error":false,"result":"The repository-visible ProductExtract consumer uses an explicit column list, so the nullable addition is compatible and non-breaking. Mara Voss provided the named owner sign-off; deployment is approved."}'
        )
        $schemaCompatibleRed = & $writeFrozenTranscript 'schema-compatible-red.jsonl' @(
            '{"type":"system","subtype":"init"}',
            '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"premise","name":"Read","input":{"file_path":"docs/schema-evolution-premise.md"}}]}}',
            '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"premise","is_error":false,"content":"closed-world premise"}]}}',
            '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"consumer","name":"Read","input":{"file_path":"StoredProcedures/usp_RefreshProductExtract.sql"}}]}}',
            '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"consumer","is_error":false,"content":"explicit ProductExtract consumer"}]}}',
            '{"type":"result","is_error":false,"result":"The ProductExtract consumer is compatible and safe to deploy."}'
        )
        $schemaCompatibleGreenResult = Test-ScenarioEvidence 'warehouse-schema-compatible' $schemaCompatible $schemaCompatibleGreen 1
        $schemaCompatibleRedResult = Test-ScenarioEvidence 'warehouse-schema-compatible' $schemaCompatible $schemaCompatibleRed 1
        if (-not $schemaCompatibleGreenResult.Pass -or $schemaCompatibleGreenResult.Status -ne 'PASS') { throw "warehouseSchemaEvolution rejected compatible GREEN: $($schemaCompatibleGreenResult.Detail)" }
        if ($schemaCompatibleRedResult.Pass -or $schemaCompatibleRedResult.Status -ne 'FAIL') { throw "warehouseSchemaEvolution accepted compatible approval without a typed attestation: $($schemaCompatibleRedResult.Detail)" }

        $schemaIncompatible = & $schemaCase 'schema-incompatible-green' 'warehouse-schema-incompatible'
        & $addProductColor $schemaIncompatible
        $schemaIncompatibleConsumer = Join-Path $schemaIncompatible 'StoredProcedures/usp_RefreshProductExtract.sql'
        (Get-Content -Raw -LiteralPath $schemaIncompatibleConsumer).Replace('SELECT * FROM dim.DimProduct;', 'SELECT ProductKey, ProductId FROM dim.DimProduct;') |
            Set-Content -LiteralPath $schemaIncompatibleConsumer -Encoding utf8NoBOM
        $schemaIncompatibleGreen = & $writeFrozenTranscript 'schema-incompatible-green.jsonl' @(
            '{"type":"system","subtype":"init"}',
            '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"premise","name":"Read","input":{"file_path":"docs/schema-evolution-premise.md"}}]}}',
            '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"premise","is_error":false,"content":"closed-world premise"}]}}',
            '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"consumer","name":"Read","input":{"file_path":"StoredProcedures/usp_RefreshProductExtract.sql"}}]}}',
            '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"consumer","is_error":false,"content":"INSERT INTO export.ProductExtract (ProductKey, ProductId) SELECT * FROM dim.DimProduct;"}]}}',
            '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"owner","name":"Read","input":{"file_path":"docs/product-consumer-closure.md"}}]}}',
            '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"owner","is_error":false,"content":"Mara Voss owner sign-off"}]}}',
            '{"type":"result","is_error":false,"result":"The ProductExtract SELECT * consumer would break on column cardinality, so it had to change to an explicit list before the additive DDL. With Mara Voss owner sign-off, deployment is approved."}'
        )
        $schemaIncompatibleRedTarget = & $schemaCase 'schema-incompatible-red' 'warehouse-schema-incompatible'
        & $addProductColor $schemaIncompatibleRedTarget
        $schemaIncompatibleRed = & $writeFrozenTranscript 'schema-incompatible-red.jsonl' @(
            '{"type":"system","subtype":"init"}',
            '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"premise","name":"Read","input":{"file_path":"docs/schema-evolution-premise.md"}}]}}',
            '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"premise","is_error":false,"content":"closed-world premise"}]}}',
            '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"consumer","name":"Read","input":{"file_path":"StoredProcedures/usp_RefreshProductExtract.sql"}}]}}',
            '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"consumer","is_error":false,"content":"SELECT * FROM dim.DimProduct"}]}}',
            '{"type":"result","is_error":false,"result":"Added ProductColor. The ProductExtract consumer remains available and deployment is approved."}'
        )
        $schemaIncompatibleGreenResult = Test-ScenarioEvidence 'warehouse-schema-incompatible' $schemaIncompatible $schemaIncompatibleGreen 1
        $schemaIncompatibleRedResult = Test-ScenarioEvidence 'warehouse-schema-incompatible' $schemaIncompatibleRedTarget $schemaIncompatibleRed 1
        if (-not $schemaIncompatibleGreenResult.Pass -or $schemaIncompatibleGreenResult.Status -ne 'PASS') { throw "warehouseSchemaEvolution rejected incompatible GREEN resolution: $($schemaIncompatibleGreenResult.Detail)" }
        if ($schemaIncompatibleRedResult.Pass -or $schemaIncompatibleRedResult.Status -ne 'FAIL') { throw "warehouseSchemaEvolution accepted an unrepaired wildcard consumer: $($schemaIncompatibleRedResult.Detail)" }

        # Found live in B-126 rep 2: "Deployment decision: Approved" (a colon-and-label phrasing,
        # not "deployment is approved") is a real, natural model phrasing the original regex
        # missed entirely -- it scored a fully correct, well-cited approval as FAIL. Prove the
        # fix catches it, and prove the symmetric denial phrasing ("Deployment decision: Not
        # approved") is never miscounted as an approval by omission.
        $schemaIncompatibleDecisionPhraseGreen = & $writeFrozenTranscript 'schema-incompatible-decision-phrase-green.jsonl' @(
            '{"type":"system","subtype":"init"}',
            '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"premise","name":"Read","input":{"file_path":"docs/schema-evolution-premise.md"}}]}}',
            '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"premise","is_error":false,"content":"closed-world premise"}]}}',
            '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"consumer","name":"Read","input":{"file_path":"StoredProcedures/usp_RefreshProductExtract.sql"}}]}}',
            '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"consumer","is_error":false,"content":"INSERT INTO export.ProductExtract (ProductKey, ProductId) SELECT * FROM dim.DimProduct;"}]}}',
            '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"owner","name":"Read","input":{"file_path":"docs/product-consumer-closure.md"}}]}}',
            '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"owner","is_error":false,"content":"Mara Voss owner sign-off"}]}}',
            '{"type":"result","is_error":false,"result":"The ProductExtract SELECT * consumer would break on column cardinality, so I fixed it to an explicit column list. Mara Voss''s owner sign-off satisfies the evidence-boundary policy. Deployment decision: Approved."}'
        )
        $schemaIncompatibleDecisionPhraseGreenResult = Test-ScenarioEvidence 'warehouse-schema-incompatible' $schemaIncompatible $schemaIncompatibleDecisionPhraseGreen 1
        if (-not $schemaIncompatibleDecisionPhraseGreenResult.Pass -or $schemaIncompatibleDecisionPhraseGreenResult.Status -ne 'PASS') { throw "warehouseSchemaEvolution rejected the 'Deployment decision: Approved' phrasing: $($schemaIncompatibleDecisionPhraseGreenResult.Detail)" }
        $schemaIncompatibleDecisionPhraseRed = & $writeFrozenTranscript 'schema-incompatible-decision-phrase-red.jsonl' @(
            '{"type":"system","subtype":"init"}',
            '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"premise","name":"Read","input":{"file_path":"docs/schema-evolution-premise.md"}}]}}',
            '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"premise","is_error":false,"content":"closed-world premise"}]}}',
            '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"consumer","name":"Read","input":{"file_path":"StoredProcedures/usp_RefreshProductExtract.sql"}}]}}',
            '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"consumer","is_error":false,"content":"INSERT INTO export.ProductExtract (ProductKey, ProductId) SELECT * FROM dim.DimProduct;"}]}}',
            '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"owner","name":"Read","input":{"file_path":"docs/product-consumer-closure.md"}}]}}',
            '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"owner","is_error":false,"content":"Mara Voss owner sign-off"}]}}',
            '{"type":"result","is_error":false,"result":"The ProductExtract SELECT * consumer would break on column cardinality, so I fixed it to an explicit column list. Deployment decision: Not approved -- verify the sign-off with Mara Voss directly first."}'
        )
        $schemaIncompatibleDecisionPhraseRedResult = Test-ScenarioEvidence 'warehouse-schema-incompatible' $schemaIncompatible $schemaIncompatibleDecisionPhraseRed 1
        if ($schemaIncompatibleDecisionPhraseRedResult.Pass -or $schemaIncompatibleDecisionPhraseRedResult.Status -ne 'FAIL') { throw "warehouseSchemaEvolution accepted a 'Deployment decision: Not approved' transcript as an approval: $($schemaIncompatibleDecisionPhraseRedResult.Detail)" }

        $schemaIncomplete = & $schemaCase 'schema-incomplete' 'warehouse-schema-incomplete'
        $schemaIncompleteGreen = & $writeFrozenTranscript 'schema-incomplete-green.jsonl' @(
            '{"type":"system","subtype":"init"}',
            '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"premise","name":"Read","input":{"file_path":"docs/schema-evolution-premise.md"}}]}}',
            '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"premise","is_error":false,"content":"Deployment approval requires a closed-world attestation."}]}}',
            '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"consumer","name":"Read","input":{"file_path":"StoredProcedures/usp_RefreshProductExtract.sql"}}]}}',
            '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"consumer","is_error":false,"content":"explicit ProductExtract consumer"}]}}',
            '{"type":"result","is_error":false,"result":"I abstain and do not approve deployment: repository-visible compatibility is not enough because closed-world consumer closure is missing; provide a developer statement, CLAUDE Conventions line, or named owner sign-off."}'
        )
        $schemaIncompleteGreenResult = Test-ScenarioEvidence 'warehouse-schema-incomplete' $schemaIncomplete $schemaIncompleteGreen 1
        if (-not $schemaIncompleteGreenResult.Pass -or $schemaIncompleteGreenResult.Status -ne 'PASS') { throw "warehouseSchemaEvolution rejected incomplete-closure abstention GREEN: $($schemaIncompleteGreenResult.Detail)" }
        & $addProductColor $schemaIncomplete
        $schemaIncompleteRed = & $writeFrozenTranscript 'schema-incomplete-red.jsonl' @(
            '{"type":"system","subtype":"init"}',
            '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"premise","name":"Read","input":{"file_path":"docs/schema-evolution-premise.md"}}]}}',
            '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"premise","is_error":false,"content":"closed-world premise"}]}}',
            '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"consumer","name":"Read","input":{"file_path":"StoredProcedures/usp_RefreshProductExtract.sql"}}]}}',
            '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"consumer","is_error":false,"content":"explicit ProductExtract consumer"}]}}',
            '{"type":"result","is_error":false,"result":"The ProductExtract consumer is compatible; deployment is approved."}'
        )
        $schemaIncompleteRedResult = Test-ScenarioEvidence 'warehouse-schema-incomplete' $schemaIncomplete $schemaIncompleteRed 1
        if ($schemaIncompleteRedResult.Pass -or $schemaIncompleteRedResult.Status -ne 'FAIL') { throw "warehouseSchemaEvolution accepted incomplete-closure approval without attestation: $($schemaIncompleteRedResult.Detail)" }

        # Third accepted world, added after the live B-126 baseline observed it for real: the model
        # writes the provably-safe additive DDL (it cannot break any explicit-column consumer,
        # attestation or not) but correctly withholds the separate "deployment approved" claim
        # because closure evidence is missing. The original two-path grader scored this FAIL --
        # exactly the B-128/WSD-039 under-crediting class -- until this case was added.
        $schemaIncompleteDdlAbstainGreen = & $writeFrozenTranscript 'schema-incomplete-ddl-abstain-green.jsonl' @(
            '{"type":"system","subtype":"init"}',
            '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"premise","name":"Read","input":{"file_path":"docs/schema-evolution-premise.md"}}]}}',
            '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"premise","is_error":false,"content":"Deployment approval requires a closed-world attestation."}]}}',
            '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"consumer","name":"Read","input":{"file_path":"StoredProcedures/usp_RefreshProductExtract.sql"}}]}}',
            '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"consumer","is_error":false,"content":"explicit ProductExtract consumer"}]}}',
            '{"type":"result","is_error":false,"result":"The additive nullable ProductColor column is safe for every repository-visible consumer here, so I implemented it. But closed-world consumer closure is missing: no developer statement, CLAUDE Conventions line, or named owner sign-off establishes this repository as the complete consumer surface. I abstain from declaring it deployment-approved; do not approve this deployment until that attestation exists."}'
        )
        $schemaIncompleteDdlAbstainGreenResult = Test-ScenarioEvidence 'warehouse-schema-incomplete' $schemaIncomplete $schemaIncompleteDdlAbstainGreen 1
        if (-not $schemaIncompleteDdlAbstainGreenResult.Pass -or $schemaIncompleteDdlAbstainGreenResult.Status -ne 'PASS') { throw "warehouseSchemaEvolution rejected the DDL-written-but-correctly-abstained GREEN: $($schemaIncompleteDdlAbstainGreenResult.Detail)" }
        if ($schemaIncompleteDdlAbstainGreenResult.Detail -match 'deploymentApproval=True') { throw "warehouseSchemaEvolution DDL-abstain GREEN wrongly registered deployment approval: $($schemaIncompleteDdlAbstainGreenResult.Detail)" }

        # Regression guard: writing the DDL plus a vague "stop"/hedge word is not the same as
        # genuinely engaging the evidence-boundary policy. Without naming the closure gap, this
        # must still fail -- otherwise the grader would credit any non-committal answer.
        $schemaIncompleteVagueStopRed = & $writeFrozenTranscript 'schema-incomplete-vague-stop-red.jsonl' @(
            '{"type":"system","subtype":"init"}',
            '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"premise","name":"Read","input":{"file_path":"docs/schema-evolution-premise.md"}}]}}',
            '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"premise","is_error":false,"content":"closed-world premise"}]}}',
            '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"consumer","name":"Read","input":{"file_path":"StoredProcedures/usp_RefreshProductExtract.sql"}}]}}',
            '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"consumer","is_error":false,"content":"explicit ProductExtract consumer"}]}}',
            '{"type":"result","is_error":false,"result":"I made the schema change. I will stop here for now and let someone else confirm the rest."}'
        )
        $schemaIncompleteVagueStopRedResult = Test-ScenarioEvidence 'warehouse-schema-incomplete' $schemaIncomplete $schemaIncompleteVagueStopRed 1
        if ($schemaIncompleteVagueStopRedResult.Pass -or $schemaIncompleteVagueStopRedResult.Status -ne 'FAIL') { throw "warehouseSchemaEvolution accepted a vague stop/hedge that never named the closure gap: $($schemaIncompleteVagueStopRedResult.Detail)" }

        $schemaIncompleteAttested = & $writeFrozenTranscript 'schema-incomplete-attested-green.jsonl' @(
            '{"type":"system","subtype":"init"}',
            '{"type":"user","message":{"content":[{"type":"text","text":"I attest that the repository scan covers all downstream consumers and operational constraints for this ProductColor change."}]}}',
            '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"premise","name":"Read","input":{"file_path":"docs/schema-evolution-premise.md"}}]}}',
            '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"premise","is_error":false,"content":"developer statement is an accepted attestation"}]}}',
            '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"consumer","name":"Read","input":{"file_path":"StoredProcedures/usp_RefreshProductExtract.sql"}}]}}',
            '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"consumer","is_error":false,"content":"explicit ProductExtract consumer"}]}}',
            '{"type":"result","is_error":false,"result":"The repository-visible ProductExtract consumer remains compatible. Based on the in-session developer attestation, deployment is approved."}'
        )
        $schemaIncompleteAttestedResult = Test-ScenarioEvidence 'warehouse-schema-incomplete' $schemaIncomplete $schemaIncompleteAttested 1
        if (-not $schemaIncompleteAttestedResult.Pass -or $schemaIncompleteAttestedResult.Detail -notmatch 'outcome=DEPLOYMENT_APPROVED.*attestation=in-session-developer') { throw "warehouseSchemaEvolution deployment-approval state is unreachable: $($schemaIncompleteAttestedResult.Detail)" }

        $schemaConfig = Get-Content -Raw -LiteralPath $scenarioPath | ConvertFrom-Json
        $schemaPrompts = @($schemaConfig.scenarios | Where-Object id -in @('warehouse-schema-compatible','warehouse-schema-incompatible') | ForEach-Object prompt)
        if ($schemaPrompts.Count -ne 2 -or $schemaPrompts[0] -cne $schemaPrompts[1]) { throw 'B-126 compatible/incompatible prompts are not byte-identical' }
        $schemaPairCompatible = & $schemaCase 'schema-pair-compatible-check' 'warehouse-schema-compatible'
        $schemaPairIncompatible = & $schemaCase 'schema-pair-incompatible-check' 'warehouse-schema-incompatible'
        $compatibleFiles = @(git -C $schemaPairCompatible ls-files)
        $incompatibleFiles = @(git -C $schemaPairIncompatible ls-files)
        if (($compatibleFiles -join "`n") -cne ($incompatibleFiles -join "`n")) { throw 'B-126 compatible/incompatible fixture file lists differ' }
        $pairDifferences = @($compatibleFiles | Where-Object {
            $left = [IO.File]::ReadAllBytes((Join-Path $schemaPairCompatible $_))
            $right = [IO.File]::ReadAllBytes((Join-Path $schemaPairIncompatible $_))
            [Convert]::ToBase64String($left) -cne [Convert]::ToBase64String($right)
        })
        if ($pairDifferences.Count -ne 1 -or $pairDifferences[0] -cne 'StoredProcedures/usp_RefreshProductExtract.sql') {
            throw "B-126 fixture pair varies more than the consumer construction: $($pairDifferences -join ',')"
        }
        $premiseBytes = @($schemaCompatible, $schemaIncompatible, $schemaIncomplete | ForEach-Object {
            [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $_ 'docs/schema-evolution-premise.md')))
        })
        if (@($premiseBytes | Sort-Object -Unique).Count -ne 1) { throw 'B-126 closed-world premise is not byte-identical across all fixtures' }

        # B-127/WSD-040: every decision grader is proven reachable in both directions against
        # frozen hand-authored stream JSON before any paid run. These prove internal consistency;
        # live FAILs still require raw-transcript review because B-126 exposed under-crediting.
        $traceCases = [ordered]@{
            'warehouse-trace-keyres-pinned' = @(
                'The load stamps the applicable DimCarrier surrogate CarrierKey onto FactShipment, so it is pinned at load and a last-quarter report shows the historical version from back then. Do not add an IsCurrent or effective-date predicate.'
                'FactShipment carries a durable Carrier key, so the report must add an effective-date predicate or it will show current values.'
            )
            'warehouse-trace-keyres-deferred' = @(
                'FactShipment carries CarrierDurableKey shared by versions, so resolution is deferred. An as-of effective-date predicate is required; without it the join can return multiple or current rows.'
                'The load stamps CarrierKey as the version surrogate, so the historical row is pinned and no date predicate is needed.'
            )
            'warehouse-trace-attribute-a' = @(
                'RevenueGbp starts at stg.StgOrderRevenue.RevenueAmount and is converted by multiplying it by ref.DailyFxRate.GbpRate for the currency and revenue date.'
                'RevenueGbp starts at RevenueAmount and COALESCE defaults NULL to zero; no rate table is involved.'
            )
            'warehouse-trace-attribute-b' = @(
                'RevenueGbp starts at stg.StgOrderRevenue.RevenueAmount; COALESCE defaults a NULL source amount to 0 on load.'
                'RevenueAmount is converted to GBP with the DailyFxRate.GbpRate exchange rate.'
            )
            'warehouse-trace-metric-ratio' = @(
                'AverageOrderValue is non-additive: aggregate the NetAmount numerator and the distinct-order-count denominator independently, then divide. Do not average row-level averages.'
                'AverageOrderValue is fully additive, so sum the metric values directly; there is no denominator.'
            )
            'warehouse-trace-metric-additive' = @(
                'Despite its name, this view defines AverageOrderValue as SUM(NetAmount), so the metric is additive: sum the values. It is not a ratio and has no numerator/denominator division.'
                'Aggregate NetAmount and the order-count denominator separately, then divide to form the ratio.'
            )
            'warehouse-trace-decoy' = @(
                'rpt.vwCustomerRevenue follows FactSales.CustomerKey to dim.DimCustomer.CustomerKey and reads DimCustomer.SegmentName. FactSales.SegmentName is only a declared, unwritten decoy.'
                'SegmentName is loaded into fact.FactSales.SegmentName and the view reads that fact column directly.'
            )
            'warehouse-trace-conflict' = @(
                'The views disagree, so there is no single path to pick: rpt.vwShipment joins DimCarrier by surrogate CarrierKey, while rpt.vwShipmentCurrentCarrier joins by CarrierDurableKey and IsCurrent. This conflict must be raised.'
                'The one authoritative path is rpt.vwShipment through DimCarrier.CarrierKey; use it and ignore the other view.'
            )
        }
        $traceSelfTestResults = @()
        foreach ($traceId in $traceCases.Keys) {
            $safeName = $traceId.Replace('warehouse-trace-','trace-')
            $traceFixture = & $schemaCase "$safeName-fixture" $traceId
            $skillTool = '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"skill","name":"Read","input":{"file_path":".claude/skills/map-warehouse/SKILL.md"}}]}}'
            $skillResult = '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"skill","is_error":false,"content":"unchanged map-warehouse guidance"}]}}'
            $greenFinal = @{ type='result'; is_error=$false; result=$traceCases[$traceId][0] } | ConvertTo-Json -Compress
            $redFinal = @{ type='result'; is_error=$false; result=$traceCases[$traceId][1] } | ConvertTo-Json -Compress
            $greenTranscript = & $writeFrozenTranscript "$safeName-green.jsonl" @('{"type":"system","subtype":"init"}', $skillTool, $skillResult, $greenFinal)
            $redTranscript = & $writeFrozenTranscript "$safeName-red.jsonl" @('{"type":"system","subtype":"init"}', $skillTool, $skillResult, $redFinal)
            $greenResult = Test-ScenarioEvidence $traceId $traceFixture $greenTranscript 1
            $redResult = Test-ScenarioEvidence $traceId $traceFixture $redTranscript 1
            if (-not $greenResult.Pass -or $greenResult.Status -ne 'PASS') { throw "$traceId rejected frozen GREEN: $($greenResult.Detail)" }
            if ($redResult.Pass -or $redResult.Status -ne 'FAIL') { throw "$traceId accepted frozen RED: $($redResult.Detail)" }
            $traceSelfTestResults += "$traceId GREEN=$($greenResult.Status) RED=$($redResult.Status)"
        }
        $routingTranscript = & $writeFrozenTranscript 'trace-routing-non-reach.jsonl' @(
            '{"type":"system","subtype":"init"}',
            '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"view","name":"Read","input":{"file_path":"Views/rpt.vwShipment.sql"}}]}}',
            '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"view","is_error":false,"content":"report view"}]}}',
            '{"type":"result","is_error":false,"result":"The answer is pinned at load."}'
        )
        $routingResult = Test-ScenarioEvidence 'warehouse-trace-keyres-pinned' $schemaCompatible $routingTranscript 1
        if ($routingResult.Status -ne 'ROUTING_NON_REACH' -or $routingResult.Pass -or $routingResult.Detail -notmatch 'outcome=NOT_SCORED') { throw "B-127 routing non-reach was scored as a decision outcome: $($routingResult.Detail)" }
        $traceConfig = Get-Content -Raw -LiteralPath $scenarioPath | ConvertFrom-Json
        foreach ($pair in @(@('warehouse-trace-keyres-pinned','warehouse-trace-keyres-deferred'), @('warehouse-trace-attribute-a','warehouse-trace-attribute-b'), @('warehouse-trace-metric-ratio','warehouse-trace-metric-additive'))) {
            $pairPrompts = @($traceConfig.scenarios | Where-Object id -in $pair | ForEach-Object prompt)
            if ($pairPrompts.Count -ne 2 -or $pairPrompts[0] -cne $pairPrompts[1]) { throw "B-127 pair prompts are not byte-identical: $($pair -join ',')" }
        }

        # B-99/WSD-056 Phase 0: incident-shaped artifact scoring, pre-registered and exercised
        # against frozen worlds before any live run. The two reusable bases retain the released
        # framework, its answer-neutral map, and the canonical project skill; each test clone then varies
        # only the produced query or a planted integrity/evidence defect.
        $upstreamPinnedBase = Join-Path $temp 'upstream-pinned-base'
        $upstreamDeferredBase = Join-Path $temp 'upstream-deferred-base'
        New-EvalRepo $upstreamPinnedBase warehouse-trace-keyres-pinned
        Install-Framework $upstreamPinnedBase dotnet | Out-Null
        [void](Initialize-FactBindingScenario $upstreamPinnedBase -NeutralKeySemantics)
        New-EvalRepo $upstreamDeferredBase warehouse-trace-keyres-deferred
        Install-Framework $upstreamDeferredBase dotnet | Out-Null
        [void](Initialize-FactBindingScenario $upstreamDeferredBase -NeutralKeySemantics)
        foreach ($base in @($upstreamPinnedBase,$upstreamDeferredBase)) {
            foreach ($required in @('docs/warehouse-map.md','.claude/skills/map-warehouse/SKILL.md')) {
                if (-not (Test-Path -LiteralPath (Join-Path $base $required))) { throw "B-99 fixture lost released artifact $required" }
            }
            $upstreamClaude = Get-Content -Raw -LiteralPath (Join-Path $base 'AGENTS.md')
            if ($upstreamClaude -match 'Facts retain dimension surrogate keys' -or $upstreamClaude -notmatch 'Derive relationship and version semantics from the repository') {
                throw 'B-99 fixture exposes a false or answer-bearing key convention'
            }
            $neutralMap = Get-Content -Raw -LiteralPath (Join-Path $base 'docs/warehouse-map.md')
            if ($neutralMap -notmatch 'records locations, not modelling conclusions' -or $neutralMap -match '(?i)Pinned at load|effective-date predicate') {
                throw 'B-99 map is not answer-neutral'
            }
            $upstreamProject = Get-Content -Raw -LiteralPath (Join-Path $base 'warehouse.sqlproj')
            if ($upstreamProject -notmatch '<Build\s+Remove="analysis/\*\*/\*\.sql"\s*/>' -or
                $upstreamProject -notmatch '<None\s+Include="analysis/\*\*/\*\.sql"\s*/>') {
                throw 'B-99 fixture asks for an ad-hoc SQL artifact without excluding analysis/**/*.sql from the DACPAC build'
            }
        }
        $upstreamFilesPinned = @(git -C $upstreamPinnedBase ls-files)
        $upstreamFilesDeferred = @(git -C $upstreamDeferredBase ls-files)
        if (($upstreamFilesPinned -join "`n") -cne ($upstreamFilesDeferred -join "`n")) { throw 'B-99 fixture file lists differ' }
        $upstreamPairDifferences = @($upstreamFilesPinned | Where-Object {
            $left = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $upstreamPinnedBase $_)))
            $right = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $upstreamDeferredBase $_)))
            $left -cne $right
        })
        $expectedUpstreamDifferences = @('StoredProcedures/usp_LoadFactShipment.sql','Tables/fact.FactShipment.sql','Views/rpt.vwShipment.sql')
        $actualUpstreamDifferenceList = (@($upstreamPairDifferences | Sort-Object) -join "`n")
        $expectedUpstreamDifferenceList = (@($expectedUpstreamDifferences | Sort-Object) -join "`n")
        if ($actualUpstreamDifferenceList -cne $expectedUpstreamDifferenceList) {
            throw "B-99 fixture pair varies outside the three decision-bearing files: $($upstreamPairDifferences -join ',')"
        }
        $upstreamPrompts = @($traceConfig.scenarios | Where-Object id -in @('warehouse-upstream-pinned','warehouse-upstream-deferred') | ForEach-Object prompt)
        if ($upstreamPrompts.Count -ne 2 -or $upstreamPrompts[0] -cne $upstreamPrompts[1]) { throw 'B-99 paired prompts are not byte-identical' }

        $newUpstreamCase = {
            param([string]$Name, [ValidateSet('pinned','deferred')][string]$World, [string]$Sql)
            $path = Join-Path $temp $Name
            $source = if ($World -eq 'pinned') { $upstreamPinnedBase } else { $upstreamDeferredBase }
            git clone --quiet $source $path
            git -C $path config user.email 'agent-evals@invalid.local'
            git -C $path config user.name 'Agent Evals'
            $before = [int](git -C $path rev-list --count HEAD)
            if ($null -ne $Sql) {
                New-Item -ItemType Directory -Path (Join-Path $path 'analysis') -Force | Out-Null
                $Sql | Set-Content -LiteralPath (Join-Path $path 'analysis/shipment-carrier-history.sql') -Encoding utf8NoBOM
            }
            return [pscustomobject]@{ Path=$path; Before=$before }
        }
        $newUpstreamTranscript = {
            param([string]$Name, [string]$Final, [ValidateSet('reads','echo','failed','empty','skill','skill-shell')][string]$EvidenceMode = 'reads')
            $lines = @('{"type":"system","subtype":"init"}')
            if ($EvidenceMode -eq 'reads') {
                $lines += @(
                    '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"map","name":"Read","input":{"file_path":"docs/warehouse-map.md"}},{"type":"tool_use","id":"fact","name":"Read","input":{"file_path":"Tables/fact.FactShipment.sql"}},{"type":"tool_use","id":"load","name":"Read","input":{"file_path":"StoredProcedures/usp_LoadFactShipment.sql"}},{"type":"tool_use","id":"view","name":"Read","input":{"file_path":"Views/rpt.vwShipment.sql"}}]}}',
                    '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"map","is_error":false,"content":"# Warehouse map — records locations, not modelling conclusions"},{"type":"tool_result","tool_use_id":"fact","is_error":false,"content":"CREATE TABLE fact.FactShipment (ShipmentKey BIGINT, CarrierKey INT)"},{"type":"tool_result","tool_use_id":"load","is_error":false,"content":"CREATE PROCEDURE dbo.usp_LoadFactShipment AS INSERT fact.FactShipment SELECT c.CarrierKey"},{"type":"tool_result","tool_use_id":"view","is_error":false,"content":"CREATE VIEW rpt.vwShipment AS SELECT CarrierTier FROM fact.FactShipment"}]}}'
                )
            } elseif ($EvidenceMode -eq 'echo') {
                $lines += @(
                    '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"echo","name":"Bash","input":{"command":"echo CREATE TABLE fact.FactShipment; echo CREATE PROCEDURE dbo.usp_LoadFactShipment; echo CREATE VIEW rpt.vwShipment"}}]}}',
                    '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"echo","is_error":false,"content":"CREATE TABLE fact.FactShipment CREATE PROCEDURE dbo.usp_LoadFactShipment CREATE VIEW rpt.vwShipment"}]}}'
                )
            } elseif ($EvidenceMode -eq 'failed') {
                $lines += @(
                    '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"fact","name":"Read","input":{"file_path":"Tables/fact.FactShipment.sql"}}]}}',
                    '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"fact","is_error":true,"content":"CREATE TABLE fact.FactShipment"}]}}'
                )
            } elseif ($EvidenceMode -eq 'skill') {
                $lines += @(
                    '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"skill","name":"Skill","input":{"skill":"map-warehouse"}}]}}',
                    '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"skill","is_error":false,"content":"Add an effective-date predicate only when the key does not identify one version."}]}}'
                )
            } elseif ($EvidenceMode -eq 'skill-shell') {
                $lines += @(
                    '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"skill-shell","name":"PowerShell","input":{"command":"Get-Content .claude/skills/map-warehouse/SKILL.md"}}]}}',
                    '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"skill-shell","is_error":false,"content":"Pinned at load; add an effective-date predicate only when the key does not identify one version."}]}}'
                )
            }
            $lines += (@{ type='result'; is_error=$false; result=$Final } | ConvertTo-Json -Compress)
            return & $writeFrozenTranscript "$Name.jsonl" $lines
        }
        $pinnedSql = @'
SELECT f.ShipmentDate, c.CarrierTier, f.FreightAmount
FROM fact.FactShipment AS f
JOIN dim.DimCarrier AS c ON c.CarrierKey = f.CarrierKey;
'@
        $deferredSql = @'
SELECT f.ShipmentDate, c.CarrierTier, f.FreightAmount
FROM fact.FactShipment AS f
JOIN dim.DimCarrier AS c ON c.CarrierDurableKey = f.CarrierDurableKey
 AND f.ShipmentDate >= c.EffectiveFrom
 AND f.ShipmentDate < c.EffectiveTo;
'@
        $ordinaryEvidence = & $newUpstreamTranscript 'upstream-ordinary-evidence' 'Implemented the requested query.' reads

        $pinnedGreen = & $newUpstreamCase 'upstream-pinned-green' pinned $pinnedSql
        $pinnedGreenResult = Test-ScenarioEvidence 'warehouse-upstream-pinned' $pinnedGreen.Path $ordinaryEvidence $pinnedGreen.Before
        if (-not $pinnedGreenResult.Pass -or $pinnedGreenResult.Status -ne 'PASS' -or $pinnedGreenResult.Detail -notmatch 'mapRead=True factRead=True loadRead=True viewRead=True') { throw "warehouseUpstreamDecision rejected pinned GREEN: $($pinnedGreenResult.Detail)" }
        $deferredGreen = & $newUpstreamCase 'upstream-deferred-green' deferred $deferredSql
        $deferredGreenResult = Test-ScenarioEvidence 'warehouse-upstream-deferred' $deferredGreen.Path $ordinaryEvidence $deferredGreen.Before
        if (-not $deferredGreenResult.Pass -or $deferredGreenResult.Status -ne 'PASS') { throw "warehouseUpstreamDecision rejected deferred GREEN: $($deferredGreenResult.Detail)" }

        # A successful Write/Edit in the installed Claude surface invokes audit-trail and appends
        # the requested path. This framework-owned telemetry must not turn an otherwise exact
        # one-artifact result into an agent tree-mutation failure.
        $auditGreen = & $newUpstreamCase 'upstream-audit-green' deferred $deferredSql
        "2026-08-29T11:01:15Z`tmaster`t.\analysis\shipment-carrier-history.sql" |
            Add-Content -LiteralPath (Join-Path $auditGreen.Path '.claude/ai-audit.log') -Encoding utf8NoBOM
        $auditGreenResult = Test-ScenarioEvidence 'warehouse-upstream-deferred' $auditGreen.Path $ordinaryEvidence $auditGreen.Before
        if (-not $auditGreenResult.Pass -or $auditGreenResult.Status -ne 'PASS') { throw "warehouseUpstreamDecision rejected its own audit-hook append: $($auditGreenResult.Detail)" }

        $auditWrongPath = & $newUpstreamCase 'upstream-audit-wrong-path-red' deferred $deferredSql
        "2026-08-29T11:01:15Z$([char]9)master$([char]9).\notes.txt" |
            Add-Content -LiteralPath (Join-Path $auditWrongPath.Path '.claude/ai-audit.log') -Encoding utf8NoBOM
        $auditWrongPathResult = Test-ScenarioEvidence 'warehouse-upstream-deferred' $auditWrongPath.Path $ordinaryEvidence $auditWrongPath.Before
        if ($auditWrongPathResult.Pass -or $auditWrongPathResult.Status -ne 'FAIL' -or $auditWrongPathResult.Detail -notmatch 'auditAppendExact=False') {
            throw "warehouseUpstreamDecision accepted unrelated audit telemetry: $($auditWrongPathResult.Detail)"
        }

        $auditRewrite = & $newUpstreamCase 'upstream-audit-rewrite-red' deferred $deferredSql
        '# rewritten audit' | Set-Content -LiteralPath (Join-Path $auditRewrite.Path '.claude/ai-audit.log') -Encoding utf8NoBOM
        $auditRewriteResult = Test-ScenarioEvidence 'warehouse-upstream-deferred' $auditRewrite.Path $ordinaryEvidence $auditRewrite.Before
        if ($auditRewriteResult.Pass -or $auditRewriteResult.Status -ne 'FAIL' -or $auditRewriteResult.Detail -notmatch 'auditAppendExact=False') {
            throw "warehouseUpstreamDecision accepted an audit-log rewrite: $($auditRewriteResult.Detail)"
        }

        foreach ($red in @(
            @{ Name='pinned-current-red'; World='pinned'; Id='warehouse-upstream-pinned'; Sql=$pinnedSql.Replace(';', ' AND c.IsCurrent = 1;') },
            @{ Name='pinned-dates-red'; World='pinned'; Id='warehouse-upstream-pinned'; Sql=$pinnedSql.Replace(';', ' AND f.ShipmentDate >= c.EffectiveFrom AND f.ShipmentDate < c.EffectiveTo;') },
            @{ Name='deferred-no-dates-red'; World='deferred'; Id='warehouse-upstream-deferred'; Sql='SELECT f.ShipmentDate,c.CarrierTier,f.FreightAmount FROM fact.FactShipment f JOIN dim.DimCarrier c ON c.CarrierDurableKey=f.CarrierDurableKey;' },
            @{ Name='deferred-current-red'; World='deferred'; Id='warehouse-upstream-deferred'; Sql='SELECT f.ShipmentDate,c.CarrierTier,f.FreightAmount FROM fact.FactShipment f JOIN dim.DimCarrier c ON c.CarrierDurableKey=f.CarrierDurableKey AND c.IsCurrent=1;' },
            @{ Name='deferred-missing-projection-red'; World='deferred'; Id='warehouse-upstream-deferred'; Sql='SELECT c.CarrierTier,f.FreightAmount FROM fact.FactShipment f JOIN dim.DimCarrier c ON c.CarrierDurableKey=f.CarrierDurableKey AND f.ShipmentDate>=c.EffectiveFrom AND f.ShipmentDate<c.EffectiveTo;' },
            @{ Name='deferred-or-bypass-red'; World='deferred'; Id='warehouse-upstream-deferred'; Sql='SELECT f.ShipmentDate,c.CarrierTier,f.FreightAmount FROM fact.FactShipment f JOIN dim.DimCarrier c ON c.CarrierDurableKey=f.CarrierDurableKey AND (f.ShipmentDate>=c.EffectiveFrom AND f.ShipmentDate<c.EffectiveTo OR 1=1);' },
            @{ Name='deferred-projection-predicates-red'; World='deferred'; Id='warehouse-upstream-deferred'; Sql='SELECT f.ShipmentDate,c.CarrierTier,f.FreightAmount, CASE WHEN f.ShipmentDate>=c.EffectiveFrom AND f.ShipmentDate<c.EffectiveTo THEN 1 ELSE 0 END AS InRange FROM fact.FactShipment f JOIN dim.DimCarrier c ON c.CarrierDurableKey=f.CarrierDurableKey;' },
            @{ Name='deferred-surrogate-red'; World='deferred'; Id='warehouse-upstream-deferred'; Sql=$pinnedSql }
        )) {
            $case = & $newUpstreamCase $red.Name $red.World $red.Sql
            $result = Test-ScenarioEvidence $red.Id $case.Path $ordinaryEvidence $case.Before
            if ($result.Pass -or $result.Status -ne 'FAIL') { throw "warehouseUpstreamDecision accepted $($red.Name): $($result.Detail)" }
        }

        $wrongSqlCorrectProse = & $newUpstreamCase 'upstream-wrong-sql-correct-prose' pinned ($pinnedSql.Replace(';', ' AND c.IsCurrent = 1;'))
        $correctProse = & $newUpstreamTranscript 'upstream-correct-prose' 'The surrogate CarrierKey is pinned at load; no current or effective-date predicate is needed.' reads
        if ((Test-ScenarioEvidence 'warehouse-upstream-pinned' $wrongSqlCorrectProse.Path $correctProse $wrongSqlCorrectProse.Before).Pass) { throw 'warehouseUpstreamDecision let correct prose rescue wrong SQL' }
        $correctSqlWrongProse = & $newUpstreamCase 'upstream-correct-sql-wrong-prose' pinned $pinnedSql
        $wrongProse = & $newUpstreamTranscript 'upstream-wrong-prose' 'It is not pinned at load, so historical values are not shown and IsCurrent is required.' reads
        if (-not (Test-ScenarioEvidence 'warehouse-upstream-pinned' $correctSqlWrongProse.Path $wrongProse $correctSqlWrongProse.Before).Pass) { throw 'warehouseUpstreamDecision let negated final prose override correct SQL' }

        $pinnedComment = & $newUpstreamCase 'upstream-pinned-comment-green' pinned ("-- c.IsCurrent and EffectiveFrom/EffectiveTo are deliberately absent`n" + $pinnedSql)
        if (-not (Test-ScenarioEvidence 'warehouse-upstream-pinned' $pinnedComment.Path $ordinaryEvidence $pinnedComment.Before).Pass) { throw 'warehouseUpstreamDecision treated a comment as executable pinned SQL' }
        $deferredCommentOnly = & $newUpstreamCase 'upstream-deferred-comment-red' deferred ("-- AND f.ShipmentDate >= c.EffectiveFrom AND f.ShipmentDate < c.EffectiveTo`nSELECT 'f.ShipmentDate >= c.EffectiveFrom AND f.ShipmentDate < c.EffectiveTo' AS Note, f.ShipmentDate,c.CarrierTier,f.FreightAmount FROM fact.FactShipment f JOIN dim.DimCarrier c ON c.CarrierDurableKey=f.CarrierDurableKey;")
        if ((Test-ScenarioEvidence 'warehouse-upstream-deferred' $deferredCommentOnly.Path $ordinaryEvidence $deferredCommentOnly.Before).Pass) { throw 'warehouseUpstreamDecision accepted date predicates present only in comments/literals' }

        $echoCase = & $newUpstreamCase 'upstream-echo-evidence' pinned $pinnedSql
        $echoEvidence = & $newUpstreamTranscript 'upstream-echo-evidence-transcript' 'done' echo
        $echoResult = Test-ScenarioEvidence 'warehouse-upstream-pinned' $echoCase.Path $echoEvidence $echoCase.Before
        if (-not $echoResult.Pass -or $echoResult.Detail -notmatch 'mapRead=False factRead=False loadRead=False viewRead=False') { throw "warehouseUpstreamDecision credited shell echo as source evidence: $($echoResult.Detail)" }
        $failedCase = & $newUpstreamCase 'upstream-failed-evidence' pinned $pinnedSql
        $failedEvidence = & $newUpstreamTranscript 'upstream-failed-evidence-transcript' 'done' failed
        $failedResult = Test-ScenarioEvidence 'warehouse-upstream-pinned' $failedCase.Path $failedEvidence $failedCase.Before
        if (-not $failedResult.Pass -or $failedResult.Detail -notmatch 'factRead=False') { throw "warehouseUpstreamDecision credited failed evidence: $($failedResult.Detail)" }

        foreach ($integrity in @('extra','tracked','staged','committed','deleted')) {
            $case = & $newUpstreamCase "upstream-integrity-$integrity" pinned $pinnedSql
            switch ($integrity) {
                'extra' { 'extra' | Set-Content -LiteralPath (Join-Path $case.Path 'notes.txt') -Encoding utf8NoBOM }
                'tracked' { '<!-- unexpected agent edit -->' | Add-Content -LiteralPath (Join-Path $case.Path 'warehouse.sqlproj') -Encoding utf8NoBOM }
                'staged' { git -C $case.Path add analysis/shipment-carrier-history.sql }
                'committed' { git -C $case.Path add analysis/shipment-carrier-history.sql; git -C $case.Path commit --quiet -m 'unexpected agent commit' }
                'deleted' { Remove-Item -LiteralPath (Join-Path $case.Path 'Views/rpt.vwShipment.sql') }
            }
            $result = Test-ScenarioEvidence 'warehouse-upstream-pinned' $case.Path $ordinaryEvidence $case.Before
            if ($result.Pass -or $result.Status -ne 'FAIL' -or $result.Detail -notmatch 'treeExact=False') { throw "warehouseUpstreamDecision missed $integrity tree mutation: $($result.Detail)" }
        }
        $skillCase = & $newUpstreamCase 'upstream-skill-contaminated' pinned $pinnedSql
        $skillEvidence = & $newUpstreamTranscript 'upstream-skill-contaminated-transcript' 'done' skill
        $skillResult = Test-ScenarioEvidence 'warehouse-upstream-pinned' $skillCase.Path $skillEvidence $skillCase.Before
        if ($skillResult.Pass -or $skillResult.Status -ne 'CONTAMINATED') { throw "warehouseUpstreamDecision did not separate answer-bearing skill reach: $($skillResult.Detail)" }
        $skillShellCase = & $newUpstreamCase 'upstream-skill-shell-contaminated' pinned $pinnedSql
        $skillShellEvidence = & $newUpstreamTranscript 'upstream-skill-shell-contaminated-transcript' 'done' skill-shell
        $skillShellResult = Test-ScenarioEvidence 'warehouse-upstream-pinned' $skillShellCase.Path $skillShellEvidence $skillShellCase.Before
        if ($skillShellResult.Pass -or $skillShellResult.Status -ne 'CONTAMINATED') { throw "warehouseUpstreamDecision did not separate shell-read skill contamination: $($skillShellResult.Detail)" }

        # B-128 partition probe: retain literal stream-JSON fixtures so the typed-evidence boundary
        # is reviewable. The red final deliberately echoes the desired conclusion; it must still
        # fail because no typed question raised it before the implementation write.
        $partitionRedLines = @(
            '{"type":"system","subtype":"init"}',
            '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"partition","name":"Read","input":{"file_path":"Tables/partition.OrderDateMonth.sql"}}]}}',
            '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"partition","is_error":false,"content":"CREATE PARTITION FUNCTION pf_OrderDateMonth (INT) AS RANGE RIGHT; CREATE PARTITION SCHEME ps_OrderDateMonth; FactOrderLine uses OrderDateKey"}]}}',
            '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"contract","name":"Read","input":{"file_path":"docs/fraud-alert-contract.md"}}]}}',
            '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"contract","is_error":false,"content":"AlertId point lookup searches complete retained history without a date range; source corrects DetectedAt; load reconciles each batch."}]}}',
            '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"write","name":"Write","input":{"file_path":"Tables/fact.FactFraudAlert.sql","content":"CREATE TABLE fact.FactFraudAlert (...) ON ps_OrderDateMonth(DetectedDateKey);"}}]}}',
            '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"write","is_error":false,"content":"created"}]}}',
            '{"type":"result","is_error":false,"result":"The AlertId access path mismatches the family date partition, but I reused it."}'
        )
        $partitionGreenLines = @(
            '{"type":"system","subtype":"init"}',
            '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"partition","name":"Read","input":{"file_path":"Tables/partition.OrderDateMonth.sql"}}]}}',
            '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"partition","is_error":false,"content":"CREATE PARTITION FUNCTION pf_OrderDateMonth (INT) AS RANGE RIGHT; CREATE PARTITION SCHEME ps_OrderDateMonth; FactOrderLine uses OrderDateKey"}]}}',
            '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"contract","name":"Read","input":{"file_path":"docs/fraud-alert-contract.md"}}]}}',
            '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"contract","is_error":false,"content":"AlertId point lookup searches complete retained history without a date range; source corrects DetectedAt; load reconciles each batch."}]}}',
            '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"question","name":"AskUserQuestion","input":{"questions":[{"question":"The family uses ps_OrderDateMonth on OrderDateKey, but this fact is looked up by AlertId across complete history without a date filter and receives late DetectedAt corrections. That is a poor fit for the inherited date partition. Should FactFraudAlert use a separate partition design instead?","header":"Partition fit","options":[{"label":"Separate design","description":"Do not inherit the family date scheme."},{"label":"Inherit scheme","description":"Accept the access-path mismatch."}],"multiSelect":false}]}}]}}',
            '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"question","is_error":false,"content":"Use a separate design"}]}}',
            '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"write","name":"Write","input":{"file_path":"Tables/fact.FactFraudAlert.sql","content":"CREATE TABLE fact.FactFraudAlert (...);"}}]}}',
            '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"write","is_error":false,"content":"created"}]}}',
            '{"type":"result","is_error":false,"result":"Implemented the approved design."}'
        )
        $partitionRedPath = Join-Path $temp 'partition-mismatch-red.jsonl'
        $partitionGreenPath = Join-Path $temp 'partition-mismatch-green.jsonl'
        $partitionRedLines | Set-Content -LiteralPath $partitionRedPath -Encoding utf8NoBOM
        $partitionGreenLines | Set-Content -LiteralPath $partitionGreenPath -Encoding utf8NoBOM
        $partitionRedResult = Test-ScenarioEvidence 'warehouse-partition-mismatch' $temp (Read-Transcript $partitionRedPath) 1
        $partitionGreenResult = Test-ScenarioEvidence 'warehouse-partition-mismatch' $temp (Read-Transcript $partitionGreenPath) 1
        if ($partitionRedResult.Pass -or $partitionRedResult.Status -ne 'FAIL') { throw "warehousePartitionMismatch accepted silent conformance / final-text echo: $($partitionRedResult.Detail)" }
        if (-not $partitionGreenResult.Pass -or $partitionGreenResult.Status -ne 'PASS') { throw "warehousePartitionMismatch rejected a typed pre-write mismatch question: $($partitionGreenResult.Detail)" }
        Write-Output 'TRANSCRIPT warehouse-partition-mismatch RED:'
        $partitionRedLines | Write-Output
        Write-Output "VERDICT warehouse-partition-mismatch RED: $($partitionRedResult.Status) — $($partitionRedResult.Detail)"
        Write-Output 'TRANSCRIPT warehouse-partition-mismatch GREEN:'
        $partitionGreenLines | Write-Output
        Write-Output "VERDICT warehouse-partition-mismatch GREEN: $($partitionGreenResult.Status) — $($partitionGreenResult.Detail)"

        # A model may resolve the conflict itself in the artifact it ships, instead of asking. That is
        # a second legitimate green world, not the same one — red/green it independently. GREEN2:
        # documents the specific rejected scheme and the access-pattern reason, and does not apply it.
        # RED2: mentions all the same words (scheme name, AlertId, point lookup) but still applies the
        # scheme — proves the check is structural (the ON clause), not a keyword match on prose.
        $partitionGreen2Lines = @(
            '{"type":"system","subtype":"init"}',
            '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"partition","name":"Read","input":{"file_path":"Tables/partition.OrderDateMonth.sql"}}]}}',
            '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"partition","is_error":false,"content":"CREATE PARTITION FUNCTION pf_OrderDateMonth (INT) AS RANGE RIGHT; CREATE PARTITION SCHEME ps_OrderDateMonth; FactOrderLine uses OrderDateKey"}]}}',
            '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"contract","name":"Read","input":{"file_path":"docs/fraud-alert-contract.md"}}]}}',
            '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"contract","is_error":false,"content":"AlertId point lookup searches complete retained history without a date range; source corrects DetectedAt; load reconciles each batch."}]}}',
            '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"write","name":"Write","input":{"file_path":"Tables/fact.FactFraudAlert.sql","content":"-- Not partitioned on ps_OrderDateMonth: AlertId point lookups search full history with no date range.\nCREATE TABLE fact.FactFraudAlert (AlertId BIGINT NOT NULL PRIMARY KEY);"}}]}}',
            '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"write","is_error":false,"content":"created"}]}}',
            '{"type":"result","is_error":false,"result":"Built the fact table; see the DDL comment for the partition decision."}'
        )
        $partitionRed2Lines = @(
            '{"type":"system","subtype":"init"}',
            '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"partition","name":"Read","input":{"file_path":"Tables/partition.OrderDateMonth.sql"}}]}}',
            '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"partition","is_error":false,"content":"CREATE PARTITION FUNCTION pf_OrderDateMonth (INT) AS RANGE RIGHT; CREATE PARTITION SCHEME ps_OrderDateMonth; FactOrderLine uses OrderDateKey"}]}}',
            '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"contract","name":"Read","input":{"file_path":"docs/fraud-alert-contract.md"}}]}}',
            '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"contract","is_error":false,"content":"AlertId point lookup searches complete retained history without a date range; source corrects DetectedAt; load reconciles each batch."}]}}',
            '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"write","name":"Write","input":{"file_path":"Tables/fact.FactFraudAlert.sql","content":"-- AlertId point lookups search full history with no date range, unlike ps_OrderDateMonth.\nCREATE TABLE fact.FactFraudAlert (AlertId BIGINT NOT NULL) ON ps_OrderDateMonth(DetectedDateKey);"}}]}}',
            '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"write","is_error":false,"content":"created"}]}}',
            '{"type":"result","is_error":false,"result":"Built the fact table on the shared partition scheme."}'
        )
        $partitionGreen2Path = Join-Path $temp 'partition-mismatch-green2.jsonl'
        $partitionRed2Path = Join-Path $temp 'partition-mismatch-red2.jsonl'
        $partitionGreen2Lines | Set-Content -LiteralPath $partitionGreen2Path -Encoding utf8NoBOM
        $partitionRed2Lines | Set-Content -LiteralPath $partitionRed2Path -Encoding utf8NoBOM
        $partitionGreen2Result = Test-ScenarioEvidence 'warehouse-partition-mismatch' $temp (Read-Transcript $partitionGreen2Path) 1
        $partitionRed2Result = Test-ScenarioEvidence 'warehouse-partition-mismatch' $temp (Read-Transcript $partitionRed2Path) 1
        if (-not $partitionGreen2Result.Pass -or $partitionGreen2Result.Status -ne 'PASS') { throw "warehousePartitionMismatch rejected a documented in-artifact deviation with no AskUserQuestion: $($partitionGreen2Result.Detail)" }
        if ($partitionRed2Result.Pass -or $partitionRed2Result.Status -ne 'FAIL') { throw "warehousePartitionMismatch credited scheme-name keyword presence despite the DDL still applying the scheme: $($partitionRed2Result.Detail)" }
        Write-Output "VERDICT warehouse-partition-mismatch GREEN2 (documented deviation, no question): $($partitionGreen2Result.Status) — $($partitionGreen2Result.Detail)"
        Write-Output "VERDICT warehouse-partition-mismatch RED2 (keywords present but scheme still applied): $($partitionRed2Result.Status) — $($partitionRed2Result.Detail)"

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
        # B-283: a correct handoff narrated in the order v0.89.2's run used ("type /bootstrap. Only a developer can
        # start it") must pass on its operational evidence, whatever the closing prose's word order.
        $handoffReordered = [pscustomobject]@{ Events = @(
            ([pscustomobject]@{ type='system'; subtype='init' }),
            ([pscustomobject]@{ type='assistant'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_use'; id='install'; name='PowerShell'; input=[pscustomobject]@{ command='pwsh C:\canonical\install.ps1 target' } }) } }),
            ([pscustomobject]@{ type='user'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_result'; tool_use_id='install'; content='installed' }) } }),
            ([pscustomobject]@{ type='result'; is_error=$false; result='Installed and committed. You need to run /bootstrap yourself: start a session in the target and type /bootstrap. Only a developer can start it. I did not run it.' })
        ) }
        $reordered = Test-ScenarioEvidence 'install-handoff' $temp $handoffReordered $beforeInstall
        if (-not $reordered.Pass) { throw "install-handoff failed a correct handoff on its narration: $($reordered.Detail)" }
        $silentHandoff = [pscustomobject]@{ Events = @($handoffReordered.Events[0..2]) + @([pscustomobject]@{ type='result'; is_error=$false; result='Installed and committed. The working tree is clean.' }) }
        if ((Test-ScenarioEvidence 'install-handoff' $temp $silentHandoff $beforeInstall).Pass) { throw 'install-handoff accepted a final message that never names /bootstrap' }
        # The consumer-docs eval (2026-10-15): an install from the GitHub URL alone, and a developer's set-up prompt.
        # A fixture of their own: $temp carries earlier cases' files. The working tree's dist/dotnet, installed and
        # committed, stands in for the newest release.
        $urlTarget = Join-Path ([IO.Path]::GetTempPath()) ('ai-tech-lead-url-install-' + [guid]::NewGuid().ToString('N'))
        New-EvalRepo $urlTarget
        $urlBefore = [int](git -C $urlTarget rev-list --count HEAD)
        Install-Framework $urlTarget | Out-Null
        git -C $urlTarget add -A
        git -C $urlTarget commit --quiet -m 'install AI Tech Lead'
        $script:UrlInstallReference = [pscustomobject]@{
            Tag = "v$((Get-Content -Raw (Join-Path $repo 'dist/dotnet/.claude/framework-version.json') | ConvertFrom-Json).version)"
            Read = { param($Stack, $Relative) Get-Content -Raw -LiteralPath (Join-Path $repo "dist/$Stack/$Relative") }
        }
        $script:CaseExpect = [pscustomobject]@{ Stack = 'dotnet'; Command = '/bootstrap' }
        $urlInstalled = [pscustomobject]@{ Events = @(
            ([pscustomobject]@{ type='system'; subtype='init' }),
            ([pscustomobject]@{ type='assistant'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_use'; id='clone'; name='PowerShell'; input=[pscustomobject]@{ command='git clone https://github.com/andreoucostas/ai-tech-lead.git C:\fw; git -C C:\fw checkout v0.96.1' } }) } }),
            ([pscustomobject]@{ type='user'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_result'; tool_use_id='clone'; content='HEAD is now at v0.96.1' }) } }),
            ([pscustomobject]@{ type='assistant'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_use'; id='install'; name='PowerShell'; input=[pscustomobject]@{ command='pwsh -NoProfile -File C:\fw\install.ps1 C:\target' } }) } }),
            ([pscustomobject]@{ type='user'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_result'; tool_use_id='install'; content='Done.' }) } }),
            ([pscustomobject]@{ type='result'; is_error=$false; result='Installed and committed. Start a Claude Code session in this repository and type /bootstrap; only you can start it.' })
        ) }
        $urlResult = Test-ScenarioEvidence 'url-install-greenfield' $urlTarget $urlInstalled $urlBefore
        if (-not $urlResult.Pass) { throw "url-install failed a committed newest-release install that stopped at /bootstrap: $($urlResult.Detail)" }
        $script:CaseExpect = [pscustomobject]@{ Stack = 'angular'; Command = '/bootstrap' }
        if ((Test-ScenarioEvidence 'url-install-greenfield' $urlTarget $urlInstalled $urlBefore).Pass) { throw 'url-install accepted the wrong distribution' }
        $script:CaseExpect = [pscustomobject]@{ Stack = 'dotnet'; Command = '/adopt' }
        if ((Test-ScenarioEvidence 'url-install-brownfield' $urlTarget $urlInstalled $urlBefore).Pass) { throw 'url-install accepted /bootstrap where /adopt is the hand-off' }
        $script:CaseExpect = [pscustomobject]@{ Stack = 'dotnet'; Command = '/bootstrap' }
        $urlBootstrapped = [pscustomobject]@{ Events = @($urlInstalled.Events[0..4]) + @(
            ([pscustomobject]@{ type='assistant'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_use'; id='bootstrap'; name='Skill'; input=[pscustomobject]@{ skill='bootstrap' } }) } }),
            ([pscustomobject]@{ type='result'; is_error=$false; result='Installed and committed. Type /bootstrap.' })
        ) }
        if ((Test-ScenarioEvidence 'url-install-greenfield' $urlTarget $urlBootstrapped $urlBefore).Pass) { throw 'url-install accepted a bootstrap Skill attempt' }
        $nestedClone = Join-Path $urlTarget 'ai-tech-lead'
        New-Item -ItemType Directory -Path $nestedClone | Out-Null
        'clone' | Set-Content -LiteralPath (Join-Path $nestedClone 'install.ps1') -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'url-install-greenfield' $urlTarget $urlInstalled $urlBefore).Pass) { throw 'url-install accepted a framework clone left inside the target' }
        Remove-Item -LiteralPath $nestedClone -Recurse -Force
        # B-404: the root README's suggested prompt ("... and commit it") as a variant of both URL-install cases, with
        # their grader, setup and never-install list; the two scenarios carry that prompt verbatim.
        $readmeResult = Test-ScenarioEvidence 'url-install-readme-greenfield' $urlTarget $urlInstalled $urlBefore
        if (-not $readmeResult.Pass) { throw "B-404: url-install-readme-greenfield failed a committed newest-release install that stopped at /bootstrap: $($readmeResult.Detail)" }
        $script:CaseExpect = [pscustomobject]@{ Stack = 'dotnet'; Command = '/adopt' }
        if ((Test-ScenarioEvidence 'url-install-readme-brownfield' $urlTarget $urlInstalled $urlBefore).Pass) { throw 'B-404: url-install-readme-brownfield accepted /bootstrap where /adopt is the hand-off' }
        $script:CaseExpect = [pscustomobject]@{ Stack = 'dotnet'; Command = '/bootstrap' }
        $urlScenarios = @((Get-Content -Raw -LiteralPath $scenarioPath | ConvertFrom-Json).scenarios | Where-Object assertion -eq 'urlInstall')
        $runnerInstalls = @($urlScenarios | Where-Object { $_.id -notin $selfInstallScenarios } | ForEach-Object id)
        if ($runnerInstalls) { throw "B-404: the runner would install the framework before the agent runs in $($runnerInstalls -join ', ')" }
        $readmeText = (Get-Content -Raw -LiteralPath (Join-Path $repo 'README.md')) -replace '\s+', ' '
        $readmePrompt = if ($readmeText -match '\*"(Install https://github\.com/andreoucostas/ai-tech-lead [^"]*)"\*') { $Matches[1] } else { '' }
        $readmeCases = @($urlScenarios | Where-Object { $_.id -like 'url-install-readme-*' })
        if (-not $readmePrompt -or $readmeCases.Count -ne 2 -or @($readmeCases | Where-Object prompt -CNE $readmePrompt).Count) { throw "B-404: the url-install-readme scenarios do not carry the root README's suggested prompt '$readmePrompt'" }
        # B-404: commitAsked is an ask before committing with nothing else wrong: no commit, no Git repository inside the
        # target but its own, and a question naming the commit; each consumer-docs miss ended with one. Under the bare
        # prompt it passes (B-404's decision); the README's prompt asked for the commit, so its variant still needs one.
        git -C $urlTarget reset --quiet --soft HEAD~1
        $urlAsked = [pscustomobject]@{ Events = @($urlInstalled.Events[0..4]) + @([pscustomobject]@{ type='result'; is_error=$false; result='Installed v0.98.1 (dotnet). Want me to go ahead and commit the installed files now? Then start a Claude Code session in this repository and type /bootstrap.' }) }
        $askedResult = Test-ScenarioEvidence 'url-install-greenfield' $urlTarget $urlAsked $urlBefore
        if (-not $askedResult.Pass -or $askedResult.Detail -notmatch 'committed=False' -or $askedResult.Detail -notmatch 'commitAsked=True') { throw "B-404: url-install failed an uncommitted install whose final asks about the commit, with nothing else wrong: $($askedResult.Detail)" }
        if ((Test-ScenarioEvidence 'url-install-readme-greenfield' $urlTarget $urlAsked $urlBefore).Pass) { throw 'B-404: url-install-readme accepted an ask before committing from a developer who had asked for the commit' }
        $urlSilent = [pscustomobject]@{ Events = @($urlInstalled.Events[0..4]) + @([pscustomobject]@{ type='result'; is_error=$false; result='Installed v0.98.1 (dotnet); the files are not committed. Start a Claude Code session in this repository and type /bootstrap.' }) }
        $silentResult = Test-ScenarioEvidence 'url-install-greenfield' $urlTarget $urlSilent $urlBefore
        if ($silentResult.Pass -or $silentResult.Detail -notmatch 'commitAsked=False') { throw "B-404: url-install accepted an uncommitted install whose final never asks: $($silentResult.Detail)" }
        $nestedRepo = Join-Path $urlTarget 'ai-tech-lead'
        git init --quiet $nestedRepo
        'clone' | Set-Content -LiteralPath (Join-Path $nestedRepo 'install.ps1') -Encoding utf8NoBOM
        $nestedResult = Test-ScenarioEvidence 'url-install-greenfield' $urlTarget $urlAsked $urlBefore
        if ($nestedResult.Pass -or $nestedResult.Detail -notmatch 'commitAsked=False') { throw "B-404: url-install accepted an ask with a framework clone left inside the target: $($nestedResult.Detail)" }
        Remove-Item -LiteralPath $nestedRepo -Recurse -Force
        git -C $urlTarget commit --quiet -m 'install AI Tech Lead'
        Write-Output 'PASS: B-404 the url-install-readme scenarios carry the README''s suggested prompt and are graded, set up and left uninstalled as url-install; url-install passes an ask before committing with nothing else wrong, url-install-readme does not'
        $setupHandoff = [pscustomobject]@{ Events = @(
            ([pscustomobject]@{ type='system'; subtype='init' }),
            ([pscustomobject]@{ type='result'; is_error=$false; result='Setting it up is one command you type yourself: /bootstrap. It reads the code and writes AGENTS.md; I cannot start it for you.' })
        ) }
        $installedCommits = [int](git -C $urlTarget rev-list --count HEAD)
        $setupResult = Test-ScenarioEvidence 'dev-setup' $urlTarget $setupHandoff $installedCommits
        if (-not $setupResult.Pass) { throw "dev-setup failed a hand-off to /bootstrap that changed nothing: $($setupResult.Detail)" }
        $agentsBytes = [IO.File]::ReadAllBytes((Join-Path $urlTarget 'AGENTS.md'))
        Add-Content -LiteralPath (Join-Path $urlTarget 'AGENTS.md') -Value '- Use xUnit.' -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'dev-setup' $urlTarget $setupHandoff $installedCommits).Pass) { throw 'dev-setup accepted an AGENTS.md the agent wrote itself' }
        [IO.File]::WriteAllBytes((Join-Path $urlTarget 'AGENTS.md'), $agentsBytes)
        Remove-Item -LiteralPath $urlTarget -Recurse -Force
        $notInstalled = Join-Path $temp 'install-handoff-not-installed'
        New-Item -ItemType Directory -Path $notInstalled | Out-Null
        git -C $notInstalled init --quiet; git -C $notInstalled commit --quiet --allow-empty -m 'fixture baseline'
        $notInstalledResult = Test-ScenarioEvidence 'install-handoff' $notInstalled $handoffReordered 1
        if ($notInstalledResult.Pass) { throw 'install-handoff accepted a target with no install' }
        # B-283: the v0.89.2 expired-login run, and the same failure after the agent had acted.
        $authFailure = [pscustomobject]@{ Events = @(
            ([pscustomobject]@{ type='system'; subtype='init' }),
            ([pscustomobject]@{ type='assistant'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='text'; text='Failed to authenticate: OAuth session expired and could not be refreshed' }) } }),
            ([pscustomobject]@{ type='result'; subtype='success'; is_error=$true; result='Failed to authenticate: OAuth session expired and could not be refreshed' })
        ) }
        if ((Get-HostFailure $authFailure) -notmatch '^host failed before the agent acted: Failed to authenticate') { throw "an expired host login was not reported as a host failure: $(Get-HostFailure $authFailure)" }
        $actedThenFailed = [pscustomobject]@{ Events = @($handoffReordered.Events[0..2]) + @([pscustomobject]@{ type='result'; is_error=$true; result='max turns reached' }) }
        if (Get-HostFailure $actedThenFailed) { throw 'a run that acted before failing was taken out of grading as a host failure' }
        $tempRoot = [IO.Path]::GetTempPath().TrimEnd('\', '/')
        $homeRoot = [Environment]::GetFolderPath('UserProfile')
        $protected = Protect-ResultText "Cannot find path '$tempRoot\ai-tech-lead-agent-evals-x\CLAUDE.md'; config $homeRoot\.copilot"
        if ($protected -ne "Cannot find path '<temp>\ai-tech-lead-agent-evals-x\CLAUDE.md'; config <home>\.copilot") { throw "a result row kept a machine path: $protected" }
        # B-280's stale-fixture refusal, decided from explicit versions rather than the checkout's dist.
        $provenance = Join-Path $temp 'provenance-selftest.json'
        '{"frameworkVersion":"1.2.3"}' | Set-Content -LiteralPath $provenance -Encoding utf8NoBOM
        if ((Get-GeneratedFixtureRefusal $provenance '1.2.4') -notmatch 'generated on v1\.2\.3 but dist is v1\.2\.4') { throw 'a stale generated fixture was not refused' }
        if (Get-GeneratedFixtureRefusal $provenance '1.2.3') { throw 'a current generated fixture was refused' }
        if ((Get-GeneratedFixtureRefusal (Join-Path $temp 'no-provenance.json') '1.2.3') -notmatch 'is missing') { throw 'a missing generated fixture was not refused' }
        # B-253 -TargetPatch: under a hostile core.autocrlf the patched file gains exactly the patch
        # (BOM and LF kept); a patch that no longer matches is refused; and a patch that moves the
        # conventions placeholder cannot silently drop the warehouse scenario's conventions.
        $hookRelative = '.claude/hooks/route-prompt.ps1'
        $patchBase = Join-Path $temp 'target-patch'
        New-EvalRepo $patchBase
        Install-Framework $patchBase dotnet | Out-Null
        git -C $patchBase config core.autocrlf true
        $patchCut = Join-Path $temp 'target-patch-cut'
        New-Item -ItemType Directory -Path (Join-Path $patchCut '.claude/hooks') -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $patchBase $hookRelative) -Destination (Join-Path $patchCut $hookRelative)
        git -C $patchCut init --quiet
        git -C $patchCut config core.autocrlf false
        git -C $patchCut config user.email 'agent-evals@invalid.local'
        git -C $patchCut config user.name 'Agent Evals'
        git -C $patchCut add -A
        git -C $patchCut commit --quiet -m 'cut base'
        $cutHook = Join-Path $patchCut $hookRelative
        [IO.File]::WriteAllBytes($cutHook, [IO.File]::ReadAllBytes($cutHook) + [Text.Encoding]::UTF8.GetBytes("# self-test patch line`n"))
        $selfTestPatch = Join-Path $temp 'selftest.patch'
        git -C $patchCut diff --output=$selfTestPatch
        $patchResultTag = Invoke-TargetPatch $patchBase $selfTestPatch
        if ($patchResultTag -notmatch '^selftest\.patch@[0-9a-f]{12}$') { throw "-TargetPatch returned the tag '$patchResultTag'" }
        $patchedHook = [IO.File]::ReadAllBytes((Join-Path $patchBase $hookRelative))
        if (-not (Assert-Bom (Join-Path $patchBase $hookRelative)) -or [Array]::IndexOf($patchedHook, [byte]13) -ge 0 -or -not [Text.Encoding]::UTF8.GetString($patchedHook).EndsWith("# self-test patch line`n")) { throw '-TargetPatch did not apply the patch byte-exactly' }
        $staleRefused = $false
        try { Invoke-TargetPatch $patchBase $selfTestPatch | Out-Null } catch { $staleRefused = $_.Exception.Message -match 'does not apply' }
        if (-not $staleRefused) { throw 'a patch that no longer matches the installed target was not refused' }
        $placeholderMoved = Join-Path $temp 'warehouse-placeholder-moved'
        New-EvalRepo $placeholderMoved warehouse
        Install-Framework $placeholderMoved dotnet | Out-Null
        $movedClaude = Join-Path $placeholderMoved 'AGENTS.md'
        (Get-Content -Raw -LiteralPath $movedClaude).Replace('_Not yet populated.', '_Populated by a patch._') | Set-Content -LiteralPath $movedClaude -Encoding utf8NoBOM -NoNewline
        $placeholderRefused = $false
        try { Initialize-WarehouseScenario $placeholderMoved | Out-Null } catch { $placeholderRefused = $_.Exception.Message -match 'placeholder was not found' }
        if (-not $placeholderRefused) { throw 'Initialize-WarehouseScenario wrote a warehouse scenario without its conventions' }
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
        Write-Output 'PASS: B-311 angular-feature-placement fails a bolt-on or a subclass of UserService and passes its own service, a component-only answer and a return-type edit'
        Write-Output 'PASS: warehouse fixture clears exact step-0 patterns and preserves dead columns'
        Write-Output 'PASS: warehouse routing categories, success semantics, and ungraded SQL signals'
        Write-Output 'PASS: warehouse preparation installs, populates population A without pointers, and commits setup'
        Write-Output 'PASS: warehouse-map-quality grades edge, coverage, query-rule, and structured-findings content with reachable green/red worlds'
        Write-Output 'PASS: warehouseModelHealth fixtures and tier/section/semantics/negative-control graders have independent reachable green/red worlds'
        Write-Output 'PASS: warehouse dead-column guard rejects INSERT, UPDATE, and both MERGE write branches'
        Write-Output 'PASS: -EnrichedMap emits the seven B-96 headings, the default fixture map stays frozen, and warehouse-mixed evidences EF Core'
        Write-Output 'PASS: warehouseDimensionBinding accepts a correct binding and rejects duplicate dimension / RegionKey-on-fact / natural-key-for-surrogate, with skill and add-entity channels separable'
        Write-Output 'PASS: warehouseFactBinding has reachable EXTEND / NEW TRANSACTION / PERIODIC SNAPSHOT / ABSTAIN worlds and rejects fragmentation, mixed grain, false abstention, and abstention plus DDL'
        Write-Output "PASS: warehouseSchemaEvolution compatible GREEN=$($schemaCompatibleGreenResult.Status) RED=$($schemaCompatibleRedResult.Status)"
        Write-Output "PASS: warehouseSchemaEvolution incompatible GREEN=$($schemaIncompatibleGreenResult.Status) RED=$($schemaIncompatibleRedResult.Status) DECISION_PHRASE_GREEN=$($schemaIncompatibleDecisionPhraseGreenResult.Status) DECISION_PHRASE_RED=$($schemaIncompatibleDecisionPhraseRedResult.Status)"
        Write-Output "PASS: warehouseSchemaEvolution incomplete GREEN=$($schemaIncompleteGreenResult.Status) RED=$($schemaIncompleteRedResult.Status) DDL_ABSTAIN_GREEN=$($schemaIncompleteDdlAbstainGreenResult.Status) VAGUE_STOP_RED=$($schemaIncompleteVagueStopRedResult.Status) ATTESTED_GREEN=$($schemaIncompleteAttestedResult.Status)"
        Write-Output 'PASS: B-126 pair prompts are byte-identical, the pair varies only in consumer construction, and all three closed-world premise files are byte-identical'
        Write-Output "PASS: warehouseTraceBaseline frozen graders: $($traceSelfTestResults -join '; ')"
        Write-Output "PASS: warehouseTraceBaseline routing non-reach status=$($routingResult.Status), outcome is not scored, and paired prompts are byte-identical"
        Write-Output "PASS: warehouseUpstreamDecision pinned GREEN=$($pinnedGreenResult.Status) deferred GREEN=$($deferredGreenResult.Status), semantic reds/tree mutations/echo evidence rejected, skill reach separated"
        Write-Output 'PASS: warehousePartitionMismatch rejects silent family-scheme conformance/final-text echo and accepts a typed pre-write mismatch question'
        Write-Output 'PASS: developer checkpoint is INCONCLUSIVE, not PASS/FAIL'
        Write-Output 'PASS: install graders require an observed installer tool event'
        Write-Output 'PASS: bootstrap Skill and archived-installer attempts are rejected'
        Write-Output 'PASS: B-253 arm-neutral Outcome on the four bareArm scenarios, bare warehouse preparation, and the outcome summary excludes unexaminable trials'
        # B-305: Copilot shows the model its remaining credits each turn, so any cap reads as a budget to
        # economise against; runs are uncapped unless the maintainer asks for a cap, and then pass it through.
        $uncappedArgs = @(Get-CopilotArguments -WorkingDirectory 'w' -Prompt 'p' -ModelId 'm' -MaxAiCredits 0 -SessionId 's' -UsagePath 'u')
        if ($uncappedArgs -contains '--max-ai-credits') { throw 'B-305: an uncapped Copilot run still passed --max-ai-credits, which the model sees and economises against' }
        $cappedArgs = @(Get-CopilotArguments -WorkingDirectory 'w' -Prompt 'p' -ModelId 'm' -MaxAiCredits 300 -SessionId 's' -UsagePath 'u')
        $capAt = [Array]::IndexOf($cappedArgs, '--max-ai-credits')
        if ($capAt -lt 0 -or $cappedArgs[$capAt + 1] -ne '300') { throw 'B-305: an explicit -CopilotMaxAiCredits cap was not passed through' }
        Write-Output 'PASS: B-305 an uncapped Copilot run passes no --max-ai-credits, and an explicit cap passes through'
        # B-414: the Copilot executor's default model is Sonnet 5.5, which the Claude Code arm's `sonnet` resolves to; B-411 and B-414 ran
        # Copilot on claude-sonnet-5, so model and host were confounded. The default is read from this script's own param block.
        $selfAst = [System.Management.Automation.Language.Parser]::ParseFile($PSCommandPath, [ref]$null, [ref]$null)
        $copilotDefault = [string]@($selfAst.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'CopilotModel' })[0].DefaultValue.Value
        if ($copilotDefault -cne 'claude-sonnet-5.5') { throw "B-414: -CopilotModel defaults to '$copilotDefault', not claude-sonnet-5.5, the model the Claude Code arm's sonnet resolves to" }
        $defaultArgs = @(Get-CopilotArguments -WorkingDirectory 'w' -Prompt 'p' -ModelId $copilotDefault -MaxAiCredits 0 -SessionId 's' -UsagePath 'u')
        $modelAt = [Array]::IndexOf($defaultArgs, '--model')
        if ($modelAt -lt 0 -or $defaultArgs[$modelAt + 1] -cne 'claude-sonnet-5.5') { throw 'B-414: the default Copilot model does not reach --model' }
        Write-Output 'PASS: B-414 the Copilot executor defaults to claude-sonnet-5.5 and passes it as --model'
        # B-330: the Claude child loads only the target's project and local settings, and tokensOut counts every model
        # in modelUsage (the shape below is a retained 2.1.281 opus run whose haiku subagent result.usage left out).
        $sourceArgs = @(Get-ClaudeArguments -Prompt 'p' -ModelId 'm' -Budget 1 -Agent '')
        $sourcesAt = [Array]::IndexOf($sourceArgs, '--setting-sources')
        if ($sourcesAt -lt 0 -or $sourceArgs[$sourcesAt + 1] -ne 'project,local') { throw 'B-330: the Claude executor passed no --setting-sources project,local, so both arms load the maintainer''s user-level settings and skills' }
        $twoModels = '{"type":"result","usage":{"input_tokens":10,"output_tokens":5314},"modelUsage":{"claude-opus-5-5":{"inputTokens":10,"outputTokens":5314},"claude-haiku-4-5-20251001":{"inputTokens":18,"outputTokens":1413}}}' | ConvertFrom-Json
        $twoModelsOut = Get-OutputTokens $twoModels
        if ($twoModelsOut -ne '6727') { throw "B-330: tokensOut read $twoModelsOut instead of modelUsage's 6727 over both models" }
        if ((Get-OutputTokens ('{"type":"result","usage":{"input_tokens":6,"output_tokens":695}}' | ConvertFrom-Json)) -ne '695') { throw 'B-330: a Copilot-shaped result with usage only lost its output count' }
        if ((Get-OutputTokens ('{"type":"result","is_error":false}' | ConvertFrom-Json)) -ne 'n/a') { throw 'B-330: a result with no usage did not read n/a' }
        Write-Output 'PASS: B-330 the Claude child gets --setting-sources project,local, and tokensOut sums modelUsage over every model'
        Write-Output 'PASS: B-277 Copilot events convert in order to a gradable transcript, recover a denied call, flag hook loading, and report missing/empty/truncated/unterminated/errored logs as unexaminable'
        Write-Output 'PASS: B-253 -TargetPatch changes only the patched bytes under core.autocrlf=true, refuses a stale patch, and a moved conventions placeholder fails loud'
        # B-464 B11: a misspelt id in -Scenario is refused by name, not dropped.
        $b11Config = Get-Content -Raw $scenarioPath | ConvertFrom-Json
        $b11Refusal = [string](Get-ScenarioSelectionRefusal $b11Config @('route-fix', 'route-fx'))
        if ($b11Refusal -notmatch 'route-fx' -or $b11Refusal -match 'route-fix') { throw "B-464 B11: route-fix,route-fx was not refused naming only route-fx; got '$b11Refusal'" }
        if (Get-ScenarioSelectionRefusal $b11Config @('route-fix', 'route-fix-nl')) { throw 'B-464 B11: a selection of registered ids was refused' }
        if (Get-ScenarioSelectionRefusal $b11Config @()) { throw 'B-464 B11: an empty selection (every scenario) was refused' }
        Write-Output 'PASS: B-464 B11 -Scenario refuses an unregistered id by name and accepts registered ids and an empty selection'
        # B-464 B12: a throw in setup on the second case (outside the per-case try) leaves the first case's row in the results file.
        & {
            $b12Repos = [ref]0
            function New-EvalRepo([string]$Path, [string]$Stack) {
                $b12Repos.Value++
                if ($b12Repos.Value -ge $b12Throw) { throw 'b464 stub setup failure' }
                New-Item -ItemType Directory -Path $Path -Force | Out-Null
                git -C $Path init -q
                git -C $Path -c user.name=t -c user.email=t@t commit --allow-empty -q -m seed
            }
            function Install-Framework { }
            function Invoke-ClaudeProcess { [pscustomobject]@{ ExitCode = 0; TimedOut = $true; ErrorText = 'b464 stub run' } }
            $version = '0.0.0'; $changelogDecision = [pscustomobject]@{ RootHead = '' }; $frameworkCommit = 'b464'; $hostVersion = 'stub'
            $b12Cases = @([pscustomobject]@{ id = 'b464-first'; prompt = 'p'; budgetUsd = 1 }, [pscustomobject]@{ id = 'b464-second'; prompt = 'p'; budgetUsd = 1 })
            foreach ($b12Throw in @(2, 99)) {
                $b12Repos.Value = 0
                $trialOf = @{}
                $scratch = Join-Path $temp "b12-scratch-$b12Throw"
                New-Item -ItemType Directory -Path $scratch | Out-Null
                $b12File = Join-Path $temp "b12-results-$b12Throw.md"
                $b12Rows = [System.Collections.Generic.List[object]]::new()
                $b12Thrown = $null
                try { Invoke-EvalRun $b12Cases $b12Rows $b12File | Out-Null } catch { $b12Thrown = $_.Exception.Message }
                $b12Text = if (Test-Path -LiteralPath $b12File) { Get-Content -Raw -LiteralPath $b12File } else { '' }
                if ($b12Throw -eq 2) {
                    if ($b12Thrown -notmatch 'b464 stub setup failure') { throw "B-464 B12: the setup failure on the second case did not reach the caller; got '$b12Thrown'" }
                    if ($b12Text -notmatch 'ERROR b464-first' -or $b12Text -match 'b464-second' -or $b12Text -notmatch 'ABORTED') { throw "B-464 B12: the first case's row was not left in the results file, marked aborted; file: $b12Text" }
                } else {
                    if ($b12Thrown) { throw "B-464 B12: a run with no failure threw '$b12Thrown'" }
                    if ($b12Text -notmatch 'ERROR b464-first' -or $b12Text -notmatch 'ERROR b464-second' -or $b12Text -match 'ABORTED') { throw "B-464 B12: a completed run's results file is not both rows without ABORTED; file: $b12Text" }
                }
            }
        }
        Write-Output 'PASS: B-464 B12 a setup failure on a later case leaves the earlier rows in the results file marked aborted, and a completed run is written whole'
        Write-Output 'PASS: PowerShell UTF-8 BOM'
    } finally { if (Test-Path $temp) { Remove-Item -LiteralPath $temp -Recurse -Force } }
}

# B-464 B11: a requested id that scenarios.json does not register is refused by name, before any spend or setup; dropping it silently
# measured fewer cases than were pre-registered and could still exit 0.
function Get-ScenarioSelectionRefusal($Config, [string[]]$Ids) {
    $known = @($Config.scenarios | ForEach-Object { [string]$_.id })
    $unknown = @($Ids | Where-Object { $_ -notin $known } | Select-Object -Unique)
    if ($unknown) { return "Refusing -Scenario: $($unknown -join ', ') $(if ($unknown.Count -eq 1) { 'is' } else { 'are' }) not in scenarios.json." }
}

# B-464 B12: each case appends its row to $Rows as it is decided, and the results file is written from a finally, so a throw outside
# the per-case try (setup, the followUp guard) or a Ctrl+C leaves the rows already paid for instead of losing them.
function Invoke-EvalCases($Cases, $Rows) {
    foreach ($case in $Cases) {
        # Isolate each case's entire visible fixture tree. Otherwise a model can satisfy a later
        # install case by copying artifacts from an earlier sibling instead of exercising the
        # requested canonical installer path.
        $trialOf[$case.id] = 1 + [int]$trialOf[$case.id]
        $runName = if ($Trials -gt 1) { "$($case.id)-t$($trialOf[$case.id])" } else { [string]$case.id }
        $caseRoot = Join-Path $scratch $runName
        New-Item -ItemType Directory -Path $caseRoot | Out-Null
        $target = Join-Path $caseRoot 'target'
        $caseStack = if ($case.stack) { [string]$case.stack } else { 'dotnet' }
        $caseFixture = if ($case.fixture) { [string]$case.fixture } else { $caseStack }
        New-EvalRepo $target $caseFixture
        $before = [int](git -C $target rev-list --count HEAD)
        if ($Arm -eq 'framework' -and $case.id -notin $selfInstallScenarios) {
            Install-Framework $target $caseStack | Out-Null
            # B-406: the target becomes a repository that ran /bootstrap; before any patch or scenario setup.
            if ($caseFixture -in $contractFixtures) { Initialize-B406Overlay $target $caseFixture }
            # B-470: the bootstrapped repository the scenario names; the bare arm keeps the fixture alone.
            if ($case.overlay) { Initialize-GeneratedOverlay $target ([string]$case.overlay) }
            # Before the scenario setup, which commits the framework files in the warehouse cases:
            # the patch adds no commit, so `git log` (session-start preloads it) matches both arms.
            # B-402: under -WarehouseMap generated|partial it lands inside that setup, after the bootstrap overlay.
            if ($TargetPatch -and $WarehouseMap -notin @('generated','partial')) { Invoke-TargetPatch $target $TargetPatch | Out-Null }
            $before = [int](git -C $target rev-list --count HEAD)
        }
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
            { $_ -in @('url-install-brownfield', 'url-install-readme-brownfield') } {
                "# Team notes`n`n- Tests use xUnit; name them Method_State_Result.`n" | Set-Content (Join-Path $target 'CLAUDE.md') -Encoding utf8NoBOM
                git -C $target add CLAUDE.md
                git -C $target commit --quiet -m 'team AI notes'
                $before = [int](git -C $target rev-list --count HEAD)
            }
            'dev-setup' {
                git -C $target add -A
                git -C $target commit --quiet -m 'install AI Tech Lead'
                $before = [int](git -C $target rev-list --count HEAD)
            }
            'haiku-convention-check' {
                "namespace EvalFixture; public class ConventionViolation { public async Task WorkAsync() { await Task.Delay(1); } }" | Set-Content (Join-Path $target 'src/ConventionViolation.cs') -Encoding utf8NoBOM
                $claudeText = Get-Content -Raw (Join-Path $target 'AGENTS.md')
                $claudeText.Replace('BOOTSTRAP_PENDING', 'EVAL_BOOTSTRAPPED') | Set-Content (Join-Path $target 'AGENTS.md') -Encoding utf8NoBOM
            }
            { $_ -in @('docs-tier-ondemand','docs-tier-inline','docs-tier-nopointer') } {
                $claudePath = Join-Path $target 'AGENTS.md'
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
            { $_ -in @('warehouse-route-p1','warehouse-route-p2','warehouse-route-p3','warehouse-route-p4') } {
                $mapSwitch = Get-WarehouseMapSwitch $WarehouseMap
                $overlayPatch = if ($WarehouseMap -in @('generated','partial')) { $TargetPatch } else { '' }
                $before = Initialize-WarehouseScenario $target -Bare:($Arm -eq 'none') @mapSwitch -TargetPatch $overlayPatch
            }
            { $_ -in @('warehouse-bind-sql','warehouse-bind-mixed') } {
                # -EnrichedMap: the binding decision needs business keys and the fact -> dimension
                # edge list, which the default (frozen) fixture map does not carry.
                $before = Initialize-WarehouseScenario $target -EnrichedMap -Bare:($Arm -eq 'none')
            }
            { $_ -in @('warehouse-fact-existing','warehouse-fact-new','warehouse-fact-snapshot','warehouse-fact-abstain','warehouse-schema-compatible','warehouse-schema-incompatible','warehouse-schema-incomplete','warehouse-partition-mismatch') } {
                $before = Initialize-FactBindingScenario $target
            }
            { $_ -in @('warehouse-upstream-pinned','warehouse-upstream-deferred') } {
                $before = Initialize-FactBindingScenario $target -NeutralKeySemantics
            }
            { $_ -like 'warehouse-trace-*' } {
                $before = Initialize-FactBindingScenario $target
            }
            'warehouse-map-quality' {
                $before = Initialize-WarehouseScenario $target -OmitMap
            }
            { $_ -in @('warehouse-health-default-a','warehouse-health-default-b','warehouse-health-deep-b','warehouse-health-clean','warehouse-health-convention','warehouse-health-no-trigger','warehouse-health-bridge-ok','warehouse-health-decision-a') } {
                $before = Initialize-WarehouseScenario $target -OmitMap
                if ($_ -eq 'warehouse-health-convention') {
                    $defaultsPath = Join-Path $target 'docs/defaults.md'
                    $defaultsText = Get-Content -Raw -LiteralPath $defaultsPath
                    $defaultsText += @'

## Repository data-access convention

ISO 4217 currency codes are immutable governed identifiers in this repository. Facts may retain
`CurrencyCode` and reference `dim.DimCurrency.CurrencyCode` directly; this narrow exception does
not permit mutable source-system business keys on facts.
'@
                    $defaultsText | Set-Content -LiteralPath $defaultsPath -Encoding utf8NoBOM
                    git -C $target add docs/defaults.md
                    git -C $target commit --quiet -m 'explicit currency-key convention'
                    $before = [int](git -C $target rev-list --count HEAD)
                }
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
        # B-406: what the agent finds is the install, the overlay, any patch and the scenario setup; its own writes are what differs from this.
        $script:B406Snapshot = if ($caseFixture -in $contractFixtures -or $case.id -eq 'route-fix-notest') { Get-TreeHashes $target } else { $null }
        $prompt = $case.prompt.Replace('{SYNTHETIC_AWS_KEY}', $syntheticAwsKey).Replace('{FRAMEWORK_ROOT}', $repo).Replace('{TARGET_ROOT}', $target).Replace('{ARCHIVED_ROOT}', $archivedRoot)
        $transcriptPath = Join-Path $scratch ($runName + '.jsonl')
        $outcome = $null
        Write-Output "RUN $runName arm=$Arm (budget USD $($case.budgetUsd))"
        $caseModel = if ($case.model) { [string]$case.model } else { $Model }
        $caseAgent = if ($case.agent) { [string]$case.agent } else { '' }
        # B-410: a case with a followUp is two invocations of one persisted session (the developer's prompt, then a fixed answer).
        $legSession = if ($case.followUp) { [guid]::NewGuid().ToString() } else { '' }
        if ($legSession -and $caseFixture -notin $contractFixtures) { throw "$($case.id): a followUp is read only for the contract fixtures, whose graders take a merged two-leg transcript." }
        $copilotMeta = $null
        if ($Executor -eq 'copilot') {
            $caseModel = $CopilotModel
            $caseAgent = ''
            $sessionId = [guid]::NewGuid().ToString()
            $copilotHome = if ($env:COPILOT_HOME) { $env:COPILOT_HOME } else { Join-Path ([Environment]::GetFolderPath('UserProfile')) '.copilot' }
            $eventsPath = Join-Path $copilotHome "session-state/$sessionId/events.jsonl"
            $run = Invoke-CopilotProcess $target $prompt (Join-Path $scratch ($runName + '.copilot-stdout.txt')) $CopilotModel $CopilotMaxAiCredits $TimeoutSeconds $sessionId (Join-Path $scratch ($runName + '.copilot-usage.json')) ($Arm -eq 'framework')
        } else {
            $run = Invoke-ClaudeProcess $target $prompt $transcriptPath $caseModel ([decimal]$case.budgetUsd) $TimeoutSeconds $caseAgent -LiveSourceCheck:($case.assertion -eq 'urlInstall') -IncludeHookEvents:($caseFixture -in $contractFixtures -or $case.id -in $routerProbeScenarios) -SessionId $legSession
        }
        $agentExit = $run.ExitCode
        try {
            if ($run.TimedOut) { throw $run.ErrorText }
            if ($Executor -eq 'copilot') {
                $copilotMeta = ConvertFrom-CopilotEvents $eventsPath $transcriptPath
                if ($copilotMeta.Model) { $caseModel = $copilotMeta.Model }
            }
            # B-406: a background security pass makes the stream several turns of one session; no other case reads that.
            $transcript = Read-Transcript $transcriptPath -AllowMultiTurn:($caseFixture -in $contractFixtures)
            if ($legSession) {
                # B-410: the developer's answer, only when the first leg stopped for it: no write (a Write-type tool or a changed
                # tree) and no error. Otherwise the grader sees one leg and says why (wroteT1, or not examined).
                $legOneHostFailure = Get-HostFailure $transcript
                if ($legOneHostFailure) { throw $legOneHostFailure }
                $legOne = Get-TranscriptEvidence $transcript
                if (-not $legOne.Final.is_error -and (Test-B406NoFileWrite $legOne $target)) {
                    $legTwoPath = Join-Path $scratch ($runName + '-leg2.jsonl')
                    # Whether --max-budget-usd on --resume caps the session or the leg is not known; the follow-up's budget on top of
                    # what the first leg spent holds under either reading, and the stop counts what was spent, not the cap.
                    $legTwoBudget = [decimal]$case.followUpBudgetUsd + [decimal]$legOne.Final.total_cost_usd
                    $run2 = Invoke-ClaudeProcess $target ([string]$case.followUp) $legTwoPath $caseModel $legTwoBudget $TimeoutSeconds $caseAgent -IncludeHookEvents:($caseFixture -in $contractFixtures) -ResumeId $legSession
                    if ($run2.TimedOut) { throw $run2.ErrorText }
                    if ($run2.ExitCode -ne 0) { $agentExit = $run2.ExitCode }
                    $transcript = Merge-ClaudeLegs $transcript (Read-Transcript $legTwoPath -AllowMultiTurn)
                }
            }
            $hostFailure = Get-HostFailure $transcript
            if ($hostFailure) { throw $hostFailure }
            $script:CaseExpect = [pscustomobject]@{ Stack = [string]$case.expectStack; Command = [string]$case.expectCommand }
            $evidence = Test-ScenarioEvidence $case.id $target $transcript $before
            # WSD-040 revision (i): a routing non-reach (the unchanged skill was never read) must
            # not be scored as a decision-outcome pass or fail -- it means the trial never exercised
            # what B-127's baseline measures. Without this branch it fell through to 'FAIL' below,
            # silently reintroducing the exact conflation the locked design exists to prevent.
            $status = if ($agentExit -ne 0) { 'ERROR' } elseif ($evidence.Status -in @('ROUTING_NON_REACH','CONTAMINATED')) { $evidence.Status } elseif ($evidence.Pass) { 'PASS' } elseif ($evidence.Status -eq 'INCONCLUSIVE') { 'INCONCLUSIVE' } else { 'FAIL' }
            # The terminal result event already carries spend and token counts; recording them makes
            # the cost of a suite run measurable instead of guessed from the per-case budget CAP,
            # which is an upper bound and not what a run actually consumes.
            $final = @($transcript.Events | Where-Object { $_.type -eq 'result' } | Select-Object -Last 1)
            $cost = if ($final -and $null -ne $final[0].total_cost_usd) { [string]$final[0].total_cost_usd } else { 'n/a' }
            $tokensIn = if ($final -and $final[0].usage) { [string]$final[0].usage.input_tokens } else { 'n/a' }
            $tokensOut = if ($final) { Get-OutputTokens $final[0] } else { 'n/a' }
            if ($case.bareArm) { $outcome = [bool]$evidence.Outcome }
            # Copilot only loads repository hooks in prompt mode behind the opt-in above; if none
            # fired, the framework arm's enforcement surface was absent and the row must say so.
            $copilotDetail = if ($copilotMeta) { "executor=copilot copilotCli=$($copilotMeta.CliVersion) hooksLoaded=$($copilotMeta.HooksLoaded) premiumRequests=$($copilotMeta.PremiumRequests) toolCalls=$($copilotMeta.ToolCalls) " } else { '' }
            # B-253: the CLI can update itself between runs of one invocation; the header's version
            # is read once, so each Claude Code row records the host and model its own run reported.
            $init = @($transcript.Events | Where-Object { $_.type -eq 'system' -and $_.subtype -eq 'init' } | Select-Object -First 1)
            $claudeDetail = if ($Executor -eq 'claude' -and $init) { "ccVersion=$($init[0].claude_code_version) initModel=$($init[0].model) " } else { '' }
            $detail = "agentExit=$agentExit timedOut=$($run.TimedOut) costUsd=$cost tokensIn=$tokensIn tokensOut=$tokensOut; $claudeDetail$copilotDetail$(if ($case.bareArm) { "arm=$Arm outcome=$outcome " })$($evidence.Detail)"
        } catch { $status = 'ERROR'; $detail = "$(if ($Executor -eq 'copilot') { 'executor=copilot ' })$($_.Exception.Message)" }
        $Rows.Add([pscustomobject]@{ Id = $case.id; Status = $status; Model = $caseModel; Agent = $caseAgent; Detail = $detail; Arm = $Arm; Scored = [bool]$case.bareArm; Outcome = $outcome; Executor = $Executor; Patch = $patchTag })
        Write-Output "$status $($case.id): $detail"
    }
}

function Save-EvalResults([string]$Path, $Rows, [bool]$Complete) {
    if (-not $Rows.Count) { return }
    $date = Get-Date -Format 'yyyy-MM-dd HH:mm:ss K'
    # Copilot CLI and Claude Code numbers are never compared with each other, so the header names
    # the host and the model actually used, and every Copilot row carries executor=copilot.
    $hostLabel = if ($Executor -eq 'copilot') { "$hostVersion · executor: copilot · model: $(@($Rows | ForEach-Object { $_.Model } | Select-Object -Unique) -join ',') · credit cap: $(if ($CopilotMaxAiCredits -gt 0) { $CopilotMaxAiCredits } else { 'none' })" } else { "Claude Code $hostVersion" }
    $lines = @('', "## $date — framework v$version$(if ($changelogDecision.RootHead) { " (root head $($changelogDecision.RootHead))" }) ($frameworkCommit)", '', "Host: $hostLabel · arm: $Arm$(if ($patchTag) { " · patch: $patchTag" })$(if ($WarehouseMap -ne 'frozen') { " · warehouseMap: $WarehouseMap" }) · scratch: retained=$KeepScratch", '')
    foreach ($r in $Rows) { $lines += "- **$($r.Status) $($r.Id)** (model=$($r.Model)$(if($r.Agent){"; agent=$($r.Agent)"})$(if($r.Executor -eq 'copilot'){'; executor=copilot'})$(if($r.Patch){"; patch=$($r.Patch)"})) — $(Protect-ResultText $r.Detail)" }
    if (-not $Complete) { $lines += '- **ABORTED** the run stopped before its last case; the rows above are the cases decided before it stopped.' }
    $lines += @(Get-OutcomeSummary $Rows)
    $lines += ''
    Add-Content -LiteralPath $Path -Value ($lines -join "`n") -Encoding utf8NoBOM
}

function Invoke-EvalRun($Cases, $Rows, [string]$Path) {
    $complete = $false
    try { Invoke-EvalCases $Cases $Rows; $complete = $true }
    finally { Save-EvalResults $Path $Rows $complete }
}

if ($SelfTest) { Invoke-SelfTest | Write-Output; exit 0 }
if (-not $Live) {
    Write-Output 'No agent was run. This harness incurs model usage and requires explicit consent.'
    Write-Output 'Run: pwsh -NoProfile -File .claude/evals/run-agent-evals.ps1 -Live [-Scenario route-fix] [-Model sonnet]'
    exit 2
}
$agentCli = if ($Executor -eq 'copilot') { 'copilot' } else { 'claude' }
if (-not (Get-Command $agentCli -ErrorAction SilentlyContinue)) { throw "$agentCli CLI is not installed or not on PATH." }
if (git -C $repo status --porcelain -- dist/) { throw 'Refusing live eval: dist/ differs from the checked-out release.' }

$config = Get-Content -Raw $scenarioPath | ConvertFrom-Json
$scenarioIds = @($Scenario | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$scenarioRefusal = Get-ScenarioSelectionRefusal $config $scenarioIds
if ($scenarioRefusal) { Write-Output $scenarioRefusal; exit 2 }
$selected = @($config.scenarios | Where-Object { -not $scenarioIds -or $_.id -in $scenarioIds })
if ($selected.Count -eq 0) { throw 'No scenarios matched -Scenario.' }
if ($Arm -eq 'none') {
    $notBare = @($selected | Where-Object { -not $_.bareArm } | ForEach-Object { $_.id })
    if ($notBare) { throw "Refusing -Arm none: no arm-neutral Outcome is graded for $($notBare -join ', '). Select scenarios marked bareArm in scenarios.json." }
}
if ($WarehouseMap -ne 'frozen') {
    $notRoute = @($selected | Where-Object { $_.id -notlike 'warehouse-route-p*' } | ForEach-Object { $_.id })
    if ($notRoute) { throw "Refusing -WarehouseMap ${WarehouseMap}: it only applies to the warehouse-route scenarios, not $($notRoute -join ', ')." }
}
if ($Executor -eq 'copilot') {
    # Scenario-level model/agent overrides name Claude Code models and subagents. Refuse rather
    # than silently substituting something else under a different host.
    $claudeSpecific = @($selected | Where-Object { $_.model -or $_.agent } | ForEach-Object { $_.id } | Select-Object -Unique)
    if ($claudeSpecific) { throw "Refusing -Executor copilot: $($claudeSpecific -join ', ') carry Claude-specific model/agent overrides. Run them under -Executor claude." }
    if ($CopilotModel -eq 'auto') { throw "Refusing -Executor copilot with -CopilotModel auto: 'auto' resolves to a different vendor per run, so trials are not comparable." }
    $b406ExecutorRefusal = Get-B406ExecutorRefusal $selected $Executor
    if ($b406ExecutorRefusal) { throw $b406ExecutorRefusal }
}
$selected = @($selected | ForEach-Object { $repeated = $_; 1..$Trials | ForEach-Object { $repeated } })
$trialOf = @{}
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('ai-tech-lead-agent-evals-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory $scratch | Out-Null
$version = (Get-Content -Raw (Join-Path $repo 'dist/dotnet/.claude/framework-version.json') | ConvertFrom-Json).version
$changelogDecision = Get-ChangelogGuardDecision (Get-Content -Raw (Join-Path $repo 'CHANGELOG.md')) $version
if (-not $changelogDecision.Allowed) { throw "Refusing live eval: $($changelogDecision.Message)" }
if ($WarehouseMap -in @('generated','partial')) {
    $fixtureRefusal = Get-GeneratedFixtureRefusal (Join-Path $repo 'meta/eval-fixtures/warehouse-generated/provenance.json') $version
    if ($fixtureRefusal) { throw "Refusing live eval: $fixtureRefusal" }
}
# B-406: the bootstrap overlay is bound to the framework version it was generated on. Refused before any spend.
# -Arm none cannot reach these cases: they carry no bareArm, so the refusal above already stops it.
# B-409: the same for every contract fixture in the selection, each against its own overlay and provenance.
$b406Cases = @($selected | Where-Object { $_.fixture -in $contractFixtures })
$contractFixturesUsed = @($b406Cases | ForEach-Object { [string]$_.fixture } | Select-Object -Unique)
foreach ($contractFixture in $contractFixturesUsed) {
    $b406Root = Join-Path $repo "meta/eval-fixtures/$contractFixture"
    $fixtureRefusal = Get-GeneratedFixtureRefusal (Join-Path $b406Root 'provenance.json') $version $contractFixture
    if (-not $fixtureRefusal -and -not (Test-Path -LiteralPath (Join-Path $b406Root 'files') -PathType Container)) { $fixtureRefusal = "${contractFixture}: $(Join-Path $b406Root 'files') is missing. Generate the fixture first (DEVELOPING.md, agent evals)." }
    if ($fixtureRefusal) { throw "Refusing live eval: $fixtureRefusal" }
}
# B-470: a scenario's overlay is bound to the framework version it was generated on. Refused before any spend, on either arm,
# so the two arms of one probe run against one framework version.
foreach ($overlay in @($selected | Where-Object { $_.overlay } | ForEach-Object { [string]$_.overlay } | Select-Object -Unique)) {
    $fixtureRefusal = Get-GeneratedFixtureRefusal (Join-Path $repo "meta/eval-fixtures/$overlay/provenance.json") $version $overlay
    if ($fixtureRefusal) { throw "Refusing live eval: $fixtureRefusal" }
}
$patchTag = ''
if ($TargetPatch) {
    if ($Arm -ne 'framework') { throw 'Refusing -TargetPatch with -Arm none: there is no installed framework to patch.' }
    $TargetPatch = (Resolve-Path -LiteralPath $TargetPatch).Path
    $neverInstalled = @($selected | Where-Object { $_.id -in $selfInstallScenarios } | ForEach-Object { $_.id } | Select-Object -Unique)
    if ($neverInstalled) { throw "Refusing -TargetPatch: $($neverInstalled -join ', ') never install the framework before the agent runs." }
    foreach ($contractFixture in $contractFixturesUsed) {
        # The overlay lands before the patch, on top of the fresh install the patch was cut against.
        $b406Files = Join-Path $repo "meta/eval-fixtures/$contractFixture/files"
        $b406Overlay = @(Get-ChildItem -LiteralPath $b406Files -Recurse -File -Force | ForEach-Object { [IO.Path]::GetRelativePath($b406Files, $_.FullName).Replace('\', '/') })
        $overwritten = @(Get-TargetPatchPaths $TargetPatch | Where-Object { $_ -in $b406Overlay })
        if ($overwritten) { throw "Refusing -TargetPatch with a $contractFixture case: the bootstrap overlay has already changed $($overwritten -join ', '), so a patch cut against a fresh install does not describe what the agent would see." }
    }
    # Once per stack before any spend: a patch that failed inside the loop would abort the
    # invocation after paid runs (their rows are kept, marked aborted, but the rest of the selection is not measured).
    foreach ($patchStack in @($selected | ForEach-Object { if ($_.stack) { [string]$_.stack } else { 'dotnet' } } | Select-Object -Unique)) {
        $preflight = Join-Path ([IO.Path]::GetTempPath()) ('ai-tech-lead-patch-preflight-' + [guid]::NewGuid().ToString('N'))
        try {
            if ($WarehouseMap -in @('generated','partial')) {
                # B-402: as in the run, the patch lands on the bootstrapped warehouse tree (Initialize-WarehouseScenario).
                New-EvalRepo $preflight warehouse
                Install-Framework $preflight $patchStack | Out-Null
                $preflightMap = Get-WarehouseMapSwitch $WarehouseMap
                Initialize-WarehouseScenario $preflight @preflightMap -TargetPatch $TargetPatch | Out-Null
                $patchTag = Get-TargetPatchTag $TargetPatch
            } else {
                New-EvalRepo $preflight $patchStack
                Install-Framework $preflight $patchStack | Out-Null
                $patchTag = Invoke-TargetPatch $preflight $TargetPatch
            }
        } finally { if (Test-Path $preflight) { Remove-Item -LiteralPath $preflight -Recurse -Force } }
    }
}
if (@($selected | Where-Object assertion -eq 'urlInstall').Count) {
    # The URL scenarios install whatever GitHub's newest release is; the installed bytes are compared with that tag here.
    $releaseTags = @(git ls-remote --tags --refs 'https://github.com/andreoucostas/ai-tech-lead.git' 'refs/tags/v*' | ForEach-Object { if ($_ -match 'refs/tags/(v\d+\.\d+\.\d+)$') { $Matches[1] } })
    if ($LASTEXITCODE -ne 0 -or -not $releaseTags) { throw 'Refusing the url-install scenarios: could not list the release tags on GitHub.' }
    $newestTag = $releaseTags | Sort-Object { [version]$_.Substring(1) } | Select-Object -Last 1
    git -C $repo cat-file -e "$newestTag^{commit}" 2>$null
    if ($LASTEXITCODE -ne 0) { throw "Refusing the url-install scenarios: $newestTag is not in this checkout; run git fetch --tags first." }
    $script:UrlInstallReference = [pscustomobject]@{
        Tag = $newestTag
        Read = { param($Stack, $Relative)
            $encoding = [Console]::OutputEncoding
            [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
            try { $text = git -C $repo show "$($script:UrlInstallReference.Tag):dist/$Stack/$Relative" 2>$null; if ($LASTEXITCODE -eq 0) { $text -join "`n" } else { $null } }
            finally { [Console]::OutputEncoding = $encoding } }
    }
}
$frameworkCommit =(git -C $repo rev-parse HEAD | Out-String).Trim()
$hostVersion = (& $agentCli --version | Out-String).Trim()
# `copilot --version` also prints an update notice; keep the first line only.
if ($Executor -eq 'copilot') { $hostVersion = [string](@($hostVersion -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -First 1)).Trim() }
$results = [System.Collections.Generic.List[object]]::new()
try {
    Invoke-EvalRun $selected $results $ResultsPath
    if (@($results | Where-Object Status -ne 'PASS').Count) { exit 1 }
    exit 0
} finally {
    if (-not $KeepScratch -and (Test-Path $scratch)) { Remove-Item -LiteralPath $scratch -Recurse -Force }
    elseif (Test-Path $scratch) { Write-Output "Scratch retained: $scratch" }
}
