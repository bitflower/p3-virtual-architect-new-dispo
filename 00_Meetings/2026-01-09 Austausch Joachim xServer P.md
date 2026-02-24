# 2026-01-09 Austausch Joachim xServer Problem

## PlanningInterval

- `PlanningInterval` = "Scope" der überhaupt als Zielplanungszeitrum herangezogen wird (in dem es erlaubt ist zu planen)
- Wird gesetzt beim Anlegen vom Transport Order
  - Ist immer 1 Stunde vor dem geplanten Tag und geht bis 1h danach

=> Darf nicht angepasst werden, durch das Setzen der Fixed Times.

Denke: "Wir setzen ZEITEN nicht DATUM" => Wir planen ja den Transportauftrag

Fix 1: Wir benötigen keinen Datumspicker

Fix 2: Datum müsste normiert werden

- Es gibt noch Öffnungszeitem im Personenstamm (TMS). Diese werden standatdmäßig herangezoegen. Setzt der Dispatcher die Fixed Tiems, werden diese übernommen. Enormes Wissen in der TMS Branch.

## Regeln

- Fahrer darf sowieso nur innerhal eines Tage fahren
- Auf jeden Fall innerhalb 24h

## Next Steps

- Klärung Max B mit Max K