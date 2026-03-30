# Implementation Proposal: Transactional Outbox for Transport Order Creation

**Date:** 2026-03-25
**Status:** Draft for Review
**Target:** June 2026 Go-Live
**Conceptual Foundation:** See [`conceptual-approach.md`](./conceptual-approach.md)

---

## Executive Summary

This document provides concrete implementation details for the Transactional Outbox Pattern described in the conceptual approach. It includes database schemas, code patterns, retry logic, and deployment phases.

---

## 1. Database Schema

### TmsSyncOutbox Table

```sql
CREATE TABLE TmsSyncOutbox (
    Id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Operation Context
    OperationType VARCHAR(50) NOT NULL,              -- 'CreateTransportOrder', 'AddLeg', etc.
    EntityId UUID NOT NULL,                          -- LotId, LegId, TransportOrderId
    DatabaseIdentifier VARCHAR(50) NOT NULL,         -- Branch database key

    -- Operation Data
    Payload JSONB NOT NULL,                          -- TMS input parameters
    TmsResponse JSONB,                               -- TMS output (IDs)

    -- State Machine
    Status VARCHAR(20) NOT NULL DEFAULT 'Pending',   -- FSM states
    AttemptCount INT DEFAULT 0,
    ErrorMessage TEXT,

    -- Audit Trail
    CreatedAt TIMESTAMP DEFAULT NOW(),
    CreatedBy VARCHAR(100),                          -- User from JWT
    LastAttemptAt TIMESTAMP,
    CompletedAt TIMESTAMP,

    -- Indexes
    INDEX idx_status_created (Status, CreatedAt),
    INDEX idx_entity_operation (EntityId, OperationType),
    INDEX idx_database (DatabaseIdentifier, Status)
);
```

### Status State Machine

```
Pending ──────> Processing ──────> Completed
   │                │
   │                │
   └────────────────┴──────────> Failed
                                    │
                                    └──────> ManualReview
```

**Status Values:**
- `Pending`: Outbox entry created, not yet processed
- `Processing`: TMS call in progress (prevents concurrent processing)
- `Completed`: Both TMS and local DB updated successfully
- `Failed`: TMS or local DB failed, available for retry
- `ManualReview`: Multiple failures, requires support intervention

### Payload and TmsResponse Examples

**Payload Structure (Input to TMS):**
```json
{
  "lotId": "550e8400-e29b-41d4-a716-446655440000",
  "performanceDate": "2026-03-25T00:00:00Z",
  "transportMode": 60,
  "legs": [
    {
      "legId": "uuid-1",
      "company": 1,
      "branch": 100,
      "shipmentId": 12345678,
      "legType": "VL",
      "originName": "Customer A",
      "destinationName": "Branch X",
      "weight": 1500.5,
      "floorPalletSpaces": 2,
      "volumePalletSpaces": 0
      // ... all LegEntity fields needed for mapping
    }
  ]
}
```

**TmsResponse Structure (Output from TMS):**
```json
{
  "transportOrderId": 987654,
  "pickupPointId": 111,
  "isNewPickupPoint": true,
  "deliveryPointId": 222,
  "isNewDeliveryPoint": false,
  "legs": [
    {
      "legId": 333,
      "shipmentId": 12345678,
      "pickupPointId": 111,
      "deliveryPointId": 222
    }
  ]
}
```

---

## 2. Entity Implementation

### C# Entity

```csharp
public class TmsSyncOutboxEntity
{
    public Guid Id { get; set; }
    public string OperationType { get; set; } = null!;
    public Guid EntityId { get; set; }
    public string DatabaseIdentifier { get; set; } = null!;

    public string Payload { get; set; } = null!;  // JSON string
    public string? TmsResponse { get; set; }      // JSON string

    public OutboxStatus Status { get; set; }
    public int AttemptCount { get; set; }
    public string? ErrorMessage { get; set; }

    public DateTime CreatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public DateTime? LastAttemptAt { get; set; }
    public DateTime? CompletedAt { get; set; }
}

public enum OutboxStatus
{
    Pending,
    Processing,
    Completed,
    Failed,
    ManualReview
}
```

### Entity Configuration (EF Core)

```csharp
public class TmsSyncOutboxConfiguration : IEntityTypeConfiguration<TmsSyncOutboxEntity>
{
    public void Configure(EntityTypeBuilder<TmsSyncOutboxEntity> builder)
    {
        builder.ToTable("TmsSyncOutbox");
        builder.HasKey(e => e.Id);

        builder.Property(e => e.OperationType).HasMaxLength(50).IsRequired();
        builder.Property(e => e.DatabaseIdentifier).HasMaxLength(50).IsRequired();
        builder.Property(e => e.Payload).HasColumnType("jsonb").IsRequired();
        builder.Property(e => e.TmsResponse).HasColumnType("jsonb");
        builder.Property(e => e.Status)
            .HasConversion<string>()
            .HasMaxLength(20)
            .IsRequired();

        builder.HasIndex(e => new { e.Status, e.CreatedAt });
        builder.HasIndex(e => new { e.EntityId, e.OperationType });
        builder.HasIndex(e => new { e.DatabaseIdentifier, e.Status });
    }
}
```

