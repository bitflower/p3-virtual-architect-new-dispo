# Follow-Up Email — Robert Zanter, POC-Zeitraum Log Switch Daten

**To:** Robert Zanter  
**Subject:** RE: Oracle CDC: Konfigurationspotentiale

---

Hallo Robert,

erstmal danke für die schnelle Reaktion — die Daten waren genau das, was wir gebraucht haben. Die Redo Log Konfiguration (1 GB, ARCHIVE_LAG_TARGET=0) erklärt sehr gut, warum wir bei Datastream diese Latenzen sehen.

Eine Sache ist uns aufgefallen: das SQL mit `SYSDATE - 3` hat uns nur Daten vom 13.-16. April geliefert. Der eigentliche POC-Zeitraum war aber **30. März bis 2. April** — da lief der Datastream Test auf TMS1060_SENDUNG.

Könntest du das gleiche Query nochmal mit einem breiteren Zeitraum laufen lassen?

```sql
SELECT TO_CHAR(first_time, 'YYYY-MM-DD HH24:MI') AS switch_time,
       sequence#,
       ROUND((next_time - first_time) * 24 * 60, 1) AS duration_min
FROM v$archived_log
WHERE first_time BETWEEN TO_DATE('2026-03-28', 'YYYY-MM-DD')
                      AND TO_DATE('2026-04-03', 'YYYY-MM-DD')
ORDER BY first_time;
```

Damit können wir die Log Switch Frequenz direkt mit den Datastream Latenz-Daten aus dem gleichen Zeitraum korrelieren. Besonders interessant für uns: wie verhalten sich die Switches über das Wochenende (30./31. März), wo vermutlich weniger Last auf der DB war.

Falls `v$archived_log` nicht so weit zurückreicht — gibt es alternativ die Daten in der Alert Log oder einem ähnlichen historischen View?

VG
Matthias
