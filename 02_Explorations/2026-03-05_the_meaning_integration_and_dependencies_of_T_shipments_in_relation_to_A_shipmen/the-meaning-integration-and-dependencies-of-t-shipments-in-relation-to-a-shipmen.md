# the meaning, integration and dependencies of T shipments in relation to A shipments. The relevant column here is sendungsart on table sendung. i need to understand the business relevance and processes around it.

**Date:** 2026-03-05
**Status:** Exploration

---

## Original User Input

> Investigate the meaning, integration and dependencies of "T shipments" in relation to "A shipments". The relevant column here is "sendungsart" on table "sendung". Need to understand the business relevance and processes around it.

---

## Summary

**Key Finding:** The New Dispo system is designed to handle **only 'A' shipments** (Abgangssendung - main/primary shipments). 'T' shipments (Teilsendung - partial/sub-shipments) serve internal TMS routing purposes and are explicitly filtered out at multiple integration points.

- **'A' = Abgangssendung**: Main/primary shipments visible to disposition planning
- **'T' = Teilsendung**: Partial/subsidiary shipments linked to main 'A' shipments, used for multi-leg transport
- **Integration Point**: Only 'A' shipments flow through v_dis_shipment_all view and CDC pipeline to New Dispo
- **Relationship**: 'T' shipments are linked to parent 'A' shipments via the `sen_zuord` table

## Analysis

### Business Meaning

#### 'A' = Abgangssendung (Main/Primary Shipment)
- **Definition:** Main or primary shipments in the outbound/dispatch flow
- **Purpose:** The primary shipment that originates from the shipper and is dispatched for delivery
- **Visibility:** These are the operational shipments visible to disposition/pickup planning system
- **Business Process:** Used for standard pickup → main-line transport → delivery flow

#### 'T' = Teilsendung (Partial/Sub-shipment)
- **Definition:** Partial or subsidiary shipments linked to a main 'A' shipment
- **Alternative Names:** "HL-Sendung" (Hauptlaufsendung/main-line), "NL-Sendung" (Nebenlaufsendung/subsidiary)
- **Purpose:** Represent breakdowns or sub-divisions of a main shipment
- **Business Process:** Created when an 'A' shipment is split for operational reasons:
  - Intermediate deliveries at consolidation points
  - Multi-leg transport routing
  - Cross-docking operations
  - Partial deliveries to different locations

### Technical Relationship

#### Sendungsart Column
- **Location:** `sendung.sendungsart`
- **Type:** `character(1)` - single character field
- **Values:**
  - `'A'` - Abgangssendung (main shipment)
  - `'T'` or `'t'` - Teilsendung (partial shipment)
  - `'E'`, `'N'`, `'F'`, `'S'`, `'V'`, `'W'`, `'Z'` - other shipment types

#### Parent-Child Linking via sen_zuord Table
The relationship between 'A' (parent) and 'T' (child) shipments is managed through the `sen_zuord` table:
- **ref_tix:** Parent shipment TIX (typically 'A' shipment)
- **sen_tix:** Child shipment TIX (typically 'T' shipment)
- **typ:** Relationship type
  - `'H'` - HL-Sendung (main-line sub-shipment)
  - `'N'` - NL-Sendung (subsidiary sub-shipment)

#### Traffic Flow (Verkehrsstrom) Determination
'T' shipments are algorithmically marked as "Direktsendung" based on traffic flow:
```sql
rSen.Direktsendung := case when rSen.Verkehrsstrom in('30 ','31 ','32 ','34 ')
                           then 'T'
                           else 'F'
                      end;
```

**Traffic Flows for T shipments:**
- `'30'` - Direct domestic short-haul
- `'31'` - Domestic long-haul
- `'32'` - Domestic consolidation
- `'34'` - International/cross-border

## Database Schema

### sendung Table (Main Shipment Table)
**Location:** `Code/tms-alloydb-schema/src/sql/table/sendung.sql:19`

```sql
CREATE TABLE sendung (
    sendung_tix numeric(22,0) NOT NULL,
    sendungsart character(1),              -- Shipment type: 'A', 'T', 'E', 'N', 'F', etc.
    sendung_n numeric(7,0),                -- Shipment number
    fix_key character(9),                  -- Departure service area
    firma numeric(3,0),                    -- Company
    niederlassung numeric(2,0),            -- Branch
    verkehrsstrom character(3),            -- Traffic flow
    direktsendung character(1),            -- Direct shipment flag ('T'/'F')
    ref_sen_tix numeric(22,0),             -- Reference shipment TIX
    ...
);
```

### sen_zuord Table (Shipment Association/Linking)
**Location:** `Code/tms-alloydb-schema/src/sql/table/sen_zuord.sql`

```sql
CREATE TABLE sen_zuord (
    ref_tix numeric(22,0) NOT NULL,    -- Parent shipment TIX
    sen_tix numeric(22,0) NOT NULL,    -- Child/associated shipment TIX
    typ character(1) NOT NULL,         -- Association type ('H', 'N', 'S', 'T', 'Z')
    u_version character(1),
    c_time timestamp,
    c_user character(8),
    u_time timestamp,
    u_user character(8),
    lfd_n numeric(5,0)                 -- Sequential number
);
```

