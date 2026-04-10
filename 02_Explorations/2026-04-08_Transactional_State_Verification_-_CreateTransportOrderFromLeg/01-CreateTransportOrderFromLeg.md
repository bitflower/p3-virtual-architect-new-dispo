# Transactional State Verification - CreateTransportOrderFromLeg

**Date:** 2026-04-08  
**Status:** Approved (Joachim, 2026-04-09)

---

<!-- internal -->
## Original User Input

> Am Ende geht es immer nur um den Zustand in der TMS-Datenbank. Der Zustand wird durch eine Funktion wie zum Beispiel CreateTransportOrderAndAddLeg veraendert. Das bedeutet, dass ein neuer Transportauftrag mit bestimmten Parametern und seinen Legs erstellt und zugewiesen wird. Wir haben also mindestens Datensaetze fuer die Legs und die Verbindungen zum Transport Order. Dieser Zustand wollen wir spaeter beim Transaktionalen Verhalten pruefen, bevor wir die Funktion erneut ausfuehren. Diese Pruefung im Code sollte ein KI-Agent durchfuehren, wenn ihm die Parameter genannt werden, und die Einstiegspunkte sind die DIS-wrapper-Funktionen. Wenn dem KI-Agent die Kandidaten gegeben werden, um den Status zu verifizieren, wie in unserem Fall die V_DIS_Leg View zusammen mit der Transport Order ID, sollte er in der Lage sein, dies zu validieren. Schliesslich koennte er auch das Diagramm zeichnen und das Konzeptdokument erstellen. Im besten Fall muesste der KI-Agent nicht in die Codebase gehen, sondern das Wissen aus dem Virtual Architect Knowledge Graph ziehen.
<!-- /internal -->

---

## Summary

This exploration documents the analysis of **transactional state verification** for the `CreateTransportOrderFromLeg` function. The goal is to:

1. Understand what state changes a DIS-wrapper function creates
2. Generate verification queries to detect "already executed" state (idempotency)
3. Document the findings with diagrams and concept documentation

---

## Analysis

### The Call Flow

```
Frontend 
    -> Backend 
        -> TMS Bridge (GraphQL Mutation)
            -> pDIS_TransportOrder.CreateTransportOrderFromLeg (PL/pgSQL)
                -> TMS Tables (State)
```

### State Changes Traced

```
CreateTransportOrderFromLeg(Company, Branch, PerformanceDate, TransportMode, RegionId, ShipmentId, LegType, Mode)
    |
    +-> pDIS_TransportOrder.New() 
    |       -> Creates: Sendung record (TransportOrderId)
    |       -> Creates: Sen_Frk_Unt record (contractor relationship)
    |       -> Sets: Sendung.Quell_K = 'D'
    |       -> Sets: VehicleStartTime via pDIS_TourPoint
    |
    +-> CreateAndAddLeg() -> AddLeg()
            |
            +-> [LegType = 'HL' (LongHaul)] pTA.AddSen()
            |       -> Writes: Sen_Zuord         -> resolved via: V_TA_Sen7, V_DIS_Leg
            |       -> Creates/Reuses: Res_Hst   -> resolved via: V_DIS_TO_Tourpoint
            |       -> Writes: TA_Sen_Lst_B      -> resolved via: (loading list views)
            |       -> LegId = ShipmentId (for LongHaul legs)
            |
            +-> [LegType = 'VL' (PreCarriage)] pTA_VL.AddLeg()
                    -> May create new Leg via pDIS_Shipment.CreateLeg()
                    -> Writes: Sen_Zuord         -> resolved via: V_TA_Sen7, V_DIS_Leg
                    -> Creates/Reuses: Res_Hst   -> resolved via: V_DIS_TO_Tourpoint
```

### Function Signature

```sql
CREATE OR REPLACE FUNCTION pDIS_TransportOrder.CreateTransportOrderFromLeg(
    Company numeric,
    Branch numeric,
    PerformanceDate timestamp without time zone,
    TransportMode numeric,
    RegionId character varying,
    ShipmentId numeric,
    LegType character varying,
    mode numeric,
    -- OUT parameters:
    OUT TransportOrderId numeric,
    OUT PickupPointId numeric,
    OUT IsNewPickupPoint boolean,
    OUT DeliveryPointId numeric,
    OUT IsNewDeliveryPoint boolean,
    OUT LegId numeric
) RETURNS record
```

### GraphQL Entry Point

File: `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/GraphQL/Mutations/PdisTransportOrder/CreateTransportOrderFromLeg/CreateTransportOrderFromLegMutation.cs`

```csharp
public async Task<CreateTransportOrderFromLegResponse> CallCreateTransportOrderFromLeg(
    [Service] IRoutineExecutor executor,
    [Service] IDbContextProvider<BranchDbContext> dbContextProvider,
    [GraphQLNonNullType] string databaseIdentifier,
    [GraphQLNonNullType] CreateTransportOrderFromLegInput input)
```

---

## Table-to-View Mapping

