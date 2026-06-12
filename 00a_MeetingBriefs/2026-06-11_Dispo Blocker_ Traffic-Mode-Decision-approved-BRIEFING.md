# Meeting Briefing: Dispo Blocker — Traffic Mode Decision (approved)

**Date:** 2026-06-11
**Participants:** Matthias Max, Maximilian Kehder, Uschmann Patrick, Joachim Schreiner
**Duration:** ~48 min

---

## Topics Discussed

1. **Traffic Mode Document — Option C finalized.** Joachim had no additional context to add (no time for Reinhard consultation). Decision: proceed with Option C — block Traffic Mode changes in UI/CNS once a Leg is dispatched. Matthias to add Option C and finalize the document.

2. **Datastream/Postgres standstill & Database Health Toolchain.** Another Datastream outage caused by a runaway job blocking everything — replication slot grew to 274 GB. Matthias explained the planned database-based monitoring approach: pull replication slot size with threshold alerts for early detection. Also investigating if AlloyDB/GCP provides native metrics. Joachim is not involved in this area.

3. **Postgres Views missing/inconsistent.** Recurring issue: Sonja deploys views, next day they're reported missing. Not an Oracle↔Postgres sync issue — happens within Postgres/AlloyDB itself. Matt (DB team) is investigating. Very random and hard to pin down.

4. **Database Health Toolchain — Completeness Checks.** Building a toolchain to verify "Vollständigkeit" of new and existing database instances. If a field is missing that a UI flow needs, no point sending someone to test — saves effort.

5. **Oracle Migration — Tour Calculation Writeback.** Joachim is finishing the last migration: a package to write calculated tour data (XServer DTO) back into Oracle. Much code was Postgres-specific (JSON handling), needed Oracle adaptation. Will finish today — then all migrations are complete.

6. **Fernverkehr Timeslot Display Bug.** Patrick found that arrival time and timeslot values display incorrectly in Fernverkehr. Joachim suspects historical reasons, needs to investigate.

7. **Grobavise Testing.** Test with Grobavise is running. Important change: preventing provisional Sendungen in Vorlauf. New Dispo UI currently can't show Grobavise (ignores Sendungstyp A and T), so Joachim will test via scripts. Maximilian to provide New Dispo access for ABN 1060 so Joachim/QS can also test at the UI level later.

8. **Oracle End-to-End Test — Next Week.** Joachim cancels his vacation (next week) to do intensive Oracle compatibility testing in ABN 1060. Goal: test Grobavise, tour data writeback, and Fernverkehr behavior end-to-end.

9. **PDF Mappings — Ladehilfsmittel.** Open mappings for loading aids on the PDF. Joachim says a view already exists (communicated weeks ago). Maximilian and Patrick will review the PDF current state tomorrow. Not a priority for Go-Live.

10. **Verkehrsstrom 31 Clarification.** Matthias had raised a question about Traffic Mode 31 last week. Joachim clarified with Reinhard: 31/32 is normal Sammelgut, same as Traffic Mode 3. NOT Relationsverladung. Can be marked as resolved in the document.

11. **Traffic Mode 3 / Relationsverladung — Deep Dive.** Whether Traffic Mode 3 (Sammelgut + no precarriage / "no Vorholung") generates a Hauptlauf-Leg from sender to receiving depot. New Dispo already generates Hauptlauf-Legs, but this was never tested end-to-end in the Fernverkehr. Joachim: "No-go" to go live with Hauptlauf-Legs without testing whole-system behavior. Patrick will generate test data; Joachim will verify in Fernverkehrsdisposition.

12. **Traffic Mode Lock Rules (Detail).** Once a Hauptlauf-Leg is dispatched: Traffic Mode is completely locked. If only a Vorlauf-Leg is dispatched: switching between 2↔4 is allowed (both have Vorlauf, no impact). Between 1↔3 is allowed (Pickup only, no Vorlauf-Leg). This is a temporary solution but safe for launch. Maximilian confirmed this works.

## Decisions Made

