namespace FeedbackFixture.Mappers;

public static class PaymentNotFoundMapper
{
    public static object Map() => new { code = Errors.PaymentNotFound.Code, resource = Errors.PaymentNotFound.ResourceKey, status = 404 };
}
