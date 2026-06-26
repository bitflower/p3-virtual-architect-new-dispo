
 
NewDispo will set these headers on the message:

_contextPartyId - Party id corresponding with Nagel-Group (for ACC: 303)
_component - Source api/service (e.g. CALConsult.CALsuite.Transport)
_correlationId (optional) - Usually a GUID, you can use this to track consumption in CALsuite. I recommend using it.

Set the subject on the message (system.Label) - SendPickupPlanToCALsuiteWM

Recommendation: use the Azrue Service Bus SDK (official)

## Code Exmaples

See the screenshots

## Environment Mapping

DEV = sb-calsuitewm-dev
ABN = sb-calsuitewm-tst
UAT = sb-calsuitewm-acc
PRD = sb-calsuitewm-prd

## contextPartyId

DEV: 44901
TST: 28302
ACC: 303
PRD: 507

These are static values, will never change
