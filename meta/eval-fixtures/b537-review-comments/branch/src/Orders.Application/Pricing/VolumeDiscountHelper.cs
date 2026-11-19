namespace Orders.Application.Pricing;

public static class VolumeDiscountHelper
{
    public const int MinimumQuantity = 10;
    private const decimal Rate = 0.05m;

    public static decimal Apply(decimal subtotal, int quantity)
        => quantity > MinimumQuantity ? subtotal * (1 - Rate) : subtotal;
}
