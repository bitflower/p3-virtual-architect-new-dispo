# Architektur-Erklärung: Markant DVA & Cloud4Log Integration

## Einfache Beschreibungen der Architektur

### Upload Flow (korrigierte Aussage)

*"Wir entkoppeln die Identifizierung der zu veröffentlichenden Dokumente von dem eigentlichen Upload, was eine asynchrone Verarbeitung ermöglicht. Während Spitzenzeiten baut sich die Warteschlange auf und wird dann abgearbeitet, bis sie leer ist. Die **Zwei-Warteschlangen-Architektur** ist die zentrale Innovation: Wenn Cloud4Log oder Markant DVA ausfällt, werden fehlgeschlagene Einträge mit Backoff in einer **separaten Warteschlange** erneut versucht, während **neue Einträge sofort in der primären Warteschlange weiterverarbeitet werden**. Dadurch erhalten LKWs, die gerade beladen werden, ihre Dokumente zuerst, bevor historische Lücken aufgefüllt werden."*

### Download Flow

*"Auch beim Download entkoppeln wir die Identifizierung der herunterzuladenden Wareneingangsdokumente vom eigentlichen Download-Vorgang. Dies ermöglicht asynchrone Verarbeitung ohne Blockierung. Der Download-Workflow fragt regelmäßig Cloud4Log und Markant DVA ab, welche neuen Proof-of-Delivery Dokumente verfügbar sind, und publiziert dann Tasks in eine Warteschlange. Diese Tasks werden vom Download Service abgearbeitet. Der Vorteil: Das System kann in seinem eigenen Tempo arbeiten und skaliert automatisch bei höherer Last. Die Cloud Task Queue garantiert dabei, dass jedes Dokument genau einmal heruntergeladen wird, auch wenn es Retry-Versuche gibt oder mehrere Polling-Durchläufe überlappen."*

### Key Reliability Features

*"Die Architektur bringt drei zentrale Verbesserungen für Zuverlässigkeit: Erstens, das System priorisiert automatisch die neuesten LKWs bei Ausfällen – wenn Cloud4Log oder Markant DVA für 30 Minuten ausfällt, bekommen nach der Wiederherstellung die aktuell zu beladenden LKWs sofort ihre Dokumente, bevor historische Daten nachgefüllt werden. Zweitens, die Cloud Task Queue stellt sicher, dass keine Tasks verloren gehen oder doppelt verarbeitet werden, selbst bei Fehlern – fehlgeschlagene Uploads werden mit exponentiell steigenden Wartezeiten erneut versucht, ohne das System zu überlasten. Drittens, jeder Standort ist unabhängig konfigurierbar – ein Problem bei einem Standort oder einer Plattform beeinflusst nicht die anderen Standorte oder Plattformen."*

---

## 5-Minuten Präsentation für technische Business-Stakeholder

### Eröffnung (30 Sekunden)

*"Wir integrieren Markant DVA neben Cloud4Log, um den digitalen Lieferschein-Austausch mit Markant-Partnern zu ermöglichen. Die Kernforderung: TMS bleibt die Single Source of Truth, und beide Plattformen können parallel pro Standort laufen."*

---

### Upload Flow - Bild 1 (2 Minuten)

**Durch das Diagramm führen:**

1. **"Es beginnt mit einem geplanten Trigger"** (Upload Cron Job)
   - Läuft alle paar Sekunden und prüft, ob es Zeit ist, neue Arbeit einzuplanen
   - Liest Standort-Konfiguration, um zu wissen, welcher Standort welche Plattform nutzt

2. **"Der Workflow orchestriert die Datensammlung"** (Upload Workflow)
   - Für jeden Standort werden Tasks mit Standort- und Zeitbereich-Informationen publiziert
   - Dies erzeugt feinkörnige, parallelisierbare Arbeitseinheiten

3. **"Zwei Warteschlangen behandeln unterschiedliche Szenarien"** (Kritischer Punkt)
   - **Synchronization Tasks Queue**: Normaler Verarbeitungspfad
   - **Failed Cartages Retry Queue**: Behandelt Einträge, die aufgrund externer Systemprobleme fehlschlagen

   *"Diese Trennung ist entscheidend für Zuverlässigkeit: Wenn Cloud4Log oder Markant DVA ausfällt, werden fehlgeschlagene Einträge mit Backoff erneut versucht, während NEUE Einträge sofort weiterverarbeitet werden. Das bedeutet, LKWs, die auf Beladung warten, haben Priorität vor dem Nachfüllen historischer Daten."*

4. **"Einzelner Upload Service mit Plattform-Adaptern"** (Cloud Function)
   - Holt Daten von TMS Bridge (unsere GraphQL API zum TMS)
   - Holt Daten aus DigiLiS Datenbank
   - Ruft Lieferschein-PDFs von Dateiservern ab
   - **Adapter Pattern**: Derselbe Service publiziert sowohl zu Cloud4Log ALS AUCH Markant DVA basierend auf Standort-Konfiguration

---

### Download Flow - Bild 2 (1,5 Minuten)

**Durch das Diagramm führen:**

1. **"Spiegelstruktur, einfachere Ausführung"**
   - Gleiche Cron → Workflow → Queue Struktur
   - Download Service holt Proof-of-Delivery Dokumente von beiden Plattformen

