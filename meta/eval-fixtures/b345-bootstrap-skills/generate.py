import os, json, sys, shutil

root = sys.argv[1]
if os.path.exists(root):
    shutil.rmtree(root)
os.makedirs(root)
os.chdir(root)


def w(p, s):
    os.makedirs(os.path.dirname(p) or '.', exist_ok=True)
    open(p, 'w', encoding='utf-8', newline='\n').write(s.lstrip('\n'))


# ---------- solution and projects (buildable shape: references and packages) ----------
guids = {'Api': '8F3C2A71-5B44-4D0E-9C61-2E7A0B9D14F3', 'Domain': '1D6E9B20-7A3F-4C85-B1E2-6F0D3C8A5B47',
         'Application': 'C4A1F7E8-2B90-4E6D-8A35-D7B19E0F2C66', 'Infrastructure': '5E8B3D92-0C17-4A6F-93D4-B2A6E1C7F085',
         'Reporting': 'A7D05C3E-9F62-4B18-85E0-3C4F1B9A6D27', 'Tests': '3B92E6F1-D84A-4C07-AE53-90F7C2D1B8E4'}
sln = ['Microsoft Visual Studio Solution File, Format Version 12.00']
for p, g in guids.items():
    path = f'tests\\Orders.Tests\\Orders.Tests.csproj' if p == 'Tests' else f'src\\Orders.{p}\\Orders.{p}.csproj'
    sln += [f'Project("{{9A19103F-16F7-4668-BE54-9A1E7A4F7556}}") = "Orders.{p}", "{path}", "{{{g}}}"', 'EndProject']
# Orders.sln is generated afterwards with `dotnet new sln` and `dotnet sln add`.


def csproj(sdk, refs=(), pkgs=(), extra=''):
    items = ''
    if pkgs:
        items += '  <ItemGroup>\n' + ''.join(f'    <PackageReference Include="{n}" Version="{v}" />\n' for n, v in pkgs) + '  </ItemGroup>\n'
    if refs:
        items += '  <ItemGroup>\n' + ''.join(f'    <ProjectReference Include="{r}" />\n' for r in refs) + '  </ItemGroup>\n'
    return f'''<Project Sdk="{sdk}">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>
{items}{extra}</Project>
'''


ef = ('Microsoft.EntityFrameworkCore.SqlServer', '8.0.10')
w('src/Orders.Domain/Orders.Domain.csproj', csproj('Microsoft.NET.Sdk'))
w('src/Orders.Application/Orders.Application.csproj', csproj('Microsoft.NET.Sdk', ['..\\Orders.Domain\\Orders.Domain.csproj'],
    [('Microsoft.Extensions.Logging.Abstractions', '8.0.2')]))
w('src/Orders.Infrastructure/Orders.Infrastructure.csproj', csproj('Microsoft.NET.Sdk',
    ['..\\Orders.Application\\Orders.Application.csproj', '..\\Orders.Domain\\Orders.Domain.csproj'],
    [ef, ('Microsoft.Extensions.Hosting.Abstractions', '8.0.1')]))
w('src/Orders.Reporting/Orders.Reporting.csproj', csproj('Microsoft.NET.Sdk', pkgs=[('Microsoft.Data.SqlClient', '5.2.2')]))
w('src/Orders.Api/Orders.Api.csproj', csproj('Microsoft.NET.Sdk.Web',
    ['..\\Orders.Application\\Orders.Application.csproj', '..\\Orders.Infrastructure\\Orders.Infrastructure.csproj',
     '..\\Orders.Reporting\\Orders.Reporting.csproj']))
w('tests/Orders.Tests/Orders.Tests.csproj', csproj('Microsoft.NET.Sdk',
    ['..\\..\\src\\Orders.Infrastructure\\Orders.Infrastructure.csproj', '..\\..\\src\\Orders.Reporting\\Orders.Reporting.csproj'],
    [('Microsoft.NET.Test.Sdk', '17.11.1'), ('xunit', '2.9.2'), ('xunit.runner.visualstudio', '2.8.2')],
    '  <ItemGroup>\n    <None Include="..\\..\\config\\feature-flags.json" Link="config\\feature-flags.json" CopyToOutputDirectory="PreserveNewest" />\n  </ItemGroup>\n'))

