# Implementation Plan: pg_notify CDC for sendung (abn1034)

**PRD:** [PRD.md](./PRD.md)
**Status:** In progress — Stream A running (2026-06-12)
**Repos:**
- **Virtual Architect (this repo):** `main` — plan, PRD, documentation only
- **Nagel-GCP (`Code/Nagel-GCP/`):** `feature/pgnotify-cdc-sendung` — all code + SQL scripts
**Worktrees:** No. Single branch per repo.

---

## 1. Decisions Locked In

| # | Question | Answer | Rationale |
|---|---|---|---|
| D1 | Outbox table or fire-and-forget pg_notify? | **No outbox (PRD as-is)** | Accept event loss during writer downtime. Simpler, faster to build. Sufficient for ABN testing where occasional gaps are tolerable. |
| D2 | Orphaned UPDATE-INSERT after reconnection? | **Emit as standalone `"UPDATE"`** | OldRecord=null. Log warning. Backend's `ShipmentUpdatedEventHandler` handles standalone `"UPDATE"` via existing fallback path. No duplicates — handler checks for existing records before creating. |
| D3 | Project location? | **`Code/Nagel-GCP/SendungCdcWriter/`** | Alongside Cloud Functions. GCP-native Cloud Run service. |
| D4 | Trigger deployment method? | **Manual psql script** | Applied directly on abn1034. SQL files stored in `Nagel-GCP/SendungCdcWriter/scripts/`. Liquibase setup is minimal and not production-ready for this use case. |
| D5 | Cloud Run CPU throttling? | **`--no-cpu-throttling` required** | Without it, Cloud Run throttles CPU when no HTTP request is active. BackgroundService LISTEN loop would freeze — replicating the exact "silent stall" pattern we're trying to fix. Combined with `min-instances: 1`, this means always-on CPU billing. |
| D6 | Filter `sendungsart = 'A'` in trigger? | **Yes — filter at trigger level** | Diverges from PRD M2 ("no filtering at trigger level"). Reduces pg_notify traffic to only the subset the Cloud Function would pass through anyway. For UPDATE: fire if EITHER old OR new `sendungsart = 'A'` (matches Cloud Function behavior, catches rows changing to/from 'A'). Acceptable coupling for a temporary solution. |

---

## 2. Architectural Notes That Bind the Implementation

### Verified Integration Points (repo is source of truth)

| PRD Claim | Verified Against Repo | Status |
|---|---|---|
| Cloud Function class: `FilterShipmentsTrigger` | `Code/Nagel-GCP/.../FilterShipmentsTrigger.cs` dispatches to `BucketDataStreamFileContentProcessor` | Correct — the processor does the actual JSONL parsing |
| `sendungsart = 'A'` filter in Cloud Function | `BucketDataStreamFileContentProcessor.cs` lines 39-41: `oldRecord?.Payload.ShipmentType == ShipmentType.A.ToString()` | Correct |
| Backend handler: `PubSubMessageHandler` | `Code/Disposition-Backend/.../CDC/PubSubMessageHandler.cs` — `BackgroundService` pulling Pub/Sub | Correct |
| `ShipmentUpdatedEventHandler` receives OldRecord + NewRecord | Handler checks `OldRecord != null && NewRecord != null` for UPDATE-INSERT/UPDATE-DELETE, also handles standalone `"UPDATE"` | Correct |
| `DeletedShipmentEventHandler` requires `OldRecord != null` + `IsDeleted: true` | Handler checks `OldRecord exists && NewRecord is null && IsDeleted: true && ChangeType: "DELETE"` | Correct |
| No existing `SendungCdcWriter` | Searched entire `Code/` tree | Confirmed — new project |

### PRD Divergences from Actual Datastream Envelope (discovered from reference JSONL files)

These fields are NOT used by the Cloud Function for business logic, but the writer should match the structure as closely as practical:

| Field | PRD Says | Actual Datastream Output | Writer Will Use |
|---|---|---|---|
| `primary_keys` | `["sendung_tix"]` | ALL 170+ columns listed | All columns from `to_jsonb()` keys — matches Datastream behavior |
| `sort_keys` | `["sendung_tix", value]` | `[timestamp_millis, "lsn_string"]` | `[source_timestamp_epoch_millis, ""]` — no LSN available |
| `schema_key` | Not detailed | SHA hash `ed46b7f9...` | Constant placeholder string — Cloud Function ignores this |
| `lsn` | Not detailed | Actual PostgreSQL LSN e.g. `"77F/F94E0880"` | `""` — no WAL access from pg_notify |
| `read_method` | `"pgnotify"` | `"postgresql-cdc"` | `"pgnotify"` — intentional, for log distinction |
| `stream_name` | Custom identifier | Full GCP resource path | `"pgnotify/sendung_cdc_abn1034"` |
| Numeric format | Not discussed | `sendung_tix` appears as `1.034E+13` (scientific) in some records, integer in others | `to_jsonb()` output passed through — format depends on PostgreSQL serialization |

### Existing Trigger Ecosystem on `tms1034.sendung`

| Trigger | Fires On | Condition | Impact |
|---|---|---|---|
| `TRAIUD_SENDUNG_TABRD_MP4` | AFTER INSERT/UPDATE/DELETE | `sendungsart = 'S'` | Dashboard queue. No conflict. |
| `TRAIU_SENDUNG_ESB` | AFTER INSERT/UPDATE | Various sendungsart types | ESB queue. No conflict. |

PostgreSQL fires AFTER ROW triggers in alphabetical order. `sendung_cdc_trigger` fires before `TRAIUD_SENDUNG_TABRD_MP4`. No ordering dependency.

### Cloud Run Worker Topology Constraints

- **`--no-cpu-throttling`**: REQUIRED. Without it, CPU is throttled to near-zero between HTTP requests. BackgroundService has no HTTP requests — it would freeze.
- **`min-instances: 1`**: REQUIRED. Keeps one instance always warm for the LISTEN connection.
- **Health check**: Cloud Run needs an HTTP endpoint for liveness/readiness even for worker services. The `BackgroundService` must also expose a minimal HTTP endpoint.
- **Connection model**: The service maintains ONE persistent `NpgsqlConnection` for LISTEN. A separate connection is used for GCS writes (via `Google.Cloud.Storage.V1`).

---

## 3. Database Objects (No New Tables)

### Trigger Function: `tms1034.sendung_cdc_notify_fn()`

```sql
CREATE OR REPLACE FUNCTION tms1034.sendung_cdc_notify_fn()
RETURNS TRIGGER AS $$
DECLARE
    v_payload TEXT;
BEGIN
    -- D6: Filter sendungsart = 'A' at trigger level to reduce pg_notify traffic.
    -- For UPDATE: fire if EITHER old OR new is 'A' (matches Cloud Function filter behavior).
    IF TG_OP = 'INSERT' AND NEW.sendungsart != 'A' THEN
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' AND OLD.sendungsart != 'A' THEN
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' AND NEW.sendungsart != 'A' AND OLD.sendungsart != 'A' THEN
        RETURN NEW;
    END IF;

    BEGIN
        IF TG_OP = 'INSERT' THEN
            v_payload := json_build_object(
                'op', 'INSERT',
                'tix', NEW.sendung_tix,
                'ts', extract(epoch from clock_timestamp()),
                'row', to_jsonb(NEW)
            )::TEXT;
            PERFORM pg_notify('sendung_cdc', v_payload);

        ELSIF TG_OP = 'UPDATE' THEN
            v_payload := json_build_object(
                'op', 'UPDATE-DELETE',
                'tix', OLD.sendung_tix,
                'ts', extract(epoch from clock_timestamp()),
                'row', to_jsonb(OLD)
            )::TEXT;
            PERFORM pg_notify('sendung_cdc', v_payload);

            v_payload := json_build_object(
                'op', 'UPDATE-INSERT',
                'tix', NEW.sendung_tix,
                'ts', extract(epoch from clock_timestamp()),
                'row', to_jsonb(NEW)
            )::TEXT;
            PERFORM pg_notify('sendung_cdc', v_payload);

        ELSIF TG_OP = 'DELETE' THEN
            v_payload := json_build_object(
                'op', 'DELETE',
                'tix', OLD.sendung_tix,
                'ts', extract(epoch from clock_timestamp()),
                'row', to_jsonb(OLD)
            )::TEXT;
            PERFORM pg_notify('sendung_cdc', v_payload);
        END IF;

    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'sendung_cdc_notify_fn failed for sendung_tix=%: % [%]',
            COALESCE(NEW.sendung_tix, OLD.sendung_tix), SQLERRM, SQLSTATE;
    END;

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;
```

