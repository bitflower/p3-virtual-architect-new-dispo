---
name: check-datastream
description: Check GCP Datastream health via gcloud CLI. Verifies stream state, CDC checkpoint progression, GCS bucket activity, and error logs. Use when the user wants to check Datastream status, CDC pipeline cloud side, or bucket activity.
allowed-tools: Bash,Read
---

# Check Datastream Skill

Runs all Google Cloud-side health checks for the Datastream CDC pipeline via gcloud and gsutil.

## When to Use

- User asks to "check datastream", "check stream status", "check CDC cloud side", "check bucket"
- When investigating why CDC events aren't arriving
- Routine health check of the CDC pipeline cloud layer

## Arguments

The skill accepts an optional stream argument:

- `/check-datastream` — checks **all streams** (default)
- `/check-datastream abn1034` — checks only the abn1034 stream
- `/check-datastream oracle` — checks only the Oracle stream

## Known Streams

| Stream ID | Source | Bucket | Type |
|-----------|--------|--------|------|
| `new-dispo-cdc-datastream-sendung-abn1034` | AlloyDB abn1034 → `sendung` | `abn1043-sendung-bucket-1` | AlloyDB CDC |
| `new-dispo-cdc-datastream-sendung-abn2820` | AlloyDB abn2820 → `sendung` | (check profile) | AlloyDB CDC |
| `orauat-1060-bucket` | Oracle TMS1060 → `SENDUNG` | (check profile) | Oracle CDC |

## GCP Context

- **Project:** `prj-cal-w-wl5-t-6c00-53ad`
- **Region:** `europe-west3`

## Execution Steps

### Step 0: Verify gcloud Auth

```bash
gcloud config get-value project
```

If not `prj-cal-w-wl5-t-6c00-53ad`, run:
```bash
gcloud config set project prj-cal-w-wl5-t-6c00-53ad
```

If auth is expired, tell the user to run `! gcloud auth login` in the prompt.

### Step 1: Stream State Overview

```bash
gcloud datastream streams list --location=europe-west3 \
  --format="table(name.basename(), state, displayName)"
```

**IMPORTANT:** `RUNNING` does NOT mean healthy. The June 8 incident proved Datastream can report RUNNING while silently stalled. This check only catches streams that are `PAUSED`, `NOT_STARTED`, or `FAILED`.

### Step 2: CDC Checkpoint Progression (Silent Stall Detection)

This is the most critical check. Datastream logs the current LSN and event timestamp every minute. If these values are frozen across entries, the stream is silently stalled.

For each RUNNING AlloyDB stream:

```bash
gcloud logging read \
  'resource.type="datastream.googleapis.com/Stream"
   resource.labels.stream_id="<STREAM_ID>"
   jsonPayload.message:"CDC checkpointed"' \
  --project=prj-cal-w-wl5-t-6c00-53ad \
  --limit=5 \
  --format="table(timestamp, jsonPayload.message)" \
  --freshness=2h
```

**Assessment:**
- Extract the log sequence number and event timestamp from each "CDC checkpointed" message
- If both values are **identical** across 3+ entries spanning > 5 minutes → **STALL DETECTED**
- If values are **advancing** → stream is healthy
- If **no log entries** returned with `--freshness=2h` → expand to `--freshness=24h`. The stream may write checkpoints sporadically if the source table has infrequent changes. If still empty → stream may be down or logging is broken

### Step 3: Error Logs

```bash
gcloud logging read \
  'resource.type="datastream.googleapis.com/Stream"
   severity>=WARNING' \
  --project=prj-cal-w-wl5-t-6c00-53ad \
  --limit=10 \
  --format="table(timestamp, severity, resource.labels.stream_id, jsonPayload.message)" \
  --freshness=24h
```

Note: Silent stalls produce NO errors. This check catches other issues (connection failures, oversized logs, schema problems).

### Step 4: GCS Bucket Activity

For each stream, check recent writes to the destination bucket:

```bash
gsutil ls -l "gs://abn1043-sendung-bucket-1/tms1034_sendung/" | tail -10
```

For a time-windowed check (current hour):
```bash
gsutil ls -l "gs://abn1043-sendung-bucket-1/tms1034_sendung/$(date -u +%Y/%m/%d/%H)/" 2>/dev/null || echo "No files this hour"
```

**Assessment:**
- Files appearing regularly → stream is writing
- No files for > 5 minutes with source activity → possible stall
- No files for > 1 hour → likely stalled or paused

### Step 5: Private Connection State

```bash
gcloud datastream private-connections list --location=europe-west3 \
  --format="table(name.basename(), state, displayName)"
```

Expected: All in `CREATED` state. Any other state = connectivity problem.

## Output Format

After running all checks, produce a structured summary:

```
Datastream Health — GCP Cloud Side
====================================
Project: prj-cal-w-wl5-t-6c00-53ad
Region:  europe-west3
Checked: <timestamp>

Stream: new-dispo-cdc-datastream-sendung-abn1034
  State:            <RUNNING/PAUSED/...>     <INFO — see CDC check>
  CDC Checkpoint:   <advancing/frozen/none>  <PASS/FAIL/UNKNOWN>
    Last LSN:       <value>
    Last Event:     <timestamp>
    Entries Span:   <time range of checked entries>
  Bucket Activity:  <last file timestamp>    <PASS/WARN/FAIL>
  Recent Errors:    <count or "none">

Stream: orauat-1060-bucket
  State:            <RUNNING/PAUSED/...>
  Recent Errors:    <count or "none">

Private Connections:
  datastream-connectivity-wl5-t-t:  <state>  <PASS if CREATED>
  psc-datastream-t-wl5:            <state>  <PASS if CREATED>

Overall: <HEALTHY / WARNING / CRITICAL>
```

Severity rules:
- **HEALTHY**: All streams in expected state, CDC checkpoints advancing, bucket receiving files, no errors
- **WARNING**: CDC checkpoint frozen < 30 min, OR bucket inactive < 1 hour, OR non-critical warnings in logs
- **CRITICAL**: CDC checkpoint frozen > 30 min (confirmed stall), OR bucket inactive > 1 hour, OR stream in unexpected state, OR private connection not CREATED

## When Stall Is Detected

If a silent stall is confirmed (frozen CDC checkpoint), report it clearly and mention:
1. The user should request a pause/resume from the Nagel GCP team (or self-service if `datastream.streams.update` permission has been granted)
2. The pause/resume commands are:
   ```bash
   gcloud datastream streams update <STREAM_ID> --location=europe-west3 --state=PAUSED --update-mask=state
   # Wait for PAUSED, then:
   gcloud datastream streams update <STREAM_ID> --location=europe-west3 --state=RUNNING --update-mask=state
   ```
3. After restart, monitor via `/check-replication-slots` to track lag catchup

## Reference

Full runbook: `02_Explorations/2026-06-12_Datastream_Health_Check_Runbook/datastream-health-check-runbook.md`
gcloud operations: `02_Explorations/2026-06-09_gcloud-tooling/gcp-datastream-gcloud-operations-guide.md`
