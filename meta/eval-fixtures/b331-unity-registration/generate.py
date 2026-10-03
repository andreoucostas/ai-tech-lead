# B-331 fixture (meta only; never shipped). A net8.0 billing service whose Core, Data and Integration projects each register
# what they implement with Unity in their own IoCConfig.Configure(IUnityContainer); Program.cs calls the three and resolves
# controllers from Unity. Nothing written into the fixture names the measurement. Usage: python generate.py <dir>
import os, sys, shutil

root = sys.argv[1]
if os.path.exists(root):
    shutil.rmtree(root)
os.makedirs(root)
os.chdir(root)


def w(p, s):
    os.makedirs(os.path.dirname(p) or '.', exist_ok=True)
    open(p, 'w', encoding='utf-8', newline='\n').write(s.lstrip('\n'))


def csproj(sdk, refs=(), pkgs=()):
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
{items}</Project>
'''


unity = ('Unity', '5.11.10')
core = '..\\Billing.Core\\Billing.Core.csproj'
w('.gitignore', 'bin/\nobj/\n.vs/\nTestResults/\n*.user\n')
w('src/Billing.Core/Billing.Core.csproj', csproj('Microsoft.NET.Sdk', pkgs=[unity]))
w('src/Billing.Data/Billing.Data.csproj', csproj('Microsoft.NET.Sdk', [core], [unity]))
w('src/Billing.Integration/Billing.Integration.csproj', csproj('Microsoft.NET.Sdk', [core], [unity]))
w('src/Billing.Api/Billing.Api.csproj', csproj('Microsoft.NET.Sdk.Web',
    [core, '..\\Billing.Data\\Billing.Data.csproj', '..\\Billing.Integration\\Billing.Integration.csproj'], [unity]))
w('tests/Billing.Tests/Billing.Tests.csproj', csproj('Microsoft.NET.Sdk', ['..\\..\\src\\Billing.Core\\Billing.Core.csproj'],
    [('Microsoft.NET.Test.Sdk', '17.11.1'), ('xunit', '2.9.2'), ('xunit.runner.visualstudio', '2.8.2')]))

w('README.md', '''
# Billing

Invoicing and payments service: invoices with tax and loyalty discounts, card payments through the
payment gateway, e-mail receipts and currency conversion.

Build and test from the repository root:

    dotnet build Billing.sln
    dotnet test Billing.sln

## Dependency injection

Application services are registered with Unity. Each project registers the services it implements in
its own `IoCConfig.Configure(IUnityContainer)`, and `Program.cs` calls the three in turn; controllers are
resolved from the container by `UnityControllerActivator`. Example:
[`src/Billing.Core/IoCConfig.cs`](src/Billing.Core/IoCConfig.cs).
''')

# ---------- Core: domain, ports and policies ----------
w('src/Billing.Core/Customers/Customer.cs', '''
namespace Billing.Core.Customers;

public sealed class Customer
{
    public Guid Id { get; init; }
    public string Name { get; init; } = "";
    public string Email { get; init; } = "";
    public int YearsActive { get; init; }
}
''')
w('src/Billing.Core/Customers/ICustomerRepository.cs', '''
namespace Billing.Core.Customers;

public interface ICustomerRepository
{
    Customer? Find(Guid id);
    void Save(Customer customer);
}
''')
w('src/Billing.Core/Invoices/Invoice.cs', '''
namespace Billing.Core.Invoices;

public sealed class Invoice
{
    public Guid Id { get; init; }
    public Guid CustomerId { get; init; }
    public decimal Amount { get; init; }
    public DateTime IssuedAt { get; init; }
    public DateTime DueAt { get; init; }
    public bool Paid { get; set; }
}
''')
w('src/Billing.Core/Invoices/IInvoiceRepository.cs', '''
namespace Billing.Core.Invoices;

public interface IInvoiceRepository
{
    Invoice? Find(Guid id);
    void Save(Invoice invoice);
}
''')
w('src/Billing.Core/Payments/Payment.cs', '''
namespace Billing.Core.Payments;

