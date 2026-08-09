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

function New-EvalRepo([string]$Path, [ValidateSet('dotnet','angular','warehouse','warehouse-mixed','warehouse-fact-binding','warehouse-health-a','warehouse-health-b','warehouse-health-clean','warehouse-health-convention','warehouse-health-no-trigger')][string]$Stack = 'dotnet') {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
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
        @'
CREATE PROCEDURE dbo.usp_LoadFactInvoice AS
MERGE fact.FactInvoice AS target
USING stg.StgInvoice AS source ON source.InvoiceId = target.InvoiceKey
WHEN NOT MATCHED THEN INSERT (InvoiceKey, CustomerKey, InvoiceDateKey, NetAmount, LoadRunId)
VALUES (source.InvoiceId, source.CustomerKey, source.InvoiceDateKey, source.NetAmount, source.LoadRunId);
'@ | Set-Content -LiteralPath (Join-Path $Path 'StoredProcedures/usp_LoadFactInvoice.sql') -Encoding utf8NoBOM
        'CREATE VIEW rpt.vwInvoiceRevenue AS SELECT CustomerKey, SUM(NetAmount) Revenue FROM fact.FactInvoice GROUP BY CustomerKey;' | Set-Content -LiteralPath (Join-Path $Path 'Views/rpt.vwInvoiceRevenue.sql') -Encoding utf8NoBOM
        git -C $Path init --quiet
        git -C $Path config user.email 'agent-evals@invalid.local'
        git -C $Path config user.name 'Agent Evals'
        git -C $Path add -A
        git -C $Path commit --quiet -m "$Stack baseline"
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
    CustomerId NVARCHAR(50) NOT NULL,
    PostedDateKey INT NOT NULL,
    SettledDateKey INT NULL,
    TransactionAmount DECIMAL(18,2) NOT NULL,
    EndOfDayBalance DECIMAL(18,2) NOT NULL,
    LoadRunId BIGINT NOT NULL
);
'@ | Set-Content -LiteralPath (Join-Path $Path 'Tables/fact.FactAccountActivity.sql') -Encoding utf8NoBOM
            @'
CREATE PROCEDURE dbo.usp_LoadFactAccountActivity AS
INSERT INTO fact.FactAccountActivity
    (ActivityKey, CustomerId, PostedDateKey, SettledDateKey, TransactionAmount, EndOfDayBalance, LoadRunId)
SELECT s.SalesId, s.CustomerId, posted.DateKey, settled.DateKey, s.NetAmount,
       SUM(s.NetAmount) OVER (PARTITION BY s.CustomerId ORDER BY s.OrderDate), s.BatchId
FROM stg.StgSalesOrder s
JOIN dim.DimDate posted ON posted.CalendarDate = s.OrderDate
LEFT JOIN dim.DimDate settled ON settled.CalendarDate = DATEADD(day, 2, s.OrderDate);
'@ | Set-Content -LiteralPath (Join-Path $Path 'StoredProcedures/usp_LoadFactAccountActivity.sql') -Encoding utf8NoBOM
            @'
CREATE VIEW rpt.vwDailyAccountPosition AS
SELECT PostedDateKey, SUM(TransactionAmount) AS DailyMovement,
       SUM(EndOfDayBalance) AS TotalBalance
FROM fact.FactAccountActivity
GROUP BY PostedDateKey;
'@ | Set-Content -LiteralPath (Join-Path $Path 'Views/rpt.vwDailyAccountPosition.sql') -Encoding utf8NoBOM
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

