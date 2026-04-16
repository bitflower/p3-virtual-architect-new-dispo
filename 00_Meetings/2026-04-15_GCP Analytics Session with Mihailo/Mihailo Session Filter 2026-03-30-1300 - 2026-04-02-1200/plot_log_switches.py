"""
Plot Oracle redo log switch data from Robert's DBA response.
Shows switch frequency vs time of day to visualize activity patterns.
"""

import os
from datetime import datetime
from collections import defaultdict
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
import numpy as np

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

# Raw data from Robert's email (Apr 13-16, 2026)
raw = """2026-04-13 07:25,5.4
2026-04-13 07:31,29.6
2026-04-13 08:00,30.3
2026-04-13 08:31,24.5
2026-04-13 08:55,5.2
2026-04-13 09:00,26.9
2026-04-13 09:27,3.1
2026-04-13 09:30,30
2026-04-13 10:00,26.3
2026-04-13 10:26,3.8
2026-04-13 10:30,30.1
2026-04-13 11:00,29.9
2026-04-13 11:30,30
2026-04-13 12:00,30
2026-04-13 12:30,30
2026-04-13 13:00,20
2026-04-13 13:20,10.4
2026-04-13 13:31,19.5
2026-04-13 13:50,10.6
2026-04-13 14:01,28.2
2026-04-13 14:29,1.4
2026-04-13 14:30,26.9
2026-04-13 14:57,3.1
2026-04-13 15:00,27.6
2026-04-13 15:28,2.4
2026-04-13 15:30,29.5
2026-04-13 16:00,0.5
2026-04-13 16:00,30
2026-04-13 16:30,30
2026-04-13 17:00,30
2026-04-13 17:30,27.2
2026-04-13 17:57,2.8
2026-04-13 18:00,30
2026-04-13 18:30,28.8
2026-04-13 18:59,1.2
2026-04-13 19:00,22.9
2026-04-13 19:23,7
2026-04-13 19:30,29.7
2026-04-13 20:00,0.3
2026-04-13 20:00,30
2026-04-13 20:30,30
2026-04-13 21:00,30
2026-04-13 21:30,22.5
2026-04-13 21:53,7.8
2026-04-13 22:01,9.6
2026-04-13 22:10,8.7
2026-04-13 22:19,11.5
2026-04-13 22:30,29.8
2026-04-13 23:00,30
2026-04-13 23:30,30
2026-04-14 00:00,13.5
2026-04-14 00:14,16.6
2026-04-14 00:30,26.8
2026-04-14 00:57,3.1
2026-04-14 01:00,3.4
2026-04-14 01:04,5.7
2026-04-14 01:09,9.9
2026-04-14 01:19,11.1
2026-04-14 01:30,16.2
2026-04-14 01:47,13.7
2026-04-14 02:00,0.3
2026-04-14 02:00,6.2
2026-04-14 02:07,12.6
2026-04-14 02:19,11
2026-04-14 02:30,16.1
2026-04-14 02:46,13.9
2026-04-14 03:00,20.6
2026-04-14 03:21,9.3
2026-04-14 03:30,30
2026-04-14 04:00,0
2026-04-14 04:00,30
2026-04-14 04:30,29.5
2026-04-14 05:00,0.6
2026-04-14 05:00,0.6
2026-04-14 05:01,9.2
2026-04-14 05:10,20.4
2026-04-14 05:30,29.8
2026-04-14 06:00,19.8
2026-04-14 06:20,10.2
2026-04-14 06:30,27.6
2026-04-14 06:58,2.4
2026-04-14 07:00,28.8
2026-04-14 07:29,1.2
2026-04-14 07:30,27.7
2026-04-14 07:58,2.7
2026-04-14 08:01,29.6
2026-04-14 08:30,29.5
2026-04-14 09:00,0.6
2026-04-14 09:00,30
2026-04-14 09:30,29.5
2026-04-14 10:00,0.5
2026-04-14 10:00,26.5
2026-04-14 10:27,3.8
2026-04-14 10:31,29.7
2026-04-14 11:00,26.5
2026-04-14 11:27,3.4
2026-04-14 11:30,30
2026-04-14 12:00,30.4
2026-04-14 12:31,29.7
2026-04-14 13:00,14
2026-04-14 13:14,16.3
2026-04-14 13:31,26
2026-04-14 13:57,3.8
2026-04-14 14:00,26.9
2026-04-14 14:27,2.9
2026-04-14 14:30,22
2026-04-14 14:52,7.9
2026-04-14 15:00,30
2026-04-14 15:30,0.2
2026-04-14 15:30,20.7
2026-04-14 15:51,9.2
2026-04-14 16:00,30
2026-04-14 16:30,29.6
2026-04-14 17:00,0.8
2026-04-14 17:01,29.6
2026-04-14 17:30,28.8
2026-04-14 17:59,1.5
2026-04-14 18:00,29.8
2026-04-14 18:30,30
2026-04-14 19:00,21.1
2026-04-14 19:21,8.9
2026-04-14 19:30,27.7
2026-04-14 19:58,2.7
2026-04-14 20:01,21
2026-04-14 20:22,8.6
2026-04-14 20:30,23.2
2026-04-14 20:53,6.8
2026-04-14 21:00,22
2026-04-14 21:22,8.1
2026-04-14 21:30,30.2
2026-04-14 22:00,0.1
2026-04-14 22:00,4
2026-04-14 22:04,13.1
2026-04-14 22:18,12.7
2026-04-14 22:30,0.1
2026-04-14 22:30,29.9
2026-04-14 23:00,30
2026-04-14 23:30,30
2026-04-15 00:00,11.4
2026-04-15 00:12,18.7
2026-04-15 00:30,28.3
2026-04-15 00:59,1.6
2026-04-15 01:00,3.2
2026-04-15 01:03,5.3
2026-04-15 01:09,8.8
2026-04-15 01:17,12.4
2026-04-15 01:30,0.8
2026-04-15 01:31,14.3
2026-04-15 01:45,14.9
2026-04-15 02:00,0.5
2026-04-15 02:00,1.5
2026-04-15 02:02,10
2026-04-15 02:12,16.7
2026-04-15 02:28,1.8
2026-04-15 02:30,18.6
2026-04-15 02:49,11.6
2026-04-15 03:00,7.2
2026-04-15 03:08,22.5
2026-04-15 03:30,29.8
2026-04-15 04:00,0.2
2026-04-15 04:00,30.1
2026-04-15 04:30,29.5
2026-04-15 05:00,0.5
2026-04-15 05:00,0.4
2026-04-15 05:01,12.1
2026-04-15 05:13,17.7
2026-04-15 05:31,29.7
2026-04-15 06:00,14.6
2026-04-15 06:15,15.3
2026-04-15 06:30,22.1
2026-04-15 06:52,8
2026-04-15 07:00,18.2
2026-04-15 07:19,11.7
2026-04-15 07:30,28.8
2026-04-15 07:59,1.2
2026-04-15 08:00,26.1
2026-04-15 08:26,4.3
2026-04-15 08:31,28.9
2026-04-15 09:00,0.7
2026-04-15 09:00,30.4
2026-04-15 09:31,22.1
2026-04-15 09:53,7.9
2026-04-15 10:01,29.9
2026-04-15 10:31,29.2
2026-04-15 11:00,0.4
2026-04-15 11:00,30.2
2026-04-15 11:30,29.9
2026-04-15 12:00,30
2026-04-15 12:30,29.8
2026-04-15 13:00,0.2
2026-04-15 13:00,15.3
2026-04-15 13:15,15.1
2026-04-15 13:31,24.3
2026-04-15 13:55,5.7
2026-04-15 14:01,29.7
2026-04-15 14:30,27.4
2026-04-15 14:58,2.9
2026-04-15 15:01,29.4
2026-04-15 15:30,0.3
2026-04-15 15:30,27.5
2026-04-15 15:58,2.5
2026-04-15 16:00,29.4
2026-04-15 16:30,0.6
2026-04-15 16:30,29.9
2026-04-15 17:00,30.1
2026-04-15 17:30,27.6
2026-04-15 17:58,2.4
2026-04-15 18:00,30.2
2026-04-15 18:30,29.9
2026-04-15 19:00,25.9
2026-04-15 19:26,4
2026-04-15 19:30,22.1
2026-04-15 19:52,8.1
2026-04-15 20:00,27
2026-04-15 20:27,3
2026-04-15 20:30,26
2026-04-15 20:56,4
2026-04-15 21:00,26.8
2026-04-15 21:27,3.2
2026-04-15 21:30,30.2
2026-04-15 22:00,4.1
2026-04-15 22:05,8
2026-04-15 22:13,8.9
2026-04-15 22:21,8.6
2026-04-15 22:30,30.2
2026-04-15 23:00,30
2026-04-15 23:30,30
2026-04-16 00:00,11.5
2026-04-16 00:12,0.5
2026-04-16 00:12,18.3
2026-04-16 00:30,29.2
2026-04-16 01:00,0.5
2026-04-16 01:00,3.8
2026-04-16 01:04,4.3
2026-04-16 01:08,8.5
2026-04-16 01:17,13.3
2026-04-16 01:30,0.3
2026-04-16 01:30,14.4
2026-04-16 01:45,15.1
2026-04-16 02:00,0.5
2026-04-16 02:00,1.6
2026-04-16 02:02,5.3
2026-04-16 02:07,14.1
2026-04-16 02:21,9.1
2026-04-16 02:30,20.9
2026-04-16 02:51,9.1
2026-04-16 03:00,2.2
2026-04-16 03:02,27.9
2026-04-16 03:30,29.9
2026-04-16 04:00,30.4
2026-04-16 04:31,29
2026-04-16 05:00,0.6
2026-04-16 05:00,0.6
2026-04-16 05:01,13
2026-04-16 05:14,16.6
2026-04-16 05:30,25.1
2026-04-16 05:56,4.9
2026-04-16 06:00,24.8
2026-04-16 06:25,5
2026-04-16 06:30,27.9
2026-04-16 06:58,2.6"""