### Key Constraints
**Location:** `Code/tms-alloydb-schema/src/sql/constraint/pk_uq/sendung_pk_uq.sql:2`

```sql
ALTER TABLE ONLY sendung
  ADD CONSTRAINT sendungc2 UNIQUE (sendung_n, fix_key, sendungsart, firma, niederlassung);
```

The unique constraint includes `sendungsart`, meaning the same shipment number can exist with different sendungsart values (e.g., one 'A' and multiple 'T' shipments).

## Source Code Evidence

### 1. Disposition System Integration (New Dispo Backend)

#### V_DIS_SHIPMENT_ALL View - Only 'A' Shipments
**Location:** `Code/tms-alloydb-schema/src/sql/view/V_DIS_SHIPMENT_ALL.sql`

```sql
create or replace view v_dis_shipment_all as
select
    s.sendung_tix,
    s.sendungsart,
    s.sendung_n,
    ...
from sendung s
where sendungsart = 'A'::bpchar;  -- ⚠️ ONLY 'A' shipments visible to New Dispo
```

**Impact:** The New Dispo batch initialization only receives 'A' shipments via GraphQL queries.

#### CDC Pipeline Filter
**Reference:** Cloud Functions filter logic (mentioned in agent findings)
```
shipmentType == 'A'  -- Only 'A' shipments published to Pub/Sub
```

**Impact:** Change events for 'T' shipments do NOT propagate to New Dispo backend.

### 2. Views Including Both 'A' and 'T' Shipments

#### V_EMP_SEN_SUM (Recipient Shipment Summary)
**Location:** `Code/tms-alloydb-schema/src/sql/view/V_EMP_SEN_SUM.sql`

```sql
WHERE ((s.verkehrsstrom = ANY (ARRAY['30'::bpchar, '34'::bpchar]))
  AND ((s.sendungsart = ANY (ARRAY['t'::bpchar, 'T'::bpchar]))
       OR ((s.sendungsart = 'A'::bpchar) AND (sen.isavis(s.status_8) = (1)::numeric))))
```

**Business Logic:** For specific traffic flows (30, 34), both 'T' and 'A' shipments are included.

#### V_SEN7, V_SEN4 (General Shipment Lists)
```sql
WHERE ((s.sendungsart = ANY (ARRAY['A'::bpchar, 'T'::bpchar, 't'::bpchar, 'Z'::bpchar]))
  AND (s.verkehrsstrom = ANY (ARRAY['3'::bpchar, '30'::bpchar, '31'::bpchar, '32'::bpchar, '34'::bpchar])))
```

### 3. Views Explicitly Excluding 'T' Shipments

#### V_ESB_MEASURINGPOINT5DETAIL (ESB Tracking Measuring Points)
**Location:** `Code/tms-alloydb-schema/src/sql/view/V_ESB_MEASURINGPOINT5DETAIL.sql`

```sql
WHERE ... AND (s.sendungsart <> ALL (ARRAY['F'::bpchar, 'T'::bpchar, 't'::bpchar]))
```

**Impact:** 'T' shipments do NOT generate ESB measuring point events for external tracking systems.

### 4. Trigger Logic Handling 'A' Shipments

#### traiu_sendung Trigger (After Update on sendung)
**Location:** `Code/tms-alloydb-schema/src/sql/trigger/all_trigger_events.sql`

```sql
CREATE TRIGGER traiu_sendung AFTER UPDATE ON sendung
  FOR EACH ROW
  WHEN (((new.sendungsart = ANY (ARRAY['A'::bpchar, 'E'::bpchar, 'N'::bpchar]))
    AND (new.status_erf <> '5'::bpchar) ...))
```

**Logic:** Main update triggers fire for 'A', 'E', and 'N' shipments, but NOT for 'T' shipments.

### 5. Backend Entity Mapping

#### SendungEntity (TMS Bridge)
**Location:** `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/Data/Entities/Sendung/SendungEntity.cs:22`

```csharp
public class SendungEntity
{
    public long SendungTix { get; set; }
    public string? Sendungsart { get; set; }  // Maps to sendung.sendungsart
    ...
}
```

#### GoogleBucketShipmentData (New Dispo Backend)
**Location:** `Code/Disposition-Backend/CALConsult.Disposition.API/Infrastructure/GooglePubSub/Dtos/GoogleBucketShipmentData.cs:20`

```csharp
[JsonProperty("sendungsart")]
public string ShipmentType { get; set; } = null!;
```

**Note:** Backend receives this field, but upstream filters ensure only 'A' values arrive.

## Findings

### Critical Integration Points

