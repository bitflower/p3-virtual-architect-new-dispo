# Driver Mobile No From Vehicle - Blocker Analysis

> **⚠️ WIP - NEEDS FURTHER INVESTIGATION**
>
> This analysis is work in progress. Further investigation required to:
> - Verify actual driver search/selection mechanisms in Uniface
> - Confirm vehicle assignment triggers and data flow
> - Validate assumptions about `fahrer` table usage
> - Test phone number availability scenarios

**Date:** 2026-03-17
**Meeting Reference:** `00_Meetings/2026-03-17_Dispo Blocker_Driver_Mobile_No-From-Vehicle.vtt`

---

## Original User Input

Investigation of the driver search and vehicle assignment flow where mobile phone numbers become available. The issue occurs BEFORE GetDriver/SetDriver are called:

1. **Driver Search** - When searching for a driver by key number (`fahrer_schluessel`), no phone number is available
2. **Vehicle Assignment** - Only when a vehicle is assigned does the phone number become available (from vehicle master data)
3. **Phone Assignment** - The phone is then assigned to the driver via `SetDriver()` and stored in the transport order

**Focus:** Understanding where driver master data comes from and how vehicle assignment provides the missing phone number.

---

## Summary

The driver master table (`fahrer`) **exists but contains NO phone number field**. The phone number is architecturally stored with **Vehicle (Equipment)** records in `eqm_items.sap_phone_no`.

**The Problem Flow:**
1. User searches for driver by key → `fahrer` table queried → Driver found but **NO phone**
2. User assigns vehicle → `eqm_items.sap_phone_no` becomes available
3. System calls `SetDriver()` → Phone stored in `sen_frk_unt.mobil_tel_n`

**The Blocker:**
If only a driver is selected (no vehicle assignment), there is no source for the phone number. The driver master has no phone field, so it cannot be retrieved during driver search.

**Impact:** New Dispo cannot contact drivers when vehicle is not assigned, blocking driver notifications.

---

## Terminology Mapping

**Meeting Discussion → Code Objects:**

| Meeting Term | Technical Object | Location |
|-------------|------------------|----------|
| "Fahrer" (Driver) search by key | `fahrer` table | Driver master data table |
| "Fahrer_schluessel" (Driver key) | `fahrer.fahrer_schluessel` | Primary key in driver master |
| "Fahrzeug" (Vehicle) | `eqm_items` table | Equipment/Vehicle master data |
| "Fahrzeugstamm" (Vehicle Master) | `eqm_items` | Equipment master data table |
| "Telefonnummer" from vehicle | `eqm_items.sap_phone_no` | Source of phone number (NOT encrypted) |
| "Telefonnummer" assignment | `sen_frk_unt.mobil_tel_n` | Stored phone (ENCRYPTED) |
| "get driver routine from transporter" | `pDIS_TransportOrder.GetDriver()` | Retrieves stored data from `sen_frk_unt` |
| "set driver" | `pDIS_TransportOrder.SetDriver()` | Stores driver+phone in `sen_frk_unt` |
| "Sendung" (Shipment/Transport Order) | `sen_frk_unt` | Transport order assignment table |

---

## Meeting Summary

### Key Points from Discussion

**Core Issue:**
- In Uniface/TMS, telephone numbers are stored with the **Vehicle (Fahrzeug)** record, not with the Driver (Fahrer) record
- When selecting a vehicle from the master data, the system pulls: Vehicle + License Plate + Driver + Telephone Number
- When selecting only a driver (without vehicle), no telephone number is available
- This is a legacy design from when phones were physically installed in vehicles

**Historical Context:**
- Originally, mobile phones were hardwired/installed in vehicles (especially for local transport vehicles "Nahverkehrsfahrzeuge")
- Drivers had the same vehicle every day, so the phone was tied to the vehicle
- Not many vehicles had telephone numbers registered in the system

**Current Behavior:**
- New Dispo automatically updates from TMS when vehicle data changes
- When a vehicle is entered in Uniface disposition, TMS returns: Vehicle, Driver, and Telephone Number together
- The telephone number is not centrally managed in driver master data

### Participants' Observations

**Patrick Uschmann:**
- Confirmed the data structure: phone is with vehicle, not driver
- When vehicle master data is used, phone number comes automatically
- TMS would need to check if updates occurred in other fields

**Joachim Schreiner:**
- Noted that driver selection in Driver Terminal uses **"get driver" routine from transporter** (= `pDIS_TransportOrder.GetDriver()`)
- Confirmed there's no field to enter telephone number for drivers currently
- Suggested checking if phone is stored in vehicle master data (Fahrzeugstamm)

