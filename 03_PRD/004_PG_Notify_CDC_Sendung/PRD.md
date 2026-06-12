# PRD: pg_notify CDC for sendung (abn1034)

**Feature ID:** 004_PG_Notify_CDC_Sendung
**Status:** Draft
**Date:** 2026-06-12
**Lifetime:** Temporary — unblocks ABN testing; retained as disabled fallback

---

## 1. Problem

GCP Datastream on abn1034 has proven unreliable, blocking the ABN release testing cycle:

- **Silent stalls:** Datastream stops consuming WAL without logging errors, appearing RUNNING while producing no output (observed 2026-06-08, 2026-06-12).
- **WAL accumulation:** The replication slot `sendung_slot_abn1034` holds ALL WAL across the entire database (700+ tables). During the June 8 stall, this reached 234 GB in hours at ~2.4 GB/hour WAL growth.
- **Disk pressure risk:** An undetected stall can fill the database disk within days.
- **No self-service:** We lack `datastream.streams.update` permission — every incident requires escalation to the Nagel GCP team.
- **Testing blocked:** The ABN test team cannot validate the release pipeline while Datastream is down.

### Root Cause (Architectural)

PostgreSQL's WAL is a single global log for the entire database. Datastream's replication slot must parse 100% of WAL to find the tiny fraction belonging to `sendung`. When the consumer stalls, the slot prevents PostgreSQL from reclaiming ANY WAL — including writes from all 700+ other tables.

Three prior incidents document this same pattern:
- 2026-01-30: 422 GB on uat2820 (replication slot + config change)
- 2026-03-17: Replication slot outage
- 2026-06-08: 234 GB on abn1034 (silent stall, stream reported RUNNING)

---

## 2. Direction Alignment

This feature is explicitly **temporary and scoped to unblocking ABN testing**:

- **Replaces only Datastream** — the transport from TMS DB to GCS bucket
- **The production pipeline stays untouched** — GCS → Cloud Function (`FilterShipmentsTrigger`) → Pub/Sub → Backend (`PubSubMessageHandler`) continues to be exercised. This is intentional: that chain will go live, and bypassing it during testing would leave a major part of the solution unvalidated.
- **pg_notify sidesteps the WAL Sender bottleneck entirely** — the trigger fires only on `sendung` writes; no replication slot is created or needed

### Prior Art

| Source | Key finding |
|---|---|
| [pg-notify-cdc-alternative.md](../../02_Explorations/2026-06-12_pg_notify_CDC_Alternative_for_sendung_abn1034/pg-notify-cdc-alternative.md) | Option B design: trigger + pg_notify, no outbox table |
| [replication-slot-size/README.md](../../02_Explorations/2026-01-30-replication-slot-size/README.md) | WAL Sender bottleneck: parses all 774 tables to find 1 |
| [replication-slot-issue/.../README.md](../../02_Explorations/2026-02-02-replication-slot-issue/2026-01-30-replication-slot-size-architekt-exploration/README.md) | Jan 30 incident: 422 GB, multiple root causes |
| [shipment-data-flow-architecture.md](../../02_Explorations/2026-02-25_User-Story-103821_OMS-Sendung-Quell-K/shipment-data-flow-architecture.md) | Full pipeline: Datastream → GCS → Cloud Function → Pub/Sub → Backend |
| [problem-2-cdc-event-processing-failure.md](../../02_Explorations/2026-03-03_cdc-sync-and-error-scenarios/problem-2-cdc-event-processing-failure.md) | Event processing failures are handler-agnostic — switching transport doesn't fix them |
| [cdc-recovery-sendung-data-sync.md](../../02_Explorations/2026-05-21_CDC_Recovery_-_Sendung_Data_Sync/cdc-recovery-sendung-data-sync.md) | Backend resolver pipeline is source-agnostic; CDCRecovery reuses same handlers |
| [replication-slot-monitoring-concept.md](../../02_Explorations/2026-06-10_Replication_Slot_Monitoring_Concept_for_AlloyDB/replication-slot-monitoring-concept-for-alloydb.md) | Silent stall detection gaps in AlloyDB/Datastream |

