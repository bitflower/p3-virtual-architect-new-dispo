# KND_SEN to SENDUNG Data Flow Analysis

## Overview

The KND_SEN table system serves as a staging environment for importing shipment data from external systems into the main TMS (Transport Management System) SENDUNG table structure.

### From Christian

```
https://development-biztalk-to-oms-and-tms-branch.cal-consult.int/swagger/index.html
```

```
/api/OmsMigration/DistributeConsignmentToTms
```

> Damit triggerst du auf ent1034 die Erstellung der Sendung aus dem OMS. Man muss aber als NL auch entsprechend 1034 mitgeben, sonst landet es in Oracle. 

> Ziel wird über Firma NL erkannt. `Sen_N` und `AbsRef_K` entsprechen der sichtbaren ConsignmentNumber in OMS `Entity_Id` entspricht der `Consignment_Id` von OMS Wenn die gleiche `Entity_Id` nochmal übergeben wird, dann muss DateQueued neuer als bei der letzten Übernahme sein.

Ansprechpartner:
Reinhard Lechner
Thomas Krause

Es gibt einen Sync von Livedaten aus OMS für 1034 in UAT und ABN, weil dies auch für Project G relevant ist (Tausende von Sendungen => Flutet die Umgebung, für ENT nicht zu empfehlen).

Es müsste in `ent` genügend disponierbare Sendungen geben:

```sql
SELECT * FROM sendung
WHERE sendungsart IN ('A') -- E & N = Nachverkehr, A = Fernverkehr
--WHERE sendungsart IN ('A', 'E', 'N') -- E & N = Nachverkehr, A = Fernverkehr
AND status_dis = 'F' -- Sind frei für die Disposition
AND leistungsdatum > localtimestamp - interval'125 days'
LIMIT 200
```

## Import über OMS-Schnitstelle

`DFV`-Prozeduren nicht einfach ausführen. Scheduling läuft über [siehe Chat]

## Frfachtenbörsentest

TO sollten alle aktuelels Datum haben, egal von wann die Sendung ist. Außerdem kann man im Tourpunkt das zustelldatum setzen als weitere Alternative um auf die Datumswerte Einfluss zu nehmen.

## Table Relationships

### Dependency Information Provided

```text
=== DEPENDENCY ANALYSIS FOR: knd_sen (tms1034.knd_sen) ===
Object Type: TABLE

STRUCTURE:
Columns (1):
  - dfv_tix unknown NOT NULL

Objects that depend on this (14):
  ← tms1034.v_knd_sen2 (VIEW)
  ← tms1034.v_knd_sen (VIEW)
  ← dfv_reorg.reorgkddfv (PROCEDURE)
  ← pvtmsnk.get3monthaverage (FUNCTION)
  ← kndsen.setlogistikk (PROCEDURE)
  ← kndsen.getlastomssortk (FUNCTION)
  ← tms1034.knd_sen_t (TABLE)
  ← tms1034.knd_sen_pos (TABLE)
  ← tms1034.knd_sen_ref (TABLE)
  ← tms1034.knd_sen_f (TABLE)
  ← tms1034.knd_sen_ls (TABLE)
  ← tms1034.knd_sen_pst (TABLE)
  ← tms1034.knd_sen_tb (TABLE)
  ← tms1034.knd_sen_zus (TABLE)

FOREIGN KEYS:
  No outgoing foreign keys
  No incoming foreign keys

ANALYSIS SUMMARY:
- Total dependencies: 0 outgoing, 14 incoming
- Complexity indicator: Medium - moderate coupling
- Role in system: Core dependency (many objects depend on this)
```

## Key Tables

### KND_SEN (Source/Staging Table)

- **Purpose**: Staging table for external shipment data imports
- **Key Fields**:
  - `dfv_tix`: Primary identifier
  - `firma`, `nl` (niederlassung): Company and branch identifiers
  - `sen_n`: Shipment number
  - `fix_key`: Fixed key identifier
  - `sen_art`: Shipment type
  - `uebern_id`: Transfer/import ID tracking

### SENDUNG (Target/Production Table)

- **Purpose**: Main operational shipment table in TMS
- **Key Fields**:
  - `sendung_tix`: Primary identifier
  - `firma`, `niederlassung`: Company and branch identifiers
  - `sendung_n`: Shipment number
  - `fix_key`: Fixed key identifier
  - `sendungsart`: Shipment type
  - Multiple status fields for tracking shipment lifecycle

