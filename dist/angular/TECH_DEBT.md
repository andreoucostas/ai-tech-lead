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

_No items yet. Run `/bootstrap` to populate this register._

**Categories**: Architecture, State Management, RxJS, Component Design, Testing, Types, Performance, Dependencies, Security

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

<!-- Populated by /bootstrap -->
