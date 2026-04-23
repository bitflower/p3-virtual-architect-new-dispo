## Subject

Oracle CDC — Status Update (CW 17)

## Body

Hi all,

Quick update on where we stand with the Oracle CDC solution.

**Key Decision (April 21):**
Datastream with LogMiner is off the table. The ~42-66 min end-to-end latency from archived redo logs is not acceptable — we need events in real time.

**Two options remain:**
- **Option A: Datastream Binary Log Reader** — reads redo logs directly (like Striim), but currently GCP Preview only. Not yet available to Nagel
- **Option B: Striim** — proven sub-second latency, currently free under borrowed Google license. Long-term cost: ~EUR 11,671/mo at 64 databases (vs. Datastream ~EUR 344/mo)

**Blocker:**
Matt Wilkinson is escalating to the Google account manager to request Binary Log Reader activation (trusted tester / Preview access). Expected answer by **April 25**. This determines our path forward.

**Parallel tracks running:**
- Oracle view conversion — Andrej/Reinhard working on Postgres-to-Oracle migration (some views blocked by missing packages)
- Infrastructure skeleton check — Nikolay/P3 verifying all GCP environments (dev/test/UAT/prod)
- DB user permissions — Yosif documenting required objects for least-privilege grants (separate users for CDC vs. application)
- VDI access for P3 developers — Ron investigating

**Pending Actions:**

| What | Owner | ETA |
|---|---|---|
| Binary Log Reader escalation to Google | Matt Wilkinson (Nagel) | April 25 |
| Striim event format mapping vs. TMS Pulse | Matthias Max (P3/CAL) | TBD |
| Oracle view conversion & testing | Andrej/Reinhard (Nagel) | Ongoing |
| Infrastructure skeleton check (all envs) | Nikolay (P3) | TBD |
| DB user permissions spec (least-privilege) | Yosif (P3) + Nagel DBA | TBD |
| VDI access for 7 P3 developers | Ron (Nagel) | TBD |
| Striim license extension request | Matt Wilkinson (Nagel) | Submitted |
| ADR-006 closure with final decision | Matthias Max (P3/CAL) | Post Google response |

**Next Steps:**
1. Google response on Binary Log Reader → decides technology path
2. If available: retest Datastream with binary reader against same Oracle source
3. If unavailable: proceed with Striim for go-live, initiate license negotiation
4. Close ADR-006 with final decision

**Go-Live target remains June 2026.**

Questions? Ping me or drop them in the Teams chat.

**Full project status:**
https://dev.azure.com/p3ds/Nagel-CAL%20Disposition/_wiki/wikis/Nagel-CAL-Disposition.wiki/15844/GoLive%2D1060%2DOracle

Thanks!
Matthias

---

<div align="center">
  <sub>Created by <strong>Virtual Architect</strong></sub>
</div>
