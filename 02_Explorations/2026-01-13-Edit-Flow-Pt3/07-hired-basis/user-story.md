**PBI**: #119746
**WHO**: As a user, I want to check or uncheck the **“received on a hired basis”** transport order properties so that I can accurately indicate which assets are received on hire.

**Description**: Users can manage the **“received on a hired basis”** status for four transport asset types on a Transport Order using individual checkboxes. The available options are **Auflieger (semi-trailer)**, **Anhänger (trailer)**, **Container**, and **Wechselbrücke (swap body)**. Each checkbox can be toggled independently, triggering immediate validation and persistence of the updated state to the TMS. If the save or validation fails, the UI reverts the change and displays an error notification. Upon reopening the Transport Order, the correct current statuses are reloaded and displayed.

**Actors**: User (dispatcher)

**Triggers**:
*   User checks or unchecks one or more "received on a hired basis" checkboxes in the Transport Order.

**Preconditions**:
*   A valid Transport Order exists and is editable.
*   The current “received on a hired basis” statuses are loaded.
    
**Postconditions**:
*   The modified property is validated and saved in the TMS immediately.  
*   The Transport Order UI reflects the new status for the updated asset type.
*   In case of validation or system failure, the previous state is restored and an error is displayed.

**Technical Solution:**

**Database:** `sen_frk_unt.anh_leihw_k`, `sen_frk_unt.anh_wb_leihw_k`, `sen_frk_unt.con_leihw_k`

| Field            | Type           | Description                                    | English                                            |
| ---------------- | -------------- | ---------------------------------------------- | -------------------------------------------------- |
| `anh_leihw_k`    | `numeric(1,0)` | Bitmask: 1 = Auflieger, 2 = Anhänger, 3 = both | Bitmask: 1 = semi-trailer, 2 = trailer, 3 = both   |
| `anh_wb_leihw_k` | `numeric(1,0)` | Wechselbrücke hired (0/1)                      | Swap body hired (0/1)                              |
| `con_leihw_k`    | `numeric(1,0)` | Container hired (0/1)                          | Container hired (0/1)                              |

**Read:**
*   Add 4 boolean columns to `v_dis_transportorder` by resolving the bitmask:

```sql
CASE WHEN (anh_leihw_k & 1) = 1 THEN 1 ELSE 0 END AS semitrailer_hired,
CASE WHEN (anh_leihw_k & 2) = 2 THEN 1 ELSE 0 END AS trailer_hired,
COALESCE(anh_wb_leihw_k, 0) AS swapbody_hired,
COALESCE(con_leihw_k, 0) AS container_hired
```

**Write:**
*   New procedure: `pDis_TransportOrder.SetHiredBasis(TransportOrderId numeric, SemitrailerHired numeric, TrailerHired numeric, SwapbodyHired numeric, ContainerHired numeric)`

```sql
create or replace procedure pDis_TransportOrder.SetHiredBasis(
    TransportOrderId numeric,
    SemitrailerHired numeric,
    TrailerHired numeric,
    SwapbodyHired numeric,
    ContainerHired numeric
)
language plpgsql
as $$
begin
    UPDATE sen_frk_unt
    SET anh_leihw_k = SemitrailerHired + (TrailerHired * 2),
        anh_wb_leihw_k = SwapbodyHired,
        con_leihw_k = ContainerHired,
        u_version = cal_util.getuversion(u_version),
        u_time = pta.gete(),
        u_user = 'TMS'
    WHERE sen_tix = TransportOrderId;
end;
$$;
```

**Constraints:**
*   `u_version` MUST be updated using `cal_util.getuversion(u_version)` to prevent Uniface sync conflicts


The business requirements have been aligned with **Maximilian Beisheim**.
The technical solution design has been aligned with **Joachim Schreiner**.
All code including database, backend and frontend of this story is developed by P3.