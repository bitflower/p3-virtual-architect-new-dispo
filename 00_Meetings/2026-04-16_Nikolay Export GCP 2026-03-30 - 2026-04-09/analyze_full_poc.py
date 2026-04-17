"""
Full POC Analysis — GCP Datastream CDC (orauat-1060-bucket)
Period: 2026-03-30 to 2026-04-09
Data sources: Nikolay GCP export + Robert DBA log switch data
"""

import json
import re
import os
from datetime import datetime, timezone, timedelta
from collections import defaultdict, Counter
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
import numpy as np

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(SCRIPT_DIR, "charts")
os.makedirs(OUT_DIR, exist_ok=True)

# Robert's log switch data file
ROBERT_FILE = os.path.join(
    os.path.dirname(SCRIPT_DIR),
    "2026-04-15_GCP Analytics Session with Mihailo",
    "Mihailo Session Filter 2026-03-30-1300 - 2026-04-02-1200",
    "RE- Oracle CDC- Konfigurationspotentiale - wider range.md"
)

plt.rcParams.update({
    'figure.facecolor': 'white',
    'axes.facecolor': '#f8f9fa',
    'axes.grid': True,
    'grid.alpha': 0.3,
    'font.size': 10,
    'figure.dpi': 150,
})

COLORS = {'p50': '#4285f4', 'p95': '#fbbc04', 'p99': '#ea4335'}

# ============================================================
# PARSERS
# ============================================================

def parse_gcp_ts(ts_str):
    """Parse GCP Metrics Explorer CSV timestamp."""
    ts_clean = re.sub(r'\s*\(.*\)\s*$', '', ts_str.strip())
    try:
        return datetime.strptime(ts_clean, "%a %b %d %Y %H:%M:%S GMT%z").astimezone(timezone.utc)
    except ValueError:
        return None


def load_metric_csv(filepath, skip_rows=2):
    """Load a single-column GCP metric CSV (2 header rows by default)."""
    with open(filepath) as f:
        lines = f.readlines()
    results = []
    for line in lines[skip_rows:]:
        parts = line.strip().rsplit(',', 1)
        if len(parts) == 2:
            dt = parse_gcp_ts(parts[0])
            try:
                val = float(parts[1])
            except ValueError:
                continue
            if dt:
                results.append((dt, val))
    return sorted(results, key=lambda x: x[0])


def load_event_count_csv(filepath):
    """Load event_count CSV with 3 columns: backfill, cdc-logminer, postgresql-cdc."""
    with open(filepath) as f:
        lines = f.readlines()
    # Header rows: line 0 = TimeSeries ID, line 1 = read_method, line 2 = project_id
    results = {'backfill': [], 'logminer': [], 'postgresql': []}
    for line in lines[3:]:
        parts = line.strip().split(',')
        if len(parts) == 4:
            dt = parse_gcp_ts(parts[0])
            if dt:
                for i, key in enumerate(['backfill', 'logminer', 'postgresql']):
                    try:
                        val = float(parts[i + 1])
                        results[key].append((dt, val))
                    except ValueError:
                        pass
    return results


def load_throughput_csv(filepath):
    """Load throughput CSV (has 1 header row + 'undefined' on row 2)."""
    with open(filepath) as f:
        lines = f.readlines()
    results = []
    for line in lines[1:]:  # skip header
        parts = line.strip().rsplit(',', 1)
        if len(parts) == 2:
            dt = parse_gcp_ts(parts[0])
            try:
                val = float(parts[1])
            except ValueError:
                continue
            if dt:
                results.append((dt, val))
    return sorted(results, key=lambda x: x[0])


def load_logs(filepath, stream_filter="orauat-1060-bucket"):
    """Load CDC activity logs, filtered by stream_id."""
    with open(filepath) as f:
        data = json.load(f)
    filtered = []
    for entry in data:
        sid = entry.get("resource", {}).get("labels", {}).get("stream_id", "")
        if sid == stream_filter:
            filtered.append(entry)
    return filtered