**Matthias Max:**
- Identified the phone number source issue
- Questioned how to handle the scenario when only driver is selected without vehicle
- Discussed centralization of driver master data

**Max Kehder:**
- Clarified: When adding a driver from database, no telephone number comes
- When adding a vehicle, it pulls vehicle + driver + phone number together
- Phone number is mapped to a specific field from the vehicle

---

## Driver Master Data Source

### The `fahrer` Table (Driver Master)

**Location:** `Code/tms-alloydb-schema/src/sql/table/fahrer.sql`

**Purpose:** Master data table for all drivers - **THIS IS WHERE DRIVERS ARE SEARCHED**

**Schema:**
```sql
CREATE TABLE fahrer (
    firmennummer numeric(3,0) NOT NULL,      -- Company
    niederlassung numeric(2,0) NOT NULL,     -- Branch
    fahrer_schluessel numeric(3,0) NOT NULL, -- Driver Key (search term)
    name character(35),                      -- Driver Name
    u_version character(1),
    c_date timestamp,
    c_time timestamp,
    u_date timestamp,
    u_time timestamp,
    ols_user character(8),
    eintrittsdatum timestamp,                -- Entry date
    fuehrerschein_kl character(20),          -- Driver's license class
    fs_geprueft_am timestamp,
    ggvs_fs character(1),
    ggvs_klassen character(20),
    text character(175),
    del_flag character(1),
    PRIMARY KEY (firmennummer, niederlassung, fahrer_schluessel)
);
```

**CRITICAL FINDING:** ❌ **NO phone number field exists in driver master data!**

**What's Missing:**
- No `telefon` field
- No `mobil_tel_n` field
- No `handy` field
- No contact information whatsoever

**Driver Search Impact:**
- When user searches for driver by `fahrer_schluessel`, query returns driver from this table
- Driver name is available
- **Phone number is NULL** - no source available

---

## TMS Database Procedures

> **Visual Reference:** See code screenshots in `00_Meetings/2026-03-17_Dispo Blocker_Driver_Mobile_No-From-Vehicle/`
> - `Bildschirmfoto 2026-03-17 um 11.21.18.png` - Uniface UI showing vehicle/driver form
> - `Bildschirmfoto 2026-03-17 um 11.24.03.png` - TMS database procedures code

> **Note:** These procedures are called AFTER driver and phone are known - they store the result, not the source

#### GetDriver Function
**Location:** `Code/tms-alloydb-schema/src/sql/package/PDIS_TRANSPORTORDER.sql:1501-1523`

> **Note:** This is the **"get driver routine from transporter"** mentioned in the meeting by Joachim Schreiner.

```sql
create or replace function pDIS_TransportOrder.GetDriver(
    p_transportorderid numeric,
    out driverno numeric,
    out drivername varchar,
    out phonenumber varchar
)
returns record
language plpgsql
as $$
begin
    select
        s.fahrer_n,
        cal_crypt.decrypt(s.fahrer_name),
        cal_crypt.decrypt(s.mobil_tel_n)
    into
        driverno,
        drivername,
        phonenumber
    from sen_frk_unt s
    where s.sen_tix = p_transportorderid and s.lfd_n = 1;
end;
$$;
```

**Retrieves from:** `sen_frk_unt` table
**Decrypts:** Driver name and mobile telephone number using `cal_crypt.decrypt()`
**Returns:** Driver number, name, and phone number for a given transport order

#### SetDriver Procedure
**Location:** `Code/tms-alloydb-schema/src/sql/package/PDIS_TRANSPORTORDER.sql:1531-1610`

```sql
create or replace procedure pDIS_TransportOrder.SetDriver(
    p_transportorderid numeric,
    p_driverno numeric,        -- Fahrer-ID (NULL for manual entry)
    p_drivername varchar,      -- Optional
    p_phonenumber varchar      -- Optional
)
language plpgsql
as $$
declare
    v_encrypted_name  varchar;
    v_encrypted_phone varchar;
begin
    -- Validation: at least one of name or phone must be provided
    if nullif(p_drivername, '') is null
      and nullif(p_phonenumber, '') is null then
      raise exception 'Either Driver Name or Phone Number must be provided';
    end if;

    -- Encrypt data
    v_encrypted_name := cal_crypt.encrypt(p_drivername);
    v_encrypted_phone := cal_crypt.encrypt(p_phonenumber);

    -- UPDATE first (Change Driver scenario)
    update sen_frk_unt
    set
        fahrer_n    = p_driverno,
        fahrer_name = v_encrypted_name,
        mobil_tel_n = v_encrypted_phone,
        u_version   = cal_util.getuversion(u_version),
        u_time      = pta.gete(),
        u_user      = pta.getuser()
    where sen_tix = p_transportorderid
    and lfd_n   = 1;

    -- INSERT fallback if no record exists
    if not found then
        insert into sen_frk_unt(...) values (...);
    end if;
end;
$$;
```

