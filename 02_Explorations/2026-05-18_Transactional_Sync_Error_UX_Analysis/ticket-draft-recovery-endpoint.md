# Draft: Recovery Endpoint for Orphaned Assignments (Flow 7)

**Status:** Extracted from #124105 — not yet assigned to a ticket
**Context:** This was originally AC 5 of #124105 but is out of scope for that ticket. Needs its own PBI.

---

## What It Does

**Given** a Flow 7 deletion succeeded in TMS but local cleanup failed,
**when** operations calls the recovery endpoint with the affected transport order ID,
**then** the endpoint cleans up orphaned LotAssignment/LegLink records (reusing existing CDC recovery logic) and returns what was cleaned up.

The endpoint must be restricted to operations/admin roles.

## Why It's Needed

Flow 7 (Delete Transport Order) is the only flow where user-driven retry cannot work — the deleted TO disappears from the UI. If TMS deletion succeeds but New Dispo local cleanup fails (CloudSQL outage, timeout, crash), orphaned LotAssignment records remain. The user has no way to trigger recovery.

Log pairing (#124105 AC 4) makes these failures detectable. This endpoint makes them recoverable.

## Building On

- CDC recovery POC logic already performs the same cleanup (unassigning orphaned legs/lots)
- Yosif confirmed this is "pretty much no extra effort" (2026-05-19)
- Decision: Option D (Manual Service Desk Recovery) approved for Go-Live — see [Flow 7 Analysis](./flow-07-delete-transport-order.md), section 8

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
