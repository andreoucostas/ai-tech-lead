namespace FeedbackFixture.Mappers;

public static class InvoiceNotFoundMapper
{
    public static object Map() => new { code = Errors.InvoiceNotFound.Code, resource = Errors.InvoiceNotFound.ResourceKey, status = 404 };
}
