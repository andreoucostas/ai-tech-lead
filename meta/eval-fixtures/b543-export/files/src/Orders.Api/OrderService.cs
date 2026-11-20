namespace Orders.Api;

public class OrderService(OrderRepository repository)
{
    public IReadOnlyList<Order> List() => repository.All();

    public Order? Find(int id) => repository.Find(id);

    public Order Place(string customer, decimal total, DateOnly today)
    {
        if (string.IsNullOrWhiteSpace(customer)) throw new ArgumentException("Customer is required.", nameof(customer));
        if (total <= 0) throw new ArgumentException("Total must be greater than zero.", nameof(total));
        return repository.Add(customer.Trim(), today, total);
    }
}
