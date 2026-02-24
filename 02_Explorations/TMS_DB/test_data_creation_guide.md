# Test Data Creation Guide for v_dis_transportorder

## Overview

This guide explains how to create test data for testing features that load data from `v_dis_transportorder`. The data must be created following specific business logic rules implemented in various functions, procedures, and views.

## Table Dependencies

### Core Tables Required

1. **SENDUNG** (Main Table)
   - Primary Key: `sendung_tix` (numeric(22,0) NOT NULL)
   - Key Fields:
     - `frankatur` (FK to FRANKATUR table)
     - `firma` (company number)
     - `sendung_tix` (unique identifier)
     - `niederlassung` (branch number)
     - `relation` (FK to RELATION table)

2. **RELATION**
   - Links to SENDUNG via `(firma, niederlassung, relation)`
   - Must have corresponding REGION entry

3. **REGION**
   - Required field: `verkehr_k = 'F'` for transport orders

4. **FRANKATUR**
   - Referenced by SENDUNG.frankatur field

5. **SEN_FRK_UNT**
   - Links contractors/vehicles to shipments
   - Required for complete transport order data

## Recommended Entry Points

### 1. Primary Method: ptavis.createsendung Function

**Location**: `/src/sql/package/PTAVIS.sql`

**Function Signature**:
```sql
CREATE OR REPLACE FUNCTION ptavis.createsendung(
    nrown numeric, 
    INOUT ssencsvstr character varying, 
    OUT swp_retvalue boolean
) RETURNS record
```

**Why Use This**:
- Handles all business logic validations
- Ensures data integrity
- Used by external systems (including OMS)
- Validates all master data relationships

**CSV Field Order** (semicolon-separated):
1. LEISTUNGSDATUM (service date)
2. FIRMA (company)
3. NIEDERLASSUNG (branch)
4. ABSEND_N/ABSEND_I (sender number/index)
5. STELLPLATZ_C (parking space)
6. ANZAHL_COLLI (number of packages)
7. GEWICHT (weight)
8. RELATION (relation/route)
9. VERKEHRSSTROM (traffic flow)
10. PROD_GRP (product group)
11. FIXTERMIN_DATUM/ZEIT (fixed appointment date/time)
12. ANKUNFT_SOLL_DATE/TIME (expected arrival date/time)
13. ENTL_REF (unloading reference)
14. EMPF_N/EMPF_I (recipient number/index)
15. PROD_K (product code)
16. FIX_VON_D/Z, FIX_BIS_D/Z (fixed time window)

### 2. Alternative Methods

**sen.put() Procedure**:
- Lower-level direct insert/update
- Requires manual validation
- Use only if you need specific control

**calnet_sen Package**:
- For network/distributed environments
- Cross-system synchronization

## Step-by-Step Test Data Creation

### Step 1: Prepare Master Data

```sql
-- 1. Create or verify FRANKATUR exists
INSERT INTO frankatur (frankaturschluesse, /* other fields */)
VALUES ('TST', /* test values */)
ON CONFLICT DO NOTHING;

-- 2. Create REGION with required verkehr_k = 'F'
INSERT INTO region (region, firma, niederlassung, verkehr_k, region_bez)
VALUES ('TST', 1, 1, 'F', 'Test Region')
ON CONFLICT DO NOTHING;

-- 3. Create RELATION linking to region
INSERT INTO relation (firmennummer, niederlassung, kz_relation, region)
VALUES (1, 1, 'TST', 'TST')
ON CONFLICT DO NOTHING;

-- 4. Ensure PERSON records exist for sender/receiver
-- (Check existing person records or create test persons)
```

### Step 2: Create Sendung Using ptavis.createsendung

