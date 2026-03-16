# Visual Grouping of Transport Orders by Vehicle

The UI of the planning view is based on grouping of transport order by vehicle. The challenge for the implementation is that the source view `v_dis_transportorder` is slow beyond 30-50 records (which is usually reached within a day).

## Rules

These rules apply to make the use case work

1. A date/time range is selected by the **user**.
2. The date range defines which transport orders must be considered for the context of grouping.
3. The total list of matching transport order that fit the date range is **not** what must be loaded immediately but what must be used to build the visual grouping (=aka sorting by the vehicle invormation and build the logial gropus from it).
4. **User sorting & filtering** must apply in any case

## Solution Proposal

1. **Master Filter**: The date range has a rank "above" all other filters and is applied to a non-expensive version of the `v_dis_transportorder`.

> We can discuss if the `v_dis_transportorder_filter`is a good fit. It **MUST** contain the vehicle column(s) though.

2. The resulting list of transport orders is sorted by `NULL` and then vehicle information. After that the user sorting and filtering is applied in the same `SELECT`.

> The `NULLS FIRST` approach lists the transport orders without vehicle assignment first

3. The result set for the pagination is built using a `page_size` property, e.g. 5 if we assume that on a regular screen we can list 5 planning cards.

> The planning card is the visual container with the 6,12,24h selector, the transport order "cards" at the top and the vehicle information (license plate) on the left)

4. The list of planning cards is built from the "cheap" filter view result list:
   a. If for example we have 5 transport orders without a vehicle assigned we only use these 5 TIX and return them (No vehicle grouping).
   b. If we have for example 15 transport orders out of which 2 have no vehicle assigned, we take these 2 and add the next next transport orders until the vehicle identifier changes the **4th time**. The creates let's say 7 more transport orders in **clusters** of vehicles with 2, 2 and 3 transport orders in to - in total a result set of 9 transport orders.

```csv
TIX       LICENSEPLATE
55667788  NULL
33445566  NULL
66447788  BB-LM 445 => First vehicle cluster change (from NULL to actual license plate)
66884455  BB-LM 445
55785566  HN-XX 666 => Second vehcile cluster change
11224455  HN-XX 666
66448899  GT-TZ 476 => Thrird vehicle cluster change
44558899  GT-TZ 476
34344555  GT-TZ 476
55778899  BN-DL 976 => STOP HERE as we have reached: 5 planning cards (2 NULLs and 3 vehicles)
```

5. With this list of TIX (which should already be ordered like in the transport order list view with the sub query approach) we make the call the expensive `v_dis_transportorder`.
