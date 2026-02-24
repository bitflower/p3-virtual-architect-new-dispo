**PBI**: #119685
**WHO**: As a user, I want to change the transport mode using a dropdown menu so that my selection updates instantly and is saved without extra confirmation steps.

**Description**: Enables users to view and update the **transport mode** of a Transport Order via a dropdown field showing only readable mode names (not IDs). Upon selection of a new mode, the dropdown closes automatically, and the system immediately saves the new value. If no change is made, no request is sent. When saving fails, the system displays a visual error message. The current mode always reflects the latest saved value. Changing the transport mode does not affect visibility or planning availability — Transport Orders remain accessible in both the old and new app environments. The user can only select from the following modes:
- 10 - Nur Datentransfer
- 20 - Fernverkehr
- 21 - Begegnungsverkehr
- 22 - One Way
- 23 - Nachtsprung
- 24 - Trampverkehr KVN
- 25 - Sonstige Systemverkehre
- 26 - Teilcharter
- 27 - Selbstabholung
- 28 - FTL
- 60 - Vorholung

> **Note:** Mode 10 (Nur Datentransfer) requires a view filter update – see "Required View Changes" in the technical solution.

**Actors**: User (dispatcher, planner).

**Triggers**:
*   User opens the transport mode dropdown and selects a different transport mode.
    
**Preconditions**:
*   A valid and editable Transport Order exists.
*   Available transport modes are listed and selectable.
    
**Postconditions**:
*   The new transport mode is saved and displayed immediately.  
*   If saving fails, an error indicator is shown, and the previous mode remains visible.
*   The Transport Order stays visible and plannable in both the new and old applications.

**Technical Solution:**

**Database:** `sendung.tran_art` (NUMERIC(2,0)) – Direct field on the Transport Order, no business logic attached.

**Read:**
- Already exposed via `v_dis_transportorder.transportmode`
- No additional view or function required

**Write:**
- New procedure: `pDis_TransportOrder.SetTransportMode(TransportOrderId NUMERIC, TransportMode NUMERIC)`
- Direct `UPDATE` on `sendung.tran_art` where `sendung_tix = TransportOrderId`
- Validate that `TransportMode` is one of the allowed values (10, 20, 21, 22, 23, 24, 25, 26, 27, 28, 60)

```sql
CREATE OR REPLACE FUNCTION pDis_TransportOrder.SetTransportMode(
    TransportOrderId  NUMERIC,
    TransportMode     NUMERIC
) RETURNS VOID AS $$
BEGIN
    -- Validate transport mode is in allowed list
    IF TransportMode NOT IN (10, 20, 21, 22, 23, 24, 25, 26, 27, 28, 60) THEN
        RAISE EXCEPTION 'Invalid transport mode: %. Allowed values: 10, 20, 21, 22, 23, 24, 25, 26, 27, 28, 60', TransportMode;
    END IF;

    UPDATE sendung
       SET tran_art = TransportMode
     WHERE sendung_tix = TransportOrderId;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Transport Order % not found', TransportOrderId;
    END IF;
END;
$$ LANGUAGE plpgsql;
```

#### Required View Changes

Changing the transport mode value could lead to the Transport Order being filtered out in New Dispo. To address this:

- Update `v_dis_transportorder` to include mode 10 in the filter:
  ```sql
  WHERE ... AND (s1.tran_art = ANY (ARRAY[10::numeric, 20::numeric, 21::numeric, ...]))
  ```
- Update `v_dis_transportorder_filter` with the same change

#### Pickup Planning Visibility

The view `v_dis_transportorder_pickupplanning` currently filters only for mode 60 (Vorholung). When transport modes become editable, the following scenarios must be covered:

1. All Transport Orders with transport mode 60 are plannable and visible on the planning page
2. All Transport Orders created from the New Dispo App remain plannable and visible on the planning page (regardless of transport mode changes)
3. All Transport Orders created via "Vorbelegung" (automatic creation) with transport mode 60 remain plannable and visible

**Expected behavior:** A Transport Order created outside New Dispo with mode changed to 60 becomes visible. If its mode is subsequently changed to something else, it disappears from the planning page (expected).

**Solution:** The existing column `sendung.Quell_K` is set to `'D'` to indicate "created by New Dispo". This is:

- Set by `pDIS_TransportOrder.New` when creating Transport Orders from New Dispo (`UPDATE Sendung SET Quell_K = 'D'`)
- Exposed in `v_dis_transportorder` as `origin` (via `s1.quell_k as origin`)
- To be used in `v_dis_transportorder_pickupplanning` filter logic:

  ```sql
  WHERE (s1.tran_art = 60)                                      -- always show mode 60 (Vorholung)
     OR (s1.quell_k = 'D')                                      -- show other modes only if created by New Dispo
  ```

**Constraints:**

- Only the listed transport modes are allowed

The business requirements have been aligned with **Maximilian Beisheim**.
The technical solution design has been aligned with **Joachim Schreiner**.  
All code including database, backends and frontend of this story is developed by P3.
