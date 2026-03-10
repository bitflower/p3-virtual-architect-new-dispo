# Oracle CDC Architektur - Status-Update

Hi Christian,

kurzes Status-Update zur CDC-Evaluierung. Wir warten noch auf Rückmeldungen, aber hier der aktuelle Stand.

## Management Summary

Zentrale Erkenntnis: Striim ist bereits im Einsatz (aktuell 5 Branches, historisch alle). Wir prüfen 4 Optionen.

Drei Blocker vor finaler Empfehlung:

- Strategische Richtung für Striim unklar (Ausbau vs. Ablösung)
- Striim Erweiterungskosten unbekannt
- Oracle Standard Edition 2 Kompatibilität mit Alternativen ungeprüft

## Empfehlung (Vorschau)

| Priorität | Option                    | Begründung                                                                           |
| --------- | ------------------------- | ------------------------------------------------------------------------------------ |
| 1         | Bestehendes Striim nutzen | Bereits deployed, erprobt, kein Dual-CDC Risiko                                      |
| 2         | GCP Datastream            | GCP-nativ, bestehendes Know-how auf GCP-Seite, aber Abhängigkeit zu Striim Strategie |
| 3         | Debezium                  | Open Source, erfordert Infrastruktur-Management                                      |

## Anforderungen (Recap)

Kernziel: NewDispo unabhängig von Projekt G enablen. CDC-Events sollen nach Pub/Sub publiziert werden - dieselben Tabellen wie beim AlloyDB-Setup.

Wichtig: Das ist KEIN Bulk-Replikations-Use-Case. Ziel ist das Triggern von Business-Logik bei spezifischen Datenänderungen (z.B. "neue Sendung angekommen"). Scope ist eng: Änderungen an bestimmten Feldern in bestimmten Tabellenzeilen. => Hoher Durchsatz ist weniger wichtig als Zuverlässigkeit und geringer Betriebsaufwand. Hier sollten wir ggf. nochmal über die Prioritäten sprechen (Kosten? Erwartete Reaktionszeit?).

Dual-CDC-Systeme müssen vermieden werden - Risiko von Datenkonflikten und doppelter Infrastruktur-Komplexität.

## Technische Rahmenbedingungen

- Oracle Versionen: 12.1.0.2 (Haupt), 19.9/19.21 (KRITIS) - alle unterstützen LogMiner. Weiteres Feedback von Robert ausstehend.
- **Edition-Mix:** Enterprise (HQ), Standard Edition 2 (Branches) => ggf. kritisch bzw. noch nicht vollends bewertet. Offene Frage: Laufen die 5 Striim-Branches auf SE2?
- Archivelog Mode: Aktiviert
- Redo Log Retention: ~1 Stunde bei manchen Branches (D33) => sehr kurzes Recovery-Fenster
- Infrastruktur-Zustand von Striim: Als "wackelig" beschrieben
- Netzwerk zu GCP: Steht

## Kritische Einschränkung: Standard Edition 2

Oracle SE2 unterstützt nicht alle LogMiner-Features:

- Kein Continuous LogMiner (Streaming API)
- Begrenzte parallele LogMiner-Sessions
- Supplemental Logging Einschränkungen in manchen Konfigurationen

=> Jedes CDC-Tool das auf LogMiner-Streaming setzt (Datastream, Debezium) hat möglicherweise eingeschränkte Funktionalität oder ist inkompatibel auf SE2-Branches. Validierung mit DBA-Team erforderlich.

## Optionen-Übersicht

Vier Optionen potentiell möglich. Details folgen nach Eingang aller Rückmeldungen.

- **Option A: Bestehendes Striim erweitern** - Pub/Sub als Ziel hinzufügen. Bereits auf SE2 erprobt. Kosten unbekannt bzw. noch zu prüfen.
- **Option B: GCP Datastream + Cloud Functions** - GCP-nativ, folgt bestehendem AlloyDB-Pattern. SE2-Kompatibilität ungeprüft.
- **Option C: Debezium Server auf GCE** - Open Source, keine Lizenzkosten. Kein internes Know-how, hoher Betriebsaufwand.
- **Option D: Oracle GoldenGate** - Oracle-nativ, teuer (~$1.000+/Monat), keine interne Expertise.

### Vergleich

| Kriterium          | Striim      | Datastream | Debezium  | GoldenGate |
| ------------------ | ----------- | ---------- | --------- | ---------- |
| Internes Know-how  | Hoch        | Mittel     | Keins     | Keins      |
| SE2 Kompatibilität | Verifiziert | Unbekannt  | Unbekannt | Ja         |
| Dual-CDC Risiko    | Keins       | Hoch       | Hoch      | Hoch       |
| Betriebsaufwand    | Niedrig     | Niedrig    | Hoch      | Mittel     |
| Kosten             | TBD         | ~$2/GiB    | Frei      | ~$1.000/Mo |

## Offene Punkte & Empfohlenes Vorgehen

| Aktion                                              | Verantwortlich | Priorität |
| --------------------------------------------------- | -------------- | --------- |
| Striim Kostendaten beschaffen (aktuell + 6 Monate)  | Matt Wilkinson | Hoch      |
| Striim Strategie klären (Ausbau vs. Ablösung)       | Christian Lang | Hoch      |
| Datastream SE2 Kompatibilität mit Google validieren | Matthias Max   | Hoch      |
| LogMiner Features auf SE2 mit DBA bestätigen        | Robert Zanter  | Hoch      |

**Empfohlenes Vorgehen:**

Phase 1 (Validierung): Striim-Kosten einholen, strategische Richtung klären, Datastream SE2-Kompatibilität prüfen.

Phase 2 (PoC basierend auf Ergebnis):

- Striim-Strategie = Ausbau => Striim um Pub/Sub erweitern
- Striim-Strategie = Ablösung => Datastream PoC (falls SE2 validiert)
- SE2 inkompatibel mit Datastream => Striim wird einzige Option

Debezium wurde bereits in [ADR001] Data Exchange Between TMS and CALSuite's Cross-Dock abgelehnt. GoldenGate wird nicht weiterverfolgt - fehlendes internes Know-how und hohe Kosten ohne erkennbaren Mehrwert.

## Ziel-Architektur

Unabhängig vom CDC-Tool:

```text
On-Premises (Oracle Branches)
         │
    [CDC Tool: Striim oder Datastream Agent]
         │
    VPN/Interconnect
         │
         ▼
       GCP
         │
      Pub/Sub
         │
         ▼
     NewDispo
```

Nächstes Update nach Eingang der Rückmeldungen.

Grüße
Matthias
