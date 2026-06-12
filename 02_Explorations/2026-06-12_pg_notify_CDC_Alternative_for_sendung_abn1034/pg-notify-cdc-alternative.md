# pg_notify CDC Alternative for sendung (abn1034)

**Date:** 2026-06-12
**Status:** Draft
**Scope:** Replace Datastream with trigger-based CDC using pg_notify for the `tms1034.sendung` table on AlloyDB (abn1034, already in GCP)

---

## Problem Statement

The GCP Datastream instance `new-dispo-cdc-datastream-sendung-abn1034` has proven unreliable:

- **Silent stalls:** Datastream stops consuming WAL without logging errors, appearing RUNNING while producing no output (observed 2026-06-08, 2026-06-12)
- **WAL accumulation:** The replication slot `sendung_slot_abn1034` holds ALL WAL across the entire database (700+ tables), not just `sendung` changes. During the June 8 stall, this reached 234 GB in hours.
- **Disk pressure risk:** At ~2.4 GB/hour WAL growth, an undetected stall can fill the disk within days.
- **No self-service:** We lack `datastream.streams.update` permission to pause/resume streams ourselves, requiring escalation through the Nagel GCP team.

### Root Cause (Architectural)

PostgreSQL's WAL is a single global log for the entire database. Datastream's replication slot must parse 100% of WAL to find the tiny fraction belonging to `sendung`. When the consumer stalls, the slot prevents PostgreSQL from reclaiming ANY WAL — including writes from all 700+ other tables.

```
┌─────────────────────────┐
│ PostgreSQL WAL (global)  │  ~2.4 GB/hour total writes
│  - table_a changes       │
│  - table_b changes       │
│  - ... 700+ tables ...   │      Replication slot holds
│  - sendung changes ◄─────┼──── ALL of this, even though
│  - table_z changes       │     only sendung is published
└─────────────────────────┘
```

---

## Solution Options

Two options exist, depending on whether we can add a new table to the TMS Database on abn1034.

### Option A: Trigger + Outbox Table + pg_notify (Recommended)

Full Datastream format compatibility. The trigger writes old and new row images to an outbox table, pg_notify wakes up the writer service for near-real-time delivery.

### Option B: pg_notify Only (No New Table)

Minimal database footprint — only a trigger function and `pg_notify`, no outbox table. The trigger fires `pg_notify` with `sendung_tix` + change_type, and the Cloud Run writer queries the live `sendung` table to build the JSONL envelope.

**Critical limitation:** The writer cannot reconstruct the **before-image** (old row values) for UPDATEs and DELETEs. By the time the writer queries `sendung`, the row already has the new values (UPDATE) or is gone (DELETE). This breaks the `UPDATE-DELETE` / `UPDATE-INSERT` pairing that the Cloud Function `BucketDataStreamFileContentProcessor` expects.

**What this means for the downstream Cloud Function:**
- **INSERT:** Works — writer queries `sendung` by `sendung_tix`, gets the new row.
- **UPDATE:** Only `UPDATE-INSERT` (new values) can be delivered. The `UPDATE-DELETE` line with pre-change data is lost. The Cloud Function currently handles a plain `"UPDATE"` change_type (falls through to `result.NewRecord = file` at line 97 of `BucketDataStreamFileContentProcessor.cs`), so this works but the Pub/Sub event will have `OldRecord = null`.
- **DELETE:** The row is gone. The writer would need to deliver a DELETE event with `is_deleted: true` and an empty or partial payload. The Cloud Function sets `result.OldRecord = file` for DELETEs — the payload would be missing.

**Workaround for DELETE:** The trigger could include the full row JSON in the pg_notify payload itself. pg_notify has an 8000-byte limit. A sendung row with 197 columns will likely exceed this, but the 44 columns the Cloud Function actually maps (~1.5-3 KB) might fit if the trigger selects only those columns. This adds coupling between the trigger and the Cloud Function's field list.

**Workaround for UPDATE old values:** Not feasible without storing state somewhere. The trigger has access to `OLD` and `NEW` inside PL/pgSQL, but pg_notify's 8000-byte limit cannot carry two full row images.

### Option Comparison

