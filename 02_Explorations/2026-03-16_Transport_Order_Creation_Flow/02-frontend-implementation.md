# Transport Order Creation - Frontend Implementation

**Date:** 2026-03-16
**Focus:** Angular drag & drop UI, API service layer, and auto-refresh flow
**Document Series:** Part 2 of 6

---

## Overview

The frontend implementation uses Angular CDK's drag-and-drop functionality to provide an intuitive interface for dispatchers to create transport orders. The flow consists of:

1. Drag & drop zone with visual feedback
2. Date picker dialog for performance date selection
3. API service layer for backend communication
4. Automatic UI refresh after successful creation

---

## 1. Drag & Drop UI (Angular CDK)

### HTML Template (Drop Zone)

**File:** `Code/Disposition-Frontend/apps/nagel-cal-disposition/src/app/components/planning-list/planning-list.component.html`

```html
<div
  class="drop-zone h-[100px] flex justify-center items-center mb-4"
  (cdkDropListDropped)="dropOnCreateTransportOrder($event)"
  cdkDropList
  [cdkDropListConnectedTo]="['shipments']"
  (cdkDropListEntered)="setIsHoveringOverCreateTransportOrder(true)"
  (cdkDropListExited)="setIsHoveringOverCreateTransportOrder(false)"
  id="icon-dropzone"
>
    <mat-icon [svgIcon]="getIconName()" [class]="getCreateTransportOrderAreaClassName()"></mat-icon>
</div>
```

**Key Features:**
- `cdkDropList` - Angular CDK directive for drop zone
- `[cdkDropListConnectedTo]="['shipments']"` - Connects to draggable items
- `(cdkDropListDropped)` - Event fired when item is dropped
- Hover state management for visual feedback

---

### TypeScript Handler (Line 182)

**File:** `Code/Disposition-Frontend/apps/nagel-cal-disposition/src/app/components/planning-list/planning-list.component.ts`

```typescript
dropOnCreateTransportOrder(event: CdkDragDrop<LotCardConfig>) {
  const dialogRef = this.dialog.open(CreateTransportOrderDialogComponent, {
    data: CREATE_TRANSPORT_ORDER_DIALOG_TEXT,
    width: '340px',
    height: '260px',
    panelClass: 'create-to-panel-class',
    position: { top: '450px' }
  });

  dialogRef.afterClosed().subscribe((selectedDate: Date) => {
    selectedDate && this.pickupPlanningTransportOrdersActionsService.createTransportOrder(
      event.item.data,  // The dragged lot/leg
      () => { this.onRefreshData(); },  // Success callback
      selectedDate  // Selected performance date
    );
  });
}
```

**Flow:**
1. User drops lot/leg on zone
2. Material Dialog opens for date selection
3. User selects performance date
4. On confirmation, service method is called with:
   - Dragged item data (lot or leg)
   - Success callback (refresh UI)
   - Selected date

---

### Dialog Component

**File:** `Code/Disposition-Frontend/apps/nagel-cal-disposition/src/app/components/create-transport-order-dialog/create-transport-order-dialog.component.ts`

```typescript
const CREATE_TRANSPORT_ORDER_DIALOG_TEXT = {
  title: $localize`Create a transport order`,
  message: $localize`Please select a start date and time for creating the transport order`,
  confirm: $localize`Create`,
  cancel: $localize`Cancel`
};
```

**Purpose:**
- Collects performance date from dispatcher
- Provides user-friendly date/time picker
- Validates input before proceeding

---

## 2. API Service Layer

**File:** `Code/Disposition-Frontend/apps/nagel-cal-disposition/src/app/services/crud-pickup-planning-transport-orders.service.ts`

### Main Service Methods

```typescript
createTransportOrder(
  draggedCard: LotCardConfig,
  onSuccess: Function,
  performanceDate: Date
) {
  protectSubscription(
    this.getCreateTransportOrderRequest(draggedCard, performanceDate),
    (response) => this.onCreateDataSuccessfulRetrieval(onSuccess, response),
    (error) => this.onCreateDataErrorRetrieval(error)
  );
}

getCreateTransportOrderRequest(
  draggedCard: LotCardConfig,
  performanceDate: Date
) {
  // Determine if it's a lot or leg
  const idType = this.isLotType(draggedCard) ? 'lotId' : 'legId';

  // Select appropriate endpoint
  const url = idType === 'lotId'
    ? `${environment.apiUrl}/api/transport-order-planning/transportorders/from-lot`
    : `${environment.apiUrl}/api/transport-order-planning/transportorders/from-leg`;

  // Build request payload
  const requestPayload = {
    [idType]: draggedCard.id,
    performanceDate: getTimezoneAdjustedDate(performanceDate)
  };

  return this.requestService.postRequest<
    CreateTransportOrderRequest,
    CreateTransportOrderResponse
  >(url, requestPayload);
}
```