---

## 3. Requirements

### Must Have

| ID | Requirement |
|---|---|
| **M1** | PL/pgSQL trigger function on `tms1034.sendung` that fires on INSERT, UPDATE, DELETE |
| **M2** | Trigger fires on ALL sendung changes — no filtering at trigger level. The existing Cloud Function `FilterShipmentsTrigger` applies the `sendungsart = 'A'` filter as it does in production. |
| **M3** | Cloud Run writer service with `min-instances: 1` in project `prj-cal-w-wl5-t-6c00-53ad` |
| **M4** | Trigger embeds full row payload via `to_jsonb()` in pg_notify. For INSERT: `to_jsonb(NEW)`. For DELETE: `to_jsonb(OLD)`. For UPDATE: two notifications — UPDATE-DELETE with `to_jsonb(OLD)` then UPDATE-INSERT with `to_jsonb(NEW)`. Writer pairs UPDATE notifications before writing (state machine: hold UPDATE-DELETE until UPDATE-INSERT arrives, write both as consecutive lines in one JSONL file). No database query needed. |
| **M5** | Writer writes Datastream-compatible JSONL to `gs://abn1043-sendung-bucket-1/tms1034_sendung/`. Hardcoded to this single environment for now. See `reference/` folder for example files per change type. |
| **M6** | Cutover: pause Datastream stream `new-dispo-cdc-datastream-sendung-abn1034`, point writer to ABN bucket, verify Cloud Functions process events, drop replication slot `sendung_slot_abn1034` to release WAL retention. |
| **M7** | Exception handler in trigger — CDC failure must NEVER block the original `sendung` write. On error: log warning, return normally, sendung transaction commits. |
| **M8** | Reconnection logic with exponential backoff when AlloyDB LISTEN connection drops. Writer must auto-reconnect and resume listening without manual intervention. |
| **M9** | Cloud Monitoring metric for writer throughput: events received, files written, errors. |

### Should Have

| ID | Requirement |
|---|---|
| **S1** | Health check endpoint on Cloud Run for liveness/readiness probes |

### Won't Have (explicit decisions)

| ID | Decision | Rationale |
|---|---|---|
| **W1** | No outbox table | Option B — avoids new TMS table for a temporary solution. Notifications lost during writer downtime are accepted. |
| **W3** | No Pub/Sub retry/DLQ for pg_notify transport | The downstream Pub/Sub chain retains its own retry behavior. pg_notify is fire-and-forget by design. |
| **W4** | No CDCRecovery as guaranteed safety net | Feature is not fully finished. Gap is accepted. |
| **W5** | No multi-environment rollout | abn1034 only. |
| **W6** | No batching | One JSONL file per logical event (1 file for INSERT/DELETE, 1 file with 2 lines for UPDATE pair). Simplifies UPDATE pairing logic. |

---

## 4. Out of Scope

- Modifying the Cloud Function, Pub/Sub topics/subscriptions, or Backend CDC handler chain — these stay untouched and continue to be exercised
- Option A (outbox table) — descoped to avoid new TMS table creation for a temporary solution
- Permanent Datastream replacement architecture — this is a stopgap to unblock testing
- Monitoring for replication slot WAL lag (no replication slot is created by this feature)
- Handler idempotency improvements (known Problem-2 issue, transport-agnostic, separate work)
- Configurable multi-environment support — hardcoded to abn1034 bucket/schema

---

## 5. Security

Low-risk surface: the writer runs inside GCP, connects to AlloyDB via private networking (same VPC as Datastream), writes to an existing GCS bucket. No new external exposure.

