# PRD 011: New Relic APM Integration

## Problem

The New Dispo stack has no application performance monitoring. When production issues occur, developers rely on GCP Cloud Logging with manual timestamp-based searches and `jq` queries against structured logs. There is no:

1. **Distributed trace visualization.** A single user action crosses Frontend → Backend → TMS Bridge → TMS Database. Today each hop is a separate log search. No tool shows the full call chain, latency breakdown, or where time is spent.

2. **RED metrics (Rate, Errors, Duration).** The architectural review (`02_Explorations/2026-02-23_harden-c4l-solution/architectural-review-patterns-and-methodology.md`) explicitly flagged "Anti-Pattern 7: Lack of Observability — no metrics for lag, throughput, error rate. Cannot measure SLA compliance."

3. **Proactive alerting.** Incidents are discovered reactively — customers or testers report issues before the team knows. The replication slot monitoring exploration (`02_Explorations/2026-06-10_Replication_Slot_Monitoring_Concept_for_AlloyDB/`) documented cases where Datastream reported RUNNING while frozen for hours.

Christian Lang has mandated New Relic as the corporate-wide monitoring solution for Nagel and provided an API key.

## Direction Alignment

- **Corporate mandate:** Christian Lang designated New Relic as Nagel's standard APM tool. This is not a tool-choice decision — it's an integration task.
- **Complements PRD 010** (E2E Trace ID with SQL Logging): PRD 010 uses .NET 8's built-in `System.Diagnostics.Activity` for W3C trace propagation. New Relic's .NET agent hooks into the same `Activity` infrastructure — trace IDs are shared automatically. PRD 010 gives SQL visibility + trace ID in the UI; New Relic gives distributed trace visualization + metrics.
- **Addresses the observability anti-pattern:** The architectural review (`02_Explorations/2026-02-23_harden-c4l-solution/architectural-review-patterns-and-methodology.md`) defined the RED metrics framework (Rate, Errors, Duration) as the standard solution for observability gaps. New Relic provides RED metrics per transaction out of the box.
- **Non-blocking by design:** New Relic's .NET agent operates as a CLR profiler — it instruments at the runtime level without blocking application threads. This satisfies the project's non-blocking requirement established in the tracing explorations.

## Requirements

### Must Have

- **M1**: New Relic .NET agent installed in TMS Bridge Docker image with `CORECLR_*` profiler environment variables configured
- **M2**: New Relic .NET agent installed in Backend Docker image with `CORECLR_*` profiler environment variables configured
- **M3**: New Relic browser agent (`@newrelic/browser-agent` npm package) installed in Frontend with SPA monitoring enabled
- **M4**: `NEW_RELIC_LICENSE_KEY` stored in GCP Secret Manager, referenced as a Cloud Run secret — never hardcoded in config, Dockerfile, or git
- **M5**: Each service reports with a distinct `NEW_RELIC_APP_NAME` (e.g. `NewDispo-TMSBridge-UAT`, `NewDispo-Backend-UAT`, `NewDispo-Frontend-UAT`)
- **M6**: Distributed traces correlate across Frontend → Backend → TMS Bridge using W3C `traceparent` header propagation (auto-handled by .NET agent + browser agent)
- **M7**: Auto-instrumented transactions visible in New Relic for: ASP.NET Core HTTP requests, HttpClient calls, EF Core / ADO.NET SQL queries
- **M8**: ABN/UAT environments instrumented first. PROD deployment gated by overhead validation (< 5% latency impact)
- **M9**: Serilog logs-in-context enabled in ABN/UAT via `NewRelic.LogEnrichers.Serilog` — logs linked to traces in New Relic UI. Disabled in PROD.
- **M10**: GCP Cloud Functions (FilterShipments, Cloud4Log) monitored via New Relic's GCP integration for infrastructure metrics (invocation count, duration, error rate)

### Should Have

- **S1**: `NEW_RELIC_DISTRIBUTED_TRACING_ENABLED=true` set explicitly (enabled by default in recent agent versions, but make it explicit)
- **S2**: Environment-specific app naming convention documented (e.g. `NewDispo-{Component}-{Environment}`)
- **S3**: Agent configuration via environment variables only — no `newrelic.config` XML file in the repo. Simpler to manage across environments.

### Could Have

- **C1**: Angular router integration for explicit route change tracking via `newrelic.interaction()` API — fallback if auto-detection misses soft navigations

### Won't Have

- **W1**: Custom HotChocolate GraphQL resolver instrumentation — deferred to V2. Auto-instrumented HTTP transactions are sufficient for V1.
- **W2**: New Relic dashboards, alerts, or SLO configuration — V2 scope. V1 ships data; V2 makes it actionable.
- **W3**: PROD Serilog log forwarding to New Relic — cost-controlled decision. ABN/UAT only for V1.
- **W4**: OpenTelemetry SDK in Cloud Functions — infrastructure metrics sufficient for V1. OTLP instrumentation is a targeted V2 task if needed.
- **W5**: Migration away from GCP Cloud Logging — New Relic is additive. Cloud Logging stays as-is.
- **W6**: Custom business metrics or events (e.g. tours calculated per hour, PoolDTO sizes) — meaningful only after baseline APM data proves value.

