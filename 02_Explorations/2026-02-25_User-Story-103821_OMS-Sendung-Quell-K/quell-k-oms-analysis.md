# User Story 103821: Sendung.Quell_K and Sen_Ref.Typ=OMS_ID

**Date:** 2026-02-25
**Status:** Exploration
**Related User Story:** 103821

---

## Original User Input

> Von Joachim: User Story 103821: Sendung.Quell_K=s und Sen_Ref.Typ=OMS_ID
> Sorry, das war nicht ganz korrekt. Quell_K für OMS-Sendungen kann jeder Kleinbuchstabe oder O sein.

**Translation:**
> Sorry, that wasn't quite correct. Quell_K for OMS shipments can be any lowercase letter or O.

---

## Summary

This exploration investigates how to retrieve the **OMS_ID** for OMS shipments in New Dispo views (e.g., `v_dis_transportorder`), with a focus on performance considerations when resolving the OMS_ID through database functions or procedures.

## Objective

**Make OMS_ID available in New Dispo views** to enable:
- Identification of OMS shipments in the New Dispo UI
- Integration with OMS-specific workflows
- Cross-reference between TMS and OMS systems

**Performance Constraint:** The OMS_ID lookup must not degrade view performance, especially if it requires joining to `sen_ref` table or calling functions/procedures.

## OMS Shipment Identification

**Quell_K (Source Key) Criteria:**
- Any lowercase letter (a-z), OR
- Uppercase 'O'

**Sendungsart (Shipment Type):**
- 'A' (Avis/Notification)
- 'N' (Normal shipment)
- 'T' (Grobavis/Rough notification)
- 'S' (Sammelgut/Groupage - for New Dispo views)

## New Dispo Views - Current State

### V_DIS_TRANSPORTORDER

**File:** `Code/tms-alloydb-schema/src/sql/view/V_DIS_TRANSPORTORDER.sql`

**Current Status:**
- ✅ Includes `quell_k as origin` (line 78)
- ❌ Does NOT include OMS_ID
- ❌ Does NOT join to `sen_ref` table

**View Complexity:**
- Uses LATERAL joins for aggregation
- Calls multiple PTA package functions (e.g., `pta.getstatus()`, `pta.getbeladtor()`, etc.)
- Already has performance considerations due to function calls

**Required Change:**
Add OMS_ID to the view by joining to `sen_ref` table:
```sql
left join sen_ref sr on (sr.sen_tix = s1.sendung_tix and sr.typ = 'OMS_ID')
```

Then add to SELECT:
```sql
sr.ref::numeric(22) as oms_id
```

**Performance Considerations:**
1. **Index Check:** Verify `sen_ref` has index on `(sen_tix, typ)` for efficient lookup
2. **LEFT JOIN Impact:** Since not all shipments have OMS_ID, LEFT JOIN is necessary
3. **Function Chain:** Multiple existing function calls already affect performance; adding a simple LEFT JOIN should have minimal impact
4. **Alternative Approach:** Consider creating a function `pta.getOmsId(sendung_tix)` if direct join causes issues

### Other New Dispo Views to Check

- `v_dis_transportorder_filter.sql`
- `V_DIS_TRANSPORTORDER_PICKUPPLANNING.sql`
- `V_DIS_TRANSPORTORDER_FEATURES.sql`
- `V_DIS_TRANSPORTORDER_PRESETTEMP.sql`
- `V_DIS_TRANSPORTORDER_COUNT.sql`

## Database Schema

### SENDUNG Table
```sql
CREATE TABLE sendung (
    sendung_tix numeric(22,0) NOT NULL,
    ...
    quell_k character(1),  -- Line 160: Source key (single character)
    ...
);
```

### SEN_REF Table
```sql
CREATE TABLE sen_ref (
    sen_tix numeric(22,0) NOT NULL,
    typ character varying(16) NOT NULL,  -- Reference type (e.g., 'OMS_ID')
    ref character varying(144) NOT NULL, -- Reference value
    u_version character(1),
    c_time timestamp without time zone,
    c_user character(8),
    u_time timestamp without time zone,
    u_user character(8),
    art character(1)
);
```

## How OMS_ID is Retrieved - Reference Implementation

### V_ESB_SENDUNG View Pattern

**File:** `Code/tms-alloydb-schema/src/sql/view/V_ESB_SENDUNG.sql`

This view demonstrates the **established pattern** for retrieving OMS_ID:

```sql
create or replace view V_ESB_SENDUNG
as
  select s.SENDUNG_TIX     SEN_TIX,
         r.REF :: numeric(22) OMS_ID,  -- ⚠️ Key retrieval pattern
         s.VERKEHRSSTROM   VK_STROM
    from SENDUNG s
    left join SEN_REF r on (r.SEN_TIX = s.SENDUNG_TIX and r.TYP = 'OMS_ID')  -- ⚠️ Simple LEFT JOIN
   where s.SENDUNGSART in ('A','N','T')
     and (s.QUELL_K between 'a' and 'z' or s.QUELL_K = 'O');
```

