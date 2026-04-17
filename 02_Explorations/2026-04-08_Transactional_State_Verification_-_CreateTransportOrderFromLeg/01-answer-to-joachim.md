# Flow #1: Rückfrage zu CreateTransportOrderFromLeg

**Datum:** 2026-04-08  
**An:** Joachim  
**Betreff:** Bestätigung Verification-Kandidaten

---

Danke Joachim!

Genau, weil `CreateTransportOrderFromLeg` nicht idempotent ist, prüfen wir in NewDispo VOR dem Aufruf ob der Zustand bereits existiert.

## Bestätigung unserer Verification-Kandidaten

Wir wollen vor dem Aufruf prüfen ob ein Leg bereits einem TO zugeordnet ist. Dafür nutzen wir `V_DIS_Leg` mit den Parametern `ShipmentId` und `LegType`.

Falls Ergebnis vorhanden (TransportOrderId NOT NULL) → Leg ist bereits einem TO zugeordnet → kein neuer Aufruf nötig.

**Ist das korrekt?**

Siehe: [Flow #1: Verification Candidates (Wiki)](/Projects/Active/Transactional-Behaviour/Flows/01-CreateTransportOrderFromLeg#verification-candidates)

## Eine Frage bleibt

In `V_DIS_Leg` wird `limit 1` verwendet um die TransportOrderId via `V_TA_Sen7` zu ermitteln.

Ist das problematisch wenn ein Leg mehreren TOs zugeordnet sein kann? Oder reicht für unseren Use Case "mindestens ein TO existiert"?
