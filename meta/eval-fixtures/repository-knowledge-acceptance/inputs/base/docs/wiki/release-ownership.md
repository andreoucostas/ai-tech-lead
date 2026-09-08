---
name: release-ownership
description: Promotion ownership and approval boundary
type: context
scope: config/promotion.json
status: verified
last-verified: 2026-08-31
---
The release operator owns promotion. Creating a package does not grant approval to promote it.
**Evidence:** config/promotion.json
**Verify by:** reread the owner field and approval runbook maintained outside this repository.