## Out of Scope

- Modifying PRD 010's implementation (trace ID badge, SQL logging)
- New Relic account administration (user management, billing, plan changes)
- Corporate naming/alerting standards (flagged as open question for Christian)
- Performance tuning or profiling — this is instrumentation setup, not optimization work
- Cloud Functions code changes of any kind

## Prerequisites to Clarify (with Christian Lang)

| # | Question | Why it matters | Blocking? |
|---|---|---|---|
| P1 | New Relic account tier — what's included? (APM, Browser, Infrastructure, Logs?) | Determines which features are available. Browser monitoring may require Pro tier. | Yes — before Frontend work |
| P2 | Data residency — EU or US data center? | Nagel is a German company. Telemetry may contain business identifiers (order IDs, customer refs). GDPR implications. | Yes — before PROD |
| P3 | Corporate naming conventions for services/apps? | Avoid rework if corporate has standards for `NEW_RELIC_APP_NAME`. | No — can rename later |
| P4 | Alert routing — where should alerts go? (Email, Slack, PagerDuty?) | Needed for V2 alerting setup but good to know early. | No — V2 |
| P5 | Data ingest limits / cost model — per-GB pricing? Caps? | Serilog log forwarding in ABN/UAT increases ingest. Need to understand cost implications. | No — ABN/UAT is low volume |
| P6 | Existing New Relic infrastructure — are other Nagel teams already reporting? | Can reuse patterns, dashboards, alert policies from other teams. | No — nice to have |

## Security

| # | Threat | Impact | MVP Mitigation |
|---|---|---|---|
| T1 | License key exposure in source code or Docker image layers | Unauthorized data ingest, billing impact | License key stored in GCP Secret Manager, injected as env var at Cloud Run runtime. Never in Dockerfile, appsettings, or git. |
| T2 | Telemetry contains business data (order IDs, customer refs, SQL parameter values) | Data exposure to New Relic SaaS | V1 deploys to ABN/UAT only (test data). PROD deployment gated by P2 (data residency) resolution. Serilog log forwarding disabled in PROD. |
| T3 | Agent overhead degrades business performance | Latency increase on tour calculations | Validate < 5% overhead in ABN/UAT before PROD. New Relic agent is non-blocking (CLR profiler). |
| T4 | Browser agent exposes license key in client-side JavaScript | Key visible in browser DevTools | Browser agent uses a separate **ingest key** (not the main license key). Ingest keys are low-privilege — they can only send data, not query or configure. Standard practice per New Relic docs. |

## Implementation Approach (unverified hint)

### TMS Bridge (Disposition-Abstraction-Layer)

- Add New Relic agent installation to the final stage of `Dockerfile`:
  ```dockerfile
  RUN apt-get update && apt-get install -y wget ca-certificates gnupg \
      && wget -O- https://download.newrelic.com/newrelic-key.gpg | apt-key add - \
      && echo "deb https://download.newrelic.com/apt newrelic non-free" > /etc/apt/sources.list.d/newrelic.list \
      && apt-get update && apt-get install -y newrelic-dotnet-agent \
      && rm -rf /var/lib/apt/lists/*
  ```
- Set environment variables in Cloud Run service revision config:
  ```
  CORECLR_ENABLE_PROFILING=1
  CORECLR_PROFILER={36032161-FFC0-4B61-B559-F6C5D41BAE5A}
  CORECLR_PROFILER_PATH=/usr/local/newrelic-dotnet-agent/libNewRelicProfiler.so
  CORECLR_NEWRELIC_HOME=/usr/local/newrelic-dotnet-agent
  NEW_RELIC_APP_NAME=NewDispo-TMSBridge-{ENV}
  NEW_RELIC_DISTRIBUTED_TRACING_ENABLED=true
  ```
- `NEW_RELIC_LICENSE_KEY` from GCP Secret Manager (Cloud Run secret reference)
- Add `NewRelic.LogEnrichers.Serilog` NuGet package; configure in `Program.cs` / `Startup.cs` behind environment check (ABN/UAT only)

### Backend (Disposition-Backend)

- Same Dockerfile + Cloud Run env var pattern as TMS Bridge
- `NEW_RELIC_APP_NAME=NewDispo-Backend-{ENV}`
- Same Serilog enricher setup

### Frontend (Disposition-Frontend)

- `npm install @newrelic/browser-agent`
- Initialize in `src/main.ts` with config from New Relic account (application ID, beacon URI, ingest key)
- Browser agent config values as Angular environment variables (not hardcoded)
- SPA monitoring enabled by default

### Cloud Functions (Nagel-GCP)

- No code changes. Configure New Relic's GCP integration via service account authorization to poll Cloud Monitoring metrics for Cloud Functions.

### Secret Management

