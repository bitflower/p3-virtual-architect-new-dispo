# EDI partyID change - contextPartyId header for Backend EDI flow to CALsuite WM

**Date:** 2026-06-25 (contract confirmed & approach aligned 2026-06-26)
**Status:** Aligned — handed to implementing dev for fast-iteration validation

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
`EdiProvider` → Azure Service Bus → CALsuite WM directly). The now-deprecated
~~CrossDock Event Publisher~~ is *not* in scope.

**This is a Backend code change, not just config.** The Backend's EDI sender
(`EdiProvider`) currently sends a bare JSON body with **zero message headers /
application properties** — there is no place for `contextPartyId` to live today.
Making the flow "work" requires: (1) setting the headers + subject in
`EdiProvider`, (2) a config field to carry the per-environment `contextPartyId`
value, and (3) wiring that value into each deployment.

**Contract confirmed (Roel, 2026-06-26 — `00_Meetings/2026-06-26_EDI-alignment-Roel/`).**
New Dispo sets the envelope as **message headers** (ASB application properties,
leading underscore) plus the message **Subject** (`system.Label`):

| field | role | value |
| ----- | ---- | ----- |
| `_contextPartyId` | party id for Nagel-Group (env-dependent) | `303` ACC/UAT, `507` PROD |
| `_component` | source api/service identifying the sender | `CALConsult.Disposition.API` (the Backend assembly/project name) |
| `_correlationId` | track consumption in CALsuite | **optional** GUID — Roel recommends using it |
| `Subject` (`system.Label`) | message subject CALsuite WM routes on | `SendPickupPlanToCALsuiteWM` |

**Agreed approach:** the **datacontract (JSON body / `JsonRootDto`) stays
unchanged** — we only add the headers and set the Subject. Use the official
**Azure Service Bus SDK** (`Azure.Messaging.ServiceBus`, already referenced
v7.20.1 — recommendation already satisfied). Then **validate via fast iteration**
(fire events → Nagel confirms) *before* committing and deploying — see
*Validation plan* below.

*Roel's two screenshots are reference only* (not the contract): a generic console
sender showing the SDK pattern (`message.Subject` + `ApplicationProperties.Add(...)`,
`ServiceBusClient` is heavy → cache/reuse), and CALsuite's own
`MessageHeadersFactory` (`CALConsult.CALoms.Shipment`) which reads `ContextPartyId`
as a numeric `long` from config — so the value is numeric (303/507), not a string.

## Resolved by alignment (Roel, 2026-06-26)

1. **Header vs. body → headers.** Set as ASB **application properties** (message
   headers), not body fields.
2. **Name/casing → leading underscore.** `_contextPartyId` (confirms the
   screenshot; *not* the deprecated CrossDock `contextPartyId`).
3. **Other headers.** `_component` (source api/service) is **required**;
   `_correlationId` (GUID) is **optional but recommended** for tracking consumption
   in CALsuite. Plus set the message **Subject** (`system.Label`) =
   `SendPickupPlanToCALsuiteWM`.
4. **Lobster vs. direct → CalSuite direct.** New Dispo sets the headers itself and
   now publishes to **CalSuite WM directly** (no Lobster), so the headers travel with
   our message regardless of environment.
5. **SDK.** Use the official **Azure Service Bus SDK** (`Azure.Messaging.ServiceBus`)
   — already referenced (v7.20.1); recommendation already satisfied.

## Decided (2026-06-26)

- **`_component` = `CALConsult.Disposition.API`** — the Backend's assembly/project
  name (csproj sets no `AssemblyName`/`RootNamespace`, so it defaults to the project
  file name); fits Roel's `CALConsult.<product>.<area>` "source api/service"
  convention. In-code alternative is the existing self-id `CALConsult.NewDispo.EdiProvider`
  (hardcoded as the body `correlationId` at `EdiJsonBuilderSubHandler.cs:45`).
- **DEV `contextPartyId` = n/a** — DEV sends no CALsuite EDI (accepted).
- **`_culture`** — intentionally **skipped**, not required.
- **Target = CalSuite WM directly, not Lobster** — New Dispo no longer publishes via
  Lobster. ABN & UAT route internally to CalSuite **ACC** (`_contextPartyId` = 303);
  PROD = 507. CalSuite queue per GoLive page = `newdispo_to_calsuite`. ⚠️ The GoLive
  ABN/UAT rows still show the stale `newdispo_to_lobster` — see *Still open #2*.

## Still open

1. **Config vs. secret.** `contextPartyId` is a non-secret static value; inject via
   the same pipeline jq patch as `ConnectionString`/`Queue`, or hardcode per
   `appsettings.{ENV}.json`. (Pipeline injection keeps all EDI settings in one place.)
   Note CALsuite reads it as a numeric `long`.
2. **ABN/UAT queue name.** GoLive page (`§3.4`) lists `newdispo_to_lobster` for
   ABN/UAT but `newdispo_to_calsuite` for PROD; with Lobster dropped, confirm ABN/UAT
   now use `newdispo_to_calsuite` and update the GoLive page accordingly.

## Analysis

### Why the EDI flow (and not CrossDock)

Two outbound integrations to CALsuite existed; the user has confirmed CrossDock is
deprecated, leaving the EDI flow as the one to productionize:

| Flow | Component | Repo | Mechanism | `contextPartyId` today |
| ---- | --------- | ---- | --------- | ---------------------- |
| **EDI (in scope)** | New Dispo Backend `SendToEDI` | `Code/Disposition-Backend` | ASB **queue** → CALsuite WM (direct) | **None — no headers set at all** |
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
  → CALsuite WM (direct)
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

**Correction (2026-06-26):** New Dispo **no longer publishes via Lobster** — the
target is **CalSuite WM directly** (queue `newdispo_to_calsuite`). The GoLive page
(`02_Explorations/2026-04-17_New_Dispo_GoLive_1060_Oracle/`, §3.4) still lists
`newdispo_to_lobster` for ABN/UAT (PROD already shows `newdispo_to_calsuite`); those
ABN/UAT rows look stale and should be reconciled. ABN & UAT route internally to
CalSuite **ACC**.

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
   - `EdiProvider.SendEdiMessageAsync` → set `Subject = "SendPickupPlanToCALsuiteWM"` and add the `_contextPartyId` / `_component` / (optional) `_correlationId` application properties.
   - `AzureServiceBusSettingsDto` → add `ContextPartyId` alongside `ConnectionString`/`Queue` (`_component` is a constant `CALConsult.Disposition.API`, no config field needed).
   - Each deployment pipeline → inject `.EdiSettings.ContextPartyId` (mirror the existing `ConnectionString`/`Queue` jq pattern), or set it in `appsettings.{ENV}.json` (it's a non-secret static value).
3. **Environment values.** ABN & UAT both route internally to CALsuite **ACC**
   (confirmed 2026-06-26), so both carry **303**; only DEV is unspecified.

   | Stage | contextPartyId |
   | ----- | -------------- |
   | ABN (→ CALsuite ACC) | **303** |
   | UAT (→ CALsuite ACC) | **303** |
   | PROD | **507** |
   | DEV | n/a — no CALsuite EDI on DEV (accepted) |
4. **Envelope contract — now confirmed (Roel, 2026-06-26).** Underscore-prefixed
   application properties `_contextPartyId`, `_component`, `_correlationId`
   (optional), plus Subject `SendPickupPlanToCALsuiteWM`. The leading-underscore
   form is confirmed (not the deprecated CrossDock `contextPartyId`). `_culture`
   (=en in yesterday's screenshot) is intentionally **skipped** — not required
   (confirmed 2026-06-26).
5. **PROD EDI is not wired yet** (pipeline injection commented out; GoLive status
   "open") — so PROD needs both the connection/queue *and* the new value before it
   can work end-to-end.

### Proposed change (contract confirmed — NOT yet applied; validate first)

Datacontract (JSON body) unchanged — only the Subject + headers are added.

```csharp
// EdiProvider.SendEdiMessageAsync
var wrappedMessage = new ServiceBusMessage(message)
{
    // Subject == the older "Label" (system.Label); CALsuite WM routes on it.
    Subject = "SendPickupPlanToCALsuiteWM",
};

// Headers CALsuite WM reads to map our JSON to the correct route-planning context.
// Leading underscore is part of the contract (Roel, 2026-06-26).
wrappedMessage.ApplicationProperties.Add("_contextPartyId", _settings.ContextPartyId); // 303 ACC/UAT, 507 PROD (numeric)
wrappedMessage.ApplicationProperties.Add("_component", "CALConsult.Disposition.API"); // the Backend assembly/project name (source api/service)
wrappedMessage.ApplicationProperties.Add("_correlationId", Guid.NewGuid().ToString());  // optional, recommended
// _culture (=en in the screenshot) intentionally skipped — not required (confirmed 2026-06-26).

await sender.SendMessageAsync(wrappedMessage);
```

### Validation plan (fast iteration — dev-driven)

This exploration is the **handoff**; the implementing dev drives the steps below.
Goal: confirm the contract end-to-end with Nagel/CALsuite **before** committing or
deploying — avoid the slow code → build → deploy → trigger → check loop.

1. **Fire** a representative message (unchanged JSON body + the Subject and headers
   above) at **CalSuite WM directly** (queue `newdispo_to_calsuite` per the GoLive
   page; New Dispo no longer publishes via Lobster) — ABN & UAT both route internally
   to CalSuite **ACC**, so `_contextPartyId` = 303. Fastest from a local run; Roel's
   sample console sender is a ready template and the Backend already uses the same SDK.
2. **Nagel confirms** quickly that CALsuite WM maps it to the route planning.
3. **Only then** make the change permanent in `EdiProvider` + config, commit, and
   deploy (ABN → UAT → PROD).

Target decided (2026-06-26): **CalSuite WM directly** (queue `newdispo_to_calsuite`),
**not** Lobster and **not** the P3 POC namespace in `appsettings.Local.json`. The
CalSuite connection string is a pipeline secret (empty in local/ABN/UAT appsettings);
the implementing dev supplies it for the local run.

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
- Alignment / contract confirmation: `00_Meetings/2026-06-26_EDI-alignment-Roel/` (Roel, 2026-06-26 — note + 2 reference screenshots)
- GoLive / ASB setup: `02_Explorations/2026-04-17_New_Dispo_GoLive_1060_Oracle/new-dispo-golive-1060-oracle.md`
- Infra context: `02_Explorations/2026-03-03_Infrastructure-documentation-wiki-comparison/Infrastructure-Operational-Guide.md` (CALSuite Service Bus)
- Deprecated, for contrast only: `[ADR001] Data Exchange Between TMS and CALSuite's Cross-Dock`; `Code/Nagel-GCP/CrossDockEventPublisher`
