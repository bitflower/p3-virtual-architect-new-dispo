**PBI**: #120244
**WHO**: As a user, I want to edit the comment field on a Transport Order so that I can add and store any relevant notes or additional information.
**Description**: Enables users to freely view, add, or edit text in the **comment field** of a Transport Order. The field supports single or multiline text up to 255 characters and is intended for unstructured information. When the user changes the text, the system automatically triggers an update request to save it. No validation, formatting, or auto-suggestion is applied. The updated comment is immediately reflected in the user interface.

**Actors**: User

**Triggers**:
*   The user edits the comment field on a Transport Order.  
*   A change in the field’s content is detected.
    
**Preconditions**:
*   A Transport Order exists and is editable by the user.  
*   The comment field is visible and accessible.
    
**Postconditions**:
*   The new comment text (up to 255 characters) is saved to the Transport Order.  
*   The updated comment is displayed in the UI.
*   No request is sent if the content does not change. 
*   No additional validation or transformation occurs.

**Technical Solution:**

**Database:** `TEXT_SENDUNG.S_TEXT` (VARCHAR 255)

**Read:**
- LATERAL JOIN from `sendung` → `TEXT_SENDUNG` via `sendung_tix`
- Filter: `TYP = 'TA1'`, ordered by `laufende_nummer ASC LIMIT 1`
- Add to `v_dis_transportorder` (no performance hit expected – no functions involved)

**Write:**
- `INSERT`/`UPDATE` on `text_sendung.s_text`
- Where: `sendung_tix = <TransportOrderID>`, `TYP = 'TA1'`, `laufende_nummer = 1`
- New procedure to be created: `pDis_TransportOrder.SetComment(TransportOrderId NUMERIC, Comment VARCHAR(255))`

#### TMS Interfaces

*None required*

**Constraints:**

- Max 255 characters (DB field limit)
- Only first comment entry (`laufende_nummer = 1`) is displayed/editable

The business requirements have been aligned with **Maximilian Beisheim**.
The technical solution design has been aligned with **Joachim Schreiner**.
All code including backends and frontend of this story is developed by P3.
The database code is developed by CAL / Joachim Schreiner.