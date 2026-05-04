# PutSignature — Database State Change Analysis

**Date:** 2026-04-30
**Source:** `Code/tms-alloydb-schema/src/sql/package/pDriverTerminal.sql` (line 1203)

---

## Call Sequence

```
PutSignature_plproxy(sTerminalId, sTransportOrderId, nMeasuringPoint, sType, oSignature)
  │
  ├─ 1. pTA.exec(nTATix, 'TAAUTOABFSIGN')
  │     ├─ a. pTA.LockRec(nTATix)           → UPDATE SENDUNG
  │     ├─ b. pTA.setStatusBits(...)         → UPDATE/INSERT SEN_ZUSTAND
  │     └─ c. pTA.setStatus(TASTATUS_DFV)   → INSERT/UPDATE SEN_TS  (conditional, only if Vk_Art < 40)
  │
  ├─ 2. SenHst.Put(...)                      → INSERT SEN_HST
  │     └─ fires trigger: TRAI_SEN_HST_SIG   → RETURN NULL (no-op for DOCTYPE 'TO_MP4_SIG_DRIVER')
  │
  ├─ 3. SenHst.AddLob(...)
  │     ├─ a. pLob.Put(rLob)                → INSERT LOB
  │     └─ b. SenHst2Lob.Put(rSenHst2Lob)  → INSERT SEN_HST2LOB
  │
  └─ 4. pTA.Clear()                          → session variable reset only, no table writes
```

---

## Table Writes

### 1. SENDUNG — UPDATE (optimistic lock + version bump)

**Via:** `pTA.LockRec(nTATix)` (PTA.sql line 9054)

| Column | Value | Purpose |
|---|---|---|
| `U_VERSION` | incremented via `CAL_UTIL.GETUVERSION()` | Optimistic lock version |
| `U_TIME` | `LOCALTIMESTAMP` | Last update timestamp |
| `OLS_USER` | `PTA.GETUSER()` | Last modifying user |

`WHERE SENDUNG_TIX = nTATix`. Raises exception if row was concurrently modified (row count = 0).

---

### 2. SEN_ZUSTAND — UPSERT (set AUTOABF signed bit)

**Via:** `pTA.setStatusBits(nTATix, 'AUTOABF', 16)` (PTA.sql line 14111)

UPDATE path:

| Column | Value | Purpose |
|---|---|---|
| `STATUS` | `BITOR(STATUS, 16)` | Sets bit for `STATUS_AUTOABFSIGNED` (value 16) |
| `U_VERSION` | incremented via `CAL_UTIL.GETUVERSION()` | Version bump |

`WHERE SEN_TIX = nTATix AND BEREICH_K = 'AUTOABF'`

INSERT path (if no row exists):

| Column | Value |
|---|---|
| `SEN_TIX` | `nTATix` |
| `BEREICH_K` | `'AUTOABF'` |
| `U_VERSION` | `'!'` |
| `STATUS` | `16` |
| `REF_K` | `null` |
| `C_TIME_INV` | `null` |
| `C_TIME` | `null` |
| `EREIGNIS_E` | `null` |
| `PRIORITY` | `null` |

---

### 3. SEN_HST — INSERT (new history event)

**Via:** `SenHst.Put(...)` (SENHST.sql line 2033)

| Column | Value | Purpose |
|---|---|---|
| `SEN_TIX` | `nTATix` (= transport order ID) | Foreign key to SENDUNG |
| `STATUS` | `230` (`Event_Lib.SIG()`) | Signature event status code |
| `C_TIME` | `LOCALTIMESTAMP` | Creation timestamp |
| `EREIGNIS_E` | `LOCALTIMESTAMP` | Event timestamp |
| `C_TIME_INV` | computed inverse of C_TIME via `CAL_Util.GETINVE()` | PK component (for uniqueness) |
| `U_VERSION` | `'!'` | Initial version marker |
| `C_USER` | `'DRIVER'` | Event creator |
| `REF_TIX` | `null` | No reference |
| `REF_K` | `'N'` (`pDriverTerminal.SEN_HST_REF_K()`) | Reference type |
| `QUELL_K` | `'0'` | Source type |
| `T` | `null` | No text |
| `META_T` | `'DocType=TO_MP4_SIG_DRIVER§TerminalId={sTerminalId}'` | Metadata (§ = Uniface ListSep) |
| `MP` | `4` or `7` (from `GetMeasuringPoint`: 7 if Tran_Art = NV, else 4) | Measuring point |
| `MP_SUB` | `0` | Sub measuring point |
| `REL` | from `CAL_Firma.GetRel(null, null)` | Relation |
| `MDE_ID` | `null` | No MDE device |
| `SACHBEARB` | `null` | No Sachbearbeiter |

On PK collision (`C_TIME_INV` duplicate), retries with incremented `C_TIME_INV` via `CAL_Util.INCINVE2()`.

