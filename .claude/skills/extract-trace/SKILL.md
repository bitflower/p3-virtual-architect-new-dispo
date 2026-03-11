---
name: extract-trace
description: Extract and consolidate trace logs from Frontend, Backend, and TMS Bridge. Creates a timestamped folder with JSON analysis and README. Use after a tour calculation when the user wants to analyze the complete trace.
allowed-tools: Bash,Write,Read,Grep,AskUserQuestion
---

# Extract Trace Skill

This skill extracts trace logs from all three components (Frontend, Backend, TMS Bridge) and creates a consolidated trace report with JSON and README.

## When to Use

- User wants to analyze a tour calculation trace
- User needs to consolidate logs from all components
- User wants performance analysis of a specific trace
- User provides Frontend console log with trace ID

## How It Works

### Step 1: Get Frontend Console Log

Ask the user to paste their Frontend console log. The log should include:
```
[TraceIdService] Generated new trace ID: <uuid>
[TraceCaptureService] {"traceId":"<uuid>",...}
```

Use AskUserQuestion to prompt:
```
Please paste the Frontend console log from Chrome DevTools (including the trace ID lines):
```

### Step 2: Extract Trace ID

Parse the Frontend log to extract:
- Trace ID (UUID format)
- Transport Order ID
- Start timestamp (from CP-FE-1)
- End timestamp (from CP-FE-2)
- Total duration

Look for pattern: `Generated new trace ID: <uuid>`

### Step 3: Find Log Files

Search for the most recent log files:

```bash
# Backend
BACKEND_LOG=$(ls -t "/Users/matthiasmax/Documents/CAL Consult/Virtual Architect - New Dispo/Code/Disposition-Backend/CALConsult.Disposition.API/logs/log-*.txt" 2>/dev/null | head -1)

# TMS Bridge
TMS_LOG=$(ls -t "/Users/matthiasmax/Documents/CAL Consult/Virtual Architect - New Dispo/Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/logs/log-*.txt" 2>/dev/null | head -1)
```

### Step 4: Extract Backend Traces

Use Grep to find all Backend capture points:

```bash
grep "<trace-id>" "$BACKEND_LOG"
```

Extract CP-BE-1 through CP-BE-8 with:
- Timestamp
- Capture Point ID
- Label
- Duration (if available)

### Step 5: Extract TMS Bridge Traces

Use Grep to find all TMS Bridge capture points:

```bash
grep "<trace-id>" "$TMS_LOG"
```

Extract CP-TB-1, CP-TB-1-Complete, CP-TB-2, CP-TB-2-Complete with:
- Timestamp
- Capture Point ID
- Label
- Duration (if available)

### Step 6: Create Timestamped Folder

Create folder with format:
```
YYYY-MM-DD_HH-MM-SS_trace-<first-8-chars-of-uuid>
```

Example:
```
2026-03-10_18-23-37_trace-6837d454
```

Base path:
```
/Users/matthiasmax/Documents/CAL Consult/Virtual Architect - New Dispo/02_Explorations/2026-03-10_holistic-tour-calculation-tracing/trace-logs/
```

### Step 7: Copy Log Files

Copy the three log files:

```bash
# Frontend (save pasted log)
cat > "$FOLDER/frontend-console-log.txt" << 'EOF'
<pasted log content>
EOF

# Backend (copy from source)
cp "$BACKEND_LOG" "$FOLDER/backend-log-$(basename "$BACKEND_LOG")"

# TMS Bridge (copy from source)
cp "$TMS_LOG" "$FOLDER/tms-bridge-log-$(basename "$TMS_LOG")"
```

### Step 8: Parse All Capture Points

Collect all 14 capture points in chronological order:

1. CP-FE-1 (Frontend)
2. CP-BE-1 (Backend)
3. CP-BE-2 (Backend)
4. CP-TB-1 (TMS Bridge)
5. CP-TB-1-Complete (TMS Bridge)
6. CP-BE-3 (Backend)
7. CP-BE-4 (Backend)
8. CP-BE-5 (Backend)
9. CP-BE-6 (Backend)
10. CP-TB-2 (TMS Bridge)
11. CP-TB-2-Complete (TMS Bridge)
12. CP-BE-7 (Backend)
13. CP-BE-8 (Backend)
14. CP-FE-2 (Frontend)

For each point, extract:
- Sequence number
- Capture Point ID
- Component name
- Timestamp (UTC)
- Local timestamp (from logs)
- Label/description
- Duration (time from previous point)
- Cumulative time (from start)