**Stores in:** `sen_frk_unt.mobil_tel_n` (encrypted)
**Pattern:** UPDATE/INSERT fallback

---

## Database Schema

### Primary Tables

#### 1. `fahrer` (Driver Master Data) - **THE SOURCE**
**Location:** `Code/tms-alloydb-schema/src/sql/table/fahrer.sql`

**Purpose:** Master data for all drivers - used when searching/selecting drivers

**Key Structure:**
- Primary Key: `(firmennummer, niederlassung, fahrer_schluessel)`
- Driver Name: `name` (35 characters)
- **Missing:** Phone/Mobile number field

**This is the table queried when:**
- User searches for driver by number
- Driver selection dropdown is populated
- Driver details are looked up

**Problem:** No phone number available at driver search/selection time

---

#### 2. `eqm_items` (Equipment/Vehicle Master Data) - **THE PHONE SOURCE**
**Location:** `Code/tms-alloydb-schema/src/sql/table/eqm_items.sql`

**Purpose:** Master data for all equipment (vehicles, trailers, containers)

**Relevant Fields:**
- `tix` (numeric 22,0) - Equipment TIX (Primary Key)
- `sap_registration_no` (varchar 15) - Vehicle Registration Number
- **`sap_phone_no` (varchar 30)** - **VEHICLE PHONE NUMBER** (NOT encrypted)

**This is where phone numbers come from:**
- Phone is stored with vehicle, not driver
- When vehicle is assigned to transport order, this field provides the phone
- Plain text (not encrypted) - comes from SAP integration

**Critical:** Phone becomes available ONLY when vehicle is assigned

---

#### 3. `sen_frk_unt` (Transport Order Freight Unit) - **THE STORAGE**
**Location:** `Code/tms-alloydb-schema/src/sql/table/sen_frk_unt.sql`

**Purpose:** Stores freight/vehicle/driver assignment data for transport orders (Sendung = Shipment)

**Schema:**
```sql
CREATE TABLE sen_frk_unt (
    -- Primary Keys
    sen_tix numeric(22,0) NOT NULL,        -- Transport Order ID
    lfd_n numeric(3,0) NOT NULL,           -- Sequential Number

    -- Audit Fields
    u_version character(1),
    c_time timestamp without time zone,
    c_user character(8),
    u_time timestamp without time zone,
    u_user character(8),

    -- Organization
    unt_tix numeric(22,0),                 -- Subcontractor ID
    firma numeric(3,0),                    -- Company
    nl numeric(2,0),                       -- Branch

    -- Vehicle Fields
    lkw_k character varying(15),           -- Truck License Plate
    lkw_amtl_k character varying(15),      -- Official Truck Plate
    lkw_tix numeric(22,0),                 -- Truck TIX (Equipment ID)
    anh_k character varying(15),           -- Trailer License Plate
    anh_tix numeric(22,0),                 -- Trailer TIX
    lkw_wb_k character varying(15),        -- Truck Swap Body
    lkw_wb_tix numeric(22,0),
    anh_wb_k character varying(15),        -- Trailer Swap Body
    anh_wb_tix numeric(22,0),
    con_k character(15),                   -- Container
    con_tix numeric(22,0),

    -- Driver Fields
    fahrer_n numeric(3,0),                 -- Driver Number
    fahrer_name character varying(144),    -- Driver Name (ENCRYPTED)
    beifah_n numeric(3,0),                 -- Co-driver Number
    beifah_name character varying(144),    -- Co-driver Name (ENCRYPTED)

    -- Phone Fields (ENCRYPTED)
    mobil_tel_n character varying(112),    -- Mobile Telephone Number
    mobil_tel_n2 character varying(112),   -- Second Mobile Number

    -- Other Fields
    temp_log_id character varying(30),     -- Temperature Logger ID
    konz character varying(10),
    fahrtenbuch character varying(10),
    vertrauen_b character(1),
    fak_bereich character(3),
    gew numeric(9,3),                      -- Weight
    stellplatz_c numeric(5,2),             -- Pallet Space

    PRIMARY KEY (sen_tix, lfd_n)
);
```

