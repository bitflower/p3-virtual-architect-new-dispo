# EDI partyID change - contextPartyId header for Backend EDI flow to CALsuite WM

**Date:** 2026-06-25
**Status:** Exploration

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
header of the messages New Dispo sends it, so it can map our JSON to the correct
route-planning (Tourenplanung) context: **`303` for ACC/UAT, `507` for Prod**.

The relevant path is the **New Dispo Backend EDI flow** (`SendToEDI` →
`EdiProvider` → Azure Service Bus → Lobster/CALsuite WM). The now-deprecated
CrossDock Event Publisher is *not* in scope.

**This is a Backend code change, not just config.** The Backend's EDI sender
(`EdiProvider`) currently sends a bare JSON body with **zero message headers /
application properties** — there is no place for `contextPartyId` to live today.
Making the flow "work" requires: (1) adding the header in `EdiProvider`, (2) a
config field to carry the per-environment value, and (3) wiring that value into
each deployment.

**Blocker before coding:** the exact header envelope CALsuite WM requires is
**undocumented** in our repo (the operational guide only states "Message Format:
EDI JSON bodies"). The screenshot shows an underscore-prefixed envelope
(`_component`, `_contextPartyId`, `_correlationId`, `_culture`) that matches
*neither* our current output *nor* the old CrossDock output. The precise contract
(property names, which headers are mandatory) must be confirmed with Patrick /
the CALsuite team — see below.

## Questions/Open Items (blocker — confirm with Patrick / CALsuite before coding)

1. **Header vs. body** — is `contextPartyId` expected as an ASB **application
   property** (most consistent with the screenshot's header view) or as a field in
   the JSON body? (Backend sets neither today.)
2. **Exact property name/casing** — screenshot shows `_contextPartyId` (leading
   underscore); deprecated CrossDock used `contextPartyId` (no underscore). Which
   does CALsuite WM actually read?
3. **Other headers** — Patrick says only *"one more"* piece of info is needed, yet
   the screenshot shows four headers. Are `_component` (`CALConsult.CALoms.Shipment`),
   `_correlationId`, `_culture` (`en`) **also required**, or already satisfied
   elsewhere? Does CALsuite WM expect `_component` to identify *our* message type?
4. **Lobster vs. direct** — on ABN/UAT the path goes via **Lobster**
   (`newdispo_to_lobster`); does Lobster currently inject the other envelope
   headers? PROD targets CALsuite WM **directly** (`newdispo_to_calsuite`) — if
   Lobster was the one adding them, the direct PROD path would be missing them.
5. **ABN / DEV value** — Patrick only gave ACC=303 and Prod=507. What value (if
   any) for ABN and DEV? (ABN shares the `sb-calsuite-tst` namespace with UAT, so
   plausibly 303 — needs confirmation.)
6. **Config vs. secret** — `contextPartyId` is a non-secret static value; inject
   via the same pipeline jq patch as `ConnectionString`/`Queue`, or hardcode per
   `appsettings.{ENV}.json`? (Pipeline injection keeps all EDI settings in one place.)

## Analysis

### Why the EDI flow (and not CrossDock)

Two outbound integrations to CALsuite existed; the user has confirmed CrossDock is
deprecated, leaving the EDI flow as the one to productionize:

| Flow | Component | Repo | Mechanism | `contextPartyId` today |
| ---- | --------- | ---- | --------- | ---------------------- |
| **EDI (in scope)** | New Dispo Backend `SendToEDI` | `Code/Disposition-Backend` | ASB **queue** → Lobster / CALsuite WM | **None — no headers set at all** |
| ~~CrossDock (deprecated)~~ | `CrossDockEventPublisher` Cloud Function | `Code/Nagel-GCP` | ASB **topic** | Set from env var `ENVIRONMENT` (`28302` test / `44901` fallback) |

The request wording ("CALsuite **WM**", "shipment", "map our JSON to the route
planning") matches the EDI flow, whose purpose is documented as *"Outbound EDI
messages (invoice/shipment distribution)"* and whose PROD target is the CALsuite
**WM** namespace (`sb-calsuitewm-acc`).

### End-to-end EDI flow (current state)

```
Frontend "Send to EDI" action
  → ClientCommunicationController (ClientCommunicationController.cs:64)
  → SendToEdiCommand → SendToEdiCommandHandler
      • resolves tourpoint/shipment communication info
      • whitelist check
      • builds JSON via EdiJsonBuilderSubHandler   ← the "JSON" Patrick refers to
      • EdiProvider.SendEdiMessageAsync(json)        ← sends BARE body, no headers
  → Azure Service Bus queue (EdiSettings.Queue)
  → Lobster / CALsuite WM
```

The JSON body itself (`JsonRootDto`) carries `correlationId`, `createdAt`,
`messageType: "SendPickupPlanToCustomerAction"`, `company`, `branch`, `content`
(tour + shipment information). It does **not** carry `component`, `contextPartyId`,
or `culture`, and its `correlationId` is the constant string
`CALConsult.NewDispo.EdiProvider` (not a per-message id).

→ The screenshot's underscore-prefixed fields are therefore **message envelope
headers**, not body fields. In Azure Service Bus terms these map to
`ServiceBusMessage.ApplicationProperties` — which the Backend never populates.

### Per-environment Service Bus targets (from GoLive doc)

| Stage | ASB Namespace | Queue | Status |
| ----- | ------------- | ----- | ------ |
| ABN   | `sb-calsuite-tst…`    | `newdispo_to_lobster`  | done |
| UAT   | `sb-calsuite-tst…`    | `newdispo_to_lobster`  | done |
| PROD  | `sb-calsuitewm-acc…`  | `newdispo_to_calsuite` | open |

Note ABN/UAT route via **Lobster**; PROD targets a **CALsuite-WM-direct** queue.
This matters for the open question of whether Lobster injects any of the other
envelope headers on the ABN/UAT path.

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
`…/SendToEDI/Dtos/JsonDtos/JsonRootDto.cs` — JSON names `correlationId`,
`createdAt`, `messageType`, `content` (no underscores, no `component`/`contextPartyId`/`culture`).

**Trigger / handler:**
`…/Application/Features/ClientCommunication/ClientCommunicationController.cs:64`
→ `SendToEdiCommand` → `SendToEdiCommandHandler.cs:72-75` (builds JSON, calls
`SendEdiMessageAsync`).

**Deployment config injection (jq patch of appsettings at deploy):**
- `Code/Disposition-Backend/azure-pipelines-cloudrun-t-t-uat.yml:49-50` — `.EdiSettings.ConnectionString = "$(ASB_CONN_LOBSTER_T_T_UAT)"`, `.EdiSettings.Queue = "$(ASB_QUEUE_UAT)"`
- `azure-pipelines-cloudrun-t-t.yml:51-52` — ABN equivalents
- `azure-pipelines-cloudrun-p-p.yml:101-102` — PROD equivalents, **currently commented out**

**Topology references:**
- `02_Explorations/2026-04-17_New_Dispo_GoLive_1060_Oracle/new-dispo-golive-1060-oracle.md:171-179` (ASB namespaces/queues per stage)
- `02_Explorations/2026-03-03_Infrastructure-documentation-wiki-comparison/Infrastructure-Operational-Guide.md:405-418` (CALSuite Service Bus; "Message Format: EDI JSON bodies" — no header contract)

## Findings

1. **It is a code change.** The Backend EDI sender attaches no application
   properties; `contextPartyId` cannot be set by config alone.
2. **Minimal change surface = 3 spots:**
   - `EdiProvider.SendEdiMessageAsync` → add `wrappedMessage.ApplicationProperties.Add("contextPartyId", _settings.ContextPartyId)` (exact name TBD).
   - `AzureServiceBusSettingsDto` → add `public string ContextPartyId { get; set; } = "";`.
   - Each deployment pipeline → inject `.EdiSettings.ContextPartyId` (mirror the existing `ConnectionString`/`Queue` jq pattern), or set it in `appsettings.{ENV}.json` (it's a non-secret static value).
3. **Environment values (only ACC/Prod given):**

   | Stage | contextPartyId |
   | ----- | -------------- |
   | UAT (= ACC) | **303** |
   | PROD | **507** |
   | ABN / DEV | ⚠️ not specified by Patrick |
4. **Envelope contract is undocumented.** The screenshot shows
   `_component=CALConsult.CALoms.Shipment`, `_contextPartyId`, `_correlationId`,
   `_culture=en` — underscore-prefixed and matching neither our current output nor
   the old CrossDock output (`component=TMS Bridge`, `contextPartyId`, `_type`).
   Cannot be inferred safely; must be confirmed.
5. **PROD EDI is not wired yet** (pipeline injection commented out; GoLive status
   "open") — so PROD needs both the connection/queue *and* the new value before it
   can work end-to-end.

### Proposed change (pending contract confirmation — NOT yet applied)

```csharp
// EdiProvider.SendEdiMessageAsync
var wrappedMessage = new ServiceBusMessage(message);

// Required by CALsuite WM to map the message to the correct route-planning context.
// Static, environment-dependent value: 303 (ACC/UAT), 507 (PROD).
// NOTE: exact property name/casing and any additional required headers
//       (_component, _correlationId, _culture) to be confirmed with CALsuite.
wrappedMessage.ApplicationProperties.Add("contextPartyId", _settings.ContextPartyId);

await sender.SendMessageAsync(wrappedMessage);
```

## Related Files

- `Code/Disposition-Backend/CALConsult.Disposition.API/Infrastructure/AzureServiceBus/EDI/EdiProvider.cs`
- `Code/Disposition-Backend/CALConsult.Disposition.API/Infrastructure/AzureServiceBus/Dtos/AzureServiceBusSettingsDto.cs`
- `Code/Disposition-Backend/CALConsult.Disposition.API/Application/Features/ClientCommunication/Requests/SendToEDI/` (Command, Handler, `EdiJsonBuilderSubHandler`, `JsonRootDto`, DTOs)
- `Code/Disposition-Backend/CALConsult.Disposition.API/Application/Features/ClientCommunication/ClientCommunicationController.cs`
- `Code/Disposition-Backend/CALConsult.Disposition.API/appsettings.{ABN,UAT,Production,Development,Local}.json` (`EdiSettings` section)
- `Code/Disposition-Backend/azure-pipelines-cloudrun-{t-t,t-t-uat,p-p}.yml`

## Related User Stories/Tasks

- **ADO User Story [#125889](https://dev.azure.com/p3ds/Nagel-CAL%20Disposition/_workitems/edit/125889)** — "EDI flow: add contextPartyId header so CALsuite WM can map our JSON to route planning" (child of Feature [#123230](https://dev.azure.com/p3ds/Nagel-CAL%20Disposition/_workitems/edit/123230) "Customer Communication")
- Request source: `00_Meetings/2026-06-25_EDI-partyID.change/2026-06-25_EDI-partyID.change.md` (+ `image.png`)
- GoLive / ASB setup: `02_Explorations/2026-04-17_New_Dispo_GoLive_1060_Oracle/new-dispo-golive-1060-oracle.md`
- Infra context: `02_Explorations/2026-03-03_Infrastructure-documentation-wiki-comparison/Infrastructure-Operational-Guide.md` (CALSuite Service Bus)
- Deprecated, for contrast only: `[ADR001] Data Exchange Between TMS and CALSuite's Cross-Dock`; `Code/Nagel-GCP/CrossDockEventPublisher`