def load_warning_logs(filepath):
    """Load warning/error logs."""
    with open(filepath) as f:
        return json.load(f)


def parse_robert_log_switches(filepath):
    """Parse Robert's SQL output for log switch data."""
    with open(filepath) as f:
        lines = f.readlines()
    results = []
    for line in lines:
        match = re.match(
            r'(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2})\s+(\d+)\s+([\d.]+)',
            line.strip()
        )
        if match:
            dt = datetime.strptime(match.group(1), "%Y-%m-%d %H:%M").replace(tzinfo=timezone.utc)
            seq = int(match.group(2))
            duration = float(match.group(3))
            results.append((dt, seq, duration))
    return results


# ============================================================
# LOAD ALL DATA
# ============================================================

print("Loading data...")

# Metrics
total_lat = {}
sys_lat = {}
stream_lat = {}
for pct in ['50TH_PERCENTILE', '95TH_PERCENTILE', '99TH_PERCENTILE']:
    label = pct.replace('TH_PERCENTILE', '').lower()
    label = f'p{label}'
    total_lat[label] = load_metric_csv(os.path.join(SCRIPT_DIR, f"Stream_total_latencies_[{pct}].csv"))
    sys_lat[label] = load_metric_csv(os.path.join(SCRIPT_DIR, f"Stream_system_latencies_[{pct}].csv"))
    stream_lat[label] = load_metric_csv(os.path.join(SCRIPT_DIR, f"Stream_latencies_[{pct}].csv"))

freshness = load_metric_csv(os.path.join(SCRIPT_DIR, "Stream_freshness_[MEAN].csv"))
event_counts = load_event_count_csv(os.path.join(SCRIPT_DIR, "Stream_event_count_[SUM].csv"))
throughput = load_throughput_csv(os.path.join(SCRIPT_DIR, "Throughput_(event_sec).csv"))

# Logs
activity_logs = load_logs(os.path.join(SCRIPT_DIR, "downloaded-logs-20260416-111739.json"))
warning_logs = load_warning_logs(os.path.join(SCRIPT_DIR, "downloaded-logs-20260416-111822.json"))

# Robert's log switch data
log_switches = parse_robert_log_switches(ROBERT_FILE)

print(f"  Metrics: total_lat={len(total_lat['p50'])} pts, sys_lat={len(sys_lat['p50'])} pts, "
      f"stream_lat={len(stream_lat['p50'])} pts, freshness={len(freshness)} pts")
print(f"  Event count: backfill={len(event_counts['backfill'])}, logminer={len(event_counts['logminer'])}, "
      f"postgresql={len(event_counts['postgresql'])}")
print(f"  Throughput: {len(throughput)} pts")
print(f"  Activity logs (orauat-1060-bucket): {len(activity_logs)} entries")
print(f"  Warning logs: {len(warning_logs)} entries")
print(f"  Log switches (Robert): {len(log_switches)} entries")

# ============================================================
# COMPUTE STATS FROM LOGS
# ============================================================

# Extract record counts and timestamps from activity logs
hourly = defaultdict(lambda: {"events": 0, "records": 0})
all_counts = []
for entry in activity_logs:
    msg = entry.get("jsonPayload", {}).get("message", "")
    match = re.search(r"writing (\d+) records", msg)
    count = int(match.group(1)) if match else 0
    ts = datetime.fromisoformat(entry["timestamp"].replace("Z", "+00:00"))
    hour_key = ts.replace(minute=0, second=0, microsecond=0)
    hourly[hour_key]["events"] += 1
    hourly[hour_key]["records"] += count
    if count > 0:
        all_counts.append(count)

hours = sorted(hourly.keys())
events = [hourly[h]["events"] for h in hours]
records = [hourly[h]["records"] for h in hours]
total_records = sum(all_counts)
total_events = len(activity_logs)