| Threat | MVP Mitigation |
|---|---|
| T1: Writer GCS credentials over-scoped | IAM: `roles/storage.objectCreator` on `abn1043-sendung-bucket-1` only |
| T2: AlloyDB credentials in writer config | Use Cloud Run secret manager or Workload Identity for DB auth |
| T3: pg_notify payload contains full row JSON (PII in sendung) | Same data already flows through Datastream to same bucket; no new exposure surface |

---

## 6. Implementation Approach

### Architecture

```
┌────────────────────────────────────────────────────────────────────┐
│ AlloyDB (abn1034)                                                  │
│                                                                    │
│  ┌──────────────┐    TRIGGER     ┌──────────────────────────────┐ │
│  │ tms1034      │───────────────>│ pg_notify('sendung_cdc',     │ │
│  │ .sendung     │  AFTER INSERT, │   {op, tix, row: to_jsonb()})│ │
│  │              │  UPDATE,DELETE  │                              │ │
│  └──────────────┘                └──────────────┬───────────────┘ │
│                                                  │                 │
└──────────────────────────────────────────────────┼─────────────────┘
                                                   │
                              ┌─────────────────────▼──────────────────────┐
                              │ Cloud Run: sendung-cdc-writer              │
                              │ (prj-cal-w-wl5-t-6c00-53ad)               │
                              │                                            │
                              │  1. LISTEN on 'sendung_cdc' channel        │
                              │  2. Parse pg_notify payload (JSON)         │
                              │  3. For UPDATE: pair UPDATE-DELETE +       │
                              │     UPDATE-INSERT before writing           │
                              │  4. Format Datastream-compatible JSONL     │
                              │  5. Write .jsonl file to GCS               │
                              └─────────────────────┬──────────────────────┘
                                                    │
                                                    ▼
                              ┌─────────────────────────────────────────────┐
                              │ gs://abn1043-sendung-bucket-1/              │
                              │   tms1034_sendung/                          │
                              │     {uuid}_pgnotify_{timestamp}.jsonl       │
                              │                                             │
                              │  Same JSONL format as Datastream ──>        │
                              │  existing pipeline processes unchanged:     │
                              │                                             │
                              │  Cloud Function (FilterShipmentsTrigger)    │
                              │       ↓ filters sendungsart = 'A'          │
                              │  Pub/Sub                                    │
                              │       ↓                                     │
                              │  New Dispo Backend (PubSubMessageHandler)   │
                              └─────────────────────────────────────────────┘
```

### Database Side (AlloyDB abn1034)

| Object | Type | Purpose |
|---|---|---|
| `tms1034.sendung_cdc_notify_fn()` | PL/pgSQL function | Fires pg_notify with embedded `to_jsonb()` payload. INSERT: 1 notification with NEW. UPDATE: 2 notifications (UPDATE-DELETE with OLD, UPDATE-INSERT with NEW). DELETE: 1 notification with OLD. Exception handler ensures trigger failure never blocks sendung writes. |
| `sendung_cdc_trigger` | AFTER trigger on `tms1034.sendung` FOR EACH ROW | Calls `sendung_cdc_notify_fn()` on INSERT, UPDATE, DELETE. No WHERE filter — all sendung changes fire. |

**pg_notify payload size:** Verified on abn1034 (2026-06-12): min 3,782 bytes, avg 4,266 bytes, max 4,636 bytes per `to_jsonb()` call. With JSON wrapper (~40 bytes overhead), worst case ~4,700 bytes — well within pg_notify's 8,000-byte limit with ~3,300 bytes headroom.

**UPDATE pairing guarantee:** Both pg_notify calls (UPDATE-DELETE + UPDATE-INSERT) execute within the same database transaction. PostgreSQL delivers all notifications from a committed transaction together, in order. The writer's state machine holds an UPDATE-DELETE in memory until the UPDATE-INSERT arrives immediately after, then writes both as consecutive lines in one JSONL file — matching the exact format the Cloud Function expects (see `example-update.jsonl`).

