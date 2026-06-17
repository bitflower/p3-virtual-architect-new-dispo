# HL Legs Still Planable — Impact on New Dispo Sync

**Date:** 2026-06-17
**Status:** Exploration

---

## Original User Input

> **Source:** Teams chat from Max Kehder, 2026-06-17
> **To raise with:** Joachim (Lead TMS Database dev)
>
> Max Kehder reported that HL (Hauptlauf) legs can still be modified in CALtms even
> when they are already planned ("verplant"). The assumption was that planned HL legs
> should be locked from modification.
>
> The CALtms modal (PGS ABN 10/34) shows two options when modifying a forwarding job
> that is part of a transport order:
> 1. Remove forwarding job from the transport order
> 2. Leave the forwarding job in the transport order and modify the transport order
>
> **Key concern:** If HL legs can be modified after planning, what downstream effects
> does this have on the sync between TMS Database → CDC → Cloud Functions → New Dispo
> Backend → New Dispo Database?

---

## Summary

Modifying a planned HL leg in CALtms triggers CDC events that the New Dispo pipeline processes **without any planning-state guard**. The entire chain — FilterShipments Cloud Function, PubSub handler, and all CDC event resolvers — is blind to whether a leg is planned. This means planned legs can be silently modified, re-lotted, or deleted in the New Dispo database, potentially corrupting tour assignments.

## Data Flow Under Analysis

```
CALtms (user modifies planned HL leg)
  → TMS Database (sendung table updated)
    → Datastream CDC
      → GCS Bucket (.jsonl files)
        → FilterShipments Cloud Function
          → PubSub topic
            → New Dispo Backend (PubSubMessageHandler)
              → ShipmentUpdatedEventHandler
                → TrafficMode resolvers / LotGenerationFields resolver
                  → New Dispo Database (legs, lots, lot_assignments modified)
```

## Analysis

### Layer 1: FilterShipments Cloud Function — No HL / Planning Filter

The `BucketDataStreamFileContentProcessor` (line 39–41) filters CDC records by two criteria only:

1. **ShipmentType == "A"** (`sendungsart` field)
2. **Client whitelist** (consignor name/city/zip match)

The `ShipmentData` DTO does **not include `lauf_kennz`** (the field that identifies HL vs VL vs NL legs). There is no field for planning status either. Every `sendung` change that passes the type-A + whitelist check is forwarded to PubSub — regardless of leg type or planning state.

### Layer 2: New Dispo Backend CDC Handlers — No Planning Guard

The `ShipmentUpdatedEventHandler` (line 69) checks only whether the update is newer than the stored leg's `UpdatedAt` timestamp. If newer, it delegates to the matching resolvers. **No resolver checks if the leg is currently planned or assigned to a tour.**

The `LotGenerationFieldsUpdatedResolver` (line 71–73) applies field changes to the leg and then **detaches it from its current lot assignment and creates a new one** — even for planned legs with active tour assignments.

The `TrafficMode1ToTrafficMode2Resolver` (line 64) goes further: it **deletes the HL leg entirely** (`base.RemoveLeg(oldHlLeg)`) and replaces it with a new VL leg — without any planning check.

The `BaseShipmentUpdatedEventResolver.RemoveLeg()` cascades: removes the leg entity, detaches it from its lot, recalculates or removes the lot, and removes orphaned lot assignments.

The only planning-awareness in the entire CDC chain is `GetSingleUnplannedShipment` — but this only applies to the **new shipment creation** path (when no legs exist yet), not to updates.

### Layer 3: TMS Schema — Planning State Exists But Is Not Consumed

In the TMS Database:
- `sendung.lauf_kennz` identifies leg type (HL, VL, NL)
- `pst_zustand` tracks planning status per `bereich_k` (business area)
- CDC triggers exist on `pst_zustand` (`TRAIUD_AGG_PST_ZUSTAND`)

However, the FilterShipments Cloud Function **only processes `sendung` table changes**. Changes to `pst_zustand` are replicated via Datastream but are not consumed by the filter function.

## Impact Scenarios

### Scenario 1: "Remove forwarding job from the transport order"

| Step | What happens |
|------|-------------|
| CALtms | User removes HL forwarding job from transport order |
| TMS DB | `sendung` record updated (transport order link removed, possibly `tran_art` changes) |
| CDC | Change flows through Datastream → FilterShipments (passes type-A + whitelist) |
| Backend | `ShipmentUpdatedEventHandler` finds existing HL leg in New Dispo |
| Backend | Traffic mode resolver may **delete the HL leg** and replace with VL |
| **Impact** | Planned leg disappears from New Dispo. Lot assignment broken. Tour corrupted. |

