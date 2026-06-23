# Implementation Plan — PRD-009: TMS Bridge DB Verifier GCP Cloud Host

**Status:** Awaiting approval
**Branch:** `feature/009-verifier-cloud-host` (in `Code/Disposition-Rollout-Tools`)
**Worktrees:** No — single branch, disjoint file ownership enforces parallelism.

---

## Decisions Locked In

| # | Question | Decision | Rationale |
|---|---|---|---|
| 1 | Cloud Functions vs Cloud Run? | **Cloud Run with Dockerfile (net9.0)** | `.Core` is net9.0; Cloud Functions only supports dotnet8 runtime. Downgrading the entire toolchain is too risky. |
| 2 | `.Core` API refactoring in scope? | **Yes** | `VerificationRunner.RunAsync()` returns `bool`; CloudHost needs `VerificationResult`. Must add `RunVerificationAsync()`. |
| 3 | Database config source for Workflow | **Scheduler message body (option c)** | Simple like hardcoded YAML, but updatable via `gcloud scheduler jobs update` without redeploying the workflow. |
| 4 | Authentication model | **`--ingress internal` + `--allow-unauthenticated`** | Matches Cloud4Log pattern. VPC-internal traffic only; no token exchange needed for Scheduler → Workflow → Cloud Run chain. |
| 5 | Pipeline repo | **Disposition-Rollout-Tools** | Keeps code + pipeline co-located. Requires one-time Azure DevOps admin setup (new pipeline definition, link variable groups). |
| 6 | GCS bucket | **Create `tms-health-t-t`** in `europe-west3` | No existing verifier bucket. Broader name since TMS Verifier is the only producer — leaves room for future health tools. |
| 7 | S1 `/verify-cloud` skill | **Descoped** | Claude Code skill, not application code. Separate follow-up. |

---

## Architectural Notes That Bind the Implementation

### PRD corrections (repo wins)

| PRD claim | Actual repo state | Implementation consequence |
|---|---|---|
| ".NET 8, containerized" (M1) | `.Core` targets `net9.0`, CLI targets `net9.0`, Tests target `net9.0` | CloudHost must be `net9.0`. Dockerfile uses `mcr.microsoft.com/dotnet/aspnet:9.0` + `sdk:9.0`. |
| "Call `VerificationRunner.RunAsync()` … Return `VerificationResult` JSON" (M4) | `RunAsync()` returns `Task<bool>`. `VerificationResult` is built internally, written to stdout. | Must add public `RunVerificationAsync()` that returns `Task<VerificationResult>`. |
| "No changes to `.Core` verification logic" (Out of Scope) | See above — impossible without API change | Stream 0 refactors `.Core` API. Verification logic itself unchanged. |
| "`Function.cs` — HTTP trigger" with Cloud Functions `IHttpFunction` | Cloud4Log uses `IHttpFunction` from `Google.Cloud.Functions.Framework`, but that requires dotnet8 runtime | CloudHost uses ASP.NET Core minimal API (`WebApplication.CreateBuilder`), not Cloud Functions framework. |
| "`SecretManagerClient.cs` wrapper" | Cloud4Log uses `Google.Cloud.SecretManager.V1` SDK directly | No wrapper class. Inject `SecretManagerServiceClient` via DI, resolve in endpoint. |
| "`StorageClient.cs` wrapper" | Cloud4Log uses `Google.Cloud.Storage.V1.StorageClient` directly via DI | No wrapper class. Inject `StorageClient` via DI, write in endpoint. |
| `devops/` folder exists | No `devops/` folder in Disposition-Rollout-Tools, no pipeline YAML, no Dockerfile | Create `devops/` folder. Create Dockerfile at project root or in CloudHost folder. |
| Pipeline in same repo as Cloud4Log | Cloud4Log pipeline is in Nagel-GCP repo, triggered by `Cloud4log/**` path | New pipeline definition needed in Azure DevOps for Disposition-Rollout-Tools repo. One-time admin task (prerequisite). |

### `VerificationRunner` refactoring design

Current:
```
RunAsync(schemas, output) → Task<bool>       // handles output internally
  └── BuildVerificationResult() → VerificationResult   // private
```

New:
```
RunVerificationAsync(schemas) → Task<VerificationResult>   // NEW — pure verification, no I/O
RunAsync(schemas, output) → Task<bool>                     // backward compat, calls RunVerificationAsync internally
```

The new method extracts the verification + result-building logic. `RunAsync` becomes a thin wrapper that calls `RunVerificationAsync`, then formats via `ConsoleReporter` or `JsonReporter` as before. CLI stays unchanged.

### Cloud Run service architecture

