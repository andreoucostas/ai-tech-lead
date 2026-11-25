using StockSync.Api.Export;
using StockSync.Api.Stock;
using StockSync.Api.Sync;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddHttpClient<SupplierFeedClient>(c => c.BaseAddress = new Uri(builder.Configuration["Supplier:BaseUrl"]!));
builder.Services.AddSingleton<StockStore>();
builder.Services.AddSingleton<SyncRunLog>();
builder.Services.AddScoped<SyncRunner>();
builder.Services.AddHostedService<NightlySyncWorker>();
builder.Services.AddSingleton<ExportWriter>();
builder.Services.AddControllers();
var app = builder.Build();
app.UseStaticFiles();
app.MapControllers();
app.Run();

public partial class Program { }