w('README.md', '''
# Orders

Order management service: customers, products, orders and invoices; integration events to other
services; CSV report exports; scheduled maintenance jobs; and calls to the pricing, shipping and tax services.

Build and test from the repository root:

    dotnet build Orders.sln
    dotnet test Orders.sln
''')

# ---------- entities; D1: vanilla CRUD (DbSet + EF configuration + controller), x4 ----------
ents = {'Customer': 'string Name, string Email', 'Product': 'string Sku, string Name, decimal Price',
        'Order': 'Guid CustomerId, DateTime PlacedAt, string Status, decimal Total',
        'Invoice': 'Guid OrderId, DateTime DueAt, bool Paid, decimal Amount'}
for e, fields in ents.items():
    lines = []
    for f in fields.split(', '):
        t, n = f.split()
        lines.append(f'    public {t} {n} {{ get; set; }}' + (' = "";' if t == 'string' else ''))
    props = '\n'.join(lines)
    w(f'src/Orders.Domain/Entities/{e}.cs', f'''
namespace Orders.Domain.Entities;

public class {e}
{{
    public Guid Id {{ get; set; }}
{props}
}}
''')
    w(f'src/Orders.Infrastructure/Persistence/Configurations/{e}Configuration.cs', f'''
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Orders.Domain.Entities;

namespace Orders.Infrastructure.Persistence.Configurations;

public class {e}Configuration : IEntityTypeConfiguration<{e}>
{{
    public void Configure(EntityTypeBuilder<{e}> builder)
    {{
        builder.ToTable("{e}s");
        builder.HasKey(x => x.Id);
    }}
}}
''')
    w(f'src/Orders.Api/Controllers/{e}sController.cs', f'''
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Orders.Domain.Entities;
using Orders.Infrastructure.Persistence;

namespace Orders.Api.Controllers;

[ApiController]
[Route("api/{e.lower()}s")]
public class {e}sController : ControllerBase
{{
    private readonly OrdersDbContext _db;
    public {e}sController(OrdersDbContext db) => _db = db;

    [HttpGet]
    public async Task<IActionResult> List() => Ok(await _db.{e}s.ToListAsync());

    [HttpGet("{{id:guid}}")]
    public async Task<IActionResult> Get(Guid id)
    {{
        var item = await _db.{e}s.FindAsync(id);
        return item is null ? NotFound() : Ok(item);
    }}

    [HttpPost]
    public async Task<IActionResult> Create({e} item)
    {{
        _db.{e}s.Add(item);
        await _db.SaveChangesAsync();
        return CreatedAtAction(nameof(Get), new {{ id = item.Id }}, item);
    }}
}}
''')
dbsets = '\n'.join(f'    public DbSet<{e}> {e}s => Set<{e}>();' for e in ents)
w('src/Orders.Infrastructure/Persistence/OrdersDbContext.cs', f'''
using Microsoft.EntityFrameworkCore;
using Orders.Domain.Entities;

namespace Orders.Infrastructure.Persistence;

public class OrdersDbContext : DbContext
{{
    public OrdersDbContext(DbContextOptions<OrdersDbContext> options) : base(options) {{ }}

{dbsets}

    protected override void OnModelCreating(ModelBuilder modelBuilder)
        => modelBuilder.ApplyConfigurationsFromAssembly(typeof(OrdersDbContext).Assembly);
}}
''')

# ---------- P1: integration events ----------
# Constellation per event: [EventVersion(N)] record, handler, EventRegistry line (topic + schema path),
# contracts/events/<topic>.v<N>.schema.json, a registry test.
# Non-obvious steps, in different files: (a) an unregistered event is not published;
# (b) the dispatcher dead-letters an event whose [EventVersion] disagrees with the .vN. of its registered schema.
w('src/Orders.Domain/Events/EventVersionAttribute.cs', '''
namespace Orders.Domain.Events;

[AttributeUsage(AttributeTargets.Class)]
public sealed class EventVersionAttribute : Attribute
{
    public EventVersionAttribute(int version) => Version = version;
    public int Version { get; }
}

public interface IIntegrationEvent
{
    Guid EventId { get; }
}
''')
events = {'OrderPlaced': ('order-placed', 1, 'Guid OrderId, Guid CustomerId, decimal Total'),
          'OrderShipped': ('order-shipped', 2, 'Guid OrderId, string Carrier, string TrackingNumber'),
          'InvoiceIssued': ('invoice-issued', 1, 'Guid InvoiceId, Guid OrderId, decimal Amount')}
