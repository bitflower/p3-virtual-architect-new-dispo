# 2026-01-27

## Flag für Transportaufträge, die von New Dispo erstellt wurden

Es wurde eine holistische Lösung eingeführt, die Transport order "markiert" in dem es das Feld `Quell_K` auf `'D'` setzt. Was bedeutete, dass der Datensatz von New Dispo geschrieben wurde.

GitHub:
- https://github.com/cal-consult/tms-alloydb-schema/pull/473/files
  - `v_dis_transportorder` now returns: `s1.quell_k as origin`, `v_ta` returns `s1.Quell_K as Quell_K`
- https://github.com/cal-consult/tms-alloydb-schema/pull/469/files
  - `pDIS_TransportOrder.New` now sets `update Sendung set Quell_K = 'D' where Sendung_Tix = TransportOrderId;`
  - https://github.com/cal-consult/tms-alloydb-schema/blob/e075fec5b84a299b3286d08e752514dcbaeb3ab1/src/sql/package/PDIS_TRANSPORTORDER.sql#L60C7-L60C77

Feld: `Quell_K` mit Wert `'D'` steht für New Dispo.

Todo:
- Kommentar einfügen, dass diese `UPDATE`-Zeile für New Dispo kennzeichnet
- In weiteren Views einbinden wie etwa `v_dis_transportorder_pickupplanning`

## Auswirkung aufs Konzept

Wir haben damit den fehlenden Baustein für die Konkretisierung der techn. Lösung.