```
Cloud Scheduler (cron, message-body = database list JSON)
    │
    ▼
Cloud Workflow (parallel per database entry)
    │
    ▼
Cloud Run: POST /verify
    │ Request body: { "database": "D-10-34", "schemas": ["tms1034"], "level": 6 }
    │
    ├── Secret Manager: resolve "D-10-34" → connection string
    ├── ProviderDetector.Detect(connectionString) → PostgreSQL or Oracle
    ├── VerificationRunner.RunVerificationAsync(schemas) → VerificationResult
    │
    ├── Response: VerificationResult JSON (HTTP 200)
    ├── GCS: results/<database>/<timestamp>.json
    ├── GCS: reports/<database>/latest.md + reports/<database>/<timestamp>.md
    └── Structured log: jsonPayload with summary (for Cloud Monitoring alerting)
```

HTTP semantics:
- **200** — verification completed (even if failures found — failures are data)
- **200** — connection error caught gracefully (error status in response body)
- **500** — infrastructure failure only (Secret Manager unavailable, GCS write failed, unhandled exception)

### GCS path layout

```
gs://tms-health-t-t/
  results/
    D-10-34/
      2026-06-23T14-30-00Z.json
    O-10-60/
      2026-06-23T14-30-00Z.json
  reports/
    D-10-34/
      latest.md
      2026-06-23T14-30-00Z.md
    O-10-60/
      latest.md
      2026-06-23T14-30-00Z.md
```

### NuGet dependencies for CloudHost

| Package | Purpose |
|---|---|
| `Google.Cloud.SecretManager.V1` | Resolve database identifier → connection string |
| `Google.Cloud.Storage.V1` | Write JSON + markdown results to GCS |
| `Microsoft.AspNetCore.App` (framework ref) | ASP.NET Core minimal API |
| `<ProjectReference>` to `.Core` | `VerificationRunner`, `MarkdownReporter`, models |

No `Google.Cloud.Functions.Framework` — this is a standard ASP.NET Core app, not a Cloud Function.

---

## Schema

N/A — no new database tables. This feature reads existing databases; it doesn't write to them.

---

## File-Level Work Breakdown

### Stream 0 — Foundation (main session, sequential)

Refactor `.Core` API and add `MarkdownReporter`. Everything else depends on this.

| File | Change | Notes |
|---|---|---|
| `.Core/Verification/VerificationRunner.cs` | Add `RunVerificationAsync()`, refactor `RunAsync()` to call it | Must preserve exact CLI behavior. `RunAsync` return type stays `Task<bool>`. |
| `.Core/Reporting/MarkdownReporter.cs` | **New.** Static class, same pattern as `ConsoleReporter` / `JsonReporter`. Takes `VerificationResult`, returns `string`. | Sections: summary table, per-object results, column detail for failures, drift warnings. |
| `TmsBridgeDbVerifier/Program.cs` | Update to use `RunVerificationAsync` when `output == "json"` | Keeps CLI backward-compatible. Console path unchanged. |
| `Tests/Verification/VerificationRunnerRefactorTests.cs` | **New.** Tests that `RunVerificationAsync` returns correct `VerificationResult` structure. | Uses mock `IDbVerifier` (same pattern as existing tests). |
| `Tests/Reporting/MarkdownReporterTests.cs` | **New.** Tests markdown output for: happy path, failures, drift, empty results. | Pattern: feed `VerificationResult` → assert markdown contains expected sections/content. |

**Constraints:** No changes to verification logic itself. No changes to `IDbVerifier` interface. All existing tests must continue passing.

### Stream A — CloudHost Service (parallel agent)

New ASP.NET Core Cloud Run service project.

| File | Change | Notes |
|---|---|---|
| `TmsBridgeDbVerifier.CloudHost/TmsBridgeDbVerifier.CloudHost.csproj` | **New.** net9.0, ASP.NET Core, refs to `.Core` + Google Cloud NuGet packages. | No `Google.Cloud.Functions.Framework`. |
| `TmsBridgeDbVerifier.CloudHost/Program.cs` | **New.** Minimal API: `builder`, DI registration (SecretManagerServiceClient, StorageClient), `POST /verify` endpoint, `GET /health` endpoint. | Single file for the service — it's small enough. |
| `TmsBridgeDbVerifier.CloudHost/Dockerfile` | **New.** Multi-stage build: `sdk:9.0` build → `aspnet:9.0` runtime. | Expose port 8080 (Cloud Run default). |
| `TmsBridgeDbVerifier.CloudHost.Tests/TmsBridgeDbVerifier.CloudHost.Tests.csproj` | **New.** MSTest project, refs CloudHost + `.Core`. | Match existing test project pattern (`net9.0`, `MSTest 3.6.1`). |
| `TmsBridgeDbVerifier.CloudHost.Tests/VerifyEndpointTests.cs` | **New.** Tests: request validation, error response on bad input, connection error handling (HTTP 200 with error body), correct GCS path construction. | Mock SecretManagerServiceClient + StorageClient. |
| `TmsBridgeDbVerifier.sln` | Add `TmsBridgeDbVerifier.CloudHost` + `TmsBridgeDbVerifier.CloudHost.Tests` projects. | Only Stream A touches the sln. |

