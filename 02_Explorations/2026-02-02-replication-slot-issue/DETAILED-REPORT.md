# TMS Pulse (PostGres): Replication Slot Issues - Detailbericht

**Erstellt:** 2026-02-16
**Autoren:** Matthias (Architect), Nikolay Hristov, Ron Vervenne, Eric Meijers, Thomas Paulus

---

## Teil 1: Das konkrete TMS Pulse CDC Problem

### Was ist passiert?
- Replication Slots sind auf 422-500 GB angewachsen (7 Tage Verzögerung)
- New Dispo erhält einwöchige alte Daten
- Issue wurde zufällig während manuellem Testing entdeckt

### Mögliche Root Causes

#### 1. Deployment-Scripts von Nagel IT brechen die Datastream-Verbindung

**Das Problem:**
- Das Script `datastream_setup.sql` killt bei jedem Deployment alle Datenbankverbindungen
- Dabei werden auch die Replication Slots neu erstellt
- Dies führt dazu, dass P3's Datastream die Verbindung verliert und in einen unrecoverable State geht
- Vermutlich ist es ein wiederkehrendes Problem

**Technischer Ablauf:**
1. Nagel IT führt Deployment mit `datastream_setup.sql` aus
2. Script killt alle aktiven DB-Verbindungen (inkl. Datastream)
3. Replication Slots werden neu erstellt
4. Datastream verliert Verbindung und kann nicht reconnecten
5. WAL (Write-Ahead Log) sammelt sich an → Replication Slot Growth
6. Nach 7 Tagen: 422-500 GB Slot Size, massive Datenverzögerung

#### 2. Proxy-Verbindungen als möglicher Faktor

**Das Problem:**
- Datastream verbindet sich über Proxy-Server (10.100.47.236 und 10.100.47.238) zur Datenbank
- Errors im Log zeigen: "*replication slot is already being used by a different process*"
- Proxy-Disconnects können das Problem verstärken oder triggern

**Diskussion:**
- Direkte Datenbankverbindung statt Proxy evaluieren
- Würde eine Fehlerquelle eliminieren
- Reduziert Komplexität der Connection-Chain

#### 3. Ungeklärte Debezium-Connector Aktivität (kritische Sicherheitsfrage)

**Was wurde entdeckt?**
- In den Logs erscheint ein Debezium-Connector für CDC
- **Nur bei neuen Datastream-Instanzen, die 2026 erstellt wurden**
- Bei älteren, bestehenden Instanzen tritt dies nicht auf

**Vermutung:**
- Google hat möglicherweise begonnen, Debezium intern für Datastream zu verwenden
- Keine öffentliche Dokumentation oder Bestätigung dafür online verfügbar

**Kritisches Risiko:**
- **Bevor wir die Replication-Slot-Untersuchung fortsetzen, müssen wir Datenlecks ausschließen**
- Unbekannte Connector-Aktivität könnte bedeuten, dass Daten an unbekannte Ziele gestreamt werden
- Security-Governance verlangt Klärung vor weiteren Maßnahmen

**Erforderliche Maßnahme:**
- **Google Support-Ticket muss sofort eröffnet werden**
- Frage: "Nutzt Google Datastream intern Debezium-Connectoren? Wenn ja, seit wann und warum nur bei neuen Instanzen?"
- **Status:** Ticket aktuell pending bei Matt und/oder Dominik Landau (P3)
- Erst nach Klärung können wir sicher mit der Replication-Slot-Investigation fortfahren

### Warum war die Investigation so ineffizient?

**Fehlende Koordination und Monitoring (macht Detection & Response ineffizient):**
- Nagel IT war nicht bewusst, dass ihre Deployment-Scripts CDC beeinflussen
- P3 hatte keine Visibility über anstehende Deployments
- Kein Monitoring hat die entstehende Datenlücke detektiert
- Issue wurde zufällig entdeckt statt durch proaktive Alerts
- Mehrtägige Investigation notwendig, da keine klaren Strukturen

**Hinweis:** Dies ist nicht die Root Cause der technischen Probleme, sondern erklärt, warum Detection und Investigation so strukturlos und zeitaufwändig waren.

---

### Ownership & Dependencies (Warum das passiert ist)

**Hinweis:** Layer 4 (Monitoring & Operations) ist derzeit in Klärung/Arbeit mit Harun.

