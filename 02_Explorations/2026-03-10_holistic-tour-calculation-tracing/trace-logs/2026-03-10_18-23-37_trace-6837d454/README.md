# Trace Logs: 6837d454-6b09-41d5-be55-be6316e3790d

**Timestamp:** 2026-03-10 18:23:37 (Local) / 2026-03-10 17:23:37 (UTC)
**Transport Order:** 10340432603203
**Duration:** 7.895 seconds

## Files

- `complete-trace.json` - Complete trace in structured JSON format (queryable)
- `frontend-console-log.txt` - Frontend browser console output
- `backend-log-20260310.txt` - Backend Serilog output (full day log)
- `tms-bridge-log-20260310.txt` - TMS Bridge Serilog output (full day log)

## Quick Search

To extract only this trace from the logs:

```bash
# Backend traces
grep "6837d454-6b09-41d5-be55-be6316e3790d" backend-log-20260310.txt

# TMS Bridge traces
grep "6837d454-6b09-41d5-be55-be6316e3790d" tms-bridge-log-20260310.txt
```

## Capture Points Summary

| Time | Component | Capture Point | Label | Step Duration | Cumulative Time |
|------|-----------|---------------|-------|---------------|-----------------|
| 17:23:37.654 | Frontend | CP-FE-1 | Request initiated | 0ms | 0ms |
| 17:23:37.672 | Backend | CP-BE-1 | Request received | 18ms | 18ms |
| 17:23:37.682 | Backend | CP-BE-2 | Before GetPoolDto | 10ms | 28ms |
| 17:23:37.684 | TMS Bridge | CP-TB-1 | GetXserverDto entry | 2ms | 30ms |
| 17:23:38.644 | TMS Bridge | CP-TB-1-Complete | GetXserverDto completed | **960ms** | 990ms |
| 17:23:38.704 | Backend | CP-BE-3 | PoolDTO received | 60ms | 1,050ms |
| 17:23:38.704 | Backend | CP-BE-4 | Before TOP Service | 0ms | 1,050ms |
| 17:23:44.691 | Backend | CP-BE-5 | After TOP Service | **5,987ms** | 7,037ms |
| 17:23:44.691 | Backend | CP-BE-6 | Before SetPoolDto | 0ms | 7,037ms |
| 17:23:44.712 | TMS Bridge | CP-TB-2 | SetXserverDto entry | 21ms | 7,058ms |
| 17:23:45.499 | TMS Bridge | CP-TB-2-Complete | SetXserverDto completed | **787ms** | 7,845ms |
| 17:23:45.507 | Backend | CP-BE-7 | After SetPoolDto | 8ms | 7,853ms |
| 17:23:45.534 | Backend | CP-BE-8 | Response sent | 27ms | 7,880ms |
| 17:23:45.549 | Frontend | CP-FE-2 | Response received | 15ms | **7,895ms** |

## Performance Analysis

**Total Duration: 7,895ms (7.895 seconds)**

### Major Operations

| Operation | Duration | % of Total | Status |
|-----------|----------|------------|--------|
| TOP Service (Route Optimization) | 5,987ms | 76% | 🔴 **Bottleneck** |
| GetPoolDto (TMS → Backend) | 1,022ms | 13% | ✅ Normal |
| SetPoolDto (Backend → TMS) | 815ms | 10% | ✅ Normal |
| Overhead (Processing) | 71ms | 1% | ✅ Minimal |

### Key Findings

- **Bottleneck:** TOP Service optimization takes 5.987s (76% of total time)
- **TMS Bridge Performance:** Both GetXserverDto (960ms) and SetXserverDto (787ms) are within normal range
- **Backend Overhead:** Minimal processing overhead (71ms across all non-TMS/TOP operations)
- **Network Latency:** Very low (<30ms between service boundaries)

### Visual Timeline

```
0ms ────────────────────────────────────────────────────────────> 7,895ms
│
├─ 0ms: CP-FE-1 (Frontend starts)
├─ 30ms: CP-TB-1 (TMS Bridge GetXserverDto starts)
├─ 990ms: CP-TB-1-Complete (GetXserverDto done - 960ms)
├─ 1,050ms: CP-BE-4 (TOP Service starts)
│
├─ 7,037ms: CP-BE-5 (TOP Service done - 5,987ms) ⚠️ BOTTLENECK
│
├─ 7,058ms: CP-TB-2 (TMS Bridge SetXserverDto starts)
├─ 7,845ms: CP-TB-2-Complete (SetXserverDto done - 787ms)
└─ 7,895ms: CP-FE-2 (Frontend receives response)
```