**Key Points:**
- `mobil_tel_n` stores phone number (ENCRYPTED with `cal_crypt`)
- Associated with transport order (`sen_tix`), not driver master
- Can store vehicle TIX references (`lkw_tix`, `anh_tix`)

#### 2. `eqm_items` (Equipment/Vehicle Master Data)
**Location:** `Code/tms-alloydb-schema/src/sql/table/eqm_items.sql`

**Purpose:** Master data for all equipment (vehicles, trailers, containers)

**Relevant Schema:**
```sql
CREATE TABLE eqm_items (
    -- Primary Keys
    tix numeric(22,0) NOT NULL,             -- Equipment TIX
    company_no_user numeric(3,0) NOT NULL,
    branch_no_user numeric(2,0) NOT NULL,

    -- Equipment Identification
    eqm_id character varying(255),          -- Equipment ID
    eqm_type_id numeric(22,0),              -- Equipment Type
    sap_registration_no character varying(15), -- Vehicle Registration Number

    -- Phone Field (NOT ENCRYPTED)
    sap_phone_no character varying(30),     -- VEHICLE PHONE NUMBER

    -- Device Fields
    mobiledevice_id character varying(255),
    mobiledevice_type_id numeric(22,0),

    -- SAP Integration
    sap_valid_from timestamp,
    sap_valid_until timestamp,
    sap_manufacturer character varying(30),
    sap_vehicle_group character varying(30),
    sap_status character varying(1),

    -- Vehicle Specifications
    sap_weight numeric(13,3),
    sap_max_weight numeric(13,3),
    sap_payload numeric(13,3),
    overall_width numeric(5,0),
    overall_height numeric(5,0),
    overall_length numeric(5,0),
    pallet_space_no numeric(5,2),

    PRIMARY KEY (tix)
);
```

**Key Points:**
- `sap_phone_no` is the **source of truth** for vehicle phone numbers
- NOT encrypted (unlike `sen_frk_unt.mobil_tel_n`)
- Part of SAP integration data
- No relation to driver master data

### Missing: Driver Master Table with Phone

**No table found** in TMS schema with structure like:
```sql
-- THIS DOES NOT EXIST
CREATE TABLE fahrer_stamm (
    firma numeric(3,0),
    nl numeric(2,0),
    fahrer_n numeric(3,0),
    mobil_tel_n varchar(112),
    PRIMARY KEY (firma, nl, fahrer_n)
);
```

This confirms the architectural issue: **drivers have no master data location for phone numbers**.

---

## Analysis

### Data Flow Analysis

#### Step 1: Driver Search (The Problem Origin)
```
User searches for driver by key number
↓
Query: SELECT * FROM fahrer WHERE fahrer_schluessel = [key]
↓
Result:
  - firmennummer (company)
  - niederlassung (branch)
  - fahrer_schluessel (driver key)
  - name (driver name)
  - ❌ NO PHONE NUMBER FIELD
↓
Driver can be selected but phone is unknown
```

#### Step 2a: Vehicle Assignment Path (Phone Becomes Available)
```
User assigns vehicle to transport order
↓
Query: SELECT * FROM eqm_items WHERE sap_registration_no = [plate]
↓
Result includes:
  - tix (equipment ID)
  - sap_phone_no ✅ PHONE NUMBER AVAILABLE!
↓
System calls SetDriver(transportorderid, driverno, drivername, phone)
  - phone = eqm_items.sap_phone_no (from vehicle)
↓
SetDriver stores in sen_frk_unt:
  - fahrer_n = driver key
  - fahrer_name = encrypt(driver name)
  - mobil_tel_n = encrypt(eqm_items.sap_phone_no)
  - lkw_tix = vehicle TIX
↓
Later: New Dispo calls GetDriver(transportorderid)
↓
Returns: driver number, driver name, phone (decrypted) ✅
```

#### Step 2b: Driver-Only Selection Path (NO Phone Available) - **THE BLOCKER**
```
User assigns driver WITHOUT vehicle
↓
Driver data from fahrer table:
  - fahrer_schluessel (driver key)
  - name (driver name)
  - ❌ NO PHONE NUMBER
↓
System calls SetDriver(transportorderid, driverno, drivername, NULL)
  - phone = NULL (no source available!)
↓
SetDriver stores in sen_frk_unt:
  - fahrer_n = driver key
  - fahrer_name = encrypt(driver name)
  - mobil_tel_n = NULL ❌
↓
Later: New Dispo calls GetDriver(transportorderid)
↓
Returns: driver number, driver name, phonenumber = NULL ❌
↓
BLOCKER: Cannot send notifications, cannot contact driver
```

