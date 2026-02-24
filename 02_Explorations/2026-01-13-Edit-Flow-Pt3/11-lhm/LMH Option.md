# LMH Option

Austausch mit joachim.

## Speicherort

```sql
SELECT * FROM RES_HST_ZUS WHERE TYP = 262
```

## Details

- In Feld `T` sehen im verstecvkten Tourpunkt die Werte mit `CAL_UNIFACE.ITEM()` "verpackt
- Versteckter Tourpoint ist immer da für jeden Transport order
- Zugriffsmethoden
  - `reshst.setopt`
    - `key` = `NULL`
    - `typ` = Konstante (welche 262 entspricht) `pTourOrt_Lib.ZUSTYP_TEMP()`
  - `reshst.getopt` zum lesen
  - Für die "Tags" innerhalb des Wertes `T` gibt es keine Konstanten
    - Also `tausch_k`
    - Gibt es nur in UniFace
    - Lösung: Einführen von Konstanten
    - Ziel-Datei: `pTourOrt_Lib`
    - Alle Tags aufnehmen
    - Betrifft auch alle Vehicle Properties
      - [Konzept](https://dev.azure.com/p3ds/Nagel-CAL%20Disposition/_wiki/wikis/Nagel-CAL-Disposition.wiki/14725/3.-Vehicle-Properties-Body-Type)
- Werte 0-2 sind in Ordnung, aber nicht in der DB vorhanden als Konstanten o.ä.

## Beispiel

`"vorkuehl_b=Ttemplog_b=Tlkw_tran_temp=2lkw_vorkuehl_temp=klappe_lkw_tran_temp=2klappe_lkw_vorkuehl_temp=anh_tran_temp=anh_vorkuehl_temp=klappe_anh_tran_temp=klappe_anh_vorkuehl_temp=atp_koffer_b=Fatp_frc_b=Tatp_frb_b=Ftrennwand_b=Tdoppelstock_b=Twb_b=Fplane_b=Ftank_b=Ftausch_k=1"`

