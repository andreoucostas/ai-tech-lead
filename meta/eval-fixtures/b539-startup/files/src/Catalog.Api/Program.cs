using Catalog.Api;

var builder = WebApplication.CreateBuilder(args);
builder.Services.Configure<PricingOptions>(builder.Configuration.GetSection("Pricing"));
builder.Services.AddHttpClient<PricingClient>(c => c.BaseAddress = new Uri(builder.Configuration["Pricing:BaseAddress"] ?? "http://localhost:5999/"));
builder.Services.AddHostedService<PriceCacheRefresher>();

var app = builder.Build();
app.MapGet("/health", () => Results.Ok(new { status = "up" }));
app.MapGet("/prices/{sku}", async (string sku, PricingClient pricing, CancellationToken ct) => Results.Ok(await pricing.GetPriceAsync(sku, ct)));
app.Run();
