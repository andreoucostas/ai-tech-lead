"""B-515 fixture v3: fixture v2's Orders service (b345-bootstrap-skills/generate.py) built as Git history, one commit per
instance, plus one step per operation in a file no code references.

    python generate.py <empty-or-absent target directory>

Differences from v2, and only these:
- History: eleven dated commits. Each P1 (integration event) and P2 (report export) instance has its own commit, so
  `git show --name-only <commit>` lists every file that instance touches. The seams arrive in their own commits first.
- P1 gains `topic`: each event's commit adds its topic to infra/servicebus/topics.json, from which the platform
  pipeline provisions Service Bus; no code reads that file, so omitting it builds, passes the tests and fails on the
  first publish in a deployed environment.
- P2 gains `deploy`: each export's commit lists its view in db/deploy-order.txt, which the release pipeline applies in
  order; omitting it builds, passes the tests and never deploys the view.
- Orders.sln is written here, with the project GUIDs v2's generator names, instead of by `dotnet new sln`.
Everything else is v2's text. INSTANCE_FILES below is the grader's ground truth (grade.py); --check compares it with
the history this script wrote.
"""
import json
import os
import shutil
import subprocess
import sys

EVENTS = [('OrderPlaced', 'order-placed', 1, 'Guid OrderId, Guid CustomerId, decimal Total'),
          ('OrderShipped', 'order-shipped', 2, 'Guid OrderId, string Carrier, string TrackingNumber'),
          ('InvoiceIssued', 'invoice-issued', 1, 'Guid InvoiceId, Guid OrderId, decimal Amount')]
EXPORTS = [('MonthlySales', 'monthly-sales', 'SELECT DATEFROMPARTS(YEAR(o.PlacedAt), MONTH(o.PlacedAt), 1) AS Month, SUM(o.Total) AS Sales\nFROM dbo.Orders AS o\nGROUP BY DATEFROMPARTS(YEAR(o.PlacedAt), MONTH(o.PlacedAt), 1);'),
           ('OpenOrders', 'open-orders', "SELECT o.Id AS OrderId, o.CustomerId, o.PlacedAt, o.Total\nFROM dbo.Orders AS o\nWHERE o.Status IN ('Placed', 'Picking');"),
           ('OverdueInvoices', 'overdue-invoices', 'SELECT i.Id AS InvoiceId, i.OrderId, i.DueAt, i.Amount\nFROM dbo.Invoices AS i\nWHERE i.Paid = 0 AND i.DueAt < SYSUTCDATETIME();')]

# Each instance's commit touches exactly these files, mapped to the operation step each file carries.
INSTANCE_FILES = {}
for _n, _t, _v, _ in EVENTS:
    INSTANCE_FILES[_n] = {
        f'src/Orders.Domain/Events/{_n}Event.cs': 'event',
        f'src/Orders.Application/EventHandlers/{_n}Handler.cs': 'handler',
        f'contracts/events/{_t}.v{_v}.schema.json': 'schema',
        'src/Orders.Infrastructure/Messaging/EventRegistry.cs': 'registry',
        'src/Orders.Api/Program.cs': 'di',
        'tests/Orders.Tests/EventRegistryTests.cs': 'test',
        'src/Orders.Application/Orders/OrderLifecycle.cs': 'raise',
        'src/Orders.Api/Controllers/CheckoutController.cs': 'raise',
        'infra/servicebus/topics.json': 'topic',
    }
for _n, _k, _ in EXPORTS:
    INSTANCE_FILES[_n] = {
        f'src/Orders.Reporting/Exports/{_n}Export.cs': 'export',
        f'db/views/rpt.vw{_n}.sql': 'view',
        'src/Orders.Reporting/ReportCatalog.cs': 'catalog',
        'config/feature-flags.json': 'flag',
        'db/security/reporting-grants.sql': 'grant',
        'tests/Orders.Tests/ReportCatalogTests.cs': 'test',
        'db/deploy-order.txt': 'deploy',
    }

