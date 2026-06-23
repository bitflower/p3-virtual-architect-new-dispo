# PRD 010: E2E Trace ID with SQL Logging

## Problem

When a tester or product owner triggers an action in the Frontend and the result doesn't match expectations, there are two gaps:

1. **No trace ID visible in the UI.** The user cannot provide a correlation key in the bug ticket. Developers must manually search Cloud Logging by timestamp and guess which log entries belong to the reported action.

2. **No SQL visibility.** The TMS Bridge executes SQL against the TMS Database but logs nothing about it. When TMS database developers need to inspect or fix database objects, they have no SQL to work from. Today's workaround: reproduce locally with `Debug.WriteLine` output — which doesn't exist in deployed environments.

GCP Cloud Run already injects trace context (`X-Cloud-Trace-Context`) on every request. ASP.NET Core's `System.Diagnostics.Activity` already participates in W3C trace propagation on .NET 8. The infrastructure for end-to-end trace correlation exists — it's just not surfaced or used.

## Direction Alignment

- Leverages existing GCP Cloud Trace infrastructure (Cloud Run trace injection, Cloud Logging trace correlation) instead of building custom tracing
- Informed by V1 tracing exploration (`02_Explorations/2026-03-10_holistic-tour-calculation-tracing/`) for non-blocking patterns and circuit breaker design — but **does not depend on or build on V1's draft PR**
- Addresses the "cannot see inside TMS Bridge SQL" gap identified in V1's `v2-future-enhancements.md` (V2.1) — at the application layer, not stored procedure level
- Follows project convention: `appsettings.json` + `IOptions<T>` for feature toggling (no runtime flag library)

## Requirements

### Must Have

- **M1**: Frontend displays the GCP trace ID (from `traceparent` header) as a visible, copyable badge in the UI
- **M2**: TMS Bridge logs full SQL statements (EF Core + raw ADO.NET) with actual parameter values, tagged with `Activity.Current?.TraceId`
- **M3**: SQL logging is gated by an `appsettings.json` toggle (`SqlTracing:Enabled`, default `false`). Intended to be `true` in ABN/UAT, `false` in PROD.
- **M4**: SQL log format is human-readable and copy-paste valid — a TMS database developer can paste the logged statement directly into a DB client
- **M5**: SQL logging code is non-blocking — a logging failure must never fail the business operation
- **M6**: SQL log entries are searchable in GCP Cloud Logging by trace ID (same trace as Frontend and Backend logs)
- **M7**: SQL log entries include the originating GraphQL operation name for context (e.g. `GetPoolDto`, `SetPoolDto`)

### Should Have

- **S1**: SQL log entries include execution duration per statement

### Could Have

- **C1**: SQL statement count/duration summary returned in the HTTP response (visible in browser DevTools without Cloud Logging access)
- **C2**: V1 trace panel integration in a future iteration — show SQL alongside timing data

### Won't Have

- **W1**: Per-request activation header — appsettings toggle per environment is sufficient for MVP. If needed, add later.
- **W2**: V1 trace panel or timing capture points — this is a separate feature (performance tracing). May converge later.
- **W3**: Database stored procedure instrumentation (V2.1 from prior art) — application-layer capture is sufficient
- **W4**: SQL parameter masking/redaction — the appsettings toggle limits exposure; masking is a separate concern if PROD use is needed
- **W5**: TOP Service or xServer tracing — different problem space

## Out of Scope