reg_lines, handler_regs = [], []
for name, (topic, ver, fields) in events.items():
    w(f'src/Orders.Domain/Events/{name}Event.cs', f'''
namespace Orders.Domain.Events;

[EventVersion({ver})]
public sealed record {name}Event(Guid EventId, {fields}) : IIntegrationEvent;
''')
    w(f'src/Orders.Application/EventHandlers/{name}Handler.cs', f'''
using Microsoft.Extensions.Logging;
using Orders.Domain.Events;

namespace Orders.Application.EventHandlers;

public sealed class {name}Handler : IIntegrationEventHandler<{name}Event>
{{
    private readonly ILogger<{name}Handler> _logger;
    public {name}Handler(ILogger<{name}Handler> logger) => _logger = logger;

    public Task HandleAsync({name}Event @event, CancellationToken cancellationToken)
    {{
        _logger.LogInformation("Handling {{Topic}} {{EventId}}", "{topic}", @event.EventId);
        return Task.CompletedTask;
    }}
}}
''')
    props = {}
    for f in ('Guid EventId, ' + fields).split(', '):
        t, n = f.split()
        props[n] = {'type': 'string', 'format': 'uuid'} if t == 'Guid' else ({'type': 'string'} if t == 'string' else {'type': 'number'})
    w(f'contracts/events/{topic}.v{ver}.schema.json', json.dumps({'$schema': 'https://json-schema.org/draft/2020-12/schema',
        '$id': f'https://contracts.orders.example/events/{topic}.v{ver}.json', 'title': f'{name}Event', 'type': 'object',
        'properties': props, 'required': list(props), 'additionalProperties': False}, indent=2) + '\n')
    reg_lines.append(f'        Register<{name}Event, {name}Handler>("{topic}", "contracts/events/{topic}.v{ver}.schema.json");')
    handler_regs.append(f'builder.Services.AddScoped<{name}Handler>();')