| Aspect | Option A (Outbox) | Option B (pg_notify only) |
|---|---|---|
| New DB objects | Table + trigger + function | Trigger + function only |
| Datastream format compatibility | Full — INSERT, UPDATE pair, DELETE | Partial — INSERT and UPDATE-INSERT only |
| DELETE support | Full old-row payload | Full via `to_jsonb(OLD)` — verified ≤4,636 bytes on abn1034 |
| UPDATE old values | Full before/after images | After-image only (OldRecord = null) |
| Durability | Outbox survives restarts | Notifications lost if no listener |
| Writer downtime tolerance | Unlimited — outbox queues changes | Zero — all changes during downtime are lost |
| Column coupling | None — `to_jsonb()` is generic | None — `to_jsonb()` is generic |
| DB write overhead | 1 extra INSERT per change (2 for UPDATE) | None beyond pg_notify |
| Monitoring | Query outbox depth | No visibility into missed notifications |

**Recommendation:** Option A. The outbox table is small (a few KB per sendung change) and provides durability, full format compatibility, and operational visibility. Option B only makes sense if adding a table is blocked by policy and the downstream Cloud Function is modified to tolerate missing OldRecord/DELETE payloads.

---

## Option A: Trigger + Outbox Table + pg_notify (Full Design)

### Architecture Overview

```
┌────────────────────────────────────────────────────────────────────────────┐
│ AlloyDB (abn1034)                                                          │
│                                                                            │
│  ┌──────────────┐    TRIGGER     ┌─────────────────────┐                   │
│  │ tms1034      │───────────────>│ tms1034             │                   │
│  │ .sendung     │  on INSERT,    │ .sendung_cdc_outbox │                   │
│  │              │  UPDATE,DELETE  │                     │                   │
│  └──────────────┘       │        └──────────┬──────────┘                   │
│                         │                   │                              │
│                    pg_notify('sendung_cdc') │ durable queue                │
│                         │                   │ (survives restarts)          │
│                         ▼                   │                              │
└─────────────────────────┼───────────────────┼──────────────────────────────┘
                          │                   │
              ┌───────────▼───────────────────▼──────────────┐
              │ Cloud Run: sendung-cdc-writer                │
              │                                              │
              │  1. LISTEN on pg_notify channel               │
              │  2. Poll outbox table (fallback, every 10s)  │
              │  3. Batch rows into Datastream JSONL format   │
              │  4. Write .jsonl files to GCS                │
              │  5. DELETE processed outbox rows              │
              └──────────────────────┬───────────────────────┘
                                     │
                                     ▼
              ┌──────────────────────────────────────────────┐
              │ gs://abn1043-sendung-bucket-1/               │
              │   tms1034_sendung/                           │
              │     {uuid}_pgnotify_{sequence}.jsonl         │
              │                                              │
              │  Same format as Datastream ──> existing      │
              │  Cloud Functions process these unchanged     │
              └──────────────────────────────────────────────┘
```

### Why This Eliminates the Replication Slot Problem

| Aspect | Datastream (current) | Trigger + pg_notify (proposed) |
|---|---|---|
| WAL retention | Holds ALL WAL across entire DB | No replication slot needed |
| WAL parsing | Parses 100% of WAL to find sendung | Only fires on sendung writes |
| Stall risk | Silent stalls with no errors | Outbox rows accumulate visibly; easy to monitor |
| Disk pressure | 234 GB in hours during stall | Outbox grows only with sendung row size (~few KB each) |
| Recovery | Requires stream pause/resume (no permission) | Restart Cloud Run service; outbox ensures no data loss |
| Self-service | Depends on Nagel GCP team | Fully under our control |

---

## Option A Implementation

### Step 1: Outbox Table

```sql
CREATE TABLE tms1034.sendung_cdc_outbox (
    id              BIGSERIAL PRIMARY KEY,
    change_type     TEXT NOT NULL,          -- 'INSERT', 'UPDATE-DELETE', 'UPDATE-INSERT', 'DELETE'
    source_timestamp TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    tx_id           BIGINT NOT NULL DEFAULT txid_current(),
    sendung_tix     NUMERIC(22,0) NOT NULL,
    payload         JSONB NOT NULL          -- full row as JSON
);

CREATE INDEX idx_sendung_cdc_outbox_unprocessed 
    ON tms1034.sendung_cdc_outbox (id);
```