2. **"Keine Locking-Mechanismen nötig"**
   - Cloud Task Queue behandelt Deduplizierung automatisch
   - Dokumente werden temporär in GCS Bucket gespeichert (30 Tage Aufbewahrung)
   - System sucht Daten sowohl in Cloud4Log als auch Markant DVA basierend auf Konfiguration

---

### Wichtige Zuverlässigkeits-Features (1 Minute)

*"Drei kritische Zuverlässigkeitsmuster:"*

1. **Prioritäts-Behandlung**: Neueste-zuerst Verarbeitung während Wiederherstellung
   - *Business-Wert*: "Wenn eine Plattform 30 Minuten ausfällt, bekommen LKWs, die gerade beladen werden, ihre QR-Codes sofort wenn das System wieder verfügbar ist, nicht erst nach dem Nachfüllen von 30 Minuten historischer Daten"

2. **Cloud Task Queue Vorteile**:
   - Deduplizierung verhindert doppelte Arbeit
   - Verzögertes Retry mit exponentiellem Backoff
   - Zuverlässige Nachrichtenzustellung

3. **Plattform-Isolation**:
   - Konfiguration auf Standort-Ebene
   - Ausfall einer Plattform beeinflusst die andere nicht
   - Adapter Pattern macht Hinzufügen zukünftiger Plattformen unkompliziert

---

### Abschluss (30 Sekunden)

*"Die Architektur refaktoriert Cloud4Log während Markant DVA hinzugefügt wird. Wir nutzen Component Integration Tests, um alle Zuverlässigkeits-Szenarien zu validieren—transiente Fehler, Wiederherstellung, Idempotenz—damit wir mit der Gewissheit deployen können, dass beide Plattformen unter allen Bedingungen korrekt funktionieren."*

---

## Visuelle Navigations-Tipps

**Bild 1 (Upload):**
- Flow nachvollziehen: Uhr → Workflow → Warteschlangen → Service → Externe Systeme
- Die **zwei Warteschlangen** als Zuverlässigkeits-Innovation betonen
- Auf die Extract/Transform/Load Box zeigen, um zu zeigen, dass ein einzelner Service beide Plattformen behandelt

**Bild 2 (Download):**
- Einfachere Spiegelung: Uhr → Workflow → Queue → Service → Storage
- Darauf hinweisen, dass die Suche zu BEIDEN externen Systemen geht

**Bei beiden Diagrammen zu erwähnen:**
- Grüne Boxen = Interne Nagel-Systeme (TMS, DigiLiS, Dateiserver)
- Weiße Boxen mit Rahmen = Externe Plattformen (Cloud4Log, Markant DVA)
- Blaue Boxen = GCP Managed Services, die Zuverlässigkeit bieten

---

## Detaillierte Erklärung

### Was korrekt ist ✓

1. **Entkopplung von Identifizierung und Upload**: JA
   - Upload Workflow identifiziert Dokumente und publiziert Tasks
   - Upload Service verarbeitet Tasks asynchron
   - Dies ermöglicht Skalierbarkeit und Autoscaling

2. **Spitzenlast-Handling**: JA
   - Warteschlangen-basierte Architektur erlaubt Ansammlung von Tasks während Spitzenzeiten (z.B. morgendliche Stoßzeiten)
   - System verarbeitet mit verfügbarer Kapazität, bis Warteschlange leer ist
   - Keine synchrone Blockierung wie in der alten Architektur

3. **Failed Cartages Retry Queue existiert**: JA

### Was präzisiert werden muss ⚠️

**Der Hauptzweck des Zwei-Warteschlangen-Systems ist NICHT allgemeines Retry—es geht um PRIORISIERUNG während der Wiederherstellung nach Ausfällen externer Systeme.**

#### Die tatsächliche Priorisierungs-Logik

Aus Ivailos Erklärung im Meeting:

> *"Wenn LKWs beladen werden und etwas schiefgeht [Cloud4Log/DVA ist nicht verfügbar], wird auf papierbasierte Prozesse zurückgefallen. Wir wollen nicht historische Daten nachfüllen priorisieren. Wenn die Plattform wieder verfügbar ist, müssen LKWs, die JETZT beladen werden, ihre QR-Codes sofort erhalten."*

**Funktionsweise:**
- **Synchronization Tasks Queue**: Normaler Verarbeitungspfad für alle neuen Einträge
- **Failed Cartages Retry Queue**: Fehlgeschlagene Einträge werden mit exponentiellem Backoff erneut versucht

**Entscheidender Vorteil:**
- Wenn eine Plattform 30 Minuten nicht verfügbar ist, sammeln sich fehlgeschlagene Einträge in der Retry-Warteschlange
- NEUE Einträge (LKWs, die JETZT beladen werden) gehen sofort durch die Synchronisierungs-Warteschlange
- Ergebnis: Aktuelle LKWs erhalten Priorität vor dem Auffüllen der 30-Minuten-Lücke

---

## Zusammenfassung

Es geht nicht nur um Retry—es geht um **Prioritäts-Isolation** während Wiederherstellungs-Szenarien. Die Zwei-Warteschlangen-Architektur stellt sicher, dass der operative Betrieb (LKWs, die gerade beladen werden) Vorrang vor der Nachbearbeitung hat.
