# 1. Change Carrier (TMS as source)

| **User Stories**                                                                                                                    |
| ----------------------------------------------------------------------------------------------------------------------------------- |
| [119737: Edit Flow – 3.1 Change Carrier (TMS as source)](https://dev.azure.com/p3ds/Nagel-CAL%20Disposition/_workitems/edit/119737) |

## Management Summary

This feature allows dispatchers to change the carrier ("Frachtführer") on a Transport Order. The implementation uses a new procedure `pDis_TransportOrder.SetCarrier`.

**Key decisions:**
- Only store address data on the Transport Order (no side effects like truck/trailer removal, billing recalculation, status updates)
- Carrier lookup uses the `person` master data table
- Contact type `UNF` (Unternehmer Fracht / Freight Contractor) is used for carriers

## 1. Contact Look Up & Validation

All look ups will be sourced from the table `person` (which represents the TMS master data and is synced periodically with the CMD (Central Master Data)).

### 1.1 Person Search

> **Note:** The keystroke search loop may be cached on Frontend or Backend level. Not every keystroke necessarily triggers a round-trip to the TMS database. A cache in the Backend (e.g. Redis or in-memory) can significantly reduce database load by storing frequently accessed `person` records and search results.

:::mermaid
sequenceDiagram
    actor User as Dispatcher
    participant FE as Frontend
    participant BE as Backend
    participant Bridge as TMS Bridge
    participant TMS as TMS Database

    User->>FE: Type in carrier name field (e.g. "Helmut Log")
    activate FE

    loop On each keystroke
        FE->>BE: searchCarrier(searchTerm)
        activate BE
        BE->>Bridge: Fuzzy search request
        activate Bridge
        Bridge->>TMS: SELECT FROM person WHERE name1 ILIKE '%searchTerm%'
        activate TMS
        Note over TMS: Returns: pers_n, name1, country, zip, city, street
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
        Note over FE: Fields become read-only (except email, name)
    else User continues typing (no selection)
        Note over FE: Fields remain editable for manual input
    end

    deactivate FE
:::

### 1.2 Location Validation

When no candidate is selected from the carrier lookup, the user can manually input address fields. To ensure data consistency with TMS master data, the combination of **Country**, **ZIP code**, and **City** must be validated against the `ort` table in the TMS database before the carrier can be saved.

**Required fields for manual input:**
- Name (free text)
- Country (must exist in TMS)
- ZIP code (must exist in TMS)
- City (must exist in TMS)
- Street (free text)

> **Note:** Manually entered values are only stored on the transport order level (`pers` table) and not persisted in master data tables (`person`).

#### 1.2.1 Country Selection

:::mermaid
sequenceDiagram
    actor User as Dispatcher
    participant FE as Frontend
    participant BE as Backend
    participant Bridge as TMS Bridge
    participant TMS as TMS Database

    User->>FE: Type in Country field (e.g. "D")

    loop On each keystroke
        FE->>BE: searchCountry(searchTerm)
        BE->>Bridge: GraphQL: searchCountry query
        Bridge->>TMS: SELECT DISTINCT FROM ort WHERE land ILIKE '%searchTerm%'
        Note over TMS: Returns: land (country_code)
        TMS-->>Bridge: Matching countries
        Bridge-->>BE: GraphQL response
        BE-->>FE: Candidates list
        FE-->>User: Show dropdown (e.g. "Germany (DE)", "Denmark (DK)")
    end

    alt User selects candidate
        User->>FE: Click on country
        FE->>FE: Set country value
        Note over FE: ZIP/City suggestions now filtered by country
    else No selection
        Note over FE: Field remains empty
    end
:::

#### 1.2.2 Postal Code (ZIP) Selection

:::mermaid
sequenceDiagram
    actor User as Dispatcher
    participant FE as Frontend
    participant BE as Backend
    participant Bridge as TMS Bridge
    participant TMS as TMS Database

    User->>FE: Type in ZIP field (e.g. "506")

    loop On each keystroke
        FE->>BE: searchZIP(searchTerm, selectedCountry?)
        BE->>Bridge: GraphQL: searchZIP query
        Bridge->>TMS: SELECT FROM ort WHERE plz ILIKE '%searchTerm%' [AND land = selectedCountry]
        Note over TMS: Returns: land, plz, ort, bezirk
        TMS-->>Bridge: Matching ZIP codes
        Bridge-->>BE: GraphQL response
        BE-->>FE: Candidates list
        FE-->>User: Show dropdown with country, ZIP, city, district
    end

    alt User selects candidate
        User->>FE: Click on ZIP candidate
        FE->>FE: Auto-populate country, city, district
        Note over FE: All related fields updated
    else No selection
        Note over FE: Field remains empty
    end
:::

#### 1.2.3 City Selection

:::mermaid
sequenceDiagram
    actor User as Dispatcher
    participant FE as Frontend
    participant BE as Backend
    participant Bridge as TMS Bridge
    participant TMS as TMS Database

    User->>FE: Type in City field (e.g. "Köln")

    loop On each keystroke
        FE->>BE: searchCity(searchTerm, selectedCountry?, selectedZIP?)
        BE->>Bridge: GraphQL: searchCity query
        Bridge->>TMS: SELECT FROM ort WHERE ort ILIKE '%searchTerm%' [AND land = selectedCountry] [AND plz = selectedZIP]
        Note over TMS: Returns: land, plz, ort, bezirk
        TMS-->>Bridge: Matching cities
        Bridge-->>BE: GraphQL response
        BE-->>FE: Candidates list
        FE-->>User: Show dropdown with country, ZIP, city, district
    end

    alt User selects candidate
        User->>FE: Click on city candidate
        FE->>FE: Auto-populate country, ZIP, district
        Note over FE: All related fields updated
    else No selection
        Note over FE: Field remains empty
    end
:::

#### 1.2.4 Street Input

The street field allows free text input without strict validation.

#### 1.2.5 Validation Flow Summary

:::mermaid
flowchart TD
    A[User enters manual carrier data] --> B{All required fields populated?}
    B -->|No| C[Save button disabled]
    B -->|Yes| D{Country/ZIP/City combination valid in TMS?}
    D -->|No| E[Show validation error]
    D -->|Yes| F[Enable Save button]
    F --> G[Submit to TMS]

    H[User leaves page with unsaved changes] --> I[Show warning: Progress will be lost]
:::

## 2. Store Carrier in Transport Order

Flow for setting or updating the carrier ("Frachtführer") on a Transport Order using the new wrapper function `pDis_TransportOrder.SetCarrier`. This procedure handles writing to `pers` and manages the relationship to the Transport Order via `sen_tb`. The procedure handles both inserting a new carrier and updating an existing one.

:::mermaid
sequenceDiagram
    participant UI as UI
    participant FE as Frontend
    participant BE as Backend
    participant Bridge as TMS Bridge
    participant TMS as TMS Database

    UI->>FE: Save carrier
    FE->>BE: SetCarrier(nSenTix, nPersTix)
    BE->>Bridge: GraphQL: setCarrier mutation
    Bridge->>TMS: pDis_TransportOrder.SetCarrier(nSenTix, nPersTix)

    Note over TMS: nPersTix from person lookup or new contact

    rect rgb(230, 245, 230)
        Note over TMS: Inside TMS Database
        TMS->>TMS: pPers.ADD(rPers) → INSERT/UPDATE pers
        TMS->>TMS: UPDATE/INSERT sen_tb
    end

    TMS-->>Bridge: success
    Bridge-->>BE: GraphQL response
    BE-->>FE: success
    FE-->>UI: Show confirmation
:::

### Steps (using pDis_TransportOrder.SetCarrier)

1. Receive `nSenTix` (Transport Order TIX), `nPersTix` (person TIX) from UI/API
2. Call `pDis_TransportOrder.SetCarrier(nSenTix, nPersTix)` which:
   - Derives `PERS` record from `nPersTix`
   - Calls `pPers.ADD(rPers)` to create/update the `pers` record
   - Creates/updates `sen_tb` link (Transport Order + Contact Type `UNF` + Person)

## Data Model

:::mermaid
erDiagram
    SENDUNG ||--o{ SEN_TB : "has contacts"
    SEN_TB ||--|| PERS : "references"
    PERS }o--|| PERSON : "copies from"

    SENDUNG {
        numeric sendung_tix PK
    }

    SEN_TB {
        numeric sen_tix PK
        char tb PK
        numeric pers_tix FK
    }

    PERS {
        numeric tix PK
        numeric pers_tix FK
        varchar name1
        varchar str
        char sitz_land
        varchar sitz_plz
        varchar sitz_ort
    }

    PERSON {
        numeric pers_tix PK
        varchar name_1
        varchar strasse
        char land_sitz
        varchar plz_sitz
        varchar ort_sitz
    }
:::

## TB (Contact Type) Values

Common values for `sen_tb.tb`:

- `ABS` - Absender (Sender)
- `EMP` - Empfänger (Recipient)
- `UNF` - Unternehmer Fracht (Freight Contractor)
- `UNN` - Unternehmer NV (NV Contractor)

## References

### pDis_TransportOrder.SetCarrier (Draft)

```sql
PROCEDURE SetCarrier(
    nSenTix  IN NUMBER,   -- Transport Order TIX (sendung.tix)
    nPersTix IN NUMBER,   -- Person TIX from person table (NULL for manual input)
    -- Manual input fields (used when nPersTix IS NULL)
    sName    IN VARCHAR2 DEFAULT NULL,
    sCountry IN VARCHAR2 DEFAULT NULL,
    sZIP     IN VARCHAR2 DEFAULT NULL,
    sCity    IN VARCHAR2 DEFAULT NULL,
    sStreet  IN VARCHAR2 DEFAULT NULL
) IS
    rPers    pers%ROWTYPE;
    rPerson  person%ROWTYPE;
    nNewPersTix NUMBER;
BEGIN
    -- Build PERS record
    IF nPersTix IS NOT NULL THEN
        -- Lookup from person master data
        SELECT * INTO rPerson FROM person WHERE pers_tix = nPersTix;

        rPers.pers_tix  := rPerson.pers_tix;
        rPers.name1     := rPerson.name_1;
        rPers.str       := rPerson.strasse;
        rPers.sitz_land := rPerson.land_sitz;
        rPers.sitz_plz  := rPerson.plz_sitz;
        rPers.sitz_ort  := rPerson.ort_sitz;
    ELSE
        -- Manual input (validation already done by caller)
        rPers.pers_tix  := NULL;  -- No master data reference
        rPers.name1     := sName;
        rPers.str       := sStreet;
        rPers.sitz_land := sCountry;
        rPers.sitz_plz  := sZIP;
        rPers.sitz_ort  := sCity;
    END IF;

    -- Create PERS record using pPers.ADD
    -- (handles TIX generation, Firma, NL, audit fields)
    nNewPersTix := pPers.ADD(rPers);

    -- Link to Transport Order via sen_tb
    INSERT INTO sen_tb (sen_tix, tb, pers_tix)
    VALUES (nSenTix, 'UNF', nNewPersTix);

    COMMIT;

END SetCarrier;
```

**Notes:**
- When `nPersTix` is provided, the procedure looks up the carrier from `person` master data
- When `nPersTix` is NULL, the manual input fields are used (location validation must be done before calling)
- No side effects like truck/trailer removal, billing recalculation, or status updates are triggered
