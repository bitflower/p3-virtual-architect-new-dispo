Hi Joachim,

Max Kehder hat uns gezeigt, dass verplante HL Legs in CALtms aktuell noch geändert werden können (ABN 10/34, Screenshot anbei). Das ist dasselbe Muster wie beim Traffic Mode Change: eine Änderung in TMS, die im New Dispo zu verwaisten Zuordnungen führt — der Leg wird gelöscht oder umgelottet, die Tourzuordnung ist danach inkonsistent.

Ähnlich wie in ADR-011 sehen wir die Lösung aus Kapazitätsgründen darin, die Änderung in TMS zu blockieren, wenn der Leg in der New Dispo bereits verplant ist. Kannst du einschätzen, ob der bestehende Blocking-Mechanismus dafür erweitert werden kann?

Eine tiefgreifende Lösung (siehe ADR-011, Options A & B) kann nur Post-Go-Live erfolgen — die Bottom-Up Synchronization ist für dieses Release explizit de-scoped.

Uschmann, Patrick Maximilian Kehder Solltet ihr dann auf PO-Ebene behandeln (In-/Out-Scope).

Danke & Grüße
Matthias

---

**Ref:** [HL Legs Still Planable — Impact on New Dispo Sync](../hl-legs-still-planable--impact-on-new-dispo-sync.md)
