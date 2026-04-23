# TMS Bridge Aggregated Query - Tree Navigation (Tour -> Tourpoints -> Sendungen)

**Date:** 2026-04-23
**Status:** Exploration
**Requested by:** Developer (via Slack)

---

## Original User Input

> "Moin, sag mal, gibts ueber die Bridge den einen Supercall wo ich Tour, Tourpunkte + Sendungen bekomme?"

> "Also Einstieg ueber eine ID einer dieser Entitaeten? Und dann den 'Baum' aller zugehoeriger Entitaeten? jo"

---

## Summary

The TMS Bridge **does not currently support** an aggregated "super call" that returns a Tour (TransportOrder) with nested Tourpoints and their Sendungen (shipments) in a single GraphQL query. The three entities are exposed as **independent, flat root queries** without navigation properties between them.

However, the **database fully supports** the required join path. The gap is purely at the Entity/GraphQL layer.

---

## Analysis

### Current GraphQL Capabilities

The TMS Bridge exposes three independent root queries:

| Query | Returns | Nesting |
|---|---|---|
| `getTransportOrders` | `TransportOrderEntity` (51 fields) | flat |
| `getTourpoints` | `TourpointEntity` (38 fields) | flat |
| `getSendungEntities` | `SendungEntity` (17 fields + 6 nav properties) | partial |

Each query requires a `databaseIdentifier` parameter and supports filtering via HotChocolate `[UseFiltering]` and `[UseSorting]`.

**Batching is enabled** (`EnableBatching = true` in Startup.cs), so multiple queries can be sent in one HTTP request, but results must be joined client-side.

### Entity Navigation Properties (Current State)

| From -> To | Property | Status |
|---|---|---|
| TransportOrder -> Tourpoints | - | **MISSING** |
| Tourpoint -> TransportOrder | - | **MISSING** (only `TransportOrderId` FK field exists) |
| Tourpoint -> Sendungen | - | **MISSING** |
| Sendung -> Tourpoint | - | **MISSING** |
| Sendung -> SenZuords | `SenZuords` | EXISTS (Sendung-to-Sendung hierarchy) |
| Sendung -> Bordero | `Bordero` | EXISTS |
| Sendung -> Rollkart | `Rollkart` | EXISTS |
| Sendung -> SenLs | `SenLs` | EXISTS |
| Sendung -> PstHsts | `PstHsts` | EXISTS |
| Sendung -> Persons | `Persons` | EXISTS |

**Key insight**: `SenZuord` links Sendung-to-Sendung (hierarchical parent-child), NOT Tourpoint-to-Sendung.

---

## Database Schema

### Join Path: TransportOrder -> Tourpoint -> Sendung

```
TransportOrder (sendung table, sendungsart='S', PK: sendung_tix)
  |
  +--[res_hst.ref_tix = sendung_tix]-->
  |
  Tourpoint (res_hst table, PK: res_hst_tix)
    |
    +--[res_hst_zus.res_hst_tix, art=101, typ=100, key::numeric]-->
    |
    Sendung (sendung table, PK: sendung_tix)
```

### Critical Linking Table: `res_hst_zus`

The connection Tourpoint <-> Sendung runs through the generic key-value table `res_hst_zus`:

```sql
-- From V_DIS_TO_TOURPOINT.sql
left join (
    select
        z.res_hst_tix,
        s.gewicht,
        s.volstpl_c,
        s.sendung_tix,
        s.bodenstpl_c,
        s.prod_grp,
        s.status_8
    from res_hst_zus z
    join sendung s on z.key::numeric = s.sendung_tix
    where z.art = 101::numeric
      and z.typ = 100::numeric
      and z.key is not null
) r on h.res_hst_tix = r.res_hst_tix
```

This is an **implicit many-to-many** relationship: one Tourpoint can have multiple Sendungen.

### Entity-to-Table/View Mappings

| Entity | Mapped To | Type |
|---|---|---|
| `TransportOrderEntity` | `v_dis_transportorder` | View |
| `TourpointEntity` | `v_dis_to_tourpoint` | View |
| `SendungEntity` | `sendung` | Table |
| `SenZuordEntity` | `sen_zuord` | Table |

---

## Source Code Evidence

### Entity Files

- `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/Data/Entities/TransportOrder/TransportOrderEntity.cs` - 51 scalar properties, no navigation properties
- `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/Data/Entities/Tourpoint/TourpointEntity.cs` - 38 scalar properties, no navigation properties
- `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/Data/Entities/Sendung/SendungEntity.cs` - 17 scalar properties + 6 navigation properties (none to Tourpoint)
- `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/Data/Entities/SenZuord/SenZuordEntity.cs` - Links Sendung-to-Sendung (not Tourpoint-to-Sendung)