## OMS JSON Data Format

The external OMS system uses the following JSON structure to populate KND_SEN tables:

### JSON to KND_SEN Mapping

| JSON Section         | Target Table     | Purpose                    |
| -------------------- | ---------------- | -------------------------- |
| `KndSen`             | `knd_sen`        | Main shipment header       |
| `KndSenLsRecords`    | `knd_sen_ls`     | Delivery slip records      |
| `KndSenPosRecords`   | `knd_sen_pos`    | Position/item records      |
| `KndSenPstRecords`   | `knd_sen_pst`    | Postal/package records     |
| `KndSenRefRecords`   | `knd_sen_ref`    | Reference records          |
| `KndSenTbRecords`    | `knd_sen_tb`     | Text block/address records |
| `KndSenLsRefRecords` | `knd_sen_ls_ref` | Delivery slip references   |
| `KndSenTRecords`     | `knd_sen_t`      | Text records               |
| `KndSenZusRecords`   | `knd_sen_zus`    | Additional data            |

### Key Field Mappings

#### Main Shipment (KndSen → knd_sen)
- `Firma` → `firma` (Company: "10")
- `Nl` → `nl` (Branch: "34")
- `Sen_N` → `sen_n` (Shipment number: "443")
- `Fix_Key` → `fix_key` (Fixed key: "34")
- `Sen_Art` → `sen_art` (Shipment type: "A")
- `Abs_Ref_K` → `abs_ref_k` (Sender reference: "443")
- `Status_K` → `status_k` (Status: "3")
- `Consignment_Id` → Custom field linking to OMS

#### KND_SEN to SENDUNG Field Mapping
| KND_SEN Field | SENDUNG Field   | Description                                 |
| ------------- | --------------- | ------------------------------------------- |
| `firma`       | `firma`         | Company identifier                          |
| `nl`          | `niederlassung` | Branch/location                             |
| `sen_n`       | `sendung_n`     | Shipment number                             |
| `fix_key`     | `fix_key`       | Fixed key identifier                        |
| `sen_art`     | `sendungsart`   | Shipment type (A=Abholung, E=Eingang, etc.) |
| `abs_ref_k`   | Custom mapping  | Sender reference                            |
| `emp_rel`     | Custom mapping  | Receiver relation                           |
| `status_k`    | `status_erf`    | Initial status mapping                      |
| `c_time`      | `c_time`        | Creation timestamp                          |
| `u_time`      | `u_time`        | Update timestamp                            |
| `c_user`      | `c_user`        | Creating user                               |

## Data Transfer Process

### Connection Architecture

1. **No Direct Foreign Keys**: KND_SEN has no foreign key relationships to SENDUNG
2. **Transformation Layer**: Data flows through DFV (Data Transfer) procedures
3. **Supporting Tables**: KND_SEN has satellite tables that mirror SENDUNG structure:
   - `knd_sen_pos` (positions)
   - `knd_sen_ref` (references)
   - `knd_sen_pst` (postal/package data)
   - `knd_sen_tb` (text blocks)
   - `knd_sen_zus` (additional data)
   - `knd_sen_ls` (delivery slips)

### Transfer Mechanism

#### Scheduled Jobs

Two primary jobs handle the data transfer automatically:

1. **DFV_SET Job** (`job_dfv_set.sql`)
   - Schedule: Every 15 minutes (`*/15 * * * *`)
   - Procedure: `DFV_SET.Process_SET()`
   - Purpose: Incoming shipment transfers (SET = Sendung Eingang Transfer)

2. **DFV_SAT Job** (`job_dfv_sat.sql`)
   - Schedule: Every 15 minutes (`*/15 * * * *`)
   - Procedure: `DFV_SAT.Process_SAT()`
   - Purpose: Outgoing shipment transfers (SAT = Sendung Ausgang Transfer)

#### Process Flow

1. **OMS System** sends JSON data to TMS via queue system
2. **JSON data** is parsed and inserted into KND_SEN tables
3. **Scheduled jobs** run every 15 minutes to process staged data
4. **DFV procedures** perform data transformation:
   - Validate data integrity
   - Apply business rules
   - Create SENDUNG records with proper initialization
   - Update related tables (positions, references, addresses)
5. **Transfer status** tracked in DFV_*_HST_TS tables
6. **dfv_tix** field serves as the primary tracking identifier

