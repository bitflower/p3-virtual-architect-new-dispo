# Email Response to Matt Wilkinson

**Date:** 2026-03-13
**Subject:** Re: Oracle CDC Kick-Off Follow-up

---

Hi Matt,

Quick update on our side:

**✅ Completed:**
- GCP storage buckets created:
  - `oracle-striim-bucket-poc`
  - `oracle-datastream-bucket-poc`
- Datastream instance provisioned: `new-dispo-oracle-cdc-datastream-sendung`
- Environment: TEST / WL5
- All temporary for POC only

**Documentation Link:**
Yes, the Datastream for Oracle documentation you shared is correct. We'll be following that guide for the Datastream POC setup.

**Workshop Scheduled:**
Martin has scheduled the follow-up for Monday, March 16, 2026 from 14:30-15:00.

**Current Status:**
We're ready from the GCP side. Now waiting on:
- Database selection confirmation (1034, 1060 or others?)
- Oracle prerequisites:
  - ARCHIVELOG mode verification
  - Supplemental logging configuration
  - CDC user setup with required grants
  - LogMiner setup for Datastream
- Character set compatibility investigation results

**Open Questions:**
- Which specific databases are confirmed for the POCs?
- Timeline for Oracle-side configuration?
- DBA availability for setup and testing?
- For the load test: How do we execute the order duplication from OMS to on-prem Oracle? Do we need VM provisioning or will this be coordinated with the DBA team?

**Communication Channel:**
We can use whatever works best for you - Teams group chat, email thread, or dedicated channel. Let us know your preference.

**Target Timeline:**
If database availability and Oracle prerequisites can be completed before Monday's workshop, we can move quickly on the manual confirmation. Once that's validated, we're ready for the week-long load test starting next Wednesday as suggested.

Let me know if you need anything else from our side.

Cheers,
Matthias

---

**Attachments/References:**
- Detailed pending items summary: `2026-03-13_pending-items-summary.md`
- P3 preparations: `2026-03-13_preparations-done-on-p3-side.md`