### Trigger: `sendung_cdc_trigger`

```sql
CREATE TRIGGER sendung_cdc_trigger
    AFTER INSERT OR UPDATE OR DELETE ON tms1034.sendung
    FOR EACH ROW
    EXECUTE FUNCTION tms1034.sendung_cdc_notify_fn();
```

### Rollback Script

```sql
DROP TRIGGER IF EXISTS sendung_cdc_trigger ON tms1034.sendung;
DROP FUNCTION IF EXISTS tms1034.sendung_cdc_notify_fn();
```

### pg_notify Payload Budget

| Change Type | Notifications | Payload Size (measured max) | Limit | Headroom |
|---|---|---|---|---|
| INSERT | 1 | ~4,700 bytes (4,636 + wrapper) | 8,000 | ~3,300 bytes |
| UPDATE | 2 (OLD + NEW, separate) | ~4,700 bytes each | 8,000 each | ~3,300 bytes each |
| DELETE | 1 | ~4,700 bytes | 8,000 | ~3,300 bytes |

---

## 4. File-Level Work Breakdown

### Stream 0 — Foundation (main session)

All paths below are relative to `Code/Nagel-GCP/` (the Nagel-GCP repo).

**Owns:**
- `SendungCdcWriter/scripts/` — trigger SQL files (deploy, rollback)
- `SendungCdcWriter/SendungCdcWriter.sln` — solution file
- `SendungCdcWriter/SendungCdcWriter/SendungCdcWriter.csproj` — project with NuGet refs
- `SendungCdcWriter/SendungCdcWriter/Program.cs` — host setup, DI
- `SendungCdcWriter/SendungCdcWriter/appsettings.json` — configuration
- `SendungCdcWriter/SendungCdcWriter/Dockerfile` — Cloud Run container
- `SendungCdcWriter/SendungCdcWriter/.dockerignore`
- `SendungCdcWriter/SendungCdcWriter/Models/DatastreamEnvelope.cs` — JSONL envelope model
- `SendungCdcWriter/SendungCdcWriter/Models/PgNotifyPayload.cs` — pg_notify JSON model

**Constraints:**
- .NET 8, C# 12 primary constructors
- NuGet: `Npgsql` (LISTEN), `Google.Cloud.Storage.V1` (GCS), `System.Text.Json` (serialization), `Microsoft.Extensions.Hosting` (worker), `Microsoft.Extensions.Diagnostics.HealthChecks` (health)
- `DatastreamEnvelope` JSON property names use `snake_case` via `JsonPropertyName` attributes — must match the reference JSONL samples exactly
- `PgNotifyPayload` matches the trigger's `json_build_object` structure: `op`, `tix`, `ts`, `row`

### Stream A — Writer Service Implementation (agent)