- Create secret `newrelic-license-key` in GCP Secret Manager for each project (ABN, UAT, DEV)
- Reference in Cloud Run service config as a secret environment variable

## Files Likely to Change

| File | Change | New/Modified |
|---|---|---|
| **TMS Bridge** | | |
| `Dockerfile` | Add `apt-get install newrelic-dotnet-agent` + `CORECLR_*` env defaults | Modified |
| Cloud Run service config | Add `NEW_RELIC_*` env vars, GCP Secret Manager reference | Modified |
| `.csproj` | Add `NewRelic.LogEnrichers.Serilog` NuGet | Modified |
| `Program.cs` or `Startup.cs` | Configure Serilog New Relic enricher (ABN/UAT) | Modified |
| **Backend** | | |
| `Dockerfile` | Same agent installation pattern | Modified |
| Cloud Run service config | Add `NEW_RELIC_*` env vars, GCP Secret Manager reference | Modified |
| `.csproj` | Add `NewRelic.LogEnrichers.Serilog` NuGet | Modified |
| `Program.cs` | Configure Serilog New Relic enricher (ABN/UAT) | Modified |
| **Frontend** | | |
| `package.json` | Add `@newrelic/browser-agent` dependency | Modified |
| `src/main.ts` | Initialize browser agent with config | Modified |
| `src/environments/environment.*.ts` | Add New Relic config values per environment | Modified |
| **Infrastructure** | | |
| GCP Secret Manager | New secret: `newrelic-license-key` per project | New |
| New Relic GCP integration | Service account authorization for Cloud Functions metrics | New |

## Verification

- [ ] Deploy TMS Bridge to UAT with New Relic agent. Verify the service appears in New Relic APM with the correct app name.
- [ ] Deploy Backend to UAT. Verify distributed traces show Backend → TMS Bridge call chain in New Relic.
- [ ] Deploy Frontend to UAT. Trigger a tour calculation. Verify New Relic shows the full Frontend → Backend → TMS Bridge distributed trace.
- [ ] Verify auto-instrumented transactions: HTTP requests, HttpClient calls, SQL queries visible in New Relic without custom code.
- [ ] Verify Serilog logs appear in New Relic Logs linked to the corresponding trace (ABN/UAT only).
- [ ] Verify GCP Cloud Functions (FilterShipments) appear in New Relic Infrastructure with invocation count and duration metrics.
- [ ] Run a tour calculation with agent vs. without agent. Verify < 5% latency overhead.
- [ ] Verify `NEW_RELIC_LICENSE_KEY` is not visible in Dockerfile, git history, or `docker inspect` output.
- [ ] Verify browser agent ingest key (not license key) is used in Frontend client-side code.

## Effort Estimate

| Component | Effort | Notes |
|---|---|---|
| TMS Bridge agent install | 0.5 day | Dockerfile + Cloud Run env vars + secret setup |
| Backend agent install | 0.5 day | Same pattern as TMS Bridge |
| Frontend browser agent | 0.5 day | npm install + init in main.ts + env config |
| Serilog logs-in-context (ABN/UAT) | 0.5 day | NuGet + Serilog config for both .NET services |
| GCP integration (Cloud Functions) | 0.5 day | Service account + New Relic GCP integration setup |
| Secret management setup | 0.5 day | GCP Secret Manager + Cloud Run secret references |
| Validation + overhead testing | 1 day | Verify all services, distributed traces, overhead |
| **Total V1** | **~4 days** | Assumes CI/CD pipeline access and New Relic account ready |

## V2 Roadmap (out of scope for this PRD)

| Feature | Prerequisite |
|---|---|
| HotChocolate GraphQL resolver instrumentation (`[Transaction]` attributes) | V1 agent installed |
| New Relic dashboards (RED metrics, tour calculation latency) | V1 data flowing |
| Alert policies (error rate spikes, latency degradation) | Dashboards + P4 (alert routing) resolved |
| SLO tracking | Baseline data from V1 |
| OpenTelemetry in Cloud Functions | V1 validated, need identified |
| PROD deployment | P2 (data residency) resolved, overhead validated |
| PROD Serilog log forwarding | Cost model (P5) understood |

## Related

- `03_PRD/Open/010_E2E_Trace_SQL_Logging/PRD.md` — complementary: shares W3C trace context via `System.Diagnostics.Activity`, adds SQL visibility and trace ID badge
- `02_Explorations/2026-02-23_harden-c4l-solution/architectural-review-patterns-and-methodology.md` — Anti-Pattern 7 (Lack of Observability), RED metrics framework
- `02_Explorations/2026-06-10_Replication_Slot_Monitoring_Concept_for_AlloyDB/` — monitoring gap precedent (Datastream stall detection)
- `02_Explorations/2026-03-10_holistic-tour-calculation-tracing/` — historical: custom tracing exploration that established non-blocking patterns and boundary capture philosophy
- `02_Explorations/2026-06-18_GCP_Monitoring_Dashboards_-_IaC_vs_Console_UI/` — dashboard management considerations for V2

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
