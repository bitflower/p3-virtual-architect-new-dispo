# Trace Logs: e86fb4e5-f246-4250-b53a-39b8ad8baada

**Timestamp:** 2026-03-10 18:44:59 (Local) / 2026-03-10 17:44:59 (UTC)
**Transport Order:** 10340432603203
**Duration:** 7.113 seconds

## Files

- `complete-trace.json` - Complete trace in structured JSON format (queryable)
- `frontend-console-log.txt` - Frontend browser console output
- `backend-log-20260310.txt` - Backend Serilog output (full day log)
- `tms-bridge-log-20260310.txt` - TMS Bridge Serilog output (full day log)

## Quick Search

To extract only this trace from the logs:

```bash
# Backend traces
grep "e86fb4e5-f246-4250-b53a-39b8ad8baada" backend-log-20260310.txt

# TMS Bridge traces
grep "e86fb4e5-f246-4250-b53a-39b8ad8baada" tms-bridge-log-20260310.txt
```

## Capture Points Summary

| Time | Component | Capture Point | Label | Step Duration | Cumulative Time |
|------|-----------|---------------|-------|---------------|-----------------|
| 17:44:59.794 | Frontend | CP-FE-1 | Request initiated | 0ms | 0ms |
| 17:44:59.799 | Backend | CP-BE-1 | Request received | 5ms | 5ms |
| 17:44:59.804 | Backend | CP-BE-2 | Before GetPoolDto | 5ms | 10ms |
| 17:44:59.808 | TMS Bridge | CP-TB-1 | GetXserverDto entry | 4ms | 14ms |
| 17:45:00.334 | TMS Bridge | CP-TB-1-Complete | GetXserverDto completed | **526ms** | 540ms |
| 17:45:00.338 | Backend | CP-BE-3 | PoolDTO received | 4ms | 544ms |
| 17:45:00.338 | Backend | CP-BE-4 | Before TOP Service | 0ms | 544ms |
| 17:45:06.315 | Backend | CP-BE-5 | After TOP Service | **5,977ms** | 6,521ms |
| 17:45:06.315 | Backend | CP-BE-6 | Before SetPoolDto | 0ms | 6,521ms |
| 17:45:06.324 | TMS Bridge | CP-TB-2 | SetXserverDto entry | 9ms | 6,530ms |
| 17:45:06.901 | TMS Bridge | CP-TB-2-Complete | SetXserverDto completed | **577ms** | 7,107ms |
| 17:45:06.903 | Backend | CP-BE-7 | After SetPoolDto | 2ms | 7,109ms |
| 17:45:06.903 | Backend | CP-BE-8 | Response sent | 0ms | 7,109ms |
| 17:45:06.907 | Frontend | CP-FE-2 | Response received | 4ms | **7,113ms** |

## Performance Analysis

**Total Duration: 7,113ms (7.113 seconds)**

### Major Operations

| Operation | Duration | % of Total | Status |
|-----------|----------|------------|--------|
| TOP Service (Route Optimization) | 5,977ms | 84% | 🔴 **Bottleneck** |
| SetPoolDto (Backend → TMS) | 588ms | 8% | ✅ Normal |
| GetPoolDto (TMS → Backend) | 534ms | 8% | ✅ Normal |
| Overhead (Processing) | 14ms | 0% | ✅ Minimal |

### Key Findings

- **Bottleneck:** TOP Service optimization takes 5.977s (84% of total time)
- **TMS Bridge Performance:** Both GetXserverDto (526ms) and SetXserverDto (577ms) are within normal range
- **Backend Overhead:** Minimal processing overhead (14ms across all non-TMS/TOP operations)
- **Network Latency:** Very low (<10ms between service boundaries)

### Visual Timeline

```
0ms ────────────────────────────────────────────────────────────> 7,113ms
│
├─ 0ms: CP-FE-1 (Frontend starts)
├─ 14ms: CP-TB-1 (TMS Bridge GetXserverDto starts)
├─ 540ms: CP-TB-1-Complete (GetXserverDto done - 526ms)
├─ 544ms: CP-BE-4 (TOP Service starts)
│
├─ 6,521ms: CP-BE-5 (TOP Service done - 5,977ms) ⚠️ BOTTLENECK
│
├─ 6,530ms: CP-TB-2 (TMS Bridge SetXserverDto starts)
├─ 7,107ms: CP-TB-2-Complete (SetXserverDto done - 577ms)
└─ 7,113ms: CP-FE-2 (Frontend receives response)
```

## Comparison with Previous Trace

| Metric | Previous (6837d454) | Current (e86fb4e5) | Change |
|--------|---------------------|-------------------|--------|
| Total Duration | 7,895ms | 7,113ms | -782ms (10% faster) ✅ |
| GetPoolDto | 1,022ms | 534ms | -488ms (48% faster) ✅ |
| TOP Service | 5,987ms | 5,977ms | -10ms (similar) |
| SetPoolDto | 815ms | 588ms | -227ms (28% faster) ✅ |

**Analysis:** This trace is 10% faster overall, primarily due to improved TMS Bridge response times for both GetPoolDto and SetPoolDto operations. TOP Service performance remains consistent around 6 seconds.
