---
type: email-draft
to: Roel Janssen
cc: (optional) Nikolay …, Maximilian Kehder
subject: New Dispo → CALsuite WM EDI — header contract & Service Bus target
date: 2026-06-26
---

Hi Roel,

Thanks for the alignment. To have it in writing before we implement, here is the
contract we'll use for the New Dispo → CALsuite WM EDI messages — please flag anything
that looks off.

## Message contract

The JSON datacontract (message body) stays **unchanged**. We add these headers (Azure
Service Bus application properties, leading underscore) and set the Subject:

| Header / property        | Value                            |
| ------------------------ | -------------------------------- |
| `_contextPartyId`        | string, per environment (below)  |
| `_component`             | `CALConsult.Disposition.API`     |
| `_correlationId`         | GUID (optional — we'll send it)  |
| Subject (`system.Label`) | `SendPickupPlanToCALsuiteWM`     |

`_culture` is not sent. SDK: official `Azure.Messaging.ServiceBus`. Tracked as User
Story #125889.

## Service Bus target — queue `newdispo_to_calsuite` (CALsuite WM directly)

| Env | Namespace           | `_contextPartyId` |
| --- | ------------------- | ----------------- |
| DEV | `sb-calsuitewm-dev` | `"44901"`         |
| ABN | `sb-calsuitewm-tst` | `"28302"`         |
| UAT | `sb-calsuitewm-acc` | `"303"`           |
| PRD | `sb-calsuitewm-prd` | `"507"`           |

## Next

We'll fire a sample message for you to verify (fast iteration), and have Nikolay
confirm the `newdispo_to_calsuite` queue is provisioned on each namespace, then
implement and deploy.

Thanks,
Matthias