---

## 3. Modified Command Handler

### Phase 1: Create Outbox Entry (Red Arrow)

```csharp
public class CreateTransportOrderFromLotCommandHandler : ICommandHandler<...>
{
    private readonly AppDbContext _appDbContext;
    private readonly ITmsSyncOutboxProcessor _outboxProcessor;

    public async Task<CreateTransportOrderFromLotResponseDto> Handle(
        CreateTransportOrderFromLotCommand request,
        CancellationToken cancellationToken)
    {
        var databaseIdentifier = request.DatabaseIdentifier;
        var lotId = request.Request.LotId;
        var performanceDate = request.Request.PerformanceDate;

        // Fetch lot with legs
        LotEntity? lot = await _appDbContext.Lots
            .Include(l => l.Legs)
            .Where(lot => lot.BranchKey.Equals(databaseIdentifier))
            .FirstOrDefaultAsync(l => l.LotId == lotId, cancellationToken)
            ?? throw new NotFoundException($"Lot with id: {lotId} was not found!");

        var legs = lot.Legs.ToList();
        var isPickupLot = DetermineIfPickupLot(legs);
        int? transportOrderTransportMode = isPickupLot ? 60 : null;

        List<CraeteTransportOrderLegDataInputDto> mappedLegs =
            MapLegEntitiesToCreateTransportOrderInputs(legs);

        // ⚡ RED ARROW: Create outbox entry FIRST
        using var transaction = await _appDbContext.Database
            .BeginTransactionAsync(cancellationToken);

        try
        {
            var outboxEntry = new TmsSyncOutboxEntity
            {
                Id = Guid.NewGuid(),
                OperationType = "CreateTransportOrder",
                EntityId = lotId,
                DatabaseIdentifier = databaseIdentifier,
                Payload = JsonSerializer.Serialize(new CreateTransportOrderPayload
                {
                    LotId = lotId,
                    PerformanceDate = performanceDate,
                    TransportMode = transportOrderTransportMode,
                    Legs = mappedLegs.Select(leg => new LegPayload
                    {
                        LegId = leg.LegId,
                        Company = leg.Company,
                        Branch = leg.Branch,
                        ShipmentId = leg.ShipmentId,
                        LegType = leg.LegType,
                        // ... map all necessary fields
                    }).ToList()
                }),
                Status = OutboxStatus.Pending,
                CreatedAt = DateTime.UtcNow,
                CreatedBy = request.UserId  // From JWT
            };

            _appDbContext.TmsSyncOutbox.Add(outboxEntry);
            await _appDbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            // ✅ User intent is now persisted atomically

            // Process outbox entry (inline for synchronous API)
            var transportOrderId = await _outboxProcessor.ProcessOutboxEntry(
                outboxEntry.Id,
                cancellationToken
            );

            return new CreateTransportOrderFromLotResponseDto
            {
                TransportOrderId = transportOrderId
            };
        }
        catch (Exception ex)
        {
            await transaction.RollbackAsync(cancellationToken);
            throw;  // Fail fast - outbox entry not created
        }
    }

    private bool DetermineIfPickupLot(List<LegEntity> legs) { /* ... */ }
    private List<CraeteTransportOrderLegDataInputDto> MapLegEntitiesToCreateTransportOrderInputs(
        List<LegEntity> legs) { /* ... */ }
}
```

---

## 4. Outbox Processor Service

### Interface

```csharp
public interface ITmsSyncOutboxProcessor
{
    Task<long> ProcessOutboxEntry(Guid outboxId, CancellationToken cancellationToken);
    Task<long> RetryOutboxEntry(Guid outboxId, CancellationToken cancellationToken);
}
```

### Implementation