function Initialize-WarehouseScenario([string]$Path, [switch]$OmitMap, [switch]$EnrichedMap) {
    New-Item -ItemType Directory -Path (Join-Path $Path 'docs') -Force | Out-Null
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
    elseif (-not $OmitMap) {
        @'
# Warehouse map

| entity | layer | grain | load proc/pipeline | orchestrated by | rerun protection | SCD | partitioning |
|--------|-------|-------|--------------------|-----------------|------------------|-----|--------------|
| DimCustomer | dimension | one row per customer version | usp_LoadDimCustomer | warehouse load | current-row merge | Type 2 | none |
| DimRegion | dimension | one row per region | usp_LoadDimRegion | warehouse load | merge by region | Type 1 | none |
| FactSales | fact | one row per sale | usp_LoadFactSales | warehouse load | LoadRunId | n/a | none |
'@ | Set-Content (Join-Path $Path 'docs/warehouse-map.md') -Encoding utf8NoBOM
    }
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

function Initialize-FactBindingScenario([string]$Path) {
    $claudePath = Join-Path $Path 'CLAUDE.md'
    $claudeText = (Get-Content -Raw $claudePath).Replace('BOOTSTRAP_PENDING', 'EVAL_BOOTSTRAPPED')
    $ordinaryConventions = @'
<!-- EVAL_BOOTSTRAPPED: repository conventions observed for this fixture. -->

- SQL source is organised by `Tables/`, `StoredProcedures/`, and `Views/`.
- Facts retain dimension surrogate keys; load dimensions before facts.
- Use `LoadRunId` and explicit insert column lists; deploy through the SQL project.
- `docs/warehouse-map.md` is the current warehouse inventory, verified against this SQL tree.
'@
    $claudeText = [regex]::Replace($claudeText, '(?s)<!-- EVAL_BOOTSTRAPPED:.*?_Not yet populated\..*?\r?\n(?=\r?\n---)', $ordinaryConventions)
    $claudeText | Set-Content $claudePath -Encoding utf8NoBOM
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
            $regionOnFact  = $factBody -match '(?i)\bRegionKey\b'
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
            return [pscustomobject]@{ Status = $status; Pass = $pass; Detail = "category=$category channels=$($channels -join ',') reachedAddEntity=$reachedAddEntity factWritten=$factWritten boundCustomer=$boundCustomer boundProduct=$boundProduct boundDate=$boundDate resolvedCustomer=$resolvedCustomer resolvedProduct=$resolvedProduct resolvedDate=$resolvedDate regionOnFact=$regionOnFact naturalKeyOnFact=$naturalKeyOnFact degenerateOnFact=$degenerateOnFact newDimTables=$($newDimTables -join ',')" }
        }
        { $_ -in @('warehouse-health-default-a','warehouse-health-default-b','warehouse-health-deep-b','warehouse-health-clean','warehouse-health-convention','warehouse-health-no-trigger') } {
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
                foreach ($healthLine in @($Section -split '\r?\n')) {
                    if ($healthLine -notmatch '^\s*\|') { continue }
                    $healthRawCells = $healthLine.Trim().Trim('|') -split '\|'
                    $healthCells = @($healthRawCells | ForEach-Object { $_.Trim() })
                    if ($healthCells.Count -lt 7) { continue }
                    $healthHasRequired = $true
                    foreach ($healthRequiredText in $Required) {
                        if ($healthLine -notmatch [regex]::Escape($healthRequiredText)) { $healthHasRequired = $false; break }
                    }
                    $healthSemanticText = $healthCells[0] + ' ' + $healthCells[2] + ' ' + $healthCells[5]
                    $healthHasSemantics = $true
                    foreach ($healthSemanticPattern in $Semantics) {
                        if ($healthSemanticText -notmatch $healthSemanticPattern) { $healthHasSemantics = $false; break }
                    }
                    if ($healthHasRequired -and $healthHasSemantics) {
                        $healthTier = if ($healthCells[3] -match '(?i)^Confirmed\b') { 'Confirmed' }
                            elseif ($healthCells[3] -match '(?i)^Likely\b') { 'Likely' }
                            elseif ($healthCells[3] -match '(?i)^Possible\b') { 'Possible' }
                            else { 'Missing' }
                        return [pscustomobject]@{ Found=$true; Tier=$healthTier; Line=$healthLine }
                    }
                }
                return [pscustomobject]@{ Found=$false; Tier='Missing'; Line='' }
            }
            $findings = Get-MarkdownSection $mapText 'Findings'
            $coverage = Get-MarkdownSection $mapText 'Coverage'
            $truncated = $mapText -match '(?im)^\s*(?:>\s*)?(?:\[?TRUNCATED\]?|OUTPUT LIMIT|CONTINUED ELSEWHERE)\b' -or ($findings -and $findings -notmatch '(?m)^\s*\|')

            $mixed = Find-HealthRow $findings @('FactAccountActivity') @('(?i)grain','(?i)(TransactionAmount|transaction)','(?i)(EndOfDayBalance|balance)')
            $natural = Find-HealthRow $findings @('FactAccountActivity','CustomerId') @('(?i)(natural|business|raw|text)','(?i)(surrogate|dimension key|CustomerKey)')
            $scd = Find-HealthRow $findings @('DimCustomer') @('(?i)SCD|Type\s*2','(?i)(history|version|WHEN MATCHED|IsCurrent)')
            $additivity = Find-HealthRow $findings @('FactAccountActivity','EndOfDayBalance') @('(?i)(semi.additive|non.additive|additivity)','(?i)(time|date|sum)')
            $roleCoverage = $mapText -match '(?is)FactAccountActivity.*PostedDateKey.*SettledDateKey.*role|FactAccountActivity.*role.*PostedDateKey.*SettledDateKey'
            $roleFinding = $findings -match '(?is)FactAccountActivity.*(?:PostedDateKey|SettledDateKey).*role'
            $role = $roleCoverage -and -not $roleFinding

            $conformance = Find-HealthRow $findings @('sales.DimParty','service.DimParty','PartyCode') @('(?i)(conform|same governed party)','(?i)(grain|contact|column)')
            $special = Find-HealthRow $findings @('DimStatus') @('(?:-1|`-1`)','(?:0|`0`)','(?i)(unknown|special|sentinel|ambiguous)')
            $bridge = Find-HealthRow $findings @('FactSales','CampaignKey') @('(?i)(many.to.many|single[^|]*(?:FK|key|column)[^|]*cannot)','(?i)(percentage|100\s*percent|100%)')
            $fan = Find-HealthRow $findings @('vwCustomerCommercialSummary','FactSales','FactReturn') @('(?i)multipl(?:y|ies|ied|ication)','(?i)(pre.aggregat|preaggregat)')

            $successful = @($e.Tools | Where-Object { $e.ToolResults.ContainsKey($_.Id) -and -not $e.ToolResults[$_.Id].is_error })
            $additivityLoadRead = [bool]@($successful | Where-Object {
                ((Get-ToolPath $_) -replace '\\','/') -match '(?i)StoredProcedures/usp_LoadFactAccountActivity\.sql$' -or
                (([string]$_.Input.command + ' ' + [string]$_.Input.path + ' ' + [string]$_.Input.pattern) -match '(?i)usp_LoadFactAccountActivity')
            } | Select-Object -First 1)

            $mixedPass = $mixed.Found -and $mixed.Tier -eq 'Likely'
            $naturalPass = $natural.Found -and $natural.Tier -eq 'Confirmed'
            $scdPass = $scd.Found -and $scd.Tier -eq 'Confirmed'
            $additivityPass = $additivity.Found -and $additivity.Tier -eq 'Likely' -and $additivityLoadRead
            $conformancePass = $conformance.Found -and $conformance.Tier -eq 'Confirmed'
            $specialPass = $special.Found -and $special.Tier -eq 'Confirmed'
            $bridgePass = $bridge.Found -and $bridge.Tier -eq 'Confirmed'
            $fanPass = $fan.Found -and $fan.Tier -eq 'Confirmed'
            $candidateRows = @($mixed.Found,$natural.Found,$scd.Found,$additivity.Found,$role,$conformance.Found,$special.Found,$bridge.Found,$fan.Found) | Where-Object { $_ }

            $pass = switch ($Id) {
                'warehouse-health-default-a' { $mixedPass -and $naturalPass -and $scdPass -and $additivityPass -and $role }
                'warehouse-health-default-b' { $conformancePass -and $specialPass -and -not $bridge.Found -and -not $fan.Found }
                'warehouse-health-deep-b' { $bridgePass -and $fanPass }
                'warehouse-health-clean' { $candidateRows.Count -eq 0 }
                'warehouse-health-convention' { -not $natural.Found }
                'warehouse-health-no-trigger' { -not $bridge.Found }
            }
            $status = if ($truncated) { 'INCONCLUSIVE' } else { 'PASS' }
            return [pscustomobject]@{ Status=$status; Pass=($status -eq 'PASS' -and $pass); Detail="mapWritten=True truncated=$truncated mixed=$mixedPass tierMixed=$($mixed.Tier) natural=$naturalPass tierNatural=$($natural.Tier) scd=$scdPass tierScd=$($scd.Tier) additivity=$additivityPass tierAdditivity=$($additivity.Tier) loadRead=$additivityLoadRead roleCoverage=$role conformance=$conformancePass tierConformance=$($conformance.Tier) special=$specialPass tierSpecial=$($special.Tier) bridge=$bridgePass tierBridge=$($bridge.Tier) fanChasm=$fanPass tierFanChasm=$($fan.Tier) candidateRows=$($candidateRows.Count)" }
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
            ([pscustomobject]@{ type='result'; is_error=$false; result='done' })
        ) }
        $healthHeader = @'
