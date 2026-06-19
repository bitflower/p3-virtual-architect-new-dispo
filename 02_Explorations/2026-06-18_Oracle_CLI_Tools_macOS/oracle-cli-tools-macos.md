# Oracle CLI Tools on macOS

**Date:** 2026-06-18
**Status:** Exploration

---

## Context

We use `psql` with `.pgpass` for AlloyDB/PostgreSQL access. This exploration documents the equivalent tooling for Oracle databases on macOS.

## Oracle CLI Options

### SQLcl (recommended)

Oracle's modern Java-based CLI — actively maintained, tab completion, inline editing, JavaScript scripting. Closest to the `psql` experience.

- **Documentation:** https://docs.oracle.com/en/database/oracle/sql-developer-command-line/
- **Download:** https://www.oracle.com/database/sqldeveloper/technologies/sqlcl/

**Install:**

```bash
brew install --cask sqlcl
```

Requires a JDK.

**After install — getting started:**

```bash
# 1. Verify installation
sql -version

# 2. Quick test connection (with inline password)
sql user/password@hostname:1521/service_name
```

**Note:** `mkstore` (needed for wallet setup) ships with Oracle Instant Client, not SQLcl. Install it too:

```bash
brew install instantclient-basic
```

Alternatively, for **Oracle Cloud (Autonomous DB)**, download the wallet zip from the console and use SQLcl's built-in wallet support:

```sql
SQL> set cloudconfig /path/to/wallet.zip
SQL> connect user@my_db_alias
```

For **on-prem Oracle** (e.g. via VPN), use the `tnsnames.ora` + `sqlnet.ora` route described in the On-Prem Setup section below.

### SQL*Plus (legacy)

The classic Oracle CLI. Lightweight, but less ergonomic.

**Install:**

```bash
brew install instantclient-sqlplus
```

Requires the base Oracle Instant Client package.

Use SQL*Plus only if you need exact compatibility with existing `.sql` scripts that rely on SQL*Plus-specific commands.

## On-Prem Setup (VPN)

SQLcl connects via TCP to the Oracle listener (default port 1521). Works over VPN as long as the route to the DB host is open — same as `psql` over VPN to AlloyDB.

### 1. Create config directory

```bash
mkdir -p ~/oracle_config
```

### 2. Define connection aliases in `tnsnames.ora`

```
# ~/oracle_config/tnsnames.ora

MY_DB =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = oracle-host.internal)(PORT = 1521))
    (CONNECT_DATA = (SERVICE_NAME = MYSERVICE)))
```

Add one entry per database. Get `HOST`, `PORT`, and `SERVICE_NAME` from your DBA or connection docs.

### 3. Point SQLcl to the config

```bash
# Add to ~/.zshrc
export TNS_ADMIN=~/oracle_config
```

### 4. Connect

```bash
sql user/password@MY_DB
```

Or with wallet (see below):

```bash
sql /@MY_DB
```

### Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `ORA-12170: TNS:Connect timeout` | VPN not connected or host unreachable | Check VPN, `ping oracle-host.internal` |
| `ORA-12154: TNS:could not resolve` | `TNS_ADMIN` not set or alias typo | Verify `echo $TNS_ADMIN`, check `tnsnames.ora` |
| `ORA-12541: TNS:no listener` | Wrong port or listener down | Confirm port with DBA |

## Credential Management: Oracle Wallet

`.pgpass` equivalent for Oracle. Stores credentials in an encrypted wallet file — no plaintext passwords on disk.

### Setup

```bash
# Create wallet directory
mkdir -p ~/oracle_wallet

# Create the wallet and add credentials
mkstore -wrl ~/oracle_wallet -create
mkstore -wrl ~/oracle_wallet -createCredential my_db_alias username password
```

### Configure `sqlnet.ora`

```
WALLET_LOCATION = (SOURCE = (METHOD = FILE) (METHOD_DATA = (DIRECTORY = /Users/<you>/oracle_wallet)))
SQLNET.WALLET_OVERRIDE = TRUE
```

### Usage

Once configured, connect without a password prompt:

```bash
sql /@my_db_alias
```

### Other Credential Options

| Method | Security | Notes |
|---|---|---|
| **Oracle Wallet** | Encrypted on disk | Recommended, closest to `.pgpass` |
| **OS Authentication** | No password needed | Requires server-side config (`CONNECT /`) |
| **`login.sql`** | Plaintext | Runs on SQLcl startup — do NOT store passwords here |

## Comparison: psql vs SQLcl

| Aspect | psql / PostgreSQL | SQLcl / Oracle |
|---|---|---|
| **CLI Tool** | `psql` | `sql` (SQLcl) |
| **Credential File** | `~/.pgpass` | Oracle Wallet (`cwallet.sso`) |
| **Credential Security** | Plaintext, file-permission protected | Encrypted |
| **Install** | `brew install libpq` | `brew install --cask sqlcl` |
| **Startup Script** | `~/.psqlrc` | `login.sql` |
| **Tab Completion** | Built-in | Built-in |