```csharp
public class TmsSyncOutboxProcessor : ITmsSyncOutboxProcessor
{
    private readonly AppDbContext _appDbContext;
    private readonly ICreateTransportOrderFromLotSubHandler _tmsSubHandler;
    private readonly IRecalculateRouteService _recalculateRouteService;
    private readonly ILogger<TmsSyncOutboxProcessor> _logger;

    public async Task<long> ProcessOutboxEntry(Guid outboxId, CancellationToken cancellationToken)
    {
        var entry = await _appDbContext.TmsSyncOutbox
            .FirstOrDefaultAsync(e => e.Id == outboxId, cancellationToken)
            ?? throw new NotFoundException($"Outbox entry {outboxId} not found");

        if (entry.Status != OutboxStatus.Pending)
        {
            throw new InvalidOperationException(
                $"Outbox entry {outboxId} is not in Pending state (current: {entry.Status})"
            );
        }

        // Mark as processing (prevents concurrent processing)
        entry.Status = OutboxStatus.Processing;
        entry.LastAttemptAt = DateTime.UtcNow;
        entry.AttemptCount++;
        await _appDbContext.SaveChangesAsync(cancellationToken);

        try
        {
            // Deserialize payload
            var payload = JsonSerializer.Deserialize<CreateTransportOrderPayload>(entry.Payload)
                ?? throw new InvalidOperationException("Failed to deserialize payload");

            // Execute TMS operation
            var tmsResponse = await CallTms(payload, entry.DatabaseIdentifier, cancellationToken);

            // Tour calculation (non-blocking, errors logged but don't fail operation)
            try
            {
                await _recalculateRouteService.Recalculate(
                    entry.DatabaseIdentifier,
                    tmsResponse.TransportOrderId,
                    cancellationToken
                );
            }
            catch (Exception tourEx)
            {
                _logger.LogWarning(tourEx,
                    "Tour calculation failed for transport order {TransportOrderId}, continuing",
                    tmsResponse.TransportOrderId);
            }

            // Complete local database state
            await CompleteLocalState(payload, tmsResponse, entry, cancellationToken);

            return tmsResponse.TransportOrderId;
        }
        catch (Exception ex)
        {
            // Handle failure (next section)
            await HandleFailure(entry, ex, cancellationToken);
            throw;
        }
    }

    private async Task<CreateTransportOrderTmsResponse> CallTms(
        CreateTransportOrderPayload payload,
        string databaseIdentifier,
        CancellationToken cancellationToken)
    {
        var firstLeg = payload.Legs.First();
        var additionalLegs = payload.Legs.Skip(1).ToList();

        var graphQLResponse = await _tmsSubHandler.Create(
            MapToTmsInputDto(firstLeg),
            additionalLegs.Select(MapToTmsInputDto).ToList(),
            payload.PerformanceDate,
            payload.TransportMode,
            databaseIdentifier,
            cancellationToken
        );

        return new CreateTransportOrderTmsResponse
        {
            TransportOrderId = graphQLResponse.CreatedTransportOrderGraphQLResponse
                .First().TransportOrderId,
            PickupPointId = graphQLResponse.CreatedTransportOrderGraphQLResponse
                .First().PickupPointId,
            DeliveryPointId = graphQLResponse.CreatedTransportOrderGraphQLResponse
                .First().DeliveryPointId,
            Legs = ExtractLegIds(graphQLResponse)
        };
    }

    private async Task CompleteLocalState(
        CreateTransportOrderPayload payload,
        CreateTransportOrderTmsResponse tmsResponse,
        TmsSyncOutboxEntity entry,
        CancellationToken cancellationToken)
    {
        using var transaction = await _appDbContext.Database.BeginTransactionAsync(cancellationToken);

        try
        {
            // Create LotAssignment
            var lotAssignment = new LotAssignmentEntity
            {
                Id = Guid.NewGuid(),
                BranchKey = entry.DatabaseIdentifier,
                ReferenceId = payload.LotId,
                TransportOrderId = tmsResponse.TransportOrderId,
                PickupTourPointId = tmsResponse.PickupPointId,
                DeliveryTourPointId = tmsResponse.DeliveryPointId,
                PickupTourPointOrder = 1,
                // ... map other fields from payload.Legs[0]
                LegLinks = payload.Legs.Select((leg, index) => new LotAssignmentLegLinkEntity
                {
                    Id = Guid.NewGuid(),
                    LegId = leg.LegId,
                    PreviousLotId = payload.LotId,
                    Order = (short)(index + 1),
                    TmsLegId = tmsResponse.Legs[index].LegId,
                    StaysLoaded = false
                }).ToList()
            };

            _appDbContext.LotAssignments.Add(lotAssignment);

            // Remove original lot
            var lot = await _appDbContext.Lots.FindAsync(payload.LotId);
            if (lot != null)
            {
                _appDbContext.Lots.Remove(lot);
            }

            // Update outbox to completed
            entry.Status = OutboxStatus.Completed;
            entry.CompletedAt = DateTime.UtcNow;
            entry.TmsResponse = JsonSerializer.Serialize(tmsResponse);

            await _appDbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            _logger.LogInformation(
                "Successfully completed outbox entry {OutboxId} for transport order {TransportOrderId}",
                entry.Id, tmsResponse.TransportOrderId
            );
        }
        catch (Exception localDbEx)
        {
            await transaction.RollbackAsync(cancellationToken);

            // ⚠️ Scenario 2: TMS succeeded, local DB failed
            // Store TMS response for idempotent retry
            entry.Status = OutboxStatus.Failed;
            entry.ErrorMessage = $"Local DB save failed: {localDbEx.Message}";
            entry.TmsResponse = JsonSerializer.Serialize(tmsResponse);  // CRITICAL!

            await _appDbContext.SaveChangesAsync(cancellationToken);

            _logger.LogError(localDbEx,
                "TMS succeeded but local DB failed for outbox {OutboxId}. TMS transport order: {TransportOrderId}",
                entry.Id, tmsResponse.TransportOrderId
            );

            throw;
        }
    }

    private async Task HandleFailure(
        TmsSyncOutboxEntity entry,
        Exception ex,
        CancellationToken cancellationToken)
    {
        entry.Status = OutboxStatus.Failed;
        entry.ErrorMessage = $"{ex.GetType().Name}: {ex.Message}";

        // Don't overwrite TmsResponse if it was already set
        // (happens when local DB fails after TMS succeeds)

        await _appDbContext.SaveChangesAsync(cancellationToken);

        _logger.LogError(ex,
            "Outbox entry {OutboxId} failed (attempt {AttemptCount})",
            entry.Id, entry.AttemptCount
        );
    }

    // Retry implementation (next section)
    public async Task<long> RetryOutboxEntry(Guid outboxId, CancellationToken cancellationToken)
    {
        // See Retry Logic section
    }
}
```

