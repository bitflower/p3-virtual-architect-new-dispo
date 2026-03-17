# Problem 1: Distributed Transaction Failure (Top-Down Sync)

**Date:** 2026-03-03
**Status:** ✅ **Covered in separate exploration**
**Meeting Reference:** `00_Meetings/2025-10-10_yosif-cdc-sync-and-error-flow.md`

---

## Summary

This problem addresses the **dual-write anti-pattern** where New Dispo writes to both TMS Database and New Dispo Database sequentially without distributed transaction coordination, leading to potential data inconsistency.

**Complexity:** High
**Category:** Distributed Transaction Failure

---

## Detailed Analysis

This problem is comprehensively covered in:

📁 **`02_Explorations/2026-03-16_Transactional-Behaviour-New-Dispo-TMS-Transport-Orders/`**

Key documents in that exploration:
- `tms-sync-error-handling-decision.md` - Decision paper for handling strategies
- `tms-sync-failure-scenarios.md` - Three failure scenarios
- `idempotency-analysis.md` - TMS operation idempotency verification
- `00-ORIGINAL-FULL-DOCUMENT.md` - Complete end-to-end flow analysis

---

## Problem Overview

**Direction:** New Dispo → TMS (Top-Down)

**Affected Flows:**
- Leg/lot assignment to transport order
- Leg/lot unassignment from transport order
- Create transport order from leg/lot
- Delete transport order
- Mark leg as stays loaded

**Failure Pattern:**
1. New Dispo calls TMS Bridge GraphQL mutation
2. TMS Bridge executes stored procedure → ✓ TMS DB modified
3. TMS Bridge returns success response
4. New Dispo updates AppDbContext entities
5. AppDbContext.SaveChangesAsync() fails → ✗ New Dispo DB not modified
6. No rollback mechanism → **Systems permanently out of sync**

---

## Solution Approach (June 2026)

**Selected:** Manual user-driven recovery with state-checking logic
**Post-June:** Migrate to Outbox Pattern for automated recovery

See detailed decision rationale in:
`02_Explorations/2026-03-16_Transactional-Behaviour-New-Dispo-TMS-Transport-Orders/tms-sync-error-handling-decision.md`

---

## Related Files

### New Dispo Backend
- `Code/Disposition-Backend/CALConsult.Disposition.API/Application/Features/TransportOrderPlanning/Requests/AssignLegToTransportOrder/AssignLegToTransportOrderCommandHandler.cs`
- `Code/Disposition-Backend/CALConsult.Disposition.API/Shared/GraphQL/RequestExecutors/Mutations/CallCreateTransportOrderFromLegGraphQLRequestExecutor.cs`

### TMS Bridge
- `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/GraphQL/Mutations/PdisTransportOrder/CreateTransportOrderFromLeg/CreateTransportOrderFromLegMutation.cs`
- `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/GraphQL/Mutations/PdisLeg/StaysLoadedMutation/StaysLoadedMutation.cs`

### TMS Database Schema
- `Code/tms-alloydb-schema/src/sql/package/PDIS_TRANSPORTORDER.sql`
- `Code/tms-alloydb-schema/src/sql/package/PTA.sql` - Contains idempotency checks

---

## Cross-References

- **Primary Exploration:** `02_Explorations/2026-03-16_Transactional-Behaviour-New-Dispo-TMS-Transport-Orders/`
- **Original Meeting:** `00_Meetings/2025-10-10_yosif-cdc-sync-and-error-flow.md`
- **Related Problem:** `problem-2-cdc-event-processing-failure.md` (Bottom-up sync)