public sealed class Payment
{
    public Guid Id { get; init; }
    public Guid InvoiceId { get; init; }
    public decimal Amount { get; init; }
    public DateTime PaidAt { get; init; }
    public string Reference { get; init; } = "";
}
''')
w('src/Billing.Core/Payments/IPaymentRepository.cs', '''
namespace Billing.Core.Payments;

public interface IPaymentRepository
{
    void Add(Payment payment);
    IReadOnlyList<Payment> ForInvoice(Guid invoiceId);
}
''')
w('src/Billing.Core/Time/IClock.cs', '''
namespace Billing.Core.Time;

public interface IClock
{
    DateTime UtcNow { get; }
}
''')
w('src/Billing.Core/Time/SystemClock.cs', '''
namespace Billing.Core.Time;

public sealed class SystemClock : IClock
{
    public DateTime UtcNow => DateTime.UtcNow;
}
''')
w('src/Billing.Core/Tax/ITaxPolicy.cs', '''
namespace Billing.Core.Tax;

public interface ITaxPolicy
{
    decimal TaxFor(decimal net);
}
''')
w('src/Billing.Core/Tax/StandardTaxPolicy.cs', '''
namespace Billing.Core.Tax;

public sealed class StandardTaxPolicy : ITaxPolicy
{
    private const decimal Rate = 0.20m;

    public decimal TaxFor(decimal net) => Math.Round(net * Rate, 2, MidpointRounding.AwayFromZero);
}
''')
w('src/Billing.Core/Discounts/IDiscountPolicy.cs', '''
using Billing.Core.Customers;

namespace Billing.Core.Discounts;

public interface IDiscountPolicy
{
    decimal DiscountFor(Customer customer, decimal net);
}
''')
w('src/Billing.Core/Discounts/LoyaltyDiscountPolicy.cs', '''
using Billing.Core.Customers;

namespace Billing.Core.Discounts;

public sealed class LoyaltyDiscountPolicy : IDiscountPolicy
{
    public decimal DiscountFor(Customer customer, decimal net)
        => customer.YearsActive >= 5 ? Math.Round(net * 0.05m, 2, MidpointRounding.AwayFromZero) : 0m;
}
''')
w('src/Billing.Core/Invoices/IInvoiceCalculator.cs', '''
using Billing.Core.Customers;

namespace Billing.Core.Invoices;

public interface IInvoiceCalculator
{
    decimal TotalFor(Invoice invoice, Customer customer);
}
''')
w('src/Billing.Core/Invoices/InvoiceCalculator.cs', '''
using Billing.Core.Customers;
using Billing.Core.Discounts;
using Billing.Core.Tax;

namespace Billing.Core.Invoices;

public sealed class InvoiceCalculator : IInvoiceCalculator
{
    private readonly ITaxPolicy _tax;
    private readonly IDiscountPolicy _discount;

    public InvoiceCalculator(ITaxPolicy tax, IDiscountPolicy discount)
    {
        _tax = tax;
        _discount = discount;
    }

    public decimal TotalFor(Invoice invoice, Customer customer)
    {
        var net = invoice.Amount - _discount.DiscountFor(customer, invoice.Amount);
        return net + _tax.TaxFor(net);
    }
}
''')
w('src/Billing.Core/IoCConfig.cs', '''
using Billing.Core.Discounts;
using Billing.Core.Invoices;
using Billing.Core.Tax;
using Billing.Core.Time;
using Unity;
using Unity.Lifetime;

namespace Billing.Core;

public static class IoCConfig
{
    public static void Configure(IUnityContainer container)
    {
        container.RegisterType<IClock, SystemClock>(new ContainerControlledLifetimeManager());
        container.RegisterType<ITaxPolicy, StandardTaxPolicy>(new ContainerControlledLifetimeManager());
        container.RegisterType<IDiscountPolicy, LoyaltyDiscountPolicy>(new HierarchicalLifetimeManager());
        container.RegisterType<IInvoiceCalculator, InvoiceCalculator>(new HierarchicalLifetimeManager());
    }
}
''')

# ---------- Data: in-memory stores ----------
w('src/Billing.Data/InMemoryInvoiceRepository.cs', '''
using System.Collections.Concurrent;
using Billing.Core.Invoices;