---

## 5. Idempotent Retry Logic

### Retry Method

```csharp
public async Task<long> RetryOutboxEntry(Guid outboxId, CancellationToken cancellationToken)
{
    var entry = await _appDbContext.TmsSyncOutbox
        .FirstOrDefaultAsync(e => e.Id == outboxId, cancellationToken)
        ?? throw new NotFoundException($"Outbox entry {outboxId} not found");

    if (entry.Status != OutboxStatus.Failed)
    {
        throw new InvalidOperationException(
            $"Can only retry Failed entries (current: {entry.Status})"
        );
    }

    // Check if we have TMS response from previous attempt
    if (!string.IsNullOrEmpty(entry.TmsResponse))
    {
        // ✅ TMS succeeded previously, only need to complete local DB
        _logger.LogInformation(
            "Retrying outbox {OutboxId} - TMS response exists, skipping TMS call",
            outboxId
        );

        var tmsResponse = JsonSerializer.Deserialize<CreateTransportOrderTmsResponse>(
            entry.TmsResponse
        );
        var payload = JsonSerializer.Deserialize<CreateTransportOrderPayload>(
            entry.Payload
        );

        entry.Status = OutboxStatus.Processing;
        entry.AttemptCount++;
        entry.LastAttemptAt = DateTime.UtcNow;
        await _appDbContext.SaveChangesAsync(cancellationToken);

        await CompleteLocalState(payload!, tmsResponse!, entry, cancellationToken);
        return tmsResponse!.TransportOrderId;
    }
    else
    {
        // TMS never succeeded or response was lost
        // Need to check if transport order was actually created
        _logger.LogInformation(
            "Retrying outbox {OutboxId} - checking TMS state before recreating",
            outboxId
        );

        var payload = JsonSerializer.Deserialize<CreateTransportOrderPayload>(entry.Payload)!;

        // Query TMS to check if transport order exists
        var existingTransportOrder = await CheckTmsForExistingTransportOrder(
            payload,
            entry.DatabaseIdentifier,
            cancellationToken
        );

        if (existingTransportOrder != null)
        {
            // Found existing transport order - use it (idempotent)
            _logger.LogInformation(
                "Found existing transport order {TransportOrderId} for outbox {OutboxId}",
                existingTransportOrder.TransportOrderId, outboxId
            );

            entry.Status = OutboxStatus.Processing;
            entry.AttemptCount++;
            entry.LastAttemptAt = DateTime.UtcNow;
            await _appDbContext.SaveChangesAsync(cancellationToken);

            await CompleteLocalState(payload, existingTransportOrder, entry, cancellationToken);
            return existingTransportOrder.TransportOrderId;
        }
        else
        {
            // No existing transport order - safe to create new
            _logger.LogInformation(
                "No existing transport order found, creating new for outbox {OutboxId}",
                outboxId
            );

            entry.Status = OutboxStatus.Pending;  // Reset to pending
            await _appDbContext.SaveChangesAsync(cancellationToken);

            return await ProcessOutboxEntry(outboxId, cancellationToken);
        }
    }
}
```

### TMS State Checking