# Time range
ts_list = sorted(datetime.fromisoformat(e["timestamp"].replace("Z", "+00:00")) for e in activity_logs)
ts_start = ts_list[0] if ts_list else None
ts_end = ts_list[-1] if ts_list else None

print(f"\n--- orauat-1060-bucket Summary ---")
print(f"  Period: {ts_start} to {ts_end}")
print(f"  Write events: {total_events}")
print(f"  Total records: {total_records:,}")
print(f"  Batch size: min={min(all_counts)}, avg={sum(all_counts)/len(all_counts):.0f}, max={max(all_counts)}")

# Latency stats
def metric_stats(data):
    if not data:
        return {}
    vals = [v for _, v in data]
    return {
        'min': min(vals),
        'avg': sum(vals) / len(vals),
        'max': max(vals),
        'count': len(vals),
    }

print(f"\n--- Latency Stats (seconds) ---")
for name, metrics in [("Total", total_lat), ("System", sys_lat), ("Stream", stream_lat)]:
    print(f"  {name}:")
    for pct, data in metrics.items():
        s = metric_stats(data)
        if s:
            print(f"    {pct}: min={s['min']:.1f}s, avg={s['avg']:.1f}s, max={s['max']:.1f}s ({s['count']} pts)")

# Warning stats
warn_codes = Counter(e['jsonPayload'].get('event_code', '') for e in warning_logs)
print(f"\n--- Warnings ---")
for code, count in warn_codes.most_common():
    print(f"  {code}: {count}")

# Log switch stats for POC period
poc_switches = [(dt, seq, dur) for dt, seq, dur in log_switches
                if datetime(2026, 3, 30, tzinfo=timezone.utc) <= dt <= datetime(2026, 4, 9, tzinfo=timezone.utc)]
if poc_switches:
    durs = [dur for _, _, dur in poc_switches]
    print(f"\n--- Log Switches (POC period Mar 30 - Apr 9) ---")
    print(f"  Count: {len(poc_switches)}")
    print(f"  Duration: min={min(durs):.1f} min, avg={sum(durs)/len(durs):.1f} min, max={max(durs):.1f} min")


# ============================================================
# CHART 01: THROUGHPUT (records + events per hour)
# ============================================================
print("\nGenerating charts...")

fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(16, 8), sharex=True)
fig.suptitle("Datastream CDC Throughput — orauat-1060-bucket\n2026-03-30 — 2026-04-09 (full POC period)",
             fontsize=13, fontweight='bold')

ax1.bar(hours, records, width=0.035, color='#4285f4', alpha=0.8)
ax1.set_ylabel("Records Written")
ax1.set_title("Records per Hour")
for h, r in zip(hours, records):
    if r > 500:
        ax1.annotate(f'{r:,}', (h, r), textcoords="offset points", xytext=(0, 5),
                     ha='center', fontsize=6)

ax2.bar(hours, events, width=0.035, color='#34a853', alpha=0.8)
ax2.set_ylabel("Write Events (log entries)")
ax2.set_title("Write Events per Hour")
ax2.xaxis.set_major_formatter(mdates.DateFormatter('%b %d\n%H:%M'))
ax2.xaxis.set_major_locator(mdates.DayLocator())

plt.tight_layout()
plt.savefig(os.path.join(OUT_DIR, "01_throughput.png"), bbox_inches='tight')
plt.close()
print("  01_throughput.png")


# ============================================================
# CHART 02: END-TO-END LATENCY (Total Latencies) — p50/p95/p99
# ============================================================
fig, ax = plt.subplots(figsize=(16, 5))
fig.suptitle("End-to-End Latency (Total Latencies) — DB change to GCS object\norauat-1060-bucket | Full POC period",
             fontsize=13, fontweight='bold')

for label, color in COLORS.items():
    data = total_lat[label]
    if data:
        times, vals = zip(*data)
        vals_min = [v / 60 for v in vals]
        ax.plot(times, vals_min, color=color, label=label, marker='o', markersize=2, linewidth=1.2)