### Root Cause

**Architectural Decision:** The system was designed when phones were physically installed in vehicles (hardwired mobile phones in trucks). Therefore:
1. Phone numbers were logically tied to vehicles, not drivers
2. SAP integration stores phone in equipment master (`eqm_items.sap_phone_no`)
3. No driver master table with phone number field exists
4. Transport order assignment table (`sen_frk_unt`) stores the phone per assignment, not per driver

### Affected Scenarios

1. **Driver selected without vehicle:**
   - No phone number available from TMS
   - New Dispo cannot display/use phone number for notifications
   - **Severity:** High - Blocks driver communication

2. **Vehicle change during transport:**
   - Phone number changes automatically with vehicle
   - May not reflect actual driver's phone
   - **Severity:** Medium - Causes communication confusion

3. **Driver change (same vehicle):**
   - Phone number remains the same (from vehicle)
   - Shows previous context, not current driver's phone
   - **Severity:** Medium - Wrong contact information

4. **Manual phone entry in New Dispo:**
   - Phone gets stored in `sen_frk_unt.mobil_tel_n`
   - But NOT synchronized back to vehicle master (`eqm_items`)
   - Future vehicle selections might overwrite this manual entry
   - **Severity:** Low - Data inconsistency

### Data Inconsistency Risks

When New Dispo calls `SetDriver` with manually entered phone:
- Phone gets stored in `sen_frk_unt.mobil_tel_n` (encrypted)
- This phone is **not** synchronized back to `eqm_items.sap_phone_no`
- When same vehicle is used on another transport order, old phone from `eqm_items` is used
- Manual entry is lost/overwritten

### Security Consideration

**Encryption Mismatch:**
- `sen_frk_unt.mobil_tel_n` uses `cal_crypt.encrypt()` / `cal_crypt.decrypt()`
- `eqm_items.sap_phone_no` is **NOT encrypted**
- When copying phone from vehicle to assignment, needs encryption
- When displaying phone, needs decryption

---

## Findings

### Code Objects Verified

✅ **TMS Database Procedures:**
- `pDIS_TransportOrder.GetDriver()` - Line 1501 (the "get driver routine from transporter")
- `pDIS_TransportOrder.SetDriver()` - Line 1531
- `pDriverTerminal` package functions

### Database Objects Verified

✅ **Tables:**
- `fahrer` - **Driver master table EXISTS** (firmennummer, niederlassung, fahrer_schluessel, name)
- `eqm_items` - Equipment/vehicle master (stores unencrypted phone in `sap_phone_no`)
- `sen_frk_unt` - Transport order assignment table (stores encrypted phone)

❌ **Missing Field:**
- `fahrer` table has **NO phone number field**
- No `mobil_tel_n`, `telefon`, `handy`, or any contact field in driver master

✅ **Procedures:**
- `GetDriver()` - Retrieves stored data from `sen_frk_unt` (AFTER driver+phone are known)
- `SetDriver()` - Stores driver+phone in `sen_frk_unt` (AFTER phone is available)

### Key Discoveries

1. **Driver master exists but incomplete:**
   - `fahrer` table is the driver master data source
   - Contains: company, branch, driver key, name, license info
   - **Missing:** Phone number field
   - Driver search/selection cannot provide phone

2. **Phone is per-vehicle, not per-driver:**
   - `eqm_items.sap_phone_no` stores phone with vehicle
   - Phone comes from SAP integration (vehicle master data)
   - When vehicle is assigned → phone becomes available
   - When only driver is assigned → NO phone source

3. **Phone storage is per-assignment:**
   - Each transport order assignment in `sen_frk_unt` stores phone
   - Phone is encrypted in assignment (`sen_frk_unt.mobil_tel_n`)
   - Phone is plain text in vehicle master (`eqm_items.sap_phone_no`)
   - Phone must be provided when calling `SetDriver()`

4. **The sequence matters:**
   - Step 1: Driver search queries `fahrer` → NO phone available
   - Step 2: Vehicle assignment queries `eqm_items` → Phone available
   - Step 3: `SetDriver()` called → Phone stored in `sen_frk_unt`
   - Step 4: `GetDriver()` retrieves stored phone
   - **Blocker:** If no vehicle assigned, sequence breaks at Step 2

