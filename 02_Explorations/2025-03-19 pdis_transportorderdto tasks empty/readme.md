# 2025-03-19 Analysis of PDIS_TRANSPORTORDERDTO returning empty `Tasks`

## Environment

Database: Pretzel PROD
Host/adress: 10.100.64.14
Port: 5432
Database name: TMS1034
Postgres-PG Adminuser: tmsbr1034

## Steps to reproduce

1. Run `01_diff-records-sendung-sen_ts.sql`
2. Pick a `sendung_tix` from the results
3. Use the `sendung_tix` to run query `02_pdis_transportorderdto-empty-tasks.sql`
4. Check the resulting JSON `01_diff-records-sendung-sen_ts.sql`

## Result

The `Tasks` are filled even though the records is not present in `SEN_TS`.