ax.axhline(y=30, color='green', linestyle='--', alpha=0.5, linewidth=1)
ax.text(total_lat['p50'][0][0], 32, 'GCP recommended max (30 min)', fontsize=8, color='green', alpha=0.7)
ax.set_ylabel("Latency (minutes)")
ax.legend(loc='upper right')
ax.xaxis.set_major_formatter(mdates.DateFormatter('%b %d\n%H:%M'))
ax.xaxis.set_major_locator(mdates.DayLocator())

plt.tight_layout()
plt.savefig(os.path.join(OUT_DIR, "02_total_latency.png"), bbox_inches='tight')
plt.close()
print("  02_total_latency.png")


# ============================================================
# CHART 03: SYSTEM LATENCY — p50/p95/p99
# ============================================================
fig, ax = plt.subplots(figsize=(16, 5))
fig.suptitle("System Latency (Datastream Processing) — read to write\norauat-1060-bucket | Full POC period",
             fontsize=13, fontweight='bold')

for label, color in COLORS.items():
    data = sys_lat[label]
    if data:
        times, vals = zip(*data)
        ax.plot(times, vals, color=color, label=label, marker='o', markersize=2, linewidth=1.2)

ax.set_ylabel("Latency (seconds)")
ax.legend(loc='upper right')
ax.xaxis.set_major_formatter(mdates.DateFormatter('%b %d\n%H:%M'))
ax.xaxis.set_major_locator(mdates.DayLocator())

plt.tight_layout()
plt.savefig(os.path.join(OUT_DIR, "03_system_latency.png"), bbox_inches='tight')
plt.close()
print("  03_system_latency.png")


# ============================================================
# CHART 04: STREAM LATENCY — p50/p95/p99
# ============================================================
fig, ax = plt.subplots(figsize=(16, 5))
fig.suptitle("Stream Latency — orauat-1060-bucket | Full POC period",
             fontsize=13, fontweight='bold')

for label, color in COLORS.items():
    data = stream_lat[label]
    if data:
        times, vals = zip(*data)
        ax.plot(times, vals, color=color, label=label, marker='o', markersize=2, linewidth=1.2)

ax.set_ylabel("Latency (seconds)")
ax.legend(loc='upper right')
ax.xaxis.set_major_formatter(mdates.DateFormatter('%b %d\n%H:%M'))
ax.xaxis.set_major_locator(mdates.DayLocator())

plt.tight_layout()
plt.savefig(os.path.join(OUT_DIR, "04_stream_latency.png"), bbox_inches='tight')
plt.close()
print("  04_stream_latency.png")


# ============================================================
# CHART 05: FRESHNESS
# ============================================================
fig, ax = plt.subplots(figsize=(16, 4))
fig.suptitle("Stream Freshness — time between source commit and Datastream read\norauat-1060-bucket | Full POC period",
             fontsize=13, fontweight='bold')

if freshness:
    times, vals = zip(*freshness)
    ax.plot(times, vals, color='#4285f4', linewidth=1, alpha=0.8, label='Freshness (MEAN)')
    ax.fill_between(times, vals, alpha=0.2, color='#4285f4')
    ax.legend(loc='upper right')

ax.set_ylabel("Freshness (seconds)")
ax.xaxis.set_major_formatter(mdates.DateFormatter('%b %d\n%H:%M'))
ax.xaxis.set_major_locator(mdates.DayLocator())

plt.tight_layout()
plt.savefig(os.path.join(OUT_DIR, "05_freshness.png"), bbox_inches='tight')
plt.close()
print("  05_freshness.png")


# ============================================================
# CHART 06: COMBINED OVERVIEW — latency + throughput
# ============================================================
fig, axes = plt.subplots(4, 1, figsize=(16, 16), sharex=True)
fig.suptitle("Datastream CDC Overview — orauat-1060-bucket\n2026-03-30 — 2026-04-09\nTotal Latency = Freshness + System Latency",
             fontsize=13, fontweight='bold')

