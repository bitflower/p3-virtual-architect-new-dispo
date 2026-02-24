# Test Data Usage Instructions

## Sample CSV File: test_sendung_data.csv

This file contains sample data for creating test sendung (shipment) records using the `ptavis.createsendung` function.

## CSV Structure

The CSV file uses semicolon (`;`) as the delimiter and contains the following fields in order:

1. **LEISTUNGSDATUM** - Service date (format: DD.MM.YYYY)
2. **FIRMA** - Company code (3 digits)
3. **NIEDERLASSUNG** - Branch code (2 digits)
4. **ABSEND_N** - Sender number (7 digits)
5. **ABSEND_I** - Sender index
6. **STELLPLATZ_C** - Parking space/dock
7. **ANZAHL_COLLI** - Number of packages
8. **GEWICHT** - Weight in kg
9. **RELATION** - Relation/route code (3 characters)
10. **VERKEHRSSTROM** - Traffic flow (NAH=local, FRN=long-distance)
11. **PROD_GRP** - Product group (STD=standard, EXP=express, PRI=priority)
12. **FIXTERMIN_DATUM** - Fixed appointment date
13. **FIXTERMIN_ZEIT** - Fixed appointment time
14. **ANKUNFT_SOLL_DATE** - Expected arrival date
15. **ANKUNFT_SOLL_TIME** - Expected arrival time
16. **ENTL_REF** - Unloading reference
17. **EMPF_N** - Recipient number (7 digits)
18. **EMPF_I** - Recipient index
19. **PROD_K** - Product code
20. **FIX_VON_D** - Fixed time window start date
21. **FIX_VON_Z** - Fixed time window start time
22. **FIX_BIS_D** - Fixed time window end date
23. **FIX_BIS_Z** - Fixed time window end time

## Sample Data Overview

The file contains 5 test shipments with varying characteristics:

1. **Row 1**: Standard local shipment with 5 packages, 100.5kg
2. **Row 2**: Standard local shipment with 10 packages, 250kg
3. **Row 3**: Express long-distance shipment with 3 packages, 50.75kg
4. **Row 4**: Standard local shipment with 8 packages, 175.25kg
5. **Row 5**: Priority long-distance shipment with 15 packages, 500kg

## How to Use

### Option 1: Process Each Row Individually

```sql
DO $$
DECLARE
    v_csv_line VARCHAR;
    v_success BOOLEAN;
    v_result RECORD;
    v_row_num INTEGER := 0;
BEGIN
    -- Example: Process the first data row (skip header)
    v_csv_line := '15.01.2024;001;01;1234567;1;A1;5;100.5;TST;NAH;STD;16.01.2024;14:00;16.01.2024;15:00;REF001;7654321;1;EXP;16.01.2024;13:00;16.01.2024;16:00';
    
    v_row_num := v_row_num + 1;
    
    SELECT * INTO v_result 
    FROM ptavis.createsendung(v_row_num, v_csv_line);
    
    IF v_result.swp_retvalue THEN
        RAISE NOTICE 'Row % processed successfully', v_row_num;
    ELSE
        RAISE NOTICE 'Row % failed: %', v_row_num, v_csv_line;
    END IF;
END $$;
```

### Option 2: Use TAVIS File Import Process

The ptavis package is designed to read CSV files from a configured directory. To use the full import process:

1. Place the CSV file in the TAVIS import directory
2. Call the file processing function:
   ```sql
   SELECT ptavis.readfiles();
   ```

## Prerequisites

Before importing the test data, ensure:

1. **Master Data Exists**:
   - Person records for senders (1234567-1234571) and recipients (7654321-7654325)
   - Relation 'TST' with proper region setup
   - Product codes (STD, EXP, PRI) in the product table
   - Frankatur codes as referenced

2. **Required Tables Are Set Up**:
   - SENDUNG table
   - RELATION table with verkehr_k = 'F'
   - REGION table
   - FRANKATUR table
   - PERSON/PERS tables for sender/recipient data

## Validation

After import, verify the data:

```sql
-- Check imported shipments
SELECT sendung_tix, sendung_n, leistungsdatum, gewicht, anzahl_colli
FROM sendung
WHERE sendung_n IN (1234567, 1234568, 1234569, 1234570, 1234571)
ORDER BY sendung_n;

-- Verify in transport order view
SELECT *
FROM v_dis_transportorder
WHERE sendung_n IN (1234567, 1234568, 1234569, 1234570, 1234571);
```

## Notes

- Dates use European format (DD.MM.YYYY)
- Times use 24-hour format (HH:MM)
- The VERKEHRSSTROM field typically uses:
  - NAH = Local/regional transport
  - FRN = Long-distance transport
- Product groups (PROD_GRP) typically include:
  - STD = Standard delivery
  - EXP = Express delivery
  - PRI = Priority delivery

## Troubleshooting

If imports fail, check:

1. Person records exist for all sender/recipient numbers
2. Relation 'TST' exists in the RELATION table
3. Date formats are correct (DD.MM.YYYY)
4. Numeric fields don't contain invalid characters
5. Required product codes exist in the PRODUKT table