# (date, message, what the commit adds). Instances interleave with the decoys, as a team's history would.
COMMITS = [
    ('2026-01-12T10:00:00+00:00', 'Orders service: entities, persistence and CRUD endpoints', 'core'),
    ('2026-01-26T10:00:00+00:00', 'Add the integration event pipeline', 'events-infra'),
    ('2026-02-09T10:00:00+00:00', 'Add the order-placed integration event', 'OrderPlaced'),
    ('2026-02-23T10:00:00+00:00', 'Add the report export pipeline', 'reports-infra'),
    ('2026-03-09T10:00:00+00:00', 'Add the monthly-sales report export', 'MonthlySales'),
    ('2026-03-23T10:00:00+00:00', 'Add the order-shipped integration event', 'OrderShipped'),
    ('2026-04-06T10:00:00+00:00', 'Add the pricing, shipping and tax clients', 'clients'),
    ('2026-04-20T10:00:00+00:00', 'Add the open-orders report export', 'OpenOrders'),
    ('2026-05-04T10:00:00+00:00', 'Add the invoice-issued integration event', 'InvoiceIssued'),
    ('2026-05-18T10:00:00+00:00', 'Add scheduled job scaffolding', 'jobs'),
    ('2026-06-01T10:00:00+00:00', 'Add the overdue-invoices report export', 'OverdueInvoices'),
]

GUIDS = {'Api': '8F3C2A71-5B44-4D0E-9C61-2E7A0B9D14F3', 'Domain': '1D6E9B20-7A3F-4C85-B1E2-6F0D3C8A5B47',
         'Application': 'C4A1F7E8-2B90-4E6D-8A35-D7B19E0F2C66', 'Infrastructure': '5E8B3D92-0C17-4A6F-93D4-B2A6E1C7F085',
         'Reporting': 'A7D05C3E-9F62-4B18-85E0-3C4F1B9A6D27', 'Tests': '3B92E6F1-D84A-4C07-AE53-90F7C2D1B8E4'}


def w(p, s):
    os.makedirs(os.path.dirname(p) or '.', exist_ok=True)
    with open(p, 'w', encoding='utf-8', newline='\n') as f:
        f.write(s.lstrip('\n'))


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


def write_core():
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
    sln = ['', 'Microsoft Visual Studio Solution File, Format Version 12.00', '# Visual Studio Version 17']
    for p, g in GUIDS.items():
        path = 'tests\\Orders.Tests\\Orders.Tests.csproj' if p == 'Tests' else f'src\\Orders.{p}\\Orders.{p}.csproj'
        sln += [f'Project("{{9A19103F-16F7-4668-BE54-9A1E7A4F7556}}") = "Orders.{p}", "{path}", "{{{g}}}"', 'EndProject']
    sln += ['Global', '\tGlobalSection(SolutionConfigurationPlatforms) = preSolution', '\t\tDebug|Any CPU = Debug|Any CPU',
            '\t\tRelease|Any CPU = Release|Any CPU', '\tEndGlobalSection', '\tGlobalSection(ProjectConfigurationPlatforms) = postSolution']
    for g in GUIDS.values():
        for c in ('Debug', 'Release'):
            sln += [f'\t\t{{{g}}}.{c}|Any CPU.ActiveCfg = {c}|Any CPU', f'\t\t{{{g}}}.{c}|Any CPU.Build.0 = {c}|Any CPU']
    sln += ['\tEndGlobalSection', 'EndGlobal', '']
    w('Orders.sln', '\n'.join(sln))
    w('README.md', '''
# Orders

Order management service: customers, products, orders and invoices; integration events to other
services; CSV report exports; scheduled maintenance jobs; and calls to the pricing, shipping and tax services.

Build and test from the repository root:

    dotnet build Orders.sln
    dotnet test Orders.sln
''')
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
    for name, fields in {'AddressDto': 'string Line1, string City, string PostalCode', 'MoneyDto': 'decimal Amount, string Currency',
                         'PagedResultDto': 'int Page, int PageSize, int Total', 'OrderLineDto': 'string Sku, int Quantity, decimal UnitPrice',
                         'ShippingQuoteDto': 'string Carrier, decimal Cost, int Days'}.items():
        w(f'src/Orders.Application/Contracts/{name}.cs', f'''
namespace Orders.Application.Contracts;

public sealed record {name}({fields});
''')
    w('config/feature-flags.json', json.dumps({'orders.checkout.v2': False}, indent=2) + '\n')