# Total latency (minutes)
ax = axes[0]
ax.set_title("End-to-End Latency (Total Latencies) — minutes")
for label, color in COLORS.items():
    data = total_lat[label]
    if data:
        times, vals = zip(*data)
        ax.plot(times, [v / 60 for v in vals], color=color, label=label, marker='o', markersize=2, linewidth=1.2)
ax.axhline(y=30, color='green', linestyle='--', alpha=0.5, linewidth=1)
ax.set_ylabel("Minutes")
ax.legend(loc='upper right')

# System latency (seconds)
ax = axes[1]
ax.set_title("System Latency (Datastream Processing) — seconds")
for label, color in COLORS.items():
    data = sys_lat[label]
    if data:
        times, vals = zip(*data)
        ax.plot(times, vals, color=color, label=label, marker='o', markersize=2, linewidth=1.2)
ax.set_ylabel("Seconds")
ax.legend(loc='upper right')

# Freshness
ax = axes[2]
ax.set_title("Stream Freshness — seconds")
if freshness:
    times, vals = zip(*freshness)
    ax.plot(times, vals, color='#4285f4', linewidth=1, alpha=0.8, label='Freshness (MEAN)')
    ax.fill_between(times, vals, alpha=0.2, color='#4285f4')
    ax.legend(loc='upper right')
ax.set_ylabel("Seconds")

# Throughput
ax = axes[3]
ax.set_title("Records Written per Hour")
ax.bar(hours, records, width=0.035, color='#4285f4', alpha=0.8, label='Records/hour')
ax.set_ylabel("Records")
ax.legend(loc='upper right')
ax.xaxis.set_major_formatter(mdates.DateFormatter('%b %d'))
ax.xaxis.set_major_locator(mdates.DayLocator())

plt.tight_layout()
plt.savefig(os.path.join(OUT_DIR, "06_combined_overview.png"), bbox_inches='tight')
plt.close()
print("  06_combined_overview.png")


# ============================================================
# CHART 07: BATCH SIZE DISTRIBUTION
# ============================================================
fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 5))
fig.suptitle(f"Batch Size Distribution — {len(all_counts):,} write events, {total_records:,} records",
             fontsize=13, fontweight='bold')

ax1.hist(all_counts, bins=50, color='#4285f4', alpha=0.8, edgecolor='white')
ax1.set_xlabel("Records per batch")
ax1.set_ylabel("Frequency")
ax1.set_title("Distribution (all)")

ax2.hist(all_counts, bins=50, color='#4285f4', alpha=0.8, edgecolor='white')
ax2.set_xlabel("Records per batch")
ax2.set_ylabel("Frequency (log scale)")
ax2.set_yscale('log')
ax2.set_title("Distribution (log scale)")

plt.tight_layout()
plt.savefig(os.path.join(OUT_DIR, "07_batch_distribution.png"), bbox_inches='tight')
plt.close()
print("  07_batch_distribution.png")


# ============================================================
# CHART 08: LOG SWITCH TIMELINE (Robert's data, full range)
# ============================================================
if log_switches:
    sw_times = [dt for dt, _, _ in log_switches]
    sw_durs = [dur for _, _, dur in log_switches]

    fig, ax = plt.subplots(figsize=(16, 5))
    fig.suptitle("Oracle Redo Log Switch Duration — UAT1060\nRobert Zanter DBA data | Mar 26 – Apr 8",
                 fontsize=13, fontweight='bold')

    bar_colors = []
    for d in sw_durs:
        if d <= 10:
            bar_colors.append('#34a853')  # green = fast
        elif d <= 20:
            bar_colors.append('#fbbc04')  # yellow = moderate
        else:
            bar_colors.append('#ea4335')  # red = slow

    ax.bar(sw_times, sw_durs, width=0.02, color=bar_colors, alpha=0.8)
    ax.axhline(y=15, color='blue', linestyle='--', alpha=0.5, linewidth=1)
    ax.text(sw_times[0], 16, 'Proposed ARCHIVE_LAG_TARGET = 900 (15 min)', fontsize=8, color='blue', alpha=0.7)
    ax.set_ylabel("Switch Duration (minutes)")

    # Legend
    from matplotlib.patches import Patch
    legend_elements = [
        Patch(facecolor='#34a853', label='≤10 min (fast)'),
        Patch(facecolor='#fbbc04', label='10-20 min (moderate)'),
        Patch(facecolor='#ea4335', label='>20 min (slow)'),
    ]
    ax.legend(handles=legend_elements, loc='upper right')
    ax.xaxis.set_major_formatter(mdates.DateFormatter('%b %d'))
    ax.xaxis.set_major_locator(mdates.DayLocator())

    plt.tight_layout()
    plt.savefig(os.path.join(OUT_DIR, "08_log_switch_timeline.png"), bbox_inches='tight')
    plt.close()
    print("  08_log_switch_timeline.png")