**Key Points:**
- Simple LEFT JOIN to `sen_ref` table
- Filter on `typ = 'OMS_ID'`
- Cast `ref` to `numeric(22)` for type safety
- LEFT JOIN ensures non-OMS shipments return NULL

**Performance:**
- ✅ Direct table join (no function calls)
- ✅ Can leverage indexes on `sen_ref(sen_tix, typ)`
- ✅ Already used in production ESB integration

### Performance Analysis

**Index Requirements:**
```sql
-- Check if this index exists on sen_ref:
CREATE INDEX idx_sen_ref_sen_tix_typ ON sen_ref(sen_tix, typ);
```

**Impact Assessment:**
1. **Best Case:** Index exists → sub-millisecond lookup per row
2. **Worst Case:** No index → table scan, significant performance degradation
3. **Cardinality:** Not all shipments have OMS_ID → LEFT JOIN mandatory

**Recommendation:** Use the V_ESB_SENDUNG pattern (direct LEFT JOIN) rather than creating a function wrapper, as it:
- Allows query optimizer to use indexes effectively
- Avoids function call overhead
- Makes dependencies explicit in the query plan

## Implementation Checklist

- [ ] Verify index exists on `sen_ref(sen_tix, typ)`
- [ ] Add LEFT JOIN to `v_dis_transportorder`
- [ ] Add `oms_id` column to view SELECT
- [ ] Test query performance with EXPLAIN ANALYZE
- [ ] Check impact on other New Dispo views that may need OMS_ID
- [ ] Update New Dispo API/Backend to expose OMS_ID field
- [ ] Update New Dispo Frontend to display OMS_ID (if required)

## Related Files

### New Dispo Views (Primary Focus)
- `Code/tms-alloydb-schema/src/sql/view/V_DIS_TRANSPORTORDER.sql` - Main New Dispo view
- `Code/tms-alloydb-schema/src/sql/view/v_dis_transportorder_filter.sql`
- `Code/tms-alloydb-schema/src/sql/view/V_DIS_TRANSPORTORDER_PICKUPPLANNING.sql`
- `Code/tms-alloydb-schema/src/sql/view/V_DIS_TRANSPORTORDER_FEATURES.sql`

### Reference Implementation
- `Code/tms-alloydb-schema/src/sql/view/V_ESB_SENDUNG.sql` - Shows OMS_ID retrieval pattern

### Tables
- `Code/tms-alloydb-schema/src/sql/table/sendung.sql` - Main shipment table (quell_k)
- `Code/tms-alloydb-schema/src/sql/table/sen_ref.sql` - Shipment references table (OMS_ID storage)

## Next Steps

1. **Verify Index:** Check `sen_ref` table for index on `(sen_tix, typ)`
2. **Prototype:** Add OMS_ID to `v_dis_transportorder` and test performance
3. **Measure Impact:** Use EXPLAIN ANALYZE to compare before/after
4. **Decide Scope:** Determine which other New Dispo views need OMS_ID

---

## Background Context

### OMS Integration via ESB

OMS shipments are integrated with TMS and changes are synchronized back to OMS via ESB (Enterprise Service Bus).

**Trigger: TRAIU_SENDUNG_ESB**

**File:** `Code/tms-alloydb-schema/src/sql/trigger/TRAIU_SENDUNG_ESB.sql`

When traffic flow (`verkehrsstrom`) changes for OMS shipments (Quell_K between 'a'-'z' or 'O', Sendungsart 'A'/'N'/'T'), the trigger queues a message to notify OMS:

```sql
elsif new.SENDUNGSART in ('A','N','T')
  and new.VERKEHRSSTROM <> coalesce(old.VERKEHRSSTROM,new.VERKEHRSSTROM)
  and (new.QUELL_K between 'a' and 'z' or new.QUELL_K = 'O')
then
  call TMS2ESB.PutToEntityChangedQueue(...);
end if;
```

This integration context explains why OMS_ID is needed: to identify the correct shipment in OMS when reporting changes.

### Other ESB Views Using OMS_ID

- `V_ESB_FAKLSTG.sql`
- `V_ESB_SEN_HST.sql`
- `V_ESB_SEN_ON_LL.sql`
- `V_ESB_SEN_ON_RK.sql`

### Open Questions

1. **Quell_K Semantics:** What's the difference between lowercase (a-z) and uppercase 'O'?
   - Different source systems within OMS?
   - Different data entry methods?

2. **Complete Quell_K Mapping:**
   - '0' = TMS internal
   - 'D' = New Dispo
   - a-z, O = OMS
   - Others?

3. **SEN_REF Reference Types:** What other reference types exist besides 'OMS_ID'?

### Related User Stories

- DEMPM-332: Avis-Handling: Übernahme aus OMS - Task 167434
- PBI-145369: DEMPM-332: Rückübertragung des Verkehrsstroms an OMS
- User Story 103821: Sendung.Quell_K and Sen_Ref.Typ=OMS_ID (current)
