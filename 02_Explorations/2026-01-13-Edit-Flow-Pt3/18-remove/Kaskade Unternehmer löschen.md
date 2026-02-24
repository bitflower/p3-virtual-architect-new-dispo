# Kaskade Unternehmer löschen 2026-01-15

## Entfernen Contractor

- Wir nutzen für Pickup Planning den `Mode` so, dass der Trailer nicht gelöscht wird
- Der `Mode` wird allerdings auch mit `remlkw` genutzt. Dies hat aber einen Einfluss.
- **Exakter Wert wird von Joachim bereitgestellt**
- Es ist auch noch ein Systemparameter beteiligt: `FVM_MODUNT_REMANH`
  - FVM: Fernverkhrsmodul
  - MODUNT: Modify Unternehmer (Event)
  - REMANH: Remove Anhänger (Folge)
  - bestimmt pro Branch, ob beim Entfernen des Unternehmer der Trailer gelöscht wird
  - Ist in allen Nagelniederlassungen so eingestellt
- Testen: Wird der Carrier enrfernt durch `remunt` ? Ggf. Sonja

## Entfernen Carrier

- Wird der Trailer überhaupt von TMS Core entfernt? Logik in `remunt`
  - Testen!
  - Falls Verhalten nicht wie gewünscht => TMS Anpassungen notwendig
- Carrier wird in UniFace nicht über `remunt` entfernt!
- Hat nur informellen Character, nicht rechnugsrelevant, muss nur auf Transportauftrag stehen
- Driver Terminal: Fahrer sieht Frachtführer/Carrier und nicht Unternehmer!

## Nebenthemen

- Zentrale Frage: Hängt das Fahrzeug am Unternehmer oder Frachtführer?
- "Session-Cache"
  - Session = Anmeldung an der Datenbank = Oracle-Session
  - Liest einzene Systemparameter ein
  - Werden im package gehalten
  - Z.B. in PTA
  - Wird von PostGres in temp. Tabelle gehalten
  - pDis_TransportOrder baut diesen aber bei jeder Anfrage neu auf => Daher irrelevant

## Code Guidelines

- `ParticipantType` mit den Werten `UNN`, `UNF` & `FRF` ist unsauber, da es sich hierbei um Implementation Details des TMS Core handelt.
  - Option 1: Separate `AddContractor`, etc. Functionen
    - Vorteil: Keine Unterscheidung zw. UNN und UNF
    - Nagel unterscheidet zwischen diesen beiden Arten (was eine Person sein kann)
    - **Filterung muss nochmal geprüft werden, z.B. auch auf unterscheidung von nach und Fernverkehr (ob wir dies in New Dispo unterscheiden müssen)** => Max beisheim + Patrick Uschmann
  - Option 2: Saubere, englische Mappings zu jeden Wert, `UNN` = Contractor, `FRF` = Carrier
    - Drei Beteiligte ergibt keinen Sinn
    - Wenn dann zwei: Contractor und Carrier

## Neue Bedingungen

- Im Fahrzeugstamm ist Egentümer eingetragen => Fahrzeug rausnehmen sollte zum Entfernen des Fahrzeug führen (Joachim)
  - Falls nicht (z.B. nur License Plate): dann evtl. nicht
  - Nur die Trailer sind im zentralen Stamm hinterlegt
  - Zugmaschinen hingegen im lokalen TMS-Stamm
- Im Fall Carrier
  - Wenn kein Carrier eingegragen, ist der Contractor der Carrier
  - Zwischen Nagel und Frachtführer gibt es keine vertragliche Beziehung, nur Haftung