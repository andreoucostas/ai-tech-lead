# Tech Debt Register

> Run `/bootstrap` to populate this file from your actual codebase analysis.
> Run `/debt [area]` to find and fix items. Run `/docs-sync` to check for staleness.

One `## DEBT-NNN` block per item. To add an item, copy the template below after the last block with the next unused number. To remove a resolved item, delete its whole block.

Template (an example, not an item):

```markdown
## DEBT-001: <Short title>

- **Key**: <area>::<claim-slug>
- **Category**: <one of the categories below>
- **Severity**: Critical | High | Medium | Low
- **Effort**: S (<1hr) | M (half day) | L (1-2 days) | XL (needs spike)
- **Files**: `path/to/file:42`, `path/to/other-file`

### Issue
<1-3 sentences on what's wrong and why it matters>

### Recommended fix
<1-3 sentences on the change and any risks>

---
```

## DEBT-001: Domain fact loads are not re-runnable

- **Key**: warehouse-loads::domain-fact-not-idempotent
- **Category**: Data Access
- **Severity**: High
- **Effort**: XL (needs spike)
- **Files**: `StoredProcedures/usp_LoadFactBrokerageRepaymentEvent.sql:1`, `StoredProcedures/usp_LoadFactBrokerageRepaymentMovement.sql:1`, `Tables/fact.FactBrokerageRepaymentMovement.sql:2` (pattern repeats in 60 `usp_LoadFact*` files; only `usp_LoadFactTransaction.sql` and `usp_LoadFactAccountBalanceMonthly.sql` are batch-scoped)

### Issue
Each domain fact load is one `INSERT … SELECT` over all staging rows with no `BatchId` filter, delete or transaction. A job retry hits the source-id primary key or reloads older batches.

### Recommended fix
Adopt the ADR-001 delete-and-reload pattern per load, in generated-family order, with a rerun-twice check. Spike first on whether staging is truncated between runs.

---

## DEBT-002: Domain dim loads insert every new member with key -1

- **Key**: warehouse-loads::dim-unknown-key-insert
- **Category**: Data Access
- **Severity**: High
- **Effort**: L (1-2 days)
- **Files**: `StoredProcedures/usp_LoadDimBrokerageRepayment.sql:1`, `Tables/dim.DimBrokerageRepayment.sql:2` (81 `usp_LoadDim*` files)

### Issue
The loads insert `VALUES (-1, <id>, 'Unknown')` into a non-identity primary key, so a second new member should fail, and facts would join to key -1.

### Recommended fix
Give these dims identity surrogate keys and keep a single seeded `-1` Unknown row. Confirm against a test database first.

---

## DEBT-003: History-flagged dims never expire rows

- **Key**: warehouse-scd::domain-dim-no-history
- **Category**: Data Access
- **Severity**: Medium
- **Effort**: L (1-2 days)
- **Files**: `StoredProcedures/usp_LoadDimCardFacility.sql:1`, `Tables/dim.DimCardFacility.sql:5-7` (25 dims with `IsCurrent`)

### Issue
The `MERGE` has only `WHEN NOT MATCHED`, so `EffectiveTo` is never set and attribute changes are not tracked.

### Recommended fix
Decide with the team whether history is intended; then implement the `usp_LoadDimCustomer.sql` close-and-insert pattern, or drop the columns.

---

## DEBT-004: Account-holder weights can sum below 1

- **Key**: warehouse-bridge::holder-weight-rounding
- **Category**: Data Access
- **Severity**: Medium
- **Effort**: S (<1hr)
- **Files**: `StoredProcedures/usp_LoadBridgeAccountHolder.sql:10`

### Issue
`1.0 / COUNT(*)` is cast to `DECIMAL(9,6)`, so three holders give 0.999999 in total and allocated measures drift.

### Recommended fix
Assign the rounding remainder to one holder, or state the tolerance as policy.

---

## DEBT-005: No warehouse tests or data-quality checks

- **Key**: warehouse-testing::no-validation-assets
- **Category**: Testing
- **Severity**: High
- **Effort**: L (1-2 days)
- **Files**: `warehouse.sqlproj`

### Issue
No SQL test, reconciliation or data-quality assets exist (`tests/evals` is framework-owned), so none of the defects above is caught before release.

### Recommended fix
Pick SQL test tooling and start with a rerun-twice and row-count reconciliation check on the two batch-scoped facts.

---

**Categories**: Architecture, Data Access, DI/Lifetime, API Design, Async, Testing, Types/Nullability, Performance, Dependencies, Security

---

## Dismissed proposals — do not re-propose without materially changed evidence

> These are reviewed claims the team determined are not debt. Keep every row for auditability.
> A later scan may reopen one only by naming the concrete evidence delta in a new active item.

| Key | Affected paths / symbols | Evidence reviewed | Dismissed | Reason |
|-----|--------------------------|-------------------|-----------|--------|
| _(none)_ | _ | _ | _ | _ |

---

## Trojan Horse Opportunities

_Group debt items by feature area so developers can bundle cleanup into feature work._

- **Fact loads (any domain)**: DEBT-001, DEBT-005
- **Dimension loads (any domain)**: DEBT-002, DEBT-003
- **Account holders / bridge**: DEBT-004
