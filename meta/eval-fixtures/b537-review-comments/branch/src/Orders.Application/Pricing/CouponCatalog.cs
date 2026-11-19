namespace Orders.Application.Pricing;

public sealed record Coupon(string Code, decimal PercentOff);

public static class CouponCatalog
{
    private static readonly Coupon[] Known =
    {
        new("SPRING10", 10m),
        new("WELCOME5", 5m),
    };

    public static Coupon? Find(string code) => Array.Find(Known, c => c.Code == code);
}
