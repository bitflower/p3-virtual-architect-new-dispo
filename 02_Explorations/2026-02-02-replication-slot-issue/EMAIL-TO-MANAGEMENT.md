**Betreff:** TMS Pulse CDC - 3 Issues identifiziert & Governance Framework Update

---

Hallo Christian, hallo Pascal,

TMS Pulse (PostGres) hat derzeit CDC-Probleme. Analyse mit Nikolay, Ron, Eric und Thomas hat drei Herausforderungen identifiziert.

## Was ist passiert?

Replication Slots sind auf 422-500 GB angewachsen (7 Tage Verzögerung). New Dispo bekommt einwöchig alte Daten. Zufällig beim Testing entdeckt.

## Die drei Issues

**Issue 1: Deployment-Scripts brechen Datastream**
- Nagel IT's `datastream_setup.sql` killt bei jedem Deployment alle DB-Verbindungen
- Datastream geht in unrecoverable State
- P3 DevOps: "This happened before" - wiederkehrendes Problem

**Issue 2: Proxy-Verbindungen verstärken das Problem**
- Datastream verbindet über Proxy zur DB (statt direkt)
- Error: "replication slot already in use by different process"
- Evaluierung: Direkte DB-Verbindung nutzen

**Issue 3: 🔴 Ungeklärter Debezium-Connector (Security)**
- Debezium-Connector erscheint in Logs
- **Nur bei neuen 2026-Instanzen** (alte Instanzen nicht betroffen)
- Vermutung: Google nutzt Debezium intern für Datastream?
- Keine Dokumentation online gefunden
- **Bevor wir weiter investigaten: Muss mit Google geklärt werden (Datenleak-Risiko)**
- Status: Support-Ticket pending bei Matt/Dominik (P3) Landanu

## Root Cause (Technisch)

Die drei Issues oben sind die technischen Root Causes.

**Das Governance-Problem:**
Die fehlende Koordination zwischen Teams (Nagel IT, P3, Constraight) + fehlendes Monitoring hat die Investigation sehr ineffizient und strukturlos gemacht. Jedes Team arbeitet korrekt, aber ohne Abstimmung und Monitoring:
- Issue wurde zufällig entdeckt (nicht durch Alerts)
- Mehrtägige Investigation notwendig
- Keine klaren Ownership-Strukturen für Layer 4 (Monitoring & Operations)

## Governance Framework - Warum wir es brauchen und was es löst

TMS Pulse zeigt, warum das Operations & Governance Framework (derzeit im Angebot) wichtig ist.
Die technischen Issues hätten schneller detektiert und effizienter gelöst werden können mit:
- Proaktivem Monitoring & Alerting (statt zufälliger Entdeckung)
- Klaren Ownership-Strukturen für Layer 4 (Operations & Monitoring)
- Koordinierten Deployment-Prozessen zwischen Teams

Wir haben einen konkreten Business Case mit messbaren Impacts (7 Tage Delay, mehrtägige Investigation, manuelle Entdeckung).

Gleiches Pattern sehen wir bei:
- Cloud4Log (Operational Ownership unklar)
- Markant DVA (in Konzeptionsphase - kann präventiv adressiert werden)

## Next Steps

**Kurzfristig (2 Wochen):**
1. 🔴 Google Support-Ticket für Debezium (**Matt und/oder Dominik Landau (P3)**)
   - Status: pending
2. `datastream_setup.sql` anpassen (**P3 mit Nagel IT / DB-Developer**)
3. Direkte DB-Verbindung evaluieren (**P3**)
4. Basis-Monitoring für Datastream aufsetzen (**P3**)
   - Aktuell: 0 Monitoring
5. Deployment-Koordination etablieren (**Nagel IT**)
   - Nagel IT informiert P3 48h vorher bei Replication Slot Changes

**Mittelfristig (bereits in Arbeit):**
1. Laufendes Governance Framework-Angebot finalisieren (**P3**)
2. Framework auf TMS Pulse, Cloud4Log, Markant DVA anwenden (**Nagel + P3**)
3. TMS Pulse Learnings einarbeiten (**P3**)

## Meeting Vorschläge

**Meeting 1: TMS Pulse CDC - Technische Koordination**
- **Teilnehmer:** Pascal, Ron, Matthias, Nikolay, Eric, Matt, Dominik Landau
- **Dauer:** 30 Min
- **Thema:** Deployment-Koordination + Google Ticket Status

**Meeting 2: Governance Framework**
- **Teilnehmer:** Christian, Pascal, Ron, Matthias, Matt, Harun, Tim, Martin
- **Dauer:** 60 Min
- **Thema:** Alignment zum Angebot + TMS Pulse Learnings

**Anhang:** Detailbericht mit vollständiger technischer Analyse, Ownership-Diagramm, Root-Cause-Details

Grüße
Matthias
