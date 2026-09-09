namespace Dispatch;

public sealed class RetailShipmentService
{
    private readonly RetailTransitionPolicy _transitionPolicy;

    public RetailShipmentService(RetailTransitionPolicy transitionPolicy)
    {
        _transitionPolicy = transitionPolicy;
    }

    public bool TryRelease(Shipment shipment)
    {
        ArgumentNullException.ThrowIfNull(shipment);
        if (!_transitionPolicy.CanRelease(shipment))
        {
            return false;
        }

        shipment.MarkReleased();
        return true;
    }
}