```mermaid
%%{init: {
  'theme':'base',
  'themeVariables': {
    'primaryColor':'#e1f5ff',
    'primaryTextColor':'#000',
    'primaryBorderColor':'#0288d1',
    'lineColor':'#666',
    'secondaryColor':'#fff3e0',
    'tertiaryColor':'#f3e5f5'
  },
  'flowchart':{
    'titleTopMargin':25,
    'diagramPadding':0,
    'layoutDirection':'TB',
    'minEntityWidth':150,
    'minEntityHeight':75,
    'entityPadding':25,
    'padding':10,
    'nodeSpacing':25,
    'rankSpacing':50
  }
}}%%
graph TB
    subgraph Layer1["Layer 1: Infrastructure"]
        DB[(AlloyDB Database<br/>TMS Pulse PostGres)]
    end

    subgraph Layer2["Layer 2: Schema & Scripts"]
        SLOT(Replication Slot<br/>sendung_slot_uat2820)
        SCRIPT(Deployment Scripts<br/>datastream_setup.sql)
        SCHEMA(Database Schema)
    end

    subgraph Layer3["Layer 3: CDC Pipeline"]
        DS(GCP Datastream<br/>new-dispo-cdc-datastream)
    end

    subgraph Layer4["Layer 4: Monitoring & Operations"]
        MONITOR(Health Monitoring<br/>Alerting & SLAs<br/>⚠️ MISSING)
    end

    subgraph Legend["🔑 Ownership"]
        L1(🔵 Layer 1: Constraight?)
        L2(🟠 Layer 2: Nagel IT)
        L3(🟣 Layer 3: P3)
        L4(⚠️ Layer 4: ??? / MISSING)
    end

    APP(New Dispo Application)

    DB --> SLOT
    SCHEMA -.gespeichert in.-> DB
    SCRIPT -.verwaltet.-> SLOT
    SCRIPT -.killt & erstellt neu.-> SLOT
    SLOT -->|WAL Stream| DS
    DS --> APP
    MONITOR -.sollte monitoren.-> DS
    MONITOR -.sollte monitoren.-> SLOT
    MONITOR -.sollte monitoren.-> DB

    style Layer1 fill:#e1f5ff,stroke:#0288d1,stroke-width:3px,rx:10,ry:10
    style Layer2 fill:#fff3e0,stroke:#f57c00,stroke-width:3px,rx:10,ry:10
    style Layer3 fill:#f3e5f5,stroke:#7b1fa2,stroke-width:3px,rx:10,ry:10
    style Layer4 fill:#ffebee,stroke:#c62828,stroke-width:3px,stroke-dasharray: 8 4,rx:10,ry:10
    style Legend fill:#f5f5f5,stroke:#9e9e9e,stroke-width:2px,stroke-dasharray: 5 5,rx:10,ry:10
    style L1 fill:#e1f5ff,stroke:#0288d1,stroke-width:2px
    style L2 fill:#fff3e0,stroke:#f57c00,stroke-width:2px
    style L3 fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    style L4 fill:#ffebee,stroke:#c62828,stroke-width:2px,stroke-dasharray: 5 2
    style SCRIPT fill:#ffebee,stroke:#c62828,stroke-width:2px
    style SLOT fill:#fff9c4,stroke:#f57f17,stroke-width:2px
    style MONITOR fill:#ffebee,stroke:#c62828,stroke-width:2px,stroke-dasharray: 5 2
```

**Das Governance-Problem (nicht die technische Root Cause):**
- P3 provisioniert und konfiguriert Datastream (Layer 3)
- Nagel IT führt Deployments durch, die Datastream brechen (Layer 2)
- Niemand monitored, keiner bekommt Alerts (Layer 4 fehlt komplett)
- Constraight managed die Infrastruktur ohne Visibility in CDC (Layer 1)

**Das führt zu:**
- Issues werden zufällig entdeckt statt durch proaktives Monitoring
- Investigation ist ineffizient und strukturlos (mehrtägig)
- Keine klaren Ownership-Strukturen für operatives Monitoring

---

### Vorschlag für unmittelbare Maßnahmen (2 Wochen)

1. **🔴 PRIORITÄT: Google Support-Ticket für Debezium-Connector öffnen** (Security-relevanter Blocker)
   - **Owner:** Matt und/oder Dominik Landau (P3)
   - Status: Ticket aktuell pending
2. **`datastream_setup.sql` im nächsten Deployment deaktivieren/anpassen**
   - **Owner:** P3 mit Nagel IT / DB-Developer
3. **Direkte Datenbankverbindung evaluieren:** Datastream direkt zur Datenbank statt über Proxy (reduziert Fehlerquellen)
   - **Owner:** P3
4. **Basis-Monitoring für Datastream einrichten** (aktuell: 0 Monitoring)
   - **Owner:** P3
5. **Deployment-Koordination:** Nagel IT informiert P3 48h vor Deployments, die Replication Slots betreffen
   - **Owner:** Nagel IT

---

### Fazit Teil 1

**Technische Root Causes:**
1. **Deployment-Scripts:** `datastream_setup.sql` killt DB-Verbindungen und bricht Datastream
2. **Proxy-Verbindungen:** Verstärken Connection-Probleme
3. **Ungeklärte Debezium-Aktivität:** Sicherheitsrelevante Frage muss mit Google geklärt werden

**Governance-Problem (macht Investigation ineffizient):**
- Fehlende Koordination zwischen Teams (Nagel IT, P3, Constraight)
- Fehlendes Monitoring (Layer 4) → zufällige Entdeckung statt Alerts
- Mehrtägige, strukturlose Investigation
- Keine klaren Ownership-Strukturen für operatives Monitoring