```csharp
private async Task<CreateTransportOrderTmsResponse?> CheckTmsForExistingTransportOrder(
    CreateTransportOrderPayload payload,
    string databaseIdentifier,
    CancellationToken cancellationToken)
{
    // Query TMS database for transport order matching this context
    // This is application-level idempotency check (Option B from conceptual doc)

    var firstLeg = payload.Legs.First();

    // Query TMS for transport order with matching:
    // - shipmentId (from first leg)
    // - performanceDate
    // - created recently (last 24 hours as safety check)

    var query = @"
        SELECT
            ta.tournr AS transport_order_id,
            ta.station AS pickup_point_id,
            ta.stationab AS delivery_point_id,
            tb.abelfd AS leg_id
        FROM ta  -- transport_order table
        JOIN tb  -- leg table
          ON ta.tournr = tb.tournr
        WHERE tb.auftrnr = @shipmentId
          AND ta.dataus = @performanceDate
          AND ta.created_at > @minCreatedAt
        LIMIT 1";

    // Execute via TMS Bridge GraphQL or direct query
    // Return response if found, null otherwise

    // TODO: Implement with actual TMS query service
    return null;  // Placeholder
}
```

---

## 6. API Endpoints

### Create Transport Order (Modified)

```csharp
[HttpPost("from-lot")]
[ProducesResponseType(StatusCodes.Status201Created)]
[ProducesResponseType(StatusCodes.Status400BadRequest)]
[ProducesResponseType(StatusCodes.Status500InternalServerError)]
public async Task<ActionResult<CreateTransportOrderFromLotResponseDto>> CreateTransportOrderFromLot(
    [FromRoute] string databaseIdentifier,
    [FromBody] CreateTransportOrderFromLotRequestDto request)
{
    try
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;

        var command = new CreateTransportOrderFromLotCommand
        {
            DatabaseIdentifier = databaseIdentifier,
            Request = request,
            UserId = userId
        };

        var result = await _mediator.Send(command);

        return CreatedAtAction(
            nameof(GetTransportOrder),
            new { databaseIdentifier, id = result.TransportOrderId },
            result
        );
    }
    catch (Exception ex)
    {
        _logger.LogError(ex, "Failed to create transport order from lot");
        return StatusCode(500, new { error = ex.Message });
    }
}
```

### Retry Endpoint (New)

```csharp
[HttpPost("retry")]
[ProducesResponseType(StatusCodes.Status200OK)]
[ProducesResponseType(StatusCodes.Status404NotFound)]
[ProducesResponseType(StatusCodes.Status400BadRequest)]
public async Task<ActionResult<CreateTransportOrderFromLotResponseDto>> RetryTransportOrderCreation(
    [FromRoute] string databaseIdentifier,
    [FromQuery] Guid outboxId)
{
    try
    {
        var transportOrderId = await _outboxProcessor.RetryOutboxEntry(outboxId);

        return Ok(new CreateTransportOrderFromLotResponseDto
        {
            TransportOrderId = transportOrderId
        });
    }
    catch (NotFoundException ex)
    {
        return NotFound(new { error = ex.Message });
    }
    catch (InvalidOperationException ex)
    {
        return BadRequest(new { error = ex.Message });
    }
    catch (Exception ex)
    {
        _logger.LogError(ex, "Failed to retry outbox entry {OutboxId}", outboxId);
        return StatusCode(500, new { error = ex.Message });
    }
}
```

### Outbox Status Endpoint (New)

```csharp
[HttpGet("outbox/{outboxId}/status")]
[ProducesResponseType(StatusCodes.Status200OK)]
[ProducesResponseType(StatusCodes.Status404NotFound)]
public async Task<ActionResult<OutboxStatusDto>> GetOutboxStatus(
    [FromRoute] Guid outboxId)
{
    var entry = await _appDbContext.TmsSyncOutbox
        .AsNoTracking()
        .FirstOrDefaultAsync(e => e.Id == outboxId);

    if (entry == null)
        return NotFound();

    return Ok(new OutboxStatusDto
    {
        OutboxId = entry.Id,
        Status = entry.Status.ToString(),
        EntityId = entry.EntityId,
        AttemptCount = entry.AttemptCount,
        ErrorMessage = entry.ErrorMessage,
        CreatedAt = entry.CreatedAt,
        CompletedAt = entry.CompletedAt,
        CanRetry = entry.Status == OutboxStatus.Failed
    });
}
```

---

## 7. Frontend Integration

### Service Method

