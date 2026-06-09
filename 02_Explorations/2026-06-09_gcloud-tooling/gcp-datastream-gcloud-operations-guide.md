# GCP Datastream gcloud Operations Guide

**Date:** 2026-06-09
**Status:** Reference

---

## Original User Input

> Documentation of how to delete, pause, restart and create a Datastream instance using gcloud CLI.
> Sources: AlloyDB and Oracle on-prem. Destination: Cloud Storage.

---

## Summary

Complete reference for managing GCP Datastream streams and connection profiles via `gcloud` CLI. Covers authentication, reading existing configurations, and the full lifecycle for two scenarios:

- **AlloyDB → Cloud Storage** (via VPC peering private connection)
- **Oracle on-prem → Cloud Storage** (via PSC private connection)

All examples use real configurations from project `prj-cal-w-wl5-t-6c00-53ad` in `europe-west3`.

---

## 1. Authentication

Before running any `gcloud datastream` command, you must be authenticated and have the correct project set.

```bash
# Authenticate (opens browser)
gcloud auth login

# Verify active account
gcloud auth list

# Set the target project
gcloud config set project prj-cal-w-wl5-t-6c00-53ad

# Verify
gcloud config get-value project
```

If your token expires mid-session, gcloud returns:

```
ERROR: Reauthentication failed. cannot prompt during non-interactive execution.
```

Re-run `gcloud auth login` to refresh.

---

## 2. Reading Existing Configurations

Before creating new streams or connection profiles, read the existing ones to understand the current setup and reuse them as templates for new instances.

### List What Exists

```bash
# List all streams
gcloud datastream streams list --location=europe-west3

# List all connection profiles
gcloud datastream connection-profiles list --location=europe-west3

# List private connections
gcloud datastream private-connections list --location=europe-west3
```

### Export Configurations as JSON Templates

```bash
# Export a stream config
gcloud datastream streams describe STREAM_ID \
  --location=europe-west3 --format=json > stream-template.json

# Export a connection profile config
gcloud datastream connection-profiles describe PROFILE_ID \
  --location=europe-west3 --format=json > profile-template.json
```

### Current Inventory (Test Environment)

**Streams:**

| Stream ID | Source | State |
|-----------|--------|-------|
| `orauat-1060-bucket` | Oracle TMS1060.SENDUNG | RUNNING |
| `new-dispo-cdc-datastream-sendung-abn1034` | AlloyDB tms1034.sendung | RUNNING |
| `new-dispo-cdc-datastream-sendung-abn2820` | AlloyDB tms2820.sendung | NOT_STARTED |

**Connection Profiles:**

| Profile ID | Type | Target |
|------------|------|--------|
| `ora-datastream-1060uat` | Oracle | 10.32.0.71:1521 (TMSA) |
| `new-dispo-cdc-postgres-connection-abn1034-1` | PostgreSQL | 10.100.47.236:5432 (abn1034) |
| `new-dispo-cdc-postgres-connection-abn2820` | PostgreSQL | AlloyDB abn2820 |
| `new-dispo-cdc-cloud-storage-connection-abn1034-1` | GCS | abn1043-sendung-bucket-1 |
| `new-dispo-cdc-cloud-storage-connection-uat2820` | GCS | AlloyDB abn2820 bucket |
| `datastream-to-cloud-storage` | GCS | tms-alloydb-datastream-bucket-wl5-t-t |

**Private Connections:**

| Connection ID | Type | Details |
|---------------|------|---------|
| `psc-datastream-t-wl5` | PSC | Network attachment: `na-datastream-t-wl5` (Oracle) |
| `datastream-connectivity-wl5-t-t` | VPC Peering | Subnet: `10.100.53.0/29` (AlloyDB) |

Use `describe` on any of these to get the full JSON config, then adapt it for a new instance.

---

## 3. Connection Profile Operations

### 3a. Create AlloyDB Source Profile

AlloyDB uses `--type=postgresql` (PostgreSQL wire protocol). Connectivity uses VPC peering private connection.