**Owns** (paths relative to `Code/Nagel-GCP/`):
- `SendungCdcWriter/SendungCdcWriter/Services/CdcListenerService.cs` — BackgroundService
- `SendungCdcWriter/SendungCdcWriter/Services/JsonlFormatter.cs` — envelope formatting
- `SendungCdcWriter/SendungCdcWriter/Services/UpdatePairTracker.cs` — UPDATE state machine
- `SendungCdcWriter/SendungCdcWriter/Services/HealthCheckService.cs` — HTTP health endpoint
- `SendungCdcWriter/SendungCdcWriter.Tests/SendungCdcWriter.Tests.csproj` — test project
- `SendungCdcWriter/SendungCdcWriter.Tests/JsonlFormatterTests.cs`
- `SendungCdcWriter/SendungCdcWriter.Tests/UpdatePairTrackerTests.cs`

**Constraints:**
- MUST NOT touch any file outside `Code/Nagel-GCP/SendungCdcWriter/`
- MUST use the `DatastreamEnvelope` and `PgNotifyPayload` models from Stream 0 as-is
- `CdcListenerService` pattern:
  - `BackgroundService.ExecuteAsync` → outer reconnection loop with exponential backoff
  - Inner: `NpgsqlConnection.OpenAsync` → `LISTEN sendung_cdc` → `WaitAsync` loop
  - On notification: parse `PgNotifyPayload`, route through `UpdatePairTracker`, format via `JsonlFormatter`, write to GCS
- `UpdatePairTracker` state machine:
  - Keyed by `sendung_tix` (multiple concurrent UPDATEs on different rows)
  - States: `Idle` → received UPDATE-DELETE → `WaitingForInsert` → received UPDATE-INSERT → emit pair → `Idle`
  - Timeout: if UPDATE-INSERT doesn't arrive within 5 seconds, emit a warning log and drop the orphaned UPDATE-DELETE (PostgreSQL guarantees both arrive together within a committed transaction, so this timeout is a safety net for reconnection edge cases only)
  - Orphaned UPDATE-INSERT (no preceding UPDATE-DELETE): emit as standalone `"UPDATE"` change_type, log warning
- `JsonlFormatter`:
  - Produces one JSONL line per Datastream event
  - Field mapping must match `example-insert.jsonl`, `example-update.jsonl`, `example-delete.jsonl` exactly for the fields the Cloud Function uses: `source_metadata.change_type`, `source_metadata.is_deleted`, `source_metadata.table`, `source_metadata.schema`, `payload.*`
  - For fields the Cloud Function doesn't use (`schema_key`, `sort_keys`, `lsn`, `primary_keys`, `stream_name`): use reasonable defaults, don't need to match Datastream exactly
  - GCS file naming: `{uuid}_pgnotify_{unix_timestamp_millis}.jsonl`
  - GCS path: `tms1034_sendung/{filename}`
  - Bucket: `abn1043-sendung-bucket-1`
- `HealthCheckService`:
  - Minimal HTTP endpoint on port 8080 (`/health`)
  - Returns 200 if LISTEN connection is alive, 503 otherwise
  - Use `IHealthCheck` interface
- Reconnection: exponential backoff starting at 1s, max 60s, with jitter
- Tests use **MSTest** (`[TestClass]`, `[TestMethod]`)
- Test coverage: JsonlFormatter (all 4 change types), UpdatePairTracker (normal pair, orphaned INSERT, orphaned DELETE, timeout, multi-row concurrent updates)

---

## 5. Code Review Gates

| Gate | After | Lenses | What to Check |
|---|---|---|---|
| G1 | Stream 0 (Foundation) | Architectural + Clean-Code (parallel) | Trigger SQL correctness, pg_notify payload size, exception handler semantics, model accuracy vs reference JSONL, project structure, NuGet package choices |
| G2 | Stream A (Writer Service) | Architectural + Clean-Code (parallel) | Reconnection logic, state machine edge cases, JSONL format correctness, GCS write error handling, health check implementation, test coverage, concurrency safety of UpdatePairTracker |
| G3 | Integration | Architectural | Does the assembled project build? Do models match between trigger output and writer input? Are the configuration values correct for abn1034? |