- Modifying the V1 tracing draft PR
- OpenTelemetry SDK integration (using .NET 8's built-in `System.Diagnostics.Activity`)
- Shared NuGet packages between Backend and TMS Bridge
- Cloud Logging dashboard/alert setup
- SQL log retention policy (uses existing Cloud Logging retention)

## Security

| # | Threat | Impact | Mitigation |
|---|---|---|---|
| T1 | SQL logs contain business data (order IDs, customer refs, weights) | Data exposure in Cloud Logging | `Enabled: false` by default. On only in ABN/UAT where test data is used. Cloud Logging access restricted by IAM. |
| T2 | Logging overhead under high load | Performance degradation | Non-blocking fire-and-forget. Circuit breaker auto-disables after consecutive failures. |

## Implementation Approach (unverified hint)

### Frontend (Disposition-Frontend)

- HTTP interceptor: generate `traceparent` header on outgoing requests using `crypto.randomUUID()` formatted as W3C trace context
- New lightweight component: trace ID badge (toolbar/footer) with copy-to-clipboard. Shows the 32-hex trace ID from the current/last request.

### Backend (Disposition-Backend)

- **Likely zero code changes.** .NET 8's `HttpClient` auto-propagates `Activity` trace context when `System.Diagnostics.Activity` is active. Verify that the GraphQL client to TMS Bridge inherits the incoming trace ID.
- Serilog: verify `logging.googleapis.com/trace` field is included in structured logs (may already be present via Cloud Run's logging agent).

### TMS Bridge (Disposition-Abstraction-Layer)

- New `SqlTracingSettings` class bound to `SqlTracing` appsettings section via `IOptions<SqlTracingSettings>`
- New `SqlTraceInterceptor : DbCommandInterceptor` (EF Core) — logs SQL + parameters when enabled
- Hook raw ADO.NET command execution in custom command builders (Postgres/Oracle) for non-EF queries
- Format: interpolated SQL with parameter values as a single human-readable string
- Log via Serilog tagged with `Activity.Current?.TraceId`
- Include GraphQL operation name from request context
- Non-blocking: wrap in try-catch, never throw from interceptor

## Files Likely to Change

| File | Change | New/Modified |
|---|---|---|
| **Frontend** | | |
| `libs/nagel-utils/src/lib/interceptors/logger.interceptor.ts` | Add `traceparent` header generation | Modified |
| Trace ID badge component (location TBD) | New component: badge + copy button | New |
| **Backend** | | |
| Possibly `GraphQLServiceSetupExtensions.cs` | Verify trace context propagation (may need no changes) | Verify |
| **TMS Bridge** | | |
| `appsettings.json` (+ ABN/UAT/DEV overrides) | Add `SqlTracing` section | Modified |
| New: `SqlTracingSettings.cs` | Options class | New |
| New: `SqlTraceInterceptor.cs` | `DbCommandInterceptor` implementation | New |
| `BranchDbContext.cs` | Register interceptor | Modified |
| Custom command builder files (Postgres/Oracle) | Add trace logging around raw SQL execution | Modified |
| `Startup.cs` or `Program.cs` | Register `IOptions<SqlTracingSettings>` | Modified |

## Verification

- [ ] Trigger any Frontend action that hits TMS Bridge. Verify the trace ID badge shows a 32-hex trace ID.
- [ ] Copy the trace ID. Search Cloud Logging. Verify Backend request logs and TMS Bridge SQL logs appear under the same trace.
- [ ] With `SqlTracing:Enabled: false`, verify zero SQL log entries appear.
- [ ] With `SqlTracing:Enabled: true`, verify full SQL with parameter values appears in Cloud Logging, including the GraphQL operation name.
- [ ] Copy a logged SQL statement. Paste into pgAdmin/DBeaver. Verify it parses as valid SQL.
- [ ] Inject a failure in the SQL interceptor. Verify the business operation succeeds (non-blocking).
- [ ] Run a tour calculation with SQL logging on vs. off. Verify < 5% overhead.

## Related

- `02_Explorations/2026-03-10_holistic-tour-calculation-tracing/` — non-blocking patterns, circuit breaker design (reuse concepts, not code)
- `02_Explorations/2026-05-18_Transactional_Sync_Error_UX_Analysis/incident-id-options.md` — GCP trace correlation on Cloud Run
- V1 tracing draft PR — independent feature, may converge later

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
