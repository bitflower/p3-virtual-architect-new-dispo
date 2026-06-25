# Draft email — Matt Wilkinson (Striim): lower GCS Writer upload interval

**To:** Matt Wilkinson (Nagel IT — Striim)
**Cc:** Nikolay Hristov, Christian Lang, Thomas Paulus
**Subject:** New Dispo CDC (Striim → GCS): lower the GCS Writer upload interval — abn1060 latency

---

Hi Matt,

We analysed the "~2 minute delay" between a change in **abn1060** (Oracle `SENDUNG`) and the event arriving in the CDC bucket, and traced it to a single cause: the **Striim GCS Writer `uploadpolicy` interval**, which is currently **5 minutes**. At ABN's volume the event-count threshold is essentially never reached, so every change waits for the next 5-minute flush boundary before its object is written. Striim's redo capture is sub-second — the network and the database are **not** the bottleneck; the wait is purely the file rollover.

**Evidence (measured 2026-06-25, from the bucket `wl5-cdc-bucket-abn1060/striim/cdc/`):**

- Objects land on an exact **5-minute grid** (smallest gap between objects = 300 s, never less).
- Passive sample of today's changes: **median 2.9 min**, up to 4.3 min.
- Controlled test — a shipment created via the New Dispo app (`SENDUNG_N 839941`): committed **09:19:07**, appeared in the bucket **09:22:51** → **3 min 44 s**, of which **222 s was pure waiting** for the 5-minute boundary (≈2 s was the actual write).

**Request:** lower the GCS Writer `uploadpolicy` **interval** on the abn1060 stream. Two targets:

| Option | interval | mean latency | worst case |
|---|---|---|---|
| A (conservative) | **30 s** | ~15 s | 30 s |
| B (aggressive — preferred to trial) | **10 s** | ~5 s | 10 s |

Please **keep an `eventcount` ceiling** alongside the interval so high-volume bursts still flush promptly on count — only the time interval needs to change.

**Proposed approach: trial 10 s in ABN first and measure, before UAT/PROD.** We'd like to verify it doesn't make Striim "work harder" in any way that matters. Our expectation, to be confirmed by the trial:

- **Core CDC work is unchanged.** Redo reading/parsing scales with the *database change volume*, not with how often we flush — so the Oracle-side mining load is identical at 5 m, 30 s, or 10 s.
- The only added work is on the **target writer**: more frequent, smaller uploads (more GCS object finalizes) and correspondingly more `filter-shipment-function` invocations. Empty windows are skipped (no events → no file), so at ABN volume the increase is modest.

**What we'll measure during the 10 s trial (ABN):**

- **Striim:** CPU / memory on the Striim server, and the GCS Writer metrics — *External I/O Latency*, *Last I/O Size*, *Total Events In Last Upload* — plus any sign of writer backpressure.
- **GCS:** object-creation / write-operation rate.
- **Consumer:** `filter-shipment-function` invocation rate, duration, errors, cold starts.
- **End-to-end latency:** re-run the same measurement to confirm the improvement.

If the 10 s trial is clean we roll it to **UAT (`wl5-cdc-bucket-uat1060`)** and **PROD (`wl5-cdc-bucket-1060`)** for go-live; if anything looks stressed we fall back to 30 s, which already gives a 10× improvement.

**Two cheap hardening items** the analysis surfaced (independent of the interval, but more relevant once we produce many more, smaller files):

1. **Object names are counter-only** (`…/cdc/wl5-cdc-bucket-abn1060.NN`, no timestamp). Per Striim's own docs this risks overwrite/data loss if the writer ever restarts and the counter resets. Adding a timestamp or sequence to the object name removes that risk.
2. **No GCS lifecycle policy** on the CDC buckets → unbounded growth. A short age-based rule (after we confirm replay/retention needs) keeps storage and bucket-listing performance in check.

Could we also confirm the **current `uploadpolicy`** values (interval + eventcount/filesize) for abn1060, and whether UAT and PROD use the same? Happy to pair on the change and run the measurement together.

Thanks,
Matthias

---

*Backing analysis: `02_Explorations/2026-06-24_Striim_CDC_latency_between_abn1060_Oracle_and_GCP_bucket…/` (Virtual Architect — New Dispo).*
