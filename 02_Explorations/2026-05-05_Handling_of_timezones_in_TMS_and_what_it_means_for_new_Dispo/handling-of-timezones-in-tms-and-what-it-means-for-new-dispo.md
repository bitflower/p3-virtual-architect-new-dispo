# Handling of Timezones in TMS and What It Means for New Dispo

**Date:** 2026-05-05
**Status:** Exploration

---

<internal>

## Original User Input

> Based on meeting transcript 00_Meetings/2026-04-30_Dispo Blocker_Timezones.vtt and email thread 00_Meetings/2026-04-30_timezones/ — a discussion triggered by timezone discrepancies observed during testing: Bulgarian developers entered 12:00, but 11:00 was stored in the database.

</internal>

---

## Summary

The TMS database stores all timestamps **without timezone information** — both in Oracle (historically) and in the replicated AlloyDB/Postgres. This is not a migration artifact but a **conscious design decision**: timestamps are strongly bound to the address context they belong to, and the local time is considered authoritative. The only exceptions are 4 UTC event fields which carry `TIMESTAMP WITH TIME ZONE` in both Oracle and Postgres.

This creates a new challenge for New Dispo, which is **a single application instance serving all 64 branches** across potentially different timezones — unlike the legacy Uniface system where each client ran on-premise next to its local database, always in sync with the local timezone.

---

## How Timestamps Are Stored in TMS

- Most fields: `TIMESTAMP WITHOUT TIMEZONE` in both Oracle and Postgres — storing **local time** of the context (branch, destination, etc.)
- 4 explicit UTC fields exist in **both Oracle and Postgres** as `TIMESTAMP WITH TIME ZONE`:
  - `SEN_HST.C_UTC`
  - `SEN_HST.EREIGNIS_UTC`
  - `PST_HST.C_UTC`
  - `PST_HST.EREIGNIS_UTC`
- These UTC fields were added because events almost always arise in the context of a Niederlassung, making the timezone easy to determine.
- The timezone is currently pulled from the **database server's settings**.

The following query on `sen_hst` illustrates both types side by side:

![sen_hst timestamp types](sen_hst_timestamp_types.png)
*Source: [Joachim Schreiner, 2026-05-04](feedback_from_joachim.md)*

`c_time` and `ereignis_e` are `timestamp without time zone` (local time), while `c_utc` and `ereignis_utc` are `timestamp with time zone` (showing the `+02` offset for Europe/Berlin in summer).

## Two Categories of Timestamps

| Category | Description | Example | Timezone Relevance |
|---|---|---|---|
| **Action tracking timestamps** | System-generated, recording when something happened | Status change timestamp, record creation timestamp (`COTC`) | Stored in local time of the database server |
| **User-set timestamps / Target times** | Explicitly entered by users or derived from business rules | Pickup time "06:00", delivery time window | Always in **local time of the destination** — must be passed through 1:1 without conversion |

## Why This Matters for New Dispo

| Aspect | Legacy (Uniface) | New Dispo |
|---|---|---|
| Architecture | One client per branch, installed on-premise | One server instance for all 64 branches |
| Timezone sync | Client and database always in same timezone | Server is in cloud timezone, branches may differ |
| Impact | None — always implicitly correct | Timezone mismatch risk when server timezone != branch timezone |

In the legacy world, timezone handling was never an issue because the Uniface client and the Oracle database always ran in the same location. New Dispo breaks this assumption: a single cloud-hosted backend serves branches in Germany, Bulgaria, and potentially other countries — each with its own implicit timezone in the data.

### Observed Behavior

A user in Bulgaria (UTC+3 in summer) entered 12:00. The database stored 11:00 (UTC+2, German summer time). Somewhere in the stack, a timezone conversion occurred — exactly the kind of conversion that **must not happen** for user-set values.

## The Fundamental Rule

> **User-set timestamps must pass through the entire stack (UI -> Backend -> TMS Bridge -> Database) without any timezone conversion.** "What you see is what you get."

## Where Timezone Handling Matters

```
┌─────────────┐     ┌──────────────┐     ┌────────────┐     ┌──────────────┐
│   Browser    │────>│  Dispo       │────>│ TMS Bridge │────>│  AlloyDB /   │
│  (User TZ)   │     │  Backend     │     │            │     │  Oracle      │
│              │     │  (Cloud TZ)  │     │            │     │  (Branch TZ) │
└─────────────┘     └──────────────┘     └────────────┘     └──────────────┘
     ^                    ^                    ^                    ^
     │                    │                    │                    │
  Bulgarian TZ?      europe-west?         passthrough?        implicit local
  German TZ?         UTC?                                     time of branch
```