```typescript
// crud-pickup-planning-transport-orders.service.ts

createTransportOrderFromLot(
  databaseIdentifier: string,
  request: CreateTransportOrderFromLotRequest
): Observable<CreateTransportOrderResponse> {
  return this.http.post<CreateTransportOrderResponse>(
    `${this.baseUrl}/${databaseIdentifier}/transportorders/from-lot`,
    request
  ).pipe(
    catchError((error: HttpErrorResponse) => {
      // Check if error response includes outboxId for retry
      if (error.error?.outboxId) {
        this.showRetryDialog(databaseIdentifier, error.error.outboxId);
      }
      return throwError(() => error);
    })
  );
}

retryTransportOrderCreation(
  databaseIdentifier: string,
  outboxId: string
): Observable<CreateTransportOrderResponse> {
  return this.http.post<CreateTransportOrderResponse>(
    `${this.baseUrl}/${databaseIdentifier}/transportorders/retry`,
    null,
    { params: { outboxId } }
  );
}

private showRetryDialog(databaseIdentifier: string, outboxId: string): void {
  const dialogRef = this.dialog.open(RetryTransportOrderDialogComponent, {
    data: { databaseIdentifier, outboxId }
  });
}
```

### Retry Dialog Component

```typescript
// retry-transport-order-dialog.component.ts

export class RetryTransportOrderDialogComponent {
  constructor(
    @Inject(MAT_DIALOG_DATA) public data: { databaseIdentifier: string; outboxId: string },
    private transportOrderService: CrudPickupPlanningTransportOrdersService,
    private dialogRef: MatDialogRef<RetryTransportOrderDialogComponent>,
    private snackBar: MatSnackBar
  ) {}

  retry(): void {
    this.transportOrderService
      .retryTransportOrderCreation(this.data.databaseIdentifier, this.data.outboxId)
      .subscribe({
        next: (response) => {
          this.snackBar.open('Transport order created successfully', 'Close', {
            duration: 3000
          });
          this.dialogRef.close(response);
        },
        error: (error) => {
          this.snackBar.open(
            `Failed to create transport order: ${error.message}`,
            'Close',
            { duration: 5000 }
          );
        }
      });
  }

  contactSupport(): void {
    // Copy reference ID to clipboard
    navigator.clipboard.writeText(this.data.outboxId);
    this.snackBar.open(
      'Reference ID copied to clipboard. Please contact support.',
      'Close',
      { duration: 5000 }
    );
  }
}
```

---

## 8. Monitoring & Observability

### Key Metrics

```csharp
// Add metrics tracking to TmsSyncOutboxProcessor

private readonly IMetrics _metrics;  // Use prometheus-net or similar

public async Task<long> ProcessOutboxEntry(...)
{
    var stopwatch = Stopwatch.StartNew();

    try
    {
        // ... processing logic ...

        _metrics.Measure.Counter.Increment(
            new CounterOptions { Name = "outbox_processed_total" },
            new MetricTags("status", "success", "operation", entry.OperationType)
        );

        _metrics.Measure.Histogram.Update(
            new HistogramOptions { Name = "outbox_processing_duration_seconds" },
            stopwatch.Elapsed.TotalSeconds,
            new MetricTags("operation", entry.OperationType)
        );

        return transportOrderId;
    }
    catch (Exception ex)
    {
        _metrics.Measure.Counter.Increment(
            new CounterOptions { Name = "outbox_processed_total" },
            new MetricTags("status", "failed", "operation", entry.OperationType)
        );

        throw;
    }
}
```

### SQL Monitoring Queries

```sql
-- Failed outbox entries (last 24h)
SELECT
    id,
    operation_type,
    entity_id,
    attempt_count,
    error_message,
    created_at
FROM TmsSyncOutbox
WHERE status = 'Failed'
  AND created_at > NOW() - INTERVAL '24 hours'
ORDER BY created_at DESC;

-- Average processing time by operation type
SELECT
    operation_type,
    AVG(EXTRACT(EPOCH FROM (completed_at - created_at))) AS avg_seconds,
    COUNT(*) AS total_count
FROM TmsSyncOutbox
WHERE status = 'Completed'
  AND created_at > NOW() - INTERVAL '24 hours'
GROUP BY operation_type;

-- Retry success rate
SELECT
    COUNT(CASE WHEN attempt_count > 1 AND status = 'Completed' THEN 1 END)::FLOAT /
    COUNT(CASE WHEN attempt_count > 1 THEN 1 END) AS retry_success_rate,
    COUNT(CASE WHEN attempt_count > 1 THEN 1 END) AS total_retries
FROM TmsSyncOutbox
WHERE created_at > NOW() - INTERVAL '7 days';

-- Entries requiring manual review
SELECT *
FROM TmsSyncOutbox
WHERE status = 'Failed'
  AND attempt_count >= 2
ORDER BY created_at DESC;
```

### Cloud4Log Integration