The outbox table acts as a **durable queue**. Unlike pg_notify (which is fire-and-forget), rows survive database restarts and consumer downtime.

### Step 2: Trigger Function

The trigger is wrapped in an exception handler so that a failure in the CDC path (e.g. outbox table full, permissions revoked) **never blocks** the original `sendung` write. If the outbox INSERT or pg_notify fails, the trigger logs a warning and returns normally — the sendung transaction commits, but the change is silently lost from the CDC stream.

```sql
CREATE OR REPLACE FUNCTION tms1034.sendung_cdc_trigger_fn()
RETURNS TRIGGER AS $$
BEGIN
    BEGIN
        IF TG_OP = 'INSERT' THEN
            INSERT INTO tms1034.sendung_cdc_outbox (change_type, sendung_tix, payload)
            VALUES ('INSERT', NEW.sendung_tix, to_jsonb(NEW));

        ELSIF TG_OP = 'UPDATE' THEN
            INSERT INTO tms1034.sendung_cdc_outbox (change_type, sendung_tix, payload)
            VALUES 
                ('UPDATE-DELETE', OLD.sendung_tix, to_jsonb(OLD)),
                ('UPDATE-INSERT', NEW.sendung_tix, to_jsonb(NEW));

        ELSIF TG_OP = 'DELETE' THEN
            INSERT INTO tms1034.sendung_cdc_outbox (change_type, sendung_tix, payload)
            VALUES ('DELETE', OLD.sendung_tix, to_jsonb(OLD));
        END IF;

        PERFORM pg_notify('sendung_cdc', TG_OP || ':' || COALESCE(NEW.sendung_tix, OLD.sendung_tix)::TEXT);

    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'sendung_cdc_trigger failed for sendung_tix=%: % [%]',
            COALESCE(NEW.sendung_tix, OLD.sendung_tix), SQLERRM, SQLSTATE;
    END;

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;
```

> **Trade-off:** The exception handler means a trigger failure silently drops the CDC event rather than failing the sendung write. This is the right default — the TMS application must never be blocked by the CDC pipeline. But it means a broken trigger can cause silent data gaps in the CDC stream. The monitoring on outbox depth (see Operational Considerations) is the safety net: if the trigger stops writing rows but sendung writes continue, the outbox depth flatlines while the application is active — which should trigger an alert.

### Step 3: Attach Trigger

```sql
CREATE TRIGGER sendung_cdc_trigger
    AFTER INSERT OR UPDATE OR DELETE ON tms1034.sendung
    FOR EACH ROW
    EXECUTE FUNCTION tms1034.sendung_cdc_trigger_fn();
```

### Step 4: Cloud Run Writer Service (.NET 8)

**NuGet packages:** `Npgsql`, `Google.Cloud.Storage.V1`, `System.Text.Json`

#### Program.cs — Worker Service Entry Point

```csharp
var builder = Host.CreateApplicationBuilder(args);
builder.Services.AddHostedService<SendungCdcWriterService>();
builder.Services.AddSingleton(StorageClient.Create());
builder.Build().Run();
```

#### Configuration (appsettings.json)

```json
{
  "ConnectionStrings": {
    "AlloyDb": "Host=...;Database=...;Username=...;Password=..."
  },
  "CdcWriter": {
    "Channel": "sendung_cdc",
    "BucketName": "abn1043-sendung-bucket-1",
    "Prefix": "tms1034_sendung/",
    "BatchMaxBytes": 52428800,
    "BatchMaxSeconds": 60,
    "PollIntervalSeconds": 10,
    "FetchLimit": 5000
  }
}
```

#### SendungCdcWriterService.cs — BackgroundService with LISTEN + Poll