Three distinct timezone contexts are at play:
1. **Browser/Client** — the user's local timezone (could be anywhere)
2. **Server (Backend)** — the cloud instance timezone (likely UTC or a GCP region timezone)
3. **Database** — the timezone from the database server's settings

### Scenarios to Investigate

1. **User-entered times** (e.g., planning pickup at 06:00): Must arrive in DB as-is. No conversion at any layer.
2. **System-generated timestamps** (e.g., "when was this status change recorded"): Currently stored in the database server's timezone. With a centralized New Dispo server, these would be in the cloud server's timezone unless explicitly handled.
3. **Event ordering / time comparisons**: If events from different branches are compared, the lack of timezone info makes ordering ambiguous.
4. **Daylight saving time transitions**: Germany (CET/CEST) and other countries switch at different dates — a pure offset approach won't suffice.

## Route Calculation Across Timezone Boundaries

Joachim Schreiner identified a concrete impact: **once a transport crosses a timezone boundary, route calculation has a bug.** Target times (e.g., agreed delivery windows) are always given in local time. When calculating travel durations and arrival times, the timezone of the destination must be known.

Current approach: the timezone is passed in the DTO to the PTV XServer.
Proposed improvement: **let the PTV XServer determine the timezone itself** from the address and reference date — this would handle DST transitions correctly.

Note: a timezone-per-branch setting alone won't solve this. Bulgaria, for example, has no Niederlassung, but customers can be delivered there or transport handed to partner carriers there. The timezone is bound to the **destination address**, not to the branch.

## Branch and Destination Timezone Data

- **Branch databases** run in the **local timezone of their location** (not all in German timezone). For German locations: Europe/Berlin.
- Table `ADMIN_NL` contains all branches (Niederlassungen) — replicated as a materialized view via DB Link/FDW on "zentrale". No timezone field exists currently. City/location (`Ort`) is available.
- **Destination timezones** cannot be derived from branch data alone — they depend on the delivery address.
- In Europe, no country has more than one timezone, so timezone could in theory be derived from country code — **except for DST transitions**, which differ by country and date.

---

## Confirmed Answers

| Question | Answer | Source |
|---|---|---|
| Are all branch DBs in German timezone? | **No.** In the local timezone of the location. German locations = Europe/Berlin. | Andrej (meeting), Matthias (email) |
| Is `timestamp without time zone` in Postgres a conscious decision? | **Yes.** Due to strong binding to address context. Decided to continue like Oracle, storing only local time. | Joachim (email) |
| Was timezone info lost during Oracle→Postgres migration? | **No.** It was never there for most fields. The 4 UTC fields are `TIMESTAMP WITH TIME ZONE` in both Oracle and Postgres. | Joachim (email) |
| Is this a Go-Live blocker for branch 1060? | **No.** Branch 1060 is a German location (Europe/Berlin). | Patrick (meeting) |
| Where does the timezone come from currently? | **From the database server's settings.** | Joachim (email) |

---

## Open Items

1. **What timezone does the GCP Cloud Run instance use?** (likely UTC — needs verification)
2. **Which specific flows/fields are affected?** — Needs systematic investigation.
3. **Where in the New Dispo stack does the observed conversion happen?** — Is it the .NET backend (DateTime vs DateTimeOffset), the GraphQL serialization, or the frontend JavaScript Date handling?
4. **How should route calculation handle cross-timezone transports?** — Joachim proposes letting PTV XServer determine timezone from address + reference date instead of passing it in the DTO.

---

## Recommended Next Steps

1. **Trace the timezone handling** through the full stack (Frontend Angular -> Backend .NET -> TMS Bridge GraphQL -> AlloyDB) to find where the observed conversion happens
2. **Define the contract**: all user-set timestamps should be treated as "naive" (no timezone) and passed through without conversion
3. **Classify all timestamp fields** in the relevant TMS tables into "user-set / target times" vs "system-generated" categories
4. **Address route calculation**: evaluate Joachim's proposal to let PTV XServer determine timezone from address + reference date

---

<internal>

## Related Files

- `Code/tms-alloydb-schema` — AlloyDB schema (timestamp field definitions)
- `Code/Disposition-Abstraction-Layer` — TMS Bridge (GraphQL layer, potential conversion point)
- `Code/Disposition-Backend` — .NET Backend (DateTime handling)
- `Code/Disposition-Frontend` — Angular Frontend (JavaScript Date handling)

</internal>
