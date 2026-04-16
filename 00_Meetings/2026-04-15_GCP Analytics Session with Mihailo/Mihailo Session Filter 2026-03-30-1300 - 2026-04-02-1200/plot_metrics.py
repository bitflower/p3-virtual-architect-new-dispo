"""
Plot Datastream CDC metrics from exported GCP data.
Generates PNG charts for: throughput, latencies, freshness.
"""

import json
import re
import csv
import os
from datetime import datetime, timezone
from collections import defaultdict
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.dates as mdates

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(SCRIPT_DIR, "charts")
os.makedirs(OUT_DIR, exist_ok=True)

plt.rcParams.update({
    'figure.facecolor': 'white',
    'axes.facecolor': '#f8f9fa',
    'axes.grid': True,
    'grid.alpha': 0.3,
    'font.size': 10,
    'figure.dpi': 150,
})

# --- Helpers ---
def parse_gcp_ts(ts_str):
    ts_clean = re.sub(r'\s*\(.*\)\s*$', '', ts_str.strip())
    try:
        return datetime.strptime(ts_clean, "%a %b %d %Y %H:%M:%S GMT%z").astimezone(timezone.utc)
    except ValueError:
        return None

def load_metric_csv(filepath, skip_rows=2):
    with open(filepath) as f:
        lines = f.readlines()
    results = []
    for line in lines[skip_rows:]:
        parts = line.strip().split(',', 1)
        if len(parts) == 2:
            dt = parse_gcp_ts(parts[0])
            try:
                val = float(parts[1])
            except ValueError:
                continue
            if dt:
                results.append((dt, val))
    return results

# ============================================================
# 1. THROUGHPUT — records per hour
# ============================================================
log_file = os.path.join(SCRIPT_DIR, "downloaded-logs-20260415-154320.json")
with open(log_file) as f:
    log_data = json.load(f)

hourly = defaultdict(lambda: {"events": 0, "records": 0})
for entry in log_data:
    msg = entry.get("jsonPayload", {}).get("message", "")
    match = re.search(r"writing (\d+) records", msg)
    count = int(match.group(1)) if match else 0
    ts = datetime.fromisoformat(entry["timestamp"].replace("Z", "+00:00"))
    hour_key = ts.replace(minute=0, second=0, microsecond=0)
    hourly[hour_key]["events"] += 1
    hourly[hour_key]["records"] += count

hours = sorted(hourly.keys())
events = [hourly[h]["events"] for h in hours]
records = [hourly[h]["records"] for h in hours]

fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(14, 8), sharex=True)
fig.suptitle("Datastream CDC Throughput — orauat-1060-bucket\n2026-03-30 13:00 — 2026-04-02 12:00", fontsize=13, fontweight='bold')

ax1.bar(hours, records, width=0.035, color='#4285f4', alpha=0.8)
ax1.set_ylabel("Records Written")
ax1.set_title("Records per Hour")
for i, (h, r) in enumerate(zip(hours, records)):
    if r > 500:
        ax1.annotate(f'{r:,}', (h, r), textcoords="offset points", xytext=(0, 5), ha='center', fontsize=7)

ax2.bar(hours, events, width=0.035, color='#34a853', alpha=0.8)
ax2.set_ylabel("Write Events (log entries)")
ax2.set_title("Write Events per Hour")
ax2.xaxis.set_major_formatter(mdates.DateFormatter('%b %d\n%H:%M'))
ax2.xaxis.set_major_locator(mdates.HourLocator(interval=6))
plt.xticks(rotation=0)

plt.tight_layout()
plt.savefig(os.path.join(OUT_DIR, "01_throughput.png"), bbox_inches='tight')
plt.close()
print("Saved: 01_throughput.png")

# ============================================================
# 2. END-TO-END LATENCY (Total Latencies) — p50/p95/p99
# ============================================================
fig, ax = plt.subplots(figsize=(14, 5))
fig.suptitle("End-to-End Latency (Total Latencies) — DB change to GCS object\norauat-1060-bucket", fontsize=13, fontweight='bold')