### Scenario 2: "Leave forwarding job and modify the transport order"

| Step | What happens |
|------|-------------|
| CALtms | User modifies forwarding job fields while keeping it in transport order |
| TMS DB | `sendung` record updated (field changes) |
| CDC | Change flows through |
| Backend | `LotGenerationFieldsUpdatedResolver` detects field changes |
| Backend | **Detaches leg from current lot assignment, creates new one** |
| **Impact** | Planned leg silently re-lotted. Existing tour point mapping invalidated. |

## Source Code Evidence

| File | Key Finding |
|------|-------------|
| `FilterShipments.Bucket/Dtos/Common/ShipmentData.cs` | No `lauf_kennz` field mapped — HL type invisible to filter |
| `FilterShipments.Bucket/Bucket/ContentProvider/BucketDataStreamFileContentProcessor.cs:39-41` | Only filters on `ShipmentType == "A"` and whitelist |
| `CDC/EventHandlers/ShipmentUpdated/ShipmentUpdatedEventHandler.cs:69` | Only checks `UpdatedAt` freshness, no planning guard |
| `CDC/EventHandlers/ShipmentUpdated/LotGenerationFieldsResolver/LotGenerationFieldsUpdatedResolver.cs:71-73` | Applies field changes + re-lots without planning check |
| `CDC/EventHandlers/ShipmentUpdated/TrafficModeUpdateResolvers/TrafficMode1ToTrafficMode2Resolver.cs:64` | Deletes HL leg via `RemoveLeg()` without planning check |
| `CDC/EventHandlers/ShipmentUpdated/TrafficModeUpdateResolvers/BaseShipmentUpdatedEventResolver.cs:83-101` | `RemoveLeg()` cascades: removes leg, lot link, lot assignment |
| `Domain/Entities/Leg/Enums/LegType.cs` | `LegType { NL, VL, HL }` — domain knows about HL but CDC doesn't use it as guard |

## Findings

1. **No HL-specific filtering in CDC pipeline** — `lauf_kennz` is not even in the `ShipmentData` DTO. The Cloud Function cannot distinguish HL from VL or NL legs.

2. **No planning-state guard in any CDC handler** — Modifications to planned legs are processed identically to unplanned ones. There is zero divergence in logic.

3. **Silent lot/tour corruption** — Planned legs can be deleted (`RemoveLeg`), re-lotted (`LotGenerationFieldsUpdatedResolver`), or have their type changed (`TrafficMode` resolvers) without any safeguard or notification.

4. **Planning status not consumed from CDC** — `pst_zustand` is CDC-replicated but the FilterShipments function only processes `sendung` table events. The planning state is available in the TMS Database but never reaches the New Dispo Backend via CDC.

5. **Two-sided risk** — The problem affects both CDC directions:
   - **TMS → New Dispo (CDC):** Unguarded modifications corrupt New Dispo state
   - **New Dispo → TMS (TMS Bridge):** `RemoveLegMutation` accepts `TransportOrderId` + `LegId` with zero preconditions — no check that the leg is planned before calling `pdis_transportorder.removeleg`. The stored procedure is the only potential guard, but its implementation is in the TMS Database, not visible in the TMS Bridge codebase.

6. **"Planned" indicator is implicit** — In the New Dispo domain, a leg is considered planned when it has a non-null `TransportOrderId` via its `LotAssignment`. There is no explicit `IsPlanned` flag on `LegEntity` — planning status must be inferred from the lot assignment chain.

## Questions for Joachim

1. **Is `lauf_kennz` the correct field to identify HL legs?** Or is there another column/view that should be used?

2. **Should TMS enforce immutability of planned HL legs?** The CALtms modal currently allows modification — is this a TMS bug, or is there a valid business case for modifying planned HL legs?

3. **What columns in `pst_zustand` encode "planned" status?** Which `bereich_k` value and which `status` code indicate that a leg is planned and should not be modified?

4. **Does `pdis_transportorder.removeleg` have planning guards?** If TMS Bridge calls this for a planned leg, does the stored procedure reject it?

5. **Should the fix be in TMS (prevent the modification) or in New Dispo (ignore/reject CDC events for planned legs) or both?**

## Related Files

- `Code/Nagel-GCP/CALConsult.Disposition.Functions/FilterShipments.Bucket/`
- `Code/Disposition-Backend/CALConsult.Disposition.API/Application/Features/CDC/`
- `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/GraphQL/Mutations/PdisTransportOrder/`
- `Code/tms-alloydb-schema/` (tables: `sendung`, `pst_zustand`, `ta_sen_lst_b`)
