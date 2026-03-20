# Email: Transactional Behaviour New Dispo <> TMS

**An:** [PO Stakeholder]
**Betreff:** Transactional Behaviour New Dispo <> TMS - Lösungsansätze und Empfehlung für Juni

---

Hallo [Name],

im letzten PO Sync haben wir das Thema Transactional Behaviour zwischen New Dispo und TMS besprochen, um Datenintegrität sicherzustellen. Hier die besprochene Darstellung der Herausforderung:

## Problem-Space

Bei kritischen Workflows (Transportauftrag erstellen, Legs/Lots hinzufügen, Tourpunkte editieren) können Fehler in der Synchronisation zwischen New Dispo und TMS zu Dateninkonsistenzen führen:

**3 Fehlerszenarien:**
1. **Early Failure:** TMS Bridge lehnt ab → sauberer Fehler, keine Inkonsistenz
2. **New Dispo DB Ausfall:** TMS erfolgreich, aber New Dispo DB schlägt fehl → TMS hat Daten, New Dispo nicht
3. **Netzwerk Timeout:** TMS erfolgreich, aber Response geht verloren → Unsicherheit über tatsächlichen Zustand

Die Szenarien 2 und 3 erfordern Abgleichslogik, um Dateninkonsistenzen zu vermeiden.

## 3 Lösungsoptionen

### Option 1: Manuelle Benutzer-Wiederherstellung
- User sieht Fehlermeldung mit "Retry" Button
- State-Checking vor Retry verhindert Duplikate (z.B. prüfen ob Leg bereits auf Transportauftrag existiert)
- **Aufwand:** 10-20% einer Outbox-Implementierung
- **Timeline:** Wahrscheinlich machbar bis Juni
- **Risiko:** User-abhängig, erfordert manuelle Eingriffe

### Option 2: Outbox Pattern mit Auto-Cure
- Request schreibt in New Dispo DB + Outbox Table (atomisch)
- Background-Prozess synchronisiert asynchron zu TMS
- Automatische Retries mit exponentiell steigenden Wartezeiten
- **Aufwand:** Medium-High
- **Timeline:** Nicht machbar bis Juni
- **Vorteil:** Automatisierte Recovery, Konsistenz wird letztendlich garantiert

### Option 3: Event-Driven Architecture
- Zu komplett event-getriebener Architektur wechseln. Details wären zu verfeinern und Vor- und Nachteile zu bewerten.
- **Aufwand:** Sehr hoch, fundamentaler Architektur-Shift
- **Timeline:** Nicht machbar bis Juni

## Entscheidung für Juni Release: Option 1 (Manuelle Wiederherstellung)

**Begründung:**
- Go-Live Zeitbeschränkung erfordert risikoarmen Ansatz mit geringer Komplexität
- Single Branch Deployment (1060, 1034) begrenzt Blast Radius
- Fehler Szenarien 2 & 3 sind selten bei stabiler Infrastruktur
- Aufwand ist kleiner (10-20% von Outbox), schont Budget für Post-Juni Improvements
- Idempotenz noch zu prüfen mit Joachim: State-Checking ermöglicht sichere Retries
- Business kann manuelle Resolution tolerieren wenn Fehlerfrequenz niedrig ist

**Post-Juni Migration:** Outbox Pattern (Option 2) als nächster Schritt.

**Next Steps:**
1. UX-Lösung
2. Technische Klärungen mit Joachim/TMS und intern im Team

Grüße
Matthias
