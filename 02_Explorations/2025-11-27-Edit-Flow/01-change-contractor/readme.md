# Loop up contacts in TMS master data and store contact in Transport Order

## 1. Contact Loop Up

All look ups will be sourced from the table `person` (which represents the TMS master data and is synced periodically with the CMD (Central master Data)).

## 2. Store Contact in Transport Order

Steps:

- TIX über Sequence holen
- PERS Satz mit dieser TIX und den Adressdaten aus der UI anlegen
- Satz in SEN_TB mit TIX der PERS und TransportOrder schreiben