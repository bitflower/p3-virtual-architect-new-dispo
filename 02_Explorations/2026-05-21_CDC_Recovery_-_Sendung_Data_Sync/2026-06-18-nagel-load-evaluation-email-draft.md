# Email Draft: TMS Database Load — CDC Recovery Mechanism

**To:** Joachim Christian, Matt Wilkinson
**From:** Matthias Max
**Subject:** CDC Recovery — TMS database load profile, quick heads-up
**Attachment:** ADR-010 — CDC Recovery Strategy: Sendung Data Sync

---

Hi Joachim, hi Christian, hi Matt,

quick heads-up — we're building a recovery mechanism for the CDC pipeline that syncs shipment data directly from TMS when Datastream/Striim has an outage.

**What does it do to TMS?**
Per branch, per recovery run, we execute exactly **two queries**:

1. `SELECT` shipment IDs (unplanned shipments only) — for detecting deletions
2. `SELECT` full shipment rows `WHERE u_time > [watermark]` — for syncing inserts/updates

That's it. No writes, no schema changes, no new objects. The watermark limits the query to the outage window, so it's not a full table scan. Both queries go through the same CDC resolver system.

**How often does this run?**
Only when someone (service desk, operations, DevOps, or a developer) manually triggers it after a CDC outage. Not a background job, not continuous polling. Think: once in a while, when something breaks.

We reviewed this in the team yesterday and explicitly decided against rate limiting or batching — given it's a one-time recovery action, that would be premature optimization. The team's PoC showed ~20 seconds end-to-end for a full branch sync with all shipments — that includes our own processing and writes, so the actual time spent querying TMS is a fraction of that.

**What I need from you:**
Just a quick confirmation that these two read-only queries per branch are fine from your side. If there are any constraints or time windows we should be aware of (e.g., "don't run this during nightly batch jobs"), let me know. If I don't hear back within 3 days, I'll consider it confirmed.

I've attached the ADR with the full technical context if you want the details.

Cheers,
Matthias