| Table Written | Verification View | Key Columns |
|---------------|-------------------|-------------|
| `Sendung` | `V_DIS_TransportOrder` | TransportOrderId, LoadingDate, Company, Branch |
| `Sen_Frk_Unt` | `V_DIS_TransportOrder` | ContractorId, TruckId, TrailerId |
| `Sen_Zuord` | `V_TA_Sen7`, `V_DIS_Leg` | TransportOrderId (via TA_Tix) |
| `Res_Hst` | `V_DIS_TO_Tourpoint` | TourPointId, Type (Pickup/Delivery) |
| `TA_Sen_Lst_B` | (loading list views) | Loading units, positions |

---

## Verification Candidates

### Primary Candidate: V_DIS_Leg

The `V_DIS_Leg` view provides visibility into leg assignments:

```sql
-- Key columns from V_DIS_Leg:
SELECT ShipmentId,
       LegId,
       LegType,
       TransportOrderId  -- NULL if not assigned, otherwise the TO it's assigned to
FROM V_DIS_Leg
WHERE ShipmentId = :ShipmentId
```

The `TransportOrderId` column is derived from:
```sql
(select TA_Tix from V_TA_Sen7 where Sen_Tix = s2.Sendung_Tix limit 1) TransportOrderId
```

The `limit 1` suggests a leg can only be assigned to ONE Transport Order at a time.

### Secondary Candidate: V_DIS_TransportOrder

For full parameter verification, join with Transport Order details:

```sql
SELECT l.TransportOrderId, 
       t.LoadingDate,      -- = PerformanceDate
       t.Company, 
       t.Branch, 
       t.TransportMode
FROM V_DIS_Leg l
JOIN V_DIS_TransportOrder t ON l.TransportOrderId = t.TransportOrderId
WHERE l.ShipmentId = :ShipmentId 
  AND l.LegType = :LegType
```

---

## Verification Strategies

### Strategy 1: Pure Logical Reference Check (ID-based)

```sql
SELECT TransportOrderId, LegId 
FROM V_DIS_Leg 
WHERE ShipmentId = :ShipmentId 
  AND LegType = :LegType 
  AND TransportOrderId IS NOT NULL
```

**Semantics:**
- Row exists -> Leg already assigned to SOME Transport Order
- Returns existing TransportOrderId
- Does NOT verify if PerformanceDate/Company/Branch match the request

**Use case:** Simple idempotency - "was this operation done?"

### Strategy 2: Full Parameter Match Check

```sql
SELECT l.TransportOrderId, l.LegId, 
       t.LoadingDate, t.Company, t.Branch, t.TransportMode
FROM V_DIS_Leg l
JOIN V_DIS_TransportOrder t ON l.TransportOrderId = t.TransportOrderId
WHERE l.ShipmentId = :ShipmentId 
  AND l.LegType = :LegType 
  AND l.TransportOrderId IS NOT NULL
```

Then in application logic:
```
IF t.LoadingDate = :PerformanceDate 
   AND t.Company = :Company 
   AND t.Branch = :Branch
   -> IDEMPOTENT: Return existing TO (same operation repeated)
   
ELSE
   -> CONFLICT: Leg assigned to TO with different parameters!
```

**Use case:** Conflict detection - distinguish "retry of same request" from "different request for same data"

---

## Answered Questions (from Joachim, 2026-04-08)

### Q1: Business Invariant - Leg Assignment Cardinality
**Question:** Can a Shipment+LegType combination be assigned to multiple Transport Orders?

**Answer:** Yes, a leg of a shipment can be assigned to multiple Transport Orders. This enables splitting a large shipment across multiple TOs. These are technically separate legs. However, 2 legs of the same shipment cannot be assigned to the same TO. The interface assigns "free" legs indirectly via ShipmentId + LegType, not by LegId.

**Implication for verification:** The `limit 1` in V_DIS_Leg should be sufficient - we only need to know if ANY TO exists for this leg. (Pending final approval)

### Q2: Verification Depth - Intermediate States
**Question:** Should we check intermediate states for partial failure recovery?

**Answer:** No intermediate states exist. Transaction control (COMMIT/ROLLBACK) is handled in NewDispo, not in the TMS kernel. It's all-or-nothing. Only exception: the kernel throws an exception if the action is not possible in the current business object state.

**Implication:** Only need to check final state (TransportOrderId exists or not).

### Q3: Applicable Packages
**Question:** Which packages can be used for verification?

**Answer:** Any wrapper package or view with "DIS" in the name.

**Scope:** `pDIS_*` packages and `V_DIS_*` views.

### Q4: Idempotency Behavior
**Question:** Is CreateTransportOrderFromLeg idempotent?

**Answer:** 
- `CreateTransportOrderFromLeg` is **NOT idempotent** - will create a new TO each time with the same parameters
- `AddLeg` is **effectively idempotent** due to business rule: only 1 leg per shipment can be assigned to a TO (regardless of leg type)

**Implication:** NewDispo MUST check state before calling `CreateTransportOrderFromLeg` to prevent duplicate TOs.

