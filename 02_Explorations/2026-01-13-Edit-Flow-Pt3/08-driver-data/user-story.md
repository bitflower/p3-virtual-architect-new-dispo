**WHO**: As a user, I want to add or change the driver of a transport order, so that the correct driver information (including phone data) is linked and stored in the TMS.

**Description**: The user can add or change the driver of a transport order using a unified “Driver name” field with fuzzy search or manual entry. When an existing driver is selected, it is linked to the transport order. If no match is selected, the user can manually enter a driver name, choose a country code from a dropdown (pre-filterable and alphabetically sorted), and provide a phone number that follows defined length and digit rules. Manually entered data is stored only at the transport order level. The country code is automatically preselected based on the carrier’s country and updates dynamically when the carrier changes (if no driver is yet assigned).

**Actors**: User (planner, dispatcher, or TMS operator)

**Triggers**: User initiates editing or creation of a transport order and interacts with the driver input field.

**Preconditions**:
*   A transport order exists and is available for editing.    
    
**Postconditions**:
*   The selected or manually entered driver information (name, country code, phone) is stored on the transport order.
*   Linked driver data references the master driver record (if selected).    
*   Manually entered phone details persist only in the transport order, not the master data.

**Technical Solution:**

**Database:** ABN 1034

**Tables:**
- Master data: `fahrer` (Nagel-internal drivers only, PK: `fahrer_schluessel`)
- Transport Order link: `sen_frk_unt` (1:1 relationship, always `lfd_n = 1`)
  - `fahrer_n` (FK, not enforced, always `NULL`)
  - `fahrer_name` (VARCHAR, encrypted driver name)
  - `mobil_tel_n` (VARCHAR, encrypted phone number with country code)
- Country codes: `land.tel_k`

**Read:**
- Fuzzy search on `fahrer` table for driver selection (must support case-insensitive, wildcards, **only non-deleted drivers where `del_flag` IS NULL or `del_flag` != 'X'**)
- Decrypt driver data on-demand (NOT in view - performance):
```sql
SELECT
    cal_crypt.decrypt(fahrer_name) as driver_name,
    cal_crypt.decrypt(mobil_tel_n) as phone_number
FROM sen_frk_unt
WHERE sen_tix = <TransportOrderId>
  AND lfd_n = 1
```
- Use separate function `GetDriver(TransportOrderId)` for on-demand retrieval

**Write:**
- New procedures in `pDis_TransportOrder`:


  - `SetDriver(TransportOrderId NUMERIC, DriverNo NUMERIC, DriverName VARCHAR, PhoneNumber VARCHAR)`
    - `DriverNo` (fahrer_n): Pass Fahrer-ID when driver selected from fuzzy search, NULL for manual entry
    - `DriverName`: Always required (encrypted with `cal_crypt.encrypt()`)
    - `PhoneNumber`: Optional, encrypted with `cal_crypt.encrypt()`
    - **UPDATE** `sen_frk_unt.fahrer_n`, `fahrer_name` and `mobil_tel_n` WHERE `sen_tix = TransportOrderId AND lfd_n = 1`
    - **INSERT** new sen_frk_unt record if not found (fallback for legacy data)
      - Sets `unt_tix = NULL`, `firma = pTA.getfirma()`, `nl = pTA.getnl()`
    - Handles both "Change Driver" (existing record) and "Add Driver" (missing record) scenarios
      - New Dispo created Transport Orders always have a `sen_frk_unt` record, for `pTA.New()` created ones it is not guaranteed
    - Follows `pTA.addUnt()` pattern (lines 3105-3114 in PTA.sql) with UPDATE first, INSERT fallback

  - `RemoveDriver(TransportOrderId NUMERIC)`
    - Clears all driver fields: `fahrer_n`, `fahrer_name`, `mobil_tel_n` → NULL
    - UPDATE only (no INSERT fallback needed)

  - `GetDriver(TransportOrderId NUMERIC) RETURNS RECORD (DriverNo NUMERIC, DriverName VARCHAR, PhoneNumber VARCHAR)`
    - Returns `DriverNo` (fahrer_n), decrypted `DriverName` and `PhoneNumber`
    - On-demand retrieval only (NOT in view for performance reasons)
    - Returns NULL values if no driver data exists or record not found

**SQL Implementation:**