**Trigger `TRAI_SEN_HST_SIG`** (all_trigger_functions.sql line 1496): fires AFTER INSERT on SEN_HST. Checks `STATUS = 230`, reads `DocType` from `META_T`. For `'TO_MP4_SIG_DRIVER'`: explicit `RETURN NULL` (no-op for Driver Terminal signatures).

---

### 4. LOB — INSERT (stores the signature image bytes)

**Via:** `SenHst.AddLob(...)` → `pLob.Put(rLob)` (PLOB.sql line 228)

| Column | Value | Purpose |
|---|---|---|
| `TIX` | new TIX from `CAL_Util.getTix(Firma, Nl)` | Primary key |
| `U_VERSION` | `'!'` | Initial version |
| `TYP` | `sType` (e.g. `'jpg'`) | Format type |
| `T` | `'Signatur'` | Label |
| `META_T` | `null` | No metadata |
| `DATEN` | `oSignature` (bytea — the raw image bytes) | The actual signature blob |
| `C_TIME` | `LOCALTIMESTAMP` | Created at |
| `C_USER` | current user | Created by |
| `U_TIME` | `LOCALTIMESTAMP` | Updated at |
| `U_USER` | current user | Updated by |

---

### 5. SEN_HST2LOB — INSERT (links the history event to the LOB)

**Via:** `SenHst.AddLob(...)` → `SenHst2Lob.Put(rSenHst2Lob)` (SENHST2LOB.sql line 20)

| Column | Value | Purpose |
|---|---|---|
| `SEN_TIX` | `nTATix` | FK to SEN_HST |
| `C_TIME_INV` | from `rSenHst.C_Time_Inv` | FK to SEN_HST (PK component) |
| `LOB_TIX` | from `rLob.Tix` | FK to LOB |
| `C_TIME` | `LOCALTIMESTAMP` | Created at |
| `C_USER` | current user | Created by |
| `U_TIME` | `LOCALTIMESTAMP` | Updated at |
| `U_USER` | current user | Updated by |

---

### 6. SEN_TS — UPSERT (DFV sync marker, conditional)

**Via:** `pTA.setStatus(TASTATUS_DFV)` → `pTA.setDfvStatus(nTATix, 32)` → `Sen.PutTs(...)` (SEN.sql line 14686)

**Condition:** Only executes if `Vk_Art < 40` (FV transport orders). Skipped for non-FV transport orders.

INSERT path:

| Column | Value | Purpose |
|---|---|---|
| `SEN_TIX` | `nTATix` | FK to SENDUNG |
| `TRAN_CODE` | `'32'` | Transaction code for DFV sync |
| `TRAN_K` | `'1'` | Transaction type |
| `TRAN_E` | timestamp | Transaction event time |
| `C_TIME` | timestamp | Created at |
| `C_USER` | current user | Created by |
| `U_TIME` | timestamp | Updated at |
| `U_USER` | current user | Updated by |

On PK collision (`SEN_TIX` + `TRAN_CODE`), updates existing row with new `TRAN_K`, `TRAN_E`, timestamps.

---

## Summary

| # | Table | Operation | What it does |
|---|---|---|---|
| 1 | **SENDUNG** | UPDATE | Lock row, bump version + timestamp |
| 2 | **SEN_ZUSTAND** | UPSERT | Set `AUTOABFSIGNED` status bit (16) in `AUTOABF` range |
| 3 | **SEN_HST** | INSERT | Create history event: status 230 (SIG), MP 4 or 7, DocType=TO_MP4_SIG_DRIVER |
| 4 | **LOB** | INSERT | Store the signature image bytes |
| 5 | **SEN_HST2LOB** | INSERT | Link the SEN_HST event to the LOB entry |
| 6 | **SEN_TS** | UPSERT | DFV sync marker (conditional: only if Vk_Art < 40) |

---

## Constants Reference

| Constant | Value | Source |
|---|---|---|
| `Event_Lib.SIG()` | `230` | EVENT_LIB.sql line 16813 |
| `pTA_Lib.ACTION_TAAUTOABFSIGN()` | `'TAAUTOABFSIGN'` | PTA_LIB.sql line 310 |
| `pTA_Lib.STATUSRANGE_AUTOABF()` | `'AUTOABF'` | PTA_LIB.sql line 158 |
| `pTA_Lib.STATUS_AUTOABFSIGNED()` | `16` | PTA_LIB.sql line 165 |
| `pTA_Lib.TASTATUS_DFV()` | `13` | PTA_LIB.sql line 181 |
| `pDriverTerminal.DOCTYPE()` | `'TO_MP4_SIG_DRIVER'` | pDriverTerminal.sql line 35 |
| `pDriverTerminal.SEN_HST_REF_K()` | `'N'` | pDriverTerminal.sql line 46 |
| `pDriverTerminal.GetMeasuringPoint()` | `7` (NV) or `4` (default) | pDriverTerminal.sql line 266 |

---

<div align="center">
  <sub>Created by <strong>Virtual Architect</strong></sub>
</div>