```sql
DO $$
DECLARE
    v_csv_string VARCHAR;
    v_success BOOLEAN;
    v_result RECORD;
BEGIN
    -- Prepare CSV string with test data
    v_csv_string := 
        '2024-01-15;' ||           -- LEISTUNGSDATUM
        '001;' ||                  -- FIRMA
        '01;' ||                   -- NIEDERLASSUNG
        '1234567;' ||              -- ABSEND_N (sender number)
        '1;' ||                    -- ABSEND_I
        'A1;' ||                   -- STELLPLATZ_C
        '5;' ||                    -- ANZAHL_COLLI (packages)
        '100.5;' ||                -- GEWICHT (weight)
        'TST;' ||                  -- RELATION
        'NAH;' ||                  -- VERKEHRSSTROM
        'STD;' ||                  -- PROD_GRP
        '2024-01-16;' ||           -- FIXTERMIN_DATUM
        '14:00;' ||                -- FIXTERMIN_ZEIT
        '2024-01-16;' ||           -- ANKUNFT_SOLL_DATE
        '15:00;' ||                -- ANKUNFT_SOLL_TIME
        'REF001;' ||               -- ENTL_REF
        '7654321;' ||              -- EMPF_N (recipient number)
        '1;' ||                    -- EMPF_I
        'EXP;' ||                  -- PROD_K (product code)
        '2024-01-16;' ||           -- FIX_VON_D
        '13:00;' ||                -- FIX_VON_Z
        '2024-01-16;' ||           -- FIX_BIS_D
        '16:00';                   -- FIX_BIS_Z
    
    -- Call the function
    SELECT * INTO v_result 
    FROM ptavis.createsendung(1, v_csv_string);
    
    IF v_result.swp_retvalue THEN
        RAISE NOTICE 'Sendung created successfully';
    ELSE
        RAISE NOTICE 'Failed to create sendung: %', v_csv_string;
    END IF;
END $$;
```

### Step 3: Add Supporting Data

```sql
-- Add contractor/vehicle assignment if needed
INSERT INTO sen_frk_unt (sen_tix, lfd_n, unt_tix, /* other fields */)
SELECT sendung_tix, 1, 12345 /* contractor ID */
FROM sendung 
WHERE sendung_n = 1234567 -- your test sendung number
  AND firma = 1
  AND niederlassung = 1;
```

## OMS Integration Points

The system integrates with OMS through:

1. **TMS2ESB.AuftragZustandmeldung2OMS**: Sends status updates back to OMS
2. **ENTITYCHANGEDQUEUE**: Queue table for changes to be synchronized
3. **SEN_TS trigger**: Captures timestamp changes on sendung records

## Validation Checklist

Before running queries on `v_dis_transportorder`, ensure:

- [ ] FRANKATUR record exists
- [ ] RELATION record exists with valid firma/niederlassung
- [ ] REGION record exists with verkehr_k = 'F'
- [ ] SENDUNG record created with sendungsart = 'S' or 's'
- [ ] Person records exist for sender/receiver
- [ ] SEN_FRK_UNT record exists with lfd_n = 1 (if contractor data needed)

## Common Issues and Solutions

1. **Missing Person Records**: The ptavis.createsendung function validates that sender/receiver person records exist. Create these first or use existing test persons.

2. **Invalid Product Codes**: The function validates product codes against the PRODUKT table. Use existing valid codes or create test products.

3. **Date Format Issues**: Use European date format (DD.MM.YYYY) in the CSV string for ptavis.createsendung.

4. **Status Calculations**: The view uses complex status calculation functions (pta.getstatus). Ensure the PTA package is properly installed.

## Testing the Result

After creating test data, verify it appears in the view:

```sql
SELECT * 
FROM v_dis_transportorder 
WHERE sendung_tix = (
    SELECT sendung_tix 
    FROM sendung 
    WHERE sendung_n = 1234567 -- your test number
    LIMIT 1
);
```

## Additional Functions for Test Data

Other useful functions for creating specific types of test data:

- `sen.gennachlieferung()` - Generate subsequent deliveries
- `sen.genueberzaehligkeit()` - Generate excess/surplus records  
- `sen.genruecklieferung()` - Generate return deliveries
- `sen.genweiterleitung()` - Generate forwarding records

These can be used to create more complex test scenarios after the initial sendung is created.