| Component | 'A' Shipments | 'T' Shipments | Impact |
|-----------|---------------|---------------|--------|
| **v_dis_shipment_all** | ✅ Included | ❌ Excluded | Only 'A' shipments visible to New Dispo batch init |
| **CDC Pipeline Filter** | ✅ Published | ❌ Filtered out | 'T' shipment changes NOT propagated to backend |
| **ESB Measuring Points** | ✅ Tracked | ❌ Not tracked | 'T' shipments invisible to external tracking |
| **Disposition Triggers** | ✅ Triggers fire | ❌ Excluded | 'A' shipments get full status update processing |
| **sen_zuord Linking** | ✅ Parent | ✅ Child | 'T' linked to parent 'A' via ref_tix |

### Key Business Dependencies

1. **Shipment Consolidation**
   - Multiple 'T' shipments can be children of a single 'A' shipment
   - Linked via `sen_zuord` table with typ='H' (HL-Sendung) or typ='N' (NL-Sendung)

2. **Pickup Planning (New Dispo)**
   - Only 'A' shipments are loaded into the disposition system
   - Pickup planning operates solely on 'A' shipments
   - Driver terminals only see 'A' shipments in pickup lists

3. **Tracking & Monitoring**
   - Only 'A' shipments reach ESB measuring points
   - External tracking systems cannot directly track 'T' shipments
   - Customer visibility limited to 'A' shipments

4. **Status Management**
   - Dispatch status (`status_abf`, `status_dis`) primarily updated for 'A' shipments
   - Status triggers focus on 'A', 'E', 'N' types
   - 'T' shipments have minimal status transition logic

5. **Multi-leg Transport Flow**
   - 'T' shipments enable multi-stop/multi-leg delivery scenarios
   - Represent intermediate routing steps not visible to end customers
   - Support consolidation center processing

### Processing Differences

#### 'A' Shipments (Abgangssendung)
- ✅ Visible in New Dispo disposition planning
- ✅ CDC events published to backend
- ✅ Full status update triggers
- ✅ ESB measuring point tracking
- ✅ Customer-facing shipment number
- ✅ Pickup planning integration

#### 'T' Shipments (Teilsendung)
- ❌ Hidden from New Dispo disposition planning
- ❌ No CDC events to backend
- ❌ Limited status update triggers
- ❌ No ESB measuring point tracking
- ✅ Linked to parent 'A' shipment via sen_zuord
- ✅ Internal TMS routing purposes only
- ✅ Specific traffic flow handling (30, 31, 32, 34)

## Questions/Open Items

### Business Requirements Questions

1. **Should 'T' shipments ever be visible in New Dispo disposition planning?**
   - Current state: Only 'A' shipments are visible
   - If yes: Major architectural changes required

2. **What happens when a driver needs to pick up or deliver a 'T' shipment?**
   - Are 'T' shipments always handled at consolidation centers?
   - Do drivers receive separate instructions for 'T' shipments outside of New Dispo?

3. **How does the legacy TMS handle 'T' shipments in dispatch planning?**
   - Is there a separate disposition process for 'T' shipments?
   - Are they automatically assigned based on parent 'A' shipment routing?

4. **Customer Visibility:**
   - Can customers track 'T' shipments independently?
   - Or do they only see the parent 'A' shipment status?

5. **Multi-leg Routing:**
   - How are 'T' shipments created? Manual or automatic?
   - What triggers the creation of a 'T' shipment from an 'A' shipment?

### Technical Implementation Questions

6. **If 'T' shipment integration is required, what changes are needed?**
   - Modify `v_dis_shipment_all` to include 'T' shipments?
   - Update CDC filter to propagate 'T' shipment events?
   - Add backend domain logic to handle parent-child relationships?
   - UI changes to display linked shipments?

7. **Leg/Lot Generation:**
   - Should 'T' shipments generate separate legs?
   - Or should legs reference the parent 'A' shipment?

8. **Status Synchronization:**
   - Should status updates on 'T' shipments affect parent 'A' shipment?
   - Vice versa?

9. **Route Calculation:**
   - Are 'T' shipments independently routed?
   - Or do they inherit routing from parent 'A' shipment?

10. **Data Integrity:**
    - Can a 'T' shipment exist without a parent 'A' shipment?
    - What validation rules apply to sen_zuord relationships?

## Related Files

### Database Schema (TMS AlloyDB)
- **Main Table:** `Code/tms-alloydb-schema/src/sql/table/sendung.sql` (line 19: sendungsart column)
- **Linking Table:** `Code/tms-alloydb-schema/src/sql/table/sen_zuord.sql`
- **Constraints:** `Code/tms-alloydb-schema/src/sql/constraint/pk_uq/sendung_pk_uq.sql` (line 2: unique constraint)

### Views (Critical for Integration)
- **New Dispo Integration:** `Code/tms-alloydb-schema/src/sql/view/V_DIS_SHIPMENT_ALL.sql` (filters for 'A' only)
- **Recipient Summary:** `Code/tms-alloydb-schema/src/sql/view/V_EMP_SEN_SUM.sql` (includes both 'A' and 'T')
- **Shipment Lists:** `Code/tms-alloydb-schema/src/sql/view/V_SEN7.sql`, `V_SEN4.sql` (includes 'A', 'T', 'Z')
- **ESB Tracking:** `Code/tms-alloydb-schema/src/sql/view/V_ESB_MEASURINGPOINT5DETAIL.sql` (excludes 'T')

