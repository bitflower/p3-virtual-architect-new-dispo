# CR: Changing the Lot Generation Rules — PickupDate to CollectionDate

**Date:** 2026-06-18
**Status:** Exploration
**PBI:** [125087 — CR: Changing the Lot generation rules](https://dev.azure.com/p3ds/Nagel-CAL%20Disposition/_workitems/edit/125087)
**PR (Draft — quick-fix approach):** [#33401 — Switch the mapping for the pickup date from field](https://dev.azure.com/p3ds/Nagel-CAL%20Disposition/_git/Disposition-Backend/pullrequest/33401)
**Participants:** Matthias Max, Boyan Valchev

---

## TL;DR for Refinement

**Problem:** Lot grouping uses `PickupDateFrom` / `PickupDateTo` — but both columns are **always NULL** in the TMS database (verified on abn1034, 2026-06-18: 0 out of 1,128 rows populated for either column, while `CollectionDate` is filled in all 1,128). The client now wants to group by `CollectionDate` instead. This means pickup dates never actually participated in lot grouping — lots were effectively grouped without any pickup date constraint.

**Options:**

| | Approach | Dev Effort | QA Effort | Code Quality |
|---|---|---|---|---|
| **A** | Remap `PickupDateFrom = CollectionDate`, keep `PickupDateTo` (NULL) | ~1h, 2 files | Low | Poor — naming lie across ~70 files, dead column remains |
| **B** | Remove both pickup columns, add `CollectionDate` everywhere | ~4-8h, ~25 prod + ~30 test files | Higher — needs QA alignment | Clean — code matches requirement |
| ~~C~~ | ~~Add `CollectionDate` alongside existing pickup columns~~ | ~~Same as B but worse~~ | ~~Same~~ | ~~Worst — dead fields + new field~~ |

**Recommendation:** Option B (clean removal). The quick fix (A) works functionally — `CollectionDate` correctly enters the grouping logic. But it leaves a naming lie (`PickupDateFrom` holding `CollectionDate` data) across the entire stack that will confuse future developers. Since we're touching core lot generation logic, we should do it right. The main cost is QA, not dev.

**Decision needed:** Is the additional QA effort for Option B acceptable given current timelines?

---

## Context

The lot generation rules currently use two pickup date columns (`PickupDateFrom`, `PickupDateTo`) to group legs into lots.
The client wants to switch to a single column: **`CollectionDate`**.

The requirement from PBI 125087 defines updated lot rules:

- **Rule A:** Same Origin and Destination address of the Legs
- **Rule B:** Same delivery date from, delivery date to, **collectiondate** *(was: pickupdatefrom, pickupdateto)*
- **Rule C:** Productgroup "Frozen" are always separate (productgroup == 4 only matches with 4)

The change applies to 7 areas:
1. Initial Generation of Lots
2. Creation of Lots
3. CDC mechanism
4. Lot assignment merge suggestion
5. Move a leg to another Lot
6. Placing a Leg into a proper Lot (unassigning)
7. Change Lot index

---

## Database Evidence (abn1034)

Queried `tms1034` schema on abn1034 (`10.100.47.236`):

| View | Total Rows | `collectiondate` non-null | `pickupdatefrom` non-null | `pickupdateto` non-null |
|---|---|---|---|---|
| `v_dis_shipment` | 8 | **8 (100%)** | **0 (0%)** | **0 (0%)** |
| `v_dis_shipment_all` | 1,128 | **1,128 (100%)** | **0 (0%)** | **0 (0%)** |

**Both pickup columns are NULL in 100% of rows.** `CollectionDate` is always populated.

Boyan confirmed in the meeting: the pickup columns were "intended to be created from New Dispo, but they're not filled from anywhere." Open question: does the client have plans to ever populate them?

---

## Data Flow: TMS DB → TMS Bridge → Backend

```
TMS DB (abn1034)                    TMS Bridge                         Backend
─────────────────                   ──────────                         ───────
v_dis_shipment_all                  DISShipmentEntity                  PickupPlanningShipmentDto
  .pickupdatefrom  ──────────────►  .PickupDateFrom  ──────────────►  .PickupDateFrom
  .pickupdateto    ──────────────►  .PickupDateTo    ──────────────►  .PickupDateTo
  .collectiondate  ──────────────►  .CollectionDate  ──────────────►  .CollectionDate
```

**TMS Bridge mapping** (`DISShipmentEntityConfiguration.cs`):
```csharp
builder.Property(e => e.PickupDateFrom).HasColumnName("pickupdatefrom");   // → always NULL
builder.Property(e => e.PickupDateTo).HasColumnName("pickupdateto");       // → always NULL
```

---

## Backend Code: Where PickupDateFrom/PickupDateTo Are Used

### Lot Matching (core grouping logic)

**`IsSuitableForLegExtension.cs`** — determines if a leg fits into an existing lot:
```csharp
&& lot.PickupDateFrom == leg.PickupDateFrom
&& lot.PickupDateTo == leg.PickupDateTo
```

**`LotAssignmentSuitableCandidateFilter.cs`** — filters suitable lot assignment candidates:
```csharp
x.PickupDateFrom?.Date == leg.PickupDateFrom?.Date &&
x.PickupDateTo?.Date == leg.PickupDateTo?.Date &&
```

### Lot Generation

**`PickupPlanningLotGenerator.cs`** — groups legs into lots, using pickup dates as grouping key:
```csharp
leg.PickupDateFrom,
leg.PickupDateTo,
// ...
PickupDateFrom = groupRepresentative.PickupDateFrom,
PickupDateTo = groupRepresentative.PickupDateTo,
```

### Mappers

**`LegExtractorsMapper.cs`** — maps shipment data to extracted leg DTO (PR #33401 touches this):
```csharp
PickupDateFrom = src.PickupDateFrom,    // current: always NULL
PickupDateTo = src.PickupDateTo,        // current: always NULL
```

**`CdcEventHandlersMapper.cs`**, **`LotGenerationFieldsMapper.cs`**, **`ShipmentUpdatedMapper.cs`** — CDC event handling chain also maps these fields.

### Full File Impact (non-migration, non-test)

| File | Role |
|---|---|
| `LegExtractorsMapper.cs` | Initial mapping from shipment to leg |
| `CdcEventHandlersMapper.cs` | CDC event mapping |
| `LotGenerationFieldsMapper.cs` | CDC lot generation field resolution |
| `LotGenerationFieldsUpdatedResolver.cs` | CDC change detection for lot fields |
| `ShipmentUpdatedMapper.cs` | CDC shipment update mapping |
| `PickupPlanningLotGenerator.cs` | Lot grouping algorithm |
| `IsSuitableForLegExtension.cs` | Lot-leg suitability check |
| `LotAssignmentSuitableCandidateFilter.cs` | Lot assignment candidate matching |
| `PickupPlanningSuitableLotForLegProvider.cs` | Find suitable lot for a leg |
| `TransportOrderPlanningLotAssignmentAssigner.cs` | TO planning lot assignment |
| `MoveLegIntoLotCommandHandler.cs` | Move leg between lots |
| `CreateLotCommandHandler.cs` | Create new lot |
| `CreateLotAssignmentSubHandler.cs` | Create lot assignment from leg |
| `AssignToLotAssignmentSubHandler.cs` | Assign leg to lot assignment |
| `AssignLotToTransportOrderMapper.cs` | Lot-to-TO assignment mapping |
| `CreateTransportOrderFromLotMapper.cs` | TO creation from lot |
| `InitializePickupPlanningMapper.cs` | Initial pickup planning setup |
| `GetDriveInstructionsMapper.cs` | Drive instructions mapping |
| `LegEntity.cs` | Domain entity |
| `LotEntity.cs` | Domain entity |
| `LotAssignmentEntity.cs` | Domain entity |
| `LotEntityConfiguration.cs` | EF configuration + composite index |
| `LegEntityConfiguration.cs` | EF configuration |
| `LotAssignmentEntityConfiguration.cs` | EF configuration |
| `GoogleBucketShipmentData.cs` | GCS PubSub DTO |

Plus ~30 test files and ~15 migration designer snapshots.

### Database Index Impact

The lot generation composite index includes both pickup columns:
```csharp
HasIndex("OriginName", "OriginCity", "OriginStreet",
         "DestinationName", "DestinationCity", "DestinationStreet",
         "DeliveryDateFrom", "DeliveryDateTo",
         "PickupDateFrom", "PickupDateTo",           // ← affected
         "OnlyFrozenProducts", "BranchKey", "IsSystemGenerated")
```
A clean removal requires a new migration to drop/recreate this index with `CollectionDate` instead.

---

## Impact Analysis: Quick Fix (Option A) on Lot Building Logic

The quick fix (PR #33401) changes the input from `NULL, NULL` to `CollectionDate, NULL`. This section traces the behavioral impact through all three matching locations.

### Before (current state — both NULLs)

Since `PickupDateFrom` and `PickupDateTo` are always NULL, they are **no-ops** in all matching:

| Location | Comparison | Result |
|---|---|---|
| `IsSuitableForLegExtension` | `NULL == NULL` | always `true` — never filters |
| `PickupPlanningLotGenerator.GroupBy` | key = `{null, null}` for all legs | no grouping effect |
| `LotAssignmentSuitableCandidateFilter` | `null?.Date == null?.Date` | always `true` — never filters |

**Today, pickup dates don't participate in lot grouping at all.** Lots are grouped by origin/destination + delivery dates + frozen product flag only.

### After the Quick Fix (PickupDateFrom = CollectionDate, PickupDateTo stays NULL)

`PickupDateFrom` now carries an actual `DateTime` (the CollectionDate). `PickupDateTo` remains NULL.

**`PickupDateFrom` becomes a real grouping dimension where it was previously invisible:**

| Location | Before | After |
|---|---|---|
| `GroupBy` key | `{null, null}` — all legs same bucket | `{2026-06-18, null}` — legs split by CollectionDate |
| `IsLotSuitableForLeg` | `NULL == NULL` → always matches | `CollectionDate_A == CollectionDate_B` → only matches same date |
| `LotAssignmentSuitableCandidateFilter` | `null == null` → always matches | `CollectionDate_A?.Date == CollectionDate_B?.Date` → only matches same date |

**Concrete example:** Two legs with same origin/destination/delivery dates but **different** CollectionDates (e.g. 2026-06-18 vs 2026-06-19) previously landed in the **same lot** (NULL == NULL). After the quick fix, they are split into **separate lots**.

### Functional Verdict

**The quick fix produces correct lot groupings.** The behavioral change (more restrictive matching via CollectionDate) is exactly what PBI 125087 requires — CollectionDate replaces the pickup pair in Rule B. No functional bugs.

### The Risk Is Structural, Not Functional

1. **Naming lie across the stack:** The field is called `PickupDateFrom` in entities, database columns, the composite index, DTOs, and tests — but holds `CollectionDate` data
2. **Dead column:** `PickupDateTo` remains as a permanently NULL column in entities, the composite index, and all matching logic — running `NULL == NULL` comparisons on every match for no reason
3. **Index mismatch:** The composite index on Lot still includes both `PickupDateFrom` (now meaningful) and `PickupDateTo` (always NULL) — the index shape doesn't match intent
4. **Future confusion:** A developer seeing `PickupDateFrom = src.CollectionDate` will question whether this is a bug or intentional. Matthias in the meeting: *"Someone later down the road will say, why do we have pickup date from mapped from collection date and pickup date to from pickup date to? That's a strange change. It confuses people."*

---

## Options Discussed (Meeting 2026-06-18)

### Option A: Quick Fix (PR #33401 — Draft)

Re-map `PickupDateFrom` to `src.CollectionDate`, keep `PickupDateTo` as-is (still NULL).

**Pros:** Minimal code change (2 files), almost no QA effort.
**Cons:** Confusing mapping — `PickupDateFrom` now holds a `CollectionDate` value. Future developers will be confused. Matthias: *"We introduce a mapping that is a confusion in itself."*

### Option B: Clean Removal (Preferred)

Remove both `PickupDateFrom`/`PickupDateTo` columns from entities and all layers. Replace with a single `CollectionDate` column throughout.

**Pros:** Clean code matching the actual requirement. No legacy confusion.
**Cons:** Huge surface area — touches ~25 production files + ~30 test files + ~15 migration snapshots. Requires new EF migration including composite index recreation. Larger QA effort — Boyan: *"The logic should be covered by unit tests, not automation tests"* but *"I don't think they are covered by automation tests."* Bigger testing effort comes from the QA side.

### Option C: Add CollectionDate alongside existing pickup columns

Keep both pickup columns, add `CollectionDate` as new field.

**Discarded** — Boyan: *"It's even worse, because we'll still need to touch the same places"* but with more fields. Dead fields remain.

---

## Decision

**Option B (clean removal) is preferred.** Matthias: *"I really differentiate between operational hacks and logical hacks. Setting up a microservice that temporarily does something — that's fine. But this is the central logic, which we make dirty."*

Agreed approach:
1. Boyan keeps PR #33401 (Option A) as a fallback
2. Boyan spends 1-2 hours implementing the clean approach (Option B)
3. Boyan talks to Vessi (QA) to evaluate the actual testing effort
4. Final decision based on QA effort assessment
5. Matthias offered to run the change through his analysis chain (Virtual Architect) for impact tracing

---

## Open Questions

- [ ] **Client confirmation needed:** Will `pickupdatefrom`/`pickupdateto` ever be populated? Are there plans to use them?
- [ ] **QA effort estimate:** How much additional testing does Option B require? (Boyan to check with Vessi)
- [ ] **Downstream impact:** Do the pickup fields surface in the Frontend or any external API? (affects blast radius of removal)

---

## Related

- **Parent:** [125084 — Change Requests](https://dev.azure.com/p3ds/Nagel-CAL%20Disposition/_workitems/edit/125084)
- **Related (Closed):** [109723 — [BE] Apply rules when creating Lots](https://dev.azure.com/p3ds/Nagel-CAL%20Disposition/_workitems/edit/109723)

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
