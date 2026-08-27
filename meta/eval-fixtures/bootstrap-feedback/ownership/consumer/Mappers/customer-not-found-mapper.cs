namespace FeedbackFixture.Mappers;

public static class CustomerNotFoundMapper
{
    public static object Map() => new { code = Errors.CustomerNotFound.Code, resource = Errors.CustomerNotFound.ResourceKey, status = 404 };
}