w('src/Orders.Application/EventHandlers/IIntegrationEventHandler.cs', '''
using Orders.Domain.Events;

namespace Orders.Application.EventHandlers;

public interface IIntegrationEventHandler<in TEvent> where TEvent : IIntegrationEvent
{
    Task HandleAsync(TEvent @event, CancellationToken cancellationToken);
}
''')
w('src/Orders.Infrastructure/Messaging/EventRegistry.cs', '''
using Orders.Application.EventHandlers;
using Orders.Domain.Events;

namespace Orders.Infrastructure.Messaging;

public sealed class EventRegistry
{
    private readonly Dictionary<Type, Registration> _map = new();

    public EventRegistry()
    {
''' + '\n'.join(reg_lines) + '''
    }

    public bool TryGet(Type eventType, out Registration registration) => _map.TryGetValue(eventType, out registration!);

    private void Register<TEvent, THandler>(string topic, string schemaPath)
        where TEvent : IIntegrationEvent
        where THandler : IIntegrationEventHandler<TEvent>
        => _map[typeof(TEvent)] = new Registration(topic, typeof(THandler), schemaPath);
}

public sealed record Registration(string Topic, Type Handler, string SchemaPath);
''')
w('src/Orders.Infrastructure/Messaging/IMessagePublisher.cs', '''
namespace Orders.Infrastructure.Messaging;

public interface IMessagePublisher
{
    Task PublishAsync(string topic, object payload, CancellationToken cancellationToken);
}
''')
w('src/Orders.Infrastructure/Messaging/OutboxDispatcher.cs', '''
using System.Reflection;
using System.Text.RegularExpressions;
using Microsoft.Extensions.DependencyInjection;
using Orders.Domain.Events;

namespace Orders.Infrastructure.Messaging;

public sealed class OutboxDispatcher
{
    private static readonly Regex SchemaVersion = new(@"\\.v(\\d+)\\.schema\\.json$");
    private readonly EventRegistry _registry;
    private readonly IMessagePublisher _publisher;
    private readonly IServiceProvider _services;

    public OutboxDispatcher(EventRegistry registry, IMessagePublisher publisher, IServiceProvider services)
    {
        _registry = registry;
        _publisher = publisher;
        _services = services;
    }

    public async Task DispatchAsync(IIntegrationEvent @event, CancellationToken cancellationToken)
    {
        if (!_registry.TryGet(@event.GetType(), out var registration))
        {
            return;
        }

        var declared = @event.GetType().GetCustomAttribute<EventVersionAttribute>()?.Version;
        var match = SchemaVersion.Match(registration.SchemaPath);
        if (declared is null || !match.Success || int.Parse(match.Groups[1].Value) != declared)
        {
            await _publisher.PublishAsync(registration.Topic + ".dlq", @event, cancellationToken);
            return;
        }

        await _publisher.PublishAsync(registration.Topic, @event, cancellationToken);
        var handler = _services.GetRequiredService(registration.Handler);
        var handle = registration.Handler.GetMethod("HandleAsync")!;
        await (Task)handle.Invoke(handler, new object[] { @event, cancellationToken })!;
    }
}
''')
w('src/Orders.Application/Orders/IOutbox.cs', '''
using Orders.Domain.Events;

namespace Orders.Application.Orders;

public interface IOutbox
{
    void Enqueue(IIntegrationEvent @event);
    bool TryDequeue(out IIntegrationEvent @event);
}
''')
w('src/Orders.Application/Orders/OrderLifecycle.cs', '''
using Orders.Domain.Entities;
using Orders.Domain.Events;

namespace Orders.Application.Orders;

public sealed class OrderLifecycle
{
    private readonly IOutbox _outbox;
    public OrderLifecycle(IOutbox outbox) => _outbox = outbox;

    public void Placed(Order order)
        => _outbox.Enqueue(new OrderPlacedEvent(Guid.NewGuid(), order.Id, order.CustomerId, order.Total));

    public void Shipped(Order order, string carrier, string trackingNumber)
        => _outbox.Enqueue(new OrderShippedEvent(Guid.NewGuid(), order.Id, carrier, trackingNumber));

    public void Invoiced(Invoice invoice)
        => _outbox.Enqueue(new InvoiceIssuedEvent(Guid.NewGuid(), invoice.Id, invoice.OrderId, invoice.Amount));
}
''')
w('src/Orders.Infrastructure/Messaging/InMemoryOutbox.cs', '''
using System.Collections.Concurrent;
using Orders.Application.Orders;
using Orders.Domain.Events;

namespace Orders.Infrastructure.Messaging;

public sealed class InMemoryOutbox : IOutbox
{
    private readonly ConcurrentQueue<IIntegrationEvent> _queue = new();
    public void Enqueue(IIntegrationEvent @event) => _queue.Enqueue(@event);
    public bool TryDequeue(out IIntegrationEvent @event) => _queue.TryDequeue(out @event!);
}
''')
w('src/Orders.Infrastructure/Messaging/OutboxProcessor.cs', '''
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Orders.Application.Orders;

namespace Orders.Infrastructure.Messaging;

public sealed class OutboxProcessor : BackgroundService
{
    private readonly IOutbox _outbox;
    private readonly IServiceScopeFactory _scopes;

    public OutboxProcessor(IOutbox outbox, IServiceScopeFactory scopes)
    {
        _outbox = outbox;
        _scopes = scopes;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            while (_outbox.TryDequeue(out var @event))
            {
                using var scope = _scopes.CreateScope();
                await scope.ServiceProvider.GetRequiredService<OutboxDispatcher>().DispatchAsync(@event, stoppingToken);
            }
            await Task.Delay(TimeSpan.FromSeconds(1), stoppingToken);
        }
    }
}
''')
w('src/Orders.Api/Controllers/CheckoutController.cs', '''
using Microsoft.AspNetCore.Mvc;
using Orders.Application.Orders;
using Orders.Infrastructure.Persistence;

namespace Orders.Api.Controllers;

[ApiController]
[Route("api/checkout")]
public class CheckoutController : ControllerBase
{
    private readonly OrdersDbContext _db;
    private readonly OrderLifecycle _lifecycle;

    public CheckoutController(OrdersDbContext db, OrderLifecycle lifecycle)
    {
        _db = db;
        _lifecycle = lifecycle;
    }

    [HttpPost("{orderId:guid}/place")]
    public async Task<IActionResult> Place(Guid orderId)
    {
        var order = await _db.Orders.FindAsync(orderId);
        if (order is null) return NotFound();
        order.Status = "Placed";
        await _db.SaveChangesAsync();
        _lifecycle.Placed(order);
        return Accepted();
    }

    [HttpPost("{orderId:guid}/ship")]
    public async Task<IActionResult> Ship(Guid orderId, string carrier, string trackingNumber)
    {
        var order = await _db.Orders.FindAsync(orderId);
        if (order is null) return NotFound();
        order.Status = "Shipped";
        await _db.SaveChangesAsync();
        _lifecycle.Shipped(order, carrier, trackingNumber);
        return Accepted();
    }

    [HttpPost("invoices/{invoiceId:guid}/issue")]
    public async Task<IActionResult> Issue(Guid invoiceId)
    {
        var invoice = await _db.Invoices.FindAsync(invoiceId);
        if (invoice is null) return NotFound();
        _lifecycle.Invoiced(invoice);
        return Accepted();
    }
}
''')
w('src/Orders.Infrastructure/Messaging/ServiceBusPublisher.cs', '''
using Microsoft.Extensions.Logging;

namespace Orders.Infrastructure.Messaging;

public sealed class ServiceBusPublisher : IMessagePublisher
{
    private readonly ILogger<ServiceBusPublisher> _logger;
    public ServiceBusPublisher(ILogger<ServiceBusPublisher> logger) => _logger = logger;

    public Task PublishAsync(string topic, object payload, CancellationToken cancellationToken)
    {
        _logger.LogInformation("Publishing to {Topic}", topic);
        return Task.CompletedTask;
    }
}
''')

