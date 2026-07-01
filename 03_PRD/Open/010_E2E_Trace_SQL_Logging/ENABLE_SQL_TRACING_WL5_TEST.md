# PRD 010 — Enabling SQL Tracing on wl5-test (Deployment Note)

**For:** Nikolay
**Service:** `cal-new-disposition-tmsbridge-t-t` (wl5-test, project `prj-cal-w-wl5-t-6c00-53ad`, region `europe-west3`)
**Date:** 2026-07-01

## TL;DR

The PRD 010 SQL-tracing code **is deployed** to wl5-test (running revision `00166`), but it produces **zero SQL logs** because the `SqlTracing:Enabled` flag resolves to **`false`** in the environment the container actually runs as. Fix = set an env-var override `SqlTracing__Enabled=true` on the **test service only** (one line). Do **not** enable it via `appsettings.Production.json` — that would also switch it on in real PROD.

## The issue

The tracing decorator (`TracingSqlCommandExecutor`) only logs SQL when `SqlTracing:Enabled = true`; otherwise it delegates and logs nothing. On the deployed service the flag is `false`, for three combined reasons:

1. **The container runs as `Production`.** `Dockerfile.cloudrun-t-t` bakes in `ENV ASPNETCORE_ENVIRONMENT="Production"` and `--environment=Production`, so the app loads `appsettings.Production.json` → `SqlTracing: { "Enabled": false }` (base `appsettings.json` is `false` too).
2. **`appsettings.Staging.json` has `Enabled: true`, but it is never loaded** — no deployed image runs as *Staging* (every cloud Dockerfile forces `Production`). So the "true" value is effectively dead config.
3. **No env-var override.** The pipeline's `gcloud run deploy` step (in `azure-pipelines-cloudrun-t-t-wl5.yml`, def 2003 `cal-new-dispo-tms-bridge-t-t-cloudrun`) does not set any env vars, and none is set on the Cloud Run service.

Net result: the code path is live, but the flag gates it off, so nothing is written to Cloud Logging.

## How to resolve

Add an env-var override on the **test** service. `SqlTracing__Enabled` (double underscore) overrides the appsettings value in ASP.NET Core.

### Option A — permanent, in the pipeline (recommended)

In `azure-pipelines-cloudrun-t-t-wl5.yml`, in the **"Deploy to GCP"** step, append one flag to the `gcloud run deploy` command:

```bash
gcloud run deploy cal-new-disposition-tmsbridge-t-t \
  --image .../cal-new-disposition-t-t-tmsbridge:latest \
  --project prj-cal-w-wl5-t-6c00-53ad \
  --region europe-west3 \
  ...existing flags... \
  --update-env-vars SqlTracing__Enabled=true
```

### Option B — immediate, no redeploy

```bash
gcloud run services update cal-new-disposition-tmsbridge-t-t \
  --project prj-cal-w-wl5-t-6c00-53ad --region europe-west3 \
  --update-env-vars SqlTracing__Enabled=true
```

The env var survives future pipeline deploys, because the deploy step doesn't touch env vars. Option A makes it version-controlled and reproducible; Option B is handy to switch it on right now.

## ⚠️ What NOT to do

Do **not** set `Enabled: true` in `appsettings.Production.json`. That file is shared with the **prod** pipeline (def 2020 `cal-new-dispo-tms-bridge-p-p-cloudrun`, which also runs `--environment=Production`), so it would turn SQL logging on in **real PROD** and expose business data (order IDs, customer refs, weights) in Cloud Logging — exactly the risk the PRD's security section calls out. Keep the flag scoped to the test service via env var.

## How to verify it worked

After enabling and triggering an action that hits the TMS Bridge (e.g. a tour calculation or order edit), the SQL entries appear in Cloud Logging. Note: Serilog writes **CLEF** — the trace ID is `jsonPayload."@tr"` and the message is `jsonPayload."@m"` (not `textPayload`).

```bash
gcloud logging read \
  'resource.labels.service_name="cal-new-disposition-tmsbridge-t-t" AND (jsonPayload."@m":"SQL Procedure" OR jsonPayload."@m":"SQL Function")' \
  --project prj-cal-w-wl5-t-6c00-53ad --freshness=1h --limit=20 \
  --format='value(timestamp, jsonPayload."@tr", jsonPayload."@m")'
```

Expected: rows like `SQL Function [OK] 406ms TraceId=... PreviousTraceId=...` with the full inline SQL.

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
