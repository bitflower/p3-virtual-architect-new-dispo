# Second Trace Capture: Tour Calculation Tracing (post timing fix)

**Date:** 2026-05-25  
**Trace ID:** `ea109799-a1f1-49d7-8901-ad2fdd1a00b0`  
**Total Duration:** 4,018 ms (Frontend-measured)  
**Trace completed correctly:** duration: 4,000ms, points: 10

## Trace Timeline

| # | Capture Point | Component | Label | Timestamp | Duration |
|---|---|---|---|---|---|
| 1 | CP-FE-1 | Frontend | Calculate routes request initiated | 06:42:29.193 | — |
| 2 | CP-BE-1 | Backend | Calculate Routes request received | 06:42:29.202 | — |
| 3 | CP-BE-2 | Backend | Before GetPoolDto call to TMS Bridge | 06:42:29.204 | — |
| 4 | CP-BE-3 | Backend | After GetPoolDto call - PoolDTO received | 06:42:29.754 | 549 ms |
| 5 | CP-BE-4 | Backend | Before TOP Service call | 06:42:29.754 | — |
| 6 | CP-BE-5 | Backend | After TOP Service call - Enriched PoolDTO | 06:42:32.836 | 3,083 ms |
| 7 | CP-BE-6 | Backend | Before SetPoolDto call to TMS Bridge | 06:42:32.836 | — |
| 8 | CP-BE-7 | Backend | After SetPoolDto call | 06:42:33.192 | 356 ms |
| 9 | CP-BE-8 | Backend | Calculate Routes response sent | 06:42:33.193 | 3,991 ms |
| 10 | CP-FE-2 | Frontend | Calculate routes response received - Success | 06:42:33.211 | 4,018 ms |

## Waterfall

```
FE-1  |>                                                              |  Request initiated
BE-1  | >                                                             |  Backend received
BE-2  | >                                                             |  -> TMS Bridge: GetPoolDto
BE-3  |        >                                                      |  <- TMS Bridge: PoolDTO (549ms)
BE-4  |        >                                                      |  -> TOP Service
BE-5  |                                                      >        |  <- TOP Service: Enriched (3,083ms)
BE-6  |                                                      >        |  -> TMS Bridge: SetPoolDto
BE-7  |                                                            >  |  <- TMS Bridge: SetPool done (356ms)
BE-8  |                                                            >  |  Backend response sent (3,991ms total)
FE-2  |                                                             > |  Frontend received (4,018ms total)
      0s        1s        2s        3s        4s
```

## Breakdown

| Phase | Duration | % of Total |
|---|---|---|
| Frontend -> Backend transit | 9 ms | 0.2% |
| TMS Bridge: GetPoolDto | 549 ms | 13.7% |
| TOP Service optimization | 3,083 ms | **76.7%** |
| TMS Bridge: SetPoolDto | 356 ms | 8.9% |
| Backend overhead + response | 21 ms | 0.5% |
| **Total (FE-measured)** | **4,018 ms** | **100%** |

## Comparison with First Run

| Metric | Run 1 | Run 2 | Delta |
|---|---|---|---|
| Total (FE) | 6,433 ms | 4,018 ms | -37.5% |
| TMS Bridge: GetPoolDto | 767 ms | 549 ms | -28.4% |
| TOP Service | 5,145 ms | 3,083 ms | -40.1% |
| TMS Bridge: SetPoolDto | 403 ms | 356 ms | -11.7% |
| completeTrace points | 1 (bug) | 10 (fixed) | -- |
| completeTrace duration | 0 ms (bug) | 4,000 ms (correct) | -- |

## Observations

- Timing fix confirmed working: `completeTrace` now reports 10 points and 4,000ms duration
- TOP Service still dominates at ~77% of total time
- Second run is faster overall (likely warm caches on TMS Bridge and TOP)
- Network overhead (FE->BE transit + BE processing) is negligible at <1%
