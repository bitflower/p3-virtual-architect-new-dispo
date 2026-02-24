**PBI**: #119744
**WHO**: As a dispatcher, I want to assign a trailer to a Transport Order so that the order is correctly linked to the physical trailer used for transport.

**Description**: Allows dispatchers to assign a trailer to a Transport Order from the Transport Order Details page. The user can link the trailer either by entering the **“Schlüsselnummer” (VehicleID)** or by providing the **license plate**. The assignment process mirrors the existing vehicle assignment flow, ensuring a consistent user experience. Once entered, the trailer information is validated and stored within the TMS.

**Actors**: Dispatcher.

**Triggers**:
*   User inputs a trailer’s VehicleID or license plate and unfocusses the trailer field within the Transport Order Details page.

**Preconditions**:
*   A valid Transport Order exists.  
*   The Transport order is editable.
    
**Postconditions**:
*   The trailer is successfully linked to the Transport Order and stored in the TMS.  
*   Assigned trailer data is displayed in the Transport Order.
*   Trailer assignment is independent of carrier/contractor filtering.

**Technical Solution:**
Use existing stored procedure `pDIS_TransportOrder.AddTrailer` - supports both variants:
*   With `TrailerId` (when trailer is known/selected)
*   Without `TrailerId` (lookup by license plate or VehicleID)

**Note:** Recently implemented by Joachim Schreiner in [PR #456](https://github.com/cal-consult/tms-alloydb-schema/pull/456). 
  
**Constraints:**

  
The business requirements have been aligned with **Maximilian Beisheim**.
The technical solution design has been aligned with **Joachim Schreiner**.
All code including database, backends and frontend of this story is developed by P3.