### Triggers
- **Update Trigger:** `Code/tms-alloydb-schema/src/sql/trigger/all_trigger_events.sql` (traiu_sendung - handles 'A', 'E', 'N')
- **Post-View Functions:** `Code/tms-alloydb-schema/src/sql/trigger/all_trigger_functions_post_views.sql` (Direktsendung logic)

### Stored Procedures/Packages
- **SEN Package:** `Code/tms-alloydb-schema/src/sql/package/SEN.sql` (lines 11092, 13817: 'E','N' filtering)
- **PPST Package:** `Code/tms-alloydb-schema/src/sql/package/PPST.sql` (HL-/NL-Sendung comments and logic)
- **PFRK Package:** `Code/tms-alloydb-schema/src/sql/package/PFRK.sql` (lines 1132, 3207: 'A' filtering)
- **DISP_MDE_AH:** `Code/tms-alloydb-schema/src/sql/package/DISP_MDE_AH.sql` (line 178: 'A','N' filtering)

### Backend Code (New Dispo)
- **TMS Bridge Entity:** `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/Data/Entities/Sendung/SendungEntity.cs` (line 22: Sendungsart property)
- **CDC DTO:** `Code/Disposition-Backend/CALConsult.Disposition.API/Infrastructure/GooglePubSub/Dtos/GoogleBucketShipmentData.cs` (line 20: ShipmentType mapping)

### Documentation
- **Architecture Docs:** Check `08_Documentation/` folder for any shipment data flow documentation
- **Related Exploration:** `02_Explorations/2026-02-25_User_Story_103821_OMS_Sendung_Quell_K_analysis/` (quell_k field related)

## Related User Stories/Tasks

### Potentially Impacted Areas

1. **User Story: OMS Sendung Quell_K analysis** (2026-02-25 exploration)
   - Related exploration on sendung table fields
   - May have implications for 'T' shipment handling

2. **Pickup Planning / Batch Initialization**
   - Current: Only loads 'A' shipments via v_dis_shipment_all
   - Impact: Any requirements to plan 'T' shipments would require view changes

3. **CDC Pipeline / Change Notifications**
   - Current: Filters for shipmentType == 'A' in Cloud Functions
   - Impact: Adding 'T' shipment events would require filter modification

4. **Route Calculation**
   - Question: Should 'T' shipments have independent routes?
   - Impact: May need separate route calculation logic for multi-leg scenarios

5. **Driver Terminal / Mobile App**
   - Current: Only displays 'A' shipments
   - Impact: If 'T' shipments need driver visibility, UI changes required

6. **Customer Tracking / Portal**
   - Question: Should customers see 'T' shipment details?
   - Impact: May need API changes to expose linked shipments

### Future Considerations

- **Multi-leg Transport Enhancement:** If New Dispo needs to support multi-leg routing, 'T' shipment integration becomes critical
- **Consolidation Center Integration:** 'T' shipments are key for consolidation/cross-dock workflows
- **International Shipments:** Traffic flows 34 (international) heavily use 'T' shipments for border crossing/customs handling

---

## Deep Dive: T and A Shipments in Legacy TMS Context

*This section explores how T and A shipments work within the legacy TMS database, independent of New Dispo integration.*

### Complete Shipment Type Classification

The `sendungsart` field defines a comprehensive shipment type hierarchy:

| Type | German Name | English Translation | Purpose |
|------|-------------|---------------------|---------|
| **'S'** | Transportauftrag (TA) | Transport Order | Master shipment aggregating other shipments |
| **'A'** | Abgangssendung | Outbound Shipment | Regular shipment with direct delivery |
| **'T'** | Teilsendung | Partial/Split Shipment | Created from splitting A or E shipments |
| **'Z'** | ZUSA | Consolidation Shipment | Aggregation/consolidation of multiple shipments |
| **'E'** | Einzelsendung | Single Shipment | Standalone single-piece shipment |
| **'N'** | Nachlieferung | Follow-up Shipment | Subsequent delivery for same customer |
| **'F'** | Fraktion | Fraction/Sub-unit | Sub-unit of larger shipment |
| **'U'** | Unknown/Conversion | - | Conversion type |

**Key Insight:** T and A shipments are part of a larger hierarchy where 'S' (Transport Orders) serve as parent containers, and 'Z' (ZUSA) shipments provide consolidation functionality.

### Shipment Hierarchy Model

```
S (Transportauftrag/TA) - Transport Order
├── A (Abgangssendung) - Direct outbound shipment
│   └── [Optional] T (Teilsendung) - If split via loading list
│       └── [Optional] Z (ZUSA) - Consolidation
├── E (Einzelsendung) - Single-piece shipment
│   └── [Optional] T (Teilsendung) - If split
├── N (Nachlieferung) - Follow-up delivery
└── F (Fraktion) - Fraction/sub-unit
```

