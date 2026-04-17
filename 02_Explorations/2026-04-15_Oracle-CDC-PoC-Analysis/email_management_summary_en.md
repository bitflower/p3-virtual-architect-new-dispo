# Email - CDC POC Analysis: Results and Options

**To:** [Recipients]  
**Subject:** Oracle CDC POC - Datastream Analysis (UAT1060) + Options  
**Attachment:** full_poc_report.md

---

Hi all,

please find attached the full analysis of the CDC POC with GCP Datastream on UAT1060 (TMS1060_SENDUNG). The data covers March 30 to April 9 - approx. 75,000 replicated records over 10 days.

**Summary:**

Striim works reliably and fast. Datastream works reliably too - 100% delivery rate, zero errors. The problem is latency: on average **~42 minutes** from DB change to GCS object. This is far outside the range business expects.

For comparison: Striim delivers an end-to-end latency of **~0.1 seconds** (~100ms, constant) on the same Oracle source. Why this difference exists and what the architectural root cause is, is explained in detail in the report (section "Datastream vs. Striim").

**Root cause:**

99.4% of the latency is **not** caused by Datastream processing (~16 seconds), but by waiting for Oracle's archived redo logs. Datastream (LogMiner method, GA) can only read once Oracle has archived the redo log - and that currently only happens when the 1 GB log is full. No time-based trigger (`ARCHIVE_LAG_TARGET = 0`). GCP sent us **130 warnings** throughout the entire POC that the redo logs are too large.

**Three options:**

|     | Option                                                                                                              | Expected Latency | Effort                            | Additional GCP Cost        |
| --- | ------------------------------------------------------------------------------------------------------------------- | ---------------- | --------------------------------- | -------------------------- |
| 1   | **Oracle Redo Log Tuning** - set ARCHIVE_LAG_TARGET (e.g. 5-15 min) + reduce log size from 1 GB to 256 MB          | 5-20 min         | Low (DBA)                         | None                       |
| 2   | **Datastream Binary Log Reader** - reads online redo logs directly, no waiting for archival                         | 1-5 min          | Medium                            | None (same per-GiB price)  |
| 3   | **Striim** - reads online redo logs in real-time, already running in POC                                            | Sub-second       | Low (technical), license cost     | N/A                        |

**Recommendation:**

Even though Striim is clearly ahead on latency: Datastream as a managed GCP service is massively cheaper. From ADR-006 (projection for 64 databases):

|               | Datastream | Striim (with license)* | Factor |
| ------------- | ---------- | ---------------------- | ------ |
| **Per month** | EUR 344    | EUR 11,671*            | 34x    |
| **Per year**  | EUR 4,124  | EUR 140,048*           | 34x    |

\* Striim costs are based on a shared cluster with "Pretzel" - actual costs after Pretzel shutdown still to be verified (see open items).

In my view it's worth running a second POC with the mentioned Oracle optimizations to see how close we can get with Datastream to the business requirements - before accepting the Striim license costs as a given.

Starting with Option 1 - low effort. Then we'll see if the achieved latency is sufficient or if we need Option 2/3.

**Open items:**
- Plan a sync meeting to discuss the way forward @Martin Dittmann
- Robert: Confirm Oracle version on UAT1060, assess feasibility of redo log tuning (including more aggressive values like 5 or 10 min)
- Team: Define target latency - what is acceptable for the CDC use case?
- Business: Align with the business side based on the new numbers - both latency (0.1s vs. 5-20 min) and cost implications (EUR 4K vs. EUR 140K/year). What is the acceptable trade-off?
- Striim costs: Verify actual Striim costs - the EUR 2,771/month compute costs are currently shared with the "Pretzel" cluster. What do the actual Striim costs look like once Pretzel is shut down?
- GCP: Binary Log Reader is still Preview (no SLA) - clarify GA timeline

The full report with all charts, metrics and details is attached.

Best,
Matthias
