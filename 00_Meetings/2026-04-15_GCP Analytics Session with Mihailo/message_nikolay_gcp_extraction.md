# Teams Message to Nikolay Hristov — GCP Datastream Artifact Extraction

**Context:** We need comprehensive GCP metrics, logs, and data for the Oracle CDC POC analysis covering two Datastream streams.

---

Hi Nikolay,

Here's the full list of what I need from GCP for the Datastream CDC POC analysis. Two streams, two time ranges:

**Stream 1: Datastream → WL3 Bucket**
- Time range: **2026-03-26 to 2026-04-09**

**Stream 2: Datastream → WL5 Bucket** (`orauat-1060-bucket`)
- Time range: **2026-03-30 to 2026-04-09**

For **each stream**, I need the following:

---

### 1. Metrics from Metrics Explorer (Cloud Monitoring)

Export as CSV from Metrics Explorer. Resource type: `Datastream Stream` (`datastream.googleapis.com/Stream`).

| # | Metric | Aggregation | Notes |
|---|--------|-------------|-------|
| 1 | `stream/event_count` | SUM, grouped by read_method | Total CDC events processed |
| 2 | `stream/total_latencies` | p50, p95, p99 (separate exports) | End-to-end latency: DB change → GCS object |
| 3 | `stream/system_latencies` | p50, p95, p99 (separate exports) | Datastream processing: read → write |
| 4 | `stream/freshness` | MEAN | Time between source commit and Datastream read |
| 5 | `stream/latencies` | p50, p95, p99 (separate exports) | Stream latency |

**How to export:** In Metrics Explorer, select the metric, set the time range, click the three-dot menu (⋮) on the chart → "Download CSV". Each percentile (p50/p95/p99) needs a separate CSV export.

**Important:** Set the alignment period to **1 minute** (or the smallest available) for maximum granularity. Default 1-hour alignment hides latency spikes.

---

### 2. CDC Activity Logs (Cloud Logging)

Go to **Logs Explorer** and run this filter:

```
resource.type="datastream.googleapis.com/Stream"
jsonPayload.message:"writing"
```

Filter by each stream separately, using the full time range. Export as **JSON** (not CSV — the JSON contains the full payload with record counts).

If the export is too large, split by week:
- Week 1: Mar 26 – Apr 02
- Week 2: Apr 02 – Apr 09

These logs contain the actual CDC write events with record counts per batch — critical for delivery rate and throughput analysis.

---

### 3. Stream Error / Warning Logs

Same Logs Explorer, but filter for errors:

```
resource.type="datastream.googleapis.com/Stream"
severity>=WARNING
```

Export as JSON for each stream, full time range.

---

### 4. Stream Configuration

For each stream, go to **Datastream → Streams → [stream name]** and screenshot or export:
- Stream details (source, destination, tables)
- **CDC method** (LogMiner or Binary Log Reader)
- `maxConcurrentCdcTasks` setting
- Any custom configurations
- **Built-in throughput chart** on the stream detail page — set the time range to the full POC period before screenshotting. (Latency is not shown on this page, only in Metrics Explorer)

---

### 5. GCS Bucket Object Listing (optional but helpful)

If feasible, a listing of the CDC output objects in each bucket with timestamps:

```bash
# WL5 bucket:
gsutil ls -rl gs://tms-alloydb-datastream-bucket-wl5-t-t/UATDataStream/TMS1060_SENDUNG/2026/** > wl5_bucket_listing.txt

# WL3 bucket (adjust path accordingly):
gsutil ls -rl gs://[wl3-bucket-name]/[path]/2026/** > wl3_bucket_listing.txt

# Alternative (gcloud storage is the newer replacement for gsutil):
gcloud storage ls -rl gs://tms-alloydb-datastream-bucket-wl5-t-t/UATDataStream/TMS1060_SENDUNG/2026/** > wl5_bucket_listing.txt
```

The bucket has a nested folder structure (year/month/day/hour). The `**` glob recurses through all levels. Pipe to a file since it'll be a long listing. This helps verify actual file creation timestamps against the metrics.

---

### Summary checklist

| Item | WL3 Stream | WL5 Stream |
|------|:---:|:---:|
| event_count CSV | ☐ | ☐ |
| total_latencies CSVs (p50/p95/p99) | ☐ | ☐ |
| system_latencies CSVs (p50/p95/p99) | ☐ | ☐ |
| freshness CSV | ☐ | ☐ |
| stream latencies CSVs (p50/p95/p99) | ☐ | ☐ |
| CDC activity logs (JSON) | ☐ | ☐ |
| Error/warning logs (JSON) | ☐ | ☐ |
| Stream configuration screenshots | ☐ | ☐ |
| GCS bucket listing (optional) | ☐ | ☐ |

That's ~18 CSV files + 4 JSON exports + 2 screenshots per stream. If you can get me the CSVs and logs, we might not even need the meeting — I can run the full analysis from these.

Let me know if anything is unclear or if you run into access issues.

Thanks,
Matthias
