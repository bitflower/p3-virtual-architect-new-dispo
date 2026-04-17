# Email Draft — Oracle Redo Log Configuration Check

**To:** Robert  
**Subject:** CDC POC — Redo Log Konfiguration auf UAT1060 prüfen

---

Hi Robert,

wir haben im Rahmen des CDC POC mit GCP Datastream auf UAT1060 (TMS1060_SENDUNG) eine durchschnittliche End-to-End-Latenz von ~66 Minuten gemessen. Die Analyse zeigt, dass der Engpass nicht das Datastream-Processing ist (~23s), sondern die Zeit zwischen einer DB-Änderung und der Verfügbarkeit des archivierten Redo Logs.

Könntest du folgende Werte auf UAT1060 prüfen?

**1. Aktuelle Redo Log Konfiguration:**
```sql
SELECT group#, bytes/1024/1024 AS size_mb, status FROM v$log;
```

**2. Aktueller ARCHIVE_LAG_TARGET:**
```sql
SHOW PARAMETER ARCHIVE_LAG_TARGET;
```

**3. Log Switch Frequenz der letzten Tage:**
```sql
SELECT TO_CHAR(first_time, 'YYYY-MM-DD HH24:MI') AS switch_time,
       sequence#,
       ROUND((next_time - first_time) * 24 * 60, 1) AS duration_min
FROM v$archived_log
WHERE first_time > SYSDATE - 3
ORDER BY first_time;
```

**Was wir uns anschauen wollen:**
- `ARCHIVE_LAG_TARGET = 900` setzen (15 min) — erzwingt einen Log Switch alle 15 Minuten, auch bei niedriger Aktivität
- Redo Log File Size auf 128-256 MB reduzieren, falls aktuell größer — kleinere Logs füllen sich schneller und switchen häufiger

GCP empfiehlt diese Settings für CDC Use Cases ([Doku](https://cloud.google.com/datastream/docs/work-with-oracle-database-redo-log-files)). Uns ist klar, dass das mehr I/O und Archive Log Volumen bedeutet — daher wäre es gut, deine Einschätzung zu bekommen, ob das auf UAT und später auch PROD machbar ist.

Alternativ prüfen wir auch den neuen "Binary Log Reader" von GCP Datastream (aktuell noch Preview), der direkt die Online Redo Logs lesen kann — also nicht auf die archivierten Logs warten muss. Das würde das Latenz-Problem grundsätzlich lösen, ist aber noch nicht GA. Die Redo Log Tuning-Option wäre der schnellere Hebel.

Am besten erstmal die aktuellen Werte, dann können wir den Impact gemeinsam einschätzen.

VG
Matthias