```csharp
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using Google.Cloud.Storage.V1;
using Npgsql;

public class SendungCdcWriterService(
    IConfiguration configuration,
    StorageClient storageClient,
    ILogger<SendungCdcWriterService> logger) : BackgroundService
{
    private readonly string _connectionString = configuration.GetConnectionString("AlloyDb")!;
    private readonly string _channel = configuration["CdcWriter:Channel"]!;
    private readonly string _bucketName = configuration["CdcWriter:BucketName"]!;
    private readonly string _prefix = configuration["CdcWriter:Prefix"]!;
    private readonly int _batchMaxBytes = configuration.GetValue<int>("CdcWriter:BatchMaxBytes");
    private readonly int _batchMaxSeconds = configuration.GetValue<int>("CdcWriter:BatchMaxSeconds");
    private readonly int _pollInterval = configuration.GetValue<int>("CdcWriter:PollIntervalSeconds");
    private readonly int _fetchLimit = configuration.GetValue<int>("CdcWriter:FetchLimit");

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
    };

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await RunListenLoopAsync(stoppingToken);
            }
            catch (Exception ex) when (!stoppingToken.IsCancellationRequested)
            {
                logger.LogError(ex, "Writer loop failed, reconnecting in 5s");
                await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);
            }
        }
    }

    private async Task RunListenLoopAsync(CancellationToken ct)
    {
        await using var listenConn = new NpgsqlConnection(_connectionString);
        await listenConn.OpenAsync(ct);
        await using (var cmd = new NpgsqlCommand($"LISTEN {_channel}", listenConn))
            await cmd.ExecuteNonQueryAsync(ct);

        logger.LogInformation("Listening on channel {Channel}", _channel);

        var batch = new List<string>();
        var batchBytes = 0;
        var batchStart = DateTime.UtcNow;

        while (!ct.IsCancellationRequested)
        {
            // Wait for pg_notify or poll timeout
            await listenConn.WaitAsync(TimeSpan.FromSeconds(_pollInterval), ct);

            // Drain notifications (we don't use the payload — outbox is the source of truth)
            while (listenConn.Notifications.TryDequeue(out _)) { }

            // Fetch and delete outbox rows in one atomic operation
            var rows = await FetchOutboxBatchAsync(ct);

            foreach (var row in rows)
            {
                var line = FormatDatastreamEnvelope(row);
                batch.Add(line);
                batchBytes += Encoding.UTF8.GetByteCount(line);
            }

            var elapsed = (DateTime.UtcNow - batchStart).TotalSeconds;
            if (batch.Count > 0 && (batchBytes >= _batchMaxBytes || elapsed >= _batchMaxSeconds))
            {
                await WriteBatchToGcsAsync(batch, ct);
                logger.LogInformation("Wrote {Count} lines to GCS", batch.Count);
                batch.Clear();
                batchBytes = 0;
                batchStart = DateTime.UtcNow;
            }
        }
    }

    private async Task<List<OutboxRow>> FetchOutboxBatchAsync(CancellationToken ct)
    {
        await using var conn = new NpgsqlConnection(_connectionString);
        await conn.OpenAsync(ct);

        const string sql = """
            DELETE FROM tms1034.sendung_cdc_outbox
            WHERE id IN (
                SELECT id FROM tms1034.sendung_cdc_outbox
                ORDER BY id
                LIMIT @limit
                FOR UPDATE SKIP LOCKED
            )
            RETURNING id, change_type, source_timestamp, tx_id, sendung_tix, payload;
            """;

        await using var cmd = new NpgsqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("limit", _fetchLimit);

        var rows = new List<OutboxRow>();
        await using var reader = await cmd.ExecuteReaderAsync(ct);
        while (await reader.ReadAsync(ct))
        {
            rows.Add(new OutboxRow
            {
                Id = reader.GetInt64(0),
                ChangeType = reader.GetString(1),
                SourceTimestamp = reader.GetDateTime(2),
                TxId = reader.GetInt64(3),
                SendungTix = reader.GetDecimal(4),
                Payload = reader.GetString(5)
            });
        }

        return rows;
    }

    private static string FormatDatastreamEnvelope(OutboxRow row)
    {
        var isDeleted = row.ChangeType is "DELETE" or "UPDATE-DELETE";

        var envelope = new DatastreamEnvelope
        {
            Uuid = Guid.NewGuid(),
            ReadTimestamp = DateTime.UtcNow,
            SourceTimestamp = row.SourceTimestamp,
            Object = "tms1034.sendung",
            ReadMethod = "pgnotify",
            StreamName = "pg_notify_cdc/sendung_abn1034",
            SchemaKey = "tms1034.sendung",
            SortKeys = ["sendung_tix", row.SendungTix],
            SourceMetadata = new DatastreamMetadata
            {
                Schema = "tms1034",
                Table = "sendung",
                IsDeleted = isDeleted,
                ChangeType = row.ChangeType,
                TxId = row.TxId,
                Lsn = "",
                PrimaryKeys = ["sendung_tix"]
            },
            Payload = JsonDocument.Parse(row.Payload).RootElement
        };

        return JsonSerializer.Serialize(envelope, JsonOptions);
    }

    private async Task WriteBatchToGcsAsync(List<string> lines, CancellationToken ct)
    {
        var fileName = $"{_prefix}{Guid.NewGuid()}_pgnotify_{DateTimeOffset.UtcNow.ToUnixTimeSeconds()}.jsonl";
        var content = string.Join("\n", lines) + "\n";
        var stream = new MemoryStream(Encoding.UTF8.GetBytes(content));

        await storageClient.UploadObjectAsync(
            _bucketName, fileName, "application/jsonl", stream, cancellationToken: ct);
    }
}

// --- Models ---

public record OutboxRow
{
    public long Id { get; init; }
    public required string ChangeType { get; init; }
    public DateTime SourceTimestamp { get; init; }
    public long TxId { get; init; }
    public decimal SendungTix { get; init; }
    public required string Payload { get; init; }
}

public record DatastreamEnvelope
{
    public Guid Uuid { get; init; }
    public DateTime ReadTimestamp { get; init; }
    public DateTime SourceTimestamp { get; init; }
    public required string Object { get; init; }
    public required string ReadMethod { get; init; }
    public required string StreamName { get; init; }
    public required string SchemaKey { get; init; }
    public required List<object> SortKeys { get; init; }
    public required DatastreamMetadata SourceMetadata { get; init; }
    public JsonElement Payload { get; init; }
}

public record DatastreamMetadata
{
    public required string Schema { get; init; }
    public required string Table { get; init; }
    public bool IsDeleted { get; init; }
    public required string ChangeType { get; init; }
    public long TxId { get; init; }
    public required string Lsn { get; init; }
    public required List<string> PrimaryKeys { get; init; }
}
```

