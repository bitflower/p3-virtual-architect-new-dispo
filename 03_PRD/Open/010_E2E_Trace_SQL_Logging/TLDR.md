# PRD 010 — E2E Trace ID with SQL Logging (TL;DR)

**Problem:** When something goes wrong, testers can't give developers a trace ID (it's not shown in the UI), and nobody can see what SQL the TMS Bridge actually executed (no logging exists).

## Solution — 3 parallel streams, 3 repos, zero overlap

| Stream | Repo | What | Size |
|--------|------|------|------|
| **0 — SQL Tracing** | TMS Bridge | Decorator on `ISqlCommandExecutor` logs full SQL + params + duration, tagged with trace ID. Circuit breaker protects against logging failures. Toggle via `appsettings`. | 3 new files, 4 modified |
| **1 — Trace Propagation** | Backend | Add `traceparent` header to TMS Bridge calls + expose `X-Trace-Id` response header + CORS fix | 2 files modified |
| **2 — Trace Badge** | Frontend | Interceptor reads `X-Trace-Id`, service + toolbar badge with copy button | 5 new files, 2 modified |

## Key decisions already locked

- Trace ID comes from GCP (not client-generated) — Backend reads `Activity.Current?.TraceId`
- Only raw ADO.NET executor is wrapped (covers >95% of SQL); EF Core interceptor skipped for MVP
- M7 (GraphQL operation name in SQL logs) descoped — needs `AsyncLocal` threading, not surgical
- C1 (SQL summary in HTTP response) descoped — separate PRD

## Risks to discuss

- SQL logs contain business data → only enabled in ABN/UAT
- `Activity.Current` might be null in TMS Bridge → fallback logs with `traceId: "none"`
- CORS must explicitly expose `X-Trace-Id` or browser silently blocks it

## Acceptance (top 3)

1. Trigger action → trace badge shows 32-hex ID in toolbar
2. Search that ID in Cloud Logging → Backend + TMS Bridge SQL logs appear under same trace
3. Copy logged SQL → paste in DBeaver → valid SQL

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