```bash
gcloud datastream connection-profiles create NEW_PROFILE_ID \
  --location=europe-west3 \
  --type=postgresql \
  --display-name="DISPLAY_NAME" \
  --postgresql-hostname=ALLOYDB_IP \
  --postgresql-port=5432 \
  --postgresql-username=USERNAME \
  --postgresql-password=PASSWORD \
  --postgresql-database=DATABASE_NAME \
  --private-connection=datastream-connectivity-wl5-t-t
```

**Real example** (from `new-dispo-cdc-postgres-connection-abn1034-1`):

```bash
gcloud datastream connection-profiles create new-dispo-cdc-postgres-connection-abn1034-1 \
  --location=europe-west3 \
  --type=postgresql \
  --display-name="new-dispo-cdc-postgres-connection-abn1034-1" \
  --postgresql-hostname=10.100.47.236 \
  --postgresql-port=5432 \
  --postgresql-username=tmsbr1034 \
  --postgresql-password=PASSWORD \
  --postgresql-database=abn1034 \
  --private-connection=datastream-connectivity-wl5-t-t
```

| Flag | Description |
|------|-------------|
| `--type=postgresql` | AlloyDB uses PostgreSQL protocol |
| `--postgresql-hostname` | AlloyDB instance IP (reachable via private connection) |
| `--postgresql-port` | Default `5432` |
| `--postgresql-database` | Database name (e.g. `abn1034`) |
| `--postgresql-username` | Replication user (e.g. `tmsbr1034`) |
| `--postgresql-password` | Or use `--postgresql-secret-manager-stored-password` |
| `--private-connection` | VPC peering connection (`datastream-connectivity-wl5-t-t`) |

### 3b. Create Oracle On-Prem Source Profile

Oracle uses `--type=oracle`. Connectivity uses PSC (Private Service Connect).

```bash
gcloud datastream connection-profiles create NEW_PROFILE_ID \
  --location=europe-west3 \
  --type=oracle \
  --display-name="DISPLAY_NAME" \
  --oracle-hostname=ORACLE_IP \
  --oracle-port=1521 \
  --oracle-username=USERNAME \
  --oracle-password=PASSWORD \
  --oracle-database-service=SERVICE_NAME \
  --private-connection=psc-datastream-t-wl5
```

**Real example** (from `ora-datastream-1060uat`):

```bash
gcloud datastream connection-profiles create ora-datastream-1060uat \
  --location=europe-west3 \
  --type=oracle \
  --display-name="ORA-datastream-1060UAT" \
  --oracle-hostname=10.32.0.71 \
  --oracle-port=1521 \
  --oracle-username=C##P3_LOGMINER \
  --oracle-password=PASSWORD \
  --oracle-database-service=TMSA \
  --private-connection=psc-datastream-t-wl5
```

| Flag | Description |
|------|-------------|
| `--type=oracle` | Oracle source |
| `--oracle-hostname` | Oracle host IP (e.g. `10.32.0.71`) |
| `--oracle-port` | Default `1521` |
| `--oracle-database-service` | Oracle service name (e.g. `TMSA`) |
| `--oracle-username` | Datastream user (e.g. `C##P3_LOGMINER`) |
| `--private-connection` | PSC connection (`psc-datastream-t-wl5`) |

### 3c. Create Cloud Storage Destination Profile

```bash
gcloud datastream connection-profiles create NEW_PROFILE_ID \
  --location=europe-west3 \
  --type=google-cloud-storage \
  --display-name="DISPLAY_NAME" \
  --bucket=BUCKET_NAME \
  --root-path=/
```

**Real example** (from `new-dispo-cdc-cloud-storage-connection-abn1034-1`):

```bash
gcloud datastream connection-profiles create new-dispo-cdc-cloud-storage-connection-abn1034-1 \
  --location=europe-west3 \
  --type=google-cloud-storage \
  --display-name="new-dispo-cdc-cloud-storage-connection-abn1034-1" \
  --bucket=abn1043-sendung-bucket-1 \
  --root-path=/
```

| Flag | Description |
|------|-------------|
| `--type=google-cloud-storage` | GCS destination |
| `--bucket` | Target GCS bucket name |
| `--root-path` | Path prefix (must start with `/`) |