# ---------- P2: report exports ----------
# Constellation per export: export class, rpt.vw<Name>.sql view, ReportCatalog line,
# reports.export.<key> flag, a catalog test.
# Non-obvious steps, in different files: (a) ReportCatalog.Visible hides an export whose flag is missing;
# (b) exports read through the ReportReader login, so each view needs a GRANT in db/security/reporting-grants.sql.
w('src/Orders.Reporting/IReportExport.cs', '''
namespace Orders.Reporting;

public interface IReportExport
{
    string Key { get; }
    string ViewName { get; }
    Task<Stream> ExportCsvAsync(IReportReader reader, CancellationToken cancellationToken);
}
''')
w('src/Orders.Reporting/IReportReader.cs', '''
using System.Text;
using Microsoft.Data.SqlClient;

namespace Orders.Reporting;

public interface IReportReader
{
    Task<Stream> ReadCsvAsync(string viewName, CancellationToken cancellationToken);
}

// Connects with the "Reporting" connection string, which signs in as the ReportReader login.
public sealed class SqlReportReader : IReportReader
{
    private readonly string _connectionString;
    public SqlReportReader(string connectionString) => _connectionString = connectionString;

    public async Task<Stream> ReadCsvAsync(string viewName, CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new SqlCommand($"SELECT * FROM {viewName}", connection);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var csv = new StringBuilder();
        while (await reader.ReadAsync(cancellationToken))
        {
            var values = new object[reader.FieldCount];
            reader.GetValues(values);
            csv.AppendLine(string.Join(",", values));
        }
        return new MemoryStream(Encoding.UTF8.GetBytes(csv.ToString()));
    }
}
''')
exports = {
    'MonthlySales': ('monthly-sales', 'SELECT DATEFROMPARTS(YEAR(o.PlacedAt), MONTH(o.PlacedAt), 1) AS Month, SUM(o.Total) AS Sales\nFROM dbo.Orders AS o\nGROUP BY DATEFROMPARTS(YEAR(o.PlacedAt), MONTH(o.PlacedAt), 1);'),
    'OpenOrders': ('open-orders', "SELECT o.Id AS OrderId, o.CustomerId, o.PlacedAt, o.Total\nFROM dbo.Orders AS o\nWHERE o.Status IN ('Placed', 'Picking');"),
    'OverdueInvoices': ('overdue-invoices', 'SELECT i.Id AS InvoiceId, i.OrderId, i.DueAt, i.Amount\nFROM dbo.Invoices AS i\nWHERE i.Paid = 0 AND i.DueAt < SYSUTCDATETIME();'),
}
cat_lines, flags, grants, inline = [], {}, [], []
for name, (key, body) in exports.items():
    w(f'src/Orders.Reporting/Exports/{name}Export.cs', f'''
namespace Orders.Reporting.Exports;

public sealed class {name}Export : IReportExport
{{
    public string Key => "{key}";
    public string ViewName => "rpt.vw{name}";

    public Task<Stream> ExportCsvAsync(IReportReader reader, CancellationToken cancellationToken)
        => reader.ReadCsvAsync(ViewName, cancellationToken);
}}
''')
    w(f'db/views/rpt.vw{name}.sql', f'''
CREATE OR ALTER VIEW rpt.vw{name}
AS
{body}
''')
    cat_lines.append(f'        new Exports.{name}Export(),')
    flags[f'reports.export.{key}'] = True
    grants.append(f'GRANT SELECT ON rpt.vw{name} TO ReportReader;')
    inline.append(f'    [InlineData("{key}")]')