def write_events_infra(events):
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
    w('src/Orders.Application/EventHandlers/IIntegrationEventHandler.cs', '''
using Orders.Domain.Events;

namespace Orders.Application.EventHandlers;

public interface IIntegrationEventHandler<in TEvent> where TEvent : IIntegrationEvent
{
    Task HandleAsync(TEvent @event, CancellationToken cancellationToken);
}
''')
    reg_lines = [f'        Register<{n}Event, {n}Handler>("{t}", "contracts/events/{t}.v{v}.schema.json");' for n, t, v, _ in events]
    w('src/Orders.Infrastructure/Messaging/EventRegistry.cs', '''
using Orders.Application.EventHandlers;
using Orders.Domain.Events;

namespace Orders.Infrastructure.Messaging;

public sealed class EventRegistry
{
    private readonly Dictionary<Type, Registration> _map = new();

    public EventRegistry()
    {
''' + ''.join(line + '\n' for line in reg_lines) + '''    }

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
    w('infra/servicebus/README.md', '''
# Service Bus

The platform pipeline provisions the `sb-orders` namespace and every topic in `topics.json`, each with its
dead-letter topic. The service has send rights only and cannot create a topic at runtime.
''')
    w('infra/servicebus/topics.json', json.dumps({'namespace': 'sb-orders', 'topics': [
        {'name': t, 'deadLetter': t + '.dlq'} for _, t, _, _ in events]}, indent=2) + '\n')
    for name, topic, ver, fields in events:
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
    names = [n for n, _, _, _ in events]
    raise_methods = {
        'OrderPlaced': '''    public void Placed(Order order)
        => _outbox.Enqueue(new OrderPlacedEvent(Guid.NewGuid(), order.Id, order.CustomerId, order.Total));
''',
        'OrderShipped': '''    public void Shipped(Order order, string carrier, string trackingNumber)
        => _outbox.Enqueue(new OrderShippedEvent(Guid.NewGuid(), order.Id, carrier, trackingNumber));
''',
        'InvoiceIssued': '''    public void Invoiced(Invoice invoice)
        => _outbox.Enqueue(new InvoiceIssuedEvent(Guid.NewGuid(), invoice.Id, invoice.OrderId, invoice.Amount));
'''}
    w('src/Orders.Application/Orders/OrderLifecycle.cs', '''
using Orders.Domain.Entities;
using Orders.Domain.Events;

namespace Orders.Application.Orders;

public sealed class OrderLifecycle
{
    private readonly IOutbox _outbox;
    public OrderLifecycle(IOutbox outbox) => _outbox = outbox;
''' + ''.join('\n' + raise_methods[n] for n in names) + '''}
''')
    if not events:
        return
    actions = {
        'OrderPlaced': '''    [HttpPost("{orderId:guid}/place")]
    public async Task<IActionResult> Place(Guid orderId)
    {
        var order = await _db.Orders.FindAsync(orderId);
        if (order is null) return NotFound();
        order.Status = "Placed";
        await _db.SaveChangesAsync();
        _lifecycle.Placed(order);
        return Accepted();
    }
''',
        'OrderShipped': '''    [HttpPost("{orderId:guid}/ship")]
    public async Task<IActionResult> Ship(Guid orderId, string carrier, string trackingNumber)
    {
        var order = await _db.Orders.FindAsync(orderId);
        if (order is null) return NotFound();
        order.Status = "Shipped";
        await _db.SaveChangesAsync();
        _lifecycle.Shipped(order, carrier, trackingNumber);
        return Accepted();
    }
''',
        'InvoiceIssued': '''    [HttpPost("invoices/{invoiceId:guid}/issue")]
    public async Task<IActionResult> Issue(Guid invoiceId)
    {
        var invoice = await _db.Invoices.FindAsync(invoiceId);
        if (invoice is null) return NotFound();
        _lifecycle.Invoiced(invoice);
        return Accepted();
    }
'''}
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

''' + '\n'.join(actions[n] for n in names) + '''}
''')
    rows = ''.join(f'    [InlineData(typeof({n}Event))]\n' for n in names)
    w('tests/Orders.Tests/EventRegistryTests.cs', '''
using Orders.Domain.Events;
using Orders.Infrastructure.Messaging;
using Xunit;

namespace Orders.Tests;

public class EventRegistryTests
{
    [Theory]
''' + rows + '''    public void Event_is_registered(Type eventType) => Assert.True(new EventRegistry().TryGet(eventType, out _));
}
''')


def write_reports_infra(exports):
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
    cat_lines, flags, grants, inline, order = [], {}, [], [], []
    for name, key, body in exports:
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
        order.append(f'views/rpt.vw{name}.sql')
    w('db/security/reporting-grants.sql', '''
-- Applied after the views. The export reader signs in as ReportReader.
''' + ''.join(g + '\n' for g in grants))
    w('db/deploy-order.txt', '''
# The release pipeline applies these scripts in this order. A script not listed here is not deployed.
''' + ''.join(o + '\n' for o in order) + 'security/reporting-grants.sql\n')
    w('src/Orders.Reporting/ReportCatalog.cs', '''
namespace Orders.Reporting;

public static class ReportCatalog
{
    public static IReadOnlyList<IReportExport> All { get; } = new IReportExport[]
    {
''' + ''.join(line + '\n' for line in cat_lines) + '''    };

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
    if exports:
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
''' + ''.join(line + '\n' for line in inline) + '''    public void Export_is_visible(string key) => Assert.Contains(ReportCatalog.Visible(Flags), e => e.Key == key);
}
''')


