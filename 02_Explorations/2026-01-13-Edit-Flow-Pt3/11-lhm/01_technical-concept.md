# 11. Select LHM Option

## Storage

```sql
SELECT * FROM RES_HST_ZUS WHERE TYP = 262
```

## Technical Details

- Value is stored in field `T` with values "packed" using `CAL_UNIFACE.ITEM()`
- A hidden tour point always exists for each transport order
- Access methods:
  - **Write:** `reshst.setopt`
    - `key` = `NULL`
    - `typ` = constant `pTourOrt_Lib.ZUSTYP_TEMP()` (equals 262)
  - **Read:** `reshst.getopt`
- The tags within the `T` value (e.g., `tausch_k`) have no existing constants
  - Constants should be added to `pTourOrt_Lib`
  - This also applies to all Vehicle Properties ([Concept](https://dev.azure.com/p3ds/Nagel-CAL%20Disposition/_wiki/wikis/Nagel-CAL-Disposition.wiki/14725/3.-Vehicle-Properties-Body-Type))

### Example Value

```
"vorkuehl_b=Ttemplog_b=Tlkw_tran_temp=2lkw_vorkuehl_temp=klappe_lkw_tran_temp=2klappe_lkw_vorkuehl_temp=anh_tran_temp=anh_vorkuehl_temp=klappe_anh_tran_temp=klappe_anh_vorkuehl_temp=atp_koffer_b=Fatp_frc_b=Tatp_frb_b=Ftrennwand_b=Tdoppelstock_b=Twb_b=Fplane_b=Ftank_b=Ftausch_k=1"
```

### Values

| Value | German                                         | English                                      |
| ----- | ---------------------------------------------- | -------------------------------------------- |
| 0     | Kein Tausch                                    | No exchange                                  |
| 1     | Tausch 1:1 - wir akzeptieren keine DPL-Scheine | 1:1 exchange - we do not accept DPL vouchers |
| 2     | Kein Tausch, Original Palettenschein           | No exchange, original pallet voucher         |

Note: Values 0-2 are valid but not defined as constants in the database.
