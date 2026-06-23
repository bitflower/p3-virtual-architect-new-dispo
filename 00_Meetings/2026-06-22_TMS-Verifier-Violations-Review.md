# TMS Verifier — Violation Review with Developer

**Date:** 2026-06-22
**Purpose:** Verify whether remaining TMS Verifier violations are real issues or false positives
**Context:** Verifier runs against two database instances, both at L6 (all checks)

| Instance | Provider | Host | Schema | User |
|---|---|---|---|---|
| ABN1034 | PostgreSQL (AlloyDB) | 10.100.47.236:5432 | tms1034 | tms1034 |
| ABN1060 | Oracle | 10.32.119.85:1521 (d60.tmsabn) | TMS1060 | TMSBR1060 |

---

## Background

The verifier's `expectedArgs` are derived from the TMS Bridge C# source code (counting `AddInput` + `AddOutput` + `AddPlsqlBooleanOutput` calls per routine). Signature matching is overload-aware — both PostgreSQL and Oracle support routine overloading, and the verifier checks whether any overload matches the expected count.

Full reports:
- [ABN1034 — PostgreSQL L6](https://dev.azure.com/p3ds/Nagel-CAL%20Disposition/_git/Disposition-Rollout-Tools?path=/reports/2026-06-22_17-55-48_abn1034-postgresql-l6.md&version=GBfeature/prd-003-column-registry-sync&_a=preview)
- [ABN1060 — Oracle L6](https://dev.azure.com/p3ds/Nagel-CAL%20Disposition/_git/Disposition-Rollout-Tools?path=/reports/2026-06-22_17-58-01_abn1060-oracle-l6.md&version=GBfeature/prd-003-column-registry-sync&_a=preview)

---

## Violations to Discuss

### 1. `legtype` CustomType — does not exist on abn1034 (L1)

```json
{
  "kind": "CustomType",
  "schema": "pdis_transportorder",
  "name": "legtype",
  "permission": "USAGE",
  "postgresqlOnly": true,
  "expectedValues": ["VL", "HL", "NL"]
}
```

Marked `postgresqlOnly: true` in the registry but NOT FOUND on the PostgreSQL database. Causes L1 (existence) + L4 (permission denied) failures.

**Question:** Was this enum dropped, never created on abn1034, or does it live in a different schema?

### 2. `geterrormessage` — Signature mismatch on Oracle only (L3)

| | Expected Args | Actual Args |
|---|:-:|:-:|
| Oracle | 0 | 2 |
| PostgreSQL | 0 | ✅ match |

The TMS Bridge code calls `GetErrorMessage` without passing any named parameters (`expectedArgs=0`). Oracle reports 2 arguments for this function.

**Question:** Does `GetErrorMessage` have default-valued parameters on Oracle that the TMS Bridge doesn't explicitly pass?

### 3. `v_dis_tp_client_comm` — 2 missing columns on Oracle (L5)

Missing: `loadinglocationgloballocationnumber` (36 chars), `shippingunitsquantitypalletplacesquantity` (41 chars)

Oracle error: `ORA-00972: Bezeichner ist zu lang` — Oracle's 30-character identifier limit.

PostgreSQL has all 88 columns (no limit issue).

**Question:** Is there an Oracle workaround (aliases, shortened names)? Or are these columns simply not available on Oracle?

> **Note:** Additional items not discussed in this meeting: `startentladung` (L3 Oracle), `abschlnve` (L3 both), `scanbarcode` (L2 Oracle).

---

## Not New Dispo relevant

### `list2dbtt` — Type mismatch on both databases (L2)

| | Expected | Actual |
|---|---|---|
| Oracle | TableFunction | Function |
| PostgreSQL | TableFunction | Function |

**Question:** Should the registry entry be changed to `Function`, or is the DB object supposed to be a TableFunction?

---

## Summary Table

| Check | PostgreSQL (abn1034) | Oracle (abn1060) |
|---|:-:|:-:|
| Existence (L1) | 77 / **1 failed** | 78 / 0 |
| Type (L2) | 76 / **1 failed** | 76 / **2 failed** |
| Signature (L3) | 43 / **1 failed** | 41 / **3 failed** |
| Permissions (L4) | 77 / **1 failed** | 78 / 0 |
| Columns (L5) | 625 / 0 | 623 / **2 missing** |

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