**Review handling:**
- Critical / High: fix before next step
- Medium: fix inline if cheap, else log in deferred section
- Low: log only
- Fix commits: `review-fix: <area>`

### G1 Review Result (2026-06-12)

**Verdict: PASS** — 2 fixes applied, remaining findings triaged as false positives or deferred.

| Finding | Severity | Disposition |
|---|---|---|
| Bucket name `abn1043` flagged as typo | Critical (both) | **False positive** — PRD specifies `abn1043-sendung-bucket-1` as actual GCP bucket name |
| Program.cs won't compile without Stream A | Critical/High (both) | **By design** — foundation wiring, Gate G3 verifies assembled build |
| Timestamp seconds vs millis in trigger | High (Arch) | **Stream A concern** — JsonlFormatter will `* 1000` |
| `List<string>` → `IReadOnlyList<string>` for PrimaryKeys | Medium (CC) | **Fixed** — immutability contract consistency |
| PgNotifyPayload short property names | Medium (CC) | **Fixed** — `Op`→`Operation`, `Tix`→`SendungTix`, `Ts`→`EpochTimestamp`, `Row`→`RowData` |
| DateTimeOffset for timestamp fields | High (CC) | **Skipped** — output-only strings, format controlled in JsonlFormatter |
| JsonArray vs JsonElement for sort_keys | High (CC) | **Skipped** — intentional: construction vs passthrough are different use cases |
| Enums for ChangeType/ReadMethod | Medium (CC) | **Skipped** — temporary solution, constants belong in JsonlFormatter |
| Split SourceMetadata to own file | Medium (CC) | **Skipped** — exclusively composed into DatastreamEnvelope |
| Docker context ambiguity | Medium (CC) | **Skipped** — Dockerfile is in project dir, build context = project dir |

---