No credentials needed -- Datastream uses the project's default service account.

### 3d. List Connection Profiles

```bash
gcloud datastream connection-profiles list --location=europe-west3
```

### 3e. Delete a Connection Profile

```bash
gcloud datastream connection-profiles delete PROFILE_ID --location=europe-west3
```

A connection profile **cannot** be deleted while referenced by an active stream.

---

## 4. Stream Operations

### 4a. Create AlloyDB → Cloud Storage Stream

```bash
gcloud datastream streams create STREAM_ID \
  --location=europe-west3 \
  --display-name="DISPLAY_NAME" \
  --source=ALLOYDB_PROFILE_ID \
  --destination=GCS_PROFILE_ID \
  --postgresql-source-config=alloydb-source-config.json \
  --gcs-destination-config=gcs-dest-config.json \
  --backfill-none
```

**alloydb-source-config.json** (based on `new-dispo-cdc-datastream-sendung-abn1034`):

```json
{
  "replicationSlot": "sendung_slot_abn1034",
  "publication": "sendung_pub",
  "includeObjects": {
    "postgresqlSchemas": [
      {
        "schema": "tms1034",
        "postgresqlTables": [
          { "table": "sendung" }
        ]
      }
    ]
  }
}
```

**gcs-dest-config.json** (based on existing streams):

```json
{
  "fileRotationInterval": "60s",
  "fileRotationMb": 50,
  "jsonFileFormat": {
    "compression": "NO_COMPRESSION",
    "schemaFileFormat": "NO_SCHEMA_FILE"
  }
}
```

**Backfill options:**
- `--backfill-none` -- CDC only, no historical data
- `--backfill-all` -- backfill all existing rows, then switch to CDC

### 4b. Create Oracle → Cloud Storage Stream

```bash
gcloud datastream streams create STREAM_ID \
  --location=europe-west3 \
  --display-name="DISPLAY_NAME" \
  --source=ORACLE_PROFILE_ID \
  --destination=GCS_PROFILE_ID \
  --oracle-source-config=oracle-source-config.json \
  --gcs-destination-config=gcs-dest-config.json \
  --backfill-all
```

**oracle-source-config.json** (based on `orauat-1060-bucket`):

```json
{
  "includeObjects": {
    "oracleSchemas": [
      {
        "schema": "TMS1060",
        "oracleTables": [
          { "table": "SENDUNG" }
        ]
      }
    ]
  },
  "maxConcurrentCdcTasks": 5,
  "maxConcurrentBackfillTasks": 16,
  "dropLargeObjects": {}
}
```

**gcs-dest-config.json** (Oracle variant with GZIP compression):

```json
{
  "path": "/UATDataStream",
  "fileRotationInterval": "60s",
  "fileRotationMb": 50,
  "jsonFileFormat": {
    "compression": "GZIP",
    "schemaFileFormat": "NO_SCHEMA_FILE"
  }
}
```

### 4c. GCS Destination Config Options

| Field | Description |
|-------|-------------|
| `path` | Subdirectory under the bucket's root-path |
| `fileRotationMb` | Rotate file after this size in MB (e.g. `50`) |
| `fileRotationInterval` | Rotate file after this duration (e.g. `"60s"`) |
| `jsonFileFormat.compression` | `"NO_COMPRESSION"` or `"GZIP"` |
| `jsonFileFormat.schemaFileFormat` | `"NO_SCHEMA_FILE"` or `"AVRO_SCHEMA_FILE"` |
| `avroFileFormat` | Use `{}` for binary Avro instead of JSON |

**GCS output path structure (automatic):**

```
gs://BUCKET/ROOT_PATH/PATH/SCHEMA.TABLE/yyyy/mm/dd/hh/mm/filename
```

### 4d. Pause a Stream

```bash
gcloud datastream streams update STREAM_ID \
  --location=europe-west3 \
  --state=PAUSED \
  --update-mask=state
```

**State transition:** `RUNNING` -> `DRAINING` -> `PAUSED`