def write_clients():
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


def write_jobs():
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
''' + ''.join(f'        [typeof({n}Job)] = "{c}",\n' for n, c in jobs.items()) + '''    };
}
''')


def write_program(events_infra, events, reports_infra):
    usings = ['using Microsoft.EntityFrameworkCore;']
    if events:
        usings.append('using Orders.Application.EventHandlers;')
    if events_infra:
        usings += ['using Orders.Application.Orders;', 'using Orders.Infrastructure.Messaging;']
    usings.append('using Orders.Infrastructure.Persistence;')
    if reports_infra:
        usings.append('using Orders.Reporting;')
    body = ['builder.Services.AddControllers();',
            'builder.Services.AddDbContext<OrdersDbContext>(o => o.UseSqlServer(builder.Configuration.GetConnectionString("Orders")));']
    if events_infra:
        body += ['builder.Services.AddSingleton<EventRegistry>();', 'builder.Services.AddSingleton<IMessagePublisher, ServiceBusPublisher>();',
                 'builder.Services.AddSingleton<IOutbox, InMemoryOutbox>();', 'builder.Services.AddScoped<OrderLifecycle>();',
                 'builder.Services.AddScoped<OutboxDispatcher>();', 'builder.Services.AddHostedService<OutboxProcessor>();']
        body += [f'builder.Services.AddScoped<{n}Handler>();' for n, _, _, _ in events]
    if reports_infra:
        body.append('builder.Services.AddSingleton<IReportReader>(_ => new SqlReportReader(builder.Configuration.GetConnectionString("Reporting")!));')
    w('src/Orders.Api/Program.cs', '\n'.join(usings) + '\n\nvar builder = WebApplication.CreateBuilder(args);\n' + '\n'.join(body) +
      '\nvar app = builder.Build();\napp.MapControllers();\napp.Run();\n')


def write_state(added):
    write_core()
    events_infra = 'events-infra' in added
    events = [e for e in EVENTS if e[0] in added]
    reports_infra = 'reports-infra' in added
    if events_infra:
        write_events_infra(events)
    if reports_infra:
        write_reports_infra([x for x in EXPORTS if x[0] in added])
    if 'clients' in added:
        write_clients()
    if 'jobs' in added:
        write_jobs()
    write_program(events_infra, events, reports_infra)


def git(*args, env=None):
    return subprocess.run(['git', *args], check=True, capture_output=True, text=True, encoding='utf-8', env=env).stdout


def generate(root):
    if os.path.exists(root):
        shutil.rmtree(root)
    os.makedirs(root)
    os.chdir(root)
    git('init', '--quiet')
    git('config', 'user.email', 'dev@orders.example')
    git('config', 'user.name', 'Orders Team')
    git('config', 'core.autocrlf', 'false')
    added = set()
    for date, message, item in COMMITS:
        added.add(item)
        write_state(added)
        git('add', '-A')
        env = dict(os.environ, GIT_AUTHOR_DATE=date, GIT_COMMITTER_DATE=date)
        git('commit', '--quiet', '-m', message, env=env)


def check(root):
    """The history this script wrote: each instance's own commit touches exactly INSTANCE_FILES[instance]."""
    os.chdir(root)
    problems = []
    log = git('log', '--reverse', '--format=%H %s').splitlines()
    if len(log) < len(COMMITS):
        problems.append(f'expected at least {len(COMMITS)} commits, found {len(log)}')
    for (_, message, item), line in zip(COMMITS, log):
        sha, subject = line.split(' ', 1)
        if subject != message:
            problems.append(f'commit {sha[:8]}: subject {subject!r}, expected {message!r}')
            continue
        if item in INSTANCE_FILES:
            touched = set(git('show', '--name-only', '--format=', sha).split())
            expected = set(INSTANCE_FILES[item])
            if touched != expected:
                problems.append(f'{item}: commit touches {sorted(touched ^ expected)} beyond or short of its ground truth')
    return problems


if __name__ == '__main__':
    if len(sys.argv) == 3 and sys.argv[1] == '--check':
        found = check(os.path.abspath(sys.argv[2]))
        print('\n'.join(found) if found else 'CHECK PASS: every instance commit touches exactly its ground-truth files')
        sys.exit(1 if found else 0)
    if len(sys.argv) != 2:
        sys.exit('usage: generate.py <target> | generate.py --check <target>')
    generate(os.path.abspath(sys.argv[1]))
    print('files:', sum(len(f) for d, _, f in os.walk('.') if '.git' not in d.split(os.sep)))
