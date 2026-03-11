# How to Extract and Analyze Traces

This guide explains how to use the `/extract-trace` skill to automatically consolidate trace logs from all three components.

## Quick Start

1. **Trigger a tour calculation** in the Frontend
2. **Copy the console log** from Chrome DevTools (include the trace ID lines)
3. **Run the skill:**
   ```
   /extract-trace
   ```
4. **Paste the Frontend console log** when prompted

The skill will automatically:
- Extract the trace ID
- Search Backend and TMS Bridge logs
- Create a timestamped folder
- Generate `complete-trace.json`
- Generate `README.md` with analysis

## What Gets Created

```
trace-logs/
└── YYYY-MM-DD_HH-MM-SS_trace-<short-id>/
    ├── complete-trace.json          ← Structured JSON with all 14 capture points
    ├── frontend-console-log.txt     ← Your pasted console log
    ├── backend-log-YYYYMMDD.txt     ← Backend Serilog output
    ├── tms-bridge-log-YYYYMMDD.txt  ← TMS Bridge Serilog output
    └── README.md                     ← Timeline, metrics, and analysis
```

## Example Console Log to Copy

When you run a tour calculation, copy everything from DevTools Console that looks like this:

```
[TraceIdService] Generated new trace ID: 6837d454-6b09-41d5-be55-be6316e3790d
[CalculateRoutesService] Starting tour calculation for order 10340432603203 with trace ID: 6837d454-6b09-41d5-be55-be6316e3790d
[TraceCaptureService] Initialized trace: 6837d454-6b09-41d5-be55-be6316e3790d
[TraceCaptureService] {"traceId":"6837d454-6b09-41d5-be55-be6316e3790d","capturePointId":"CP-FE-1",...}
...
[TraceCaptureService] {"traceId":"6837d454-6b09-41d5-be55-be6316e3790d","capturePointId":"CP-FE-2",...}
```

**Tip:** Use DevTools Console filter to show only trace-related logs:
- Filter: `[TraceIdService] OR [TraceCaptureService] OR [CalculateRoutesService]`

## What the Skill Analyzes

### Capture Points (14 total)
- **Frontend (2):** CP-FE-1, CP-FE-2
- **Backend (8):** CP-BE-1 through CP-BE-8
- **TMS Bridge (4):** CP-TB-1, CP-TB-1-Complete, CP-TB-2, CP-TB-2-Complete

### Performance Metrics
- Total duration
- Step-by-step timing
- Cumulative execution time
- Bottleneck identification
- Component breakdown percentages

### Output Files

#### complete-trace.json
Structured JSON with:
- All 14 capture points in sequence
- Full metadata (timestamps, durations, data)
- Performance metrics and bottleneck analysis
- Queryable with `jq`

#### README.md
Human-readable analysis with:
- Timeline table with step and cumulative durations
- Performance breakdown
- Visual timeline (ASCII)
- Key findings and bottleneck identification

## Troubleshooting

### "No Backend logs found"
**Cause:** Backend not writing logs or wrong path
**Fix:**
1. Check if Backend is running
2. Verify Serilog configuration in `appsettings.Local.json`
3. Check logs directory exists: `Code/Disposition-Backend/CALConsult.Disposition.API/logs/`

### "No TMS Bridge logs found"
**Cause:** TMS Bridge not writing logs or wrong path
**Fix:**
1. Check if TMS Bridge is running
2. Verify Serilog configuration in `appsettings.Development.json`
3. Check logs directory exists: `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/logs/`

### "Trace ID not found in Backend/TMS Bridge"
**Cause:** Trace didn't propagate correctly
**Fix:**
1. Verify Backend and TMS Bridge were restarted after Serilog config changes
2. Check if X-Trace-Id header is being sent (DevTools → Network → Headers)
3. Verify TraceContextMiddleware is registered in both services

### "Only X capture points found (expected 14)"
**Cause:** Request failed or didn't complete
**Check:**
- If < 8 points: Request failed in Backend
- If 8-12 points: TMS Bridge or TOP Service issue
- If 13 points: Frontend didn't receive response

## Advanced Usage

### Query the JSON with jq

```bash
cd trace-logs/2026-03-10_18-23-37_trace-6837d454/

# Get all capture points
jq '.capturePoints[]' complete-trace.json

# Get only Backend operations
jq '.capturePoints[] | select(.component == "Backend")' complete-trace.json

# Get durations over 1 second
jq '.capturePoints[] | select(.durationMs > 1000)' complete-trace.json

# Get bottleneck info
jq '.performanceMetrics.bottleneck' complete-trace.json
```

### Filter Logs

```bash
# Extract only this trace from full log
grep "6837d454-6b09-41d5-be55-be6316e3790d" backend-log-20260310.txt > trace-only.txt

# Count capture points per component
grep "CapturePoint=CP" backend-log-20260310.txt | grep "6837d454" | wc -l
```

## Tips

1. **Run immediately after calculation** - Log files get large, easier to search when fresh
2. **Keep the browser console open** - Makes it easy to copy logs
3. **Use console filters** - Reduces noise when copying logs
4. **Check all services are running** - Backend, TMS Bridge, and Frontend must all be active
5. **Verify log output** - Ensure services are configured to write to files

## Skill Location

The `/extract-trace` skill is available in all three component repositories:
- `Code/Disposition-Frontend/.claude/skills/extract-trace.md`
- `Code/Disposition-Backend/.claude/skills/extract-trace.md`
- `Code/Disposition-Abstraction-Layer/.claude/skills/extract-trace.md`

You can run it from any of these locations.

## Example Output

```
✅ Trace extracted successfully!

Folder: 02_Explorations/2026-03-10_holistic-tour-calculation-tracing/trace-logs/2026-03-10_18-23-37_trace-6837d454/

Files created:
✅ complete-trace.json (structured trace data)
✅ frontend-console-log.txt
✅ backend-log-20260310.txt
✅ tms-bridge-log-20260310.txt
✅ README.md (analysis and timeline)

Capture Points: 14/14 ✅
Duration: 7.895 seconds
Bottleneck: TOP Service (5.987s, 76%)

Next steps:
- Open README.md for detailed timeline and analysis
- Query complete-trace.json with jq for specific insights
- Share trace-6837d454 folder with team for debugging
```