---

## Teil 2: Governance Framework - Warum wir es brauchen und was es löst

**Kontext:** Das Operations & Governance Framework, das derzeit im Angebot ausgearbeitet wird, adressiert genau die Lücken, die bei TMS Pulse sichtbar geworden sind.

### Das TMS Pulse Problem bestätigt unseren Ansatz

Dieses konkrete TMS Pulse Beispiel zeigt sehr deutlich, warum das geplante Operations & Governance Framework wichtig ist.

**Was das Framework verhindert hätte:**
Die technischen Issues (Deployment-Script, Proxy-Probleme, Debezium) wären mit dem Framework nicht automatisch verhindert worden. ABER: Die Detection und Resolution wären deutlich effizienter gewesen:
- Proaktives Monitoring hätte das Problem innerhalb von Minuten/Stunden detektiert (statt zufällig nach 7 Tagen)
- Klare Ownership-Strukturen hätten eine strukturierte, schnelle Investigation ermöglicht (statt mehrtägiger unstrukturierter Suche)
- Koordinierte Deployment-Prozesse hätten das Script-Problem frühzeitig verhindert oder schnell identifiziert

Wir sehen ein wiederkehrendes Pattern:

**Projekte mit ähnlichen Herausforderungen:**
- **TMS Pulse (PostGres)** - Wie gerade erlebt: fehlende Team-Koordination, kein Monitoring
- **Cloud4Log** - Operational Ownership zwischen Teams noch in Klärung
- **Markant DVA** - Aktuell in Konzeptionsphase, idealer Zeitpunkt für Framework-Anwendung

**Die gute Nachricht:** Wir haben dies erkannt und arbeiten bereits an der Lösung. Das geplante Framework würde Detection & Response deutlich verbessern:

1. **Operations & Governance Framework für alle Cloud-Deliveries:** Monitoring, Alerting, SLAs, Handoff-Prozeduren als Standard-Bestandteile
2. **Delivery Standards:** Klare Definition was Teil einer technischen Delivery sein muss (Monitoring, Dokumentation, Runbooks, Alert-Routing)
3. **Ownership Model für Layer 4:** Verantwortlichkeiten für operatives Monitoring definieren (Delivery-Teams, zentrales Ops, oder cross-funktional)
4. **Proactive statt Reactive:** Strukturiertes Monitoring und Alerting statt zufälliger Entdeckung von Problemen
5. **Koordinierte Deployments:** Teams wissen, welche Auswirkungen ihre Änderungen auf andere Systeme haben

### Warum wir das jetzt teilen

TMS Pulse ist ein konkretes, real aufgetretenes Beispiel, das den Business Case für das Framework bestätigt. Es zeigt nicht nur theoretische Risiken, sondern messbare Impacts (7 Tage Datenverzögerung, mehrtägige Investigation, manuelle Entdeckung). Dies hilft bei der Priorisierung und Budgetierung der geplanten Governance-Initiative.

---

## Zusammenfassung & Next Steps

**Kurzfristig (TMS Pulse CDC):**
- 🔴 **Google Support-Ticket für Debezium-Connector** (**Matt und/oder Dominik Landau (P3)**)
  - Blockiert weitere Investigation aus Security-Gründen
  - Status: Ticket aktuell pending
- **Deployment-Script anpassen** (**P3 mit Nagel IT / DB-Developer**)
- **Direkte DB-Verbindung evaluieren** (**P3**)
- **Basis-Monitoring für Datastream aufsetzen** (**P3**)
- **Deployment-Koordination etablieren** (**Nagel IT**)
  - Nagel IT informiert P3 48h vorher bei Änderungen an Replication Slots

**Mittelfristig (Governance - bereits in Arbeit):**
1. Laufendes Operations & Governance Framework-Angebot finalisieren (**P3**)
2. Framework auf TMS Pulse, Cloud4Log und Markant DVA anwenden (**Nagel + P3**)
3. TMS Pulse Learnings in Framework-Definition einfließen lassen (**P3**)

**Follow-up Meeting Vorschläge:**

**Meeting 1: TMS Pulse CDC - Technische Koordination**
- Teilnehmer: Pascal, Ron Vervenne, Matthias, Nikolay Hristov, Eric Meijers, Matt Wilkinson, Dominik Landau
- Dauer: 30 Min
- Thema: Deployment-Koordination etablieren, Google Support-Ticket Status

**Meeting 2: Governance Framework**
- Teilnehmer: Christian, Pascal, Ron Vervenne, Matthias, Matt Wilkinson, Harun, Tim, Martin
- Dauer: 60 Min
- Thema: Alignment zum laufenden Angebot, TMS Pulse Learnings einarbeiten

---

**Aktueller Status:** Technisches Root Cause bei TMS Pulse identifiziert, Recovery läuft. **🔴 Debezium-Connector:** Google Support-Ticket pending bei Matt/Dominik Landau (P3) (Security-Klärung). Das Governance Framework ist bereits in Arbeit und wird durch diese Learnings gestärkt.
