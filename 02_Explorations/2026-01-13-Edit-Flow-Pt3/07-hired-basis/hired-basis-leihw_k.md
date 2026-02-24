# "Received on a Hired Basis" - Technical Documentation

## Overview

The "received on a hired basis" (German: "leihweise") property for transport orders is stored in the `sen_frk_unt` table, NOT in `sen_zus` or `res_hst_zus`.

## Database Location

**Table:** `sen_frk_unt` (Sendung-Frachtkarten-Unternehmer / shipment-freight-contractor)

**Primary Key:** `sen_tix` + `lfd_n`

## Fields

| Field            | Type           | Description                                                     |
| ---------------- | -------------- | --------------------------------------------------------------- |
| `anh_leihw_k`    | `numeric(1,0)` | Trailer hired (Anhänger/Auflieger leihweise) - see values below |
| `anh_wb_leihw_k` | `numeric(1,0)` | Trailer swap body hired (Anhänger Wechselbrücke leihweise)      |
| `con_leihw_k`    | `numeric(1,0)` | Container hired (Container leihweise)                           |

### Values for `anh_leihw_k`

This field uses a bitmask to represent multiple options:

| Value | Meaning                                   |
| ----- | ----------------------------------------- |
| `0`   | Not hired (own)                           |
| `1`   | Auflieger (semi-trailer) hired            |
| `2`   | Anhänger (trailer) hired                  |
| `3`   | Both Auflieger and Anhänger hired (1 + 2) |

### Values for other fields

For `anh_wb_leihw_k`, `con_leihw_k`:

- `0` = not hired (own)
- `1` = hired

## Related Tables

The same fields exist in:
- `frk_unt` - Freight card contractor
- `dfv_frk_unt` - DFV freight card contractor
- `dfv_sen_unt` - DFV shipment contractor

## Reading These Fields

### View for Reading (with bitmask resolved)

A view should be created to read the 4 hired values as boolean flags (numeric 1/0), resolving the bitmask in `anh_leihw_k` into separate columns:

```sql
CREATE OR REPLACE VIEW v_dis_transportorder_hired AS
SELECT
    sen_tix,
    lfd_n,
    -- Resolve anh_leihw_k bitmask into separate flags
    CASE WHEN (anh_leihw_k & 1) = 1 THEN 1 ELSE 0 END AS semitrailer_hired,      -- Bit 1: Auflieger
    CASE WHEN (anh_leihw_k & 2) = 2 THEN 1 ELSE 0 END AS trailer_hired,          -- Bit 2: Anhänger
    -- Other fields as-is
    COALESCE(anh_wb_leihw_k, 0) AS trailer_swapbody_hired,
    COALESCE(con_leihw_k, 0) AS container_hired
FROM sen_frk_unt;
```

This resolves:

- `anh_leihw_k = 1` → `semitrailer_hired = 1`, `trailer_hired = 0`
- `anh_leihw_k = 2` → `semitrailer_hired = 0`, `trailer_hired = 1`
- `anh_leihw_k = 3` → `semitrailer_hired = 1`, `trailer_hired = 1`

## Writing to These Fields

### Direct UPDATE (Recommended)

There is **no dedicated setter function** for these fields. They can be written directly:

```sql
UPDATE sen_frk_unt
SET anh_leihw_k = <value>,
    anh_wb_leihw_k = <value>,
    con_leihw_k = <value>,
    u_version = cal_util.getuversion(u_version),
    u_time = pta.gete(),
    u_user = 'TMS'
WHERE sen_tix = <transport_order_tix>;
```

**Important:**

- `u_version` must be updated using `cal_util.getuversion(u_version)` to avoid conflicts with Uniface. This increments the version character and ensures proper synchronization.
- `u_time` must always be set on UPDATE (changed date) using `pta.gete()` which returns the session timestamp or current timestamp.
- `c_time` is the created date and should only be set on INSERT, never on UPDATE.

### Triggers

The following triggers exist on `sen_frk_unt` but do NOT affect the `leihw_k` fields:

| Trigger                   | Event                | Purpose                                       |
| ------------------------- | -------------------- | --------------------------------------------- |
| `trbiu_sen_frk_unt_crypt` | BEFORE INSERT/UPDATE | Encrypts `FAHRER_NAME` and `BEIFAH_NAME` only |
| `trad_sen_frk_unt`        | AFTER DELETE         | Cleans up `FRK_UNT_ZUS` records               |
| `trad_sen_frk_unt_audit`  | AFTER DELETE         | Audit logging                                 |

## Usage in Codebase

The fields are written:
- Via direct INSERT in `PTA.sql` when creating `sen_frk_unt` records (line 4472-4477)
- Via DFV/UDB transfer mechanisms (`UDB_SENUNT.sql`, `UDB_FRKUNT.sql`)

---

## General Note: u_version Handling

**Important:** The `u_version` field must be handled correctly everywhere it is present in the database schema. When updating any table that contains a `u_version` column, always use `cal_util.getuversion(u_version)` to increment the version. Failing to do so will cause synchronization conflicts with Uniface.
