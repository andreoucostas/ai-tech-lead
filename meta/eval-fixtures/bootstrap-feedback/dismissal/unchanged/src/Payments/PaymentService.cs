namespace FeedbackFixture.Payments;

public sealed class PaymentService
{
    private readonly HashSet<string> _processedKeys = [];

    public void Charge(string idempotencyKey)
    {
        if (!_processedKeys.Add(idempotencyKey))
        {
            throw new InvalidOperationException("Duplicate charge");
        }
    }
}