---

## Questions/Open Items

### Business Process Questions

1. **Is the vehicle-based phone model still valid?**
   - Do drivers still use vehicle-installed phones?
   - Or do drivers mostly use personal mobile phones?
   - Should phone be mandatory for driver assignments?

2. **What's the preferred phone source?**
   - Driver's personal phone (if available)
   - Vehicle's installed phone
   - Manual entry per assignment

3. **How to handle driver changes?**
   - When driver changes but vehicle stays same, should phone change?
   - Should system prompt for phone update?

### Technical Questions

1. **Should we create a driver master table?**
   - Add `fahrer_stamm` table with phone field?
   - Migrate existing phone data from vehicles to drivers?
   - Impact on Uniface and other systems?

2. **Fallback logic priority?**
   - If both driver and vehicle have phones, which takes precedence?
   - Should manual entry override all?

3. **Data synchronization?**
   - Should manual phone entries in New Dispo be synced to driver master?
   - Should vehicle phone changes trigger updates to active assignments?

### User Experience Questions

1. **Should vehicle be mandatory?**
   - Force vehicle selection when assigning driver?
   - Or allow driver-only with mandatory phone entry?

2. **How to handle missing phone numbers?**
   - Block assignment until phone is provided?
   - Show warning but allow assignment?
   - Auto-lookup phone from last assignment?

---

## Recommendations

### Short-term (Quick Fix) - 1-2 Sprints

**Goal:** Unblock New Dispo immediately

1. **Make phone number mandatory in SetDriver:**
   - Update validation in `pDIS_TransportOrder.SetDriver()`
   - If `p_phonenumber` is NULL, raise error with clear message
   - Forces user to provide phone (either from vehicle or manual)

2. **Add UI validation in calling applications:**
   - When driver is selected without vehicle, prompt for phone input
   - Mark as required
   - Store manual entry via `SetDriver` call

3. **Create helper function for phone lookup:**
   - Add `pDIS_TransportOrder.GetDriverPhone()` function
   - Check last assignment for this driver's phone
   - Return as suggestion/default value

**Pros:**
- Quick to implement
- Minimal database changes
- Unblocks user workflow

**Cons:**
- Manual data entry burden
- No centralized driver phone storage
- Data duplication across assignments

### Medium-term (Architectural Fix) - 1-2 Months

**Goal:** Add phone number to driver master data

1. **Alter `fahrer` table to add phone field:**
```sql
ALTER TABLE fahrer
ADD COLUMN mobil_tel_n varchar(112); -- encrypted phone number

-- Optional: add email for future use
ALTER TABLE fahrer
ADD COLUMN email varchar(255);
```

**Alternative: Create separate driver contact table:**
```sql
CREATE TABLE fahrer_kontakt (
    firmennummer numeric(3,0) NOT NULL,
    niederlassung numeric(2,0) NOT NULL,
    fahrer_schluessel numeric(3,0) NOT NULL,
    mobil_tel_n varchar(112),      -- encrypted
    mobil_tel_n2 varchar(112),     -- encrypted backup
    email varchar(255),
    u_time timestamp,
    u_user varchar(8),
    PRIMARY KEY (firmennummer, niederlassung, fahrer_schluessel),
    FOREIGN KEY (firmennummer, niederlassung, fahrer_schluessel)
        REFERENCES fahrer(firmennummer, niederlassung, fahrer_schluessel)
);
```

2. **Implement fallback logic in SetDriver:**
```sql
-- Enhanced SetDriver procedure with phone fallback
CREATE OR REPLACE PROCEDURE pDIS_TransportOrder.SetDriver(
    p_transportorderid numeric,
    p_driverno numeric,
    p_drivername varchar,
    p_phonenumber varchar
)
AS $$
DECLARE
    v_phone varchar;
BEGIN
    -- Priority 1: Use explicitly provided phone number
    IF p_phonenumber IS NOT NULL THEN
        v_phone := p_phonenumber;

    -- Priority 2: Get from driver master (NEW!)
    ELSE
        SELECT cal_crypt.decrypt(mobil_tel_n)
        INTO v_phone
        FROM fahrer
        WHERE firmennummer = pta.getfirma()
          AND niederlassung = pta.getnl()
          AND fahrer_schluessel = p_driverno;

        -- Priority 3: If not in driver master, try vehicle
        IF v_phone IS NULL THEN
            SELECT eqm.sap_phone_no INTO v_phone
            FROM sen_frk_unt s
            JOIN eqm_items eqm ON s.lkw_tix = eqm.tix
            WHERE s.sen_tix = p_transportorderid;
        END IF;
    END IF;

    -- Store in assignment (existing code continues...)
    UPDATE sen_frk_unt
    SET mobil_tel_n = cal_crypt.encrypt(v_phone),
        fahrer_n = p_driverno,
        fahrer_name = cal_crypt.encrypt(p_drivername)
    WHERE sen_tix = p_transportorderid;
END;
$$;
```

