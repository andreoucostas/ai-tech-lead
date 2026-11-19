namespace Orders.Application.Pricing;

public sealed record PricingRequest(decimal UnitPrice, int Quantity, string? CouponCode);
