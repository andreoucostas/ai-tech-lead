using Microsoft.AspNetCore.Mvc;
using Orders.Application.Orders;
using Orders.Application.Pricing;
using Orders.Infrastructure.Persistence;

namespace Orders.Api.Controllers;

[ApiController]
[Route("api/checkout")]
public class CheckoutController : ControllerBase
{
    private readonly OrdersDbContext _db;
    private readonly OrderLifecycle _lifecycle;
    private readonly OrderPricing _pricing;

    public CheckoutController(OrdersDbContext db, OrderLifecycle lifecycle, OrderPricing pricing)
    {
        _db = db;
        _lifecycle = lifecycle;
        _pricing = pricing;
    }

    [HttpPost("quote")]
    public IActionResult Quote(QuoteRequest body)
    {
        if (body.Quantity < 1 || body.UnitPrice <= 0)
            return BadRequest("Quantity must be at least 1 and the unit price greater than zero.");
        return Ok(_pricing.Total(new PricingRequest(body.UnitPrice, body.Quantity, body.CouponCode)));
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

public sealed record QuoteRequest(decimal UnitPrice, int Quantity, string? CouponCode = null);
