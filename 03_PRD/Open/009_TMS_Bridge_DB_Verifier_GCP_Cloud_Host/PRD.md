# PRD-009: TMS Bridge DB Verifier — GCP Cloud Host

**Feature ID:** 009_TMS_Bridge_DB_Verifier_GCP_Cloud_Host
**Date:** 2026-06-23
**Status:** Implementation complete — PR #33453 open
**Prerequisite:** PRD-003 (Core Library + Column Verification) — complete
**Target workload:** wl5 test — `prj-cal-w-wl5-t-6c00-53ad`

---

## 1. Problem

The TMS Bridge DB Verifier (`.Core` library, delivered by PRD-003) can verify all 77+ database objects across PostgreSQL and Oracle. But it can only run from a developer laptop with VPN access. Several databases (Oracle on-prem, UAT/PROD AlloyDB) are unreachable from local machines.

The team needs schema verification to run **independent of any laptop** — on a schedule, against any configured database, with results persisted and accessible. Today, if a view loses a column (BUG-124918 scenario), nobody knows until a runtime crash.

**Evidence from prior art:**

- Advanced TMS Verifier exploration: designed the 6-layer architecture with `.Core` as shared library and Cloud Run service as one of the host options (`02_Explorations/2026-06-11_Advanced_TMS_Verifier_-_Continuous_Database_Monitoring_Service_in_GCP/`)
- Cloud4Log: proven Cloud Run service + Cloud Scheduler + Cloud Workflow pattern already deployed in this project (`Code/Nagel-GCP/Cloud4Log/`)
- GCP infrastructure (VPC, VPN, Secret Manager) already connects Cloud Run services to both AlloyDB and Oracle on-prem

## 2. Direction Alignment

This is Layer 5 of the exploration's recommended approach. Layers 1 (Core + CLI) and 2 (Claude Code skill, partially) are delivered. This PRD delivers the cloud-hosted verification host.

**Conscious scope reductions from exploration:**

| Exploration vision | V1 decision | Rationale |
|---|---|---|
| Firestore for history | Cloud Storage JSON files | Simpler, no new infra, queryable with `gsutil` + `jq` |
| Blazor timeline dashboard | Markdown reports in GCS | Sufficient for team visibility, zero frontend code |
| `IResultStore`/`IResultQuery` abstraction | Direct GCS writes | Only one storage backend — abstraction is premature |

## 3. Requirements (MoSCoW)

### Must Have