**Important:**
- Some in-flight data may still arrive at the destination after pausing
- If paused longer than the source database's WAL/redo log retention period, resuming may fail -- you would need to delete and recreate the stream

### 4e. Resume a Stream

```bash
gcloud datastream streams update STREAM_ID \
  --location=europe-west3 \
  --state=RUNNING \
  --update-mask=state
```

**State transition:** `PAUSED` -> `RUNNING`

### 4f. Delete a Stream

```bash
gcloud datastream streams delete STREAM_ID --location=europe-west3
```

Add `--quiet` to skip confirmation prompt.

Deleting stops replication immediately. Cleanup on the source database is **not** automatic:

**AlloyDB / PostgreSQL:**
```sql
SELECT pg_drop_replication_slot('sendung_slot_abn1034');
DROP PUBLICATION sendung_pub;
```

**Oracle:**
The LogMiner session is cleaned up by Datastream, but verify no orphaned redo log groups remain.

### 4g. Describe a Stream

```bash
gcloud datastream streams describe STREAM_ID \
  --location=europe-west3 \
  --format=json
```

---

## 5. Stream State Machine

```
                 create
                   │
                   v
    ┌─────────────────────────────┐
    │     NOT_STARTED             │
    └─────────┬───────────────────┘
              │ start (state=RUNNING)
              v
    ┌─────────────────────────────┐
    │     RUNNING                 │◄──────────┐
    └─────────┬───────────────────┘           │
              │ pause (state=PAUSED)          │ resume (state=RUNNING)
              v                               │
    ┌─────────────────────────────┐           │
    │     DRAINING                │           │
    └─────────┬───────────────────┘           │
              │                               │
              v                               │
    ┌─────────────────────────────┐           │
    │     PAUSED                  │───────────┘
    └─────────────────────────────┘

    Any state ──── delete ────► DELETED
```

---

## 6. Common Flags

All `gcloud datastream` commands support:

| Flag | Description |
|------|-------------|
| `--project=PROJECT_ID` | Target GCP project |
| `--location=LOCATION` | Region (always `europe-west3` for this project) |
| `--format=FORMAT` | Output format: `json`, `yaml`, `text` |
| `--quiet` | Suppress confirmation prompts |
| `--verbosity=LEVEL` | `debug`, `info`, `warning`, `error` |

---

## 7. Prerequisites

### AlloyDB Source

- Logical replication enabled: `wal_level = logical`
- A replication slot and publication must exist for the Datastream user
- User needs `REPLICATION` privilege
- Private connection via VPC peering must exist (`datastream-connectivity-wl5-t-t`)

```sql
CREATE USER tmsbr1034 WITH REPLICATION LOGIN PASSWORD 'password';
GRANT USAGE ON SCHEMA tms1034 TO tmsbr1034;
GRANT SELECT ON ALL TABLES IN SCHEMA tms1034 TO tmsbr1034;
CREATE PUBLICATION sendung_pub FOR TABLE tms1034.sendung;
SELECT pg_create_logical_replication_slot('sendung_slot_abn1034', 'pgoutput');
```

### Oracle On-Prem Source

- Oracle 11g+ with LogMiner
- Supplemental logging enabled
- Datastream user needs LogMiner privileges (e.g. `C##P3_LOGMINER`)
- Private connection via PSC must exist (`psc-datastream-t-wl5`)

### Cloud Storage Destination

- Target bucket must exist
- Datastream service account needs `Storage Object Admin` on the bucket

### General

- All resources (connection profiles, streams, private connections) must be in the **same location** (`europe-west3`)

---

## 8. Quick Reference: Full Lifecycle

### AlloyDB → Cloud Storage