**Constraints:**
- Must NOT touch any `.Core` files (Stream 0 owns those).
- Must NOT touch `devops/` (Stream B owns that).
- `POST /verify` returns `VerificationResult` JSON. Connection errors are caught and returned as HTTP 200 with an error structure — not 500.
- Structured logging via `ILogger`, not `Console.WriteLine`.
- `TMSVERIFIER_RESULT_BUCKET` read from environment variable.
- Secret Manager access uses the project's service account identity (Application Default Credentials).

### Stream B — DevOps / Infrastructure (parallel agent)

Workflow YAML, pipeline YAML, infra documentation.

| File | Change | Notes |
|---|---|---|
| `devops/workflow-verify-databases.yml` | **New.** GCP Cloud Workflow. Receives database list as `arguments`, iterates in parallel, calls `POST /verify` per database. | Model after Cloud4Log `workflow-upload.yml` structure: `params: [arguments]`, parallel for-each, error handling per database (log + continue, don't abort all). |
| `devops/azure-pipelines-cloudrun-t-t.yml` | **New.** Azure DevOps pipeline: build, test, Docker build+push to Artifact Registry, deploy Cloud Run service, deploy workflow, create/update scheduler job. | Model structure after Cloud4Log pipeline but use `gcloud run deploy` (not `gcloud functions deploy`). Include Workload Identity Federation login step. |
| `devops/INFRA-SETUP.md` | **New.** One-time manual setup steps: create GCS bucket, create Artifact Registry repo (if needed), create Azure DevOps pipeline definition, link variable groups, grant `storage.objectCreator` to service account. | Not code — documentation of prerequisites. |

**Constraints:**
- Must NOT touch any `.cs` or `.csproj` files (Streams 0/A own those).
- Workflow must handle per-database failures gracefully (log error, continue to next database).
- Pipeline must only deploy on `master`/`main` branch builds.
- Scheduler message body format: `{ "databases": [{"id": "D-10-34", "schemas": ["tms1034"], "level": 6}] }`.

---

## Code Review Gates

| After | Lenses | Rationale |
|---|---|---|
| Stream 0 (Foundation) | Architectural + Clean-code (parallel) | `.Core` API change cascades into everything. Schema/contract correctness and module cohesion matter most here. |
| Stream A (CloudHost) | Architectural + Clean-code (parallel) | HTTP semantics, error handling, secret resolution correctness, GCS path construction, test coverage. |
| Stream B (DevOps) | Architectural only | YAML correctness, deployment safety, no hardcoded secrets, proper error handling in workflow. |
| Integration | Architectural only | Does the assembled feature compile, does `dotnet test` pass, are sln references correct. |

**Review handling:**
- Critical/High → fix before next step (`review-fix: <area>` commits)
- Medium → fix if cheap, else log in Deferred section
- Low → log only
- Contradiction with plan → stop, ask user

---

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| `.Core` refactoring breaks CLI behavior | Medium | High | Stream 0 includes regression tests. `RunAsync` wrapper preserves exact return semantics. Run full test suite before proceeding. |
| Oracle native library (`Oracle.ManagedDataAccess.Core`) fails in Linux Docker container | Medium | High | Oracle client works on Linux, but may need `LD_LIBRARY_PATH` or Alpine vs Debian base image choice. Use `aspnet:9.0` (Debian-based, not Alpine). Test locally with `docker build && docker run`. |
| Secret Manager naming convention doesn't match what we expect | Low | Medium | Verify by calling `gcloud secrets list --project=prj-cal-w-wl5-t-6c00-53ad` during implementation. The CLI currently takes raw connection strings — the naming convention comes from the TMS Bridge, not the verifier. |
| Azure DevOps pipeline setup requires admin access we don't have | Medium | Medium | Document the setup in `INFRA-SETUP.md`. Pipeline YAML is code-ready; the admin step can happen separately. Not a blocker for code completion. |
| GCS write fails silently, losing verification results | Low | High | Log GCS write failures as errors. Return verification result in HTTP response regardless of GCS outcome — the workflow gets the data even if persistence fails. |
| Cloud Run cold start exceeds Cloud Workflow timeout | Low | Medium | Set Cloud Run `--min-instances=0` with `--timeout=300s`. Verification of one database typically takes seconds (lightweight catalog queries). Cloud Workflow default timeout is 30 minutes. |
| `VerificationRunner` Console.* output pollutes Cloud Logging | Low | Low | The refactored `RunVerificationAsync` path doesn't touch Console. Console output only happens in the legacy `RunAsync` path (CLI). |

---

## Out of Scope

- **S1 `/verify-cloud` Claude Code skill** — descoped per decision #7. Separate follow-up.
- **C1 Wiki auto-publish** — depends on markdown reports in GCS being available first.
- **C2 Aggregate dashboard** — requires multiple databases to be running first.
- **Prod pipeline** — PRD says "Prod pipeline when prod workload is confirmed." Test only.
- **Terraform/IaC** — manual `gcloud` for V1 per PRD.
- **Firestore, Blazor dashboard, `IResultStore` abstraction** — PRD Won't Have list.
- **Any changes to `.Core` verification logic** — only API surface (new public method) and new reporter.
- **Changes to existing CLI tool behavior** — `Program.cs` updated but output stays identical.

---

## Acceptance Checklist

Derived from PRD Verification section:

- [ ] **V1 — Local invocation:** `dotnet run` CloudHost locally, POST `/verify` with reachable database (ABN 1034 via VPN). Response is valid `VerificationResult` JSON.
- [ ] **V2 — GCS writes:** After invocation, JSON file at `results/<database>/<timestamp>.json` and markdown at `reports/<database>/latest.md` + `reports/<database>/<timestamp>.md` in the GCS bucket.
- [ ] **V3 — Secret Manager resolution:** POST with `"database": "D-10-34"` resolves to PostgreSQL connection string. POST with `"database": "O-10-60"` resolves to Oracle connection string.
- [ ] **V4 — Cloud Workflow parallel execution:** Deploy workflow, trigger via `gcloud workflows run`. All configured databases checked in parallel. Workflow succeeds if all return HTTP 200.
- [ ] **V5 — Cloud Scheduler trigger:** Scheduler fires on cron. Workflow runs. Results appear in GCS.
- [ ] **V6 — Cloud Monitoring alert:** Deliberate column mismatch → log-based metric fires → alert policy triggers notification.
- [ ] **V7 — MarkdownReporter output:** Generated markdown is valid, readable, contains: summary table, per-object status, column detail for failures, drift warnings.
- [ ] **V8 — Unreachable database handling:** POST with unreachable database identifier → HTTP 200 with connection error in response body. No crash, no retry storm.
- [ ] **V9 — CI/CD pipeline:** Pipeline builds, runs tests, pushes Docker image, deploys Cloud Run service. Deployment succeeds, service is callable.
- [ ] **V10 — Health endpoint:** `GET /health` returns 200 with version info.
- [ ] **V11 — All existing tests pass:** `dotnet test TmsBridgeDbVerifier.sln` green after all changes.

---

## Execution Order

1. **Write this plan** → commit to feature branch (this step).
2. **Stream 0 — Foundation:**
   - Refactor `VerificationRunner` (add `RunVerificationAsync`)
   - Add `MarkdownReporter`
   - Update `Program.cs`
   - Add tests for both
   - Run full test suite: `dotnet test TmsBridgeDbVerifier.sln`
3. **Review gate: Stream 0** — architectural + clean-code, parallel.
4. **Fix review findings** (Critical/High before proceeding).
5. **Streams A + B in parallel** (single message, two Agent tool calls):
   - **Stream A:** CloudHost project, Dockerfile, tests, sln update.
   - **Stream B:** Workflow YAML, pipeline YAML, infra setup doc.
6. **Review gate: Streams A + B** — both reviewed in parallel (A gets architectural + clean-code; B gets architectural).
7. **Fix review findings.**
8. **Integration:**
   - Verify sln builds cleanly: `dotnet build TmsBridgeDbVerifier.sln`
   - Run full test suite: `dotnet test TmsBridgeDbVerifier.sln`
   - Local Docker build + run test (if Docker available)
9. **Review gate: Integration** — architectural lens on assembled feature.
10. **Report back** with green/red status, review finding counts, deviations.

**Prerequisites (not in this branch, must happen separately):**
- Create GCS bucket: `gcloud storage buckets create gs://tms-health-t-t --location=europe-west3 --project=prj-cal-w-wl5-t-6c00-53ad`
- Create Azure DevOps pipeline definition for Disposition-Rollout-Tools repo
- Link variable groups (`Nagel-Disposition`, GCP vars) to new pipeline
- Grant `storage.objectCreator` on bucket to `wl5-cloudrun@prj-cal-w-wl5-t-6c00-53ad.iam.gserviceaccount.com`

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
