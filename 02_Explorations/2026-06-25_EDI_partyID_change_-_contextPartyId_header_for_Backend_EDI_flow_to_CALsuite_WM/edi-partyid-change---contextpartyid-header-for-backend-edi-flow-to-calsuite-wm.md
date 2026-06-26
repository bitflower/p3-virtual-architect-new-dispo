# EDI partyID change - contextPartyId header for Backend EDI flow to CALsuite WM

**Date:** 2026-06-25
**Status:** Ready for fast-iteration validation

---

<internal>

## Original User Input

Request from the client (Patrick), forwarded by Max Kehder
(`00_Meetings/2026-06-25_EDI-partyID.change/2026-06-25_EDI-partyID.change.md`):

> **Patrick (DE):** Damit CALsuite WM unser JSON mit der Tourenplanung richtig
> zuordnen kann, benötigen die eine weitere Information im Header. Ist ein
> statischer Wert abhängig von der Umgebung, die wir ansprechen möchten.
> ACC: 303 / Prod: 507
>
> **Max (EN):** To enable CALsuite WM to correctly map our JSON to the route
> planning, we need to include some additional information in the header. This is
> a static value that depends on the environment we wish to address.
> `ACC = UAT`. "This is another code change isn't it?"

Reference screenshot (`image.png`) — message **headers** as CALsuite WM expects them:

| name              | value                       |
| ----------------- | --------------------------- |
| `_component`      | `CALConsult.CALoms.Shipment`|
| `_contextPartyId` | `303`                       |
| `_correlationId`  | *(present)*                 |
| `_culture`        | `en`                        |

Follow-up clarification from Matthias: **CrossDock is deprecated. We need to get the EDI flow working.**

---

</internal>

## Summary

CALsuite WM needs a static, environment-dependent **`contextPartyId`** value in the
header of the messages New Dispo sends it, so it can map our JSON to the route-planning
(Tourenplanung) context. The relevant path is the **New Dispo Backend EDI flow**
(`SendToEDI` → `EdiProvider` → Azure Service Bus → CALsuite WM directly); the
deprecated CrossDock Event Publisher is out of scope.

This is a **Backend code change**, not just config: `EdiProvider` currently sends a
bare JSON body with **zero message headers / application properties**, so there is no
place for `contextPartyId` today. The work is (1) setting the headers + Subject in
`EdiProvider`, (2) a config field for the per-environment `contextPartyId`, and
(3) wiring it into each deployment.

## Contract

The datacontract (JSON body / `JsonRootDto`) is **unchanged**. New Dispo adds message
headers (ASB application properties, leading underscore) and sets the message
**Subject** (`system.Label`):

| Field | Role | Value |
| ----- | ---- | ----- |
| `_contextPartyId` | party id for Nagel-Group (env-dependent) | **string**, per environment — see table below |
| `_component` | source api/service identifying the sender | `CALConsult.Disposition.API` (the Backend assembly/project name) |
| `_correlationId` | track consumption in CALsuite | GUID (optional) |
| `Subject` (`system.Label`) | message subject CALsuite WM routes on | `SendPickupPlanToCALsuiteWM` |

`_culture` is not sent. Use the official **Azure Service Bus SDK**
(`Azure.Messaging.ServiceBus`, already referenced v7.20.1).

**Service Bus target** — queue `newdispo_to_calsuite` on every environment, CALsuite WM
directly (no Lobster):

| Env | Service Bus Namespace | `_contextPartyId` |
| --- | --------------------- | ----------------- |
| DEV | `sb-calsuitewm-dev` | `"44901"` |
| ABN | `sb-calsuitewm-tst` | `"28302"` |
| UAT | `sb-calsuitewm-acc` | `"303"` |
| PRD | `sb-calsuitewm-prd` | `"507"` |

## Open items

1. **Config vs. secret.** `contextPartyId` is a non-secret static value; inject via the
   pipeline jq patch (like `ConnectionString`/`Queue`) or per `appsettings.{ENV}.json`.
2. **Queue provisioning.** Confirm the `newdispo_to_calsuite` queue is set on each
   namespace (Nikolay).

## Analysis

### Why the EDI flow (and not CrossDock)

Two outbound integrations to CALsuite exist; CrossDock is deprecated, leaving the EDI
flow as the one to productionize:

| Flow | Component | Repo | Mechanism | `contextPartyId` today |
| ---- | --------- | ---- | --------- | ---------------------- |
| **EDI (in scope)** | New Dispo Backend `SendToEDI` | `Code/Disposition-Backend` | ASB **queue** → CALsuite WM (direct) | **None — no headers set at all** |
| ~~CrossDock (deprecated)~~ | `CrossDockEventPublisher` Cloud Function | `Code/Nagel-GCP` | ASB **topic** | Set from env var `ENVIRONMENT` (`28302` test / `44901` fallback) |

The request wording ("CALsuite **WM**", "shipment", "map our JSON to the route
planning") matches the EDI flow, whose purpose is *"Outbound EDI messages
(invoice/shipment distribution)"*.

### End-to-end EDI flow

```
Frontend "Send to EDI" action
  → ClientCommunicationController (ClientCommunicationController.cs:64)
  → SendToEdiCommand → SendToEdiCommandHandler
      • resolves tourpoint/shipment communication info
      • whitelist check
      • builds JSON via EdiJsonBuilderSubHandler   ← the "JSON" Patrick refers to
      • EdiProvider.SendEdiMessageAsync(json)        ← sends BARE body, no headers
  → Azure Service Bus queue (EdiSettings.Queue)
  → CALsuite WM (direct)
```

The JSON body (`JsonRootDto`) carries `correlationId`, `createdAt`,
`messageType: "SendPickupPlanToCustomerAction"`, `company`, `branch`, `content`. It does
**not** carry `component`, `contextPartyId`, or `culture`. The underscore-prefixed fields
are **message envelope headers** → `ServiceBusMessage.ApplicationProperties`.

### Per-environment Service Bus targets

| Stage | Service Bus Namespace | Queue | Status |
| ----- | --------------------- | ----- | ------ |
| DEV   | `sb-calsuitewm-dev` | `newdispo_to_calsuite` | open |
| ABN   | `sb-calsuitewm-tst` | `newdispo_to_calsuite` | open |
| UAT   | `sb-calsuitewm-acc` | `newdispo_to_calsuite` | open |
| PRD   | `sb-calsuitewm-prd` | `newdispo_to_calsuite` | open |

CALsuite WM directly (no Lobster). Pending: Nikolay to confirm the queue is set on each
namespace.

## Source Code Evidence

**The exact change point — `EdiProvider` sends no headers:**
`Code/Disposition-Backend/CALConsult.Disposition.API/Infrastructure/AzureServiceBus/EDI/EdiProvider.cs:30-35`
```csharp
public async Task SendEdiMessageAsync(string message)
{
    ServiceBusSender sender = _client.CreateSender(_queueName);
    var wrappedMessage = new ServiceBusMessage(message);   // ← no ApplicationProperties
    await sender.SendMessageAsync(wrappedMessage);
}
```
(Verified: `grep ApplicationProperties` over `Infrastructure/AzureServiceBus/` returns nothing.)

**Config DTO — only connection string + queue:**
`…/Infrastructure/AzureServiceBus/Dtos/AzureServiceBusSettingsDto.cs`
```csharp
public string ConnectionString { get; set; } = "";
public string Queue { get; set; } = "";
// no party-id field exists
```

**JSON builder / body shape:**
`…/Application/Features/ClientCommunication/Requests/SendToEDI/SubHandlers/EdiJsonBuilderSubHandler.cs:43-56`
— builds `JsonRootDto { CorrelationId = "CALConsult.NewDispo.EdiProvider",
MessageType = "SendPickupPlanToCustomerAction", … }`.
`…/SendToEDI/Dtos/JsonDtos/JsonRootDto.cs` — JSON names `correlationId`, `createdAt`,
`messageType`, `content` (no underscores, no `component`/`contextPartyId`/`culture`).

**Trigger / handler:**
`…/Application/Features/ClientCommunication/ClientCommunicationController.cs:64`
→ `SendToEdiCommand` → `SendToEdiCommandHandler.cs:72-75` (builds JSON, calls
`SendEdiMessageAsync`).

**Deployment config injection (jq patch of appsettings at deploy):**
- `Code/Disposition-Backend/azure-pipelines-cloudrun-t-t-uat.yml:49-50` — `.EdiSettings.ConnectionString`, `.EdiSettings.Queue`
- `azure-pipelines-cloudrun-t-t.yml:51-52` — ABN equivalents
- `azure-pipelines-cloudrun-p-p.yml:101-102` — PROD equivalents, **currently commented out**

**Topology reference:**
- `02_Explorations/2026-04-17_New_Dispo_GoLive_1060_Oracle/new-dispo-golive-1060-oracle.md` (§3.4 Azure Service Bus)

## Findings

1. **It is a code change.** The Backend EDI sender attaches no application properties;
   `contextPartyId` cannot be set by config alone.
2. **Minimal change surface = 3 spots:**
   - `EdiProvider.SendEdiMessageAsync` → set `Subject = "SendPickupPlanToCALsuiteWM"` and add the `_contextPartyId` / `_component` / `_correlationId` application properties.
   - `AzureServiceBusSettingsDto` → add `string ContextPartyId` alongside `ConnectionString`/`Queue` (`_component` is the constant `CALConsult.Disposition.API`).
   - Each deployment pipeline → inject `.EdiSettings.ContextPartyId` (mirror the `ConnectionString`/`Queue` jq pattern) or set per `appsettings.{ENV}.json`.
3. **Environment values.** `_contextPartyId` is a **string**, per environment: DEV
   (`sb-calsuitewm-dev`) `"44901"`, ABN (`sb-calsuitewm-tst`) `"28302"`, UAT
   (`sb-calsuitewm-acc`) `"303"`, PRD (`sb-calsuitewm-prd`) `"507"`.
4. **Envelope.** Underscore-prefixed application properties `_contextPartyId` (string),
   `_component`, `_correlationId` (optional), plus Subject `SendPickupPlanToCALsuiteWM`.
   `_culture` is not sent.
5. **PROD EDI is not wired yet** (pipeline injection commented out), so PROD needs the
   connection/queue and the value before it can work end-to-end.

### Proposed change

Datacontract (JSON body) unchanged — only the Subject + headers are added.

```csharp
// EdiProvider.SendEdiMessageAsync
ServiceBusSender sender = _client.CreateSender(_queueName);

var wrappedMessage = new ServiceBusMessage(message)
{
    Subject     = "SendPickupPlanToCALsuiteWM",   // == system.Label
    ContentType = "application/json",
};

wrappedMessage.ApplicationProperties.Add("_contextPartyId", _settings.ContextPartyId); // string, e.g. "303"
wrappedMessage.ApplicationProperties.Add("_component",      "CALConsult.Disposition.API");
wrappedMessage.ApplicationProperties.Add("_correlationId",  Guid.NewGuid().ToString());

await sender.SendMessageAsync(wrappedMessage);
```

`AzureServiceBusSettingsDto` gains `string ContextPartyId`, injected per environment.

### Validation plan (fast iteration)

Confirm the contract end-to-end with Nagel/CALsuite **before** committing or deploying:

1. **Fire** a representative message (unchanged JSON body + the Subject and headers
   above) at the target namespace/queue — fastest from a local run. The Backend already
   uses the same SDK.
2. **Nagel confirms** CALsuite WM maps it to the route planning.
3. **Only then** make the change permanent in `EdiProvider` + config, commit, and deploy
   (ABN → UAT → PROD).

## Related Files

- `Code/Disposition-Backend/CALConsult.Disposition.API/Infrastructure/AzureServiceBus/EDI/EdiProvider.cs`
- `Code/Disposition-Backend/CALConsult.Disposition.API/Infrastructure/AzureServiceBus/Dtos/AzureServiceBusSettingsDto.cs`
- `Code/Disposition-Backend/CALConsult.Disposition.API/Application/Features/ClientCommunication/Requests/SendToEDI/` (Command, Handler, `EdiJsonBuilderSubHandler`, `JsonRootDto`, DTOs)
- `Code/Disposition-Backend/CALConsult.Disposition.API/Application/Features/ClientCommunication/ClientCommunicationController.cs`
- `Code/Disposition-Backend/CALConsult.Disposition.API/appsettings.{ABN,UAT,Production,Development,Local}.json` (`EdiSettings` section)
- `Code/Disposition-Backend/azure-pipelines-cloudrun-{t-t,t-t-uat,p-p}.yml`

## Related User Stories/Tasks

- **ADO User Story [#125889](https://dev.azure.com/p3ds/Nagel-CAL%20Disposition/_workitems/edit/125889)** — "EDI flow: add contextPartyId header so CALsuite WM can map our JSON to route planning" (child of Feature [#123230](https://dev.azure.com/p3ds/Nagel-CAL%20Disposition/_workitems/edit/123230) "Customer Communication")
- Alignment notes: `00_Meetings/2026-06-26_EDI-alignment-Roel/`
- GoLive / ASB setup: `02_Explorations/2026-04-17_New_Dispo_GoLive_1060_Oracle/new-dispo-golive-1060-oracle.md`
- Deprecated, for contrast only: `[ADR001] Data Exchange Between TMS and CALSuite's Cross-Dock`; `Code/Nagel-GCP/CrossDockEventPublisher`
