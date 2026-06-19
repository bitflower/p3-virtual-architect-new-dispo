# Databases

| Engine | Env | Host | Port | Service / DB | User | CLI |
|---|---|---|---|---|---|---|
| AlloyDB | ABN1034 | 10.100.47.236 | 5432 | abn1034 | tms1034 | `psql` |
| AlloyDB | ENT1034 | 10.100.4.16 | 5432 | ent1034 | tms1034 | `psql` |
| Oracle | ABN1060 | 10.32.119.85 | 1521 | d60.tmsabn | TMSBR1060 | `sql` (SQLcl) |
| Oracle | UAT1060 | 10.32.0.71 | 1521 | dzvseqmtst.tms | TMSBR1060 | `sql` (SQLcl) — port blocked, pending DB admin |

**AlloyDB:** `psql` without password parameter (`.pgpass` configured)
**Oracle:** `sql USER@ALIAS` with password prompt (wallet not yet set up). Requires VPN + `TNS_ADMIN=~/oracle_config`.