### Cloud Run Writer Service

- .NET 8 Worker Service (`BackgroundService`)
- Npgsql `LISTEN` + `WaitAsync` for pg_notify channel `sendung_cdc`
- Stateless notification-to-JSONL transformer — no database read connection needed, only the LISTEN connection
- UPDATE state machine: `idle` → received UPDATE-DELETE → hold in memory → received UPDATE-INSERT → write paired file → `idle`
- One JSONL file per logical event written to GCS
- Reconnection with exponential backoff on connection loss (M8)
- Deploy in `prj-cal-w-wl5-t-6c00-53ad` with `min-instances: 1`

### JSONL Envelope Format

The writer must produce the exact same envelope structure as Datastream. Reference samples from the live ABN bucket are in this folder:

| File | Change Type | Lines | Description |
|---|---|---|---|
| `example-insert.jsonl` | INSERT | 1 | Single INSERT event, `is_deleted=false` |
| `example-update.jsonl` | UPDATE-DELETE + UPDATE-INSERT | 2 | Paired UPDATE, same `tx_id`, consecutive lines |
| `example-delete.jsonl` | DELETE | 1 | Single DELETE event, `is_deleted=true` |
| `reference-datastream-sample.jsonl` | Multiple UPDATE pairs | 12 | Bulk reference from live Datastream |

Key envelope fields the writer must populate:

| Field | Source |
|---|---|
| `uuid` | Generated UUID |
| `read_timestamp` | Current UTC time |
| `source_timestamp` | Trigger execution time (from pg_notify payload or current UTC) |
| `object` | `"tms1034_sendung"` (underscore, not dot — matches Datastream) |
| `read_method` | `"pgnotify"` (distinguishes from Datastream's `"postgresql-cdc"`) |
| `source_metadata.change_type` | `"INSERT"`, `"UPDATE-DELETE"`, `"UPDATE-INSERT"`, or `"DELETE"` |
| `source_metadata.is_deleted` | `true` for DELETE and UPDATE-DELETE, `false` otherwise |
| `source_metadata.table` | `"sendung"` |
| `source_metadata.schema` | `"tms1034"` |
| `payload` | The `to_jsonb()` output — PostgreSQL column names as keys |

### Cutover Sequence

1. Deploy trigger function and trigger on abn1034
2. Deploy Cloud Run writer service
3. Verify JSONL files appear in `gs://abn1043-sendung-bucket-1/tms1034_sendung/`
4. Verify Cloud Function `FilterShipmentsTrigger` processes the files correctly
5. Verify events flow through Pub/Sub to Backend
6. Pause Datastream stream `new-dispo-cdc-datastream-sendung-abn1034`
7. Drop replication slot `sendung_slot_abn1034` to release WAL retention

### Exit / Fallback Retention

When Datastream stabilizes or a permanent CDC solution is decided:

1. `ALTER TABLE tms1034.sendung DISABLE TRIGGER sendung_cdc_trigger;`
2. Scale Cloud Run writer to 0 instances (keep image and service definition)
3. Resume Datastream or activate permanent solution
4. Trigger + Cloud Run image available for re-enable if Datastream fails again

---

## 7. Files Likely to Change

| Component | Change | New / Modified |
|---|---|---|
| AlloyDB abn1034: `tms1034.sendung_cdc_notify_fn()` | Trigger function (PL/pgSQL) | New |
| AlloyDB abn1034: `sendung_cdc_trigger` | AFTER trigger on sendung | New |
| New Cloud Run service: `SendungCdcWriter/` | Worker service (.NET 8) | New project |
| GCP: Cloud Run service definition | Dockerfile, deployment config, IAM bindings | New |
| GCP: Datastream stream `new-dispo-cdc-datastream-sendung-abn1034` | Paused at cutover | Modified (operational) |
| GCP: Replication slot `sendung_slot_abn1034` | Dropped at cutover | Removed |

**No changes to:** Cloud Functions, Pub/Sub topics/subscriptions, New Dispo Backend, TMS Bridge, Frontend.

---

## 8. Verification

| Step | What | Pass Criteria |
|---|---|---|
| **V1** | Deploy trigger on abn1034, INSERT a test sendung row | pg_notify fires, visible in a `LISTEN` psql session |
| **V2** | UPDATE a test sendung row | Two pg_notify events fire: UPDATE-DELETE then UPDATE-INSERT, both visible in LISTEN session |
| **V3** | DELETE a test sendung row | pg_notify fires with `to_jsonb(OLD)` payload |
| **V4** | Deploy writer, observe GCS bucket | JSONL files appear in `gs://abn1043-sendung-bucket-1/tms1034_sendung/` |
| **V5** | Compare JSONL envelope with reference samples | Envelope structure matches: `source_metadata.change_type`, `payload.*` column names, `is_deleted` flag. UPDATE events appear as 2-line paired file. |
| **V6** | Cloud Function processes pg_notify-generated files | `FilterShipmentsTrigger` logs show successful processing, Pub/Sub messages published for `sendungsart = 'A'` rows, non-A rows filtered |
| **V7** | Backend receives and processes events | `PubSubMessageHandler` processes INSERT/UPDATE/DELETE events. Legs appear, update, and delete in New Dispo. ShipmentUpdatedEventHandler receives both OldRecord and NewRecord for UPDATEs. |
| **V8** | Pause Datastream, drop replication slot | WAL retention released, no slot growth, pg_notify continues independently |
| **V9** | ABN test team resumes testing | End-to-end sendung flow works without Datastream |
| **V10** | Writer reconnects after connection loss | Kill LISTEN connection; writer reconnects with backoff and resumes processing |

---

## 9. Related

| Type | Reference |
|---|---|
| Source exploration | [pg-notify-cdc-alternative.md](../../02_Explorations/2026-06-12_pg_notify_CDC_Alternative_for_sendung_abn1034/pg-notify-cdc-alternative.md) |
| Replication slot incidents | [2026-01-30 README.md](../../02_Explorations/2026-01-30-replication-slot-size/README.md), [2026-02-02 README.md](../../02_Explorations/2026-02-02-replication-slot-issue/2026-01-30-replication-slot-size-architekt-exploration/README.md) |
| Pipeline architecture | [shipment-data-flow-architecture.md](../../02_Explorations/2026-02-25_User-Story-103821_OMS-Sendung-Quell-K/shipment-data-flow-architecture.md) |
| CDC error handling | [problem-2-cdc-event-processing-failure.md](../../02_Explorations/2026-03-03_cdc-sync-and-error-scenarios/problem-2-cdc-event-processing-failure.md) |
| CDCRecovery design | [cdc-recovery-sendung-data-sync.md](../../02_Explorations/2026-05-21_CDC_Recovery_-_Sendung_Data_Sync/cdc-recovery-sendung-data-sync.md) |
| Datastream operations | [gcp-datastream-gcloud-operations-guide.md](../../02_Explorations/2026-06-09_gcloud-tooling/gcp-datastream-gcloud-operations-guide.md) |
| Silent stall monitoring | [replication-slot-monitoring-concept.md](../../02_Explorations/2026-06-10_Replication_Slot_Monitoring_Concept_for_AlloyDB/replication-slot-monitoring-concept-for-alloydb.md) |
| Sendung table semantics | [the-meaning-integration-and-dependencies-of-t-shipments.md](../../02_Explorations/2026-03-05_the_meaning_integration_and_dependencies_of_T_shipments_in_relation_to_A_shipmen/the-meaning-integration-and-dependencies-of-t-shipments-in-relation-to-a-shipmen.md) |
| JSONL reference samples | `example-insert.jsonl`, `example-update.jsonl`, `example-delete.jsonl`, `reference-datastream-sample.jsonl` (this folder) |

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