namespace Billing.Data;

public sealed class InMemoryInvoiceRepository : IInvoiceRepository
{
    private readonly ConcurrentDictionary<Guid, Invoice> _items = new();

    public Invoice? Find(Guid id) => _items.TryGetValue(id, out var invoice) ? invoice : null;

    public void Save(Invoice invoice) => _items[invoice.Id] = invoice;
}
''')
w('src/Billing.Data/InMemoryCustomerRepository.cs', '''
using System.Collections.Concurrent;
using Billing.Core.Customers;

namespace Billing.Data;

public sealed class InMemoryCustomerRepository : ICustomerRepository
{
    private readonly ConcurrentDictionary<Guid, Customer> _items = new();

    public Customer? Find(Guid id) => _items.TryGetValue(id, out var customer) ? customer : null;

    public void Save(Customer customer) => _items[customer.Id] = customer;
}
''')
w('src/Billing.Data/InMemoryPaymentRepository.cs', '''
using System.Collections.Concurrent;
using Billing.Core.Payments;

namespace Billing.Data;

public sealed class InMemoryPaymentRepository : IPaymentRepository
{
    private readonly ConcurrentBag<Payment> _items = new();

    public void Add(Payment payment) => _items.Add(payment);

    public IReadOnlyList<Payment> ForInvoice(Guid invoiceId) => _items.Where(p => p.InvoiceId == invoiceId).ToList();
}
''')
w('src/Billing.Data/IoCConfig.cs', '''
using Billing.Core.Customers;
using Billing.Core.Invoices;
using Billing.Core.Payments;
using Unity;
using Unity.Lifetime;

namespace Billing.Data;

public static class IoCConfig
{
    public static void Configure(IUnityContainer container)
    {
        container.RegisterType<IInvoiceRepository, InMemoryInvoiceRepository>(new ContainerControlledLifetimeManager());
        container.RegisterType<ICustomerRepository, InMemoryCustomerRepository>(new ContainerControlledLifetimeManager());
        container.RegisterType<IPaymentRepository, InMemoryPaymentRepository>(new ContainerControlledLifetimeManager());
    }
}
''')

# ---------- Integration: external clients ----------
w('src/Billing.Integration/Payments/IPaymentGatewayClient.cs', '''
namespace Billing.Integration.Payments;

public interface IPaymentGatewayClient
{
    Task<string> ChargeAsync(Guid invoiceId, decimal amount, CancellationToken cancellationToken);
}
''')
w('src/Billing.Integration/Payments/PaymentGatewayClient.cs', '''
namespace Billing.Integration.Payments;

public sealed class PaymentGatewayClient : IPaymentGatewayClient
{
    public Task<string> ChargeAsync(Guid invoiceId, decimal amount, CancellationToken cancellationToken)
        => Task.FromResult("ch_" + invoiceId.ToString("N"));
}
''')
w('src/Billing.Integration/Notifications/IEmailNotifier.cs', '''
namespace Billing.Integration.Notifications;

public interface IEmailNotifier
{
    Task SendReceiptAsync(string email, decimal amount, CancellationToken cancellationToken);
}
''')
w('src/Billing.Integration/Notifications/SmtpEmailNotifier.cs', '''
namespace Billing.Integration.Notifications;

public sealed class SmtpEmailNotifier : IEmailNotifier
{
    public Task SendReceiptAsync(string email, decimal amount, CancellationToken cancellationToken) => Task.CompletedTask;
}
''')
w('src/Billing.Integration/Rates/IExchangeRateClient.cs', '''
namespace Billing.Integration.Rates;

public interface IExchangeRateClient
{
    Task<decimal> RateAsync(string fromCurrency, string toCurrency, CancellationToken cancellationToken);
}
''')
w('src/Billing.Integration/Rates/ExchangeRateClient.cs', '''
namespace Billing.Integration.Rates;