3. **Create driver phone maintenance procedures:**
   - Add procedures for updating `fahrer.mobil_tel_n`
   - Encryption/decryption using `cal_crypt`
   - Audit trail for phone number changes
   - Uniface forms for driver master maintenance

4. **Data migration strategy:**
   - Analyze `sen_frk_unt` for frequently used driver+phone combinations:
     ```sql
     SELECT fahrer_n,
            cal_crypt.decrypt(mobil_tel_n) as phone,
            COUNT(*) as usage_count
     FROM sen_frk_unt
     WHERE mobil_tel_n IS NOT NULL
     GROUP BY fahrer_n, mobil_tel_n
     ORDER BY usage_count DESC;
     ```
   - Identify most common phone for each driver
   - Populate `fahrer.mobil_tel_n` with migrated data
   - Handle conflicts (same driver, multiple phones) → keep most recent or most used

**Pros:**
- Centralized driver contact data
- Reduces manual entry
- Better data consistency
- Aligns with modern usage (drivers have phones, not vehicles)

**Cons:**
- Requires database schema change
- Impacts multiple systems (Uniface, TMS Bridge, New Dispo)
- Data migration complexity
- Testing effort

### Long-term (Full Modernization) - 3-6 Months

**Goal:** Comprehensive driver master data management

1. **Centralized driver management service:**
   - RESTful API for driver CRUD operations
   - Support multiple contact methods (phone, email, SMS)
   - Preference management (primary phone, backup phone)
   - Historical tracking of contact changes