```csharp
// Log structured events for Cloud4Log

_logger.LogError(
    new EventId(2001, "OutboxProcessingFailed"),
    ex,
    "Outbox entry {OutboxId} failed: Operation={Operation}, EntityId={EntityId}, " +
    "AttemptCount={AttemptCount}, ErrorType={ErrorType}",
    entry.Id,
    entry.OperationType,
    entry.EntityId,
    entry.AttemptCount,
    ex.GetType().Name
);
```

---

## 9. Support Dashboard (Admin Panel)

### Failed Entries View

```csharp
[HttpGet("admin/outbox/failed")]
[Authorize(Roles = "Admin,Support")]
public async Task<ActionResult<PagedResult<OutboxEntryDto>>> GetFailedOutboxEntries(
    [FromQuery] int page = 1,
    [FromQuery] int pageSize = 50)
{
    var query = _appDbContext.TmsSyncOutbox
        .Where(e => e.Status == OutboxStatus.Failed || e.Status == OutboxStatus.ManualReview)
        .OrderByDescending(e => e.CreatedAt);

    var totalCount = await query.CountAsync();
    var entries = await query
        .Skip((page - 1) * pageSize)
        .Take(pageSize)
        .Select(e => new OutboxEntryDto
        {
            Id = e.Id,
            OperationType = e.OperationType,
            EntityId = e.EntityId,
            Status = e.Status.ToString(),
            AttemptCount = e.AttemptCount,
            ErrorMessage = e.ErrorMessage,
            CreatedAt = e.CreatedAt,
            CreatedBy = e.CreatedBy,
            Payload = e.Payload,
            TmsResponse = e.TmsResponse
        })
        .ToListAsync();

    return Ok(new PagedResult<OutboxEntryDto>
    {
        Items = entries,
        TotalCount = totalCount,
        Page = page,
        PageSize = pageSize
    });
}
```

### Manual Resolution Endpoint

```csharp
[HttpPost("admin/outbox/{outboxId}/manual-complete")]
[Authorize(Roles = "Admin")]
public async Task<ActionResult> ManuallyCompleteOutboxEntry(
    [FromRoute] Guid outboxId,
    [FromBody] ManualCompletionDto completion)
{
    var entry = await _appDbContext.TmsSyncOutbox.FindAsync(outboxId);
    if (entry == null)
        return NotFound();

    entry.Status = OutboxStatus.Completed;
    entry.CompletedAt = DateTime.UtcNow;
    entry.ErrorMessage = $"Manually resolved by {User.Identity!.Name}: {completion.Notes}";
    entry.TmsResponse = completion.TmsResponse;

    await _appDbContext.SaveChangesAsync();

    _logger.LogWarning(
        "Outbox entry {OutboxId} manually completed by {User}: {Notes}",
        outboxId, User.Identity.Name, completion.Notes
    );

    return Ok();
}
```

---

## 10. Cleanup Job

### Background Service

```csharp
public class OutboxCleanupService : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<OutboxCleanupService> _logger;
    private readonly TimeSpan _interval = TimeSpan.FromHours(24);
    private readonly int _retentionDays = 30;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await CleanupCompletedEntries(stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during outbox cleanup");
            }

            await Task.Delay(_interval, stoppingToken);
        }
    }

    private async Task CleanupCompletedEntries(CancellationToken cancellationToken)
    {
        using var scope = _serviceProvider.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<AppDbContext>();

        var cutoffDate = DateTime.UtcNow.AddDays(-_retentionDays);

        var deletedCount = await dbContext.TmsSyncOutbox
            .Where(e => e.Status == OutboxStatus.Completed && e.CompletedAt < cutoffDate)
            .ExecuteDeleteAsync(cancellationToken);

        if (deletedCount > 0)
        {
            _logger.LogInformation(
                "Deleted {Count} completed outbox entries older than {Days} days",
                deletedCount, _retentionDays
            );
        }
    }
}

// Register in Program.cs
builder.Services.AddHostedService<OutboxCleanupService>();
```

---

## 11. Testing Strategy

### Unit Tests

