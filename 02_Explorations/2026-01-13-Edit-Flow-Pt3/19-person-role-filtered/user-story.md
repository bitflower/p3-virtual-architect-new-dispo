**WHO**: As a dispatcher, I only want to have contractor/carrier available to select from for the designated field, when I add a contractor/carrier, so that I don't accidentially assign (or can accidentially try to assign) a wrong person to a non matching role.

**Description**: The dispatcher can only select valid entities for each designated field when assigning participants to a transport order. In the "Contractor" and "Carrier" fields, only corresponding entity types are available for selection (e.g., only carriers appear in the carrier field). For contractors and carriers, both `UNN` (Unternehmer Nahverkehr) and `UNF` (Unternehmer Fernverkehr) are shown in the lookup. If a person has both contractor roles (`UNN` and `UNF`), they appear only once in the selection to avoid duplicates. When assigned, the first found role is used. This ensures that the dispatcher cannot accidentally assign an incorrect role and avoids system errors or validation issues during assignment. As a result, the data remains consistent, and the assignment process runs smoothly without interruptions or error messages.

**Actors**: Dispatcher

**Triggers**: Dispatcher adds or modifies a contractor or carrier.

**Preconditions**:
*   The transport order is open for editing.
*   Master data for contractors and carriers exists in the system.
    
**Postconditions**:
*   Only valid, role-specific entities can be selected in each field.
*   The dispatcher cannot assign incompatible entity types to a field.
*   Persons with multiple contractor roles (`UNN` and `UNF`) appear only once in the lookup.
*   The system stores the correctly assigned entity according to its role (contractor or carrier).
*   Only one role value per person is set on the transport order (no multiple assignments).

**Technical Solution:**

**Overview:**
This is potentially a **frontend-only change**. The complete stack (Frontend → New Dispo Backend → TMS Bridge GraphQL → `v_pers_tb`) is already in place. Currently, the frontend filters by role code `UNF` only, which excludes valid `UNN` persons from contractor and carrier lookups. The frontend needs to extend its filter to include both `UNN` and `UNF`, and implement client-side deduplication for persons with multiple roles.

**Existing Stack:**

The database view `v_pers_tb` provides person data with role assignments:
* Joins `person` with `person_special` on `pers_tix`
* Exposes `kz_transportbeteil` as `pers_tb` column (contains role codes: `UNN`, `UNF`, etc.)
* Returns all roles per person without deduplication (a person with both `UNN` and `UNF` appears as two rows)
* Includes del_flag filtering and additional fields (address, zones, business logic)

This view is already integrated through: **Frontend → New Dispo Backend → TMS Bridge GraphQL → `v_pers_tb`**

No database, backend, or TMS Bridge changes are required.

**Required Frontend Changes:**

1. **Extend Filter**: Include both role codes `UNN` and `UNF` for contractor and carrier lookups (currently only `UNF`)
2. **Deduplicate Results**: Group by `pers_tix` to show each person only once when they have multiple roles
3. **Assignment Logic**:
   * For contractors: Assign the first found role (`UNN` or `UNF`) from the person's data to the transport order
   * For carriers: Assign role code `FRF` to the transport order

**Business Rules:**

* A person can have multiple roles in `person_special` (different `kz_transportbeteil` values)
* The same person can be both a contractor and a carrier (with different role assignments)
* When a person has multiple contractor roles (`UNN` and `UNF`), they appear once in the lookup and the first found role is used for assignment
* Role code mapping for transport order assignment:
  * Contractors: Use the role from master data (`UNN` or `UNF`)
  * Carriers: Always assign `FRF` (Frachtführer)
* Only one role value per person is assigned to the transport order

**Additional Context:**

* The distinction between `UNN` and `UNF` is expected to lose importance over time as the separation between local and long-distance transport becomes less relevant

The business requirements have been aligned with **Maximilian Beisheim** and **Patrick Uschmann**.
The technical solution design has been aligned with **Joachim Schreiner**.
All code including database, backend and frontend of this story is developed by P3.