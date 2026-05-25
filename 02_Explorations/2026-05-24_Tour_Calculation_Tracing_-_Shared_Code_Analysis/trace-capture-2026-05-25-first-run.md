# First Trace Capture: Tour Calculation Tracing

**Date:** 2026-05-25  
**Transport Order:** 439766  
**Trace ID:** `6baa1fc0-7717-49df-9c37-cfc525a1c718`  
**Total Duration:** 6,433 ms (Frontend-measured)

## Trace Timeline

| # | Capture Point | Component | Label | Timestamp | Duration |
|---|---|---|---|---|---|
| 1 | CP-FE-1 | Frontend | Calculate routes request initiated | 06:36:49.850 | — |
| 2 | CP-BE-1 | Backend | Calculate Routes request received | 06:36:49.866 | — |
| 3 | CP-BE-2 | Backend | Before GetPoolDto call to TMS Bridge | 06:36:49.875 | — |
| 4 | CP-BE-3 | Backend | After GetPoolDto call - PoolDTO received | 06:36:50.641 | 767 ms |
| 5 | CP-BE-4 | Backend | Before TOP Service call | 06:36:50.641 | — |
| 6 | CP-BE-5 | Backend | After TOP Service call - Enriched PoolDTO | 06:36:55.786 | 5,145 ms |
| 7 | CP-BE-6 | Backend | Before SetPoolDto call to TMS Bridge | 06:36:55.786 | — |
| 8 | CP-BE-7 | Backend | After SetPoolDto call | 06:36:56.189 | 403 ms |
| 9 | CP-BE-8 | Backend | Calculate Routes response sent | 06:36:56.203 | 6,337 ms |
| 10 | CP-FE-2 | Frontend | Calculate routes response received - Success | 06:36:56.283 | 6,433 ms |

## Waterfall

```
FE-1  |>                                                              |  Request initiated
BE-1  | >                                                             |  Backend received
BE-2  | >                                                             |  -> TMS Bridge: GetPoolDto
BE-3  |      >                                                        |  <- TMS Bridge: PoolDTO (767ms)
BE-4  |      >                                                        |  -> TOP Service
BE-5  |                                                        >      |  <- TOP Service: Enriched (5,145ms)
BE-6  |                                                        >      |  -> TMS Bridge: SetPoolDto
BE-7  |                                                            >  |  <- TMS Bridge: SetPool done (403ms)
BE-8  |                                                             > |  Backend response sent (6,337ms total)
FE-2  |                                                              >|  Frontend received (6,433ms total)
      0s        1s        2s        3s        4s        5s        6s
```

## Breakdown

| Phase | Duration | % of Total |
|---|---|---|
| Frontend -> Backend transit | 16 ms | 0.2% |
| TMS Bridge: GetPoolDto | 767 ms | 11.9% |
| TOP Service optimization | 5,145 ms | **80.0%** |
| TMS Bridge: SetPoolDto | 403 ms | 6.3% |
| Backend overhead + response | 102 ms | 1.6% |
| **Total (FE-measured)** | **6,433 ms** | **100%** |

## Observation

The TOP Service call dominates at 80% of total time. TMS Bridge calls (GetPoolDto + SetPoolDto) account for ~18%. Network and processing overhead is minimal.
