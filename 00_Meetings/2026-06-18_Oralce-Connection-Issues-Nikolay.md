## Nikolay

Alle we are trying to connect the tms bridge to uat1060 and we are getting this error:
 
"Oracle.ManagedDataAccess.Client.OracleException (0x80004005): ORA-50201: Oracle Communication: Failed to connect to server or failed to parse connect string
---> OracleInternal.Network.NetworkException (0x80004005): ORA-50201: Oracle Communication: Failed to connect to server or failed to parse connect string
---> OracleInternal.Network.NetworkException (0x80004005): ORA-12514: Cannot connect to database. Service CTMSA_DG1.TMS is not registered with the listener at host dzvseqmtst.tms/10.32.0.71 port 1521. (CONNECTION_ID=cK7AQ4U/70Sfh2/s74tEHw==)
[Database - ORA-12514 - Cannot connect to database. Service service_name is not registered with the l…](https://docs.oracle.com/error-help/db/ora-12514/)

## Thomas Paulus

Please use dzvseqmtst.tms as Servuce Name. This should work better.