---

<!-- internal -->
## Agent Architecture Discussion

### Option A: Native Code Browsing (Claude Code)

**Pros:**
- Always up-to-date with latest code
- Can follow dynamic call chains
- No maintenance of separate knowledge base

**Cons:**
- Slower - needs to read multiple files per analysis
- Context window consumption
- May miss cross-file relationships

### Option B: Neo4j AST Knowledge Graph as Router

**Pros:**
- Fast traversal of call graphs
- Pre-computed relationships (who calls what, what tables are touched)
- Efficient for "find all functions that write to table X"
- Agent can query graph first, then read specific code sections

**Cons:**
- Requires keeping graph in sync with code changes
- Initial setup effort
- May miss dynamic/runtime relationships

### Recommended: Hybrid Approach

```
Agent receives: Entry point (e.g., "CreateTransportOrderFromLeg")
    |
    +-> Query Neo4j: "What does this function call? What tables does it touch?"
    |       Returns: Call graph, affected tables, views
    |
    +-> Query Neo4j: "What views expose state for these tables?"
    |       Returns: Verification candidates (V_DIS_Leg, V_DIS_TransportOrder)
    |
    +-> Claude Code: Read specific verification view definitions
    |       Returns: Exact column mappings, join conditions
    |
    +-> Generate: Verification queries + documentation
```

The Neo4j graph acts as a **semantic router** - it knows WHERE to look, Claude Code reads WHAT it says.

### Code Browsing Evaluation (This Session)

**What it took to trace `CreateTransportOrderFromLeg` via native code browsing:**

| Step | Action | Files Read | Queries |
|------|--------|------------|---------|
| 1 | Find entry point | Grep for function name | 1 |
| 2 | Read PDIS_TRANSPORTORDER.sql | 1733 lines | 1 |
| 3 | Read V_DIS_LEG.sql | 203 lines | 1 |
| 4 | Read V_DIS_TRANSPORTORDER.sql | 100 lines | 1 |
| 5 | Find underlying tables | Grep for INSERT statements | 1 |
| 6 | Read GraphQL mutation | 59 lines | 1 |

**Total:** ~2100 lines read, 6 tool calls, ~3-5 minutes

**What Neo4j could provide instantly:**
```cypher
MATCH (f:Function {name: 'CreateTransportOrderFromLeg'})
      -[:CALLS*]->(called:Function)
      -[:WRITES]->(t:Table)
MATCH (v:View)-[:READS]->(t)
RETURN f, called, t, v
```

**Result:** Call graph + tables + views in one query (~100ms)

**Conclusion:**
- Native browsing: Effective but slow, context-heavy
- Neo4j routing: 50-100x faster for known patterns
- Hybrid optimal: Neo4j for structure, Claude for semantics
<!-- /internal -->

---

## Related Files

| File                                                                            | Purpose               |
| ------------------------------------------------------------------------------- | --------------------- |
| `Code/tms-alloydb-schema/src/sql/package/PDIS_TRANSPORTORDER.sql`               | DIS wrapper functions |
| `Code/tms-alloydb-schema/src/sql/view/V_DIS_LEG.sql`                            | Leg verification view |
| `Code/tms-alloydb-schema/src/sql/view/V_DIS_TRANSPORTORDER.sql`                 | TO verification view  |
| `Code/Disposition-Abstraction-Layer/.../CreateTransportOrderFromLegMutation.cs` | GraphQL entry point   |
| `Code/Disposition-Abstraction-Layer/.../CreateAndAddLegMutation.cs`             | GraphQL for AddLeg    |

---

## Next Steps

1. [x] ~~Verify business invariant (Q1) with stakeholders~~ - Answered by Joachim
2. [x] ~~Decide on verification depth (Q2)~~ - No intermediate states, check final only
3. [x] ~~Define applicable packages (Q3)~~ - All pDIS_* packages
4. [x] ~~Define idempotency behavior (Q4)~~ - Must pre-check, function is not idempotent
5. [ ] Implement verification check in NewDispo before calling CreateTransportOrderFromLeg
6. [ ] Test with CreateTransportOrderFromLeg as first case

---

<!-- internal -->
## Session Context (2026-04-08)

### Pending Decisions (Non-Neo4j)

All open questions (Q1-Q4) require business/architecture input, not Neo4j:
- **Q1** needs business stakeholder confirmation on leg assignment cardinality
- **Q2-Q4** are design decisions for the resilience pattern

### Neo4j Integration (Deferred)

Future optimization - current agent works without it via native code browsing.

Questions for later:
- What entities/relationships does the existing Neo4j AST capture?
- Does it have CALLS, WRITES, READS relationships?
- Does it link views to underlying tables?

### Agent Status

**Ready for use** in current state with native code browsing. Can analyze:
- Entry point: DIS-wrapper function name
- Output: State changes, verification queries, table-to-view mappings

**6 additional flows to analyze** - agent can be applied to each.
<!-- /internal -->
