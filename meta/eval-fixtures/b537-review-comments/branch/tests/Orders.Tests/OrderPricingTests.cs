using Orders.Application.Pricing;
using Xunit;

namespace Orders.Tests;

public class OrderPricingTests
{
    private readonly OrderPricing _pricing = new();

    [Fact]
    public void Rounds_half_away_from_zero()
    {
        Assert.Equal(2.67m, new OrderPricing().Total(new PricingRequest(2.665m, 1, "")));
    }

    [Fact]
    public void Small_orders_get_no_volume_discount()
    {
        Assert.Equal(90.00m, _pricing.Total(new PricingRequest(10m, 9, "")));
    }

    [Fact]
    public void Large_orders_get_the_volume_discount()
    {
        Assert.Equal(104.50m, _pricing.Total(new PricingRequest(10m, 11, "")));
    }
}