2. **Multi-phone support:**
   - Work phone (company-provided)
   - Personal phone (driver's own)
   - Emergency contact
   - Preference flag for which to use

3. **Real-time synchronization:**
   - Update driver contact when changed in any system
   - Propagate to active transport orders
   - Notification to dispatchers when driver contact changes

4. **Integration with HR/SAP:**
   - Sync driver master data with HR system
   - Validate phone numbers against telecom provider
   - Compliance with GDPR for contact data

5. **Enhanced UI:**
   - Driver profile page with all contact methods
   - Communication history per driver
   - Quick contact actions (call, SMS, email)

**Pros:**
- Modern, scalable architecture
- Best user experience
- Data quality improvements
- Regulatory compliance

**Cons:**
- Significant development effort
- High cost
- Long timeline
- Requires organizational change management

---

## Related Files

### TMS Database Schema
- `Code/tms-alloydb-schema/src/sql/table/sen_frk_unt.sql`
- `Code/tms-alloydb-schema/src/sql/table/eqm_items.sql`
- `Code/tms-alloydb-schema/src/sql/package/PDIS_TRANSPORTORDER.sql`
- `Code/tms-alloydb-schema/src/sql/package/pDriverTerminal.sql`

### Documentation
- `00_Meetings/2026-03-17_Dispo Blocker_Driver_Mobile_No-From-Vehicle.vtt` - Meeting transcript
- `00_Meetings/2026-03-17_Dispo Blocker_Driver_Mobile_No-From-Vehicle/Bildschirmfoto 2026-03-17 um 11.21.18.png` - Uniface UI screenshot
- `00_Meetings/2026-03-17_Dispo Blocker_Driver_Mobile_No-From-Vehicle/Bildschirmfoto 2026-03-17 um 11.24.03.png` - TMS procedures code screenshot

### Views Involving Phone Data
- `Code/tms-alloydb-schema/src/sql/view/v_ta.sql`
- `Code/tms-alloydb-schema/src/sql/view/V_DIS_TRANSPORTORDER.sql`
- `Code/tms-alloydb-schema/src/sql/view/v_dis_transportorder_filter.sql`

---

## Related User Stories/Tasks

### Immediate Action Items

- [ ] **Decision:** Business approval for short-term vs medium-term approach
- [ ] **Task:** Add phone validation in SetDriver procedure
- [ ] **Task:** Update New Dispo UI to show phone input when driver selected without vehicle
- [ ] **Task:** Document current behavior and workarounds in user documentation

### If Medium-term Approach Chosen

- [ ] **Decision:** Alter `fahrer` table vs create separate `fahrer_kontakt` table
- [ ] **Story:** Add `mobil_tel_n` field to `fahrer` table (ALTER TABLE)
- [ ] **Story:** Implement phone fallback logic in `SetDriver()` procedure
- [ ] **Story:** Create `UpdateDriverPhone()` procedure for maintaining driver contact data
- [ ] **Story:** Data migration analysis and script for existing driver phones
- [ ] **Story:** Update driver search/query functions to optionally return phone
- [ ] **Story:** Uniface forms for driver phone maintenance
- [ ] **Task:** Create views/functions for driver lookup with phone
- [ ] **Task:** Integration testing with all systems (Uniface, New Dispo, Driver Terminal)
- [ ] **Task:** Security review for encryption strategy
- [ ] **Task:** Performance testing for phone lookup fallback logic

### Technical Debt Items

- [ ] **Debt:** Inconsistent encryption (sen_frk_unt vs eqm_items)
- [ ] **Debt:** No centralized driver master data
- [ ] **Debt:** Manual phone entries not persisted to master
- [ ] **Debt:** Phone number validation missing

---

## Status

**Current Status:** ⚠️ Analysis Complete - Awaiting Business Decision

**Blocker Severity:** 🔴 High - Affects driver notifications and contact management

**Impact:**
- New Dispo cannot contact drivers when vehicle not assigned
- Dispatchers must manually track driver phone numbers
- Risk of wrong contact information

**Next Steps:**
1. Present findings to product owner and stakeholders
2. Decide: Short-term workaround or medium-term architectural fix?
3. Estimate effort for chosen approach
4. Create user stories and tasks
5. Prioritize in backlog

**Dependencies:**
- Business decision on adding phone to driver master data
- Database schema change approval (ALTER TABLE fahrer)
- Uniface system updates for driver phone maintenance
- Data migration strategy

---

## Complete Picture Summary

### Current Architecture Flow

**1. Driver Search Phase:**
```
User searches driver by key
    ↓
Query: SELECT * FROM fahrer WHERE fahrer_schluessel = [key]
    ↓
Returns: name, license info
    ❌ NO phone field exists
```

**2. Phone Becomes Available (Vehicle Assignment):**
```
User assigns vehicle
    ↓
Query: SELECT sap_phone_no FROM eqm_items WHERE sap_registration_no = [plate]
    ↓
Returns: ✅ phone from vehicle
```

**3. Storage Phase:**
```
Call: SetDriver(transportorderid, driverno, name, phone)
    ↓
Store: INSERT/UPDATE sen_frk_unt SET mobil_tel_n = encrypt(phone)
```

**4. Retrieval Phase (Later):**
```
Call: GetDriver(transportorderid)
    ↓
Returns: decrypt(mobil_tel_n) from sen_frk_unt
```

### The Architectural Gap

**Driver Master (`fahrer` table) Contains:**
- ✅ `firmennummer` - Company ID
- ✅ `niederlassung` - Branch ID
- ✅ `fahrer_schluessel` - Driver key (search term)
- ✅ `name` - Driver name
- ✅ `fuehrerschein_kl` - License class
- ❌ **NO `mobil_tel_n` field** - Phone number missing!

**Result:** Phone only available AFTER vehicle assignment, not during driver search.

### The Solution Path

**Add phone number to driver master data:**

```sql
-- Option 1: Extend existing table
ALTER TABLE fahrer
ADD COLUMN mobil_tel_n varchar(112);  -- encrypted

-- Option 2: Separate contact table
CREATE TABLE fahrer_kontakt (
    firmennummer numeric(3,0) NOT NULL,
    niederlassung numeric(2,0) NOT NULL,
    fahrer_schluessel numeric(3,0) NOT NULL,
    mobil_tel_n varchar(112),  -- encrypted
    PRIMARY KEY (firmennummer, niederlassung, fahrer_schluessel),
    FOREIGN KEY (firmennummer, niederlassung, fahrer_schluessel)
        REFERENCES fahrer
);
```

**Then enhance SetDriver() with fallback:**
1. Use provided phone (if given)
2. Fall back to `fahrer.mobil_tel_n` (NEW!)
3. Fall back to vehicle's `sap_phone_no`

**Outcome:** Driver search can provide phone immediately, making vehicle assignment optional for phone availability.
