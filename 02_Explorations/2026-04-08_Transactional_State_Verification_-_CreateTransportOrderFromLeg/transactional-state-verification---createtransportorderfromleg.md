# Transactional State Verification - CreateTransportOrderFromLeg

**Date:** 2026-04-08
<!-- internal -->
**Status:** Exploration
<!-- /internal -->

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
            |       -> Creates: Assignment in V_TA_Sen7
            |       -> Creates: TourPoints in Res_Hst (Pickup + Delivery)
            |       -> LegId = ShipmentId (for LongHaul legs)
            |
            +-> [LegType = 'VL' (PreCarriage)] pTA_VL.AddLeg()
                    -> May create new Leg via pDIS_Shipment.CreateLeg()
                    -> Creates: TourPoints
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

## Open Questions (for Business)

### Q1: Business Invariant - Leg Assignment Cardinality
**Question:** Can a Shipment+LegType combination be assigned to multiple Transport Orders (e.g., different PerformanceDates)?

**Hypothesis:** Based on `limit 1` in V_DIS_Leg, it appears to be a 1:1 relationship - a leg can only be on ONE Transport Order at a time.

**Action:** Verify with business stakeholders.

### Q2: Verification Depth
**Question:** Should the agent check only "operation completed" state, or also intermediate states for partial failure recovery?

**Options:**
- A) Only final state (TransportOrderId + LegId both exist)
- B) Intermediate states (TO created but leg not yet assigned)

### Q3: Scope of Agent
**Question:** Start with `pDIS_TransportOrder` functions only, or include other packages?

**Candidates:**
- `pDIS_Shipment` (Shipment operations)
- `pDIS_TourPoint` (Tour point operations)
- `pDIS_Tour` (Tour operations)

### Q4: Conflict Handling Strategy
**Question:** When a retry detects "leg already assigned to TO with DIFFERENT parameters" - what should happen?

**Options:**
- A) FAIL with error (strict idempotency)
- B) Return existing TO anyway (loose idempotency)
- C) Depends on specific parameter differences

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

1. [ ] Verify business invariant (Q1) with stakeholders
2. [ ] Decide on verification depth (Q2)
3. [ ] Define agent scope (Q3)
4. [ ] Define conflict handling strategy (Q4)
5. [ ] Prototype agent with Neo4j router + Claude Code reader
6. [ ] Test with CreateTransportOrderFromLeg as first case
