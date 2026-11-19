namespace Orders.Application.Pricing;

public static class RoundingRule
{
    public static decimal ToCents(decimal value) => Math.Round(value, 2, MidpointRounding.AwayFromZero);
}
