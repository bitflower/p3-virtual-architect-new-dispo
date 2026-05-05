# PostGres Timezone Initialization

**Date:** 2026-05-05
**Status:** Exploration

---

## Original User Input

> In the TMS Database there is supposed to be a timezone "init" process or so on boot

---

## Summary

The TMS Database sets the timezone at database creation time using `ALTER DATABASE ... SET TIMEZONE TO :'db_time_zone'`. This is not a per-boot process but a one-time configuration persisted in PostgreSQL's `pg_database` catalog. Every new session automatically inherits the database-level timezone setting. All TMS databases are configured to **`Europe/Berlin`**.

## Analysis

### How PostgreSQL Database-Level Timezone Works

When `ALTER DATABASE <name> SET TIMEZONE TO '<tz>'` is executed, PostgreSQL stores this setting in the `pg_database` system catalog. On every new connection to that database, PostgreSQL applies this setting as the session default — no boot-time script or startup hook is needed.

This means:
- The setting survives database restarts
- Every new session gets `Europe/Berlin` as its timezone
- Applications connecting to the database do not need to issue `SET TIMEZONE` themselves (unless they want to override)

### Databases and Their Timezone Configuration

| Database | SQL File | Timezone Source |
|---|---|---|
| Main TMS DB | `all_create_database.sql` | Parameterized via `:db_time_zone` |
| Cron DB | `create_cron_database.sql` | Parameterized via `:db_time_zone` |
| File Transfer DB | `create_file_database.sql` | Parameterized via `:db_time_zone` |
| Striim Ops DB | `create_striimops_database.sql` | **Hardcoded** `'Europe/Berlin'` |

### Parameter Flow

```
YAML config (per environment)
  → DB_TIME_ZONE: "Europe/Berlin"
    → Shell script (-v db_time_zone="${DB_TIME_ZONE}")
      → SQL: ALTER DATABASE :db_name SET TIMEZONE TO :'db_time_zone';
```

## Source Code Evidence

### Database Creation SQL

**`src/sql/scripts/database/all_create_database.sql`** (Lines 33-34):
```sql
ALTER DATABASE :db_name SET TIMEZONE TO :'db_time_zone';
```

**`src/sql/scripts/database/create_cron_database.sql`** (Lines 28-29):
```sql
ALTER DATABASE :db_cron_name SET TIMEZONE TO :'db_time_zone';
```

**`src/sql/scripts/database/create_file_database.sql`** (Lines 34-35):
```sql
ALTER DATABASE :db_file_name SET TIMEZONE TO :'db_time_zone';
```

**`src/sql/scripts/database/create_striimops_database.sql`** (Lines 27-28):
```sql
ALTER DATABASE striim_ops SET TIMEZONE TO 'Europe/Berlin';
```

### Shell Scripts Passing the Parameter

- **`tms-db-execute-scripts.sh`** (Line 114): `-v db_time_zone="${DB_TIME_ZONE}"`
- **`cron-db-execute-scripts.sh`** (Line 47): same pattern
- **`file-db-execute-scripts.sh`** (Line 48): same pattern

### Environment Config Example

**`src/sql/scripts/config/prod/wl2-adb-p-eu-tms01-clst-tms1034.yaml`** (Line 17):
```yaml
DB_TIME_ZONE: "Europe/Berlin"
```

## Findings

1. **One-time setup, not per-boot**: The timezone is set via `ALTER DATABASE` at creation time and persisted in PostgreSQL's catalog. No boot-time initialization is needed.
2. **All databases use `Europe/Berlin`**: Both parameterized and hardcoded values point to the same timezone.
3. **Striim Ops is the outlier**: It hardcodes `'Europe/Berlin'` directly in SQL rather than using the `db_time_zone` parameter. This is a minor inconsistency but has no practical impact as long as the intended timezone remains `Europe/Berlin`.
4. **Session-level behavior**: Any application connecting to these databases will automatically operate in `Europe/Berlin` unless it explicitly overrides with `SET TIMEZONE`.

## Questions/Open Items

- Does the TMS Bridge or New Dispo Backend override the session timezone on connection? If so, the database-level default becomes irrelevant for those applications.
- Should the Striim Ops hardcoded timezone be parameterized for consistency?
- Are there any use cases where a different timezone per environment would be needed (e.g., for international rollout)?

## Related Files

- `Code/tms-alloydb-schema/src/sql/scripts/database/all_create_database.sql`
- `Code/tms-alloydb-schema/src/sql/scripts/database/create_cron_database.sql`
- `Code/tms-alloydb-schema/src/sql/scripts/database/create_file_database.sql`
- `Code/tms-alloydb-schema/src/sql/scripts/database/create_striimops_database.sql`
- `Code/tms-alloydb-schema/src/sql/scripts/tms-db-execute-scripts.sh`
- `Code/tms-alloydb-schema/src/sql/scripts/config/prod/wl2-adb-p-eu-tms01-clst-tms1034.yaml`
- `Code/tms-alloydb-schema/.github/workflows/manual_db_schema_create.yml`
