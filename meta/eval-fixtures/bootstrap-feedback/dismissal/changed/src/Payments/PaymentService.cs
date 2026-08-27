namespace FeedbackFixture.Payments;

public sealed class PaymentService
{
    public void Charge(string idempotencyKey)
    {
        _ = idempotencyKey;
    }
}
