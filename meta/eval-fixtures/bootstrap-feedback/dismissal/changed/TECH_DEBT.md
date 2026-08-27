# Tech Debt Register

## Dismissed proposals — do not re-propose without materially changed evidence

| Key | Affected paths / symbols | Evidence reviewed | Dismissed | Reason |
|-----|--------------------------|-------------------|-----------|--------|
| payments::duplicate-charge-guard-absent | `src/Payments/PaymentService.cs` / `Charge` | `_processedKeys.Add(idempotencyKey)` rejects duplicates before mutation | 2026-08-20 | Existing guard already enforces the sample's documented process-local contract. |
