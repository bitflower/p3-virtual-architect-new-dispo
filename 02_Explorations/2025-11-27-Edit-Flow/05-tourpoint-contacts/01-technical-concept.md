# 5. Edit Tourpoint Contact Data

| **User Stories**                                                                                                                                                                              |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [119752: Edit Flow – 14.1 Edit Tour Point Data I Changing Tourpoint data of an existing Tourpoint (TMS as source)](https://dev.azure.com/p3ds/Nagel-CAL%20Disposition/_workitems/edit/119752) |

> **Note:** This flow updates the existing `PERS` record linked to a tourpoint. The `PERS` record for a tourpoint always exists - we only update it, never create a new one. Loading and Unloading tourpoints are excluded from this edit flow. Manually entered data is stored only on the transport order level, not in master data tables.

> **Note:** The exact tech-stack implementation is to be decided during implementation, e.g. what logic will be in Backend, TMS Bridge, and TMS Database.

## End-to-End Flow

:::mermaid
sequenceDiagram
    actor User as Dispatcher
    participant FE as Frontend
    participant BE as Backend
    participant Bridge as TMS Bridge
    participant TMS as TMS Database

    title Edit Tourpoint Contact Data

    User->>FE: Type in tourpoint Name1 field
    activate FE

    loop Fuzzy Search (on keystroke)
        FE->>BE: Search tourpoint (fuzzy)
        activate BE
        BE->>Bridge: Query person table
        activate Bridge
        Bridge->>TMS: SELECT FROM person (fuzzy match)
        activate TMS
        TMS-->>Bridge: Matching candidates
        deactivate TMS
        Bridge-->>BE: Candidates list
        deactivate Bridge
        BE-->>FE: Candidates (pers_n, name1, name2, country, zip, city, street)
        deactivate BE
    end

    alt Candidate Selected
        User->>FE: Select candidate from list
        FE->>FE: Auto-populate all address fields
        Note over FE: Fields (except reference, name, tournumber) become read-only
    else Manual Entry
        User->>FE: Enter address manually
        loop Validate Location Fields (onBlur)
            FE->>BE: Validate country/zip/city/street
            BE->>Bridge: Check location exists
            Bridge->>TMS: Query location tables
            TMS-->>Bridge: Location valid/invalid
            Bridge-->>BE: Validation result
            BE-->>FE: Valid / Invalid (show red border if invalid)
        end
    end

    User->>FE: Confirm / Save tourpoint
    FE->>FE: Validate required fields

    alt All Required Fields Valid
        FE->>BE: Save tourpoint contact to Transport Order
        activate BE
        BE->>Bridge: setTourpointContact(tourpointTix, contactData)
        activate Bridge
        Bridge->>TMS: BEGIN
        activate TMS

        rect rgb(230, 245, 230)
            Note over TMS: Update existing PERS record
            TMS->>TMS: Get existing PERS via RES_HST_ZUS (typ=999, key='PERS_TIX')
            TMS->>TMS: UPDATE pers SET name1=?, str=?, ... WHERE tix=nPersTix
        end

        alt Success
            TMS->>TMS: COMMIT
            TMS-->>Bridge: Return pers.tix
        else Error
            TMS->>TMS: ROLLBACK
            TMS-->>Bridge: Return error
        end

        deactivate TMS
        Bridge-->>BE: Result
        deactivate Bridge
        BE-->>FE: Success / Error
        deactivate BE
        FE-->>User: Show confirmation
    else Missing Required Fields
        FE-->>User: Show validation error (red borders)
    end

    deactivate FE
:::

## 1. Tourpoint Contact Look Up

All look ups will be sourced from the table `person` (which represents the TMS master data and is synced periodically with the CMD (Central Master Data)).

> **Note:** The keystroke search loop may be cached on Frontend or Backend level. Not every keystroke necessarily triggers a round-trip to the TMS database.

:::mermaid
sequenceDiagram
    actor User as Dispatcher
    participant FE as Frontend
    participant BE as Backend
    participant Bridge as TMS Bridge
    participant TMS as TMS Database

    User->>FE: Type in tourpoint Name1 field (e.g. "Helmut Log")
    activate FE

    loop On each keystroke
        FE->>BE: searchTourpointContact(searchTerm)
        activate BE
        BE->>Bridge: Fuzzy search request
        activate Bridge
        Bridge->>TMS: SELECT FROM person WHERE name_1 ILIKE '%searchTerm%'
        activate TMS
        Note over TMS: Returns: pers_n, name_1, name_2, land_sitz, plz_sitz, ort_sitz, strasse
        TMS-->>Bridge: Matching candidates
        deactivate TMS
        Bridge-->>BE: Candidates list
        deactivate Bridge
        BE-->>FE: Candidates for dropdown
        deactivate BE
        FE-->>User: Show dropdown with candidates
    end

    alt User selects candidate
        User->>FE: Click on candidate
        FE->>FE: Auto-populate all address fields
        Note over FE: Fields become read-only (except reference, name, tournumber)
    else User continues typing (no selection)
        Note over FE: Fields remain editable for manual input
    end

    deactivate FE
:::

### Candidate Display Fields

Each suggestion displays the following fields to help identify the correct tourpoint:

| Field   | Description    |
| ------- | -------------- |
| Name1   | Primary name   |
| Name2   | Secondary name |
| Country | Country code   |
| ZIP     | Postal code    |
| City    | City name      |
| Street  | Street address |

## 2. Manual Entry with Cascading Validation

When no candidate is selected, the user can manually enter location data. Each field is validated against the TMS database with cascading dependencies.

:::mermaid
sequenceDiagram
    actor User as Dispatcher
    participant FE as Frontend
    participant BE as Backend
    participant TMS as TMS Database

    User->>FE: Enter Country (e.g. "DE")
    FE->>BE: searchCountry("DE")
    BE->>TMS: SELECT FROM location WHERE land ILIKE 'DE%'
    TMS-->>BE: ["Germany (DE)", "Denmark (DK)"]
    BE-->>FE: Suggestions
    FE-->>User: Show country suggestions
    User->>FE: Select "Germany (DE)"
    Note over FE: Country validated, no red border

    User->>FE: Enter ZIP (e.g. "50")
    FE->>BE: searchZip("50", country="DE")
    BE->>TMS: SELECT FROM location WHERE land='DE' AND plz ILIKE '50%'
    TMS-->>BE: ["50667", "50668", "50670", ...]
    BE-->>FE: ZIP suggestions filtered by country
    FE-->>User: Show ZIP suggestions
    User->>FE: Select "50667"

    User->>FE: Enter City (e.g. "Köln")
    FE->>BE: searchCity("Köln", country="DE", zip="50667")
    BE->>TMS: SELECT FROM location WHERE land='DE' AND plz='50667' AND ort ILIKE 'Köln%'
    TMS-->>BE: ["Köln"]
    BE-->>FE: City suggestions filtered by country and ZIP
    User->>FE: Select "Köln"

    User->>FE: Enter Street (free text allowed)
    FE->>BE: searchStreet("Domkloster")
    BE->>TMS: SELECT DISTINCT strasse FROM person WHERE strasse ILIKE 'Domkloster%'
    TMS-->>BE: ["Domkloster 1", "Domkloster 2", ...]
    BE-->>FE: Street suggestions (not mandatory to match)
    Note over FE: Street can be free text - no validation required
:::

### Validation Rules per Field

| Field   | Validation                                                    | On Invalid                      |
| ------- | ------------------------------------------------------------- | ------------------------------- |
| Country | Must match exactly one entry in TMS location table            | Red border, treated as empty    |
| ZIP     | Must exist in TMS (filtered by selected country if present)   | Red border, treated as empty    |
| City    | Must exist in TMS (filtered by country and/or ZIP if present) | Red border, treated as empty    |
| Street  | Fuzzy suggestions from TMS, but free text input allowed       | No validation, can be any value |

### Required Fields for Manual Entry

All of the following must be populated and valid for the save request to be sent:

- Name (Name1)
- Country (Land)
- ZIP code (PLZ)
- City (Stadt)
- Street (Straße)

## 3. Update Tourpoint Contact

The tourpoint contact is updated by modifying the existing `PERS` record that is already linked to the tourpoint via `RES_HST_ZUS`. The `PERS` record always exists for a tourpoint.

:::mermaid
sequenceDiagram
    participant UI as UI / API
    participant FN as updateTourpointContact()
    participant RES_HST_ZUS as res_hst_zus
    participant PERS as pers

    UI->>FN: updateTourpointContact(nResHstTix, contactData)

    Note over FN: contactData from UI or person lookup

    FN->>RES_HST_ZUS: Get PERS_TIX from res_hst_zus WHERE res_hst_tix=? AND typ=999 AND key='PERS_TIX'
    RES_HST_ZUS-->>FN: nPersTix (existing PERS record)

    FN->>FN: Build update values from contactData

    FN->>PERS: UPDATE pers SET name1=?, name2=?, str=?, sitz_land=?, sitz_plz=?, sitz_ort=? WHERE tix=nPersTix
    Note over PERS: Update audit fields (U_Time, U_User)
    PERS-->>FN: success

    FN-->>UI: success
:::

### Steps (Update existing PERS)

1. Receive `nResHstTix` (Tourpoint), and `contactData` from UI/API
2. Retrieve existing `PERS.tix` via `RES_HST_ZUS` (typ=999, key='PERS_TIX')
3. Build update values from `contactData` (name1, name2, street, city, zip, country)
4. Update the existing `PERS` record:
   - Update address fields (name1, name2, str, sitz_land, sitz_plz, sitz_ort)
   - Update audit fields (`U_Time`, `U_User`)
   - If candidate was selected: also update `pers_tix` FK to reference the master data

## Data Model

:::mermaid
erDiagram
    V_TOUR ||--o{ RES_HST : "has tourpoints"
    RES_HST ||--o{ RES_HST_ZUS : "has additional data"
    RES_HST_ZUS ||--o| PERS : "references contact"
    PERS }o--|| PERSON : "copies from"

    V_TOUR {
        numeric tour_tix PK
        varchar tour_nr
    }

    RES_HST {
        numeric res_hst_tix PK
        numeric ref_tix FK "Tour reference"
        numeric typ "Tourpoint type"
        numeric art "Tourpoint art"
    }

    RES_HST_ZUS {
        numeric res_hst_tix PK,FK
        numeric lfd_n PK
        numeric typ "999 = OPT (pTourOrt_Lib)"
        varchar key "PERS_TIX"
        varchar t "value (PERS.tix)"
    }

    PERS {
        numeric tix PK
        numeric pers_tix FK
        varchar name1
        varchar name2
        varchar str
        char sitz_land
        varchar sitz_plz
        varchar sitz_ort
    }

    PERSON {
        numeric pers_tix PK
        varchar name_1
        varchar name_2
        varchar strasse
        char land_sitz
        varchar plz_sitz
        varchar ort_sitz
    }
:::

## Constants (pTourOrt_Lib)

```sql
-- Property Type for tourpoint contact (res_hst_zus.typ)
ZUSTYP_OPT()  = 999  -- Options type

-- Property Key for PERS reference (res_hst_zus.key)
'PERS_TIX'  -- Key to store the PERS TIX reference
```

## Field Mapping: PERSON to PERS

When a candidate is selected from the `person` master data table, the values are copied to the existing `pers` record:

| PERSON (master) | PERS (transport order) | Description    |
| --------------- | ---------------------- | -------------- |
| `pers_tix`      | `pers_tix`             | Master data FK |
| `name_1`        | `name1`                | Primary name   |
| `name_2`        | `name2`                | Secondary name |
| `land_sitz`     | `sitz_land`            | Country code   |
| `plz_sitz`      | `sitz_plz`             | Postal code    |
| `ort_sitz`      | `sitz_ort`             | City           |
| `strasse`       | `str`                  | Street         |

## Read Tourpoint Contact

Tourpoint contact data can be read via the `V_TOUR` view which joins with the `PERS` table through `RES_HST_ZUS`.

:::mermaid
sequenceDiagram
    participant UI as UI / API
    participant Bridge as TMS Bridge
    participant TMS as TMS Database

    UI->>Bridge: getTourpointContact(tourpointTix)

    Bridge->>TMS: SELECT p.* FROM pers p<br/>JOIN res_hst_zus z ON z.t = p.tix::varchar<br/>WHERE z.res_hst_tix = ? AND z.typ = 999 AND z.key = 'PERS_TIX'
    activate TMS

    TMS-->>Bridge: PERS record (name1, name2, sitz_land, sitz_plz, sitz_ort, str)
    deactivate TMS

    Bridge-->>UI: TourpointContactDTO
:::

## Validation Rules

1. **Candidate Selection Mode:**
   - All fields auto-populated from selected candidate
   - Fields (except reference, name, tournumber) become read-only
   - No additional validation required

2. **Manual Entry Mode:**
   - **Country:** Must match exactly one entry in TMS database
   - **ZIP:** Must exist in TMS (filtered by country if selected)
   - **City:** Must exist in TMS (filtered by country and/or ZIP if selected)
   - **Street:** Free text allowed, fuzzy suggestions provided
   - **Name:** Required, free text

3. **onBlur Validation:**
   - Each field validated when user leaves it
   - Invalid fields receive red border
   - Invalid fields treated as empty for subsequent validations

4. **Save Conditions:**
   - All required fields must be populated
   - Country, ZIP, City must be validated against TMS database
   - Street can be any value

## Behavior Summary

| Scenario                      | Field State             | Data Storage                             |
| ----------------------------- | ----------------------- | ---------------------------------------- |
| Candidate selected            | Read-only (most fields) | Update existing PERS from PERSON         |
| Manual entry, all valid       | Editable                | Update existing PERS (transport order)   |
| Manual entry, invalid field   | Red border on field     | Save blocked until corrected             |
| Field changed after candidate | Re-enables manual mode  | Clear candidate reference, allow editing |

## Error Handling

| Error Case                    | Action                             |
| ----------------------------- | ---------------------------------- |
| Invalid tourpoint TIX         | Return error, no changes           |
| Missing required fields       | Show validation errors, block save |
| Invalid country/zip/city      | Show red border, treat as empty    |
| Database constraint violation | Rollback transaction, return error |
| Save fails                    | Show error, revert to last saved   |

## References

- Reference view: `V_TOUR` (shows how tourpoint = `res_hst` is linked to `PERS`)
- Resolution via: `RES_HST_ZUS` with `typ = 999` and `key = 'PERS_TIX'`
- Constants from: `pTourOrt_Lib`