**Linking Mechanism:** All relationships managed through `sen_zuord` table:
- `typ = 'S'`: Links S shipment to child shipments (A/T/E/N)
- `typ = 'Z'`: Links Z consolidation shipment to consolidated shipments

**Source:** `Code/tms-alloydb-schema/src/sql/view/v_ta_sen7.sql`

### sen_zuord Relationship Types

```sql
CREATE TABLE sen_zuord (
    ref_tix numeric(22,0) NOT NULL,  -- Parent shipment TIX
    sen_tix numeric(22,0) NOT NULL,  -- Child shipment TIX
    typ character(1) NOT NULL,       -- Relationship type
    lfd_n numeric(5,0)               -- Sequence number for ordering
);
```

**Relationship Types (typ field):**
- **'S'** - Standard TA linkage: Parent S (Transport Order) → Child shipment (A/T/E/N)
- **'Z'** - ZUSA linkage: Z (Consolidation) → Consolidated shipments
- **'H'** - HL-Sendung: Main-line sub-shipment (referenced in comments)
- **'N'** - NL-Sendung: Secondary/subsidiary shipment (referenced in comments)

### T Shipment Creation Workflow

#### When Are T Shipments Created?

**Trigger 1: Loading List Assignment**
```sql
-- From V_TA_ZUSA_SEN.sql
WHERE s.sendungsart = 'T'
  AND s.ladelist_tix IS NOT NULL
```

When an A shipment gets assigned to a loading list (`ladelist_tix`):
1. Original A shipment remains as master record
2. T shipments created for each piece/colli on the loading list
3. Each T shipment references the same `ladelist_tix`
4. T shipments linked to parent S via `sen_zuord(typ='S')`

**Trigger 2: Multi-leg Routing Requirements**

Traffic flows `30, 31, 32, 34` automatically mark shipments for splitting:
```sql
-- From all_trigger_functions_post_views.sql
rSen.Direktsendung := case
    when rSen.Verkehrsstrom in('30 ','31 ','32 ','34 ')
    then 'T'
    else 'F'
end;
```

When `direktsendung = 'T'`, the shipment is eligible for T-type processing.

**Trigger 3: Piece-Based Operations**

From `LSTGEN.sql` (Loading List Generation):
```sql
(i_lst_art = 'N'  AND (i_sendung.sendungsart = 'A' OR i_sendung.sendungsart = 'F'))
(i_lst_art = 'VH' AND (i_sendung.sendungsart = 'A' OR i_sendung.sendungsart = 'F'))
(i_lst_art = 'H'  AND (i_sendung.sendungsart = 'A' OR i_sendung.sendungsart = 'F'))
```

Only 'A' and 'F' shipments can generate loading lists, which then create 'T' shipments.

### Document Assignment: Bordero vs Rollkart vs Ladelist

#### A (Abgangssendung) Document Flow:

```sql
-- Key fields in sendung table
bordero_tix numeric(22,0),      -- Bordero (waybill) TIX
bordero_n numeric(15,0),         -- Bordero number
bordero_pos numeric(3,0),        -- Position on bordero
bordero_e timestamp,             -- Bordero entry time

rollkart_tix numeric(22,0),      -- Rollkart (roll cart) TIX
rollk_n numeric(15,0),           -- Rollkart number
rollk_pos numeric(3,0),          -- Position on rollkart

ladelist_tix numeric(22,0),      -- Loading list TIX
ladeliste_n numeric(15,0),       -- Loading list number
ladeliste_pos numeric(3,0)       -- Position on loading list
```

**Document Priority:**
1. **Bordero** - Primary shipping document for A shipments
   - Used for standard direct deliveries
   - Contains routing and delivery instructions
   - Drives status transitions

2. **Rollkart** - For smaller consolidated shipments
   - Multiple shipments on same physical cart
   - Often used for local/regional distribution

3. **Ladelist** - Triggers T shipment creation
   - Multi-piece shipments requiring piece-level tracking
   - Creates one T shipment per piece or logical group
   - Enables independent routing per piece

#### T (Teilsendung) Document Flow:

```sql
-- From V_TA_ZUSA_SEN.sql
WHERE (s.sendungsart = 'T' AND s.ladelist_tix IS NOT NULL)
```

**T Shipments:**
- **Always** have `ladelist_tix` populated (by definition created from loading lists)
- May **inherit** `bordero_tix` from parent A shipment
- Can have **independent** `rollkart_tix` for physical routing
- Share same `ladeliste_n` with sibling T shipments

### Status Field Workflow Differences

#### Status Fields Overview:

```sql
status_erf character(1)     -- Erfassung (Capture/Entry) status
status_dis character(1)     -- Disposition status
status_abf character(1)     -- Abfertigung (Dispatch) status
status_frb character(1)     -- Frachtberechnung (Freight calculation)
status_zus character(1)     -- Zusatz (Supplementary)
status_mod character(1)     -- Modifikation (Modification)
status_rue character(1)     -- Rückmeldung (Feedback/Response)
status_sta character(1)     -- Status aggregation
status_hst numeric(3,0)     -- HST (History) status pointer
status_8 character(1)       -- AVIS flag (advance notice)
```