### Query Files

- `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/GraphQL/Queries/TransportOrderQuery.cs`
- `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/GraphQL/Queries/TourpointQuery.cs`
- `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/GraphQL/Queries/Sendung/SendungQuery.cs`

### Configuration

- `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/Startup.cs` - GraphQL setup with HotChocolate, batching enabled
- `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/Data/DbContexts/BranchDbContext.cs` - Entity-to-table/view mappings

### Database Views

- `Code/tms-alloydb-schema/src/sql/view/V_DIS_TRANSPORTORDER.sql`
- `Code/tms-alloydb-schema/src/sql/view/V_DIS_TO_TOURPOINT.sql`

---

## Findings

### 1. No "Supercall" exists today

The GraphQL API only supports flat, independent queries per entity type. No nested tree navigation is possible.

### 2. Database supports full tree navigation

All required joins exist at the database level. The gap is purely in the Entity/GraphQL layer.

### 3. Tourpoint -> Sendung link uses generic key-value table

The `res_hst_zus` table with `art=101, typ=100` is the linking mechanism. This non-standard FK pattern is why navigation properties were never added.

### 4. Tourpoint only exposes aggregated shipment data

Currently, `TourpointEntity` has `ShipmentAmount`, `PackageAmount`, `Weight` etc. as aggregated sums -- not individual Sendung references.

### 5. Three implementation options identified

| Option | Approach | Effort | EF Purity | Performance |
|---|---|---|---|---|
| **A: Custom Resolvers** | `[ExtendObjectType]` with raw SQL | Low-Medium | Low | Medium |
| **B: Junction Entity** | New `ResHstZusEntity` + EF relationships | Medium | High | Medium |
| **C: DataLoaders** | Batch loading to prevent N+1 | Add-on to A or B | N/A | High |

**Recommended**: Option A (custom resolvers) + Option C (DataLoaders) for pragmatic implementation with good performance.

### Option A - Custom Resolver Example

```csharp
[ExtendObjectType(typeof(TourpointEntity))]
public class TourpointResolvers
{
    public async Task<List<SendungEntity>> GetSendungen(
        [Parent] TourpointEntity tourpoint,
        [Service] IDbContextProvider<BranchDbContext> dbContextProvider,
        [ScopedState("DatabaseIdentifier")] string databaseIdentifier)
    {
        var dbContext = await dbContextProvider.GetDbContextAsync(databaseIdentifier);

        return await dbContext.Sendungs
            .FromSqlRaw(@"
                SELECT s.*
                FROM sendung s
                JOIN res_hst_zus z ON z.key::numeric = s.sendung_tix
                WHERE z.res_hst_tix = {0}
                  AND z.art = 101
                  AND z.typ = 100
            ", tourpoint.TourpointId)
            .ToListAsync();
    }
}
```

### Target Query Shape (after implementation)

```graphql
query GetTourWithDetails {
  getTransportOrders(
    databaseIdentifier: "D-ABC-001"
    where: { transportOrderId: { eq: 123456 } }
  ) {
    transportOrderNumber
    loadingDate
    status
    tourpoints {
      sequenceNumber
      name1
      street
      postalCode
      city
      sendungen {
        sendungTix
        sendungN
        absendName1
        leistungsDatum
      }
    }
  }
}
```

---

## Questions/Open Items

- [ ] Is this a feature request or just an exploratory question?
- [ ] Which direction of tree navigation is most important? (Tour -> down, or Sendung -> up?)
- [ ] Are individual Sendung details needed, or are the aggregated values on Tourpoint (ShipmentAmount, Weight) sufficient?
- [ ] Performance requirements: How many Tourpoints/Sendungen per Tour are typical?
- [ ] Should the reverse direction (Sendung -> Tourpoint -> Tour) also be supported?
- [ ] Multi-tenant consideration: Does the `databaseIdentifier` scoping work correctly with custom resolvers?

---

## Related Files

- `Code/Disposition-Abstraction-Layer/` - TMS Bridge codebase
- `Code/tms-alloydb-schema/src/sql/view/` - Database view definitions
- `Code/tms-alloydb-schema/src/sql/table/res_hst_zus.sql` - Junction table definition

## Related User Stories/Tasks

- None identified yet -- pending clarification if this becomes a feature request