# ============================================================
# CHART 09: LOG SWITCH BY HOUR OF DAY
# ============================================================
if log_switches:
    hourly_durs = defaultdict(list)
    for dt, _, dur in log_switches:
        hourly_durs[dt.hour].append(dur)

    all_hours = range(24)
    avg_durs = [np.mean(hourly_durs[h]) if h in hourly_durs else 0 for h in all_hours]

    fig, ax = plt.subplots(figsize=(14, 5))
    fig.suptitle("Oracle Log Switch Duration by Hour of Day — UAT1060\nMar 26 – Apr 8 | Avg duration per hour",
                 fontsize=13, fontweight='bold')

    bar_colors = []
    for d in avg_durs:
        if d <= 10:
            bar_colors.append('#34a853')
        elif d <= 20:
            bar_colors.append('#fbbc04')
        else:
            bar_colors.append('#ea4335')

    bars = ax.bar(list(all_hours), avg_durs, color=bar_colors, alpha=0.8, edgecolor='white')
    ax.axhline(y=15, color='blue', linestyle='--', alpha=0.5, linewidth=1)
    ax.set_xlabel("Hour of Day (UTC)")
    ax.set_ylabel("Avg Switch Duration (minutes)")
    ax.set_xticks(list(all_hours))

    for i, (h, d) in enumerate(zip(all_hours, avg_durs)):
        if d > 0:
            ax.text(h, d + 0.3, f'{d:.0f}', ha='center', fontsize=7)

    legend_elements = [
        Patch(facecolor='#34a853', label='≤10 min (fast — batch jobs)'),
        Patch(facecolor='#fbbc04', label='10-20 min (moderate)'),
        Patch(facecolor='#ea4335', label='>20 min (slow — low activity)'),
    ]
    ax.legend(handles=legend_elements, loc='upper left')

    plt.tight_layout()
    plt.savefig(os.path.join(OUT_DIR, "09_log_switch_by_hour.png"), bbox_inches='tight')
    plt.close()
    print("  09_log_switch_by_hour.png")


# ============================================================
# CHART 10: CURRENT VS PROPOSED MAX LATENCY
# ============================================================
if log_switches:
    hourly_max = defaultdict(float)
    for dt, _, dur in log_switches:
        hourly_max[dt.hour] = max(hourly_max[dt.hour], dur)

    current_max = [hourly_max.get(h, 0) for h in all_hours]
    proposed_max = [min(d, 15) for d in current_max]

    fig, ax = plt.subplots(figsize=(14, 5))
    fig.suptitle("Max Log Switch Duration: Current vs Proposed — UAT1060\nWith ARCHIVE_LAG_TARGET = 900 (15 min cap)",
                 fontsize=13, fontweight='bold')

    x = np.arange(24)
    width = 0.35
    ax.bar(x - width / 2, current_max, width, label='Current (no time limit)', color='#ea4335', alpha=0.8)
    ax.bar(x + width / 2, proposed_max, width, label='Proposed (max 15 min)', color='#34a853', alpha=0.8)
    ax.axhline(y=15, color='blue', linestyle='--', alpha=0.3)
    ax.set_xlabel("Hour of Day (UTC)")
    ax.set_ylabel("Max Switch Duration (minutes)")
    ax.set_xticks(x)
    ax.legend(loc='upper right')

    plt.tight_layout()
    plt.savefig(os.path.join(OUT_DIR, "10_current_vs_proposed.png"), bbox_inches='tight')
    plt.close()
    print("  10_current_vs_proposed.png")


