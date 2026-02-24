# 8. Change Driver Data

**Database: ABN 1034**

## Database Analysis Findings

### SQL Analysis Mappings

| SQL File | Result CSV | Description |
|----------|-----------|-------------|
| `analyze-sen_frk_unt-distribution.sql` | `data-1769599276056.csv` | Distribution of sen_frk_unt records per transport order |
| `analyze-sen_tb-contacts.sql` | `data-1769599942828.csv` | Contact type distribution via sen_tb table (UNF/UNN/FRF) |

### sen_frk_unt Cardinality

Analysis confirms **0:1 relationship** between `sendung` and `sen_frk_unt`:
- 98.60% of transport orders have 0 sen_frk_unt records
- 1.40% of transport orders have exactly 1 sen_frk_unt record (lfd_n = 1)
- 0% have multiple records
- Despite composite PK allowing multiple records, only `lfd_n = 1` is used in practice

### Contractor vs Carrier Structure

Based on analysis of `/Konzepte/2025-11-27-Edit-Flow/01-change-contractor`:

**Transport orders have TWO separate links:**

1. **Contractor (UNF/UNN)** - The Nagel branch responsible for the order
   - Stored in: `sen_tb` table with `tb='UNF'` or `tb='UNN'`
   - References: `pers.tix` (person/address data)
   - Managed via: `pTA.addUnt()` / `pDis_TransportOrder.SetContractor()`
   - **Data (ABN 1034):**
     - UNF (Long-haul): 787 transport orders (1.34% of all orders)
     - UNN (Local): 13 transport orders (0.02% of all orders)

2. **Carrier (FRF)** - The external freight forwarder executing the transport
   - Stored in: `sen_tb` table with `tb='FRF'`
   - References: `pers.tix` (person/address data)
   - **Data (ABN 1034):** 120 transport orders (0.20% of all orders)

**`sen_frk_unt` table:**
- Also contains `unt_tix` which references `pers.tix` (the contractor executing the freight)
- Stores operational data: driver (encrypted), vehicle, trailer, container
- Updated automatically by `pTA.addUnt()` when contractor is changed

**Data Model:**
```
SENDUNG (Transport Order)
  ├── sen_tb (Contact relationships)
  │   ├── tb='UNF' → pers (Freight Contractor)
  │   ├── tb='UNN' → pers (Local Contractor)
  │   ├── tb='FRF' → pers (Carrier)
  │   ├── tb='ABS' → pers (Sender)
  │   └── tb='EMP' → pers (Recipient)
  │
  └── sen_frk_unt (Operational assignment - 0:1)
      ├── unt_tix → pers (Contractor)
      ├── lkw_tix → eqm_local (Vehicle)
      ├── anh_tix → eqm_local (Trailer)
      ├── fahrer_name (encrypted driver)
      └── mobil_tel_n (encrypted phone)
```

---

- Niederlassungen haben einen Fahrerstamm
  - Tabelle `fahrer`: Nur Nagel-interne Fahrer
    - Enthält Klarnamen
    - Warum? Zu volatil, ändert sich zu arg/oft
    - PK: `fahrer_schluessel`
    - Auf diese Tabelle wird der Fuzzy Search angewandt
    - Fizzy Search muss New Dispo unterstützen (Groß/Klein, Wildcards, etc.)
- Verknüpfung über `sen_frk_unt`
  - FK: `fahrer_n` nicht hart forciert über Constraint
  - Warum? Ergibt keinen Sinn, weil dies die Verschlüsselung brechen würde.
  - Ergo: Ist immer `NULL` (zumindest auf PROD derzeit, in ABN gibt es Records, dies ist aber nicht erwartungsgemäß und kann ignoeriter werden)
  - `fahrer_name` enthält verschlüsselten Wert: `30996cfeb5e8318d638b2ae5ef0d76bf73d6f87056562a4f522fe076b9493c04e32372a13fea38fb89fe75a90131a64ab1e37d479b0bbef3`
- Entschlüsselung ist auch kein Problem
  - Chivrieren: Es gibt einen Verschlüsselungsalgorithmus
  - `cal_crypt.encrypt(stext character varying, nkeytype numeric DEFAULT cal_crypt.c_key_type_username()) RETURNS character varying` in `CAL_CRYPT`
  - `cal_crypt.decrypt(sencryptedtext character varying, nkeytype numeric DEFAULT cal_crypt.c_key_type_username()) RETURNS character varying` in `CAL_CRYPT`
- `v_ta` beinhaltet ggf. Auflösungslogik

## Business-Regeln

- Wenn das Fahrzeug einen Fahrer zugewordnet hat, wird dieser übernommen beim Hinzufügen eines Fahrzeugs
- Ansonsten keine weitere Logik
  - Den "Add"-Case gibt es sozusagen gar nicht in der Praxis, da es ohne einen Unternehmer keinen Fahrer geben kann (siehe Kommentar unten bei den Fragen)
- Ergo: Konzentration auf Edit-FLow
  - `sen_frk_unt`- Satz bereits vorhanden
  - Übliche Assign-Methodik über Verschlüsselung anwenden um zu lesen und schreiben
- Telefonnummer: `mobil_tel_n`
  - Ebenfalls verschlüsselt, da personenbezogen
  - `mobil_tel_n2` erstmal ignorieren
  - Ländervorwahlen bestehen in `SELECT tel_k FROM land`
    - Prüfen, ob wir das verwenden
    - Keine Zwang, freie Liste in New Dispo hinterlegt geht auch

## Business-Fragen

- Kann es einen Fahrer geben, ohne dass der Unternehmer bekannt ist?
  - Joachim: Würde es ausschließen und Stand jetzt nicht relevant => Use Case gibt es nicht
  - Nochmals mit Max B klären
  - **Kontext**: Der "Unternehmer" hier bezieht sich auf den Contractor (UNF/UNN) in `sen_tb`, nicht den Carrier (FRF)
  - Ein Fahrer kann technisch in `sen_frk_unt` gespeichert werden, auch wenn `sen_tb` leer ist (keine Contractor-Zuweisung)
  - Geschäftlich ist dies aber nicht relevant, da immer ein Contractor zugewiesen ist

## Entschlüsselungsvorgang

```sql
SELECT
	fahrer_n, cal_crypt.decrypt(fahrer_name) as decrypted_fahrer_name
    cal_crypt.decrypt(mobil_tel_n) as decrypted_tel_n. -- "+491515267771"
FROM
	TMS1034.SEN_FRK_UNT
WHERE
	FAHRER_NAME IS NOT NULL
LIMIT 100
```

## Löschen des Fahrers

- `NULL` setzen von `fahrer_name`

## Löschen Mobilnummer

- `NULL` Setzen von `mobil_tel_n`