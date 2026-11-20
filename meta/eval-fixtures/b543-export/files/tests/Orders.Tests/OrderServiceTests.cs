using Orders.Api;
using Xunit;

namespace Orders.Tests;

public class OrderServiceTests
{
    private static readonly DateOnly Today = new(2026, 11, 20);

    [Fact]
    public void List_ReturnsSeededOrders()
    {
        var service = new OrderService(new OrderRepository());
        Assert.Equal(4, service.List().Count);
    }

    [Fact]
    public void Find_ReturnsNullForUnknownId()
    {
        var service = new OrderService(new OrderRepository());
        Assert.Null(service.Find(99));
    }

    [Fact]
    public void Place_AddsPendingOrderWithNextId()
    {
        var service = new OrderService(new OrderRepository());
        var order = service.Place("New Customer", 10.00m, Today);
        Assert.Equal(5, order.Id);
        Assert.Equal(OrderStatus.Pending, order.Status);
        Assert.Equal(Today, order.PlacedOn);
        Assert.Equal(order, service.Find(5));
    }

    [Fact]
    public void Place_RejectsEmptyCustomer()
    {
        var service = new OrderService(new OrderRepository());
        Assert.Throws<ArgumentException>(() => service.Place(" ", 10.00m, Today));
    }
}