**Endpoints:**
- `POST /api/transport-order-planning/transportorders/from-lot` - Create from lot
- `POST /api/transport-order-planning/transportorders/from-leg` - Create from single leg

**Request Payload:**
```typescript
{
  lotId: "123e4567-e89b-12d3-a456-426614174000",  // OR legId
  performanceDate: "2026-03-16T10:00:00.000Z"
}
```

---

## 3. Frontend Auto-Refresh Flow

### Automatic UI Refresh

After successful transport order creation, the frontend automatically refreshes the transport order list to reflect the changes.

**Callback Pattern:**
```typescript
this.pickupPlanningTransportOrdersActionsService.createTransportOrder(
  event.item.data,
  () => { this.onRefreshData(); },  // Success callback triggers refresh
  selectedDate
);
```

---

### Silent Route Calculation (Debounced)

**File:** `Code/Disposition-Frontend/apps/nagel-cal-disposition/src/app/services/calculate-routes.service.ts`

```typescript
triggerSilentCalculateRoutesObservable$
  .pipe(
    filter((id: number | null) => id !== null),
    debounceTime(3000),  // 3 second delay
  )
  .subscribe((transportOrderId: number) => {
    this.calculateRoutes(transportOrderId, true);
  });
```

**Purpose:**
- Allows multiple rapid changes without triggering calculation each time
- 3-second delay prevents excessive route recalculations
- Silent mode doesn't show loading indicators to avoid UI noise

---

## Component Structure

### File Organization

| Component | File Path | Purpose |
|-----------|-----------|---------|
| **Planning List** | `Code/Disposition-Frontend/apps/nagel-cal-disposition/src/app/components/planning-list/planning-list.component.ts` | Drag & drop handler |
| **Planning List HTML** | `Code/Disposition-Frontend/apps/nagel-cal-disposition/src/app/components/planning-list/planning-list.component.html` | Drop zone markup |
| **Create TO Dialog** | `Code/Disposition-Frontend/apps/nagel-cal-disposition/src/app/components/create-transport-order-dialog/create-transport-order-dialog.component.ts` | Date picker dialog |
| **CRUD Service** | `Code/Disposition-Frontend/apps/nagel-cal-disposition/src/app/services/crud-pickup-planning-transport-orders.service.ts` | API integration |
| **Calculate Routes** | `Code/Disposition-Frontend/apps/nagel-cal-disposition/src/app/services/calculate-routes.service.ts` | Tour calc trigger |

---

## User Experience Flow

```
1. User drags lot/leg from unplanned area
   ↓
2. Visual feedback: drop zone highlights on hover
   ↓
3. User drops item on "Create Transport Order" zone
   ↓
4. Dialog opens: "Select performance date"
   ↓
5. User selects date and clicks "Create"
   ↓
6. Loading indicator appears
   ↓
7. API request sent to backend
   ↓
8. Success:
   - Success message displayed
   - Transport order list refreshes automatically
   - Item disappears from unplanned area
   - (After 3s) Silent route calculation triggered
   ↓
9. Error:
   - Error message displayed
   - Item remains in unplanned area
   - User can retry
```

---

## Key Implementation Details

### 1. Type Detection (Lot vs Leg)

The service automatically determines whether the dragged item is a lot or a single leg and calls the appropriate endpoint.

```typescript
const idType = this.isLotType(draggedCard) ? 'lotId' : 'legId';
```

### 2. Timezone Handling

Performance dates are adjusted for timezone differences:

```typescript
performanceDate: getTimezoneAdjustedDate(performanceDate)
```

### 3. Error Handling

The service layer includes centralized error handling:

```typescript
(error) => this.onCreateDataErrorRetrieval(error)
```

This ensures consistent error messages and logging across all transport order operations.

---

## See Also

- **[Overview and Flow](./01-overview-and-flow.md)** - High-level sequence diagram and summary
- **[Backend Implementation](./03-backend-implementation.md)** - Command handlers and business logic
- **[API Reference](./06-api-reference.md)** - Complete HTTP endpoint documentation
- **[Data Model Transformations](./05-data-model-transformations.md)** - Entity state changes