rows = []
for line in raw.strip().split('\n'):
    parts = line.split(',')
    dt = datetime.strptime(parts[0].strip(), '%Y-%m-%d %H:%M')
    dur = float(parts[1].strip())
    rows.append((dt, dur))

times = [r[0] for r in rows]
durations = [r[1] for r in rows]

# ============================================================
# Chart 1: Timeline — each dot is a log switch, color = duration
# ============================================================
fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(16, 8), sharex=True)
fig.suptitle("Oracle Redo Log Switch Pattern — UAT1060\n(Data from DBA, Apr 13-16 2026. ARCHIVE_LAG_TARGET = 0, Log Size = 1 GB)",
             fontsize=13, fontweight='bold')

# Scatter: x=time, y=duration, color by duration
colors_map = []
for d in durations:
    if d >= 28:
        colors_map.append('#ea4335')  # red = slow (30 min, low activity)
    elif d >= 15:
        colors_map.append('#fbbc04')  # yellow = moderate
    else:
        colors_map.append('#34a853')  # green = fast (high activity)

# Plot with legend handles
from matplotlib.lines import Line2D
s_green = ax1.scatter([], [], c='#34a853', s=20, label='< 15 min (high DB activity)')
s_yellow = ax1.scatter([], [], c='#fbbc04', s=20, label='15-28 min (moderate activity)')
s_red = ax1.scatter([], [], c='#ea4335', s=20, label='28-30 min (low activity — log takes full time to fill)')
ax1.scatter(times, durations, c=colors_map, s=20, alpha=0.7, edgecolors='none')
ax1.axhline(y=30, color='#ea4335', linestyle='--', alpha=0.4, linewidth=1)
ax1.axhline(y=15, color='#fbbc04', linestyle='--', alpha=0.4, linewidth=1)
ax1.set_ylabel("Duration until switch (min)")
ax1.set_title("Each dot = one redo log switch, colored by DB write activity level")
ax1.legend(handles=[s_green, s_yellow, s_red], loc='lower right', fontsize=9, framealpha=0.9)