```csharp
public class TmsSyncOutboxProcessorTests
{
    [Fact]
    public async Task ProcessOutboxEntry_TmsSucceeds_CompletesSuccessfully()
    {
        // Arrange
        var outboxId = Guid.NewGuid();
        var payload = CreateTestPayload();
        var tmsResponse = CreateTestTmsResponse();

        var mockTmsSubHandler = new Mock<ICreateTransportOrderFromLotSubHandler>();
        mockTmsSubHandler
            .Setup(x => x.Create(It.IsAny<...>()))
            .ReturnsAsync(tmsResponse);

        // Act
        var result = await _processor.ProcessOutboxEntry(outboxId);

        // Assert
        var entry = await _dbContext.TmsSyncOutbox.FindAsync(outboxId);
        Assert.Equal(OutboxStatus.Completed, entry.Status);
        Assert.NotNull(entry.TmsResponse);
        Assert.NotNull(entry.CompletedAt);
    }

    [Fact]
    public async Task ProcessOutboxEntry_LocalDbFails_PreservesTmsResponse()
    {
        // Arrange - set up scenario where TMS succeeds but local save fails

        // Act & Assert
        await Assert.ThrowsAsync<DbUpdateException>(() =>
            _processor.ProcessOutboxEntry(outboxId)
        );

        var entry = await _dbContext.TmsSyncOutbox.FindAsync(outboxId);
        Assert.Equal(OutboxStatus.Failed, entry.Status);
        Assert.NotNull(entry.TmsResponse);  // CRITICAL: preserved for retry
    }

    [Fact]
    public async Task RetryOutboxEntry_WithTmsResponse_SkipsTmsCall()
    {
        // Arrange
        var entry = CreateFailedEntryWithTmsResponse();

        var mockTmsSubHandler = new Mock<ICreateTransportOrderFromLotSubHandler>();

        // Act
        await _processor.RetryOutboxEntry(entry.Id);

        // Assert
        mockTmsSubHandler.Verify(
            x => x.Create(It.IsAny<...>()),
            Times.Never  // TMS should NOT be called
        );

        var updated = await _dbContext.TmsSyncOutbox.FindAsync(entry.Id);
        Assert.Equal(OutboxStatus.Completed, updated.Status);
    }
}
```

### Integration Tests

```csharp
public class TransportOrderCreationIntegrationTests : IClassFixture<WebApplicationFactory<Program>>
{
    [Fact]
    public async Task CreateTransportOrder_DatabaseFailsAfterTms_CanRetry()
    {
        // Arrange
        var request = CreateTestRequest();

        // Simulate database failure after TMS call
        // (inject fault or use Testcontainers to restart DB)

        // Act 1: Initial attempt fails
        var response1 = await _client.PostAsJsonAsync($"/{DatabaseId}/transportorders/from-lot", request);
        Assert.Equal(HttpStatusCode.InternalServerError, response1.StatusCode);
        var error = await response1.Content.ReadFromJsonAsync<ErrorResponse>();
        Assert.NotNull(error.OutboxId);

        // Act 2: Retry with outboxId
        var response2 = await _client.PostAsync(
            $"/{DatabaseId}/transportorders/retry?outboxId={error.OutboxId}",
            null
        );

        // Assert: Retry succeeds
        Assert.Equal(HttpStatusCode.OK, response2.StatusCode);
        var result = await response2.Content.ReadFromJsonAsync<CreateTransportOrderResponse>();
        Assert.NotNull(result.TransportOrderId);
    }
}
```

---

## 12. Deployment Checklist

### Database Migration

```bash
# Create migration
dotnet ef migrations add AddTmsSyncOutbox

# Review migration SQL
dotnet ef migrations script

# Apply to staging
dotnet ef database update --context AppDbContext --connection "..."

# Verify table exists
psql -c "\d TmsSyncOutbox"
```

### Configuration

```json
// appsettings.json
{
  "TmsSyncOutbox": {
    "RetentionDays": 30,
    "CleanupIntervalHours": 24,
    "MaxRetryAttempts": 3
  }
}
```

### Feature Flag (Optional)

```csharp
// Use feature flag to gradually roll out
if (_featureManager.IsEnabledAsync("TransactionalOutbox").Result)
{
    // Use new outbox-based flow
    return await CreateWithOutbox(request);
}
else
{
    // Use old direct flow
    return await CreateDirect(request);
}
```

---

## 13. Rollback Plan

### If Issues Arise Post-Deployment

1. **Disable Feature Flag** (if used)
2. **Revert to Previous Code** (keep outbox table for audit)
3. **Manual Completion** of pending outbox entries:

```sql
-- Find pending entries
SELECT * FROM TmsSyncOutbox WHERE status = 'Pending';

-- Check if transport order exists in TMS
-- (manual query against TMS database)

-- If exists, manually create LotAssignment
-- If not exists, mark as failed for later retry
UPDATE TmsSyncOutbox
SET status = 'ManualReview',
    error_message = 'Rollback - requires manual review'
WHERE status = 'Pending';
```

---

## Next Steps

1. **Code Review:** Review this implementation proposal with team
2. **Spike:** Create prototype of outbox table + basic processing
3. **TMS Coordination:** Confirm idempotency approach with Joachim
4. **Frontend Mockups:** Design retry dialog UX
5. **Support Training:** Prepare runbook for manual resolution

---

**Document Owner:** Matthias (Virtual Architect)
**Last Updated:** 2026-03-25
