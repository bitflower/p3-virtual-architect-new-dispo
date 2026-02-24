**PBI**: #119750
**WHO**: As a user, I want to select a loading aids (LHM) option so that the correct configuration is stored in the TMS.

**Description**: Allows users to choose one of three predefined **loading aids (LHM)** options from a dropdown menu on the Transport Order. Once a selection is made, the chosen value is saved directly to the TMS. The selection determines how pallet exchanges or vouchers are handled for that Transport Order.

**Actors**: User (dispatcher).

**Triggers**:
*   User opens the LHM dropdown and selects one of the available options.
    
**Preconditions**:
*   A valid Transport Order is open and editable.
    
**Postconditions**:
*   The selected LHM option is saved to the Transport Order in TMS.

**Technical Solution:**

Procedure in `pDIS_TransportOrder`, following the `SetVehicleAttributes` pattern:

```sql
-- Set LHM (Loading Aids) option on Transport Order
-- TO BE ADDED
create or replace procedure pDIS_TransportOrder.SetLoadingAidsOption(
    TransportOrderId   numeric,
    LoadingAidsOption  numeric  -- 0, 1, or 2 (NULL = keep existing)
)
-- Pattern: Resolve start tourpoint → get properties → update → save
-- Storage: RES_HST_ZUS.T where TYP = 262 (ZUSTYP_TEMP)
-- Uses: pta2.getStartOrt, reshst.getzus/setzus, CAL_Uniface.PutItem
```

#### Implementation Pattern (from `SetVehicleAttributes`)

```sql
nStartOrtTix := pta2.getStartOrt(TransportOrderId);
sProperties  := reshst.getzus(nStartOrtTix, pTourOrt_Lib.ZUSTYP_TEMP());

if (LoadingAidsOption is not null) then
    call CAL_Uniface.PutItem(sProperties, pTourOrt_Lib.ZUSID_TAUSCH_K(), LoadingAidsOption::varchar);
end if;

call reshst.setzus(nStartOrtTix, pTourOrt_Lib.ZUSTYP_TEMP(), sProperties);
```

#### New Constant Required

Add to `pTourOrt_Lib`:

```sql
ZUSID_TAUSCH_K() returns 'tausch_k'  -- LHM exchange option key
```

#### LHM Values

| Value | German                                         | English                                      |
| ----- | ---------------------------------------------- | -------------------------------------------- |
| `0`   | Kein Tausch                                    | No exchange                                  |
| `1`   | Tausch 1:1 - wir akzeptieren keine DPL-Scheine | 1:1 exchange - we do not accept DPL vouchers |
| `2`   | Kein Tausch, Original Palettenschein           | No exchange, original pallet voucher         |

#### Storage Details

* **Table:** `RES_HST_ZUS` where `TYP = 262`
* **Field:** `T` (packed key-value string via `CAL_UNIFACE.ITEM()`)
* **Tag:** `tausch_k`

**Constraints:**

The business requirements have been aligned with **Maximilian Beisheim**.
The technical solution design has been aligned with **Joachim Schreiner**.
All code is developed by P3.
