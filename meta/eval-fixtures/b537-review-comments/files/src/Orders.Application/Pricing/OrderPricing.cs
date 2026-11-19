namespace Orders.Application.Pricing;

public sealed class OrderPricing
{
    public decimal Total(PricingRequest request) => RoundingRule.ToCents(request.UnitPrice * request.Quantity);
}
