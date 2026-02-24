# 9. Change Reference

- Entspricht der "Übereinkunft mit dem Kunden, z.b. einen Zeitslot zu buchen"
- Es gibt eine Referenz je Tourpunkt, nicht mehrere

## Technisches Interface

```sql
--
-- Name: SetLoadingReference; Type: procedure; Schema: -; Owner: -
--
create or replace procedure pDIS_TourPoint.SetLoadingReference(
    TourPointId      numeric,
    LoadingReference varchar)
language plpgsql
as $$
   begin
      call ResHst.SetOpt(TourPointId, pTourOrt_Lib.ZUSKEY_LADREF(), LoadingReference);
   end;
$$;


--
-- Name: GetLoadingReference(numeric) ; Type: FUNCTION; Schema: pDIS_TourPoint; Owner: -
--
create or replace function pDIS_TourPoint.GetLoadingReference(TourPointId numeric)
returns varchar
language plpgsql
as $$
   begin
      return ResHst.GetOpt(TourPointId, pTourOrt_Lib.ZUSKEY_LADREF());
   end;
$$;
```

- Löschen mit `NULL` in `SetLoadingReference`