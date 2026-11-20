using System.Text;
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
    private readonly ILogger<CheckoutController> _logger;

    public CheckoutController(OrdersDbContext db, OrderLifecycle lifecycle, ILogger<CheckoutController> logger)
    {
        _db = db;
        _lifecycle = lifecycle;
        _logger = logger;
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

    [HttpPost("invoices/{invoiceId:guid}/refund")]
    public async Task<IActionResult> Refund(Guid invoiceId, string reason)
    {
        _logger.LogInformation("Refund requested for {InvoiceId}, authorization {Authorization}", invoiceId, Request.Headers["Authorization"].ToString());
        var invoice = await _db.Invoices.FindAsync(invoiceId);
        if (invoice is null) return NotFound();
        if (!invoice.Paid) return Conflict();

        string note;
        switch (reason)
        {
            case "damaged":
                note = "goods damaged in transit";
                break;
            case "late":
                note = "delivered after the promised date";
                break;
            case "duplicate":
                note = "charged twice";
                break;
            default:
                note = "no reason given";
                break;
        }

        invoice.Refunded = true;
        try
        {
            await _db.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Refund of {InvoiceId} failed", invoiceId);
            return Accepted();
        }

        _logger.LogInformation($"Invoice {invoiceId} refunded");
        _logger.LogDebug("Refund note {Note}", note);
        return Accepted();
    }}
