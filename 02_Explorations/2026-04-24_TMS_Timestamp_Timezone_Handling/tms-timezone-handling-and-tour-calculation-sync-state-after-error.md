# TMS Timestamp Timezone Handling

**Date:** 2026-04-24
**Status:** Exploration
**Source:** Meeting Boyan Valchev + Matthias Max (2026-04-24), Teams chat with Joachim Schreiner (2026-04-09)

---

## Original User Input

The `u_time` column (and all timestamp fields) in TMS are stored as `timestamp without time zone` in AlloyDB/Postgres. Oracle stores them as `TIMESTAMP WITH TIME ZONE` (Joachim Schreiner). In AlloyDB the timezone information is not present. New Dispo accesses multiple branches that could potentially be in different timezones.

---

## Context

The TMS database uses `timestamp without time zone` for all date/time columns in AlloyDB/Postgres views. The column in question is `u_time` (update time — the time when the record was last updated), found in the `sendung` (sandbox) table and related views (subquery aliased as `TPP`).

## Confirmed Facts (Joachim Schreiner, 2026-04-09, Teams Chat)

From Teams chat (Maximilian Kehder asking, Joachim Schreiner confirming):

1. **All timestamps in TMS are stored in local time** (i.e., the local time of the branch)
2. **4 exceptions** are stored in UTC:
   - `SEN_HST.EREIGNIS_UTC`
   - `SEN_HST_C_UTC`
   - `PST_HST.EREIGNIS_UTC`
   - (presumably `PST_HST_C_UTC`)
3. **Oracle stores as `TIMESTAMP WITH TIME ZONE`** (Joachim: "Wir speichern das in ORA als TIMESTAMP WITH TIME ZONE")

## Observation (Boyan's Test)

- Action executed at 12:00 Bulgarian time (UTC+3 / EEST)
- `u_time` saved as 11:00 in the database
- Conclusion: the database stores in German time (UTC+2 / CEST during summer, UTC+1 / CET during winter)

## Problem Statement

Since AlloyDB stores `timestamp without time zone`, the New Dispo system cannot programmatically determine which timezone these timestamps represent. The team's **assumption** is that all databases store in German timezone (Europe/Berlin), but:

- This is unconfirmed for all branches
- Different branches could theoretically be hosted in different timezones
- The old TMS desktop client didn't need timezone flexibility because all clients ran on the same physical network, in the same city

## Historical Hypothesis (Matthias Max)

In the old TMS world, all desktop clients ran on the same physical network, in the same location. There was no need for timezone awareness. With New Dispo accessing multiple branches potentially in different timezones, this becomes a real issue.

## What Needs Clarification

| # | Question | Owner | Status |
|---|----------|-------|--------|
| 1 | Are **all** branch databases hosted in German timezone? | Matthias → Nagel (Andre/Reinhardt/Joachim) | **Open** |
| 2 | For branch 1060 specifically: what timezone does the database use? | Matthias → Nagel | **Open** |
| 3 | Is the `timestamp without time zone` an intentional design decision or an oversight in the Postgres schema? | Matthias → Nagel | **Open** |
| 4 | Where exactly does the timezone information get lost between Oracle (`TIMESTAMP WITH TIME ZONE`) and AlloyDB (`timestamp without time zone`)? | Open | **Open** |

## Possible Solution Direction

If timezone information is not available in the database, store the branch timezone as configuration:
- Per-branch timezone info in the key/secret manager or tenant configuration
- Apply timezone offset when parsing `timestamp without time zone` values

## Related Files

- `00_Meetings/2026-04-09_timezone/` — source meeting folder
- `00_Meetings/2026-04-09_timezone/image.png` — Teams chat confirming Joachim's timezone statement
- `00_Meetings/2026-04-09_timezone/info-from-boyan.md` — ticket links from Boyan
