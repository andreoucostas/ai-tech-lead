-- Scalar helper for the region-revenue report.

CREATE OR ALTER FUNCTION dbo.NetLineAmount
(
    @GrossAmount DECIMAL(19,4),
    @TaxAmount   DECIMAL(19,4)
)
RETURNS DECIMAL(19,4)
AS
BEGIN
    RETURN @GrossAmount - @TaxAmount;
END;
GO
