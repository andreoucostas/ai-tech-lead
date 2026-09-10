-- First-party report entry point.

IF OBJECT_ID(N'dbo.InvoiceLine', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.InvoiceLine
    (
        InvoiceLineId   BIGINT        NOT NULL PRIMARY KEY,
        RegionCode      NVARCHAR(8)   NOT NULL,
        ProductCategory NVARCHAR(40)  NOT NULL,
        InvoiceDate     DATE          NOT NULL,
        Status          NVARCHAR(16)  NOT NULL,
        GrossAmount     DECIMAL(19,4) NOT NULL,
        TaxAmount       DECIMAL(19,4) NOT NULL
    );
END;
GO

CREATE OR ALTER PROCEDURE dbo.RunRegionRevenue
    @Region      NVARCHAR(8),
    @ThroughDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    CREATE TABLE #ReportScope
    (
        ProductCategory NVARCHAR(40)  NOT NULL,
        GrossAmount     DECIMAL(19,4) NOT NULL,
        TaxAmount       DECIMAL(19,4) NOT NULL
    );

    INSERT INTO #ReportScope (ProductCategory, GrossAmount, TaxAmount)
    SELECT il.ProductCategory, il.GrossAmount, il.TaxAmount
    FROM dbo.InvoiceLine AS il
    WHERE il.RegionCode = @Region
      AND il.InvoiceDate <= @ThroughDate
      AND il.Status <> N'Draft';

    EXEC dbo.RenderRegionRevenue
        @Region             = @Region,
        @ThroughDate        = @ThroughDate,
        @IncludeAdjustments = 1;

    DROP TABLE #ReportScope;
END;
GO
