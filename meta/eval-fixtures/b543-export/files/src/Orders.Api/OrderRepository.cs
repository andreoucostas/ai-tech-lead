namespace Orders.Api;

public class OrderRepository
{
    private readonly object _gate = new();
    private readonly List<Order> _orders =
    [
        new(1, "Acme Ltd", new DateOnly(2026, 11, 2), 120.50m, OrderStatus.Shipped),
        new(2, "Smith, Jones and Partners", new DateOnly(2026, 11, 10), 89.99m, OrderStatus.Pending),
        new(3, "Blue Harbour Cafe", new DateOnly(2026, 11, 15), 15.00m, OrderStatus.Cancelled),
        new(4, "Riverside Books", new DateOnly(2026, 11, 18), 230.25m, OrderStatus.Pending),
    ];

    public IReadOnlyList<Order> All()
    {
        lock (_gate) return _orders.ToList();
    }

    public Order? Find(int id)
    {
        lock (_gate) return _orders.FirstOrDefault(o => o.Id == id);
    }

    public Order Add(string customer, DateOnly placedOn, decimal total)
    {
        lock (_gate)
        {
            var order = new Order(_orders.Max(o => o.Id) + 1, customer, placedOn, total, OrderStatus.Pending);
            _orders.Add(order);
            return order;
        }
    }
}
