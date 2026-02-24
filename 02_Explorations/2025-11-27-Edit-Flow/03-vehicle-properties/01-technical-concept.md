# 2. Vehicle Properties & Body Type

| **User Stories**                                                                                                                               |
| ---------------------------------------------------------------------------------------------------------------------------------------------- |
| [119781: Edit Flow – 10. Changing Vehicle Properties and body type](https://dev.azure.com/p3ds/Nagel-CAL%20Disposition/_workitems/edit/119781) |

## Management Summary

This feature allows dispatchers to view and modify vehicle properties (body type, equipment features) on a Transport Order. The implementation uses the hidden tourpoint pattern where properties are stored as key-value pairs in `RES_HST_ZUS`.

**Key decisions:**
- Reading via new view `V_DIS_TRANSPORTORDER_VEHICLEPROPS` that parses the raw key-value data into structured columns
- Writing via new function `pDis_TransportOrder.SetVehicleProperties` that encapsulates the `pTA2` and `ResHst` logic
- Body types and vehicle properties are stored as boolean flags in `ZUSTYP_TEMP` (262)
- All values use the existing `ResHst.SetZus` UPSERT pattern

> **Note:** Vehicle properties are stored in the "hidden tourpoint" (`RES_HST` with `typ = TYP_STOP`) of each Transport Order. All values are stored as key-value pairs in `RES_HST_ZUS.T` field.

> **Note:** The exact tech-stack implementation is to be decided during implementation, e.g. what logic will be in Backend, TMS Bridge, and TMS Database.

## 1. Read Vehicle Properties

Vehicle properties are read via the `V_DIS_TRANSPORTORDER_VEHICLEPROPS` view, which internally queries `RES_HST_ZUS` via the hidden tourpoint.

:::mermaid
sequenceDiagram
    participant FE as Frontend
    participant BE as Backend
    participant Bridge as TMS Bridge
    participant TMS as TMS Database (V_DIS_TRANSPORTORDER_VEHICLEPROPS)

    FE->>BE: getVehicleProperties(transportOrderId)
    BE->>Bridge: getVehicleProperties(transportOrderId)
    Bridge->>TMS: SELECT * FROM V_DIS_TRANSPORTORDER_VEHICLEPROPS WHERE transportorderid = ?
    activate TMS

    Note over TMS: View queries hidden tourpoint (RES_HST)
    Note over TMS: View queries body types and vehicle properties (RES_HST_ZUS typ=262)

    TMS-->>Bridge: body types, precooling_required, temp_recorder_required, partition_wall, double_deck
    deactivate TMS
    Bridge-->>BE: VehiclePropertiesDTO
    BE-->>FE: VehiclePropertiesDTO
:::

### Reading Properties - Steps

1. Query `V_DIS_TRANSPORTORDER_VEHICLEPROPS` with the Transport Order ID
2. The view internally:
   - Gets the hidden tourpoint via `RES_HST` (typ = TYP_STOP)
   - Reads all properties via `ResHst.GetZus(nTix, ZUSTYP_TEMP)` - returns a single string containing body types and vehicle properties as boolean flags
   - Parses the key-value pairs using `cal_uniface.item(key, value)` to extract individual fields
3. Return the structured `VehiclePropertiesDTO` to the UI

### New View: V_DIS_TRANSPORTORDER_VEHICLEPROPS (Draft)

A new view is required to expose vehicle properties for the Edit Flow. All body types and vehicle properties are stored together in `RES_HST_ZUS` with `typ = 262` (ZUSTYP_TEMP) as boolean flags.

#### View Definition

```sql
--
-- Name: v_dis_transportorder_vehicleprops; Type: VIEW; Schema: tms1034; Owner: -
--

CREATE OR REPLACE VIEW v_dis_transportorder_vehicleprops AS
WITH props AS (
    SELECT
        h.ref_tix AS ta_tix,
        reshst.getzus(h.res_hst_tix, ptourort_lib.zustyp_temp()) AS properties_raw
    FROM res_hst h
    WHERE h.typ = ptourort_lib.typ_stop()  -- Hidden start point (typ = 4)
      AND h.art = ptourort_lib.art_res1()  -- art = 101
)
SELECT
    p.ta_tix AS transportorderid,

    -- Body Types
    cal_uniface.item('atp_frc_b', p.properties_raw) AS atp_frc,
    cal_uniface.item('atp_frb_b', p.properties_raw) AS atp_frb,
    cal_uniface.item('atp_koffer_b', p.properties_raw) AS atp_box,
    cal_uniface.item('wb_b', p.properties_raw) AS swap_body,
    cal_uniface.item('plane_b', p.properties_raw) AS tarpaulin,
    cal_uniface.item('tank_b', p.properties_raw) AS tank_silo,

    -- Vehicle Properties
    cal_uniface.item('vorkuehl_b', p.properties_raw) AS precooling_required,
    cal_uniface.item('tempschreiber_b', p.properties_raw) AS temp_recorder_required,
    cal_uniface.item('trennwand_b', p.properties_raw) AS partition_wall,
    cal_uniface.item('doppelstock_b', p.properties_raw) AS double_deck

FROM props p;
```

#### View Columns

| Column                       | Type    | Description                      |
| ---------------------------- | ------- | -------------------------------- |
| `transportorderid`           | numeric | Transport Order TIX (PK)         |
| **Body Types**               |         |                                  |
| `atp_frc`                    | varchar | ATP refrigerated FRC -20°C (T/F/1/0)   |
| `atp_frb`                    | varchar | ATP refrigerated FRB -10°C (T/F/1/0)   |
| `atp_box`                    | varchar | ATP certified box body (T/F/1/0)       |
| `swap_body`                  | varchar | Swap body (T/F/1/0)                    |
| `tarpaulin`                  | varchar | Tarpaulin (T/F/1/0)                    |
| `tank_silo`                  | varchar | Tank / Silo (T/F/1/0)                  |
| **Vehicle Properties**       |         |                                        |
| `precooling_required`        | varchar | Pre-cooling required (T/F/1/0)         |
| `temp_recorder_required`     | varchar | Temp recorder required (T/F/1/0)       |
| `partition_wall`             | varchar | Partition wall (T/F/1/0)               |
| `double_deck`                | varchar | Double deck (T/F/1/0)                  |

#### View Usage Example

```sql
-- Get vehicle properties for a specific Transport Order
SELECT *
FROM v_dis_transportorder_vehicleprops
WHERE transportorderid = 12345;

-- Get all Transport Orders requiring pre-cooling
SELECT transportorderid, atp_frc, precooling_required
FROM v_dis_transportorder_vehicleprops
WHERE precooling_required = 'T';
```

## 2. Store Vehicle Properties

:::mermaid
sequenceDiagram
    participant FE as Frontend
    participant BE as Backend
    participant Bridge as TMS Bridge
    participant TMS as TMS Database (pDis_TransportOrder.SetVehicleProperties)

    FE->>BE: setVehicleProperties(transportOrderId, bodyTypes, vehicleProps)
    BE->>Bridge: setVehicleProperties(transportOrderId, bodyTypes, vehicleProps)
    Bridge->>TMS: pDis_TransportOrder.SetVehicleProperties(nTaTix, ...)
    activate TMS

    Note over TMS: Get hidden tourpoint via pTA2.getStartOrt(nTaTix)

    Note over TMS: ResHst.SetZus(nResHstTix, ZUSTYP_TEMP, sProperties)

    TMS-->>Bridge: success
    deactivate TMS
    Bridge-->>BE: success
    BE-->>FE: success
:::

### Storing Properties - Steps

1. Frontend sends vehicle properties to Backend
2. Backend calls TMS Bridge `setVehicleProperties(transportOrderId, ...)`
3. TMS Bridge calls `pDis_TransportOrder.SetVehicleProperties(nTaTix, ...)`
4. The function internally:
   - Gets the hidden tourpoint TIX via `pTA2.getStartOrt(nTaTix)`
   - Reads existing properties to preserve unchanged values
   - Builds the key=value string with updated values
   - Calls `ResHst.SetZus(nResHstTix, ZUSTYP_TEMP, sValue)`
5. Return success/error response through the chain

> **Note:** `ResHst.SetZus` handles both INSERT and UPDATE automatically (UPSERT pattern).

### New Function: pDis_TransportOrder.SetVehicleProperties (Draft)

The function provides a clean interface with English parameter names matching the view columns. Internally it converts to the uniface storage format.

```sql
CREATE OR REPLACE FUNCTION pdis_transportorder.setvehicleproperties(
    p_ta_tix                     numeric,
    -- Body Types
    p_atp_frc                    boolean DEFAULT NULL,
    p_atp_frb                    boolean DEFAULT NULL,
    p_atp_box                    boolean DEFAULT NULL,
    p_swap_body                  boolean DEFAULT NULL,
    p_tarpaulin                  boolean DEFAULT NULL,
    p_tank_silo                  boolean DEFAULT NULL,
    -- Vehicle Properties
    p_precooling_required        boolean DEFAULT NULL,
    p_temp_recorder_required     boolean DEFAULT NULL,
    p_partition_wall             boolean DEFAULT NULL,
    p_double_deck                boolean DEFAULT NULL
) RETURNS void AS $$
DECLARE
    v_res_hst_tix    numeric;
    v_current        varchar;
    v_properties     varchar;
BEGIN
    -- Get hidden tourpoint TIX for the Transport Order
    v_res_hst_tix := pta2.getstartort(p_ta_tix);

    IF v_res_hst_tix IS NULL THEN
        RAISE EXCEPTION 'Hidden tourpoint not found for Transport Order %', p_ta_tix;
    END IF;

    -- Read current properties (to preserve values not being updated)
    v_current := reshst.getzus(v_res_hst_tix, ptourort_lib.zustyp_temp());

    -- Helper function to get current or new value for booleans
    -- NULL param = keep existing, TRUE/FALSE = set new value
    v_properties := concat_ws(' ',
        -- Body Types (only include if param is not NULL, otherwise keep existing)
        'atp_frc_b=' || CASE
            WHEN p_atp_frc IS NOT NULL THEN CASE WHEN p_atp_frc THEN 'T' ELSE 'F' END
            ELSE coalesce(cal_uniface.item('atp_frc_b', v_current), 'F') END,
        'atp_frb_b=' || CASE
            WHEN p_atp_frb IS NOT NULL THEN CASE WHEN p_atp_frb THEN 'T' ELSE 'F' END
            ELSE coalesce(cal_uniface.item('atp_frb_b', v_current), 'F') END,
        'atp_koffer_b=' || CASE
            WHEN p_atp_box IS NOT NULL THEN CASE WHEN p_atp_box THEN 'T' ELSE 'F' END
            ELSE coalesce(cal_uniface.item('atp_koffer_b', v_current), 'F') END,
        'wb_b=' || CASE
            WHEN p_swap_body IS NOT NULL THEN CASE WHEN p_swap_body THEN 'T' ELSE 'F' END
            ELSE coalesce(cal_uniface.item('wb_b', v_current), 'F') END,
        'plane_b=' || CASE
            WHEN p_tarpaulin IS NOT NULL THEN CASE WHEN p_tarpaulin THEN 'T' ELSE 'F' END
            ELSE coalesce(cal_uniface.item('plane_b', v_current), 'F') END,
        'tank_b=' || CASE
            WHEN p_tank_silo IS NOT NULL THEN CASE WHEN p_tank_silo THEN 'T' ELSE 'F' END
            ELSE coalesce(cal_uniface.item('tank_b', v_current), 'F') END,
        -- Vehicle Properties
        'vorkuehl_b=' || CASE
            WHEN p_precooling_required IS NOT NULL THEN CASE WHEN p_precooling_required THEN 'T' ELSE 'F' END
            ELSE coalesce(cal_uniface.item('vorkuehl_b', v_current), 'F') END,
        'tempschreiber_b=' || CASE
            WHEN p_temp_recorder_required IS NOT NULL THEN CASE WHEN p_temp_recorder_required THEN 'T' ELSE 'F' END
            ELSE coalesce(cal_uniface.item('tempschreiber_b', v_current), 'F') END,
        'trennwand_b=' || CASE
            WHEN p_partition_wall IS NOT NULL THEN CASE WHEN p_partition_wall THEN 'T' ELSE 'F' END
            ELSE coalesce(cal_uniface.item('trennwand_b', v_current), 'F') END,
        'doppelstock_b=' || CASE
            WHEN p_double_deck IS NOT NULL THEN CASE WHEN p_double_deck THEN 'T' ELSE 'F' END
            ELSE coalesce(cal_uniface.item('doppelstock_b', v_current), 'F') END
    );

    -- Set all properties in ZUSTYP_TEMP (262)
    PERFORM reshst.setzus(v_res_hst_tix, ptourort_lib.zustyp_temp(), v_properties);
END;
$$ LANGUAGE plpgsql;
```

> **Note:** Parameters with `NULL` value preserve the existing value in the database. Pass `true`/`false` explicitly to change a boolean value.

#### Function Parameters

| Parameter                      | Type    | Description                       |
| ------------------------------ | ------- | --------------------------------- |
| `p_ta_tix`                     | numeric | Transport Order TIX (required)    |
| **Body Types**                 |         |                                   |
| `p_atp_frc`                    | boolean | ATP refrigerated FRC -20°C        |
| `p_atp_frb`                    | boolean | ATP refrigerated FRB -10°C        |
| `p_atp_box`                    | boolean | ATP certified box body            |
| `p_swap_body`                  | boolean | Swap body                         |
| `p_tarpaulin`                  | boolean | Tarpaulin                         |
| `p_tank_silo`                  | boolean | Tank / Silo                       |
| **Vehicle Properties**         |         |                                   |
| `p_precooling_required`        | boolean | Pre-cooling required              |
| `p_temp_recorder_required`     | boolean | Temperature recorder required     |
| `p_partition_wall`             | boolean | Partition wall                    |
| `p_double_deck`                | boolean | Double deck loading               |

#### Usage Examples

**Set all properties (full update):**

```sql
SELECT pdis_transportorder.setvehicleproperties(
    p_ta_tix := 12345,
    -- Body Types
    p_atp_frc := true,
    p_atp_frb := false,
    p_atp_box := false,
    p_swap_body := true,
    p_tarpaulin := false,
    p_tank_silo := false,
    -- Vehicle Properties
    p_precooling_required := true,
    p_temp_recorder_required := true,
    p_partition_wall := false,
    p_double_deck := true
);
```

**Partial update (only change specific values, keep others unchanged):**

```sql
-- Only update double_deck and swap_body, keep all other values
SELECT pdis_transportorder.setvehicleproperties(
    p_ta_tix := 12345,
    p_double_deck := false,
    p_swap_body := true
);
```

## Data Model

:::mermaid
erDiagram
    TA ||--|| RES_HST : "has hidden tourpoint"
    RES_HST ||--o{ RES_HST_ZUS : "has properties"

    TA {
        numeric ta_tix PK
    }

    RES_HST {
        numeric res_hst_tix PK
        numeric ref_tix FK "TA.ta_tix"
        numeric typ "4 = TYP_STOP (hidden)"
        numeric art "101 = ART_RES1"
    }

    RES_HST_ZUS {
        numeric res_hst_tix PK,FK
        numeric lfd_n PK
        numeric typ "262 = ZUSTYP_TEMP"
        varchar t "key=value pairs (max 2000 chars)"
    }
:::

## Property Storage in RES_HST_ZUS

### Body Types & Vehicle Properties

All vehicle properties are stored together in `RES_HST_ZUS` with `typ = 262` (ZUSTYP_TEMP). Values are stored as key=value pairs in the `T` field, concatenated with delimiters.

> **Note:** The `LKWTYP` table contains vehicle weight/size profiles (PKW, 3.49t, 7.49t, 40t), not body types. Body types are stored as boolean flags in ZUSTYP_TEMP.

> **Note:** The field keys below (e.g., `atp_frc_b`, `wb_b`) are string literals, not function constants. Use them directly as strings when parsing the T field.

#### Body Types

| UI Label (DE)         | View/API Column | Internal Key   | Example Value    |
| --------------------- | --------------- | -------------- | ---------------- |
| ATP-Kühlung FRC -20°C | `atp_frc`       | `atp_frc_b`    | `atp_frc_b=T`    |
| ATP-Kühlung FRB -10°C | `atp_frb`       | `atp_frb_b`    | `atp_frb_b=T`    |
| ATP-Koffer            | `atp_box`       | `atp_koffer_b` | `atp_koffer_b=T` |
| Wechselbrücke         | `swap_body`     | `wb_b`         | `wb_b=T`         |
| Plane                 | `tarpaulin`     | `plane_b`      | `plane_b=T`      |
| Tank / Silo           | `tank_silo`     | `tank_b`       | `tank_b=T`       |

#### Vehicle Properties

| UI Label (DE)                    | View/API Column         | Internal Key      | Example Value       |
| -------------------------------- | ----------------------- | ----------------- | ------------------- |
| Temperaturschreiber erforderlich | `temp_recorder_required`| `tempschreiber_b` | `tempschreiber_b=T` |
| Vorkühlung                       | `precooling_required`   | `vorkuehl_b`      | `vorkuehl_b=T`      |
| Trennwand                        | `partition_wall`        | `trennwand_b`     | `trennwand_b=T`     |
| Doppelstock                      | `double_deck`           | `doppelstock_b`   | `doppelstock_b=T`   |

#### Example T Field Value

```
vorkuehl_b=T doppelstock_b=T trennwand_b=0 atp_frc_b=T atp_frb_b=1 wb_b=T plane_b=F tank_b=F tempschreiber_b=T atp_koffer_b=F
```

## Existing TMS Functions

### Reading

| Function                          | Description                                  |
| --------------------------------- | -------------------------------------------- |
| `pTA2.getStartOrt(nTaTix)`        | Get hidden tourpoint TIX for Transport Order |
| `ResHst.GetOpt(nTix, sKey)`       | Get option value from RES_HST_ZUS            |
| `ResHst.GetZus(nTix, nTyp)`       | Get additional value by type                 |
| `ResHst.GetZus(nTix, nTyp, sKey)` | Get additional value by type and key         |

### Writing

| Procedure                           | Description                          |
| ----------------------------------- | ------------------------------------ |
| `ResHst.SetOpt(nTix, sKey, sValue)` | Set/update option (UPSERT)           |
| `ResHst.SetZus(nTix, nTyp, sValue)` | Set/update additional value (UPSERT) |
| `ResHst.SetZus(rResHstZus)`         | Set/update using record type         |

## Constants (pTourOrt_Lib)

```sql
-- Property Types (res_hst_zus.typ)
ZUSTYP_TEMP()    = 262  -- Temperature settings, body types, and vehicle properties
                       -- Note: key column is always NULL, all values stored in T field

-- Tourpoint Types (res_hst.typ)
TYP_STOP() = 4  -- Hidden start point
```

## Validation Rules

1. **Body Type:**
   - At least one body type can remain unchecked (no mandatory requirement)
   - Only predefined body types allowed (no free-text)
   - Multiple selections possible

2. **Vehicle Properties:**
   - `Vorkühlung` cannot be unchecked (always required)
   - No interdependency logic between properties
   - Each property maps to a boolean value

## Error Handling

| Error Case                    | Action                             |
| ----------------------------- | ---------------------------------- |
| Invalid Transport Order TIX   | Return error, no changes           |
| Hidden tourpoint not found    | Return error, no changes           |
| Database constraint violation | Rollback transaction, return error |
| Value exceeds field length    | Truncate or return error           |
