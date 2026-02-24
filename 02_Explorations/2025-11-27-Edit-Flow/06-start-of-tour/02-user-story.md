WHO: As a dispatcher
WHAT: I want the tour calculation/optimization to use the correct start time for the entire tour
WHY: so that the tour does not start at a random time.

Start time determination logic

## 1. If the Transport Order has tourpoints (excluding type = 4):

- If the first tourpoint has a **fixedArrivalTime**, use that as the tour start time. => **YES**
- Otherwise, use the **plannedArrivalTime** of the first tourpoint. => **Only available after xServer has calculated**
- If that is also missing, fall back to the performanceDate of the Transport Order. => Gehört nicht in den Kernel (lt. Joachim), Vorschlag: Setzen des **fixedArrivalTime** auf *performanceDate* (incl. Time) in New Dispo => Als sep. Vorgang bevor man berechnet.

JOACHIM PRÜFT DIES ABER NOCHMAL => EVTL. DOCH KERNEL

pDIS_TourPoint.SetLoadingInterval: Setzt die fixedArrivalTime oder die Range
pDIS_TourPoint.RemoveLoadingIntervals: Entfernt die fixedArrivalTime oder Range

Sonderfall: Neuer Tourpunkt kommt vor dem bisherigen hinzu => Der neue Tourpunkt muss die **fixedArrivalTime** bekommen.
  
## 2. If the Transport Order has no valid tourpoints (only type = 4 or none):

- Use the **performanceDate** as the start time.
- If the performanceDate is only a date (no time), default to 00:00:00.

**=> Kann gar nicht berechnet werden bzw. ergibt keinen Sinn**
=> Es gibt einen zustand des TO wenn er noch kein Leg hat (und kein Unternehmer auf Fahrzeug). Zustand des TO ändert sich.

Feld: `V_DIS_TRANSPORTORDER` => `pta.getstatus(s1.sendung_tix) as status`
Mögliche Werte: `pTa_lib`

UX: Berechnung abhängig vom Status gar nicht erst anbieten.

## 3. When adding a Leg to a Transport Order without existing tourpoints (excluding type = 4):

- The first added tourpoint must have its ~~plannedArrivalTime~~ `fixedArrivalTime` initialized with the Transport Order’s performanceDate.

## Pending Work (Joachim)

The TMS Database adds the `performanceDate` of the Transport Order to the PoolDTO - NOT the first tourpoint's `fixedArrivalTime`. This way, the xServer knows the start of the tour.

Target property in the PoolDTO where the `performanceDate` is written:

The `Location` with the ID of the first tour point: `Plans[0].Tours[0].TourElements[0].LocationId`, the field `OpeningIntervals`.

Value:

```json
{
    "End": "2025-09-25T23:00:00",
    "Start": "2025-09-24T23:00:00"
}
```

=> entspricht dem Konstrukt, wie es z.B. `fixedArrivalTime` hat

This allows the dispatcher to set the `fixedArrivalTime` later - in which case the `performanceDate` is NOT passed into the PoolDTO.

## Pending P3

Remove the `StartTime` on the dummy vehicle.