## 6. Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation | Source |
|---|---|---|---|---|
| **R1: Events lost during writer downtime** | Certain (every deployment) | Low (ABN testing, not production) | Accepted trade-off (D1). CDCRecovery manual catch-up available if gaps are noticed. | PRD W1, W4 |
| **R2: pg_notify payload exceeds 8000 bytes** | Low (max measured 4,636) | Medium (event silently dropped) | Exception handler in trigger. Add structured log in writer for payload size distribution. Monitor for schema changes. | PRD M7 |
| **R3: Cloud Run CPU throttling** | High (if misconfigured) | Critical (silent stall — zero events processed) | Deploy with `--no-cpu-throttling` flag. Health check monitors LISTEN connection. | Phase 0 Footgun 2 |
| **R4: Batch import amplifies GCS write latency** | Low (normal testing flow) | Low (events buffered, delivered with delay) | Npgsql notification buffer absorbs bursts. Single-event-per-file keeps processing simple. | Phase 0 Footgun 4 |
| **R5: JSONL format mismatch** | Low | High (Cloud Function rejects files) | Compare writer output against reference JSONL samples in tests. Shadow-mode verification before cutover. | PRD V5 |
| **R6: AlloyDB connection auth** | Medium | Medium (writer can't connect) | Use Workload Identity for Cloud Run → AlloyDB. Fallback: Cloud Run Secret Manager for connection string. | PRD T2 |
| **R7: UPDATE pair lost on reconnection** | Low (PostgreSQL delivers both together) | Low (orphaned event emitted as standalone UPDATE) | 5-second timeout on pending pairs. Orphaned UPDATE-INSERT emitted as standalone `"UPDATE"`. Warning logged. | D2 |
| **R8: Existing triggers add combined overhead** | Low | Low | Total added: ~1-2ms per row. Existing triggers already add similar overhead. Benchmark on abn1034 before cutover. | Phase 0 Footgun 6 |

---

## 7. Out of Scope

- Modifying Cloud Function (`FilterShipmentsTrigger`), Pub/Sub topics/subscriptions, or Backend CDC handlers
- Outbox table (Option A from exploration) — explicit decision D1
- CDCRecovery as automated safety net (PRD W4)
- Multi-environment support — hardcoded to abn1034/tms1034
- Batching (PRD W6) — one file per logical event
- Pub/Sub retry/DLQ for pg_notify transport (PRD W3)
- Liquibase changeset for trigger DDL — manual psql only (D4)
- Cloud Monitoring dashboard — structured logging + basic health check only (M9 simplified)
- Permanent Datastream replacement architecture
- Configurable bucket/schema — all hardcoded for abn1034

---

## 8. Acceptance Checklist

Derived from PRD Verification section:

| # | Criterion | Corresponds To |
|---|---|---|
| AC1 | Trigger function `sendung_cdc_notify_fn()` created on `tms1034` | PRD M1 |
| AC2 | Trigger fires on INSERT of `sendungsart = 'A'` — pg_notify visible in `LISTEN` psql session | PRD V1, D6 |
| AC2a | Trigger does NOT fire on INSERT of `sendungsart != 'A'` | D6 |
| AC3 | Trigger fires on UPDATE of `sendungsart = 'A'` — two pg_notify events (UPDATE-DELETE, UPDATE-INSERT) | PRD V2, D6 |
| AC4 | Trigger fires on DELETE of `sendungsart = 'A'` — pg_notify with `to_jsonb(OLD)` payload | PRD V3, D6 |
| AC5 | Trigger exception handler: simulated failure does NOT block sendung write | PRD M7 |
| AC6 | Writer project builds and Dockerfile produces working container | PRD M3 |
| AC7 | Writer LISTEN loop receives pg_notify events and produces JSONL files | PRD V4 |
| AC8 | JSONL envelope matches reference samples (change_type, is_deleted, payload field names) | PRD V5, M5 |
| AC9 | UPDATE events produce 2-line paired JSONL file | PRD M4 |
| AC10 | Writer reconnects after connection loss with exponential backoff | PRD M8, V10 |
| AC11 | Health check endpoint returns 200 (live) / 503 (disconnected) | PRD S1 |
| AC12 | Tests pass: JsonlFormatter (all 4 change types) + UpdatePairTracker (edge cases) | — |
| AC13 | Orphaned UPDATE-INSERT emitted as standalone UPDATE with warning log | D2 |

**Not verifiable locally (require abn1034 access):**

| # | Criterion | Corresponds To |
|---|---|---|
| AC14 | JSONL files appear in `gs://abn1043-sendung-bucket-1/tms1034_sendung/` | PRD V4 |
| AC15 | Cloud Function `FilterShipmentsTrigger` processes pg_notify-generated files | PRD V6 |
| AC16 | Backend receives and processes events via Pub/Sub | PRD V7 |
| AC17 | Datastream paused, replication slot dropped, pg_notify continues independently | PRD V8 |

---

## 9. Execution Order

| Step | What | Gate? | Branch | Status |
|---|---|---|---|---|
| 1 | Create feature branch `feature/pgnotify-cdc-sendung` | Hard stop: user confirms | — | Done |
| 2 | Commit this plan to feature branch | — | `feature/pgnotify-cdc-sendung` | Skipped (plan in VA repo) |
| 3 | **Stream 0**: Trigger SQL scripts + .NET project scaffolding + models | — | same | Done |
| 4 | **Review Gate G1**: Architectural + Clean-Code on Stream 0 | Hard stop: fix Critical/High | same | Done (see below) |
| 5 | Commit Stream 0 | — | same | Done (`0857848`) |
| 6 | **Stream A**: Writer service implementation (CdcListenerService, JsonlFormatter, UpdatePairTracker, HealthCheck, Tests) | — | same | In progress |
| 7 | **Review Gate G2**: Architectural + Clean-Code on Stream A | Hard stop: fix Critical/High | same | — |
| 8 | Commit Stream A | — | same | — |
| 9 | **Integration**: Build verification, model consistency check | — | same | — |
| 10 | **Review Gate G3**: Architectural on integrated project | Hard stop: fix Critical/High | same | — |
| 11 | Final commit + report | — | same | — |

---

## 10. Local Testing Strategy

**Start on ent1034** — not abn1034. Validate trigger + writer end-to-end on ent1034 first, then promote to abn1034.

| Step | Database | What | Status |
|---|---|---|---|
| T1 | `ent1034` (10.100.4.16) | Deploy trigger (`001_create_sendung_cdc_trigger.sql`) | Done (2026-06-12) |
| T2 | `ent1034` | Run writer locally with `Gcs:LocalOutputPath` → verify JSONL files on disk | Done (2026-06-12) |
| T3 | `ent1034` | Manual `pg_notify` test — confirm full pipeline works without touching real data | Done (2026-06-12) |
| T4 | `ent1034` | Trigger a real `sendungsart='A'` INSERT/UPDATE/DELETE — inspect JSONL output | Done (2026-06-12) |
| T5 | `ent1034` | Rollback trigger if issues found, iterate | — |
| T6 | `abn1034` (10.100.47.236) | Deploy trigger — production-path testing | — |
| T7 | `abn1034` | Run writer against GCS bucket `abn1043-sendung-bucket-1` | — |

**ent1034 connection:**
```
psql -h 10.100.4.16 -U tms1034 -d ent1034
```

**Local writer run (ent1034 + local files):**
```bash
cd Code/Nagel-GCP/SendungCdcWriter/SendungCdcWriter
export ConnectionStrings__AlloyDb="Host=10.100.4.16;Port=5432;Database=ent1034;Username=tms1034"
dotnet run
```

Note: `appsettings.json` has `Gcs:LocalOutputPath` set to `./temp/pg-notify-test` — JSONL files will appear there. Set to `null` when switching to GCS.

### T1–T4 Executed SQL Log (2026-06-12, ent1034)

**T1 — Deploy trigger:**
```sql
-- Applied via: psql -h 10.100.4.16 -U tms1034 -d ent1034 -f scripts/001_create_sendung_cdc_trigger.sql
-- Result: CREATE FUNCTION, CREATE TRIGGER
```

**T3 — Manual pg_notify (synthetic payload, no table change):**
```sql
SELECT pg_notify('sendung_cdc', json_build_object(
    'op', 'INSERT',
    'tix', 99999,
    'ts', extract(epoch from clock_timestamp()),
    'row', '{"sendung_tix":99999,"u_version":"!","sendung_n":1,"sendungsart":"A"}'::jsonb
)::text);
-- Result: Writer produced JSONL file (562 bytes), envelope correct
```

**T4 — Real data UPDATE (no-op, existing row):**
```sql
UPDATE tms1034.sendung SET u_time = u_time WHERE sendung_tix = 10340431238593;
-- Row: ISOVOLTA KASSEL → RECAERO UAP (sendungsart='A', status_dis='F')
-- Result: 2-line JSONL file (13,742 bytes) — UPDATE-DELETE (is_deleted=true) + UPDATE-INSERT (is_deleted=false)
```

**T4 — Real data INSERT (test row):**
```sql
INSERT INTO tms1034.sendung (sendung_tix, sendung_n, sendungsart, status_dis, firma, niederlassung,
    fix_key, u_version, c_time, c_user, u_time, ols_user)
VALUES (999999999999999, 9999999, 'A', 'F', 10, 34, '34       ', '!', now(), 'TEST    ', now(), 'TEST    ');
-- Result: JSONL file (6,301 bytes) — INSERT (is_deleted=false)
```

**T4 — Real data DELETE (test row cleanup):**
```sql
DELETE FROM tms1034.sendung WHERE sendung_tix = 999999999999999;
-- Result: JSONL file (6,300 bytes) — DELETE (is_deleted=true)
```

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