public sealed class ExchangeRateClient : IExchangeRateClient
{
    public Task<decimal> RateAsync(string fromCurrency, string toCurrency, CancellationToken cancellationToken)
        => Task.FromResult(fromCurrency == toCurrency ? 1m : 1.17m);
}
''')
w('src/Billing.Integration/IoCConfig.cs', '''
using Billing.Integration.Notifications;
using Billing.Integration.Payments;
using Billing.Integration.Rates;
using Unity;
using Unity.Lifetime;

namespace Billing.Integration;

public static class IoCConfig
{
    public static void Configure(IUnityContainer container)
    {
        container.RegisterType<IPaymentGatewayClient, PaymentGatewayClient>(new HierarchicalLifetimeManager());
        container.RegisterType<IEmailNotifier, SmtpEmailNotifier>(new HierarchicalLifetimeManager());
        container.RegisterType<IExchangeRateClient, ExchangeRateClient>(new HierarchicalLifetimeManager());
    }
}
''')

# ---------- Api: host and controllers ----------
w('src/Billing.Api/UnityControllerActivator.cs', '''
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Controllers;
using Unity;

namespace Billing.Api;

public sealed class UnityControllerActivator : IControllerActivator
{
    private readonly IUnityContainer _container;

    public UnityControllerActivator(IUnityContainer container) => _container = container;

    public object Create(ControllerContext context)
    {
        var scope = _container.CreateChildContainer();
        context.HttpContext.Items[typeof(UnityControllerActivator)] = scope;
        return scope.Resolve(context.ActionDescriptor.ControllerTypeInfo.AsType());
    }

    public void Release(ControllerContext context, object controller)
    {
        if (context.HttpContext.Items[typeof(UnityControllerActivator)] is IUnityContainer scope)
        {
            scope.Dispose();
        }
    }
}
''')
w('src/Billing.Api/Program.cs', '''
using Billing.Api;
using Microsoft.AspNetCore.Mvc.Controllers;
using Unity;

var container = new UnityContainer();
Billing.Core.IoCConfig.Configure(container);
Billing.Data.IoCConfig.Configure(container);
Billing.Integration.IoCConfig.Configure(container);

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllers();
builder.Services.AddSingleton<IControllerActivator>(new UnityControllerActivator(container));

var app = builder.Build();
app.MapControllers();
app.Run();
''')
w('src/Billing.Api/Controllers/InvoicesController.cs', '''
using Billing.Core.Customers;
using Billing.Core.Invoices;
using Billing.Integration.Rates;
using Microsoft.AspNetCore.Mvc;

namespace Billing.Api.Controllers;

[ApiController]
[Route("api/invoices")]
public class InvoicesController : ControllerBase
{
    private readonly IInvoiceRepository _invoices;
    private readonly ICustomerRepository _customers;
    private readonly IInvoiceCalculator _calculator;
    private readonly IExchangeRateClient _rates;

    public InvoicesController(IInvoiceRepository invoices, ICustomerRepository customers,
        IInvoiceCalculator calculator, IExchangeRateClient rates)
    {
        _invoices = invoices;
        _customers = customers;
        _calculator = calculator;
        _rates = rates;
    }

    [HttpGet("{id:guid}")]
    public IActionResult Get(Guid id)
    {
        var invoice = _invoices.Find(id);
        return invoice is null ? NotFound() : Ok(invoice);
    }

    [HttpGet("{id:guid}/total")]
    public async Task<IActionResult> Total(Guid id, string currency = "GBP", CancellationToken cancellationToken = default)
    {
        var invoice = _invoices.Find(id);
        if (invoice is null) return NotFound();
        var customer = _customers.Find(invoice.CustomerId);
        if (customer is null) return NotFound();
        var rate = await _rates.RateAsync("GBP", currency, cancellationToken);
        return Ok(_calculator.TotalFor(invoice, customer) * rate);
    }
}
''')
w('src/Billing.Api/Controllers/PaymentsController.cs', '''
using Billing.Core.Customers;
using Billing.Core.Invoices;
using Billing.Core.Payments;
using Billing.Core.Time;
using Billing.Integration.Notifications;
using Billing.Integration.Payments;
using Microsoft.AspNetCore.Mvc;

