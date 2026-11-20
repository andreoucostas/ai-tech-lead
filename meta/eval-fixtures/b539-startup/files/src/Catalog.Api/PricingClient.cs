namespace Catalog.Api;

public sealed class PricingOptions
{
    public string BaseAddress { get; set; } = "http://localhost:5999/";
    public int RetryCount { get; set; } = 0;
}

public sealed class PricingClient
{
    private readonly HttpClient _http;

    public PricingClient(HttpClient http) => _http = http;

    public async Task<decimal> GetPriceAsync(string sku, CancellationToken ct = default)
    {
        var text = await _http.GetStringAsync($"prices/{sku}", ct);
        return decimal.Parse(text, System.Globalization.CultureInfo.InvariantCulture);
    }
}
