using Orders.Application.Pricing;
using Xunit;

namespace Orders.Tests.Hidden;

public class B537HiddenTests
{
    [Fact]
    public void R1_ten_units_get_the_volume_discount()
    {
        var pricing = new OrderPricing();
        Assert.Equal(95.00m, pricing.Total(new PricingRequest(10m, 10, "NONE")));
        Assert.Equal(90.00m, pricing.Total(new PricingRequest(10m, 9, "NONE")));
    }

    [Fact]
    public void R2_no_coupon_means_no_coupon_discount()
    {
        var pricing = new OrderPricing();
        Assert.Equal(10.00m, pricing.Total(new PricingRequest(10m, 1, null)));
    }
}