| finding | entity | evidence | finding confidence | severity if confirmed | consequence | remediation |
|---|---|---|---|---|---|---|
'@
        $healthRowsA = @(
            '| Two row meanings coexist | FactAccountActivity | TransactionAmount is transactional while EndOfDayBalance is a daily balance at a different grain | Likely | blocking | Aggregation mixes grains | Separate the daily position |',
            '| Source identifier used for dimensional relationship | FactAccountActivity / CustomerId | CustomerId is a natural business key; CustomerKey is the required surrogate dimension key | Confirmed | blocking | Version joins can drift | Resolve CustomerKey in the load |',
            '| Declared history has no change path | DimCustomer | Type 2 SCD columns exist but no history version or WHEN MATCHED IsCurrent transition is present | Confirmed | significant | Attribute history is lost | Add an evidenced version transition |',
            '| Balance is summed across dates | FactAccountActivity / EndOfDayBalance | EndOfDayBalance is semi-additive and must not sum across time or date | Likely | blocking | Balances are overstated | Select the closing snapshot per period |'
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
        ($healthMapA.Replace('| Likely | blocking | Aggregation mixes grains', '| Confirmed | blocking | Aggregation mixes grains')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-default-a' $healthTemp $healthEvidence 1).Detail -notmatch 'mixed=False tierMixed=Confirmed') { throw 'warehouseModelHealth accepted the wrong mixed-grain confidence tier' }
        ($healthMapA.Replace('Two row meanings coexist | FactAccountActivity', 'Two row meanings coexist | FactOtherActivity')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-default-a' $healthTemp $healthEvidence 1).Detail -notmatch 'mixed=False') { throw 'warehouseModelHealth accepted mixed-grain semantics on the wrong entity' }
        ($healthMapA.Replace('TransactionAmount is transactional while EndOfDayBalance is a daily balance at a different grain', 'both columns were inventoried')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-default-a' $healthTemp $healthEvidence 1).Detail -notmatch 'mixed=False') { throw 'warehouseModelHealth accepted the mixed-grain entity with wrong semantics' }
        ($healthMapA.Replace('| Confirmed | blocking | Version joins can drift', '| Likely | blocking | Version joins can drift')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-default-a' $healthTemp $healthEvidence 1).Detail -notmatch 'natural=False tierNatural=Likely') { throw 'warehouseModelHealth accepted the wrong natural-key confidence tier' }
        ($healthMapA.Replace('FactAccountActivity / CustomerId', 'FactOther / CustomerId')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-default-a' $healthTemp $healthEvidence 1).Detail -notmatch 'natural=False') { throw 'warehouseModelHealth accepted right natural-key semantics on the wrong entity' }
        ($healthMapA.Replace('CustomerId is a natural business key; CustomerKey is the required surrogate dimension key', 'CustomerId is copied for reference')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-default-a' $healthTemp $healthEvidence 1).Detail -notmatch 'natural=False') { throw 'warehouseModelHealth accepted the right entity with wrong natural-key semantics' }
        ($healthMapA.Replace('| Confirmed | significant | Attribute history is lost', '| Likely | significant | Attribute history is lost')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-default-a' $healthTemp $healthEvidence 1).Detail -notmatch 'scd=False tierScd=Likely') { throw 'warehouseModelHealth accepted the wrong SCD confidence tier' }
        ($healthMapA.Replace('Declared history has no change path | DimCustomer', 'Declared history has no change path | DimOther')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-default-a' $healthTemp $healthEvidence 1).Detail -notmatch 'scd=False') { throw 'warehouseModelHealth accepted SCD semantics on the wrong entity' }
        ($healthMapA.Replace('Type 2 SCD columns exist but no history version or WHEN MATCHED IsCurrent transition is present', 'dimension load was inventoried')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-default-a' $healthTemp $healthEvidence 1).Detail -notmatch 'scd=False') { throw 'warehouseModelHealth accepted the SCD entity with wrong semantics' }
        ($healthMapA.Replace('| Likely | blocking | Balances are overstated', '| Confirmed | blocking | Balances are overstated')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-default-a' $healthTemp $healthEvidence 1).Detail -notmatch 'additivity=False tierAdditivity=Confirmed') { throw 'warehouseModelHealth accepted the wrong additivity confidence tier' }
        ($healthMapA.Replace('FactAccountActivity / EndOfDayBalance', 'FactOtherActivity / EndOfDayBalance')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-default-a' $healthTemp $healthEvidence 1).Detail -notmatch 'additivity=False') { throw 'warehouseModelHealth accepted additivity semantics on the wrong entity' }
        ($healthMapA.Replace('EndOfDayBalance is semi-additive and must not sum across time or date', 'EndOfDayBalance was inventoried')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-default-a' $healthTemp $healthEvidence 1).Detail -notmatch 'additivity=False') { throw 'warehouseModelHealth accepted the additivity entity with wrong semantics' }
        ($healthMapA.Replace('## Findings', "## Findings`n`n| Missing roles | FactAccountActivity / PostedDateKey / SettledDateKey | role labels absent | Confirmed | significant | map ambiguous | record roles |")) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-default-a' $healthTemp $healthEvidence 1).Detail -notmatch 'roleCoverage=False') { throw 'warehouseModelHealth accepted a role-playing gap in Findings instead of Coverage' }
        ($healthMapA.Replace('FactAccountActivity reaches DimDate through PostedDateKey and SettledDateKey', 'FactOtherActivity reaches DimDate through PostedDateKey and SettledDateKey')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-default-a' $healthTemp $healthEvidence 1).Detail -notmatch 'roleCoverage=False') { throw 'warehouseModelHealth accepted role coverage on the wrong entity' }
        $healthNoReadEvidence = [pscustomobject]@{ Events = @(
            ([pscustomobject]@{ type='system'; subtype='init' }),
            ([pscustomobject]@{ type='result'; is_error=$false; result='done' })
        ) }
        $healthMapA | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-default-a' $healthTemp $healthNoReadEvidence 1).Detail -notmatch 'additivity=False.*loadRead=False') { throw 'warehouseModelHealth accepted additivity without same-pass load evidence' }

        $healthRowsB = @(
            '| Shared party definitions disagree | sales.DimParty / service.DimParty / PartyCode | same governed party uses different grain and contact column shape | Confirmed | significant | Consumers cannot treat the dimensions as conformed | Align or document the split |',
            '| Reserved rows have indistinguishable labels | DimStatus | keys -1 and 0 are both seeded as Unknown special sentinel members and are ambiguous | Confirmed | significant | Consumers cannot distinguish states | Give each reserved member one meaning |'
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
        ($healthMapB.Replace('keys -1 and 0 are both seeded as Unknown special sentinel members and are ambiguous', 'reserved rows were inventoried')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        if ((Test-ScenarioEvidence 'warehouse-health-default-b' $healthTemp $healthEvidence 1).Detail -notmatch 'special=False') { throw 'warehouseModelHealth accepted the special-member entity with wrong semantics' }

        $healthRowsDeep = @(
            '| Attribution relationship has no allocation owner | FactSales / CampaignKey | multiple campaign percentage attribution needs a bridge or allocation at the evidenced many-to-many grain | Confirmed | blocking | Credit can be lost | Introduce an allocation owner |',
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
        ($healthMapDeep.Replace('multiple campaign percentage attribution needs a bridge or allocation at the evidenced many-to-many grain', 'campaign data was inventoried')) | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
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
        $healthStandalone = "## Coverage`n`nDefault pass completed.`n`n## Findings`n`n$healthHeader`n$($healthRowsA[0])`n"
        $healthStandalone | Set-Content -LiteralPath $healthMapPath -Encoding utf8NoBOM
        $healthStandaloneResult = Test-ScenarioEvidence 'warehouse-health-default-a' $healthTemp $healthEvidence 1
        if ($healthStandaloneResult.Detail -notmatch 'mixed=True' -or $healthStandaloneResult.Detail -match 'natural=True|scd=True|additivity=True') { throw 'warehouseModelHealth confuses one detector row with another' }

        foreach ($healthFixture in @('warehouse-health-a','warehouse-health-b','warehouse-health-clean','warehouse-health-convention','warehouse-health-no-trigger')) {
            $healthFixturePath = Join-Path $temp $healthFixture
            New-EvalRepo $healthFixturePath $healthFixture
            if (-not (Test-Path -LiteralPath (Join-Path $healthFixturePath 'warehouse.sqlproj'))) { throw "$healthFixture fixture has no SQL project" }
            if (-not (Test-Path -LiteralPath (Join-Path $healthFixturePath 'Tables') -PathType Container)) { throw "$healthFixture fixture has no Tables directory" }
        }
        if (-not (Test-Path -LiteralPath (Join-Path $temp 'warehouse-health-a/StoredProcedures/usp_LoadFactAccountActivity.sql'))) { throw 'warehouse-health-a is missing its load evidence' }
        if (-not (Test-Path -LiteralPath (Join-Path $temp 'warehouse-health-b/Views/rpt.vwCustomerCommercialSummary.sql'))) { throw 'warehouse-health-b is missing its scoped consumption view' }
        if (-not (Test-Path -LiteralPath (Join-Path $temp 'warehouse-health-no-trigger/Tables/fact.FactCampaignResponse.sql'))) { throw 'warehouse-health-no-trigger is missing the bridge false-positive control' }

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
        Write-Output 'PASS: warehouse-map-quality grades edge, coverage, query-rule, and structured-findings content with reachable green/red worlds'
        Write-Output 'PASS: warehouseModelHealth fixtures and tier/section/semantics/negative-control graders have independent reachable green/red worlds'
        Write-Output 'PASS: warehouse dead-column guard rejects INSERT, UPDATE, and both MERGE write branches'
        Write-Output 'PASS: -EnrichedMap emits the seven B-96 headings, the default fixture map stays frozen, and warehouse-mixed evidences EF Core'
        Write-Output 'PASS: warehouseDimensionBinding accepts a correct binding and rejects duplicate dimension / RegionKey-on-fact / natural-key-for-surrogate, with skill and add-entity channels separable'
        Write-Output 'PASS: warehouseFactBinding has reachable EXTEND / NEW TRANSACTION / PERIODIC SNAPSHOT / ABSTAIN worlds and rejects fragmentation, mixed grain, false abstention, and abstention plus DDL'
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
            { $_ -in @('warehouse-bind-sql','warehouse-bind-mixed') } {
                # -EnrichedMap: the binding decision needs business keys and the fact -> dimension
                # edge list, which the default (frozen) fixture map does not carry.
                $before = Initialize-WarehouseScenario $target -EnrichedMap
            }
            { $_ -in @('warehouse-fact-existing','warehouse-fact-new','warehouse-fact-snapshot','warehouse-fact-abstain') } {
                $before = Initialize-FactBindingScenario $target
            }
            'warehouse-map-quality' {
                $before = Initialize-WarehouseScenario $target -OmitMap
            }
            { $_ -in @('warehouse-health-default-a','warehouse-health-default-b','warehouse-health-deep-b','warehouse-health-clean','warehouse-health-convention','warehouse-health-no-trigger') } {
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