# Bar: switches per hour
hourly_count = defaultdict(int)
for dt, dur in rows:
    hour_key = dt.replace(minute=0)
    hourly_count[hour_key] += 1

hours_sorted = sorted(hourly_count.keys())
counts = [hourly_count[h] for h in hours_sorted]

bar_colors = ['#34a853' if c > 3 else '#fbbc04' if c > 2 else '#ea4335' for c in counts]
ax2.bar(hours_sorted, counts, width=0.035, color=bar_colors, alpha=0.8)
ax2.set_ylabel("Switches per hour")
ax2.set_title("Log switches per hour (more = higher DB write activity)")
from matplotlib.patches import Patch
legend_elements = [
    Patch(facecolor='#34a853', alpha=0.8, label='> 3 switches/hr (high activity)'),
    Patch(facecolor='#fbbc04', alpha=0.8, label='2-3 switches/hr (moderate)'),
    Patch(facecolor='#ea4335', alpha=0.8, label='< 2 switches/hr (low activity)'),
]
ax2.legend(handles=legend_elements, loc='upper right', fontsize=9, framealpha=0.9)
ax2.xaxis.set_major_formatter(mdates.DateFormatter('%b %d\n%H:%M'))
ax2.xaxis.set_major_locator(mdates.HourLocator(interval=6))

plt.tight_layout()
plt.savefig(os.path.join(OUT_DIR, "08_log_switch_timeline.png"), bbox_inches='tight')
plt.close()
print("Saved: 08_log_switch_timeline.png")

# ============================================================
# Chart 2: Hour-of-day heatmap — avg switch duration by hour
# ============================================================
fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(14, 7))
fig.suptitle("Oracle Redo Log Activity by Hour of Day — UAT1060\nCurrent: Switches ONLY when 1 GB log is full (no time trigger)",
             fontsize=13, fontweight='bold')

hourly_durs = defaultdict(list)
hourly_counts = defaultdict(int)
for dt, dur in rows:
    h = dt.hour
    hourly_durs[h].append(dur)
    hourly_counts[h] += 1

