**PBI**: #119946
**WHO**: As a dispatcher, I want editing of certain Transport Order sections to be blocked once the order reaches final statuses (6 or 7), so past orders cannot be modified and invoicing consistency is preserved.

**Description**: When a Transport Order reaches status 6 or 7, the UI blocks editing in the “General,” “Drive Instructions,” and “Transport Properties” sections. Users cannot modify any fields or perform edit actions on these sections. On the Planning page, the Transport Order slider becomes non-editable (except for forwarding to the details page). A static visual indicator and tooltip inform the user that the Transport Order is locked due to its status.

**Actors**: Accountant, Dispatcher.

**Triggers**:
*   Transport Order changes to status 6 or 7.
*   User opens a Transport Order with status 6 or 7
    - Over the Planning view
    - Over the Transport Order details page

**Preconditions**:
*   A Transport Order exists with status 6 or 7.

**Postconditions**:
*   Editing of the Transport Order sections “General,” “Drive Instructions,” and “Transport Properties” is disabled.
*   The Planning slider (on the Planning view) shows a locked state with disabled edit actions.
*   A static message and tooltip are displayed to explain that the Transport Order is locked and uneditable.

**Technical Solution:**

* **Status check**: Query `pta.getstatus(s1.sendung_tix) as status` from `v_dis_transportorder` view
* **Blocking condition**: `status IN (6, 7)` (BIT-Status based)
* **Frontend**: Disable editing when condition is met

> **Side note:** TMS Core rejects writes on locked orders anyway → New Dispo can not do any harm in case the block should fail for any reason

**Constraints:**



The business requirements have been aligned with **Maximilian Beisheim**.
The technical solution design has been aligned with **Joachim Schreiner**.  
All code including database, backends and frontend of this story is developed by P3.