w('db/security/reporting-grants.sql', '''
-- Applied after the views. The export reader signs in as ReportReader.
''' + '\n'.join(grants) + '\n')
w('src/Orders.Reporting/ReportCatalog.cs', '''
namespace Orders.Reporting;

public static class ReportCatalog
{
    public static IReadOnlyList<IReportExport> All { get; } = new IReportExport[]
    {
''' + '\n'.join(cat_lines) + '''
    };

    public static IEnumerable<IReportExport> Visible(IReadOnlyDictionary<string, bool> flags)
        => All.Where(e => flags.TryGetValue("reports.export." + e.Key, out var enabled) && enabled);
}
''')
flags['orders.checkout.v2'] = False
w('config/feature-flags.json', json.dumps(flags, indent=2) + '\n')
w('src/Orders.Api/Controllers/ReportsController.cs', '''
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Orders.Reporting;

namespace Orders.Api.Controllers;

[ApiController]
[Route("api/reports")]
public class ReportsController : ControllerBase
{
    private readonly IReportReader _reader;
    private readonly IReadOnlyDictionary<string, bool> _flags;

    public ReportsController(IReportReader reader, IWebHostEnvironment env)
    {
        _reader = reader;
        var path = Path.Combine(env.ContentRootPath, "config", "feature-flags.json");
        _flags = JsonSerializer.Deserialize<Dictionary<string, bool>>(System.IO.File.ReadAllText(path))!;
    }

    [HttpGet]
    public IActionResult List() => Ok(ReportCatalog.Visible(_flags).Select(e => e.Key));

    [HttpGet("{key}")]
    public async Task<IActionResult> Export(string key, CancellationToken cancellationToken)
    {
        var export = ReportCatalog.Visible(_flags).FirstOrDefault(e => e.Key == key);
        if (export is null) return NotFound();
        return File(await export.ExportCsvAsync(_reader, cancellationToken), "text/csv", key + ".csv");
    }
}
''')

# ---------- D2: repeated anti-pattern (new HttpClient per call, sync-over-async .Result) ----------
for name, host in {'Pricing': 'pricing', 'Shipping': 'shipping', 'Tax': 'tax'}.items():
    w(f'src/Orders.Application/Services/{name}Client.cs', f'''
namespace Orders.Application.Services;

public class {name}Client
{{
    public string GetQuote(string id)
    {{
        var http = new HttpClient();
        return http.GetStringAsync($"https://{host}.internal.example/quote/{{id}}").Result;
    }}
}}
''')

