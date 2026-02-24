# SENDUNG Table Deletion Methods

This document lists all methods (functions, procedures, triggers) that delete records from the SENDUNG table in the TMS AlloyDB schema.

## Primary Deletion Function

### 1. dfv_set.deletesendung(nSenTix numeric)
- **Type:** FUNCTION  
- **Schema:** dfv_set
- **File:** `src/sql/package/DFV_SET.sql:272`
- **Description:** Main deletion function for safely removing Avis-Sendungen (shipments with STATUS_8 = 'S', '2', or '3'). Handles related cleanup including Rollkarte and Bordero status updates, deactivates tracking records, and removes audit entries.

## Package-Level Deletion Methods

### 2. sen.delete_procedure
- **Type:** PROCEDURE (referenced in SEN package)
- **Schema:** sen
- **File:** `src/sql/package/SEN.sql:4296`
- **Description:** Direct deletion from SENDUNG table by SENDUNG_TIX

### 3. pla.delete_procedures
- **Type:** PROCEDURE 
- **Schema:** pla
- **File:** `src/sql/package/PLA.sql:1732, 1739`
- **Description:** Multiple deletion points for transport order cleanup

### 4. calnet_sen.delete_procedure
- **Type:** PROCEDURE
- **Schema:** calnet_sen  
- **File:** `src/sql/package/CALNET_SEN.sql:807`
- **Description:** CAL network shipment deletion

### 5. pwa.delete_procedures
- **Type:** PROCEDURE
- **Schema:** pwa
- **File:** `src/sql/package/PWA.sql:325`
- **Description:** Pickup and warehouse assignment deletion

### 6. paa.delete_procedures
- **Type:** PROCEDURE
- **Schema:** paa
- **File:** `src/sql/package/PAA.sql:565, 591`
- **Description:** Transport assignment deletion procedures

### 7. rorgsen.delete_procedures
- **Type:** PROCEDURE
- **Schema:** rorgsen
- **File:** `src/sql/package/RORGSEN.sql:382, 733, 1069`
- **Description:** Archive reorganization procedures that delete old shipments

### 8. pta.delete_procedures
- **Type:** PROCEDURE  
- **Schema:** pta
- **File:** `src/sql/package/PTA.sql:4754, 4771`
- **Description:** Transport order planning deletion procedures

### 9. disp_mde_eb.delete_procedures
- **Type:** PROCEDURE
- **Schema:** disp_mde_eb
- **File:** `src/sql/package/DISP_MDE_EB.sql:395, 397`
- **Description:** Mobile data entry deletion for dispatch processes

### 10. lst2zdb.deletedsen2dfv
- **Type:** PROCEDURE
- **Schema:** lst2zdb
- **File:** `src/sql/package/LST2ZDB.sql:152`
- **Description:** Transfer deleted shipments from TMS_AUDIT to DFV system

## Trigger Functions

### 11. sendung_d_trfunc()
- **Type:** TRIGGER FUNCTION
- **Schema:** public
- **File:** `src/sql/trigger/all_trigger_functions.sql:9551`
- **Description:** AFTER DELETE trigger that handles surplus shipment cleanup

### 12. trbd_sendung_trfunc()
- **Type:** TRIGGER FUNCTION  
- **Schema:** public
- **File:** `src/sql/trigger/all_trigger_events.sql:1220`
- **Description:** BEFORE DELETE trigger for shipments of types A, E, N, S

### 13. traud_sendung_audit_trfunc()
- **Type:** TRIGGER FUNCTION
- **Schema:** public  
- **File:** Various trigger function files
- **Description:** Audit trigger for DELETE operations on SENDUNG table

## Archive/Cleanup Procedures

### 14. rorg_client.archive_procedures
- **Type:** PROCEDURE
- **Schema:** rorg_client
- **File:** `src/sql/package/RORG_CLIENT.sql:536`
- **Description:** Archive procedures that delete old shipment data based on SENDUNG_D date

### 15. tmsdfvavis.checksenfordelete
- **Type:** FUNCTION
- **Schema:** tmsdfvavis
- **File:** `src/sql/package/TMSDFVAVIS.sql:257`
- **Description:** Validation function called from triggers to check if shipment can be deleted (avoids "mutating tables" error)

## Recommended Usage

For safe deletion of shipment records, use the primary deletion function:

```sql
SELECT dfv_set.deletesendung(your_sendung_tix);
```

This function ensures proper validation (only deletes Avis-Sendungen) and handles all related data cleanup automatically.

## Frontend Integration

### CAL_UNIFACE Package Analysis
The CAL_UNIFACE package serves as the main entry point for the UniFace frontend application but **does not contain any sendung deletion methods**. This package only provides utility functions for:

- **List manipulation:** Functions like `delitem()`, `getitem()`, `putitem()` for managing UniFace-style lists
- **String processing:** Functions for parsing, formatting, and manipulating strings 
- **Data conversion:** Functions for handling numeric values, dates, and data type conversions
- **Path operations:** Functions for working with path-like strings

For sendung deletion from the UniFace frontend, the application would call the database functions directly (like `dfv_set.deletesendung()`) through the application layer rather than through CAL_UNIFACE utility functions.

## Notes

- Most direct DELETE statements are embedded within larger procedures and should not be called directly
- The `dfv_set.deletesendung()` function is the safest and most comprehensive method for deleting shipments
- Trigger functions automatically handle cascading effects when deletions occur
- Archive procedures are typically used for bulk cleanup of old data during maintenance operations
- The CAL_UNIFACE package contains no sendung-specific business logic - it's purely a utility library