# 17. Block Transport Order

- `pta.getstatus(s1.sendung_tix) as status,` in `v_dis_transportorder` enthält die benötigten Werte
- Basiert auf BIT-Status
- Prüfung: Wert entweder 6 oder 7

## Randnotizen

- `CanExecute`-Routine (von Joachim genannt) ist eine Alternative aber techn. zu viel Overhead
- Sollte New Dispo trotzallem Schreiben, wirft der TMS Core sowieso einen Fehler, welchen New Dispo abfangen muss und ggf. darstellen