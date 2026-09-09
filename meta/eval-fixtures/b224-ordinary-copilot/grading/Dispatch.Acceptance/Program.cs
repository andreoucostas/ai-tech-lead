using Dispatch;

var passed = 0;
var failed = 0;

Check("queued attempt zero cancels", ShipmentState.Queued, 0, true, ShipmentState.Cancelled);
Check("queued attempt one cancels", ShipmentState.Queued, 1, true, ShipmentState.Cancelled);
Check("queued maximum attempt rejects", ShipmentState.Queued, 2, false, ShipmentState.Queued);
Check("reserved retail shipment rejects", ShipmentState.Reserved, 0, false, ShipmentState.Reserved);
Check("draft retail shipment rejects", ShipmentState.Draft, 0, false, ShipmentState.Draft);
Check("cancelled retail shipment rejects", ShipmentState.Cancelled, 0, false, ShipmentState.Cancelled);

var packed = new Shipment(ShipmentState.Packed, 0);
var releaseService = CreateService();
Record("existing release remains valid", releaseService.TryRelease(packed) && packed.State == ShipmentState.Released);

Console.WriteLine($"{passed} passed, {failed} failed");
return failed;

void Check(string name, ShipmentState initial, int attempts, bool expectedAccepted, ShipmentState expectedState)
{
    var shipment = new Shipment(initial, attempts);
    var service = CreateService();
    var method = typeof(RetailShipmentService).GetMethod("TryCancel", [typeof(Shipment)]);
    if (method is null)
    {
        Record(name, false);
        return;
    }

    var accepted = method.Invoke(service, [shipment]);
    Record(name, accepted is bool actual && actual == expectedAccepted && shipment.State == expectedState);
}

RetailShipmentService CreateService() =>
    new(new RetailTransitionPolicy(new RetailCancellationOptions(2)));

void Record(string name, bool assertion)
{
    if (assertion)
    {
        passed++;
        Console.WriteLine($"PASS: {name}");
    }
    else
    {
        failed++;
        Console.WriteLine($"FAIL: {name}");
    }
}
