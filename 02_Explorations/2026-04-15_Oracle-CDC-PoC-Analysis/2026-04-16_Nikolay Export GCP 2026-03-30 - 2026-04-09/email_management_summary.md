# Email - CDC POC Analyse: Ergebnisse und Optionen

**To:** [Empfänger]  
**Subject:** Oracle CDC POC - Analyse-Ergebnis Datastream (UAT1060) + Handlungsoptionen  
**Attachment:** full_poc_report.md

---

Hi zusammen,

anbei die vollständige Analyse des CDC POC mit GCP Datastream auf UAT1060 (TMS1060_SENDUNG). Die Daten decken den Zeitraum 30. März bis 9. April ab - ca. 75.000 replizierte Records über 10 Tage.

**Kurzfassung:**

Datastream funktioniert zuverlässig - 100% Delivery Rate, null Fehler. Das Problem ist die Latenz: im Schnitt **~42 Minuten** von der DB-Änderung bis zum GCS-Objekt. Das ist weit außerhalb dessen, was die fachliche Seite erwartet.

Zum Vergleich: Striim liefert auf der gleichen Oracle-Quelle eine End-to-End-Latenz von **~0,1 Sekunden** (~100ms, konstant). Warum dieser Unterschied besteht und was die architekturelle Ursache ist, ist im Report erklärt (Abschnitt "Datastream vs. Striim").

**Ursache:**

99,4% der Latenz entsteht **nicht** im Datastream-Processing (~16 Sekunden), sondern beim Warten auf Oracle's archivierte Redo Logs. Datastream (LogMiner-Methode, GA) kann erst lesen, wenn Oracle das Redo Log archiviert hat - und das passiert aktuell nur, wenn das 1 GB Log voll ist. Kein Zeittrigger (`ARCHIVE_LAG_TARGET = 0`). GCP hat uns während des gesamten POC **130 Warnungen** geschickt, dass die Redo Logs zu groß sind.

**Drei Optionen:**

|     | Option                                                                                                            | Erwartete Latenz | Aufwand                          | GCP-Mehrkosten             |
| --- | ----------------------------------------------------------------------------------------------------------------- | ---------------- | -------------------------------- | -------------------------- |
| 1   | **Oracle Redo Log Tuning** - ARCHIVE_LAG_TARGET setzen (z.B. 5-15 min) + Log-Größe von 1 GB auf 256 MB reduzieren | 5-20 min         | Gering (DBA)                     | Keine                      |
| 2   | **Datastream Binary Log Reader** - liest Online Redo Logs direkt, kein Warten auf Archivierung                    | 1-5 min          | Mittel                           | Keine (gleicher GiB-Preis) |
| 3   | **Striim** - liest Online Redo Logs in Echtzeit, läuft bereits im POC                                             | Sub-Sekunde      | Gering (technisch), Lizenzkosten | N/A                        |

**Empfehlung:**

Auch wenn Striim bei der Latenz klar vorne liegt: Datastream ist als managed GCP-Service massiv günstiger. Aus ADR-006 (Hochrechnung auf 64 Datenbanken):

|               | Datastream | Striim (mit Lizenz)* | Faktor |
| ------------- | ---------- | -------------------- | ------ |
| **Pro Monat** | EUR 344    | EUR 11.671*          | 34×    |
| **Pro Jahr**  | EUR 4.124  | EUR 140.048*         | 34×    |

\* Striim-Kosten basieren auf geteiltem Cluster mit "Pretzel" - tatsächliche Kosten nach Pretzel-Abschaltung noch zu verifizieren (siehe offene Punkte).

Aus meiner Sicht lohnt sich ein zweiter POC-Lauf mit den genannten Oracle-Optimierungen um zu sehen, wie nah wir mit Datastream an die fachlichen Anforderungen kommen - bevor wir die Striim-Lizenzkosten als gegeben hinnehmen.

Und zwar zunächst Option 1 - da geringer Aufwand. Dann sehen wir, ob die erreichte Latenz ausreicht oder ob wir Option 2/3 brauchen.

**Offene Punkte:**
- Robert: Oracle-Version auf UAT1060 bestätigen, Machbarkeit des Redo Log Tuning einschätzen (auch für aggressivere Werte wie 5 oder 10 min)
- Team: Ziel-Latenz definieren - was ist für den CDC Use Case akzeptabel?
- Business: Abstimmung mit der Fachseite auf Basis der neuen Zahlen - sowohl Latenz (0,1s vs. 5-20 min) als auch Kostenimplikation (EUR 4K vs. EUR 140K/Jahr). Was ist der akzeptable Trade-off?
- Striim-Kosten verifizieren: Die EUR 2.771/Monat Compute-Kosten sind aktuell geteilt mit dem "Pretzel"-Cluster. Wie sehen die tatsächlichen Striim-Kosten aus, wenn Pretzel abgeschaltet wird?
- GCP: Binary Log Reader ist noch Preview (kein SLA) - GA-Timeline klären

Der vollständige Report mit allen Charts, Metriken und Details ist im Anhang.

VG
Matthias
