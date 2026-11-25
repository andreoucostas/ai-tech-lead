namespace StockSync.Api.Stock;

public sealed record StockItem(string Sku, int Quantity, DateTimeOffset UpdatedAt);

public sealed record StockSnapshot(DateTimeOffset TakenAt, IReadOnlyList<StockItem> Items);
