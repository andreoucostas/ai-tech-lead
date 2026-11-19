namespace Orders.Application.Pricing;

public class CouponRule
{
    public static decimal Apply(decimal subtotal, Coupon? coupon)
    {
        if (coupon is null) return subtotal;

        return subtotal * (1 - coupon.PercentOff / 100m);
    }
}