```sql
--
-- Name: SetDriver(numeric, numeric, varchar, varchar) ; Type: PROCEDURE; Schema: pDIS_TransportOrder; Owner: -
-- Description: Sets or updates driver data for a transport order with UPDATE/INSERT fallback pattern
--
CREATE OR REPLACE PROCEDURE pDIS_TransportOrder.SetDriver(
    TransportOrderId NUMERIC,
    DriverNo         NUMERIC,   -- Fahrer-ID from fuzzy search (NULL for manual entry)
    DriverName       VARCHAR,   -- Always required
    PhoneNumber      VARCHAR    -- Phone with country code
)
LANGUAGE plpgsql
AS $$
DECLARE
    vEncryptedName  VARCHAR;
    vEncryptedPhone VARCHAR;
BEGIN
    -- Validate: DriverName must always be provided
    IF DriverName IS NULL OR trim(DriverName) = '' THEN
        RAISE EXCEPTION 'DriverName is required';
    END IF;

    -- Encrypt personal data
    vEncryptedName  := cal_crypt.encrypt(DriverName);
    vEncryptedPhone := cal_crypt.encrypt(PhoneNumber);

    -- Try UPDATE first (Change Driver scenario - existing sen_frk_unt record)
    UPDATE sen_frk_unt
    SET
        fahrer_n    = DriverNo,         -- Set FK if known driver, NULL for manual entry
        fahrer_name = vEncryptedName,   -- Always set encrypted name
        mobil_tel_n = vEncryptedPhone,  -- Encrypted phone
        u_version   = cal_util.getuversion(u_version),
        u_time      = pTA.gete(),
        u_user      = pTA.getuser()
    WHERE sen_tix = TransportOrderId
      AND lfd_n   = 1;

    -- Fallback INSERT if not found (Add Driver scenario - legacy data without sen_frk_unt)
    IF NOT FOUND THEN
        INSERT INTO sen_frk_unt(
            sen_tix, lfd_n, u_version, c_time, c_user, u_time, u_user,
            unt_tix, firma, nl, fahrer_n, fahrer_name, mobil_tel_n
        )
        VALUES(
            TransportOrderId, 1, '!',
            pTA.gete(), pTA.getuser(), pTA.gete(), pTA.getuser(),
            NULL, pTA.getfirma(), pTA.getnl(),
            DriverNo, vEncryptedName, vEncryptedPhone
        );
    END IF;
END;
$$;


--
-- Name: RemoveDriver(numeric) ; Type: PROCEDURE; Schema: pDIS_TransportOrder; Owner: -
-- Description: Removes driver data from a transport order
--
CREATE OR REPLACE PROCEDURE pDIS_TransportOrder.RemoveDriver(
    TransportOrderId NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE sen_frk_unt
    SET
        fahrer_n    = NULL,  -- Clear driver FK
        fahrer_name = NULL,  -- Clear encrypted name
        mobil_tel_n = NULL,  -- Clear encrypted phone
        u_version   = cal_util.getuversion(u_version),
        u_time      = pTA.gete(),
        u_user      = pTA.getuser()
    WHERE sen_tix = TransportOrderId
      AND lfd_n   = 1;

    -- No INSERT fallback needed for remove operation
END;
$$;


--
-- Name: GetDriver(numeric, out numeric, out varchar, out varchar) ; Type: FUNCTION; Schema: pDIS_TransportOrder; Owner: -
-- Description: Retrieves decrypted driver data for a specific transport order (on-demand only)
--
CREATE OR REPLACE FUNCTION pDIS_TransportOrder.GetDriver(
    TransportOrderId NUMERIC,
    OUT DriverNo     NUMERIC,   -- Fahrer-ID (NULL if manual entry)
    OUT DriverName   VARCHAR,   -- Decrypted driver name
    OUT PhoneNumber  VARCHAR    -- Decrypted phone number
)
RETURNS RECORD
LANGUAGE plpgsql
AS $$
BEGIN
    SELECT
        fahrer_n,
        cal_crypt.decrypt(fahrer_name),
        cal_crypt.decrypt(mobil_tel_n)
    INTO
        DriverNo,
        DriverName,
        PhoneNumber
    FROM sen_frk_unt
    WHERE sen_tix = TransportOrderId
      AND lfd_n   = 1;

    -- Returns NULL values if record not found
END;
$$;
```

**Usage Examples:**

```sql
-- Set driver from fuzzy search (known driver with fahrer_n)
CALL pDIS_TransportOrder.SetDriver(12345, 4711, 'Max Mustermann', '+491234567890');

-- Set driver via manual entry (no fahrer_n)
CALL pDIS_TransportOrder.SetDriver(12345, NULL, 'Hans Schmidt', '+491234567890');

-- Remove driver data
CALL pDIS_TransportOrder.RemoveDriver(12345);

-- Read driver data (on-demand, only when needed)
SELECT * FROM pDIS_TransportOrder.GetDriver(12345);

-- Or with explicit column names:
SELECT
    (pDIS_TransportOrder.GetDriver(12345)).*
FROM dual;

-- Example result:
-- DriverNo | DriverName        | PhoneNumber
-- 4711     | Max Mustermann    | +491234567890
-- NULL     | Hans Schmidt      | +491234567890
```

**Performance Note:**
- Driver data decryption happens **on-demand only** when `GetDriver()` is called
- **NOT** included in `v_dis_transportorder` to avoid decrypting all rows unnecessarily
- Backend should fetch driver data separately only when displaying/editing transport order details

**Business Logic:**
- When vehicle with assigned driver is added via `pTA.addLkw()`, driver is automatically copied to `sen_frk_unt.fahrer_name` IF no driver is currently assigned (database-level logic in PTA.sql lines 1399-1421)
- Country code pre-selected from carrier's country, updates dynamically on carrier change (if no driver assigned yet) - handled in backend/UI

**Constraints:**
d
- No referential integrity enforcement possible (`fahrer_n` FK cannot be used)
- Driver assignment depends on entrepreneur/carrier being set first (business rule enforced in UI/backend)
- Personal data encryption mandatory for GDPR compliance
- sen_frk_unt may not exist for old data (98.60% of orders in ABN 1034 have no sen_frk_unt record)
- Solution must handle both UPDATE (existing record) and INSERT (missing record) scenarios
- Driver data can be stored independently of contractor

The business requirements have been aligned with **Maximilian Beisheim** and **Patrick Uschmann**.
The technical solution design has been aligned with **Joachim Schreiner**.
All code including database, backend and frontend of this story is developed by P3.