#### Dockerfile

```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY . .
RUN dotnet publish -c Release -o /app

FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app
COPY --from=build /app .
ENTRYPOINT ["dotnet", "SendungCdcWriter.dll"]
```

---

## Datastream Format Compatibility

The existing Cloud Function `FilterShipments.Bucket` deserializes JSONL lines into `GoogleBucketFileContentDto<ShipmentData>`. The proposed envelope matches this exactly:

| Datastream field | Type | pg_notify equivalent | Cloud Function usage |
|---|---|---|---|
| `uuid` | GUID | Generated UUID | `Id` — not used in business logic |
| `read_timestamp` | DateTime | Current UTC time | `ReadTimestamp` — not used in business logic |
| `source_timestamp` | DateTime | Trigger `clock_timestamp()` | `SourceTimestamp` — not used in business logic |
| `object` | string | `"tms1034.sendung"` | `Object` — not used in business logic |
| `read_method` | string | `"pgnotify"` | `ReadMethod` — not used in business logic |
| `stream_name` | string | Custom identifier | `StreamName` — not used in business logic |
| `schema_key` | string | `"tms1034.sendung"` | `SchemaKey` — not used in business logic |
| `sort_keys` | List | `["sendung_tix", value]` | `SortKeys` — not used in business logic |
| `source_metadata.schema` | string | `"tms1034"` | Not used in business logic |
| `source_metadata.table` | string | `"sendung"` | Forwarded to Pub/Sub `Table` field |
| `source_metadata.is_deleted` | bool | Derived from change_type | Forwarded to Pub/Sub `IsDeleted` field |
| `source_metadata.change_type` | string | Same values as Datastream | **Critical** — drives UPDATE-DELETE/UPDATE-INSERT pairing |
| `source_metadata.tx_id` | long | `txid_current()` | Not used in business logic |
| `source_metadata.lsn` | string | Empty (no WAL access) | Not used in business logic |
| `source_metadata.primary_keys` | List | `["sendung_tix"]` | Not used in business logic |
| `payload.*` | varies | `to_jsonb(NEW/OLD)` | **Critical** — 44 fields mapped to `ShipmentData` |

### Change Type Pairing