- **Option C approved** for Traffic Mode handling — block Traffic Mode changes when any Leg is dispatched. Matthias to finalize the document.
- **Verkehrsstrom 31 is NOT Relationsverladung** — normal Sammelgut like 3. Mark as resolved in the document.
- **Traffic Mode lock rules agreed:** Full lock when Hauptlauf-Leg dispatched; 2↔4 switch allowed when only Vorlauf dispatched. Temporary solution, safe for Go-Live.
- **ABN 1060 environment:** Only bugfixes, no new view changes. Postgres stand is fully synced.
- **Joachim cancels vacation** next week to run Oracle tests in ABN 1060.
- **Hauptlauf-Leg generation must be tested end-to-end** before going live — no-go without verifying behavior in Fernverkehrsdisposition.

## Action Items for Matthias

| # | Action | Context | Urgency |
|---|--------|---------|---------|
| 1 | Update Traffic Mode document: add Option C, mark Verkehrsstrom 31 as resolved (not Relationsverladung) | Traffic Mode decision finalized, document needs to reflect agreed approach | High |
| 2 | Continue Database Health Toolchain (replication slot monitoring, completeness checks) | Recurring Datastream outages; also investigating native GCP/AlloyDB metrics as Plan B | Medium |

## Action Items for Others

| Owner | Action | Context |
|-------|--------|---------|
| Joachim | Finish Oracle migration for tour calculation writeback (XServer DTO) | Last remaining migration — target: today (2026-06-11) |
| Joachim | Test Traffic Mode 3 / Relationsverladung behavior in Fernverkehr | Unclear if Fernverkehr generates correct Leg for "no Vorholung" case |
| Joachim | Cancel vacation, start intensive Oracle testing next week in ABN 1060 | End-to-end compatibility testing needed before Go-Live |
| Patrick | Generate test data for Relationsverladung / Traffic Mode 3 | Verify how transport orders behave in Fernverkehr |
| Patrick | Verify with Max whether Traffic Mode 3 is correctly aligned | Open question on Relationsverladung handling |
| Maximilian | Provide Joachim New Dispo access credentials for ABN 1060 | So Joachim/QS can test at UI level |
| Maximilian + Patrick | Review PDF current state for open Ladehilfsmittel mappings | Tomorrow (2026-06-12), not Go-Live priority |

## Topics Needing Matthias's Attention

- **Hauptlauf-Leg end-to-end test is a Go-Live blocker.** Joachim was explicit: "No-go" without testing how Hauptlauf-Legs from New Dispo behave in the full Fernverkehr process. This needs to be tracked.
- **Postgres view disappearance issue** remains unresolved and unpredictable. Matt (DB team) is investigating, but no root cause yet. The Database Health Toolchain completeness checks may help catch these earlier.
- **Fernverkehr timeslot display bug** — Joachim needs to investigate, may have deeper implications for data correctness in long-distance dispatching.

## Open Questions

- Does Traffic Mode 3 (Sammelgut + no Vorholung) generate a Hauptlauf-Leg that can be processed correctly in the Fernverkehrsdisposition? (Joachim + Patrick to verify)
- Root cause of Postgres views disappearing after deployment? (Matt investigating)
- Can AlloyDB/GCP natively expose replication slot size metrics without custom implementation? (Matthias investigating as Plan B)

## Transcript Quality

Moderate. The transcript is auto-generated from a primarily German meeting with frequent German/English code-switching. Domain terms like "Grobavise", "Verkehrsart/Verkehrsstrom", "Vorlauf/Hauptlauf-Leg" are often garbled. Speaker attribution is reliable. The first ~2 minutes are mostly joining noise. The substantive discussion from ~03:40 onward is interpretable with domain knowledge, though some technical details around Traffic Mode numbers (30, 31, 32) required careful cross-referencing across utterances. The Relationsverladung discussion (~26:00–32:00) is the densest section with the most noise.

---

<div align="center">
  <sub>Created by <strong>Virtual Architect</strong></sub>
</div>
