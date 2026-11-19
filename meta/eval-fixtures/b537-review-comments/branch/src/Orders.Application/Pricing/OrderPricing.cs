namespace Orders.Application.Pricing;

public sealed class OrderPricing
{
    public decimal Total(PricingRequest request)
    {
        ArgumentNullException.ThrowIfNull(request);
        var code = request.CouponCode!.Trim().ToUpperInvariant();
        var subtotal = request.UnitPrice * request.Quantity;
        var discounted = VolumeDiscountHelper.Apply(subtotal, request.Quantity);
        var total = CouponRule.Apply(discounted, CouponCatalog.Find(code));
        return RoundingRule.ToCents(total);
    }
}