The Cloud Function expects UPDATE operations as two consecutive JSONL lines:
1. `change_type: "UPDATE-DELETE"` — old row values
2. `change_type: "UPDATE-INSERT"` — new row values

The trigger writes these as two consecutive outbox rows with sequential `id` values. The writer service processes outbox rows in `id` order, preserving the pairing that `BucketDataStreamFileContentProcessor.HandleUpdateEventAsync()` expects.

### Payload Column Names

`to_jsonb(NEW)` produces a JSON object with **PostgreSQL column names as keys** — exactly what Datastream delivers. The Cloud Function's `ShipmentData` DTO maps these via `[JsonProperty("sendung_tix")]`, `[JsonProperty("firma")]`, etc. No translation needed.

---

## Operational Considerations

### Trigger Overhead & Transaction Blocking

The trigger runs **inside the same transaction** as the original `sendung` write. The sendung INSERT/UPDATE/DELETE does not return to the caller until the trigger completes.

**Per-row cost breakdown:**
- `to_jsonb(NEW/OLD)` on a 197-column row: ~0.1–0.5ms
- Outbox INSERT (single row, append-only table): ~0.5–1ms
- `pg_notify`: sub-millisecond (in-memory within transaction)
- **Total added latency per row: ~1–2ms**

This is negligible for normal single-row operations.

**Bulk operations are the concern:** If a batch job updates 10,000 sendung rows in one transaction, the trigger fires per row — producing 20,000 outbox INSERTs (UPDATE = 2 rows each) within the same transaction. At ~1ms each, that adds ~20 seconds to the transaction. The exception handler prevents failures from blocking, but the outbox writes themselves still add latency.

#### Async Alternative: pg_notify Only for Signal, Deferred Capture

Instead of writing the outbox in the trigger, the trigger could fire only `pg_notify` with the `sendung_tix`, and the Cloud Run writer queries the live `sendung` table to build the payload. This makes the trigger nearly zero-cost:

```sql
-- Lightweight trigger: only pg_notify, no outbox write
CREATE OR REPLACE FUNCTION tms1034.sendung_cdc_trigger_async_fn()
RETURNS TRIGGER AS $$
BEGIN
    BEGIN
        PERFORM pg_notify('sendung_cdc',
            json_build_object(
                'op', TG_OP,
                'tix', COALESCE(NEW.sendung_tix, OLD.sendung_tix)
            )::TEXT
        );
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'sendung_cdc_trigger failed for sendung_tix=%: % [%]',
            COALESCE(NEW.sendung_tix, OLD.sendung_tix), SQLERRM, SQLSTATE;
    END;

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;
```

The Cloud Run writer receives the notification, then queries `sendung` by `sendung_tix` to build the full payload. **This only works for INSERT and UPDATE** — for DELETEs the row is already gone by the time the writer queries, so the payload cannot be reconstructed.

**Beyond DELETEs, this also introduces broader consistency risks — the payload may not match the triggering change:**

| Scenario | What happens | Impact |
|---|---|---|
| Rapid consecutive UPDATEs | Writer queries after both UPDATEs committed. First notification reads state from second UPDATE. | First change's values are lost. Cloud Function sees a "phantom" update where old and new values are identical, or skips an intermediate state. |
| UPDATE followed by DELETE | Writer receives UPDATE notification, queries by `sendung_tix` — row is already gone. | UPDATE event is lost entirely, or must be emitted with empty payload. |
| DELETE | Row is gone by the time writer queries. | DELETE event has no payload. Cloud Function expects `OldRecord` with row data for DELETEs. |
| INSERT followed by immediate UPDATE | Writer reads already-updated row for the INSERT notification. | INSERT event carries post-update values. Subsequent UPDATE notification reads the same values → appears as no-op. |
| Writer downtime | pg_notify is fire-and-forget. All notifications during downtime are lost permanently. | Silent data gap — no outbox to catch up from. |

**The outbox approach (Step 2 above) avoids all of these** because `to_jsonb(OLD)` / `to_jsonb(NEW)` captures the exact row state at trigger execution time, inside the transaction, before any subsequent change can occur.

#### Recommendation

Use the **synchronous outbox trigger** (Step 2) as the default. The ~1–2ms per-row overhead is acceptable for normal operations. For known bulk operations (batch jobs, data migrations), consider temporarily disabling the trigger:

```sql
ALTER TABLE tms1034.sendung DISABLE TRIGGER sendung_cdc_trigger;
-- ... run bulk operation ...
ALTER TABLE tms1034.sendung ENABLE TRIGGER sendung_cdc_trigger;
```

After re-enabling, the bulk changes are already committed in `sendung` but missing from the outbox. The Cloud Run writer can run a reconciliation query to detect and backfill the gap if needed. This is a controlled, planned operation — unlike the async approach where consistency gaps happen silently at runtime.

### Outbox Growth & Cleanup

- Under normal operation, the writer deletes rows as it processes them
- If the writer is down, the outbox grows at the rate of sendung changes only (not the full 2.4 GB/hour WAL)
- A `sendung` row as JSONB is ~2-5 KB. Even 100,000 unprocessed changes = ~500 MB
- Add a monitoring alert on `SELECT count(*) FROM tms1034.sendung_cdc_outbox`

### pg_notify Reliability

pg_notify is **not durable** — notifications are lost if no listener is connected. This is by design:
- pg_notify serves only as a **wake-up signal** for low-latency delivery
- The outbox table is the **source of truth** for pending changes
- The writer polls the outbox every 10 seconds regardless of notifications
- Worst case without pg_notify: 10-second delay instead of sub-second

### Cloud Run Considerations

- Cloud Run needs a persistent process (not request-driven) for the LISTEN connection
- Use Cloud Run with `min-instances: 1` to keep the listener alive
- AlloyDB and Cloud Run are both in GCP — no cross-network connectivity needed
- The Cloud Run service needs AlloyDB IAM or password-based auth and GCS write permission

### Monitoring

| Metric | Query / Source | Alert threshold |
|---|---|---|
| Outbox depth | `SELECT count(*) FROM tms1034.sendung_cdc_outbox` | > 10,000 rows |
| Oldest unprocessed | `SELECT age(min(source_timestamp)) FROM tms1034.sendung_cdc_outbox` | > 5 minutes |
| GCS write rate | GCS bucket metrics | 0 files in 5 minutes |
| Cloud Run health | Cloud Run health check | Instance not running |

---

## Option B: pg_notify Only (Minimal Design)

### Architecture Overview

```
┌────────────────────────────────────────────────────────────────────────────┐
│ AlloyDB (abn1034)                                                          │
│                                                                            │
│  ┌──────────────┐    TRIGGER                                               │
│  │ tms1034      │────────────────── pg_notify('sendung_cdc',              │
│  │ .sendung     │  on INSERT,        '{"op":"INSERT","tix":123}')         │
│  │              │  UPDATE, DELETE                                          │
│  └──────────────┘       │             no outbox table                      │
│                         │                                                  │
└─────────────────────────┼──────────────────────────────────────────────────┘
                          │
              ┌───────────▼──────────────────────────────────┐
              │ Cloud Run: sendung-cdc-writer                │
              │                                              │
              │  1. LISTEN on pg_notify channel               │
              │  2. On notification:                          │
              │     INSERT → query sendung by tix → emit     │
              │     UPDATE → query sendung by tix → emit     │
              │             (new values only, no old image)   │
              │     DELETE → emit with empty/partial payload  │
              │  3. Batch into JSONL, write to GCS            │
              └──────────────────────┬───────────────────────┘
                                     │
                                     ▼
              ┌──────────────────────────────────────────────┐
              │ gs://abn1043-sendung-bucket-1/               │
              │   tms1034_sendung/                           │
              │     {uuid}_pgnotify_{sequence}.jsonl         │
              └──────────────────────────────────────────────┘
```

### Option B Implementation

#### Trigger Function (no outbox)