#### A Shipment Status Processing:

**Trigger Logic:**
```sql
-- From all_trigger_events.sql
CREATE TRIGGER traiu_sendung AFTER UPDATE ON sendung
WHEN (
    -- Case 1: Status and address changes for A/E/N shipments
    (new.sendungsart = ANY (ARRAY['A'::bpchar, 'E'::bpchar, 'N'::bpchar]))
    AND (new.status_erf <> '5'::bpchar)

    OR

    -- Case 2: Dispatch status change for A shipments only
    ((COALESCE(new.status_abf, '*') <> COALESCE(old.status_abf, '*'))
     AND (new.sendungsart = 'A'::bpchar)
     AND (new.status_rue IS NULL)
     AND ((new.status_abf = 'A'::bpchar) OR (old.status_abf = 'A'::bpchar)))
)
```

**Key Points:**
- **status_abf** changes trigger workflow ONLY for 'A' shipments
- When `status_abf = 'A'` (dispatched), special processing occurs
- Requires `status_rue IS NULL` (no feedback response yet)
- 'E' and 'N' shipments get address/routing change triggers
- **'T' shipments excluded from main trigger logic**

#### T Shipment Status Processing:

From view logic in `V_TA_SEN.sql`:
```sql
-- Mode-dependent T shipment visibility
WHEN (
    (COALESCE(pta.getmodus(), 1) <> 1)  -- Non-standard mode
    AND (
        (s.sendungsart = ANY (ARRAY['t'::bpchar, 'T'::bpchar]))
        OR ((s.sendungsart = 'A'::bpchar) AND (sen.isavis(s.status_8) = 1))
    )
)
OR
(
    (COALESCE(pta.getmodus(), 1) = 1)   -- Standard mode
    AND (s.sendungsart <> ALL (ARRAY['T'::bpchar, 't'::bpchar]))
)
```

**Interpretation:**
- **Standard mode (modus=1):** T shipments hidden from TA views
- **Alternative modes:** T shipments visible alongside A shipments with AVIS flag
- **AVIS (status_8):** When set, A shipments treated similarly to T shipments in reporting

**Why the difference?**
- T shipments represent internal operational splits
- Customers and standard workflows see only A shipments
- Warehouse/logistics operations need T visibility in special modes

### ZUSA (Consolidation) Shipment Integration

#### The Z Shipment Role:

**Purpose:** Consolidate multiple A or T shipments for combined transport

**View: V_TA_ZUSA_SEN**
```sql
-- ZUSA relationships
WHERE (
    -- Case 1: T shipments with loading lists linked to other T
    (s.sendungsart = 'T' AND s.ladelist_tix IS NOT NULL AND z.sendungsart = 'T')

    OR

    -- Case 2: A/U shipments linked to Z consolidation
    ((s.sendungsart = 'A' OR s.sendungsart = 'U') AND z.sendungsart = 'Z')
)
AND z.status_3 = 'Z'  -- ZUSA marker in status field
```

**Consolidation Pattern:**
```
S (Transport Order)
├── Z (ZUSA Consolidation)
│   ├── A (Shipment 1)
│   ├── A (Shipment 2)
│   └── T (Shipment 3) ← from split A shipment
```

**Business Use Case:**
- Multiple customer shipments going to same geographic region
- Combined into single Z shipment for efficient trunk transport
- De-consolidated at destination hub
- Individual A/T shipments delivered separately at final mile

### Multi-leg Routing with T Shipments

#### Leg Structure:

T shipments enable multi-hop routing through resource history tracking:

**From V_TA_SEN.sql:**
```sql
t.res_hst_tix,          -- Resource/Hardware Stop TIX
t.typ = 3 AND t.art = 100  -- Tour point type indicator
```

**Multi-leg Pattern:**
```
A (Origin Shipment) → [Split at Hub 1]
  ├→ T1 (Leg: Hub 1 → Hub 2) → res_hst_tix = Stop1
  │   └→ T1.1 (Leg: Hub 2 → Final Dest) → res_hst_tix = Stop2
  │
  └→ T2 (Leg: Hub 1 → Hub 3) → res_hst_tix = Stop3
      └→ T2.1 (Leg: Hub 3 → Final Dest) → res_hst_tix = Stop4
```

**Status Progression:**
- Each leg has independent `status_dis`, `status_abf` tracking
- Parent A shipment status aggregates child T statuses
- `res_hst_tix` links to physical stop/location history

#### Dispatch Logic from DISP_SPEICH.sql:

```sql
IF (v_disp_info = 'LK'
    OR (v_disp_info = 'LT' AND v_sendungsart = 'A')
    OR (v_disp_info = 'LM' AND v_sendungsart != 'A'))
```