namespace Billing.Api.Controllers;

[ApiController]
[Route("api/payments")]
public class PaymentsController : ControllerBase
{
    private readonly IInvoiceRepository _invoices;
    private readonly ICustomerRepository _customers;
    private readonly IPaymentRepository _payments;
    private readonly IPaymentGatewayClient _gateway;
    private readonly IEmailNotifier _notifier;
    private readonly IClock _clock;

    public PaymentsController(IInvoiceRepository invoices, ICustomerRepository customers, IPaymentRepository payments,
        IPaymentGatewayClient gateway, IEmailNotifier notifier, IClock clock)
    {
        _invoices = invoices;
        _customers = customers;
        _payments = payments;
        _gateway = gateway;
        _notifier = notifier;
        _clock = clock;
    }

    [HttpPost("{invoiceId:guid}")]
    public async Task<IActionResult> Pay(Guid invoiceId, CancellationToken cancellationToken)
    {
        var invoice = _invoices.Find(invoiceId);
        if (invoice is null) return NotFound();
        if (invoice.Paid) return Conflict();
        var customer = _customers.Find(invoice.CustomerId);
        if (customer is null) return NotFound();
        var reference = await _gateway.ChargeAsync(invoice.Id, invoice.Amount, cancellationToken);
        _payments.Add(new Payment { Id = Guid.NewGuid(), InvoiceId = invoice.Id, Amount = invoice.Amount, PaidAt = _clock.UtcNow, Reference = reference });
        invoice.Paid = true;
        _invoices.Save(invoice);
        await _notifier.SendReceiptAsync(customer.Email, invoice.Amount, cancellationToken);
        return Ok(reference);
    }

    [HttpGet("{invoiceId:guid}")]
    public IActionResult ForInvoice(Guid invoiceId) => Ok(_payments.ForInvoice(invoiceId));
}
''')
w('src/Billing.Api/Controllers/CustomersController.cs', '''
using Billing.Core.Customers;
using Microsoft.AspNetCore.Mvc;

namespace Billing.Api.Controllers;

[ApiController]
[Route("api/customers")]
public class CustomersController : ControllerBase
{
    private readonly ICustomerRepository _customers;

    public CustomersController(ICustomerRepository customers) => _customers = customers;

    [HttpGet("{id:guid}")]
    public IActionResult Get(Guid id)
    {
        var customer = _customers.Find(id);
        return customer is null ? NotFound() : Ok(customer);
    }
}
''')

# ---------- tests ----------
w('tests/Billing.Tests/InvoiceCalculatorTests.cs', '''
using Billing.Core.Customers;
using Billing.Core.Discounts;
using Billing.Core.Invoices;
using Billing.Core.Tax;
using Xunit;

namespace Billing.Tests;

public class InvoiceCalculatorTests
{
    private static readonly InvoiceCalculator Calculator = new(new StandardTaxPolicy(), new LoyaltyDiscountPolicy());

    [Fact]
    public void New_customer_pays_net_plus_tax()
        => Assert.Equal(120m, Calculator.TotalFor(new Invoice { Amount = 100m }, new Customer { YearsActive = 1 }));

    [Fact]
    public void Loyal_customer_gets_five_percent_off_before_tax()
        => Assert.Equal(114m, Calculator.TotalFor(new Invoice { Amount = 100m }, new Customer { YearsActive = 5 }));
}
''')
w('tests/Billing.Tests/StandardTaxPolicyTests.cs', '''
using Billing.Core.Tax;
using Xunit;

namespace Billing.Tests;

public class StandardTaxPolicyTests
{
    [Fact]
    public void Tax_rounds_half_away_from_zero()
        => Assert.Equal(0.03m, new StandardTaxPolicy().TaxFor(0.125m));
}
''')
count = sum(len(f) for _, _, f in os.walk('.'))
print('files:', count)