hours = list(range(24))
avg_durs = [sum(hourly_durs[h])/len(hourly_durs[h]) if h in hourly_durs else 0 for h in hours]
switch_counts = [hourly_counts[h] for h in hours]

# Avg duration per hour
bar_colors = ['#34a853' if d < 15 else '#fbbc04' if d < 25 else '#ea4335' for d in avg_durs]
bars = ax1.bar(hours, avg_durs, color=bar_colors, alpha=0.8, edgecolor='white')
ax1.axhline(y=15, color='green', linestyle='--', alpha=0.5, linewidth=1)
ax1.text(0.5, 15.5, 'Proposed ARCHIVE_LAG_TARGET = 900 (15 min max)', fontsize=9, color='green')
ax1.axhline(y=30, color='#ea4335', linestyle='--', alpha=0.3, linewidth=1)
ax1.set_ylabel("Avg switch duration (min)")
ax1.set_xlabel("")
ax1.set_xticks(hours)
ax1.set_xticklabels([f'{h:02d}:00' for h in hours], rotation=45, fontsize=8)
ax1.set_title("Avg time between log switches (shorter = more DB activity = more redo data)")
from matplotlib.patches import Patch as Patch2
legend2 = [
    Patch2(facecolor='#34a853', alpha=0.8, label='< 15 min avg (high activity)'),
    Patch2(facecolor='#fbbc04', alpha=0.8, label='15-25 min avg (moderate)'),
    Patch2(facecolor='#ea4335', alpha=0.8, label='> 25 min avg (low activity)'),
    Line2D([0], [0], color='green', linestyle='--', label='Proposed 15 min max (ARCHIVE_LAG_TARGET=900)'),
]
ax1.legend(handles=legend2, loc='upper left', fontsize=8, framealpha=0.9)

# Annotate
for i, (h, d) in enumerate(zip(hours, avg_durs)):
    label = "LOW" if d >= 28 else ""
    if label:
        ax1.text(h, d + 0.5, label, ha='center', fontsize=7, color='#ea4335', fontweight='bold')

# Switches per hour
bar_colors2 = ['#34a853' if c > 8 else '#fbbc04' if c > 5 else '#ea4335' for c in switch_counts]
ax2.bar(hours, switch_counts, color=bar_colors2, alpha=0.8, edgecolor='white')
ax2.set_ylabel("Total switches (over 3.5 days)")
ax2.set_xlabel("Hour of day")
ax2.set_xticks(hours)
ax2.set_xticklabels([f'{h:02d}:00' for h in hours], rotation=45, fontsize=8)
ax2.set_title("Number of log switches per hour-of-day (more = higher write volume)")
legend3 = [
    Patch2(facecolor='#34a853', alpha=0.8, label='> 8 switches (high write volume)'),
    Patch2(facecolor='#fbbc04', alpha=0.8, label='5-8 switches (moderate)'),
    Patch2(facecolor='#ea4335', alpha=0.8, label='< 5 switches (low volume)'),
]
ax2.legend(handles=legend3, loc='upper right', fontsize=8, framealpha=0.9)

plt.tight_layout()
plt.savefig(os.path.join(OUT_DIR, "09_log_switch_by_hour.png"), bbox_inches='tight')
plt.close()
print("Saved: 09_log_switch_by_hour.png")

# ============================================================
# Chart 3: Current vs Proposed — what changes
# ============================================================
fig, ax = plt.subplots(figsize=(14, 5))
fig.suptitle("Impact of ARCHIVE_LAG_TARGET = 900\nMax CDC latency per hour: Current vs. Proposed",
             fontsize=13, fontweight='bold')

max_durs_current = [max(hourly_durs[h]) if h in hourly_durs else 0 for h in hours]
max_durs_proposed = [min(d, 15) for d in max_durs_current]

x = np.arange(24)
width = 0.35

bars1 = ax.bar(x - width/2, max_durs_current, width, label='Current (no time trigger)', color='#ea4335', alpha=0.7)
bars2 = ax.bar(x + width/2, max_durs_proposed, width, label='Proposed (15 min max)', color='#34a853', alpha=0.7)

ax.axhline(y=15, color='green', linestyle='--', alpha=0.5, linewidth=1)
ax.set_ylabel("Max switch duration (min)")
ax.set_xlabel("Hour of day")
ax.set_xticks(x)
ax.set_xticklabels([f'{h:02d}' for h in hours])
ax.legend(loc='upper right')
ax.set_title("Worst-case CDC latency floor by hour of day")

plt.tight_layout()
plt.savefig(os.path.join(OUT_DIR, "10_current_vs_proposed.png"), bbox_inches='tight')
plt.close()
print("Saved: 10_current_vs_proposed.png")

print(f"\nAll charts saved to: {OUT_DIR}")
