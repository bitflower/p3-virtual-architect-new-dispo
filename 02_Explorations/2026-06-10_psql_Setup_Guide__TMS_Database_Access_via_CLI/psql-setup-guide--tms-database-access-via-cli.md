# psql Setup Guide — TMS Database Access via CLI

**Date:** 2026-06-10
**Status:** Reference

---

## Summary

How to access TMS PostgreSQL/AlloyDB databases from the command line using `psql`, with secure credential handling via `~/.pgpass`.

## Prerequisites

- PostgreSQL client installed via Homebrew: `brew install libpq` or `brew install postgresql`
- Verify: `psql --version`

## Credential Setup (`.pgpass`)

psql reads credentials from `~/.pgpass` so passwords never appear in commands or shell history.

**Format** — one line per database:

```
hostname:port:database:username:password
```

**Example:**

```
10.100.47.236:5432:abn1034:tms1034:YourPasswordHere
```

**Permissions** — psql ignores the file unless it's owner-only readable:

```bash
chmod 600 ~/.pgpass
```

## Connecting

```bash
psql -h 10.100.47.236 -p 5432 -d abn1034 -U tms1034
```

With `.pgpass` in place, no password prompt appears.

## Common Commands

| Command                        | Description                          |
| ------------------------------ | ------------------------------------ |
| `\dt`                          | List all tables                      |
| `\dt sendung*`                 | List tables matching a pattern       |
| `\dv`                          | List all views                       |
| `\d sendung`                   | Describe table (columns, types)      |
| `\x`                           | Toggle expanded (vertical) display   |
| `\timing`                      | Toggle query execution time display  |
| `\q`                           | Quit                                 |

## Running Queries from the Shell

Single query (non-interactive):

```bash
psql -h 10.100.47.236 -d abn1034 -U tms1034 -c "SELECT count(*) FROM sendung;"
```

Query from a file:

```bash
psql -h 10.100.47.236 -d abn1034 -U tms1034 -f query.sql
```

CSV output:

```bash
psql -h 10.100.47.236 -d abn1034 -U tms1034 \
  --csv -c "SELECT sendung_n, empf_name1 FROM sendung LIMIT 10;"
```

## Multiple Databases

Add one line per database in `~/.pgpass`:

```
10.100.47.236:5432:abn1034:tms1034:PasswordA
10.100.47.236:5432:uat1034:tms1034:PasswordB
```

Then switch target with `-d`:

```bash
psql -h 10.100.47.236 -d uat1034 -U tms1034
```

## Tips

- Use `\x auto` for automatic vertical display on wide result sets
- Pipe to `less` for scrollable output: `psql ... -c "SELECT ..." | less -S`
- Use `\copy` (client-side) to export query results to CSV files