# ---------- D3: one-line naming rule (*Dto records in Contracts/), not mirroring the entities ----------
for name, fields in {'AddressDto': 'string Line1, string City, string PostalCode', 'MoneyDto': 'decimal Amount, string Currency',
                     'PagedResultDto': 'int Page, int PageSize, int Total', 'OrderLineDto': 'string Sku, int Quantity, decimal UnitPrice',
                     'ShippingQuoteDto': 'string Carrier, decimal Cost, int Days'}.items():
    w(f'src/Orders.Application/Contracts/{name}.cs', f'''
namespace Orders.Application.Contracts;

public sealed record {name}({fields});
''')

# ---------- D4: two scheduled jobs (below the three-instance threshold) ----------
jobs = {'NightlyReconciliation': '0 2 * * *', 'PurgeStaleCarts': '30 3 * * *'}
for name in jobs:
    w(f'src/Orders.Application/Jobs/{name}Job.cs', f'''
namespace Orders.Application.Jobs;

public sealed class {name}Job : IScheduledJob
{{
    public string LockName => "job:{name.lower()}";
    public Task ExecuteAsync(CancellationToken cancellationToken) => Task.CompletedTask;
}}
''')
w('src/Orders.Application/Jobs/JobSchedule.cs', '''
namespace Orders.Application.Jobs;

public interface IScheduledJob
{
    string LockName { get; }
    Task ExecuteAsync(CancellationToken cancellationToken);
}

public static class JobSchedule
{
    public static IReadOnlyDictionary<Type, string> Cron { get; } = new Dictionary<Type, string>
    {
''' + '\n'.join(f'        [typeof({n}Job)] = "{c}",' for n, c in jobs.items()) + '''
    };
}
''')

# ---------- composition root: wires events, exports and controllers ----------
w('src/Orders.Api/Program.cs', '''
using Microsoft.EntityFrameworkCore;
using Orders.Application.EventHandlers;
using Orders.Application.Orders;
using Orders.Infrastructure.Messaging;
using Orders.Infrastructure.Persistence;
using Orders.Reporting;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllers();
builder.Services.AddDbContext<OrdersDbContext>(o => o.UseSqlServer(builder.Configuration.GetConnectionString("Orders")));
builder.Services.AddSingleton<EventRegistry>();
builder.Services.AddSingleton<IMessagePublisher, ServiceBusPublisher>();
builder.Services.AddSingleton<IOutbox, InMemoryOutbox>();
builder.Services.AddScoped<OrderLifecycle>();
builder.Services.AddScoped<OutboxDispatcher>();
builder.Services.AddHostedService<OutboxProcessor>();
''' + '\n'.join(handler_regs) + '''
builder.Services.AddSingleton<IReportReader>(_ => new SqlReportReader(builder.Configuration.GetConnectionString("Reporting")!));
var app = builder.Build();
app.MapControllers();
app.Run();
''')

# ---------- tests ----------
w('tests/Orders.Tests/EventRegistryTests.cs', '''
using Orders.Domain.Events;
using Orders.Infrastructure.Messaging;
using Xunit;

namespace Orders.Tests;

public class EventRegistryTests
{
    [Theory]
    [InlineData(typeof(OrderPlacedEvent))]
    [InlineData(typeof(OrderShippedEvent))]
    [InlineData(typeof(InvoiceIssuedEvent))]
    public void Event_is_registered(Type eventType) => Assert.True(new EventRegistry().TryGet(eventType, out _));
}
''')
w('tests/Orders.Tests/ReportCatalogTests.cs', '''
using System.Text.Json;
using Orders.Reporting;
using Xunit;

namespace Orders.Tests;

public class ReportCatalogTests
{
    private static readonly Dictionary<string, bool> Flags =
        JsonSerializer.Deserialize<Dictionary<string, bool>>(File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "config", "feature-flags.json")))!;

    [Theory]
''' + '\n'.join(inline) + '''
    public void Export_is_visible(string key) => Assert.Contains(ReportCatalog.Visible(Flags), e => e.Key == key);
}
''')
count = sum(len(f) for _, _, f in os.walk('.'))
print('files:', count)