### Step 9: Calculate Performance Metrics

Calculate:

**Durations:**
- Total duration (CP-FE-1 to CP-FE-2)
- GetPoolDto (CP-BE-2 to CP-BE-3)
- TOP Service (CP-BE-4 to CP-BE-5)
- SetPoolDto (CP-BE-6 to CP-BE-7)

**Percentages:**
- Each operation as % of total

**Bottleneck:**
- Identify longest operation (usually TOP Service)

### Step 10: Generate complete-trace.json

Create JSON with structure:

```json
{
  "traceId": "<uuid>",
  "transportOrderId": "<order-id>",
  "startTime": "<UTC timestamp>",
  "endTime": "<UTC timestamp>",
  "totalDurationMs": <number>,
  "status": "success",
  "capturePoints": [
    {
      "sequence": 1,
      "capturePointId": "CP-FE-1",
      "component": "Frontend",
      "timestamp": "<UTC>",
      "label": "...",
      "data": {...}
    },
    ...
  ],
  "performanceMetrics": {
    "totalDurationMs": <number>,
    "breakdown": {
      "getPoolDtoMs": <number>,
      "getPoolDtoPercent": <number>,
      "topServiceMs": <number>,
      "topServicePercent": <number>,
      "setPoolDtoMs": <number>,
      "setPoolDtoPercent": <number>
    },
    "bottleneck": {
      "component": "...",
      "durationMs": <number>,
      "percentOfTotal": <number>
    }
  }
}
```

### Step 11: Generate README.md

Create README with:

**Header:**
```markdown
# Trace Logs: <trace-id>

**Timestamp:** YYYY-MM-DD HH:MM:SS (Local) / YYYY-MM-DD HH:MM:SS (UTC)
**Transport Order:** <order-id>
**Duration:** X.XXX seconds
```

**Files Section:**
List all 4 files

**Capture Points Table:**
```markdown
| Time | Component | Capture Point | Label | Step Duration | Cumulative Time |
|------|-----------|---------------|-------|---------------|-----------------|
| ... | ... | ... | ... | Xms | Xms |
```

**Performance Analysis:**
- Total duration
- Major operations table
- Key findings (bottleneck, TMS Bridge performance, overhead)
- Visual timeline (ASCII art)

Use the same format as:
```
02_Explorations/2026-03-10_holistic-tour-calculation-tracing/trace-logs/2026-03-10_18-23-37_trace-6837d454/README.md
```

### Step 12: Output Results

Show the user:

```
✅ Trace extracted successfully!

Folder: 02_Explorations/.../trace-logs/YYYY-MM-DD_HH-MM-SS_trace-XXXXXXXX/

Files created:
✅ complete-trace.json (structured trace data)
✅ frontend-console-log.txt
✅ backend-log-YYYYMMDD.txt
✅ tms-bridge-log-YYYYMMDD.txt
✅ README.md (analysis and timeline)

Capture Points: X/14 ✅
Duration: X.XXX seconds
Bottleneck: TOP Service (X.XXXs, XX%)

Next steps:
- Open README.md for detailed timeline and analysis
- Query complete-trace.json with jq for specific insights
- Share trace folder with team for debugging
```

## Error Handling

### Trace ID Not Found in Backend
- Alert user: "⚠️ Trace ID not found in Backend logs"
- Check if Backend is running and writing logs
- Verify Backend Serilog configuration includes Console and File sinks
- Suggest checking if Backend was restarted after config changes

### Trace ID Not Found in TMS Bridge
- Alert user: "⚠️ Trace ID not found in TMS Bridge logs"
- Check if TMS Bridge is running and writing logs
- Verify TMS Bridge Serilog configuration
- Continue with available data, mark TMS Bridge points as missing in README

### No Log Files Found
- Alert user about missing log files
- Show expected paths
- Suggest checking if services are running
- Provide instructions to verify Serilog configuration

### Incomplete Trace (< 14 capture points)
- Show which points are missing
- Provide diagnosis:
  - < 8 points: Request failed in Backend
  - 8-12 points: TMS Bridge or TOP Service issue
  - 13 points: Frontend didn't receive response
- Create folder with available data anyway

## Tips

- Run this skill immediately after a tour calculation
- Ensure Backend and TMS Bridge are running and writing logs
- Check that Serilog is configured with Console and File sinks at Information level
- Use DevTools Console filter to reduce noise when copying Frontend logs