colors = {'p50': '#4285f4', 'p95': '#fbbc04', 'p99': '#ea4335'}
for i, (label, color) in enumerate(colors.items()):
    filepath = os.path.join(SCRIPT_DIR, f"Stream_total_latencies_for_orauat-1060-bucket_[SUM]_{i+1}.csv")
    data = load_metric_csv(filepath)
    if data:
        times, vals = zip(*data)
        vals_min = [v / 60 for v in vals]  # convert to minutes
        ax.plot(times, vals_min, color=color, label=label, marker='o', markersize=3, linewidth=1.5)

ax.set_ylabel("Latency (minutes)")
ax.legend(loc='upper right')
ax.xaxis.set_major_formatter(mdates.DateFormatter('%b %d\n%H:%M'))
ax.xaxis.set_major_locator(mdates.HourLocator(interval=6))
ax.axhline(y=30, color='green', linestyle='--', alpha=0.5, label='GCP recommended max (30 min)')
ax.legend(loc='upper right')
plt.tight_layout()
plt.savefig(os.path.join(OUT_DIR, "02_total_latency.png"), bbox_inches='tight')
plt.close()
print("Saved: 02_total_latency.png")

# ============================================================
# 3. SYSTEM LATENCY (Datastream processing) — p50/p95/p99
# ============================================================
fig, ax = plt.subplots(figsize=(14, 5))
fig.suptitle("System Latency (Datastream Processing) — read to write\norauat-1060-bucket", fontsize=13, fontweight='bold')

for i, (label, color) in enumerate(colors.items()):
    filepath = os.path.join(SCRIPT_DIR, f"Stream_system_latencies_for_orauat-1060-bucket_[SUM]_{i+1}.csv")
    data = load_metric_csv(filepath)
    if data:
        times, vals = zip(*data)
        ax.plot(times, vals, color=color, label=label, marker='o', markersize=3, linewidth=1.5)

ax.set_ylabel("Latency (seconds)")
ax.legend(loc='upper right')
ax.xaxis.set_major_formatter(mdates.DateFormatter('%b %d\n%H:%M'))
ax.xaxis.set_major_locator(mdates.HourLocator(interval=6))
plt.tight_layout()
plt.savefig(os.path.join(OUT_DIR, "03_system_latency.png"), bbox_inches='tight')
plt.close()
print("Saved: 03_system_latency.png")

# ============================================================
# 4. STREAM LATENCY — p50/p95/p99
# ============================================================
fig, ax = plt.subplots(figsize=(14, 5))
fig.suptitle("Stream Latency — orauat-1060-bucket", fontsize=13, fontweight='bold')

for i, (label, color) in enumerate(colors.items()):
    filepath = os.path.join(SCRIPT_DIR, f"Stream_latencies_for_orauat-1060-bucket_[SUM]_{i+1}.csv")
    data = load_metric_csv(filepath)
    if data:
        times, vals = zip(*data)
        ax.plot(times, vals, color=color, label=label, marker='o', markersize=3, linewidth=1.5)

ax.set_ylabel("Latency (seconds)")
ax.legend(loc='upper right')
ax.xaxis.set_major_formatter(mdates.DateFormatter('%b %d\n%H:%M'))
ax.xaxis.set_major_locator(mdates.HourLocator(interval=6))
plt.tight_layout()
plt.savefig(os.path.join(OUT_DIR, "04_stream_latency.png"), bbox_inches='tight')
plt.close()
print("Saved: 04_stream_latency.png")

# ============================================================
# 5. FRESHNESS
# ============================================================
freshness_data = load_metric_csv(
    os.path.join(SCRIPT_DIR, "Stream_freshness_for_orauat-1060-bucket_[MEAN].csv"),
    skip_rows=4
)

fig, ax = plt.subplots(figsize=(14, 4))
fig.suptitle("Stream Freshness — time between source commit and Datastream read\norauat-1060-bucket", fontsize=13, fontweight='bold')

if freshness_data:
    times, vals = zip(*freshness_data)
    ax.plot(times, vals, color='#4285f4', linewidth=1, alpha=0.8)
    ax.fill_between(times, vals, alpha=0.2, color='#4285f4')