```sql
CREATE OR REPLACE FUNCTION tms1034.sendung_cdc_notify_fn()
RETURNS TRIGGER AS $$
DECLARE
    v_payload TEXT;
    v_tix     NUMERIC;
BEGIN
    v_tix := COALESCE(NEW.sendung_tix, OLD.sendung_tix);

    BEGIN
        IF TG_OP = 'DELETE' THEN
            -- Row will be gone — embed full row via to_jsonb(OLD)
            -- 197 columns serialized as JSON may exceed pg_notify's 8000-byte limit.
            -- If it does, the EXCEPTION handler catches it and the DELETE event is lost.
            v_payload := json_build_object(
                'op', 'DELETE',
                'tix', v_tix,
                'row', to_jsonb(OLD)
            )::TEXT;
        ELSE
            -- INSERT/UPDATE: writer can query the live row by sendung_tix
            v_payload := json_build_object('op', TG_OP, 'tix', v_tix)::TEXT;
        END IF;

        PERFORM pg_notify('sendung_cdc', v_payload);

    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'sendung_cdc_notify failed for sendung_tix=%: % [%]',
            v_tix, SQLERRM, SQLSTATE;
    END;

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;
```

> **8000-byte limit — verified safe on abn1034:** `to_jsonb(OLD)` serializes all 197 columns generically — no hand-written column list, no coupling to `ShipmentData`. Measured across 100k rows on abn1034 (2026-06-12): **min 3,782 bytes, avg 4,266 bytes, max 4,636 bytes**. With the `{"op":"DELETE","tix":...,"row":...}` wrapper (~40 bytes), the worst case is ~4,700 bytes — well within pg_notify's 8,000-byte limit with ~3,300 bytes of headroom. The exception handler remains as a safety net in case future schema changes or data patterns push rows past the limit.

#### Limitations Accepted in Option B

1. **No durability:** If Cloud Run is down, notifications are silently lost. No outbox to catch up from.
2. **No UPDATE old image:** Pub/Sub events for UPDATEs will have `OldRecord = null`. The Cloud Function currently handles a plain `"UPDATE"` change_type (falls through to `result.NewRecord = file` at line 97 of `BucketDataStreamFileContentProcessor.cs`), so this works but downstream consumers lose the ability to diff old vs. new.
3. **DELETE payload size:** `to_jsonb(OLD)` measured at max 4,636 bytes on abn1034 (2026-06-12), well within the 8,000-byte limit. Exception handler remains as safety net for future schema growth.
4. **No monitoring visibility:** There's no table to query for backlog depth or processing lag.

---

## Migration Strategy

### Phase 1: Deploy in Shadow Mode
1. Create the outbox table and trigger on abn1034
2. Deploy the Cloud Run writer, writing to a **separate test bucket**
3. Compare output with Datastream's bucket for correctness
4. Validate that the Cloud Function can process pg_notify-generated files

### Phase 2: Cutover
1. Pause Datastream stream
2. Point Cloud Run writer to production bucket `gs://abn1043-sendung-bucket-1`
3. Verify Cloud Functions process events correctly
4. Drop the replication slot `sendung_slot_abn1034` to release WAL retention

### Phase 3: Cleanup
1. Drop the Datastream stream
2. Drop the publication `sendung_pub`
3. Remove Datastream connection profiles

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Trigger slows down sendung writes | Low | Medium | Benchmark before deploying; outbox insert is a single cheap write |
| Cloud Run writer crashes | Medium | Low | Outbox persists data; restart picks up where it left off; poll fallback |
| pg_notify channel saturated | Low | None | pg_notify is only a signal; outbox is the real queue |
| Outbox table grows unbounded | Low | Medium | Monitor + alert on row count; auto-cleanup already built into writer |
| JSONL format mismatch | Low | High | Shadow-mode comparison in Phase 1 catches any differences |
| `to_jsonb()` column name differences | Very Low | High | PostgreSQL column names = Datastream payload keys; verified against ShipmentData DTO |

---

## Open Questions

1. **AlloyDB permissions:** Can we create triggers and tables on the abn1034 instance, or does this need DBA approval?
2. **Cloud Run deployment:** Which GCP project should host the writer service? Same as Datastream (`prj-cal-w-wl5-t-6c00-53ad`) or a shared services project?
3. **Replica Identity:** Is `sendung` already set to `REPLICA IDENTITY FULL`? The trigger uses `OLD` record for UPDATE/DELETE, which requires either a primary key (we have `sendung_tix`) or FULL replica identity. Since the trigger accesses `OLD` directly (not via WAL decoding), this is **not** a concern — `OLD` is always available in `AFTER` triggers.
4. **Multi-environment rollout:** Should this pattern be extended to other environments (UAT, DEV, PROD) or is abn1034 the pilot?

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