```bash
# 0. Authenticate
gcloud auth login
gcloud config set project prj-cal-w-wl5-t-6c00-53ad

# 1. Read existing configs as templates
gcloud datastream connection-profiles list --location=europe-west3
gcloud datastream streams describe new-dispo-cdc-datastream-sendung-abn1034 \
  --location=europe-west3 --format=json

# 2. Create connection profiles
gcloud datastream connection-profiles create new-dispo-cdc-postgres-connection-ABNXXXX \
  --location=europe-west3 --type=postgresql \
  --display-name="new-dispo-cdc-postgres-connection-ABNXXXX" \
  --postgresql-hostname=ALLOYDB_IP --postgresql-port=5432 \
  --postgresql-database=abnXXXX \
  --postgresql-username=tmsbrXXXX --postgresql-password=PASSWORD \
  --private-connection=datastream-connectivity-wl5-t-t

gcloud datastream connection-profiles create new-dispo-cdc-cloud-storage-connection-abnXXXX \
  --location=europe-west3 --type=google-cloud-storage \
  --display-name="new-dispo-cdc-cloud-storage-connection-abnXXXX" \
  --bucket=abnXXXX-sendung-bucket --root-path=/

# 3. Create stream
gcloud datastream streams create new-dispo-cdc-datastream-sendung-abnXXXX \
  --location=europe-west3 \
  --display-name="new-dispo-cdc-datastream-sendung-abnXXXX" \
  --source=new-dispo-cdc-postgres-connection-ABNXXXX \
  --destination=new-dispo-cdc-cloud-storage-connection-abnXXXX \
  --postgresql-source-config=alloydb-source-config.json \
  --gcs-destination-config=gcs-dest-config.json \
  --backfill-none

# 4. Pause
gcloud datastream streams update new-dispo-cdc-datastream-sendung-abnXXXX \
  --location=europe-west3 --state=PAUSED --update-mask=state

# 5. Resume
gcloud datastream streams update new-dispo-cdc-datastream-sendung-abnXXXX \
  --location=europe-west3 --state=RUNNING --update-mask=state

# 6. Delete stream
gcloud datastream streams delete new-dispo-cdc-datastream-sendung-abnXXXX \
  --location=europe-west3

# 7. Delete connection profiles
gcloud datastream connection-profiles delete new-dispo-cdc-postgres-connection-ABNXXXX \
  --location=europe-west3
gcloud datastream connection-profiles delete new-dispo-cdc-cloud-storage-connection-abnXXXX \
  --location=europe-west3
```

### Oracle On-Prem → Cloud Storage

```bash
# 0. Authenticate
gcloud auth login
gcloud config set project prj-cal-w-wl5-t-6c00-53ad

# 1. Read existing configs as templates
gcloud datastream connection-profiles describe ora-datastream-1060uat \
  --location=europe-west3 --format=json
gcloud datastream streams describe orauat-1060-bucket \
  --location=europe-west3 --format=json

# 2. Create connection profiles
gcloud datastream connection-profiles create ora-datastream-XXXX \
  --location=europe-west3 --type=oracle \
  --display-name="ORA-datastream-XXXX" \
  --oracle-hostname=ORACLE_IP --oracle-port=1521 \
  --oracle-username=C##P3_LOGMINER --oracle-password=PASSWORD \
  --oracle-database-service=TMSA \
  --private-connection=psc-datastream-t-wl5

gcloud datastream connection-profiles create gcs-oracle-XXXX \
  --location=europe-west3 --type=google-cloud-storage \
  --display-name="GCS Oracle XXXX" \
  --bucket=oracle-XXXX-bucket --root-path=/

# 3. Create stream
gcloud datastream streams create oraXXXX-bucket \
  --location=europe-west3 \
  --display-name="ORAXXXX-Bucket" \
  --source=ora-datastream-XXXX --destination=gcs-oracle-XXXX \
  --oracle-source-config=oracle-source-config.json \
  --gcs-destination-config=gcs-dest-config.json \
  --backfill-all

# 4. Pause
gcloud datastream streams update oraXXXX-bucket \
  --location=europe-west3 --state=PAUSED --update-mask=state

# 5. Resume
gcloud datastream streams update oraXXXX-bucket \
  --location=europe-west3 --state=RUNNING --update-mask=state

# 6. Delete stream
gcloud datastream streams delete oraXXXX-bucket --location=europe-west3

# 7. Delete connection profiles
gcloud datastream connection-profiles delete ora-datastream-XXXX --location=europe-west3
gcloud datastream connection-profiles delete gcs-oracle-XXXX --location=europe-west3
```

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