ax.set_ylabel("Freshness (seconds)")
ax.xaxis.set_major_formatter(mdates.DateFormatter('%b %d\n%H:%M'))
ax.xaxis.set_major_locator(mdates.HourLocator(interval=6))
plt.tight_layout()
plt.savefig(os.path.join(OUT_DIR, "05_freshness.png"), bbox_inches='tight')
plt.close()
print("Saved: 05_freshness.png")

# ============================================================
# 6. COMBINED OVERVIEW — latency comparison
# ============================================================
fig, axes = plt.subplots(3, 1, figsize=(14, 12), sharex=True)
fig.suptitle("Datastream CDC Latency Overview — orauat-1060-bucket\n2026-03-30 13:00 — 2026-04-02 12:00\nTotal Latency = Freshness + System Latency (per GCP docs)", fontsize=13, fontweight='bold')

# Total latency (minutes)
ax = axes[0]
ax.set_title("End-to-End Latency (Total Latencies) — minutes")
for i, (label, color) in enumerate(colors.items()):
    filepath = os.path.join(SCRIPT_DIR, f"Stream_total_latencies_for_orauat-1060-bucket_[SUM]_{i+1}.csv")
    data = load_metric_csv(filepath)
    if data:
        times, vals = zip(*data)
        ax.plot(times, [v/60 for v in vals], color=color, label=label, marker='o', markersize=3, linewidth=1.5)
ax.axhline(y=30, color='green', linestyle='--', alpha=0.5, linewidth=1)
ax.text(times[0], 32, 'GCP recommended max (30 min)', fontsize=8, color='green', alpha=0.7)
ax.set_ylabel("Minutes")
ax.legend(loc='upper right')

# System latency (seconds)
ax = axes[1]
ax.set_title("System Latency (Datastream Processing) — seconds")
for i, (label, color) in enumerate(colors.items()):
    filepath = os.path.join(SCRIPT_DIR, f"Stream_system_latencies_for_orauat-1060-bucket_[SUM]_{i+1}.csv")
    data = load_metric_csv(filepath)
    if data:
        times, vals = zip(*data)
        ax.plot(times, vals, color=color, label=label, marker='o', markersize=3, linewidth=1.5)
ax.set_ylabel("Seconds")
ax.legend(loc='upper right')

# Throughput
ax = axes[2]
ax.set_title("Records Written per Hour")
ax.bar(hours, records, width=0.035, color='#4285f4', alpha=0.8)
ax.set_ylabel("Records")
ax.xaxis.set_major_formatter(mdates.DateFormatter('%b %d %H:%M'))
ax.xaxis.set_major_locator(mdates.HourLocator(interval=6))

plt.tight_layout()
plt.savefig(os.path.join(OUT_DIR, "06_combined_overview.png"), bbox_inches='tight')
plt.close()
print("Saved: 06_combined_overview.png")

# ============================================================
# 7. BATCH SIZE DISTRIBUTION
# ============================================================
all_counts = []
for entry in log_data:
    msg = entry.get("jsonPayload", {}).get("message", "")
    match = re.search(r"writing (\d+) records", msg)
    if match:
        all_counts.append(int(match.group(1)))

fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 5))
fig.suptitle("Batch Size Distribution — 1,271 write events", fontsize=13, fontweight='bold')

# Histogram
ax1.hist(all_counts, bins=50, color='#4285f4', alpha=0.8, edgecolor='white')
ax1.set_xlabel("Records per batch")
ax1.set_ylabel("Frequency")
ax1.set_title("Distribution (all)")

# Log scale for detail
ax2.hist(all_counts, bins=50, color='#4285f4', alpha=0.8, edgecolor='white')
ax2.set_xlabel("Records per batch")
ax2.set_ylabel("Frequency (log scale)")
ax2.set_yscale('log')
ax2.set_title("Distribution (log scale)")

plt.tight_layout()
plt.savefig(os.path.join(OUT_DIR, "07_batch_distribution.png"), bbox_inches='tight')
plt.close()
print("Saved: 07_batch_distribution.png")

print(f"\nAll charts saved to: {OUT_DIR}")