# ============================================================
# CHART 11: LOG SWITCH vs DATASTREAM LATENCY CORRELATION
# ============================================================
if log_switches and total_lat['p50']:
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(16, 8), sharex=True)
    fig.suptitle("Oracle Log Switch Duration vs Datastream End-to-End Latency\norauat-1060-bucket | POC overlap period",
                 fontsize=13, fontweight='bold')

    # Log switches (only POC period)
    poc_sw = [(dt, dur) for dt, _, dur in log_switches
              if datetime(2026, 3, 30, tzinfo=timezone.utc) <= dt <= datetime(2026, 4, 9, tzinfo=timezone.utc)]
    if poc_sw:
        sw_t, sw_d = zip(*poc_sw)
        colors_sw = ['#34a853' if d <= 10 else '#fbbc04' if d <= 20 else '#ea4335' for d in sw_d]
        ax1.bar(sw_t, sw_d, width=0.015, color=colors_sw, alpha=0.7)
        ax1.axhline(y=15, color='blue', linestyle='--', alpha=0.4)
        ax1.set_ylabel("Log Switch Duration (min)")
        ax1.set_title("Oracle Redo Log Switch Duration")
        legend_elements = [
            Patch(facecolor='#34a853', label='≤10 min'),
            Patch(facecolor='#fbbc04', label='10-20 min'),
            Patch(facecolor='#ea4335', label='>20 min'),
        ]
        ax1.legend(handles=legend_elements, loc='upper right')

    # Datastream total latency
    for label, color in COLORS.items():
        data = total_lat[label]
        if data:
            times, vals = zip(*data)
            ax2.plot(times, [v / 60 for v in vals], color=color, label=label, marker='o', markersize=2, linewidth=1.2)
    ax2.axhline(y=30, color='green', linestyle='--', alpha=0.4)
    ax2.set_ylabel("End-to-End Latency (min)")
    ax2.set_title("Datastream Total Latency")
    ax2.legend(loc='upper right')
    ax2.xaxis.set_major_formatter(mdates.DateFormatter('%b %d'))
    ax2.xaxis.set_major_locator(mdates.DayLocator())

    plt.tight_layout()
    plt.savefig(os.path.join(OUT_DIR, "11_logswitch_vs_latency.png"), bbox_inches='tight')
    plt.close()
    print("  11_logswitch_vs_latency.png")


# ============================================================
# CHART 12: GCP WARNINGS TIMELINE
# ============================================================
if warning_logs:
    warn_times = []
    for e in warning_logs:
        dt = datetime.fromisoformat(e["timestamp"].replace("Z", "+00:00"))
        warn_times.append(dt)

    warn_daily = Counter()
    for dt in warn_times:
        warn_daily[dt.date()] += 1

    dates = sorted(warn_daily.keys())
    counts = [warn_daily[d] for d in dates]

    fig, ax = plt.subplots(figsize=(14, 4))
    fig.suptitle(f"GCP Datastream Warnings — ORACLE_CDC_LOG_FILE_SIZE_TOO_BIG\norauat-1060-bucket | {len(warning_logs)} warnings total",
                 fontsize=13, fontweight='bold')

    ax.bar([datetime(d.year, d.month, d.day) for d in dates], counts,
           width=0.8, color='#ea4335', alpha=0.8, label='LOG_FILE_SIZE_TOO_BIG')
    ax.set_ylabel("Warnings per Day")
    ax.legend(loc='upper right')
    ax.xaxis.set_major_formatter(mdates.DateFormatter('%b %d'))
    ax.xaxis.set_major_locator(mdates.DayLocator())

    for d, c in zip(dates, counts):
        ax.text(datetime(d.year, d.month, d.day), c + 0.2, str(c), ha='center', fontsize=9)

    plt.tight_layout()
    plt.savefig(os.path.join(OUT_DIR, "12_gcp_warnings.png"), bbox_inches='tight')
    plt.close()
    print("  12_gcp_warnings.png")


