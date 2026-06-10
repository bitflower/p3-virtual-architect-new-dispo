SELECT
      slot_name,
      slot_type,
      active,
      pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS slot_size,
      pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) AS slot_size_bytes,
      restart_lsn,
      confirmed_flush_lsn
  FROM pg_replication_slots
  ORDER BY pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) DESC;