### Manual Triggering

While automated, the process can be manually triggered:

```sql
-- Direct procedure call
CALL DFV_SET.Process_SET();
CALL DFV_SAT.Process_SAT();
```

## Key Components

### DFV Subsystem

- **DFV_REORG**: Handles reorganization and cleanup of KND data
  - `reorgkddfv`: Specific procedure for KND_SEN maintenance
- **DFV_SET/DFV_SAT**: Core transfer procedures
- **Transfer Tracking**: Uses timestamp tables (*_HST_TS) to track transfer status

### Views

- `v_knd_sen`: Primary view for accessing staging data
- `v_knd_sen2`: Alternative view for staging data access

## Summary

The KND_SEN to SENDUNG data flow represents a robust staging architecture where:

- **OMS integration**: JSON data from external OMS is structured for TMS processing
- **External data isolation**: Safely isolated in staging tables before production
- **Automated processing**: Jobs process data every 15 minutes automatically
- **Business logic validation**: Occurs during transfer with error handling
- **No direct coupling**: Between staging and production tables
- **Complete audit trail**: Through history tables and transfer tracking
- **Pull-based approach**: Maximum control and reliability for data processing

## JSON Bodies & Queries

```json
{
  "QueueTransmissionData": {
    "SourceEntityName": "V_ESB_CONSIGNMENT",
    "TargetEntityName": "KND_SEN",
    "Entity_Id": "89950",
    "EntityIdColumn": "CONSIGNMENT_ID",
    "DateQueued": "2025-07-30T14:56:00"
  },
  "KndSen": {
    "Firma": "10",
    "Nl": "34",
    "Sen_N": "443",
    "C_Time": "2025-07-28T11:37:16",
    "C_User": "",
    "U_Time": "2025-07-29T17:38:03",
    "U_User": "",
    "Abs_Ref_K": "443",
    "Vk_Strom": "3",
    "Lst_D": "2025-07-30T00:00:00",
    "Emp_Rel": "60",
    "Fix_Bis_D": "2025-07-30T00:00:00",
    "Frank": "6",
    "Status_K": "3",
    "Prod_Grp": "01",
    "Consignment_Id": "89950",
    "Consignment_Statuscode": "42",
    "Quell_K": "s",
    "Fix_Key": "34",
    "Tran_Art": "01",
    "Sen_Art": "A",
    "Tran_K": "1",
    "U_Version": "!",
    "SelbstAbh_K": "0",
    "SelbstAnl_B": "0",
    "Dir_Angelad_B": "0",
    "Sort_K": "OMS-0000000000000000033823"
  },
  "KndSenLsRecords": {
    "KndSenLs": [
      {
        "Ls_N": "OMS0001",
        "U_Version": "!",
        "Ls_D": "2025-07-30T11:37:18",
        "Colli_C": "0",
        "Tats_Gew": "78",
        "Inh": "FEINKOST"
      },
      {
        "Ls_N": "OMS0002",
        "U_Version": "!",
        "Ls_D": "2025-07-11T07:37:18",
        "Colli_C": "0",
        "Tats_Gew": "78",
        "Inh": "FEINKOST"
      }
    ]
  },
  "KndSenPosRecords": {
    "KndSenPos": [
      {
        "Pos_N": "1",
        "Ve_C": "1",
        "Ve_Tk": "EUR",
        "Lhm_C": "20",
        "Lhm_Tk": "BOX",
        "Stellplatz_C": "6.5",
        "Gueterart": "00001",
        "Tats_Gew": "2578",
        "Frpf_Gew": "78",
        "Stueck_C": "40",
        "Zeichen_N": "4477888",
        "Inh": "SPEZIELLES",
        "U_Version": "!",
        "Bodenstpl_C": "1"
      },
      {
        "Pos_N": "2",
        "Lhm_C": "5",
        "Lhm_Tk": "EUR",
        "Stellplatz_C": "0",
        "Gueterart": "00002",
        "Tats_Gew": "1511",
        "Frpf_Gew": "22",
        "Stueck_C": "7",
        "Zeichen_N": "2244111",
        "Inh": "LECKERFOOD",
        "U_Version": "!"
      },
      {
        "Pos_N": "3",
        "Lhm_C": "40",
        "Lhm_Tk": "BOX",
        "Stellplatz_C": "0",
        "Gueterart": "00007",
        "Tats_Gew": "1531",
        "Frpf_Gew": "32",
        "Stueck_C": "100",
        "Zeichen_N": "3355566",
        "Inh": "DRINKS",
        "U_Version": "!"
      }
    ]
  },
  "KndSenPstRecords": {
    "KndSenPst": [
      {
        "Pst_N": "357200389300707189",
        "Pst_Ebene": "E",
        "U_Version": "!"
      },
      {
        "Pst_N": "357200389300707196",
        "Pst_Ebene": "E",
        "U_Version": "!"
      },
      {
        "Pst_N": "357200389300707202",
        "Pst_Ebene": "E",
        "U_Version": "!"
      }
    ]
  },
  "KndSenRefRecords": {
    "KndSenRef": [
      {
        "Typ": "OMS_ID",
        "Ref": "89950",
        "Art": "I",
        "U_Version": "!"
      },
      {
        "Typ": "IFTMIN-BGM",
        "Ref": "1502361",
        "Art": "I",
        "U_Version": "!"
      },
      {
        "Typ": "LIEFNR",
        "Ref": "1502361",
        "Art": "I",
        "U_Version": "!"
      }
    ]
  },
  "KndSenTbRecords": {
    "KndSenTb": [
      {
        "Pers_N": "787878",
        "Pers_I": "0",
        "Pers_Tb": "ABS",
        "Name1": "TEST D34",
        "Str": "HASELWEG 5",
        "Sitz_Land": "D",
        "Sitz_Plz": "34233",
        "Sitz_Ort": "FULDATAL",
        "Sitz_Bez": "ROTHWESTEN",
        "Ber_Land": "D",
        "Ber_Plz": "34233",
        "Ber_Ort": "FULDATAL",
        "Ber_Bez": "ROTHWESTEN",
        "U_Version": "!"
      },
      {
        "Pers_N": "0",
        "Pers_I": "0",
        "Pers_Tb": "EMP",
        "Name1": "THORSTENS SHOPPING MALL",
        "Str": "BERLINER STRASSE 45",
        "Sitz_Land": "D",
        "Sitz_Plz": "61118",
        "Sitz_Ort": "BAD VILBEL",
        "Ber_Land": "D",
        "Ber_Plz": "61118",
        "Ber_Ort": "BAD VILBEL",
        "U_Version": "!"
      }
    ]
  },
  "KndSenLsRefRecords": {
    "KndSenLsRef": [
      {
        "Ls_N": "OMS0002",
        "Typ": "AUF",
        "Ref": "TEST2AUFT066LS",
        "Art": "E",
        "U_Version": "!"
      },
      {
        "Ls_N": "OMS0002",
        "Typ": "BES",
        "Ref": "TEST2BESTEL654",
        "Art": "E",
        "U_Version": "!"
      }
    ]
  },
  "KndSenTRecords": {
    "KndSenT": [
      {
        "Lfd_N": "1",
        "U_Version": "!",
        "Typ": "M",
        "T": "SYSTEMTEST OMS"
      }
    ]
  },
  "KndSenPosTRecords": null,
  "KndSenLsPstRecords": null,
  "KndSenFRecords": null,
  "KndSenZusRecords": {
    "KndSenZus": [
      {
        "U_Version": "!",
        "Id": "ABL_SCAN_ANW_K",
        "Wert": "1"
      },
      {
        "U_Version": "!",
        "Id": "SA_ANGELADEN"
      }
    ]
  },
  "KndSoFuRecords": null
}
```

```sql
  SELECT *
  FROM knd_sen
  WHERE abs_ref_k = '443'
  LIMIT 10
```

```sql
SELECT * FROM dfv_sen_hst
```

```sql
SELECT * FROM dfv_sen_hst_ts
```

```sql
  SELECT sr.*
  --, s.*
  FROM sendung s
  JOIN sen_ref sr ON s.sendung_tix = sr.sen_tix
  WHERE sr.ref = '443'  -- abs_ref_k value
    --AND sr.typ IN ('OMS_ID', 'KD_REF', 'ABS_REF');
```

```sql
  SELECT *
  FROM sendung
  WHERE firma = '10'
    AND niederlassung = '34'
    --AND sendung_n = '443'
    --AND fix_key = '34';
```

```sql
SELECT * FROM v_job ORDER BY sched_e DESC NULLS LAST LIMIT 10
```