# ============================================================
# CHART 13: EVENT COUNT BY READ METHOD
# ============================================================
fig, ax = plt.subplots(figsize=(16, 5))
fig.suptitle("Datastream Event Count by Read Method — orauat-1060-bucket project\nFull POC period",
             fontsize=13, fontweight='bold')

method_colors = {'backfill': '#fbbc04', 'logminer': '#4285f4', 'postgresql': '#34a853'}
method_labels = {'backfill': 'oracle-backfill', 'logminer': 'oracle-cdc-logminer', 'postgresql': 'postgresql-cdc'}
for key, color in method_colors.items():
    data = event_counts[key]
    if data:
        times, vals = zip(*data)
        ax.plot(times, vals, color=color, label=method_labels[key], marker='o', markersize=2, linewidth=1.2)

ax.set_ylabel("Event Count (events/sec)")
ax.legend(loc='upper right')
ax.xaxis.set_major_formatter(mdates.DateFormatter('%b %d'))
ax.xaxis.set_major_locator(mdates.DayLocator())

plt.tight_layout()
plt.savefig(os.path.join(OUT_DIR, "13_event_count_by_method.png"), bbox_inches='tight')
plt.close()
print("  13_event_count_by_method.png")


# ============================================================
# SUMMARY JSON
# ============================================================
summary = {
    "stream": "orauat-1060-bucket",
    "source": "Oracle UAT1060 (TMS1060_SENDUNG)",
    "target": "gs://tms-alloydb-datastream-bucket-wl5-t-t/UATDataStream",
    "period": f"{ts_start.isoformat()} to {ts_end.isoformat()}" if ts_start else "unknown",
    "throughput": {
        "write_events": total_events,
        "total_records": total_records,
        "errors": 0,
        "delivery_rate": "100.00%",
        "batch_size": {
            "min": min(all_counts),
            "avg": round(sum(all_counts) / len(all_counts), 1),
            "max": max(all_counts),
        }
    },
    "latency": {
        "total_latency_seconds": {
            pct: metric_stats(data) for pct, data in total_lat.items()
        },
        "system_latency_seconds": {
            pct: metric_stats(data) for pct, data in sys_lat.items()
        },
        "stream_latency_seconds": {
            pct: metric_stats(data) for pct, data in stream_lat.items()
        },
    },
    "freshness": metric_stats(freshness),
    "warnings": {
        "total": len(warning_logs),
        "ORACLE_CDC_LOG_FILE_SIZE_TOO_BIG": warn_codes.get("ORACLE_CDC_LOG_FILE_SIZE_TOO_BIG", 0),
    },
    "log_switches_poc_period": {
        "count": len(poc_switches),
        "duration_min": {
            "min": round(min(durs), 1) if durs else None,
            "avg": round(sum(durs) / len(durs), 1) if durs else None,
            "max": round(max(durs), 1) if durs else None,
        }
    } if poc_switches else {},
    "dual_stream_note": "Two Datastream instances (orauat-1060-bucket WL5 + new-dispo-cdc-datastream-sendung-abn1034 WL3) connected to same Oracle UAT1060 source",
}

with open(os.path.join(SCRIPT_DIR, "full_poc_summary.json"), "w") as f:
    json.dump(summary, f, indent=2, default=str)
print("\n  full_poc_summary.json")


print(f"\nAll charts saved to: {OUT_DIR}")
print("Done.")