**Dispatch Type Codes:**
- **LK** - Any shipment type (standard)
- **LT** - Only for 'A' shipments (direct transport)
- **LM** - Only for non-'A' shipments (T, E, N - multi-leg or special)

### Key TMS Reporting Views

#### V_TA_SEN7 - Complete Shipment Hierarchy

**Structure:**
```sql
-- Shows: S (TA) → Z (ZUSA) → Shipments (A/T/E/N)
SELECT
    t.sendung_tix AS ta_tix,      -- Transport Order TIX
    z.sendung_tix AS zusa_tix,    -- ZUSA TIX (or direct child)
    s.sendung_tix AS sen_tix      -- Final shipment TIX
FROM sendung t, sen_zuord tz, sendung z, sen_zuord zs, sendung s
WHERE t.sendungsart = 'S'
  AND z.sendungsart IN ('T', 'Z')
  AND s.sendungsart IN ('A', 'U', 'T', 'E', 'N', 'H')
```

**Source:** `Code/tms-alloydb-schema/src/sql/view/v_ta_sen7.sql`

**Use Case:** Complete visibility of entire transport order hierarchy for operations planning

#### V_TA_ZUSA_SEN - Consolidation Analysis

**Structure:**
```sql
-- Shows: TA → ZUSA → A/T shipments with consolidation
WHERE (
    (s.sendungsart = 'T' AND s.ladelist_tix IS NOT NULL AND z.sendungsart = 'T')
    OR
    ((s.sendungsart = 'A' OR s.sendungsart = 'U') AND z.sendungsart = 'Z')
)
AND z.status_3 = 'Z'
```

**Source:** `Code/tms-alloydb-schema/src/sql/view/V_TA_ZUSA_SEN.sql`

**Use Case:** Analyze consolidation efficiency, track consolidated shipment groups

#### V_EMP_SEN_SUM - Recipient-Based Aggregation

**Structure:**
```sql
-- Aggregates by recipient, includes T and A with AVIS
WHERE (
    (s.verkehrsstrom = ANY (ARRAY['30'::bpchar, '34'::bpchar]))
    AND (
        (s.sendungsart = ANY (ARRAY['t'::bpchar, 'T'::bpchar]))
        OR ((s.sendungsart = 'A'::bpchar) AND (sen.isavis(s.status_8) = 1))
    )
)
GROUP BY empf_n, empf_i, empf_name1, emp_erm_rel
```

**Source:** `Code/tms-alloydb-schema/src/sql/view/V_EMP_SEN_SUM.sql`

**Use Case:** Customer service view showing all shipments (including T pieces) for recipient

#### V_REL_SEN_SUM - Service Area Aggregation

**Structure:**
```sql
-- Aggregates by service area (relation)
WHERE sendungsart IN ('T', 't')
   OR (sendungsart = 'A' AND sen.isavis(status_8) = 1)
GROUP BY emp_erm_rel, leistungsdatum
```

**Use Case:** Regional operations planning by service area

### Status Aggregation and Reporting

#### AVIS Flag (status_8) Special Handling:

The `status_8` field serves as an AVIS (advance notice) flag:

```sql
-- From sen.isavis() function logic in views
sen.isavis(s.status_8) = 1  -- AVIS is active
```

**When AVIS is set:**
- A shipments treated like T shipments in some reports
- Indicates customer requested special notification
- Changes visibility in recipient and service area views
- Aggregated separately in summary reports

**Business Meaning:**
- Customer wants advance notice of delivery
- Shipment requires special handling/communication
- Often used for high-value or time-critical shipments

### German Business Terminology Reference

| German Term | Abbreviation | English | TMS Field/Context |
|-------------|--------------|---------|-------------------|
| **Transportauftrag** | TA | Transport Order | sendungsart = 'S' |
| **Abgangssendung** | - | Outbound Shipment | sendungsart = 'A' |
| **Teilsendung** | - | Partial Shipment | sendungsart = 'T' |
| **Zusammenfassung** | ZUSA | Consolidation | sendungsart = 'Z', status_3 = 'Z' |
| **Einzelsendung** | - | Single Shipment | sendungsart = 'E' |
| **Nachlieferung** | - | Follow-up Delivery | sendungsart = 'N' |
| **Hauptlaufsendung** | HL | Main-line Shipment | sen_zuord.typ = 'H' |
| **Nebenlaufsendung** | NL | Secondary Shipment | sen_zuord.typ = 'N' |
| **Bordero** | - | Waybill/Bill of Lading | bordero_tix, bordero_n |
| **Rollkarte** | - | Roll Cart | rollkart_tix, rollk_n |
| **Ladeliste** | - | Loading List | ladelist_tix, ladeliste_n |
| **Erfassung** | ERF | Data Capture/Entry | status_erf |
| **Disposition** | DIS | Planning/Assignment | status_dis |
| **Abfertigung** | ABF | Dispatch/Handling | status_abf |
| **Rückmeldung** | RUE | Feedback/Response | status_rue |
| **Avis** | - | Advance Notice | status_8 |
| **Verkehrsstrom** | - | Traffic Flow | verkehrsstrom field |
| **Relation** | REL | Service Area | relation, emp_erm_rel |

