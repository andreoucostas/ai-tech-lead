-- First-party report wrapper.

CREATE OR ALTER PROCEDURE dbo.RenderRegionRevenue
    @Region             NVARCHAR(8),
    @ThroughDate        DATE,
    @IncludeAdjustments BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        s.ProductCategory                                   AS ProductCategory,
        SUM(dbo.NetLineAmount(s.GrossAmount, s.TaxAmount))  AS NetRevenue
    FROM #ReportScope AS s
    GROUP BY s.ProductCategory
    ORDER BY s.ProductCategory;

    IF @IncludeAdjustments = 1
    BEGIN
        -- dbo.EmitExternalAdjustments is maintained outside this repository.
        EXEC dbo.EmitExternalAdjustments
            @Region      = @Region,
            @ThroughDate = @ThroughDate;
    END;
END;
GO