- **M1: Cloud Run service project in Disposition-Rollout-Tools.** New project `TmsBridgeDbVerifier.CloudHost` with `<ProjectReference>` to `.Core`. .NET 8, containerized, deployed to Cloud Run in wl5. HTTP endpoint.
- **M2: HTTP trigger accepts database identifier + level.** Request shape: `POST /verify` with JSON body `{ "database": "D-10-34", "schemas": ["tms1034"], "level": 6 }`. The `database` field is a Secret Manager key that resolves to a connection string.
- **M3: Secret Manager connection string resolution.** Read connection string from Secret Manager using the database identifier. Follow the same naming convention the TMS Bridge uses. No hardcoded connection strings.
- **M4: Run verification and return JSON.** Call `VerificationRunner.RunAsync()` from `.Core`. Return the `VerificationResult` JSON as the HTTP response body. HTTP 200 on success (even if verification finds failures — failures are data, not errors). HTTP 500 only on infrastructure errors (can't connect, Secret Manager unavailable).
- **M5: Write result JSON to Cloud Storage.** After verification, write the `VerificationResult` JSON to a GCS bucket as a timestamped file: `gs://{TMSVERIFIER_RESULT_BUCKET}/results/<database>/<timestamp>.json`. Bucket name is configurable via `TMSVERIFIER_RESULT_BUCKET` environment variable on the Cloud Run service. This provides history without Firestore.
- **M6: Cloud Workflow for parallel database checks.** YAML workflow that calls the Cloud Run service once per configured database, in parallel. Input: list of database configurations. Output: aggregated pass/fail.
- **M7: Cloud Scheduler cron.** Triggers the Cloud Workflow on a configurable schedule (default: every 60 min during business hours).
- **M8: `MarkdownReporter` in `.Core`.** Generates a markdown status report from a `VerificationResult`. Pure code formatting — no AI/LLM involved. Same pattern as the existing `ConsoleReporter` and `JsonReporter`. Sections: summary table, per-object results with column details, drift warnings.
- **M9: Cloud Monitoring alert on verification failure.** Log-based metric on `jsonPayload.summary.fail > 0`. Alert policy notifies via email (or configurable channel).
- **M10: Markdown report written to Cloud Storage.** After JSON, also write a markdown report to `gs://{TMSVERIFIER_RESULT_BUCKET}/reports/<database>/latest.md` and `gs://{TMSVERIFIER_RESULT_BUCKET}/reports/<database>/<timestamp>.md`. Enables direct linking from wiki or Slack.
- **M11: Service account and VPC configuration.** Reuse existing `wl5-cloudrun` service account (`wl5-cloudrun@prj-cal-w-wl5-t-6c00-53ad.iam.gserviceaccount.com`). Deploy with the same VPC/subnet and network tags (`postgres-user`, `oracle-user`) as the TMS Bridge Cloud Run service. Grant `storage.objectCreator` on the results bucket if not already present. Cloud Workflow's invoker service account needs `run.invoker` on this service.
- **M12: Azure DevOps CI/CD pipeline.** Build, test, and deploy the Cloud Run service to GCP. Follow `Cloud4Log/devops/azure-pipelines-cloudrun-t-t.yml` as reference pattern. Pipeline YAML for test environment. Prod pipeline when prod workload is confirmed.

### Should Have

- **S1: `/verify-cloud` Claude Code skill.** Skill that triggers the Cloud Workflow via `gcloud workflows run`, waits for completion, and reports results locally. Provides an ad-hoc way to trigger cloud verification without waiting for the scheduler.
- **S2: Health endpoint.** `GET /health` returns 200 + function version + last check timestamp per configured database (read from GCS bucket listing).

### Could Have

- **C1: Wiki auto-publish.** After each verification run, push the latest markdown report to the wiki via Azure DevOps API. Team bookmarks the wiki page for a live dashboard.
- **C2: Aggregate dashboard markdown.** A single `all-databases.md` report combining the latest results from all configured databases into one page.

### Won't Have

- **W1: Firestore result store** — Cloud Storage JSON files are sufficient for V1 history
- **W2: Blazor timeline dashboard** — markdown reports are the V1 dashboard
- **W3: `IResultStore`/`IResultQuery` interfaces** — premature abstraction; Cloud Storage is the only backend
- **W4: Pipeline gate integration** — separate concern (exploration Phase 4, future PRD)
- **W5: Terraform/Pulumi for infrastructure** — manual `gcloud` setup for V1; IaC if reproducibility is needed later

## 4. Out of Scope

- Any changes to the existing CLI tool
- Any changes to `.Core` verification logic (only adding `MarkdownReporter`)
- Custom authentication beyond the existing `wl5-cloudrun` service account and IAM setup
- Multi-region deployment
- Rate limiting / request throttling (Cloud Scheduler is the only caller)

## 5. Implementation Approach (unverified hint)

### Module layout

```
Code/Disposition-Rollout-Tools/
+-- TmsBridgeDbVerifier.Core/              (existing — add MarkdownReporter only)
|   +-- Reporting/
|   |   +-- ConsoleReporter.cs             (existing)
|   |   +-- JsonReporter.cs                (existing)
|   |   +-- MarkdownReporter.cs            (new — M8)
+-- TmsBridgeDbVerifier.CloudHost/         (new — M1)
|   +-- TmsBridgeDbVerifier.CloudHost.csproj
|   +-- Function.cs                        (HTTP trigger — M2, M4)
|   +-- SecretManagerClient.cs             (M3)
|   +-- StorageClient.cs                   (M5, S1)
+-- TmsBridgeDbVerifier.CloudHost.Tests/   (new)
|   +-- TmsBridgeDbVerifier.CloudHost.Tests.csproj
|   +-- FunctionTests.cs
+-- devops/
    +-- workflow-verify-databases.yml       (M6 — GCP Cloud Workflow)
    +-- azure-pipelines-cloudrun-t-t.yml  (M10 — test deploy)
    +-- azure-pipelines-cloudrun-p-p.yml  (M10 — prod deploy)
```

### Connection string flow

```
Cloud Scheduler
    |
    v
Cloud Workflow (parallel per database)
    |
    v
Cloud Run: POST /verify { "database": "D-10-34", "schemas": ["tms1034"], "level": 6 }
    |
    v
Secret Manager: resolve "D-10-34" → connection string
    |
    v
ProviderDetector.Detect(connectionString) → PostgreSQL or Oracle
    |
    v
VerificationRunner.RunAsync(schemas, "json")
    |
    v
VerificationResult JSON
    |
    +--→ HTTP response (to Workflow)
    +--→ Cloud Storage: results/<database>/<timestamp>.json
    +--→ Cloud Storage: reports/<database>/latest.md  (S1)
    +--→ Cloud Logging: structured log (for M9 alerting)
```

### Implementation order

1. **M8: MarkdownReporter** — add to `.Core`, test with existing test infrastructure
2. **M1-M4: Cloud Run service skeleton** — HTTP trigger, Secret Manager, `VerificationRunner` call, JSON response
3. **M5/M10: Cloud Storage writes** — JSON + markdown results to GCS bucket
4. **M6-M7: Workflow + Scheduler** — YAML workflow, gcloud scheduler setup
5. **M9: Cloud Monitoring** — log-based metric + alert policy
6. **M10: CI/CD pipeline** — Azure DevOps pipeline YAMLs for test + prod deployment

## 6. Files Likely to Change

| File | Change | New/Modified |
|---|---|---|
| `TmsBridgeDbVerifier.Core/Reporting/MarkdownReporter.cs` | Markdown report generator (pure code) | New |
| `TmsBridgeDbVerifier.CloudHost/TmsBridgeDbVerifier.CloudHost.csproj` | Cloud Run service project (.NET 8) | New |
| `TmsBridgeDbVerifier.CloudHost/Function.cs` | HTTP trigger entry point | New |
| `TmsBridgeDbVerifier.CloudHost/SecretManagerClient.cs` | Secret Manager wrapper | New |
| `TmsBridgeDbVerifier.CloudHost/StorageClient.cs` | GCS write helper | New |
| `TmsBridgeDbVerifier.CloudHost.Tests/TmsBridgeDbVerifier.CloudHost.Tests.csproj` | Test project | New |
| `TmsBridgeDbVerifier.CloudHost.Tests/FunctionTests.cs` | Unit tests for function logic | New |
| `TmsBridgeDbVerifier.Tests/Reporting/MarkdownReporterTests.cs` | Tests for MarkdownReporter | New |
| `devops/workflow-verify-databases.yml` | GCP Cloud Workflow YAML | New |
| `devops/azure-pipelines-cloudrun-t-t.yml` | Azure DevOps CI/CD — test env | New |
| `TmsBridgeDbVerifier.sln` | Add CloudHost + CloudHost.Tests projects | Modified |

## 7. Verification

- **V1 — Local function invocation.** `dotnet run` the Cloud Run service project locally, POST a request with a reachable database (e.g. ABN 1034 via VPN). Verify JSON response matches expected `VerificationResult` schema.
- **V2 — Cloud Storage writes.** After function invocation, verify JSON + markdown files appear in the target GCS bucket at the expected paths.
- **V3 — Secret Manager resolution.** Function resolves `D-10-34` to a valid PostgreSQL connection string from Secret Manager. Function resolves `O-10-60` to a valid Oracle connection string.
- **V4 — Cloud Workflow parallel execution.** Deploy workflow, trigger manually via `gcloud workflows run`. All configured databases are checked in parallel. Workflow succeeds if all functions return HTTP 200.
- **V5 — Cloud Scheduler trigger.** Scheduler fires on configured cron. Workflow runs. Results appear in GCS bucket.
- **V6 — Cloud Monitoring alert.** Introduce a deliberate column mismatch (or test against a known-broken database). Verify the log-based metric fires and the alert policy triggers a notification.
- **V7 — MarkdownReporter output.** Generated markdown is valid, readable, and contains: summary table, per-object status, column detail for failures, drift warnings.
- **V8 — Unreachable database handling.** Function receives a database identifier for an unreachable DB. Returns HTTP 200 with connection error status in the response body (connection error is data, not a crash). No Cloud Run service crash or retry storm.
- **V9 — CI/CD pipeline.** Pipeline builds, runs tests, and deploys the Cloud Run service to GCP test environment. Deployment succeeds and function is callable.

## 8. Related

### Prior Art

- `02_Explorations/2026-06-11_Advanced_TMS_Verifier_-_Continuous_Database_Monitoring_Service_in_GCP/` — full architecture design, comparison matrix, 6-layer plan
- `Code/Nagel-GCP/Cloud4Log/` — reference Cloud Run service + Workflow + Scheduler pattern
- `Code/Nagel-GCP/Cloud4Log/devops/` — reference Azure DevOps pipeline YAMLs and Cloud Workflow YAMLs

### Prerequisites

- **PRD-003** (Core Library + Column Verification) — complete, `.Core` exists with full L1-L6 verification, `ConsoleReporter`, `JsonReporter`

### Downstream

- Wiki auto-publish (C1) — depends on markdown reports being in GCS
- Timeline dashboard (future PRD) — depends on JSON history in GCS; Firestore migration if needed
- Pipeline gate (exploration Phase 4, separate PRD) — independent, uses CLI not Cloud Run service

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
