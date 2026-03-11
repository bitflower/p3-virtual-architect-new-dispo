# Extract Trace Skill

Automatically extracts and consolidates trace logs from all three components (Frontend, Backend, TMS Bridge) after a tour calculation.

## Usage

```
/extract-trace
```

Then paste the Frontend console log when prompted.

## What It Does

1. ✅ Extracts trace ID from Frontend console log
2. ✅ Searches Backend logs for matching trace
3. ✅ Searches TMS Bridge logs for matching trace
4. ✅ Creates timestamped folder with trace ID
5. ✅ Copies all 3 log files to consolidated location
6. ✅ Generates `complete-trace.json` with all capture points and performance metrics
7. ✅ Generates `README.md` with timeline, analysis, and bottleneck identification

## Prerequisites

- Backend and TMS Bridge must be running and writing logs to files
- Serilog must be configured with Console and File sinks at Information level
- A tour calculation must have been performed (generating a trace ID)

## Example

```bash
# 1. Run tour calculation in Frontend
# 2. Copy console log from Chrome DevTools
# 3. Run skill

/extract-trace

# Paste log when prompted:
[TraceIdService] Generated new trace ID: 6837d454-6b09-41d5-be55-be6316e3790d
[CalculateRoutesService] Starting tour calculation...
[TraceCaptureService] {"traceId":"6837d454..."...}
...
```

## Output

Creates a folder structure:

```
02_Explorations/2026-03-10_holistic-tour-calculation-tracing/trace-logs/
└── 2026-03-10_18-23-37_trace-6837d454/
    ├── complete-trace.json          ← All 14 capture points + metrics
    ├── frontend-console-log.txt     ← Your pasted log
    ├── backend-log-20260310.txt     ← Auto-fetched from Backend
    ├── tms-bridge-log-20260310.txt  ← Auto-fetched from TMS Bridge
    └── README.md                     ← Timeline and performance analysis
```

## What Gets Analyzed

### Capture Points (14 total)
- Frontend: CP-FE-1, CP-FE-2
- Backend: CP-BE-1 through CP-BE-8
- TMS Bridge: CP-TB-1, CP-TB-1-Complete, CP-TB-2, CP-TB-2-Complete

### Performance Metrics
- Total duration
- Step-by-step timing (duration between each capture point)
- Cumulative execution time (elapsed from start)
- Component breakdown (Frontend/Backend/TMS Bridge percentages)
- Operation breakdown (GetPoolDto, TOP Service, SetPoolDto)
- Bottleneck identification (slowest operation)

### Output Files

**complete-trace.json**
- Structured JSON with all capture points
- Full metadata (timestamps, durations, data)
- Performance metrics and bottleneck analysis
- Queryable with `jq` command

**README.md**
- Timeline table with step and cumulative durations
- Performance breakdown by operation
- Visual timeline (ASCII art)
- Key findings and recommendations

## Troubleshooting

### "No Backend logs found"
- Check if Backend service is running
- Verify Serilog configuration in `appsettings.Local.json`
- Check logs directory exists: `Code/Disposition-Backend/CALConsult.Disposition.API/logs/`

### "No TMS Bridge logs found"
- Check if TMS Bridge service is running
- Verify Serilog configuration in `appsettings.Development.json`
- Check logs directory exists: `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/logs/`

### "Trace ID not found"
- Verify services were restarted after Serilog config changes
- Check if X-Trace-Id header is being sent (DevTools → Network → Headers)
- Verify TraceContextMiddleware is registered in both Backend and TMS Bridge

### "Only X/14 capture points found"
- Less than 8 points: Request failed in Backend
- 8-12 points: TMS Bridge or TOP Service issue
- 13 points: Frontend didn't receive response
- Check error logs for more details

## Advanced Usage

Query the generated JSON:

```bash
cd trace-logs/2026-03-10_18-23-37_trace-6837d454/

# Get all capture points
jq '.capturePoints[]' complete-trace.json

# Get only Backend operations
jq '.capturePoints[] | select(.component == "Backend")' complete-trace.json

# Get operations over 1 second
jq '.capturePoints[] | select(.durationMs > 1000)' complete-trace.json

# Get bottleneck info
jq '.performanceMetrics.bottleneck' complete-trace.json
```

## Tips

1. Run immediately after tour calculation (easier to find in fresh logs)
2. Keep browser console open during calculation (makes copying easier)
3. Use DevTools Console filter: `TraceIdService OR TraceCaptureService`
4. Ensure all services (Frontend, Backend, TMS Bridge) are running
5. Verify log output is configured (Console + File sinks)

## Related Documentation

- [User Guide](../../../02_Explorations/2026-03-10_holistic-tour-calculation-tracing/user-guide.md)
- [Test Validation](../../../02_Explorations/2026-03-10_holistic-tour-calculation-tracing/test-validation.md)
- [Storage Strategy](../../../02_Explorations/2026-03-10_holistic-tour-calculation-tracing/storage-strategy.md)
- [How to Extract Traces](../../../02_Explorations/2026-03-10_holistic-tour-calculation-tracing/trace-logs/HOW-TO-EXTRACT-TRACES.md)