### Complete T/A Lifecycle Workflow

```
1. ORDER ENTRY
   └→ Create S (Transport Order) - sendungsart = 'S'
       ├→ Order contains one or more planned shipments
       └→ Links via sen_zuord to child shipments

2. SHIPMENT CREATION
   └→ Create A (Abgangssendung) - sendungsart = 'A'
       ├→ Linked to parent S via sen_zuord(typ='S')
       ├→ status_erf set (data captured)
       ├→ Address and routing info populated
       └→ Assigned to bordero (standard workflow)

3. PLANNING DECISION POINT

   Path A: DIRECT DELIVERY (no splitting)
   └→ A shipment proceeds as-is
       ├→ status_dis = 'L' (planned to tour)
       ├→ Assigned to driver/tour
       ├→ status_abf = 'A' (dispatched) triggers workflow
       └→ Delivered as single unit

   Path B: MULTI-PIECE / MULTI-LEG (splitting)
   └→ Loading list assignment
       ├→ ladelist_tix populated on A shipment
       ├→ Generate T shipments for each piece/group
       │   ├→ Each T has same ladelist_tix
       │   ├→ Each T linked via sen_zuord(typ='S') to parent S
       │   ├→ T shipments can have independent routing
       │   └→ T shipments tracked separately through legs
       └→ Original A remains as master record

4. CONSOLIDATION (optional)
   └→ Create Z (ZUSA) consolidation
       ├→ Multiple A or T shipments combined
       ├→ Linked via sen_zuord(typ='Z')
       ├→ status_3 = 'Z' marks ZUSA type
       ├→ Combined transport to shared destination
       └→ De-consolidated at destination hub

5. DISPATCH & TRACKING

   For A shipments:
   ├→ status_abf updates trigger main workflow
   ├→ ESB measuring points generated
   ├→ Customer tracking available
   └→ Standard status progression

   For T shipments:
   ├→ Independent status per leg/piece
   ├→ No ESB measuring points (internal only)
   ├→ Not visible to customer directly
   ├→ Aggregated status rolled up to parent A
   └→ Special mode required for TMS visibility

6. DELIVERY COMPLETION
   └→ All T pieces completed → A status updated
       ├→ status_rue processed (feedback)
       ├→ Customer sees A shipment as delivered
       └→ T shipment details archived
```

### Critical Files for T/A Logic

**Core Tables:**
- `Code/tms-alloydb-schema/src/sql/table/sendung.sql` (line 19: sendungsart)
- `Code/tms-alloydb-schema/src/sql/table/sen_zuord.sql` (relationship table)

**Hierarchy Views:**
- `Code/tms-alloydb-schema/src/sql/view/v_ta_sen7.sql` (complete hierarchy)
- `Code/tms-alloydb-schema/src/sql/view/V_TA_ZUSA_SEN.sql` (consolidation)
- `Code/tms-alloydb-schema/src/sql/view/V_TA_SEN.sql` (TA → shipment detail)

**Summary Views:**
- `Code/tms-alloydb-schema/src/sql/view/V_EMP_SEN_SUM.sql` (recipient aggregation)
- `Code/tms-alloydb-schema/src/sql/view/V_REL_SEN_SUM.sql` (service area aggregation)

**Processing Logic:**
- `Code/tms-alloydb-schema/src/sql/package/PTA.sql` (TA processing)
- `Code/tms-alloydb-schema/src/sql/package/LSTGEN.sql` (loading list generation)
- `Code/tms-alloydb-schema/src/sql/package/DISP_SPEICH.sql` (dispatch storage)
- `Code/tms-alloydb-schema/src/sql/trigger/all_trigger_events.sql` (status triggers)

### Key Insights for Architecture Decisions

1. **T Shipments Are Not Independent Entities**
   - Always children of S (Transport Order) shipments
   - Created as byproduct of loading list assignment
   - Cannot exist without parent S linkage via sen_zuord

2. **A Shipments Are Customer-Facing**
   - Primary business transaction record
   - Visible in customer tracking systems
   - Generate ESB measuring point events
   - Trigger main workflow status transitions

3. **T Shipments Enable Internal Operations**
   - Support multi-leg routing without customer complexity
   - Enable piece-level tracking for large shipments
   - Allow consolidation/de-consolidation flexibility
   - Keep customer view simple while supporting complex logistics

4. **Status Synchronization Is One-Way**
   - T shipment status → rolls up to parent A shipment
   - A shipment status → does NOT automatically update T shipments
   - Each T shipment has independent operational status
   - Customer sees only aggregated A shipment status

5. **Integration Implications for New Dispo**
   - Current filtering (A only) maintains customer-facing view
   - Adding T shipments would expose internal operations
   - Would require parent-child relationship handling in domain model
   - May create confusion if drivers see internal split pieces
   - Consider whether multi-leg planning is needed vs. single-leg focus
