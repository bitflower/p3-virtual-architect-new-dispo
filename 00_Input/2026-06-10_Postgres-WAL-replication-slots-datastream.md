# PostgreSQL WAL, Replication Slots & GCP Datastream

Reference document covering how Write-Ahead Logging, logical replication slots, and GCP Datastream interact — including the specific risks when syncing a small subset of tables from a large, active database.

---

## 1. Core Components

### Write-Ahead Logging (WAL)

WAL is PostgreSQL's transaction log. Every insert, update, or delete is first appended to a sequential, append-only WAL file — **not** written directly to the table files on disk.

- A transaction is only "committed" once its WAL record is flushed to disk.
- On crash recovery, PostgreSQL replays committed WAL entries that hadn't reached the main data files yet. This guarantees **durability**.

### Replication Slots

Because the WAL contains a chronological record of every change, it is the natural source for **replication** — sending data to replicas or external consumers like GCP Datastream.

PostgreSQL periodically deletes old WAL files to reclaim disk space. If a consumer goes offline, the WAL files it still needs might be deleted before it reconnects. A **Replication Slot** prevents this:

- It is a marker on the primary that tells PostgreSQL: *"Do not delete any WAL files until the consumer assigned to this slot has confirmed it has read them."*
- For GCP Datastream, PostgreSQL uses a **Logical Replication Slot**. Instead of streaming raw binary WAL, it decodes changes into logical events (e.g., `TABLE users: INSERT id=5, name='Alice'`).

### Publications

A **Publication** defines *which tables* the logical decoding layer should include. When a consumer connects via a replication slot, it specifies which publication to use. The `pgoutput` plugin then filters decoded WAL entries accordingly.

```sql
-- Only replicate changes from one specific table
CREATE PUBLICATION my_pub FOR TABLE target_table_name;
```

> **Important:** The WAL Sender still has to *parse* the entire WAL — the publication only controls which decoded changes get *transmitted*. This distinction is key to understanding the performance risks in section 3.

### WAL Sender Process

A **WAL Sender** is a dedicated PostgreSQL background process that reads the WAL through the replication slot, applies the publication filter, and streams the result to the consumer.

```
                                                       ┌──────────────┐
                                                       │ Publication  │
                                                       │ (table filter│
                                                       │  definition) │
                                                       └──────┬───────┘
                                                              │ filters
                                                              ▼
┌──────────────┐     ┌─────────────────┐     ┌────────────────────────┐          ┌────────────────┐
│ Postgres WAL │────>│Replication Slot │────>│WAL Sender + pgoutput   │──(net)──>│ GCP Datastream │
│ (all tables) │     │ (retention      │     │ (decode all, transmit  │          │                │
│              │     │  marker)        │     │  only published tables)│          │                │
└──────────────┘     └─────────────────┘     └────────────────────────┘          └────────────────┘
        │                                              │
        │         parses 100% of WAL                   │  transmits only
        └──────────────────────────────────────────────┘  matching changes
```

### WAL Sender States

The `pg_stat_replication` view shows what the WAL Sender is doing at any moment:

| State | Meaning |
|---|---|
| `startup` | Consumer just connected. WAL Sender is initializing and authenticating. |
| `catchup` | Consumer was offline; WAL Sender is rapidly replaying accumulated backlog from disk. |
| `streaming` | **Ideal state.** Consumer is caught up. Changes are streamed in near real-time as transactions commit. |
| `backup` | Handling a base backup. |
| `stopping` | Gracefully shutting down the connection. |

---

## 2. Slot & Publication Creation

In enterprise environments, DBAs typically create the replication slot and publication manually for tight control over permissions, naming, and resource allocation. GCP Datastream only needs the **slot name** in its configuration to match the one the DBAs created.

```sql
-- 1. Create a publication for the specific table(s)
CREATE PUBLICATION my_pub FOR TABLE target_table_name;

-- 2. Create a logical replication slot (using pgoutput plugin)
SELECT pg_create_logical_replication_slot('my_slot', 'pgoutput');
```

If the synced table undergoes `UPDATE` or `DELETE` operations, ensure it has a Primary Key or set its replica identity so the WAL contains the "before" image of rows:

```sql
ALTER TABLE target_table_name REPLICA IDENTITY FULL;
```

---

## 3. Risk: The 1-out-of-700 Table Bottleneck

When syncing only a small subset of tables (e.g., 1 out of 700) from a highly active database, a specific architectural risk arises.

### Why Datastream Can Stall

PostgreSQL has **one global WAL** for the entire database. Every change across all 700 tables lands in the same chronological stream. The logical replication slot forces the WAL Sender to process *everything* to find what it needs.

1. **CPU/Memory Bottleneck:** The WAL Sender reads 100% of WAL, decodes each transaction, and discards anything not matching the publication. If the other 699 tables produce gigabytes of writes, the WAL Sender spends most of its time filtering noise.

2. **Datastream Appears Stuck:** From the GCP Console, Datastream may look stalled or making zero progress. In reality, it is waiting for the WAL Sender to parse through millions of irrelevant rows to find a single update for the synced table.

3. **WAL Accumulation (Storage Trap):** If Datastream cannot acknowledge WAL fast enough, the replication slot prevents PostgreSQL from deleting those files. Disk usage grows rapidly, risking a **primary database crash**.

### Monitoring

Replication slot lag (in bytes) is the key metric to watch for early detection of disk-full scenarios:

```sql
SELECT
    slot_name,
    active,
    pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn) AS bytes_lag
FROM pg_replication_slots;
```

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
