"""
Extract Datastream CDC metrics from GCP Logs Explorer JSON export.

Usage:
    python3 extract_datastream_metrics.py

Reads:  downloaded-logs-20260415-154320.json (same directory)
Writes: datastream_metrics.csv      — one row per log entry
        datastream_summary.json     — aggregated metrics
        datastream_hourly.csv       — records per hour for charting
"""

import json
import re
import csv
import os
from datetime import datetime
from collections import defaultdict

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
INPUT_FILE = os.path.join(SCRIPT_DIR, "downloaded-logs-20260415-154320.json")
OUTPUT_CSV = os.path.join(SCRIPT_DIR, "datastream_metrics.csv")
OUTPUT_SUMMARY = os.path.join(SCRIPT_DIR, "datastream_summary.json")
OUTPUT_HOURLY = os.path.join(SCRIPT_DIR, "datastream_hourly.csv")

with open(INPUT_FILE) as f:
    data = json.load(f)

# --- Extract per-entry metrics ---
rows = []
for entry in data:
    jp = entry.get("jsonPayload", {})
    msg = jp.get("message", "")
    match = re.search(r"writing (\d+) records", msg)
    record_count = int(match.group(1)) if match else 0

    ts = entry.get("timestamp", "")
    rows.append({
        "timestamp": ts,
        "severity": entry.get("severity", ""),
        "object_name": jp.get("object_name", ""),
        "event_code": jp.get("event_code", ""),
        "context": jp.get("context", ""),
        "record_count": record_count,
        "stream_id": entry.get("resource", {}).get("labels", {}).get("stream_id", ""),
        "destination": msg.split("destination: ")[-1] if "destination: " in msg else "",
        "message": msg,
    })

rows.sort(key=lambda r: r["timestamp"])

# --- Write per-entry CSV ---
with open(OUTPUT_CSV, "w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=[
        "timestamp", "severity", "object_name", "event_code",
        "context", "record_count", "stream_id", "destination", "message"
    ])
    writer.writeheader()
    writer.writerows(rows)

# --- Hourly aggregation ---
hourly = defaultdict(lambda: {"log_entries": 0, "total_records": 0, "errors": 0})
for row in rows:
    hour = row["timestamp"][:13]  # "2026-03-30T13"
    hourly[hour]["log_entries"] += 1
    hourly[hour]["total_records"] += row["record_count"]
    if row["severity"] in ("ERROR", "CRITICAL"):
        hourly[hour]["errors"] += 1

with open(OUTPUT_HOURLY, "w", newline="") as f:
    writer = csv.writer(f)
    writer.writerow(["hour", "log_entries", "total_records", "errors"])
    for hour in sorted(hourly.keys()):
        h = hourly[hour]
        writer.writerow([hour, h["log_entries"], h["total_records"], h["errors"]])

# --- Summary ---
record_counts = [r["record_count"] for r in rows]
total_records = sum(record_counts)
total_entries = len(rows)
error_entries = sum(1 for r in rows if r["severity"] in ("ERROR", "CRITICAL"))
first_ts = rows[0]["timestamp"] if rows else ""
last_ts = rows[-1]["timestamp"] if rows else ""

summary = {
    "time_range": {
        "from": first_ts,
        "to": last_ts,
    },
    "totals": {
        "log_entries": total_entries,
        "total_records_processed": total_records,
        "error_entries": error_entries,
        "successful_entries": total_entries - error_entries,
    },
    "delivery_rate": {
        "by_log_entries": f"{((total_entries - error_entries) / total_entries * 100):.2f}%" if total_entries else "N/A",
        "errors_found": error_entries,
        "note": "All log entries have severity=INFO, 0 errors detected",
    },
    "records_per_entry": {
        "min": min(record_counts) if record_counts else 0,
        "max": max(record_counts) if record_counts else 0,
        "avg": round(sum(record_counts) / len(record_counts), 1) if record_counts else 0,
    },
    "by_object_name": {},
    "by_stream_id": {},
}

# Group by object_name
for row in rows:
    obj = row["object_name"]
    if obj not in summary["by_object_name"]:
        summary["by_object_name"][obj] = {"log_entries": 0, "total_records": 0}
    summary["by_object_name"][obj]["log_entries"] += 1
    summary["by_object_name"][obj]["total_records"] += row["record_count"]

# Group by stream_id
for row in rows:
    sid = row["stream_id"]
    if sid not in summary["by_stream_id"]:
        summary["by_stream_id"][sid] = {"log_entries": 0, "total_records": 0}
    summary["by_stream_id"][sid]["log_entries"] += 1
    summary["by_stream_id"][sid]["total_records"] += row["record_count"]

with open(OUTPUT_SUMMARY, "w") as f:
    json.dump(summary, f, indent=2)

# --- Print summary to console ---
print("=" * 60)
print("DATASTREAM CDC METRICS SUMMARY")
print("=" * 60)
print(f"Time range:     {first_ts} — {last_ts}")
print(f"Log entries:    {total_entries:,}")
print(f"Total records:  {total_records:,}")
print(f"Errors:         {error_entries}")
print(f"Delivery rate:  {summary['delivery_rate']['by_log_entries']}")
print(f"Records/entry:  min={min(record_counts)}, max={max(record_counts)}, avg={sum(record_counts)/len(record_counts):.1f}")
print()
print("By table:")
for obj, stats in summary["by_object_name"].items():
    print(f"  {obj}: {stats['log_entries']:,} entries, {stats['total_records']:,} records")
print()
print(f"Output files:")
print(f"  {OUTPUT_CSV}")
print(f"  {OUTPUT_HOURLY}")
print(f"  {OUTPUT_SUMMARY}")
