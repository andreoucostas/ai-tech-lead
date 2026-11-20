namespace Orders.Domain.Entities;

public class Invoice
{
    public Guid Id { get; set; }
    public Guid OrderId { get; set; }
    public DateTime DueAt { get; set; }
    public bool Paid { get; set; }
    public bool Refunded { get; set; }
    public decimal Amount { get; set; }
}
